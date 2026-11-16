extends "res://tools/zhujiazhuang_rts_test.gd"
## Frozen Daming scene. The original cover, gate and release handlers run.

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b = await _start("",7)
	var l = b.level
	b.set_process(false)
	b.set_physics_process(false)
	for u in b.units:
		u.set_physics_process(false)
	var prison_guard
	for u in b.units:
		if alive(u) and u.faction == 1:
			if not u.is_building and not u.is_worker and prison_guard == null:
				prison_guard = u
			u.position = b.map.cell_to_world(Vector2i(5,5))
	l._update_briefing(b)
	check(b.mission.stage_title == "两线筹备 · 经营与潜入","opening asks the disguised pair to pass the jail checkpoint")
	l.chai.position = b.map.cell_to_world(l.PRISON_CHECK)
	l.yue.position = l.chai.position+Vector2(10,0)
	l.chai._break_invis()
	l._cover_tick(b,0.25)
	l._update_briefing(b)
	check(b.mission.stage_title == "潜入 · 重整乔装" and "蔡福家" in b.mission.objective and "强攻南门" in b.mission.objective,"exposure before admission offers cover recovery and the assault fallback")
	l.on_mission_action(b,"daming_admit",l.chai)
	check(not l.prison_open and not b.mission.actions.daming_admit.done,"exposed operator cannot pass the checkpoint")
	l.chai.position = b.map.cell_to_world(l.SAFEHOUSE)
	for t in range(11):
		l._cover_tick(b,0.25)
	check(l.chai._invis_t<=0 and absf(float(l.chai.get_meta("daming_recover",0.0))-2.75)<0.01,"recovery is still incomplete at 2.75 seconds")
	l._cover_tick(b,0.25)
	l._update_briefing(b)
	check(l.chai._invis_t>0 and b.mission.stage_title == "两线筹备 · 经营与潜入","actual safehouse recovery unlocks the checkpoint guidance after 3 seconds")
	l.chai.position = b.map.cell_to_world(l.PRISON_CHECK)
	l.on_mission_action(b,"daming_admit",l.chai)
	check(l.prison_open and b.mission.actions.has("daming_rescue") and b.mission.actions.daming_admit.done,"successful admission retires inspection and creates the real opening-locks action")
	check(b.mission.stage_title == "入院 · 就位接应" and b.mission.objective.begins_with("牢院已放行"),"admission switches the objective immediately")
	l.chai.position = b.map.cell_to_world(l.PRISON_INSIDE)
	l.yue.position = l.chai.position+Vector2(10,0)
	l._update_briefing(b)
	check(b.mission.stage_title == "待机 · 自选举火时机","moving both original agents inside exposes timing choice")
	l.scout._break_invis()
	l._cover_tick(b,0.25)
	l._update_briefing(b)
	l.on_mission_action(b,"daming_fire",l.scout)
	check(not l.signaled and "时迁" in b.mission.objective and "蔡福家" in b.mission.objective,"exposed signal agent gets targeted fallback while the original signal guard stays in force")
	l.gate.take_damage(100000,null,false,true)
	check(l.gate_open and b.mission.has_event("daming_gate_breached") and not l.signaled,"actual gate damage opens the fallback route without signaling")
	check(b.mission.stage_title == "牢内 · 开枷救人" and "开枷救出二人" in b.mission.objective and b.mission.actions.has("daming_rescue"),"gate breach with jail already open immediately directs the player to shackles")
	var localize = root.get_node("Localize")
	for language in ["zh_TW","en","ja"]:
		localize.set_language(language,false)
		check(localize.text(b.mission.objective)!=b.mission.objective and b.mission._objective.text==localize.text(b.mission.objective),
			"opening-locks objective displayed in "+language)
	localize.set_language("zh_CN",false)
	var order_serials: Array = b.units.map(func(u): return u._order_serial)
	var gold: int = b.gold
	var wood: int = b.wood
	l._update_briefing(b)
	check(order_serials == b.units.map(func(u): return u._order_serial) and b.gold == gold and b.wood == wood and not l.rescued,
		"briefing refresh does not issue orders, spend resources or release the prisoners")
	prison_guard.position = b.map.cell_to_world(l.JAIL_ACTION)+Vector2(5,0)
	l.on_mission_action(b,"daming_rescue",l.chai)
	check(not l.rescued and not b.mission.actions.daming_rescue.done,"nearby live guard still prevents opening the locks")
	prison_guard.position = b.map.cell_to_world(Vector2i(5,5))
	l.on_mission_action(b,"daming_rescue",l.chai)
	check(l.rescued and b.mission.has_event("daming_prisoners_freed") and b.mission.stage_title == "护送 · 二人活着出城",
		"opening locks after the guard leaves immediately switches to manual escort")
	check(l.lu.faction == 0 and l.shi.faction == 0 and not l.lu.is_captive and not l.shi.is_captive
		and not l.lu.manual_order_active and not l.shi.manual_order_active,"the original wounded units are available and have no automatic move")
	var contract = load("res://scripts/run_campaign_level_state.gd").new()
	check(contract.audit_declarations("level8").ok,"briefing introduces no new save fields")
	print("DAMING_JAIL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"frozen real level, production cover, gate damage, release and objective handlers"}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
