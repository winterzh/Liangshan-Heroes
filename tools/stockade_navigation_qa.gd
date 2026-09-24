extends SceneTree
## Actual authored map + production navigation; no player profile or Steam writes.
var checks: Array = []
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok: failures.append(label)

func legal(map, origin: Vector2, path: PackedVector2Array) -> bool:
	if path.is_empty(): return false
	for point in path:
		if not map.is_open_world(point) or not map._segment_open(origin, point): return false
		origin = point
	return true

func _run() -> void:
	var Map = load("res://scripts/game_map.gd")
	var Layout = load("res://scripts/liangshan_layout.gd")
	for script in ["skirmish", "custom_defense"]:
		var level = load("res://scripts/levels/" + script + ".gd").new()
		var map = Map.new()
		map.init_map(level.map_w(), level.map_h(), level.map_theme(), level.map_base())
		seed(5088120)
		level.paint_map(map)
		map.bake()
		var wall_count := 0
		for y in range(20, 45):
			for x in range(5, 32):
				if x not in [5, 31] and y not in [20, 44]: continue
				var gate: bool = (y == 44 and x >= 16 and x <= 20) or (x == 31 and y >= 30 and y <= 34)
				var cell := Vector2i(x, y)
				check(map.is_open_cell(cell) == gate, script + " boundary " + str(cell))
				if gate: continue
				wall_count += 1
				check(not map._static_open(cell, 0) and not map._static_open(cell, 1), script + " static wall both factions " + str(cell))
				# Crossing the pictured wall, including diagonal shortcuts, must fail.
				var normal := Vector2(0, 32) if y in [20, 44] else Vector2(32, 0)
				var center: Vector2 = map.cell_to_world(cell)
				for skew in [-12.0, 0.0, 12.0]:
					var tangent: Vector2 = Vector2(normal.y, -normal.x).normalized() * skew
					check(not map._segment_open(center - normal + tangent, center + normal - tangent), script + " wall segment " + str(cell) + " skew=" + str(skew))
		check(wall_count == 90, script + " all 90 wall cells checked")
		var outside: Vector2 = map.cell_to_world(Vector2i(18, 1))
		var inside: Vector2 = map.cell_to_world(Vector2i(18, 36))
		var east: Vector2 = map.cell_to_world(Vector2i(34, 32))
		check(legal(map, outside, map.find_path(outside, east)), script + " north approach reaches east outside wall")
		for faction in [0, 1]:
			check(legal(map, outside, map.find_path(outside, inside, faction)), script + " open gates allow entrance faction=" + str(faction))
		map.block_footprint(Layout.RTS_GATE, 2, true)
		map.block_footprint(Layout.RTS_EAST_GATE, 2, true)
		for faction in [0, 1]:
			check(map.find_path(outside, inside, faction).is_empty(), script + " closed gates prevent entry faction=" + str(faction))
			check(map.find_path(inside, outside, faction).is_empty(), script + " closed gates prevent escape faction=" + str(faction))
		map.block_footprint(Layout.RTS_EAST_GATE, 2, false)
		for faction in [0, 1]:
			var path: PackedVector2Array = map.find_path(outside, inside, faction)
			check(legal(map, outside, path), script + " east gate opens legal route faction=" + str(faction))
			check(legal(map, inside, map.find_path(inside, outside, faction)), script + " return route through east gate faction=" + str(faction))
		map.block_footprint(Layout.RTS_EAST_GATE, 2, true)
		check(map.find_path(outside, inside).is_empty(), script + " reclosing east gate removes passage")
		map.block_footprint(Layout.RTS_GATE, 2, false)
		var south: Vector2 = map.cell_to_world(Vector2i(18, 49))
		check(legal(map, south, map.find_path(south, inside)), script + " south gate remains usable")
		map.free()
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"scope": "Authored skirmish/custom defense maps; 90 wall cells, diagonal segments, both factions, gate opening/reclosing and north approach connectivity. Not visual or performance acceptance."}
	FileAccess.open(OS.get_environment("STOCKADE_QA_OUTPUT"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("STOCKADE_QA ", checks.size(), " checks; failures=", failures.size())
	for failure in failures: print("FAIL ", failure)
	quit(0 if failures.is_empty() else 1)
