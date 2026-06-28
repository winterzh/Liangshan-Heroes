extends SceneTree
## 把 ChatGPT 生成的 2x2 走/打循环大图切成横向帧带，写入 assets/anim/<key>_<state>.png。
##   godot --headless --path . --script res://tools/cut_anim.gd
## 输入：/tmp/cg/<state>_<key>.png（state ∈ walk/attack），绿幕底 2x2，阅读序 = 走循环序。
## 处理：检测黑色网格 → 抠绿底（边缘泛洪）→ 去绿边溢色 → 内容居中(与静态图集同法，
##       保证 idle↔walk 不跳) → 各帧缩放为 FRAME 方格 → 按 [左上,右上,左下,右下] 拼成 1x4 帧带。

const FRAME := 256          # 每帧输出方格边长
const INSET := 26           # 切格后内缩，吃掉网格线 + 每格黑框边
const KEY_TOL2 := 0.05      # 抠绿底颜色距离平方阈值
const GRID := 2
var _interior_px := 0       # 当前帧带累计抠掉的「内部残绿」像素（日志用）


func _init() -> void:
	# 默认从 /tmp/cg 切全部；设 CG_DIR=<dir> 只切该目录（外科式重切几张，不动其余）
	var SRC_DIR := OS.get_environment("CG_DIR")
	if SRC_DIR == "":
		SRC_DIR = "/tmp/cg"
	var dir := DirAccess.open(SRC_DIR)
	if dir == null:
		print("[cut_anim] cannot open ", SRC_DIR); quit(); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/anim"))
	var n := 0
	for f in dir.get_files():
		if not f.ends_with(".png"): continue
		var state := ""
		if f.begins_with("walk_"): state = "walk"
		elif f.begins_with("attack_"): state = "attack"
		elif f.begins_with("death_"): state = "death"
		elif f.begins_with("idle_"): state = "idle"
		elif f.begins_with("gather_"): state = "gather"
		else: continue
		var key := f.get_basename().substr(state.length() + 1)
		_cut(SRC_DIR + "/" + f, key, state)
		n += 1
	# 建筑 2x2 图集（绿幕底）→ assets/buildings.png（2x2 静态图集）
	if FileAccess.file_exists(SRC_DIR + "/buildings.png"):
		_cut_atlas(SRC_DIR + "/buildings.png", "res://assets/buildings.png", 304)
	# 资源点物件 2x2 图集（绿幕底）→ assets/objects.png（金矿+三种树）
	if FileAccess.file_exists(SRC_DIR + "/objects.png"):
		_cut_atlas(SRC_DIR + "/objects.png", "res://assets/objects.png", 256)
	# 陷阱 2x2（均分切·绿幕抠像·逐格居中）→ assets/traps.png（滚木/陷坑/火油 + 备用）
	if FileAccess.file_exists(SRC_DIR + "/traps_raw.png"):
		_cut_grid(SRC_DIR + "/traps_raw.png", "res://assets/traps.png", 256, 2, true)
	# 新防御塔 2x2（备用静态图集，3x3 朝向图缺失时回退）→ assets/buildings2.png
	if FileAccess.file_exists(SRC_DIR + "/towers_raw.png"):
		_cut_grid(SRC_DIR + "/towers_raw.png", "res://assets/buildings2.png", 304, 2, true)
	# 杂项建筑 2x2（集市/攻城作坊 + 备用）→ assets/buildings3.png
	if FileAccess.file_exists(SRC_DIR + "/buildings3_raw.png"):
		_cut_grid(SRC_DIR + "/buildings3_raw.png", "res://assets/buildings3.png", 304, 2, true)
	# 防御塔 3x3 八方向开火图（均分切·绿幕抠像·【不】逐格居中，保持塔身固定只转武器）→ assets/tower_*.png
	for tw in ["tower_arrow", "tower_thunder", "tower_altar", "tower_caltrop"]:
		if FileAccess.file_exists(SRC_DIR + "/" + tw + ".png"):
			_cut_grid(SRC_DIR + "/" + tw + ".png", "res://assets/" + tw + ".png", 256, 3, false)
	print("[cut_anim] done, ", n, " sheets")
	quit()


