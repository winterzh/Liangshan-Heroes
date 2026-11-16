extends "res://tools/jiangzhou_rts_play.gd"
## Focused dock feedback fixture, followed by one live story route.

func _fixture() -> Dictionary:
	var b = await _start("",1)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	var l = b.level
	l.execution_halted = true
	l._free(b,true)
	l._free(b,false)
	var chao = l.named_units.chao_gai
	l.on_mission_action(b,"rally_dock",chao)
	l.on_mission_action(b,"rally_dock",chao)
	var buttons: Array = b.mission._buttons.get_children().filter(func(node):
		return node.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","")=="jiang_find_rearguard")
	check(buttons.size()==1 and "jiang_find_rearguard" in b.mission.LEVEL_BUTTON_IDS.level2,
		"rally registers one stable dock locator")
	var button: Button = buttons[0]
	var dock: Vector2 = b.map.cell_to_world(l.DOCK)
	for key in l.NAMED: l.named_units[key].position=dock+Vector2(130,0)
	chao.position=b.map.cell_to_world(Vector2i(32,26))
	l.named_units.zhang_heng.resolve_story("embarked")
	var fallen = l.named_units.yan_shun
	var fallen_name: String = fallen.display_name
	fallen.take_damage(100000.0,l.executioners[0],false,true)
	fallen.queue_free()
	await process_frame
	var roster: Dictionary = l._dock_roster(b)
	check(roster.aboard==1 and roster.lost==1 and roster.ashore.size()==4 and roster.farthest==chao,
		"roster distinguishes original passengers, living allies ashore and fallen allies")
	var current = l.named_units.li_kui
	b.select_members([current],false)
	var before: Array = [b.selection.duplicate(),current._order_serial,chao._order_serial,b.mission.active_action_id]
	b.center_camera_cell(b.map.world_to_cell(chao.position))
	var expected: Vector2 = b.camera.position
	b.center_camera_cell(l.DOCK)
	button.pressed.emit()
	check(b.camera.position==expected and b.camera.position!=b.to_screen(dock)
		and before==[b.selection.duplicate(),current._order_serial,chao._order_serial,b.mission.active_action_id],
		"the locator only moves the camera and leaves selection and orders alone")
	var hints := {}
	var localize = root.get_node("Localize")
	var phrases := {"zh_CN":"仍在岸上","zh_TW":"仍在岸上","en":"Still ashore","ja":"岸に残る仲間"}
	for locale in phrases:
		localize.set_language(locale,false)
		b.mission.set_status("")
		l._update_dock_guidance(b)
		var hint: String = b.mission._status.text
		hints[locale]=hint
		check(phrases[locale] in hint and "1/6" in hint and localize.text(chao.display_name) in hint
			and not localize.text(fallen_name) in hint,"localized dock roster is current in "+locale)
	localize.set_language("zh_CN",false)
	b.mission.set_feedback("定位反馈仍在显示")
	l._update_dock_guidance(b)
	check(b.mission._status.text=="定位反馈仍在显示","roster does not overwrite active action feedback")
	for ally in roster.ashore: ally.resolve_story("embarked")
	b.mission.set_status("")
	l._update_dock_guidance(b)
	check("5/6" in b.mission._status.text and "阵亡1" in b.mission._status.text and not "仍在岸上" in b.mission._status.text,
		"all survivors aboard leaves the lost named ally out of the credit")
	button.pressed.emit()
	check(b.mission._status.text=="幸存好汉都已登船。","locator explains when nobody is left ashore")
	var data := {"initial_aboard":roster.aboard,"initial_lost":roster.lost,"hints":hints,"after_aboard":5}
	await _dispose(b)
	return data

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	var fixture := await _fixture()
	route="story"
	var b = await _start("",1)
	Engine.time_scale=4
	await _play_rescue(b)
	var roster: Dictionary=b.level._dock_roster(b)
	check(b.level.rally and roster.aboard==6 and roster.lost==0
		and "named_survive" in play_metrics.result.done_ids,
		"the real rally and boarding route settles all six original heroes as credit")
	print("JIANGZHOU_DOCK_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"fixture":fixture,"live":play_metrics,
		"live_crew_aboard":roster.aboard,"time_scale":Engine.time_scale}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
