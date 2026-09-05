extends "res://tools/environment_field_render_qa.gd"

func _probe_capture(b, label: String, repair: bool, alpha_view: bool) -> Dictionary:
	b.map.material.set_shader_parameter("qa_restore_primitive_alpha", repair)
	b.map.material.set_shader_parameter("qa_show_atlas_alpha", alpha_view)
	for i in range(10): await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := output.path_join(label + ".png")
	check(img.save_png(path) == OK, label + " saved")
	return {"file":label + ".png", "pixels_sha256":img.get_data().hex_encode().sha256_text(), "file_sha256":FileAccess.get_sha256(path)}

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN", "1")
	output = ProjectSettings.globalize_path("res://.godot/terrain_seam_probe")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	Engine.max_fps = 60
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	var b = await _start("level3")
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.hud.hide()
	if b._fog_layer != null: b._fog_layer.hide()
	b.camera.position = b.to_screen(b.map.cell_to_world(_field_cell(b.map)))
	b.camera.zoom = Vector2.ONE * 1.5
	b.camera.force_update_scroll()
	var source := FileAccess.get_file_as_string("res://tools/contracts/terrain_seams/before_661e8d1.gdshader")
	source = source.replace("varying vec2 ground_position;", "varying vec2 ground_position;\nvarying float qa_primitive_alpha;\nuniform bool qa_restore_primitive_alpha = false;\nuniform bool qa_show_atlas_alpha = false;")
	source = source.replace("ground_position = VERTEX;", "ground_position = VERTEX;\n\tqa_primitive_alpha = COLOR.a;")
	source = source.replace("void fragment() {", "void fragment() {\n\tfloat qa_atlas_alpha = COLOR.a;\n\tif (qa_restore_primitive_alpha && natural_surface_enabled) { COLOR.a = qa_primitive_alpha; }")
	source = source.replace("COLOR.rgb *= scene_tint.rgb;", "COLOR.rgb *= scene_tint.rgb;\n\tif (qa_show_atlas_alpha) { COLOR = vec4(vec3(qa_atlas_alpha), 1.0); }")
	var shader := Shader.new()
	shader.code = source
	b.map.material.shader = shader
	report.samples.append(await _probe_capture(b,"scene_before",false,false))
	report.samples.append(await _probe_capture(b,"scene_after",true,false))
	for child in b.get_children():
		if child not in [b.world,b.camera] and (child is CanvasItem or child is CanvasLayer): child.hide()
	for child in b.world.get_children():
		if child != b.map and child is CanvasItem: child.hide()
	for child in b.map.get_children():
		if child is CanvasItem: child.hide()
	report.samples.append(await _probe_capture(b,"terrain_before",false,false))
	report.samples.append(await _probe_capture(b,"terrain_after",true,false))
	report.samples.append(await _probe_capture(b,"atlas_alpha",false,true))
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
