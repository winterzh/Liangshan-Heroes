extends "terminal.gd"
## Three processes are required because actual SaveAndExit owns process exit.
## The loss is caused only by ordinary movement into the existing enemy camp.
var original_song: Variant
var song_id := ""
var death_evidence: Dictionary = {}
var loss_samples: Array = []

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	mode = OS.get_environment("LL_MODE")
	var profile: String = OS.get_environment("LL_PROFILE").replace("\\", "/").simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and mode in MODES and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("LSH_CONTINUE_FLOW_QA") == "1" \
		and OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").simplify_path() == profile \
		and Intent.hex(OS.get_environment("LL_PROCESS_NONCE"), 32)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/") \
		and project.to_lower() == OS.get_environment("LL_PROJECT").replace("\\", "/").to_lower()
	if not safe: push_error("LIAN_LOSS_PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	check(DisplayServer.get_name() != "headless", "actual GL display is active")
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", false), "actual source runtime identity"): finish(); return
	if not check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3" and Intent.CONTRACTS.level4.version == 2,
		"current candidate lifecycle v3 and Level4 contract2 only"): finish(); return
	var prepared: Dictionary = Factory.prepare_runtime(trusted)
	if not check(prepared.get("ok", false) and not prepared.get("deploy_or_start_called", true), "actual Level4 factory prepares without deployment"): finish(); return
	runtime = prepared.runtime
	if not await wait_for_startup(): finish(); return
	flow = get_node("/root/ContinueFlow")
	if not check(flow.is_enabled() and flow._private_qa_enabled(), "actual private Flow UI entry enabled without public campaign release"): finish(); return
	flow.operation_finished.connect(on_flow_operation)
	get_node("/root/Localize").set_language("zh_CN", false)
	var settings: Node = get_node("/root/Settings")
	settings.game_speed = 1.0; settings.auto_micro_level = 0; settings.edge_scroll = false
	if mode == "save_before_loss":
		await first_process()
	elif read_predecessor():
		if mode == "resume_loss":
			if await restore_same_slot(): await natural_loss()
		else:
			await reject_terminal()
	if save_exit_owned: return
	finish()

func alive(unit: Variant) -> bool:
	return is_instance_valid(unit) and unit.hp > 0.0 and unit.story_outcome == ""

func clock_healthy() -> bool:
	return is_instance_valid(battle) and battle.gameplay_rng_fault().is_empty() \
		and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60

func on_song_died(unit: Variant) -> void:
	# Read the killer assigned by production Unit.take_damage before the died
	# signal. No callback changes the victim, killer, Battle or mission state.
	var killer: Variant = unit._killer
	death_evidence = {"same_original_actor":unit == original_song, "entity_id":str(unit.entity_id),
		"hp":unit.hp, "story_outcome":unit.story_outcome, "position":unit.position,
		"tick":battle._run_clock._next_tick, "phase":int(battle.phase),
		"killer_valid":is_instance_valid(killer), "killer_entity_id":str(killer.entity_id) if is_instance_valid(killer) else "",
		"killer_key":killer.key if is_instance_valid(killer) else "", "killer_faction":killer.faction if is_instance_valid(killer) else -1,
		"killer_registered":battle.units.has(killer) if is_instance_valid(killer) else false,
		"killer_source_id":unit._killer_source_id}
	observations["natural_death"] = death_evidence.duplicate(true)

