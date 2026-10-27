extends "terminal.gd"
const Policy := preload("policy.gd")
var policy: RefCounted
var next_economy_tick := 0
var combat_samples: Array = []

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	mode = OS.get_environment("LT_MODE")
	var profile: String = OS.get_environment("LT_PROFILE").replace("\\", "/").simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and mode in MODES and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("LSH_CONTINUE_FLOW_QA") == "1" \
		and OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").simplify_path() == profile \
		and Intent.hex(OS.get_environment("LT_PROCESS_NONCE"), 32)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/") \
		and project.to_lower() == OS.get_environment("LT_PROJECT").replace("\\", "/").to_lower()
	if not safe: push_error("LIAN_PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	check(true, "real source project and four private profile roots with Steam disabled and QA suppression absent")
	check(DisplayServer.get_name() != "headless", "actual GL display is active")
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", false), "actual source runtime identity"): finish(); return
	if not check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3" and Intent.CONTRACTS.level4.version == 2,
		"current candidate lifecycle v3 and Level4 contract2 only"): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check(pack.get("ok", false) and not pack.get("deploy_or_start_called", true), "installed Level4 factory prepares without deployment"): finish(); return
	runtime = pack.runtime
	if not await wait_for_startup(): finish(); return
	flow = get_node("/root/ContinueFlow")
	if not check(flow.is_enabled() and flow._private_qa_enabled(), "actual private Flow UI entry is enabled without public campaign release"): finish(); return
	flow.operation_finished.connect(on_flow_operation)
	get_node("/root/Localize").set_language("zh_CN", false)
	var settings: Node = get_node("/root/Settings")
	settings.game_speed = 1.0; settings.auto_micro_level = 0; settings.edge_scroll = false
	if mode == "save_training":
		await first_process()
	elif read_predecessor():
		if mode in ["resume_training", "resume_victory"]:
			if await restore_same_slot():
				if mode == "resume_training": await complete_training()
				else:
					check(producer._train_queue.is_empty() and producer._train_t == 0.0 and new_ids() == [training.new_unit_id],
						"second independent Continue retains exactly one already completed paid soldier")
					if failures.is_empty(): await natural_victory()
		else:
			await reject_terminal()
	if save_exit_owned: return
	finish()

func alive(unit: Variant) -> bool:
	return is_instance_valid(unit) and unit.hp > 0.0 and unit.story_outcome == ""

func simulation_ok() -> bool:
	return is_instance_valid(battle) and battle.gameplay_rng_fault().is_empty() \
		and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60

func record_action(kind: String, actors: Array, detail: Dictionary = {}) -> void:
	var ids: Array = []
	for actor: Variant in actors:
		if is_instance_valid(actor): ids.append(str(actor.entity_id))
	action_evidence.append({"kind":kind, "actor_entity_ids":ids, "tick":battle._run_clock._next_tick, "detail":detail.duplicate(true)})

func economy_step() -> void:
	if battle._run_clock._next_tick < next_economy_tick: return
	next_economy_tick = battle._run_clock._next_tick + 75
	policy._economy_lhm(battle)

func wait_live(predicate: Callable, seconds: float) -> bool:
	var limit: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < limit and simulation_ok() and battle.phase == B.Phase.FIGHT and failures.is_empty():
		economy_step()
		await get_tree().process_frame
	return bool(predicate.call()) and simulation_ok() and battle.phase == B.Phase.FIGHT and failures.is_empty()

func stance_command(unit: Variant, wanted: int) -> void:
	if not alive(unit): check(false, "stance recipient remains alive"); return
	for count: int in range(4):
		if unit.stance == wanted: return
		battle.select_members([unit], false)
		battle._cycle_stance()
		record_action("cycle_stance", [unit], {"resulting_stance":unit.stance})
	check(unit.stance == wanted, "ordinary stance cycle reaches requested stance")

