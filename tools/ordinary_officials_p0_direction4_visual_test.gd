extends SceneTree
## Real 1280x720 renderer fixture for the nine ordinary-official P0 adoptions.
## It proves exact four-direction runtime routing and the two Daming disguise
## portraits. It is not a playthrough, performance result, or full-campaign QA.

const GROUPS := {
	"daming_public_servants": [
		{"key": "chai_jin", "variant": "chai_jin_officer"},
		{"key": "yue_he", "variant": "yue_he_officer"},
	],
	"ordinary_official_troops": [
		{"key": "guan_dao", "variant": ""},
		{"key": "guan_gong", "variant": ""},
		{"key": "guan_qi", "variant": ""},
	],
	"execution_and_story_staff": [
		{"key": "guan_zhanzi", "variant": ""},
		{"key": "guan_laozi", "variant": ""},
		{"key": "jun_han", "variant": ""},
		{"key": "zhu_keke", "variant": ""},
	],
}
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)
var failures: Array[String] = []
var checks: Array = []
var captures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	print("[ordinary-officials-visual] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _expected_frame_path(entry: Dictionary, direction: String) -> String:
	var variant: String = entry.variant
	if variant.is_empty():
		return "res://assets/anim/%s_idle_%s.png" % [entry.key, direction]
	return "res://assets/campaign/anim/%s_idle_%s.png" % [variant, direction]


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


func _add_portrait(layer: CanvasLayer, texture: Texture2D, at: Vector2) -> TextureRect:
	var frame := ColorRect.new()
	frame.position = at - Vector2(4, 4)
	frame.size = Vector2(108, 108)
	frame.color = Color(0.075, 0.095, 0.11, 0.94)
	layer.add_child(frame)
	var rect := TextureRect.new()
	rect.position = at
	rect.size = Vector2(100, 100)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.add_child(rect)
	return rect


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("ordinary_officials_p0_direction4_visual_test requires a real renderer")
		quit(2)
		return
	var output_dir := OS.get_environment("ORDINARY_OFFICIALS_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/ordinary_officials_p0_direction4_production_20260903/runtime_visual")
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
	top.size = Vector2(1280, 56)
	top.color = Color(0.055, 0.075, 0.095, 0.92)
	overlay.add_child(top)
	for column in DIRECTIONS.size():
		_add_label(overlay, DIRECTIONS[column].to_upper(), Vector2(300 + column * 170, 58), Vector2(160, 28), 17, Color("9cc8e6"))
	_add_label(overlay, "PORTRAIT", Vector2(1055, 58), Vector2(180, 28), 17, Color("d5bd7e"))
	var title_label := _add_label(overlay, "", Vector2(0, 13), Vector2(1280, 34), 22)

	for group_name in GROUPS:
		title_label.text = "九项普通官军四向实机 · %s" % group_name
		var spawned: Array = []
		var transient_overlay: Array[Node] = []
		var entries: Array = GROUPS[group_name]
		for row in entries.size():
			var entry: Dictionary = entries[row]
			var key: String = entry.key
			var variant: String = entry.variant
			var row_name := variant if not variant.is_empty() else key
			transient_overlay.append(_add_label(overlay, row_name, Vector2(18, 154 + row * 130), Vector2(245, 28), 18))
			for column in DIRECTIONS.size():
				var direction: String = DIRECTIONS[column]
				var unit = battle.spawn_unit(key, 0, origin)
				unit.position = origin + ISO_INV.basis_xform(Vector2(-255 + column * 170, -178 + row * 130))
				unit.art_variant = variant
				unit.animation_direction = direction
				unit._direction_candidate = direction
				unit._direction_votes = 4
				unit.face_left = direction in ["sw", "nw"]
				unit.visual_scale = 1.05
				unit.set_process(false)
				unit.set_physics_process(false)
				unit.queue_redraw()
				var frame: Texture2D = unit._anim_frame_for_state(art.unit_texture(key, variant, direction))
				var source := _source(frame)
				var expected := _expected_frame_path(entry, direction)
				_check(source == expected, "%s_%s_exact_runtime_frame" % [row_name, direction], source)
				_check(unit._frame_directional, "%s_%s_disables_legacy_mirror" % [row_name, direction])
				spawned.append(unit)
			if not variant.is_empty():
				var portrait: Texture2D = art.avatar_texture(key, variant)
				var portrait_source := _source(portrait)
				var expected_portrait := "res://assets/campaign/portraits/%s.png" % variant
				_check(portrait_source == expected_portrait, "%s_exact_runtime_portrait" % variant, portrait_source)
				var portrait_rect := _add_portrait(overlay, portrait, Vector2(1095, 116 + row * 130))
				transient_overlay.append(portrait_rect)
				transient_overlay.append(portrait_rect.get_parent().get_child(portrait_rect.get_index() - 1))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var output := output_dir.path_join("%s_1280.png" % group_name)
		var error := root.get_texture().get_image().save_png(output)
		_check(error == OK and FileAccess.file_exists(output), group_name + "_capture_written", output)
		captures.append({"group": group_name, "png": output, "sha256": FileAccess.get_sha256(output)})
		for unit in spawned:
			unit.queue_free()
		for control in transient_overlay:
			if is_instance_valid(control):
				control.queue_free()
		await process_frame

	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"captures": captures,
		"viewport": [1280, 720],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real Unit renderer fixture for nine adopted ordinary-official entries, four exact directions, and Chai Jin/Yue He disguise portraits. No gameplay, performance, full-campaign, or human-playtest claim.",
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("ORDINARY_OFFICIALS_VISUAL_RESULT ", JSON.stringify(report))
	current_scene = null
	_release_battle_cursor_textures(battle)
	overlay.queue_free()
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
