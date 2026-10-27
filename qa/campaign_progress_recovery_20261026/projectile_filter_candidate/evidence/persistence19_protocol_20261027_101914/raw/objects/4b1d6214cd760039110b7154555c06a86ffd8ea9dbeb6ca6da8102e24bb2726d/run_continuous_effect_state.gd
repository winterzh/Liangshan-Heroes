extends RefCounted
## Three continuous Battle arrays only. This is NOT a full Battle serializer.
## Current constructors: _add_ground_dot, hua_snipe append, lin_duel append.
## Consumers: _ground_dot_pass, _hua_snipe_dot_pass, _lin_duel_pass and
## _resolve_lin_duel_death. Capture/bind never calls any of these methods.
## Caller freezes the complete run, owns graph order and releases tombstones
## after every module binds, before enabling simulation or delivering events.
const SCHEMA := "defense_continuous_effects_v1"
const ARRAYS := ["_ground_dots", "_hua_snipe_dots", "_lin_duels"]
const FIELDS := {
	"_ground_dots": ["pos", "r", "foe", "caster", "follow", "attack_slow", "attack_miss", "ability_id", "t", "tick_t", "tick", "per"],
	"_hua_snipe_dots": ["target", "caster", "ability_id", "t", "tick_t", "tick", "pct", "ticks_left"],
	"_lin_duels": ["caster", "target", "t", "heal_pct"]}
const REFERENCES := {"_ground_dots": ["caster", "follow"], "_hua_snipe_dots": ["target", "caster"], "_lin_duels": ["caster", "target"]}
const FLOATS := {
	"_ground_dots": ["r", "attack_slow", "attack_miss", "t", "tick_t", "tick", "per"],
	"_hua_snipe_dots": ["t", "tick_t", "tick", "pct"], "_lin_duels": ["t", "heal_pct"]}
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
	return {"_ground_dots": battle._ground_dots, "_hua_snipe_dots": battle._hua_snipe_dots, "_lin_duels": battle._lin_duels}

func _entry_values(entry: Dictionary, kind: String, path: String) -> Dictionary:
	for field in FLOATS[kind]:
		if typeof(entry[field]) != TYPE_FLOAT or not is_finite(entry[field]): return _failure("VALUE_FLOAT", path + "." + field)
	if entry.t <= 0.0: return _failure("EXPIRED_EFFECT_RECORD", path)
	if kind != "_lin_duels":
		if typeof(entry.ability_id) != TYPE_STRING or entry.ability_id.length() > 128: return _failure("ABILITY_ID", path)
		if entry.tick <= 0.0: return _failure("TICK_INTERVAL", path)
		# tick_t may be nonpositive after ground DOT's single-step catch-up. Never
		# clamp it, derive it from t, or change the original while/one-tick policy.
	match kind:
		"_ground_dots":
			if typeof(entry.pos) != TYPE_VECTOR2 or not entry.pos.is_finite(): return _failure("POSITION", path)
			if typeof(entry.foe) != TYPE_INT or entry.foe not in [0, 1]: return _failure("FACTION", path)
			if entry.r < 0.0: return _failure("RADIUS", path)
		"_hua_snipe_dots":
			if typeof(entry.ticks_left) != TYPE_INT or entry.ticks_left <= 0: return _failure("TICKS_LEFT", path)
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
	if not battle._ground_dots.is_empty() or not battle._hua_snipe_dots.is_empty() or not battle._lin_duels.is_empty():
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
	# Single non-yielding assignment phase; no tick, death callback or skill cast.
	battle._ground_dots = pending._ground_dots
	battle._hua_snipe_dots = pending._hua_snipe_dots
	battle._lin_duels = pending._lin_duels
	return {"ok": true, "bound": true, "expired_bindings": expired_count,
		"covered_arrays": ARRAYS.duplicate(), "complete_battle": false, "tombstone_release_owned_by_caller": true}
