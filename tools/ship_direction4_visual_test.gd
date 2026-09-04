extends SceneTree
## Real 1280x720 renderer fixture for the dynamic water-vessel direction contract.
## It covers the Level 5 ship definitions after their campaign-object direction
## interface and web-authored PNGs are present. It is visual evidence only: it
## does not claim water pathing, combat, performance, campaign completion, or a
## complete ship-action set.

const DIRECTIONS := ["se", "sw", "ne", "nw"]
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)
const ROWS := [
	{"label":"梁山战船 · default", "key":"liangshan_warship", "object_key":"liangshan_boat", "state":"default", "directional":true},
	{"label":"官军战船 · default", "key":"imperial_warship", "object_key":"official_warship", "state":"default", "directional":true},
	{"label":"官军战船 · damaged", "key":"imperial_warship", "object_key":"official_warship", "state":"damaged", "directional":true},
	{"label":"官军战船 · flooding", "key":"imperial_warship", "object_key":"official_warship", "state":"flooding", "directional":true},
	{"label":"官军战船 · disabled（旧图回退）", "key":"imperial_warship", "object_key":"official_warship", "state":"disabled", "directional":false},
]

var failures: Array[String] = []
var gates: Array = []
var checks: Array = []
var captures: Array = []
var samples: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	print("[ship-direction4-visual] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		failures.append(name)


func _gate(name: String, detail := "") -> void:
	gates.append({"name": name, "detail": detail})
	print("[ship-direction4-visual] GATE ", name, " ", detail)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _direction_path(object_key: String, state: String, direction: String) -> String:
	return "res://assets/campaign/objects/%s_%s_%s.png" % [object_key, state, direction]


func _legacy_path(object_key: String, state: String) -> String:
	return "res://assets/campaign/objects/%s_%s.png" % [object_key, state]


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


func _release_battle_cursor_textures(battle) -> void:
	# Battle registers generated ImageTexture cursors with process-global Input.
	# Release both sides before the temporary Battle is freed to avoid ObjectDB/RID
	# warnings at renderer shutdown.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _release_runtime_audio() -> void:
	# The project synthesizes WAVs in global Music/Sfx at startup. Stop player
	# backends and clear their stream references after the background music worker
	# has joined, otherwise a short visual fixture can leave AudioStreamWAV/RID
	# objects alive while the renderer shuts down.
	var music = root.get_node_or_null("Music")
	if music != null:
		music.set_process(false)
		var music_thread = music.get("_thr")
		if music_thread is Thread and music_thread.is_started():
			music_thread.wait_to_finish()
		await process_frame
		for property in ["_p_calm", "_p_battle"]:
			var player = music.get(property)
			if player is AudioStreamPlayer:
				player.stop()
				player.stream = null
				player.queue_free()
			music.set(property, null)
		music.set("_tracks", {"calm": [], "battle": []})
	var sfx = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.set_process(false)
		var players: Array = sfx.get("_players")
		for player in players:
			if player is AudioStreamPlayer:
				player.stop()
				player.stream = null
				player.queue_free()
		sfx.set("_bank", {})
		sfx.set("_players", [])
	await process_frame


func _status() -> String:
	if not failures.is_empty():
		return "failed"
	if not gates.is_empty():
		return "blocked"
	return "passed"


func _write_report(output_dir: String) -> String:
	var report := {
		"status": _status(),
		"passed": failures.is_empty() and gates.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"gates": gates,
		"captures": captures,
		"samples": samples,
		"viewport": [1280, 720],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real Unit renderer fixture for Level 5 dynamic water vessels. It verifies four exact campaign-object direction files for Liangshan default and official default/damaged/flooding. Official disabled is deliberately required to use the old state file and retain legacy mirror eligibility. No water-pathing, combat, performance, complete-action, full-roster, or human-playtest claim.",
	}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_check(false, "report_written", report_path)
		return report_path
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	_check(FileAccess.file_exists(report_path), "report_written", report_path)
	return report_path


func _capture(output_dir: String, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := output_dir.path_join(name)
	var error := root.get_texture().get_image().save_png(output)
	_check(error == OK and FileAccess.file_exists(output), name + "_written", output)
	if error == OK and FileAccess.file_exists(output):
		captures.append({"png": output, "sha256": FileAccess.get_sha256(output)})


func _verify_interface_and_art(art) -> void:
	if art == null:
		_gate("art_autoload_missing", "/root/Art")
		return
	for method_name in ["campaign_object_texture", "campaign_object_uses_directional_source"]:
		if not art.has_method(method_name):
			_gate("campaign_object_direction_interface_missing", method_name)
	if not gates.is_empty():
		return
	for spec in ROWS:
		var object_key := String(spec["object_key"])
		var state := String(spec["state"])
		if bool(spec["directional"]):
			for direction in DIRECTIONS:
				var expected := _direction_path(object_key, state, direction)
				if not ResourceLoader.exists(expected):
					_gate("directional_ship_asset_missing", expected)
		else:
			var legacy := _legacy_path(object_key, state)
			if not ResourceLoader.exists(legacy):
				_gate("disabled_legacy_ship_asset_missing", legacy)
			for direction in DIRECTIONS:
				var unexpected := _direction_path(object_key, state, direction)
				_check(not ResourceLoader.exists(unexpected), "disabled_%s_remains_legacy_only" % direction, unexpected)


func _make_gate_overlay(reason: String) -> CanvasLayer:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)
	backdrop.color = Color("152338")
	overlay.add_child(backdrop)
	_add_label(overlay, "战船四向实机夹具：等待资源接口", Vector2(0, 180), Vector2(1280, 48), 28, Color("e8dfc5"))
	_add_label(overlay, reason, Vector2(90, 270), Vector2(1100, 230), 18, Color("d6b68a"))
	_add_label(overlay, "该截图只证明夹具被正确阻断；并不构成战船四向美术通过。", Vector2(0, 580), Vector2(1280, 30), 16, Color("9cc8e6"))
	return overlay


func _make_runtime_overlay() -> Dictionary:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var top := ColorRect.new()
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 56)
	top.color = Color(0.055, 0.075, 0.095, 0.92)
	overlay.add_child(top)
	var title := _add_label(overlay, "动态战船四向实机 · 三败高太尉 · campaign_object", Vector2(0, 13), Vector2(1280, 34), 22)
	for column in DIRECTIONS.size():
		_add_label(overlay, DIRECTIONS[column].to_upper(), Vector2(290 + column * 220, 60), Vector2(200, 28), 17, Color("9cc8e6"))
	for row in ROWS.size():
		_add_label(overlay, String(ROWS[row]["label"]), Vector2(16, 150 + row * 103), Vector2(255, 48), 16)
	return {"overlay": overlay, "title": title}


