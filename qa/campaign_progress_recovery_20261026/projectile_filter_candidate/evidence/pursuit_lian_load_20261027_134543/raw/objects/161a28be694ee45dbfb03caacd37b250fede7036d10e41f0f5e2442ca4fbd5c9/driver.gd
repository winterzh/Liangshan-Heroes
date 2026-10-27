extends "terminal.gd"
## No old launcher, clock override, seed, state fixture or direct win/lose call.
const Policy := preload("policy.gd")
var policy: RefCounted
var flagship_observation: Dictionary = {}
var flag_hp_drops := 0

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	mode = OS.get_environment("GVT_MODE")
	var profile: String = OS.get_environment("GVT_PROFILE").replace("\\", "/").simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and mode in MODES and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("LSH_CONTINUE_FLOW_QA") == "1" \
		and OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").simplify_path() == profile \
		and Intent.hex(OS.get_environment("GVT_PROCESS_NONCE"), 32)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/") \
		and project.to_lower() == OS.get_environment("GVT_PROJECT").replace("\\", "/").to_lower()
	if not safe: push_error("GAO_TERMINAL_PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	check(DisplayServer.get_name() != "headless", "actual GL display is active")
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", false), "actual source runtime identity"): finish(); return
	if not check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3" and Intent.CONTRACTS.level5.version == 3,
		"current candidate lifecycle v3 and Level5 contract3 only"): finish(); return
	var prepared: Dictionary = Factory.prepare_runtime(trusted)
	if not check(prepared.get("ok", false) and not prepared.get("deploy_or_start_called", true), "actual Level5 factory prepares without deployment"): finish(); return
	runtime = prepared.runtime
	if not await wait_for_startup(): finish(); return
	flow = get_node("/root/ContinueFlow")
	if not check(flow.is_enabled() and flow._private_qa_enabled(), "actual private Flow UI entry enabled without public campaign release"): finish(); return
	flow.operation_finished.connect(on_flow_operation)
	get_node("/root/Localize").set_language("zh_CN", false)
	var settings: Node = get_node("/root/Settings")
	settings.game_speed = 1.0; settings.auto_micro_level = 0; settings.edge_scroll = false
	if mode == "save_after_wave1":
		await start_from_menu()
		if failures.is_empty():
			opening["baseline"] = {"cfg":cfg_snapshot(), "rewards":rewards_snapshot()}
			opening["wave_observations"] = []
			opening["flagship_entity_id"] = str(battle.level.flagship.entity_id)
			policy = Policy.new(self)
			await play_until_save(false)
	elif read_predecessor():
		if mode == "reject_terminal": await reject_terminal()
		elif await restore_same_slot():
			policy = Policy.new(self)
			policy.restore_counters(opening.policy)
			check(cfg_snapshot() == opening.baseline.cfg and rewards_snapshot() == opening.baseline.rewards,
				"independent active Continue does not settle progress or rewards")
			if failures.is_empty():
				if mode == "resume_core_save": await play_until_save(true)
				else: await finish_restored_core()
	if save_exit_owned: return
	finish()

func alive(unit: Variant) -> bool:
	return is_instance_valid(unit) and unit.hp > 0.0 and unit.story_outcome == ""

func record_action(kind: String, units: Array, detail: Dictionary = {}) -> void:
	var row: Dictionary = {"kind":kind, "tick":battle._run_clock._next_tick, "level_elapsed":battle.level.elapsed,
		"actors":units.filter(func(u): return is_instance_valid(u)).map(func(u): return str(u.entity_id))}
	row.merge(detail, false)
	action_evidence.append(row)

func on_flagship_resolved(unit: Variant, outcome: String) -> void:
	flagship_observation = {"same_original":unit == battle.level.flagship,
		"entity_id":str(unit.entity_id), "outcome":outcome, "hp":unit.hp,
		"tick":battle._run_clock._next_tick, "elapsed":battle.level.elapsed,
		"all_waves_sent":battle.level.waves.all(func(row): return row.sent)}

