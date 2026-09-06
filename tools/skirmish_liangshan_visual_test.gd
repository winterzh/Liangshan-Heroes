extends SceneTree
## 驻守战梁山泊真实渲染取景。只改测试镜头与迷雾可见性，不注入战斗结果。

const VIEW_SIZE := Vector2i(1280, 720)
var output_dir := ""
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	if DisplayServer.get_name() == "headless":
		push_error("Skirmish Liangshan visual test requires a graphical renderer.")
		quit(2)
		return
	output_dir = OS.get_environment("SKIRMISH_LIANGSHAN_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/skirmish_liangshan_environment_20260904/visual_review")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.title = "梁山泊驻守战环境检查 · 1280×720"
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)

	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.skirmish = true
	seed(5088120)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud._on_start_pressed()
	battle._smoke = false
	await process_frame
	await process_frame
	# 正常开局后强制完成一次真实迷雾刷新，再检查直立环境物件没有穿出未探索黑区。
	battle._fog_t = 0.0
	battle._fog_pass(0.20)
	battle.map.sample_scenery._refresh_fog_visibility()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 1.0

	# 玩家开局镜头：保留战争迷雾，证明正常游玩看到的是厅堂和寨门。
	await _capture(battle, "01_player_start_fog", Vector2i(23, 35), 0.92, false)
	# 地貌总览与两个进攻节点：仅为视觉审查临时隐藏迷雾。
	await _capture(battle, "02_water_reeds_overview", Vector2i(24, 36), 0.62, true)
	await _capture(battle, "03_hall_three_passes", Vector2i(18, 36), 0.88, true)
	await _capture(battle, "04_beaches_and_docks", Vector2i(28, 43), 0.70, true)
	await _capture(battle, "05_mountain_road", Vector2i(18, 13), 0.72, true)
	await _capture(battle, "06_unexplored_fog_boundary", Vector2i(31, 18), 0.88, false)
	await _capture(battle, "07_east_mountain_pass", Vector2i(31, 32), 1.02, true)

	var art_id: String = String(battle.map.get_meta("liangshan_art_level_id", ""))
	var sample_ok: bool = battle.map.sample_scenery != null
	var hall_ok: bool = is_instance_valid(battle.level.hall) \
		and battle.level.hall.display_name == "忠义堂" \
		and bool(battle.level.hall.get_meta("campaign_environment_static_visual", false))
	var fog_scenery: Dictionary = battle.map.sample_scenery.fog_visibility_summary()
	var minimap_frame_mode: String = battle.hud.minimap.viewport_frame_mode()
	var east_parts: Array[Node2D] = battle.map.sample_scenery._entrance._side_gate_parts
	var east_hidden_before := not east_parts.is_empty() \
		and east_parts.all(func(part): return not part.visible)
	battle._reveal_fog_at(battle.map.cell_to_world(Vector2i(31,32)),260.0,3.0)
	battle._fog_t = 0.0
	battle._fog_pass(0.20)
	battle.map.sample_scenery._refresh_fog_visibility()
	var east_visible_after := not east_parts.is_empty() \
		and east_parts.all(func(part): return part.visible)
	var fog_reveal := {"east_gate_hidden_before_reveal":east_hidden_before,
		"east_gate_visible_after_reveal":east_visible_after}
	var report := {
		"passed": captures.size() == 7 and captures.all(func(c): return bool(c.saved)) \
			and art_id == "level5" and sample_ok and hall_ok \
			and bool(fog_scenery.fog_ready) and int(fog_scenery.visible_unexplored_scenery) == 0 \
			and east_hidden_before and east_visible_after \
			and minimap_frame_mode == "axis_aligned_rect",
		"viewport": [VIEW_SIZE.x, VIEW_SIZE.y],
		"renderer": RenderingServer.get_video_adapter_name(),
		"captures": captures,
		"liangshan_art_level_id": art_id,
		"sample_scenery": sample_ok,
		"hall_static_visual": hall_ok,
		"fog_scenery": fog_scenery,
		"fog_reveal": fog_reveal,
		"minimap_frame_mode": minimap_frame_mode,
		"capture_adjustments": ["camera only", "fog hidden only in captures 02-05 and 07", "simulation frozen after normal start"],
		"human_playtest": false,
		"performance_test": false,
	}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("[skirmish-liangshan-visual] ", JSON.stringify(report))
	quit(0 if bool(report.passed) else 1)


func _capture(battle, stem: String, center: Vector2i, zoom: float, hide_fog: bool) -> void:
	var saved_fog: bool = battle.fog
	if hide_fog:
		battle.fog = false
		battle.map.sample_scenery._refresh_fog_visibility()
	if battle._fog_layer != null:
		battle._fog_layer.visible = not hide_fog
	battle.camera.position = battle.to_screen(battle.map.cell_to_world(center))
	battle.camera.zoom = Vector2.ONE * zoom
	battle.camera.force_update_scroll()
	battle._grid_build()
	battle.hud.set_top(battle.level.top_status(battle))
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := output_dir.path_join(stem + "_1280.png")
	var saved := image != null and not image.is_empty() and image.get_size() == VIEW_SIZE \
		and image.save_png(path) == OK
	captures.append({"stem": stem, "png": path, "saved": saved, "fog_hidden": hide_fog,
		"center": [center.x, center.y], "zoom": zoom})
	battle.fog = saved_fog
	battle.map.sample_scenery._refresh_fog_visibility()
