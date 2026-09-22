extends SceneTree
## Run only in a private project/profile. Production menus, queue APIs and
## Unit ticks are exercised; fixtures supply resources/buildings, not timing.
const DT := 1.0 / 60.0
var checks: Array = []
var failures: Array = []
var samples: Array = []
var functional_completed := false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[rts-economy-rules] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _private_ok() -> bool:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var expected_project := OS.get_environment("LSH_RTS_RULES_QA_PROJECT")
	var expected_profile := OS.get_environment("LSH_RTS_RULES_QA_PROFILE")
	if expected_project.is_empty(): expected_project = OS.get_environment("LSH_RTS_QA_PROJECT")
	if expected_profile.is_empty(): expected_profile = OS.get_environment("LSH_RTS_QA_PROFILE")
	var expected := expected_project.simplify_path().trim_suffix("/")
	var profile := OS.get_user_data_dir().simplify_path().trim_suffix("/")
	return not expected_project.is_empty() and not expected_profile.is_empty() \
		and project == expected and profile == expected_profile.simplify_path().trim_suffix("/") \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-") \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"

func _make_battle():
	var campaign = root.get_node("Campaign")
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(key, false)
	campaign.skirmish_ai = true
	campaign.ai_difficulty = "normal"
	campaign.victory_mode = "conquest"
	campaign.set_meta("rts_training_intel", false)
	root.get_node("Settings").auto_micro_level = 0
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	if not b.has_method("gameplay_rng_fault"):
		check(false, "production Battle script must parse and attach")
		b.queue_free()
		return null
	b.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	b.phase = b.Phase.FIGHT
	b.hud._intro_root.hide()
	b.level.on_start(b)
	check(b.gameplay_rng_fault().is_empty(), "real Battle starts with valid RNG")
	return b

func _release(b) -> void:
	current_scene = null
	b.queue_free()
	await process_frame
	await process_frame

func _building(b, key: String, offset: Vector2i):
	var cell = b.map.nearest_open(b.level.AI_BASE + offset)
	return b.spawn_at(key, 1, cell)

func _tick_building(b, building, seconds: float) -> void:
	for i in range(int(round(seconds / DT))):
		b._grid_build()
		building._physics_process(DT)

