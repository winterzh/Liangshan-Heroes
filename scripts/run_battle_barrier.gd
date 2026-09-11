extends Node
## Complete-step capture gate. The host explicitly opts into an installed profile.
## Capture remains synchronous; the host owns complete schema and disk commit.
signal capture_ready(clock_record: Dictionary)
signal capture_rejected(code: String)
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Mission := preload("res://scripts/campaign_mission.gd")
enum State { IDLE, REQUESTED, DRAINING, HELD }
var world: Variant
var clock: Variant
var state := State.IDLE
var _was_paused := false
var _held_clock := false
var _saved_ui: Array = []
var _saved_camera: Dictionary = {}
var _capture_context: Dictionary = Profiles.CLASSIC_CONTEXT.duplicate(true)
var _context_error := ""

class Edge extends Node:
	var gate: Variant
	var first := false
	func _physics_process(_delta: float) -> void:
		if first: gate._begin()
		else: gate._end()

func configure(battle: Variant, simulation_clock: Variant,
		trusted_context: Dictionary = Profiles.CLASSIC_CONTEXT) -> void:
	world = battle
	clock = simulation_clock
	var selected: Dictionary = Profiles.normalize_context(trusted_context)
	_context_error = "" if selected.ok else "CAPTURE_CONTEXT_UNSUPPORTED"
	if selected.ok:
		if not Profiles._installed(selected.profile_id): _context_error = "CAPTURE_PROFILE_NOT_INSTALLED"
		_capture_context = selected.context.duplicate(true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var first := Edge.new()
	first.gate = self
	first.first = true
	first.process_physics_priority = -2147483648
	add_child(first)
	var last := Edge.new()
	last.gate = self
	last.process_physics_priority = 2147483647
	add_child(last)
	get_tree().process_frame.connect(_idle_boundary)

func input_closed() -> bool:
	return state != State.IDLE

func _begin() -> void:
	if get_tree().paused or not is_instance_valid(world) or not world.can_process() or not world.is_physics_processing(): return
	if Engine.physics_ticks_per_second != 60:
		clock.abort_step("CLOCK_HZ_CHANGED")
		return
	var result: Dictionary = clock.begin_step()
	if not result.ok: clock.abort_step(result.code)

func _end() -> void:
	if not clock.in_step(): return
	if get_tree().paused:
		clock.abort_step("PAUSED_DURING_STEP")
		return
	var result: Dictionary = clock.end_step()
	if not result.ok: clock.abort_step(result.code)

func _scope() -> Dictionary:
	if not _context_error.is_empty(): return {"ok": false, "code": _context_error}
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not world.is_inside_tree(): return {"ok": false, "code": "WORLD_UNAVAILABLE"}
	if not world.gameplay_rng_fault().is_empty(): return {"ok": false, "code": "BATTLE_FAULT"}
	if int(world.phase) != 2 or not world.economy: return {"ok": false, "code": "CLASSIC_FIGHT_REQUIRED"}
	if _capture_context == Profiles.CLASSIC_CONTEXT:
		if world._official_context.get("mode", "") != "defense" or int(world._official_context.get("waves", 0)) != 30: return {"ok": false, "code": "CLASSIC_30_REQUIRED"}
		if world.level == null or world.level.get_script().resource_path != "res://scripts/levels/skirmish.gd": return {"ok": false, "code": "CLASSIC_LEVEL_REQUIRED"}
		if world.mission != null: return {"ok": false, "code": "UNSUPPORTED_CAPTURE_ENVIRONMENT"}
	else:
		# Context is supplied by the installed host, never copied from a slot.
		# Selecting an official campaign chapter authorizes this boundary only.
		if not Profiles.is_official_campaign_context(_capture_context): return {"ok": false, "code": "CAMPAIGN_CAPTURE_CONTEXT"}
		if world.get_script() != preload("res://scripts/battle.gd") or world._official_context != _capture_context: return {"ok": false, "code": "CAMPAIGN_CAPTURE_CONTEXT"}
		var expected_script: Script = Profiles.level_script(Profiles.normalize_context(_capture_context).profile_id)
		if not is_instance_valid(world.level) or expected_script == null or world.level.get_script() != expected_script: return {"ok": false, "code": "CAMPAIGN_CAPTURE_LEVEL"}
		if not is_instance_valid(world.mission) or world.mission.get_script() != Mission: return {"ok": false, "code": "CAMPAIGN_CAPTURE_MISSION"}
	if world.ai_friendly or world._smoke or world._prof_on or world._no_opt: return {"ok": false, "code": "UNSUPPORTED_CAPTURE_ENVIRONMENT"}
	if Engine.physics_ticks_per_second != 60: return {"ok": false, "code": "CLOCK_HZ_CHANGED"}
	if not clock.fault().is_empty(): return {"ok": false, "code": clock.fault()}
	return {"ok": true}

func _close_input() -> void:
	# Finish uncommitted pointer gestures; already submitted orders stay intact.
	world.cancel_armed()
	world._dragging = false
	world._box_mode = false
	world._panning = false
	world._press_ms = 0
	world._last_tap_ms = 0
	world._last_group_time = 0
	var camera: Variant = world.camera
	_saved_camera = {"node": camera, "mode": camera.process_mode, "input": camera.is_processing_unhandled_input()}
	camera._mid_drag = false
	camera._touches.clear()
	camera._pinch_d = 0.0
	camera._pinch_mid = Vector2.ZERO
	camera.set_process_unhandled_input(false)
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	# HUD is normally ALWAYS. Disable its subtree and block every current signal
	# source, including direct Button.pressed routes into Battle commands.
	world.hud._release_run_pointer_state()
	_gate_new_ui()

func _gate_new_ui() -> void:
	# The final physics step and deferred callbacks can create Mission controls
	# after request_capture. Retain each node's original flags exactly once.
	var registered: Dictionary = {}
	for row: Dictionary in _saved_ui:
		if is_instance_valid(row.node): registered[row.node] = true
	var stack: Array = [world.hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if not registered.has(node):
			_saved_ui.append({"node": node, "blocked": node.is_blocking_signals(), "mode": node.process_mode})
			node.set_block_signals(true)
			node.process_mode = Node.PROCESS_MODE_DISABLED
		stack.append_array(node.get_children(true))

func request_capture() -> Dictionary:
	if state != State.IDLE: return {"ok": false, "code": "CAPTURE_ALREADY_REQUESTED"}
	var scoped := _scope()
	if not scoped.ok: return scoped
	if world.hud == null or world.camera == null: return {"ok": false, "code": "INPUT_SURFACES_UNAVAILABLE"}
	_was_paused = get_tree().paused
	state = State.REQUESTED
	_close_input()
	return {"ok": true}

func health() -> Dictionary:
	var scoped := _scope()
	if not scoped.ok: return scoped
	if not get_tree().paused or not input_closed(): return {"ok": false, "code": "CAPTURE_NOT_PAUSED"}
	if clock.in_step(): return {"ok": false, "code": "PHYSICS_STEP_STILL_OPEN"}
	if world._dragging or world._box_mode or world._panning or world.camera._mid_drag or not world.camera._touches.is_empty(): return {"ok": false, "code": "INPUT_NOT_RELEASED"}
	if world.hud.process_mode != Node.PROCESS_MODE_DISABLED or world.camera.process_mode != Node.PROCESS_MODE_DISABLED: return {"ok": false, "code": "INPUT_GATE_LOST"}
	var ui_stack: Array = [world.hud]
	while not ui_stack.is_empty():
		var ui: Node = ui_stack.pop_back()
		if ui.process_mode != Node.PROCESS_MODE_DISABLED or not ui.is_blocking_signals(): return {"ok": false, "code": "INPUT_GATE_LOST"}
		ui_stack.append_array(ui.get_children(true))
	var stack: Array = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == self: continue
		if node.is_queued_for_deletion(): return {"ok": false, "code": "QUEUED_WORLD_NODE"}
		if node.process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT: return {"ok": false, "code": "UNSUPPORTED_PROCESS_THREAD_GROUP"}
		if node.process_physics_priority in [-2147483648, 2147483647]: return {"ok": false, "code": "PHYSICS_EDGE_CONFLICT"}
		if node.can_process() and (node.is_processing() or node.is_physics_processing()): return {"ok": false, "code": "WORLD_STILL_PROCESSING"}
		stack.append_array(node.get_children(true))
	return {"ok": true}

func _idle_boundary() -> void:
	if state in [State.IDLE, State.HELD]: return
	if clock.in_step():
		_reject("PHYSICS_STEP_STILL_OPEN")
		return
	if not clock.fault().is_empty():
		_reject(clock.fault())
		return
	if state == State.REQUESTED:
		# All current physics callbacks have ended. The following paused frame
		# drains nested deferred calls and queued frees before the next boundary.
		get_tree().paused = true
		state = State.DRAINING
		return
	if is_instance_valid(world) and is_instance_valid(world.hud): _gate_new_ui()
	var status := health()
	if not status.ok:
		_reject(status.code)
		return
	var held: Dictionary = clock.freeze_cache(Engine.get_physics_frames())
	if not held.ok:
		_reject(held.code)
		return
	_held_clock = true
	var captured: Dictionary = clock.capture()
	if not captured.ok:
		_reject(captured.code)
		return
	state = State.HELD
	world._refresh_run_capture_presentation()
	capture_ready.emit(captured.record)

func _reject(code: String) -> void:
	get_tree().paused = true
	state = State.HELD
	capture_rejected.emit(code)

func release_capture() -> Dictionary:
	if state != State.HELD: return {"ok": false, "code": "CAPTURE_NOT_HELD"}
	if not clock.fault().is_empty(): return {"ok": false, "code": clock.fault()}
	if _held_clock:
		var released: Dictionary = clock.release_source_hold(Engine.get_physics_frames())
		if not released.ok: return released
		_held_clock = false
	_restore_input()
	state = State.IDLE
	get_tree().paused = _was_paused
	return {"ok": true}

func cancel_for_terminal() -> Dictionary:
	# A fight can end in the final physics step of a pending save request.
	# No world snapshot has been captured yet. Restore input only after that
	# step closes; the terminal coordinator retains the current pause state.
	if not is_instance_valid(world) or int(world.phase) != 3: return {"ok": false, "code": "TERMINAL_WORLD_REQUIRED"}
	if Engine.is_in_physics_frame() or clock.in_step(): return {"ok": false, "code": "TERMINAL_CAPTURE_STEP_OPEN"}
	if not clock.fault().is_empty(): return {"ok": false, "code": clock.fault()}
	if _held_clock: return {"ok": false, "code": "TERMINAL_CAPTURE_ALREADY_FROZEN"}
	_restore_input()
	state = State.IDLE
	return {"ok": true}

func _restore_input() -> void:
	for row in _saved_ui:
		if is_instance_valid(row.node):
			row.node.set_block_signals(row.blocked)
			row.node.process_mode = row.mode
	_saved_ui.clear()
	if not _saved_camera.is_empty() and is_instance_valid(_saved_camera.node):
		_saved_camera.node.process_mode = _saved_camera.mode
		_saved_camera.node.set_process_unhandled_input(_saved_camera.input)
	_saved_camera.clear()

func _exit_tree() -> void:
	if get_tree().process_frame.is_connected(_idle_boundary): get_tree().process_frame.disconnect(_idle_boundary)
