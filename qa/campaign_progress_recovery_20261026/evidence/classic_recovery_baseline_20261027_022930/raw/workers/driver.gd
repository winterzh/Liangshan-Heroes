extends "classic_base.gd"
## Source branch diagnosis only. The initial Button uses the private gate.
## After its synchronous request we clear ONLY that QA flag before _restore.
var stage := ""
var case_kind := ""
var expected_result := ""
var stage_root := ""
var case_nonce := ""
var process_nonce := ""
var actions: Array = []
var observed: Dictionary = {}
var previous: Dictionary = {}
var branch_gate: Dictionary = {}
var capture_observer_calls := 0
var capture_registration: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	stage = OS.get_environment("SC_STAGE")
	case_kind = OS.get_environment("SC_CASE")
	expected_result = OS.get_environment("SC_EXPECT")
	stage_root = OS.get_environment("SC_OUTPUT")
	var output_root: String = OS.get_environment("SC_RUN").replace("\\", "/").trim_suffix("/")
	if not output_root.is_absolute_path() or not stage_root.replace("\\", "/").begins_with(output_root + "/") \
		or ".." in stage_root.replace("\\", "/").split("/"):
		get_tree().quit(2); return
	case_nonce = OS.get_environment("SC_NONCE")
	process_nonce = OS.get_environment("SC_PROCESS_NONCE")
	state = {"fight_origin_tick":0}
	flow = get_node("/root/ContinueFlow")
	policy = Policy.new()
	_boot.call_deferred()

func valid_profile() -> bool:
	var profile: String = OS.get_environment("SC_PROFILE").replace("\\", "/").trim_suffix("/")
	if not profile.is_absolute_path() or not stage_root.is_absolute_path() or not OS.has_feature("editor"): return false
	if ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/") != OS.get_environment("SC_PROJECT").replace("\\", "/").trim_suffix("/"): return false
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): return false
	if OS.get_environment("LSH_CONTINUE_FLOW_QA") != "1" or OS.get_environment("LSH_CONTINUE_FLOW_PROFILE") != OS.get_environment("SC_PROFILE"): return false
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		if OS.get_environment(key).replace("\\", "/") != profile.path_join(key.to_lower()): return false
	return OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/") \
		and LocalLifecycle._hex(case_nonce,32) and LocalLifecycle._hex(process_nonce,32)

func all_passed() -> bool:
	return not checks.is_empty() and checks.all(func(row): return row.passed)

func publish(name: String, value: Dictionary) -> bool:
	var path: String = stage_root.path_join(name)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp"): return false
	return _write(path + ".tmp", value) and DirAccess.rename_absolute(path + ".tmp", path) == OK

func identity_row() -> Dictionary:
	return {"pid":OS.get_process_id(), "nonce":case_nonce,"process_nonce":process_nonce,
		"profile":OS.get_environment("SC_PROFILE"),"identity":Codec.new().encode(trusted).get("value",{}),
		"content_version":trusted.get("content_version",""),"engine_sha256":trusted.get("engine_binary_sha256","")}

func restore_gate_state(menu: Node) -> Dictionary:
	return {"phase":int(flow.phase),"restoring":flow.phase == flow.Phase.RESTORING,
		"source_is_menu":flow._source == menu,"session_absent":flow._session == null,"operation_received":_received}

func _boot() -> void:
	if not _check("explicit private source profile", valid_profile() and stage in ["writer","reader"] \
		and case_kind in ["pending","record"] and expected_result in ["baseline","fixed"]): finish("scope_refused"); return
	trusted = Provider.new().resolve_runtime_identity()
	if not _check("exact generated source and engine", trusted.get("ok",false) and trusted.get("source_mode",false) \
		and trusted.content_version == OS.get_environment("SC_CONTENT") \
		and trusted.engine_binary_sha256 == OS.get_environment("SC_ENGINE")): finish("identity_refused"); return
	if not _check("normal GL 1x60Hz", DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 \
		and Engine.physics_ticks_per_second == 60 and get_node("/root/Settings").game_speed == 1.0): finish("simulation_refused"); return
	AudioServer.set_bus_mute(0,true)
	Localize.set_language("zh_CN",false)
	var limit: int = Time.get_ticks_msec() + 30000
	while not flow.can_launch() and Time.get_ticks_msec() < limit: await get_tree().process_frame
	if not _check("original startup completed",flow.can_launch() and flow.last_result.get("startup_checked",false)): finish("startup_refused"); return
	if not _check("SDK remains unavailable",not get_node("/root/SteamService").available): finish("sdk_refused"); return
	var menu: Node = MenuScene.instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	flow.operation_finished.connect(_operation)
	if stage == "writer": await create_writer(menu)
	else: await recover_reader(menu)

