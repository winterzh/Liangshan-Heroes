extends SceneTree
## Original Level7 visual fixture; no playthrough or performance acceptance.
var output := ""
var checks: Array = []
var failures: Array = []
var screenshots: Array = []
var instances: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failures.append(label)

func snapshot(unit) -> Dictionary:
	return {"key":unit.key,"position":[unit.position.x,unit.position.y],"radius":unit.radius,"hp":unit.hp,"max_hp":unit.max_hp,"faction":unit.faction,"art_variant":unit.art_variant,"building":unit.is_building}

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name+".png")
	var image := root.get_texture().get_image()
	check(image.get_size()==root.size,"capture dimensions "+name)
	check(image.save_png(path)==OK,"capture "+name)
	screenshots.append({"path":name+".png","sha256":FileAccess.get_sha256(path),"size":[image.get_width(),image.get_height()]})

func _run() -> void:
	output = OS.get_environment("TAVERN_ART_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED")!="1": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0,true)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/roadside_tavern_variants_20261015/source_manifest.json"))
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","ai_friendly","scale_on"]: campaign.set(mode,false)
	campaign.current = -1
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id=="level7": campaign.current = i
	check(campaign.current>=0,"resolve original level7 by stable id")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	seed(5088120)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle._on_start_battle()
	await process_frame
	check(battle.level.id()=="level7","original Level7 active")
	check(battle.level.get_script().resource_path=="res://scripts/levels/level7_kuaihuolin_short.gd","current production short duel script")
	# Freeze only this private visual fixture, while retaining original world units.
	battle.set_process(false)
	battle.set_physics_process(false)
	for unit in battle.units:
		unit.set_physics_process(false)
	await snap("1280x720_normal_fog_opening")
	battle.fog = false
	if battle._fog_layer!=null: battle._fog_layer.hide()
	battle.camera.set_process(false)
	battle.camera.set_physics_process(false)
	battle.camera.position_smoothing_enabled = false
	var found: Dictionary = {}
	var before: Dictionary = {}
	for unit in battle.units:
		var route := String(unit.get_meta("campaign_environment_route",""))
		if not route.begins_with("roadside_tavern_"): continue
		check(not found.has(route),"unique original instance "+route)
		found[route] = unit
		before[route] = snapshot(unit)
	check(found.size()==4,"all four original taverns exist")
	var image_hashes: Array = []
	var game_map_script = load("res://scripts/game_map.gd")
	for row in manifest.variants:
		var key: String = row.key
		var path: String = "res://"+row.path
		var tex = CampaignEnvironmentArt.object("level7",key)
		check(tex is Texture2D and not tex is AtlasTexture,"normal PNG bypasses atlas fallback "+key)
		if tex==null or not found.has(key): continue
		check(tex.resource_path==path,"exact own source "+key)
		check(FileAccess.get_sha256(path)==row.sha256,"source SHA "+key)
		var image: Image = tex.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var pixel_sha := HashingContext.new()
		pixel_sha.start(HashingContext.HASH_SHA256)
		pixel_sha.update(image.get_data())
		var digest := pixel_sha.finish().hex_encode()
		image_hashes.append(digest)
		var source_image := Image.load_from_file(path)
		source_image.convert(Image.FORMAT_RGBA8)
		var alpha_exact := true
		var opaque_rgb_exact := true
		for y in range(512):
			for x in range(512):
				var original := source_image.get_pixel(x,y)
				var imported := image.get_pixel(x,y)
				alpha_exact = alpha_exact and original.a==imported.a
				if original.a>=0.95:
					opaque_rgb_exact = opaque_rgb_exact and original==imported
		check(alpha_exact,"import preserves all alpha pixels "+key)
		check(opaque_rgb_exact,"import preserves opaque artwork pixels "+key)
		for corner in [Vector2i(0,0),Vector2i(511,0),Vector2i(0,511),Vector2i(511,511)]:
			check(image.get_pixelv(corner).a==0.0,"transparent corner "+key+str(corner))
		for level in ["level1","level5","level8","skirmish","arena","custom_defense"]:
			check(CampaignEnvironmentArt.object(level,key)==null,"scope guard "+level+key)
		var unit = found[key]
		var scoped = unit._campaign_environment_texture()
		check(scoped==tex,"original unit uses its own variant "+key)
		check(is_equal_approx(float(unit.get_meta("campaign_environment_foot",-1)),float(row.foot)),"measured foot "+key)
		var foot_meta = unit.get_meta("campaign_environment_foot")
		var top_meta = unit.get_meta("campaign_environment_visible_top")
		check(unit.ui_portrait_texture()==tex,"original unit portrait matches world "+key)
		check(unit.get_meta("campaign_environment_foot")==foot_meta and unit.get_meta("campaign_environment_visible_top")==top_meta,"portrait query preserves draw metadata "+key)
		instances.append({"route":key,"before":before[key],"texture":tex.resource_path,"foot":foot_meta,"top":top_meta})
	check(image_hashes.size()==4 and image_hashes.count(image_hashes[0])==1 and image_hashes.count(image_hashes[1])==1 and image_hashes.count(image_hashes[2])==1 and image_hashes.count(image_hashes[3])==1,"four distinct imported appearances")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		var prefix := str(dimensions.x)+"x"+str(dimensions.y)
		battle.camera.zoom = Vector2.ONE*0.7
		battle.camera.position = battle.to_screen(battle.map.cell_to_world(Vector2i(30,18)))
		battle.camera.force_update_scroll()
		for unit in battle.units:
			if unit.has_method("_refresh_fog_visibility"): unit._refresh_fog_visibility()
		await create_timer(0.15).timeout
		await snap(prefix+"_overview")
		for row in manifest.variants:
			var key: String = row.key
			if not found.has(key): continue
			var unit = found[key]
			battle.camera.zoom = Vector2.ONE*1.7
			battle.camera.position = battle.to_screen(unit.position)+Vector2(0,-25)
			battle.camera.force_update_scroll()
			battle._grid_build()
			unit.queue_redraw()
			await create_timer(0.15).timeout
			await snap(prefix+"_"+key)
			check(unit.is_visible_in_tree(),"original unit visible "+prefix+key)
			var visual_size: float = game_map_script.building_visual_px(game_map_script.footprint_half_for(unit.radius))
			var expected := visual_size*(float(row.visible_top)-float(row.foot))-8.0
			check(unit.has_meta("campaign_environment_label_y") and is_equal_approx(float(unit.get_meta("campaign_environment_label_y",0)),expected),"name above own roof "+prefix+key)
			check(snapshot(unit)==before[key],"mechanical state unchanged "+prefix+key)
			check(unit._campaign_environment_render_texture!=null and unit._campaign_environment_render_texture.resource_path=="res://"+row.path,"draw owns its texture between frames "+prefix+key)
			# Sample the opaque roof core in the actual framebuffer, guarding the
			# white-quad regression rather than relying only on resolver identity.
			var bbox: Array = row.visible_bbox_xywh
			var local_roof := Vector2((float(bbox[0])+float(bbox[2])*0.5)/512.0-0.5,(float(bbox[1])+float(bbox[3])*0.25)/512.0-float(row.foot))*visual_size
			var roof_screen: Vector2 = unit.get_global_transform_with_canvas()*game_map_script.ISO_INV*local_roof
			var frame := root.get_texture().get_image()
			var point := Vector2i(roof_screen.round())
			var in_frame := Rect2i(Vector2i.ZERO,frame.get_size()).has_point(point)
			check(in_frame,"roof sample in framebuffer "+prefix+key)
			if in_frame:
				var color := frame.get_pixelv(point)
				check(not (color.r>0.9 and color.g>0.9 and color.b>0.9),"painted roof replaces white quad "+prefix+key)
	for item in instances:
		item["after"] = snapshot(found[item.route])
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":screenshots,"instances":instances,"scope":"Original production Level7 four taverns at three resolutions; private frozen visual fixture. No full gameplay, frame rate, Steam publication or human acceptance."}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("TAVERN_ART_QA ",checks.size()," checks; ",failures.size()," failures")
	battle.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
