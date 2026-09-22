extends SceneTree
## Natural 60 Hz Unit/Projectile ticks using real Battle setup and public orders.
## Fixtures disable level/AI/target ticking, use durable targets and flat terrain.
## No _deal_hit calls, damage mocks or production timing overrides are used.
## Run in an isolated checkout: godot --headless --path COPY --script
## res://tools/combat_controls_regression_qa.gd

const DT := 1.0 / 60.0
var failures: Array[String] = []
var samples: Array = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("[combat-controls] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _reset(b, terrain := 4) -> void:
	for u in b.units.duplicate():
		if is_instance_valid(u): u.free()
	b.units.clear()
	b.selection.clear()
	for fx in b.fx_root.get_children(): fx.free()
	b._grid.clear()
	b._mob_grid.clear()
	b._body_grid_liang.clear()
	b._body_grid_guan.clear()
	b._focus_counts.clear()
	b.map.init_map(28, 24, "town", terrain)
	b.map.bake()
	b.mission = null
	b.fog = false
	b.track_hero_combat_stats = false

func _tick(b, attacker) -> void:
	b._grid_build()
	attacker._physics_process(DT)
	for fx in b.fx_root.get_children():
		var script = fx.get_script()
		if script != null and script.resource_path == "res://scripts/projectile.gd" and not fx.is_queued_for_deletion():
			fx._physics_process(DT)

func _attack_sample(b, key: String, rate: float) -> Dictionary:
	_reset(b)
	var attacker = b.spawn_at(key, 0, Vector2i(10, 10))
	var target = b.spawn_at("guan_dao", 1, Vector2i(11, 10))
	target.max_hp = 1000000.0
	target.hp = target.max_hp
	if rate < 1.0: attacker.apply_attack_speed_slow(rate, 20.0)
	else: attacker.apply_atkspeed(rate, 20.0)
	attacker.order_attack(target, false, true)
	var starts := 0
	var hits := 0
	var last_start := -1
	var first_hit_delay := -1
	var hit_phase_ok := true
	for frame in range(480):
		var before_cd: float = attacker._cd
		var before_hp: float = target.hp
		_tick(b, attacker)
		if attacker._cd > before_cd:
			starts += 1
			last_start = frame
		if target.hp < before_hp:
			hits += 1
			if first_hit_delay < 0: first_hit_delay = frame - last_start + 1
			if not attacker.is_ranged:
				hit_phase_ok = hit_phase_ok and attacker._pending_done and attacker._lunge <= attacker._hit_at
	var sample := {"unit": key, "rate": rate, "seconds": 8, "starts": starts, "hits": hits,
		"damage": target.max_hp - target.hp, "first_hit_frames": first_hit_delay,
		"swing_speed": attacker._swing_speed, "weapon": attacker._weapon_kind()}
	check(hits > 0 and starts - hits <= 1, "%s rate %.2f completes every started attack except the final in-flight hit" % [key, rate])
	check(hit_phase_ok, "%s rate %.2f melee damage matches authored animation hit phase" % [key, rate])
	check(b.gameplay_rng_fault().is_empty(), "%s rate %.2f keeps the gameplay RNG healthy" % [key, rate])
	samples.append(sample)
	return sample

func _wu_combination(b) -> void:
	_reset(b)
	var wu = b.spawn_at("wu_song", 0, Vector2i(10, 10))
	var target = b.spawn_at("guan_dao", 1, Vector2i(11, 10))
	target.max_hp = 1000000.0
	target.hp = target.max_hp
	# Inject a legal rank-3 random outcome, then use less than the genuine 1.4s
	# reroll interval. The flag's actual aura API supplies its 1.9 multiplier.
	wu.start_drunk(0.7, 1.8, 20.0)
	wu._drunk_atk = 1.8
	wu._drunk_reroll = 1.4
	wu.apply_aura_atkspeed(1.9, 9.0, 9001)
	wu.order_attack(target, false, true)
	var hits := 0
	for frame in range(72):
		var before: float = target.hp
		_tick(b, wu)
		if target.hp < before: hits += 1
	check(wu._weapon_kind() == wu.WK.SWORD, "Wu retains his authored sword weapon")
	check(hits >= 5 and wu._drunk_reroll > 0.0, "legal drunk high roll plus righteous flag produces at least five real hits in 1.2s")
	samples.append({"case": "Wu legal drunk plus flag", "hits": hits, "seconds": 1.2, "damage": target.max_hp - target.hp})

func _building_sample(b, key: String, origin: Vector2i, blocker_mode := false) -> void:
	_reset(b)
	var building = b.spawn_at(key, 0, Vector2i(16, 12))
	var attacker = b.spawn_at("guan_dao", 1, origin)
	building.max_hp = 1000000.0
	building.hp = building.max_hp
	attacker._amove_dest = b.map.cell_to_world(Vector2i(24, 12))
	if blocker_mode: attacker.engage_path_blocker(building)
	else: attacker.order_attack(building, false, true)
	var legal := true
	for frame in range(900):
		var before: Vector2 = attacker.position
		_tick(b, attacker)
		legal = legal and b.map.is_open_world(attacker.position) and b.map._segment_open(before, attacker.position)
	var label := "%s from %s via %s" % [key, origin, "blocker AI" if blocker_mode else "explicit attack"]
	check(building.hp < building.max_hp, label + " actually takes natural melee hits")
	check(legal, label + " never enters or crosses the solid footprint")
	check(attacker._target == building and attacker._melee_target_in_range(building), label + " retains a legal attack position")
	samples.append({"case": label, "damage": building.max_hp - building.hp,
		"distance_to_center": attacker.position.distance_to(building.position), "position": str(attacker.position)})

func _barrier_sample(b, water := false) -> void:
	_reset(b)
	b.map.fill_rect(14, 0, 1, b.map.h, b.map.T.WATER if water else b.map.T.HALL)
	b.map.bake()
	var building = b.spawn_at("house", 0, Vector2i(16, 12))
	var attacker = b.spawn_at("siege_ram", 1, Vector2i(13, 12))
	# This is an ordinary sub-cell location: numerically within melee reach of
	# the footprint, but another solid tile/water strip lies between the actors.
	attacker.position += Vector2(4.0, 0.0)
	building.max_hp = 1000000.0
	building.hp = building.max_hp
	attacker.order_attack(building, false, true)
	var initial: Vector2 = attacker.position
	for frame in range(300): _tick(b, attacker)
	var name := "water strip" if water else "separate wall"
	check(building.hp == building.max_hp, "melee cannot hit a building through " + name)
	check(attacker.position.distance_to(initial) < 0.1 and b.map.is_open_world(attacker.position), "melee cannot cross " + name)
	b.map.set_cell_t(14, 12, b.map.T.GRASS)
	b.map.bake()
	# bake reconstructs terrain grids; reinstall the real target footprint.
	building.set_meta("footprint_blocked", false)
	b.register_building_footprint(building)
	attacker.order_attack(building, false, true)
	for frame in range(300): _tick(b, attacker)
	check(building.hp < building.max_hp, "opening " + name + " makes the same attack command succeed")

func _mobile_collision_sample(b) -> void:
	_reset(b)
	var building = b.spawn_at("house", 0, Vector2i(16, 12))
	var guard = b.spawn_at("liang_dao", 0, Vector2i(12, 12))
	var attacker = b.spawn_at("guan_dao", 1, Vector2i(8, 12))
	building.max_hp = 1000000.0
	building.hp = building.max_hp
	attacker.order_attack(building, false, true)
	var bodies_separate := true
	for frame in range(480):
		_tick(b, attacker)
		bodies_separate = bodies_separate and attacker.position.distance_to(guard.position) >= attacker.radius + guard.radius + 2.0
	check(bodies_separate and building.hp == building.max_hp, "building attack does not bypass an enemy body's collision radius")
	b.units.erase(guard)
	guard.free()
	for frame in range(480): _tick(b, attacker)
	check(building.hp < building.max_hp, "building attack resumes after the physical blocker leaves")

func _water_profile_sample(b) -> void:
	_reset(b, b.map.T.WATER)
	# Navigation-profile fixture: a melee actor using the real naval movement
	# profile; there is no production melee ship, so its combat stats stay unedited.
	var definition: Dictionary = b._defs.guan_dao.duplicate(true)
	definition.movement_profile = "water"
	b._defs["qa_water_melee"] = definition
	b.map.fill_rect(14, 0, 1, b.map.h, b.map.T.GRASS)
	b.map.bake()
	var building = b.spawn_at("house", 0, Vector2i(16, 12))
	var attacker = b.spawn_at("qa_water_melee", 1, Vector2i(10, 12))
	building.max_hp = 1000000.0
	building.hp = building.max_hp
	attacker.order_attack(building, false, true)
	for frame in range(300): _tick(b, attacker)
	check(building.hp == building.max_hp and b.map.world_to_cell(attacker.position).x < 14, "water-profile melee does not cross a land divider")
	b.map.set_cell_t(14, 12, b.map.T.WATER)
	b.map.bake()
	building.set_meta("footprint_blocked", false)
	b.register_building_footprint(building)
	attacker.order_attack(building, false, true)
	var legal := true
	for frame in range(900):
		var before: Vector2 = attacker.position
		_tick(b, attacker)
		legal = legal and b.map._segment_open(before, attacker.position, "water")
	check(legal and building.hp < building.max_hp, "water-profile melee reaches and damages an accessible footprint without leaving water")
	b._defs.erase("qa_water_melee")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	var campaign = root.get_node("Campaign")
	campaign.current = 4
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(key, false)
	campaign.skirmish = true
	root.get_node("Settings").auto_micro_level = 0
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.process_mode = Node.PROCESS_MODE_DISABLED
	check(b.gameplay_rng_fault().is_empty(), "production Battle startup provides a healthy gameplay RNG")
	if failures.is_empty():
		for key in ["wu_song", "lin_chong", "li_kui", "lu_zhishen", "hua_rong"]:
			var slow := _attack_sample(b, key, 0.65)
			var normal := _attack_sample(b, key, 1.0)
			var fast := _attack_sample(b, key, 1.9)
			var combined := _attack_sample(b, key, 3.42)
			check(slow.hits < normal.hits and fast.hits >= normal.hits * 1.6 and combined.hits >= normal.hits * 2.7,
				key + " attack-speed gains scale actual damage-event frequency without a fixed windup cap")
			check(slow.first_hit_frames > normal.first_hit_frames and combined.first_hit_frames < normal.first_hit_frames,
				key + " first-hit response scales with the same attack rate")
		_wu_combination(b)
		_building_sample(b, "house", Vector2i(8, 12))
		_building_sample(b, "house", Vector2i(9, 5))
		_building_sample(b, "house", Vector2i(8, 12), true)
		_building_sample(b, "hall", Vector2i(8, 12))
		_barrier_sample(b)
		_barrier_sample(b, true)
		_mobile_collision_sample(b)
		_water_profile_sample(b)
	print("[combat-controls-result] " + JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "samples": samples, "scope": "isolated natural combat ticks, not a full campaign playthrough"}))
	b.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
