extends RefCounted
## Runtime/PCK fog contract. Trusted identity and Scripts come from the caller.
## Five authoritative values plus the existing, possibly lagging display pixels.
const SCHEMA := "battle_fog_runtime_v1"
const CODEC_CONTRACT := "run_state_value_codec_v1"
const MAX_AXIS := 256
const MAX_CELLS := 4096
const FOG_STEP := 0.18
const VALUE_FIELDS := ["map_w", "map_h", "fog", "_vision", "_sight_now", "_reveal_t", "_fog_t"]
const NODE_FIELDS := ["name", "position", "basis_x", "basis_y", "visible", "modulate", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "light_mask", "visibility_layer", "texture_filter", "texture_repeat", "use_parent_material", "clip_children", "interpolation", "activation"]
const ACTIVATION_FIELDS := ["mode", "priority", "physics_priority", "process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]
var _content_version: String = ""
var _battle_script: Script
var _map_script: Script
var _layer_script: Script
var _codec: Variant = null
var _bound: Dictionary = {}

func _init(trusted_identity: Dictionary, battle_script: Script, map_script: Script,
		codec_script: Script, fog_layer_script: Script) -> void:
	# Never take this context from the record being restored. The driver/root
	# resolves the real provider before constructing this module.
	if trusted_identity.get("ok") != true or trusted_identity.get("save_eligible") != true: return
	var version: Variant = trusted_identity.get("content_version")
	if typeof(version) != TYPE_STRING or version.strip_edges().is_empty() or version.length() > 256: return
	if battle_script == null or map_script == null or codec_script == null or fog_layer_script == null: return
	for script in [battle_script, map_script, codec_script, fog_layer_script]:
		if not script.can_instantiate(): return
	_content_version = version
	_battle_script = battle_script; _map_script = map_script; _layer_script = fog_layer_script
	_codec = codec_script.new()

func _bad(code: String, field: String = "") -> Dictionary:
	return {"ok": false, "code": code, "field": field, "complete_battle": false}

func _fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return true

func _node(value: Variant, script: Script) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) and value is Node and value.get_script() == script and not value.is_queued_for_deletion()

func _paused() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	return loop is SceneTree and (loop as SceneTree).paused and not Engine.is_in_physics_frame()

func _dimensions(width: Variant, height: Variant) -> Dictionary:
	if typeof(width) != TYPE_INT or typeof(height) != TYPE_INT: return _bad("DIMENSION_TYPE")
	if width < 1 or height < 1 or width > MAX_AXIS or height > MAX_AXIS: return _bad("DIMENSION_BOUND")
	var cells: int = width * height
	if cells > MAX_CELLS: return _bad("CELL_LIMIT")
	return {"ok": true, "cells": cells}

func _values(value: Variant, native_bytes: bool) -> Dictionary:
	if not _fields(value, VALUE_FIELDS): return _bad("VALUE_FIELDS")
	var dims: Dictionary = _dimensions(value.map_w, value.map_h)
	if not dims.ok: return dims
	if typeof(value.fog) != TYPE_BOOL: return _bad("FOG_FLAG")
	var byte_type: int = TYPE_PACKED_BYTE_ARRAY if native_bytes else TYPE_ARRAY
	if typeof(value._vision) != byte_type or typeof(value._sight_now) != byte_type: return _bad("BYTE_ARRAY_TYPE")
	if typeof(value._reveal_t) != TYPE_PACKED_FLOAT32_ARRAY: return _bad("REVEAL_TYPE")
	var empty: bool = value._vision.is_empty() and value._sight_now.is_empty() and value._reveal_t.is_empty()
	if empty:
		if value.fog: return _bad("ENABLED_FOG_EMPTY")
	elif value._vision.size() != dims.cells or value._sight_now.size() != dims.cells or value._reveal_t.size() != dims.cells:
		return _bad("ARRAY_LENGTH")
	if typeof(value._fog_t) != TYPE_FLOAT or not is_finite(value._fog_t) or value._fog_t < 0.0 or value._fog_t > FOG_STEP: return _bad("FOG_PHASE")
	for i in range(value._vision.size()):
		if typeof(value._vision[i]) != TYPE_INT or value._vision[i] < 0 or value._vision[i] > 2: return _bad("VISION_DOMAIN")
		if typeof(value._sight_now[i]) != TYPE_INT or value._sight_now[i] < 0 or value._sight_now[i] > 1: return _bad("SIGHT_DOMAIN")
		if not is_finite(value._reveal_t[i]) or value._reveal_t[i] < 0.0: return _bad("REVEAL_DOMAIN")
	return {"ok": true, "initialized": not empty, "cells": dims.cells}