func natural_loss() -> void:
	var level: Variant = battle.level
	var original_hall: Variant = level.hall
	var original_receipt: Variant = battle._continue_receipt
	original_song = level.song
	if not check(checkpoint.generation == 1 and alive(original_hall) and alive(original_song)
		and not original_song.garrisoned and original_song.faction == 0, "restored original camp and commander start alive before any loss order"): return
	check(cfg_snapshot() == loss_baseline.cfg and campaign_memory() == loss_baseline.campaign_memory
		and rewards_snapshot() == loss_baseline.rewards, "independent Continue preserves saved progress and reward baseline")
	if not failures.is_empty(): return
	song_id = str(original_song.entity_id)
	var origin: Vector2 = original_song.position
	var initial_hp: float = original_song.hp
	var prior_metrics: Array = battle.mission.stage_metrics.duplicate(true)
	original_song.died.connect(on_song_died, CONNECT_ONE_SHOT)
	if not press_button(battle.hud._pause_resume_button, "resume saved battle for natural defeat"): return
	# Passive stance is an ordinary player command; it prevents Song Jiang from
	# counterattacking after reaching the chosen point, without disabling enemies.
	for count: int in range(4):
		if original_song.stance == original_song.STANCE_PASSIVE: break
		battle.select_members([original_song], false)
		battle._cycle_stance()
		action_evidence.append({"kind":"cycle_stance", "actor_entity_id":song_id, "stance":original_song.stance,
			"tick":battle._run_clock._next_tick})
	if not check(original_song.stance == original_song.STANCE_PASSIVE, "ordinary command-card stance cycle sets passive commander"): return
	var target_cell := Vector2i(50, 31)
	var target_point: Vector2 = battle.map.cell_to_world(target_cell)
	if not check(battle.map.is_open_cell(target_cell, original_song.movement_profile), "authored approach between existing enemy commanders is walkable"): return
	var before_serial: int = original_song._order_serial
	battle.select_members([original_song], false)
	battle.minimap_order(target_point, false)
	action_evidence.append({"kind":"ordinary_minimap_move", "actor_entity_id":song_id, "from":origin,
		"target_cell":target_cell, "target_point":target_point, "before_serial":before_serial,
		"after_serial":original_song._order_serial, "tick":battle._run_clock._next_tick})
	if not check(original_song._order_serial > before_serial, "actual movement command advances original command serial"): return
	var deadline: int = Time.get_ticks_msec() + 240000
	var next_sample: int = 0
	var previous_hp: float = initial_hp
	var observed_hp_drops := 0
	var maximum_distance := 0.0
	while battle.phase == B.Phase.FIGHT and death_evidence.is_empty() and Time.get_ticks_msec() < deadline and clock_healthy():
		if not is_instance_valid(original_song): break
		maximum_distance = maxf(maximum_distance, original_song.position.distance_to(origin))
		if original_song.hp < previous_hp: observed_hp_drops += 1
		previous_hp = original_song.hp
		if battle._run_clock._next_tick >= next_sample:
			next_sample = battle._run_clock._next_tick + 120
			var attackers: Array = []
			for unit: Variant in battle.units:
				if alive(unit) and unit.faction == 1 and unit._target == original_song:
					attackers.append({"entity_id":str(unit.entity_id), "key":unit.key, "distance":unit.position.distance_to(original_song.position)})
			loss_samples.append({"tick":battle._run_clock._next_tick, "song_hp":original_song.hp,
				"song_position":original_song.position, "hall_hp":original_hall.hp, "actual_attackers":attackers})
		await get_tree().process_frame
	observations["loss_route"] = {"origin":origin, "initial_hp":initial_hp, "target_cell":target_cell,
		"samples":loss_samples, "hp_drop_observations":observed_hp_drops, "maximum_distance_from_origin":maximum_distance}
	check(clock_healthy(), "natural defeat retains normal 1x/60Hz and healthy gameplay RNG")
	check(not death_evidence.is_empty() and death_evidence.get("same_original_actor", false)
		and death_evidence.get("entity_id") == song_id and death_evidence.get("hp") == 0.0
		and death_evidence.get("story_outcome") == "" and death_evidence.get("killer_valid", false)
		and death_evidence.get("killer_faction") == 1 and death_evidence.get("killer_registered", false),
		"original commander dies to an actual registered enemy through production damage and died signal")
	check(maximum_distance > 128.0 and observed_hp_drops > 0, "ordinary movement and real HP loss were observed before death")
	check(level.hall == original_hall and alive(original_hall) and level.song == original_song
		and is_instance_valid(original_song) and original_song.hp == 0.0, "loss is original commander death while original camp survives")
	check(battle.phase == B.Phase.END and not battle.mission.has_event("lhm_victory"), "actual Level4 callback enters defeat instead of victory")
	if not failures.is_empty(): return
	if not await await_loss_terminal(): return
	if not check(battle.mission._result_frozen, "production already froze complete loss result"): return
	var full_result: Dictionary = battle.mission.result_snapshot(false)
	stage_completed = await verify_loss_terminal(original_receipt, full_result, prior_metrics)
