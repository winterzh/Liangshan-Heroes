extends Node2D
## 寨门的原生绘制部件；脚点由入口布局负责，生命/阻挡由驻守战的 stockade_gate Unit 负责。
var lintel := false
const POST_HEIGHT := 66.0
var facing := 1.0
var simple := false
var plaque_text := "梁山"
var replacement_texture: Texture2D
var replacement_owner := false
var replacement_size := 220.0
var replacement_foot := 0.82
var replacement_text_rect: Array = []
var sealed := false
var closed_leaf_end := Vector2.ZERO
var _roof_outline := PackedVector2Array()

# 屋面瓦片原先每帧以数百个 CanvasItem polygon/line 逐块绘制。两座寨门
# 会占掉梁山实机的大部分绘制提交；缓存为局部 ArrayMesh，仍在门架自身的
# screen_basis 下绘制，因此不改变等距坡面、遮挡或贴图层级。
const ROOF_TILE_COLUMNS := 28
const ROOF_TILE_ROWS := 6
var _roof_fill_meshes: Array[ArrayMesh] = []
var _roof_line_meshes: Array[ArrayMesh] = []
var _roof_mesh_ready := false
var _last_roof_route := "unrendered"

func occludes_body(body: Rect2) -> bool:
	if facing<0:
		body = Rect2(Vector2(-body.end.x,body.position.y),body.size)
	if _roof_outline.is_empty():
		var vertices := PackedVector2Array()
		for front in [true,false]:
			for i in range(29):
				vertices.append(_roof_point(float(i)/28.0,1.0,front))
		vertices.append(_roof_point(0.0,0.0,true)-Vector2(0,15))
		vertices.append(_roof_point(1.0,0.0,true)-Vector2(0,15))
		_roof_outline = Geometry2D.convex_hull(vertices)
	var corners := PackedVector2Array([body.position,Vector2(body.end.x,body.position.y),body.end,Vector2(body.position.x,body.end.y)])
	return not Geometry2D.intersect_polygons(_roof_outline,corners).is_empty()

func _screen_basis() -> Transform2D:
	return GameMap.ISO_INV*Transform2D(Vector2(facing,0),Vector2(0,1),Vector2.ZERO)

func _draw() -> void:
	if replacement_texture!=null:
		if replacement_owner:
			draw_set_transform_matrix(GameMap.ISO_INV)
			draw_texture_rect(replacement_texture,
				Rect2(-replacement_size*0.5,-replacement_size*replacement_foot,replacement_size,replacement_size),false)
			_draw_replacement_plaque()
			draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	draw_set_transform_matrix(_screen_basis())
	if lintel:
		if simple:
			var a := Vector2(-128,-POST_HEIGHT-64)
			var b := Vector2(0,-POST_HEIGHT)
			draw_line(a,b,Color("352b1d"),13.0,true)
			draw_line(a-Vector2(0,3),b-Vector2(0,3),Color("80603c"),4.0,true)
		else:
			_draw_roof()
	else:
		_draw_post()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_replacement_plaque() -> void:
	if replacement_text_rect.size()!=4 or plaque_text.is_empty(): return
	var origin := Vector2(-replacement_size*0.5,-replacement_size*replacement_foot)
	var rect := Rect2(origin+Vector2(float(replacement_text_rect[0]),float(replacement_text_rect[1]))*replacement_size,
		Vector2(float(replacement_text_rect[2]),float(replacement_text_rect[3]))*replacement_size)
	if rect.size.x<1.0 or rect.size.y<1.0: return
	var fs := maxi(8,int(minf(rect.size.y*0.72,rect.size.x/maxf(plaque_text.length(),1)*1.5)))
	var base := rect.position.y+(rect.size.y+fs)*0.5-1.0
	draw_string_outline(ThemeDB.fallback_font,Vector2(rect.position.x,base),plaque_text,
		HORIZONTAL_ALIGNMENT_CENTER,int(rect.size.x),fs,maxi(1,int(fs*0.1)),Color(0.05,0.04,0.03,0.9))
	draw_string(ThemeDB.fallback_font,Vector2(rect.position.x,base),plaque_text,
		HORIZONTAL_ALIGNMENT_CENTER,int(rect.size.x),fs,Color("cab586"))

