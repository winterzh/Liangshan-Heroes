extends RefCounted
## Candidate v26: ordinary paid house/guards preserve the camp while rescue proceeds.
## Original v25 route remains immutable. No enemy/HP/resource/time patch.
## External unexecuted skeleton. Fixed existing Battle calls; never constructs saves.
## A qualified runner supplies profile/content guard, check, hold, save/install audits.
const ADMISSION := "daming_admit"
const FIRE := "daming_fire"
const GATE := "daming_gate"
const RESCUE := "daming_rescue"
const ROLES := ["lu", "shi"]
const CAMP_GUARD_KEYS := ["wu_yong", "liang_dao"]
const ROUTE_LIMIT_MS := 900000
var driver: Node
var level_script: Script
var first_role := ""
var started_ms := 0
var commands: Array = []
var checkpoint_ticks: Dictionary = {}
var failure := ""

func configure(runner: Node, role: String) -> Dictionary:
	if not is_instance_valid(runner) or role not in ROLES:
		return {"ok": false, "code": "RETREAT_QA_CONFIG"}
	for method: String in ["check", "_hold", "_healthy", "_release_and_run"]:
		if not runner.has_method(method): return {"ok": false, "code": "RETREAT_QA_RUNNER_" + method}
	driver = runner
	first_role = role
	level_script = load("res://scripts/levels/level8_daming_rts.gd")
	started_ms = Time.get_ticks_msec()
	return {"ok": true, "executed": false, "first_role": first_role}

func _check(label: String, condition: bool, detail: Variant = null) -> bool:
	if not condition and failure.is_empty(): failure = label
	return driver.check(label, condition, detail)

func _alive(u: Variant) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and not u._dying and u.story_outcome == ""

func _fight(b: Node) -> bool:
	return driver._healthy(b) and b.level.get_script() == level_script

func _step_wait(b: Node, label: String, predicate: Callable, limit_ms: int = 180000) -> bool:
	var local_start := Time.get_ticks_msec()
	var next_sample: int = local_start
	while Time.get_ticks_msec() - local_start < limit_ms and Time.get_ticks_msec() - started_ms < ROUTE_LIMIT_MS:
		await driver.get_tree().process_frame
		if not _fight(b): return _check(label + " fight remains healthy", false, observe(b))
		if label == "prison approach clear" and Time.get_ticks_msec() >= next_sample:
			driver.observations.append({"prison_approach_sample":observe(b)})
			next_sample = Time.get_ticks_msec()+15000
		if predicate.call():
			checkpoint_ticks[label] = {"logical_tick": str(b._run_clock._next_tick), "physics": Engine.get_physics_frames(), "msec": Time.get_ticks_msec()}
			return true
	return _check(label + " natural deadline", false, observe(b))

func _order(b: Node, members: Array, cell: Vector2i, attack_move := false) -> bool:
	if not _check("route order idle unpaused", _fight(b) and not driver.get_tree().paused and not Engine.is_in_physics_frame() and b._save_barrier.state == b._save_barrier.State.IDLE): return false
	if not _check("route movers all actually alive", not members.is_empty() and members.all(func(u): return _alive(u))): return false
	b.select_members(members, false)
	b.minimap_order(b.map.cell_to_world(cell), attack_move)
	commands.append({"ids": members.map(func(u): return str(u.entity_id)), "cell": [cell.x, cell.y], "attack_move": attack_move, "logical_tick": str(b._run_clock._next_tick)})
	if cell == level_script.PRISON_CHECK:
		driver.observations.append({"prison_order_after":members.map(func(u): return _motion_state(b,u))})
	return true

func _crew(b: Node) -> Array:
	return b.units.filter(func(u): return _alive(u) and u.faction == 0 and not u.is_noncombat and not u.is_building and (u.key in level_script.FIELD_KEYS or u.key == "siege_cata") and u.key not in CAMP_GUARD_KEYS)

