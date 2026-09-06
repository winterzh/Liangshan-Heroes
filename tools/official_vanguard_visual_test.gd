extends SceneTree
## Real-renderer evidence for the Chapter 80 vanguard headship. This fixture
## reads the Level 5 definition and Unit renderer; it does not alter gameplay,
## source artwork, pathing, combat values, saves, or release files.

const CampaignArt := preload("res://scripts/campaign_art.gd")
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const STATES := ["default", "damaged", "flooding", "disabled"]
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)

var checks: Array = []
var failures: Array[String] = []
var captures: Array = []
var samples: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	print("[official-vanguard-visual] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _add_label(layer: CanvasLayer, text: String, at: Vector2, size: Vector2, font_size := 18, color := Color("f0e1b9")) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)


func _capture(output_dir: String, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(name)
	var result := root.get_texture().get_image().save_png(path)
	_check(result == OK and FileAccess.file_exists(path), name + "_written", path)
	if result == OK and FileAccess.file_exists(path):
		captures.append({"png": path, "sha256": FileAccess.get_sha256(path)})


func _configure_direction(unit, direction: String, state: String, scale: float) -> void:
	unit.animation_direction = direction
	unit._direction_candidate = direction
	unit._direction_votes = 4
	unit.face_left = direction in ["sw", "nw"]
	unit.visual_scale = scale
	unit.set_meta("campaign_flag_context", "chapter80_vanguard_headship")
	unit.set_meta("ship_state", state)
	unit.set_process(false)
	unit.set_physics_process(false)
	unit.queue_redraw()


func _release_audio() -> void:
	for autoload_name in ["Sfx", "Music"]:
		var node = root.get_node_or_null(autoload_name)
		if node == null:
			continue
		node.set_process(false)
		for child in node.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
				child.queue_free()
	await process_frame


func _write_report(output_dir: String) -> void:
	var report := {
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"captures": captures,
		"samples": samples,
		"viewport": [1280, 720],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real Level 5 Unit renderer fixture for the Chapter 80 vanguard headship. It verifies its single deployment, exact per-state/per-direction source files, white-list context, and 1280x720 appearance. It does not prove water pathing, combat balance, campaign completion, performance, or human playtesting.",
	}
	var path := output_dir.path_join("report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "report_written", path)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	_check(FileAccess.file_exists(path), "report_written", path)


func _finish(battle, overlay: CanvasLayer) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	if battle != null and is_instance_valid(battle):
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
		battle.queue_free()
	await process_frame
	await process_frame
	await _release_audio()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("official_vanguard_visual_test requires a real renderer")
		quit(2)
		return
	var output_dir := OS.get_environment("OFFICIAL_VANGUARD_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/direction4_20260901/runtime_official_vanguard")
	DirAccess.make_dir_recursive_absolute(output_dir)
	OS.set_environment("CAMPAIGN_QA", "1")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	var campaign = root.get_node_or_null("Campaign")
	_check(campaign != null, "campaign_autoload_available")
	if campaign == null:
		_write_report(output_dir)
		quit(1)
		return
	campaign.arena = false
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.custom_defense = false
	campaign.scenario = false
	campaign.current = campaign.index_for_id("level5")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud.hide()
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	_check(battle._defs.has("official_vanguard"), "level5_has_vanguard_definition")
	var water_cell: Vector2i = battle.map.nearest_open(Vector2i(42, 40), "water")
	_check(water_cell.x >= 0, "level5_has_water_fixture_cell", str(water_cell))
	if water_cell.x < 0 or not battle._defs.has("official_vanguard"):
		_write_report(output_dir)
		await _finish(battle, null)
		return
	if battle.map.sample_scenery != null:
		battle.map.sample_scenery.hide()
	var origin: Vector2 = battle.map.cell_to_world(water_cell)
	battle.camera.position = battle.to_screen(origin)
	battle.camera.zoom = Vector2.ONE
	battle.camera.force_update_scroll()
	battle.level._start_final_fleet(battle)
	await process_frame
	var headship = battle.level.vanguard_headship
	_check(is_instance_valid(headship) and headship.key == "official_vanguard", "level5_finale_spawns_one_vanguard_headship")
	_check(battle.level.enemy_fleet.size() == 5 and battle.level.enemy_fleet.filter(func(ship): return ship.key == "official_vanguard").size() == 1, "finale_keeps_one_vanguard_inside_five_ship_compression")
	_check(is_instance_valid(headship) and String(headship.get_meta("campaign_flag_context", "")) == "chapter80_vanguard_headship" and headship._campaign_flag_object_key() == "official_vanguard", "level5_headship_selects_only_authorized_pair_flag")
	for unit in battle.units:
		if is_instance_valid(unit):
			unit.hide()
	if not is_instance_valid(headship):
		_write_report(output_dir)
		await _finish(battle, null)
		return
	headship.show()
	headship.position = origin
	_configure_direction(headship, "se", "default", 2.25)
	var close_overlay := CanvasLayer.new()
	root.add_child(close_overlay)
	_add_label(close_overlay, "第八十回 · 丘岳、徐京、梅展所领先锋头船", Vector2(0, 12), Vector2(1280, 34), 22)
	_add_label(close_overlay, "两旗合书：搅海翻江冲巨浪，安邦定国灭洪妖（本作按逗号分两旗排版）", Vector2(0, 46), Vector2(1280, 28), 16, Color("b8d5e9"))
	await _capture(output_dir, "official_vanguard_level5_default_1280.png")
	headship.hide()
	close_overlay.queue_free()
	await process_frame
	var grid_overlay := CanvasLayer.new()
	root.add_child(grid_overlay)
	_add_label(grid_overlay, "先锋头船 · 真四向与四种船况 · 仅第八十回编制旗文", Vector2(0, 8), Vector2(1280, 34), 21)
	for column in DIRECTIONS.size():
		_add_label(grid_overlay, DIRECTIONS[column].to_upper(), Vector2(150 + column * 282, 47), Vector2(260, 24), 16, Color("b8d5e9"))
	for row in STATES.size():
		_add_label(grid_overlay, STATES[row], Vector2(8, 126 + row * 145), Vector2(130, 28), 15, Color("b8d5e9"))
	var art = root.get_node_or_null("Art")
	_check(art != null and art.has_method("campaign_object_texture"), "campaign_art_runtime_interface_available")
	var by_state: Dictionary = {}
	var spawned: Array = []
	for row in STATES.size():
		var state: String = STATES[row]
		for column in DIRECTIONS.size():
			var direction: String = DIRECTIONS[column]
			var unit = battle.spawn_unit("official_vanguard", 1, origin)
			_check(unit != null, "vanguard_%s_%s_spawned" % [state, direction])
			if unit == null:
				continue
			unit.position = origin + ISO_INV.basis_xform(Vector2(-405 + column * 282, -205 + row * 145))
			_configure_direction(unit, direction, state, 1.55)
			spawned.append({"unit": unit, "state": state, "direction": direction})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	for record in spawned:
		var unit = record["unit"]
		var state: String = record["state"]
		var direction: String = record["direction"]
		var expected := CampaignArt.object_direction_path("official_vanguard", state, direction)
		var texture: Texture2D = art.call("campaign_object_texture", "official_vanguard", state, direction) as Texture2D
		var source := _source(texture)
		var source_abs := ProjectSettings.globalize_path(source) if not source.is_empty() else ""
		var sha := FileAccess.get_sha256(source_abs) if not source_abs.is_empty() and FileAccess.file_exists(source_abs) else ""
		var directional := bool(art.call("campaign_object_uses_directional_source", "official_vanguard", state, direction))
		var selected := String(unit._campaign_flag_object_key())
		if not by_state.has(state):
			by_state[state] = []
		by_state[state].append(sha)
		samples.append({"state": state, "direction": direction, "expected_source": expected, "source": source, "source_sha256": sha, "uses_directional_source": directional, "unit_frame_directional": unit._frame_directional, "selected_flag_overlay_object": selected})
		_check(source == expected, "vanguard_%s_%s_exact_runtime_frame" % [state, direction], source)
		_check(directional and unit._frame_directional, "vanguard_%s_%s_uses_true_directional_renderer" % [state, direction])
		_check(selected == "official_vanguard", "vanguard_%s_%s_selects_pair_flag" % [state, direction], selected)
	for state in STATES:
		var unique: Dictionary = {}
		for sha in by_state.get(state, []):
			unique[String(sha)] = true
		_check(unique.size() == DIRECTIONS.size(), "vanguard_%s_has_four_distinct_directional_pngs" % state, JSON.stringify(unique.keys()))
	await _capture(output_dir, "official_vanguard_states_1280.png")
	for record in spawned:
		var unit = record["unit"]
		if is_instance_valid(unit):
			unit.queue_free()
	await process_frame
	grid_overlay.queue_free()
	await process_frame
	_write_report(output_dir)
	await _finish(battle, null)
