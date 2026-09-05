extends "res://tools/campaign_mode_performance_test.gd"
## Real-render comparison of the field sampler only; no simulated victory or performance claim.
const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")

func _terrain_state(map) -> Dictionary:
	var surfaces: Dictionary = map.natural_surface_maps()
	return {
		"grid": map.grid.to_byte_array().hex_encode().sha256_text(),
		"solid": map._base_solid.hex_encode().sha256_text(),
		"blocks": map._block_count.to_byte_array().hex_encode().sha256_text(),
		"height": map.height_field.samples.to_byte_array().hex_encode().sha256_text() if map.height_field != null else "flat",
		"weights": surfaces.weight_sha256, "land": surfaces.land_sha256,
	}

func _field_cell(map) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -1
	var best_distance := INF
	var center := Vector2(map.w * 0.5, map.h * 0.5)
	for y in range(3, map.h - 3):
		for x in range(3, map.w - 3):
			if map.t_at(x, y) != map.T.FIELD: continue
			var score := 0
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if map.t_at(x + dx, y + dy) == map.T.FIELD: score += 1
			var distance := Vector2(x, y).distance_squared_to(center)
			if score > best_score or (score == best_score and distance < best_distance):
				best_score = score
				best_distance = distance
				best = Vector2i(x, y)
	return best

func _capture(b, label: String, zoom: float, enabled: bool) -> Dictionary:
	b.map.material.set_shader_parameter("use_surface_field_texture", enabled)
	b.camera.zoom = Vector2.ONE * zoom
	b.camera.force_update_scroll()
	for i in range(8): await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := output.path_join(label + ".png")
	check(img.save_png(path) == OK, label + " screenshot saved")
	return {"file": label + ".png", "pixels_sha256": img.get_data().hex_encode().sha256_text(),
		"file_sha256": FileAccess.get_sha256(path), "size": [img.get_width(), img.get_height()], "zoom": zoom, "field_enabled": enabled}

func _sample_field(id: String) -> void:
	var b = await _start(id)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.hud.hide()
	if b._fog_layer != null: b._fog_layer.hide()
	var cell := _field_cell(b.map)
	check(cell.x >= 0, id + " authored map contains field terrain")
	b.camera.position = b.to_screen(b.map.cell_to_world(cell))
	var initial := _terrain_state(b.map)
	var routed: Dictionary = b.map.get_meta("natural_surface_contract", {}).get("routed_surfaces", {}).get("surface_field", {})
	check(routed.get("loaded", false) and routed.get("sampling_mode") == "map_clamped" and not routed.get("repeat_enabled", true), id + " loads clamped field texture without repetition")
	var tex = b.map.material.get_shader_parameter("surface_field_texture")
	check(tex != null and tex.get_size() == Vector2(1254, 1254), id + " preserves native source resolution")
	var captures := []
	for zoom in [1.0, 1.5]:
		var label: String = id + "_" + str(int(zoom * 100))
		var before := await _capture(b, label + "_before", zoom, false)
		var after := await _capture(b, label + "_after", zoom, true)
		var restored := await _capture(b, label + "_restored", zoom, false)
		check(before.pixels_sha256 != after.pixels_sha256, label + " field texture changes actual rendered pixels")
		check(before.pixels_sha256 == restored.pixels_sha256, label + " restored sampler reproduces identical pixels")
		check(before.size == [1280, 720] and after.size == [1280, 720], label + " viewport is 1280x720")
		captures.append({"before": before, "after": after, "restored": restored})
	check(_terrain_state(b.map) == initial, id + " sampler toggle preserves terrain collision height and masks")
	report.samples.append({"level": id, "camera_cell": [cell.x, cell.y], "terrain_state": initial, "routed": routed, "captures": captures})
	await _dispose(b, true)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Real renderer required")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN", "1")
	output = ProjectSettings.globalize_path("res://.godot/environment_field_qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	Engine.max_fps = 60
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	AudioServer.set_bus_mute(0, true)
	var save_before := _save_hash()
	report["scope"] = "field-only sampler toggle in frozen authored level3/level8 scenes at 100/150%; HUD and fog overlay hidden; no combat or performance approval"
	report["renderer"] = {"adapter": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(), "method": RenderingServer.get_current_rendering_method()}
	for id in ["level1", "level2", "level4", "level5", "level6", "level7", "arena", "skirmish"]:
		check(EnvironmentArt.surface(id, "surface_field") == null, id + " cannot resolve field texture")
	for id in ["level3", "level8"]: await _sample_field(id)
	check(report.samples.size() == 2, "both requested scenes completed all capture pairs")
	check(_save_hash() == save_before, "campaign save unchanged")
	report["save_before"] = save_before
	report["save_after"] = _save_hash()
	report["passed"] = failures.is_empty()
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[field-render-result] ", JSON.stringify({"passed": failures.is_empty(), "checks": report.mode_checks.size(), "failures": failures, "output": output}))
	quit(0 if failures.is_empty() else 1)