func _prepare_camp_defense(b: Node) -> bool:
	var cell: Vector2i = level_script.CAMP + Vector2i(-3, -1)
	if not _check("original strategist alive for camp guard", _alive(b.level.strategist)): return false
	if not _order(b, [b.level.strategist], cell, true): return false
	var builders: Array = b.level.workers.filter(func(u): return _alive(u)).slice(0, 2)
	if not _check("two original workers build paid camp house", builders.size() == 2 and _fight(b) and not Engine.is_in_physics_frame()): return false
	var house_cell := Vector2i(-1, -1)
	var half: int = b.building_footprint_half("house")
	for offset: Vector2i in [Vector2i(5, 3), Vector2i(5, 4), Vector2i(6, 3), Vector2i(6, 4), Vector2i(7, 3), Vector2i(4, 5), Vector2i(5, 5)]:
		var candidate: Vector2i = level_script.CAMP + offset
		if b.building_terrain_valid("house", candidate) and not b._building_overlap(candidate, half) and not b._resource_overlap(candidate, half):
			house_cell = candidate
			break
	if not _check("ordinary house preview finds valid camp placement", house_cell != Vector2i(-1, -1)): return false
	var prior_cap: int = b.pop_cap
	var prior_ids: Array = b.units.map(func(u): return u.entity_id)
	var before_gold: float = b.gold
	var before_wood: float = b.wood
	var cost: Dictionary = b._defs.house
	b.select_members(builders, false)
	b.arm_build("house")
	b._try_place_building(b.to_screen(b.map.cell_to_world(house_cell)))
	var houses: Array = b.units.filter(func(u): return _alive(u) and u.faction == 0 and u.key == "house" and u.entity_id not in prior_ids and b.map.world_to_cell(u.position) == house_cell)
	if not _check("ordinary build API creates one paid house site", houses.size() == 1 and houses[0].is_constructing and b.gold == before_gold - int(cost.cost_gold) and b.wood == before_wood - int(cost.cost_wood)): return false
	commands.append({"kind":"player_build", "attack_move":false, "key":"house", "ids":builders.map(func(u): return str(u.entity_id)), "cell":[house_cell.x, house_cell.y], "gold":int(cost.cost_gold), "wood":int(cost.cost_wood), "logical_tick":str(b._run_clock._next_tick)})
	var house: Node = houses[0]
	if not await _step_wait(b, "paid camp house completes normally", func(): return _alive(house) and not house.is_constructing and b.pop_cap == prior_cap + int(cost.provides_pop), 90000): return false
	var barracks: Array = b.units.filter(func(u): return _alive(u) and u.faction == 0 and u.key == "barracks" and not u.is_constructing)
	if not _check("original camp barracks exists", barracks.size() == 1): return false
	var building: Node = barracks[0]
	b.select_members([building], false)
	# Player clicks use the rendered point and the terrain inverse projection.
	# unproject uses a bounded height search, so the flat logical point need not
	# equal the resulting player command target. Assert the exact API target and
	# the original destination cell, retaining selection/production prerequisites.
	var rally_logic: Vector2 = b.map.cell_to_world(cell)
	var rally_screen: Vector2 = b.to_screen(rally_logic)
	var expected_rally: Vector2 = b.to_logic(rally_screen)
	b.minimap_order(rally_logic, false)
	var rally_detail := {"selected":b.selection.has(building), "produces":building.setup_def.has("produces"), "has_rally":building.has_rally, "requested":[rally_logic.x,rally_logic.y], "screen":[rally_screen.x,rally_screen.y], "api_target":[expected_rally.x,expected_rally.y], "actual":[building.rally.x,building.rally.y], "height_field":b.map.height_field != null}
	if not _check("normal building order sets camp rally", b.selection.has(building) and building.setup_def.has("produces") and building.has_rally and building.rally == expected_rally and b.map.world_to_cell(building.rally) == cell, rally_detail): return false
	commands.append({"kind":"player_rally", "attack_move":false, "ids":[str(building.entity_id)], "cell":[cell.x, cell.y], "logical_tick":str(b._run_clock._next_tick)})
	var soldier_cost: Dictionary = b._defs.liang_dao
	for index in range(4):
		before_gold = b.gold
		before_wood = b.wood
		var queue_before: int = building._train_queue.size()
		var paid: bool = b.queue_train(building, "liang_dao")
		if not _check("normal paid camp guard queue %d" % index, paid and building._train_queue.size() == queue_before + 1 and b.gold == before_gold - int(soldier_cost.cost_gold) and b.wood == before_wood - int(soldier_cost.cost_wood)): return false
		commands.append({"kind":"player_train", "attack_move":false, "ids":[str(building.entity_id)], "cell":[cell.x, cell.y], "key":"liang_dao", "building_id":str(building.entity_id), "gold":int(soldier_cost.cost_gold), "wood":int(soldier_cost.cost_wood), "logical_tick":str(b._run_clock._next_tick)})
	return _check("camp guard keys are excluded from assault and escort", _crew(b).all(func(u): return u.key not in CAMP_GUARD_KEYS) and _crew(b).size() >= 3)