func create_writer(menu: Node) -> void:
	if not _check("fresh original slot",Slot.new().read_slot().get("code") == "NO_SLOT"): finish("slot_present"); return
	if not _press(_text_button(menu,Localize.text("🛡  驻守战"),true),"defense menu"): finish("menu_refused"); return
	await get_tree().process_frame
	if not _press(_text_button(menu,Localize.text("🛡  30 关 · 经典（推荐）")),"classic30 menu"): finish("menu_refused"); return
	var limit: int = Time.get_ticks_msec() + 60000
	while (get_tree().current_scene == null or get_tree().current_scene.get_script() != BattleScript) and Time.get_ticks_msec() < limit:
		await get_tree().process_frame
	battle = get_tree().current_scene
	if not _check("real classic battle",is_instance_valid(battle) and battle.get_script() == BattleScript and battle.level.get_script() == Classic): finish("launch_refused"); return
	_check("ordinary initial economy",battle.gold == 250 and battle.wood == 150 and battle.pop_cap == 20)
	while battle.hud._intro_root.visible:
		if not _press(battle.hud._intro_btn,"advance original intro"): finish("intro_refused"); return
		await get_tree().process_frame
	state.fight_origin_tick = int(battle._run_clock._next_tick)
	limit = Time.get_ticks_msec() + 10000
	while not battle.is_visible_world(battle.level.hall.position) and Time.get_ticks_msec() < limit: await get_tree().process_frame
	if not _check("normal FIGHT and sight",battle.phase == battle.Phase.FIGHT and battle.is_visible_world(battle.level.hall.position)): finish("fight_refused"); return
	policy.initial_orders(battle,0.0)
	actions = policy.take_actions()
	var paid: Array = actions.filter(func(row): return row.kind in ["build","train"])
	_check("ordinary paid build and train",paid.any(func(row): return row.kind == "build") and paid.any(func(row): return row.kind == "train"))
	for action: Dictionary in paid:
		var d: Dictionary = action.detail
		_check("actual command deducted installed cost",float(d.before[0]) - float(d.after[0]) == float(d.definition_cost[0]) \
			and float(d.before[1]) - float(d.after[1]) == float(d.definition_cost[1]),d)
	for attempt in range(3):
		if get_tree().paused and battle.hud._pause_root.visible: break
		var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true
		get_viewport().push_input(key); key = key.duplicate(); key.pressed = false; get_viewport().push_input(key)
		await get_tree().process_frame
	if not _check("real viewport Esc pause",get_tree().paused and battle.hud._pause_root.visible) or not all_passed(): finish("pause_refused"); return
	var request: Dictionary = identity_row()
	request.merge({"schema":"classic_recovery_gate_v1","case":case_kind,"directory":Slot.new().directory})
	if not publish("request.json",request): finish("request_write_failed"); return
	limit = Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(stage_root.path_join("ack.json")) and Time.get_ticks_msec() < limit: await get_tree().process_frame
	var ack: Variant = _read_json(stage_root.path_join("ack.json"))
	if not _check("host armed exact native boundary",typeof(ack) == TYPE_DICTIONARY and ack.get("pid") == OS.get_process_id() \
		and ack.get("nonce") == case_nonce and ack.get("process_nonce") == process_nonce): finish("ack_refused"); return
	# Register first, then observe both callbacks after the synchronous request.
	# Godot may unlink ONE_SHOT callbacks before invoking this observer.
	var prior_flow_absent: bool = not battle._save_barrier.capture_ready.is_connected(Callable(flow,"_capture_ready"))
	battle._save_barrier.capture_ready.connect(capture_witness,CONNECT_ONE_SHOT)
	var before_press := {"frame":str(Engine.get_process_frames()),
		"observer_registered":battle._save_barrier.capture_ready.is_connected(capture_witness),
		"flow_callback_absent":prior_flow_absent,"capture_calls":capture_observer_calls}
	_saving = true
	if not _press(_named(battle.hud,"SaveAndExit"),"original SaveAndExit"): finish("save_refused"); return
	# No await/pump: request_capture only sets REQUESTED and returns. HELD is
	# reached by the original barrier on later process frames.
	capture_registration = observe_capture_registration(before_press)
	if not _check("same-stack original capture registrations before emission",capture_registration_valid()):
		finish("capture_registration_refused"); return
	if flow.phase == flow.Phase.CONFIRM:
		_check("unexpected overwrite refused",false); finish("unexpected_overwrite")

