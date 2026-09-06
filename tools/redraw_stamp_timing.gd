extends "res://tools/chase_speed_qa.gd"
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute("res://.godot/redraw_stamp_timing")
	check(FileAccess.get_sha256("res://tools/contracts/redraw_stamp/before_68a9430.txt")=="9f446ffd3c70c9e7cadd4a30b9080aa0889102f0e25e884b558f65fe975e4588","frozen redraw helper hash matches")
	Engine.max_fps=60
	var b=await _start("level1");b.process_mode=Node.PROCESS_MODE_DISABLED
	var scripts:=[]
	for path in ["res://tools/contracts/redraw_stamp/before_68a9430.txt",""]:
		var script:=GDScript.new();script.source_code='extends "res://scripts/unit.gd"\n'+(FileAccess.get_file_as_string(path) if not path.is_empty() else "")
		check(script.reload()==OK,"complete redraw helper compiles "+path);scripts.append(script)
	var samples:=[]
	for count in [1,64,206]:
		var groups: Array=[[],[]]
		for which in range(2):
			for i in range(count):
				var u=_unit(b,scripts[which],0);u.set_physics_process(false);groups[which].append(u)
		for repeats in [1,4]:
			var windows:=[];var before:=[];var after:=[]
			var totals: Array[int]=[0,0]
			var frames:=[]
			for tick in range(70):
				await physics_frame
				for which in ([0,1] if tick%2==0 else [1,0]):
					var start:=Time.get_ticks_usec()
					for repeat in range(repeats):
						for u in groups[which]:u._request_redraw()
					var elapsed:=Time.get_ticks_usec()-start
					if tick>=10:totals[which]+=elapsed
				if tick>=10:frames.append(Engine.get_process_frames())
				if tick>=10 and (tick-9)%20==0:
					windows.append({"reference_us":totals[0],"candidate_us":totals[1]})
					before.append(totals[0]);after.append(totals[1]);totals=[0,0]
			before.sort();after.sort()
			samples.append({"units_each":count,"requests_per_unit_per_physics_tick":repeats,"physics_ticks_per_window":20,"frames":frames,"windows":windows,"reference_us":before[1],"candidate_us":after[1],"ratio":float(after[1])/before[1]})
		for group in groups:
			for u in group:u.free()
	FileAccess.open("res://.godot/redraw_stamp_timing/report.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"failures":failures,"checks":report.mode_checks.size(),"scope":"Complete request helpers in real physics callbacks with identical units, warmup then three twenty-tick windows; alternates order each tick. Includes first signal connection and repeated requests, excludes later unchanged CanvasItem callback/render work. Not FPS."},"\t"))
	await _dispose(b);quit(0 if failures.is_empty() else 1)
