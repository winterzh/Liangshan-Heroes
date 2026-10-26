extends "terminal.gd"
## Dual-role ordinary rescue. Only actual UI/Flow owns pause, save and restore.
const Route := preload("route.gd")
var terminal_signals: Array = []

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	mode = OS.get_environment("DF_MODE")
	first_role = OS.get_environment("DF_FIRST_ROLE")
	var profile: String = OS.get_environment("DF_PROFILE").replace("\\", "/").simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and mode in MODES and first_role in ["lu", "shi"] \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty() \
		and OS.get_environment("LSH_CONTINUE_FLOW_QA") == "1" \
		and OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").simplify_path() == profile
	for key: String in ["DF_NONCE", "DF_ROLE_NONCE", "DF_PROCESS_NONCE"]:
		safe = safe and Intent.hex(OS.get_environment(key), 32)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/") \
		and project.to_lower() == OS.get_environment("DF_PROJECT").replace("\\", "/").to_lower()
	if not safe: push_error("DAMING_FLOW_PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	check(DisplayServer.get_name() != "headless", "actual GL display is active")
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", false), "actual source runtime identity"): finish(); return
	if not check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3" \
		and Intent.SCHEMA == "campaign_progress_intent_v2" and Intent.CONTRACTS.level8.version == 2 \
		and Intent.CONTRACTS.level8.ids == GOALS, "current LC3/Intent2/Level8 contract2 exact three-goal protocol"): finish(); return
	var prepared: Dictionary = Factory.prepare_runtime(trusted)
	if not check(prepared.get("ok", false) and not prepared.get("deploy_or_start_called", true), "actual Level8 factory prepares without deployment"): finish(); return
	runtime = prepared.runtime
	if not await wait_for_startup(): finish(); return
	flow = get_node("/root/ContinueFlow")
	if not check(flow.is_enabled() and flow._private_qa_enabled(), "actual private Flow UI entry enabled without public campaign release"): finish(); return
	flow.operation_finished.connect(on_flow_operation)
	get_node("/root/Localize").set_language("zh_CN", false)
	# Ordinary user settings only; no simulation rate override or world assignment.
	var settings: Node = get_node("/root/Settings")
	settings.game_speed = 1.0; settings.auto_micro_level = 0; settings.edge_scroll = false
	route = Route.new()
	var configured: Dictionary = route.configure(self, first_role)
	if not check(configured.get("ok", false), "ordinary route binds exact first role", configured): finish(); return
	if mode == "save_single":
		await start_from_menu()
		if failures.is_empty():
			opening["baseline"] = {"cfg":cfg_snapshot(), "rewards":rewards_snapshot(), "unlocked":get_node("/root/Campaign").unlocked}
			await play_first_and_save()
	elif read_predecessor():
		if mode == "reject_terminal": await reject_terminal()
		elif await restore_same_slot():
			check(cfg_snapshot() == opening.baseline.cfg and rewards_snapshot() == opening.baseline.rewards,
				"independent active Continue does not settle progress or rewards")
			if failures.is_empty():
				if mode == "resume_settle_save": await settle_and_resave()
				else: await finish_second()
	if save_exit_owned: return
	finish()

func resume_play(label: String) -> bool:
	if not check(get_tree().paused and battle.hud._pause_root.visible and healthy(), "actual restored pause is ready before Resume"): return false
	if not press_button(battle.hud._pause_resume_button, label): return false
	return check(not get_tree().paused and not battle.hud._pause_root.visible \
		and battle._save_barrier.state == battle._save_barrier.State.IDLE, "normal Resume releases paused world with idle save barrier")

func play_first_and_save() -> void:
	if not await route.natural_rescue(battle): return
	if not await route.first_exit(battle): return
	if not check_single_safe("natural first exit"): return
	observations["natural_single_safe"] = route.observe(battle)
	await save_same_slot(1)

func settle_and_resave() -> void:
	if not check(int(checkpoint.generation) == 1 and route.commands.is_empty(), "B independently restores original generation1 with no route orders"): return
	if not check_single_safe("before ordinary settle"): return
	var before: Dictionary = safe_effects()
	var start_tick: int = battle._run_clock._next_tick
	var start_elapsed: float = battle.mission.elapsed
	if not resume_play("resume actual single-safe world for ordinary 120 ticks"): return
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and battle._run_clock._next_tick - start_tick < 120:
		await get_tree().process_frame
		if not healthy(): break
	var actual_ticks: int = battle._run_clock._next_tick - start_tick
	check(healthy() and actual_ticks >= 120 and not get_tree().paused and route.commands.is_empty(),
		"B observes at least 120 ordinary ticks without gameplay orders", {"ticks":actual_ticks})
	check(absf((battle.mission.elapsed - start_elapsed) - float(actual_ticks) / 60.0) < 0.0001,
		"Mission elapsed advances by actual ordinary simulation ticks")
	check(safe_effects() == before, "safe actor identity visibility stopped state and report/action counts do not replay")
	if not check_single_safe("after ordinary settle"): return
	observations["safe_no_replay"] = {"ticks":actual_ticks, "before":before, "after":safe_effects()}
	await save_same_slot(2)

func on_terminal(value: Dictionary) -> void:
	terminal_signals.append(value.duplicate(true))

func finish_second() -> void:
	if not check(int(checkpoint.generation) == 2 and route.commands.is_empty(), "C independently restores original generation2 with no route orders"): return
	if not check_single_safe("before second escort"): return
	var original_receipt: Variant = battle._continue_receipt
	var metrics_before: Array = battle.mission.stage_metrics.duplicate(true)
	if not check(flow.phase == flow.Phase.IDLE, "no earlier pending terminal operation before ordinary escort"): return
	flow.operation_finished.connect(on_terminal)
	if not await route.finish_other_naturally(battle): return
	if not await await_terminal(): return
	if not check(battle.mission._result_frozen, "production froze the actual result before QA reads it"): return
	var result: Dictionary = battle.mission._result_cache.duplicate(true)
	check(battle.mission.has_event("daming_lu_safe") and battle.mission.has_event("daming_shi_safe") \
		and battle.mission.has_event("daming_victory") and battle.level.lu.story_outcome == "retreated" \
		and battle.level.shi.story_outcome == "retreated" and battle.level.hall.hp > 0.0,
		"both original prisoners exit naturally while original camp remains alive")
	check(battle.mission.report.count(safe_text(battle.level.lu)) == 1 \
		and battle.mission.report.count(safe_text(battle.level.shi)) == 1 \
		and battle.mission.report.count("两名获救者生还，梁山前营守住") == 1,
		"natural safe and victory reports appear once each")
	check(terminal_signals.size() == 1 and terminal_signals[0].get("ok", false) \
		and terminal_signals[0].get("terminal_completed", false) and terminal_signals[0].get("local_terminal", false),
		"exactly one real asynchronous terminal operation notification", terminal_signals)
	check(result.get("core_goal") == battle.level.campaign_core_goal(), "full frozen result retains exact authored Daming core goal")
	observations["natural_terminal"] = true
	observations["natural_terminal_state"] = route.observe(battle)
	observations["terminal_signals"] = terminal_signals.duplicate(true)
	if not failures.is_empty(): return
	if not verify_terminal(original_receipt, result, metrics_before): return
	check(terminal_signals.size() == 1, "settled frames add no terminal notification")
	stage_completed = failures.is_empty()
