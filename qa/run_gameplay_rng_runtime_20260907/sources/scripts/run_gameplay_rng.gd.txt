extends RefCounted
## An owned native RNG stream. No global random calls and no Battle integration.
const Codec = preload("res://scripts/run_state_value_codec.gd")
const MODULE_CONTRACT_VERSION := 1
const CODEC_CONTRACT_VERSION := 1
const I64_MAX := 9223372036854775807
const I32_MIN := -2147483648
const I32_MAX := 2147483647
const FLOAT_BOUND := 1.0e30 # Deliberately below native float32 overflow, including subtraction.
const RECORD_FIELDS := ["kind", "version", "compat", "seed", "state", "calls"]
const COMPAT_FIELDS := ["engine_binary_sha256", "engine_version", "engine_hash", "os", "real_t_bits", "content_version", "module_contract_version", "codec_contract_version"]
var _codec = Codec.new()
var _rng: RandomNumberGenerator
var _calls: int = 0
var _compat: Dictionary = {}
var _trusted_content_version: Variant

func _init(trusted_content_version: Variant) -> void:
	# Root supplies a trusted build/content identity, never one copied from the save.
	_trusted_content_version = trusted_content_version

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return true

func _sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for code in value.to_utf8_buffer():
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true

func compatibility(engine_binary_sha256: Variant) -> Dictionary:
	# The host must measure its actual executable. Source files need not exist in a PCK.
	if not _sha(engine_binary_sha256): return _bad("ENGINE_BINARY_ID")
	if typeof(_trusted_content_version) != TYPE_STRING: return _bad("CONTENT_VERSION")
	var content: String = _trusted_content_version
	if content.strip_edges().is_empty() or content.length() > 256:
		return _bad("CONTENT_VERSION")
	var version: Dictionary = Engine.get_version_info()
	if typeof(version.get("string")) != TYPE_STRING or String(version.string).is_empty() \
		or typeof(version.get("hash")) != TYPE_STRING or String(version.hash).is_empty():
		return _bad("ENGINE_VERSION")
	return {"ok": true, "code": "OK", "value": {
		"engine_binary_sha256": engine_binary_sha256, "engine_version": version.string,
		"engine_hash": version.hash, "os": OS.get_name(),
		"real_t_bits": 64 if Vector2(16777217.0, 0.0).x == 16777217.0 else 32,
		"content_version": content, "module_contract_version": MODULE_CONTRACT_VERSION,
		"codec_contract_version": CODEC_CONTRACT_VERSION}}

func start(initial_seed: Variant, engine_binary_sha256: Variant) -> Dictionary:
	if _rng != null: return _bad("ALREADY_STARTED")
	if typeof(initial_seed) != TYPE_INT: return _bad("SEED_TYPE")
	var identity: Dictionary = compatibility(engine_binary_sha256)
	if not identity.ok: return identity
	var candidate := RandomNumberGenerator.new()
	candidate.seed = initial_seed
	if candidate.seed != initial_seed: return _bad("NATIVE_SEED_DOMAIN")
	_rng = candidate
	_calls = 0
	_compat = identity.value
	return {"ok": true, "code": "OK"}

func capture() -> Dictionary:
	if _rng == null: return _bad("NOT_STARTED")
	var encoded: Dictionary = _codec.encode({"kind": "godot-gameplay-rng", "version": 2,
		"compat": _compat.duplicate(true), "seed": _rng.seed, "state": _rng.state, "calls": _calls})
	if not encoded.ok: return _bad("CODEC_" + encoded.code)
	return {"ok": true, "code": "OK", "record": encoded.value}

func validate_record(record: Variant, engine_binary_sha256: Variant) -> Dictionary:
	# Bounded codec traversal happens before any stringify or native object creation.
	var decoded: Dictionary = _codec.decode(record)
	if not decoded.ok: return _bad("CODEC_" + decoded.code)
	var value: Variant = decoded.value
	if not _fields(value, RECORD_FIELDS): return _bad("RECORD_FIELDS")
	if typeof(value.kind) != TYPE_STRING or value.kind != "godot-gameplay-rng": return _bad("KIND")
	if typeof(value.version) != TYPE_INT or value.version != 2: return _bad("VERSION")
	if not _fields(value.compat, COMPAT_FIELDS): return _bad("COMPAT_FIELDS")
	var identity: Dictionary = compatibility(engine_binary_sha256)
	if not identity.ok: return identity
	# Compare codec representation too: Dictionary equality alone may equate 32 with 32.0.
	var expected: Dictionary = _codec.encode(identity.value)
	var received: Dictionary = _codec.encode(value.compat)
	if not received.ok or received.value != expected.value: return _bad("COMPAT_MISMATCH")
	if typeof(value.seed) != TYPE_INT or typeof(value.state) != TYPE_INT: return _bad("RNG_INTEGER_TYPE")
	if typeof(value.calls) != TYPE_INT or value.calls < 0: return _bad("CALL_COUNT")
	return {"ok": true, "code": "OK", "value": value}

func restore(record: Variant, engine_binary_sha256: Variant) -> Dictionary:
	var checked: Dictionary = validate_record(record, engine_binary_sha256)
	if not checked.ok: return checked
	var value: Dictionary = checked.value
	var candidate := RandomNumberGenerator.new()
	# seed changes native state. Never reverse these assignments.
	candidate.seed = value.seed
	candidate.state = value.state
	if candidate.seed != value.seed or candidate.state != value.state: return _bad("NATIVE_INTEGER_DOMAIN")
	# Commit only after complete validation and native readback. Rejection preserves the old stream.
	_rng = candidate
	_calls = value.calls
	_compat = value.compat.duplicate(true)
	return {"ok": true, "code": "OK"}

func _ready_to_draw() -> String:
	if _rng == null: return "NOT_STARTED"
	if _calls == I64_MAX: return "CALL_COUNT_EXHAUSTED"
	return ""

func draw_randi() -> Dictionary:
	var issue: String = _ready_to_draw()
	if issue != "": return _bad(issue)
	var value: int = _rng.randi()
	_calls += 1
	return {"ok": true, "code": "OK", "value": value}

func draw_randf() -> Dictionary:
	var issue: String = _ready_to_draw()
	if issue != "": return _bad(issue)
	var value: float = _rng.randf()
	_calls += 1
	return {"ok": true, "code": "OK", "value": value}

func draw_randi_range(from: Variant, to: Variant) -> Dictionary:
	var issue: String = _ready_to_draw()
	if issue != "": return _bad(issue)
	if typeof(from) != TYPE_INT or typeof(to) != TYPE_INT: return _bad("INT_RANGE_TYPE")
	if from < I32_MIN or from > I32_MAX or to < I32_MIN or to > I32_MAX: return _bad("INT_RANGE_DOMAIN")
	var value: int = _rng.randi_range(from, to)
	_calls += 1 # Equal bounds count as one public call even when native state does not move.
	return {"ok": true, "code": "OK", "value": value}

func draw_randf_range(from: Variant, to: Variant) -> Dictionary:
	var issue: String = _ready_to_draw()
	if issue != "": return _bad(issue)
	# Explicit float API: migrate integer literals to floats at the call site.
	if typeof(from) != TYPE_FLOAT or typeof(to) != TYPE_FLOAT: return _bad("FLOAT_RANGE_TYPE")
	if not is_finite(from) or not is_finite(to) or absf(from) > FLOAT_BOUND or absf(to) > FLOAT_BOUND:
		return _bad("FLOAT_RANGE_DOMAIN")
	var value: float = _rng.randf_range(from, to)
	_calls += 1
	return {"ok": true, "code": "OK", "value": value}
