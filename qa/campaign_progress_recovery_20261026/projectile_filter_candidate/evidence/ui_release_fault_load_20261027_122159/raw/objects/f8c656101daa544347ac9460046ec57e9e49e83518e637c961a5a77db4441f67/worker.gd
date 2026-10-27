extends "base.gd"
## Two native processes. A permanent clock fault is deliberately injected only
## at a healthy production HELD boundary; it is never repaired or naturalized.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	mode = OS.get_environment("URF_MODE")
	output = OS.get_environment("URF_OUTPUT")
	flow = get_node("/root/ContinueFlow")
	run.call_deferred()

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check("strict isolated source-private fault-model scope",profile_valid() and mode in MODES): finish_failure("profile_refused"); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("actual installed source and engine identity",trusted.get("ok",false) and trusted.get("source_mode",false) and trusted.get("content_version") == OS.get_environment("URF_CONTENT") and trusted.get("engine_binary_sha256") == OS.get_environment("URF_ENGINE")): finish_failure("identity_refused"); return
	if not check("native GL ordinary 1x 60Hz",DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60 and get_node("/root/Settings").game_speed == 1.0): finish_failure("simulation_refused"); return
	AudioServer.set_bus_mute(0,true)
	Localize.set_language("zh_CN",false)
	var deadline: int = Time.get_ticks_msec() + 90000
	while not flow.can_launch() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not check("ordinary startup completes before any model fault",flow.can_launch() and flow.last_result.get("startup_checked",false) and flow.is_enabled() and not get_node("/root/SteamService").available): finish_failure("startup_refused"); return
	observations["startup"] = {"result":flow.last_result.duplicate(true),"phase":int(flow.phase),"startup_scanned":flow._startup_scanned,"session_absent":flow._session == null}
	observations["diagnostic_before"] = file_row("user://continue_error.json")
	menu = MenuScene.instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	flow.operation_finished.connect(on_operation)
	if mode == "fault_exit": await fault_exit_run()
	else: await restart_run()