func _action_done(b: Node, key: String) -> bool:
	return b.mission.actions.has(key) and b.mission.actions[key].done and b.mission.has_event("action:" + b.mission.stage_id + ":" + key)

func natural_rescue(b: Node) -> bool:
	if not _check("fresh actual admission start", _fight(b) and not b.level.prison_open and not b.level.rescued): return false
	if not _gather_camp_workers(b): return false
	if not _order(b, _crew(b), level_script.CAMP + Vector2i(-2,-2), true): return false
	if not await _prepare_camp_defense(b): return false
	if not _order(b, [b.level.yue], level_script.PRISON_CHECK + Vector2i(0, 1)): return false
	if not await _step_wait(b, "Yue disguised at admission", func(): return b.level._near(b, b.level.yue, level_script.PRISON_CHECK, 128.0) and b.level.yue._invis_t > 0.0): return false
	if not _order(b, [b.level.chai], level_script.PRISON_CHECK): return false
	if not await _step_wait(b, "real admission complete", func(): return b.level.prison_open and _action_done(b, ADMISSION) and b.mission.has_event("daming_prison_admitted")): return false
	if not _order(b, [b.level.chai, b.level.yue], level_script.PRISON_INSIDE): return false
	if not await _step_wait(b, "both inner actors ready", func(): return b.level._inside_prison(b, b.level.chai) and b.level._inside_prison(b, b.level.yue)): return false
	# Establish the ordinary prison admission before the long paid training queue.
	# Both inner actors remain at the actual prison while the army is prepared.
	if not await _prepare_paid_assault(b): return false
	if not _order(b, [b.level.scout], level_script.FIRE_CELL): return false
	if not await _step_wait(b, "real fire complete", func(): return b.level.signaled and _action_done(b, FIRE) and b.mission.has_event("daming_fire_lit") and b.mission.actions.has(GATE)): return false
	var crew := _crew(b)
	if not _check("real field crew includes gate hero and two friends", crew.size() >= 3 and crew.any(func(u): return u.key in ["lu_zhishen", "wu_song"])): return false
	if not _order(b, crew, level_script.GATE_APPROACH, true): return false
	if not await _step_wait(b, "gate resistance cleared", func(): return not b.level._guarded(b, level_script.GATE_APPROACH, 150.0) and _crew(b).filter(func(u): return b.level._near(b, u, level_script.GATE_APPROACH, 180.0)).size() >= 3): return false
	# A real attack may have breached the gate already; preserve that story result.
	if not b.level.gate_open:
		var hero: Array = _crew(b).filter(func(u): return u.key in ["lu_zhishen", "wu_song"])
		if not _check("gate hero survives actual clearing", not hero.is_empty()): return false
		if not _order(b, [hero[0]], level_script.GATE_APPROACH): return false
		if not await _step_wait(b, "real gate action complete", func(): return b.level.gate_open and b.mission.has_event("daming_gate_opened")): return false
	if not _order(b, _crew(b), level_script.PRISON_CHECK, true): return false
	if not await _step_wait(b, "prison approach clear", func(): return not b.level._guarded(b, level_script.PRISON_CHECK, 160.0)): return false
	if not _order(b, _crew(b), level_script.JAIL_ACTION, true): return false
	if not await _step_wait(b, "jail action resistance clear", func(): return not b.level._guarded(b, level_script.JAIL_ACTION, 120.0)): return false
	if not _order(b, [b.level.chai], level_script.JAIL_ACTION): return false
	if not await _step_wait(b, "real rescue complete", func(): return b.level.rescued and _action_done(b, RESCUE) and b.mission.has_event("daming_prisoners_freed")): return false
	return _check("both rescued alive naturally", _alive(b.level.lu) and _alive(b.level.shi) and not b.level.lu.is_captive and not b.level.shi.is_captive)

func first_exit_and_hold(b: Node) -> bool:
	var first: Node = b.level.get(first_role)
	var other_role: String = "shi" if first_role == "lu" else "lu"
	var other: Node = b.level.get(other_role)
	if not _check("first exit begins rescued FIGHT with other alive", _fight(b) and b.level.rescued and b.level.gate_open and _alive(first) and _alive(other)): return false
	# Other actor receives no exit order. Combat survival is a real route condition.
	if not _order(b, _crew(b), level_script.EXIT_CELL, true): return false
	if not _order(b, [first], level_script.EXIT_CELL): return false
	if not await _step_wait(b, "first actual safety callback completed", func(): return first.story_outcome == "retreated" and b.mission.has_event("daming_" + first_role + "_safe")): return false
	# Observe only after completed physics; signal itself preceded Mission.mark.
	driver.get_tree().paused = true
	if not await driver._hold(b, "single retreat first completed physics"): return false
	return _check("single safe full state HELD", single_safe_valid(b), observe(b))

