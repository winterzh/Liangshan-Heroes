extends SceneTree
## Vulkan capture driven by the frozen exported executable.  No native UI or
## desktop pixels are sampled; both PNGs come from the game's root viewport.

const VIEW := Vector2i(1280, 720)
const FROZEN_EXE_SHA256 := "f7e7fdabbf3869e56a6b5b0d1869069e89122ccb8dc4c2e091ed16b188e0bcf3"
var output_dir := ""
var captures: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[package-visual] " + message)


func _sample_metrics(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {}
	var count := 0
	var black := 0
	var luminance := 0.0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var color := image.get_pixel(x, y)
			var light := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			luminance += light
			if light < 0.02:
				black += 1
			count += 1
	return {
		"samples": count,
		"mean_luminance": luminance / maxf(1.0, float(count)),
		"near_black_ratio": float(black) / maxf(1.0, float(count)),
	}


func _capture(name: String) -> void:
	for unused in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output_dir.path_join(name + ".png")
	var error := image.save_png(path) if image != null else ERR_CANT_CREATE
	var row := {
		"name": name,
		"path": path.replace("\\", "/"),
		"save_error": error,
		"size": [image.get_width(), image.get_height()] if image != null else [],
		"metrics": _sample_metrics(image),
		"sha256": FileAccess.get_sha256(path) if error == OK else "",
	}
	captures.append(row)
	print("PACKAGE_VISUAL_CAPTURE ", JSON.stringify(row))
	if error != OK or image == null or image.get_size() != VIEW:
		_fail("invalid capture " + name)


func _free_scene(scene) -> void:
	if scene != null and is_instance_valid(scene):
		if current_scene == scene:
			current_scene = null
		scene.queue_free()
	for unused in range(3):
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("real renderer required; headless display server was selected")
		_finish()
		return
	output_dir = OS.get_environment("PACKAGE_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = OS.get_user_data_dir().path_join("package_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var mounted_pack := OS.get_environment("PACKAGE_MOUNTED_PACK").replace("\\", "/")
	var mounted_sha := FileAccess.get_sha256(mounted_pack) if not mounted_pack.is_empty() else ""
	if not mounted_pack.to_lower().ends_with("/liangshanheroes.exe") \
			or mounted_sha != FROZEN_EXE_SHA256:
		_fail("mounted package path/hash does not match the frozen exported EXE")
	root.size = VIEW
	root.content_scale_size = VIEW
	AudioServer.set_bus_mute(0, true)
	var settings := root.get_node_or_null("Settings")
	if settings != null:
		settings.edge_scroll = false
		settings.auto_micro_level = 0
		settings.game_speed = 1.0

	var menu_scene = load("res://scenes/menu.tscn")
	if menu_scene == null:
		_fail("packaged menu scene missing")
	else:
		var menu = menu_scene.instantiate()
		root.add_child(menu)
		current_scene = menu
		await _capture("package_main_menu_1280x720")
		await _free_scene(menu)

	var campaign := root.get_node_or_null("Campaign")
	if campaign == null:
		_fail("Campaign autoload missing")
	else:
		for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense",
				"scale_on", "ai_friendly"]:
			campaign.set(mode, false)
		campaign.skirmish = true
		campaign.defense_waves = 1
		campaign.defense_random = false
		var battle_scene = load("res://scenes/main.tscn")
		if battle_scene == null:
			_fail("packaged battle scene missing")
		else:
			var battle = battle_scene.instantiate()
			root.add_child(battle)
			current_scene = battle
			for unused in range(5):
				await process_frame
			if battle.hud != null and battle.hud._intro_root != null:
				battle.hud._intro_root.visible = false
			if battle.has_method("_on_intro_done"):
				battle._on_intro_done()
			for unused in range(30):
				await process_frame
			await _capture("package_liangshan_defense_1280x720")
			await _free_scene(battle)

	_finish()


func _finish() -> void:
	var report_path := output_dir.path_join("package_visual_capture.json") if not output_dir.is_empty() \
		else OS.get_user_data_dir().path_join("package_visual_capture.json")
	var report := {
		"kind": "steam_test_export_internal_viewport_capture",
		"schema": 1,
		"passed": failures.is_empty() and captures.size() == 2,
		"execution_scope": "Godot console mounts the frozen LiangshanHeroes.exe with --main-pack; screenshots are root viewport pixels from that embedded PCK, not native desktop capture.",
		"runner_executable": OS.get_executable_path().replace("\\", "/"),
		"mounted_pack": OS.get_environment("PACKAGE_MOUNTED_PACK").replace("\\", "/"),
		"mounted_pack_sha256": FileAccess.get_sha256(OS.get_environment("PACKAGE_MOUNTED_PACK")),
		"display_server": DisplayServer.get_name(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"viewport": [VIEW.x, VIEW.y],
		"captures": captures,
		"failures": failures,
		"human_visual_review": false,
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	var wrote := file != null
	if wrote:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("PACKAGE_VISUAL_CAPTURE_RESULT ", JSON.stringify({
		"passed": report.passed, "captures": captures.size(),
		"failures": failures.size(), "report": report_path,
		"report_written": wrote,
	}))
	for unused in range(3):
		await process_frame
	quit(0 if wrote and bool(report.passed) else 1)
