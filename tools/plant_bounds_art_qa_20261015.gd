extends SceneTree
var output := ""
var checks: Array = []
var failures: Array = []
var screenshots: Array = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,name: String) -> void:
	checks.append({"name":name,"passed":ok})
	if not ok: failures.append(name)
func snap(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var path := output.path_join(name+".png")
	var image := root.get_texture().get_image()
	check(image.get_size()==root.size,"viewport size "+name)
	check(image.save_png(path)==OK,"capture "+name)
	screenshots.append({"path":name+".png","sha256":FileAccess.get_sha256(path)})
func state(battle) -> Array:
	var rows: Array = []
	for unit in battle.units: rows.append([unit.key,unit.position.x,unit.position.y,unit.hp,unit.entity_id])
	return rows
func _run() -> void:
	output=OS.get_environment("PLANT_ART_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED")!="1": quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true)
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/plant_bounds_20261015/source_calibration.json"))
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]: campaign.set(mode,false)
	campaign.current=4
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").auto_micro_level=0
	seed(5088120)
	var battle=load("res://scenes/main.tscn").instantiate()
	root.add_child(battle);current_scene=battle
	await process_frame
	battle.hud._intro_root.hide();battle._on_intro_done();battle._on_start_battle()
	await process_frame
	check(battle.level.id()=="level5","original Level5 active")
	battle.set_process(false);battle.set_physics_process(false)
	for unit in battle.units: unit.set_physics_process(false)
	var before := state(battle)
	var grid_before: Array = Array(battle.map.grid)
	var found: Dictionary = {}
	var counts: Dictionary = {}
	for node in battle.find_children("*","Node2D",true,false):
		var key := String(node.get_meta("campaign_environment_route",""))
		for plant in contract.plants:
			if key!=plant.key: continue
			counts[key]=int(counts.get(key,0))+1
			if not found.has(key): found[key]=node
			check(is_equal_approx(float(node.foot),float(plant.measured_foot)),"original scenery foot "+key+str(counts[key]))
			check(node.tex!=null and node.tex.resource_path=="res://"+plant.path,"original plant source "+key+str(counts[key]))
	check(found.size()==7,"all seven original plant routes represented")
	for plant in contract.plants:
		var metrics := CampaignEnvironmentArt.calibrated_visual_metrics("object","level5",plant.key)
		check(not metrics.is_empty() and is_equal_approx(float(metrics.get("foot",-1)),float(plant.measured_foot)),"source-bound measured metrics "+plant.key)
		check(CampaignEnvironmentArt.calibrated_visual_metrics("object","level7",plant.key).is_empty(),"level scope guard "+plant.key)
		if found.has(plant.key):
			var node=found[plant.key]
			var visible_bottom: float = -node.size*node.foot+node.size*(float(plant.measured_bbox_xywh[1])+float(plant.measured_bbox_xywh[3]))/512.0
			check(absf(visible_bottom)<0.001,"painted bottom meets original ground anchor "+plant.key)
	await snap("1280x720_normal_fog_opening")
	battle.fog=false
	if battle._fog_layer!=null: battle._fog_layer.hide()
	battle.camera.set_process(false);battle.camera.set_physics_process(false);battle.camera.position_smoothing_enabled=false
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=dimensions;root.content_scale_size=dimensions
		await process_frame
		var prefix := str(dimensions.x)+"x"+str(dimensions.y)
		for plant in contract.plants:
			if not found.has(plant.key):continue
			var node=found[plant.key]
			battle.camera.zoom=Vector2.ONE*2.0
			battle.camera.position=battle.to_screen(node.position)+Vector2(0,-20)
			battle.camera.force_update_scroll()
			battle.map.sample_scenery._refresh_fog_visibility()
			node.queue_redraw()
			await create_timer(0.15).timeout
			await snap(prefix+"_"+plant.key)
			check(node.is_visible_in_tree(),"actual original plant visible "+prefix+plant.key)
	check(state(battle)==before and Array(battle.map.grid)==grid_before,"original gameplay and terrain unchanged")
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":screenshots,"route_counts":counts,"scope":"Original Level5 seven plant alpha-bound alignment at three resolutions, private frozen visual fixture; no full gameplay/performance/platform or human qualification."}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("PLANT_BOUNDS_ART_QA ",checks.size()," checks; ",failures.size()," failures")
	battle.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
