extends RefCounted
## Exact short Kuaihuolin tell nodes only; no duel replay.
const Kuai := preload("res://scripts/levels/level7_kuaihuolin_short.gd")
const FIELDS := {"kuai_tell": ["kind", "progress", "extent", "metadata", "token"]}
const TOKENS := {"fist_marker": "level7:fist", "drill_marker": "level7:drill"}
const META := ["render_height", "tell_kind"]

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code, "complete_world": false}

static func kind(node: Node) -> String:
	return "kuai_tell" if node.get_script() == Kuai.DuelTell else ""

static func make() -> Node2D:
	return Kuai.DuelTell.new()

static func metadata(node: Node) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in node.get_meta_list(): out[String(key)] = node.get_meta(key)
	return out

static func valid(value: Dictionary) -> bool:
	if typeof(value.get("kind")) != TYPE_STRING or value.kind not in ["heavy", "rush"]: return false
	for field: String in ["progress", "extent"]:
		if typeof(value.get(field)) != TYPE_FLOAT or not is_finite(value[field]): return false
	if value.progress < 0.0 or value.progress > 1.0 or value.extent < 0.0 or value.extent > 190.001: return false
	if typeof(value.get("token")) != TYPE_STRING or value.token not in TOKENS.values(): return false
	if typeof(value.get("metadata")) != TYPE_DICTIONARY: return false
	for key: Variant in value.metadata:
		if typeof(key) != TYPE_STRING or key not in META: return false
		var entry: Variant = value.metadata[key]
		if key == "render_height":
			if typeof(entry) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(entry)): return false
		elif typeof(entry) != TYPE_STRING or entry not in ["heavy", "rush"]: return false
	if value.token == TOKENS.drill_marker:
		return value.kind == "heavy" and value.progress == 0.0 and value.extent == 190.0 and not value.metadata.has("tell_kind")
	return typeof(value.metadata.get("tell_kind")) == TYPE_STRING and value.metadata.tell_kind == value.kind

static func node_supported(node: Node2D) -> bool:
	if node.get_script() != Kuai.DuelTell or node.is_queued_for_deletion() or node.get_child_count(true) != 0: return false
	if node.material != null or node.use_parent_material or node.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE or node.texture_repeat != CanvasItem.TEXTURE_REPEAT_PARENT_NODE: return false
	if node.light_mask != 1 or node.visibility_layer != 1 or node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED or node.process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT: return false
	if not node.get_groups().is_empty() or not node.get_incoming_connections().is_empty(): return false
	for info: Dictionary in node.get_signal_list():
		for row: Dictionary in node.get_signal_connection_list(info.name):
			var callback: Callable = row.callable
			if info.name != &"child_order_changed" or not node.is_inside_tree() or row.flags != CONNECT_REFERENCE_COUNTED or callback.get_object() != node.get_viewport(): return false
			if callback.get_method() == &"Viewport::canvas_parent_mark_dirty" and callback.get_bound_arguments() == [node]: continue
			if callback.get_method() == &"Viewport::gui_set_root_order_dirty" and callback.get_bound_arguments().is_empty(): continue
			return false
	return true

## Capture/activation registry. No nested/orphan tell or aliased Level reference
## can be omitted merely because it is absent from the Level's two fields.
static func tokens(level: Variant, root: Node2D) -> Dictionary:
	if typeof(level) != TYPE_OBJECT or not is_instance_valid(level) or level.get_script() != Kuai: return _bad("KUAI_INSTALLED_LEVEL")
	if not is_instance_valid(root) or root.is_queued_for_deletion(): return _bad("KUAI_FX_ROOT")
	var objects: Dictionary = {}; var by_token: Dictionary = {}
	for field: String in TOKENS:
		var node: Variant = level.get(field)
		if not is_instance_valid(node): continue
		if not node is Node2D or not node_supported(node) or node.get_parent() != root or objects.has(node): return _bad("KUAI_TELL_REFERENCE")
		var token: String = TOKENS[field]
		var value := {"kind": node.kind, "progress": node.progress, "extent": node.extent, "metadata": metadata(node), "token": token}
		if not valid(value): return _bad("KUAI_TELL_VALUE")
		objects[node] = token; by_token[token] = node
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.get_script() == Kuai.DuelTell and (node.get_parent() != root or not objects.has(node)): return _bad("KUAI_ORPHAN_TELL")
		for child: Node in node.get_children(true): stack.append(child)
	return {"ok": true, "external_to_token": objects, "tokens": by_token}

## Values come only from the installed LevelState validator. This checks visual
## ownership/geometry, without equating drill presence to one numeric stage:
## direct subdual can retain a drill, and a live charge retains its full tell.
static func check_rows(rows: Array, expected: Dictionary, level_values: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for row: Dictionary in rows:
		if row.kind != "kuai_tell": continue
		var value: Dictionary = row.values
		if row.parent != "1" or not valid(value) or not expected.has(value.token) or found.has(value.token): return _bad("KUAI_TELL_TOKEN_SET")
		found[value.token] = true
		var position: Vector2
		var angle := 0.0
		if value.token == TOKENS.drill_marker:
			position = level_values.drill_origin
		else:
			if value.kind != level_values.special_kind: return _bad("KUAI_TELL_KIND_PAIR")
			var progress: float = 1.0 - level_values.fist_windup / (1.6 if value.kind == "heavy" else 1.25)
			if not is_equal_approx(value.progress, progress): return _bad("KUAI_TELL_PROGRESS_PAIR")
			var distance: float = level_values.rush_from.distance_to(level_values.rush_end)
			if not is_equal_approx(value.extent, distance): return _bad("KUAI_TELL_EXTENT_PAIR")
			position = level_values.fist_at if value.kind == "heavy" else level_values.rush_from
			if value.kind == "rush": angle = (level_values.rush_end - level_values.rush_from).angle()
		var transform := Transform2D(angle, position)
		if row.node.position != position or not row.node.basis_x.is_equal_approx(transform.x) or not row.node.basis_y.is_equal_approx(transform.y) or row.node.z_index != 3449 or not row.node.z_as_relative:
			return _bad("KUAI_TELL_GEOMETRY_PAIR")
	if found.size() != expected.size(): return _bad("KUAI_TELL_TOKEN_COVERAGE")
	return {"ok": true}

static func restore_render_transform(node: Node2D) -> void:
	var transform: Transform2D = node.transform
	transform.origin -= Vector2.ONE * float(node.get_meta("render_height", 0.0))
	RenderingServer.canvas_item_set_transform(node.get_canvas_item(), transform)
	node.queue_redraw()
