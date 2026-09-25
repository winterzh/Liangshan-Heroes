extends RefCounted
## Ordered, persistent meshes for static scenery's existing CanvasItem commands.
## Never sort by texture: translucent strokes, rock overlays and caps retain
## their original painter order. Only consecutive commands sharing a texture
## are coalesced. The owner retains this object for as long as its draw list.
##
## AA geometry follows Godot 4.6's canvas line/polyline feather construction:
## https://github.com/godotengine/godot/blob/4.6.3-stable/servers/rendering/renderer_canvas_cull.cpp
## This retains actual alpha-gradient edge/cap triangles, including subpixel
## widths and bounded miter joins; it does not replace AA lines with hard quads.
## Godot portions: Copyright (c) 2014-present Godot Engine contributors.
## Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
## THE SOFTWARE.

const FEATHER_SIZE := 1.25
static var _enabled := OS.get_environment("LSH_STATIC_SCENERY_BATCH") != "0"
var valid := true
var _batches: Array[Dictionary] = []
var _texture: Texture2D
var _vertices := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _source_commands := 0
var _vertex_count := 0
var _triangle_count := 0
var _aa_lines := 0
var _aa_polylines := 0
var _native_texture_rects := 0


static func enabled() -> bool:
	return _enabled


func finish() -> void:
	_flush()


func draw(canvas: CanvasItem) -> void:
	for batch in _batches:
		if batch.has("rect"):
			canvas.draw_texture_rect(batch.texture, batch.rect, batch.tile, batch.color)
		else:
			canvas.draw_mesh(batch.mesh, batch.texture)


func summary() -> Dictionary:
	return {"valid": valid, "source_commands": _source_commands,
		"draw_submissions": _batches.size(), "vertices": _vertex_count,
		"triangles": _triangle_count, "aa_lines": _aa_lines,
		"aa_polylines": _aa_polylines, "native_texture_rects": _native_texture_rects,
		"ordered": true}


func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_polygon(points, PackedColorArray([color]))


func draw_polygon(points: PackedVector2Array, colors: PackedColorArray,
		uvs := PackedVector2Array(), texture: Texture2D = null) -> void:
	_source_commands += 1
	var triangles := Geometry2D.triangulate_polygon(points)
	if triangles.is_empty() or (colors.size() != 1 and colors.size() != points.size()) \
			or (not uvs.is_empty() and uvs.size() != points.size()):
		valid = false
		return
	_append(points, colors, triangles, uvs, texture)


func draw_texture_rect(texture: Texture2D, rect: Rect2, tile: bool,
		color := Color.WHITE) -> void:
	_source_commands += 1
	_native_texture_rects += 1
	# Keep the sparse rock sprites as native commands. In particular AtlasTexture
	# can request filter_clip / margins, which ordinary mesh UVs do not reproduce.
	# Flush on both sides so these sprites never move across translucent strokes.
	_flush()
	_batches.append({"texture": texture, "rect": rect, "tile": tile, "color": color})
	_texture = null


func draw_line(from: Vector2, to: Vector2, color: Color, width: float,
		antialiased := false) -> void:
	_source_commands += 1
	if width < 0.0:
		valid = false
		return
	var backwards := (from - to).normalized()
	var normal := backwards.orthogonal()
	var half := normal * width * 0.5
	var a := from + half
	var b := from - half
	var c := to + half
	var d := to - half
	_quad(a, b, d, c, PackedColorArray([color]))
	if not antialiased:
		return
	_aa_lines += 1
	var feather := FEATHER_SIZE * minf(width, 1.0)
	var side := normal * feather
	var cap := backwards * feather
	var clear := Color(color, 0.0)
	var edge_colors := PackedColorArray([color, clear, clear, color])
	_quad(a, a + side, c + side, c, edge_colors)
	_quad(b, b - side, d - side, d, edge_colors)
	_quad(a, a + cap, b + cap, b, edge_colors)
	_quad(c, c - cap, d - cap, d, edge_colors)
	var corner_colors := PackedColorArray([color, clear, clear, clear])
	_quad(a, a + cap, a + cap + side, a + side, corner_colors)
	_quad(b, b + cap, b + cap - side, b - side, corner_colors)
	_quad(c, c - cap, c - cap + side, c + side, corner_colors)
	_quad(d, d - cap, d - cap - side, d - side, corner_colors)


