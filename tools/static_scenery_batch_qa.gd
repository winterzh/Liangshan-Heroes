extends SceneTree
## Graphical desktop synthetic QA, NOT phone/frame-performance or visual approval.
## Run only in the runner's isolated LSH-rts copy/profile; no production assets.
const SOURCES := ["scripts/static_scenery_draw_batch.gd", "scripts/liangshan_scenery.gd", "scripts/liangshan_entrance.gd"]
const PROPOSAL := {"mean_channel_error_255": 0.5, "max_channel_error_255": 32, "pct_pixels_any_channel_gt8": 0.25}
var failures: Array = []

class Fixture extends Node2D:
	var mode := "legacy"
	var batch = null
	var textures: Array = []
	func setup(which: String, shared: Array) -> void:
		mode = which; textures = shared
		if mode == "batch":
			batch = load("res://scripts/static_scenery_draw_batch.gd").new()
			recipe(batch, true); batch.finish()
	func quad(x: float, y: float, w: float, h: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(x,y), Vector2(x+w,y), Vector2(x+w,y+h), Vector2(x,y+h)])
	func recipe(canvas, aa: bool) -> void:
		var widths := [0.8, 1.0, 1.4, 3.0, 5.0]
		for i in widths.size():
			canvas.draw_line(Vector2(15,14+i*14), Vector2(185,18+i*14), Color(0.7,0.8,0.4,0.72), widths[i], aa)
		canvas.draw_polyline(PackedVector2Array([Vector2(15,105),Vector2(50,106),Vector2(90,100),Vector2(130,109),Vector2(180,103)]),Color(0.1,0.3,0.2,0.45),1.4,aa)
		canvas.draw_polyline(PackedVector2Array([Vector2(15,145),Vector2(60,121),Vector2(62,151),Vector2(115,125),Vector2(185,145)]),Color(0.6,0.4,0.2,0.8),3.0,aa)
		canvas.draw_polyline(PackedVector2Array([Vector2(220,12),Vector2(310,23),Vector2(288,72),Vector2(230,65),Vector2(220,12)]),Color(0.5,0.7,0.9,0.65),1.0,aa)
		canvas.draw_polyline(PackedVector2Array([Vector2(220,90),Vector2(245,110),Vector2(245,110),Vector2(265,91),Vector2(305,112)]),Color(0.9,0.5,0.4,0.7),1.4,aa)
		var uv := PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
		canvas.draw_colored_polygon(quad(15,170,295,65),Color(0.25,0.35,0.16,0.7))
		canvas.draw_polygon(quad(25,175,80,45),PackedColorArray([Color.RED,Color.GREEN,Color.BLUE,Color(0.7,0.6,0.3,0.2)]))
		canvas.draw_polygon(quad(65,178,80,50),PackedColorArray([Color(1,1,1,0.65)]),uv,textures[0])
		canvas.draw_texture_rect(textures[2],Rect2(105,165,65,65),false,Color(1,1,1,0.75))
		canvas.draw_colored_polygon(quad(130,185,65,45),Color(0.8,0.2,0.2,0.4))
		canvas.draw_polygon(quad(160,176,80,50),PackedColorArray([Color(1,1,1,0.6)]),uv,textures[1])
		canvas.draw_texture_rect(textures[0],Rect2(215,185,60,40),false,Color(1,1,1,0.7))
		canvas.draw_line(Vector2(20,203),Vector2(305,210),Color(0.8,0.9,0.2,0.6),1.4,aa)
	func _draw() -> void:
		if mode == "batch": batch.draw(self)
		else: recipe(self, mode != "hard")

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _private_ok() -> bool:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("LSH_RTS_QA_PROFILE").simplify_path().trim_suffix("/")
	var output := OS.get_environment("LSH_RTS_QA_OUT").simplify_path().trim_suffix("/")
	return project == OS.get_environment("LSH_RTS_QA_PROJECT").simplify_path().trim_suffix("/") \
		and profile.is_absolute_path() and output.is_absolute_path() and output != project and not output.begins_with(project + "/") \
		and output != profile and not output.begins_with(profile + "/") and OS.get_user_data_dir().simplify_path().trim_suffix("/") == profile \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-rts-") \
		and FileAccess.file_exists("res://override.cfg") and not FileAccess.file_exists("res://.git") \
		and not DirAccess.dir_exists_absolute(project.path_join(".git")) and DisplayServer.get_name() != "headless" \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1" \
		and OS.get_environment("CONTENT_UPDATE_NO_AUTO") == "1"

func _hashes() -> Dictionary:
	var result := {}
	for path in SOURCES: result[path] = FileAccess.get_sha256("res://" + path)
	return result

func _textures() -> Array:
	var result: Array = []
	for variant in 2:
		var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16: img.set_pixel(x,y,Color(float(x)/15.0,float(y)/15.0,float((x+y+variant)%4)/3.0,0.4+0.6*float((x+y)%2)))
		result.append(ImageTexture.create_from_image(img))
	var atlas := AtlasTexture.new()
	atlas.atlas = result[0]; atlas.region = Rect2(2,2,12,12); atlas.margin = Rect2(1,2,15,16); atlas.filter_clip = true
	result.append(atlas)
	return result

