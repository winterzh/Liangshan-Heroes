extends RefCounted
## Pending real Battle.LiBrawnAxesFx: all 7 declarations are accounted for.
## caster/hits use stable Unit tags; game is bound to the caller's new Battle.
## tex uses a fixed trusted constructor texture (or original procedural fallback).
## Never loads save-supplied paths, resolves hits, deals damage or calls RNG.
## Root owns ordered attachment and the complete paused transaction barrier.
const SCHEMA := "defense_li_brawn_axes_state_v1"
const VALUE_FIELDS := ["dur", "elapsed", "resolved"]
const NODE_FIELDS := ["name", "position", "modulate", "basis_x", "basis_y", "visible", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "activation"]
const ACTIVATION_FIELDS := ["mode", "priority", "physics_priority", "process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]
const MAX_ENTITIES := 4096
const MAX_HITS := 4096
const MAX_ID := "9223372036854775807"
var _codec: Variant = null
var _axes_script: Script
var _unit_script: Script
var _trusted_axe_texture: Texture2D = null

func _init(codec_script: Script, axes_script: Script, unit_script: Script, trusted_axe_texture: Texture2D = null) -> void:
	_axes_script = axes_script
	_unit_script = unit_script
	_trusted_axe_texture = trusted_axe_texture
	if codec_script != null and axes_script != null and unit_script != null:
		if codec_script.can_instantiate() and axes_script.can_instantiate() and unit_script.can_instantiate():
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

func _axes(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == _axes_script and not value.is_queued_for_deletion()

func _unit(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value.get_script() == _unit_script and not value.is_queued_for_deletion()

func _battle(value: Variant) -> bool:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value) or not value is Node: return false
	if value.is_queued_for_deletion(): return false
	var script: Variant = value.get_script()
	return script != null and script.get_global_name() == &"Battle"

func _known_ids(ids: Dictionary) -> Dictionary:
	if ids.size() > MAX_ENTITIES: return _failure("REGISTRY_SHAPE")
	for key in ids:
		if not _id(key): return _failure("REGISTRY_ID")
	return {"ok": true}

func _read_values(fx: Variant) -> Dictionary:
	return {"dur": fx.dur, "elapsed": fx.elapsed, "resolved": fx.resolved}

func _check_values(values: Variant) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY or not _fields(values, VALUE_FIELDS): return _failure("VALUE_FIELDS")
	for field in ["dur", "elapsed"]:
		if typeof(values[field]) != TYPE_FLOAT or not is_finite(values[field]): return _failure("VALUE_FLOAT", field)
	if typeof(values.resolved) != TYPE_BOOL: return _failure("RESOLVED_TYPE")
	if values.resolved: return _failure("ALREADY_RESOLVED")
	if values.dur <= 0.0 or values.elapsed < 0.0 or values.elapsed >= values.dur: return _failure("PENDING_PHASE")
	return {"ok": true}

func _visual(texture: Variant) -> Dictionary:
	if texture == null: return {"ok": true, "value": "procedural"}
	if not is_instance_valid(_trusted_axe_texture) or not is_same(texture, _trusted_axe_texture):
		return _failure("UNTRUSTED_TEXTURE")
	return {"ok": true, "value": "trusted_axe"}

func _check_visual(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_STRING or value not in ["procedural", "trusted_axe"]: return _failure("VISUAL_KIND")
	if value == "trusted_axe" and not is_instance_valid(_trusted_axe_texture): return _failure("TRUSTED_TEXTURE_REQUIRED")
	return {"ok": true}

func _hits(values: Variant, registry_or_ids: Dictionary, capturing: bool) -> Dictionary:
	if typeof(values) != TYPE_ARRAY or values.size() > MAX_HITS: return _failure("HITS_SHAPE")
	var result: Array = []
	for index in range(values.size()):
		var hit: Variant = values[index]
		var field: String = "hits[%d]" % index
		if typeof(hit) != TYPE_DICTIONARY or not _fields(hit, ["target", "dmg"]): return _failure("HIT_FIELDS", field)
		if typeof(hit.dmg) != TYPE_FLOAT or not is_finite(hit.dmg) or hit.dmg <= 0.0: return _failure("HIT_DAMAGE", field)
		var tagged: Dictionary = _tag(hit.target, registry_or_ids, field) if capturing else _check_tag(hit.target, registry_or_ids, field)
		if not tagged.ok: return tagged
		# No sweep, deduplication or secondary damage recomputation.
		result.append({"target": tagged.value if capturing else hit.target, "dmg": hit.dmg})
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

func _read_node(fx: Variant) -> Dictionary:
	# Generated @ names are rebuilt when attached in the saved effect order.
	var saved_name: String = "" if String(fx.name).begins_with("@") else String(fx.name)
	return {"name": saved_name, "position": fx.position, "modulate": fx.modulate, "basis_x": fx.transform.x, "basis_y": fx.transform.y,
		"visible": fx.visible, "self_modulate": fx.self_modulate, "z_index": fx.z_index,
		"z_as_relative": fx.z_as_relative, "show_behind_parent": fx.show_behind_parent,
		"top_level": fx.top_level, "y_sort_enabled": fx.y_sort_enabled,
		"activation": {"mode": int(fx.process_mode), "priority": fx.process_priority,
			"physics_priority": fx.process_physics_priority, "process": fx.is_processing(),
			"physics": fx.is_physics_processing(), "input": fx.is_processing_input(),
			"shortcut": fx.is_processing_shortcut_input(), "unhandled_input": fx.is_processing_unhandled_input(),
			"unhandled_key": fx.is_processing_unhandled_key_input(), "signals_blocked": fx.is_blocking_signals()}}

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



func capture(fx: Variant, content_version: String, object_to_unit_id: Dictionary) -> Dictionary:
	if _codec == null: return _failure("MODULE_CONFIGURATION")
	if not _version(content_version): return _failure("CONTENT_VERSION")
	if not _axes(fx): return _failure("AXES_INSTANCE_OR_PENDING_DELETE")
	if not _battle(fx.game): return _failure("BATTLE_CONTEXT_REQUIRED")
	var registry: Dictionary = _registry(object_to_unit_id)
	if not registry.ok: return registry
	var values: Dictionary = _read_values(fx)
	var checked: Dictionary = _check_values(values)
	if not checked.ok: return checked
	var node: Dictionary = _read_node(fx)
	checked = _check_node(node)
	if not checked.ok: return checked
	var caster_tag: Dictionary = _tag(fx.caster, object_to_unit_id, "caster")
	if not caster_tag.ok: return caster_tag
	var hits: Dictionary = _hits(fx.hits, object_to_unit_id, true)
	if not hits.ok: return hits
	var visual: Dictionary = _visual(fx.tex)
	if not visual.ok: return visual
	var encoded: Dictionary = _codec.encode({"values": values, "node": node,
		"caster": caster_tag.value, "hits": hits.value, "visual": visual.value})
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
	if typeof(payload) != TYPE_DICTIONARY or not _fields(payload, ["values", "node", "caster", "hits", "visual"]): return _failure("PAYLOAD_FIELDS")
	checked = _check_values(payload.values)
	if not checked.ok: return checked
	checked = _check_node(payload.node)
	if not checked.ok: return checked
	checked = _check_visual(payload.visual)
	if not checked.ok: return checked
	checked = _check_tag(payload.caster, known_unit_ids, "caster")
	if not checked.ok: return checked
	var hits: Dictionary = _hits(payload.hits, known_unit_ids, false)
	if not hits.ok: return hits
	return {"ok": true, "values": payload.values, "node": payload.node,
		"caster": payload.caster, "hits": hits.value, "visual": payload.visual}

func instantiate(record: Variant, content_version: String, known_unit_ids: Dictionary) -> Dictionary:
	var state: Dictionary = validate(record, content_version, known_unit_ids)
	if not state.ok: return state
	var fx: Variant = _axes_script.new()
	fx.set_block_signals(true)
	fx.process_mode = Node.PROCESS_MODE_DISABLED
	fx.dur = state.values.dur
	fx.elapsed = state.values.elapsed
	fx.resolved = state.values.resolved
	fx.tex = _trusted_axe_texture if state.visual == "trusted_axe" else null
	var node: Dictionary = state.node
	if not node.name.is_empty(): fx.name = node.name
	fx.transform = Transform2D(node.basis_x, node.basis_y, node.position)
	fx.modulate = node.modulate
	fx.visible = node.visible
	fx.self_modulate = node.self_modulate
	fx.z_index = node.z_index
	fx.z_as_relative = node.z_as_relative
	fx.show_behind_parent = node.show_behind_parent
	fx.top_level = node.top_level
	fx.y_sort_enabled = node.y_sort_enabled
	return {"ok": true, "fx": fx, "activation": node.activation,
		"pending_bind_fields": ["caster", "hits", "game"], "bound": false}

func _resolve_tag(tag: Dictionary, units: Dictionary, expired_unit: Variant) -> Variant:
	match tag.state:
		"entity": return units[tag.id]
		"expired": return expired_unit
	return null

# Root frees the shared tombstone only after every graph binding is complete.
func bind(fx: Variant, record: Variant, content_version: String, id_to_unit: Dictionary, new_battle: Variant, expired_unit: Variant = null) -> Dictionary:
	if not _axes(fx) or fx.get_parent() != null or fx.is_inside_tree() or not fx.is_blocking_signals() or fx.process_mode != Node.PROCESS_MODE_DISABLED:
		return _failure("SHELL_NOT_DETACHED_DISABLED")
	if not _battle(new_battle): return _failure("NEW_BATTLE_REQUIRED")
	var known: Dictionary = {}
	var seen: Dictionary = {}
	for key in id_to_unit:
		if not _id(key) or not _unit(id_to_unit[key]): return _failure("BIND_REGISTRY")
		if seen.has(id_to_unit[key]): return _failure("BIND_DUPLICATE_OBJECT")
		seen[id_to_unit[key]] = true
		known[key] = true
	var state: Dictionary = validate(record, content_version, known)
	if not state.ok: return state
	var expired_count: int = 1 if state.caster.state == "expired" else 0
	for hit in state.hits:
		if hit.target.state == "expired": expired_count += 1
	if expired_count > 0:
		if not _unit(expired_unit) or expired_unit.is_inside_tree() or expired_unit.get_parent() != null or seen.has(expired_unit):
			return _failure("LIVE_DETACHED_TOMBSTONE_REQUIRED")
	var caster_value: Variant = _resolve_tag(state.caster, id_to_unit, expired_unit)
	var hits: Array = []
	for hit in state.hits:
		hits.append({"target": _resolve_tag(hit.target, id_to_unit, expired_unit), "dmg": hit.dmg})
	# No damage, effect spawn or texture load: only assign validated state.
	fx.caster = caster_value
	fx.hits = hits
	fx.game = new_battle
	return {"ok": true, "bound": true, "expired_bindings": expired_count,
		"activation": state.node.activation, "tombstone_release_owned_by_caller": true}

func activate(fx: Variant, activation: Dictionary) -> Dictionary:
	if not _axes(fx): return _failure("AXES_INSTANCE")
	var checked: Dictionary = _check_activation(activation)
	if not checked.ok: return checked
	if not fx.is_inside_tree() or not fx.get_tree().paused: return _failure("ACTIVATION_REQUIRES_PAUSED_TREE")
	fx.process_priority = activation.priority
	fx.process_physics_priority = activation.physics_priority
	fx.set_process(activation.process)
	fx.set_physics_process(activation.physics)
	fx.set_process_input(activation.input)
	fx.set_process_shortcut_input(activation.shortcut)
	fx.set_process_unhandled_input(activation.unhandled_input)
	fx.set_process_unhandled_key_input(activation.unhandled_key)
	fx.set_block_signals(activation.signals_blocked)
	fx.process_mode = activation.mode
	return {"ok": true}
