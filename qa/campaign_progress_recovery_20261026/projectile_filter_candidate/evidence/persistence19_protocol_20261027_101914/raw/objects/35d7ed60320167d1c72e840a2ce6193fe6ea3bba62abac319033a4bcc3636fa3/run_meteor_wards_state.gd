extends RefCounted
## Meteor + ward authority only. Unit pools, _ward_serial and visual Nodes belong
## to the root transaction. Hit-ID callbacks must use the root's stable identity
## graph; expired Unit refs bind to live tombstones, freed only after all modules.
const SCHEMA := "defense_meteor_wards_v1"
const ARRAYS := ["_meteor_zones", "_wards"]
const FIELDS := {
	"_meteor_zones": ["pos", "dir", "remain", "speed", "hw", "foe", "caster", "ability_id", "impact", "dps", "dot_dur", "hit", "trail"],
	"_wards": ["pos", "r", "t", "pulse", "pulse_t", "aura_t", "mode", "ally", "foe", "caster", "ability_id", "heal", "dmg", "atkspeed", "banner_kind", "slow", "slow_dur", "hero_reduction", "troop_reduction", "aura_id", "col"]}
const REFERENCES := {"_meteor_zones": ["caster"], "_wards": ["caster"]}
const FLOATS := {
	"_meteor_zones": ["remain", "speed", "hw", "impact", "dps", "dot_dur", "trail"],
	"_wards": ["r", "t", "pulse", "pulse_t", "aura_t", "heal", "dmg", "atkspeed", "slow", "slow_dur", "hero_reduction", "troop_reduction"]}
const MAX_HITS := 4096
const MAX_ENTITIES := 4096
const MAX_RECORDS := 4096
const MAX_ID := "9223372036854775807"
var _codec: Variant = null
var _battle_script: Script
var _unit_script: Script
var _encode_hit: Callable
var _validate_hit: Callable
var _decode_hit: Callable

func _init(codec_script: Script, battle_script: Script, unit_script: Script, encode_hit: Callable, validate_hit: Callable, decode_hit: Callable) -> void:
	_encode_hit = encode_hit
	_validate_hit = validate_hit
	_decode_hit = decode_hit
	_battle_script = battle_script
	_unit_script = unit_script
	if codec_script != null and battle_script != null and unit_script != null and encode_hit.is_valid() and validate_hit.is_valid() and decode_hit.is_valid():
		if codec_script.can_instantiate() and battle_script.can_instantiate() and unit_script.can_instantiate():
			_codec = codec_script.new()

func _failure(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}

func _fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

