extends "res://tools/lianhuanma_drill_test.gd"
## One rehearsal using ordinary movement, touch attack and actual drill predicates.

const TAP := {"zh_CN":"轻点","zh_TW":"輕點","en":"tap","ja":"タップ"}

func _until(predicate: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while not predicate.call() and elapsed < seconds:
		await _wait(0.1)
		elapsed += 0.1
	return predicate.call()

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	var facts := {}
	var b = await _start("",3)
	var l = b.level
	Engine.time_scale = 4.0
	b.fog = false
	for u in b.units:
		u.fog_visible = true
		u.show()
		u.order_stop()
		u.set_stance(u.STANCE_PASSIVE)
		if u.faction == 1: u.set_physics_process(false)
	l.xu.position = b.map.cell_to_world(Vector2i(13,45))
	var hook = b.units.filter(func(u): return u.faction == 0 and u.key == "gou_lian")[0]
	var lure = b.units.filter(func(u): return u.faction == 0 and u.key == "liang_qiang")[0]
	hook.position = b.map.cell_to_world(Vector2i(10,47))
	lure.position = b.map.cell_to_world(Vector2i(19,47))
	await _reset_drill(b,l)
	check(b.hud.touch_ui and alive(l.dummy) and "第一步" in l.unit_tactical_hint(b,l.dummy),
		"placing the real practice rider exposes the first action through its inspector")
	if not failures.is_empty():
		_finish(facts)
		return
	facts["lure_prompt"]=l.unit_tactical_hint(b,l.dummy)
	_click(b,[lure],l.DRILL_ENTRY+Vector2i(0,2))
	var entered := await _until(func(): return l.drill_entered,20)
	var retreat_hint: String = l.unit_tactical_hint(b,lure)
	check(entered and l.drill_lure == lure and "退到教场西侧" in retreat_hint and lure.display_name in retreat_hint,
		"actual lure names the correct unit and direction in the retreat hint")
	facts["retreat"]=retreat_hint
	_click(b,[lure],Vector2i(11,46))
	var withdrew := await _until(func(): return l.drill_withdrew,22)
	check(withdrew and "让徐宁和一名钩镰手" in l.unit_tactical_hint(b,l.dummy),
		"the real retreat asks for the two actual matching fighters")
	facts["approach"]=l.unit_tactical_hint(b,l.dummy)
	if not failures.is_empty():
		_finish(facts)
		return
	# Bounded setup: fighters stand on navigable practice ground. The attack,
	# contact, coordination and successful resolution use the normal game code.
	l.xu.position = l.dummy.position+Vector2(-64,0)
	hook.position = l.dummy.position+Vector2(0,-64)
	b.center_camera_cell(b.map.world_to_cell(l.dummy.position))
	b.select_members([l.xu,hook],false)
	var loc = root.get_node("Localize")
	facts["ready"] = {}
	for locale: String in TAP:
		loc.set_language(locale,false)
		var hint: String = l.unit_tactical_hint(b,l.dummy)
		check(TAP[locale] in hint and not l.drill_coordinated and l.dummy.hp == 120,
			"ready drill hint points to the attack without starting it / "+locale)
		facts.ready[locale]=hint
	loc.set_language("zh_CN",false)
	b.hud.set_touch_ui(false)
	check("右键" in l.unit_tactical_hint(b,l.dummy),"desktop retains the physical right-click instruction")
	b.hud.set_touch_ui(true)
	var clicked: Vector2 = b.to_screen(l.dummy.position)
	check(b._friendly_at(clicked) == null and b._enemy_at(clicked) == l.dummy,"touch position hits the practice rider")
	b._tap_command(clicked,false)
	check(l.xu._target == l.dummy and hook._target == l.dummy,"the tap starts two normal attack orders")
	var finished := await _until(func(): return l.drill_complete or not alive(l.dummy),24)
	check(finished and l.drill_coordinated and l.drill_complete and b.mission.has_event("lhm_drill_complete")
		and b.phase == b.Phase.FIGHT and l.riders.size() == 12,"actual joint attacks complete the optional rehearsal and leave the real riders in play")
	facts["drill_complete"]=l.drill_complete
	if failures.is_empty():
		var rider = l.riders[0]
		rider.position = b.map.cell_to_world(l.LANES[0])
		for u in [l.xu,hook]: u.order_stop()
		l.xu.position = rider.position+Vector2(-50,0)
		hook.position = rider.position+Vector2(0,-50)
		rider.apply_slow(0.5,4)
		var hint: String = l.unit_tactical_hint(b,rider)
		check("钩镰2/2" in hint and "轻点攻击" in hint,"field hook pairing uses touch-aware instruction and actual partners")
		facts["actual_rider"]=hint
	await _dispose(b)
	_finish(facts)

func _finish(facts: Dictionary) -> void:
	print("LHM_TOUCH_DRILL_RESULT ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("lianhuanma_touch_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
