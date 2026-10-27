extends RefCounted
## 取材于第十一回的林峦、金沙滩、芦苇港汊；60格战场的压缩布局，非历史测绘。
## 此处改地形与通行；波次、兵力及战斗数值仍由原关卡管理。
const T := GameMap.T
const COMBAT_GROUND := Rect2i(24, 24, 15, 19)
const MAINLAND := [Vector2(-2,-2),Vector2(30,-2),Vector2(32,5),Vector2(30,9),
	Vector2(34,13),Vector2(32,17),Vector2(35,20),Vector2(33,23),Vector2(36,27),
	Vector2(35,31),Vector2(38,34),Vector2(35,37),Vector2(37,40),Vector2(31,43),
	Vector2(26,44),Vector2(24,47),Vector2(19,47),Vector2(18,48),Vector2(14,47),
	Vector2(11,46),Vector2(8,44),Vector2(5,42),Vector2(-2,44)]
const REED_BANKS := [
	[Vector2(51,-2),Vector2(62,-2),Vector2(62,62),Vector2(50,62),Vector2(53,54),
		Vector2(49,48),Vector2(51,43),Vector2(48,39),Vector2(51,33),Vector2(49,27),
		Vector2(52,22),Vector2(48,17),Vector2(50,12),Vector2(47,7)],
	[Vector2(-2,54),Vector2(5,51),Vector2(9,53),Vector2(15,56),Vector2(23,53),
		Vector2(27,50),Vector2(30,51),Vector2(33,55),Vector2(40,53),Vector2(44,56),
		Vector2(51,55),Vector2(62,59),Vector2(62,62),Vector2(-2,62)],
	[Vector2(39,1),Vector2(44,3),Vector2(46,8),Vector2(43,11),Vector2(46,16),
		Vector2(44,19),Vector2(40,17),Vector2(38,12),Vector2(40,8)],
	[Vector2(45,28),Vector2(48,30),Vector2(46,34),Vector2(48,38),Vector2(46,41),
		Vector2(44,38),Vector2(43,33)],
]

static func paint(map: GameMap) -> void:
	var original := map.grid.duplicate()
	var mainland := PackedVector2Array(MAINLAND)
	for y in range(map.h):
		for x in range(map.w):
			var cell := Vector2i(x,y)
			var p := Vector2(cell) + Vector2(0.5,0.5)
			var terrain := T.WATER
			if Geometry2D.is_point_in_polygon(p,mainland):
				var edge := _edge_distance(p,mainland)
				terrain = T.SHORE if edge<1.7 else T.GRASS
				# 山地连出北/西边界；林缘成片，不能重做随机草格圆环。
				if edge>3.0 and (y<26 or x<10):
					terrain = T.FOREST
				elif edge<3.5 and x>27:
					terrain = T.REEDS
			else:
				for bank in REED_BANKS:
					var outline := PackedVector2Array(bank)
					if Geometry2D.is_point_in_polygon(p,outline):
						terrain = T.MARSH if _edge_distance(p,outline)<0.8 else T.REEDS
						break
			# 东侧大港保持隔水，仅让原两条堤道跨过；苇滩不能暗中铺出第三条陆路。
			if x>=39 and x<=42:
				terrain = T.WATER
			if COMBAT_GROUND.has_point(cell) or original[y*map.w+x]==T.ROAD:
				terrain = original[y*map.w+x]
			map.set_cell_t(x,y,terrain)
	# 山麓小路沿后山下至寨侧，留在可通行的林中，不穿厅墙。
	map.paint_path([Vector2(18,6),Vector2(21,11),Vector2(19,17),Vector2(23,22),Vector2(23,23)],0,T.ROAD)
	# 裸岩与林木共同构成后山，岩块占地同步阻挡，不把大岩石画在可穿行地上。
	for cell in ridge_cells():
		map.set_cell_t(cell.x,cell.y,T.CLIFF)
	# 南侧低滩到主码头，道路与院落由Layout最后写入。
	map.fill_ellipse(Vector2(16,45),6,2,T.SHORE,[T.GRASS,T.MARSH,T.REEDS])
	# 官军营地落在东岸干地，不再让帐篷悬在水面。
	map.fill_rect(54,20,6,5,T.SHORE,[T.REEDS,T.MARSH,T.WATER])
	map.fill_rect(54,44,6,5,T.SHORE,[T.REEDS,T.MARSH,T.WATER])

static func ridge_cells() -> Array[Vector2i]:
	return [Vector2i(10,15),Vector2i(11,15),Vector2i(12,16),Vector2i(13,16),
		Vector2i(7,22),Vector2i(7,23),Vector2i(6,24),Vector2i(6,25),
		Vector2i(25,12),Vector2i(26,12),Vector2i(26,13)]

static func _edge_distance(p: Vector2, polygon: PackedVector2Array) -> float:
	var distance := INF
	for i in range(polygon.size()):
		distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,
			polygon[i],polygon[(i+1)%polygon.size()])))
	return distance