## 均分网格切图（绿幕抠像）：grid×grid 等分 → 每格 INSET 内缩 → 抠绿底 → 去溢色 →（可选逐格居中）→
## 拼成 cell*grid 的干净透明图集（art_db 以同 grid 切片）。无网格线的干净绿幕图用「等分」比找黑缝更稳。
## do_center=false 用于「朝向图」：保持主体在格内同一相对位置（只让武器朝向变化，塔身不跳）。
func _cut_grid(src_path: String, dst: String, cell: int, grid: int, do_center: bool) -> void:
	var img := Image.load_from_file(src_path)
	if img == null:
		print("[cut_anim] SKIP missing ", src_path); return
	img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var out := Image.create(cell * grid, cell * grid, false, Image.FORMAT_RGBA8)
	for cy in range(grid):
		for cx in range(grid):
			var rx: int = int(round(float(W) * cx / grid)) + INSET
			var ry: int = int(round(float(H) * cy / grid)) + INSET
			var rw: int = int(round(float(W) * (cx + 1) / grid)) - INSET - rx
			var rh: int = int(round(float(H) * (cy + 1) / grid)) - INSET - ry
			var sub := img.get_region(Rect2i(rx, ry, rw, rh))
			sub.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
			_key_background(sub)
			_despill(sub)
			if do_center:
				_center_content(sub)
			out.blit_rect(sub, Rect2i(0, 0, cell, cell), Vector2i(cx * cell, cy * cell))
	out.save_png(ProjectSettings.globalize_path(dst))
	print("[cut_anim] wrote ", dst, " (", grid, "x", grid, ")")


## 2x2 绿幕图集 → 抠底·去溢色·居中后按 2x2 输出（art_db 以 grid=2 切片）
func _cut_atlas(src_path: String, dst: String, cell: int) -> void:
	var img := Image.load_from_file(src_path)
	if img == null:
		print("[cut_anim] SKIP missing ", src_path); return
	img.convert(Image.FORMAT_RGBA8)
	var xb := _detect_bounds(img, true)
	var yb := _detect_bounds(img, false)
	var out := Image.create(cell * GRID, cell * GRID, false, Image.FORMAT_RGBA8)
	for cy in range(GRID):
		for cx in range(GRID):
			var rx: int = xb[cx] + INSET
			var ry: int = yb[cy] + INSET
			var rw: int = xb[cx + 1] - INSET - rx
			var rh: int = yb[cy + 1] - INSET - ry
			var sub := img.get_region(Rect2i(rx, ry, rw, rh))
			sub.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
			_key_background(sub)
			_despill(sub)
			_center_content(sub)
			out.blit_rect(sub, Rect2i(0, 0, cell, cell), Vector2i(cx * cell, cy * cell))
	out.save_png(ProjectSettings.globalize_path(dst))
	print("[cut_anim] wrote ", dst)


