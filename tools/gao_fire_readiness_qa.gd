extends "res://tools/gao_rts_play.gd"
var liu_id := -1
var returned: Dictionary={}
func _economy_gao(b) -> void:
	if liu_id<0: liu_id=b.find_unit("liu_tang").entity_id
	super._economy_gao(b)
	if b.mission.has_event("gao_liu_returned") and returned.is_empty():
		var hero=b.find_unit("liu_tang")
		returned={"id":hero.entity_id,"hp":hero.hp,"position":str(hero.position),"outcome":hero.story_outcome,"fire_safe":b.mission.has_event("fire_escort_safe"),"abandoned":b.level.fire_abandoned}
func _capture_hint(b,u,name: String) -> void:
	u.show();u.fog_visible=true
	b.select_members([u],false)
	b.hud.update_selection_panel(b.selection);b.hud._refresh_panel()
	b.center_camera_cell(b.map.world_to_cell(u.position))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var label: Label=b.hud._info_stats
	check(b.hud._info_box.get_global_rect().encloses(label.get_global_rect()) and label.get_minimum_size().y<=label.size.y+1,name+" tactical hint fits unit panel")
	root.get_texture().get_image().save_png(out_dir+"/"+name+".png")
func _fixture() -> void:
	var b=await _start("",4)
	b.set_process(false);b.set_physics_process(false);b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	var l=b.level
	var liu=b.find_unit("liu_tang")
	var two=b.find_unit("ruan_xiaoer_boat")
	var five=b.find_unit("ruan_xiaowu_boat")
	check("公孙胜" in l.unit_tactical_hint(b,liu),"preparation explains wind before boarding")
	l.on_mission_action(b,"gao_wind",b.find_unit("gongsun_sheng"))
	check("60木" in l.unit_tactical_hint(b,liu),"wind completion explains real wood cost")
	l.on_mission_action(b,"gao_prepare",liu)
	var return_marker: Vector2 = b.map.cell_to_world(l.LIU_RETURN)
	check(b.mission.can_tap_action([l.fireboat],return_marker) and not b.mission.can_tap_action([two],return_marker),
		"only the original fireboat is eligible to return Liu Tang before ignition")
	l.fireboat.position=b.map.cell_to_world(l.FIRE_POINTS[1])
	two.position=l.fireboat.position+Vector2(220,0)
	five.position=l.fireboat.position+Vector2(-221,0)
	for foe in l.water_groups[1]: foe.position=Vector2(10000,10000)
	var enemy=l.water_groups[1][0]
	enemy.position=l.fireboat.position+Vector2(l.FIRE_ZONE_RADIUS,0)
	b._sight_now.fill(0);b._reveal_t.fill(0)
	check("尚未出发" in l._wave_objective(b) and "安全水域" in l.unit_tactical_hint(b,l.fireboat),
		"early preparation shows the safe-water waiting option before the wave")
	l.waves[1].sent=true
	check("进入火区" in l._wave_objective(b),
		"the prepared fire route tells players to await visible targets once the wave is moving")
	var marker_position: Vector2=l.fireboat.position
	l.fireboat.position=b.map.cell_to_world(l.FIRE_SAFE)
	check("到举火旗标" in l._wave_objective(b),
		"the objective directs the fireboat back to an actual ignition marker")
	l.fireboat.position=marker_position
	check(l._fire_targets(l.fireboat).size()==1 and "可见连船0" in l.unit_tactical_hint(b,l.fireboat),"hidden ship is not disclosed by tactical hint")
	var cell: Vector2i=b.map.world_to_cell(enemy.position)
	b._sight_now[cell.y*b.map.w+cell.x]=1
	check("可见连船1" in l.unit_tactical_hint(b,l.fireboat) and "到位1/2" in l.unit_tactical_hint(b,l.fireboat),"visible target and actual escort range are reported separately")
	check("两艘接应船" in l._wave_objective(b),"a visible target with a missing escort identifies the actual requirement")
	l.on_mission_action(b,"gao_fire_1",l.fireboat)
	check(not l.fire_lit,"one escort at 221 cannot satisfy existing fire action")
	five.position=l.fireboat.position+Vector2(-220,0)
	enemy.position=l.fireboat.position+Vector2(l.FIRE_ZONE_RADIUS+1.0,0)
	check(l._fire_targets(l.fireboat).is_empty() and l._fire_escorts(b,l.fireboat).size()==2,"actual fire radius is inclusive 230 and escort radius stays inclusive 220")
	enemy.position=l.fireboat.position+Vector2(l.FIRE_ZONE_RADIUS,0)
	var before: Array=[two._order_serial,five._order_serial,l.fireboat._order_serial,b.gold,b.wood]
	l.unit_tactical_hint(b,l.fireboat)
	check(before==[two._order_serial,five._order_serial,l.fireboat._order_serial,b.gold,b.wood],"hint does not issue orders or spend resources")
	b.hud.set_touch_ui(false)
	var action_source := "可以举火。选中火船，右键举火旗标。"
	var loc := root.get_node("Localize")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	for language in ["zh_CN","zh_TW","en","ja"]:
		loc.set_language(language,false)
		l._update_wave_objective(b)
		var expected: String=action_source if language=="zh_CN" else String(catalog[action_source][language])
		check(b.mission._objective.text==expected and expected in l.unit_tactical_hint(b,l.fireboat),
			language+" task and unit panel agree on the original ignition action")
	loc.set_language("zh_CN",false)
	l.waves[2].sent=true
	check("第三批" in l._wave_objective(b),"third-wave core defense guidance retains precedence over optional fire")
	l.waves[2].sent=false
	root.get_node("Localize").set_language("en",false)
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	await _capture_hint(b,l.fireboat,"en_ready_960")
	root.get_node("Localize").set_language("zh_CN",false)
	l.on_mission_action(b,"gao_fire_1",l.fireboat)
	check(l.fire_lit and l.liu_carrier==two,"shared readiness preserves actual fire transfer")
	check(b.mission.actions.gao_liu_return.actors==["ruan_xiaoer_boat"] and b.mission.can_tap_action([two],return_marker)
		and not b.mission.can_tap_action([five],return_marker),"return marker switches to the actual passenger carrier")
	check("撤到安全水域" in l._wave_objective(b),"an actual ignition hands off to the two-ship withdrawal")
	two.position=b.map.cell_to_world(l.FIRE_SAFE)
	five.position=two.position+Vector2(121,0)
	check("安全区1/2" in l.unit_tactical_hint(b,two),"withdrawal counts only ships in the safe radius")
	for foe in b.units:
		if foe.faction==1: foe.position=Vector2(10000,10000)
	l.on_mission_action(b,"gao_fire_withdraw",two)
	check(not b.mission.has_event("fire_escort_safe"),"one ship outside safe radius cannot complete withdrawal")
	five.position=two.position+Vector2(120,0)
	l.on_mission_action(b,"gao_fire_withdraw",two)
	check(b.mission.has_event("fire_escort_safe"),"two safe ships complete the original withdrawal")
	var return_source := "双船已撤离，火攻演义保留。可让阮小二送刘唐返港下船。"
	var safe_source := "双船已撤离，火攻演义保留。"
	for language in ["zh_CN","zh_TW","en","ja"]:
		loc.set_language(language,false)
		l._update_wave_objective(b)
		var current: String = return_source if language=="zh_CN" else String(catalog[return_source][language])
		var safe: String = safe_source if language=="zh_CN" else String(catalog[safe_source][language])
		check(b.mission._objective.text==current and l.unit_tactical_hint(b,two)==current and l.unit_tactical_hint(b,five)==safe,
			language+" live objective names the carrier and only its panel offers return")
	await _capture_hint(b,two,"ja_safe_960")
	loc.set_language("zh_CN",false)
	two.position=return_marker
	l.on_mission_action(b,"gao_liu_return",two)
	l._update_wave_objective(b)
	check(b.mission.has_event("gao_liu_returned") and b.mission.has_event("fire_escort_safe") and liu.story_outcome=="",
		"original Liu Tang returns ashore and keeps the fire objective")
	check(l.unit_tactical_hint(b,two)==safe_source and l.unit_tactical_hint(b,five)==safe_source
		and "普通战船" in b.mission._objective.text,"after unloading, both panels stop offering a return and the task returns to fleet defense")
	await _dispose(b)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	out_dir="res://.godot/gao-fire-readiness"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var flow := root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec()+180000
	while not flow.can_launch():
		if flow.phase==flow.Phase.ERROR or Time.get_ticks_msec()>=deadline:
			push_error("Campaign startup phase %s: %s" % [flow.phase, flow.last_result])
			quit(2)
			return
		await process_frame
	if OS.get_environment("FIRE_LIVE_ONLY")!="1": await _fixture()
	var fixture_checks := checks
	if OS.get_environment("FIRE_FIXTURE_ONLY")!="1":
		root.get_node("Localize").set_language("zh_CN",false)
		build_cells=[Vector2i(24,26),Vector2i(26,40),Vector2i(14,42),Vector2i(10,43),Vector2i(21,40),Vector2i(26,23),Vector2i(9,31),Vector2i(15,24)]
		route="story"
		var b=await _start("",4)
		Engine.time_scale=4
		print("[gao-fire] time_scale=",Engine.time_scale)
		await _play_gao(b)
		check(returned.get("id",-2)==liu_id and returned.get("outcome","missing")=="","original Liu Tang returns ashore through normal orders")
		check(returned.get("fire_safe",false) and not returned.get("abandoned",true),"actual completed withdrawal survives disembarking")
		play_metrics["liu_return"]=returned
		await _dispose(b)
	Engine.time_scale=1
	var report={"passed":failures.is_empty(),"checks":checks,"fixture_checks":fixture_checks,"failures":failures,"metrics":play_metrics,"scope":"explicit readiness fixtures and/or actual fire-return-capture route; no whole-world restore, human or performance qualification"}
	FileAccess.open(out_dir+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[gao-fire] ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
