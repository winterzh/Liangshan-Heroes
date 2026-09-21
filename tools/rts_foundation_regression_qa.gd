extends SceneTree
## Run only in an imported private project with a unique LSH user profile.
## Production movement, queue, camera, separation and deposit methods execute here.
## The cast fixture replaces only final spell payload with a counted receipt; it
## still uses Battle's real walk/pending queues and Unit's real windup/state machine.
var failures: Array[String] = []
var checks: Array = []
var evidence := {}
var completed: Array[String] = []
var unit_script
var map_script
var battle_script
var counting_map_script: GDScript

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	print("[foundation] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _compile(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK, "fixture wrapper compiles")
	return script

func _map(blocked := false):
	var map = counting_map_script.new()
	map.init_map(80, 30, "marsh", map_script.T.GRASS)
	if blocked:
		for y in range(30): map.set_cell_t(40, y, map_script.T.CLIFF)
	map.bake()
	return map

func _unit(map, at := Vector2(160, 160)):
	var u = unit_script.new()
	u.map = map
	u.position = at
	u.base_speed = 72.0
	u.stance = unit_script.STANCE_PASSIVE # No enemies in detached movement fixtures.
	return u

func _movement_cases() -> void:
	var map = _map()
	var u = _unit(map)
	var start: Vector2 = u.position
	u.order_move(Vector2(2200, 160), false, 30.0)
	for frame in range(180): u._phys_body(1.0 / 60.0)
	evidence.move = {"frames": 180, "distance": u.position.distance_to(start), "path_calls": map.calls, "cap": u._group_cap}
	check(absf(u.position.distance_to(start) - 90.0) < 0.01, "ordinary 3-second march retains 30px/s group speed")
	check(map.calls == 1 and u._group_cap == 30.0, "ordinary progress does not trigger watchdog repathing")
	var before: int = map.calls
	u._last_pos = u.position
	u._stuck_t = 0.0
	for frame in range(91): u._movement_watchdog(1.0 / 60.0)
	check(map.calls == before + 1 and u._group_cap == 30.0, "genuine 1.5-second stall repaths and retains group cap")
	u._begin_amove(Vector2(2200, 160), true)
	u._resume_amove = true
	u._state = unit_script.ST_CHASE
	u._target = null
	u._do_chase(1.0 / 60.0)
	check(u._state == unit_script.ST_AMOVE and u._group_cap == 30.0, "attack-move resumes after combat without losing group cap")
	u.free()
	map.free()
	completed.append("movement")

func _patrol_cases() -> void:
	var map = _map(true)
	var u = _unit(map, Vector2(160, 500))
	u.order_patrol(Vector2(2000, 500))
	u._group_cap = 30.0
	for frame in range(180): u._phys_body(1.0 / 60.0)
	evidence.patrol = {"frames": 180, "path_calls": map.calls, "retry": u._move_retry, "wait": u._repath}
	check(map.calls <= 8 and map.calls >= 4, "unreachable patrol is bounded across three seconds")
	check(u.position == Vector2(160, 500) and u._patrolling, "unreachable patrol waits without fabricating movement")
	for y in range(30): map.set_cell_t(40, y, map_script.T.GRASS)
	map.bake()
	for frame in range(180): u._phys_body(1.0 / 60.0)
	check(u.position.x > 175.0 and u._group_cap == 30.0, "patrol resumes after route opens and keeps group cap")
	u.order_stop()
	for y in range(30): map.set_cell_t(40, y, map_script.T.CLIFF)
	map.bake()
	u.order_patrol(Vector2(2000, 500))
	for frame in range(8): u._phys_body(1.0 / 60.0)
	u.order_move(Vector2(96, 500), true)
	u._phys_body(1.0 / 60.0)
	check(not u._patrolling and u._state == unit_script.ST_MOVE and u._home == Vector2(96, 500), "failed patrol does not block queued withdrawal")
	u.free()
	map.free()
	completed.append("patrol")

func _cast_cases() -> void:
	var owner_script = _compile("extends \"res://scripts/battle.gd\"\nvar receipts := 0\nfunc _do_ability(_caster: Unit, _slot: int, _point: Vector2, _target: Unit = null) -> void:\n\treceipts += 1\n")
	var b = owner_script.new()
	var map = _map()
	b.map = map
	b._abilities = {"qa_queue": {"targeted": true, "target": "point", "cast_windup": 0.2, "effect": {"cast_range": 100.0}}}
	var u = _unit(map, Vector2(160, 300))
	u.battle = b
	u.is_hero = true
	u.ability_slots = [{"id": "qa_queue", "rank": 1, "passive": false, "cd_t": 0.0, "charges": 0, "recharge_t": 0.0, "cast_seq": 0}]
	b.units = [u]
	var retreat := Vector2(100, 300)
	b._begin_cast(u, 0, u.position)
	var serial: int = u._cast_serial
	var order_serial: int = u._order_serial
	u.order_move(retreat, true)
	check(u._cast_t > 0.0 and u._cast_serial == serial and u._order_serial == order_serial \
		and u._queue.size() == 1 and u._state == unit_script.ST_IDLE, "Shift move preserves active windup and replacement serial")
	for frame in range(30):
		u._phys_body(1.0 / 60.0)
		b._tick_pending_casts()
	check(b.receipts == 1 and u._state == unit_script.ST_MOVE and u._home == retreat, "windup settles exactly once before queued movement begins")
	u.order_stop()
	u.position = Vector2(160, 300)
	b._queue_walk_cast_point(u, 0, Vector2(480, 300))
	b._walk_cast_pass(1.0 / 60.0)
	order_serial = u._order_serial
	u.order_move(retreat, true)
	var preserved_at_windup := false
	for frame in range(420):
		b._walk_cast_pass(1.0 / 60.0)
		if u._cast_t > 0.0: preserved_at_windup = preserved_at_windup or u._queue.size() == 1
		u._phys_body(1.0 / 60.0)
		b._tick_pending_casts()
	check(preserved_at_windup and b.receipts == 2 and u._home == retreat and u._order_serial == order_serial, "walk-cast replans and transfers to windup without eating queued withdrawal")
	u.order_stop()
	u.position = Vector2(160, 300)
	b._queue_walk_cast_point(u, 0, Vector2(480, 300))
	b._walk_cast_pass(1.0 / 60.0)
	u.order_stop()
	b._walk_cast_pass(1.0 / 60.0)
	check(b._walk_casts.is_empty() and u._state == unit_script.ST_IDLE and b.receipts == 2, "explicit Stop cancels walk-cast intent")
	# Detached state-machine fixtures avoid UI cancellation messages; the scene suite
	# below exercises the player-facing branches with a real HUD and real deaths.
	u.faction = unit_script.FACTION_GUAN
	for reason in ["dead target", "freed target", "timeout", "unready slot", "nonfinite point"]:
		u.order_stop()
		u.position = Vector2(160, 300)
		u.ability_slots[0].cd_t = 0.0
		var target = _unit(map, Vector2(480, 300))
		if reason in ["dead target", "freed target"]:
			b._queue_walk_cast(u, 0, target)
		else:
			b._queue_walk_cast_point(u, 0, target.position)
		order_serial = u._order_serial
		u.order_move(retreat, true, 24.0)
		u.order_move(Vector2(96, 160), true, 18.0)
		match reason:
			"dead target": target.hp = 0.0
			"freed target": target.free()
			"timeout": b._walk_casts[0].age = 15.0
			"unready slot": u.ability_slots[0].cd_t = 1.0
			"nonfinite point": b._walk_casts[0].point = Vector2.INF
		b._walk_cast_pass(1.0 / 60.0)
		check(b._walk_casts.is_empty() and u._state == unit_script.ST_MOVE and u._home == retreat \
			and u._queue.size() == 1 and u._group_cap == 24.0 and u._order_serial == order_serial \
			and u.position == Vector2(160, 300) and b.receipts == 2,
			"walk-cast %s immediately hands off Shift retreat without executing or losing its queue" % reason)
		if is_instance_valid(target): target.free()
	u.order_stop()
	u.ability_slots[0].cd_t = 0.0
	b._queue_walk_cast_point(u, 0, Vector2(480, 300))
	var stale_serial: int = u._order_serial
	u.order_move(Vector2(160, 450), false, 25.0)
	u.order_move(retreat, true)
	var new_path: PackedVector2Array = u._path.duplicate()
	order_serial = u._order_serial
	b._walk_casts[0].age = 16.0
	b._walk_cast_pass(1.0 / 60.0)
	check(b._walk_casts.is_empty() and u._path == new_path and u._home == Vector2(160, 450) \
		and u._queue.size() == 1 and u._group_cap == 25.0 and u._order_serial == order_serial \
		and not u.finish_action_move(stale_serial), "stale cast serial never stops a newer explicit move or its Shift queue")
	u.order_stop()
	b._queue_walk_cast_point(u, 0, Vector2(480, 300))
	b._walk_casts[0].age = 16.0
	b._walk_cast_pass(1.0 / 60.0)
	check(b._walk_casts.is_empty() and u._state == unit_script.ST_IDLE and u._path.is_empty() \
		and u._home == u.position and not u.manual_order_active, "cancelled approach without a queue stops at its current position")
	# A brand-new cast remains a replacement command; preserving a queue is opt-in.
	u.order_move(Vector2(400, 300))
	u.order_move(Vector2(600, 300), true)
	u.begin_cast_windup(0.2, Color.WHITE)
	check(u._queue.is_empty(), "new immediate cast still replaces previous movement queue")
	# A blocked approach can exhaust its path before Battle's 15-second deadline.
	# It then waits in IDLE under the busy latch; cancellation must clear that
	# old home anchor too, not make Defend resume the cancelled route next frame.
	for y in range(30): map.set_cell_t(40, y, map_script.T.CLIFF)
	map.bake()
	for queued in [false, true]:
		u.order_stop()
		u.position = Vector2(160, 300)
		b._queue_walk_cast_point(u, 0, Vector2(2000, 300))
		if queued: u.order_move(retreat, true, 24.0)
		for frame in range(5): u._phys_body(1.0 / 60.0)
		check(u._state == unit_script.ST_IDLE and u._action_queue_busy(),
			"blocked approach naturally reaches an idle busy wait (queued=%s)" % queued)
		b._walk_casts[0].age = 16.0
		b._walk_cast_pass(1.0 / 60.0)
		if queued:
			check(u._state == unit_script.ST_MOVE and u._home == retreat and u._queue.is_empty() \
				and u._group_cap == 24.0, "timeout during idle approach wait immediately hands off Shift retreat")
		else:
			check(u._state == unit_script.ST_IDLE and u._home == u.position and u._path.is_empty() \
				and not u.manual_order_active, "timeout during idle approach wait clears the cancelled home anchor")
	u.free()
	b.units.clear()
	b.free()
	map.free()
	completed.append("cast")

func _cargo_cases() -> void:
	var b = battle_script.new()
	var map = _map()
	b.map = map
	b.gold = 0
	b.wood = 0
	var worker = _unit(map)
	worker.battle = b
	worker.is_worker = true
	var depot = _unit(map)
	depot.is_building = true
	depot.setup_def = {"drop_off": true}
	var wood = _unit(map, Vector2(500, 160))
	wood.is_resource = true
	wood.is_building = true
	wood.res_kind = "wood"
	wood.res_left = 1000.0
	var gold = _unit(map, Vector2(500, 320))
	gold.is_resource = true
	gold.is_building = true
	gold.res_kind = "gold"
	gold.res_left = 1000.0
	b.units = [worker, depot, wood, gold]
	worker._carry_amt = 10.0
	worker._carry_kind = "gold"
	worker.order_gather(wood)
	check(worker._state == unit_script.ST_RETURN and worker._carry_kind == "gold" and worker._gather_node == wood, "switch gold to wood deposits existing gold first")
	worker._do_return(1.0 / 60.0)
	check(b.gold == 10 and b.wood == 0 and worker._carry_amt == 0.0 \
		and worker._carry_kind == "wood" and worker._state == unit_script.ST_GATHER, "gold cargo is not converted and new wood target resumes")
	worker._carry_amt = 10.0
	worker._carry_kind = "wood"
	worker.order_gather(gold)
	worker._do_return(1.0 / 60.0)
	check(b.gold == 10 and b.wood == 5 and worker._carry_kind == "gold", "wood cargo keeps wood conversion rate before gold collection")
	b.units.erase(depot)
	worker._carry_amt = 7.0
	worker._carry_kind = "wood"
	worker.order_gather(gold)
	check(worker._carry_amt == 7.0 and worker._carry_kind == "wood" and worker._state == unit_script.ST_IDLE, "missing depot preserves old cargo without changing type")
	for node in [worker, depot, wood, gold]: node.free()
	b.units.clear()
	b.free()
	map.free()
	completed.append("cargo")

func _separation_cases() -> void:
	var b = battle_script.new()
	var map = _map()
	b.map = map
	var a = _unit(map, Vector2(160, 160))
	var c = _unit(map, Vector2(170, 160))
	a.entity_id = 1
	c.entity_id = 2
	a.radius = 11.0
	c.radius = 11.0
	a.order_hold_position()
	c.order_move(Vector2(600, 160))
	b.units = [a, c]
	b._grid_build()
	b._separation_pass(1.0 / 60.0)
	var direct := [a.position, c.position]
	var holding_displacement: float = a.position.distance_to(Vector2(160, 160))
	evidence.hold = {"holding_displacement": holding_displacement, "moving_displacement": c.position.distance_to(Vector2(170, 160))}
	check(holding_displacement > 0.0 and holding_displacement < 0.5 \
		and a.position.distance_to(c.position) >= 23.99, "Hold gives way slightly while moving friend resolves almost all overlap")
	a.position = Vector2(160, 160)
	c.position = Vector2(170, 160)
	b._grid_build()
	load("res://scripts/crowd_separation.gd").solve(b.units, b._mob_grid, map, b.GRID_CELL)
	check(a.position.is_equal_approx(direct[0]) and c.position.is_equal_approx(direct[1]), "buffered and direct separation use identical Hold priorities")
	a.position = Vector2(160, 160)
	c.position = Vector2(170, 160)
	c.order_hold_position()
	b._grid_build()
	b._separation_pass(1.0 / 60.0)
	check(a.position.distance_to(c.position) >= 23.99 and a.position.x < 160.0 and c.position.x > 170.0, "two holding units can still resolve overlap instead of hard-locking")
	var crossing_results := []
	for buffered in [false, true]:
		a.position = Vector2(320, 300)
		c.position = Vector2(160, 300)
		c.stance = unit_script.STANCE_PASSIVE
		c.order_move(Vector2(600, 300))
		var max_side := 0.0
		for frame in range(300):
			c._phys_body(1.0 / 60.0)
			b._grid_build()
			if buffered:
				load("res://scripts/crowd_separation.gd").solve(b.units, b._mob_grid, map, b.GRID_CELL)
			else:
				b._separation_pass(1.0 / 60.0)
			max_side = maxf(max_side, absf(c.position.y - 300.0))
		crossing_results.append({"holder": a.position, "mover": c.position, "side": max_side})
		check(c.position.x > 360.0 and max_side > 10.0 and a.position.distance_to(Vector2(320, 300)) < 5.0,
			"head-on friend passes Hold without pushing it away (%s)" % ("buffered" if buffered else "direct"))
	check(crossing_results[0].holder.is_equal_approx(crossing_results[1].holder) \
		and crossing_results[0].mover.is_equal_approx(crossing_results[1].mover), "head-on traversal agrees between direct and buffered separation")
	evidence.hold_crossing = crossing_results
	a.position = Vector2(320, 300)
	c.position = Vector2(300, 300)
	c.order_move(Vector2(600, 300))
	c.faction = 1
	var radial := Vector2(296, 300)
	check(unit_script.separation_yield_position(c,c.position,a,a.position,radial,4.0,map) == radial,
		"Hold sidestep never grants enemy phasing")
	c.faction = a.faction
	a.position = Vector2(320, 319.5)
	c.position = Vector2(300, 319.5)
	c.order_move(Vector2(600, 319.5))
	map.set_cell_t(9, 10, map_script.T.CLIFF)
	map.bake()
	var safe_side: Vector2 = unit_script.separation_yield_position(c,c.position,a,a.position,Vector2(296,319.5),4.0,map)
	check(safe_side.y < 320.0 and map._segment_open(c.position,safe_side,c.movement_profile),
		"Hold sidestep remains on navigable side of a cliff")
	a.free()
	c.free()
	b.units.clear()
	b.free()
	map.free()
	completed.append("separation")

func _camera_cases() -> void:
	var cam = load("res://scripts/rts_camera.gd").new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 4000
	cam.limit_bottom = 3000
	root.add_child(cam)
	cam.set_process(false)
	for scale in [0.5, 1.1, 3.2]:
		cam.zoom = Vector2.ONE * scale
		cam.position = Vector2(9000, 1400)
		cam.clamp_to_limits()
		await process_frame
		var center: Vector2 = cam.view_center()
		check(cam.position.distance_to(center) < 0.1, "camera node and actual center agree at right limit zoom %s" % scale)
		cam.position.x -= 100.0
		cam.clamp_to_limits()
		await process_frame
		check(absf((cam.view_center().x - center.x) + 100.0) < 0.1, "reverse pan reacts immediately at zoom %s" % scale)
	cam.zoom = Vector2.ONE
	cam.position = Vector2(9000, 1400)
	cam.clamp_to_limits()
	cam._zoom_by(0.5)
	await process_frame
	check(cam.position.distance_to(cam.view_center()) < 0.1, "zooming out at an edge clamps the input center immediately")
	var start_center: Vector2 = cam.view_center()
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	cam._unhandled_input(middle)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(30, 0)
	cam._unhandled_input(drag)
	await process_frame
	check(absf(cam.view_center().x - start_center.x + 30.0 / cam.zoom.x) < 0.1,
		"real middle-drag input reverses immediately from the clamped edge")
	cam.free()
	completed.append("camera")

func _run() -> void:
	if OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1" \
		or not OS.get_user_data_dir().contains("LSH-"):
		push_error("Requires STEAM_DISABLED=1 CAMPAIGN_QA=1 and a private LSH user directory")
		quit(2)
		return
	print("[foundation] profile=", OS.get_user_data_dir())
	AudioServer.set_bus_mute(0, true)
	unit_script = load("res://scripts/unit.gd")
	map_script = load("res://scripts/game_map.gd")
	battle_script = load("res://scripts/battle.gd")
	if not unit_script.can_instantiate() or not map_script.can_instantiate() or not battle_script.can_instantiate():
		push_error("Production scripts did not compile; regression suite did not run")
		quit(2)
		return
	counting_map_script = _compile("extends GameMap\nvar calls := 0\nfunc find_path(from_w: Vector2, to_w: Vector2, faction := 0, profile: String = \"land\") -> PackedVector2Array:\n\tcalls += 1\n\treturn super.find_path(from_w, to_w, faction, profile)\n")
	_movement_cases()
	_patrol_cases()
	_cast_cases()
	_cargo_cases()
	_separation_cases()
	await _camera_cases()
	check(completed.size() == 6, "all six runtime suites reached their final assertions")
	var report := {"schema": 1, "passed": failures.is_empty(), "checks": checks, "failures": failures, "evidence": evidence,
		"profile": OS.get_user_data_dir(), "scope": "Real production primitives; counted spell payload; not a full campaign playthrough"}
	var out := OS.get_environment("LSH_FOUNDATION_QA_OUT")
	if out.is_empty() and not OS.get_environment("LSH_RTS_QA_OUT").is_empty():
		out = OS.get_environment("LSH_RTS_QA_OUT").path_join("foundation-result.json")
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file == null:
			check(false, "write QA report")
		else:
			file.store_string(JSON.stringify(report, "\t"))
	print("[foundation] summary checks=", checks.size(), " failures=", failures.size(), " evidence=", JSON.stringify(evidence))
	quit(0 if failures.is_empty() else 1)