func _cut(src_path: String, key: String, state: String) -> void:
	var img := Image.load_from_file(src_path)
	if img == null:
		print("[cut_anim] SKIP missing ", src_path); return
	img.convert(Image.FORMAT_RGBA8)
	_interior_px = 0
	# 干净绿幕 2×2（无网格线）：按 GRID 等分定格，比「找最暗缝」稳。
	# 找暗缝会把人物暗部误当格缝 → 下排帧裁进上排人物的脚（脚跑到帧顶）。带网格线的图走 _cut_atlas。
	var xb := _even_bounds(img.get_width())
	var yb := _even_bounds(img.get_height())
	# 阅读序 → 走循环序：左上,右上,左下,右下
	var order := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var strip := Image.create(FRAME * order.size(), FRAME, false, Image.FORMAT_RGBA8)
	for i in range(order.size()):
		var cx: int = order[i].x
		var cy: int = order[i].y
		var rx: int = xb[cx] + INSET
		var ry: int = yb[cy] + INSET
		var rw: int = xb[cx + 1] - INSET - rx
		var rh: int = yb[cy + 1] - INSET - ry
		var cell := img.get_region(Rect2i(rx, ry, rw, rh))
		cell.resize(FRAME, FRAME, Image.INTERPOLATE_LANCZOS)
		_interior_px += _key_background(cell)
		_despill(cell)
		if OS.get_environment("BOTTOM_ANCHOR") == "1":
			_fit_and_anchor(cell)   # 图鉴批：把人物缩放到留边、脚底站基线（修源图「太满、腿被切」）
		elif state == "death":
			_bottom_anchor_content(cell)
		else:
			_center_content(cell)
		strip.blit_rect(cell, Rect2i(0, 0, FRAME, FRAME), Vector2i(i * FRAME, 0))
	var dst := "res://assets/anim/%s_%s.png" % [key, state]
	strip.save_png(ProjectSettings.globalize_path(dst))
	print("[cut_anim] wrote ", dst)
	if _interior_px > 0:
		print("[degreen] %s_%s 内部残绿抠掉 %d px" % [key, state, _interior_px])