func _activation(node: Node) -> Dictionary:
	return {"mode": int(node.process_mode), "priority": node.process_priority,
		"physics_priority": node.process_physics_priority, "process": node.is_processing(),
		"physics": node.is_physics_processing(), "input": node.is_processing_input(),
		"shortcut": node.is_processing_shortcut_input(), "unhandled_input": node.is_processing_unhandled_input(),
		"unhandled_key": node.is_processing_unhandled_key_input(), "signals_blocked": node.is_blocking_signals()}

func _activation_valid(value: Variant) -> bool:
	if not _fields(value, ACTIVATION_FIELDS): return false
	for key in ["mode", "priority", "physics_priority"]:
		if typeof(value[key]) != TYPE_INT: return false
	if value.mode < 0 or value.mode > 4: return false
	for key in ["priority", "physics_priority"]:
		if value[key] < -2147483648 or value[key] > 2147483647: return false
	for key in ["process", "physics", "input", "shortcut", "unhandled_input", "unhandled_key", "signals_blocked"]:
		if typeof(value[key]) != TYPE_BOOL: return false
	return true

func _node_values(layer: Node2D) -> Dictionary:
	return {"name": "" if String(layer.name).begins_with("@") else String(layer.name),
		"position": layer.position, "basis_x": layer.transform.x, "basis_y": layer.transform.y,
		"visible": layer.visible, "modulate": layer.modulate, "self_modulate": layer.self_modulate,
		"z_index": layer.z_index, "z_as_relative": layer.z_as_relative,
		"show_behind_parent": layer.show_behind_parent, "top_level": layer.top_level,
		"y_sort_enabled": layer.y_sort_enabled, "light_mask": layer.light_mask,
		"visibility_layer": layer.visibility_layer, "texture_filter": int(layer.texture_filter),
		"texture_repeat": int(layer.texture_repeat), "use_parent_material": layer.use_parent_material,
		"clip_children": int(layer.clip_children), "interpolation": int(layer.physics_interpolation_mode),
		"activation": _activation(layer)}

func _node_valid(value: Variant) -> bool:
	if not _fields(value, NODE_FIELDS): return false
	if typeof(value.name) != TYPE_STRING or value.name.length() > 256 or String(value.name).validate_node_name() != value.name: return false
	for key in ["position", "basis_x", "basis_y"]:
		if typeof(value[key]) != TYPE_VECTOR2 or not value[key].is_finite(): return false
	for key in ["visible", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "use_parent_material"]:
		if typeof(value[key]) != TYPE_BOOL: return false
	for key in ["modulate", "self_modulate"]:
		if typeof(value[key]) != TYPE_COLOR: return false
		var color: Color = value[key]
		for part in [color.r, color.g, color.b, color.a]:
			if not is_finite(part): return false
	for key in ["z_index", "light_mask", "visibility_layer", "texture_filter", "texture_repeat", "clip_children", "interpolation"]:
		if typeof(value[key]) != TYPE_INT: return false
	if value.z_index < -4096 or value.z_index > 4096: return false
	if value.light_mask < 0 or value.light_mask > 1048575 or value.visibility_layer < 0 or value.visibility_layer > 1048575: return false
	if value.texture_filter < 0 or value.texture_filter > 6 or value.texture_repeat < 0 or value.texture_repeat > 3: return false
	if value.clip_children < 0 or value.clip_children > 2 or value.interpolation < 0 or value.interpolation > 2: return false
	return _activation_valid(value.activation)

func _hex(value: Variant, bytes: int) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != bytes * 2: return false
	for i in range(value.length()):
		var c: int = value.unicode_at(i)
		if not (c >= 48 and c <= 57) and not (c >= 97 and c <= 102): return false
	return true

func _render_valid(render: Variant, values: Dictionary, initialized: bool) -> Dictionary:
	if not initialized:
		return {"ok": true} if _fields(render, ["kind"]) and render.kind == "none" else _bad("EMPTY_FOG_RENDER")
	if not _fields(render, ["kind", "format", "rgba_hex", "node", "world_child_index", "ws"]) or render.kind != "rgba8_fog_layer": return _bad("RENDER_FIELDS")
	if typeof(render.format) != TYPE_STRING or render.format != "RGBA8_NO_MIPMAPS": return _bad("IMAGE_FORMAT")
	if not _hex(render.rgba_hex, values.map_w * values.map_h * 4): return _bad("IMAGE_BYTES")
	if not _node_valid(render.node): return _bad("LAYER_NODE")
	if typeof(render.world_child_index) != TYPE_INT or render.world_child_index < 0 or render.world_child_index >= 65536: return _bad("LAYER_ORDER")
	if typeof(render.ws) != TYPE_VECTOR2 or render.ws != Vector2(values.map_w * 32, values.map_h * 32): return _bad("LAYER_MAP_EXTENT")
	var pixels: PackedByteArray = render.rgba_hex.hex_decode()
	for offset in range(0, pixels.size(), 4):
		if pixels[offset] != 0 or pixels[offset + 1] != 0 or pixels[offset + 2] != 0 or pixels[offset + 3] not in [0, 127, 128, 255]: return _bad("FOG_PIXEL_DOMAIN")
	# Do NOT compare these pixels to current _vision: reveal changes the values
	# immediately while the display deliberately waits for the next fog pass.
	return {"ok": true}