func draw_polyline(points: PackedVector2Array, color: Color, width: float,
		antialiased := false) -> void:
	_source_commands += 1
	if points.size() < 2 or width < 0.0:
		valid = false
		return
	var loop := points[0].is_equal_approx(points[-1])
	var first_dir := Vector2.ZERO
	var last_dir := Vector2.ZERO
	for i in range(1, points.size()):
		var direction := (points[i] - points[i - 1]).normalized()
		if first_dir.is_zero_approx() and not direction.is_zero_approx():
			first_dir = direction
		if not direction.is_zero_approx():
			last_dir = direction
	var middle := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var solid_colors := PackedColorArray()
	var edge_colors := PackedColorArray()
	var clear := Color(color, 0.0)
	var feather := FEATHER_SIZE * minf(width, 1.0)
	var previous := Vector2.ZERO
	for i in range(points.size()):
		var direction := previous if i == points.size() - 1 else (points[i + 1] - points[i]).normalized()
		if direction.is_zero_approx(): direction = previous
		if loop and i == 0: previous = last_dir
		elif loop and i == points.size() - 1: previous = first_dir
		var edge: Vector2
		if not loop and i == 0: edge = first_dir.orthogonal()
		elif not loop and i == points.size() - 1: edge = last_dir.orthogonal()
		else: edge = _join_offset(direction, previous)
		var half := edge * width * 0.5
		var border := edge * feather
		var p := points[i]
		if antialiased and not loop and i == 0:
			var cap := -direction * feather
			middle.append_array(PackedVector2Array([p + half + cap, p - half + cap]))
			solid_colors.append_array(PackedColorArray([clear, clear]))
			left.append_array(PackedVector2Array([p + half + cap, p + half + cap + border]))
			right.append_array(PackedVector2Array([p - half + cap, p - half + cap - border]))
			edge_colors.append_array(PackedColorArray([clear, clear]))
		middle.append_array(PackedVector2Array([p + half, p - half]))
		solid_colors.append_array(PackedColorArray([color, color]))
		if antialiased:
			left.append_array(PackedVector2Array([p + half, p + half + border]))
			right.append_array(PackedVector2Array([p - half, p - half - border]))
			edge_colors.append_array(PackedColorArray([color, clear]))
			if not loop and i == points.size() - 1:
				var cap := previous * feather
				middle.append_array(PackedVector2Array([p + half + cap, p - half + cap]))
				solid_colors.append_array(PackedColorArray([clear, clear]))
				# Repeated corner vertex preserves the engine's end-cap diagonal.
				left.append_array(PackedVector2Array([p + half, p + half + cap + border, p + half + cap]))
				right.append_array(PackedVector2Array([p - half, p - half + cap - border, p - half + cap]))
				edge_colors.append_array(PackedColorArray([color, clear, clear]))
		previous = direction
	_strip(middle, solid_colors)
	if antialiased:
		_aa_polylines += 1
		_strip(left, edge_colors)
		_strip(right, edge_colors)


func _join_offset(direction: Vector2, previous: Vector2) -> Vector2:
	var bisector := (previous * direction.length() - direction * previous.length()).normalized()
	var sine := sin(bisector.angle_to(previous))
	var length := 1.0
	if not is_zero_approx(sine) and not direction.is_equal_approx(previous):
		length = clampf(1.0 / sine, -3.0, 3.0)
	else:
		bisector = direction.orthogonal()
	if bisector.is_zero_approx(): bisector = direction.orthogonal()
	return bisector * length


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, colors: PackedColorArray) -> void:
	_append(PackedVector2Array([a, b, c, d]), colors,
		PackedInt32Array([0, 1, 2, 0, 2, 3]), PackedVector2Array(), null)


func _strip(points: PackedVector2Array, colors: PackedColorArray) -> void:
	var triangles := PackedInt32Array()
	for i in range(points.size() - 2):
		triangles.append_array(PackedInt32Array([i, i + 1, i + 2] if i % 2 == 0 else [i + 1, i, i + 2]))
	_append(points, colors, triangles, PackedVector2Array(), null)


func _append(points: PackedVector2Array, colors: PackedColorArray,
		triangles: PackedInt32Array, uvs: PackedVector2Array, texture: Texture2D) -> void:
	if texture != _texture:
		_flush()
		_texture = texture
	var first := _vertices.size()
	for i in range(points.size()):
		_vertices.append(Vector3(points[i].x, points[i].y, 0.0))
		_colors.append(colors[0] if colors.size() == 1 else colors[i])
		_uvs.append(Vector2.ZERO if uvs.is_empty() else uvs[i])
	for index in triangles:
		_indices.append(first + index)


func _flush() -> void:
	if _indices.is_empty(): return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_batches.append({"mesh": mesh, "texture": _texture})
	_vertex_count += _vertices.size()
	_triangle_count += _indices.size() / 3
	_vertices = PackedVector3Array()
	_colors = PackedColorArray()
	_uvs = PackedVector2Array()
	_indices = PackedInt32Array()
