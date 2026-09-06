extends "res://tools/campaign_mode_performance_test.gd"
## 同一已冻结地图切换提交顺序；仅验证地面像素与静态渲染成本，不代表战斗帧率。

func _terrain_snapshot(map) -> Dictionary:
	return {"grid":map.grid.to_byte_array().hex_encode().sha256_text(),
		"solid":map._base_solid.hex_encode().sha256_text(),
		"blocks":map._block_count.to_byte_array().hex_encode().sha256_text(),
		"height":map.height_field.samples.to_byte_array().hex_encode().sha256_text() if map.height_field!=null else "flat"}

func _isolate_terrain(b) -> void:
	b.process_mode=Node.PROCESS_MODE_DISABLED
	for child in b.get_children():
		if child not in [b.world,b.camera] and (child is CanvasItem or child is CanvasLayer): child.hide()
	for child in b.world.get_children():
		if child!=b.map and child is CanvasItem: child.hide()
	for child in b.map.get_children():
		if child is CanvasItem: child.hide()

func _terrain_sample(map, enabled: bool, label: String) -> Dictionary:
	OS.set_environment("CAMPAIGN_TERRAIN_BATCH","1" if enabled else "0")
	map.queue_redraw()
	for i in range(12): await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var image_path := output.path_join(label+".png")
	image.save_png(image_path)
	var frames: Array[float]=[]
	var calls: Array[float]=[]
	var previous := Time.get_ticks_usec()
	var start := previous
	while Time.get_ticks_usec()-start<2000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous=now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var mean: float=frames.reduce(func(a,v):return a+v,0.0)/frames.size()
	frames.sort()
	return {"enabled":enabled,"frames":frames.size(),"average_frame_ms":mean,
		"p95_frame_ms":frames[mini(frames.size()-1,int(ceil(frames.size()*0.95))-1)],
		"mean_draw_calls":calls.reduce(func(a,v):return a+v,0.0)/calls.size(),
		"image_sha256":image.get_data().hex_encode().sha256_text(),"image_path":image_path}

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	output=ProjectSettings.globalize_path("res://qa/terrain_batch")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var s=root.get_node("Settings")
	s.edge_scroll=false; s.auto_micro_level=0; s.game_speed=1.0
	AudioServer.set_bus_mute(0,true)
	var headless := DisplayServer.get_name()=="headless"
	if not headless:
		DisplayServer.window_set_size(root.size)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	report["scope"]="frozen terrain only: exact same state and camera, no units, scenery, HUD or atmosphere; not live combat performance"
	report["headless"]=headless
	for id in ["level3","level5","level8"]:
		var b=await _start(id)
		var before := _terrain_snapshot(b.map)
		var wall_cells := 0
		for y in range(b.map.h):
			for x in range(b.map.w):
				if b.map.t_at(x,y)==b.map.T.CLIFF and b.map._is_authored_wall_base(x,y): wall_cells+=1
		check((wall_cells>0)==(id in ["level3","level8"]),id+" only authored wall foundations receive packed-earth material")
		if not headless and id!="level8":
			_isolate_terrain(b)
			_camera(b,Vector2i(29,29) if id=="level3" else Vector2i(23,23),0.8)
			var off := await _terrain_sample(b.map,false,id+"_off")
			var on := await _terrain_sample(b.map,true,id+"_on")
			check(off.image_sha256==on.image_sha256,id+" batched terrain pixels are identical")
			check(on.mean_draw_calls<off.mean_draw_calls*0.6,id+" reduces terrain draw calls by at least 40 percent")
			report.samples.append({"level":id,"off":off,"on":on})
		check(_terrain_snapshot(b.map)==before,id+" grid collision occupancy and height data unchanged")
		await _dispose(b)
	OS.set_environment("CAMPAIGN_TERRAIN_BATCH","1")
	report["passed"]=failures.is_empty(); report["failures"]=failures
	var path := output.path_join("headless_contract.json" if headless else "render_ab.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("[terrain-batch-result] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"path":path,"samples":report.samples}))
	quit(0 if failures.is_empty() else 1)
