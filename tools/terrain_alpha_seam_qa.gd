extends "res://tools/environment_field_render_qa.gd"
## Real pixels and alpha, not a text-only check of shader implementation.
const OLD_SHADER := "res://tools/contracts/terrain_seams/before_661e8d1.gdshader"
const OLD_SHADER_SHA := "5719a11adb1504b7b9b0ab9edbd713e9eb588a3916e6e101e597cebc4e1adabf"
const CAMERAS := {"level1":Vector2i(22,20), "level2":Vector2i(27,23),
	"level4":Vector2i(20,40), "level5":Vector2i(17,38),
	"level6":Vector2i(27,20), "level7":Vector2i(35,19)}
var old_shader: Shader
var fixed_shader: Shader

func _texture(color: Color) -> ImageTexture:
	var img := Image.create(4,4,false,Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _probe_material(shader: Shader, natural: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("map_size",Vector2(4,2))
	mat.set_shader_parameter("land_mask",_texture(Color(1,0,0,1)))
	mat.set_shader_parameter("surface_weights",_texture(Color(0,0,0,0)))
	mat.set_shader_parameter("surface_field_texture",_texture(Color(0.4,0.3,0.15,1)))
	mat.set_shader_parameter("use_surface_field_texture",true)
	mat.set_shader_parameter("natural_surface_enabled",natural)
	mat.set_shader_parameter("coast_enabled",false)
	mat.set_shader_parameter("height_enabled",false)
	mat.set_shader_parameter("field_tint",Color.WHITE)
	return mat

func _viewport_image(view: SubViewport) -> Image:
	for i in range(8): await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func _alpha_samples(img: Image) -> Array:
	return [img.get_pixel(16,32).a,img.get_pixel(48,32).a,
		img.get_pixel(80,32).a,img.get_pixel(112,32).a]

func _synthetic_alpha() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(128,64)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var atlas := Image.create(16,16,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.WHITE)
	atlas.fill_rect(Rect2i(0,0,8,16),Color(1,1,1,0.25))
	var texture := ImageTexture.create_from_image(atlas)
	var batch = load("res://scripts/terrain_draw_batch.gd").new()
	var quad := MeshInstance2D.new()
	quad.mesh = batch._textured_mesh([
		[Rect2(0,0,64,64),Rect2(0,0,16,16),Color.WHITE],
		[Rect2(64,0,64,64),Rect2(0,0,16,16),Color(1,1,1,0.5)]],Vector2(16,16))
	quad.texture = texture
	view.add_child(quad)
	quad.material = _probe_material(old_shader,true)
	var before := await _viewport_image(view)
	var old_alphas := _alpha_samples(before)
	for i in range(4):
		check(absf(old_alphas[i] - [0.25,1.0,0.125,0.5][i]) < 0.02,"fixture reproduces atlas alpha leakage sample " + str(i))
	quad.material = _probe_material(fixed_shader,true)
	var after := await _viewport_image(view)
	var new_alphas := _alpha_samples(after)
	for i in range(4):
		check(absf(new_alphas[i] - [1.0,1.0,0.5,0.5][i]) < 0.02,"natural terrain ignores gutters and keeps vertex opacity sample " + str(i))
	quad.modulate.a = 0.6
	var faded := await _viewport_image(view)
	var faded_alphas := _alpha_samples(faded)
	for i in range(4):
		check(absf(faded_alphas[i] - [0.6,0.6,0.3,0.3][i]) < 0.02,"CanvasItem opacity preserved sample " + str(i))
	quad.modulate.a = 1.0
	quad.material = _probe_material(old_shader,false)
	var old_legacy := await _viewport_image(view)
	quad.material = _probe_material(fixed_shader,false)
	var new_legacy := await _viewport_image(view)
	check(old_legacy.get_data() == new_legacy.get_data(),"legacy transparent rendering remains pixel-identical")
	before.save_png(output.path_join("synthetic_before.png"))
	after.save_png(output.path_join("synthetic_after.png"))
	faded.save_png(output.path_join("synthetic_faded.png"))
	report["synthetic"] = {"old_alpha":old_alphas,"new_alpha":new_alphas,"modulated_alpha":faded_alphas,
		"legacy_equal":old_legacy.get_data()==new_legacy.get_data(), "scope":"GPU-rendered RGBA fixture: two vertex opacities and CanvasItem modulation; no production image editing"}
	view.queue_free()
	await process_frame

func _scene_capture(b, label: String, shader: Shader, save_png: bool = true) -> Dictionary:
	b.map.material.shader = shader
	for i in range(10): await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var result := {"pixels_sha256":img.get_data().hex_encode().sha256_text(),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"size":[img.get_width(),img.get_height()]}
	if save_png:
		var filename := label + ".png"
		check(img.save_png(output.path_join(filename)) == OK,label + " image saved")
		result["file"] = filename
		result["file_sha256"] = FileAccess.get_sha256(output.path_join(filename))
	return result

func _scene_probe(id: String) -> void:
	var b = await _start(id)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.hud.hide()
	if b._fog_layer != null: b._fog_layer.hide()
	var cell: Vector2i = _field_cell(b.map) if id in ["level3","level8"] else CAMERAS[id]
	b.camera.position = b.to_screen(b.map.cell_to_world(cell))
	var before_state := _terrain_state(b.map)
	var captures := []
	for zoom in ([1.0,1.5] if id in ["level3","level8"] else [1.0]):
		b.camera.zoom = Vector2.ONE * zoom
		b.camera.force_update_scroll()
		var label: String = id + "_" + str(int(zoom * 100))
		var before := await _scene_capture(b,label + "_before",old_shader)
		var after := await _scene_capture(b,label + "_after",fixed_shader)
		var restored := await _scene_capture(b,label + "_restored",old_shader,false)
		check(before.pixels_sha256 == restored.pixels_sha256,label + " old shader restoration is pixel-identical")
		check(before.draw_calls == after.draw_calls,label + " terrain fix adds no draw calls")
		check(before.size == [1280,720] and after.size == [1280,720],label + " actual viewport dimensions")
		if id in ["level3","level8"]:
			check(before.pixels_sha256 != after.pixels_sha256,label + " existing seams change in real pixels")
		captures.append({"zoom":zoom,"before":before,"after":after,"restored":restored})
	check(_terrain_state(b.map) == before_state,id + " grid collision occupancy height and masks unchanged")
	report.samples.append({"level":id,"level_script":b.level.get_script().resource_path,
		"camera_cell":[cell.x,cell.y],"state":before_state,"captures":captures})
	await _dispose(b,true)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Real renderer required")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA","1")
	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN","1")
	output = ProjectSettings.globalize_path("res://.godot/terrain_alpha_seam_qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	Engine.max_fps = 60
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	AudioServer.set_bus_mute(0,true)
	var save_before := _save_hash()
	check(FileAccess.get_sha256(OLD_SHADER) == OLD_SHADER_SHA,"old shader matches immutable pre-fix commit")
	if not failures.is_empty():
		quit(2)
		return
	old_shader = Shader.new()
	old_shader.code = FileAccess.get_file_as_string(OLD_SHADER)
	fixed_shader = load("res://scripts/liangshan_coast.gdshader")
	report["scope"] = "eight authored campaigns, frozen same scene and camera; field views also 150%; HUD/fog overlay hidden; synthetic RGBA opacity; no combat or frame-rate claim"
	report["shader_sources"] = {"before_sha256":OLD_SHADER_SHA,
		"after_sha256":FileAccess.get_sha256("res://scripts/liangshan_coast.gdshader")}
	report["renderer"] = {"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"method":RenderingServer.get_current_rendering_method()}
	await _synthetic_alpha()
	for id in ["level1","level2","level3","level4","level5","level6","level7","level8"]:
		await _scene_probe(id)
	check(report.samples.size() == 8 and report.has("synthetic"),"all eight scenes and synthetic fixture completed")
	check(_save_hash() == save_before,"campaign save unchanged")
	report["save_before"] = save_before
	report["save_after"] = _save_hash()
	report["passed"] = failures.is_empty()
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("[terrain-alpha-seam-result] ",JSON.stringify({"passed":failures.is_empty(),"checks":report.mode_checks.size(),"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
