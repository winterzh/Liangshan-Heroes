extends "base.gd"
## Three real UI transactions. Faults belong solely to the external native host.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	mode = OS.get_environment("USR_MODE")
	output = OS.get_environment("USR_OUTPUT")
	flow = get_node("/root/ContinueFlow")
	run.call_deferred()

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check("strict isolated source-private scope",profile_valid() and mode in MODES): finish_failure("profile_refused"); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("actual installed source and engine identity",trusted.get("ok",false) and trusted.get("source_mode",false) and trusted.get("content_version") == OS.get_environment("USR_CONTENT") and trusted.get("engine_binary_sha256") == OS.get_environment("USR_ENGINE")): finish_failure("identity_refused"); return
	if not check("native GL normal 1x 60Hz",DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60 and get_node("/root/Settings").game_speed == 1.0): finish_failure("simulation_refused"); return
	AudioServer.set_bus_mute(0,true)
	Localize.set_language("zh_CN",false)
	var deadline: int = Time.get_ticks_msec() + 90000
	while not flow.can_launch() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not check("ordinary startup completed and SDK disabled",flow.can_launch() and flow.last_result.get("startup_checked",false) and flow.is_enabled() and not get_node("/root/SteamService").available): finish_failure("startup_refused"); return
	menu = MenuScene.instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	flow.operation_finished.connect(on_operation)
	if mode == "save_initial": await initial_run()
	elif mode == "retry_save": await retry_run()
	else: await reject_run()

func initial_run() -> void:
	if not check("fresh profile has no original slot",Slot.new(SLOT_ROOT).read_slot().get("code") == "NO_SLOT"): finish_failure("existing_slot"); return
	if not press(text_button(menu,Localize.text("🛡  驻守战"),true),"defense menu"): finish_failure("defense_button"); return
	await get_tree().process_frame
	if not check("ordinary classic menu options",not Campaign.ai_friendly and not Campaign.scale_on): finish_failure("menu_options"); return
	if not press(text_button(menu,Localize.text("🛡  30 关 · 经典（推荐）")),"classic 30 menu"): finish_failure("classic_button"); return
	var deadline: int = Time.get_ticks_msec() + 90000
	while (get_tree().current_scene == null or get_tree().current_scene.get_script() != BattleScript) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	battle = get_tree().current_scene
	if not check("actual menu started original classic world",is_instance_valid(battle) and battle.get_script() == BattleScript and battle.level.get_script() == Classic and battle._official_context == Slot.CONTEXT): finish_failure("menu_world"); return
	check("ordinary starting economy",battle.gold == 250 and battle.wood == 150 and battle.pop_cap == 20)
	while battle.hud._intro_root.visible:
		if not press(battle.hud._intro_btn,"normal intro"): finish_failure("intro"); return
		await get_tree().process_frame
	var first_tick: int = battle._run_clock._next_tick
	deadline = Time.get_ticks_msec() + 30000
	while battle._run_clock._next_tick < first_tick + 120 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not check("ordinary FIGHT clock advances before initial save",battle.phase == battle.Phase.FIGHT and not get_tree().paused and battle._run_clock._next_tick >= first_tick + 120): finish_failure("initial_clock"); return
	if not await pause_world() or not passed(): finish_failure("initial_pause"); return
	if not arm_capture(): finish_failure("initial_capture_observer"); return
	want_exit = true; received = false
	if not press(named(battle.hud,"SaveAndExit"),"initial SaveAndExit"): finish_failure("initial_save_button"); return
	check("empty slot directly requests real capture",flow.phase == flow.Phase.SAVING and battle._save_barrier.state == battle._save_barrier.State.REQUESTED)
	if not await wait_operation() or not result.get("ok",false): finish_failure("initial_save_failed"); return
	while not finished: await get_tree().process_frame

func continue_from_menu() -> bool:
	received = false
	if not press(named(menu,"ContinueBattle"),"actual menu Continue"): return false
	if not await wait_operation(): return false
	return check("actual Flow Continue succeeded",result.get("ok",false),result)

