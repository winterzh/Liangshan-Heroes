class_name GameMap
extends Node2D
## 通用地形地图（关卡驱动）：尺寸可变，地形种类带通行性/移速/混色规则。
## 关卡通过 paint 原语（fill_ellipse/paint_path/fill_rect/scatter/set_cell）绘制各自布局，
## 再调用 bake() 建立 AStar 寻路。渲染层套等距投影（见 ISO）。

const CELL := 32

# 等距投影（AoE2 式 2:1 菱形格）：逻辑空间(方格) <-> 屏幕空间。
const ISO := Transform2D(Vector2(1.0, 0.5), Vector2(-1.0, 0.5), Vector2.ZERO)
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)

# 建筑占地半径（格）：小建筑至少 1，最大 3。视觉/可点半径/放置预览都由它派生，单一来源——
# 改这一处即同步「建造预览虚影、实际建筑贴图、选取/驻军/修理可点范围」三者，永不再错位。
static func footprint_half_for(radius: float) -> int:
	return clampi(int(round(radius / float(CELL))), 1, 3)

# 建筑贴图边长（px）：跟占地走（(2*half+1) 格再放大 1.5，留出屋檐/旗帜超出地基）。
# 建造预览与落成后的实际贴图都用这条，确保「预览多大、建好就多大」。
static func building_visual_px(half: int) -> float:
	return float(2 * half + 1) * float(CELL) * 1.5

enum T {
	WATER, SHORE, MARSH, REEDS, GRASS, ROAD, FOREST, HALL,
	DRYHILL, CLIFF, TOWN, PLAZA, FIELD, PLAIN, DOCK,
}

# 地形属性表：tex(贴图键), color(占位色), solid(不可通行), sl/sg(梁山/官军移速倍率), rank(混色优先级)
const INFO := {
	T.WATER:   {"tex": "water",   "color": "2b5d8a", "solid": true,  "sl": 0.4,  "sg": 0.4,  "rank": 0},
	T.SHORE:   {"tex": "shore",   "color": "5d6e4e", "solid": false, "sl": 0.9,  "sg": 0.7,  "rank": 1},
	T.MARSH:   {"tex": "marsh",   "color": "5d6e4e", "solid": false, "sl": 0.85, "sg": 0.5,  "rank": 2},
	T.REEDS:   {"tex": "reeds",   "color": "7d8f57", "solid": false, "sl": 0.85, "sg": 0.5,  "rank": 3},
	T.GRASS:   {"tex": "grass",   "color": "6f9c54", "solid": false, "sl": 1.0,  "sg": 1.0,  "rank": 4},
	T.ROAD:    {"tex": "road",    "color": "b59a6a", "solid": false, "sl": 1.15, "sg": 1.15, "rank": 6},
	T.FOREST:  {"tex": "forest",  "color": "3f6e3c", "solid": false, "sl": 0.8,  "sg": 0.8,  "rank": 5},
	T.HALL:    {"tex": "grass",   "color": "6f9c54", "solid": true,  "sl": 1.0,  "sg": 1.0,  "rank": 4},
	T.DRYHILL: {"tex": "dryhill", "color": "b59760", "solid": false, "sl": 1.0,  "sg": 1.0,  "rank": 4},
	T.CLIFF:   {"tex": "cliff",   "color": "7a6242", "solid": true,  "sl": 1.0,  "sg": 1.0,  "rank": 7},
	T.TOWN:    {"tex": "town",    "color": "9a8a72", "solid": false, "sl": 1.1,  "sg": 1.1,  "rank": 6},
	T.PLAZA:   {"tex": "plaza",   "color": "a89a7e", "solid": false, "sl": 1.1,  "sg": 1.1,  "rank": 6},
	T.FIELD:   {"tex": "field",   "color": "8a9550", "solid": false, "sl": 0.95, "sg": 0.9,  "rank": 4},
	T.PLAIN:   {"tex": "grass",   "color": "789c52", "solid": false, "sl": 1.05, "sg": 1.05, "rank": 4},
	T.DOCK:    {"tex": "bridge",  "color": "8a6f4d", "solid": false, "sl": 1.1,  "sg": 1.1,  "rank": 6},
}

var w := 60
var h := 60
var theme := "marsh"
var base_fill := T.GRASS

var grid := PackedInt32Array()
var astar := AStarGrid2D.new()
var decor: Array = []   # [tex_key, Vector2i cell, float size]，由关卡设置