## 把人物内容缩放到「留边」尺寸并脚底站基线：解决源图人物画得太满、腿/脚被切出帧的问题。
## 目标：人物高 ≈ 帧高 TGT_H、宽 ≤ 帧宽 TGT_W（保横纵比，整体可见、四周留白），脚底落在 帧高 FOOT_Y。
const TGT_H := 0.80
const TGT_W := 0.84
const FOOT_Y := 0.96
func _fit_and_anchor(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.3:
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
	if maxx < 0:
		return
	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	var content := img.get_region(Rect2i(minx, miny, bw, bh))
	var s: float = minf(float(h) * TGT_H / float(bh), float(w) * TGT_W / float(bw))
	s = minf(s, 1.25)   # 略放大封顶，避免把本就小的图放糊
	var nw := maxi(1, int(round(float(bw) * s)))
	var nh := maxi(1, int(round(float(bh) * s)))
	content.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	img.fill(Color(0, 0, 0, 0))
	var px := int(round((float(w) - float(nw)) * 0.5))
	var py := int(round(float(h) * FOOT_Y)) - nh
	img.blit_rect(content, Rect2i(0, 0, nw, nh), Vector2i(maxi(px, 0), maxi(py, 0)))


## 等分定界：GRID 等分图宽/高（干净绿幕无网格线时用，避免找暗缝误判）。
func _even_bounds(size: int) -> Array:
	var b := []
	for k in range(GRID + 1):
		b.append(int(round(float(size) * k / GRID)))
	return b


func _detect_bounds(img: Image, vertical: bool) -> Array:
	var size := img.get_width() if vertical else img.get_height()
	var other := img.get_height() if vertical else img.get_width()
	var bounds := [0]
	for k in range(1, GRID):
		var expect := int(round(float(size) * k / GRID))
		var best := expect
		var best_lum := INF
		for p in range(expect - 18, expect + 19):
			if p < 1 or p >= size - 1: continue
			var lum := 0.0
			for q in range(0, other, 16):
				var c := img.get_pixel(p, q) if vertical else img.get_pixel(q, p)
				lum += c.get_luminance()
			if lum < best_lum:
				best_lum = lum; best = p
		bounds.append(best)
	bounds.append(size)
	return bounds


## 抠底；返回「内部绿池」(被图形包住、泛洪到不了的残绿)被额外抠掉的像素数，供日志统计。
func _key_background(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var bg := _border_median(img)
	var visited := PackedByteArray(); visited.resize(w * h)
	var stack := PackedInt32Array()
	for x in range(w):
		for y: int in [0, h - 1]:
			var i := y * w + x
			if visited[i] == 0 and _near(img.get_pixel(x, y), bg):
				visited[i] = 1; stack.append(i)
	for y in range(h):
		for x2: int in [0, w - 1]:
			var i2 := y * w + x2
			if visited[i2] == 0 and _near(img.get_pixel(x2, y), bg):
				visited[i2] = 1; stack.append(i2)
	while stack.size() > 0:
		var i := stack[stack.size() - 1]; stack.resize(stack.size() - 1)
		var x := i % w; var y := i / w
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		for nn: int in [i - 1, i + 1, i - w, i + w]:
			if nn < 0 or nn >= w * h: continue
			var nx := nn % w
			if absi(nx - x) > 1: continue
			if visited[nn] == 0 and _near(img.get_pixel(nx, nn / w), bg):
				visited[nn] = 1; stack.append(nn)
	# 内部绿池：被图形圈住、与边缘不连通的残绿（如拉弓的臂弓之间、跨步的两腿之间）。
	# 泛洪到不了 → 全图再扫一遍，凡仍是底色的直接抠透明（在去溢色之前，免得变成深青残块）。
	var interior := 0
	for yy in range(h):
		for xx in range(w):
			var c := img.get_pixel(xx, yy)
			if c.a > 0.0 and _near(c, bg):
				img.set_pixel(xx, yy, Color(0, 0, 0, 0))
				interior += 1
	return interior


## 去绿边溢色：残留的半透/不透明绿色描边像素，把过亮的绿分量压回到 max(r,b)
func _despill(img: Image) -> void:
	var w := img.get_width(); var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a <= 0.02: continue
			if c.g > 0.30 and c.g > c.r * 1.12 and c.g > c.b * 1.12:
				var m: float = maxf(c.r, c.b)
				img.set_pixel(x, y, Color(c.r, m, c.b, c.a))


func _near(c: Color, bg: Color) -> bool:
	var dr := c.r - bg.r; var dg := c.g - bg.g; var db := c.b - bg.b
	return dr * dr + dg * dg + db * db < KEY_TOL2


func _border_median(img: Image) -> Color:
	var rs: Array = []; var gs: Array = []; var bs: Array = []
	var w := img.get_width(); var h := img.get_height()
	for x in range(0, w, 3):
		for y in [1, h - 2]:
			var c := img.get_pixel(x, y); rs.append(c.r); gs.append(c.g); bs.append(c.b)
	for y in range(0, h, 3):
		for x in [1, w - 2]:
			var c2 := img.get_pixel(x, y); rs.append(c2.r); gs.append(c2.g); bs.append(c2.b)
	rs.sort(); gs.sort(); bs.sort()
	var m := rs.size() / 2
	return Color(rs[m], gs[m], bs[m])


func _center_content(img: Image) -> void:
	var w := img.get_width(); var h := img.get_height()
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				minx = mini(minx, x); miny = mini(miny, y)
				maxx = maxi(maxx, x); maxy = maxi(maxy, y)
	if maxx < 0: return
	var dx := w / 2 - (minx + maxx + 1) / 2
	var dy := h / 2 - (miny + maxy + 1) / 2
	if dx == 0 and dy == 0: return
	var shifted := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var src := Rect2i(maxi(0, -dx), maxi(0, -dy), w - absi(dx), h - absi(dy))
	shifted.blit_rect(img, src, Vector2i(maxi(0, dx), maxi(0, dy)))
	img.copy_from(shifted)


## 死亡帧专用：横向居中 + 内容「脚底」对齐统一基线（身体随帧塌向地面，而非被居中浮在半空）。
func _bottom_anchor_content(img: Image) -> void:
	var w := img.get_width(); var h := img.get_height()
	var minx := w; var maxx := -1; var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				minx = mini(minx, x); maxx = maxi(maxx, x); maxy = maxi(maxy, y)
	if maxx < 0: return
	var baseline := int(h * 0.92)                 # 统一脚底基线（接近格底）
	var dx := w / 2 - (minx + maxx + 1) / 2       # 横向居中
	var dy := baseline - maxy                     # 底缘对齐基线
	if dx == 0 and dy == 0: return
	var shifted := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var src := Rect2i(maxi(0, -dx), maxi(0, -dy), w - absi(dx), h - absi(dy))
	shifted.blit_rect(img, src, Vector2i(maxi(0, dx), maxi(0, dy)))
	img.copy_from(shifted)
