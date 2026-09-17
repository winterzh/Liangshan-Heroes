extends RefCounted
## Isolated logical physics phase. No Engine reads, wall time or random draws.
## The world scheduler must call begin/end exactly once around every complete step.
const SCHEMA := "run_simulation_clock_v1"
const HZ := 60
const MAX_NEXT := 9223372036854775807
var _next_tick := 0
var _tick := -1
var _initialized := false
var _in_step := false
var _completed := false
var _fault := ""

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func initialize_new(first_tick: int = 0) -> Dictionary:
	if _initialized: return _bad("CLOCK_ALREADY_INITIALIZED")
	if first_tick < 0 or first_tick >= MAX_NEXT: return _bad("CLOCK_INITIAL_TICK")
	_next_tick = first_tick
	_tick = first_tick - 1
	_initialized = true
	return {"ok": true}

func begin_step() -> Dictionary:
	if not _initialized: return _bad("CLOCK_NOT_INITIALIZED")
	if not _fault.is_empty(): return _bad(_fault)
	if _in_step: return _bad("CLOCK_STEP_ALREADY_OPEN")
	if _next_tick >= MAX_NEXT:
		abort_step("CLOCK_EXHAUSTED")
		return _bad(_fault)
	_tick = _next_tick
	_in_step = true
	return {"ok": true, "tick": _tick}

func end_step() -> Dictionary:
	if not _fault.is_empty(): return _bad(_fault)
	if not _in_step: return _bad("CLOCK_NO_OPEN_STEP")
	_next_tick = _tick + 1
	_in_step = false
	_completed = true
	return {"ok": true, "tick": _tick}

func abort_step(code: String) -> void:
	if _fault.is_empty(): _fault = code if not code.is_empty() else "CLOCK_STEP_ABORTED"
	_in_step = false

func frame() -> int:
	return _tick

func in_step() -> bool:
	return _in_step

func fault() -> String:
	return _fault

func capture() -> Dictionary:
	if not _initialized or not _completed: return _bad("CLOCK_NO_COMPLETED_STEP")
	if not _fault.is_empty(): return _bad(_fault)
	if _in_step: return _bad("CLOCK_STEP_OPEN")
	return {"ok": true, "record": {"schema": SCHEMA, "physics_hz": HZ, "next_tick": str(_next_tick)}}

func validate(record: Variant) -> Dictionary:
	if typeof(record) != TYPE_DICTIONARY or record.size() != 3: return _bad("CLOCK_RECORD_FIELDS")
	for key: Variant in record:
		if typeof(key) != TYPE_STRING or key not in ["schema", "physics_hz", "next_tick"]: return _bad("CLOCK_RECORD_FIELDS")
	if record.schema != SCHEMA: return _bad("CLOCK_SCHEMA")
	# JSON parses numbers as floats. Only this exact small integral value is allowed.
	if typeof(record.physics_hz) not in [TYPE_INT, TYPE_FLOAT] or record.physics_hz != HZ: return _bad("CLOCK_HZ")
	if typeof(record.next_tick) != TYPE_STRING: return _bad("CLOCK_TICK_TEXT")
	var value: String = record.next_tick
	if value.is_empty() or value.length() > 19 or value.begins_with("0"): return _bad("CLOCK_TICK_TEXT")
	for character: String in value:
		if character < "0" or character > "9": return _bad("CLOCK_TICK_TEXT")
	if value.length() == 19 and value > "9223372036854775807": return _bad("CLOCK_TICK_RANGE")
	return {"ok": true, "next_tick": int(value)}

func restore(record: Variant) -> Dictionary:
	if _initialized: return _bad("CLOCK_ALREADY_INITIALIZED")
	var result: Dictionary = validate(record)
	if not result.ok: return result
	_next_tick = result.next_tick
	_tick = _next_tick - 1
	_initialized = true
	_completed = true
	return {"ok": true}