func retry_run() -> void:
	if not load_previous("save_initial"): finish_failure("previous_initial"); return
	var original: Dictionary = previous_disk()
	if original.is_empty() or not passed(): finish_failure("previous_disk"); return
	if not await continue_from_menu() or not verify_restored(previous.checkpoint): finish_failure("initial_restore"); return
	var before: Dictionary = snapshot()
	var before_exact: Variant = exact(before)
	var before_disk: Dictionary = disk_row()
	var before_instances: Dictionary = entity_instances()
	var battle_id: int = battle.get_instance_id()
	var graph_id: int = flow._graph.get_instance_id()
	var lifecycle_id: int = battle._continue_receipt.get_instance_id()
	var frame: int = Engine.get_process_frames()
	if not press(named(battle.hud,"SaveAndExit"),"overwrite prompt for Cancel"): finish_failure("cancel_prompt"); return
	check("existing slot requires real confirmation and keeps pause intent",flow.phase == flow.Phase.CONFIRM and flow._before_paused and flow._source == battle and flow._session == null and battle._save_barrier.state == battle._save_barrier.State.IDLE and get_tree().paused)
	observations["cancel_confirmation"] = {"frame":str(frame),"expected":flow._expected.duplicate(true),"before_paused":flow._before_paused,"battle_instance_id":str(battle_id),"graph_instance_id":str(graph_id),"lifecycle_instance_id":str(lifecycle_id),"clock_next":str(battle._run_clock._next_tick)}
	if not press(named(flow,"CancelSave"),"actual CancelSave"): finish_failure("cancel_button"); return
	# No await between opening confirmation and cancellation: exact world equality
	# is valid only for this still-paused synchronous stack.
	check("same-stack Cancel clears only prompt and retains real objects",Engine.get_process_frames() == frame and flow.phase == flow.Phase.IDLE and flow._session == null and flow._source == null and flow._expected.is_empty() and flow._overlay == null and get_tree().paused and battle.get_instance_id() == battle_id and flow._graph.get_instance_id() == graph_id and battle._continue_receipt.get_instance_id() == lifecycle_id and entity_instances() == before_instances)
	check("cancel leaves paused typed gameplay and disk exactly unchanged",exact(snapshot()) == before_exact and disk_row() == before_disk)
	if not passed(): finish_failure("cancel_scope"); return
	var tick_before: int = battle._run_clock._next_tick
	if not press(battle.hud._pause_resume_button,"Resume after canceled prompt"): finish_failure("cancel_resume"); return
	var deadline: int = Time.get_ticks_msec() + 30000
	while battle._run_clock._next_tick < tick_before + 120 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	observations["cancel_running_interval"] = {"before_tick":str(tick_before),"after_tick":str(battle._run_clock._next_tick),"world_instance_id":str(battle.get_instance_id()),"paused":get_tree().paused}
	check("Cancel permits ordinary resumed simulation rather than freezing time",not get_tree().paused and battle._run_clock._next_tick >= tick_before + 120 and battle.phase == battle.Phase.FIGHT and battle.get_instance_id() == battle_id and battle._save_barrier.state == battle._save_barrier.State.IDLE)
	check("running after Cancel does not save or allocate another lifecycle",disk_row() == before_disk and battle._continue_receipt.get_instance_id() == lifecycle_id)
	if not passed() or not await pause_world(): finish_failure("cancel_clock"); return
	if not press(named(battle.hud,"SaveAndExit"),"second actual overwrite prompt"): finish_failure("retry_prompt"); return
	check("second Confirm preserves original CAS",flow.phase == flow.Phase.CONFIRM and flow._expected == {"revision":int(original.generation),"file_sha256":original.file_sha256} and flow._session == null)
	if not passed(): finish_failure("retry_prompt_scope"); return
	var owner_path: String = String(original.slot_directory).path_join("writing/owner.json")
	if not await gate("arm_owner_release",{"slot_directory":original.slot_directory,"owner_path":owner_path,"expected_revision":int(original.generation),"expected_sha256":original.file_sha256}): finish_failure("owner_arm"); return
	if not arm_capture(): finish_failure("retry_capture_observer"); return
	received = false
	if not press(named(flow,"ConfirmSave"),"actual ConfirmSave with native fault"): finish_failure("confirm_button"); return
	if not await wait_operation() or not failure_is_owned(): finish_failure("first_lock_release"); return
	retain_pending()
	observations["first_failure"] = pending_observation()
	if not same_pending(): finish_failure("first_pending_scope"); return
	var held_first: Dictionary = snapshot(true)
	var held_exact: Variant = exact(held_first)
	var held_clock: Variant = exact(battle._run_clock.capture().get("record",{}))
	for index in range(3): await get_tree().process_frame
	check("error modal keeps actual HELD world and clock",exact(snapshot(true)) == held_exact and exact(battle._run_clock.capture().get("record",{})) == held_clock and same_pending())
	if not passed(): finish_failure("held_error"); return
	if not await gate("arm_retry_release",{"owner_path":owner_path,"expected_code":"LOCK_RELEASE","expected_revision":retained_pending.expected_revision,"expected_sha256":retained_pending.expected_sha256}): finish_failure("retry_owner_arm"); return
	if not same_pending(): finish_failure("retry_rearmed_pending_scope"); return
	received = false
	if not press(named(flow,"RetrySave"),"actual RetrySave while native owner fault remains"): finish_failure("first_retry_button"); return
	if not await wait_operation() or not failure_is_owned() or not same_pending(): finish_failure("blocked_retry"); return
	observations["blocked_retry"] = pending_observation()
	check("blocked retry does not recapture or advance gameplay",capture_count == 1 and exact(snapshot(true)) == held_exact and exact(battle._run_clock.capture().get("record",{})) == held_clock)
	if not passed(): finish_failure("blocked_retry_scope"); return
	if not await gate("release_retry_handles",{"owner_path":owner_path,"expected_code":"LOCK_RELEASE"}): finish_failure("owner_release"); return
	if not same_pending(): finish_failure("released_pending_scope"); return
	want_exit = true; received = false
	if not press(named(flow,"RetrySave"),"actual RetrySave after host releases original handle"): finish_failure("final_retry_button"); return
	if not await wait_operation() or not result.get("ok",false): finish_failure("final_retry_failed"); return
	while not finished: await get_tree().process_frame

