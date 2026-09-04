extends SceneTree
## Graphical evidence from the real level-2 deployment. The actual deployed Li
## Kui node is frozen at mission start and rotated through four idle directions;
## no unit position, costume route, HP, faction, or mission state is injected.

const VIEW_SIZE := Vector2i(1280, 720)
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const VARIANT := "li_kui_jiangzhou"
const DEFAULT_OUT := "res://qa/li_kui_jiangzhou_direction4_production_20260903/level2_visual"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[li-kui-level2-visual] ", "PASS " if passed else "FAIL ", name,
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


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("li_kui_jiangzhou_level2_visual_test needs a graphical renderer")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	var output_dir := OS.get_environment("LI_KUI_JIANGZHOU_LEVEL2_VISUAL_OUT")
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
	campaign.current = campaign.index_for_id("level2")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud._on_start_pressed()
	await process_frame
	var li_kui = battle.find_unit("li_kui")
	_check("real level2 deployed Li Kui", is_instance_valid(li_kui))
	if not is_instance_valid(li_kui):
		await _finish(output_dir, battle)
		return
	_check("real deployed node carries Jiangzhou-only variant", li_kui.art_variant == VARIANT, li_kui.art_variant)
	_check("real deployed node remains at authored start cell",
		battle.map.world_to_cell(li_kui.position) == Vector2i(9, 31), battle.map.world_to_cell(li_kui.position))

	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	for unit in battle.units:
		if is_instance_valid(unit):
			unit.set_process(false)
			unit.set_physics_process(false)
	battle.mission.tick(0.0)
	battle.hud.set_top(battle.level.top_status(battle))
	battle._grid_build()
	battle.camera.position = battle.to_screen(li_kui.position) - Vector2(95.0, -35.0) / 2.0
	battle.camera.zoom = Vector2.ONE * 2.0
	battle.camera.force_update_scroll()

	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var banner := ColorRect.new()
	banner.position = Vector2(360, 8)
	banner.size = Vector2(560, 42)
	banner.color = Color(0.04, 0.055, 0.07, 0.90)
	overlay.add_child(banner)
	var title := Label.new()
	title.position = Vector2(360, 12)
	title.size = Vector2(560, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("f2e2bc"))
	overlay.add_child(title)

	var art := root.get_node("Art")
	for direction in DIRECTIONS:
		li_kui.animation_direction = direction
		li_kui._direction_candidate = direction
		li_kui._direction_votes = 4
		li_kui.face_left = direction in ["sw", "nw"]
		li_kui._move_blend = 0.0
		li_kui.story_outcome = ""
		li_kui.queue_redraw()
		title.text = "江州劫法场·真实关卡李逵待机方向 %s" % direction.to_upper()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var frames: Array = art.unit_anim_frames("li_kui", "idle", direction, li_kui.art_variant)
		var expected := "res://assets/campaign/anim/%s_idle_%s.png" % [VARIANT, direction]
		var actual := _source(frames[0]) if not frames.is_empty() else ""
		_check("real node source " + direction, frames.size() == 1 and actual == expected,
			{"actual": actual, "expected": expected})
		_check("real node draw is directional " + direction, li_kui._frame_directional)
		var output := output_dir.path_join("level2_li_kui_idle_%s_1280x720.png" % direction)
		var image := root.get_texture().get_image()
		var correct_size := image != null and not image.is_empty() and image.get_size() == VIEW_SIZE
		var error := image.save_png(output) if correct_size else ERR_CANT_CREATE
		_check("capture written " + direction, correct_size and error == OK and FileAccess.file_exists(output), output)
		captures.append({
			"direction": direction,
			"png": output,
			"sha256": FileAccess.get_sha256(output) if FileAccess.file_exists(output) else "",
			"source": actual,
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
		"viewport": [1280, 720],
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Actual level2-deployed Li Kui at authored start cell, with only idle direction and camera changed for four visual captures; not a playthrough or human acceptance.",
		"steam_modified_or_exported": false,
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("LI_KUI_JIANGZHOU_LEVEL2_VISUAL_RESULT ", JSON.stringify(report))
	current_scene = null
	_release_battle_cursor_textures(battle)
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
