extends "res://tools/lianhuanma_rts_test.gd"
## Actual battle callbacks with controlled fall of the manor and original riders.

func _locator_buttons(b) -> Array:
	return b.mission._buttons.get_children().filter(func(node):
		return node.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","")=="lhm_locate_remaining")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	var b = await _start("",3)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	var l = b.level
	var localize = root.get_node("Localize")
	var north: Array = l.riders.filter(func(u): return u.get_meta("wave_group")==0)
	var south: Array = l.riders.filter(func(u): return u.get_meta("wave_group")==1)
	check(north.size()==6 and south.size()==6 and _locator_buttons(b).is_empty(),
		"the original two columns are present and the locator is gated by the manor")
	for rider in north:
		rider.take_damage(100000.0,l.song,false,true)
	l.elapsed=float(l.waves[0].time)+1.0
	l.strategy_t=0.0
	l.process(b,0.0)
	var before_manor: String=l.top_status(b)
	check(l.lhm_killed==6 and not l.waves[0].sent and not l.waves[0].warned,
		"a destroyed northern column gets no muster warning or later charge")
	check("北 余0骑" in before_manor and "南 119秒" in before_manor
		and "准备南路" in b.mission.stage_title,
		"the next live column keeps its timer and takes over the preparation objective")
	var target = south[0]
	var second = south[1]
	target.position=b.map.cell_to_world(Vector2i(22,39))
	second.position=b.map.cell_to_world(Vector2i(26,40))
	var base = l.enemy_base
	base.take_damage(100000.0,l.song,false,true)
	await process_frame
	l.strategy_t=0.0
	l.process(b,0.0)
	var after_manor: String=l.top_status(b)
	var buttons := _locator_buttons(b)
	check(l.manor_fallen and buttons.size()==1 and b.mission.has_event("lhm_manor_fallen"),
		"the real manor death registers exactly one fixed-id locator")
	check("南 余6骑" in after_manor and not l.waves[1].sent and "查看 · 余骑" in b.mission.objective,
		"remaining riders replace pre-charge timers during the cleanup objective")
	if buttons.size()!=1:
		await _dispose(b)
		quit(1)
		return
	var button: Button=buttons[0]
	b.select_members([l.xu],false)
	var orders_before := [l.xu._order_serial,target._order_serial,b.mission.active_action_id]
	b.center_camera_cell(b.map.world_to_cell(target.position))
	var expected: Vector2=b.camera.position
	b.center_camera_cell(l.CAMP)
	button.pressed.emit()
	check(b.camera.position==expected and b.selection==[l.xu]
		and orders_before==[l.xu._order_serial,target._order_serial,b.mission.active_action_id],
		"the locator centers the nearest original rider without issuing or cancelling orders")
	check(b.lit_cells.has(b.map.world_to_cell(target.position)),"the selected rider uses the existing battlefield hint")
	var hints := {}
	var translations := {"zh_CN":"已定位南路","zh_TW":"已定位南路","en":"southern column","ja":"南路の残存騎兵"}
	for locale in translations:
		localize.set_language(locale,false)
		button.pressed.emit()
		hints[locale]=b.mission._status.text
		check(translations[locale] in hints[locale],
			"the locator reports the actual lane in "+locale)
	localize.set_language("zh_CN",false)
	target.take_damage(100000.0,l.song,false,true)
	b.center_camera_cell(b.map.world_to_cell(second.position))
	expected=b.camera.position
	b.center_camera_cell(l.CAMP)
	button.pressed.emit()
	check(b.camera.position==expected and "南 余5骑" in l.top_status(b),
		"the locator retargets to the next living rider after an actual death callback")
	for i in range(1,south.size()):
		south[i].take_damage(100000.0,l.song,false,true)
	button.pressed.emit()
	check(b.mission._status.text=="余骑已全部击溃。","a locator with no riders gives accurate feedback")
	l.strategy_t=0.0
	l.process(b,0.0)
	check(l.lhm_killed==12 and b.mission.has_event("lhm_victory") and b.phase==b.Phase.END,
		"the normal win callback fires after the twelve original riders and manor are defeated")
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"top_before_manor":before_manor,
		"top_after_manor":after_manor,"localizations":hints,"riders_defeated":l.lhm_killed,
		"scope":"controlled actual chapter state with lethal damage, real mission button and victory callback"}
	print("LHM_REMAINING_RESULT ",JSON.stringify(report))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
