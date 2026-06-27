extends SceneTree
## 一次性图集预处理（headless 运行）：
##   godot --headless --path . --script res://tools/process_sheets.gd
## 功能：检测网格线精确切格 → 去线 → 单位/物件格抠掉纯色底（边缘泛洪）→
## 内容居中 → 重组为整齐的 256px 网格图集，覆盖写回 assets/。
## 原始图保留为 *_raw.png。

const INSET := 6           # 切格后内缩像素，吃掉网格线和压边
const KEY_TOL2 := 0.024    # 抠底颜色距离平方阈值（RGB 欧氏）

# 地形图中需要抠底的"物件格"（其余为整铺地块，不抠）
const TERRAIN_PROP_CELLS := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(3, 2), Vector2i(0, 3), Vector2i(2, 3)]
# 等距版（v2）原图：第 3、4 行全部为灰底等距物件
const TERRAIN_PROP_CELLS_ISO := [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
]
# 特殊子裁剪（归一化区域）：旧版堤道瓦片自带左右木桩边框，平铺成竖条纹——只取中段纯土路
const TERRAIN_CROPS := {Vector2i(2, 1): Rect2(0.30, 0.04, 0.40, 0.92)}


func _init() -> void:
	# 格子输出尺寸贴近原图切格后的实际尺寸（约 301/405px），避免二次重采样损失细节
	_process_sheet("res://assets/units_sheet_raw.png", "res://assets/units_sheet.png", 4, 304, true, [])
	# 等距版地形原图优先（土路已是纯夯土，无需裁剪）；缺失时退回旧版
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/terrain_sheet_raw_iso.png")):
		_process_sheet("res://assets/terrain_sheet_raw_iso.png", "res://assets/terrain_sheet.png", 4, 304, false, TERRAIN_PROP_CELLS_ISO)
	else:
		_process_sheet("res://assets/terrain_sheet_raw.png", "res://assets/terrain_sheet.png", 4, 304, false, TERRAIN_PROP_CELLS, TERRAIN_CROPS)
	_process_sheet("res://assets/portraits_sheet_raw.png", "res://assets/portraits_sheet.png", 3, 400, false, [])

	# —— 第二批图集（五幕战役）——
	# 新单位图集：全格抠灰底
	_process_sheet("res://assets/units2_raw.png", "res://assets/units2.png", 4, 304, true, [])
	_process_sheet("res://assets/units3_raw.png", "res://assets/units3.png", 4, 304, true, [])
	# 新地形图集：前 6 格(0-5)为无缝地块不抠，第 3、4 行为等距物件抠底
	_process_sheet("res://assets/terrain2_raw.png", "res://assets/terrain2.png", 4, 304, false, TERRAIN_PROP_CELLS_ISO)
	# 新头像图集：半身像不抠
	_process_sheet("res://assets/portraits2_raw.png", "res://assets/portraits2.png", 3, 400, false, [])
	# —— 第三批图集（第6-8幕：鲁智深/武松/张清剧情新登场人物）——
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/portraits3_raw.png")):
		_process_sheet("res://assets/portraits3_raw.png", "res://assets/portraits3.png", 3, 400, false, [])
	# —— 第四批头像（据守模式·地方英雄：祝家庄/连环马敌将 + 史文恭）——
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/portraits4_raw.png")):
		_process_sheet("res://assets/portraits4_raw.png", "res://assets/portraits4.png", 3, 400, false, [])
	# —— 第五批头像（据守模式·官军/庄兵兵种立绘：刀盾/弓手/骑兵/精骑/刽子手/打手/祝家马军/弓手/庄客）——
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/portraits5_raw.png")):
		_process_sheet("res://assets/portraits5_raw.png", "res://assets/portraits5.png", 3, 400, false, [])
	# 驻守战官军大将头像（十节度使等）
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/portraits6_raw.png")):
		_process_sheet("res://assets/portraits6_raw.png", "res://assets/portraits6.png", 3, 400, false, [])
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/portraits7_raw.png")):
		_process_sheet("res://assets/portraits7_raw.png", "res://assets/portraits7.png", 3, 400, false, [])
	# 重画批头像（梁山好汉/配角 + 江州牢子/连环马/朴刀/长枪/猛虎）
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/portraits8_raw.png")):
		_process_sheet("res://assets/portraits8_raw.png", "res://assets/portraits8.png", 3, 400, false, [])
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/portraits9_raw.png")):
		_process_sheet("res://assets/portraits9_raw.png", "res://assets/portraits9.png", 3, 400, false, [])

	# 一百单八将补全批：portraits10..18（3×3 灰底头像，不抠底）
	for n in range(10, 19):
		var rp := "res://assets/portraits%d_raw.png" % n
		if FileAccess.file_exists(ProjectSettings.globalize_path(rp)):
			_process_sheet(rp, "res://assets/portraits%d.png" % n, 3, 400, false, [])

	print("[process_sheets] done")
	quit()


