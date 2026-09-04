extends "res://tools/campaign_mode_performance_test.gd"
## 同一已冻结场景、镜头和shader实例切换自然地表。八关固定机位截图供人工比较；
## 2秒静态帧时只用于发现明显回退，不代表交战或稳定60FPS。
const CAPTURE_CELLS := {
	"level1":Vector2i(22,20), "level2":Vector2i(27,23),
	"level3":Vector2i(19,28), "level4":Vector2i(20,40),
	"level5":Vector2i(17,38), "level6":Vector2i(27,20),
	"level7":Vector2i(35,19), "level8":Vector2i(35,16),
}


func _terrain_state(map) -> Dictionary:
	return {
		"grid": map.grid.to_byte_array().hex_encode().sha256_text(),
		"solid": map._base_solid.hex_encode().sha256_text(),
		"blocks": map._block_count.to_byte_array().hex_encode().sha256_text(),
		"height": map.height_field.samples.to_byte_array().hex_encode().sha256_text()
			if map.height_field != null else "flat",
	}


func _set_natural(map, enabled: bool) -> void:
	map.natural_surface_enabled = enabled
	if map.material is ShaderMaterial:
		map.material.set_shader_parameter("natural_surface_enabled", enabled)
	map.queue_redraw()


func _capture(b, label: String, zoom: float) -> Dictionary:
	b.camera.zoom = Vector2.ONE * zoom
	b.camera.force_update_scroll()
	for i in range(12):
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output.path_join(label + ".png")
	image.save_png(path)
	return {"path": path, "sha256": image.get_data().hex_encode().sha256_text(),
		"zoom": zoom, "width": image.get_width(), "height": image.get_height()}


func _timed_sample(label: String) -> Dictionary:
	var intervals: Array[float] = []
	var calls: Array[float] = []
	var previous := Time.get_ticks_usec()
	var start := previous
	while Time.get_ticks_usec() - start < 2000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	intervals.sort()
	return {
		"label": label,
		"frames": intervals.size(),
		"average_frame_ms": intervals.reduce(func(total, value): return total + value, 0.0) / intervals.size(),
		"p95_frame_ms": intervals[mini(intervals.size() - 1, int(ceil(intervals.size() * 0.95)) - 1)],
		"worst_frame_ms": intervals.back(),
		"mean_draw_calls": calls.reduce(func(total, value): return total + value, 0.0) / calls.size(),
	}


func _sample_level(id: String, cell: Vector2i) -> Dictionary:
	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN", "1")
	var b = await _start(id)
	b.set_process(false)
	b.camera.set_process(false)
	for u in b.units:
		u.set_physics_process(false)
	b.camera.position = b.to_screen(b.map.cell_to_world(cell))
	var before := _terrain_state(b.map)

	_set_natural(b.map, false)
	var off_100 := await _capture(b, id + "_off_100", 1.0)
	var off_150 := await _capture(b, id + "_off_150", 1.5)
	b.camera.zoom = Vector2.ONE
	var off_perf := await _timed_sample(id + "_off")

	_set_natural(b.map, true)
	var on_100 := await _capture(b, id + "_on_100", 1.0)
	var on_150 := await _capture(b, id + "_on_150", 1.5)
	b.camera.zoom = Vector2.ONE
	var on_perf := await _timed_sample(id + "_on")
	var after := _terrain_state(b.map)

	check(off_100.sha256 != on_100.sha256 and off_150.sha256 != on_150.sha256,
		id + " natural material changes real 100 and 150 percent composites")
	check([off_100,off_150,on_100,on_150].all(func(c): return c.width==1280 and c.height==720),
		id + " writes every fixed-camera comparison at exactly 1280x720")
	check(before == after, id + " live visual toggle leaves terrain, collision and height byte-identical")
	check(on_perf.p95_frame_ms <= maxf(off_perf.p95_frame_ms * 1.10, off_perf.p95_frame_ms + 0.35),
		id + " natural terrain static P95 regresses no more than ten percent")
	var result := {"level": id, "off_100": off_100, "off_150": off_150,
		"on_100": on_100, "on_150": on_150, "off_performance": off_perf,
		"on_performance": on_perf, "state": before, "camera_cell":str(cell),
		"viewport":"1280x720"}
	await _dispose(b)
	return result


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[natural-terrain-render] real renderer required")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	output = OS.get_environment("NATURAL_TERRAIN_RENDER_OUT")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://qa/natural_terrain_20260902/render")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	AudioServer.set_bus_mute(0, true)
	report["scope"] = "all eight campaigns in the same live scene and fixed camera, 1280x720 at 100/150 percent plus two-second static frame sample; not combat, full campaign or human visual approval"
	report["renderer"] = {"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"method": RenderingServer.get_current_rendering_method(), "viewport": str(root.size)}
	var selected_levels: Array[String] = []
	var requested := OS.get_environment("NATURAL_TERRAIN_RENDER_LEVELS").strip_edges()
	if requested.is_empty():
		for id in CAPTURE_CELLS: selected_levels.append(id)
	else:
		for id in requested.split(",",false):
			var normalized := id.strip_edges()
			if CAPTURE_CELLS.has(normalized) and normalized not in selected_levels:
				selected_levels.append(normalized)
	if selected_levels.is_empty():
		print("[natural-terrain-render] no valid level selected")
		quit(2)
		return
	report["selected_levels"] = selected_levels
	report["samples"] = []
	for id in selected_levels:
		report.samples.append(await _sample_level(id,CAPTURE_CELLS[id]))
	report["passed"] = failures.is_empty()
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[natural-terrain-render-result] ", JSON.stringify({"passed": failures.is_empty(),
		"checks": report.mode_checks.size(), "failures": failures, "output": output}))
	quit(0 if failures.is_empty() else 1)
