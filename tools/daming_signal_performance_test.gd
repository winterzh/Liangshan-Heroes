extends "res://tools/campaign_mode_performance_test.gd"
## One rendered sample reached through the normal campaign HUD and authored mission driver.
## No stage-deployment shortcut, HP change, invulnerability, extra units or damage injection.

func _unit_receipts(b) -> Array:
	var result := []
	for u in b.units:
		if not is_instance_valid(u): continue
		result.append({"instance_id":u.get_instance_id(),"key":u.key,"faction":u.faction,
			"cell":str(b.map.world_to_cell(u.position)),"hp":u.hp,"max_hp":u.max_hp,"story_outcome":u.story_outcome})
	return result

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		print("[daming-render] real renderer required; headless performance is refused")
		quit(2)
		return
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--fixed-fps"):
			print("[daming-render] fixed-fps invalidates frame-time sampling")
			quit(2)
			return
	OS.set_environment("CAMPAIGN_QA","1")
	output=OS.get_environment("DAMING_PERFORMANCE_OUT")
	if output=="": output=ProjectSettings.globalize_path("res://qa/campaign_runtime/content2_daming")
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before := _save_hash()
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var settings=root.get_node("Settings")
	settings.edge_scroll=false
	settings.auto_micro_level=0
	settings.game_speed=1.0
	AudioServer.set_bus_mute(0,true)
	report["sample_scope"]="One 10-second rendered Daming fire-signal window. Normal HUD start and authored smoke mission commands reach the signal; task automation is then disabled while unit AI/combat continues. No change to HP, unit counts, damage, immunity or defeat rules. This is not a human playtest, stable-FPS claim, or whole-level worst case."
	report["renderer"]={"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"vendor":RenderingServer.get_video_adapter_vendor(),"api":RenderingServer.get_video_adapter_api_version(),
		"method":RenderingServer.get_current_rendering_method(),"vsync":DisplayServer.window_get_vsync_mode(),
		"godot":Engine.get_version_info(),"sample_time_scale":1.0,"prepare_time_scale":4.0,
		"physics_ticks_per_second":Engine.physics_ticks_per_second,"fixed_fps":false,"max_fps":Engine.max_fps}
	var machine_path := output.path_join("machine_and_process_gate.json")
	if FileAccess.file_exists(machine_path): report["machine_and_process_gate"]=JSON.parse_string(FileAccess.get_file_as_string(machine_path))
	var b=await _start("level8")
	report["initial_campaign_units"]=_unit_receipts(b)
	report["initial_counts"]=_counts(b)
	b._smoke=true
	Engine.time_scale=4.0
	var prepare_started := Time.get_ticks_msec()
	var deadline := prepare_started+55000
	while not b.mission.has_event("daming_fire_lit") and b.phase==b.Phase.FIGHT and Time.get_ticks_msec()<deadline:
		await process_frame
	b._smoke=false
	Engine.time_scale=1.0
	check(b.mission.has_event("daming_fire_lit") and b.phase==b.Phase.FIGHT and b.level.stage=="gate","Normal mission commands reach the authored fire signal in a live battle")
	check(b.mission.active_action_id=="","No mission action remains queued when task automation stops")
	report["prepare"]={"wall_seconds":float(Time.get_ticks_msec()-prepare_started)/1000.0,
		"game_seconds":b.mission.total_game_seconds,"stage":b.level.stage,"events":b.mission.events.keys(),
		"stage_metrics":b.mission.stage_metrics.duplicate(true),"phase":int(b.phase),"counts":_counts(b),
		"kills":b.kills,"units":_unit_receipts(b)}
	if failures.is_empty():
		# Keep the full city, fire tower and gate force in the activity region; ordinary gameplay camera only.
		_camera(b,Vector2i(32,30),0.75)
		report["camera"]={"cell":"(32,30)","zoom":0.75}
		var stage_at_start: String=b.level.stage
		var kills_at_start: int=b.kills
		await _sample(b,"daming_fire_signal")
		var sample: Dictionary=report.samples.back()
		sample["stage_at_start"]=stage_at_start
		sample["stage_at_end"]=b.level.stage
		sample["kills_before_warmup"]=kills_at_start
		sample["task_automation_enabled"]=b._smoke
		sample["units_at_end"]=_unit_receipts(b)
		sample["valid_live_render_sample"]=not sample.ended_during_sample and sample.wall_seconds>=10.0 and sample.mean_draw_calls>0
		report["post_sample_mission"]={"stage":b.level.stage,"events":b.mission.events.keys(),"game_seconds":b.mission.total_game_seconds,"active_action":b.mission.active_action_id}
	await _dispose(b)
	check(_save_hash()==saved_before,"CAMPAIGN_QA leaves campaign progress bytes unchanged")
	report["save_hash_before"]=saved_before
	report["save_hash_after"]=_save_hash()
	report["passed"]=failures.is_empty()
	report["failures"]=failures
	var file := FileAccess.open(output.path_join("runtime_performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("[daming-render-result] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