func fault_exit_run() -> void:
	var business: Dictionary = business_row()
	var progress: Dictionary = progress_row()
	var slot_probe: Dictionary = Slot.new(SLOT_ROOT).inspect_slot()
	checkpoint = {"business":business,"exact_business":exact(business),"progress":progress,"exact_progress":exact(progress),"slot_probe":slot_probe}
	if not check("fresh profile proves no Slot LC CFG journal candidate or reward ledger",business["continue"].kind == "absent" and not business.cfg.exists and business.cfg_journal.kind == "absent" and business.cfg_candidates.kind == "absent" and business.steam_receipts.kind == "absent" and slot_probe == {"ok":true,"exists":false,"revision":0,"file_sha256":Slot.ZERO}): finish_failure("existing_business"); return
	if not press(text_button(menu,Localize.text("🛡  驻守战"),true),"defense menu"): finish_failure("defense_button"); return
	await get_tree().process_frame
	if not check("ordinary classic menu options",not Campaign.ai_friendly and not Campaign.scale_on): finish_failure("menu_options"); return
	if not press(text_button(menu,Localize.text("🛡  30 关 · 经典（推荐）")),"classic 30 menu"): finish_failure("classic_button"); return
	var deadline: int = Time.get_ticks_msec() + 90000
	while (get_tree().current_scene == null or get_tree().current_scene.get_script() != BattleScript) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	battle = get_tree().current_scene
	if not check("actual menu starts the original classic world",is_instance_valid(battle) and battle.get_script() == BattleScript and battle.level.get_script() == Classic and battle._official_context == Slot.CONTEXT and battle._continue_receipt == null and battle._steam_run_id == 0): finish_failure("menu_world"); return
	check("ordinary starting economy is not injected",battle.gold == 250 and battle.wood == 150 and battle.pop_cap == 20)
	deadline = Time.get_ticks_msec() + 30000
	while battle.hud._intro_root.visible and Time.get_ticks_msec() < deadline:
		if not press(battle.hud._intro_btn,"normal intro"): finish_failure("intro"); return
		await get_tree().process_frame
	if not check("normal intro completes",not battle.hud._intro_root.visible): finish_failure("intro_timeout"); return
	var first_tick: int = battle._run_clock._next_tick
	deadline = Time.get_ticks_msec() + 30000
	while battle._run_clock._next_tick < first_tick + 120 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not check("ordinary FIGHT advances at least 120 complete ticks before injection",battle.phase == battle.Phase.FIGHT and not get_tree().paused and battle._run_clock._next_tick >= first_tick + 120 and battle._run_clock.fault().is_empty()): finish_failure("initial_clock"); return
	observations["ordinary_run"] = {"first_tick":str(first_tick),"last_tick":str(battle._run_clock._next_tick),"fault":battle._run_clock.fault()}
	if not await pause_world() or not unchanged_business("ordinary play before capture") or not passed(): finish_failure("initial_pause"); return
	if not arm_fault(): finish_failure("observer_registration"); return
	received = false
	if not press(named(battle.hud,"SaveAndExit"),"actual first SaveAndExit"): finish_failure("save_button"); return
	# Same stack, no await: request_capture has only set REQUESTED; its two
	# process-frame boundaries have not emitted capture_ready yet.
	if not observe_registration(): finish_failure("request_sequence"); return
	if not await wait_operation(): finish_failure("save_no_result"); return
	if not check("actual capture failure cannot commit or safely release",operations.size() == 1 and not result.get("ok",true) and result.get("code") == FAULT and result.get("original_error") == FAULT and result.get("battle_held",false) and not result.get("pending_save",false) and not result.get("terminal_pending",false) and flow.phase == flow.Phase.ERROR and flow._session == null and flow.last_result == result and battle._continue_receipt == null): finish_failure("wrong_capture_failure"); return
	if not same_held("original failed save") or not unchanged_business("failed capture") or not passed(): finish_failure("failed_capture_changed_state"); return
	observations["first_failure"] = {"result":flow.last_result.duplicate(true),"scope":held_scope(),"operation_count":operations.size(),"session_absent":flow._session == null,"slot_probe":Slot.new(SLOT_ROOT).inspect_slot()}
	var before_retry: Dictionary = flow.last_result.duplicate(true)
	if not press(named(flow,"RetryRelease"),"actual RetryRelease of permanent fault"): finish_failure("retry_button"); return
	var expected_retry: Dictionary = before_retry.duplicate(true)
	expected_retry["release_error"] = FAULT
	if not check("RetryRelease reports the same permanent fault without new operation",flow.phase == flow.Phase.ERROR and flow.last_result == expected_retry and operations.size() == 1 and named(flow,"RetryRelease") != null and named(flow,"LeaveHeldBattle") != null): finish_failure("retry_release_result"); return
	if not same_held("failed RetryRelease") or not unchanged_business("failed RetryRelease") or not passed(): finish_failure("retry_changed_state"); return
	observations["retry_release"] = {"result":flow.last_result.duplicate(true),"scope":held_scope(),"operation_count":operations.size(),"fault_calls":fault_call_count}
	# The real ERROR Escape path refuses dismissal of a held Battle.
	escape_viewport()
	await get_tree().process_frame
	if not check("actual Escape cannot dismiss the permanently held failure",flow.phase == flow.Phase.ERROR and named(flow,"RetryRelease") != null and get_tree().paused and operations.size() == 1): finish_failure("escape_dismissed_error"); return
	if not same_held("held error after Escape"): finish_failure("escape_changed_state"); return
	if not press(named(flow,"LeaveHeldBattle"),"actual LeaveHeldBattle confirmation"): finish_failure("leave_button"); return
	if not check("failed exit confirmation focuses real CancelSave",flow.phase == flow.Phase.EXIT_CONFIRM and get_viewport().gui_get_focus_owner() == named(flow,"CancelSave") and not get_node("/root/AppLifecycle").quit_started()): finish_failure("leave_confirmation"); return
	var confirm_frame: String = str(Engine.get_process_frames())
	if not same_held("exit confirmation"): finish_failure("confirmation_changed_state"); return
	if not press(named(flow,"CancelSave"),"cancel actual failed-exit confirmation"): finish_failure("cancel_button"); return
	if not check("cancel remains on original held error in same synchronous frame",flow.phase == flow.Phase.ERROR and str(Engine.get_process_frames()) == confirm_frame and not get_node("/root/AppLifecycle").quit_started() and operations.size() == 1): finish_failure("cancel_failed"); return
	if not same_held("cancelled exit") or not unchanged_business("cancelled exit") or not passed(): finish_failure("cancel_changed_state"); return
	observations["leave_cancel"] = {"frame":confirm_frame,"phase":int(flow.phase),"scope":held_scope(),"result":flow.last_result.duplicate(true),"operation_count":operations.size(),"quit_started":false}
	if not press(named(flow,"LeaveHeldBattle"),"reopen actual failed-exit confirmation"): finish_failure("second_leave_button"); return
	if not check("second confirmation remains on same held model",flow.phase == flow.Phase.EXIT_CONFIRM and same_held("second exit confirmation")): finish_failure("second_confirmation"); return
	if not unchanged_business("before production failed-exit confirmation") or not passed(): finish_failure("before_exit_changed_business"); return
	if not press(named(flow,"ConfirmSave"),"confirm actual failed Battle exit"): finish_failure("confirm_exit_button"); return
	var app: Node = get_node("/root/AppLifecycle")
	release_exit_observed = app.quit_started() and app.quit_reason() == "continue_failed" and flow.phase == flow.Phase.EXITING
	check("production AppLifecycle owns continue_failed exit",release_exit_observed and operations.size() == 1 and fault_call_count == 1 and capture_count == 1)
	observations["production_exit"] = {"quit_started":app.quit_started(),"quit_reason":app.quit_reason(),"phase":int(flow.phase),"scope":held_scope(),"operation_count":operations.size(),"slot_probe":Slot.new(SLOT_ROOT).inspect_slot()}
	observations["diagnostic_after"] = file_row("user://continue_error.json")
	check("failed-save diagnostic is separate from business state",observations.diagnostic_after.exists and read_json("user://continue_error.json").get("code","") == FAULT)
	unchanged_business("production-owned quit")
	finished = true; exit_reason = "continue_failed"
	# Do not quit or await here: production owns its original three-frame exit.
	report()

