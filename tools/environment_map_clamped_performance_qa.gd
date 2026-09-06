extends "res://tools/campaign_mode_performance_test.gd"
## Isolates the incremental cost of routed 2048px map-clamped surfaces from the
## existing atlas fallback in the same frozen scene. Three paired, reversed-
## order windows reduce one-off scheduler/texture-residency noise. This remains
## static-render evidence, not a battle soak or player test.
const LEVELS := ["level1","level2","level3","level4","level5","level6","level7","level8"]
const CAPTURE_CELLS := {
	"level1":Vector2i(22,20), "level2":Vector2i(27,23),
	"level3":Vector2i(19,28), "level4":Vector2i(20,40),
	"level5":Vector2i(17,38), "level6":Vector2i(27,20),
	"level7":Vector2i(35,19), "level8":Vector2i(35,16),
}
const WEB_FLAGS := ["use_surface_forest_texture","use_surface_dry_texture",
	"use_surface_wet_texture","use_surface_hard_texture","use_surface_field_texture"]
const SAMPLE_USEC := 1000000


func _set_web(material: ShaderMaterial, routed: Dictionary, enabled: bool) -> void:
	for flag in WEB_FLAGS:
		material.set_shader_parameter(flag, enabled and bool(routed.get(flag,false)))
	await RenderingServer.frame_post_draw


func _window(label: String) -> Dictionary:
	for i in range(30):
		await RenderingServer.frame_post_draw
	var intervals: Array[float] = []
	var previous := Time.get_ticks_usec()
	var start := previous
	while Time.get_ticks_usec()-start<SAMPLE_USEC:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now-previous)/1000.0)
		previous=now
	intervals.sort()
	return {"label":label,"frames":intervals.size(),
		"average_frame_ms":intervals.reduce(func(a,v): return a+v,0.0)/intervals.size(),
		"p95_frame_ms":intervals[mini(intervals.size()-1,int(ceil(intervals.size()*0.95))-1)],
		"p99_frame_ms":intervals[mini(intervals.size()-1,int(ceil(intervals.size()*0.99))-1)],
		"worst_frame_ms":intervals.back()}


func _median(values: Array[float]) -> float:
	values.sort()
	return values[int(values.size()/2)]


func _sample_level(id: String) -> Dictionary:
	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN","1")
	var b=await _start(id)
	b.set_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	b.camera.position=b.to_screen(b.map.cell_to_world(CAPTURE_CELLS[id]))
	b.camera.zoom=Vector2.ONE
	b.camera.force_update_scroll()
	var material := b.map.material as ShaderMaterial
	var routed := {}
	for flag in WEB_FLAGS: routed[flag]=bool(material.get_shader_parameter(flag))
	# Load and sample every routed texture before any timed window.
	await _set_web(material,routed,true)
	for i in range(120): await RenderingServer.frame_post_draw
	var atlas_windows := []
	var web_windows := []
	for round_index in range(3):
		var web_first := round_index==1
		for use_web in ([true,false] if web_first else [false,true]):
			await _set_web(material,routed,use_web)
			var sample := await _window("web" if use_web else "atlas")
			if use_web: web_windows.append(sample)
			else: atlas_windows.append(sample)
	var atlas_p95: Array[float] = []
	var atlas_p99: Array[float] = []
	var web_p95: Array[float] = []
	var web_p99: Array[float] = []
	for sample in atlas_windows:
		atlas_p95.append(float(sample.p95_frame_ms)); atlas_p99.append(float(sample.p99_frame_ms))
	for sample in web_windows:
		web_p95.append(float(sample.p95_frame_ms)); web_p99.append(float(sample.p99_frame_ms))
	var median_atlas_p95 := _median(atlas_p95)
	var median_web_p95 := _median(web_p95)
	var median_web_p99 := _median(web_p99)
	var individual_absolute_passes: int = int(web_windows.reduce(func(total,sample):
		return total+int(float(sample.p95_frame_ms)<=P95_FRAME_MS_LIMIT
			and float(sample.p99_frame_ms)<=P99_FRAME_MS_LIMIT),0))
	check(median_web_p95<=P95_FRAME_MS_LIMIT,id+" median Web P95 <= 16.7 ms")
	check(median_web_p99<=P99_FRAME_MS_LIMIT,id+" median Web P99 <= 33.3 ms")
	check(median_web_p95<=maxf(median_atlas_p95*P95_REGRESSION_LIMIT,median_atlas_p95+0.35),
		id+" median Web P95 regresses no more than ten percent vs same-scene atlas fallback")
	check(individual_absolute_passes>=2,id+" at least two of three Web windows pass both absolute gates")
	var result := {"level":id,"camera_cell":str(CAPTURE_CELLS[id]),
		"routed_flags":routed,"atlas_windows":atlas_windows,"web_windows":web_windows,
		"median_atlas_p95_frame_ms":median_atlas_p95,
		"median_atlas_p99_frame_ms":_median(atlas_p99),
		"median_web_p95_frame_ms":median_web_p95,
		"median_web_p99_frame_ms":median_web_p99,
		"web_absolute_pass_windows":individual_absolute_passes}
	await _dispose(b)
	return result


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		print("[map-clamped-performance] real renderer required")
		quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	output=OS.get_environment("MAP_CLAMPED_PERFORMANCE_OUT")
	if output.is_empty(): output=ProjectSettings.globalize_path("res://qa/environment_map_clamped_20260902/performance")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var settings=root.get_node("Settings")
	settings.edge_scroll=false; settings.auto_micro_level=0; settings.game_speed=1.0
	AudioServer.set_bus_mute(0,true)
	report["scope"]="three paired one-second static windows per mode and level; same scene/material, prewarmed routed textures, reversed middle order; no combat soak or player claim"
	report["renderer"]={"adapter":RenderingServer.get_video_adapter_name(),
		"api":RenderingServer.get_video_adapter_api_version(),
		"method":RenderingServer.get_current_rendering_method(),"viewport":str(root.size)}
	report["thresholds"]={"p95_ms":P95_FRAME_MS_LIMIT,"p99_ms":P99_FRAME_MS_LIMIT,
		"p95_regression_ratio":P95_REGRESSION_LIMIT,"minimum_individual_absolute_passes":2}
	var selected_levels: Array[String] = []
	var requested := OS.get_environment("MAP_CLAMPED_PERFORMANCE_LEVELS").strip_edges()
	if requested.is_empty():
		selected_levels.assign(LEVELS)
	else:
		for id in requested.split(",",false):
			var normalized := id.strip_edges()
			if normalized in LEVELS and normalized not in selected_levels:
				selected_levels.append(normalized)
	if selected_levels.is_empty():
		print("[map-clamped-performance] no valid level selected")
		quit(2); return
	report["selected_levels"]=selected_levels
	report["samples"]=[]
	for id in selected_levels: report.samples.append(await _sample_level(id))
	report["expected_check_count"]=selected_levels.size()*4
	report["passed"]=failures.is_empty()
	report["failures"]=failures
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("[map-clamped-performance-result] ",JSON.stringify({"passed":failures.is_empty(),
		"checks":report.mode_checks.size(),"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
