extends Node
## Order-recording fixtures; no live movement or campaign victory claims.
var checks: Array = []

class OrderUnit extends Unit:
	var orders := 0
	var destination := Vector2.ZERO
	func order_amove(pos: Vector2, _queued := false, _cap := 0.0) -> void:
		orders += 1
		destination = pos
	func order_stop() -> void: orders += 1

class Field extends RefCounted:
	var map := GameMap.new()
	func target_visible_to(_observer, _target) -> bool: return true

func _ready() -> void: _run.call_deferred()

func check(label: String, passed: bool) -> void:
	checks.append({"label":label,"passed":passed})
	print("PURSUIT ","PASS " if passed else "FAIL ",label)

func _run() -> void:
	var profile := OS.get_environment("LSH_SQUAD_PROFILE").replace("\\","/")
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile.to_lower()+"/appdata/") or OS.get_environment("STEAM_DISABLED") != "1":
		get_tree().quit(2)
		return
	var b := Field.new()
	var level = load("res://scripts/levels/level2_jiangzhou_rts.gd").new()
	var members: Array = []
	for i in range(6):
		var u := OrderUnit.new()
		u.position = b.map.cell_to_world(Vector2i(32+i%3,9))
		members.append(u)
		level.pursuit.append(u)
	var escapee := OrderUnit.new()
	escapee.position = b.map.cell_to_world(level.DOCK)
	level.song_freed = escapee
	check("distant escapee is not used as spawn destination", level._pursuit_target(b,[members[0]]) == b.map.cell_to_world(level.SCAFFOLD+Vector2i(0,5)))
	level.pursuit_sent = true
	level._pursuit_tick(b,2.0)
	for u in members: u.position = level.pursuit_west_goal
	level._pursuit_tick(b,2.0)
	check("two existing groups branch into different lanes", level.pursuit_west_goal != level.pursuit_south_goal and level.pursuit_steps == [1,1] and level.pursuit.size() == 6)
	escapee.position = members[0].position + Vector2(200,0)
	var seen_at := escapee.position
	level._pursuit_tick(b,2.0)
	check("actual observation updates chase goal", level.pursuit_west_goal == seen_at and level.pursuit_contacts[0])
	escapee.position = b.map.cell_to_world(Vector2i(5,55))
	level._pursuit_tick(b,2.0)
	check("lost contact retains last sighting instead of unseen new position", level.pursuit_west_goal == seen_at)
	for u in members: u.position = seen_at
	level._pursuit_tick(b,2.0)
	check("reaching last sighting resumes route search", not level.pursuit_contacts[0] and level.pursuit_steps[0] >= 1 and level.pursuit_west_goal != escapee.position)
	members[0].hp = 0.0
	check("casualties do not swap surviving lane assignments", level._search_group(0) == [members[2],members[4]] and level._search_group(1) == [members[1],members[3],members[5]])
	escapee.position = b.map.cell_to_world(Vector2i(55,3))
	level.pursuit_steps = [5,5]
	level.pursuit_contacts = [false,false]
	level.pursuit_west_goal = b.map.cell_to_world(level.DOCK)
	level.pursuit_south_goal = level.pursuit_west_goal
	for u in members: u.position = level.pursuit_west_goal
	level._pursuit_tick(b,2.0)
	var orders: Array = members.map(func(u): return u.orders)
	level._pursuit_tick(b,2.0)
	check("finished search guards once without repeatedly cancelling combat", level.pursuit_steps == [6,6] and members.map(func(u): return u.orders) == orders)
	level.first_rescued = true
	check("first freed Song Jiang leaves Dai Zong a distinct rescue task", "另队解救戴宗" in level._escort_objective())
	escapee.story_outcome = "embarked"
	check("early boarding still points to the other captive", "回法场解救另一人" in level._escort_objective())
	escapee.story_outcome = ""
	level.song_freed = null
	level.dai_freed = escapee
	check("first freed Dai Zong leaves Song Jiang a distinct rescue task", "另队解救宋江" in level._escort_objective())
	level.song_freed = members[1]
	level.named_units = {"zhang_shun":members[3], "zhang_heng":members[5]}
	check("both freed with both boat allies can still rendezvous", "白龙庙" in level._escort_objective())
	members[3].hp = 0
	check("loss of a boat ally gives boarding guidance", "登船点" in level._escort_objective() and "白龙庙" not in level._escort_objective())
	level.song_freed.story_outcome = "embarked"
	level.dai_freed.story_outcome = "embarked"
	check("both aboard hands control to the departure objective", level._escort_objective().is_empty())
	var state = load("res://scripts/run_campaign_level_state.gd").new()
	check("all chapter declarations remain classified", state.SCRIPTS.keys().all(func(key): return state.audit_declarations(key).ok))
	var sample = load("res://scripts/levels/level2_jiangzhou_rts.gd").new()
	var saved_unit = load("res://scripts/unit.gd").new()
	saved_unit.entity_id = 1
	saved_unit.process_mode = Node.PROCESS_MODE_DISABLED
	saved_unit.set_block_signals(true)
	sample.caches.resize(2)
	sample.executioners.resize(2)
	sample.pursuit.resize(6)
	sample.pursuit[2] = saved_unit
	sample.pursuit_sent = true
	sample.first_rescued = true
	sample.pursuit_steps = [2,1]
	sample.pursuit_contacts = [true,false]
	sample.pursuit_west_goal = Vector2(600,900)
	sample.pursuit_south_goal = Vector2(900,800)
	sample.pursuit_think = 1.25
	var capture: Dictionary = state.capture(sample,"level2","pursuit:v2",{"1":saved_unit},2,{}, {"mission_token":"pursuit:fixture","deferred_drained":true})
	check("search state captures",capture.ok)
	if capture.ok:
		var restored: Dictionary = state.restore(capture.record,"level2","pursuit:v2",{"1":saved_unit},2,{},"pursuit:fixture")
		check("last sighting route cursor cooldown and identity survive restore",restored.ok and restored.level.pursuit_steps == [2,1] and restored.level.pursuit_contacts == [true,false] and restored.level.pursuit_west_goal == Vector2(600,900) and restored.level.pursuit_south_goal == Vector2(900,800) and restored.level.pursuit_think == 1.25 and restored.level.pursuit[2] == saved_unit)
		sample.pursuit_steps = [7,0]
		check("invalid search cursor is rejected",not state.capture(sample,"level2","pursuit:v2",{"1":saved_unit},2,{}, {"mission_token":"pursuit:fixture","deferred_drained":true}).ok)
		sample.pursuit_steps = [6,0]
		sample.pursuit_west_goal = Vector2.ZERO
		check("finished cursor without a search destination is rejected",not state.capture(sample,"level2","pursuit:v2",{"1":saved_unit},2,{}, {"mission_token":"pursuit:fixture","deferred_drained":true}).ok)
	for u in members: u.free()
	escapee.free()
	saved_unit.free()
	b.map.free()
	var passed := checks.all(func(row): return row.passed)
	FileAccess.open(OS.get_environment("LSH_SQUAD_REPORT"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"recorded orders and Level component; not live movement or full continue"},"\t"))
	get_tree().quit(0 if passed else 1)