func observe_capture_registration(before: Dictionary) -> Dictionary:
	var rows: Array = []
	for connection: Dictionary in battle._save_barrier.capture_ready.get_connections():
		var callback: Callable = connection.callable
		rows.append({"index":rows.size(),"method":String(callback.get_method()),
			"object_id":str(callback.get_object_id()),"valid":callback.is_valid(),"flags":int(connection.flags),
			"is_flow":callback == Callable(flow,"_capture_ready"),"is_observer":callback == Callable(self,"capture_witness")})
	return {"before_button":before,"frame":str(Engine.get_process_frames()),
		"phase":int(flow.phase),"saving":flow.phase == flow.Phase.SAVING,
		"source_is_battle":flow._source == battle,"session_absent":flow._session == null,
		"barrier_state":int(battle._save_barrier.state),"requested":battle._save_barrier.state == battle._save_barrier.State.REQUESTED,
		"capture_calls":capture_observer_calls,"flow_object_id":str(flow.get_instance_id()),
		"observer_object_id":str(get_instance_id()),"one_shot_flag":int(CONNECT_ONE_SHOT),
		"connection_count":rows.size(),"connections":rows}

func capture_registration_valid() -> bool:
	if capture_registration.is_empty(): return false
	var row: Dictionary = capture_registration
	var prior: Dictionary = row.before_button
	var flow_rows: Array = row.connections.filter(func(item): return item.is_flow)
	var observer_rows: Array = row.connections.filter(func(item): return item.is_observer)
	if not prior.observer_registered or not prior.flow_callback_absent or prior.capture_calls != 0 \
		or row.frame != prior.frame or not row.saving or not row.source_is_battle or not row.session_absent \
		or not row.requested or row.capture_calls != 0 or flow_rows.size() != 1 or observer_rows.size() != 1: return false
	# Keep the returned list/order as evidence; do not assume its order is the
	# signal invocation order. Actual HELD/session absence and host stack prove it.
	return flow_rows[0].valid and observer_rows[0].valid \
		and (int(flow_rows[0].flags) & CONNECT_ONE_SHOT) != 0 \
		and (int(observer_rows[0].flags) & CONNECT_ONE_SHOT) != 0

func capture_witness(_clock: Dictionary) -> void:
	capture_observer_calls += 1
	if battle._save_barrier.capture_ready.is_connected(capture_witness):
		battle._save_barrier.capture_ready.disconnect(capture_witness)
	var order := {"calls":capture_observer_calls,"held":battle._save_barrier.state == battle._save_barrier.State.HELD,
		"outside_physics":not Engine.is_in_physics_frame(),"clock_next":str(battle._run_clock._next_tick),
		"flow_callback_connected":battle._save_barrier.capture_ready.is_connected(Callable(flow,"_capture_ready")),
		"flow_session_absent":flow._session == null,
		"observer_disconnected":not battle._save_barrier.capture_ready.is_connected(capture_witness)}
	_check("one read-only observer precedes original Flow capture",order.calls == 1 and order.held and order.outside_physics \
		and capture_registration_valid() and order.flow_session_absent and order.observer_disconnected)
	var snapshot: Dictionary = _snapshot()
	var encoded: Dictionary = Codec.new().encode(snapshot)
	_check("actual HELD typed world snapshot",encoded.ok and battle._save_barrier.state == battle._save_barrier.State.HELD)
	var value: Dictionary = identity_row()
	value.merge({"schema":"classic_recovery_prepared_v1","case":case_kind,"passed":all_passed(),"checks":checks,
		"exact_snapshot":encoded.get("value",{}),"actions":actions,"slot_directory":Slot.new().directory,
		"capture_registration":capture_registration,"capture_observer":order,
		"initial_private_gate_used":true,"public_entry_qualified":false})
	if not publish("prepared.json",value): push_error("CLASSIC_RECOVERY_PREPARED_WRITE")

