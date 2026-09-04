extends SceneTree
## Real 1280x720 rendering evidence for the whitelist-based campaign flag layer.
## It renders the Level 5 High Qiu flagship in its four true directions beside
## ordinary official warships.  It does not modify gameplay scripts, campaign
## art, Level 5 data, pathing, combat, or save data.

const CampaignArt := preload("res://scripts/campaign_art.gd")
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const GAO_STATES := ["default", "damaged", "flooding", "disabled"]
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)


## This is intentionally separate from Unit. It proves the paint helper requires
## the exact unit/object/context route before the real Unit renderer is sampled below.
class OverlayDrawProbe extends Node2D:
	var overlay_script: Script
	var unit_key := ""
	var object_key := ""
	var context := ""
	var state := "default"
	var direction := "se"
	var visual_size := 256.0
	var exact_directional_source := true
	var drawn := false
	var draw_calls := 0

	func _draw() -> void:
		draw_calls += 1
		drawn = bool(overlay_script.call("draw_dynamic_unit", self, unit_key, object_key, context, state,
			direction, visual_size, exact_directional_source)) if overlay_script != null else false


var failures: Array[String] = []
var gates: Array = []
var checks: Array = []
var captures: Array = []
var samples: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	print("[campaign-flag-overlay-visual] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		failures.append(name)


func _gate(name: String, detail := "") -> void:
	gates.append({"name": name, "detail": detail})
	print("[campaign-flag-overlay-visual] GATE ", name, " ", detail)


func _status() -> String:
	if not failures.is_empty():
		return "failed"
	if not gates.is_empty():
		return "blocked"
	return "passed"


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _direction_path(object_key: String, state: String, direction: String) -> String:
	return "res://assets/campaign/objects/%s_%s_%s.png" % [object_key, state, direction]


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
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _release_runtime_audio() -> void:
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
		"scope": "Real Unit renderer fixture for the High Qiu command-flag overlay. It verifies the dynamic helper accepts gao_flagship in default, damaged, flooding, and disabled states while rejecting official_warship, then renders High Qiu's four directions beside generic official warships and in a four-state grid. It is not a claim about water pathing, combat, performance, generic-ship state coverage, campaign completion, or human playtesting.",
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


func _make_gate_overlay(reason: String) -> CanvasLayer:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)
	backdrop.color = Color("152338")
	overlay.add_child(backdrop)
	_add_label(overlay, "高俅座船旗文实机夹具：等待资源接口", Vector2(0, 180), Vector2(1280, 48), 28, Color("e8dfc5"))
	_add_label(overlay, reason, Vector2(90, 270), Vector2(1100, 230), 18, Color("d6b68a"))
	_add_label(overlay, "该截图只证明夹具被正确阻断；不构成旗文渲染通过。", Vector2(0, 580), Vector2(1280, 30), 16, Color("9cc8e6"))
	return overlay


func _make_runtime_overlay() -> CanvasLayer:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var top := ColorRect.new()
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 58)
	top.color = Color(0.055, 0.075, 0.095, 0.92)
	overlay.add_child(top)
	_add_label(overlay, "高俅中军船「帅」字旗 · 第八十回 · 动态旗文白名单实机", Vector2(0, 12), Vector2(1280, 36), 22)
	for column in DIRECTIONS.size():
		_add_label(overlay, DIRECTIONS[column].to_upper(), Vector2(280 + column * 230, 62), Vector2(210, 30), 17, Color("9cc8e6"))
	_add_label(overlay, "高俅座船 · 旗文应显示", Vector2(14, 205), Vector2(250, 40), 16)
	_add_label(overlay, "普通官船 · 不应显示旗文", Vector2(14, 470), Vector2(250, 40), 16)
	return overlay


func _make_state_overlay() -> CanvasLayer:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var top := ColorRect.new()
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 58)
	top.color = Color(0.055, 0.075, 0.095, 0.92)
	overlay.add_child(top)
	_add_label(overlay, "高俅中军船「帅」字旗 · 四种船况均保留旗文", Vector2(0, 12), Vector2(1280, 36), 22)
	for column in DIRECTIONS.size():
		_add_label(overlay, DIRECTIONS[column].to_upper(), Vector2(280 + column * 230, 62), Vector2(210, 30), 17, Color("9cc8e6"))
	for row in GAO_STATES.size():
		_add_label(overlay, "高俅座船 · %s" % GAO_STATES[row], Vector2(14, 155 + row * 145), Vector2(250, 40), 16)
	return overlay


