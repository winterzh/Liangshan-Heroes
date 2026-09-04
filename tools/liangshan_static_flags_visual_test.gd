extends SceneTree
## 1280x720 real-scene visual evidence for the Level 5 fixed standards.
## The fixture keeps the authored map/scenery renderer and only hides gameplay HUD.

var checks: Array = []
var failures: Array[String] = []
var captures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail := "") -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[liangshan-static-flags-visual] ", "PASS " if passed else "FAIL ", name, " ", detail)
	if not passed:
		failures.append(name)


func _label(text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(1280, 62)
	panel.color = Color(0.05, 0.07, 0.09, 0.90)
	layer.add_child(panel)
	var title := Label.new()
	title.text = text
	title.position = Vector2(20, 12)
	title.size = Vector2(1240, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f2dfb0"))
	layer.add_child(title)
	return layer


func _save(output_dir: String, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(name)
	var error := root.get_texture().get_image().save_png(path)
	_check(name + "_written", error == OK and FileAccess.file_exists(path), path)
	if error == OK and FileAccess.file_exists(path):
		captures.append({"png": path, "sha256": FileAccess.get_sha256(path)})


func _stop_audio() -> void:
	for autoload_name in ["Sfx", "Music"]:
		var audio_root = root.get_node_or_null(autoload_name)
		if audio_root == null:
			continue
		audio_root.set("enabled", false)
		for child in audio_root.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null


func _run() -> void:
	var output_dir := OS.get_environment("LIANGSHAN_STATIC_FLAGS_VISUAL_OUT")
	if output_dir.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	_stop_audio()
	var campaign = root.get_node_or_null("Campaign")
	_check("campaign_autoload_available", campaign != null)
	if campaign == null:
		quit(5)
		return
	for key in ["arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]:
		campaign.set(key, false)
	campaign.current = campaign.index_for_id("level5")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	await process_frame
	battle.hud.hide()
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	for unit in battle.units:
		unit.set_process(false)
		unit.set_physics_process(false)
	var scenery = battle.map.sample_scenery
	_check("level5_scenery_exists", scenery != null)
	var markers: Dictionary = {}
	if scenery != null:
		for child in scenery.get_children():
			if child.has_method("static_marker"):
				var marker := String(child.static_marker())
				if not marker.is_empty():
					markers[marker] = int(markers.get(marker, 0)) + 1
	for marker in ["liangshan_hilltop_standard", "zhongyi_hall_standard_west", "zhongyi_hall_standard_east"]:
		_check(marker + "_visible_renderer_node", int(markers.get(marker, 0)) == 1, JSON.stringify(markers))
	var views := [
		{"name": "zhongyi_hall_flags_1280.png", "cell": Vector2i(16, 32), "zoom": 1.65,
			"title": "忠义堂前绣字红旗：山东呼保义 · 河北玉麒麟"},
		{"name": "liangshan_hilltop_standard_1280.png", "cell": Vector2i(10, 15), "zoom": 1.85,
			"title": "梁山山顶杏黄旗：替天行道"},
	]
	for view in views:
		battle.camera.position = battle.to_screen(battle.map.cell_to_world(view.cell))
		battle.camera.zoom = Vector2.ONE * float(view.zoom)
		battle.camera.force_update_scroll()
		var layer := _label(String(view.title))
		await create_timer(0.35).timeout
		await _save(output_dir, String(view.name))
		layer.queue_free()
		await process_frame
	var report_path := output_dir.path_join("report.json")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	_check("report_opened", report != null, report_path)
	if report != null:
		report.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks,
			"captures": captures, "markers": markers, "viewport": [1280, 720],
			"scope": "Real Level 5 static-scenery rendering of the three Chapter 71 standards. It does not prove campaign completion, combat balance, performance, or human playtesting."}, "\t") + "\n")
		report.close()
	_stop_audio()
	battle.queue_free()
	await process_frame
	print("[liangshan-static-flags-visual-result] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 5)
