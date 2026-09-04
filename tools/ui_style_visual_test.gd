extends SceneTree
## Unified UI visual evidence. Requires a graphical renderer and captures real 1280x720 pixels.

const VIEW := Vector2i(1280, 720)
const OUTPUT := "res://qa/ui_style_20260903"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI style visual QA requires a graphical renderer.")
		quit(2)
		return
	get_root().size = VIEW
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var results: Array[Dictionary] = []
	results.append(await _capture_scene("res://scenes/menu.tscn", "menu_1280x720.png"))
	results.append(await _capture_settings())
	results.append(await _capture_scene("res://scenes/codex.tscn", "codex_1280x720.png"))
	results.append(await _capture_scene("res://scenes/editor.tscn", "defense_editor_1280x720.png"))
	results.append(await _capture_scene("res://scenes/scenario_editor.tscn", "scenario_editor_1280x720.png"))
	var passed := true
	for result in results:
		passed = passed and bool(result.get("passed", false))
	var report := {
		"passed": passed,
		"viewport": [VIEW.x, VIEW.y],
		"captures": results,
		"scope": "Rendered desktop UI style evidence only; not gameplay, mobile-device, performance or player acceptance."
	}
	var report_path := ProjectSettings.globalize_path(OUTPUT.path_join("report.json"))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("[ui-style-visual] ", JSON.stringify(report))
	quit(0 if passed else 1)


func _capture_scene(path: String, filename: String) -> Dictionary:
	var packed := load(path) as PackedScene
	if packed == null:
		return {"file": filename, "passed": false, "error": "load_failed"}
	var scene := packed.instantiate()
	get_root().add_child(scene)
	await _settle()
	var result := _save(filename)
	scene.queue_free()
	await process_frame
	await process_frame
	return result


func _capture_settings() -> Dictionary:
	var packed := load("res://scenes/menu.tscn") as PackedScene
	var menu := packed.instantiate()
	get_root().add_child(menu)
	await _settle()
	var settings_script := load("res://scripts/settings_panel.gd") as Script
	var panel: Control = settings_script.new()
	menu.add_child(panel)
	await _settle()
	var result := _save("settings_1280x720.png")
	menu.queue_free()
	await process_frame
	await process_frame
	return result


func _settle() -> void:
	for _i in range(5):
		await process_frame
	await create_timer(0.08).timeout
	await process_frame


func _save(filename: String) -> Dictionary:
	var image := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT.path_join(filename))
	var error := image.save_png(path) if image != null else ERR_CANT_CREATE
	return {
		"file": filename,
		"passed": image != null and image.get_size() == VIEW and error == OK,
		"size": [image.get_width(), image.get_height()] if image != null else [0, 0],
		"save_error": error
	}
