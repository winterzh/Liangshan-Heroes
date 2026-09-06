extends "res://tools/unit_redraw_qa.gd"
const STAMP_REFERENCE := "res://tools/contracts/redraw_stamp/before_68a9430.txt"
const STAMP_SHA := "9f446ffd3c70c9e7cadd4a30b9080aa0889102f0e25e884b558f65fe975e4588"
var physics_marks := []
func _physics_fixture() -> void:
	super()
	if ticking:
		physics_marks.append({"frame":Engine.get_process_frames(),"queued":pair[1]._queued_redraw_frame,"reference_connected":process_frame.is_connected(pair[0].queue_redraw),"current_connected":process_frame.is_connected(pair[1].queue_redraw)})

func _compare_stamped(b,key: String,mode: String,variant: String,fps: int) -> void:
	Engine.max_fps=fps
	await _make_pair(b,key,variant)
	visual_case=mode;ticking=true
	await RenderingServer.frame_post_draw
	var pixels_equal:=true;var states_equal:=true;var cadence_equal:=true;var rows:=[]
	for i in range(8):
		var old_count: int=pair[0].qa_draws;var new_count: int=pair[1].qa_draws;var previous_tick:=tick_id
		await RenderingServer.frame_post_draw
		var a: Image=views[0].get_texture().get_image();var z: Image=views[1].get_texture().get_image()
		pixels_equal=pixels_equal and a.get_data()==z.get_data()
		states_equal=states_equal and pair[1].qa_last==pair[1].qa_snapshot() and pair[0].qa_last==pair[1].qa_last
		var old_delta: int=pair[0].qa_draws-old_count;var new_delta: int=pair[1].qa_draws-new_count
		cadence_equal=cadence_equal and old_delta==new_delta and new_delta<=1
		rows.append({"physics_ticks":tick_id-previous_tick,"reference_draws":old_delta,"current_draws":new_delta})
		if i==7 and fps==15 and key=="song_jiang" and mode=="attack":
			check(a.save_png(output.path_join("attack_reference.png"))==OK and z.save_png(output.path_join("attack_current.png"))==OK,"paired current-baseline attack pixels saved")
	var label:=key+" "+mode+" "+variant+" at "+str(fps)+" FPS cap"
	check(pixels_equal,label+" identical actual RGBA every rendered frame")
	check(states_equal,label+" current physics state reaches the same rendered frame")
	check(cadence_equal,label+" same draw cadence and at most one draw per rendered frame")
	samples.append({"key":key,"case":mode,"variant":variant,"fps_cap":fps,"frames":8,"frame_rows":rows})
	await _remove_pair()

func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/redraw_stamp_qa");DirAccess.make_dir_recursive_absolute(output)
	var saved:=_save_hash()
	check(FileAccess.get_sha256(STAMP_REFERENCE)==STAMP_SHA,"frozen 68a9430 complete helper hash matches")
	root.size=Vector2i(960,640);DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.time_scale=1.0;Engine.max_fps=15;Engine.physics_ticks_per_second=60
	for reference in [true,false]:
		var script:=GDScript.new();script.source_code=COUNTED+(FileAccess.get_file_as_string(STAMP_REFERENCE) if reference else "")
		check(script.reload()==OK,"counted actual Unit compiles reference="+str(reference));counted_scripts.append(script)
	if not failures.is_empty():quit(2);return
	var b=await _start("level5");b.process_mode=Node.PROCESS_MODE_DISABLED;b._lite_fx=false
	physics_frame.connect(_physics_fixture)
	for fps in [15,60]:
		for spec in [["song_jiang","walk",""],["song_jiang","attack",""],["song_jiang","death",""],["song_jiang","idle","song_jiang_bound"],["guan_dao","walk",""],["hua_rong","attack",""],["arrow_tower","burn",""],["tree","harvest",""]]:
			await _compare_stamped(b,spec[0],spec[1],spec[2],fps)
	Engine.max_fps=15
	await _lifecycle(b)
	physics_frame.disconnect(_physics_fixture)
	check(physics_marks.size()>100 and physics_marks.all(func(row):return row.frame==row.queued and row.reference_connected and row.current_connected),"actual physics requests share the expected process frame and one-shot signal")
	check(samples.filter(func(s):return s.fps_cap==15).all(func(s):return s.frame_rows.any(func(row):return row.physics_ticks>1)),"every 15 FPS case exercises catch-up physics")
	await _dispose(b,true);check(_save_hash()==saved,"player campaign save bytes unchanged")
	report["samples"]=samples;report["physics_marks"]=physics_marks;report["passed"]=failures.is_empty();report["failures"]=failures
	report["scope"]="Frozen 68a9430 one-shot scheduling versus production frame stamp, same actual Unit visual states with real 60Hz physics and rendering at 15/60 FPS caps. 128 paired images compared as raw RGBA. Includes input/pause/hidden/detached/freed lifecycle; not normal combat FPS."
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[redraw-stamp-qa] ",JSON.stringify({"checks":report.mode_checks.size(),"passed":report.passed,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