func capture(battle: Variant, boundary: Dictionary) -> Dictionary:
	if _codec == null: return _bad("TRUSTED_RUNTIME_CONTRACT_REQUIRED")
	if not _paused() or boundary.get("quiescent") != true: return _bad("PAUSED_QUIESCENT_BARRIER_REQUIRED")
	if not _node(battle, _battle_script) or not _node(battle.map, _map_script): return _bad("BATTLE_MAP_INSTANCE")
	if not battle.gameplay_rng_fault().is_empty(): return _bad("FAULTED_BATTLE")
	var values: Dictionary = {"map_w": battle.map.w, "map_h": battle.map.h, "fog": battle.fog,
		"_vision": battle._vision, "_sight_now": battle._sight_now, "_reveal_t": battle._reveal_t, "_fog_t": battle._fog_t}
	var checked: Dictionary = _values(values, true)
	if not checked.ok: return checked
	var render: Dictionary = {"kind": "none"}
	if checked.initialized:
		if not is_instance_valid(battle._vision_img) or not is_instance_valid(battle._fog_tex) or not _node(battle._fog_layer, _layer_script): return _bad("FOG_RENDER_OBJECTS")
		var img: Image = battle._vision_img
		if img.get_size() != Vector2i(values.map_w, values.map_h) or img.get_format() != Image.FORMAT_RGBA8 or img.has_mipmaps() or img.is_compressed(): return _bad("IMAGE_FORMAT")
		var layer: Variant = battle._fog_layer
		if not is_instance_valid(battle.world) or layer.get_parent() != battle.world or layer.tex != battle._fog_tex: return _bad("FOG_RESOURCE_BINDING")
		if layer.material != null or layer.get_child_count(true) != 0 or not layer.get_meta_list().is_empty(): return _bad("UNSUPPORTED_FOG_NODE_EXTENSION")
		var texture_image: Image = battle._fog_tex.get_image()
		if texture_image == null or texture_image.get_size() != img.get_size() or texture_image.get_format() != Image.FORMAT_RGBA8 or texture_image.get_data() != img.get_data(): return _bad("TEXTURE_IMAGE_MISMATCH")
		render = {"kind": "rgba8_fog_layer", "format": "RGBA8_NO_MIPMAPS", "rgba_hex": img.get_data().hex_encode(),
			"node": _node_values(layer), "world_child_index": layer.get_index(), "ws": layer.ws}
	elif battle._vision_img != null or battle._fog_tex != null or battle._fog_layer != null:
		return _bad("EMPTY_FOG_HAS_RENDER_OBJECTS")
	var render_check: Dictionary = _render_valid(render, values, checked.initialized)
	if not render_check.ok: return render_check
	values["_vision"] = Array(values._vision); values["_sight_now"] = Array(values._sight_now)
	var encoded: Dictionary = _codec.encode({"values": values, "render": render})
	if not encoded.ok: return encoded
	return {"ok": true, "record": {"schema": SCHEMA, "content_version": _content_version, "codec_contract": CODEC_CONTRACT, "payload": encoded.value}, "complete_battle": false}

func validate(record: Variant, expected_dimensions: Vector2i) -> Dictionary:
	if _codec == null: return _bad("TRUSTED_RUNTIME_CONTRACT_REQUIRED")
	if not _fields(record, ["schema", "content_version", "codec_contract", "payload"]): return _bad("RECORD_FIELDS")
	if typeof(record.schema) != TYPE_STRING or record.schema != SCHEMA: return _bad("SCHEMA")
	if typeof(record.content_version) != TYPE_STRING or record.content_version != _content_version: return _bad("CONTENT_VERSION")
	if typeof(record.codec_contract) != TYPE_STRING or record.codec_contract != CODEC_CONTRACT: return _bad("CODEC_CONTRACT")
	var expected: Dictionary = _dimensions(expected_dimensions.x, expected_dimensions.y)
	if not expected.ok: return expected
	var decoded: Dictionary = _codec.decode(record.payload)
	if not decoded.ok: return decoded
	if not _fields(decoded.value, ["values", "render"]): return _bad("PAYLOAD_FIELDS")
	var values: Variant = decoded.value.values
	var checked: Dictionary = _values(values, false)
	if not checked.ok: return checked
	if values.map_w != expected_dimensions.x or values.map_h != expected_dimensions.y: return _bad("DIMENSION_MISMATCH")
	var display: Dictionary = _render_valid(decoded.value.render, values, checked.initialized)
	if not display.ok: return display
	values["_vision"] = PackedByteArray(values._vision)
	values["_sight_now"] = PackedByteArray(values._sight_now)
	return {"ok": true, "values": values, "render": decoded.value.render, "initialized": checked.initialized, "complete_battle": false}

