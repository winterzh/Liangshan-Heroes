extends Node
## Focused fixtures for squad decisions and Level-state roundtrip, not a full
## campaign playthrough or complete-world continue qualification.
var checks: Array = []

class OrderUnit extends Unit:
	var last_order := ""
	func order_move(_pos: Vector2, _queued := false, _group_cap := 0.0) -> void: last_order = "move"
	func order_amove(_pos: Vector2, _queued := false, _group_cap := 0.0) -> void: last_order = "amove"
	func order_stop() -> void: last_order = "stop"

class FieldFixture extends RefCounted:
	var map := GameMap.new()
	var mission := MissionFixture.new()
	var units: Array = []
	var messages: Array = []
	var visible := false
	func is_visible_world(_p: Vector2) -> bool: return visible
	func target_visible_to(_observer, _target) -> bool: return true
	func msg(value, _duration) -> void: messages.append(value)

class MissionFixture extends RefCounted:
	var stage_title := ""
	var objective := ""
	var active_action_id := "zhu_rts_rescue"
	var progress := 1.5
	func set_title(value: String) -> void: stage_title = value
	func set_objective(value: String) -> void: objective = value

func _ready() -> void:
	_run.call_deferred()

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	print("SQUAD ", "PASS " if passed else "FAIL ", label)