func _process_sheet(src_path: String, dst_path: String, grid: int, cell_out: int, key_all: bool, key_cells: Array, crops: Dictionary = {}) -> void:
	var img := Image.load_from_file(src_path)
	if img == null:
		print("[process_sheets] SKIP missing ", src_path)
		return
	img.convert(Image.FORMAT_RGBA8)
	var xb := _detect_bounds(img, grid, true)
	var yb := _detect_bounds(img, grid, false)
	print("[process_sheets] %s xb=%s yb=%s" % [src_path.get_file(), xb, yb])

	var out := Image.create(grid * cell_out, grid * cell_out, false, Image.FORMAT_RGBA8)
	for cy in range(grid):
		for cx in range(grid):
			var rx: int = xb[cx] + INSET
			var ry: int = yb[cy] + INSET
			var rw: int = xb[cx + 1] - INSET - rx
			var rh: int = yb[cy + 1] - INSET - ry
			if crops.has(Vector2i(cx, cy)):
				var cr: Rect2 = crops[Vector2i(cx, cy)]
				rx += int(rw * cr.position.x)
				ry += int(rh * cr.position.y)
				rw = int(rw * cr.size.x)
				rh = int(rh * cr.size.y)
			var cell := img.get_region(Rect2i(rx, ry, rw, rh))
			cell.resize(cell_out, cell_out, Image.INTERPOLATE_LANCZOS)
			var do_key := key_all or key_cells.has(Vector2i(cx, cy))
			if do_key:
				_key_background(cell)
				_center_content(cell)
			out.blit_rect(cell, Rect2i(0, 0, cell_out, cell_out), Vector2i(cx * cell_out, cy * cell_out))
	out.save_png(ProjectSettings.globalize_path(dst_path))
	print("[process_sheets] wrote ", dst_path)


## 沿期望等分位置 ±14px 找最暗的行/列 = 网格线中心
func _detect_bounds(img: Image, grid: int, vertical: bool) -> Array:
	var size := img.get_width() if vertical else img.get_height()
	var other := img.get_height() if vertical else img.get_width()
	var bounds := [0]
	for k in range(1, grid):
		var expect := int(round(float(size) * k / grid))
		var best := expect
		var best_lum := INF
		for p in range(expect - 14, expect + 15):
			if p < 1 or p >= size - 1:
				continue
			var lum := 0.0
			for q in range(0, other, 16):
				var c := img.get_pixel(p, q) if vertical else img.get_pixel(q, p)
				lum += c.get_luminance()
			if lum < best_lum:
				best_lum = lum
				best = p
		bounds.append(best)
	bounds.append(size)
	return bounds


## 从边缘泛洪去除纯色背景（背景色取边框中值），不伤及精灵内部同色区域
func _key_background(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bg := _border_median(img)
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack := PackedInt32Array()

	for x in range(w):
		for y: int in [0, h - 1]:
			var i := y * w + x
			if visited[i] == 0 and _near(img.get_pixel(x, y), bg):
				visited[i] = 1
				stack.append(i)
	for y in range(h):
		for x2: int in [0, w - 1]:
			var i2 := y * w + x2
			if visited[i2] == 0 and _near(img.get_pixel(x2, y), bg):
				visited[i2] = 1
				stack.append(i2)

	while stack.size() > 0:
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % w
		var y := i / w
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		for n: int in [i - 1, i + 1, i - w, i + w]:
			if n < 0 or n >= w * h:
				continue
			var nx := n % w
			if absi(nx - x) > 1:
				continue
			if visited[n] == 0 and _near(img.get_pixel(nx, n / w), bg):
				visited[n] = 1
				stack.append(n)


func _near(c: Color, bg: Color) -> bool:
	var dr := c.r - bg.r
	var dg := c.g - bg.g
	var db := c.b - bg.b
	return dr * dr + dg * dg + db * db < KEY_TOL2


func _border_median(img: Image) -> Color:
	var rs: Array = []
	var gs: Array = []
	var bs: Array = []
	var w := img.get_width()
	var h := img.get_height()
	for x in range(0, w, 3):
		for y in [1, h - 2]:
			var c := img.get_pixel(x, y)
			rs.append(c.r)
			gs.append(c.g)
			bs.append(c.b)
	for y in range(0, h, 3):
		for x in [1, w - 2]:
			var c2 := img.get_pixel(x, y)
			rs.append(c2.r)
			gs.append(c2.g)
			bs.append(c2.b)
	rs.sort()
	gs.sort()
	bs.sort()
	var m := rs.size() / 2
	return Color(rs[m], gs[m], bs[m])


## 把不透明内容的包围盒平移到画布中心
func _center_content(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return
	var dx := w / 2 - (minx + maxx + 1) / 2
	var dy := h / 2 - (miny + maxy + 1) / 2
	if dx == 0 and dy == 0:
		return
	var shifted := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var src := Rect2i(maxi(0, -dx), maxi(0, -dy), w - absi(dx), h - absi(dy))
	shifted.blit_rect(img, src, Vector2i(maxi(0, dx), maxi(0, dy)))
	img.copy_from(shifted)
