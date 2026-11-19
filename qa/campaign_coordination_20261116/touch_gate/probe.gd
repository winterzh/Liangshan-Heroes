extends "res://tools/zhujiazhuang_rts_test.gd"
## Bounded fixture: real fire, gate, and jail callbacks and the shared tap route.

const READY := {"zh_CN":"轻点夺门","zh_TW":"輕點奪門","en":"tap the gate seizure","ja":"門を奪う旗をタップ"}

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	var facts := {}
	var flow := root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec()+60000
	while not flow.can_launch():
		if flow.phase==flow.Phase.ERROR or Time.get_ticks_msec()>=deadline:
			push_error(str(flow.last_result))
			quit(2)
			return
		await process_frame
	var b = await _start("",7)
	if b.phase!=b.Phase.FIGHT or not b.mission.actions.has("daming_fire"):
		push_error("Daming did not enter an active campaign battle")
		quit(3)
		return
	b.set_process(false)
	b.set_physics_process(false)
	var l = b.level
	var guard = null
	var far: Vector2 = b.map.cell_to_world(Vector2i(5,5))
	for u in b.units:
		u.set_physics_process(false)
		if u.faction == 1 and u != l.gate:
			u.position = far
			if guard == null and not u.is_building and not u.is_worker: guard = u
	check(b.hud.touch_ui and guard != null,"real Daming scene uses the touch layout and an original guard")
	l._open_prison(b,false)
	l.chai.position = b.map.cell_to_world(l.PRISON_INSIDE)
	l.yue.position = l.chai.position + Vector2(10,0)
	l.on_mission_action(b,"daming_fire",l.scout)
	check(l.signaled and b.mission.actions.has("daming_gate") and "鲁智深或武松" in b.mission.objective,
		"the real fire callback opens the gate action and directs a commander to assemble")
	var leader = b.find_unit("lu_zhishen")
	var troops: Array = b.units.filter(func(u): return u.faction == 0 and u.key == "liang_qiang")
	var gate_marker: Vector2 = b.map.cell_to_world(l.GATE_APPROACH)
	leader.position = gate_marker
	l.on_mission_action(b,"daming_gate",leader)
	check(not l.gate_open and "接应人手不足" in b.mission._status.text,
		"an original leader alone receives the specific missing-crew retry")
	facts["crew_retry"]=b.mission._status.text
	for i in range(2):
		troops[i].position = gate_marker + Vector2(32+i*32,32)
	guard.position = gate_marker + Vector2(0,96)
	b._grid_build()
	b.fog = false
	var hint: String = l.unit_tactical_hint(b,leader)
	check("门外3/3" in hint and "可见守军" in hint,"assembled crew sees the actual visible South Gate threat")
	facts["visible_guard"]=hint
	l.on_mission_action(b,"daming_gate",leader)
	check(not l.gate_open and "门前仍有抵抗" in b.mission._status.text,
		"the same gate handler distinguishes remaining resistance")
	facts["guard_retry"]=b.mission._status.text

	b.fog = true
	b._sight_now.fill(0)
	b._reveal_t.fill(0)
	var loc = root.get_node("Localize")
	facts["ready"]= {}
	for locale: String in READY:
		loc.set_language(locale,false)
		hint = l.unit_tactical_hint(b,leader)
		check(READY[locale] in hint and not l.gate_open,"touch prompt names the gate flag without revealing hidden enemies / "+locale)
		facts.ready[locale]=hint
	loc.set_language("zh_CN",false)
	check(l._guarded(b,l.GATE_APPROACH,l.GATE_GUARD_RADIUS),"an unseen guard still blocks actual gate seizure")
	b.hud.set_touch_ui(false)
	check("右键夺门" in l.unit_tactical_hint(b,leader),"desktop keeps the gate right-click prompt")
	b.hud.set_touch_ui(true)
	b.fog = false
	guard.position = far
	b._grid_build()
	b.center_camera_cell(l.GATE_APPROACH)
	b.select_members([leader,troops[0],troops[1]],false)
	b._tap_command(b.to_screen(gate_marker),false)
	var gate_token: int = leader.mission_order_token
	b.mission.tick(2.1)
	check(gate_token > 0 and l.gate_open and b.mission.has_event("daming_response_arrived")
		and "轻点开枷" in b.mission.objective,"a real group tap opens the South Gate and hands off to the jail prompt")
	if not failures.is_empty():
		_finish(facts)
		return
	var shackles: Vector2 = b.map.cell_to_world(l.JAIL_ACTION)
	guard.position = shackles + Vector2(4,0)
	check("开枷处仍有可见守军" in l.unit_tactical_hint(b,l.chai),"the jail hint exposes a guard only at the actual shackles")
	guard.position = far
	l.chai.position = shackles
	b.center_camera_cell(l.JAIL_ACTION)
	b._grid_build()
	b.select_single(l.chai,false)
	b._tap_command(b.to_screen(shackles),false)
	b.mission.tick(3.1)
	check(l.rescued and b.mission.has_event("daming_inner_unlock"),"normal touch release frees the original prisoners in the inner route")
	if failures.is_empty():
		var serials: Array = [l.lu._order_serial,l.shi._order_serial]
		l.activate_mission_button(b,"daming_select_wounded")
		check("轻点城外接应地" in b.mission._status.text and b.selection.size() == 2
			and serials == [l.lu._order_serial,l.shi._order_serial],"wounded shortcut suggests a tap and does not order evacuation")
	facts["gate_open"]=l.gate_open
	facts["rescued"]=l.rescued
	facts["inner_unlock"]=b.mission.has_event("daming_inner_unlock")
	await _dispose(b)
	_finish(facts)

func _finish(facts: Dictionary) -> void:
	print("DAMING_TOUCH_GATE_RESULT ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("daming_touch_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
