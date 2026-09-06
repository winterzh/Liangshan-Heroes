extends SceneTree
## Graphical QA fixture for the production Lin Chong post-untie walk strips.
## It uses the real level-6 Unit/map renderer at camera zoom 1.0, then freezes
## progression and selects the escort variant. This is not progression evidence.

const VIEW_SIZE := Vector2i(1280, 720)
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const VARIANT := "lin_chong_escort"
const OUTPUT := "res://qa/lin_chong_escort_walk_direction4_production_20260902/visual"

var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lin-chong-escort-visual] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


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
		push_error("Lin Chong escort visual QA requires a graphical renderer.")
		quit(2)
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create output directory: %s" % output_dir)
		quit(2)
		return

	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.title = "Lin Chong escort direction-4 walk QA"
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
	_check("real level6 Lin Chong exists", is_instance_valid(lin))
	if not is_instance_valid(lin):
		_finish(campaign, save_existed, save_before, output_dir)
		return
	battle._smoke = false
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	lin.art_variant = VARIANT
	lin.is_noncombat = true
	lin.set_meta("story_pose", "")
	lin._move_blend = 1.0
	battle.camera.position = battle.to_screen(lin.position) - Vector2(105.0, -10.0)
	battle.camera.zoom = Vector2.ONE
	battle.camera.offset = Vector2.ZERO
	battle.camera.force_update_scroll()
	battle._grid_build()
	_check("fixture uses real level6 Unit with escort variant", lin.art_variant == VARIANT, lin.art_variant)
	_check("real display scale is radius-derived", is_equal_approx(lin.radius * 3.7 * lin.visual_scale, 48.1), {
		"radius": lin.radius,
		"visual_scale": lin.visual_scale,
		"draw_square_px": lin.radius * 3.7 * lin.visual_scale,
	})

	for direction in DIRECTIONS:
		for frame_index in range(4):
			lin.animation_direction = direction
			lin.face_left = direction in ["sw", "nw"]
			lin._anim_t = TAU * (float(frame_index) + 0.1) / 4.0
			lin.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var fallback: Texture2D = root.get_node("Art").unit_texture(lin.key, VARIANT, direction)
			var selected: Texture2D = lin._anim_frame_for_state(fallback)
			var region: Rect2 = selected.region if selected is AtlasTexture else Rect2()
			var expected := "res://assets/campaign/anim/lin_chong_escort_walk_%s.png" % direction
			var exact: bool = _source(selected) == expected and region == Rect2(frame_index * 256, 0, 256, 256) and bool(lin._frame_directional)
			var file_path := output_dir.path_join("lin_chong_escort_walk_%s_f%d_actual_zoom1_1280.png" % [direction, frame_index])
			var image := root.get_texture().get_image()
			var saved: bool = image != null and image.get_size() == VIEW_SIZE and image.save_png(file_path) == OK
			_check("capture %s frame %d exact" % [direction, frame_index], exact, {
				"source": _source(selected), "region": str(region), "directional": lin._frame_directional,
			})
			_check("capture %s frame %d saved" % [direction, frame_index], saved, file_path)
			captures.append({
				"direction": direction,
				"frame": frame_index,
				"png": file_path,
				"source": _source(selected),
				"region": str(region),
				"camera_zoom": 1.0,
				"unit_draw_square_px": lin.radius * 3.7 * lin.visual_scale,
			})

	battle.queue_free()
	await process_frame
	await process_frame
	_finish(campaign, save_existed, save_before, output_dir)


func _finish(campaign, save_existed: bool, save_before: PackedByteArray, output_dir: String) -> void:
	var save_exists_now := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_now := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	_check("campaign save existence and bytes unchanged", save_existed == save_exists_now and save_before == save_now)
	var passed := failures.is_empty() and captures.size() == 16
	var report := {
		"passed": passed,
		"checks": checks,
		"captures": captures,
		"viewport": [VIEW_SIZE.x, VIEW_SIZE.y],
		"renderer": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"scope": "Real level6 Unit/map renderer at zoom 1.0; frozen escort-variant fixture only, not mission progression, player input, cadence or performance evidence.",
	}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	var report_ok := file != null
	if report_ok:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("[lin-chong-escort-visual-summary] ", JSON.stringify({
		"passed": passed and report_ok,
		"captures": captures.size(),
		"report": output_dir.path_join("report.json"),
	}))
	quit(0 if passed and report_ok else 1)