func bind(battle: Variant, record: Variant) -> Dictionary:
	if not _paused(): return _bad("PAUSED_INSTALL_REQUIRED")
	if not _node(battle, _battle_script) or battle.is_inside_tree() or battle.get_parent() != null or battle.process_mode != Node.PROCESS_MODE_DISABLED or not battle.is_blocking_signals(): return _bad("DETACHED_DISABLED_BATTLE_REQUIRED")
	if _bound.has(battle): return _bad("ALREADY_BOUND")
	if not battle.gameplay_rng_fault().is_empty(): return _bad("FAULTED_DESTINATION")
	if not _node(battle.map, _map_script): return _bad("MAP_INSTANCE")
	if not battle._vision.is_empty() or not battle._sight_now.is_empty() or not battle._reveal_t.is_empty() or battle._vision_img != null or battle._fog_tex != null or battle._fog_layer != null: return _bad("FRESH_FOG_DESTINATION_REQUIRED")
	var checked: Dictionary = validate(record, Vector2i(battle.map.w, battle.map.h))
	if not checked.ok: return checked
	var values: Dictionary = checked.values
	var image: Image = null
	var texture: ImageTexture = null
	var layer: Variant = null
	var activation: Dictionary = {}
	var order: int = -1
	if checked.initialized:
		var render: Dictionary = checked.render
		image = Image.create_from_data(values.map_w, values.map_h, false, Image.FORMAT_RGBA8, render.rgba_hex.hex_decode())
		if image == null or image.is_empty(): return _bad("IMAGE_CREATE")
		texture = ImageTexture.create_from_image(image)
		if texture == null: return _bad("TEXTURE_CREATE")
		layer = _layer_script.new()
		layer.set_block_signals(true); layer.process_mode = Node.PROCESS_MODE_DISABLED
		for method in ["set_process", "set_physics_process", "set_process_input", "set_process_shortcut_input", "set_process_unhandled_input", "set_process_unhandled_key_input"]: layer.call(method, false)
		var node: Dictionary = render.node
		if not node.name.is_empty(): layer.name = node.name
		layer.transform = Transform2D(node.basis_x, node.basis_y, node.position)
		for key in ["visible", "modulate", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "light_mask", "visibility_layer", "texture_filter", "texture_repeat", "use_parent_material", "clip_children"]: layer.set(key, node[key])
		layer.physics_interpolation_mode = node.interpolation
		layer.tex = texture; layer.ws = render.ws
		activation = node.activation; order = render.world_child_index
	# All validation/resources are prepared before the first Battle assignment.
	battle.fog = values.fog; battle._vision = values._vision; battle._sight_now = values._sight_now
	battle._reveal_t = values._reveal_t; battle._fog_t = values._fog_t
	battle._vision_img = image; battle._fog_tex = texture; battle._fog_layer = layer
	_bound[battle] = layer
	return {"ok": true, "layer": layer, "world_child_index": order, "activation": activation,
		"unit_visibility_written": false, "fog_tick_invoked": false, "complete_battle": false}

func activate(battle: Variant, activation: Variant) -> Dictionary:
	if not _paused() or not _node(battle, _battle_script) or not _bound.has(battle): return _bad("PAUSED_BOUND_BATTLE_REQUIRED")
	var layer: Variant = _bound[battle]
	if layer == null:
		return {"ok": true} if typeof(activation) == TYPE_DICTIONARY and activation.is_empty() else _bad("EMPTY_ACTIVATION")
	if not _node(layer, _layer_script) or not layer.is_inside_tree() or layer.get_parent() != battle.world: return _bad("LAYER_NOT_ATTACHED_TO_WORLD")
	if not _activation_valid(activation): return _bad("ACTIVATION_FIELDS")
	layer.process_priority = activation.priority; layer.process_physics_priority = activation.physics_priority
	layer.set_process(activation.process); layer.set_physics_process(activation.physics)
	layer.set_process_input(activation.input); layer.set_process_shortcut_input(activation.shortcut)
	layer.set_process_unhandled_input(activation.unhandled_input); layer.set_process_unhandled_key_input(activation.unhandled_key)
	layer.set_block_signals(activation.signals_blocked); layer.process_mode = activation.mode
	return {"ok": true, "complete_battle": false}
