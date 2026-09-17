extends RefCounted
## Beast lines, four bolt modes and traps. Unit pools and visual Nodes belong
## to the root transaction. Hit-ID callbacks must use the root's stable identity
## graph; expired Unit refs bind to live tombstones, freed only after all modules.
const SCHEMA := "defense_remaining_effects_v1"
const ARRAYS := ["_gong_lines", "_bolts", "_traps"]
const FIELDS := {
	"_gong_lines": ["kind", "origin", "dir", "length", "traveled", "speed", "half_width", "foe", "caster", "ability_id", "dmg", "push", "slow", "slow_dur", "hit"],
	"_traps": ["key", "pos", "trigger_r", "arm_t", "effect", "owner", "fx"],
	"bolt": ["mode", "pos", "tgt", "speed", "eff", "sc", "rank", "caster", "fx"],
	"bolt_line": ["mode", "pos", "dir", "traveled", "len", "width", "speed", "eff", "sc", "rank", "caster", "fx"],
	"hook_out": ["mode", "pos", "dir", "traveled", "len", "width", "speed", "eff", "sc", "rank", "caster", "fx"],
	"hook_drag": ["mode", "pos", "dir", "traveled", "len", "width", "speed", "eff", "sc", "rank", "caster", "fx", "victim"]}
const REFERENCES := {
	"_gong_lines": ["caster"], "_traps": [], "bolt": ["caster", "tgt"],
	"bolt_line": ["caster"], "hook_out": ["caster"], "hook_drag": ["caster", "victim"]}
const FLOATS := {
	"_gong_lines": ["length", "traveled", "speed", "half_width", "dmg", "push", "slow", "slow_dur"],
	"_traps": ["trigger_r", "arm_t"], "bolt": ["speed", "sc"],
	"bolt_line": ["traveled", "len", "width", "speed", "sc"],
	"hook_out": ["traveled", "len", "width", "speed", "sc"],
	"hook_drag": ["traveled", "len", "width", "speed", "sc"]}
const MAX_HITS := 4096
const MAX_ENTITIES := 4096
const MAX_RECORDS := 4096
const MAX_ID := "9223372036854775806"
var _codec: Variant = null
var _battle_script: Script
var _unit_script: Script
var _encode_hit: Callable
var _validate_hit: Callable
var _decode_hit: Callable
var _encode_fx: Callable
var _validate_fx: Callable
var _decode_fx: Callable

func _init(codec_script: Script, battle_script: Script, unit_script: Script,
		encode_hit: Callable, validate_hit: Callable, decode_hit: Callable,
		encode_fx: Callable, validate_fx: Callable, decode_fx: Callable) -> void:
	_encode_fx = encode_fx
	_validate_fx = validate_fx
	_decode_fx = decode_fx
	if not encode_fx.is_valid() or not validate_fx.is_valid() or not decode_fx.is_valid(): return
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
	return {"_gong_lines": battle._gong_lines, "_bolts": battle._bolts, "_traps": battle._traps}

func _kind(entry: Dictionary, array_name: String) -> String:
	if array_name != "_bolts": return array_name
	var mode: Variant = entry.get("mode")
	return mode if typeof(mode) == TYPE_STRING and mode in ["bolt", "bolt_line", "hook_out", "hook_drag"] else ""

