extends SceneTree
## Graphical fixture using real Battle-spawned lian_huan_ma Unit nodes.
## Five 1280x720 captures show all four directions for every adopted state.

const STATES := ["idle", "walk", "attack", "hurt", "death"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const VIEW_SIZE := Vector2i(1280, 720)
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)
const DEFAULT_OUT := "res://qa/lianhuanma_p0_direction4_production_20260903/runtime_visual"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lian-huan-ma-visual] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _label(layer: CanvasLayer, text: String, at: Vector2, size: Vector2, font_size := 18, color := Color("e8dfc5")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)
	return label


func _state_setup(unit, state: String, direction: String) -> void:
	unit.art_variant = ""
	unit.animation_direction = direction
	unit._direction_candidate = direction
	unit._direction_votes = 4
	unit.face_left = direction in ["sw", "nw"]
	unit._move_blend = 0.0
	unit._lunge = 0.0
	unit._flinch = Vector2.ZERO
	unit._dying = false
	unit._death_t = 0.0
	unit.story_outcome = ""
	match state:
		"walk":
			unit._move_blend = 1.0
			unit._anim_t = 1.2
		"attack":
			unit._lunge = 0.68
			unit._lunge_dir = {
				"se": Vector2.RIGHT, "sw": Vector2.DOWN,
				"ne": Vector2.UP, "nw": Vector2.LEFT,
			}[direction]
		"hurt":
			unit._flinch = Vector2(2.5, -0.5)
		"death":
			unit._dying = true
			unit._death_t = 1.0
	unit.queue_redraw()


func _expected(state: String, direction: String) -> String:
	return "res://assets/anim/lian_huan_ma_%s_%s.png" % [state, direction]


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("lian_huan_ma_direction4_visual_test needs a graphical renderer")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	var output_dir := OS.get_environment("LHM_DIRECTION4_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	DisplayServer.window_set_size(VIEW_SIZE)
	AudioServer.set_bus_mute(0, true)
	var campaign := root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "custom_defense", "scenario"]:
		campaign.set(mode, false)
	campaign.arena = true
	campaign.current = campaign.index_for_id("level4")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud.hide()
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	for existing in battle.units:
		existing.hide()
		existing.set_process(false)
		existing.set_physics_process(false)
	var open_cell: Vector2i = battle.map.nearest_open(Vector2i(24, 24), "land")
	if open_cell.x < 0:
		open_cell = battle.map.nearest_open(Vector2i(10, 10), "land")
	var origin: Vector2 = battle.map.cell_to_world(open_cell)
	battle.camera.position = battle.to_screen(origin) - Vector2(0, 36)
	battle.camera.zoom = Vector2.ONE
	battle.camera.force_update_scroll()

	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var top := ColorRect.new()
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 58)
	top.color = Color(0.055, 0.075, 0.095, 0.94)
	overlay.add_child(top)
	for column in DIRECTIONS.size():
		_label(overlay, DIRECTIONS[column].to_upper(), Vector2(268 + column * 205, 72), Vector2(190, 26), 18, Color("9cc8e6"))
	var title := _label(overlay, "", Vector2(0, 13), Vector2(1280, 34), 22)
	var art := root.get_node("Art")

	for state in STATES:
		title.text = "第五十五至五十七回·连环甲马四向实机 · %s" % state.to_upper()
		var spawned: Array = []
		for column in DIRECTIONS.size():
			var direction: String = DIRECTIONS[column]
			var unit = battle.spawn_unit("lian_huan_ma", 1, origin)
			unit.position = origin + ISO_INV.basis_xform(Vector2(-315 + column * 205, 12))
			unit.visual_scale = 1.85
			_state_setup(unit, state, direction)
			unit.set_process(false)
			unit.set_physics_process(false)
			var frames: Array = art.unit_anim_frames("lian_huan_ma", state, direction, "")
			var actual := _source(frames[0]) if not frames.is_empty() else ""
			_check("runtime source %s/%s" % [state, direction], actual == _expected(state, direction), {
				"actual": actual, "expected": _expected(state, direction)})
			spawned.append(unit)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		for index in spawned.size():
			_check("render marks directional %s/%s" % [state, DIRECTIONS[index]], spawned[index]._frame_directional)
		var output := output_dir.path_join("%s_1280x720.png" % state)
		var image := root.get_texture().get_image()
		var correct_size := image != null and not image.is_empty() and image.get_size() == VIEW_SIZE
		var error := image.save_png(output) if correct_size else ERR_CANT_CREATE
		_check("capture written " + state, correct_size and error == OK and FileAccess.file_exists(output), output)
		captures.append({"state": state, "png": output,
			"sha256": FileAccess.get_sha256(output) if FileAccess.file_exists(output) else ""})
		for unit in spawned:
			unit.queue_free()
		await process_frame

	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"captures": captures,
		"viewport": [VIEW_SIZE.x, VIEW_SIZE.y],
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real Battle-spawned lian_huan_ma renderer for idle/walk/attack/hurt/death and four exact directions; level4 is selected but mission completion is not exercised",
		"excluded": ["mission completion", "human playtest", "Steam build or upload"],
		"steam_modified_or_exported": false,
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("LHM_DIRECTION4_VISUAL_RESULT ", JSON.stringify({
		"passed": failures.is_empty(), "checks": checks.size(), "captures": captures.size(), "report": report_path}))
	current_scene = null
	_release_battle_cursor_textures(battle)
	overlay.queue_free()
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