func single_safe_valid(b: Node) -> bool:
	var other_role: String = "shi" if first_role == "lu" else "lu"
	var first: Node = b.level.get(first_role)
	var other: Node = b.level.get(other_role)
	return _fight(b) and b.level.rescued and b.level.prison_open and b.level.gate_open and _alive(other) and first.story_outcome == "retreated" and first.hp >= 1.0 and not first._dying and b.units.has(first) and b.units.has(other) and first.get_parent() == b.units_root and other.get_parent() == b.units_root and not b.selection.has(first) and b.mission.has_event("daming_" + first_role + "_safe") and not b.mission.has_event("daming_" + other_role + "_safe") and not b.mission.has_event("daming_victory") and _stopped(first)

func _stopped(u: Node) -> bool:
	return not u.visible and not u.selected and u.passive and u.stance == 3 and u._queue.is_empty() and u._path.is_empty() and not u._patrolling and u._target == null and u._hua_lock_target == null and u._hua_lock_shots == 0 and not u._resume_amove and u._chase_intent == 0 and u._group_cap == 0.0 and u._home == u.position and u._has_home and u._state == 0 and u._pending_target == null and u._pending_done and u._lunge == 0.0 and u._cast_t == 0.0 and not u._stepped and u._move_blend == 0.0

func finish_other_naturally(b: Node) -> bool:
	if not _check("independent restored single-safe state", single_safe_valid(b), observe(b)): return false
	if not driver._release_and_run(b): return false
	var other_role: String = "shi" if first_role == "lu" else "lu"
	var other: Node = b.level.get(other_role)
	if not _order(b, _crew(b), level_script.EXIT_CELL, true): return false
	if not _order(b, [other], level_script.EXIT_CELL): return false
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		await driver.get_tree().process_frame
		if b.phase == b.Phase.END: break
		if not _fight(b): return _check("final escort remains healthy", false, observe(b))
	if not _check("actual Level natural victory state", b.phase == b.Phase.END and b.mission.has_event("daming_lu_safe") and b.mission.has_event("daming_shi_safe") and b.mission.has_event("daming_victory") and b.level.lu.story_outcome == "retreated" and b.level.shi.story_outcome == "retreated", observe(b)): return false
	var flow: Node = driver.get_node("/root/ContinueFlow")
	deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await driver.get_tree().process_frame
		if flow.last_result.get("terminal_completed", false) or flow.last_result.get("terminal_pending", false): break
	return _check("actual durable local terminal completes before outcome claim", flow.last_result.get("ok", false) and flow.last_result.get("terminal_completed", false) and flow.last_result.get("local_terminal", false) and is_instance_valid(b._continue_receipt) and b._steam_run_id == 0, flow.last_result)

func _motion_state(b: Node, u: Variant) -> Dictionary:
	if not is_instance_valid(u): return {"exists":false}
	var points: Array = []
	for point in u._path: points.append([point.x,point.y])
	var value := {"exists":true,"id":str(u.entity_id),"key":u.key,"hp":u.hp,"position":[u.position.x,u.position.y],"state":u._state,"path":points,"path_i":u._path_i,"home":[u._home.x,u._home.y],"amove_destination":[u._amove_dest.x,u._amove_dest.y],"queued":u._queue.size(),"serial":u._order_serial,"manual_active":u.manual_order_active,"mission_active":u.mission_order_active,"root_time":u._root_t,"stun_time":u._stun_t,"stuck_time":u._stuck_t,"move_retry":u._move_retry}
	var target = u._target
	value.target = {"exists":is_instance_valid(target)}
	if is_instance_valid(target): value.target.merge({"id":str(target.entity_id),"key":target.key,"hp":target.hp,"position":[target.position.x,target.position.y]})
	if u._path_i >= 0 and u._path_i < u._path.size():
		var waypoint: Vector2 = u._path[u._path_i]
		value.waypoint = {"position":[waypoint.x,waypoint.y],"map_open":b.map._segment_open(u.position,waypoint,u.movement_profile)}
	return value

