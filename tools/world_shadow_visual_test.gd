extends SceneTree
## Real-renderer evidence for the shared unit-shadow path.
## This is a visual fixture, not a combat, pacing, or human-playtest result.

const MODES := ["campaign", "arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]
var checks: Array = []
var failures: Array[String] = []
var captures: Array = []
var output_dir := ""


func _luminance(c: Color) -> float:
	return c.r * 255.0 + c.g * 255.0 + c.b * 255.0


func _frame_metrics(image: Image) -> Dictionary:
	# Sampling is intentionally coarse: this fixture needs a durable "not an
	# all-black fog frame" contract, not a benchmark or screenshot hash oracle.
	var sampled := 0
	var lit := 0
	var total_luminance := 0.0
	# Exclude the fixture label; a label must never make an all-black world pass.
	for y in range(80, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var value := _luminance(image.get_pixel(x, y))
			total_luminance += value
			sampled += 1
			if value > 30.0:
				lit += 1
	return {
		"sampled": sampled,
		"lit": lit,
		"lit_ratio": float(lit) / float(maxi(1, sampled)),
		"mean_luminance": total_luminance / float(maxi(1, sampled)),
	}


func _local_render_delta(before: Image, after: Image, battle, node: Node2D) -> Dictionary:
	# This checks the actual rendered neighbourhood of a probe, including the
	# darker ground below its feet. It does not pretend to identify a silhouette
	# from arbitrary terrain pixels; source-branch checks cover that separately.
	# Unit's global canvas transform does not include Camera2D consistently for
	# elevated campaign terrain. Battle's own map projection plus camera state is
	# the same mapping used by the renderer, so it gives a stable screen ROI.
	var anchor: Vector2 = (battle.to_screen(node.position) - battle.camera.position) * battle.camera.zoom \
		+ Vector2(before.get_width(), before.get_height()) * 0.5
	var left := clampi(int(anchor.x) - 84, 0, before.get_width() - 1)
	var right := clampi(int(anchor.x) + 84, 0, before.get_width() - 1)
	var top := clampi(int(anchor.y) - 34, 0, before.get_height() - 1)
	var bottom := clampi(int(anchor.y) + 104, 0, before.get_height() - 1)
	var changed := 0
	var darkened := 0
	var sampled := 0
	for y in range(top, bottom + 1, 2):
		for x in range(left, right + 1, 2):
			var old_lum := _luminance(before.get_pixel(x, y))
			var new_lum := _luminance(after.get_pixel(x, y))
			if absf(new_lum - old_lum) > 24.0:
				changed += 1
			if old_lum - new_lum > 18.0:
				darkened += 1
			sampled += 1
	return {
		"anchor": [roundi(anchor.x), roundi(anchor.y)],
		"sampled": sampled,
		"changed": changed,
		"darkened": darkened,
	}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	print("[world-shadow-visual] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		failures.append(name)


func _configure_mode(mode: String) -> void:
	var campaign = root.get_node("Campaign")
	campaign.arena = mode == "arena"
	campaign.skirmish = mode == "skirmish"
	campaign.skirmish_ai = mode == "skirmish_ai"
	campaign.custom_defense = mode == "custom_defense"
	campaign.scenario = mode == "scenario"
	campaign.custom_config = {"name": "阴影视图", "waves": []} if mode == "custom_defense" else {}
	campaign.scenario_data = {
		"id": "shadow_scenario", "title": "阴影视图", "subtitle": "共享阴影实机夹具",
		"map": {"w": 48, "h": 48, "theme": "marsh", "base": "GRASS"},
		"camera_start": [24, 24], "deploy": [],
		"intro": [{"who": "旁白", "key": "narrator", "text": "共享阴影视图。"}]
	} if mode == "scenario" else {}
	campaign.current = campaign.index_for_id("level5")
	campaign.ai_friendly = false
	campaign.scale_on = false


func _expected_level_id(mode: String) -> String:
	return String({
		"campaign": "level5", "arena": "arena", "skirmish": "skirmish",
		"skirmish_ai": "skirmish_ai", "custom_defense": "custom_defense",
		"scenario": "shadow_scenario",
	}.get(mode, ""))


func _mode_label(battle, mode: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var label := Label.new()
	label.text = "共享阴影实机夹具  |  %s  |  level=%s" % [mode, String(battle.level.id())]
	label.position = Vector2(18, 16)
	label.size = Vector2(620, 34)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f4ead2"))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.03, 0.94))
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)
	battle.add_child(layer)
	return layer


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _probe_cell(battle, want_slope: bool) -> Vector2i:
	var best: Vector2i = battle.map.nearest_open(battle.level.camera_start_cell(), "land")
	var best_height := -1.0
	var forest_t: int = int(battle.map.T.FOREST)
	if not want_slope:
		return best
	for y in range(battle.map.h):
		for x in range(battle.map.w):
			var cell := Vector2i(x, y)
			if not battle.map.is_open_cell(cell, "land") or int(battle.map.t_at(x, y)) == forest_t:
				continue
			var height: float = battle.map.height_at(battle.map.cell_to_world(cell))
			if height > best_height:
				best_height = height
				best = cell
	return best


func _capture_mode(mode: String) -> void:
	_configure_mode(mode)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud.hide()
	var mode_overlay := _mode_label(battle, mode)
	_check(String(battle.level.id()) == _expected_level_id(mode), mode + " constructs its own level", String(battle.level.id()))
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	for existing in battle.units:
		existing.hide()
		existing.set_process(false)
		existing.set_physics_process(false)
	var cell := _probe_cell(battle, mode == "campaign")
	battle.camera.position = battle.to_screen(battle.map.cell_to_world(cell))
	battle.camera.zoom = Vector2.ONE * 2.25
	battle.camera.force_update_scroll()
	var probe = battle.spawn_at("liang_dao", 0, cell)
	var tower = null
	_check(probe != null, mode + " probe spawned", str(cell))
	if probe != null:
		probe.visual_scale = 2.0
		probe.animation_direction = "sw"
		probe._direction_candidate = "sw"
		probe._direction_votes = 4
		probe.face_left = true
		probe.set_process(false)
		probe.set_physics_process(false)
		probe.hide()
		probe.queue_redraw()
		battle.camera.position = battle.to_screen(probe.position)
		battle.camera.zoom = Vector2.ONE * 2.25
		battle.camera.force_update_scroll()
		var world_shadow = load("res://scripts/world_shadow.gd")
		var description: Dictionary = world_shadow.describe_unit(probe)
		_check(bool(description.visible) and int(description.contact_layers) == 1 and String(description.projection) == "batched_ellipse" and bool(description.silhouette), mode + " troop receives batched contact and projection", JSON.stringify(description))
		_check(String(description.light) == "upper_left" and description.cast_offset == [3.0, 3.0], mode + " uses fixed upper-left light", JSON.stringify(description))
		var is_campaign := mode == "campaign"
		_check((battle.map.sample_scenery != null) == is_campaign, mode + " map environment route", "sample_scenery=" + str(battle.map.sample_scenery != null))
		if is_campaign:
			_check(battle.map.height_field != null and battle.map.height_at(probe.position) > 0.0 and description.ground_basis != [1.0, 0.0, 0.0, 1.0], "campaign slope basis reaches shared shadow", JSON.stringify(description))
		else:
			_check(battle.map.height_field == null and description.ground_basis == [1.0, 0.0, 0.0, 1.0], mode + " flat map uses identity shadow basis", JSON.stringify(description))
		var tower_cell: Vector2i = battle.map.nearest_open(cell + Vector2i(4, -2), "land")
		tower = battle.spawn_at("arrow_tower", 0, tower_cell)
		_check(tower != null, mode + " building probe spawned", str(tower_cell))
		if tower != null:
			tower.set_process(false)
			tower.set_physics_process(false)
			tower.hide()
			tower.queue_redraw()
			var building_description: Dictionary = world_shadow.describe_unit(tower)
			_check(bool(building_description.visible) and int(building_description.contact_layers) == 4 and bool(building_description.texture_silhouette), mode + " building keeps textured shared shadow", JSON.stringify(building_description))
	# Preserve actual fog rendering in free-play modes, but run one explicit pass
	# around the two probes because the fixture has frozen the battle loop before
	# its normal INTRO-phase fog update. This is visual evidence, not fog QA.
	if battle.fog and probe != null and tower != null:
		battle._fog_t = 0.0
		battle._fog_pass(0.0)
		battle._fog_layer.queue_redraw()
		_check(battle.is_lit_world(probe.position) and battle.is_lit_world(tower.position), mode + " fog settles around real probes", "probe=" + str(battle.map.world_to_cell(probe.position)) + " tower=" + str(battle.map.world_to_cell(tower.position)))
	await process_frame
	await RenderingServer.frame_post_draw
	var background_image: Image = root.get_texture().get_image().duplicate()
	if probe != null:
		probe.show()
		probe.queue_redraw()
	if tower != null:
		tower.show()
		tower.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if probe != null:
		var shadow_module = load("res://scripts/world_shadow.gd")
		var batch_summary: Dictionary = shadow_module.batch_summary(battle)
		_check(bool(batch_summary.get("exists", false)) and int(batch_summary.get("contact_instances", 0)) >= 1 and int(batch_summary.get("cast_instances", 0)) >= 1 and int(batch_summary.get("shapes_per_instance", 0)) == 2 and int(batch_summary.get("draw_submissions", 0)) == 1, mode + " visible troops use one paired-shape MultiMesh submission", JSON.stringify(batch_summary))
		var routes: Dictionary = shadow_module.route_summary(battle)
		_check(int(routes.get("mobile_units", 0)) >= 1 and int(routes.get("local_outline_units", 0)) >= 1 and int(routes.get("duplicate_routes", -1)) == 0 and int(routes.get("unrouted_units", -1)) == 0, mode + " mobile and local outline routes do not overlap", JSON.stringify(routes))
		if mode == "campaign":
			_check(int(routes.get("scenery_outline_anchors", 0)) > 0 and int(routes.get("scenery_static_batch_anchors", 0)) == int(routes.get("scenery_outline_anchors", -1)) and int(routes.get("scenery_local_outline_anchors", -1)) == 0 and int(routes.get("scenery_duplicate_routes", -1)) == 0, mode + " scenery anchors use one static mesh route", JSON.stringify(routes))
	var rendered_image := root.get_texture().get_image()
	var frame_metrics := _frame_metrics(rendered_image)
	_check(float(frame_metrics.lit_ratio) > 0.10, mode + " frame has real non-black map pixels", JSON.stringify(frame_metrics))
	if probe != null:
		_check(probe.visible and probe.is_visible_in_tree(), mode + " unit probe actually visible", str(probe.get_global_transform_with_canvas().origin))
		var unit_delta := _local_render_delta(background_image, rendered_image, battle, probe)
		_check(int(unit_delta.changed) >= 24 and int(unit_delta.darkened) >= 8, mode + " unit shadow-region darkens rendered map", JSON.stringify(unit_delta))
	if tower != null:
		_check(tower.visible and tower.is_visible_in_tree(), mode + " building probe actually visible", str(tower.get_global_transform_with_canvas().origin))
		var building_delta := _local_render_delta(background_image, rendered_image, battle, tower)
		_check(int(building_delta.changed) >= 24 and int(building_delta.darkened) >= 8, mode + " building shadow-region darkens rendered map", JSON.stringify(building_delta))
	var png := output_dir.path_join(mode + "_1280.png")
	var error := rendered_image.save_png(png)
	_check(error == OK and FileAccess.file_exists(png), mode + " capture written", png)
	if FileAccess.file_exists(png):
		captures.append({"mode": mode, "level_id": String(battle.level.id()), "png": png, "sha256": FileAccess.get_sha256(png), "frame_metrics": frame_metrics})
	if mode == "campaign" and battle.map.sample_scenery != null:
		var scenery = battle.map.sample_scenery
		var scenery_shadows: Array = scenery._ground_shadows
		_check(not scenery_shadows.is_empty(), "campaign scenery has static shadow anchors", "count=" + str(scenery_shadows.size()))
		if not scenery_shadows.is_empty():
			var static_batch: Dictionary = scenery.shadow_batch_summary()
			_check(bool(static_batch.get("uses_mesh_batch", false)) and bool(static_batch.get("contact_mesh", false)) and int(static_batch.get("anchors", -1)) == scenery_shadows.size() and int(static_batch.get("draw_submissions", 0)) < scenery_shadows.size() * 6, "campaign static scenery meshes retain every anchor", JSON.stringify(static_batch))
			var map_center: Vector2 = battle.map.cell_to_world(Vector2i(battle.map.w / 2, battle.map.h / 2))
			var scenic: Dictionary = scenery_shadows[0]
			var nearest_center: float = INF
			for raw in scenery_shadows:
				var candidate: Dictionary = raw
				var d2: float = (candidate.p as Vector2).distance_squared_to(map_center)
				if d2 < nearest_center:
					nearest_center = d2
					scenic = candidate
			# Node positions stay in logical coordinates; to_screen applies the same
			# terrain elevation shift as the static scenery node exactly once.
			battle.camera.position = battle.to_screen(scenic.p)
			battle.camera.zoom = Vector2.ONE * 2.0
			battle.camera.force_update_scroll()
			await process_frame
			await RenderingServer.frame_post_draw
			var scenery_png := output_dir.path_join("scenery_shadow_1280.png")
			var scenery_error := root.get_texture().get_image().save_png(scenery_png)
			_check(scenery_error == OK and FileAccess.file_exists(scenery_png), "campaign scenery shadow capture written", scenery_png)
			if FileAccess.file_exists(scenery_png):
				captures.append({"mode": "campaign_scenery", "level_id": String(battle.level.id()), "png": scenery_png, "sha256": FileAccess.get_sha256(scenery_png)})
	current_scene = null
	mode_overlay.queue_free()
	_release_battle_cursor_textures(battle)
	battle.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("world_shadow_visual_test requires a real renderer")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	output_dir = OS.get_environment("WORLD_SHADOW_VISUAL_OUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://qa/direction4_20260902/runtime_world_shadow")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0, true)
	var source := FileAccess.get_file_as_string("res://scripts/unit.gd")
	_check(source.count("WorldShadow.ensure_batch(") == 1 and source.count("WorldShadow.draw_unit(") == 1 and not source.contains(".draw_unit_shadow(self"), "unit routes mobile shadows through one shared batch", "Unit.setup creates the shared batch; Unit._draw keeps only sparse building/resource outlines")
	var scenery_source := FileAccess.get_file_as_string("res://scripts/liangshan_scenery.gd")
	_check(scenery_source.count("WorldShadow.draw_scenery_shadow(") == 1, "scenery uses one shared static-shadow entry", "static contact and cast share one owner")
	for mode in MODES:
		await _capture_mode(mode)
	var campaign = root.get_node("Campaign")
	campaign.arena = false
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.custom_defense = false
	campaign.scenario = false
	campaign.custom_config = {}
	campaign.scenario_data = {}
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"captures": captures,
		"viewport": [1280, 720],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scope": "Real renderer fixture for one normal unit and one building in campaign, arena, skirmish, AI battle, custom defense and scenario. Troops and heroes use one paired-shape MultiMesh submission for a contact ellipse plus a down-right cast ellipse; buildings retain textured projections. Fog-enabled modes receive one explicit real FogLayer pass around the probes after the fixture freezes, so this validates neither fog progression nor combat. This is not performance or human-playtest evidence.",
	}
	var path := output_dir.path_join("report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("WORLD_SHADOW_VISUAL_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
