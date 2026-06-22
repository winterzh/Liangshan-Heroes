extends SceneTree
## 去掉 units2/units3 图集每格「脚下白云」（灰底抠图残留的近白软晕）。
##   godot --headless --path . --script res://tools/strip_puff.gd
## 思路：在已抠底(背景透明)的格子里，从透明区向内泛洪，吃掉「底部、近白、低饱和」的残留
## 像素——这正是脚下的白云；彩色/深色的人物本体不被吃。仅处理底部 ~38%，避免误伤白袍上身。

const SHEETS := ["res://assets/units2.png", "res://assets/units3.png", "res://assets/units_sheet.png"]
const GRID := 4
const ZONE := 0.55          # 只在内容包围盒「底部 45%」清理
const PALE_LUM := 0.57      # 近白阈值
const PALE_SAT := 0.34      # 低饱和阈值（白/灰，非肤色/衣物）


func _init() -> void:
	for s in SHEETS:
		if FileAccess.file_exists(ProjectSettings.globalize_path(s)):
			_do_sheet(s)
		else:
			print("[strip_puff] skip missing ", s)
	print("[strip_puff] done")
	quit()


func _do_sheet(path: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		print("[strip_puff] cannot load ", path); return
	img.convert(Image.FORMAT_RGBA8)
	var cell := img.get_width() / GRID
	var total := 0
	for cy in range(GRID):
		for cx in range(GRID):
			total += _strip_cell(img, cx * cell, cy * cell, cell)
	img.save_png(ProjectSettings.globalize_path(path))
	print("[strip_puff] %s erased=%d px" % [path.get_file(), total])


## 在 [ox,oy, cell×cell] 这一格内清白云，返回擦除像素数
func _strip_cell(img: Image, ox: int, oy: int, cell: int) -> int:
	# 内容包围盒（不透明）
	var miny := cell; var maxy := -1
	for y in range(cell):
		for x in range(cell):
			if img.get_pixel(ox + x, oy + y).a > 0.05:
				miny = mini(miny, y); maxy = maxi(maxy, y)
	if maxy < 0:
		return 0
	var zone_top := miny + int(float(maxy - miny) * ZONE)   # 仅清理底部区
	# 从透明像素向内泛洪，吃「底部+近白+低饱和」的残留
	var visited := PackedByteArray(); visited.resize(cell * cell)
	var stack := PackedInt32Array()
	for y in range(cell):
		for x in range(cell):
			if img.get_pixel(ox + x, oy + y).a <= 0.05:
				var i := y * cell + x
				if visited[i] == 0:
					visited[i] = 1; stack.append(i)
	var erased := 0
	while stack.size() > 0:
		var i := stack[stack.size() - 1]; stack.resize(stack.size() - 1)
		var x := i % cell; var y := i / cell
		for nn: int in [i - 1, i + 1, i - cell, i + cell]:
			if nn < 0 or nn >= cell * cell: continue
			var nx := nn % cell
			if absi(nx - x) > 1: continue   # 防左右环绕
			if visited[nn] != 0: continue
			var ny := nn / cell
			var c := img.get_pixel(ox + nx, oy + ny)
			if c.a <= 0.05:
				visited[nn] = 1; stack.append(nn)        # 透明：继续扩散
			elif ny >= zone_top and _is_puff(c):
				visited[nn] = 1
				img.set_pixel(ox + nx, oy + ny, Color(0, 0, 0, 0))   # 白云：擦掉并继续
				stack.append(nn); erased += 1
	return erased


func _is_puff(c: Color) -> bool:
	var mx: float = maxf(maxf(c.r, c.g), c.b)
	var mn: float = minf(minf(c.r, c.g), c.b)
	var sat := (mx - mn) / maxf(mx, 0.001)
	return c.get_luminance() > PALE_LUM and sat < PALE_SAT