func _run() -> void:
	var private_root := OS.get_environment("LSH_SQUAD_PROFILE").replace("\\", "/")
	if private_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(private_root.to_lower() + "/appdata/") or OS.get_environment("STEAM_DISABLED") != "1":
		get_tree().quit(2)
		return
	var state = load("res://scripts/run_campaign_level_state.gd").new()
	check("all chapter declarations still classified", state.SCRIPTS.keys().all(func(k): return state.audit_declarations(k).ok))
	var b := FieldFixture.new()
	var level = load("res://scripts/levels/level3_zhujiazhuang_rts.gd").new()
	level.outpost = OrderUnit.new()
	level.enemy_base = OrderUnit.new()
	level.song = OrderUnit.new()
	level.outpost.position = b.map.cell_to_world(level.OUTPOST)
	level.song.position = b.map.cell_to_world(level.CAMP)
	level.song.faction = Unit.FACTION_LIANG
	b.units.append(level.song)
	level._raids(b, 0.5)
	check("opening intel requires scouting", not level.outpost_scouted and "南营情报需侦察" in level.top_status(b))
	# Fixture overrides unit order execution: checks state transitions, not movement.
	var squad: Array = [OrderUnit.new(), OrderUnit.new(), OrderUnit.new()]
	for u in squad: u.position = b.map.cell_to_world(level.OUTPOST + Vector2i(3,0))
	level.reserve.assign(squad)
	level.raid_clock = 0.0
	level._raids(b, 0.5)
	check("assembled units deploy without duplication", level.raid_state == "attack" and level.raiders.size() == 3 and level.reserve.is_empty())
	var before_hp: float = squad[0].hp
	for u in squad: u.hp = u.max_hp * 0.4
	level._raids(b, 0.5)
	check("wounded squad issues retreat orders", level.raid_state == "retreat" and squad[0].hp < before_hp and squad[0].last_order == "move")
	for u in squad: u.position = level.raid_home
	level._raids(b, 0.5)
	check("returned survivors regroup without healing", level.raid_state == "muster" and level.reserve.size() == 3 and is_equal_approx(squad[0].hp, squad[0].max_hp * 0.4))
	level.outpost.hp = 0.0
	level.raid_clock = 0.0
	var raids: int = level.raids_sent
	level._raids(b, 0.5)
	check("destroyed outpost stops new raids but keeps survivors", level.raids_sent == raids and level.reserve.size() == 3)
	level.expansion_spotted = false
	level.resource_guards.clear()
	level.reserve.assign(squad)
	level.song.position = b.map.cell_to_world(level.EXPANSION)
	for u in squad: u.position = b.map.cell_to_world(Vector2i(60,50))
	level._observe_expansion(b)
	check("enemy does not learn distant player expansion", not level.expansion_spotted)
	squad[0].position = level.song.position + Vector2(32,0)
	level._observe_expansion(b)
	check("nearby observer learns player presence", level.expansion_spotted)
	# Existing garrison only; a second entrance cannot teleport or redirect it.
	level.reserve.clear()
	level.gate_defenders.assign(squad)
	var before_positions: Array = squad.map(func(member): return member.position)
	level._commit_gate_defense(b, level.SIDE_GATE)
	var first_target: Vector2 = level.defense_target
	level._commit_gate_defense(b, level.MAIN_GATE)
	check("first opening commits existing guards without teleport or second retarget", level.defense_state == "moving" and level.defense_target == first_target and level.gate_defenders.size() == 3 and squad.map(func(member): return member.position) == before_positions and squad[0].last_order == "amove")
	level._gate_defense_tick(b, 0.5)
	check("unseen gate response does not announce enemy movement", not level.defense_announced)
	b.visible = true
	for member in squad: member.position = first_target
	level._gate_defense_tick(b, 0.5)
	check("visible arrived guards settle without healing", level.defense_announced and level.defense_state == "guard" and squad[0].last_order == "stop" and is_equal_approx(squad[0].hp, squad[0].max_hp * 0.4))
	level.hall = level.song
	level.prisoners.append(squad[0])
	level.prisoners_freed = true
	level._refresh_stage(b)
	var rescued_first := b.mission.stage_title
	level.manor_fallen = true
	level._refresh_stage(b)
	var returning := b.mission.stage_title
	squad[0].position = level.hall.position
	level._refresh_stage(b)
	check("rescue first then fall and return update objective without cancelling action", rescued_first != returning and returning != b.mission.stage_title and b.mission.active_action_id == "zhu_rts_rescue" and b.mission.progress == 1.5)
	# Detached component fixture: persistence of new state, without world mount.
	var sample = load("res://scripts/levels/level3_zhujiazhuang_rts.gd").new()
	var u = load("res://scripts/unit.gd").new()
	u.entity_id = 1
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.set_block_signals(true)
	sample.prisoners.resize(7)
	sample.raiders.append(u)
	sample.raid_state = "retreat"
	sample.raid_strength = 4
	sample.raid_elapsed = 12.5
	sample.raid_home = Vector2(900,700)
	sample.outpost_scouted = true
	sample.expansion_spotted = true
	sample.gate_defenders.append(u)
	sample.defense_state = "moving"
	sample.defense_target = Vector2(480,576)
	sample.defense_elapsed = 6.5
	sample.defense_announced = true
	var captured: Dictionary = state.capture(sample, "level3", "squad:v3", {"1": u}, 2, {}, {"mission_token": "squad:fixture", "deferred_drained": true})
	check("new squad state captures", captured.ok)
	if captured.ok:
		var restored: Dictionary = state.restore(captured.record, "level3", "squad:v3", {"1": u}, 2, {}, "squad:fixture")
		check("retreat state and unit identity survive roundtrip", restored.ok and restored.level.raid_state == "retreat" and restored.level.raid_elapsed == 12.5 and restored.level.raid_home == Vector2(900,700) and restored.level.raiders[0] == u and restored.level.outpost_scouted and restored.level.expansion_spotted)
		check("gate response state and identity survive roundtrip", restored.ok and restored.level.gate_defenders[0] == u and restored.level.defense_state == "moving" and restored.level.defense_target == Vector2(480,576) and restored.level.defense_elapsed == 6.5 and restored.level.defense_announced)
		check("different content rejected", not state.restore(captured.record, "level3", "older:v1", {"1": u}, 2, {}, "squad:fixture").ok)
	u.free()
	for member in squad: member.free()
	level.outpost.free()
	level.enemy_base.free()
	level.song.free()
	b.map.free()
	var passed := checks.all(func(row): return row.passed)
	var report := {"passed": passed, "scope": "squad fixtures and level component; not full battle continue or human fun", "checks": checks}
	var file := FileAccess.open(OS.get_environment("LSH_SQUAD_REPORT"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	get_tree().quit(0 if passed else 1)
