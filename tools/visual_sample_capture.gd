extends SceneTree
## Real-render capture harness. Run with --script and VISUAL_CAPTURE_DIR.
## Uses a deployment scene; never calls campaign/settings save or advances waves.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out_dir := OS.get_environment("VISUAL_CAPTURE_DIR")
	if out_dir.is_empty():
		push_error("VISUAL_CAPTURE_DIR is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Normal visual acceptance always exercises the cached-roof route. A caller may
	# explicitly set =0 for a one-run legacy A/B capture, but that is not acceptance.
	if OS.get_environment("CAMPAIGN_GATE_ROOF_MESH").is_empty():
		OS.set_environment("CAMPAIGN_GATE_ROOF_MESH", "1")
	var campaign := root.get_node("Campaign")
	campaign.current = 4
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.arena = false
	campaign.custom_defense = false
	campaign.scenario = false
	campaign.ai_friendly = false
	campaign.scale_on = false
	var settings := root.get_node("Settings")
	settings.edge_scroll = false
	settings.game_speed = 1.0
	settings.atmosphere = true
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	seed(5088120)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	var expect_sample := OS.get_environment("LIANGSHAN_VISUAL_BASELINE") != "1"
	if expect_sample and (battle.map.sample_scenery == null or battle.map.sample_scenery._trees.is_empty()):
		push_error("Sample scene failed to load")
		quit(4)
		return
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.camera.set_process(false)
	battle.set_process(false)
	for unit in battle.units:
		unit.set_physics_process(false)
	battle._grid_build()
	if OS.get_environment("VISUAL_SAMPLE_INTERACTIVE") == "1":
		# 只读视觉浏览：保持部署状态，禁用战斗输入和波次；相机仍可移动缩放。
		root.title = "梁山视觉样板（仅浏览，不保存）"
		battle.set_process_input(false)
		battle.set_process_unhandled_input(false)
		battle.hud.start_btn.hide()
		battle.hud.set_top("梁山视觉样板 · 方向键移动 · 滚轮缩放 · 关闭窗口退出")
		battle.camera.position = battle.to_screen(battle.map.cell_to_world(Vector2i(23, 29)))
		battle.camera.zoom = Vector2.ONE * 0.85
		battle.camera.set_process(true)
		print("[visual_preview] camera enabled; combat and saving disabled")
		return
	if OS.get_environment("VISUAL_PERFORMANCE_ONLY")=="1":
		await _measure_coast(battle,out_dir)
		battle.queue_free()
		await process_frame
		await process_frame
		quit(0)
		return
	await create_timer(2.5).timeout
	var views := [
		{"name": "overview", "cell": Vector2i(23, 29), "zoom": 0.85},
		{"name": "hall_forest", "cell": Vector2i(17, 27), "zoom": 1.45},
		{"name": "causeway", "cell": Vector2i(34, 29), "zoom": 1.65},
		{"name": "entrance", "cell": Vector2i(17, 38), "zoom": 1.10},
		{"name": "wetland", "cell": Vector2i(27, 43), "zoom": 0.85},
		{"name": "back_hills", "cell": Vector2i(16, 20), "zoom": 1.05},
		{"name": "landscape", "cell": Vector2i(29, 29), "zoom": 0.60},
	]
	for view in views:
		battle.camera.position = battle.to_screen(battle.map.cell_to_world(view.cell))
		battle.camera.zoom = Vector2.ONE * float(view.zoom)
		battle.camera.force_update_scroll()
		await create_timer(1.10).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		var err := shot.save_png(out_dir.path_join(view.name + ".png"))
		print("[visual_capture] %s %dx%d save=%d" % [view.name, shot.get_width(), shot.get_height(), err])
		if err != OK:
			quit(3)
			return
	var solids: Array = []
	var weights: Array = []
	for y in range(battle.map.h):
		for x in range(battle.map.w):
			var cell := Vector2i(x, y)
			solids.append(battle.map.astar.is_point_solid(cell))
			weights.append([battle.map.astar.get_point_weight_scale(cell), battle.map.astar_guan.get_point_weight_scale(cell)])
	var snapshot := {"grid": Array(battle.map.grid), "solids": solids, "weights": weights,
		"units": [], "paths": [], "decor": battle.map.decor}
	for unit in battle.units:
		snapshot.units.append({"key": unit.key, "position": [unit.position.x, unit.position.y], "hp": unit.hp})
	for source in [Vector2i(57, 22), Vector2i(57, 46)]:
		var path: PackedVector2Array = battle.map.astar_guan.get_point_path(source, Vector2i(20, 30))
		snapshot.paths.append(Array(path))
	var file := FileAccess.open(out_dir.path_join("gameplay_snapshot.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	print("[visual_capture] snapshot saved; grid=%d units=%d" % [snapshot.grid.size(), snapshot.units.size()])
	if OS.get_environment("VISUAL_VERIFY") == "1" and expect_sample:
		var passed := await _verify_forest(battle, out_dir)
		passed = await _verify_layout(battle, out_dir) and passed
		passed = await _verify_gate_roof(battle, out_dir) and passed
		passed = await _verify_stockade(battle, out_dir) and passed
		if battle.map.height_field != null:
			passed = await _verify_height(battle, out_dir) and passed
		passed = await _verify_environment(battle,out_dir) and passed
		await _measure_coast(battle, out_dir)
		if not passed:
			quit(5)
			return
	battle.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _verify_forest(battle, out_dir: String) -> bool:
	var scenery = battle.map.sample_scenery
	var target_tree = scenery._trees[0]
	for tree in scenery._trees:
		if tree.position.distance_squared_to(Vector2(816, 720)) < target_tree.position.distance_squared_to(Vector2(816, 720)):
			target_tree = tree
	var probe = battle.spawn_unit("liang_dao", 0, target_tree.position - Vector2(20, 20))
	probe.set_physics_process(false)
	battle._grid_build()
	battle._set_selection([probe])
	battle.camera.position = battle.to_screen(target_tree.position) + Vector2(0, -35)
	battle.camera.zoom = Vector2.ONE * 2.2
	battle.camera.force_update_scroll()
	await create_timer(1.5).timeout
	var can_select: bool = battle._friendly_at(battle.to_screen(probe.position)) == probe
	var faded: bool = target_tree.modulate.a < 0.6
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("forest_passage.png"))
	var destination: Vector2 = target_tree.position + Vector2(48, 48)
	probe.order_move(destination)
	probe.set_physics_process(true)
	var start_ms := Time.get_ticks_msec()
	while probe.position.distance_to(destination) > 6.0 and Time.get_ticks_msec() - start_ms < 10000:
		await physics_frame
		battle._grid_build()
	var reached: bool = probe.position.distance_to(destination) <= 6.0
	probe.set_physics_process(false)
	# 移到林外，确认被让开的树冠可恢复。
	probe.position = battle.map.cell_to_world(Vector2i(30, 30))
	battle._grid_build()
	await create_timer(0.3).timeout
	var restored: bool = is_equal_approx(target_tree.modulate.a, 1.0)
	var result := {"select_under_canopy": can_select, "canopy_fades": faded,
		"walk_through_forest": reached, "canopy_restores": restored,
		"tree_count": scenery._trees.size(), "passed": can_select and faded and reached and restored}
	var file := FileAccess.open(out_dir.path_join("forest_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("[visual_verify] ", JSON.stringify(result))
	return result.passed


func _verify_layout(battle, out_dir: String) -> bool:
	var layout = load("res://scripts/liangshan_layout.gd")
	# --script 在 autoload 就绪前编译入口，不能以 GameMap 注解提前编译 Art 依赖。
	var map = battle.map
	var result := {"routes": [], "blocked_bank_cells": 0, "banks_block_both_factions": true,
		"paths_avoid_solids": true, "all_routes_reachable": true}
	for y in range(map.h):
		for x in range(map.w):
			if layout.is_bank(Vector2i(x, y)):
				result.blocked_bank_cells += 1
				result.banks_block_both_factions = result.banks_block_both_factions \
					and map.astar.is_point_solid(Vector2i(x, y)) and map.astar_guan.is_point_solid(Vector2i(x, y))
	for pair in [[layout.DOCK, layout.HALL_APPROACH],
		[Vector2i(57, 22), Vector2i(20, 30)], [Vector2i(57, 46), Vector2i(20, 30)],
		[Vector2i(13, 42), Vector2i(13, 38)]]:
		for team in range(2):
			var grid: AStarGrid2D = map.astar if team == 0 else map.astar_guan
			var path := grid.get_id_path(pair[0], pair[1])
			result.all_routes_reachable = result.all_routes_reachable and not path.is_empty()
			for cell in path:
				result.paths_avoid_solids = result.paths_avoid_solids and not grid.is_point_solid(cell)
			result.routes.append({"from": str(pair[0]), "to": str(pair[1]), "faction": team, "points": path.size()})
	var probe = battle.spawn_at("liang_dao", 0, layout.DOCK)
	probe.set_physics_process(false)
	battle._grid_build()
	battle._set_selection([probe])
	result.walk_dock_to_gate = await _walk_probe(battle, probe, map.cell_to_world(layout.GATE))
	await create_timer(0.3).timeout
	result.gate_fades = battle.map.sample_scenery._entrance._gate_parts[0].modulate.a < 0.6
	result.select_in_gate = battle._friendly_at(battle.to_screen(probe.position)) == probe
	battle.camera.position = battle.to_screen(map.cell_to_world(Vector2i(17, 38)))
	battle.camera.zoom = Vector2.ONE * 1.1
	battle.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("gate_passage.png"))
	result.walk_gate_to_hall = await _walk_probe(battle, probe, map.cell_to_world(layout.HALL_APPROACH))
	result.walk_hall_to_dock = await _walk_probe(battle, probe, map.cell_to_world(layout.DOCK))
	await create_timer(0.3).timeout
	result.gate_restores = is_equal_approx(battle.map.sample_scenery._entrance._gate_parts[0].modulate.a, 1.0)
	# 实际绕行陡边，不能只凭AStar返回路径就认定人物不穿岩壁。
	probe.position = map.cell_to_world(Vector2i(13, 42))
	battle._grid_build()
	result.walk_around_bank = await _walk_probe(battle, probe, map.cell_to_world(Vector2i(13, 38)))
	probe.position = map.cell_to_world(Vector2i(25,31))
	battle._grid_build()
	result.walk_east_gate = await _walk_probe(battle,probe,map.cell_to_world(layout.EAST_GATE))
	await create_timer(0.3).timeout
	result.east_gate_fades = battle.map.sample_scenery._entrance._side_gate_parts[0].modulate.a<0.6
	result.select_east_gate = battle._friendly_at(battle.to_screen(probe.position))==probe
	battle.camera.position = battle.to_screen(map.cell_to_world(layout.EAST_GATE))
	battle.camera.zoom = Vector2.ONE * 1.1
	battle.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("east_gate_passage.png"))
	result.walk_east_to_hall = await _walk_probe(battle,probe,map.cell_to_world(layout.HALL_APPROACH))
	await create_timer(0.3).timeout
	result.east_gate_restores = is_equal_approx(battle.map.sample_scenery._entrance._side_gate_parts[0].modulate.a,1.0)
	result.passed = result.all_routes_reachable and result.paths_avoid_solids and result.banks_block_both_factions \
		and result.walk_dock_to_gate and result.walk_gate_to_hall and result.walk_hall_to_dock \
		and result.gate_fades and result.select_in_gate and result.gate_restores and result.walk_around_bank
	result.passed = result.passed and result.walk_east_gate and result.walk_east_to_hall and result.east_gate_fades and result.select_east_gate and result.east_gate_restores
	# 绕墙探针离开屋面范围，避免干扰下一项独立遮挡检查。
	probe.position = map.cell_to_world(layout.DOCK)
	battle._grid_build()
	var file := FileAccess.open(out_dir.path_join("layout_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("[layout_verify] ", JSON.stringify(result))
	return result.passed


func _verify_gate_roof(battle, out_dir: String) -> bool:
	# 真实士兵位于旧门洞检测范围以外，检查扩大的屋顶遮挡和点选。
	var entrance = battle.map.sample_scenery._entrance
	var roof = entrance._gate_parts[-1]
	var east_roof = entrance._side_gate_parts[-1]
	# Force a real draw for both lintels before reading route state. This catches a
	# missing cached mesh instead of merely accepting the old immediate fallback.
	for lintel in [roof, east_roof]:
		lintel.queue_redraw()
	battle.camera.position = battle.to_screen(roof.position)
	battle.camera.zoom = Vector2.ONE * 1.1
	battle.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	battle.camera.position = battle.to_screen(east_roof.position)
	battle.camera.zoom = Vector2.ONE * 1.1
	battle.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var roof_mesh_routes: Array = []
	var mesh_routes_ready := true
	for lintel in [roof, east_roof]:
		var summary: Dictionary = lintel.roof_batch_summary()
		var mesh_ok := bool(summary.get("lintel", false)) and bool(summary.get("enabled", false)) \
			and bool(summary.get("ready", false)) and String(summary.get("last_roof_route", "")) == "mesh" \
			and int(summary.get("faces", 0)) == 2 and int(summary.get("draw_submissions", 0)) == 4 \
			and int(summary.get("tile_count", 0)) == 336
		summary["mesh_route_ok"] = mesh_ok
		roof_mesh_routes.append(summary)
		mesh_routes_ready = mesh_routes_ready and mesh_ok
	var origin: Vector2 = battle.to_screen(roof.position)
	var candidates: Array[Vector2] = []
	for y in range(140,158):
		for x in range(48,78):
			var p := Vector2(x,y)*8.0+Vector2(4,4)
			var cell: Vector2i = battle.map.world_to_cell(p)
			if battle.map.astar.is_point_solid(cell):
				continue
			var foot: Vector2 = battle.to_screen(p)-origin
			if roof.occludes_body(Rect2(foot+Vector2(-12,-38),Vector2(24,40))):
				candidates.append(p)
	var result := {"behind_main_gate": true, "candidate_count": candidates.size(), "checks": [],
		"gate_roof_mesh_mode": OS.get_environment("CAMPAIGN_GATE_ROOF_MESH"),
		"roof_mesh_routes": roof_mesh_routes, "mesh_routes_ready": mesh_routes_ready, "passed": false}
	if not candidates.is_empty():
		var probe = battle.spawn_unit("liang_dao",0,candidates[0])
		probe.set_physics_process(false)
		battle._set_selection([probe])
		var passed := true
		for index in [0,candidates.size()/2,candidates.size()-1]:
			probe.position = candidates[int(index)]
			battle._grid_build()
			await create_timer(0.3).timeout
			var faded: bool = roof.modulate.a < 0.6
			var picked: bool = battle._friendly_at(battle.to_screen(probe.position)) == probe
			result.checks.append({"position":str(probe.position),"faded":faded,"selected":picked})
			passed = passed and faded and picked
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("roof_occlusion.png"))
		# 此入口停掉战斗process，无法依赖常规单位清理；保留有效实例并移开。
		probe.position = battle.map.cell_to_world(Vector2i(30,31))
		battle._set_selection([])
		battle._grid_build()
		await create_timer(0.3).timeout
		result.restored = is_equal_approx(roof.modulate.a,1.0)
		result.passed = passed and result.restored and mesh_routes_ready
	var file := FileAccess.open(out_dir.path_join("roof_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("[roof_verify] ",JSON.stringify(result))
	return result.passed


func _verify_stockade(battle,out_dir: String) -> bool:
	var walls = battle.map.sample_scenery._entrance._wall_parts
	var probe = battle.spawn_at("liang_dao",0,Vector2i(13,39))
	probe.set_physics_process(false)
	battle._set_selection([probe])
	battle._grid_build()
	await create_timer(0.3).timeout
	var faded := 0
	for wall in walls:
		if wall.modulate.a < 0.6:
			faded += 1
	var selected: bool = battle._friendly_at(battle.to_screen(probe.position)) == probe
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("wall_occlusion.png"))
	probe.position = battle.map.cell_to_world(Vector2i(30,32))
	battle._set_selection([])
	battle._grid_build()
	await create_timer(0.3).timeout
	var remaining := 0
	for wall in walls:
		if wall.modulate.a < 0.6:
			remaining += 1
	var result := {"wall_segments":walls.size(),"faded_segments":faded,"selected":selected,
		"restored":remaining==0,"passed":walls.size()>0 and faded>0 and selected and remaining==0}
	var file := FileAccess.open(out_dir.path_join("wall_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("[wall_verify] ",JSON.stringify(result))
	return result.passed


func _walk_probe(battle, probe, destination: Vector2) -> bool:
	probe.order_move(destination)
	probe.set_physics_process(true)
	var start_ms := Time.get_ticks_msec()
	var crossed_solid := false
	while probe.position.distance_to(destination) > 6.0 and Time.get_ticks_msec() - start_ms < 20000:
		await physics_frame
		battle._grid_build()
		crossed_solid = crossed_solid or battle.map.astar.is_point_solid(battle.map.world_to_cell(probe.position))
	probe.set_physics_process(false)
	return probe.position.distance_to(destination) <= 6.0 and not crossed_solid


func _measure_coast(battle, out_dir: String) -> void:
	# 同一静态镜头、无PNG保存的轻量比较；不是兵海或完整关卡性能验收。
	var coast_material = battle.map.material
	battle.camera.position = battle.to_screen(battle.map.cell_to_world(Vector2i(17, 38)))
	battle.camera.zoom = Vector2.ONE * 1.1
	battle.camera.force_update_scroll()
	var rows: Array = []
	for enabled in [true, false, true]:
		coast_material.set_shader_parameter("coast_enabled", enabled)
		await create_timer(2.0).timeout
		var start := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - start < 3000000:
			await process_frame
			frames += 1
		var seconds := float(Time.get_ticks_usec() - start) / 1000000.0
		rows.append({"coast_enabled": enabled, "frames": frames, "seconds": seconds, "fps": frames / seconds})
	coast_material.set_shader_parameter("coast_enabled", true)
	var file := FileAccess.open(out_dir.path_join("coast_frame_check.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"capped_at_fps": 60, "static_camera_only": true, "height_kept_enabled": battle.map.height_field != null, "samples": rows}, "\t"))
	file.close()
	print("[coast_frames] ", JSON.stringify(rows))
	var landscape_rows: Array = []
	for view in [{"name":"back_hills","cell":Vector2i(16,20),"zoom":1.05},
		{"name":"landscape","cell":Vector2i(29,29),"zoom":0.60}]:
		battle.camera.position = battle.to_screen(battle.map.cell_to_world(view.cell))
		battle.camera.zoom = Vector2.ONE*float(view.zoom)
		battle.camera.force_update_scroll()
		await create_timer(2.0).timeout
		var start := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec()-start<3000000:
			await process_frame
			frames+=1
		var seconds := float(Time.get_ticks_usec()-start)/1000000.0
		landscape_rows.append({"view":view.name,"fps":frames/seconds,"seconds":seconds,
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	file = FileAccess.open(out_dir.path_join("landscape_frame_check.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"static_only":true,"capped_at_fps":60,"samples":landscape_rows},"\t"))
	file.close()
	print("[landscape_frames] ",JSON.stringify(landscape_rows))


func _verify_height(battle, out_dir: String) -> bool:
	var map = battle.map
	var result := {"roundtrip_samples": 0, "max_roundtrip_error": 0.0,
		"min_projection_derivative": 1.0, "height_order": false,
		"max_render_anchor_error": 0.0, "walk_up_down": true, "select_on_slope": true}
	# 密集覆盖坡面及平地；检查投影没有折叠，逆投影回到原点。
	for y in range(240):
		for x in range(240):
			var p := Vector2(x, y) * 8.0 + Vector2(3.2, 5.6)
			var screen: Vector2 = battle.to_screen(p)
			var restored: Vector2 = battle.to_logic(screen)
			result.max_roundtrip_error = maxf(result.max_roundtrip_error, p.distance_to(restored))
			var derivative: float = battle.to_screen(p + Vector2.ONE).y - screen.y
			result.min_projection_derivative = minf(result.min_projection_derivative, derivative)
			result.roundtrip_samples += 1
	var dock: float = map.height_at(map.cell_to_world(Vector2i(16, 49)))
	var gate: float = map.height_at(map.cell_to_world(Vector2i(16, 40)))
	var hall: float = map.height_at(map.cell_to_world(Vector2i(16, 30)))
	result.heights = {"dock": dock, "gate": gate, "hall": hall}
	result.height_order = is_equal_approx(hall,gate) and gate>dock and dock==0.0
	var court_low := INF
	var court_high := -INF
	for y in range(28,41):
		for x in range(11,23):
			var h: float = map.height_at(map.cell_to_world(Vector2i(x,y)))
			court_low = minf(court_low,h)
			court_high = maxf(court_high,h)
	result.courtyard_height_range = [court_low,court_high]
	result.courtyard_flat = absf(court_high-court_low)<0.01
	result.outer_approach_rises = true
	var last_height := -1.0
	var approach: Array = []
	for y in [49,47,45,43,41,40]:
		var h: float = map.height_at(map.cell_to_world(Vector2i(16,y)))
		result.outer_approach_rises = result.outer_approach_rises and h>=last_height
		last_height = h
		approach.append({"y":y,"height":h})
	result.outer_approach = approach
	var probe = battle.spawn_at("liang_dao", 0, Vector2i(16, 44))
	probe.set_physics_process(false)
	battle._set_selection([probe])
	var stations: Array = []
	for cell in [Vector2i(16, 40), Vector2i(16, 34), Vector2i(16, 44)]:
		var destination: Vector2 = map.cell_to_world(cell)
		probe.order_move(destination)
		probe.set_physics_process(true)
		var start := Time.get_ticks_msec()
		while probe.position.distance_to(destination) > 6.0 and Time.get_ticks_msec() - start < 20000:
			await process_frame
			battle._grid_build()
			await RenderingServer.frame_post_draw
			var expected: float = map.height_at(probe.position)
			var actual: float = probe.get_meta("render_height", 0.0)
			result.max_render_anchor_error = maxf(result.max_render_anchor_error, absf(expected - actual))
		probe.set_physics_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		var reached: bool = probe.position.distance_to(destination) <= 6.0
		var picked: bool = battle._friendly_at(battle.to_screen(probe.position)) == probe
		result.walk_up_down = result.walk_up_down and reached
		result.select_on_slope = result.select_on_slope and picked
		stations.append({"cell": str(cell), "height": map.height_at(probe.position), "reached": reached, "selected": picked})
		if cell == Vector2i(16, 34):
			battle.camera.position = battle.to_screen(map.cell_to_world(Vector2i(17, 36)))
			battle.camera.zoom = Vector2.ONE * 1.25
			battle.camera.force_update_scroll()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir.path_join("uphill_unit.png"))
	result.stations = stations
	# 使用真实特效类检查跨坡端点，而非只测试辅助函数。
	var script = load("res://scripts/battle.gd")
	var arrow = script.HuaTargetArrowFx.new()
	arrow.position = map.cell_to_world(Vector2i(16, 44))
	arrow.end_w = map.cell_to_world(Vector2i(16, 34))
	battle.fx_root.add_child(arrow)
	arrow.set_process(false)
	var expected_end: Vector2 = battle.to_screen(arrow.end_w) - battle.to_screen(arrow.position)
	result.projectile_endpoint_error = expected_end.distance_to(arrow._E)
	arrow.t = arrow.dur - arrow.travel * 0.5
	arrow.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("uphill_arrow.png"))
	arrow.queue_free()
	result.passed = result.max_roundtrip_error < 0.01 and result.min_projection_derivative > 0.1 \
		and result.height_order and result.courtyard_flat and result.outer_approach_rises and result.walk_up_down and result.select_on_slope \
		and result.max_render_anchor_error < 0.01 and result.projectile_endpoint_error < 0.01
	var file := FileAccess.open(out_dir.path_join("height_checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("[height_verify] ", JSON.stringify(result))
	return result.passed


func _verify_environment(battle, out_dir: String) -> bool:
	var map = battle.map
	var landscape = load("res://scripts/liangshan_environment.gd")
	var result := {"water_is_level":true,"boats_on_water":true,"tents_on_dry_ground":true,
		"ridges_block_both_sides":true,"no_third_land_route":true,"cut_routes":[],
		"back_hill_walk":true,"hill_select":true,"hill_render_anchor_error":0.0}
	var max_water_height := 0.0
	for y in range(map.h):
		for x in range(map.w):
			if map.t_at(x,y)==0:
				max_water_height = maxf(max_water_height,map.height_at(map.cell_to_world(Vector2i(x,y))))
	result.max_water_height = max_water_height
	result.water_is_level = max_water_height<0.01
	for d in map.decor:
		if d[0]=="boat":
			result.boats_on_water = result.boats_on_water and map.t_at(d[1].x,d[1].y)==0
		elif d[0]=="tent":
			result.tents_on_dry_ground = result.tents_on_dry_ground and map.t_at(d[1].x,d[1].y) in [1,4,5]
	for cell in landscape.ridge_cells():
		result.ridges_block_both_sides = result.ridges_block_both_sides and map.astar.is_point_solid(cell) and map.astar_guan.is_point_solid(cell)
	# 在独立AStar副本封掉东港两处堤道，应再无绕苇滩进入山寨的第三条陆路。
	for faction in range(2):
		var nav := AStarGrid2D.new()
		nav.region = Rect2i(0,0,map.w,map.h)
		nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		nav.update()
		var original: AStarGrid2D = map.astar if faction==0 else map.astar_guan
		for y in range(map.h):
			for x in range(map.w):
				var cell := Vector2i(x,y)
				if original.is_point_solid(cell) or (x>=39 and x<=42 and map.t_at(x,y)==5):
					nav.set_point_solid(cell,true)
		for source in [Vector2i(57,22),Vector2i(57,46)]:
			var route := nav.get_id_path(source,Vector2i(20,30))
			result.no_third_land_route = result.no_third_land_route and route.is_empty()
			result.cut_routes.append({"faction":faction,"source":str(source),"points":route.size()})
	# 新增林间山路真实行走与坡上点选；不只核验路径数组。
	var probe = battle.spawn_at("liang_dao",0,Vector2i(25,26))
	probe.set_physics_process(false)
	battle._set_selection([probe])
	var stations: Array = []
	for cell in [Vector2i(23,22),Vector2i(19,17),Vector2i(21,11)]:
		var reached := await _walk_probe(battle,probe,map.cell_to_world(cell))
		await process_frame
		await RenderingServer.frame_post_draw
		var selected: bool = battle._friendly_at(battle.to_screen(probe.position))==probe
		var expected: float = map.height_at(probe.position)
		var actual: float = probe.get_meta("render_height",0.0)
		result.back_hill_walk = result.back_hill_walk and reached
		result.hill_select = result.hill_select and selected
		result.hill_render_anchor_error = maxf(result.hill_render_anchor_error,absf(actual-expected))
		stations.append({"cell":str(cell),"reached":reached,"selected":selected,"height":expected})
	result.hill_stations = stations
	battle.camera.position = battle.to_screen(map.cell_to_world(Vector2i(19,16)))
	battle.camera.zoom = Vector2.ONE*1.3
	battle.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("hill_passage.png"))
	probe.position = map.cell_to_world(Vector2i(30,34))
	battle._set_selection([])
	battle._grid_build()
	result.passed = result.water_is_level and result.boats_on_water and result.tents_on_dry_ground \
		and result.ridges_block_both_sides and result.no_third_land_route and result.back_hill_walk \
		and result.hill_select and result.hill_render_anchor_error<0.01
	var file := FileAccess.open(out_dir.path_join("environment_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("[environment_verify] ",JSON.stringify(result))
	return result.passed
