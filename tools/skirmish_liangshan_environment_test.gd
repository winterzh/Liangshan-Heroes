extends SceneTree
## 驻守战梁山泊地貌契约：只验证地图数据、通行和经营空间，不冒充图形/真人试玩。

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	checks += 1
	if not ok:
		var detail_text := str(detail)
		failures.append(label + (": " + detail_text if not detail_text.is_empty() else ""))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level = load("res://scripts/levels/skirmish.gd").new()
	var Map = load("res://scripts/game_map.gd")
	var map = Map.new()
	get_root().add_child(map)
	map.init_map(level.map_w(), level.map_h(), level.map_theme(), level.map_base())
	level.paint_map(map)
	map.bake()

	_check(map.w == 60 and map.h == 60, "60格梁山压缩布局", Vector2i(map.w, map.h))
	_check(level.HALL == Vector2i(18, 30), "忠义堂与共同布局对齐", level.HALL)
	_check(level.GATE_A == Vector2i(18, 1), "山前大路入口固定", level.GATE_A)
	_check(map.t_at(level.GATE_C.x, level.GATE_C.y) == Map.T.DOCK,
		"金沙滩入口落在码头", map.t_at(level.GATE_C.x, level.GATE_C.y))

	var counts := {}
	for y in range(map.h):
		for x in range(map.w):
			var terrain: int = map.t_at(x, y)
			counts[terrain] = int(counts.get(terrain, 0)) + 1
	var wet_outer := int(counts.get(Map.T.WATER, 0)) + int(counts.get(Map.T.MARSH, 0)) \
		+ int(counts.get(Map.T.REEDS, 0))
	_check(int(counts.get(Map.T.WATER, 0)) >= 900, "水泊构成明显外圈", counts)
	_check(int(counts.get(Map.T.REEDS, 0)) >= 200, "芦苇港汊成片", counts)
	_check(wet_outer >= 2000, "水泊芦汊合计超过地图一半", wet_outer)
	_check(int(counts.get(Map.T.FOREST, 0)) >= 500, "林峦形成后山", counts)
	_check(int(counts.get(Map.T.ROAD, 0)) >= 70, "三关山路连续", counts)

	var hall_world: Vector2 = map.cell_to_world(level.HALL)
	var lane_lengths := {}
	for lane in range(level.GATES.size()):
		var gate: Vector2i = level.GATES[lane]
		var path: PackedVector2Array = map.find_path(map.cell_to_world(gate), hall_world, 1, "land")
		lane_lengths[lane] = path.size()
		_check(map.is_open_cell(gate), "入口%d为陆地开放格" % lane, gate)
		_check(not path.is_empty(), "入口%d可达忠义堂" % lane, gate)

	var economy_open := 0
	for y in range(24, 44):
		for x in range(7, 31):
			if map.is_open_cell(Vector2i(x, y)):
				economy_open += 1
	_check(economy_open >= 250, "寨心保留经营建造空间", economy_open)
	_check(map.nearest_open(level.GOLD).distance_to(level.GOLD) <= 2.0,
		"金矿靠近指定后山资源位", map.nearest_open(level.GOLD))

	var Layout = load("res://scripts/liangshan_layout.gd")
	var rts_court: Rect2i = Layout.court_for(map)
	var buildable_centers := 0
	for y in range(rts_court.position.y + 1, rts_court.end.y - 1):
		for x in range(rts_court.position.x + 1, rts_court.end.x - 1):
			if map.area_buildable(Vector2i(x,y),1):
				buildable_centers += 1
	_check(Layout.is_rts_layout(map), "驻守战启用RTS大寨布局")
	_check(rts_court.size.x >= 25 and rts_court.size.y >= 23, "内院尺寸容纳多座3×3建筑", rts_court)
	_check(buildable_centers >= 250, "3×3建筑可选中心充足", buildable_centers)
	_check(Layout.gate_for(map) == Vector2i(18,44) and Layout.east_gate_for(map) == Vector2i(31,32),
		"两座寨门移至大院外圈")
	_check(level.HALL.x == Layout.gate_for(map).x
		and level.HALL.x == Layout.dock_for(map).x
		and level.GATE_C.x == level.HALL.x,
		"忠义堂山前关主码头共用南北中轴")
	_check(Layout.east_gate_for(map).y * 2 + 1 == rts_court.position.y * 2 + rts_court.size.y,
		"东山关位于东墙中点", Layout.east_gate_for(map))
	var grove_cells: Array = level.TREE_GROVE_WEST + level.TREE_GROVE_REAR
	var grove_unique := {}
	for c in grove_cells:
		grove_unique[c] = true
	_check(level.TREE_GROVE_WEST.size() == 8 and level.TREE_GROVE_REAR.size() == 8
		and grove_unique.size() == 16, "木材集中为两片八棵林团")
	_check(level.TREE_GROVE_WEST.all(func(c): return c.x <= 13 and c.y <= 29)
		and level.TREE_GROVE_REAR.all(func(c): return c.x <= 13 and c.y >= 32),
		"两片林团收在寨内西侧并让出东门进攻线")
	var grove_clear_of_threats := grove_cells.all(func(c):
		return level.GATES.all(func(g): return Vector2(c).distance_to(Vector2(g)) >= 10.0))
	_check(grove_clear_of_threats, "林木距三路敌军入口至少十格")
	var entrance = load("res://scripts/liangshan_entrance.gd").new()
	entrance.setup(map)
	var gate_orientation: Dictionary = entrance.gate_orientation_summary()
	_check(gate_orientation.main_axis == "x" and is_equal_approx(gate_orientation.main_facing,1.0),
		"南侧正门沿X轴墙向展开", gate_orientation)
	_check(gate_orientation.east_axis == "y" and is_equal_approx(gate_orientation.east_facing,-1.0),
		"东门沿Y轴墙向展开", gate_orientation)
	_check(not gate_orientation.main_uses_fixed_bitmap,
		"RTS正门禁用固定朝下位图", gate_orientation)
	_check(gate_orientation.main_plaque == "山前关" and gate_orientation.east_plaque == "东山关",
		"寨门按原著关隘命名", gate_orientation)
	entrance.free()
	var wall_ridges: Array[PackedVector2Array] = Layout.bank_ridges_for(map)
	var axis_aligned := true
	var screen_directions := {}
	for ridge in wall_ridges:
		for i in range(ridge.size()-1):
			var delta: Vector2 = ridge[i+1]-ridge[i]
			axis_aligned = axis_aligned and (is_zero_approx(delta.x) or is_zero_approx(delta.y))
			var projected: Vector2 = map.project(delta*Map.CELL)
			screen_directions[signf(projected.x*projected.y)] = true
	_check(axis_aligned, "寨墙沿真实格线布置")
	_check(screen_directions.has(-1.0) and screen_directions.has(1.0), "寨墙覆盖两种等距斜向", screen_directions)

	# 驻守战的大院不能反向污染第五关等剧情地图；未设置元数据时仍使用原布局。
	var story_map = Map.new()
	get_root().add_child(story_map)
	story_map.init_map(60, 60, level.map_theme(), level.map_base())
	_check(not Layout.is_rts_layout(story_map), "剧情地图默认不启用RTS大寨")
	_check(Layout.gate_for(story_map) == Layout.GATE
		and Layout.east_gate_for(story_map) == Layout.EAST_GATE
		and Layout.court_for(story_map) == Layout.COURT,
		"剧情地图保留原寨门与内院布局")
	_check(String(map.get_meta("zhongyi_hall_facing_cardinal", "")) == "south"
		and Vector2i(map.get_meta("zhongyi_hall_front_vector", Vector2i.ZERO)) == Vector2i(0,1),
		"忠义堂坐北朝南并面向山前关")
	_check(rts_court.has_point(level.HILLTOP_FLAG) and level.HILLTOP_FLAG.y < level.HALL.y,
		"替天行道杏黄旗位于寨内堂后山顶", level.HILLTOP_FLAG)

	var report := {
		"checks": checks,
		"passed": failures.is_empty(),
		"failures": failures,
		"terrain_counts": counts,
		"lane_path_points": lane_lengths,
		"economy_open_cells": economy_open,
		"rts_court": [rts_court.position.x,rts_court.position.y,rts_court.size.x,rts_court.size.y],
		"buildable_centers_3x3": buildable_centers,
		"resource_groves": {"west": level.TREE_GROVE_WEST.size(), "rear": level.TREE_GROVE_REAR.size()},
		"wall_ridges": wall_ridges.size(),
		"gate_orientation": gate_orientation,
		"scope": "map data, terrain composition, land path reachability and economy space; not visual or human playtest",
	}
	var report_dir := ProjectSettings.globalize_path("res://qa/skirmish_axis_resource_groves_20260904")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file := FileAccess.open(report_dir.path_join("map_contract.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("[skirmish-liangshan] ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
