extends SceneTree
## Open the unchanged configured main scene and retain a real viewport.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := OS.get_environment("LSH_WORKSTATION_OUTPUT")
	if output.is_empty():
		push_error("LSH_WORKSTATION_OUTPUT is required")
		quit(2)
		return
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	var error := change_scene_to_file(main_scene)
	if error != OK:
		push_error("Configured main scene failed: %s" % error)
		quit(2)
		return
	for frame in range(180):
		await process_frame
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()
	var screenshot_error := viewport_image.save_png(output.path_join("menu.png"))
	var report := {
		"schema": "workstation_startup_probe_v1",
		"passed": current_scene != null and current_scene.scene_file_path == main_scene
			and not viewport_image.is_empty() and screenshot_error == OK,
		"main_scene": main_scene,
		"actual_scene": current_scene.scene_file_path if current_scene != null else "",
		"frames": 180,
		"viewport_size": [viewport_image.get_width(), viewport_image.get_height()],
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"user_directory": OS.get_user_data_dir(),
		"engine": Engine.get_version_info(),
		"time_scale": Engine.time_scale,
		"pid": OS.get_process_id(),
	}
	var file := FileAccess.open(output.path_join("startup_report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Startup report write failed")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("WORKSTATION_STARTUP_PROBE ", JSON.stringify(report))
	quit(0 if report.passed else 2)
