## Failure consumers use a deliberately rejecting Battle test double; the
## allocator and graph below use actual current Battle/Unit/Map scripts.
class RejectBattle extends RefCounted:
	var units: Array = []
	var map: Variant
	var _gameplay_rng_issue: String = ""
	var _defs: Dictionary = {}
	var attempts: int = 0
	var capacity: bool = false
	var gold: int = 1000
	var wood: int = 700
	var mission = null
	func entity_ids_available(_count: int = 1) -> bool: return capacity
	func _gameplay_rng_stop(code: String) -> Dictionary:
		if _gameplay_rng_issue.is_empty(): _gameplay_rng_issue = code
		return {"ok": false, "code": _gameplay_rng_issue}
	func gameplay_rng_fault() -> String: return _gameplay_rng_issue
	func spawn_unit(_key: String, _faction: int, _at: Vector2) -> Variant:
		attempts += 1
		return null
	func spawn_at(_key: String, _faction: int, _at: Vector2i) -> Variant:
		attempts += 1
		return null
	func spawn_group(_key: String, _n: int, _faction: int, _gate: Vector2i, _target: Vector2, _spread := 2) -> Array:
		attempts += 1
		_gameplay_rng_stop("INJECTED_GROUP_FAILURE")
		return []
	func faction_spend(_faction: int, g: int, w: int) -> bool:
		gold -= g
		wood -= w
		return true
	func add_resources(g: int, w: int, _faction: int = 0) -> void:
		gold += g
		wood += w
	func on_unit_trained(_building, _key: String) -> bool:
		_gameplay_rng_stop("INJECTED_PRODUCTION_FAILURE")
		return false
	func msg(_text: String, _time: float = 3.5) -> void: pass
	func clear_campaign_section() -> void:
		for u in units: u.queue_free()
		units.clear()

func _reject_battle(map_script: Script) -> RejectBattle:
	var rejected := RejectBattle.new()
	rejected.map = map_script.new()
	owned.append(rejected.map)
	return rejected

func _patient(unit_script: Script, b: RejectBattle, key: String) -> Variant:
	var u: Variant = unit_script.new()
	owned.append(u)
	u.key = key
	u.hp = 75.0
	u.max_hp = 100.0
	u._combat_cool = 1.75
	u.position = Vector2(448, 576)
	u.faction = 0
	b.units.append(u)
	return u

