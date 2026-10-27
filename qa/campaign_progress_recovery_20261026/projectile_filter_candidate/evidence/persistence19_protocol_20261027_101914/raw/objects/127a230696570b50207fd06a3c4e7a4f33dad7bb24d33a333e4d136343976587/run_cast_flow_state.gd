extends RefCounted
## Spell-flow queues only. Never casts, starts cooldowns, commands or rebuilds paths.
## The outer transaction restores Unit values/order paths and all other graphs.
const SCHEMA := "defense_cast_flow_v1"
const ARRAYS := ["_walk_casts", "_pending_casts", "_channels"]
const FIELDS := {
	"_walk_casts": ["c", "slot", "tgt", "point", "serial", "t", "age"],
	"_pending_casts": ["caster", "slot", "lp", "tgt", "serial"],
	"_channels": ["caster", "center", "eff", "sc", "rank", "r", "tick", "tick_t", "ad"]}
const REFERENCES := {"_walk_casts": ["c", "tgt"], "_pending_casts": ["caster", "tgt"], "_channels": ["caster"]}
const FLOATS := {"_walk_casts": ["t", "age"], "_pending_casts": [], "_channels": ["sc", "r", "tick", "tick_t"]}
const REQUIRED_UNIT_FIELDS := ["_order_serial", "_cast_serial", "_cast_t", "_cast_dur", "_cast_color", "_channel_t", "_channel_dur", "ability_slots", "_queue", "_path", "_path_i", "_state", "manual_order_active", "_target", "_stun_t", "_silence_t"]
const MAX_ENTITIES := 4096
const MAX_RECORDS := 4096
const MAX_ID := "9223372036854775807"
var _codec: Variant = null
var _battle_script: Script
var _unit_script: Script

func _init(codec_script: Script, battle_script: Script, unit_script: Script) -> void:
	_battle_script = battle_script
	_unit_script = unit_script
	if codec_script != null and battle_script != null and unit_script != null:
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
	return {"_walk_casts": battle._walk_casts, "_pending_casts": battle._pending_casts, "_channels": battle._channels}

func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

func _channel_definitions(entry: Dictionary, path: String) -> Dictionary:
	if typeof(entry.eff) != TYPE_DICTIONARY or typeof(entry.ad) != TYPE_DICTIONARY:
		return _failure("CHANNEL_DEFINITIONS", path)
	var eff: Dictionary = entry.eff
	var mode: Variant = eff.get("active_kind", eff.get("kind"))
	if typeof(mode) != TYPE_STRING or mode != "channel": return _failure("CHANNEL_KIND", path)
	# Preserve complete dictionaries; validate fields read by the real consumers.
	# Missing optional keys remain absent, never filled with null or defaults.
	for field in ["dur", "tick", "dmg", "slow", "slow_dur", "stun", "def_down_dur", "blind", "silence", "amp", "amp_dur", "root", "disarm", "taunt", "hex"]:
		if eff.has(field) and not _number(eff[field]): return _failure("CHANNEL_NUMBER", path + ".eff." + field)
	for field in ["kind", "active_kind", "_ability_id", "dispel"]:
		if eff.has(field) and typeof(eff[field]) != TYPE_STRING: return _failure("CHANNEL_STRING", path + ".eff." + field)
	if eff.has("def_down"):
		if typeof(eff.def_down) == TYPE_ARRAY:
			if eff.def_down.is_empty(): return _failure("CHANNEL_RANK_VALUES", path)
			for value in eff.def_down:
				if not _number(value): return _failure("CHANNEL_RANK_VALUES", path)
		elif not _number(eff.def_down): return _failure("CHANNEL_RANK_VALUES", path)
	if entry.ad.has("color"):
		var col: Variant = entry.ad.color
		if typeof(col) != TYPE_COLOR or not is_finite(col.r) or not is_finite(col.g) or not is_finite(col.b) or not is_finite(col.a):
			return _failure("CHANNEL_COLOR", path)
	# The bounded codec rejects cycles/Objects/non-finite or unsupported data,
	# including metadata not consumed here. Nothing is silently omitted.
	return {"ok": true}