func natural_drill() -> bool:
	var level: Variant = battle.level
	var hooks: Array = battle.units.filter(func(u): return alive(u) and str(u.entity_id) == training.new_unit_id)
	var lures: Array = battle.units.filter(func(u): return alive(u) and u.faction == 0 and u.key == "liang_qiang")
	if not check(alive(level.xu) and hooks.size() == 1 and not lures.is_empty(), "real instructor, newly paid hook soldier and ordinary lure available"): return false
	var hook: Variant = hooks[0]
	var lure: Variant = lures[0]
	var instructor: Variant = level.xu
	var old_stances: Array = [instructor.stance, hook.stance, lure.stance]
	for actor: Variant in [instructor, hook, lure]: stance_command(actor, actor.STANCE_PASSIVE)
	# These actors receive only drill orders until completion. Economy continues;
	# no whole-army order, enemy pause, geometry assignment or early damage.
	policy.move(battle, [hook], level.DRILL + Vector2i(-2, -2))
	policy.move(battle, [instructor], battle.mission.actions.lhm_drill_reset.cell)
	if not check(await wait_live(func(): return alive(level.dummy), 80.0), "instructor walks to actual mission action and completes one-second setup"): return false
	check(battle.mission.actions.lhm_drill_reset.actors.has("xu_ning") and not level.drill_complete \
		and not level.drill_entered, "authored practice starts without pre-awarded goal")
	var dummy_id: String = str(level.dummy.entity_id)
	policy.move(battle, [lure], level.DRILL_ENTRY + Vector2i(0, 2))
	if not check(await wait_live(func(): return level.drill_entered and level.drill_lure == lure, 55.0), "ordinary non-hook infantry actually enters lure radius"): return false
	var entered_origin: Vector2 = level.drill_lure_origin
	policy.move(battle, [lure], level.DRILL + Vector2i(-5, 1))
	if not check(await wait_live(func(): return level.drill_withdrew, 55.0), "same lure actually withdraws west behind the hook line"): return false
	check(lure.position.distance_to(entered_origin) > 80.0 and lure.position.distance_to(level.dummy.position) > 128.0 \
		and lure.position.x < float(level.DRILL.x - 1) * 32.0, "observed real retreat satisfies all production geometry conditions")
	# Clicking within the reset flag's radius would order Xu Ning to set up a
	# replacement dummy. Approach from the east using ordinary open map cells.
	var reset_action: Dictionary = battle.mission.actions.lhm_drill_reset
	var reset_center: Vector2 = battle.map.cell_to_world(reset_action.cell)
	var approach_cells: Array = [level.DRILL + Vector2i(1, 0), level.DRILL + Vector2i(1, -1)]
	var approach_actors: Array = [instructor, hook]
	for index: int in range(approach_cells.size()):
		var approach: Vector2 = battle.map.cell_to_world(approach_cells[index])
		if not check(battle.map.is_open_cell(approach_cells[index], approach_actors[index].movement_profile) \
			and approach.distance_to(reset_center) > float(reset_action.click_reach) \
			and approach.distance_to(battle.map.cell_to_world(level.DRILL)) <= 88.0,
			"ordinary drill approach is open, near the dummy destination and outside reset click radius"): return false
		policy.move(battle, [approach_actors[index]], approach_cells[index])
	if not check(await wait_live(func(): return alive(level.dummy) and instructor.position.distance_to(level.dummy.position) <= 88.0 \
		and hook.position.distance_to(level.dummy.position) <= 88.0, 45.0), "both passive hooks walk into real melee approach"): return false
	check(not level.drill_coordinated and not level.drill_complete and str(level.dummy.entity_id) == dummy_id,
		"same live dummy and passive proximity do not fabricate coordinated hit")
	policy.target(battle, [instructor, hook], level.dummy, "drill_attack")
	if not check(await wait_live(func(): return level.drill_complete, 45.0), "real two-person attacks complete optional teaching"): return false
	check(level.drill_entered and level.drill_withdrew and level.drill_coordinated \
		and battle.mission.has_event("lhm_drill_complete") and battle.mission.actions.lhm_drill_reset.done,
		"actual teaching event and mission action close naturally")
	observations["natural_drill"] = {"instructor_id":str(instructor.entity_id), "hook_id":str(hook.entity_id),
		"lure_id":str(lure.entity_id), "dummy_id":dummy_id, "lure_origin":entered_origin,
		"lure_retreat":lure.position, "completed_tick":battle._run_clock._next_tick}
	var actors: Array = [instructor, hook, lure]
	for index: int in range(actors.size()): stance_command(actors[index], int(old_stances[index]))
	return failures.is_empty()