func _finish(battle, overlay, exit_code: int) -> void:
	current_scene = null
	if battle != null and is_instance_valid(battle):
		_release_battle_cursor_textures(battle)
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
	await process_frame
	await process_frame
	await _release_runtime_audio()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(exit_code)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("ship_direction4_visual_test requires a real renderer")
		await _release_runtime_audio()
		await process_frame
		quit(2)
		return
	var output_dir := OS.get_environment("SHIP_DIRECTION4_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/direction4_20260901/runtime_ship_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	OS.set_environment("CAMPAIGN_QA", "1")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	var art = root.get_node_or_null("Art")
	_verify_interface_and_art(art)
	if not gates.is_empty():
		var blocked := _make_gate_overlay("\n".join(gates.map(func(g): return String(g["name"]) + "\n" + String(g["detail"]))))
		await _capture(output_dir, "gate_1280.png")
		var blocked_report := _write_report(output_dir)
		print("SHIP_DIRECTION4_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": blocked_report, "gates": gates, "failures": failures}))
		await _finish(null, blocked, 2)
		return

	var campaign = root.get_node_or_null("Campaign")
	if campaign == null:
		_gate("campaign_autoload_missing", "/root/Campaign")
		var campaign_blocked := _make_gate_overlay("campaign_autoload_missing\n/root/Campaign")
		await _capture(output_dir, "gate_1280.png")
		var campaign_report := _write_report(output_dir)
		print("SHIP_DIRECTION4_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": campaign_report, "gates": gates, "failures": failures}))
		await _finish(null, campaign_blocked, 2)
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
	for existing in battle.units:
		existing.hide()
		existing.set_process(false)
		existing.set_physics_process(false)
	# The authored Level 5 shore objects are useful in play, but a tower or dock can
	# fully cover one fixture slot. Hide only that scenery layer so every test ship
	# remains visually inspectable against the real map and real Unit renderer.
	if battle.map.sample_scenery != null:
		battle.map.sample_scenery.hide()
	for key in ["liangshan_warship", "imperial_warship"]:
		_check(battle._defs.has(key), "%s_level5_definition_present" % key)
	var water_cell: Vector2i = battle.map.nearest_open(Vector2i(42, 40), "water")
	_check(water_cell.x >= 0, "level5_has_water_spawn_cell", str(water_cell))
	if water_cell.x < 0:
		var no_water_overlay := _make_gate_overlay("level5_has_water_spawn_cell\n动态战船没有可用水面出生点")
		await _capture(output_dir, "gate_1280.png")
		var no_water_report := _write_report(output_dir)
		print("SHIP_DIRECTION4_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": no_water_report, "gates": gates, "failures": failures}))
		await _finish(battle, no_water_overlay, 1)
		return
	var origin: Vector2 = battle.map.cell_to_world(water_cell)
	battle.camera.position = battle.to_screen(origin)
	battle.camera.zoom = Vector2.ONE
	battle.camera.force_update_scroll()
	var ui := _make_runtime_overlay()
	var overlay: CanvasLayer = ui["overlay"]
	var spawned: Array = []
	var hashes_by_row: Dictionary = {}
	for row in ROWS.size():
		var spec: Dictionary = ROWS[row]
		var key := String(spec["key"])
		var object_key := String(spec["object_key"])
		var state := String(spec["state"])
		for column in DIRECTIONS.size():
			var direction: String = DIRECTIONS[column]
			var unit = battle.spawn_unit(key, 0, origin)
			_check(unit != null, "%s_%s_spawned" % [state, direction])
			if unit == null:
				continue
			unit.position = origin + ISO_INV.basis_xform(Vector2(-270 + column * 220, -190 + row * 103))
			unit.animation_direction = direction
			unit._direction_candidate = direction
			unit._direction_votes = 4
			unit.face_left = direction in ["sw", "nw"]
			unit.visual_scale = 1.15
			unit.set_meta("ship_state", state)
			unit.set_process(false)
			unit.set_physics_process(false)
			unit.queue_redraw()
			spawned.append({"unit": unit, "object_key": object_key, "state": state, "direction": direction, "directional": bool(spec["directional"])})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	for record in spawned:
		var unit = record["unit"]
		if not is_instance_valid(unit):
			_check(false, "ship_instance_survived_render", String(record))
			continue
		var object_key := String(record["object_key"])
		var state := String(record["state"])
		var direction := String(record["direction"])
		var expected_directional := bool(record["directional"])
		var texture: Texture2D = art.call("campaign_object_texture", object_key, state, direction) as Texture2D
		var source := _source(texture)
		var source_abs := ProjectSettings.globalize_path(source) if not source.is_empty() else ""
		var source_sha := FileAccess.get_sha256(source_abs) if not source_abs.is_empty() and FileAccess.file_exists(source_abs) else ""
		var uses_directional := bool(art.call("campaign_object_uses_directional_source", object_key, state, direction))
		var expected_source := _direction_path(object_key, state, direction) if expected_directional else _legacy_path(object_key, state)
		var row_id := object_key + "_" + state
		if not hashes_by_row.has(row_id):
			hashes_by_row[row_id] = []
		hashes_by_row[row_id].append(source_sha)
		samples.append({"object_key": object_key, "state": state, "direction": direction, "expected_source": expected_source, "source": source, "source_sha256": source_sha, "uses_directional_source": uses_directional, "unit_frame_directional": unit._frame_directional, "face_left": unit.face_left})
		_check(source == expected_source, "%s_%s_%s_exact_runtime_frame" % [object_key, state, direction], source)
		_check(uses_directional == expected_directional, "%s_%s_%s_direction_source_contract" % [object_key, state, direction], str(uses_directional))
		_check(unit._frame_directional == expected_directional, "%s_%s_%s_renderer_mirror_contract" % [object_key, state, direction], str(unit._frame_directional))
		if not expected_directional and direction in ["sw", "nw"]:
			_check(unit.face_left and not unit._frame_directional, "disabled_%s_keeps_legacy_mirror_eligibility" % direction, "face_left=%s directional=%s" % [unit.face_left, unit._frame_directional])
	for spec in ROWS:
		var row_id := String(spec["object_key"]) + "_" + String(spec["state"])
		var unique_hashes: Dictionary = {}
		for source_sha in hashes_by_row.get(row_id, []):
			unique_hashes[String(source_sha)] = true
		var expected_hash_count := DIRECTIONS.size() if bool(spec["directional"]) else 1
		_check(unique_hashes.size() == expected_hash_count, "%s_source_byte_contract" % row_id, JSON.stringify(unique_hashes.keys()))
	await _capture(output_dir, "ships_1280.png")
	for record in spawned:
		var unit = record["unit"]
		if is_instance_valid(unit):
			unit.queue_free()
	await process_frame
	var report_path := _write_report(output_dir)
	print("SHIP_DIRECTION4_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": report_path, "gates": gates, "failures": failures, "checks": checks.size()}))
	await _finish(battle, overlay, 0 if _status() == "passed" else 1)