func _cache(batch) -> Dictionary:
	var ids: Array = []; var order: Array = []; var clear_vertices := 0; var valid := true
	for entry in batch._batches:
		var tex = entry.texture
		var texture_id: int = tex.get_instance_id() if tex != null else 0
		var texture_rid: int = tex.get_rid().get_id() if tex != null else 0
		valid = valid and (tex == null or tex.get_rid().is_valid())
		order.append(["rect" if entry.has("rect") else "mesh",texture_id])
		if entry.has("mesh"):
			var mesh = entry.mesh
			valid = valid and mesh.get_rid().is_valid() and mesh.get_surface_count() == 1
			ids.append([mesh.get_instance_id(),mesh.get_rid().get_id(),texture_id,texture_rid])
			for color in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
				if color.a == 0.0: clear_vertices += 1
		else: ids.append([0,0,texture_id,texture_rid])
	return {"resource_ids":ids,"order":order,"valid_rids":valid,"transparent_aa_vertices":clear_vertices}

func _diff(a: Image, b: Image) -> Dictionary:
	var aa := a.get_data(); var bb := b.get_data(); var total := 0.0; var peak := 0; var changed := 0; var active := 0
	for pixel in a.get_width()*a.get_height():
		var largest := 0
		if aa[pixel*4+3] > 0 or bb[pixel*4+3] > 0: active += 1
		for channel in 4:
			var error := absi(int(aa[pixel*4+channel])-int(bb[pixel*4+channel]))
			total += error; largest = maxi(largest,error)
		peak = maxi(peak,largest)
		if largest > 8: changed += 1
	var pixels := a.get_width()*a.get_height()
	return {"mean_channel_error_255":total/(pixels*4.0),"max_channel_error_255":peak,"pct_pixels_any_channel_gt8":100.0*changed/pixels,"foreground_mean_channel_error_255":total/maxi(1,active*4),"foreground_pixels":active}

func _run() -> void:
	if not _private_ok():
		push_error("Static batch QA requires isolated graphical LSH-rts project/profile and disabled services"); quit(2); return
	var output := OS.get_environment("LSH_RTS_QA_OUT")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create external QA output"); quit(2); return
	var before := _hashes(); var textures := _textures(); var views: Array = []; var fixtures: Array = []; var samples: Array = []
	for digest in before.values(): check(String(digest).length() == 64,"source exists with SHA256")
	root.size = Vector2i(1280,480)
	for mode in ["legacy","batch","hard"]:
		var view := SubViewport.new()
		view.size = Vector2i(640,480); view.transparent_bg = true; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.msaa_2d = Viewport.MSAA_DISABLED; view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		root.add_child(view); views.append(view)
		var fixture := Fixture.new()
		fixture.setup(mode,textures); fixture.position = Vector2(25.25,22.5); fixture.rotation = 0.037
		view.add_child(fixture); fixtures.append(fixture)
		if mode != "hard":
			var display := TextureRect.new()
			display.texture = view.get_texture(); display.position.x = 640 if mode == "batch" else 0; root.add_child(display)
	var batch = fixtures[1].batch
	var cache := _cache(batch); var summary: Dictionary = batch.summary()
	check(batch.valid and cache.valid_rids,"valid mesh and texture resources")
	check(summary.aa_lines == 6 and summary.aa_polylines == 4 and cache.transparent_aa_vertices > 0,"AA coverage and genuine transparent fringe vertices")
	var expected := [["mesh",0],["mesh",textures[0].get_instance_id()],["rect",textures[2].get_instance_id()],["mesh",0],["mesh",textures[1].get_instance_id()],["rect",textures[0].get_instance_id()],["mesh",0]]
	check(cache.order == expected and summary.native_texture_rects == 2 and summary.source_commands == 17,"ordered texture transitions and native AtlasTexture barriers")
	for zoom in [0.6,1.0,1.7]:
		for fixture in fixtures: fixture.scale = Vector2.ONE*zoom; fixture.queue_redraw()
		for redraw in 12:
			for fixture in fixtures: fixture.queue_redraw()
			await RenderingServer.frame_post_draw
		check(_cache(batch) == cache and batch.summary() == summary,"resource IDs/RIDs and batches reused at scale " + str(zoom))
		var images: Array = []; var stem := "static_batch_s" + str(roundi(zoom*100)).pad_zeros(3)
		for i in views.size():
			var img: Image = views[i].get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8); images.append(img)
			check(img.save_png(output.path_join(stem+"_"+fixtures[i].mode+".png")) == OK,"save raw PNG")
		var pair := Image.create(1280,480,false,Image.FORMAT_RGBA8)
		pair.blit_rect(images[0],Rect2i(0,0,640,480),Vector2i.ZERO); pair.blit_rect(images[1],Rect2i(0,0,640,480),Vector2i(640,0))
		check(pair.save_png(output.path_join(stem+"_legacy_left_batch_right.png")) == OK,"save pair PNG")
		var difference := _diff(images[0],images[1]); var hard := _diff(images[0],images[2]); var within := true
		for key in PROPOSAL: within = within and difference[key] <= PROPOSAL[key]
		check(hard.max_channel_error_255 > 8 and hard.foreground_pixels > 0,"AA negative control detects hard-edge rendering")
		samples.append({"scale":zoom,"legacy_vs_batch":difference,"legacy_vs_hard_edge":hard,"within_unapproved_proposal":within,"png_stem":stem})
	check(_hashes() == before,"helper and production owner sources unchanged during QA")
	var report := {"passed":failures.is_empty(),"pass_scope":"structural only; numerical thresholds UNAPPROVED; visual review required","device_scope":"desktop synthetic SubViewport, not Android or frame timing","failures":failures,"sources_sha256":before,"summary":summary,"texture_barriers":2,"cache":cache,"redraws_per_scale":12,"proposal_not_gate":PROPOSAL,"samples":samples,"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(output.path_join("static-scenery-batch-result.json"),FileAccess.WRITE)
	if file == null: push_error("Cannot write static batch QA report"); quit(2); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("[static-scenery-batch-result] ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
