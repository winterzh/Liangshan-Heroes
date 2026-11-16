extends "res://tools/lianhuanma_tactics_qa.gd"
## Frozen real-world coordination/briefing fixtures, not an actual playthrough.
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	root.get_node("Settings").edge_scroll=false
	var folder := "res://.godot/daming-coordination"
	DirAccess.make_dir_recursive_absolute(folder)
	var b=await _start("",7)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	b.fog=false
	b._fog_layer.hide()
	var l=b.level
	for u in b.units:
		if u.faction==0 and u.key in l.FIELD_KEYS: u.position=b.map.cell_to_world(l.CAMP)
	var soldiers: Array=b.units.filter(func(u): return u.faction==0 and u.key in ["liang_qiang","liang_gong"])
	var leader=b.find_unit("lu_zhishen")
	for i in range(3): soldiers[i].position=b.map.cell_to_world(l.GATE_APPROACH)
	check(l.coordination_state(b).crew==3 and not l.coordination_state(b).leader and "鲁智深" in l.unit_tactical_hint(b,l.scout),"three soldiers do not imply required commander is present")
	soldiers[0]._stun_t=1
	soldiers[1].garrisoned=true
	check(l._gate_crew(b).size()==1,"actual gate crew excludes stunned and garrisoned units")
	soldiers[0]._stun_t=0
	soldiers[1].garrisoned=false
	for u in soldiers: u.position=b.map.cell_to_world(l.CAMP)
	leader.position=b.map.cell_to_world(l.GATE_APPROACH)
	check(l.coordination_state(b).leader and "两名战友" in l.unit_tactical_hint(b,l.scout),"commander alone still needs companions")
	for i in range(2): soldiers[i].position=leader.position+Vector2(10+i*15,0)
	l.chai.position=b.map.cell_to_world(l.PRISON_INSIDE)
	l.yue.position=l.chai.position+Vector2(10,0)
	check(l.coordination_state(b).inside==2 and l._briefing(b).title=="待机 · 自选举火时机","inside position enables timing advice before fire")
	l.scout._invis_t=0
	check("恢复乔装" in l.unit_tactical_hint(b,l.scout),"exposed signal agent is called out after team is ready")
	l.scout._invis_t=99999
	var old_hp: float=l.yue.hp
	l.yue.hp=0
	check(l._briefing(b).title=="强攻 · 内应失去接应","lost agent points to the existing assault route")
	l.yue.hp=old_hp
	var serials: Array=b.units.map(func(u): return u._order_serial)
	var money: Array=[b.gold,b.wood]
	var action: Dictionary=b.mission.actions.daming_fire
	var action_before: Array=[action.done,action.get("progress",0)]
	l._update_briefing(b)
	l._update_briefing(b)
	check(serials==b.units.map(func(u): return u._order_serial) and money==[b.gold,b.wood] and action_before==[action.done,action.get("progress",0)],"briefing reads state without orders, costs or action resets")
	var texts: Array=[]
	for language in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(language,false)
		l._update_briefing(b)
		await _capture(b,l.scout,language+"_ready",folder,texts)
		check(b.mission._objective.get_minimum_size().y<=b.mission._objective.size.y+1,language+" objective has enough height")
	root.get_node("Localize").set_language("zh_CN",false)
	# Existing signal action remains available even if no outside army is ready.
	for u in b.units:
		if u.faction==0 and u.key in l.FIELD_KEYS: u.position=b.map.cell_to_world(l.CAMP)
	l.on_mission_action(b,"daming_fire",l.scout)
	check(l.signaled and l.signal_left==90 and b.mission.actions.has("daming_gate") and l.coordination_state(b).crew==0,"early fire remains a player choice rather than a new readiness lock")
	l.signal_left=0
	l.strategy_t=0
	l.process(b,0.25)
	check(l.reserve_returned and l.phase_title=="回防 · 重整再接应" and not b.mission.actions.daming_gate.done,"expiry keeps gate action available and updates recovery objective")
	await _capture(b,l.scout,"zh_CN_expired",folder,texts)
	l.rescued=true
	l._update_briefing(b)
	check(l.phase_title=="撤离 · 先打开南门","rescue before gate opening explains the blocked escape")
	l.gate_open=true
	b.mission.mark("daming_lu_safe","fixture: one prisoner safely outside")
	l._update_briefing(b)
	check("1/2" in b.mission.objective and "1/2" in l.top_status(b),"one escaped prisoner is reflected in objective and top bar")
	l.shi.faction=0
	root.get_node("Localize").set_language("en",false)
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	l._update_briefing(b)
	await _capture(b,l.shi,"en_narrow_escort",folder,texts)
	var state=load("res://scripts/run_campaign_level_state.gd").new()
	check(state.audit_declarations("level8").ok,"derived coordination adds no unclassified save fields")
	await _dispose(b)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"texts":texts,"scope":"frozen predicate, actual action and rendered HUD fixtures; not live route or complete restore"},"\t"))
	quit(0 if failures.is_empty() else 1)

func _capture(b,target,name: String,folder: String,texts: Array) -> void:
	# Battle processing is frozen above: explicitly tick the existing mission UI
	# and expand it before measuring. Hidden labels have no valid layout yet.
	b.mission.tick(0.0)
	b.mission._set_expanded(true)
	b.hud.set_top(b.level.top_status(b))
	await process_frame
	await process_frame
	b.mission._detail_scroll.ensure_control_visible(b.mission._objective)
	await super._capture(b,target,name,folder,texts)
	texts.append({"name":name+"_objective","text":b.mission._objective.text,"rect":str(b.mission._objective.get_global_rect()),"visible":b.mission._objective.is_visible_in_tree()})