func failure_is_owned() -> bool:
	return check("native LOCK_RELEASE has retryable retained save and visible RetrySave",not result.get("ok",true) and result.get("code") == "LOCK_RELEASE" and result.get("pending_save",false) and result.get("battle_held",false) and result.get("retryable",false) and not result.get("unsafe",true) and not result.get("restart_required",true) and flow.phase == flow.Phase.ERROR and flow._source == battle and flow._session != null and flow._session.has_pending_save() and is_instance_valid(named(flow,"RetrySave")))

func retain_pending() -> void:
	pending_session = flow._session
	pending_store = pending_session._store
	pending_ref = pending_store._pending_write
	proposal_ref = pending_ref.proposal
	record_ref = proposal_ref.record
	retained_pending = pending_observation()

func pending_observation() -> Dictionary:
	var session: RefCounted = flow._session
	var store: RefCounted = session._store
	var pending: Dictionary = store._pending_write
	var proposal_raw: String = JSON.stringify(pending.proposal)
	var clock: Dictionary = battle._run_clock.capture()
	var owner_path: String = String(store.directory).path_join("writing/owner.json")
	return {"session_instance_id":str(session.get_instance_id()),"store_instance_id":str(store.get_instance_id()),"battle_instance_id":str(battle.get_instance_id()),"directory":store.directory,"session_phase":session._phase,"owner_path":owner_path,"owner_raw":store._lock_raw,"owner_sha256":FileAccess.get_sha256(owner_path),"locked":store._locked,"lock_created":store._lock_created,"expected_revision":pending.revision,"expected_sha256":pending.file_sha256,"proposal_json_sha256":proposal_raw.sha256_text(),"proposal_json_bytes":proposal_raw.to_utf8_buffer().size(),"proposal_record_sha256":pending.proposal.sha256,"proposal_record_generation":pending.proposal.record.generation,"proposal_record_hash_matches":JSON.stringify(pending.proposal.record).sha256_text() == pending.proposal.sha256,"clock_ok":clock.get("ok",false),"exact_clock":exact(clock.get("record",{})),"exact_session_clock":exact(session._save_clock),"exact_lease":exact(session._save_lease),"barrier_held":battle._save_barrier.state == battle._save_barrier.State.HELD,"barrier_health":battle._save_barrier.health(),"tree_paused":get_tree().paused,"slot_inventory":store.inventory(),"classic_lifecycle":lifecycle_row(previous_disk().binding)}