func init_map(p_w: int, p_h: int, p_theme: String, p_base: int) -> void:
	w = p_w
	h = p_h
	theme = p_theme
	base_fill = p_base
	grid.resize(w * h)
	for i in range(grid.size()):
		grid[i] = base_fill


func idx(x: int, y: int) -> int:
	return y * w + x


func t_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return T.WATER
	return grid[idx(x, y)]


func set_cell_t(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	grid[idx(x, y)] = v


## ---------- 绘制原语（关卡布局用） ----------

func fill_ellipse(c: Vector2, rx: float, ry: float, val: int, only: Array = []) -> void:
	for y in range(int(c.y - ry), int(c.y + ry) + 1):
		for x in range(int(c.x - rx), int(c.x + rx) + 1):
			var dx := (x - c.x) / maxf(rx, 0.001)
			var dy := (y - c.y) / maxf(ry, 0.001)
			if dx * dx + dy * dy <= 1.0:
				if only.is_empty() or t_at(x, y) in only:
					set_cell_t(x, y, val)


func fill_rect(x0: int, y0: int, rw: int, rh: int, val: int, only: Array = []) -> void:
	for y in range(y0, y0 + rh):
		for x in range(x0, x0 + rw):
			if only.is_empty() or t_at(x, y) in only:
				set_cell_t(x, y, val)


func paint_path(pts: Array, brush: int, val: int) -> void:
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := int(a.distance_to(b) * 2.0) + 1
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / float(steps))
			for dy in range(-brush, brush + 1):
				for dx in range(-brush, brush + 1):
					set_cell_t(int(round(p.x)) + dx, int(round(p.y)) + dy, val)


## 在指定地形上按伪随机散布另一种地形（点缀）
func scatter(of_type: int, into: int, density: int, seed_mix: int = 0) -> void:
	for y in range(h):
		for x in range(w):
			if t_at(x, y) == of_type and (x * 13 + y * 7 + x * y + seed_mix) % 19 < density:
				set_cell_t(x, y, into)


## ---------- 寻路烘焙 ----------

func bake() -> void:
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in range(h):
		for x in range(w):
			var id := Vector2i(x, y)
			var info: Dictionary = INFO[t_at(x, y)]
			if info["solid"]:
				astar.set_point_solid(id, true)
			else:
				var sl: float = info["sl"]
				astar.set_point_weight_scale(id, clampf(1.4 / maxf(sl, 0.2), 1.0, 4.0))
	queue_redraw()


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / CELL)), 0, w - 1), clampi(int(floor(p.y / CELL)), 0, h - 1))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)


func is_open_cell(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return false
	return not astar.is_point_solid(c)


func is_open_world(p: Vector2) -> bool:
	return is_open_cell(world_to_cell(p))


func nearest_open(c: Vector2i) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 1))
	if is_open_cell(c):
		return c
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if is_open_cell(n):
					return n
	return c


func find_path(from_w: Vector2, to_w: Vector2) -> PackedVector2Array:
	var a := nearest_open(world_to_cell(from_w))
	var b := nearest_open(world_to_cell(to_w))
	var out := PackedVector2Array()
	if a == b:
		out.append(cell_to_world(b))
		return out
	var ids := astar.get_id_path(a, b)
	for i in range(1, ids.size()):
		out.append(cell_to_world(ids[i]))
	if out.is_empty():
		out.append(cell_to_world(b))
	return out


## 建造占地：把 (2*half+1)² 范围内格子在寻路网格里设/清 solid（建筑挡路）
func block_footprint(c: Vector2i, half: int, solid: bool) -> void:
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var n := c + Vector2i(dx, dy)
			if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h:
				astar.set_point_solid(n, solid)


## 该范围能否建造：全部在界内且当前可通行（非水/崖/已占建筑）
func area_buildable(c: Vector2i, half: int) -> bool:
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var n := c + Vector2i(dx, dy)
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				return false
			if not is_open_cell(n):
				return false
	return true


func t_world(p: Vector2) -> int:
	var c := world_to_cell(p)
	return t_at(c.x, c.y)


## 地形移速倍率（按阵营）
func speed_mult_at(p: Vector2, faction: int) -> float:
	var info: Dictionary = INFO[t_world(p)]
	return info["sl"] if faction == Unit.FACTION_LIANG else info["sg"]


## ---------- 渲染 ----------

const TILE_SPAN := 8


func _blend_color(t: int) -> Color:
	var info: Dictionary = INFO[t]
	return Art.terrain_avg_color(info["tex"], Color(info["color"]))