func observe_waves() -> void:
	for index: int in range(3):
		var row: Dictionary = battle.level.waves[index]
		if not row.sent or opening.wave_observations.any(func(item): return item.index == index): continue
		opening.wave_observations.append({"index":index, "scheduled":row.time, "observed_elapsed":battle.level.elapsed,
			"tick":battle._run_clock._next_tick, "land_alive_at_dispatch":battle.level._count(battle.level.land_groups[index]),
			"water_alive_at_dispatch":battle.level._count(battle.level.water_groups[index])})
		check(battle.level.elapsed >= row.time and battle.level._count(battle.level.land_groups[index]) > 0
			and battle.level._count(battle.level.water_groups[index]) > 0,
			"original wave %d naturally dispatches living land and water forces at its normal timer" % (index+1))

func core_ready() -> bool:
	return battle.level.core_ready and battle.level.flagship_disabled and battle.level._core_threats_clear() 		and is_instance_valid(battle.level.end_button) and battle.phase == B.Phase.FIGHT

func first_wave_clear() -> bool:
	return battle.level.waves[0].sent and battle.level._count(battle.level.land_groups[0]) == 0 		and battle.level._count(battle.level.water_groups[0]) == 0

func play_until_save(to_core: bool) -> void:
	var level: Variant = battle.level
	var hall: Variant = level.hall
	var song: Variant = level.song
	if not check(alive(hall) and alive(song) and str(hall.entity_id) == opening.hall_entity_id
		and str(song.entity_id) == opening.song_entity_id, "strategy uses original living camp and commander"): return
	if get_tree().paused:
		if not press_button(battle.hud._pause_resume_button, "resume actual battle for remaining Gao expeditions"): return
	if not song.garrisoned:
		policy.garrison(battle, [song], hall)
		var garrison_limit: int = Time.get_ticks_msec() + 30000
		while healthy() and not song.garrisoned and failures.is_empty() and Time.get_ticks_msec() < garrison_limit:
			await get_tree().process_frame
	if not check(song.garrisoned and song.garrison_holder == hall and hall.passengers.has(song),
		"ordinary command-card garrison places original Song inside original hall"): return
	if to_core:
		if not check(str(level.flagship.entity_id) == opening.flagship_entity_id and not level.flagship_disabled,
			"independent resume retains original unresolved flagship before third expedition"): return
		level.flagship.story_resolved.connect(on_flagship_resolved, CONNECT_ONE_SHOT)
	var wall_limit: int = Time.get_ticks_msec() + (1100000 if to_core else 420000)
	var elapsed_limit: float = 1200.0 if to_core else 320.0
	var next_order: float = level.elapsed
	var next_log: float = level.elapsed
	var previous_hp: float = level.flagship.hp
	while healthy() and failures.is_empty() and Time.get_ticks_msec() < wall_limit and level.elapsed < elapsed_limit:
		observe_waves()
		if level.flagship.hp < previous_hp: flag_hp_drops += 1
		previous_hp = level.flagship.hp
		if (core_ready() if to_core else first_wave_clear()): break
		if level.elapsed >= next_order:
			next_order = level.elapsed + 1.5
			policy.economy(battle)
			policy.fight(battle)
		if level.elapsed >= next_log:
			next_log = level.elapsed + 30.0
			var sample: Dictionary = {"elapsed":level.elapsed, "waves":level.waves.duplicate(true),
				"land_remaining":level.land_groups.map(func(g): return level._count(g)),
				"water_remaining":level.water_groups.map(func(g): return level._count(g)),
				"flagship_hp":level.flagship.hp, "flagship_outcome":level.flagship.story_outcome,
				"gold":battle.gold, "wood":battle.wood, "population":battle.population_summary(), "hall_hp":hall.hp}
			observations.get_or_add("battle_samples", []).append(sample)
			print("GAO_CORE_PROGRESS ", JSON.stringify(sample))
		await get_tree().process_frame
	observe_waves()
	if to_core and level.flagship.story_resolved.is_connected(on_flagship_resolved):
		level.flagship.story_resolved.disconnect(on_flagship_resolved)
	check(healthy() and alive(hall) and alive(song) and level.hall == hall and level.song == song
		and song.garrisoned and song.garrison_holder == hall, "natural strategy retains original hall and protected commander at 1x/60Hz")
	if to_core:
		check(core_ready() and level.waves.all(func(row): return row.sent) and opening.wave_observations.size() == 3,
			"all three normal expeditions end in actual core readiness before the bounded deadline")
		check(flagship_observation.get("same_original", false) and flagship_observation.get("entity_id") == opening.flagship_entity_id
			and flagship_observation.get("outcome") == "subdued" and flagship_observation.get("all_waves_sent", false)
			and flag_hp_drops > 0 and level.flagship.story_outcome == "subdued", "real combat damages and subdues the original flagship after natural third dispatch")
		opening["flagship_resolution"] = flagship_observation.duplicate(true)
		opening["flagship_hp_drop_observations"] = flag_hp_drops
		check(not battle.mission.has_event("gao_basic_victory") and not battle.mission._result_frozen,
			"core-ready save stops before the authored end button or any terminal settlement")
	else:
		check(first_wave_clear() and not level.waves[1].sent and not level.waves[2].sent and not level.core_ready,
			"first natural expedition clears before the second dispatch, without ending the chapter")
	opening["policy"] = policy.snapshot()
	observations["strategy"] = policy.snapshot()
	check(policy.buildings_started >= 1 and policy.units_queued_by_key.get("liangshan_warship",0) >= 1,
		"ordinary strategy constructed its paid economy and queued real warships")
	if not failures.is_empty(): return
	await save_same_slot(2 if to_core else 1)

