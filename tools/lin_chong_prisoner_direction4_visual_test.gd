extends SceneTree
## Graphical QA fixture for the production Lin Chong prisoner idle/walk subset.
## It uses the real level-6 deployment, Unit drawing path, map and 1.0 camera zoom.
## Direction and movement blend are frozen only for each screenshot; this is not
## evidence of mission progression, player input, animation cadence or performance.

const VIEW_SIZE := Vector2i(1280, 720)
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const STATES := ["idle", "walk"]

var output_dir := ""
var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lin-chong-visual] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	if DisplayServer.get_name() == "headless":
		push_error("Lin Chong visual QA requires a graphical renderer.")
		quit(2)
		return
	output_dir = OS.get_environment("LIN_CHONG_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/lin_chong_prisoner_direction4_production_20260902/visual")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("Cannot create output directory: %s (%d)" % [output_dir, mkdir_error])
		quit(2)
		return

	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.title = "Lin Chong prisoner direction-4 production QA · actual Unit scale"
	root.get_node("Settings").edge_scroll = false
	AudioServer.set_bus_mute(0, true)

	var campaign = root.get_node("Campaign")
	var save_existed := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_before := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_existed else PackedByteArray()
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.current = campaign.index_for_id("level6")
	seed(5088120)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud._on_start_pressed()
	await process_frame

	var lin = battle.level.lin_freed
	_check("real level6 prisoner exists", is_instance_valid(lin))
	if not is_instance_valid(lin):
		_finish(campaign, save_existed, save_before)
		return
	_check("real level6 prisoner variant", lin.art_variant == "lin_chong_prisoner", lin.art_variant)
	_check("real level6 prisoner remains noncombat", lin.is_noncombat)
	_check("real level6 display scale is radius-derived", is_equal_approx(lin.radius * 3.7 * lin.visual_scale, 48.1), {
		"radius": lin.radius,
		"visual_scale": lin.visual_scale,
		"draw_square_px": lin.radius * 3.7 * lin.visual_scale,
	})

	# Freeze the real deployment after start. Only the QA pose values below change.
	battle._smoke = false
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	battle.camera.position = battle.to_screen(lin.position) - Vector2(105.0, -10.0)
	battle.camera.zoom = Vector2.ONE
	battle.camera.offset = Vector2.ZERO
	battle.camera.force_update_scroll()
	battle._grid_build()

	for state in STATES:
		for direction in DIRECTIONS:
			lin.animation_direction = direction
			lin.face_left = direction in ["sw", "nw"]
			lin._move_blend = 1.0 if state == "walk" else 0.0
			lin._anim_t = 0.55
			lin._idle_t = 0.35
			lin.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var expected := "res://assets/campaign/anim/lin_chong_prisoner_%s_%s.png" % [state, direction]
			var selected: Texture2D = lin._anim_frame_for_state(root.get_node("Art").unit_texture(lin.key, lin.art_variant, direction))
			var selected_path: String = _source(selected)
			var image := root.get_texture().get_image()
			var file_name := "lin_chong_prisoner_%s_%s_actual_zoom1_1280.png" % [state, direction]
			var file_path := output_dir.path_join(file_name)
			var saved: bool = image != null and image.get_size() == VIEW_SIZE and image.save_png(file_path) == OK
			var exact: bool = selected_path == expected and bool(lin._frame_directional)
			_check("capture %s %s uses exact production source" % [state, direction], exact, {
				"actual": selected_path,
				"expected": expected,
				"directional": lin._frame_directional,
			})
			_check("capture %s %s saved at 1280x720" % [state, direction], saved, file_path)
			captures.append({
				"state": state,
				"direction": direction,
				"png": file_path,
				"source": selected_path,
				"camera_zoom": 1.0,
				"unit_draw_square_px": lin.radius * 3.7 * lin.visual_scale,
			})

	battle.queue_free()
	await process_frame
	await process_frame
	_finish(campaign, save_existed, save_before)


func _finish(campaign, save_existed: bool, save_before: PackedByteArray) -> void:
	var save_exists_now := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_now := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	_check("campaign save existence and bytes unchanged", save_existed == save_exists_now and save_before == save_now)
	var passed: bool = not checks.is_empty() and checks.all(func(item): return bool(item.passed)) and captures.size() == 8
	var report := {
		"passed": passed,
		"checks": checks,
		"captures": captures,
		"viewport": [VIEW_SIZE.x, VIEW_SIZE.y],
		"renderer": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"scope": "Real level6 Unit/map renderer at camera zoom 1.0; pose-frozen QA fixture only, not mission progression, human playtest, cadence or performance evidence.",
	}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	var report_ok := file != null
	if report_ok:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("[lin-chong-visual-summary] ", JSON.stringify({"passed": passed and report_ok, "captures": captures.size(), "report": output_dir.path_join("report.json")}))
	quit(0 if passed and report_ok else 1)