func _verify_overlay_probe() -> void:
	# Delay this load until the project autoloads exist. Unit preloads this same
	# helper, and an eager preload from a bare --script fixture can compile before
	# the Art singleton is registered.
	var overlay_script = load("res://scripts/campaign_flag_overlay.gd")
	_check(overlay_script != null, "campaign_flag_overlay_script_loaded_after_autoload")
	if overlay_script == null:
		return
	var gao_probes: Array = []
	for state in GAO_STATES:
		var gao_probe := OverlayDrawProbe.new()
		gao_probe.overlay_script = overlay_script
		gao_probe.unit_key = "gao_flagship"
		gao_probe.object_key = "gao_flagship"
		gao_probe.context = "chapter80_gao_flagship"
		gao_probe.state = state
		gao_probe.direction = "se"
		gao_probe.position = Vector2(8, 455)
		root.add_child(gao_probe)
		gao_probe.queue_redraw()
		gao_probes.append(gao_probe)
	var wrong_gao_probe := OverlayDrawProbe.new()
	wrong_gao_probe.overlay_script = overlay_script
	wrong_gao_probe.unit_key = "gao_flagship"
	wrong_gao_probe.object_key = "gao_flagship"
	wrong_gao_probe.context = ""
	wrong_gao_probe.state = "default"
	wrong_gao_probe.direction = "se"
	wrong_gao_probe.position = Vector2(8, 455)
	root.add_child(wrong_gao_probe)
	wrong_gao_probe.queue_redraw()
	var official_probe := OverlayDrawProbe.new()
	official_probe.overlay_script = overlay_script
	official_probe.unit_key = "imperial_warship"
	official_probe.object_key = "official_warship"
	official_probe.state = "default"
	official_probe.direction = "se"
	official_probe.position = Vector2(8, 455)
	root.add_child(official_probe)
	official_probe.queue_redraw()
	var vanguard_probe := OverlayDrawProbe.new()
	vanguard_probe.overlay_script = overlay_script
	vanguard_probe.unit_key = "official_vanguard"
	vanguard_probe.object_key = "official_vanguard"
	vanguard_probe.context = "chapter80_vanguard_headship"
	vanguard_probe.state = "default"
	vanguard_probe.direction = "se"
	vanguard_probe.position = Vector2(320, 455)
	root.add_child(vanguard_probe)
	vanguard_probe.queue_redraw()
	var wrong_vanguard_probe := OverlayDrawProbe.new()
	wrong_vanguard_probe.overlay_script = overlay_script
	wrong_vanguard_probe.unit_key = "official_vanguard"
	wrong_vanguard_probe.object_key = "official_vanguard"
	wrong_vanguard_probe.context = ""
	wrong_vanguard_probe.state = "default"
	wrong_vanguard_probe.direction = "se"
	wrong_vanguard_probe.position = Vector2(320, 455)
	root.add_child(wrong_vanguard_probe)
	wrong_vanguard_probe.queue_redraw()
	await process_frame
	await process_frame
	for gao_probe in gao_probes:
		_check(gao_probe.draw_calls > 0 and gao_probe.drawn, "dynamic_helper_draws_gao_command_flag_%s" % gao_probe.state, "calls=%s drawn=%s" % [gao_probe.draw_calls, gao_probe.drawn])
	_check(wrong_gao_probe.draw_calls > 0 and not wrong_gao_probe.drawn, "dynamic_helper_rejects_gao_without_context", "calls=%s drawn=%s" % [wrong_gao_probe.draw_calls, wrong_gao_probe.drawn])
	_check(official_probe.draw_calls > 0 and not official_probe.drawn, "dynamic_helper_rejects_generic_official_ship", "calls=%s drawn=%s" % [official_probe.draw_calls, official_probe.drawn])
	_check(vanguard_probe.draw_calls > 0 and vanguard_probe.drawn, "dynamic_helper_draws_chapter80_vanguard_pair", "calls=%s drawn=%s" % [vanguard_probe.draw_calls, vanguard_probe.drawn])
	_check(wrong_vanguard_probe.draw_calls > 0 and not wrong_vanguard_probe.drawn, "dynamic_helper_rejects_vanguard_without_context", "calls=%s drawn=%s" % [wrong_vanguard_probe.draw_calls, wrong_vanguard_probe.drawn])
	for gao_probe in gao_probes:
		gao_probe.queue_free()
	wrong_gao_probe.queue_free()
	official_probe.queue_free()
	vanguard_probe.queue_free()
	wrong_vanguard_probe.queue_free()
	await process_frame


