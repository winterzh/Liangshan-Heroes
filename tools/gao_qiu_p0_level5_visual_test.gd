extends SceneTree
## Graphical evidence from the real level-5 scene. The test enters the authored
## third-fleet deployment to inspect its actual Gao flagship, then creates one
## isolated Gao unit at the authored prisoner dock with the same wet-captive
## properties used by land_gao. Only state/direction/camera are varied.

const VIEW_SIZE := Vector2i(1280, 720)
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const SHIP_STATES := ["default", "damaged", "flooding", "disabled"]
const CAPTURED_STATES := ["idle", "down"]
const DEFAULT_OUT := "res://qa/gao_qiu_p0_runtime_20260903/level5_visual"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[gao-qiu-level5-visual] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _set_direction(unit, direction: String) -> void:
	unit.animation_direction = direction
	unit._direction_candidate = direction
	unit._direction_votes = 4
	unit.face_left = direction in ["sw", "nw"]
	unit._move_blend = 0.0
	unit.queue_redraw()


func _capture(output_dir: String, filename: String, metadata: Dictionary) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := output_dir.path_join(filename)
	var image := root.get_texture().get_image()
	var correct_size := image != null and not image.is_empty() and image.get_size() == VIEW_SIZE
	var error := image.save_png(output) if correct_size else ERR_CANT_CREATE
	_check("capture written " + filename, correct_size and error == OK and FileAccess.file_exists(output), output)
	var record := metadata.duplicate(true)
	record["png"] = output
	record["sha256"] = FileAccess.get_sha256(output) if FileAccess.file_exists(output) else ""
	captures.append(record)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("gao_qiu_p0_level5_visual_test needs a graphical renderer")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	var output_dir := OS.get_environment("GAO_QIU_P0_LEVEL5_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	DisplayServer.window_set_size(VIEW_SIZE)
	AudioServer.set_bus_mute(0, true)
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.game_speed = 1.0
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.current = campaign.index_for_id("level5")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud._on_start_pressed()
	await process_frame
	battle.level._start_final_fleet(battle)
	await process_frame
	var flagship = battle.level.flagship
	_check("real third-fleet flagship exists", is_instance_valid(flagship) and flagship.key == "gao_flagship")
	_check("real flagship has chapter80 context", is_instance_valid(flagship)
		and String(flagship.get_meta("campaign_flag_context", "")) == "chapter80_gao_flagship")
	if not is_instance_valid(flagship):
		await _finish(output_dir, battle)
		return

	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	for unit in battle.units:
		if is_instance_valid(unit):
			unit.set_process(false)
			unit.set_physics_process(false)
			if unit != flagship:
				unit.hide()
	battle.hud.hide()
	if battle.map.sample_scenery != null:
		battle.map.sample_scenery.hide()
	flagship.show()
	flagship.visual_scale = 1.8
	# Shift the camera target upward so the tall mast and runtime glyph remain below
	# the QA title bar in the magnified captures.
	battle.camera.position = battle.to_screen(flagship.position) - Vector2(0, 65)
	battle.camera.zoom = Vector2.ONE * 3.0
	battle.camera.force_update_scroll()

	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var banner := ColorRect.new()
	banner.position = Vector2(250, 8)
	banner.size = Vector2(780, 46)
	banner.color = Color(0.04, 0.055, 0.07, 0.92)
	overlay.add_child(banner)
	var title := Label.new()
	title.position = Vector2(250, 12)
	title.size = Vector2(780, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("f2e2bc"))
	overlay.add_child(title)

	var art := root.get_node("Art")
	for state in SHIP_STATES:
		for direction in DIRECTIONS:
			flagship.set_meta("ship_state", state)
			_set_direction(flagship, direction)
			title.text = "第八十回·高俅中军海鳅船 %s / %s · 运行时仅叠「帅」字" % [state, direction.to_upper()]
			var expected := "res://assets/campaign/objects/gao_flagship_%s_%s.png" % [state, direction]
			var texture: Texture2D = art.call("campaign_object_texture", "gao_flagship", state, direction) as Texture2D
			_check("ship runtime source %s_%s" % [state, direction], _source(texture) == expected, _source(texture))
			await _capture(output_dir, "flagship_%s_%s_1280x720.png" % [state, direction], {
				"kind": "real_level5_flagship", "state": state, "direction": direction,
				"source": _source(texture), "visual_scale": flagship.visual_scale,
				"camera_zoom": battle.camera.zoom.x,
			})

	flagship.hide()
	var dock_cell: Vector2i = battle.level.PRISONER_DOCK_LAND
	var captive = battle.spawn_unit("gao_qiu", 1, battle.map.cell_to_world(dock_cell))
	_check("isolated Gao unit created at authored prisoner dock", is_instance_valid(captive)
		and battle.map.world_to_cell(captive.position) == dock_cell, dock_cell)
	if is_instance_valid(captive):
		captive.art_variant = "gao_qiu_captured"
		captive.is_cavalry = false
		captive.atk = 0
		captive.base_speed = 0
		captive.is_captive = true
		captive.visual_scale = 1.0
		captive.set_process(false)
		captive.set_physics_process(false)
		battle.camera.position = battle.to_screen(captive.position) - Vector2(0, 60)
		battle.camera.zoom = Vector2.ONE * 3.2
		battle.camera.force_update_scroll()
		for state in CAPTURED_STATES:
			captive.story_outcome = "" if state == "idle" else "captured"
			for direction in DIRECTIONS:
				_set_direction(captive, direction)
				title.text = "第八十回·换鲜绢衣前的湿俘高俅 %s / %s" % [state, direction.to_upper()]
				var frames: Array = art.unit_anim_frames("gao_qiu", state, direction, captive.art_variant)
				var expected := "res://assets/campaign/anim/gao_qiu_captured_%s_%s.png" % [state, direction]
				var actual := _source(frames[0]) if not frames.is_empty() else ""
				_check("captured runtime source %s_%s" % [state, direction], frames.size() == 1 and actual == expected,
					{"actual": actual, "expected": expected})
				await _capture(output_dir, "captured_%s_%s_1280x720.png" % [state, direction], {
					"kind": "isolated_runtime_variant_at_authored_dock", "state": state, "direction": direction,
					"source": actual, "visual_scale": captive.visual_scale,
					"camera_zoom": battle.camera.zoom.x,
				})

	overlay.queue_free()
	await _finish(output_dir, battle)


func _finish(output_dir: String, battle) -> void:
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"captures": captures,
		"viewport": [VIEW_SIZE.x, VIEW_SIZE.y],
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real level5 third-fleet Gao flagship plus one isolated Gao unit at the authored prisoner dock configured exactly as the land_gao wet-captive route. Only state, direction and camera are varied.",
		"excluded": ["human playthrough", "mission-completion proof", "Steam build or upload"],
		"steam_modified_or_exported": false,
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("GAO_QIU_P0_LEVEL5_VISUAL_RESULT ", JSON.stringify({"passed": failures.is_empty(), "checks": checks.size(), "captures": captures.size(), "report": report_path}))
	current_scene = null
	_release_battle_cursor_textures(battle)
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