func _stable_failure_tests(battle_script: Script, map_script: Script, unit_script: Script, graph: Variant) -> void:
	var actual: Variant = _shell(battle_script, map_script)
	actual._defs = {"identity_fixture": {"building": true, "hp": 100, "name": "Identity fixture"}}
	var first: Variant = actual.spawn_unit("identity_fixture", 0, Vector2(64, 64))
	var second: Variant = actual.spawn_unit("identity_fixture", 0, Vector2(96, 64))
	_check("actual spawn assigns positive monotonic identity", first != null and second != null and first.entity_id == 1 and second.entity_id == 2 and actual.next_entity_id == 3)
	actual.units.erase(first)
	first.free()
	var third: Variant = actual.spawn_unit("identity_fixture", 0, Vector2(128, 64))
	_check("released entity ID never reused", third != null and third.entity_id == 3 and actual.next_entity_id == 4 and actual.units == [second, third])
	actual.next_entity_id = 9223372036854775806
	var last: Variant = actual.spawn_unit("identity_fixture", 0, Vector2(160, 64))
	_check("last issuable ID and exhausted sentinel remain exact", last != null and last.entity_id == 9223372036854775806 and actual.next_entity_id == 9223372036854775807)
	var old_children: Array = actual.units_root.get_children()
	var old_active: Array = actual.units.duplicate()
	var failed: Variant = actual.spawn_unit("identity_fixture", 0, Vector2(192, 64))
	_check("exhausted creation publishes no node or active entry", failed == null and actual.units_root.get_children() == old_children and actual.units == old_active and actual.next_entity_id == 9223372036854775807)
	_check("first fault is retained and no wrap occurs", actual.gameplay_rng_fault() == "ENTITY_ID_EXHAUSTED" and actual._allocate_entity_id() == 0 and actual.next_entity_id == 9223372036854775807)
	_check("faulted world RNG capture rejects", actual.capture_gameplay_rng().get("code") == "ENTITY_ID_EXHAUSTED")
	var actual_ids: Dictionary = {}
	for u: Variant in actual.units: actual_ids[u] = str(u.entity_id)
	_check("faulted world Unit graph capture rejects before serialization", graph.capture(actual, actual_ids, VERSION).get("code") == "BATTLE_FAULT")

	for is_song: bool in [true, false]:
		var b := _reject_battle(map_script)
		var level: Variant = load("res://scripts/levels/level2_jiangzhou_rts.gd").new()
		var old: Variant = _patient(unit_script, b, "song_jiang_bound" if is_song else "dai_zong_bound")
		if is_song: level.song_bound = old
		else: level.dai_bound = old
		level._free(b, is_song)
		_check("Jiangzhou failed rescue retains bound actor " + str(is_song), b.units == [old] and not old.is_queued_for_deletion() and (level.song_bound == old if is_song else level.dai_bound == old) and level.song_freed == null and level.dai_freed == null and old.hp == 75.0 and old._combat_cool == 1.75)
		_check("Jiangzhou required replacement is visible fault " + str(is_song), b.attempts == 1 and b.gameplay_rng_fault() == "ENTITY_REQUIRED_REPLACEMENT")
	var jb := _reject_battle(map_script)
	var jl: Variant = load("res://scripts/levels/level2_jiangzhou_rts.gd").new()
	jl.post = _patient(unit_script, jb, "supply_post")
	jl.alarm = true
	jl.train_left = 0.0
	jb._defs = {"liang_dao": {"cost_gold": 53, "cost_wood": 19, "train_time": 4.0}}
	jl._produce(jb, 0.1)
	_check("paid reinforcement failure refunds exact gold and wood", jb.gold == 1000 and jb.wood == 700 and jb.attempts == 1)
	_check("paid reinforcement failure retains completion counters", jl.enemy_produced == 0 and jl.enemy_spent_gold == 0 and jl.enemy_spent_wood == 0 and jl.reinforcements.is_empty() and not jb.gameplay_rng_fault().is_empty())

	var lb := _reject_battle(map_script)
	var ll: Variant = load("res://scripts/levels/level4_lianhuanma_rts.gd").new()
	var dummy: Variant = _patient(unit_script, lb, "hook_training_dummy")
	ll.dummy = dummy
	ll.on_mission_action(lb, "lhm_drill_reset", null)
	_check("failed drill reset retains old dummy and instructor", ll.dummy == dummy and not dummy.is_queued_for_deletion() and lb.units == [dummy] and ll.xu == null and lb.gameplay_rng_fault() == "ENTITY_REQUIRED_REPLACEMENT")

	var yb := _reject_battle(map_script)
	var yl: Variant = load("res://scripts/levels/level6_yezhulin.gd").new()
	var bound: Variant = _patient(unit_script, yb, "lin_chong_bound")
	yl.lin_bound = bound
	yl.st = yl.CARE
	yl._finish_untie(yb)
	_check("failed Lin Chong untying retains original injury state", yl.lin_bound == bound and yl.lin_freed == null and not bound.is_queued_for_deletion() and yb.units == [bound] and bound.hp == 75.0 and yb.gameplay_rng_fault() == "ENTITY_REQUIRED_REPLACEMENT")

	var gb := _reject_battle(map_script)
	var gl: Variant = load("res://scripts/levels/level5_gao_rts.gd").new()
	var carrier: Variant = _patient(unit_script, gb, "zhang_shun_boat")
	carrier.position = gb.map.cell_to_world(gl.LANDING_WATER)
	carrier.set_meta("carried_story_person", "高俅")
	carrier.display_name = "交接前押送艇"
	gl.recovered = true
	gl.carrier = carrier
	gl.on_mission_action(gb, "gao_land", carrier)
	_check("failed Gao transfer keeps ship passenger and landing state", not gl.landed and gl.prisoner == null and carrier.get_meta("carried_story_person") == "高俅" and carrier.display_name == "交接前押送艇" and gb.units == [carrier] and gb.gameplay_rng_fault() == "ENTITY_REQUIRED_REPLACEMENT")

	var ab := _reject_battle(map_script)
	var al: Variant = load("res://scripts/levels/arena.gd").new()
	seed(75271)
	var expected_random: int = randi()
	seed(75271)
	al.arena_spawn_random(ab)
	_check("arena capacity failure does not advance wave or consume RNG", al._wave == 0 and ab.attempts == 0 and ab.gameplay_rng_fault() == "ENTITY_ARENA_CAPACITY" and randi() == expected_random)
	var sb := _reject_battle(map_script)
	var sl: Variant = load("res://scripts/levels/scenario.gd").new()
	sl.data = {"waves": [{"groups": [{"key": "guan_dao", "n": 2}], "reinforce": {"units": [{"key": "liang_dao"}]}}]}
	_check("scenario capacity failure reports false", not sl._spawn_wave(sb, 0))
	_check("scenario failed wave does not publish or increment", not sl._wave_spawned and sl._wave_i == 0 and sb.attempts == 0 and sb.gameplay_rng_fault() == "ENTITY_SCENARIO_CAPACITY")
	var zb := _reject_battle(map_script)
	var zl: Variant = load("res://scripts/levels/level3_zhujiazhuang.gd").new()
	var retained: Variant = _patient(unit_script, zb, "song_jiang")
	zl._second_day(zb)
	_check("authored redeploy capacity fails before old world deletion", zb.units == [retained] and not retained.is_queued_for_deletion() and zb.attempts == 0 and zb.gameplay_rng_fault() == "ENTITY_REDEPLOY_CAPACITY")

	var pb := _reject_battle(map_script)
	var producer: Variant = _patient(unit_script, pb, "barracks")
	producer.battle = pb
	producer._train_queue = ["liang_dao", "liang_gong"]
	producer._train_t = 0.0
	producer._production_tick(0.1)
	_check("failed actual Unit production retains paid queue order", producer._train_queue == ["liang_dao", "liang_gong"] and pb.gameplay_rng_fault() == "INJECTED_PRODUCTION_FAILURE")
