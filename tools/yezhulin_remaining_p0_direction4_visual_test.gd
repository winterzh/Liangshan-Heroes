extends SceneTree
## Real-renderer fixture for the five replacement variants in the remaining
## seven-state provenance batch. Story-scene captures are run separately.

const DIRECTIONS := ["se", "sw", "ne", "nw"]
const SPECS := [
	{"key": "lin_chong", "label": "林冲押解", "variant": "lin_chong_escort", "walk": false},
	{"key": "dong_chao", "label": "董超", "variant": "dong_chao_escort", "walk": true},
	{"key": "xue_ba", "label": "薛霸", "variant": "xue_ba_escort", "walk": true},
	{"key": "shi_qian", "label": "时迁闹鹅儿提篮", "variant": "shi_qian_lantern", "walk": false},
	{"key": "shi_xiu", "label": "祝家庄受缚石秀", "variant": "bound_shi_xiu", "walk": false},
]
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)

var failures: Array[String] = []
var checks: Array = []
var captures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	print("[yezhulin-remaining-visual] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _region_x(texture: Texture2D) -> int:
	return int(texture.region.position.x) if texture is AtlasTexture else -1


func _add_label(layer: CanvasLayer, text: String, at: Vector2, size: Vector2,
		font_size := 18, color := Color("e8dfc5")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)
	return label


func _add_portrait(layer: CanvasLayer, texture: Texture2D, at: Vector2, label: String) -> Array[Node]:
	var frame := ColorRect.new()
	frame.position = at - Vector2(4, 4)
	frame.size = Vector2(128, 128)
	frame.color = Color(0.055, 0.075, 0.095, 0.95)
	layer.add_child(frame)
	var rect := TextureRect.new()
	rect.position = at
	rect.size = Vector2(120, 120)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.add_child(rect)
	var caption := _add_label(layer, label, at + Vector2(-8, 124), Vector2(136, 26), 15, Color("d5bd7e"))
	return [frame, rect, caption]


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _spawn_frame(battle, art, spec: Dictionary, state: String, direction: String,
		frame_index: int, world_position: Vector2):
	var unit = battle.spawn_unit(spec.key, 0, world_position)
	unit.position = world_position
	unit.art_variant = spec.variant
	unit.animation_direction = direction
	unit._direction_candidate = direction
	unit._direction_votes = 4
	unit.face_left = direction in ["sw", "nw"]
	unit.visual_scale = 1.0
	unit._move_blend = 1.0 if state == "walk" else 0.0
	unit._anim_t = (float(frame_index) + 0.02) * TAU / 4.0 if state == "walk" else 0.0
	unit._idle_t = 0.0
	unit.set_process(false)
	unit.set_physics_process(false)
	unit.queue_redraw()
	var fallback: Texture2D = art.unit_texture(spec.key, spec.variant, direction)
	var frame: Texture2D = unit._anim_frame_for_state(fallback)
	var expected := "res://assets/campaign/anim/%s_%s_%s.png" % [spec.variant, state, direction]
	_check(_source(frame) == expected, "%s_%s_%s_frame_%d_path" % [spec.variant, state, direction, frame_index], _source(frame))
	_check(unit._frame_directional, "%s_%s_%s_no_mirror" % [spec.variant, state, direction])
	_check(_region_x(frame) == (frame_index * 256 if state == "walk" else 0),
		"%s_%s_%s_frame_%d_region" % [spec.variant, state, direction, frame_index], str(_region_x(frame)))
	return unit


func _capture(output_dir: String, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := output_dir.path_join(name + "_1280.png")
	var error := root.get_texture().get_image().save_png(output)
	_check(error == OK and FileAccess.file_exists(output), name + "_capture_written", output)
	captures.append({"name": name, "png": output, "sha256": FileAccess.get_sha256(output)})


func _clear_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("yezhulin_remaining_p0_direction4_visual_test requires a real renderer")
		quit(2)
		return
	var output_dir := OS.get_environment("YEZHULIN_REMAINING_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/yezhulin_remaining_p0_direction4_production_20260903/runtime_visual")
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
	campaign.current = campaign.index_for_id("level6")
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
	top.size = Vector2(1280, 58)
	top.color = Color(0.055, 0.075, 0.095, 0.94)
	overlay.add_child(top)
	var title := _add_label(overlay, "", Vector2(0, 12), Vector2(1280, 36), 23)
	for column in DIRECTIONS.size():
		_add_label(overlay, DIRECTIONS[column].to_upper(), Vector2(175 + column * 230, 72), Vector2(190, 28), 18, Color("9cc8e6"))

	for spec in SPECS:
		var nodes: Array = []
		title.text = "%s · 四方向单帧与同造型头像" % spec.label
		for column in DIRECTIONS.size():
			var position := origin + ISO_INV.basis_xform(Vector2(-390 + column * 230, 20))
			nodes.append(_spawn_frame(battle, art, spec, "idle", DIRECTIONS[column], 0, position))
		var portrait: Texture2D = art.avatar_texture(spec.key, spec.variant)
		nodes.append_array(_add_portrait(overlay, portrait, Vector2(1085, 315), "同造型头像"))
		await _capture(output_dir, "%s_idle_direction4" % spec.variant)
		await _clear_nodes(nodes)

	for spec in SPECS:
		if not spec.walk:
			continue
		var nodes: Array = []
		title.text = "%s · 四方向四帧真实步态" % spec.label
		for row in 4:
			nodes.append(_add_label(overlay, "walk_%d" % row, Vector2(18, 130 + row * 145), Vector2(145, 28), 17))
			for column in DIRECTIONS.size():
				var position := origin + ISO_INV.basis_xform(Vector2(-320 + column * 220, -215 + row * 145))
				nodes.append(_spawn_frame(battle, art, spec, "walk", DIRECTIONS[column], row, position))
		await _capture(output_dir, "%s_walk4" % spec.variant)
		await _clear_nodes(nodes)

	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"captures": captures,
		"viewport": [1280, 720],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real Unit renderer fixture for five replacement variants, four exact directions, four exact Dong Chao and Xue Ba walk frames, portraits and no-mirror routing. Story progression is captured separately.",
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("YEZHULIN_REMAINING_VISUAL_RESULT ", JSON.stringify(report))
	current_scene = null
	_release_battle_cursor_textures(battle)
	overlay.queue_free()
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
