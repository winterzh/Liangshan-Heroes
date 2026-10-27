extends RefCounted
## A derived ground canvas owned by the existing battle overlay. It creates no
## scene nodes, selection state, gameplay fields or persistent save payload.
var _item := RID()
var _parent := RID()

func clear() -> void:
	if _item.is_valid():
		RenderingServer.canvas_item_clear(_item)
		RenderingServer.canvas_item_set_visible(_item, false)

func draw_ring(parent: CanvasItem, local_transform: Transform2D, points: PackedVector2Array, edge: Color, fill: Color) -> void:
	clear()
	if not is_instance_valid(parent) or not parent.is_inside_tree() or points.size() < 3:
		return
	if not local_transform.x.is_finite() or not local_transform.y.is_finite() or not local_transform.origin.is_finite():
		return
	for point in points:
		if not point.is_finite(): return
	if not _item.is_valid():
		_item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_z_index(_item, 0)
		# units_root has no own painting. Its ground item is submitted before
		# that parent and all ordinary Unit children, including first-frame z0.
		RenderingServer.canvas_item_set_draw_behind_parent(_item, true)
	var next_parent := parent.get_canvas_item()
	if next_parent != _parent:
		RenderingServer.canvas_item_set_parent(_item, next_parent)
		_parent = next_parent
	# Geometry remains in the original overlay's projected coordinates. This
	# compensates the new parent without flattening terrain or scaling stroke.
	RenderingServer.canvas_item_set_transform(_item, local_transform)
	RenderingServer.canvas_item_add_polygon(_item, points, PackedColorArray([fill]))
	var closed := points.duplicate()
	closed.append(points[0])
	RenderingServer.canvas_item_add_polyline(_item, closed, PackedColorArray([edge]), 1.6, false)
	RenderingServer.canvas_item_set_visible(_item, true)

func release() -> void:
	if _item.is_valid():
		RenderingServer.free_rid(_item)
		_item = RID()
	_parent = RID()

func _notification(what: int) -> void:
	# A final RefCounted notification must not dispatch another script method
	# through an already-null instance. The normal Overlay exit calls release.
	if what == NOTIFICATION_PREDELETE and _item.is_valid():
		RenderingServer.free_rid(_item)
