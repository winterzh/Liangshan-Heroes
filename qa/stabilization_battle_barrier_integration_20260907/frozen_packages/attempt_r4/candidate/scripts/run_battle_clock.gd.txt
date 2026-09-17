extends RefCounted
## Explicit complete-step serial plus the legacy cache-frame phase.
## Engine counters enter only as a local anchor; saved phase never depends on
## matching the new process's modulo. No delta scaling or RNG is performed.
const SCHEMA := "battle_simulation_clock_v1"
const MAX_INT := 9223372036854775807
var _next_tick := 0
var _tick := -1
var _cache_frame := 0
var _engine_anchor := 0
var _initialized := false
var _completed := false
var _in_step := false
var _held := false
var _fault := ""

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func initialize_new(engine_frame: int) -> Dictionary:
	if _initialized: return _bad("CLOCK_ALREADY_INITIALIZED")
	if engine_frame < 0: return _bad("CLOCK_ENGINE_FRAME")
	_cache_frame = engine_frame
	_engine_anchor = engine_frame
	_initialized = true
	return {"ok": true}

func observe_cache_frame(engine_frame: int) -> int:
	if not _initialized or not _fault.is_empty(): return -1
	if _held: return _cache_frame
	if engine_frame < _engine_anchor:
		abort_step("CLOCK_ENGINE_FRAME_REGRESSED")
		return -1
	var advance := engine_frame - _engine_anchor
	if advance > MAX_INT - _cache_frame:
		abort_step("CLOCK_CACHE_EXHAUSTED")
		return -1
	_cache_frame += advance
	_engine_anchor = engine_frame
	return _cache_frame

func begin_step() -> Dictionary:
	if not _initialized: return _bad("CLOCK_NOT_INITIALIZED")
	if not _fault.is_empty(): return _bad(_fault)
	if _held: return _bad("CLOCK_CAPTURE_HELD")
	if _in_step: return _bad("CLOCK_STEP_ALREADY_OPEN")
	if _next_tick >= MAX_INT:
		abort_step("CLOCK_STEPS_EXHAUSTED")
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
	return {"ok": true}

func abort_step(code: String) -> void:
	if _fault.is_empty(): _fault = code if not code.is_empty() else "CLOCK_STEP_ABORTED"
	_in_step = false

func in_step() -> bool:
	return _in_step

func fault() -> String:
	return _fault

func freeze_cache(engine_frame: int) -> Dictionary:
	if _held: return _bad("CLOCK_ALREADY_HELD")
	if _in_step: return _bad("CLOCK_STEP_OPEN")
	if not _completed: return _bad("CLOCK_NO_COMPLETED_STEP")
	if observe_cache_frame(engine_frame) < 0: return _bad(_fault)
	_held = true
	return {"ok": true}

func release_source_hold(engine_frame: int) -> Dictionary:
	if not _held: return _bad("CLOCK_NOT_HELD")
	if not _fault.is_empty(): return _bad(_fault)
	# The original process must retain its original paused-frame cache behavior.
	# Its anchor was deliberately not advanced while reading the frozen snapshot.
	_held = false
	if observe_cache_frame(engine_frame) < 0: return _bad(_fault)
	return {"ok": true}

func activate_restored(engine_frame: int) -> Dictionary:
	if not _initialized or not _held or not _fault.is_empty(): return _bad("CLOCK_RESTORE_ACTIVATION_STATE")
	if engine_frame < 0: return _bad("CLOCK_ENGINE_FRAME")
	# Loading time belongs to neither the saved world nor its first resumed step.
	_engine_anchor = engine_frame
	_held = false
	return {"ok": true}

func capture() -> Dictionary:
	if not _initialized or not _completed: return _bad("CLOCK_NO_COMPLETED_STEP")
	if not _fault.is_empty(): return _bad(_fault)
	if _in_step or not _held: return _bad("CLOCK_STABLE_CAPTURE_REQUIRED")
	return {"ok": true, "record": {"schema": SCHEMA, "physics_hz": 60,
		"next_tick": str(_next_tick), "cache_frame": str(_cache_frame)}}

func _decimal(value: Variant, allow_zero: bool) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 19: return false
	if value == "0": return allow_zero
	if value.begins_with("0"): return false
	for character: String in value:
		if character < "0" or character > "9": return false
	return value.length() < 19 or value <= "9223372036854775807"

func validate(record: Variant) -> Dictionary:
	if typeof(record) != TYPE_DICTIONARY or record.size() != 4: return _bad("CLOCK_RECORD_FIELDS")
	for key: Variant in record:
		if typeof(key) != TYPE_STRING or key not in ["schema", "physics_hz", "next_tick", "cache_frame"]: return _bad("CLOCK_RECORD_FIELDS")
	if record.schema != SCHEMA: return _bad("CLOCK_SCHEMA")
	if typeof(record.physics_hz) not in [TYPE_INT, TYPE_FLOAT] or record.physics_hz != 60: return _bad("CLOCK_HZ")
	if not _decimal(record.next_tick, false) or not _decimal(record.cache_frame, true): return _bad("CLOCK_INTEGER_TEXT")
	return {"ok": true, "next_tick": int(record.next_tick), "cache_frame": int(record.cache_frame)}

func restore(record: Variant, engine_frame: int) -> Dictionary:
	if _initialized: return _bad("CLOCK_ALREADY_INITIALIZED")
	if engine_frame < 0: return _bad("CLOCK_ENGINE_FRAME")
	var checked: Dictionary = validate(record)
	if not checked.ok: return checked
	_next_tick = checked.next_tick
	_tick = _next_tick - 1
	_cache_frame = checked.cache_frame
	_engine_anchor = engine_frame
	_initialized = true
	_completed = true
	_held = true
	return {"ok": true}