func _functional(b) -> void:
	var level = b.level
	var campaign = root.get_node("Campaign")
	check(is_equal_approx(b.faction_gather_mult[1], 1.0), "normal AI has no hidden gather multiplier")
	check(b.faction_gold(1) == b.gold and b.faction_wood(1) == b.wood, "normal starting gold/wood match player")
	check(level._guan_workers(b).size() == 5 and level._ai_pop_cap(b) == b.pop_cap, "normal starts with five workers and matching population capacity")
	for pair in [["guan_dao", "liang_dao"], ["guan_gong", "liang_gong"], ["guan_qi", "liang_ma"]]:
		for field in ["cost_gold", "cost_wood", "pop", "train_time", "min_age"]:
			check(b._defs[pair[0]].get(field, 1) == b._defs[pair[1]].get(field, 1), "%s mirrors %s %s" % [pair[0], pair[1], field])
	var ordinary: String = level.top_status(b)
	for secret in ["AI 金", "农", "待发", "突击", "高俅血", "大营 %"]:
		check(not ordinary.contains(secret), "ordinary status hides " + secret)
	campaign.set_meta("rts_training_intel", true)
	var observed: String = level.top_status(b)
	check(observed.contains("训练情报") and observed.contains("AI 金") and observed.contains("待发"), "explicit training switch shows labelled omniscient data")
	campaign.set_meta("rts_training_intel", false)
	check(level.top_status(b) == ordinary, "disabling training switch restores ordinary status")
	check(level.difficulty_rules_text().contains("1.9") and level.difficulty_rules_text().contains("280"), "difficulty aid is disclosed in menu text")
	level._elapsed = 1000.0
	b.faction_res[1] = {"gold": 0.0, "wood": 0.0}
	level._ai_advance_age(b)
	check(level._ai_age == 1 and level.ai_base._research_key == "", "time alone never grants a free age")
	b.faction_res[1] = {"gold": 1000.0, "wood": 1000.0}
	var player_gold: int = b.gold
	var hero = b.spawn_at("hu_yanzhuo", 1, b.map.nearest_open(level.AI_BASE + Vector2i(5, 7)))
	var hero_hp_before: float = hero.max_hp
	level._ai_advance_age(b)
	check(level.ai_base._research_key == "tech_age2" and level._ai_age == 1, "age request creates genuine research, not instant age change")
	check(b.faction_gold(1) == 800 and b.faction_wood(1) == 880 and b.gold == player_gold, "age research charges enemy pool only")
	check(not b.queue_train(level.ai_base, "lou_luo", false), "research blocks training in the same building")
	check(b.queue_research(level.hall, "tech_age2", false), "enemy research does not lock player's matching technology")
	_tick_building(b, level.ai_base, 39.0)
	check(level._ai_age == 1, "age remains locked before forty-second research completes")
	_tick_building(b, level.ai_base, 1.1)
	check(level._ai_age == 2 and b.current_age == 1, "research completes enemy age without advancing player")
	check(is_equal_approx(hero.max_hp, hero_hp_before * 1.1), "enemy age health includes real hero recomputation")
	hero._recompute_hero_stats()
	check(is_equal_approx(hero.max_hp, hero_hp_before * 1.1), "hero recomputation preserves enemy age bonus")
	level._ai_advance_age(b)
	check(level.ai_base._research_key == "tech_age3" and level._ai_age == 2, "third age also requires a paid research queue")
	_tick_building(b, level.ai_base, 55.1)
	check(level._ai_age == 3 and is_equal_approx(level.faction_attack_tech_mult(hero), 1.1), "third-age completion exposes correct hero attack technology multiplier")
	check(b.queue_train(level.ai_base, "luan_tingyu", false), "enemy hero uses the hall production queue")
	check(level._queued_count(b, "", true) == 1 and level.ai_base._train_t == b.train_time_for("luan_tingyu"), "hero reserves population and real training duration")
	check(not b.queue_train(level.ai_base, "luan_tingyu", false), "same hero cannot be queued twice")
	b.cancel_train(level.ai_base, 0)
	var bar = _building(b, "barracks", Vector2i(9, 3))
	bar.is_constructing = true
	check(not b.queue_train(bar, "guan_dao", false), "unfinished barracks cannot train")
	bar.is_constructing = false
	var before_count: int = b.count_alive(1, "guan_dao")
	var gold_before: float = b.faction_gold(1)
	var wood_before: float = b.faction_wood(1)
	check(b.queue_train(bar, "guan_dao", false), "AI uses public real training queue")
	check(b.count_alive(1, "guan_dao") == before_count and bar._train_queue.size() == 1, "paying adds queued work, not an immediate soldier")
	check(b.faction_gold(1) == gold_before - b._defs.guan_dao.cost_gold and b.faction_wood(1) == wood_before - b._defs.guan_dao.cost_wood, "soldier charges actual gold and wood")
	_tick_building(b, bar, float(b._defs.guan_dao.train_time) - 0.1)
	check(b.count_alive(1, "guan_dao") == before_count, "soldier cannot emerge early")
	_tick_building(b, bar, 0.2)
	check(b.count_alive(1, "guan_dao") == before_count + 1 and bar._train_queue.is_empty(), "real building ticks complete soldier production")
	check(level._staged.size() > 0, "completed soldier joins AI staging, not player rally flow")
	check(b.queue_train(bar, "guan_dao", false), "second soldier can queue")
	b.cancel_train(bar, 0)
	check(b.faction_gold(1) == gold_before - b._defs.guan_dao.cost_gold and b.gold == player_gold - 200, "cancel refunds enemy pool, never player pool")
	var bar2 = _building(b, "barracks", Vector2i(-9, 3))
	b.faction_res[1] = {"gold": 10000.0, "wood": 10000.0}
	for i in range(12):
		b.queue_train(bar if i % 2 == 0 else bar2, "guan_dao", false)
	check(level._ai_pop(b) + level._queued_pop(b) == level._ai_pop_cap(b), "multiple queues reserve the shared population exactly")
	check(not b.queue_train(bar, "guan_dao", false), "full reserved population blocks another purchase")
	while not bar._train_queue.is_empty(): b.cancel_train(bar, 0)
	while not bar2._train_queue.is_empty(): b.cancel_train(bar2, 0)
	var halted: int = b.count_alive(1, "guan_dao")
	check(b.queue_train(bar, "guan_dao", false), "destruction fixture has a paid queued soldier")
	bar.hp = 0.0
	_tick_building(b, bar, 30.0)
	check(b.count_alive(1, "guan_dao") == halted, "destroyed production building never completes its queue")
	check(not b.queue_train(bar, "guan_dao", false), "destroyed building cannot accept new orders")
	level._ai_age = 3
	var workshop = _building(b, "siege_workshop", Vector2i(9, -7))
	var ram_before: int = b.count_alive(1, "siege_ram")
	check(b.queue_train(workshop, "siege_ram", false), "siege uses the same paid queue")
	check(level._queued_pop(b) >= 3 and b.count_alive(1, "siege_ram") == ram_before, "siege reserves three population and does not instantly spawn")
	var no_market_gold: float = b.faction_gold(1)
	b.faction_res[1].wood = 0.0
	level._ai_trade_fallback(b)
	check(b.faction_gold(1) == no_market_gold and b.faction_wood(1) == 0, "AI cannot trade without a completed market")
	var market = _building(b, "market", Vector2i(-9, -7))
	level._ai_trade_fallback(b)
	check(b.faction_gold(1) == no_market_gold - 100 and b.faction_wood(1) == 70, "completed market enables the shared 100-to-70 exchange")
	check(b.gameplay_rng_fault().is_empty(), "functional fixtures preserve RNG contract")
	functional_completed = true

