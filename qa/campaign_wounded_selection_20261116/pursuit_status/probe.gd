extends "res://tools/daming_rts_test.gd"
## Two isolated chapter fixtures using the normal gates, pursuit and rescue callbacks.

func _freeze(b) -> void:
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	var l=b.level
	for u in b.units:
		u.set_physics_process(false)
		if u.faction==1 and u!=l.gate and u not in l.pursuit:
			u.position=Vector2(-10000,-10000)

func _tick(b) -> void:
	b.level.strategy_t=0.0
	b.level.process(b,0.0)

func _signal_case() -> Dictionary:
	var b=await _start("",7)
	_freeze(b)
	var l=b.level
	l._open_prison(b,false)
	l.chai.position=b.map.cell_to_world(l.PRISON_INSIDE)
	l.yue.position=l.chai.position+Vector2(15,0)
	l.scout._invis_t=20.0
	l.on_mission_action(b,"daming_fire",l.scout)
	check(l.signaled and b.mission.actions.has("daming_gate"),"valid spies activate the normal signal gate action")
	var commander=b.find_unit("lu_zhishen")
	var crew: Array=b.units.filter(func(u): return u.faction==0 and u.key in ["liang_qiang","liang_gong"])
	var marker: Vector2=b.map.cell_to_world(l.GATE_APPROACH)
	for i in range(3): crew[i].position=marker+Vector2(i*16,12)
	commander.position=marker
	commander._stun_t=1.5
	var gate_action: Dictionary=b.mission.actions.daming_gate
	gate_action.done=true
	l.on_mission_action(b,"daming_gate",commander)
	check(l._gate_crew(b).size()>=3 and not l.gate_open and not gate_action.done
		and "暂时无法夺门" in b.mission._status.text,
		"three ordinary allies do not authorize an incapacitated acting commander")
	commander._stun_t=0.0
	l.on_mission_action(b,"daming_gate",commander)
	check(l.gate_open and b.mission.has_event("daming_response_arrived"),
		"the original commander can finish once able to act")
	l.on_mission_action(b,"daming_rescue",l.chai)
	check(l.rescued and not l.pursuit_warned,"rescue alone does not trigger pursuit while the prisoners are inside")
	l.lu.position=b.map.cell_to_world(Vector2i(19,24))
	_tick(b)
	check(l.pursuit_warned and not l.pursuit_sent and l.pursuit_t==15.0,
		"one wounded prisoner leaving starts a full fifteen-second warning")
	var localize=root.get_node("Localize")
	var texts: Dictionary={}
	var phrases := {"zh_CN":"留守队15秒后追击","zh_TW":"留守隊15秒後追擊",
		"en":"Pursuit starts in 15 s","ja":"守備隊の追撃まで15秒"}
	for locale in phrases:
		localize.set_language(locale,false)
		texts[locale]=l.top_status(b)
		check(phrases[locale] in texts[locale],"pursuit countdown resolves in "+locale)
	localize.set_language("zh_CN",false)
	for i in range(4): l.pursuit[i].take_damage(100000.0,commander,false,true)
	var survivors: Array=l.pursuit.slice(4)
	var ids: Array=survivors.map(func(u): return u.entity_id)
	var serials: Array=survivors.map(func(u): return u._order_serial)
	var before_count: int=b.units.size()
	for i in range(59): l._update_pursuit(b)
	check(not l.pursuit_sent and l.pursuit_t==0.25,"the remaining squad waits through the warning window")
	l._update_pursuit(b)
	check(l.pursuit_sent and b.mission.has_event("daming_pursuit")
		and survivors.map(func(u): return u.entity_id)==ids and b.units.size()==before_count
		and survivors.map(func(u): return u._order_serial)!=serials and "正追向南门" in l.top_status(b),
		"only the surviving original soldiers receive their existing march once")
	l.lu.position=b.map.cell_to_world(l.EXIT_CELL)
	_tick(b)
	check(b.mission.has_event("daming_lu_safe") and not b.mission.has_event("daming_shi_safe") and b.phase==b.Phase.FIGHT,
		"one safe prisoner cannot end the mission while the second is inside")
	l.shi.position=b.map.cell_to_world(l.EXIT_CELL)
	_tick(b)
	check(b.phase==b.Phase.END and b.mission.has_event("daming_victory"),"both original wounded prisoners must reach the actual exit")
	await _dispose(b)
	return {"countdown":texts,"dispatched_original_ids":ids}

func _assault_case() -> Dictionary:
	var b=await _start("",7)
	_freeze(b)
	var l=b.level
	var soldier=b.find_unit("lu_zhishen")
	l.chai.take_damage(100000.0,l.pursuit[0],false,true)
	l._update_briefing(b)
	check("强攻" in b.mission.stage_title and not l.signaled,"a real spy death shifts the objective to frontal rescue")
	l.gate.take_damage(100000.0,soldier,false,true)
	soldier.position=b.map.cell_to_world(l.PRISON_CHECK)
	_tick(b)
	check(l.gate_open and l.prison_open and b.mission.has_event("daming_gate_breached")
		and b.mission.has_event("daming_prison_breached"),"damage opens the south gate and actual field presence opens the prison")
	l.on_mission_action(b,"daming_rescue",soldier)
	for foe in l.pursuit: foe.take_damage(100000.0,soldier,false,true)
	l.lu.position=b.map.cell_to_world(Vector2i(19,24))
	_tick(b)
	var status: String=l.top_status(b)
	check(l.rescued and not l.pursuit_warned and not l.pursuit_sent
		and not b.mission.has_event("daming_pursuit") and "留守队已击退" in status,
		"an intercepted garrison does not create a false warning or dispatch")
	l.lu.position=b.map.cell_to_world(l.EXIT_CELL)
	l.shi.position=b.map.cell_to_world(l.EXIT_CELL)
	_tick(b)
	check(b.phase==b.Phase.END and b.mission.has_event("daming_victory"),"the assault fallback still completes the rescue after interception")
	await _dispose(b)
	return {"intercepted_status":status}

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var signal_case:=await _signal_case()
	var assault_case:=await _assault_case()
	print("DAMING_PURSUIT_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"signal":signal_case,"assault":assault_case,
		"scope":"controlled actual scenes with gate, original pursuit, and two-prisoner evacuation callbacks"}))
	quit(0 if failures.is_empty() else 1)