func _fx(callback: Callable, value: Variant, kind: String, phase: String) -> Dictionary:
	# The complete visual graph owns global root order, node deduplication and
	# disabled constructor shells. Callback sources come only from trusted code.
	var expected: String = "trap_marker" if kind == "_traps" else "bolt"
	var expected_script: Script = _battle_script.TrapMarkerFx if expected == "trap_marker" else _battle_script.BoltFx
	if phase == "capture" and typeof(value) != TYPE_NIL:
		if typeof(value) != TYPE_OBJECT: return _failure("FX_CAPTURE_TYPE")
		if is_instance_valid(value) and (not value is Node2D or value.get_script() != expected_script or value.is_queued_for_deletion()): return _failure("FX_CAPTURE_CLASS")
	if not callback.is_valid(): return _failure("FX_CALLBACK")
	var result: Variant = callback.call(value, expected)
	if typeof(result) != TYPE_DICTIONARY or typeof(result.get("ok")) != TYPE_BOOL: return _failure("FX_RESULT")
	if not result.ok: return _failure("FX_" + String(result.get("code", "REJECTED")))
	if phase != "validate" and not result.has("value"): return _failure("FX_VALUE")
	if phase == "capture" or phase == "validate":
		var token: Variant = result.value if phase == "capture" else value
		if typeof(token) != TYPE_DICTIONARY or typeof(token.get("state")) != TYPE_STRING: return _failure("FX_TAG")
		if token.state in ["none", "expired"]:
			if not _fields(token, ["state"]): return _failure("FX_TAG")
		elif token.state == "node":
			if not _fields(token, ["state", "id"]) or not _id(token.id): return _failure("FX_ID")
		else: return _failure("FX_TAG")
		if phase == "capture":
			var expected_state: String = "none" if typeof(value) == TYPE_NIL else ("node" if is_instance_valid(value) else "expired")
			if token.state != expected_state: return _failure("FX_TAG_STATE")
	elif phase == "bind":
		if value.state == "none" and typeof(result.value) != TYPE_NIL: return _failure("FX_NONE_BIND")
		if value.state != "none":
			if typeof(result.value) != TYPE_OBJECT or not is_instance_valid(result.value) or not result.value is Node2D: return _failure("FX_BIND_NODE")
			if result.value.get_script() != expected_script: return _failure("FX_BIND_CLASS")
			if result.value.is_inside_tree() or result.value.process_mode != Node.PROCESS_MODE_DISABLED or not result.value.is_blocking_signals(): return _failure("FX_BIND_ACTIVE")
	return result

func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

func _effect_values(eff: Variant, trap: bool, path: String) -> Dictionary:
	if typeof(eff) != TYPE_DICTIONARY: return _failure("EFFECT_DEFINITION", path)
	# Validate all fields consumed by the trusted trap/rider methods. Preserve
	# absent optional keys and the complete value-only dictionaries verbatim.
	for key: String in ["dmg", "radius", "total", "dur", "slow", "slow_dur", "stun", "def_down_dur", "blind", "silence", "amp", "amp_dur", "root", "disarm", "taunt", "hex"]:
		if eff.has(key) and not _number(eff[key]): return _failure("EFFECT_NUMBER", path + "." + key)
	for key: String in ["kind", "active_kind", "_ability_id", "dispel"]:
		if eff.has(key) and typeof(eff[key]) != TYPE_STRING: return _failure("EFFECT_STRING", path + "." + key)
	if trap and String(eff.get("kind", "aoe")) not in ["aoe", "stun", "fire"]: return _failure("TRAP_KIND", path)
	if eff.has("def_down"):
		if typeof(eff.def_down) == TYPE_ARRAY:
			if eff.def_down.is_empty(): return _failure("EFFECT_RANK_VALUES", path)
			for value: Variant in eff.def_down:
				if not _number(value): return _failure("EFFECT_RANK_VALUES", path)
		elif not _number(eff.def_down): return _failure("EFFECT_RANK_VALUES", path)
	return {"ok": true}