func _short_match(b) -> void:
	var level = b.level
	var max_army: int = level._ai_alive_army(b)
	var max_queued := 0
	for frame in range(10800):
		b._physics_process(DT)
		for u in b.units.duplicate():
			if is_instance_valid(u) and not u.is_queued_for_deletion(): u._physics_process(DT)
		for fx in b.fx_root.get_children():
			if fx.has_method("_physics_process") and not fx.is_queued_for_deletion(): fx._physics_process(DT)
		max_army = maxi(max_army, level._ai_alive_army(b))
		max_queued = maxi(max_queued, level._queued_count(b))
		if frame % 600 == 0: await process_frame
		if not b.gameplay_rng_fault().is_empty() or b.phase == b.Phase.END: break
	check(b.gameplay_rng_fault().is_empty(), "short normal match runs without gameplay RNG fault")
	check(level._has_building(b, "barracks") or max_queued > 0, "normal AI establishes production during short match")
	check(max_queued > 0 and max_army > 2, "natural AI decisions enqueue and finish recruits")
	samples.append({"kind": "180-second normal 1v1 simulation", "elapsed": level._elapsed, "enemy_age": level._ai_age,
		"peak_enemy_army": max_army, "peak_enemy_queue": max_queued, "phase": b.phase,
		"enemy_gold": b.faction_gold(1), "enemy_wood": b.faction_wood(1), "rng_fault": b.gameplay_rng_fault(),
		"limit": "deterministic tick smoke, no player orders; not balance or human playability acceptance"})

func _run() -> void:
	if not _private_ok():
		push_error("PRIVATE_RTS_ECONOMY_QA_REQUIRED")
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	var b = await _make_battle()
	if b == null: quit(3); return
	_functional(b)
	await _release(b)
	b = await _make_battle()
	if b == null: quit(3); return
	await _short_match(b)
	await _release(b)
	check(functional_completed and checks.size() >= 50 and samples.size() == 1, "complete functional checks and short-match sample are mandatory")
	print("[rts-economy-rules-result] " + JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "samples": samples, "user_dir": OS.get_user_data_dir()}))
	quit(0 if failures.is_empty() else 1)