func _entry_values(entry: Dictionary, kind: String, path: String) -> Dictionary:
	for field in FLOATS[kind]:
		if typeof(entry[field]) != TYPE_FLOAT or not is_finite(entry[field]): return _failure("VALUE_FLOAT", path + "." + field)
	if kind in ["_walk_casts", "_pending_casts"]:
		if typeof(entry.slot) != TYPE_INT or entry.slot < 0: return _failure("SLOT", path)
		if typeof(entry.serial) != TYPE_INT or entry.serial < (-1 if kind == "_walk_casts" else 0): return _failure("SERIAL", path)
	if kind == "_walk_casts":
		if entry.age < 0.0: return _failure("WALK_AGE", path)
		if typeof(entry.point) != TYPE_VECTOR2 or (entry.point != Vector2.INF and not entry.point.is_finite()): return _failure("WALK_POINT", path)
	elif kind == "_pending_casts":
		if typeof(entry.lp) != TYPE_VECTOR2 or not entry.lp.is_finite(): return _failure("CAST_POINT", path)
	else:
		if typeof(entry.center) != TYPE_VECTOR2 or not entry.center.is_finite(): return _failure("CHANNEL_CENTER", path)
		if typeof(entry.rank) != TYPE_INT or entry.rank <= 0 or entry.sc < 0.0 or entry.r < 0.0 or entry.tick <= 0.0: return _failure("CHANNEL_VALUES", path)
		var definitions: Dictionary = _channel_definitions(entry, path)
		if not definitions.ok: return definitions
	# Overdue timers and serial mismatches are preserved for original consumers.
	return {"ok": true}

func _point_unpack(value: Variant, path: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("mode")) != TYPE_STRING: return _failure("WALK_POINT_TAG", path)
	if value.mode == "unit_target":
		if not _fields(value, ["mode"]): return _failure("WALK_POINT_TAG", path)
		return {"ok": true, "value": Vector2.INF}
	if value.mode == "point":
		if not _fields(value, ["mode", "value"]) or typeof(value.value) != TYPE_VECTOR2 or not value.value.is_finite(): return _failure("WALK_POINT_TAG", path)
		return {"ok": true, "value": value.value}
	return _failure("WALK_POINT_TAG", path)

func _arrays(value: Variant, registry_or_ids: Dictionary, capturing: bool) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, ARRAYS): return _failure("ARRAY_FIELDS")
	var result: Dictionary = {}
	var total: int = 0
	for kind in ARRAYS:
		var rows: Variant = value[kind]
		if typeof(rows) != TYPE_ARRAY: return _failure("ARRAY_TYPE", kind)
		total += rows.size()
		if total > MAX_RECORDS: return _failure("CAST_RECORD_LIMIT")
		var output: Array = []
		for index in range(rows.size()):
			var entry: Variant = rows[index]
			var path: String = "%s[%d]" % [kind, index]
			if typeof(entry) != TYPE_DICTIONARY or not _fields(entry, FIELDS[kind]): return _failure("ENTRY_FIELDS", path)
			var native: Dictionary = entry.duplicate(false)
			if kind == "_walk_casts" and not capturing:
				var point: Dictionary = _point_unpack(entry.point, path)
				if not point.ok: return point
				native["point"] = point.value
			var checked: Dictionary = _entry_values(native, kind, path)
			if not checked.ok: return checked
			var copy: Dictionary = {}
			for field in FIELDS[kind]:
				if field in REFERENCES[kind]:
					var tagged: Dictionary = _tag(entry[field], registry_or_ids, path + "." + field) if capturing else _check_tag(entry[field], registry_or_ids, path + "." + field)
					if not tagged.ok: return tagged
					copy[field] = tagged.value if capturing else entry[field]
				else: copy[field] = native[field]
			if kind == "_walk_casts":
				var unit_target: bool = native.point == Vector2.INF
				if (unit_target and copy.tgt.state == "none") or (not unit_target and copy.tgt.state != "none"):
					return _failure("WALK_TARGET_MODE", path)
				if capturing: copy["point"] = {"mode": "unit_target"} if unit_target else {"mode": "point", "value": native.point}
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
	var encoded: Dictionary = _codec.encode(state.value)
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
	var state: Dictionary = _arrays(decoded.value, known_unit_ids, false)
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
	if not battle._walk_casts.is_empty() or not battle._pending_casts.is_empty() or not battle._channels.is_empty():
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
			entries.append(copy)
		pending[kind] = entries
	# Non-yielding assignment only; the outer transaction restores Unit phases,
	# cooldowns, orders/path, abilities and map before it activates any consumer.
	battle._walk_casts = pending._walk_casts
	battle._pending_casts = pending._pending_casts
	battle._channels = pending._channels
	return {"ok": true, "bound": true, "expired_bindings": expired_count,
		"covered_arrays": ARRAYS.duplicate(), "complete_battle": false,
		"required_unit_fields": REQUIRED_UNIT_FIELDS.duplicate(),
		"tombstone_release_owned_by_caller": true, "visual_nodes_restored": false}