func _draw_post() -> void:
	# 驻守战未破门时，两扇厚木门在中心合拢；剧情版和破门后仍沿两侧敞开。
	var leaf_end := closed_leaf_end if sealed and closed_leaf_end.length_squared() > 1.0 else Vector2(30,-15)
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO,leaf_end,leaf_end-Vector2(0,61),Vector2(0,-61)]),Color("4b3522"))
	for i in range(6):
		var p := leaf_end*float(i)/6.0
		draw_line(p,p-Vector2(0,61),Color("826039") if i%2==0 else Color("30261b"),1.1,true)
	for y in [15,46]:
		draw_line(Vector2(0,-y),leaf_end-Vector2(0,y),Color("282922"),3.5,true)
		for i in [1,4]:
			draw_circle(leaf_end*float(i)/6.0-Vector2(0,y),0.8,Color("9a8965"),true,-1.0,true)
	if sealed:
		# 斜撑让关闭状态一眼可辨，也避免门板只像铺在地上的木桥。
		draw_line(Vector2(2,-8),leaf_end-Vector2(2,53),Color("2d251a"),5.0,true)
		draw_line(Vector2(2,-10),leaf_end-Vector2(2,55),Color("9a7445"),1.5,true)
	# 石础顶面、迎光面和背光面，不画横过门洞的门板。
	draw_colored_polygon(PackedVector2Array([Vector2(-18,-3),Vector2(0,-12),Vector2(18,-3),Vector2(0,6)]), Color("8b8270"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18,-3),Vector2(0,6),Vector2(0,13),Vector2(-18,4)]), Color("635b4b"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,6),Vector2(18,-3),Vector2(18,4),Vector2(0,13)]), Color("49483d"))
	draw_rect(Rect2(-8,-POST_HEIGHT,16,POST_HEIGHT), Color("5d4027"))
	draw_rect(Rect2(-8,-POST_HEIGHT,5,POST_HEIGHT), Color("987247"))
	draw_rect(Rect2(5,-POST_HEIGHT,3,POST_HEIGHT), Color("3d3020"))
	for i in range(10):
		var grain := PackedVector2Array()
		for j in range(14):
			grain.append(Vector2(-7.0+i*1.5+sin(float(i+j)*1.4)*0.5, -POST_HEIGHT+j*6))
		draw_polyline(grain, Color(0.20,0.12,0.06,0.35) if i%2==0 else Color(0.71,0.51,0.28,0.22), 0.65, true)
	# 斜撑与两级承托，接到上方横梁。
	for side in [-1.0,1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side*7,-55),Vector2(side*27,-80),Vector2(side*17,-80),Vector2(side*7,-67)]),Color("72502e"))
		draw_line(Vector2(side*7,-57),Vector2(side*24,-79),Color("b18c55"),1.2,true)
	for tier in range(2):
		var width := 26.0+tier*11.0
		var y := -POST_HEIGHT+5.0-tier*6.0
		draw_rect(Rect2(-width*0.5,y,width,4),Color("8c673d"))
		draw_line(Vector2(-width*0.5,y),Vector2(width*0.5,y),Color("b69761"),1.0,true)
	for y in [-49,-16]:
		draw_rect(Rect2(-8,y,16,4),Color("35352d"))
		for x in [-4,4]:
			draw_circle(Vector2(x,y+2),0.8,Color("89806a"),true,-1.0,true)

func _roof_point(t: float, u: float, front: bool) -> Vector2:
	var a := Vector2(-138,-POST_HEIGHT-69)
	var b := Vector2(10,-POST_HEIGHT+5)
	var span := a.lerp(b,t)
	var ridge := span+Vector2(0,-26)
	var eave := span+(Vector2(-16,8) if front else Vector2(16,-8))
	var p := ridge.lerp(eave,u)
	# 中段下凹，端部起翘。弧度用于屋面本身，不只是额外勾边。
	p.y += sin(u*PI)*(1.5 if front else 0.5)-pow(absf(t-0.5)*2.0,8.0)*u*(2.0 if front else 1.0)
	return p

func _roof_mesh_enabled() -> bool:
	# Keep the former immediate drawing path for one-run screenshot A/B review.
	return OS.get_environment("CAMPAIGN_GATE_ROOF_MESH") != "0"


