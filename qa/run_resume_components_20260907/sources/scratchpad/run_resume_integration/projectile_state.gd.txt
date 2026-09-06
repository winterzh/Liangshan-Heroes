extends RefCounted
## Standard-defense Projectile factory: all 14 declarations (12 values, 2 refs).
## Caller owns fx_root ordering and the run-wide paused capture/commit barrier.
## Never calls Projectile.setup, _physics_process, damage APIs or any RNG API.
## Script injection + schema/content version work in exported PCKs, without source reads.
## Queued deletion is excluded: finish deferred frees before building the snapshot.
const SCHEMA := "defense_projectile_state_v1"
const VALUE_FIELDS := ["dmg", "crit", "damage_ability_id", "speed", "_dir", "_life", "kind", "splash", "on_slow_mult", "on_slow_dur", "_dist0", "_spin"]
const FLOAT_FIELDS := ["dmg", "speed", "_life", "splash", "on_slow_mult", "on_slow_dur", "_dist0", "_spin"]
const REFERENCE_FIELDS := ["target", "shooter"]
const NODE_FIELDS := ["name", "position", "modulate", "basis_x", "basis_y", "visible", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "activation"]
const ACTIVATION_FIELDS := ["mode", "priority", "physics_priority", "process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]
const MAX_ENTITIES := 4096
const MAX_ID := "9223372036854775807"
var _codec: Variant = null
var _projectile_script: Script
var _unit_script: Script

func _init(codec_script: Script, projectile_script: Script, unit_script: Script) -> void:
	_projectile_script = projectile_script
	_unit_script = unit_script
	if codec_script != null and projectile_script != null and unit_script != null:
		if codec_script.can_instantiate() and projectile_script.can_instantiate() and unit_script.can_instantiate():
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

func _projectile(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == _projectile_script and not value.is_queued_for_deletion()

func _unit(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == _unit_script and not value.is_queued_for_deletion()

func _known_ids(ids: Dictionary) -> Dictionary:
	# Empty registry is legal for a projectile whose target and shooter expired.
	if ids.size() > MAX_ENTITIES: return _failure("REGISTRY_SHAPE")
	for key in ids:
		if not _id(key): return _failure("REGISTRY_ID")
	return {"ok": true}

func _read_values(projectile: Variant) -> Dictionary:
	return {"dmg": projectile.dmg, "crit": projectile.crit, "damage_ability_id": projectile.damage_ability_id,
		"speed": projectile.speed, "_dir": projectile._dir, "_life": projectile._life, "kind": projectile.kind,
		"splash": projectile.splash, "on_slow_mult": projectile.on_slow_mult, "on_slow_dur": projectile.on_slow_dur,
		"_dist0": projectile._dist0, "_spin": projectile._spin}

func _check_values(values: Variant) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY or not _fields(values, VALUE_FIELDS): return _failure("VALUE_FIELDS")
	for field in FLOAT_FIELDS:
		if typeof(values[field]) != TYPE_FLOAT or not is_finite(values[field]): return _failure("VALUE_FLOAT", field)
	if typeof(values.crit) != TYPE_BOOL: return _failure("VALUE_BOOL", "crit")
	for field in ["kind", "damage_ability_id"]:
		if typeof(values[field]) != TYPE_STRING or values[field].length() > 128: return _failure("VALUE_STRING", field)
	if values.kind not in ["arrow", "boulder", "fireball", "bomb", "magic"]: return _failure("PROJECTILE_KIND")
	if typeof(values._dir) != TYPE_VECTOR2 or not values._dir.is_finite(): return _failure("VALUE_DIRECTION")
	if values._dist0 <= 0.0: return _failure("INITIAL_DISTANCE")
	# No normalizing direction, clamping timers or changing remaining flight state.
	return {"ok": true}

func _assign_values(projectile: Variant, values: Dictionary) -> void:
	projectile.dmg = values.dmg
	projectile.crit = values.crit
	projectile.damage_ability_id = values.damage_ability_id
	projectile.speed = values.speed
	projectile._dir = values._dir
	projectile._life = values._life
	projectile.kind = values.kind
	projectile.splash = values.splash
	projectile.on_slow_mult = values.on_slow_mult
	projectile.on_slow_dur = values.on_slow_dur
	projectile._dist0 = values._dist0
	projectile._spin = values._spin

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

func _read_node(projectile: Variant) -> Dictionary:
	# Generated @ names are rebuilt when attached in the saved effect order.
	var saved_name: String = "" if String(projectile.name).begins_with("@") else String(projectile.name)
	return {"name": saved_name, "position": projectile.position, "modulate": projectile.modulate, "basis_x": projectile.transform.x, "basis_y": projectile.transform.y,
		"visible": projectile.visible, "self_modulate": projectile.self_modulate, "z_index": projectile.z_index,
		"z_as_relative": projectile.z_as_relative, "show_behind_parent": projectile.show_behind_parent,
		"top_level": projectile.top_level, "y_sort_enabled": projectile.y_sort_enabled,
		"activation": {"mode": int(projectile.process_mode), "priority": projectile.process_priority,
			"physics_priority": projectile.process_physics_priority, "process": projectile.is_processing(),
			"physics": projectile.is_physics_processing(), "input": projectile.is_processing_input(),
			"shortcut": projectile.is_processing_shortcut_input(), "unhandled_input": projectile.is_processing_unhandled_input(),
			"unhandled_key": projectile.is_processing_unhandled_key_input(), "signals_blocked": projectile.is_blocking_signals()}}

func _check_activation(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, ACTIVATION_FIELDS): return _failure("ACTIVATION_FIELDS")
	for key in ["mode", "priority", "physics_priority"]:
		if typeof(value[key]) != TYPE_INT: return _failure("ACTIVATION_INTEGER", key)
	if value.mode < 0 or value.mode > 4: return _failure("ACTIVATION_MODE")
	for key in ["priority", "physics_priority"]:
		if value[key] < -2147483648 or value[key] > 2147483647: return _failure("ACTIVATION_RANGE", key)
	for key in ["process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]:
		if typeof(value[key]) != TYPE_BOOL: return _failure("ACTIVATION_BOOL", key)
	return {"ok": true}

func _check_node(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _fields(value, NODE_FIELDS): return _failure("NODE_FIELDS")
	if typeof(value.name) != TYPE_STRING or value.name.length() > 256: return _failure("NODE_NAME")
	for key in ["position", "basis_x", "basis_y"]:
		if typeof(value[key]) != TYPE_VECTOR2 or not value[key].is_finite(): return _failure("NODE_TRANSFORM", key)
	for key in ["visible", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled"]:
		if typeof(value[key]) != TYPE_BOOL: return _failure("NODE_BOOL", key)
	if typeof(value.z_index) != TYPE_INT or value.z_index < -4096 or value.z_index > 4096: return _failure("NODE_Z")
	for key in ["modulate", "self_modulate"]:
		if typeof(value[key]) != TYPE_COLOR: return _failure("NODE_COLOR", key)
		var color: Color = value[key]
		for part in [color.r, color.g, color.b, color.a]:
			if not is_finite(part): return _failure("NODE_COLOR", key)
	return _check_activation(value.activation)


func capture(projectile: Variant, content_version: String, object_to_unit_id: Dictionary) -> Dictionary:
	if _codec == null: return _failure("MODULE_CONFIGURATION")
	if not _version(content_version): return _failure("CONTENT_VERSION")
	if not _projectile(projectile): return _failure("PROJECTILE_INSTANCE")
	var registry: Dictionary = _registry(object_to_unit_id)
	if not registry.ok: return registry
	var values: Dictionary = _read_values(projectile)
	var checked: Dictionary = _check_values(values)
	if not checked.ok: return checked
	var node: Dictionary = _read_node(projectile)
	checked = _check_node(node)
	if not checked.ok: return checked
	var target_tag: Dictionary = _tag(projectile.target, object_to_unit_id, "target")
	if not target_tag.ok: return target_tag
	var shooter_tag: Dictionary = _tag(projectile.shooter, object_to_unit_id, "shooter")
	if not shooter_tag.ok: return shooter_tag
	var encoded: Dictionary = _codec.encode({"values": values, "node": node,
		"references": {"target": target_tag.value, "shooter": shooter_tag.value}})
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
	var payload: Variant = decoded.value
	if typeof(payload) != TYPE_DICTIONARY or not _fields(payload, ["values", "node", "references"]): return _failure("PAYLOAD_FIELDS")
	checked = _check_values(payload.values)
	if not checked.ok: return checked
	checked = _check_node(payload.node)
	if not checked.ok: return checked
	if typeof(payload.references) != TYPE_DICTIONARY or not _fields(payload.references, REFERENCE_FIELDS): return _failure("REFERENCE_FIELDS")
	for field in REFERENCE_FIELDS:
		checked = _check_tag(payload.references[field], known_unit_ids, field)
		if not checked.ok: return checked
	return {"ok": true, "values": payload.values, "node": payload.node, "references": payload.references}

func instantiate(record: Variant, content_version: String, known_unit_ids: Dictionary) -> Dictionary:
	var state: Dictionary = validate(record, content_version, known_unit_ids)
	if not state.ok: return state
	var projectile: Variant = _projectile_script.new()
	projectile.set_block_signals(true)
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	_assign_values(projectile, state.values)
	var node: Dictionary = state.node
	if not node.name.is_empty(): projectile.name = node.name
	projectile.transform = Transform2D(node.basis_x, node.basis_y, node.position)
	projectile.modulate = node.modulate
	projectile.visible = node.visible
	projectile.self_modulate = node.self_modulate
	projectile.z_index = node.z_index
	projectile.z_as_relative = node.z_as_relative
	projectile.show_behind_parent = node.show_behind_parent
	projectile.top_level = node.top_level
	projectile.y_sort_enabled = node.y_sort_enabled
	return {"ok": true, "projectile": projectile, "activation": node.activation,
		"pending_bind_fields": REFERENCE_FIELDS.duplicate(), "bound": false}

func _resolve_tag(tag: Dictionary, units: Dictionary, expired_unit: Variant) -> Variant:
	match tag.state:
		"entity": return units[tag.id]
		"expired": return expired_unit
	return null

# Keep expired_unit alive through ALL Unit/Projectile/Effect/Battle binding.
# Caller then frees the shared tombstone before any node is activated/unpaused.
func bind(projectile: Variant, record: Variant, content_version: String, id_to_unit: Dictionary, expired_unit: Variant = null) -> Dictionary:
	if not _projectile(projectile) or projectile.get_parent() != null or projectile.is_inside_tree() or not projectile.is_blocking_signals() or projectile.process_mode != Node.PROCESS_MODE_DISABLED:
		return _failure("SHELL_NOT_DETACHED_DISABLED")
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
	for field in REFERENCE_FIELDS:
		if state.references[field].state == "expired": expired_count += 1
	if expired_count > 0:
		if not _unit(expired_unit) or expired_unit.is_inside_tree() or expired_unit.get_parent() != null or seen.has(expired_unit):
			return _failure("LIVE_DETACHED_TOMBSTONE_REQUIRED")
	# All failure-returning validation has finished before typed reference writes.
	var target_value: Variant = _resolve_tag(state.references.target, id_to_unit, expired_unit)
	var shooter_value: Variant = _resolve_tag(state.references.shooter, id_to_unit, expired_unit)
	projectile.target = target_value
	projectile.shooter = shooter_value
	return {"ok": true, "bound": true, "expired_bindings": expired_count,
		"activation": state.node.activation, "tombstone_release_owned_by_caller": true}

# After ordered attachment and root-wide graph/RNG completion, while still paused.
func activate(projectile: Variant, activation: Dictionary) -> Dictionary:
	if not _projectile(projectile): return _failure("PROJECTILE_INSTANCE")
	var checked: Dictionary = _check_activation(activation)
	if not checked.ok: return checked
	if not projectile.is_inside_tree() or not projectile.get_tree().paused: return _failure("ACTIVATION_REQUIRES_PAUSED_TREE")
	projectile.process_priority = activation.priority
	projectile.process_physics_priority = activation.physics_priority
	projectile.set_process(activation.process)
	projectile.set_physics_process(activation.physics)
	projectile.set_process_input(activation.input)
	projectile.set_process_shortcut_input(activation.shortcut)
	projectile.set_process_unhandled_input(activation.unhandled_input)
	projectile.set_process_unhandled_key_input(activation.unhandled_key)
	projectile.set_block_signals(activation.signals_blocked)
	projectile.process_mode = activation.mode
	return {"ok": true}