func restart_run() -> void:
	if not load_previous() or not passed(): finish_failure("previous_fault_process"); return
	if not check("independent startup does not replay a failed save",flow.phase == flow.Phase.IDLE and flow._session == null and flow._campaign_terminal == null and operations.is_empty() and no_world() and fault_call_count == 0 and capture_count == 0 and not get_node("/root/AppLifecycle").quit_started()): finish_failure("restart_state"); return
	if not unchanged_business("independent startup") or not passed(): finish_failure("restart_changed_business"); return
	var probe: Dictionary = Slot.new(SLOT_ROOT).inspect_slot()
	if not check("independent native slot probe remains truly empty",probe == {"ok":true,"exists":false,"revision":0,"file_sha256":Slot.ZERO}): finish_failure("unexpected_slot"); return
	received = false
	if not press(named(menu,"ContinueBattle"),"actual menu Continue after failed capture"): finish_failure("continue_button"); return
	if not await wait_operation(): finish_failure("continue_no_result"); return
	if not check("actual Continue refuses NO_SLOT without a world or retained Session",operations.size() == 1 and not result.get("ok",true) and result.get("code") == "NO_SLOT" and not result.get("battle_held",false) and flow.phase == flow.Phase.ERROR and flow._session == null and no_world()): finish_failure("wrong_continue_rejection"); return
	observations["restart_no_slot"] = {"result":result.duplicate(true),"phase":int(flow.phase),"slot_probe":probe,"no_world":no_world(),"session_absent":flow._session == null,"operation_count":operations.size()}
	if not press(named(flow,"CloseError"),"actual CloseError returns to same menu"): finish_failure("close_error_button"); return
	if not check("CloseError preserves original menu without save replay",flow.phase == flow.Phase.IDLE and not flow.busy() and flow._session == null and flow._source == null and no_world() and operations.size() == 1): finish_failure("close_error_failed"); return
	if not unchanged_business("NO_SLOT and CloseError") or not passed(): finish_failure("rejection_changed_business"); return
	observations["restart_after_close"] = {"phase":int(flow.phase),"no_world":no_world(),"operation_count":operations.size(),"business":business_row(),"exact_progress":exact(progress_row())}
	observations["diagnostic_after"] = file_row("user://continue_error.json")
	check("restart diagnostic is NO_SLOT and is not business persistence",observations.diagnostic_after.exists and read_json("user://continue_error.json").get("code","") == "NO_SLOT")
	finish_verified()
