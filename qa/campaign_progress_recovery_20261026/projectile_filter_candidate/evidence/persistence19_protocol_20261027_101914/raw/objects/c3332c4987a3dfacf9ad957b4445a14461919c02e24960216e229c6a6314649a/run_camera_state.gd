extends RefCounted
## Explicit RTS camera state. The outer transaction owns world/input activation.
const B := preload("res://scripts/battle.gd")
const C := preload("res://scripts/rts_camera.gd")
const M := preload("res://scripts/game_map.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Fog := preload("res://scripts/run_fog_state.gd")
const SCHEMA := "rts_camera_state_v1"
const SCRIPT_FLOATS := ["pan_speed", "_user_input_t", "_shake", "_shake_ph", "_pinch_d"]
const SCRIPT_BOOLS := ["_mid_drag", "auto_driving", "touch_mode"]
const SCRIPT_FIELDS := ["pan_speed", "_user_input_t", "_shake", "_shake_ph", "_pinch_d", "_mid_drag", "auto_driving", "touch_mode", "_touches", "_pinch_mid"]
const CAMERA_INTS := ["anchor_mode", "process_callback", "limit_left", "limit_top", "limit_right", "limit_bottom"]
const CAMERA_BOOLS := ["ignore_rotation", "enabled", "limit_enabled", "limit_smoothed", "position_smoothing_enabled", "rotation_smoothing_enabled", "drag_horizontal_enabled", "drag_vertical_enabled", "editor_draw_screen", "editor_draw_limits", "editor_draw_drag_margin"]
const CAMERA_FLOATS := ["position_smoothing_speed", "rotation_smoothing_speed", "drag_horizontal_offset", "drag_vertical_offset", "drag_left_margin", "drag_top_margin", "drag_right_margin", "drag_bottom_margin"]
var _codec: Variant = Codec.new()
var _nodes: Variant = Fog.new({}, B, M, Codec, B.FogLayer)
var _camera: Variant = null
var _owner: Variant = null
var _record: Dictionary = {}
var _active := false

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _fields(value: Variant, keys: Array) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.size() == keys.size() and value.has_all(keys)

func _plain_camera(camera: Variant) -> bool:
	if not is_instance_valid(camera) or camera.get_script() != C or camera.is_queued_for_deletion() or camera.get_child_count(true) != 0 or camera.custom_viewport != null or camera.material != null or not camera.get_meta_list().is_empty(): return false
	for info: Dictionary in camera.get_signal_list():
		if not camera.get_signal_connection_list(info.name).is_empty(): return false
	return true

func capture(owner: Variant) -> Dictionary:
	if not is_instance_valid(owner) or owner.get_script() != B or owner._save_barrier == null or owner._save_barrier.state != owner._save_barrier.State.HELD: return _bad("CAMERA_HELD_BARRIER_REQUIRED")
	var camera: Variant = owner.camera
	if not _plain_camera(camera) or camera.get_parent() != owner: return _bad("CAMERA_SOURCE")
	var held: Dictionary = owner._save_barrier._saved_camera
	if not _fields(held, ["node", "mode", "input"]) or held.node != camera or camera.process_mode != Node.PROCESS_MODE_DISABLED or camera.is_processing_unhandled_input(): return _bad("CAMERA_INPUT_GATE")
	var node: Dictionary = _nodes._node_values(camera)
	node.activation.mode = held.mode
	node.activation.unhandled_input = held.input
	var script: Dictionary = {}
	for key: String in SCRIPT_FIELDS: script[key] = camera.get(key)
	var engine: Dictionary = {"offset": camera.offset, "zoom": camera.zoom}
	for key: String in CAMERA_INTS + CAMERA_BOOLS + CAMERA_FLOATS: engine[key] = camera.get(key)
	var raw := {"schema": SCHEMA, "node": node, "script": script, "engine": engine, "current": camera.is_current()}
	var checked: Dictionary = validate(raw)
	if not checked.ok: return checked
	return _codec.encode(raw)

func validate(raw: Variant) -> Dictionary:
	if not _fields(raw, ["schema", "node", "script", "engine", "current"]) or raw.schema != SCHEMA or not _nodes._node_valid(raw.node) or typeof(raw.current) != TYPE_BOOL: return _bad("CAMERA_RECORD")
	if not _fields(raw.script, SCRIPT_FIELDS) or not _fields(raw.engine, CAMERA_INTS + CAMERA_BOOLS + CAMERA_FLOATS + ["offset", "zoom"]): return _bad("CAMERA_FIELDS")
	var s: Dictionary = raw.script
	var e: Dictionary = raw.engine
	for key: String in SCRIPT_FLOATS:
		if typeof(s[key]) != TYPE_FLOAT or not is_finite(s[key]): return _bad("CAMERA_SCRIPT_FLOAT")
	for key: String in SCRIPT_BOOLS:
		if typeof(s[key]) != TYPE_BOOL: return _bad("CAMERA_SCRIPT_BOOL")
	if typeof(s._touches) != TYPE_DICTIONARY or not s._touches.is_empty() or s._mid_drag or s._pinch_d != 0.0 or typeof(s._pinch_mid) != TYPE_VECTOR2 or s._pinch_mid != Vector2.ZERO: return _bad("CAMERA_GESTURE_NOT_RELEASED")
	if s.pan_speed <= 0.0 or s._user_input_t < 0.0 or s._shake < 0.0 or s._shake > 9.0: return _bad("CAMERA_SCRIPT_RANGE")
	for key: String in CAMERA_INTS:
		if typeof(e[key]) != TYPE_INT or e[key] < -2147483648 or e[key] > 2147483647: return _bad("CAMERA_ENGINE_INT")
	for key: String in CAMERA_BOOLS:
		if typeof(e[key]) != TYPE_BOOL: return _bad("CAMERA_ENGINE_BOOL")
	for key: String in CAMERA_FLOATS:
		if typeof(e[key]) != TYPE_FLOAT or not is_finite(e[key]): return _bad("CAMERA_ENGINE_FLOAT")
	if e.anchor_mode not in [0, 1] or e.process_callback not in [0, 1] or e.limit_left >= e.limit_right or e.limit_top >= e.limit_bottom: return _bad("CAMERA_LIMITS")
	if e.position_smoothing_speed < 0.0 or e.rotation_smoothing_speed < 0.0 or absf(e.drag_horizontal_offset) > 1.0 or absf(e.drag_vertical_offset) > 1.0: return _bad("CAMERA_ENGINE_RANGE")
	for key: String in ["drag_left_margin", "drag_top_margin", "drag_right_margin", "drag_bottom_margin"]:
		if e[key] < 0.0 or e[key] > 1.0: return _bad("CAMERA_DRAG_MARGIN")
	for key: String in ["offset", "zoom"]:
		if typeof(e[key]) != TYPE_VECTOR2 or not e[key].is_finite(): return _bad("CAMERA_VECTOR")
	if e.zoom.x <= 0.0 or e.zoom.y <= 0.0: return _bad("CAMERA_ZOOM")
	# The shipped RTS camera never enables native history-dependent smoothing
	# or drag margins. Their hidden integration state cannot be reconstructed by
	# assigning public properties; reject instead of resetting that state.
	if e.position_smoothing_enabled or e.rotation_smoothing_enabled or e.limit_smoothed or e.drag_horizontal_enabled or e.drag_vertical_enabled: return _bad("CAMERA_NATIVE_HISTORY_UNSUPPORTED")
	if not e.enabled or not raw.current: return _bad("CAMERA_ACTIVE_VIEW_REQUIRED")
	return {"ok": true}

func bind(owner: Variant, record: Variant) -> Dictionary:
	if _owner != null or not is_instance_valid(owner) or owner.get_script() != B or owner.is_inside_tree() or owner.camera != null: return _bad("CAMERA_BIND_PHASE")
	var decoded: Dictionary = _codec.decode(record)
	if not decoded.ok: return decoded
	var checked: Dictionary = validate(decoded.value)
	if not checked.ok: return checked
	var raw: Dictionary = decoded.value
	var camera := C.new()
	# Camera2D may select itself on ENTER_TREE, even without make_current().
	# Keep it disabled until the final paused installation explicitly switches.
	camera.enabled = false
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	camera.set_block_signals(true)
	camera.set_process(false); camera.set_physics_process(false)
	camera.set_process_input(false); camera.set_process_shortcut_input(false)
	camera.set_process_unhandled_input(false); camera.set_process_unhandled_key_input(false)
	camera.set_meta("_run_camera_prepared", true)
	var node: Dictionary = raw.node
	if not node.name.is_empty(): camera.name = node.name
	camera.transform = Transform2D(node.basis_x, node.basis_y, node.position)
	for key: String in ["visible", "modulate", "self_modulate", "z_index", "z_as_relative", "show_behind_parent", "top_level", "y_sort_enabled", "light_mask", "visibility_layer", "texture_filter", "texture_repeat", "use_parent_material", "clip_children"]: camera.set(key, node[key])
	camera.physics_interpolation_mode = node.interpolation
	for key: String in SCRIPT_FIELDS: camera.set(key, raw.script[key])
	for key: String in CAMERA_INTS + CAMERA_BOOLS + CAMERA_FLOATS + ["offset", "zoom"]:
		if key != "enabled": camera.set(key, raw.engine[key])
	owner.camera = camera
	owner.add_child(camera)
	_owner = owner; _camera = camera; _record = raw.duplicate(true)
	return {"ok": true}

func activate() -> Dictionary:
	if _active or not is_instance_valid(_owner) or not is_instance_valid(_camera) or _owner.camera != _camera or _camera.get_parent() != _owner or not _camera.is_inside_tree() or not _camera.get_tree().paused: return _bad("CAMERA_ACTIVATION_PHASE")
	if _camera.enabled or _camera.process_mode != Node.PROCESS_MODE_DISABLED or _camera.get_meta("_run_camera_prepared", false) != true: return _bad("CAMERA_PREPARATION_CHANGED")
	var a: Dictionary = _record.node.activation
	_camera.process_priority = a.priority; _camera.process_physics_priority = a.physics_priority
	_camera.set_process(a.process); _camera.set_physics_process(a.physics); _camera.set_process_input(a.input)
	_camera.set_process_shortcut_input(a.shortcut); _camera.set_process_unhandled_input(a.unhandled_input); _camera.set_process_unhandled_key_input(a.unhandled_key)
	_camera.set_block_signals(a.signals_blocked); _camera.process_mode = a.mode
	_camera.enabled = true
	_camera.make_current()
	_camera.force_update_scroll()
	_camera.remove_meta("_run_camera_prepared")
	_active = true
	return {"ok": true}
