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
	var flow := root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec()+120000
	while not flow.can_launch():
		if flow.phase==flow.Phase.ERROR or Time.get_ticks_msec()>=deadline:
			push_error(str(flow.last_result))
			quit(2)
			return
		await process_frame
	var b=await _start("",7)
	if b.phase!=b.Phase.FIGHT or not b.mission.actions.has("daming_fire"):
		push_error("Daming did not enter an active campaign battle")
		quit(3)
		return
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
	check("翠云楼举火" in l.unit_tactical_hint(b,l.scout) and "翠云楼举火" in l._briefing(b).text,
		"ready teams see the ignition action before the diversion begins")
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
	var loc := root.get_node("Localize")
	for language in ["zh_CN","zh_TW","en","ja"]:
		loc.set_language(language,false)
		l._update_briefing(b)
		await _capture(b,l.scout,language+"_ready",folder,texts)
		check(b.mission._objective.get_minimum_size().y<=b.mission._objective.size.y+1,language+" objective has enough height")
		var expected: String=loc.text("时迁")+loc.text("·乔装")
		check(b.hud._info_name.text.begins_with(expected),language+" rendered spy name includes localized disguise")
		var names_match := true
		for agent in [l.scout,l.chai,l.yue]:
			var name: String=agent.setup_def.name
			for suffix in ["·乔装","·暴露"]:
				if loc.text(name+suffix)!=loc.text(name)+loc.text(suffix):
					names_match=false
		check(names_match,language+" exact unit title lookup covers all three spies and both cover states")
	root.get_node("Localize").set_language("zh_CN",false)
	# Existing signal action remains available even if no outside army is ready.
	for u in b.units:
		if u.faction==0 and u.key in l.FIELD_KEYS: u.position=b.map.cell_to_world(l.CAMP)
	l.on_mission_action(b,"daming_fire",l.scout)
	check(l.signaled and l.signal_left==90 and b.mission.actions.has("daming_gate") and l.coordination_state(b).crew==0,"early fire remains a player choice rather than a new readiness lock")
	check("鲁智深或武松" in b.mission.objective and "90秒" in l.top_status(b),
		"the active signal shows its countdown and calls for a commander")
	var gate_marker: Vector2 = b.map.cell_to_world(l.GATE_APPROACH)
	leader.position=gate_marker
	l._update_briefing(b)
	check("两名战友" in b.mission.objective and "两名战友" in l.unit_tactical_hint(b,leader),
		"the objective and inspected unit both ask for missing companions")
	var far: Vector2 = b.map.cell_to_world(Vector2i(5,5))
	for u in b.units:
		if u.faction==1 and u!=l.gate: u.position=far
	for i in range(2): soldiers[i].position=gate_marker+Vector2(30+i*25,30)
	var guard = l.reserve[0]
	guard.position=gate_marker+Vector2(0,96)
	b._grid_build()
	l._update_briefing(b)
	check("可见守军" in b.mission.objective and "可见守军" in l.unit_tactical_hint(b,leader),
		"with the crew assembled, visible resistance becomes the next step")
	b.fog=true
	b._sight_now.fill(0)
	b._reveal_t.fill(0)
	b.hud.set_touch_ui(false)
	l._update_briefing(b)
	check("右键夺门" in b.mission.objective and not "可见守军" in l.unit_tactical_hint(b,leader)
		and l._guarded(b,l.GATE_APPROACH,l.GATE_GUARD_RADIUS),
		"unit and task text reveal no hidden guards, while the gate still enforces resistance")
	b.fog=false
	guard.position=far
	b._grid_build()
	l._update_briefing(b)
	check("右键夺门" in l.unit_tactical_hint(b,leader) and "右键夺门" in b.mission.objective,
		"cleared gate directs the ready group to the actual desktop action")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var title_source := "火号生效 · 城内暂停补兵"
	var action_source := "接应人手已齐。选鲁智深或武松，右键夺门旗标。"
	for language in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(language,false)
		var title: String=title_source if language=="zh_CN" else String(catalog[title_source][language])
		var hint: String=action_source if language=="zh_CN" else String(catalog[action_source][language])
		check(b.mission._title.text==title and b.mission._objective.text==hint and hint in l.unit_tactical_hint(b,leader),
			language+" translated signal title and contextual desktop prompt")
	root.get_node("Localize").set_language("zh_CN",false)
	l.signal_left=0
	l.strategy_t=0
	l.process(b,0.25)
	check(l.reserve_returned and l.phase_title=="回防 · 重整再接应" and not b.mission.actions.daming_gate.done,"expiry keeps gate action available and updates recovery objective")
	var recovery_source := "火号已过，幸存守军回防，未拆的城内营恢复补兵。\n%s\n也可护送器械强攻南门。"
	for language in ["zh_CN","zh_TW","en","ja"]:
		loc.set_language(language,false)
		l._update_briefing(b)
		var template: String = recovery_source if language=="zh_CN" else String(catalog[recovery_source][language])
		var hint: String = action_source if language=="zh_CN" else String(catalog[action_source][language])
		check(b.mission._objective.text==template%hint and hint in l.unit_tactical_hint(b,leader),
			language+" expired fire signal still shows the applicable gate order and assault option")
	loc.set_language("zh_CN",false)
	leader.position=b.map.cell_to_world(l.CAMP)
	l._update_briefing(b)
	check("接应需鲁智深或武松" in b.mission._objective.text,"when the signal expires, the objective still identifies a missing leader")
	leader.position=gate_marker
	soldiers[0].position=b.map.cell_to_world(l.CAMP)
	l._update_briefing(b)
	check("两名战友" in b.mission._objective.text,"after expiry, reaching the gate as its leader still calls for a full party")
	soldiers[0].position=gate_marker+Vector2(30,30)
	guard.position=gate_marker+Vector2(0,96)
	l._update_briefing(b)
	check("可见守军" in b.mission._objective.text,"after expiry, visible guards still replace the generic order with a clearing step")
	guard.position=far
	b._grid_build()
	l._update_briefing(b)
	await _capture(b,l.scout,"zh_CN_expired",folder,texts)
	l.rescued=true
	l._update_briefing(b)
	check(l.phase_title=="撤离 · 先打开南门","rescue before gate opening explains the blocked escape")
	l.on_mission_action(b,"daming_gate",leader)
	check(l.gate_open and b.mission.has_event("daming_response_arrived") and not b.mission.has_event("daming_gate_breached"),
		"the original gate action still opens the intact gate after the 90-second diversion")
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