func observe(b: Node) -> Dictionary:
	var spies: Dictionary = {}
	for pair in [["chai",b.level.chai],["yue",b.level.yue],["scout",b.level.scout]]:
		var actor = pair[1]
		spies[pair[0]] = {"exists":is_instance_valid(actor),"hp":actor.hp,"invis":actor._invis_t,"position":[actor.position.x,actor.position.y],"outcome":actor.story_outcome,"state":actor._state,"target":[actor.mission_order_target.x,actor.mission_order_target.y],"mission_order":actor.mission_order_active,"manual_order":actor.manual_order_active} if is_instance_valid(actor) else {"exists":false}
	var out := {"phase": b.phase, "first_role": first_role, "orders": commands.size(), "logical_tick": str(b._run_clock._next_tick), "events": b.mission.events.duplicate(true), "report": b.mission.report.duplicate(true), "rescued": b.level.rescued, "gate_open": b.level.gate_open, "prison_open": b.level.prison_open, "actors": {}, "failure": failure}
	out["spies"] = spies
	out.camp = {"exists":is_instance_valid(b.level.hall)}
	if is_instance_valid(b.level.hall): out.camp.merge({"hp":b.level.hall.hp, "dying":b.level.hall._dying, "outcome":b.level.hall.story_outcome})
	out.assault = _crew(b).map(func(u): return _motion_state(b,u))
	out.prison_guards = b.units.filter(func(u): return _alive(u) and u.faction == 1 and not u.is_resource and b.level._near(b,u,level_script.PRISON_CHECK,160.0)).map(func(u): return {"motion":_motion_state(b,u),"segment_open":b.map._segment_open(u.position,b.map.cell_to_world(level_script.PRISON_CHECK))})
	out.camp_guards = b.units.filter(func(u): return _alive(u) and u.faction == 0 and u.key in CAMP_GUARD_KEYS).map(func(u): return {"id":str(u.entity_id), "key":u.key, "hp":u.hp, "position":[u.position.x, u.position.y]})
	out.end_title = b.hud._end_title.text
	out.end_sub = b.hud._end_sub.text
	for role: String in ROLES:
		var u: Variant = b.level.get(role)
		out.actors[role] = {"exists": is_instance_valid(u)}
		if is_instance_valid(u):
			out.actors[role].merge({"id": str(u.entity_id), "hp": u.hp, "dying": u._dying, "outcome": u.story_outcome, "position": [u.position.x, u.position.y], "in_root": u.get_parent() == b.units_root, "active": b.units.has(u), "selected": b.selection.has(u), "visible": u.visible})
	return out

func _paid_build(b: Node, key: String) -> Node:
	var cost: Dictionary = b._defs[key]
	if not await _step_wait(b, key + " real gathered build budget", func(): return b.gold >= int(cost.cost_gold) and b.wood >= int(cost.cost_wood)): return null
	var builders: Array = b.level.workers.filter(func(u): return _alive(u)).slice(0,2)
	if not _check(key + " two living original builders", builders.size() == 2 and not Engine.is_in_physics_frame()): return null
	var site := Vector2i(-1,-1)
	var half: int = b.building_footprint_half(key)
	for y in range(0,9):
		for x in range(4,11):
			var candidate: Vector2i = level_script.CAMP + Vector2i(x,y)
			if b.building_terrain_valid(key,candidate) and not b._building_overlap(candidate,half) and not b._resource_overlap(candidate,half):
				site = candidate
				break
		if site != Vector2i(-1,-1): break
	if not _check(key + " normal legal camp preview", site != Vector2i(-1,-1)): return null
	var ids: Array = b.units.map(func(u): return u.entity_id)
	var gold: float = b.gold
	var wood: float = b.wood
	b.select_members(builders,false)
	b.arm_build(key)
	b._try_place_building(b.to_screen(b.map.cell_to_world(site)))
	var created: Array = b.units.filter(func(u): return _alive(u) and u.key == key and u.faction == 0 and u.entity_id not in ids and b.map.world_to_cell(u.position) == site)
	if not _check(key + " ordinary API creates paid site", created.size() == 1 and created[0].is_constructing and b.gold == gold-int(cost.cost_gold) and b.wood == wood-int(cost.cost_wood)): return null
	commands.append({"kind":"player_build","attack_move":false,"ids":builders.map(func(u): return str(u.entity_id)),"key":key,"cell":[site.x,site.y],"gold":int(cost.cost_gold),"wood":int(cost.cost_wood),"logical_tick":str(b._run_clock._next_tick)})
	var building: Node = created[0]
	if not await _step_wait(b,key + " completes on ordinary clock",func(): return _alive(building) and not building.is_constructing,90000): return null
	return building

