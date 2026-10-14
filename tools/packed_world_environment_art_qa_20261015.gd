extends SceneTree
var output := ""
var checks: Array = []
var failures: Array = []
var screenshots: Array = []
var rows: Array = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failures.append(label)
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name+".png")
	var image := root.get_texture().get_image()
	check(image.get_size()==root.size,"capture dimensions "+name)
	check(image.save_png(path)==OK,"capture "+name)
	screenshots.append({"path":name+".png","sha256":FileAccess.get_sha256(path),"size":[image.get_width(),image.get_height()]})
func mechanical(battle) -> Array:
	var result: Array = []
	for unit in battle.units: result.append([unit.key,unit.entity_id,unit.position.x,unit.position.y,unit.hp,unit.radius,unit.faction])
	return result
func _run() -> void:
	output=OS.get_environment("PACKED_WORLD_ART_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED")!="1": quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PACKED_WORLD_ART_INPUTS")))
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]: campaign.set(mode,false)
	campaign.current=6
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").auto_micro_level=0
	seed(5088120)
	var battle=load("res://scenes/main.tscn").instantiate()
	root.add_child(battle);current_scene=battle
	await process_frame
	battle.hud._intro_root.hide();battle._on_intro_done();battle._on_start_battle()
	await process_frame
	check(battle.level.id()=="level7","original Level7 active")
	battle.set_process(false);battle.set_physics_process(false)
	for unit in battle.units: unit.set_physics_process(false)
	await snap("1280x720_normal_fog_opening")
	var before := mechanical(battle)
	var map_before: Array = Array(battle.map.grid)
	var decor_before: Array = battle.map.decor.duplicate(true)
	var native: Dictionary = {}
	for node in battle.find_children("*","Node2D",true,false):
		var route := String(node.get_meta("campaign_environment_route",""))
		if route.begins_with("kuaihuolin_stall_"):
			check(not native.has(route),"unique original stall "+route)
			native[route]=node
	check(native.size()==6,"all six original market positions have distinct native art")
	var taverns: Dictionary = {}
	for unit in battle.units:
		var key := String(unit.get_meta("campaign_environment_route",""))
		if key.begins_with("roadside_tavern_"): taverns[key]=unit
	check(taverns.size()==4,"four original taverns retained in packed world")
	for row in manifest.taverns:
		if not taverns.has(row.key): check(false,"original tavern missing "+row.key);continue
		var unit=taverns[row.key]
		var texture=unit._campaign_environment_texture()
		check(texture!=null and not texture is AtlasTexture and texture.resource_path=="res://"+row.path,"packed original tavern owns its variant "+row.key)
		check(not FileAccess.file_exists("res://"+row.path),"no loose original tavern PNG "+row.key)
		check(is_equal_approx(float(unit.get_meta("campaign_environment_foot",-1)),float(row.foot)),"packed tavern measured foot "+row.key)
		check(unit.ui_portrait_texture()==texture,"packed tavern portrait matches world "+row.key)
	var expected_cells := {"inn_a":Vector2i(12,16),"wine":Vector2i(19,20),"goods":Vector2i(29,18),"dice":Vector2i(38,19),"money":Vector2i(48,18),"inn_b":Vector2i(52,22)}
	for row in manifest.variants:
		var key: String = row.key
		if not native.has(key): continue
		var node=native[key]
		var tex: Texture2D = node.native_texture
		check(tex!=null and not tex is AtlasTexture and tex.resource_path=="res://"+row.path,"exact own retained PNG "+key)
		check(not FileAccess.file_exists("res://"+row.path) and CampaignEnvironmentArt._verified_png_source_sha("res://"+row.path)==row.sha256,"packed pixels verified without original PNG "+key)
		check(is_equal_approx(node.foot,float(row.foot)),"measured foot "+key)
		check(node.size==64.0 and node.native_size==96.0,"original marker size and explicit presentation scale "+key)
		check(node.kind==("inn" if String(row.kind).begins_with("inn") else row.kind),"original shop identity "+key)
		var cell: Vector2i = expected_cells[row.kind]
		check(node.position==battle.map.cell_to_world(cell),"original logical anchor "+key)
		check(node.native_draw_offset==(Vector2(-28,12) if row.kind=="money" else Vector2.ZERO),"explicit money-booth visual clearance only "+key)
		var image := tex.get_image()
		for point in [Vector2i(0,0),Vector2i(511,0),Vector2i(0,511),Vector2i(511,511)]:
			check(image.get_pixelv(point).a<=1.0/255.0+0.0001,"transparent source corner "+key+str(point))
		for level in ["level1","level5","level8","skirmish","arena"]:
			check(CampaignEnvironmentArt.object(level,key)==null,"route scope guard "+level+key)
		check(node.normalized_text_rect==CampaignEnvironmentArt.calibrated_text_rect("object","level7",key,"default",row.text_surface),"source-bound blank sign surface "+key)
		rows.append({"route":key,"kind":node.kind,"position":[node.position.x,node.position.y],"source":tex.resource_path,"foot":node.foot,"text_rect":node.normalized_text_rect})
	battle.fog=false
	if battle._fog_layer!=null: battle._fog_layer.hide()
	battle.camera.set_process(false);battle.camera.set_physics_process(false)
	battle.camera.position_smoothing_enabled=false
	var game_map=load("res://scripts/game_map.gd")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=dimensions;root.content_scale_size=dimensions
		await process_frame
		var prefix := str(dimensions.x)+"x"+str(dimensions.y)
		battle.camera.zoom=Vector2.ONE*0.7
		battle.camera.position=battle.to_screen(battle.map.cell_to_world(Vector2i(31,18)))
		battle.camera.force_update_scroll()
		battle.map.sample_scenery._refresh_fog_visibility()
		await create_timer(0.15).timeout
		await snap(prefix+"_overview")
		for row in manifest.variants:
			var key: String = row.key
			if not native.has(key): continue
			var node=native[key]
			battle.camera.zoom=Vector2.ONE*2.0
			battle.camera.position=battle.to_screen(node.position)+Vector2(0,-25)
			battle.camera.force_update_scroll()
			battle.map.sample_scenery._refresh_fog_visibility()
			node.queue_redraw()
			await create_timer(0.15).timeout
			await snap(prefix+"_"+row.kind)
			check(node.is_visible_in_tree(),"native stall visible "+prefix+key)
			var bbox: Array = row.visible_bbox_xywh
			var local_roof: Vector2 = Vector2((float(bbox[0])+float(bbox[2])*0.5)/512.0-0.5,(float(bbox[1])+float(bbox[3])*0.3)/512.0-node.foot)*node.native_size+node.native_draw_offset
			var screen: Vector2 = node.get_global_transform_with_canvas()*game_map.ISO_INV*local_roof
			var frame := root.get_texture().get_image()
			var point := Vector2i(screen.round())
			if Rect2i(Vector2i.ZERO,frame.get_size()).has_point(point):
				var color := frame.get_pixelv(point)
				check(not (color.r>0.95 and color.g>0.95 and color.b>0.95),"native painted canopy instead of white quad "+prefix+key)
			else: check(false,"canopy sample remains in viewport "+prefix+key)
	check(mechanical(battle)==before,"all original gameplay units unchanged during art draws")
	check(Array(battle.map.grid)==map_before and battle.map.decor==decor_before,"original terrain and decor layout unchanged")
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"instances":rows,"screenshots":screenshots,"scope":"Original full-game PCK Level7, six native stalls and four taverns at three resolutions. Editor runs actual packed game resources; no release-EXE, full gameplay, live SDK, performance, human or Steam qualification."}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("PACKED_WORLD_ENVIRONMENT_ART_QA ",checks.size()," checks; ",failures.size()," failures")
	battle.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
