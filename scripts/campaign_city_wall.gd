extends Node2D
## A reusable brick-faced earthen city wall, on the same blocked cells as navigation.
## Static vertex colors keep courses and coping readable without a draw call per brick.
var end_local := Vector2.ZERO
var height_scale := 108.0
var salt := 0
var _mesh: ArrayMesh

func _draw() -> void:
	if _mesh==null: _build_mesh()
	draw_set_transform_matrix(GameMap.ISO_INV)
	draw_mesh(_mesh,null)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _build_mesh() -> void:
	var verts: Array[Vector2]=[]
	var colors: Array[Color]=[]
	var top := height_scale*0.76
	var depth := Vector2(10,-5)
	_quad(verts,colors,_p(0,0),_p(1,0),_p(1,top),_p(0,top),Color("514f43"))
	for row in range(7):
		var lower := row*top/7.0+0.6
		var upper := (row+1)*top/7.0-0.6
		var stagger := 0.5 if row%2 else 0.0
		for brick in range(-1,3):
			var left := maxf(0.0,(brick+stagger)/2.0+0.008)
			var right := minf(1.0,(brick+1+stagger)/2.0-0.008)
			if left>=right: continue
			var tone := float(posmod(brick*11+row*7+salt,9))*0.009
			_quad(verts,colors,_p(left,lower),_p(right,lower),_p(right,upper),_p(left,upper),Color("77725f").darkened(tone))
	_quad(verts,colors,_p(0,top),_p(1,top),_p(1,top)+depth,_p(0,top)+depth,Color("a19b83"))
	# Modest crenellations distinguish the city boundary from a wooden manor fence.
	for i in range(2):
		var l := float(i)*0.5
		var r := l+0.31
		var high := top+height_scale*0.16
		_quad(verts,colors,_p(l,top),_p(r,top),_p(r,high),_p(l,high),Color("797561"))
		_quad(verts,colors,_p(l,high),_p(r,high),_p(r,high)+depth,_p(l,high)+depth,Color("aaa48b"))
		_quad(verts,colors,_p(r,top),_p(r,top)+depth,_p(r,high)+depth,_p(r,high),Color("5a594a"))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector2Array(verts)
	arrays[Mesh.ARRAY_COLOR]=PackedColorArray(colors)
	_mesh=ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func _p(t: float,height: float) -> Vector2:
	return end_local*t-Vector2(0,height)

func _quad(verts: Array[Vector2],colors: Array[Color],a: Vector2,b: Vector2,c: Vector2,d: Vector2,tint: Color) -> void:
	verts.append_array([a,b,c,a,c,d])
	for i in range(6): colors.append(tint)

func body_overlaps(foot: Vector2) -> bool:
	var area := Rect2(Vector2.ZERO,Vector2.ZERO).expand(end_local)
	area.position.y-=height_scale
	area.size.y+=height_scale+10.0
	return area.intersects(Rect2(foot+Vector2(-12,-38),Vector2(24,40)))