func recover_reader(menu: Node) -> void:
	var previous_path: String = OS.get_environment("SC_PREVIOUS")
	if not _check("original producer report hash",FileAccess.get_sha256(previous_path) == OS.get_environment("SC_PREVIOUS_SHA")): finish("producer_refused"); return
	var parsed: Variant = _read_json(previous_path)
	if not _check("same producer profile and different process",typeof(parsed) == TYPE_DICTIONARY and parsed.get("passed",false) \
		and parsed.get("nonce") == case_nonce and parsed.get("profile") == OS.get_environment("SC_PROFILE") \
		and parsed.get("process_nonce") != process_nonce and parsed.get("identity") == identity_row().identity): finish("producer_refused"); return
	previous = parsed
	var slot: RefCounted = Slot.new()
	var before: Dictionary = slot.inventory()
	var candidate: Dictionary = slot._verified("receipt.pending") if case_kind == "pending" else slot._chain()
	if not _check("strict complete original classic packet",candidate.ok and candidate.revision == 1 and candidate.document.context == Slot.CONTEXT \
		and candidate.document.binding.kind == "uncredited" and candidate.file_sha256 == OS.get_environment("SC_SLOT_SHA")): finish("candidate_refused"); return
	var binding: Dictionary = candidate.document.binding
	var lifecycle: RefCounted = LocalLifecycle.new(binding.token,SLOT_ROOT)
	var local_before: Dictionary = lifecycle.inventory()
	var head: Dictionary = lifecycle.open_head()
	_check("original active local lifecycle",head.ok and head.revision == 1 and head.file_sha256 == binding.receipt_sha256 and head.document.state == "active")
	if not all_passed(): finish("lifecycle_refused"); return
	_received = false
	branch_gate = {"before_frame":Engine.get_process_frames(),"initial_private_gate_used":flow._private_qa_enabled()}
	if not _check("actual initial private gate is recorded",branch_gate.initial_private_gate_used): finish("branch_gate_refused"); return
	if not _press(_named(menu,"ContinueBattle"),"actual Continue then source-branch gate diagnostic"): finish("continue_refused"); return
	# request_continue is synchronous and only CONNECT_ONE_SHOT schedules the
	# real _restore on the next process_frame. No await/pump occurs before clear.
	branch_gate.request = restore_gate_state(menu)
	if not _check("accepted request awaits original process_frame",branch_gate.request.restoring and branch_gate.request.source_is_menu \
		and branch_gate.request.session_absent and not branch_gate.request.operation_received \
		and Engine.get_process_frames() == branch_gate.before_frame): finish("branch_timing_refused"); return
	OS.set_environment("LSH_CONTINUE_FLOW_QA","")
	branch_gate.after_frame = Engine.get_process_frames()
	branch_gate.private_gate_after_clear = flow._private_qa_enabled()
	branch_gate.after_clear = restore_gate_state(menu)
	if not _check("only QA gate removed before original callback",not branch_gate.private_gate_after_clear \
		and OS.get_environment("STEAM_DISABLED") == "1" and branch_gate.after_frame == branch_gate.before_frame \
		and branch_gate.after_clear == branch_gate.request): finish("branch_timing_refused"); return
	await _wait_operation()
	if expected_result == "baseline":
		_check("original public-scope branch reproduces preread refusal",_received and not _result.get("ok",false) and _result.get("code") == "RECOVERY_REQUIRED",_result)
		_check("refusal retains menu and no world",get_tree().current_scene == menu \
			and get_tree().root.get_children().all(func(n): return n.get_script() != BattleScript))
		_check("original residue and active lifecycle preserved",slot.inventory() == before and lifecycle.inventory() == local_before)
	else:
		if not _check("candidate branch restores",_received and _result.get("ok",false),_result): finish("restore_refused"); return
		battle = get_tree().current_scene
		if not _check("actual paused restored classic world",battle.get_script() == BattleScript and battle.level.get_script() == Classic \
			and get_tree().paused and battle.hud._pause_root.visible): finish("world_refused"); return
		_saving = false
		var actual: Dictionary = Codec.new().encode(_snapshot())
		_check("exact typed world resource and queue observation preserved",actual.ok and actual.value == previous.exact_snapshot)
		var restored: Dictionary = slot.read_slot()
		_check("same original slot SHA token and local receipt",restored.ok and restored.file_sha256 == candidate.file_sha256 \
			and restored.document == candidate.document and restored.document.binding == binding \
			and battle._continue_receipt != null and battle._continue_receipt.token == binding.token)
		_check("local lifecycle bytes unchanged",lifecycle.inventory() == local_before)
	observed = {"operation":_result,"before_inventory":before,"after_inventory":slot.inventory(),
		"candidate_sha256":candidate.file_sha256,"binding":binding,"local_inventory":local_before}
	finish("baseline_preread_reproduced" if expected_result == "baseline" else "fixed_branch_restored")

func _operation(value: Dictionary) -> void:
	_received = true; _result = value.duplicate(true)
	if stage == "writer":
		_check("writer must stop at host's original production boundary",false,value)
		finish("writer_unexpected_completion")

func finish(outcome: String) -> void:
	if _finished: return
	_finished = true
	_check("SDK-off boundary remains",OS.get_environment("STEAM_DISABLED") == "1" and not get_node("/root/SteamService").available)
	var value: Dictionary = identity_row()
	value.merge({"schema":"classic_recovery_branch_v1","stage":stage,"case":case_kind,"expected":expected_result,
		"passed":all_passed(),"checks":checks,"outcome":outcome,"observed":observed,"gate":branch_gate,
		"initial_private_gate_used":true,"source_restore_branch_only":true,"public_entry_qualified":false,
		"original_release_qualified":false,"sdk_qualified":false,"os_input":false})
	var wrote: bool = publish("report.json",value)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if wrote and all_passed() else 1)
