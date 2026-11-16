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
	l.fireboat.position=b.map.cell_to_world(l.FIRE_POINTS[1])
	two.position=l.fireboat.position+Vector2(220,0)
	five.position=l.fireboat.position+Vector2(-221,0)
	for foe in l.water_groups[1]: foe.position=Vector2(10000,10000)
	var enemy=l.water_groups[1][0]
	enemy.position=l.fireboat.position+Vector2(l.FIRE_ZONE_RADIUS,0)
	b._sight_now.fill(0);b._reveal_t.fill(0)
	check(l._fire_targets(l.fireboat).size()==1 and "可见连船0" in l.unit_tactical_hint(b,l.fireboat),"hidden ship is not disclosed by tactical hint")
	var cell: Vector2i=b.map.world_to_cell(enemy.position)
	b._sight_now[cell.y*b.map.w+cell.x]=1
	check("可见连船1" in l.unit_tactical_hint(b,l.fireboat) and "到位1/2" in l.unit_tactical_hint(b,l.fireboat),"visible target and actual escort range are reported separately")
	l.on_mission_action(b,"gao_fire_1",l.fireboat)
	check(not l.fire_lit,"one escort at 221 cannot satisfy existing fire action")
	five.position=l.fireboat.position+Vector2(-220,0)
	enemy.position=l.fireboat.position+Vector2(l.FIRE_ZONE_RADIUS+1.0,0)
	check(l._fire_targets(l.fireboat).is_empty() and l._fire_escorts(b,l.fireboat).size()==2,"actual fire radius is inclusive 230 and escort radius stays inclusive 220")
	enemy.position=l.fireboat.position+Vector2(l.FIRE_ZONE_RADIUS,0)
	var before: Array=[two._order_serial,five._order_serial,l.fireboat._order_serial,b.gold,b.wood]
	l.unit_tactical_hint(b,l.fireboat)
	check(before==[two._order_serial,five._order_serial,l.fireboat._order_serial,b.gold,b.wood],"hint does not issue orders or spend resources")
	root.get_node("Localize").set_language("en",false)
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	await _capture_hint(b,l.fireboat,"en_ready_960")
	root.get_node("Localize").set_language("zh_CN",false)
	l.on_mission_action(b,"gao_fire_1",l.fireboat)
	check(l.fire_lit and l.liu_carrier==two,"shared readiness preserves actual fire transfer")
	two.position=b.map.cell_to_world(l.FIRE_SAFE)
	five.position=two.position+Vector2(121,0)
	check("安全区1/2" in l.unit_tactical_hint(b,two),"withdrawal counts only ships in the safe radius")
	for foe in b.units:
		if foe.faction==1: foe.position=Vector2(10000,10000)
	l.on_mission_action(b,"gao_fire_withdraw",two)
	check(not b.mission.has_event("fire_escort_safe"),"one ship outside safe radius cannot complete withdrawal")
	five.position=two.position+Vector2(120,0)
	l.on_mission_action(b,"gao_fire_withdraw",two)
	check(b.mission.has_event("fire_escort_safe") and "成果保留" in l.unit_tactical_hint(b,two),"two safe ships unlock original completion and return advice")
	root.get_node("Localize").set_language("ja",false)
	check("演義目標" in l.unit_tactical_hint(b,two) and not "演义成果" in l.unit_tactical_hint(b,two),"completed return advice is actually localized in Japanese")
	await _capture_hint(b,two,"ja_safe_960")
	await _dispose(b)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	out_dir="res://.godot/gao-fire-readiness"
	DirAccess.make_dir_recursive_absolute(out_dir)
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
