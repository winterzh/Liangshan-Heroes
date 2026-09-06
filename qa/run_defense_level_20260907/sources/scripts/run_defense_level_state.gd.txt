extends RefCounted
## Standard 30-wave Level state only. The outer transaction owns Battle,
## Campaign options, the live Unit graph, shared identity and activation.
## No deployment, on_start, wave generation, UI refresh or random draw occurs here.
const SCHEMA := "standard_defense_level_v1"
const VALUE_FIELDS := ["_wave", "_wave_t", "_wave_spawned", "_started",
	"_final_cleanup_last_alive", "_final_cleanup_last_hp", "_final_cleanup_quiet",
	"_final_cleanup_tick", "_final_cleanup_active", "_wavelist_cache"]
const PAYLOAD_FIELDS := ["values", "hall", "cleanup_positions"]
const MAX_UNITS := 4096
var _codec: Variant = null
var _level_script: Script
var _unit_script: Script

func _init(codec_script: Script, level_script: Script, unit_script: Script) -> void:
	_level_script = level_script
	_unit_script = unit_script
	for script: Script in [codec_script, level_script, unit_script]:
		if script == null or not script.can_instantiate(): return
	_codec = codec_script.new()

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _fields(value: Variant, expected: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != expected.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

func _version(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= 256

func _unit(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) \
		and value.get_script() == _unit_script and not value.is_queued_for_deletion()

func _hall(value: Variant) -> bool:
	return _unit(value) and value.key == "hall" and value.faction == 0 and value.is_building and not value.is_resource

func _id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 19: return false
	if value.unicode_at(0) < 49 or value.unicode_at(0) > 57: return false
	for index in range(1, value.length()):
		if value.unicode_at(index) < 48 or value.unicode_at(index) > 57: return false
	return value.length() < 19 or value <= "9223372036854775807"

func _values(values: Variant) -> Dictionary:
	if not _fields(values, VALUE_FIELDS): return _bad("VALUE_FIELDS")
	for field in ["_wave", "_final_cleanup_last_alive"]:
		if typeof(values[field]) != TYPE_INT: return _bad("VALUE_INTEGER")
	for field in ["_wave_t", "_final_cleanup_last_hp", "_final_cleanup_quiet", "_final_cleanup_tick"]:
		if typeof(values[field]) != TYPE_FLOAT or not is_finite(values[field]): return _bad("VALUE_FLOAT")
	for field in ["_wave_spawned", "_started", "_final_cleanup_active"]:
		if typeof(values[field]) != TYPE_BOOL: return _bad("VALUE_BOOLEAN")
	if not values._started or values._wave < 0 or values._wave > 30: return _bad("STARTED_STANDARD_RUN_REQUIRED")
	if values._wave_spawned != (values._wave > 0): return _bad("WAVE_PROGRESS")
	if values._wave < 30 and (values._wave_t <= 0.0 or values._wave_t > float(_level_script.WAVES[values._wave]["t"])):
		return _bad("WAVE_TIMER_RANGE")
	if values._wave == 30 and values._wave_t > 0.0: return _bad("FINAL_WAVE_TIMER")
	if values._final_cleanup_last_alive < -1 or values._final_cleanup_last_alive > MAX_UNITS \
		or values._final_cleanup_last_hp < -1.0 or values._final_cleanup_quiet < 0.0 \
		or values._final_cleanup_tick < 0.0 or values._final_cleanup_tick > _level_script.FINAL_CLEANUP_STEP:
		return _bad("CLEANUP_VALUE_RANGE")
	if (values._final_cleanup_last_alive == -1) != (values._final_cleanup_last_hp == -1.0): return _bad("CLEANUP_SENTINEL")
	if values._wave < 30 and (values._final_cleanup_last_alive != -1 or values._final_cleanup_quiet != 0.0 \
		or values._final_cleanup_tick != 0.0 or values._final_cleanup_active): return _bad("CLEANUP_BEFORE_FINAL")
	# Use the trusted class constant, never call _waves (which can generate RNG).
	var canonical: Dictionary = _codec.encode(_level_script.WAVES)
	var received: Dictionary = _codec.encode(values._wavelist_cache)
	if not received.ok or not canonical.ok or received.value != canonical.value:
		return _bad("STANDARD_THIRTY_WAVES_REQUIRED")
	return {"ok": true}

func _identity(callback: Callable, value: Variant, needs_value: bool) -> Dictionary:
	if not callback.is_valid(): return _bad("IDENTITY_CALLBACK")
	var result: Variant = callback.call(value)
	if typeof(result) != TYPE_DICTIONARY or typeof(result.get("ok")) != TYPE_BOOL: return _bad("IDENTITY_RESULT")
	if not result.ok: return _bad("IDENTITY_REJECTED")
	if needs_value and not result.has("value"): return _bad("IDENTITY_RESULT")
	return result

func _target(token: Variant, known: Dictionary) -> bool:
	if not _fields(token, ["kind", "id"]) or typeof(token.kind) != TYPE_STRING or typeof(token.id) != TYPE_STRING: return false
	if token.kind == "entity": return _id(token.id) and known.has(token.id)
	if token.kind == "retired": return token.id.begins_with("r:") and _id(token.id.substr(2))
	return false

func capture(level: Variant, content_version: String, object_to_id: Dictionary,
		encode_unit_id: Callable) -> Dictionary:
	if _codec == null: return _bad("MODULE_CONFIGURATION")
	if not _version(content_version): return _bad("CONTENT_VERSION")
	if typeof(level) != TYPE_OBJECT or not is_instance_valid(level) or level.get_script() != _level_script: return _bad("LEVEL_INSTANCE")
	if not encode_unit_id.is_valid(): return _bad("IDENTITY_ENCODER")
	if object_to_id.size() > MAX_UNITS: return _bad("REGISTRY_LIMIT")
	var known: Dictionary = {}
	for unit in object_to_id:
		if not _unit(unit) or not _id(object_to_id[unit]) or known.has(object_to_id[unit]): return _bad("REGISTRY")
		known[object_to_id[unit]] = true
	if not _hall(level.hall) or not object_to_id.has(level.hall): return _bad("HALL_REFERENCE")
	var values: Dictionary = {}
	for field in VALUE_FIELDS: values[field] = level.get(field)
	var checked: Dictionary = _values(values)
	if not checked.ok: return checked
	if typeof(level._final_cleanup_positions) != TYPE_DICTIONARY or level._final_cleanup_positions.size() > MAX_UNITS: return _bad("POSITION_LIMIT")
	if level._final_cleanup_last_alive == -1 and not level._final_cleanup_positions.is_empty(): return _bad("UNSAMPLED_POSITIONS")
	var positions: Array = []
	var seen: Array = []
	for native_id in level._final_cleanup_positions:
		var position: Variant = level._final_cleanup_positions[native_id]
		if typeof(native_id) != TYPE_INT or native_id <= 0: return _bad("POSITION_ID")
		if typeof(position) != TYPE_VECTOR2 or not position.is_finite(): return _bad("POSITION_VALUE")
		var encoded: Dictionary = _identity(encode_unit_id, native_id, true)
		if not encoded.ok: return encoded
		if not _target(encoded.value, known): return _bad("POSITION_ID")
		if encoded.value in seen: return _bad("DUPLICATE_POSITION_ID")
		seen.append(encoded.value)
		positions.append({"target": encoded.value, "position": position})
	var payload: Dictionary = _codec.encode({"values": values, "hall": object_to_id[level.hall], "cleanup_positions": positions})
	if not payload.ok: return payload
	return {"ok": true, "record": {"schema": SCHEMA, "content_version": content_version, "payload": payload.value}}

func validate(record: Variant, content_version: String, known_unit_ids: Dictionary,
		validate_unit_id: Callable) -> Dictionary:
	if _codec == null: return _bad("MODULE_CONFIGURATION")
	if not _version(content_version): return _bad("CONTENT_VERSION")
	if not _fields(record, ["schema", "content_version", "payload"]): return _bad("RECORD_FIELDS")
	if typeof(record.schema) != TYPE_STRING or record.schema != SCHEMA: return _bad("SCHEMA")
	if typeof(record.content_version) != TYPE_STRING or record.content_version != content_version: return _bad("CONTENT_VERSION")
	if not validate_unit_id.is_valid(): return _bad("IDENTITY_VALIDATOR")
	if known_unit_ids.size() > MAX_UNITS: return _bad("REGISTRY_LIMIT")
	for key in known_unit_ids:
		if not _id(key): return _bad("REGISTRY")
	var decoded: Dictionary = _codec.decode(record.payload)
	if not decoded.ok: return decoded
	var payload: Variant = decoded.value
	if not _fields(payload, PAYLOAD_FIELDS): return _bad("PAYLOAD_FIELDS")
	var checked: Dictionary = _values(payload.values)
	if not checked.ok: return checked
	if not _id(payload.hall) or not known_unit_ids.has(payload.hall): return _bad("HALL_REFERENCE")
	if typeof(payload.cleanup_positions) != TYPE_ARRAY or payload.cleanup_positions.size() > MAX_UNITS: return _bad("POSITION_LIMIT")
	if payload.values._final_cleanup_last_alive == -1 and not payload.cleanup_positions.is_empty(): return _bad("UNSAMPLED_POSITIONS")
	var seen: Dictionary = {}
	for row in payload.cleanup_positions:
		if not _fields(row, ["target", "position"]): return _bad("POSITION_FIELDS")
		if typeof(row.position) != TYPE_VECTOR2 or not row.position.is_finite(): return _bad("POSITION_VALUE")
		if not _target(row.target, known_unit_ids): return _bad("POSITION_ID")
		var valid: Dictionary = _identity(validate_unit_id, row.target, false)
		if not valid.ok: return valid
		# A cleanup sample always identifies a live-at-sampling or retired Unit.
		var key: String = String(row.target.kind) + ":" + String(row.target.id)
		if seen.has(key): return _bad("DUPLICATE_POSITION_ID")
		seen[key] = true
	return {"ok": true, "value": payload, "complete_battle": false}

func restore(record: Variant, content_version: String, id_to_unit: Dictionary,
		validate_unit_id: Callable, decode_unit_id: Callable) -> Dictionary:
	if not decode_unit_id.is_valid(): return _bad("IDENTITY_DECODER")
	var known: Dictionary = {}
	var objects: Dictionary = {}
	for key in id_to_unit:
		if not _id(key) or not _unit(id_to_unit[key]) or objects.has(id_to_unit[key]): return _bad("REGISTRY")
		known[key] = true
		objects[id_to_unit[key]] = true
	var checked: Dictionary = validate(record, content_version, known, validate_unit_id)
	if not checked.ok: return checked
	if not _hall(id_to_unit[checked.value.hall]): return _bad("HALL_IDENTITY")
	var positions: Dictionary = {}
	for row in checked.value.cleanup_positions:
		var decoded: Dictionary = _identity(decode_unit_id, row.target, true)
		if not decoded.ok or typeof(decoded.get("value")) != TYPE_INT or decoded.value <= 0:
			return _bad("IDENTITY_DECODE")
		if positions.has(decoded.value): return _bad("DUPLICATE_NATIVE_ID")
		positions[decoded.value] = row.position
	# Only a new RefCounted level is populated. Caller discards its private graph
	# on any error and releases shared retired-ID tombstones after all bindings.
	var level: Variant = _level_script.new()
	for field in VALUE_FIELDS: level.set(field, checked.value.values[field])
	level.hall = id_to_unit[checked.value.hall]
	level._final_cleanup_positions = positions
	return {"ok": true, "level": level, "complete_battle": false,
		"tombstone_release_owned_by_caller": true, "deploy_or_start_called": false}