func _entry_values(entry: Dictionary, kind: String, path: String) -> Dictionary:
	for field: String in FLOATS[kind]:
		if typeof(entry[field]) != TYPE_FLOAT or not is_finite(entry[field]): return _failure("VALUE_FLOAT", path + "." + field)
	if kind == "_gong_lines":
		for field: String in ["origin", "dir"]:
			if typeof(entry[field]) != TYPE_VECTOR2 or not entry[field].is_finite(): return _failure("VECTOR", path + "." + field)
		if entry.kind != "beast" or entry.length <= 0.0 or entry.speed <= 0.0 or entry.traveled < 0.0 or entry.traveled >= entry.length or entry.half_width < 0.0: return _failure("BEAST_PROGRESS", path)
		if typeof(entry.foe) != TYPE_INT or entry.foe not in [0, 1]: return _failure("FACTION", path)
		if typeof(entry.ability_id) != TYPE_STRING or entry.ability_id.length() > 128: return _failure("ABILITY_ID", path)
	else:
		if typeof(entry.pos) != TYPE_VECTOR2 or not entry.pos.is_finite(): return _failure("POSITION", path)
		if kind == "_traps":
			if typeof(entry.key) != TYPE_STRING or entry.key.length() > 128 or entry.key.is_empty(): return _failure("TRAP_KEY", path)
			if typeof(entry.owner) != TYPE_INT or entry.owner not in [0, 1] or entry.trigger_r < 0.0: return _failure("TRAP_VALUE", path)
			# arm_t can cross below zero for one complete step; preserve it.
			return _effect_values(entry.effect, true, path)
		if entry.speed <= 0.0 or typeof(entry.rank) != TYPE_INT or entry.rank < 0: return _failure("BOLT_VALUE", path)
		if kind != "bolt":
			if typeof(entry.dir) != TYPE_VECTOR2 or not entry.dir.is_finite(): return _failure("DIRECTION", path)
			if entry.traveled < 0.0 or entry.len <= 0.0 or entry.width < 0.0: return _failure("BOLT_DISTANCE", path)
			# hook_drag preserves the outward dir/traveled/len; it may have hooked
			# on the last outward step beyond len. Do not discard those fields.
		return _effect_values(entry.eff, false, path)
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
		# Native beast hits cannot be zero. Only entity or retired target tokens
		# are meaningful; no source-pool/item hash or generic scalar identity.
		if typeof(row.identity) != TYPE_DICTIONARY or row.identity.get("kind") not in ["entity", "retired"]: return _failure("HIT_ID_DOMAIN", path)
		if row.identity in seen: return _failure("HIT_DUPLICATE_IDENTITY", path)
		seen.append(row.identity)
	return {"ok": true, "value": rows}

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
			if typeof(entry) != TYPE_DICTIONARY: return _failure("ENTRY_FIELDS", path)
			var record_kind: String = _kind(entry, kind)
			if record_kind.is_empty() or not _fields(entry, FIELDS[record_kind]): return _failure("ENTRY_FIELDS", path)
			var checked: Dictionary = _entry_values(entry, record_kind, path)
			if not checked.ok: return checked
			var copy: Dictionary = {}
			for field in FIELDS[record_kind]:
				if field in REFERENCES[record_kind]:
					var tagged: Dictionary = _tag(entry[field], registry_or_ids, path + "." + field) if capturing else _check_tag(entry[field], registry_or_ids, path + "." + field)
					if not tagged.ok: return tagged
					copy[field] = tagged.value if capturing else entry[field]
				elif kind == "_gong_lines" and field == "hit":
					var hits: Dictionary = _hit_records(entry[field], capturing, path + ".hit")
					if not hits.ok: return hits
					copy[field] = hits.value
				elif field == "fx":
					var fx: Dictionary = _fx(_encode_fx if capturing else _validate_fx, entry.fx, kind, "capture" if capturing else "validate")
					if not fx.ok: return fx
					copy[field] = fx.value if capturing else entry.fx
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
		if str(object.entity_id) != entity_id: return _failure("REGISTRY_ENTITY_FIELD")
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
	if not battle.gameplay_rng_fault().is_empty(): return _failure("BATTLE_FAULT")
	var registry: Dictionary = _registry(object_to_unit_id)
	if not registry.ok: return registry
	var state: Dictionary = _arrays(_read_arrays(battle), object_to_unit_id, true)
	if not state.ok: return state
	var encoded: Dictionary = _codec.encode({"arrays": state.value})
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
	if typeof(decoded.value) != TYPE_DICTIONARY or not _fields(decoded.value, ["arrays"]): return _failure("PAYLOAD_FIELDS")
	var state: Dictionary = _arrays(decoded.value.arrays, known_unit_ids, false)
	if not state.ok: return state
	return {"ok": true, "arrays": state.value, "covered_arrays": ARRAYS.duplicate(), "complete_battle": false}

