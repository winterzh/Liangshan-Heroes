extends RefCounted
## World composition only. UI/camera/Steam and final Battle installation are separate.
const B := preload("res://scripts/battle.gd")
const M := preload("res://scripts/game_map.gd")
const U := preload("res://scripts/unit.gd")
const S := preload("res://scripts/world_shadow.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Fog := preload("res://scripts/run_fog_state.gd")
const SCHEMA := "battle_world_display_v1"
const ROLES := ["map", "units", "fx", "fog", "water", "dapple", "shadow"]
var _codec: Variant = Codec.new()
var _node: Variant = Fog.new({}, B, M, Codec, B.FogLayer)
var _plan: Array = []
var _owner: Variant = null
var _order: Array = []
var _active := false

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _fields(value: Variant, keys: Array) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.size() == keys.size() and value.has_all(keys)

func _safe(node: Node2D) -> bool:
	if node.is_queued_for_deletion() or node.material != null or not node.get_meta_list().is_empty(): return false
	for signal_info: Dictionary in node.get_signal_list():
		for connection: Dictionary in node.get_signal_connection_list(signal_info.name):
			# Godot creates these two ref-counted Viewport hooks on tree entry.
			# They are recreated by the engine, never serialized as user callbacks.
			var call: Callable = connection.callable
			if signal_info.name != &"child_order_changed" or connection.flags != Object.CONNECT_REFERENCE_COUNTED or not node.is_inside_tree() or call.get_object() != node.get_viewport(): return false
			var method: String = call.get_method()
			if method == "Viewport::canvas_parent_mark_dirty" and call.get_bound_arguments() == [node]: continue
			if method == "Viewport::gui_set_root_order_dirty" and call.get_bound_arguments().is_empty(): continue
			return false
	return true

func _texture(texture: Variant) -> Dictionary:
	if texture == null: return {"state": "none"}
	if not texture is Texture2D or texture.get_script() != null: return {}
	var img: Image = texture.get_image()
	if img == null or img.is_empty(): return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(img.get_data())
	return {"state": "image", "width": img.get_width(), "height": img.get_height(), "format": int(img.get_format()), "mipmaps": img.has_mipmaps(), "sha256": hash.finish().hex_encode()}

func _templates(owner: Variant) -> Dictionary:
	# Rebuild only these trusted rendering resources. Never run Battle._ready.
	var staging := B.new()
	staging.map = owner.map
	staging.world = Node2D.new(); staging.add_child(staging.world)
	staging._build_dapple()
	var dapple: Node2D = staging.world.get_child(0)
	staging.world.remove_child(dapple)
	var water := B.LiangshanWaterBackdrop.new()
	water.ws = Vector2(owner.map.w * M.CELL, owner.map.h * M.CELL)
	var art: Variant = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Art")
	if art != null and art.get_script().resource_path == "res://scripts/art_db.gd": water.tex = art.terrain_texture("water")
	if water.tex is AtlasTexture:
		var img: Image = water.tex.get_image()
		if img != null and not img.is_empty(): water.tex = ImageTexture.create_from_image(img)
	var shadow := S.ShadowBatch.new(); shadow.setup(owner)
	staging.map = null; staging.free()
	return {"water": water, "dapple": dapple, "shadow": shadow}

func _free_templates(templates: Dictionary) -> void:
	for node: Node in templates.values(): node.free()

func _shadow_fixed(batch: Variant, template: Variant) -> bool:
	if batch.get_child_count(true) != 1 or batch.get_child(0) != batch.paired_instances: return false
	var node: Variant = batch.paired_instances
	var mm: Variant = batch.paired_multimesh
	if node.get_script() != null or not node is MultiMeshInstance2D or not _safe(node) or node.get_child_count(true) != 0 or node.texture != null or node.multimesh != mm: return false
	if mm == null or mm.get_script() != null or mm.transform_format != MultiMesh.TRANSFORM_2D or not mm.use_colors or mm.use_custom_data or mm.mesh == null or mm.mesh.get_script() != null or mm.mesh.get_surface_count() != 1: return false
	if mm.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES: return false
	if mm.mesh.surface_get_arrays(0) != template.paired_multimesh.mesh.surface_get_arrays(0): return false
	var material: Variant = mm.mesh.surface_get_material(0)
	var expected: Variant = template.paired_multimesh.mesh.surface_get_material(0)
	if not material is ShaderMaterial or material.get_script() != null or material.next_pass != null or material.shader == null or material.shader.code != expected.shader.code: return false
	if not material.shader.get_shader_uniform_list().is_empty(): return false
	return mm.custom_aabb == template.paired_multimesh.custom_aabb

func _role(owner: Variant, node: Node) -> String:
	if node == owner.map: return "map"
	if node == owner.units_root: return "units"
	if node == owner.fx_root: return "fx"
	if node == owner._fog_layer: return "fog"
	if node.get_script() == B.LiangshanWaterBackdrop: return "water"
	if node.get_script() == B.DappleLayer: return "dapple"
	if node.get_script() == S.ShadowBatch: return "shadow"
	return ""

func capture(owner: Variant, ids: Dictionary) -> Dictionary:
	if not is_instance_valid(owner) or owner.get_script() != B or not is_instance_valid(owner.world) or owner.world.get_parent() != owner: return _bad("DISPLAY_OWNER")
	for node: Node2D in [owner.world, owner.units_root]:
		if node.get_script() != null or node.get_class() != "Node2D" or not _safe(node): return _bad("DISPLAY_CONTAINER")
	var templates: Dictionary = _templates(owner)
	var rows: Array = []
	var error := ""
	var seen: Array = []
	for node: Node in owner.world.get_children(true):
		var role: String = _role(owner, node)
		if role.is_empty() or role in seen: error = "DISPLAY_UNKNOWN_OR_DUPLICATE_CHILD"; break
		seen.append(role)
		var row: Dictionary = {"role": role}
		if role in ["water", "dapple", "shadow"]:
			if not _safe(node): error = "DISPLAY_NODE_OVERRIDE"; break
			row["node"] = _node._node_values(node)
			if role != "shadow":
				if node.get_child_count(true) != 0 or node.ws != templates[role].ws or _texture(node.tex) != _texture(templates[role].tex): error = "DISPLAY_TEXTURE_CHANGED"; break
				row["texture"] = _texture(node.tex); row["ws"] = node.ws
			else:
				if node.battle != owner or not _shadow_fixed(node, templates.shadow): error = "DISPLAY_SHADOW_RESOURCE"; break
				var retained: Array = []
				for unit: Variant in node.retained_dying_units:
					if not is_instance_valid(unit) or not ids.has(unit) or unit.get_script() != U or unit.battle != owner or retained.has(ids[unit]): error = "DISPLAY_SHADOW_REFERENCE"; break
					retained.append(ids[unit])
				row["retained"] = retained
				row["capacity"] = node.capacity; row["active"] = node.active_count; row["retained_visible"] = node.retained_dying_visible
				row["instances"] = _node._node_values(node.paired_instances)
				row["buffer"] = node.paired_multimesh.buffer.to_byte_array().hex_encode()
				if node.capacity != node.paired_multimesh.instance_count or node.active_count != node.paired_multimesh.visible_instance_count: error = "DISPLAY_SHADOW_COUNTS"; break
		rows.append(row)
	_free_templates(templates)
	if not error.is_empty(): return _bad(error)
	var raw := {"schema": SCHEMA, "world": _node._node_values(owner.world), "units": _node._node_values(owner.units_root), "children": rows}
	var checked: Dictionary = _validate(raw, ids.values())
	if not checked.ok: return checked
	return encode_record(raw)

func _validate(raw: Variant, ids: Array) -> Dictionary:
	if not _fields(raw, ["schema", "world", "units", "children"]) or raw.schema != SCHEMA or not _node._node_valid(raw.world) or not _node._node_valid(raw.units) or typeof(raw.children) != TYPE_ARRAY: return _bad("DISPLAY_RECORD")
	var seen: Array = []
	for row: Variant in raw.children:
		if typeof(row) != TYPE_DICTIONARY or typeof(row.get("role")) != TYPE_STRING or row.role not in ROLES or row.role in seen: return _bad("DISPLAY_CHILD_ROLE")
		seen.append(row.role)
		if row.role in ["map", "units", "fx", "fog"]:
			if not _fields(row, ["role"]): return _bad("DISPLAY_BOUND_CHILD_FIELDS")
			continue
		var fields := ["role", "node", "texture", "ws"] if row.role != "shadow" else ["role", "node", "retained", "capacity", "active", "retained_visible", "instances", "buffer"]
		if not _fields(row, fields) or not _node._node_valid(row.node): return _bad("DISPLAY_CHILD_FIELDS")
		if row.role != "shadow":
			if typeof(row.ws) != TYPE_VECTOR2 or not row.ws.is_finite() or typeof(row.texture) != TYPE_DICTIONARY: return _bad("DISPLAY_TEXTURE_RECORD")
		else:
			if not _node._node_valid(row.instances) or typeof(row.retained) != TYPE_ARRAY or typeof(row.buffer) != TYPE_STRING: return _bad("DISPLAY_SHADOW_RECORD")
			for key: String in ["capacity", "active", "retained_visible"]:
				if typeof(row[key]) != TYPE_INT or row[key] < 0: return _bad("DISPLAY_SHADOW_COUNT")
			if row.capacity < S.INITIAL_BATCH_CAPACITY or row.capacity > 4096 or row.capacity & (row.capacity - 1) != 0 or row.active > row.capacity or row.retained_visible > row.active or row.buffer.length() != row.capacity * 12 * 8: return _bad("DISPLAY_SHADOW_CAPACITY")
			var used: Array = []
			for id: Variant in row.retained:
				if typeof(id) != TYPE_STRING or id not in ids or id in used: return _bad("DISPLAY_SHADOW_ID")
				used.append(id)
			for character: String in row.buffer:
				if character not in "0123456789abcdef": return _bad("DISPLAY_SHADOW_HEX")
			for value: float in row.buffer.hex_decode().to_float32_array():
				if not is_finite(value): return _bad("DISPLAY_SHADOW_BUFFER")
	for role: String in ["map", "units", "fx"]:
		if role not in seen: return _bad("DISPLAY_REQUIRED_CHILD")
	return {"ok": true, "value": raw}

func _assign(node: Node2D, values: Dictionary) -> void:
	if not values.name.is_empty(): node.name = values.name
	node.transform = Transform2D(values.basis_x, values.basis_y, values.position)
	for key: String in ["visible", "modulate", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "light_mask", "visibility_layer", "texture_filter", "texture_repeat", "use_parent_material", "clip_children"]: node.set(key, values[key])
	node.physics_interpolation_mode = values.interpolation
	node.process_mode = Node.PROCESS_MODE_DISABLED; node.set_block_signals(true)
	_plan.append({"node": node, "activation": values.activation})

func bind(owner: Variant, record: Variant, units: Dictionary) -> Dictionary:
	if _owner != null or not is_instance_valid(owner) or owner.get_script() != B or owner.is_inside_tree(): return _bad("DISPLAY_BIND_PHASE")
	var decoded: Dictionary = decode_record(record)
	if not decoded.ok: return decoded
	var checked: Dictionary = _validate(decoded.value, units.keys())
	if not checked.ok: return checked
	var raw: Dictionary = decoded.value
	var templates: Dictionary = _templates(owner)
	var nodes: Dictionary = {"map": owner.map, "units": owner.units_root, "fx": owner.fx_root}
	if owner._fog_layer != null: nodes["fog"] = owner._fog_layer
	var error := ""
	for row: Dictionary in raw.children:
		if row.role in ["water", "dapple"]:
			if row.ws != templates[row.role].ws or row.texture != _texture(templates[row.role].tex): error = "DISPLAY_TRUSTED_TEXTURE_MISMATCH"; break
		elif row.role == "fog" and not nodes.has("fog"): error = "DISPLAY_FOG_MISSING"; break
	if (raw.children.any(func(row): return row.role == "fog")) != nodes.has("fog"): error = "DISPLAY_FOG_PRESENCE"
	if owner.world.get_child_count(true) != nodes.size(): error = "DISPLAY_DESTINATION_CHILDREN"
	if not error.is_empty(): _free_templates(templates); return _bad(error)
	_assign(owner.world, raw.world); _assign(owner.units_root, raw.units)
	for row: Dictionary in raw.children:
		var role: String = row.role
		if templates.has(role):
			var node: Node2D = templates[role]; templates.erase(role)
			_assign(node, row.node)
			if role == "water": node.set_meta("_run_restore_prepared", true)
			if role == "shadow":
				node._resize(row.capacity); node.active_count = row.active; node.retained_dying_visible = row.retained_visible
				node.paired_multimesh.buffer = row.buffer.hex_decode().to_float32_array(); node.paired_multimesh.visible_instance_count = row.active
				for id: String in row.retained: node.retained_dying_units.append(units[id])
				_assign(node.paired_instances, row.instances)
			owner.world.add_child(node); nodes[role] = node
		_order.append(nodes[role])
	for index: int in range(_order.size()): owner.world.move_child(_order[index], index)
	_free_templates(templates)
	_owner = owner
	return {"ok": true}

func activate() -> Dictionary:
	if _active or not is_instance_valid(_owner) or not _owner.world.is_inside_tree() or not _owner.world.get_tree().paused or _owner.world.get_children(true) != _order: return _bad("DISPLAY_ACTIVATION_ORDER")
	for row: Dictionary in _plan:
		if not is_instance_valid(row.node): return _bad("DISPLAY_ACTIVATION_NODE")
	for row: Dictionary in _plan:
		var node: Node = row.node
		var s: Dictionary = row.activation
		node.process_priority = s.priority; node.process_physics_priority = s.physics_priority
		node.set_process(s.process); node.set_physics_process(s.physics); node.set_process_input(s.input)
		node.set_process_shortcut_input(s.shortcut); node.set_process_unhandled_input(s.unhandled_input); node.set_process_unhandled_key_input(s.unhandled_key)
		node.set_block_signals(s.signals_blocked); node.process_mode = s.mode
		if node.has_meta("_run_restore_prepared"): node.remove_meta("_run_restore_prepared")
	_active = true
	return {"ok": true}

func encode_record(raw: Dictionary) -> Dictionary:
	var copy: Dictionary = raw.duplicate(true)
	var buffer := ""
	for row: Dictionary in copy.children:
		if row.role == "shadow": buffer = row.buffer; row.buffer = ""
	var encoded: Dictionary = _codec.encode(copy)
	if not encoded.ok: return encoded
	# Fixed f32 bytes are separately bounded, not arbitrary serialized objects.
	return {"ok": true, "value": {"payload": encoded.value, "shadow_buffer": buffer}}

func decode_record(record: Variant) -> Dictionary:
	if not _fields(record, ["payload", "shadow_buffer"]) or typeof(record.shadow_buffer) != TYPE_STRING or record.shadow_buffer.length() > 4096 * 12 * 8: return _bad("DISPLAY_ENVELOPE")
	var decoded: Dictionary = _codec.decode(record.payload)
	if not decoded.ok: return decoded
	if not _fields(decoded.value, ["schema", "world", "units", "children"]) or typeof(decoded.value.children) != TYPE_ARRAY: return _bad("DISPLAY_RECORD")
	var count := 0
	for row: Variant in decoded.value.children:
		if typeof(row) != TYPE_DICTIONARY: return _bad("DISPLAY_CHILD_RECORD")
		if row.get("role") == "shadow":
			if row.get("buffer") != "": return _bad("DISPLAY_BUFFER_PLACEHOLDER")
			row.buffer = record.shadow_buffer; count += 1
	if count > 1 or (count == 0 and not record.shadow_buffer.is_empty()): return _bad("DISPLAY_BUFFER_OWNER")
	return decoded
