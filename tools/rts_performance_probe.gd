extends "res://tools/zhujiazhuang_rts_test.gd"
## Live rendered 1x windows after warmup. No fixed-fps/headless samples.
## PERF_MODE=live|paused_sim, PERF_LEVEL=7 by default, PERF_OUT=absolute JSON.
func sample(b,label: String) -> Dictionary:
	await _wait(3)
	var times: Array[float]=[]
	var process_ms := 0.0
	var physics_ms := 0.0
	var draw_calls := 0.0
	var started := Time.get_ticks_usec()
	var previous := started
	var drawn_start := Engine.get_frames_drawn()
	var process_start := Engine.get_process_frames()
	var physics_start := Engine.get_physics_frames()
	while Time.get_ticks_usec()-started<10000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now-previous)/1000)
		previous=now
		process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
		physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		draw_calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var elapsed: float=float(Time.get_ticks_usec()-started)/1000000
	var sorted=times.duplicate()
	sorted.sort()
	return {"label":label,"wall_seconds":elapsed,"frames":times.size(),"drawn_frame_delta":Engine.get_frames_drawn()-drawn_start,"process_frame_delta":Engine.get_process_frames()-process_start,"physics_frame_delta":Engine.get_physics_frames()-physics_start,"fps":times.size()/elapsed,"p95_ms":sorted[ceili(sorted.size()*0.95)-1],"p99_ms":sorted[ceili(sorted.size()*0.99)-1],"worst_ms":sorted[-1],"mean_process_ms":process_ms/times.size(),"mean_physics_ms":physics_ms/times.size(),"mean_draw_calls":draw_calls/times.size(),"unit_count":b.units.size(),"raw_frame_ms":times}
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--fixed-fps"): quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").game_speed=1.0
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	Engine.time_scale=1
	var index := 7 if OS.get_environment("PERF_LEVEL")=="" else int(OS.get_environment("PERF_LEVEL"))
	var b=await _start("skirmish" if OS.get_environment("PERF_DEFENSE")=="1" else "",index)
	var mode: String=OS.get_environment("PERF_MODE")
	if mode=="": mode="live"
	if mode=="paused_sim":
		b.set_process(false)
		for u in b.units: u.set_physics_process(false)
	b.camera.zoom=Vector2.ONE
	var camera_cell: Vector2i=b.level.camera_start_cell()
	var requested_cell := OS.get_environment("PERF_CELL").split(",")
	if requested_cell.size()==2: camera_cell=Vector2i(int(requested_cell[0]),int(requested_cell[1]))
	b.center_camera_cell(camera_cell)
	var result=await sample(b,mode)
	result["level_index"]=index
	result["level_id"]=b.level.id()
	result["camera_cell"]=[camera_cell.x,camera_cell.y]
	result["time_scale"]=Engine.time_scale
	result["renderer"]=RenderingServer.get_current_rendering_method()
	result["adapter"]=RenderingServer.get_video_adapter_name()
	result["godot"]=Engine.get_version_info().string
	result["resolution"]="1440x900"
	var output: String=OS.get_environment("PERF_OUT")
	if output=="": output="res://.godot/rts_performance.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	result.erase("raw_frame_ms")
	print("[rts-performance] ",JSON.stringify(result))
	await _dispose(b)
	quit()