func _capture_gao_state_grid(battle, art, origin: Vector2, output_dir: String) -> void:
	var overlay := _make_state_overlay()
	var spawned: Array = []
	for row in GAO_STATES.size():
		var state: String = GAO_STATES[row]
		for column in DIRECTIONS.size():
			var direction: String = DIRECTIONS[column]
			var unit = battle.spawn_unit("gao_flagship", 1, origin)
			_check(unit != null, "gao_%s_%s_state_grid_spawned" % [state, direction])
			if unit == null:
				continue
			unit.position = origin + ISO_INV.basis_xform(Vector2(-300 + column * 230, -190 + row * 145))
			unit.animation_direction = direction
			unit._direction_candidate = direction
			unit._direction_votes = 4
			unit.face_left = direction in ["sw", "nw"]
			unit.visual_scale = 0.80
			unit.set_meta("ship_state", state)
			unit.set_meta("campaign_flag_context", "chapter80_gao_flagship")
			unit.set_process(false)
			unit.set_physics_process(false)
			unit.queue_redraw()
			spawned.append({"unit": unit, "state": state, "direction": direction})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var hashes_by_state: Dictionary = {}
	for record in spawned:
		var unit = record["unit"]
		if not is_instance_valid(unit):
			_check(false, "gao_state_grid_instance_survived_render", String(record))
			continue
		var state: String = record["state"]
		var direction: String = record["direction"]
		var expected_source := _direction_path("gao_flagship", state, direction)
		var texture: Texture2D = art.call("campaign_object_texture", "gao_flagship", state, direction) as Texture2D
		var source := _source(texture)
		var source_abs := ProjectSettings.globalize_path(source) if not source.is_empty() else ""
		var source_sha := FileAccess.get_sha256(source_abs) if not source_abs.is_empty() and FileAccess.file_exists(source_abs) else ""
		var uses_directional := bool(art.call("campaign_object_uses_directional_source", "gao_flagship", state, direction))
		var selected_overlay: String = String(unit._campaign_flag_object_key())
		if not hashes_by_state.has(state):
			hashes_by_state[state] = []
		hashes_by_state[state].append(source_sha)
		samples.append({"object_key": "gao_flagship", "state": state, "direction": direction, "expected_source": expected_source, "source": source, "source_sha256": source_sha, "uses_directional_source": uses_directional, "unit_frame_directional": unit._frame_directional, "selected_flag_overlay_object": selected_overlay, "fixture": "four_state_grid"})
		_check(source == expected_source, "gao_%s_%s_exact_runtime_frame" % [state, direction], source)
		_check(uses_directional, "gao_%s_%s_uses_true_directional_source" % [state, direction], str(uses_directional))
		_check(unit._frame_directional, "gao_%s_%s_renderer_disables_mirroring" % [state, direction], str(unit._frame_directional))
		_check(selected_overlay == "gao_flagship", "gao_%s_%s_unit_selects_command_overlay" % [state, direction], selected_overlay)
	for state in GAO_STATES:
		var unique_hashes: Dictionary = {}
		for source_sha in hashes_by_state.get(state, []):
			unique_hashes[String(source_sha)] = true
		_check(unique_hashes.size() == DIRECTIONS.size(), "gao_%s_four_distinct_directional_pngs" % state, JSON.stringify(unique_hashes.keys()))
	await _capture(output_dir, "campaign_flag_overlay_states_1280.png")
	for record in spawned:
		var unit = record["unit"]
		if is_instance_valid(unit):
			unit.queue_free()
	await process_frame
	overlay.queue_free()
	await process_frame


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
		push_error("campaign_flag_overlay_visual_test requires a real renderer")
		await _release_runtime_audio()
		await process_frame
		quit(2)
		return
	var output_dir := OS.get_environment("CAMPAIGN_FLAG_OVERLAY_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/direction4_20260901/runtime_campaign_flag_overlay")
	DirAccess.make_dir_recursive_absolute(output_dir)
	OS.set_environment("CAMPAIGN_QA", "1")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	_check(String(CampaignArt.dynamic_flag_route("gao_flagship", "gao_flagship", "chapter80_gao_flagship").get("overlay_id", "")) == "gao_flagship_command"
		and CampaignArt.dynamic_flag_route("gao_flagship", "gao_flagship", "").is_empty(), "gao_flagship_requires_explicit_unit_object_context_route")
	_check(CampaignArt.dynamic_flag_route("imperial_warship", "official_warship", "").is_empty(), "official_warship_has_no_dynamic_flag_route")
	_check(String(CampaignArt.dynamic_flag_route("official_vanguard", "official_vanguard", "chapter80_vanguard_headship").get("overlay_id", "")) == "official_vanguard_red_pair"
		and CampaignArt.dynamic_flag_route("official_vanguard", "official_vanguard", "").is_empty(), "vanguard_pair_requires_chapter80_context")
	await _verify_overlay_probe()
	if not failures.is_empty():
		var early_overlay := _make_gate_overlay("\n".join(failures))
		await _capture(output_dir, "gate_1280.png")
		var early_report := _write_report(output_dir)
		print("CAMPAIGN_FLAG_OVERLAY_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": early_report, "failures": failures}))
		await _finish(null, early_overlay, 1)
		return
	var art = root.get_node_or_null("Art")
	if art == null or not art.has_method("campaign_object_texture") or not art.has_method("campaign_object_uses_directional_source"):
		_gate("campaign_object_interface_missing", "/root/Art")
		var blocked := _make_gate_overlay("campaign_object_interface_missing\n/root/Art")
		await _capture(output_dir, "gate_1280.png")
		var blocked_report := _write_report(output_dir)
		print("CAMPAIGN_FLAG_OVERLAY_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": blocked_report, "gates": gates, "failures": failures}))
		await _finish(null, blocked, 2)
		return
	var campaign = root.get_node_or_null("Campaign")
	if campaign == null:
		_gate("campaign_autoload_missing", "/root/Campaign")
		var campaign_blocked := _make_gate_overlay("campaign_autoload_missing\n/root/Campaign")
		await _capture(output_dir, "gate_1280.png")
		var campaign_report := _write_report(output_dir)
		print("CAMPAIGN_FLAG_OVERLAY_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": campaign_report, "gates": gates, "failures": failures}))
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
	# Static shore scenery may otherwise completely cover a flag fixture slot.
	# Hide only that layer; the temporary ships still draw through the real map,
	# unit renderer, campaign-object texture and overlay paths.
	if battle.map.sample_scenery != null:
		battle.map.sample_scenery.hide()
	for key in ["gao_flagship", "imperial_warship"]:
		_check(battle._defs.has(key), "%s_level5_definition_present" % key)
	var water_cell: Vector2i = battle.map.nearest_open(Vector2i(42, 40), "water")
	_check(water_cell.x >= 0, "level5_has_water_spawn_cell", str(water_cell))
	if water_cell.x < 0:
		var no_water_overlay := _make_gate_overlay("level5_has_water_spawn_cell\n动态战船没有可用水面出生点")
		await _capture(output_dir, "gate_1280.png")
		var no_water_report := _write_report(output_dir)
		print("CAMPAIGN_FLAG_OVERLAY_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": no_water_report, "gates": gates, "failures": failures}))
		await _finish(battle, no_water_overlay, 1)
		return
	var origin: Vector2 = battle.map.cell_to_world(water_cell)
	battle.camera.position = battle.to_screen(origin)
	battle.camera.zoom = Vector2.ONE
	battle.camera.force_update_scroll()
	var overlay := _make_runtime_overlay()
	var spawned: Array = []
	for row in 2:
		var key := "gao_flagship" if row == 0 else "imperial_warship"
		var object_key := "gao_flagship" if row == 0 else "official_warship"
		for column in DIRECTIONS.size():
			var direction: String = DIRECTIONS[column]
			var unit = battle.spawn_unit(key, 1, origin)
			_check(unit != null, "%s_%s_spawned" % [object_key, direction])
			if unit == null:
				continue
			unit.position = origin + ISO_INV.basis_xform(Vector2(-300 + column * 230, -125 + row * 265))
			unit.animation_direction = direction
			unit._direction_candidate = direction
			unit._direction_votes = 4
			unit.face_left = direction in ["sw", "nw"]
			unit.visual_scale = 1.12
			unit.set_meta("ship_state", "default")
			if object_key == "gao_flagship":
				unit.set_meta("campaign_flag_context", "chapter80_gao_flagship")
			unit.set_process(false)
			unit.set_physics_process(false)
			unit.queue_redraw()
			spawned.append({"unit": unit, "object_key": object_key, "direction": direction})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var hashes_by_object: Dictionary = {}
	for record in spawned:
		var unit = record["unit"]
		if not is_instance_valid(unit):
			_check(false, "ship_instance_survived_render", String(record))
			continue
		var object_key: String = record["object_key"]
		var direction: String = record["direction"]
		var expected_source := _direction_path(object_key, "default", direction)
		var texture: Texture2D = art.call("campaign_object_texture", object_key, "default", direction) as Texture2D
		var source := _source(texture)
		var source_abs := ProjectSettings.globalize_path(source) if not source.is_empty() else ""
		var source_sha := FileAccess.get_sha256(source_abs) if not source_abs.is_empty() and FileAccess.file_exists(source_abs) else ""
		var uses_directional := bool(art.call("campaign_object_uses_directional_source", object_key, "default", direction))
		var selected_overlay: String = String(unit._campaign_flag_object_key())
		if not hashes_by_object.has(object_key):
			hashes_by_object[object_key] = []
		hashes_by_object[object_key].append(source_sha)
		samples.append({"object_key": object_key, "direction": direction, "expected_source": expected_source, "source": source, "source_sha256": source_sha, "uses_directional_source": uses_directional, "unit_frame_directional": unit._frame_directional, "selected_flag_overlay_object": selected_overlay})
		_check(source == expected_source, "%s_%s_exact_runtime_frame" % [object_key, direction], source)
		_check(uses_directional, "%s_%s_uses_true_directional_source" % [object_key, direction], str(uses_directional))
		_check(unit._frame_directional, "%s_%s_renderer_disables_mirroring" % [object_key, direction], str(unit._frame_directional))
		if object_key == "gao_flagship":
			_check(selected_overlay == "gao_flagship", "gao_%s_unit_selects_command_overlay" % direction, selected_overlay)
		else:
			_check(selected_overlay.is_empty(), "official_%s_unit_does_not_select_command_overlay" % direction, selected_overlay)
	for object_key in ["gao_flagship", "official_warship"]:
		var unique_hashes: Dictionary = {}
		for source_sha in hashes_by_object.get(object_key, []):
			unique_hashes[String(source_sha)] = true
		_check(unique_hashes.size() == DIRECTIONS.size(), "%s_four_distinct_directional_pngs" % object_key, JSON.stringify(unique_hashes.keys()))
	await _capture(output_dir, "campaign_flag_overlay_1280.png")
	for record in spawned:
		var unit = record["unit"]
		if is_instance_valid(unit):
			unit.queue_free()
	await process_frame
	overlay.queue_free()
	await process_frame
	await _capture_gao_state_grid(battle, art, origin, output_dir)
	var report_path := _write_report(output_dir)
	print("CAMPAIGN_FLAG_OVERLAY_VISUAL_RESULT ", JSON.stringify({"status": _status(), "report": report_path, "gates": gates, "failures": failures, "checks": checks.size()}))
	await _finish(battle, null, 0 if _status() == "passed" else 1)
