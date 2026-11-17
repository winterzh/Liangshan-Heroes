extends "res://tools/jiangzhou_rts_play.gd"

func _fixture() -> Dictionary:
	var b = await _start("",1)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	var l = b.level
	l.execution_halted = true
	l._free(b,true)
	var buttons: Array = b.mission._buttons.get_children().filter(func(node):
		return node.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","")=="jiang_bailong_meeting")
	check(buttons.size()==1,"first rescue exposes exactly one installed rendezvous button")
	if buttons.is_empty():
		await _dispose(b)
		return {}
	var button: Button = buttons[0]
	button.pressed.emit()
	check("先解救宋江、戴宗" in b.mission._status.text,"awaiting second rescue explains the requirement")
	l._free(b,false)
	var at_temple: Vector2 = b.map.cell_to_world(l.BAILONG)
	var west = l.named_units.zhang_shun
	var south = l.named_units.zhang_heng
	l.song_freed.position = at_temple
	l.dai_freed.position = at_temple + Vector2(1,0)
	west.position = at_temple + Vector2(129,0)
	south.position = at_temple + Vector2(130,0)
	b.select_members([west],false)
	var serial: int = west._order_serial
	b.center_camera_cell(l.BAILONG)
	var expected_center: Vector2 = b.camera.position
	b.center_camera_cell(l.SCAFFOLD)
	var hints := {}
	var localize = root.get_node("Localize")
	var captions := {"zh_CN":"查看 · 白龙庙","zh_TW":"查看 · 白龍廟","en":"View · White Dragon Temple","ja":"確認 · 白竜廟"}
	for locale in captions:
		localize.set_language(locale,false)
		button.pressed.emit()
		var hint: String = b.mission._status.text
		hints[locale] = hint
		check(button.text == captions[locale] and "3/4" in hint and localize.text(south.display_name) in hint
			and localize.text(west.display_name) not in hint,"only the missing member is named in "+locale)
	check(b.camera.position==expected_center and b.selection==[west] and west._order_serial==serial
		and not l.meeting,"looking at the temple only moves the camera")
	localize.set_language("zh_CN",false)
	l.song_freed.story_outcome = "embarked"
	button.pressed.emit()
	check("可直接护送二人登船" in b.mission._status.text,"an already boarded rescuee no longer implies a temple meeting")
	l.song_freed.story_outcome = ""
	south.hp = 0.0
	button.pressed.emit()
	check("可直接护送二人登船" in b.mission._status.text,"loss of a named boat ally leaves the boarding route")
	south.hp = south.max_hp
	l.strategy_t = 0.0
	l.process(b,0.25)
	check(not l.meeting,"exact distance boundary does not award the meeting")
	south.position = at_temple + Vector2(129,0)
	button.pressed.emit()
	check("四人已到齐" in b.mission._status.text and not l.meeting,"the button confirms attendance without awarding the meeting")
	l.process(b,0.25)
	button.pressed.emit()
	check(l.meeting and b.mission.has_event("bailong") and "会合已完成" in b.mission._status.text,"the actual level tick awards the meeting after all arrive")
	await _dispose(b)
	return hints

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var fixture := await _fixture()
	if failures.is_empty():
		route = "story"
		var b = await _start("",1)
		Engine.time_scale = 4
		await _play_rescue(b)
		check(b.level.meeting and "bailong_meeting" in play_metrics.result.done_ids,"real movement still earns the rendezvous goal")
		await _dispose(b)
	print("JIANG_BAILONG_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"fixture":fixture,"live":play_metrics,"time_scale":Engine.time_scale}))
	quit(0 if failures.is_empty() else 1)
