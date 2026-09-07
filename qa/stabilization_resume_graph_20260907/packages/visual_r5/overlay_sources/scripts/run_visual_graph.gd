extends RefCounted
## Explicit shared visual graph subset. Real current Battle Fx scripts, no skill replay.
## Outer factory owns the paused barrier, Unit graph/tombstones and final activation.
## Unknown scripts/children fail the snapshot; they are never omitted or placeholders.
const SCHEMA := "defense_visual_graph_subset_v1"
const LIMIT := 4096
const TEX := "res://assets/vfx/gong_beast_charge_run.png"
const FIELDS := {
	"container": [],
	"hit_spark": ["dur", "t", "heavy", "_seed"],
	"float_label": ["amount", "crit", "on_player", "t"],
	"bolt": ["col", "chain", "art", "_trail", "_t"],
	"trap_marker": ["key", "col", "rad", "armed", "_t"],
	"beast_stampede": ["dur", "t", "dir", "length", "travel_speed", "count", "_pack"]}
const NODE_FIELDS := ["name", "position", "modulate", "basis_x", "basis_y", "visible", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "activation"]
const ACTIVATION_FIELDS := ["mode", "priority", "physics_priority", "process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]
var _codec: Variant
var _battle: Script
var _unit: Script
var _objects: Dictionary = {}
var _records: Dictionary = {}
var _nodes: Dictionary = {}
var _expired: Dictionary = {}
var _root: Node2D
var _activation: Dictionary = {}
var _committed := false

func _init(codec: Script, battle: Script, unit: Script) -> void:
	_codec = codec.new()
	_battle = battle
	_unit = unit

func _failure(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field}

func _fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

func _id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 19: return false
	if value[0] == "0": return false
	for ch: String in value:
		if ch < "0" or ch > "9": return false
	return value.length() < 19 or value <= "9223372036854775806"

func _kind(node: Node2D) -> String:
	if node.get_script() == null and node.get_class() == "Node2D": return "container"
	if node.get_script() == _battle.BoltFx: return "bolt"
	if node.get_script() == _battle.TrapMarkerFx: return "trap_marker"
	if node.get_script() == _battle.BeastStampedeFx: return "beast_stampede"
	if node.get_script() == _battle.HitSpark: return "hit_spark"
	if node.get_script() == _battle.FloatLabel: return "float_label"
	return ""

func _new(kind: String) -> Node2D:
	match kind:
		"container": return Node2D.new()
		"bolt": return _battle.BoltFx.new()
		"trap_marker": return _battle.TrapMarkerFx.new()
		"beast_stampede": return _battle.BeastStampedeFx.new()
		"hit_spark": return _battle.HitSpark.new()
		"float_label": return _battle.FloatLabel.new()
	return null

func _tag(value: Variant, units: Dictionary) -> Dictionary:
	if typeof(value) == TYPE_NIL: return {"ok": true, "value": {"state": "none"}}
	if typeof(value) != TYPE_OBJECT: return _failure("UNIT_REFERENCE_TYPE")
	if not is_instance_valid(value): return {"ok": true, "value": {"state": "expired"}}
	if value.get_script() != _unit or value.is_queued_for_deletion() or not units.has(value): return _failure("UNIT_REFERENCE_UNREGISTERED")
	return {"ok": true, "value": {"state": "entity", "id": units[value]}}

func _tag_check(value: Variant, known: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("state")) != TYPE_STRING: return _failure("UNIT_REFERENCE_TAG")
	if value.state in ["none", "expired"]:
		if not _fields(value, ["state"]): return _failure("UNIT_REFERENCE_TAG")
	elif value.state == "entity":
		if not _fields(value, ["state", "id"]) or not _id(value.id) or not known.has(value.id): return _failure("UNIT_REFERENCE_ID")
	else: return _failure("UNIT_REFERENCE_TAG")
	return {"ok": true}

func _values(node: Node2D, kind: String) -> Dictionary:
	var values: Dictionary = {}
	for field: String in FIELDS[kind]: values[field] = node.get(field)
	return values

func _values_check(values: Variant, kind: String) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY or not _fields(values, FIELDS[kind]): return _failure("VALUE_FIELDS", kind)
	var floats: Array = ["_t"] if kind in ["bolt", "trap_marker"] else []
	if kind == "trap_marker": floats.append("rad")
	if kind == "beast_stampede": floats = ["dur", "t", "length", "travel_speed"]
	if kind == "hit_spark": floats = ["dur", "t"]
	if kind == "float_label": floats = ["t"]
	for key: String in floats:
		if typeof(values[key]) != TYPE_FLOAT or not is_finite(values[key]): return _failure("VALUE_FLOAT", key)
	if kind in ["bolt", "trap_marker"]:
		if typeof(values.col) != TYPE_COLOR: return _failure("VALUE_COLOR")
		if values._t < 0.0: return _failure("VALUE_ELAPSED")
		var key: String = "art" if kind == "bolt" else "key"
		if typeof(values[key]) != TYPE_STRING or values[key].length() > 128: return _failure("VALUE_STRING")
		key = "chain" if kind == "bolt" else "armed"
		if typeof(values[key]) != TYPE_BOOL: return _failure("VALUE_BOOL")
	if kind == "bolt":
		if typeof(values._trail) != TYPE_ARRAY or values._trail.size() > 10: return _failure("TRAIL_SIZE")
		for point: Variant in values._trail:
			if typeof(point) != TYPE_VECTOR2 or not point.is_finite(): return _failure("TRAIL_POINT")
	if kind == "trap_marker" and values.rad < 0.0: return _failure("TRAP_RADIUS")
	if kind == "hit_spark":
		if typeof(values.heavy) != TYPE_BOOL or typeof(values._seed) != TYPE_INT or values.dur <= 0.0 or values.t <= 0.0 or values.t > values.dur: return _failure("HIT_SPARK_VALUES")
	if kind == "float_label":
		if typeof(values.amount) != TYPE_INT or typeof(values.crit) != TYPE_BOOL or typeof(values.on_player) != TYPE_BOOL: return _failure("FLOAT_LABEL_VALUES")
		if values.t < 0.0 or values.t >= (0.95 if values.crit else 0.72): return _failure("FLOAT_LABEL_LIFETIME")
	if kind == "beast_stampede":
		if values.dur <= 0.0 or values.t <= 0.0 or values.t > values.dur or values.length <= 0.0 or values.travel_speed <= 0.0: return _failure("BEAST_LIFETIME")
		if typeof(values.dir) != TYPE_VECTOR2 or not values.dir.is_finite(): return _failure("BEAST_DIRECTION")
		if typeof(values.count) != TYPE_INT or values.count < 1 or values.count > LIMIT: return _failure("BEAST_COUNT")
		if typeof(values._pack) != TYPE_ARRAY or values._pack.size() != values.count: return _failure("BEAST_PACK_SIZE")
		for row: Variant in values._pack:
			if typeof(row) != TYPE_DICTIONARY or not _fields(row, ["side", "delay", "size"]): return _failure("BEAST_PACK_FIELDS")
			for field: String in row:
				if typeof(row[field]) != TYPE_FLOAT or not is_finite(row[field]): return _failure("BEAST_PACK_FLOAT")
	return {"ok": true}

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


func _registry(registry: Dictionary, reversed: bool) -> Dictionary:
	if registry.size() > LIMIT: return _failure("REGISTRY_SIZE")
	var known: Dictionary = {}
	var seen: Dictionary = {}
	for key: Variant in registry:
		var id: Variant = key if reversed else registry[key]
		var node: Variant = registry[key] if reversed else key
		if not _id(id) or typeof(node) != TYPE_OBJECT or not is_instance_valid(node) or node.get_script() != _unit or node.is_queued_for_deletion(): return _failure("REGISTRY_ROW")
		if str(node.entity_id) != id or known.has(id) or seen.has(node): return _failure("REGISTRY_ID")
		known[id] = true
		seen[node] = true
	return {"ok": true, "known": known}

func capture(root: Node2D, version: String, units: Dictionary) -> Dictionary:
	_objects.clear()
	_records.clear()
	if version.is_empty() or version.length() > 256: return _failure("CONTENT_VERSION")
	var registry: Dictionary = _registry(units, false)
	if not registry.ok: return registry
	if root == null or not is_instance_valid(root) or _kind(root) != "container" or root.is_queued_for_deletion(): return _failure("VISUAL_ROOT")
	var rows: Array = []
	var stack: Array = [{"node": root, "parent": "", "index": 0}]
	while not stack.is_empty():
		if rows.size() >= LIMIT: return _failure("VISUAL_LIMIT")
		var entry: Dictionary = stack.pop_back()
		var node: Variant = entry.node
		if not is_instance_valid(node) or not node is Node2D or node.is_queued_for_deletion(): return _failure("VISUAL_NODE")
		var kind: String = _kind(node)
		if kind.is_empty(): return _failure("UNSUPPORTED_VISUAL_SCRIPT", str(node.get_script()))
		# Current supported effects create no child nodes; containers express world/root order.
		if node.get_child_count(true) != node.get_child_count(): return _failure("UNSUPPORTED_INTERNAL_VISUAL")
		if kind != "container" and node.get_child_count(true) != 0: return _failure("UNSUPPORTED_VISUAL_CHILDREN", kind)
		if kind == "beast_stampede" and (not node.tex is Texture2D or node.tex.resource_path != TEX): return _failure("BEAST_TEXTURE")
		var id: String = str(rows.size() + 1)
		var refs: Dictionary = {}
		if kind == "bolt":
			var tag: Dictionary = _tag(node.chain_from, units)
			if not tag.ok: return tag
			refs["chain_from"] = tag.value
		var row: Dictionary = {"id": id, "parent": entry.parent, "index": entry.index,
			"kind": kind, "node": _read_node(node), "values": _values(node, kind), "references": refs}
		rows.append(row)
		_objects[node] = id
		_records[id] = row
		for index: int in range(node.get_child_count(true) - 1, -1, -1):
			stack.append({"node": node.get_child(index, true), "parent": id, "index": index})
	var encoded: Dictionary = _codec.encode(rows)
	if not encoded.ok: return encoded
	var wire: Dictionary = {"schema": SCHEMA, "content_version": version, "records": encoded.value}
	var checked: Dictionary = validate(wire, version, registry.known)
	if not checked.ok: return checked
	return {"ok": true, "value": wire, "count": rows.size(), "complete_visual_graph": false}

func validate(record: Variant, version: String, known: Dictionary) -> Dictionary:
	if typeof(record) != TYPE_DICTIONARY or not _fields(record, ["schema", "content_version", "records"]): return _failure("VISUAL_SCHEMA")
	if record.schema != SCHEMA or record.content_version != version or version.is_empty() or version.length() > 256: return _failure("VISUAL_VERSION")
	for id: Variant in known:
		if not _id(id): return _failure("REGISTRY_ID")
	var decoded: Dictionary = _codec.decode(record.records)
	if not decoded.ok: return decoded
	if typeof(decoded.value) != TYPE_ARRAY or decoded.value.is_empty() or decoded.value.size() > LIMIT: return _failure("VISUAL_RECORDS")
	var indexed: Dictionary = {}
	var counts: Dictionary = {}
	var ancestry: Array = []
	for row: Variant in decoded.value:
		if typeof(row) != TYPE_DICTIONARY or not _fields(row, ["id", "parent", "index", "kind", "node", "values", "references"]): return _failure("VISUAL_RECORD_FIELDS")
		if typeof(row.id) != TYPE_STRING or row.id != str(indexed.size() + 1): return _failure("VISUAL_ID_ORDER")
		if typeof(row.kind) != TYPE_STRING or not FIELDS.has(row.kind): return _failure("VISUAL_KIND")
		if typeof(row.parent) != TYPE_STRING or typeof(row.index) != TYPE_INT: return _failure("VISUAL_PARENT")
		if indexed.is_empty():
			if row.kind != "container" or row.parent != "" or row.index != 0: return _failure("VISUAL_ROOT_RECORD")
		else:
			if not indexed.has(row.parent) or indexed[row.parent].kind != "container": return _failure("VISUAL_PARENT_KIND")
			while not ancestry.is_empty() and ancestry.back() != row.parent: ancestry.pop_back()
			if ancestry.is_empty(): return _failure("VISUAL_PREORDER")
			if row.index != int(counts.get(row.parent, 0)): return _failure("VISUAL_SIBLING_ORDER")
			counts[row.parent] = row.index + 1
		var nc: Dictionary = _check_node(row.node)
		if not nc.ok: return nc
		var vc: Dictionary = _values_check(row.values, row.kind)
		if not vc.ok: return vc
		if typeof(row.references) != TYPE_DICTIONARY or not _fields(row.references, ["chain_from"] if row.kind == "bolt" else []): return _failure("VISUAL_REFERENCES")
		if row.kind == "bolt":
			var tc: Dictionary = _tag_check(row.references.chain_from, known)
			if not tc.ok: return tc
		indexed[row.id] = row
		ancestry.append(row.id)
	_records = indexed
	return {"ok": true, "rows": decoded.value}

func _assign_node(node: Node2D, state: Dictionary) -> void:
	if not state.name.is_empty(): node.name = state.name
	node.transform = Transform2D(state.basis_x, state.basis_y, state.position)
	for field: String in ["modulate", "visible", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled"]:
		node.set(field, state[field])

func prepare(record: Variant, version: String, units: Dictionary, expired_unit: Variant = null) -> Dictionary:
	if is_instance_valid(_root) or not _nodes.is_empty(): return _failure("VISUAL_ALREADY_PREPARED")
	var registry: Dictionary = _registry(units, true)
	if not registry.ok: return registry
	var checked: Dictionary = validate(record, version, registry.known)
	if not checked.ok: return checked
	for row: Dictionary in checked.rows:
		if row.kind == "bolt" and row.references.chain_from.state == "expired":
			if typeof(expired_unit) != TYPE_OBJECT or not is_instance_valid(expired_unit) or expired_unit.get_script() != _unit or expired_unit.get_parent() != null or expired_unit.is_inside_tree() or units.values().has(expired_unit): return _failure("LIVE_UNIT_TOMBSTONE_REQUIRED")
	# All fallible record/reference checks precede any allocation or typed assignment.
	for row: Dictionary in checked.rows:
		var node: Node2D = _new(row.kind)
		node.set_block_signals(true)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if row.kind in ["beast_stampede", "hit_spark"]: node.set_meta("_run_restore_prepared", true)
		_assign_node(node, row.node)
		for field: String in FIELDS[row.kind]: node.set(field, row.values[field])
		if row.kind == "bolt":
			var tag: Dictionary = row.references.chain_from
			node.chain_from = units[tag.id] if tag.state == "entity" else (expired_unit if tag.state == "expired" else null)
		_nodes[row.id] = node
		_activation[row.id] = row.node.activation
		if row.parent == "": _root = node
		else: _nodes[row.parent].add_child(node)
	return {"ok": true, "root": _root, "nodes": _nodes.duplicate(), "created_count": _nodes.size(), "complete_visual_graph": false}

func encode_token(value: Variant, expected: String) -> Dictionary:
	if expected not in ["bolt", "trap_marker"]: return _failure("FX_EXPECTED_KIND")
	if typeof(value) == TYPE_NIL: return {"ok": true, "value": {"state": "none"}}
	if typeof(value) != TYPE_OBJECT: return _failure("FX_OBJECT")
	if not is_instance_valid(value): return {"ok": true, "value": {"state": "expired"}}
	if not value is Node2D or _kind(value) != expected or not _objects.has(value): return _failure("FX_UNREGISTERED")
	return {"ok": true, "value": {"state": "node", "id": _objects[value]}}

func validate_token(value: Variant, expected: String) -> Dictionary:
	if expected not in ["bolt", "trap_marker"]: return _failure("FX_EXPECTED_KIND")
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("state")) != TYPE_STRING: return _failure("FX_TAG")
	if value.state in ["none", "expired"]:
		if not _fields(value, ["state"]): return _failure("FX_TAG")
	elif value.state == "node":
		if not _fields(value, ["state", "id"]) or not _id(value.id) or not _records.has(value.id) or _records[value.id].kind != expected: return _failure("FX_NODE_KIND")
	else: return _failure("FX_TAG")
	return {"ok": true}

func decode_token(value: Variant, expected: String) -> Dictionary:
	var checked: Dictionary = validate_token(value, expected)
	if not checked.ok: return checked
	if value.state == "none": return {"ok": true, "value": null}
	if value.state == "node":
		if not _nodes.has(value.id): return _failure("FX_NOT_PREPARED")
		return {"ok": true, "value": _nodes[value.id]}
	if not _expired.has(expected):
		var node: Node2D = _new(expected)
		node.set_block_signals(true)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		_expired[expected] = node
	return {"ok": true, "value": _expired[expected]}

func release_expired_fx() -> void:
	# Root calls only after every effect array has captured its typed references.
	for node: Node2D in _expired.values():
		if is_instance_valid(node): node.free()
	_expired.clear()

func activate() -> Dictionary:
	if not is_instance_valid(_root) or not _root.is_inside_tree() or not _root.get_tree().paused: return _failure("ACTIVATION_REQUIRES_PAUSED_TREE")
	if not _expired.is_empty(): return _failure("FX_TOMBSTONES_NOT_RELEASED")
	if _committed: return _failure("VISUAL_ALREADY_ACTIVATED")
	for id: String in _nodes:
		var node: Node2D = _nodes[id]
		if not is_instance_valid(node) or not node.is_node_ready() or not node.is_blocking_signals() or node.process_mode != Node.PROCESS_MODE_DISABLED: return _failure("VISUAL_ACTIVATION_STATE")
	for id: String in _nodes:
		var node: Node2D = _nodes[id]
		var state: Dictionary = _activation[id]
		node.process_priority = state.priority
		node.process_physics_priority = state.physics_priority
		node.set_process(state.process)
		node.set_physics_process(state.physics)
		node.set_process_input(state.input)
		node.set_process_shortcut_input(state.shortcut)
		node.set_process_unhandled_input(state.unhandled_input)
		node.set_process_unhandled_key_input(state.unhandled_key)
		node.set_block_signals(state.signals_blocked)
		node.process_mode = state.mode
		if node.has_meta("_run_restore_prepared"): node.remove_meta("_run_restore_prepared")
	_committed = true
	return {"ok": true}

func dispose() -> void:
	release_expired_fx()
	if not _committed and is_instance_valid(_root): _root.free()
	_root = null
	_nodes.clear()
	_activation.clear()
