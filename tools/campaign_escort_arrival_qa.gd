extends "res://tools/yezhulin_short_test.gd"
## Frozen arrival boundaries and one existing, unmodified live north route.
var arrival_observations: Array=[]
func _freeze_arrival(b) -> void:
	b.set_process(false)
	b.set_physics_process(false)
	b.hud.set_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
func _arrival_fixture() -> void:
	var b=await _start("",5)
	_freeze_arrival(b)
	var l=b.level
	l._begin_open_rescue(b,"arrival fixture")
	for guard in l.escorts: guard.resolve_story("subdued")
	l.lu.position=l.lin_bound.position+Vector2(50,0)
	l.process(b,2)
	_freeze_arrival(b)
	l.process(b,3)
	check(l.st==l.ESCAPE,"fixture reaches original rescue handoff")
	var group: Array=l._escort_group()
	var rest: Vector2=b.map.cell_to_world(l.REST)
	for u in group: u.position=rest
	l.escorts[1].position=rest+Vector2(250,0)
	l.escort_player_target=rest
	var state: Dictionary=l._escort_arrival_at(rest,96)
	check(state.arrived==3 and state.total==4 and state.missing==[l.escorts[1]],"rest arrival names exactly the one missing survivor")
	check(l._escort_heading_to_rest(b) and not l._survivors_near(rest,96),"readout and actual rest gate share the same boundary")
	l.lin_freed.hp-=20
	var hp: float=l.lin_freed.hp
	l.on_mission_action(b,"rest_stop",l.lin_freed)
	check(not l.rest_reached and l.lin_freed.hp==hp and not b.mission.actions.rest_stop.done,"missing companion does not consume rest or heal")
	var buttons: Array=b.mission._buttons.get_children().filter(func(c): return c.get_meta("campaign_presentation_v1",{}).get("button_id","")=="pine_waiting")
	check(buttons.size()==1,"arrival locator is registered as one actual level button")
	if buttons.is_empty(): await _dispose(b); return
	var descriptor: Dictionary=buttons[0].get_meta("campaign_presentation_v1")
	var presentation=load("res://scripts/run_campaign_presentation_state.gd").new()
	check(presentation._descriptor_valid(descriptor,{"level_id":"level6"}),"presentation contract accepts the installed locator ID")
	b.select_single(l.lin_freed,false)
	var selection: Array=b.selection.duplicate()
	var serials: Array=group.map(func(u): return u._order_serial)
	var positions: Array=group.map(func(u): return u.position)
	b.center_camera_cell(b.map.world_to_cell(l.escorts[1].position))
	var expected_camera: Vector2=b.camera.position
	b.center_camera_cell(l.PINE)
	buttons[0].pressed.emit()
	check(b.camera.position==expected_camera,"actual button finds farthest missing companion")
	check(b.selection==selection and serials==group.map(func(u): return u._order_serial) and positions==group.map(func(u): return u.position),"viewing does not select, issue orders or move anyone")
	check("3/4" in b.mission._status.text and l.escorts[1].display_name in b.mission._status.text,"feedback includes count and missing name")
	l.escorts[1].position=rest+Vector2(98,0)
	check(l._survivors_near(rest,96) and l._escort_arrival_at(rest,96).arrived==4,"native two-pixel settling margin is counted")
	l.escorts[1].position=rest+Vector2(99,0)
	check(not l._survivors_near(rest,96) and l._escort_arrival_at(rest,96).arrived==3,"one pixel beyond margin is still missing")
	var exit_point: Vector2=b.map.cell_to_world(l.EXIT_W)
	for u in group: u.position=exit_point
	l.escorts[0].position=b.map.cell_to_world(l.REST)
	l.escorts[1].position=b.map.cell_to_world(l.PINE)
	l.escort_player_target=exit_point
	l.on_mission_action(b,"leave_forest",l.lin_freed)
	l.process(b,0)
	check(not l.victory and "2/4" in l.top_status(b) and not l._escort_heading_to_rest(b),"exit still waits for both living guards and displays 2/4")
	check(l._escort_arrival_at(exit_point,l.EXIT_R).farthest==l.escorts[1],"exit locator ranks actual distance")
	for language in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(language,false)
		b.mission.set_status(l._escort_arrival_guidance(b,false))
		b.hud.set_top(l.top_status(b))
		check("2/4" in b.mission._status.text and "2/4" in l.top_status(b),language+" arrival formats include both counters")
		arrival_observations.append({"language":language,"status":b.mission._status.text,"top":l.top_status(b),"button":buttons[0].text})
		if language in ["zh_CN","en"]:
			root.size=Vector2i(1280,720) if language=="zh_CN" else Vector2i(960,540)
			root.content_scale_size=root.size
			b.mission._set_expanded(true)
			for i in range(8):
				b.hud._refresh_hero_bar(); b.hud._refresh_resource_values(); b.mission.tick(0); b.hud._layout_info_panel()
				await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/"+language+".png")==OK,language+" actual-renderer screenshot")
	root.get_node("Localize").set_language("zh_CN",false)
	l.escorts[0].hp=0 # Explicit death boundary only; no live victory claim.
	state=l._escort_arrival_at(exit_point,l.EXIT_R)
	check(state.total==3 and state.arrived==2 and state.missing==[l.escorts[1]],"dead escort is not an impossible fourth arrival requirement")
	l.escorts[1].position=exit_point
	check(l._escort_arrival_at(exit_point,l.EXIT_R).missing.is_empty() and l._survivors_near(exit_point,l.EXIT_R),"all surviving companions satisfy the unchanged arrival gate")
	check(load("res://tools/level6_world_restore_qa.gd")!=null,"updated restore callback fixture compiles; full restore not run")
	await _dispose(b)
func _early_care_fixture() -> void:
	var b=await _start("",5)
	_freeze_arrival(b)
	var l=b.level
	l._begin_open_rescue(b,"care fixture")
	check("2名" in l._care_guidance() and l._escorts_threatening(),"both active guards count as resisting")
	l.escorts[0].resolve_story("subdued")
	check("1名" in l._care_guidance(),"subdued guard no longer contributes to resistance")
	l.escorts[1].resolve_story("subdued")
	l.lu.position=l.lin_bound.position+Vector2(l.CARE_REACH+1,0)
	check(not l._escorts_threatening() and "回到林冲身边" in l._care_guidance(),"clear fight prompts return until the real care boundary")
	l.lu.position=l.lin_bound.position+Vector2(l.CARE_REACH,0)
	check("正在解缚" in l._care_guidance(),"actual care range changes feedback to untying")
	l.process(b,l.UNTIE_TIME)
	check(is_instance_valid(l.lin_freed) and "正在照伤" in l._care_guidance(),"untying hands off to real tending feedback")
	await _dispose(b)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var force_only := OS.get_environment("YF_FORCE_ONLY")=="1"
	folder="res://.godot/yezhulin-early-force" if force_only else "res://.godot/campaign-escort-arrival"
	DirAccess.make_dir_recursive_absolute(folder)
	if force_only: await _early_care_fixture()
	else: await _arrival_fixture()
	Engine.time_scale=4
	await _live("force" if force_only else "north")
	Engine.time_scale=1
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"fixture_observations":arrival_observations,"live_cases":cases,"scope":"focused care transitions plus actual early-force route" if force_only else "frozen arrival/locator boundaries plus existing north live route; not full restore, human fun or device/performance acceptance"},"\t"))
	quit(0 if failures.is_empty() else 1)