func _near_lower_water(x: int, y: int) -> bool:
	return t_at(x - 1, y) == T.WATER or t_at(x + 1, y) == T.WATER \
		or t_at(x, y - 1) == T.WATER or t_at(x, y + 1) == T.WATER


func _draw() -> void:
	for y in range(h):
		for x in range(w):
			var t := t_at(x, y)
			var info: Dictionary = INFO[t]
			var rect := Rect2(x * CELL, y * CELL, CELL, CELL)
			var key: String = info["tex"]
			var hv := (x * 31 + y * 17 + x * y) % 15
			if (t == T.GRASS or t == T.HALL) and hv % 3 == 0:
				key = "grass2"
			elif t == T.MARSH:
				key = "marsh" if (hv == 0 and not _near_lower_water(x, y)) else "shore"
			var tex: Texture2D = Art.terrain_texture(key)
			if tex != null:
				var at := tex as AtlasTexture
				# 地基(T.HALL)虽 solid，渲染上当草地无缝铺，避免营前出现一块突兀方块
				if at != null and (not bool(info["solid"]) or t == T.HALL):
					var sub := at.region.size / float(TILE_SPAN)
					var src := Rect2(at.region.position
						+ Vector2(float(posmod(x, TILE_SPAN)), float(posmod(y, TILE_SPAN))) * sub, sub)
					draw_texture_rect_region(at.atlas, rect, src)
				else:
					var rot := 0 if (t == T.ROAD or info["solid"]) else (x * 7 + y * 13 + x * y) % 4
					if rot == 0:
						draw_texture_rect(tex, rect, false)
					else:
						draw_set_transform(rect.position + Vector2(CELL * 0.5, CELL * 0.5), rot * PI * 0.5, Vector2.ONE)
						draw_texture_rect(tex, Rect2(-CELL * 0.5, -CELL * 0.5, CELL, CELL), false)
						draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var c: Color = Color(info["color"])
				if (x + y) % 2 == 0:
					c = c.darkened(0.04)
				c = c.lightened(float((x * 7 + y * 13) % 5) * 0.012)
				draw_rect(rect, c)
				if t == T.REEDS:
					var rc := Color("a8b86a")
					for k in range(3):
						var ox := float((x * 31 + y * 17 + k * 11) % 22) + 5.0
						var oy := float((x * 19 + y * 23 + k * 7) % 18) + 8.0
						draw_line(rect.position + Vector2(ox, oy + 6), rect.position + Vector2(ox, oy - 4), rc, 1.5)

	_draw_blends()

	for d in decor:
		var dtex: Texture2D = Art.terrain_texture(d[0])
		if dtex != null:
			var c := cell_to_world(d[1])
			var s: float = d[2]
			var tr := ISO_INV
			tr.origin = c
			draw_set_transform_matrix(tr)
			draw_texture_rect(dtex, Rect2(-s * 0.5, -s * 0.8, s, s), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const BLEND_W := 11.0
const BLEND_A := 0.5


func _draw_blends() -> void:
	for y in range(h):
		for x in range(w):
			var t := t_at(x, y)
			var rank: int = INFO[t]["rank"]
			var x0 := float(x * CELL)
			var y0 := float(y * CELL)
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nt := t_at(x + d[0], y + d[1])
				if nt == t or INFO[nt]["rank"] <= rank:
					continue
				var c := _blend_color(nt)
				var ca := Color(c.r, c.g, c.b, BLEND_A)
				var c0 := Color(c.r, c.g, c.b, 0.0)
				var pts: PackedVector2Array
				if d[0] == -1:
					pts = PackedVector2Array([Vector2(x0, y0), Vector2(x0, y0 + CELL), Vector2(x0 + BLEND_W, y0 + CELL), Vector2(x0 + BLEND_W, y0)])
				elif d[0] == 1:
					pts = PackedVector2Array([Vector2(x0 + CELL, y0), Vector2(x0 + CELL, y0 + CELL), Vector2(x0 + CELL - BLEND_W, y0 + CELL), Vector2(x0 + CELL - BLEND_W, y0)])
				elif d[1] == -1:
					pts = PackedVector2Array([Vector2(x0, y0), Vector2(x0 + CELL, y0), Vector2(x0 + CELL, y0 + BLEND_W), Vector2(x0, y0 + BLEND_W)])
				else:
					pts = PackedVector2Array([Vector2(x0, y0 + CELL), Vector2(x0 + CELL, y0 + CELL), Vector2(x0 + CELL, y0 + CELL - BLEND_W), Vector2(x0, y0 + CELL - BLEND_W)])
				draw_polygon(pts, PackedColorArray([ca, ca, c0, c0]))
