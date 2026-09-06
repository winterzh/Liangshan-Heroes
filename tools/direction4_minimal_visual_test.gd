extends SceneTree
## Native 1280x720 renderer fixture using real Battle-spawned Unit nodes.
## Five screenshots show the two adopted identities in all four directions.

const UNITS := ["li_kui", "gou_lian"]
const STATES := ["idle", "walk", "attack", "hurt", "down"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)

var checks: Array = []
var failures: Array[String] = []
var captures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name, "passed":passed, "detail":detail})
	print("[direction4-minimal-visual] ", "PASS " if passed else "FAIL ", name,
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
	unit.story_outcome = ""
	match state:
		"walk":
			unit._move_blend = 1.0
			unit._anim_t = 1.2
		"attack":
			unit._lunge = 0.68
			unit._lunge_dir = {
				"se":Vector2.RIGHT, "sw":Vector2.DOWN,
				"ne":Vector2.UP, "nw":Vector2.LEFT,
			}[direction]
		"hurt": unit._flinch = Vector2(2.5, -0.5)
		"down": unit.story_outcome = "subdued"
	unit.queue_redraw()


func _expected_source(key: String, state: String, direction: String) -> String:
	return "res://assets/anim/%s_%s_%s.png" % [key, state, direction]


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("direction4_minimal_visual_test requires a real renderer")
		quit(2)
		return
	var output_dir := OS.get_environment("DIRECTION4_MINIMAL_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/direction4_minimal_production_20260902/runtime_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	OS.set_environment("CAMPAIGN_QA", "1")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	var art := root.get_node("Art")
	var campaign := root.get_node("Campaign")
	campaign.arena = true
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.custom_defense = false
	campaign.scenario = false
	campaign.current = campaign.index_for_id("level7")
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
	battle.camera.position = battle.to_screen(origin)
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
		_label(overlay, DIRECTIONS[column].to_upper(), Vector2(300 + column * 175, 64), Vector2(165, 26), 17, Color("9cc8e6"))
	var title := _label(overlay, "", Vector2(0, 13), Vector2(1280, 34), 22)

	for state in STATES:
		title.text = "李逵 / 钩镰枪手 · 四向实机 · %s" % state.to_upper()
		var spawned: Array = []
		for row in UNITS.size():
			var key: String = UNITS[row]
			_label(overlay, "李逵" if key == "li_kui" else "钩镰枪手", Vector2(30, 230 + row * 245), Vector2(210, 30), 20)
			for column in DIRECTIONS.size():
				var direction: String = DIRECTIONS[column]
				var unit = battle.spawn_unit(key, 0, origin)
				unit.position = origin + ISO_INV.basis_xform(Vector2(-260 + column * 175, -145 + row * 245))
				unit.visual_scale = 1.35
				_state_setup(unit, state, direction)
				unit.set_process(false)
				unit.set_physics_process(false)
				var frames: Array = art.unit_anim_frames(key, state, direction, "")
				var actual := _source(frames[0]) if not frames.is_empty() else ""
				_check("visual source %s/%s/%s" % [key, state, direction],
					actual == _expected_source(key, state, direction),
					{"expected":_expected_source(key, state, direction), "actual":actual})
				spawned.append(unit)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if state == "down":
			for index in spawned.size():
				_check("real down draw is directional %s/%s" % [UNITS[index >> 2], DIRECTIONS[index % 4]], spawned[index]._frame_directional)
		var output := output_dir.path_join("%s_1280x720.png" % state)
		var error := root.get_texture().get_image().save_png(output)
		_check("capture written " + state, error == OK and FileAccess.file_exists(output), output)
		captures.append({"state":state, "png":output, "sha256":FileAccess.get_sha256(output)})
		for unit in spawned:
			unit.queue_free()
		for child in overlay.get_children():
			if child is Label and child.position.y >= 150:
				child.queue_free()
		await process_frame

	var report := {
		"passed":failures.is_empty(),
		"checks":checks.size(),
		"failures":failures,
		"captures":captures,
		"viewport":[1280, 720],
		"display_server":DisplayServer.get_name(),
		"renderer":RenderingServer.get_video_adapter_name(),
		"scope":"Real Battle-spawned Unit renderer for adopted li_kui/gou_lian states and directions. Visual fixture only; no balance or playthrough claim.",
		"visual_scale":1.35,
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("DIRECTION4_MINIMAL_VISUAL_RESULT ", JSON.stringify(report))
	current_scene = null
	_release_battle_cursor_textures(battle)
	overlay.queue_free()
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