func roof_batch_summary() -> Dictionary:
	return {"lintel": lintel, "enabled": _roof_mesh_enabled(),
		"ready": _roof_mesh_ready, "last_roof_route": _last_roof_route,
		"faces": _roof_fill_meshes.size(),
		"draw_submissions": _roof_fill_meshes.size() + _roof_line_meshes.size(),
		"tile_count": ROOF_TILE_COLUMNS * ROOF_TILE_ROWS * 2}


func _draw_roof() -> void:
	var a := Vector2(-128,-POST_HEIGHT-64)
	var b := Vector2(0,-POST_HEIGHT)
	# 横梁有厚度，下缘保持深色，避免亮线像金属棚架。
	draw_line(a,b,Color("392b1c"),13.0,true)
	draw_line(a+Vector2(0,-3),b+Vector2(0,-3),Color("987043"),6.0,true)
	draw_line(a+Vector2(0,1),b+Vector2(0,1),Color("694928"),2.0,true)
	for i in range(12):
		var p := a.lerp(b,float(i)/11.0)
		draw_line(p+Vector2(-14,-6),p+Vector2(12,-19),Color("4b3724"),3.0,true)
	# 先远坡，再山面，最后近坡，形成明确的双坡瓦顶。
	var use_mesh := _roof_mesh_enabled()
	if use_mesh:
		_ensure_roof_meshes()
		use_mesh = _roof_mesh_ready
	_last_roof_route = "mesh" if use_mesh else ("legacy" if not _roof_mesh_enabled() else "legacy_fallback")
	if use_mesh:
		_draw_roof_face_mesh(0)
	else:
		_draw_roof_face(false)
	var ridge := _roof_point(1.0,0.0,true)
	var back := _roof_point(1.0,1.0,false)
	var front := _roof_point(1.0,1.0,true)
	draw_colored_polygon(PackedVector2Array([ridge,back,front]),Color("63482c"))
	draw_polyline(PackedVector2Array([back,ridge,front]),Color("a0875c"),2.0,true)
	draw_line(ridge+Vector2(0,6),back.lerp(front,0.5),Color("342c21"),2.0,true)
	if use_mesh:
		_draw_roof_face_mesh(1)
	else:
		_draw_roof_face(true)
	var ridge_line := PackedVector2Array()
	for i in range(29):
		var t := float(i)/28.0
		var p := _roof_point(t,0.0,true)
		p.y -= pow(absf(t-0.5)*2.0,8.0)*2.0
		ridge_line.append(p)
	draw_polyline(ridge_line,Color("343730"),5.5,true)
	draw_polyline(ridge_line,Color("aaa18a"),1.6,true)
	# 匾额顺横梁透视，尺寸低于门洞净高；随整个门架透明避让。
	var plaque := Transform2D(Vector2(1,0.5),Vector2(0,1),a.lerp(b,0.5)+Vector2(-23,12))
	draw_set_transform_matrix(_screen_basis()*plaque)
	draw_rect(Rect2(-2,-11,48,20),Color("82613a"))
	draw_rect(Rect2(0,-9,44,16),Color("302c21"))
	if facing<0:
		# The doorway may face the other axis, but lettering must never be mirrored.
		draw_set_transform_matrix(_screen_basis()*plaque*Transform2D(Vector2(-1,0),Vector2(0,1),Vector2(44,0)))
	draw_string(ThemeDB.fallback_font,Vector2(4,3),plaque_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("cab586"))
	draw_set_transform_matrix(_screen_basis())


func _draw_roof_face_mesh(index: int) -> void:
	if index < 0 or index >= _roof_fill_meshes.size() or index >= _roof_line_meshes.size():
		_draw_roof_face(index == 1)
		return
	draw_mesh(_roof_fill_meshes[index], null)
	draw_mesh(_roof_line_meshes[index], null)
	_draw_roof_eaves(index == 1)


func _ensure_roof_meshes() -> void:
	if _roof_mesh_ready:
		return
	_roof_fill_meshes.clear()
	_roof_line_meshes.clear()
	for front in [false, true]:
		var meshes := _build_roof_face_meshes(front)
		var fill: ArrayMesh = meshes.fill
		var lines: ArrayMesh = meshes.lines
		if fill == null or lines == null:
			_roof_fill_meshes.clear()
			_roof_line_meshes.clear()
			return
		_roof_fill_meshes.append(fill)
		_roof_line_meshes.append(lines)
	_roof_mesh_ready = _roof_fill_meshes.size() == 2 and _roof_line_meshes.size() == 2