func _version(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value.length() <= 256

func _battle(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == _battle_script and not value.is_queued_for_deletion()

func _unit(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == _unit_script and not value.is_queued_for_deletion()

func _known_ids(ids: Dictionary) -> Dictionary:
	if ids.size() > MAX_ENTITIES: return _failure("REGISTRY_SHAPE")
	for key in ids:
		if not _id(key): return _failure("REGISTRY_ID")
	return {"ok": true}

func _read_arrays(battle: Variant) -> Dictionary:
	return {"_meteor_zones": battle._meteor_zones, "_wards": battle._wards}

func _entry_values(entry: Dictionary, kind: String, path: String) -> Dictionary:
	for field in FLOATS[kind]:
		if typeof(entry[field]) != TYPE_FLOAT or not is_finite(entry[field]): return _failure("VALUE_FLOAT", path + "." + field)
	if typeof(entry.pos) != TYPE_VECTOR2 or not entry.pos.is_finite(): return _failure("POSITION", path)
	if typeof(entry.foe) != TYPE_INT or entry.foe not in [0, 1]: return _failure("FACTION", path)
	if typeof(entry.ability_id) != TYPE_STRING or entry.ability_id.length() > 128: return _failure("ABILITY_ID", path)
	if kind == "_meteor_zones":
		if typeof(entry.dir) != TYPE_VECTOR2 or not entry.dir.is_finite(): return _failure("DIRECTION", path)
		if entry.remain <= 0.0 or entry.speed <= 0.0 or entry.hw < 0.0 or entry.dot_dur <= 0.0 or entry.trail < 0.0: return _failure("METEOR_VALUE", path)
	else:
		if entry.t <= 0.0 or entry.pulse <= 0.0 or entry.r < 0.0: return _failure("WARD_VALUE", path)
		if typeof(entry.ally) != TYPE_INT or entry.ally not in [0, 1]: return _failure("FACTION", path)
		if typeof(entry.aura_id) != TYPE_INT or entry.aura_id <= 0: return _failure("WARD_AURA_ID", path)
		if typeof(entry.mode) != TYPE_STRING or entry.mode.length() > 128 or typeof(entry.banner_kind) != TYPE_STRING or entry.banner_kind.length() > 128: return _failure("WARD_MODE", path)
		if typeof(entry.col) != TYPE_COLOR: return _failure("WARD_COLOR", path)
		if not is_finite(entry.col.r) or not is_finite(entry.col.g) or not is_finite(entry.col.b) or not is_finite(entry.col.a): return _failure("WARD_COLOR", path)
	# Keep overdue pulse/aura timers and meteor trail=999 as recorded. The
	# consumer's one-increment/last-step policy must not be reconstructed here.
	return {"ok": true}

func _identity(callback: Callable, value: Variant, path: String) -> Dictionary:
	if not callback.is_valid(): return _failure("IDENTITY_CALLBACK", path)
	var result: Variant = callback.call(value)
	if typeof(result) != TYPE_DICTIONARY or typeof(result.get("ok")) != TYPE_BOOL: return _failure("IDENTITY_RESULT", path)
	if not result.ok: return _failure("IDENTITY_" + String(result.get("code", "REJECTED")), path)
	return result

func _hit_records(value: Variant, capturing: bool, path: String) -> Dictionary:
	var rows: Array = []
	if capturing:
		if typeof(value) != TYPE_DICTIONARY or value.size() > MAX_HITS: return _failure("HIT_MAP", path)
		for native_id in value:
			if typeof(native_id) != TYPE_INT or native_id <= 0 or typeof(value[native_id]) != TYPE_BOOL or not value[native_id]: return _failure("HIT_NATIVE_ENTRY", path)
			var encoded: Dictionary = _identity(_encode_hit, native_id, path)
			if not encoded.ok: return encoded
			if not encoded.has("value"): return _failure("IDENTITY_RESULT", path)
			rows.append({"identity": encoded.value, "hit": true})
	else:
		if typeof(value) != TYPE_ARRAY or value.size() > MAX_HITS: return _failure("HIT_RECORDS", path)
		rows = value
	var seen: Array = []
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY or not _fields(row, ["identity", "hit"]) or typeof(row.hit) != TYPE_BOOL or not row.hit: return _failure("HIT_RECORD_ENTRY", path)
		var checked: Dictionary = _identity(_validate_hit, row.identity, path)
		if not checked.ok: return checked
		# Native meteor hits cannot be zero. Only entity or retired target tokens
		# are meaningful; no source-pool/item hash or generic scalar identity.
		if typeof(row.identity) != TYPE_DICTIONARY or row.identity.get("kind") not in ["entity", "retired"]: return _failure("HIT_ID_DOMAIN", path)
		if row.identity in seen: return _failure("HIT_DUPLICATE_IDENTITY", path)
		seen.append(row.identity)
	return {"ok": true, "value": rows}

func _serial(serial: Variant, wards: Array) -> Dictionary:
	if typeof(serial) != TYPE_INT or serial < 0: return _failure("WARD_SERIAL")
	var ids: Dictionary = {}
	for ward in wards:
		if ward.aura_id > serial or ids.has(ward.aura_id): return _failure("WARD_SERIAL")
		ids[ward.aura_id] = true
	return {"ok": true}

func _arrays(value: Variant, registry_or_ids: Dictionary, capturing: bool) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, ARRAYS): return _failure("ARRAY_FIELDS")
	var result: Dictionary = {}
	var total: int = 0
	for kind in ARRAYS:
		var entries: Variant = value[kind]
		if typeof(entries) != TYPE_ARRAY: return _failure("ARRAY_TYPE", kind)
		total += entries.size()
		if total > MAX_RECORDS: return _failure("EFFECT_RECORD_LIMIT")
		var output: Array = []
		for index in range(entries.size()):
			var entry: Variant = entries[index]
			var path: String = "%s[%d]" % [kind, index]
			if typeof(entry) != TYPE_DICTIONARY or not _fields(entry, FIELDS[kind]): return _failure("ENTRY_FIELDS", path)
			var checked: Dictionary = _entry_values(entry, kind, path)
			if not checked.ok: return checked
			var copy: Dictionary = {}
			for field in FIELDS[kind]:
				if field in REFERENCES[kind]:
					var tagged: Dictionary = _tag(entry[field], registry_or_ids, path + "." + field) if capturing else _check_tag(entry[field], registry_or_ids, path + "." + field)
					if not tagged.ok: return tagged
					copy[field] = tagged.value if capturing else entry[field]
				elif kind == "_meteor_zones" and field == "hit":
					var hits: Dictionary = _hit_records(entry[field], capturing, path + ".hit")
					if not hits.ok: return hits
					copy[field] = hits.value
				else: copy[field] = entry[field]
			output.append(copy)
		result[kind] = output
	return {"ok": true, "value": result}

func _id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > MAX_ID.length(): return false
	if value.unicode_at(0) < 49 or value.unicode_at(0) > 57: return false
	for i in range(1, value.length()):
		var c: int = value.unicode_at(i)
		if c < 48 or c > 57: return false
	return value.length() < MAX_ID.length() or value <= MAX_ID

func _registry(registry: Variant) -> Dictionary:
	if typeof(registry) != TYPE_DICTIONARY or registry.size() > MAX_ENTITIES: return _failure("REGISTRY_SHAPE")
	var ids: Dictionary = {}
	for object in registry:
		# A queued deletion is still live, but the caller must use its
		# snapshot barrier to finish deletion before building its registry.
		if typeof(object) != TYPE_OBJECT or not is_instance_valid(object): return _failure("REGISTRY_OBJECT")
		if object.get_script() != _unit_script: return _failure("REGISTRY_UNIT_TYPE")
		if object.is_queued_for_deletion(): return _failure("REGISTRY_PENDING_DELETE")
		var entity_id: Variant = registry[object]
		if not _id(entity_id): return _failure("REGISTRY_ID")
		if ids.has(entity_id): return _failure("REGISTRY_DUPLICATE_ID")
		ids[entity_id] = true
	return {"ok":true,"ids":ids}

func _tag(value: Variant, registry: Dictionary, path: String) -> Dictionary:
	# Do not compare to null first: freed Object Variants must retain expired.
	if typeof(value) == TYPE_NIL: return {"ok":true,"value":{"state":"none"}}
	if typeof(value) != TYPE_OBJECT: return _failure("REFERENCE_TYPE", path)
	if not is_instance_valid(value): return {"ok":true,"value":{"state":"expired"}}
	if value.get_script() != _unit_script: return _failure("REFERENCE_UNIT_TYPE", path)
	if not registry.has(value): return _failure("REFERENCE_UNREGISTERED", path)
	return {"ok":true,"value":{"state":"entity","id":registry[value]}}

func _check_tag(value: Variant, ids: Dictionary, path: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not value.has("state") or typeof(value.state) != TYPE_STRING: return _failure("REFERENCE_TAG", path)
	match value.state:
		"none", "expired":
			if not _fields(value,["state"]): return _failure("REFERENCE_TAG", path)
		"entity":
			if not _fields(value,["state","id"]) or not _id(value.id): return _failure("REFERENCE_TAG", path)
			if not ids.has(value.id): return _failure("REFERENCE_UNKNOWN_ID", path)
		_: return _failure("REFERENCE_TAG", path)
	return {"ok":true}


func capture(battle: Variant, content_version: String, object_to_unit_id: Dictionary) -> Dictionary:
	if _codec == null: return _failure("MODULE_CONFIGURATION")
	if not _version(content_version): return _failure("CONTENT_VERSION")
	if not _battle(battle): return _failure("BATTLE_INSTANCE")
	var registry: Dictionary = _registry(object_to_unit_id)
	if not registry.ok: return registry
	var state: Dictionary = _arrays(_read_arrays(battle), object_to_unit_id, true)
	if not state.ok: return state
	var serial: Dictionary = _serial(battle._ward_serial, state.value._wards)
	if not serial.ok: return serial
	var encoded: Dictionary = _codec.encode({"arrays": state.value, "ward_serial": battle._ward_serial})
	if not encoded.ok: return _failure("CODEC_" + String(encoded.code), String(encoded.get("path", "")))
	return {"ok": true, "record": {"schema": SCHEMA, "content_version": content_version, "payload": encoded.value}}

func validate(record: Variant, content_version: String, known_unit_ids: Dictionary) -> Dictionary:
	if _codec == null: return _failure("MODULE_CONFIGURATION")
	if not _version(content_version): return _failure("CONTENT_VERSION")
	if typeof(record) != TYPE_DICTIONARY or not _fields(record, ["schema", "content_version", "payload"]): return _failure("RECORD_FIELDS")
	if typeof(record.schema) != TYPE_STRING or record.schema != SCHEMA: return _failure("SCHEMA")
	if typeof(record.content_version) != TYPE_STRING or record.content_version != content_version: return _failure("CONTENT_VERSION")
	var checked: Dictionary = _known_ids(known_unit_ids)
	if not checked.ok: return checked
	var decoded: Dictionary = _codec.decode(record.payload)
	if not decoded.ok: return _failure("CODEC_" + String(decoded.code), String(decoded.get("path", "")))
	if typeof(decoded.value) != TYPE_DICTIONARY or not _fields(decoded.value, ["arrays", "ward_serial"]): return _failure("PAYLOAD_FIELDS")
	var state: Dictionary = _arrays(decoded.value.arrays, known_unit_ids, false)
	if not state.ok: return state
	var serial: Dictionary = _serial(decoded.value.ward_serial, state.value._wards)
	if not serial.ok: return serial
	return {"ok": true, "arrays": state.value, "required_ward_serial": decoded.value.ward_serial,
		"covered_arrays": ARRAYS.duplicate(), "complete_battle": false}

func instantiate(record: Variant, content_version: String, known_unit_ids: Dictionary) -> Dictionary:
	var state: Dictionary = validate(record, content_version, known_unit_ids)
	if not state.ok: return state
	var battle: Variant = _battle_script.new()
	battle.set_block_signals(true)
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	return {"ok": true, "battle": battle, "pending_bind_fields": ARRAYS.duplicate(), "required_ward_serial": state.required_ward_serial, "bound": false, "complete_battle": false}

func _resolve_tag(tag: Dictionary, units: Dictionary, expired_unit: Variant) -> Variant:
	match tag.state:
		"entity": return units[tag.id]
		"expired": return expired_unit
	return null

func bind(battle: Variant, record: Variant, content_version: String, id_to_unit: Dictionary, expired_unit: Variant = null) -> Dictionary:
	if not _battle(battle) or battle.get_parent() != null or battle.is_inside_tree() or battle.process_mode != Node.PROCESS_MODE_DISABLED or not battle.is_blocking_signals():
		return _failure("BATTLE_SHELL_NOT_DETACHED_DISABLED")
	if not battle._meteor_zones.is_empty() or not battle._wards.is_empty():
		return _failure("DESTINATION_EFFECT_ARRAYS_NOT_EMPTY")
	var known: Dictionary = {}
	var seen: Dictionary = {}
	for key in id_to_unit:
		if not _id(key) or not _unit(id_to_unit[key]): return _failure("BIND_REGISTRY")
		if seen.has(id_to_unit[key]): return _failure("BIND_DUPLICATE_OBJECT")
		seen[id_to_unit[key]] = true
		known[key] = true
	var state: Dictionary = validate(record, content_version, known)
	if not state.ok: return state
	if battle._ward_serial != state.required_ward_serial: return _failure("ROOT_WARD_SERIAL_NOT_RESTORED")
	var expired_count: int = 0
	for kind in ARRAYS:
		for entry in state.arrays[kind]:
			for field in REFERENCES[kind]:
				if entry[field].state == "expired": expired_count += 1
	if expired_count > 0:
		if not _unit(expired_unit) or expired_unit.get_parent() != null or expired_unit.is_inside_tree() or seen.has(expired_unit):
			return _failure("LIVE_DETACHED_TOMBSTONE_REQUIRED")
	var pending: Dictionary = {}
	for kind in ARRAYS:
		var entries: Array = []
		for entry in state.arrays[kind]:
			var copy: Dictionary = entry.duplicate(false)
			for field in REFERENCES[kind]: copy[field] = _resolve_tag(entry[field], id_to_unit, expired_unit)
			if kind == "_meteor_zones":
				var hits: Dictionary = {}
				for row in entry.hit:
					var decoded_id: Dictionary = _identity(_decode_hit, row.identity, kind + ".hit")
					if not decoded_id.ok: return decoded_id
					if not decoded_id.has("value") or typeof(decoded_id.value) != TYPE_INT or decoded_id.value <= 0: return _failure("HIT_DECODE_ID")
					if hits.has(decoded_id.value): return _failure("HIT_DECODE_COLLISION")
					hits[decoded_id.value] = true
				copy["hit"] = hits
			entries.append(copy)
		pending[kind] = entries
	# Single assignment phase; no hit, buff refresh, heal, cast or serial advance.
	# A decoder rejection may have allocated graph tombstones; the root must
	# discard the whole private identity transaction on any bind failure.
	battle._meteor_zones = pending._meteor_zones
	battle._wards = pending._wards
	return {"ok": true, "bound": true, "expired_bindings": expired_count,
		"covered_arrays": ARRAYS.duplicate(), "complete_battle": false, "tombstone_release_owned_by_caller": true, "visual_nodes_restored": false}
