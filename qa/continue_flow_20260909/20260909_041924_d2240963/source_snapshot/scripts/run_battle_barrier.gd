extends Node
## Actual classic-defense capture gate. Still a candidate until native world QA.
## Capture remains synchronous; the host owns complete schema and disk commit.
signal capture_ready(clock_record: Dictionary)
signal capture_rejected(code: String)
enum State { IDLE, REQUESTED, DRAINING, HELD }
var world: Variant
var clock: Variant
var state := State.IDLE
var _was_paused := false
var _held_clock := false
var _saved_ui: Array = []
var _saved_camera: Dictionary = {}

class Edge extends Node:
	var gate: Variant
	var first := false
	func _physics_process(_delta: float) -> void:
		if first: gate._begin()
		else: gate._end()

func configure(battle: Variant, simulation_clock: Variant) -> void:
	world = battle
	clock = simulation_clock

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
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not world.is_inside_tree(): return {"ok": false, "code": "WORLD_UNAVAILABLE"}
	if not world.gameplay_rng_fault().is_empty(): return {"ok": false, "code": "BATTLE_FAULT"}
	if int(world.phase) != 2 or not world.economy: return {"ok": false, "code": "CLASSIC_FIGHT_REQUIRED"}
	if world._official_context.get("mode", "") != "defense" or int(world._official_context.get("waves", 0)) != 30: return {"ok": false, "code": "CLASSIC_30_REQUIRED"}
	if world.level == null or world.level.get_script().resource_path != "res://scripts/levels/skirmish.gd": return {"ok": false, "code": "CLASSIC_LEVEL_REQUIRED"}
	if world.mission != null or world.ai_friendly or world._smoke or world._prof_on or world._no_opt: return {"ok": false, "code": "UNSUPPORTED_CAPTURE_ENVIRONMENT"}
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
	var stack: Array = [world.hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
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
	for row in _saved_ui:
		if is_instance_valid(row.node):
			row.node.set_block_signals(row.blocked)
			row.node.process_mode = row.mode
	_saved_ui.clear()
	if not _saved_camera.is_empty() and is_instance_valid(_saved_camera.node):
		_saved_camera.node.process_mode = _saved_camera.mode
		_saved_camera.node.set_process_unhandled_input(_saved_camera.input)
	_saved_camera.clear()
	state = State.IDLE
	get_tree().paused = _was_paused
	return {"ok": true}

func _exit_tree() -> void:
	if get_tree().process_frame.is_connected(_idle_boundary): get_tree().process_frame.disconnect(_idle_boundary)