func _build_roof_face_meshes(front: bool) -> Dictionary:
	var fill_vertices := PackedVector3Array()
	var fill_colors := PackedColorArray()
	var fill_indices := PackedInt32Array()
	var line_vertices := PackedVector3Array()
	var line_colors := PackedColorArray()
	var line_indices := PackedInt32Array()
	for row in range(ROOF_TILE_ROWS):
		for col in range(ROOF_TILE_COLUMNS):
			var t0 := float(col) / float(ROOF_TILE_COLUMNS)
			var t1 := float(col + 1) / float(ROOF_TILE_COLUMNS)
			var u0 := float(row) / float(ROOF_TILE_ROWS)
			var u1 := float(row + 1) / float(ROOF_TILE_ROWS)
			var q0 := _roof_point(t0, u0, front)
			var q1 := _roof_point(t1, u0, front)
			var q2 := _roof_point(t1, u1, front)
			var q3 := _roof_point(t0, u1, front)
			var tone := float((col * 13 + row * 7) % 9) * 0.009
			var base := Color("55554b") if front else Color("3c4039")
			_append_roof_quad(fill_vertices, fill_colors, fill_indices, q0, q1, q2, q3, base.lightened(tone))
			_append_roof_stroke(line_vertices, line_colors, line_indices, q0, q3,
				Color(0.67, 0.65, 0.55, 0.58), 0.8)
			_append_roof_stroke(line_vertices, line_colors, line_indices, q1, q2,
				Color(0.14, 0.17, 0.14, 0.7), 0.7)
			_append_roof_stroke(line_vertices, line_colors, line_indices, q3, q2,
				Color(0.19, 0.21, 0.18, 0.6), 0.8)
	return {"fill": _make_roof_mesh(fill_vertices, fill_colors, fill_indices),
		"lines": _make_roof_mesh(line_vertices, line_colors, line_indices)}


func _append_roof_quad(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, q0: Vector2, q1: Vector2, q2: Vector2, q3: Vector2,
		color: Color) -> void:
	var first := vertices.size()
	for point in [q0, q1, q2, q3]:
		vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append(color)
	indices.append_array(PackedInt32Array([first, first + 1, first + 2,
		first, first + 2, first + 3]))


func _append_roof_stroke(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, from: Vector2, to: Vector2, color: Color,
		width: float) -> void:
	var delta := to - from
	if delta.length_squared() <= 0.000001:
		return
	# A narrow quad batches the old sub-pixel antialiased lines. At game scale
	# this matches the old 0.7–0.8 px seams while reducing thousands of calls.
	var normal := Vector2(-delta.y, delta.x).normalized() * width * 0.5
	_append_roof_quad(vertices, colors, indices, from + normal, to + normal,
		to - normal, from - normal, color)


func _make_roof_mesh(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _draw_roof_face(front: bool) -> void:
	for row in range(ROOF_TILE_ROWS):
		for col in range(ROOF_TILE_COLUMNS):
			var t0 := float(col) / float(ROOF_TILE_COLUMNS)
			var t1 := float(col + 1) / float(ROOF_TILE_COLUMNS)
			var u0 := float(row) / float(ROOF_TILE_ROWS)
			var u1 := float(row + 1) / float(ROOF_TILE_ROWS)
			var q0 := _roof_point(t0,u0,front)
			var q1 := _roof_point(t1,u0,front)
			var q2 := _roof_point(t1,u1,front)
			var q3 := _roof_point(t0,u1,front)
			var tone := float((col*13+row*7)%9)*0.009
			var base := Color("55554b") if front else Color("3c4039")
			draw_colored_polygon(PackedVector2Array([q0,q1,q2,q3]),base.lightened(tone))
			draw_line(q0,q3,Color(0.67,0.65,0.55,0.58),0.8,true)
			draw_line(q1,q2,Color(0.14,0.17,0.14,0.7),0.7,true)
			draw_line(q3,q2,Color(0.19,0.21,0.18,0.6),0.8,true)
	_draw_roof_eaves(front)


func _draw_roof_eaves(front: bool) -> void:
	var eaves := PackedVector2Array()
	for i in range(ROOF_TILE_COLUMNS + 1):
		eaves.append(_roof_point(float(i) / float(ROOF_TILE_COLUMNS), 1.0, front))
	draw_polyline(eaves,Color("34382f"),4.0,true)
	draw_polyline(eaves,Color("99947c"),1.3,true)
