extends Node
## Experimental scheduler fixture adapter, NOT a completed Battle/save boundary.
## Callers own a real command gate and a health/deferred-work predicate.
signal capture_ready(clock_record: Dictionary)
signal capture_rejected(code: String)
signal input_gate_changed(closed: bool)
enum State { IDLE, REQUESTED, DRAINING, HELD }
var clock: Variant
var world: Node
var health: Callable
var input_released: Callable
var state := State.IDLE
var _was_paused := false
var _drain_frames := 0

class Edge extends Node:
	var controller: Variant
	var first := false
	func _physics_process(_delta: float) -> void:
		if first: controller._begin()
		else: controller._end()

func configure(p_world: Node, p_clock: Variant, p_health: Callable, p_input_released: Callable) -> void:
	world = p_world
	clock = p_clock
	health = p_health
	input_released = p_input_released

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var first := Edge.new()
	first.controller = self
	first.first = true
	first.process_physics_priority = -2147483648
	add_child(first)
	var last := Edge.new()
	last.controller = self
	last.process_physics_priority = 2147483647
	add_child(last)
	get_tree().process_frame.connect(_idle_boundary)

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

func request_capture() -> Dictionary:
	if state != State.IDLE: return {"ok": false, "code": "CAPTURE_ALREADY_REQUESTED"}
	if not health.is_valid() or not input_released.is_valid(): return {"ok": false, "code": "CAPTURE_GUARDS_REQUIRED"}
	if not clock.fault().is_empty(): return {"ok": false, "code": clock.fault()}
	_was_paused = get_tree().paused
	state = State.REQUESTED
	input_gate_changed.emit(true)
	return {"ok": true}

func _idle_boundary() -> void:
	if state == State.IDLE or state == State.HELD: return
	if clock.in_step():
		_reject("PHYSICS_STEP_STILL_OPEN")
		return
	if not clock.fault().is_empty():
		_reject(clock.fault())
		return
	if state == State.REQUESTED:
		# Entire current physics batch has ended; no capture in this frame.
		# The next process boundary follows this paused idle/deferred/free drain.
		get_tree().paused = true
		state = State.DRAINING
		_drain_frames = 0
		return
	_drain_frames += 1
	if not get_tree().paused:
		_reject("PAUSE_LOST_DURING_CAPTURE")
		return
	if not input_released.call():
		if _drain_frames >= 8: _reject("INPUT_GATE_NOT_RELEASED")
		return
	var status: Dictionary = health.call()
	if status.get("ok") != true:
		_reject(String(status.get("code", "WORLD_NOT_QUIESCENT")))
		return
	var captured: Dictionary = clock.capture()
	if not captured.ok:
		_reject(captured.code)
		return
	state = State.HELD
	# Synchronous read-only capture point before the new idle callbacks.
	capture_ready.emit(captured.record)

func _reject(code: String) -> void:
	get_tree().paused = true
	state = State.HELD
	capture_rejected.emit(code)

func release_capture() -> Dictionary:
	if state != State.HELD: return {"ok": false, "code": "CAPTURE_NOT_HELD"}
	if not clock.fault().is_empty(): return {"ok": false, "code": clock.fault()}
	state = State.IDLE
	input_gate_changed.emit(false)
	get_tree().paused = _was_paused
	return {"ok": true}

func _exit_tree() -> void:
	if get_tree().process_frame.is_connected(_idle_boundary): get_tree().process_frame.disconnect(_idle_boundary)
