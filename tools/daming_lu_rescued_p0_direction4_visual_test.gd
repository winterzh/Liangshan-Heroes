extends SceneTree
## Real 1280x720 Unit renderer fixture for rescued Lu Junyi's idle and both
## walk frames in four true directions. This is not a campaign playthrough,
## performance result, or human acceptance test.

const VARIANT := "daming_rescued_lu_junyi"
const KEY := "lu_junyi"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const ROWS := [
	{"label": "idle", "state": "idle", "move_blend": 0.0, "anim_t": 0.0, "region_x": 0},
	{"label": "walk_a", "state": "walk", "move_blend": 1.0, "anim_t": 0.01, "region_x": 0},
	{"label": "walk_b", "state": "walk", "move_blend": 1.0, "anim_t": PI + 0.01, "region_x": 256},
]
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)
var failures: Array[String] = []
var checks: Array = []
var captures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	print("[daming-lu-rescued-visual] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _region_x(texture: Texture2D) -> int:
	return int(texture.region.position.x) if texture is AtlasTexture else -1


func _add_label(layer: CanvasLayer, text: String, at: Vector2, size: Vector2, font_size := 18, color := Color("e8dfc5")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)
	return label


func _add_portrait(layer: CanvasLayer, texture: Texture2D, at: Vector2) -> void:
	var frame := ColorRect.new()
	frame.position = at - Vector2(4, 4)
	frame.size = Vector2(104, 104)
	frame.color = Color(0.055, 0.075, 0.095, 0.95)
	layer.add_child(frame)
	var rect := TextureRect.new()
	rect.position = at
	rect.size = Vector2(96, 96)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.add_child(rect)


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("daming_lu_rescued_p0_direction4_visual_test requires a real renderer")
		quit(2)
		return
	var output_dir := OS.get_environment("DAMING_LU_RESCUED_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/daming_lu_rescued_p0_direction4_production_20260903/runtime_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	OS.set_environment("CAMPAIGN_QA", "1")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	var art = root.get_node("Art")
	var campaign = root.get_node("Campaign")
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
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 60)
	top.color = Color(0.055, 0.075, 0.095, 0.94)
	overlay.add_child(top)
	_add_label(overlay, "大名府获救卢俊义 · 真四向待机与两帧步态", Vector2(0, 12), Vector2(1280, 38), 23)
	for column in DIRECTIONS.size():
		_add_label(overlay, DIRECTIONS[column].to_upper(), Vector2(245 + column * 220, 62), Vector2(190, 28), 18, Color("9cc8e6"))
	for row in ROWS.size():
		_add_label(overlay, ROWS[row].label, Vector2(12, 155 + row * 180), Vector2(180, 28), 18)

	var spawned: Array = []
	for row_index in ROWS.size():
		var row: Dictionary = ROWS[row_index]
		for column in DIRECTIONS.size():
			var direction: String = DIRECTIONS[column]
			var unit = battle.spawn_unit(KEY, 0, origin)
			unit.position = origin + ISO_INV.basis_xform(Vector2(-300 + column * 220, -188 + row_index * 180))
			unit.art_variant = VARIANT
			unit.animation_direction = direction
			unit._direction_candidate = direction
			unit._direction_votes = 4
			unit.face_left = direction in ["sw", "nw"]
			unit.visual_scale = 1.08
			unit._move_blend = float(row.move_blend)
			unit._anim_t = float(row.anim_t)
			unit._idle_t = 0.0
			unit.set_process(false)
			unit.set_physics_process(false)
			unit.queue_redraw()
			var fallback: Texture2D = art.unit_texture(KEY, VARIANT, direction)
			var frame: Texture2D = unit._anim_frame_for_state(fallback)
			var expected := "res://assets/campaign/anim/%s_%s_%s.png" % [VARIANT, row.state, direction]
			var source := _source(frame)
			_check(source == expected, "%s_%s_exact_runtime_frame" % [row.label, direction], source)
			_check(unit._frame_directional, "%s_%s_disables_legacy_mirror" % [row.label, direction])
			_check(_region_x(frame) == int(row.region_x), "%s_%s_expected_strip_frame" % [row.label, direction], str(_region_x(frame)))
			spawned.append(unit)

	var portrait: Texture2D = art.avatar_texture(KEY, VARIANT)
	var portrait_source := _source(portrait)
	_check(portrait_source == "res://assets/campaign/portraits/daming_rescued_lu_junyi.png", "exact_runtime_portrait", portrait_source)
	_add_label(overlay, "获救头像", Vector2(1080, 78), Vector2(160, 28), 17, Color("d5bd7e"))
	_add_portrait(overlay, portrait, Vector2(1110, 108))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := output_dir.path_join("daming_lu_rescued_all_directions_1280.png")
	var error := root.get_texture().get_image().save_png(output)
	_check(error == OK and FileAccess.file_exists(output), "capture_written", output)
	captures.append({"png": output, "sha256": FileAccess.get_sha256(output)})

	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"captures": captures,
		"viewport": [1280, 720],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real Unit renderer fixture for Daming rescued Lu Junyi idle and both walk strip frames in four exact directions plus the rescued portrait. No campaign-playthrough, performance, or human-playtest claim.",
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("DAMING_LU_RESCUED_VISUAL_RESULT ", JSON.stringify(report))
	current_scene = null
	_release_battle_cursor_textures(battle)
	overlay.queue_free()
	for unit in spawned:
		unit.queue_free()
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