func instantiate(record: Variant, content_version: String, known_unit_ids: Dictionary) -> Dictionary:
	var state: Dictionary = validate(record, content_version, known_unit_ids)
	if not state.ok: return state
	var battle: Variant = _battle_script.new()
	battle.set_block_signals(true)
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	return {"ok": true, "battle": battle, "pending_bind_fields": ARRAYS.duplicate(), "bound": false, "complete_battle": false}

func _resolve_tag(tag: Dictionary, units: Dictionary, expired_unit: Variant) -> Variant:
	match tag.state:
		"entity": return units[tag.id]
		"expired": return expired_unit
	return null

func bind(battle: Variant, record: Variant, content_version: String, id_to_unit: Dictionary, expired_unit: Variant = null) -> Dictionary:
	if not _battle(battle) or battle.get_parent() != null or battle.is_inside_tree() or battle.process_mode != Node.PROCESS_MODE_DISABLED or not battle.is_blocking_signals():
		return _failure("BATTLE_SHELL_NOT_DETACHED_DISABLED")
	if not battle._gong_lines.is_empty() or not battle._bolts.is_empty() or not battle._traps.is_empty():
		return _failure("DESTINATION_EFFECT_ARRAYS_NOT_EMPTY")
	var known: Dictionary = {}
	var seen: Dictionary = {}
	for key in id_to_unit:
		if not _id(key) or not _unit(id_to_unit[key]): return _failure("BIND_REGISTRY")
		if str(id_to_unit[key].entity_id) != key: return _failure("BIND_ENTITY_FIELD")
		if seen.has(id_to_unit[key]): return _failure("BIND_DUPLICATE_OBJECT")
		seen[id_to_unit[key]] = true
		known[key] = true
	var state: Dictionary = validate(record, content_version, known)
	if not state.ok: return state
	var expired_count: int = 0
	for kind in ARRAYS:
		for entry in state.arrays[kind]:
			for field in REFERENCES[_kind(entry, kind)]:
				if entry[field].state == "expired": expired_count += 1
	if expired_count > 0:
		if not _unit(expired_unit) or expired_unit.get_parent() != null or expired_unit.is_inside_tree() or seen.has(expired_unit):
			return _failure("LIVE_DETACHED_TOMBSTONE_REQUIRED")
	var pending: Dictionary = {}
	for kind in ARRAYS:
		var entries: Array = []
		for entry in state.arrays[kind]:
			var copy: Dictionary = entry.duplicate(false)
			for field in REFERENCES[_kind(entry, kind)]: copy[field] = _resolve_tag(entry[field], id_to_unit, expired_unit)
			if kind == "_gong_lines":
				var hits: Dictionary = {}
				for row in entry.hit:
					var decoded_id: Dictionary = _identity(_decode_hit, row.identity, kind + ".hit")
					if not decoded_id.ok: return decoded_id
					if not decoded_id.has("value") or typeof(decoded_id.value) != TYPE_INT or decoded_id.value <= 0: return _failure("HIT_DECODE_ID")
					if hits.has(decoded_id.value): return _failure("HIT_DECODE_COLLISION")
					hits[decoded_id.value] = true
				copy["hit"] = hits
			if kind in ["_bolts", "_traps"]:
				var fx: Dictionary = _fx(_decode_fx, entry.fx, kind, "bind")
				if not fx.ok: return fx
				copy["fx"] = fx.value
			entries.append(copy)
		pending[kind] = entries
	# Single assignment phase; no hit, buff refresh, heal, cast or serial advance.
	# A decoder rejection may have allocated graph tombstones; the root must
	# discard the whole private identity transaction on any bind failure.
	battle._gong_lines = pending._gong_lines
	battle._bolts = pending._bolts
	battle._traps = pending._traps
	return {"ok": true, "bound": true, "expired_bindings": expired_count,
		"covered_arrays": ARRAYS.duplicate(), "complete_battle": false, "tombstone_release_owned_by_caller": true, "visual_nodes_restored": false}
