extends "res://tools/campaign_mode_performance_test.gd"
## 补测：正常下令护送获救者到庄内安全空地，再开门采样；不改数值、数量、结算。

func _wait_event(b, event: String) -> bool:
	var deadline := Time.get_ticks_msec()+20000
	while not b.mission.has_event(event) and b.phase==b.Phase.FIGHT and Time.get_ticks_msec()<deadline:
		await process_frame
	return b.mission.has_event(event) and b.phase==b.Phase.FIGHT

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		print("[zhu-escort] real renderer required")
		quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	OS.set_environment("CAMPAIGN_TERRAIN_BATCH","1")
	output=ProjectSettings.globalize_path("res://qa/campaign_runtime/optimized_zhu_escort")
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before := _save_hash()
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var settings=root.get_node("Settings")
	settings.edge_scroll=false; settings.auto_micro_level=0; settings.game_speed=1.0
	AudioServer.set_bus_mute(0,true)
	report["fixture_difference"]="Compared with the older performance fixture, ordinary move orders retreat rescued prisoners and ordinary attack orders provide covering action before opening the gate. HP, counts, damage and victory/failure rules are unchanged. Do not use as a strictly matched FPS comparison."
	report["renderer"]={"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),
		"method":RenderingServer.get_current_rendering_method(),"vsync":DisplayServer.window_get_vsync_mode(),"godot":Engine.get_version_info()}
	var b=await _start("level3")
	b.level._third_day(b)
	report["zhu_authored_deployment"]=_counts(b)
	Engine.time_scale=4.0
	b.mission.request_action("zhu_enter_manor")
	check(await _wait_event(b,"zhu_sun_entered"),"Sun enters through the authored mission action")
	if failures.is_empty():
		b.mission.request_action("zhu_free_prisoners")
		check(await _wait_event(b,"zhu_prisoners_freed"),"Prisoners released through the authored mission action")
	var escorted: Array=[]
	if failures.is_empty():
		for i in range(b.level.prisoners.size()):
			var u=b.level.prisoners[i]
			var goal: Vector2=b.map.cell_to_world(Vector2i(14+i%4,37+i/4))
			escorted.append({"unit":u,"goal":goal,"start":str(u.position),"hp_start":u.hp})
			u.order_move(goal)
		for rescuer in [b.level.sun,b.level.gu]:
			var target=null
			var distance := INF
			for foe in b.units_of(1):
				if foe.key!="zhu_keke": continue
				var d: float=rescuer.position.distance_to(foe.position)
				if d<distance: distance=d; target=foe
			if target!=null: rescuer.order_attack(target)
		var deadline := Time.get_ticks_msec()+15000
		while b.phase==b.Phase.FIGHT and Time.get_ticks_msec()<deadline:
			var arrived: bool=escorted.all(func(e):return e.unit.hp>0 and e.unit.position.distance_to(e.goal)<44.0)
			if arrived: break
			await process_frame
		check(escorted.all(func(e):return e.unit.hp>0 and e.unit.position.distance_to(e.goal)<44.0),"All seven prisoners actually reach cover alive using move orders")
		report["escort_receipts"]=escorted.map(func(e):return {"key":e.unit.key,"start":e.start,"destination":str(e.goal),"arrived":str(e.unit.position),"hp_start":e.hp_start,"hp_arrived":e.unit.hp})
	if failures.is_empty():
		b.mission.request_action("zhu_open_gate")
		check(await _wait_event(b,"zhu_gate_opened"),"Sun opens gate after the escorted prisoners reach cover")
	Engine.time_scale=1.0
	if failures.is_empty():
		_camera(b,Vector2i(29,29),0.8)
		await _sample(b,"zhu_authored_assault_escorted")
	await _dispose(b)
	check(_save_hash()==saved_before,"CAMPAIGN_QA leaves campaign progress bytes unchanged")
	report["save_hash_before"]=saved_before; report["save_hash_after"]=_save_hash()
	report["passed"]=failures.is_empty(); report["failures"]=failures
	var file := FileAccess.open(output.path_join("runtime_performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("[zhu-escort-result] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
