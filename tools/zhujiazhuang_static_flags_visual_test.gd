extends SceneTree
## 1280x720 real Level 3 visual evidence for the Chapter 48 white standards.
## The fixture keeps the authored map and runtime overlay, hides only gameplay HUD,
## and does not modify or regenerate the underlying banner bitmap.

const MARKERS := ["zhujiazhuang_gate_chao_standard", "zhujiazhuang_gate_song_standard"]

var checks: Array = []
var failures: Array[String] = []
var captures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail := "") -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[zhujiazhuang-static-flags-visual] ", "PASS " if passed else "FAIL ", name, " ", detail)
	if not passed:
		failures.append(name)


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


func _label(text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2.ZERO
	panel.size = Vector2(1280, 58)
	panel.color = Color(0.05, 0.07, 0.09, 0.90)
	layer.add_child(panel)
	var title := Label.new()
	title.text = text
	title.position = Vector2(20, 10)
	title.size = Vector2(1240, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f2dfb0"))
	layer.add_child(title)
	return layer


func _save(output_dir: String, file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(file_name)
	var image := root.get_texture().get_image()
	var error := image.save_png(path) if image != null and image.get_size() == Vector2i(1280, 720) else ERR_CANT_CREATE
	_check(file_name + "_written_1280x720", error == OK and FileAccess.file_exists(path), path)
	if error == OK and FileAccess.file_exists(path):
		captures.append({"png": path, "sha256": FileAccess.get_sha256(path)})


func _run() -> void:
	var output_dir := OS.get_environment("ZHUJIAZHUANG_STATIC_FLAGS_VISUAL_OUT")
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
	campaign.current = campaign.index_for_id("level3")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	await process_frame
	_check("real_level3_loaded", battle.level != null and battle.level.id() == "level3")
	battle.hud.hide()
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	for unit in battle.units:
		unit.set_process(false)
		unit.set_physics_process(false)
	var scenery = battle.map.sample_scenery
	_check("level3_scenery_exists", scenery != null)
	var markers: Dictionary = {}
	if scenery != null:
		for child in scenery.get_children():
			if child.has_method("static_marker"):
				var marker := String(child.static_marker())
				if not marker.is_empty():
					markers[marker] = int(markers.get(marker, 0)) + 1
	for marker in MARKERS:
		_check(marker + "_visible_renderer_node", int(markers.get(marker, 0)) == 1, JSON.stringify(markers))
	var views := [
		{"name": "zhujiazhuang_white_flags_close_1280.png", "cell": Vector2i(12, 28), "zoom": 1.35,
			"title": "祝家庄白旗：填平水泊擒晁盖 · 踏破梁山捉宋江"},
		{"name": "zhujiazhuang_white_flags_gate_context_1280.png", "cell": Vector2i(17, 28), "zoom": 1.10,
			"title": "三打祝家庄：两面原著白旗的关卡落位"},
	]
	for view in views:
		battle.camera.position = battle.to_screen(battle.map.cell_to_world(view.cell))
		battle.camera.zoom = Vector2.ONE * float(view.zoom)
		battle.camera.offset = Vector2.ZERO
		battle.camera.force_update_scroll()
		var layer := _label(String(view.title))
		await create_timer(0.30).timeout
		await _save(output_dir, String(view.name))
		layer.queue_free()
		await process_frame
	var report_path := output_dir.path_join("report.json")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	_check("report_opened", report != null, report_path)
	if report != null:
		report.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks,
			"captures": captures, "markers": markers, "viewport": [1280, 720],
			"scope": "Real Level 3 static-scenery rendering of two Chapter 48 white standards; no campaign completion, combat, performance, or human playtest claim."}, "\t") + "\n")
		report.close()
	_stop_audio()
	battle.queue_free()
	await process_frame
	print("[zhujiazhuang-static-flags-visual-result] ", JSON.stringify({"passed": failures.is_empty(),
		"checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 5)