func same_pending() -> bool:
	if not check("same Flow Session Store and original proposal references",flow._session == pending_session and pending_session._store == pending_store and is_same(pending_ref,pending_store._pending_write) and is_same(proposal_ref,pending_store._pending_write.proposal) and is_same(record_ref,pending_store._pending_write.proposal.record)): return false
	var observed: Dictionary = pending_observation()
	check("original CAS proposal clock lease inventory and owner retained",observed == retained_pending and observed.expected_revision == 1 and observed.expected_sha256 == previous.checkpoint.file_sha256 and observed.proposal_record_generation == 2 and observed.proposal_record_hash_matches and observed.clock_ok and observed.exact_clock == observed.exact_session_clock and observed.barrier_held and observed.barrier_health.ok and observed.tree_paused and observed.locked)
	return passed()

func no_world() -> bool:
	return get_tree().root.get_children().all(func(node: Node) -> bool: return node.get_script() != BattleScript)

func record_names(directory: String) -> Array:
	var folder := DirAccess.open(directory)
	if folder == null: return []
	var rows: Array = []
	for name: String in folder.get_files(): rows.append(name)
	for name: String in folder.get_directories(): rows.append(name + "/")
	rows.sort()
	return rows

func reject_run() -> void:
	if not load_previous("retry_save"): finish_failure("previous_retry"); return
	var original: Dictionary = previous_disk()
	var before: Dictionary = disk_row()
	if not check("third process starts from exact gen2 disk metadata",not original.is_empty() and before == original and before.generation == 2): finish_failure("gen2_disk"); return
	var menu_id: int = menu.get_instance_id()
	var names_before: Array = record_names(before.slot_directory)
	if not await gate("arm_record_read",{"slot_directory":before.slot_directory,"record_path":before.record_path,"record_sha256":before.file_sha256}): finish_failure("read_arm"); return
	received = false
	if not press(named(menu,"ContinueBattle"),"actual Continue with native record read denied"): finish_failure("rejected_continue_button"); return
	if not await wait_operation(): finish_failure("read_timeout"); return
	check("actual file denial surfaced from native Slot read",not result.get("ok",true) and result.get("code") == "READ_OPEN" and not result.get("battle_held",false) and not result.get("pending_save",false),result)
	check("failed Continue retains exact menu without a Battle or Session",get_tree().current_scene == menu and menu.get_instance_id() == menu_id and no_world() and flow._session == null and flow.phase == flow.Phase.ERROR and not get_tree().paused)
	check("read failure leaves directory set and readable lifecycle unchanged",record_names(before.slot_directory) == names_before and lifecycle_row(before.binding) == before.lifecycle)
	observations["continue_read_refusal"] = result.duplicate(true)
	if not passed() or not press(named(flow,"CloseError"),"actual CloseError after native read failure"): finish_failure("close_error_button"); return
	check("CloseError returns same usable menu without new world",flow.phase == flow.Phase.IDLE and flow._session == null and flow._source == null and flow._overlay == null and no_world() and get_tree().current_scene == menu and menu.get_instance_id() == menu_id and not named(menu,"ContinueBattle").disabled)
	if not passed(): finish_failure("close_error_scope"); return
	if not await gate("release_record_read",{"record_path":before.record_path,"expected_code":"READ_OPEN"}): finish_failure("read_release"); return
	check("repaired native access reveals original bytes unchanged",disk_row() == before)
	if not passed() or not await continue_from_menu() or not verify_restored(previous.checkpoint): finish_failure("retry_continue"); return
	checkpoint = disk_row()
	observations["final_disk"] = checkpoint.duplicate(true)
	checkpoint["exact_disk"] = exact(checkpoint.duplicate(true))
	checkpoint["snapshot"] = snapshot()
	checkpoint["exact_snapshot"] = exact(checkpoint.snapshot)
	check("continued gen2 has no extra save or terminal lifecycle",observations.final_disk == original and checkpoint.exact_snapshot == previous.checkpoint.exact_snapshot and checkpoint.exact_disk == previous.checkpoint.exact_disk and battle._save_barrier.state == battle._save_barrier.State.IDLE and battle._continue_receipt.token == before.binding.token)
	finish_verified()