func natural_victory() -> void:
	var level: Variant = battle.level
	var original_receipt: Variant = battle._continue_receipt
	var original_hall: Variant = level.hall
	var original_song: Variant = level.song
	var rider_ids: Array = []
	for rider: Variant in level.riders:
		if is_instance_valid(rider): rider_ids.append(str(rider.entity_id))
	check(checkpoint.generation == 2 and rider_ids.size() == 12 and level.lhm_killed == 0,
		"resave precedes combat and retains twelve original riders")
	if not failures.is_empty(): return
	policy = Policy.new(self)
	if not press_button(battle.hud._pause_resume_button, "resume completed training save for natural Level4 battle"): return
	policy.garrison(battle, [level.song], level.hall)
	if not check(await wait_live(func(): return level.song.garrisoned, 30.0), "commander enters original camp by ordinary garrison command"): return
	if not await natural_drill(): return
	var lane: String = "north"
	var assault_ready: bool = false
	var limit: int = Time.get_ticks_msec() + 1000000
	var next_sample_tick: int = 0
	while battle.phase == B.Phase.FIGHT and Time.get_ticks_msec() < limit and simulation_ok() and failures.is_empty():
		economy_step()
		var army: Array = battle.units.filter(func(u): return alive(u) and u.faction == 0 and u != level.song \
			and not u.is_worker and not u.is_building and not u.is_noncombat and not u.garrisoned)
		var cell: Vector2i = level.LANES[0]
		var target: Variant = null
		var attack_move: bool = true
		if level.riders.filter(func(u): return alive(u) and int(u.get_meta("wave_group")) == 0).is_empty(): lane = "south"
		if level.lhm_killed >= 12: lane = "counter"
		if lane == "south": cell = level.LANES[1]
		if lane == "counter":
			if army.size() < 8: assault_ready = false
			if not assault_ready:
				cell = Vector2i(34, 32); attack_move = false
				if army.filter(func(u): return u.position.distance_to(battle.map.cell_to_world(cell)) < 220.0).size() >= 18: assault_ready = true
			if assault_ready:
				if alive(level.hu): target = level.hu; cell = Vector2i(49,29)
				elif alive(level.han): target = level.han; cell = Vector2i(49,33)
				elif alive(level.enemy_base): target = level.enemy_base; cell = level.ENEMY_CAMP
		if army.size() >= 8 or level.elapsed > 120.0:
			if alive(target) and target.fog_visible: policy.target(battle, army, target)
			else: policy.move(battle, army, cell, attack_move)
		policy._skills_lhm(battle, army)
		if battle._run_clock._next_tick >= next_sample_tick:
			next_sample_tick = battle._run_clock._next_tick + 1800
			var sample: Dictionary = {"tick":battle._run_clock._next_tick, "elapsed":level.elapsed, "lane":lane,
				"army":army.size(), "riders_defeated":level.lhm_killed, "hooks_broken":level.broken_count,
				"gold":battle.gold, "wood":battle.wood, "hall_hp":level.hall.hp, "song_hp":level.song.hp}
			combat_samples.append(sample); print("LIAN_COMBAT ", sample)
		var next_tick: int = battle._run_clock._next_tick + 75
		await wait_live(func(): return battle._run_clock._next_tick >= next_tick, 8.0)
	observations["combat"] = {"samples":combat_samples, "initial_rider_ids":rider_ids,
		"buildings_started":policy.buildings_started, "units_queued":policy.units_queued,
		"units_queued_by_key":policy.units_queued_by_key, "orders":policy.orders, "skill_orders":policy.skill_orders}
	check(simulation_ok(), "natural battle preserves normal simulation and RNG health")
	check(battle.phase == B.Phase.END and battle.mission.has_event("lhm_victory"), "normal economy and combat reach actual victory within bounded route")
	check(level.hall == original_hall and level.song == original_song and alive(level.hall) and alive(level.song), "original camp and commander survive entire saved route")
	check(level.lhm_killed == 12 and level.manor_fallen and level.broken_count == 12 \
		and not battle.mission.has_event("lhm_direct_break"), "all twelve original riders are hook-broken before defeat and headquarters falls")
	check(battle.mission.has_event("lhm_han_captured") and battle.mission.has_event("lhm_hu_fled"), "Han Tao captured and Huyan Zhuo retreats through actual combat outcomes")
	check(policy.buildings_started >= 2 and policy.units_queued >= 8 and policy.skill_orders > 0, "ordinary building paid recruitment and skill commands support real combat")
	if not failures.is_empty(): return
	if not await await_terminal(): return
	if not check(battle.mission._result_frozen, "production terminal already froze the complete mission result"): return
	var full_result: Dictionary = battle.mission.result_snapshot(true)
	stage_completed = await verify_terminal(original_receipt, full_result)
