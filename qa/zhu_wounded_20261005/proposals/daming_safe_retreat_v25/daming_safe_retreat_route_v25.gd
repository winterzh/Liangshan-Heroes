extends RefCounted
## External unexecuted skeleton. Fixed existing Battle calls; never constructs saves.
## A qualified runner supplies profile/content guard, check, hold, save/install audits.
const ADMISSION := "daming_admit"
const FIRE := "daming_fire"
const GATE := "daming_gate"
const RESCUE := "daming_rescue"
const ROLES := ["lu", "shi"]
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
	while Time.get_ticks_msec() - local_start < limit_ms and Time.get_ticks_msec() - started_ms < ROUTE_LIMIT_MS:
		await driver.get_tree().process_frame
		if not _fight(b): return _check(label + " fight remains healthy", false, observe(b))
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
	return true

func _crew(b: Node) -> Array:
	return b.units.filter(func(u): return _alive(u) and u.faction == 0 and not u.is_noncombat and not u.is_building and u.key in level_script.FIELD_KEYS)

func _action_done(b: Node, key: String) -> bool:
	return b.mission.actions.has(key) and b.mission.actions[key].done and b.mission.has_event("action:" + b.mission.stage_id + ":" + key)

func natural_rescue(b: Node) -> bool:
	if not _check("fresh actual admission start", _fight(b) and not b.level.prison_open and not b.level.rescued): return false
	if not _order(b, [b.level.yue], level_script.PRISON_CHECK + Vector2i(0, 1)): return false
	if not await _step_wait(b, "Yue disguised at admission", func(): return b.level._near(b, b.level.yue, level_script.PRISON_CHECK, 128.0) and b.level.yue._invis_t > 0.0): return false
	if not _order(b, [b.level.chai], level_script.PRISON_CHECK): return false
	if not await _step_wait(b, "real admission complete", func(): return b.level.prison_open and _action_done(b, ADMISSION) and b.mission.has_event("daming_prison_admitted")): return false
	if not _order(b, [b.level.chai, b.level.yue], level_script.PRISON_INSIDE): return false
	if not await _step_wait(b, "both inner actors ready", func(): return b.level._inside_prison(b, b.level.chai) and b.level._inside_prison(b, b.level.yue)): return false
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

func observe(b: Node) -> Dictionary:
	var out := {"phase": b.phase, "first_role": first_role, "orders": commands.size(), "logical_tick": str(b._run_clock._next_tick), "events": b.mission.events.duplicate(true), "report": b.mission.report.duplicate(true), "rescued": b.level.rescued, "gate_open": b.level.gate_open, "prison_open": b.level.prison_open, "actors": {}, "failure": failure}
	for role: String in ROLES:
		var u: Variant = b.level.get(role)
		out.actors[role] = {"exists": is_instance_valid(u)}
		if is_instance_valid(u):
			out.actors[role].merge({"id": str(u.entity_id), "hp": u.hp, "dying": u._dying, "outcome": u.story_outcome, "position": [u.position.x, u.position.y], "in_root": u.get_parent() == b.units_root, "active": b.units.has(u), "selected": b.selection.has(u), "visible": u.visible})
	return out
