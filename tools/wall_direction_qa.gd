extends "res://tools/zhujiazhuang_rts_test.gd"
## Reversing a wall's authoring order must preserve every source point and pixel.
## Real-map density checks complement (not replace) the gate/occlusion contracts.
var observations := {}
var map_script
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	map_script=load("res://scripts/game_map.gd")
	var Renderer=load("res://scripts/liangshan_stockade.gd")
	var environment=load("res://scripts/campaign_environment_art.gd")
	var texture=environment.object("level5","stockade_segment")
	var folder=OS.get_environment("WALL_DIRECTION_OUT")
	if folder.is_empty(): folder="res://.godot/wall_direction_qa"
	DirAccess.make_dir_recursive_absolute(folder)
	var visual=OS.get_environment("WALL_DIRECTION_VISUAL")=="1"
	if visual:
		check(DisplayServer.get_name()!="headless","pixel comparison uses real rendering")
		if DisplayServer.get_name()=="headless": quit(2); return
	for end in [Vector2(156,78),Vector2(-156,78),Vector2(156,62),Vector2(-156,94),Vector2(156,0),Vector2(-156,0.000001)]:
		var w=Renderer.new()
		w.campaign_texture=texture
		w.height_scale=98.0
		w.end_local=end
		var forward: Transform2D=w.source_transform()
		w.end_local=-end
		var backward: Transform2D=w.source_transform()
		var same=true
		# Source corners, interior beam and end posts; no copied fitting formula.
		for p in [Vector2.ZERO,Vector2(512,512),Vector2(220,235),Vector2(185,264),Vector2(331,342)]:
			if (forward*p).distance_to(end+backward*p)>0.001: same=false
		check(same,"reversed authoring retains all world source points "+str(end))
		check(forward.y.is_equal_approx(Vector2.DOWN),"source poles stay vertical at authored height "+str(end))
		if visual:
			var first=await _render(w,end,false)
			var second=await _render(w,end,true)
			check(first.get_used_rect().get_area()>5000,"pixel fixture contains visible wall art "+str(end))
			check(first.get_data()==second.get_data(),"forward/reverse actual pixels identical "+str(end))
			if end==Vector2(156,78):
				check(first.save_png(folder+"/forward.png")==OK and second.save_png(folder+"/reverse.png")==OK,"saved representative pixel comparison")
		w.free()
	for entry in [["zhu","",2],["liangshan","",4],["defense","skirmish",4]]:
		var b=await _start(entry[1],entry[2])
		b.phase=b.Phase.DEPLOY
		var walls=b.map.sample_scenery._walls if entry[2]==2 else b.map.sample_scenery._entrance._wall_parts
		var max_shear=0.0
		var min_ratio=INF
		var max_ratio=0.0
		for w in walls:
			var tr: Transform2D=w.source_transform()
			max_shear=maxf(max_shear,absf(tr.x.y/tr.x.x))
			var ratio=absf(tr.x.x/tr.y.y)
			min_ratio=minf(min_ratio,ratio)
			max_ratio=maxf(max_ratio,ratio)
		check(min_ratio>0.85 and max_ratio<1.3,entry[0]+" panels preserve source proportions within measured tolerance")
		check(max_shear<0.18,entry[0]+" source cross-axis correction stays below 18 percent")
		observations[entry[0]]={"parts":walls.size(),"max_axis_correction":max_shear,"min_width_height_ratio":min_ratio,"max_width_height_ratio":max_ratio}
		await _dispose(b)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations},"\t")+"\n")
	print("[wall-direction] ",checks," checks, failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func _render(w, end: Vector2, reverse: bool) -> Image:
	var viewport=SubViewport.new()
	viewport.size=Vector2i(640,400)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.world_2d=World2D.new()
	root.add_child(viewport)
	var world=Node2D.new()
	world.transform=map_script.ISO
	viewport.add_child(world)
	w.position=map_script.ISO_INV*(Vector2(320,180)+(end if reverse else Vector2.ZERO))
	w.end_local=-end if reverse else end
	world.add_child(w)
	w.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result=viewport.get_texture().get_image()
	world.remove_child(w)
	viewport.queue_free()
	await process_frame
	return result