func _gather_camp_workers(b: Node) -> bool:
	var workers: Array = b.level.workers.filter(func(u): return _alive(u))
	var worker_details: Array = b.level.workers.map(func(u): return {"id":str(u.entity_id),"hp":u.hp,"dying":u._dying,"outcome":u.story_outcome,"position":[u.position.x,u.position.y]} if is_instance_valid(u) else {"exists":false})
	if not _check("six surviving workers resume ordinary harvesting",workers.size() == 6,worker_details): return false
	for index in range(workers.size()):
		var kind: String = "gold" if index < 3 else "wood"
		var resources: Array = b.units.filter(func(u): return is_instance_valid(u) and u.is_resource and u.res_kind == kind and u.res_left > 0 and b.map.world_to_cell(u.position).x >= level_script.CAMP.x)
		resources.sort_custom(func(a,c): return workers[index].position.distance_squared_to(a.position) < workers[index].position.distance_squared_to(c.position))
		var node: Node = resources[0] if not resources.is_empty() else null
		if not _check("actual camp resource available",is_instance_valid(node) and node.is_resource): return false
		if not _order(b,[workers[index]],b.map.world_to_cell(node.position),false): return false
	return true

func _paid_queue(b: Node, building: Node, key: String) -> bool:
	if not await _step_wait(b,key + " ordinary train preconditions",func(): return _alive(building) and b._train_block_reason(building,key).is_empty()): return false
	var cost: Dictionary = b._defs[key]
	var gold: float = b.gold
	var wood: float = b.wood
	var prior: int = building._train_queue.size()
	var queued: bool = b.queue_train(building,key)
	if not _check(key + " actual paid production queued",queued and building._train_queue.size() == prior+1 and b.gold == gold-int(cost.cost_gold) and b.wood == wood-int(cost.cost_wood)): return false
	var cell: Vector2i = b.map.world_to_cell(building.position)
	commands.append({"kind":"player_train","attack_move":false,"ids":[str(building.entity_id)],"key":key,"cell":[cell.x,cell.y],"gold":int(cost.cost_gold),"wood":int(cost.cost_wood),"logical_tick":str(b._run_clock._next_tick)})
	return true

func _camp_rally(b: Node, building: Node) -> bool:
	var cell: Vector2i = level_script.CAMP + Vector2i(-2,-2)
	var logic: Vector2 = b.map.cell_to_world(cell)
	var expected: Vector2 = b.to_logic(b.to_screen(logic))
	b.select_members([building],false)
	b.minimap_order(logic,false)
	if not _check("paid producer actual camp rally",b.selection.has(building) and building.has_rally and building.rally == expected and b.map.world_to_cell(building.rally) == cell): return false
	commands.append({"kind":"player_rally","attack_move":false,"ids":[str(building.entity_id)],"cell":[cell.x,cell.y],"logical_tick":str(b._run_clock._next_tick)})
	return true

func _prepare_paid_assault(b: Node) -> bool:
	if not _gather_camp_workers(b): return false
	var cap: int = b.pop_cap
	var house: Node = await _paid_build(b,"house")
	if not _check("second paid house grants actual population",is_instance_valid(house) and b.pop_cap == cap+int(b._defs.house.provides_pop)): return false
	var workshop: Node = await _paid_build(b,"siege_workshop")
	if not _check("real completed siege workshop",is_instance_valid(workshop)): return false
	if not _gather_camp_workers(b): return false
	var barracks: Array = b.units.filter(func(u): return _alive(u) and u.faction == 0 and u.key == "barracks" and not u.is_constructing)
	if not _check("one original assault producer",barracks.size() == 1): return false
	var producer: Node = barracks[0]
	if not _camp_rally(b,producer) or not _camp_rally(b,workshop): return false
	for index in range(2):
		if not await _paid_queue(b,workshop,"siege_cata"): return false
	for index in range(12):
		if not await _paid_queue(b,producer,"liang_qiang" if index%2 == 0 else "liang_gong"): return false
	if not await _step_wait(b,"all paid assault queues finish on real clock",func(): return producer._train_queue.is_empty() and workshop._train_queue.is_empty(),360000): return false
	return _check("surviving actual siege and reinforced field crew",_crew(b).filter(func(u): return u.key == "siege_cata").size() == 2 and _crew(b).size() >= 16,observe(b))
