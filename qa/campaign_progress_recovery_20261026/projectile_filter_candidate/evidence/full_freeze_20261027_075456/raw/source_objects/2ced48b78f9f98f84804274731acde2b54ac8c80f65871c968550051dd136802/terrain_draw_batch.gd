extends RefCounted
## 保持原地面格的 UV、顶点色与本地坐标不变，按 atlas 合成 ArrayMesh 后由
## GameMap 自己的 CanvasItem 一次 draw_mesh。不能把 MeshInstance2D 挂到地图外：
## 那会绕开 liangshan_coast 的材质、自然地表遮罩与高度投影。
var textured: Dictionary = {}
var tints: Array = []
# CanvasItem retains only a mesh RID in its draw list. Keep the ArrayMesh
# resources alive in the batch object, which GameMap stores until its next
# terrain redraw.
var _meshes: Array[ArrayMesh] = []


func add_region(texture: Texture2D, destination: Rect2, source: Rect2, color: Color) -> void:
	var key := texture.get_rid().get_id()
	if not textured.has(key):
		textured[key] = {"texture": texture, "quads": []}
	textured[key].quads.append([destination, source, color])


func add_tint(rect: Rect2, color: Color) -> void:
	tints.append([rect, color])


func flush(canvas: Node2D) -> void:
	# Kept as a one-run A/B fallback for screenshot review. The default path is
	# mesh batching; `=0` replays the former commands without changing map data.
	if OS.get_environment("CAMPAIGN_TERRAIN_MESH_BATCH") == "0":
		_flush_legacy(canvas)
		return
	for group in textured.values():
		var texture: Texture2D = group.texture
		var mesh := _textured_mesh(group.quads, texture.get_size())
		if mesh != null:
			# `canvas` is GameMap itself, retaining its existing local transform and
			# ShaderMaterial. Atlas is supplied only as the draw source texture.
			_meshes.append(mesh)
			canvas.draw_mesh(mesh, texture)
	# 色罩只覆盖自己的同一格；地形顶点连续，延后到整层贴图之后不改变合成。
	var tint_mesh := _tint_mesh(tints)
	if tint_mesh != null:
		_meshes.append(tint_mesh)
		canvas.draw_mesh(tint_mesh, null)


func _flush_legacy(canvas: Node2D) -> void:
	for group in textured.values():
		for quad in group.quads:
			canvas.draw_texture_rect_region(group.texture, quad[0], quad[1], quad[2])
	for tint in tints:
		canvas.draw_rect(tint[0], tint[1])


func _textured_mesh(quads: Array, texture_size: Vector2) -> ArrayMesh:
	if quads.is_empty() or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return null
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(quads.size() * 4)
	uvs.resize(quads.size() * 4)
	colors.resize(quads.size() * 4)
	indices.resize(quads.size() * 6)
	for index in quads.size():
		var quad: Array = quads[index]
		var destination: Rect2 = quad[0]
		var source: Rect2 = quad[1]
		var color: Color = quad[2]
		var vertex := index * 4
		vertices[vertex] = Vector3(destination.position.x, destination.position.y, 0.0)
		vertices[vertex + 1] = Vector3(destination.end.x, destination.position.y, 0.0)
		vertices[vertex + 2] = Vector3(destination.end.x, destination.end.y, 0.0)
		vertices[vertex + 3] = Vector3(destination.position.x, destination.end.y, 0.0)
		uvs[vertex] = source.position / texture_size
		uvs[vertex + 1] = Vector2(source.end.x / texture_size.x, source.position.y / texture_size.y)
		uvs[vertex + 2] = source.end / texture_size
		uvs[vertex + 3] = Vector2(source.position.x / texture_size.x, source.end.y / texture_size.y)
		colors[vertex] = color
		colors[vertex + 1] = color
		colors[vertex + 2] = color
		colors[vertex + 3] = color
		var triangle := index * 6
		indices[triangle] = vertex
		indices[triangle + 1] = vertex + 1
		indices[triangle + 2] = vertex + 2
		indices[triangle + 3] = vertex
		indices[triangle + 4] = vertex + 2
		indices[triangle + 5] = vertex + 3
	return _mesh_from_arrays(vertices, uvs, colors, indices)


func _tint_mesh(rects: Array) -> ArrayMesh:
	if rects.is_empty():
		return null
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(rects.size() * 4)
	colors.resize(rects.size() * 4)
	indices.resize(rects.size() * 6)
	for index in rects.size():
		var tint: Array = rects[index]
		var rect: Rect2 = tint[0]
		var color: Color = tint[1]
		var vertex := index * 4
		vertices[vertex] = Vector3(rect.position.x, rect.position.y, 0.0)
		vertices[vertex + 1] = Vector3(rect.end.x, rect.position.y, 0.0)
		vertices[vertex + 2] = Vector3(rect.end.x, rect.end.y, 0.0)
		vertices[vertex + 3] = Vector3(rect.position.x, rect.end.y, 0.0)
		colors[vertex] = color
		colors[vertex + 1] = color
		colors[vertex + 2] = color
		colors[vertex + 3] = color
		var triangle := index * 6
		indices[triangle] = vertex
		indices[triangle + 1] = vertex + 1
		indices[triangle + 2] = vertex + 2
		indices[triangle + 3] = vertex
		indices[triangle + 4] = vertex + 2
		indices[triangle + 5] = vertex + 3
	return _mesh_from_arrays(vertices, PackedVector2Array(), colors, indices)


func _mesh_from_arrays(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
