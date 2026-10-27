extends RefCounted
## Fixed Huangnigang props only; these carry no units, collision or gameplay.
const Huang := preload("res://scripts/levels/level1_huangnigang.gd")
const ArtEvent := preload("res://scripts/campaign_art_event.gd")
const FIELDS := {
	"hg_cart": ["texture", "size", "life", "duration", "contact_shadow_enabled", "metadata", "token"],
	"hg_sign": ["label", "tint", "radius", "metadata", "token"],
	"hg_art": ["texture", "size", "foot", "life", "duration", "metadata", "token"]}
const META := ["render_height", "fog_clearance_px", "campaign_object", "campaign_environment_route", "campaign_environment_state", "campaign_environment_fallback_key", "mission_action", "jujube_cart_index"]

static func kind(node: Node) -> String:
	if node.get_script() == Huang.JujubeCart: return "hg_cart"
	if node.get_script() == Huang.FieldSign: return "hg_sign"
	if node.get_script() == ArtEvent: return "hg_art"
	return ""

static func make(type: String) -> Node2D:
	match type:
		"hg_cart": return Huang.JujubeCart.new()
		"hg_sign": return Huang.FieldSign.new()
		"hg_art": return ArtEvent.new()
	return null

static func tokens(level: Variant) -> Dictionary:
	var out := {}
	if not is_instance_valid(level): return out
	var index := 0
	for field in ["good_sign", "sale_sign", "suspicion_sign"]:
		var node: Variant = level.get(field)
		if is_instance_valid(node):
			out[node] = "ext:level1:%s:%d" % [field, index]
			index += 1
	for field in ["field_signs", "jujube_carts"]:
		var array: Array = level.get(field)
		for i in range(array.size()):
			if is_instance_valid(array[i]): out[array[i]] = "ext:level1:%s:%d" % [field, i]
	return out

static func metadata(node: Node) -> Dictionary:
	var out := {}
	for key in node.get_meta_list(): out[String(key)] = node.get_meta(key)
	return out

static func valid(value: Dictionary, type: String) -> bool:
	if typeof(value.metadata) != TYPE_DICTIONARY or value.metadata.size() > META.size() or typeof(value.token) != TYPE_STRING: return false
	for key in value.metadata:
		if key not in META: return false
		var entry: Variant = value.metadata[key]
		if key in ["render_height", "fog_clearance_px"]:
			if typeof(entry) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(entry)): return false
		elif key == "jujube_cart_index":
			if typeof(entry) != TYPE_INT or entry < 0 or entry > 6: return false
		elif typeof(entry) != TYPE_STRING or entry.length() > 256: return false
	if not value.token.is_empty():
		var pieces: PackedStringArray = value.token.split(":")
		if pieces.size() != 4 or pieces[0] != "ext" or pieces[1] != "level1" or not pieces[3].is_valid_int() or str(int(pieces[3])) != pieces[3] or int(pieces[3]) < 0 or int(pieces[3]) > 63: return false
		if type == "hg_cart":
			if pieces[2] != "jujube_carts" or int(pieces[3]) > 6 or value.metadata.get("jujube_cart_index") != int(pieces[3]): return false
		elif type != "hg_sign" or pieces[2] not in ["field_signs", "good_sign", "sale_sign", "suspicion_sign"]: return false
	elif type != "hg_art": return false
	if type == "hg_sign":
		return typeof(value.label) == TYPE_STRING and value.label.length() <= 4096 and typeof(value.tint) == TYPE_COLOR and typeof(value.radius) == TYPE_FLOAT and is_finite(value.radius) and value.radius > 0.0
	for field in ["size", "life", "duration"] + (["foot"] if type == "hg_art" else []):
		if typeof(value[field]) != TYPE_FLOAT or not is_finite(value[field]): return false
	return value.size > 0.0 and (type != "hg_cart" or (typeof(value.contact_shadow_enabled) == TYPE_BOOL and value.life == -1.0 and value.duration == -1.0))

static func node_supported(node: Node2D) -> bool:
	if node.material != null or node.use_parent_material or node.get_child_count(true) != 0: return false
	if node.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE or node.texture_repeat != CanvasItem.TEXTURE_REPEAT_PARENT_NODE or node.light_mask != 1 or node.visibility_layer != 1 or node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED: return false
	if node.process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT or not node.get_groups().is_empty(): return false
	for info in node.get_signal_list():
		for row in node.get_signal_connection_list(info.name):
			var callback: Callable = row.callable
			if info.name != &"child_order_changed" or not node.is_inside_tree() or callback.get_object() != node.get_viewport() or row.flags != CONNECT_REFERENCE_COUNTED: return false
			if callback.get_method() == &"Viewport::canvas_parent_mark_dirty" and callback.get_bound_arguments() == [node]: continue
			if callback.get_method() == &"Viewport::gui_set_root_order_dirty" and callback.get_bound_arguments().is_empty(): continue
			return false
	for row in node.get_incoming_connections():
		if kind(node) != "hg_sign" or row.signal.get_object() != Localize or row.signal.get_name() != &"language_changed" or row.callable != Callable(node, "_on_language_changed") or row.flags != 0: return false
	var language_count := 0
	for row in Localize.language_changed.get_connections():
		var callback: Callable = row.callable
		if callback.get_object() != node: continue
		if kind(node) != "hg_sign" or callback != Callable(node, "_on_language_changed") or row.flags != 0 or not callback.get_bound_arguments().is_empty(): return false
		language_count += 1
	if language_count != (1 if kind(node) == "hg_sign" and node.is_inside_tree() else 0): return false
	return true

static func restore_render_transform(node: Node2D) -> void:
	var transform: Transform2D = node.transform
	transform.origin -= Vector2.ONE * float(node.get_meta("render_height", 0.0))
	RenderingServer.canvas_item_set_transform(node.get_canvas_item(), transform)