func finish_restored_core() -> void:
	var level: Variant = battle.level
	if not check(checkpoint.generation == 2 and core_ready() and level.waves.all(func(row): return row.sent)
		and level.flagship.story_outcome == "subdued" and str(level.flagship.entity_id) == opening.flagship_entity_id,
		"third process restores original completed core, all dispatched waves and subdued flagship"): return
	var button: Variant = level.end_button
	var entries: Array = battle.mission._buttons.get_children().filter(func(node): return node is Button and node.get_meta(battle.mission.PRESENTATION_META, {}).get("kind", "") == "level" and node.get_meta(battle.mission.PRESENTATION_META, {}).get("button_id", "") == "gao_end")
	var connections: Array = button.pressed.get_connections()
	var original_callbacks: Array = connections.filter(func(row): return row.callable.get_object() == battle.mission and row.callable.get_method() == "_activate_level_button" and row.callable.get_bound_arguments() == ["gao_end"])
	if not check(entries == [button] and button.get_parent() == battle.mission._buttons and original_callbacks.size() == 1
		and not button.disabled, "exact one rebuilt Mission-owned gao_end retains original installed dispatch binding"): return
	observations["restored_end_button"] = {"same_level_mission_node":entries == [button], "original_callback_count":original_callbacks.size(),
		"presentation":button.get_meta(battle.mission.PRESENTATION_META).duplicate(true), "instance_id":str(button.get_instance_id()), "process_id":OS.get_process_id()}
	var receipt: Variant = battle._continue_receipt
	var metrics_before: Array = battle.mission.stage_metrics.duplicate(true)
	if not press_button(battle.hud._pause_resume_button, "resume restored core-ready battle"): return
	await get_tree().process_frame
	if not battle.mission._expanded:
		if not press_button(battle.mission._toggle, "expand actual mission panel"): return
		await get_tree().process_frame
	if not await reveal_button(button) or not press_button(button, "actual restored gao_end core victory"): return
	if not await await_terminal(): return
	if not check(battle.mission._result_frozen, "original end flow froze complete actual victory result"): return
	stage_completed = await verify_terminal(receipt, battle.mission.result_snapshot(true), metrics_before)
