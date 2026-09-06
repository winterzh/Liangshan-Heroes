extends "res://tools/zhujiazhuang_rts_test.gd"
## DAMING_TEST=contracts|assault|signal. Live routes never inject troops, money,
## damage or mission results; placement/freeze fixtures are limited to contracts.
var skill_orders := 0
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	if OS.get_environment("DAMING_VISUAL")=="1": root.size=Vector2i(1440,900)
	route=OS.get_environment("DAMING_TEST")
	if route=="": route="contracts"
	out_dir="res://qa/daming_rts_20260905"
	build_cells=[Vector2i(25,54),Vector2i(37,57),Vector2i(29,63),Vector2i(39,49),Vector2i(23,50),Vector2i(21,62),Vector2i(35,51),Vector2i(44,55),Vector2i(16,55),Vector2i(45,50),Vector2i(17,62)]
	var b=await _start("",7)
	Engine.time_scale=4
	if route=="contracts": await _contracts_dm(b)
	else: await _play_dm(b)
	await _dispose(b)
	if route=="contracts":
		b=await _start("skirmish")
		check(b._defs.shi_qian==Defs.UNITS.shi_qian and b._defs.hall==Defs.UNITS.hall,"spy/population/roster overrides do not leak to defense")
		await _dispose(b)
	Engine.time_scale=1
	check(checks==({"contracts":36,"assault":5,"signal":7}.get(route,0)),"all expected route assertions executed")
	var result={"route":route,"checks":checks,"passed":failures.is_empty(),"failures":failures,"metrics":play_metrics,"scope":"isolated contract fixtures" if route=="contracts" else "automated actual economy and combat; not human fun acceptance"}
	DirAccess.make_dir_recursive_absolute(out_dir)
	FileAccess.open(out_dir+"/"+route+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("[daming-rts] ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
func _freeze_foes(b) -> void:
	for u in b.units:
		if u.faction==1: u.set_physics_process(false)
func _contracts_dm(b) -> void:
	var l=b.level
	check(l.get_script().resource_path.ends_with("level8_daming_rts.gd"),"level8 enters persistent RTS chapter")
	check(b.economy and b.fog and b.used_pop()==19 and b.pop_cap==24,"opening real economy/population matches deployed troops")
	check(b.find_unit("song_jiang")==null and b._defs.hall.produces.has("wu_yong"),"Song Jiang remains on Liangshan; Wu Yong commands field camp")
	for key in ["liang_dao","liang_qiang","liang_gong","siege_cata","siege_ram","arrow_tower","wu_yong","lu_zhishen","wu_song"]:
		check(b._defs[key]==Defs.UNITS[key],"shared combat and costs unchanged: "+key)
	check(l.lu.faction==2 and l.shi.faction==2 and l.lu.is_captive and l.shi.is_captive,"bound prisoners are neutral and cannot reveal city or fill field hero bar")
	check(l.reserve.size()==6 and l.pursuit.size()==6,"all diversion and pursuit soldiers exist before trigger")
	check(b.map.find_path(l.strategist.position,b.map.cell_to_world(l.PRISON_CHECK)).is_empty(),"closed gates prevent outside army from entering city")
	check(not b.map.find_path(l.chai.position,b.map.cell_to_world(l.PRISON_CHECK)).is_empty(),"inside agents can reach prison check without outside gate")
	check(b.map.find_path(l.chai.position,b.map.cell_to_world(l.PRISON_INSIDE)).is_empty(),"locked prison prevents walking through inner wall")
	var gold_before: int=b.gold
	var wood_before: int=b.wood
	await _wait(20)
	check(b.gold>gold_before and b.wood>wood_before,"camp workers really harvest and unload both resources")
	check(_place(b,"house"),"normal player building placement works in expanded camp")
	await _wait(25)
	check(b.pop_cap>24,"worker completes house without scripted stage reset")
	var barracks=b.units.filter(func(u): return u.faction==0 and u.key=="barracks")[0]
	var count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="liang_qiang").size()
	var old_gold: int=b.gold
	check(b.queue_train(barracks,"liang_qiang",false) and b.gold<old_gold,"ordinary troop recruitment debits real account")
	await _wait(25)
	check(b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="liang_qiang").size()==count+1,"recruited troop appears after actual timer")
	_freeze_foes(b)
	for worker in l.enemy_workers: worker.set_physics_process(false)
	b.faction_res[1]={"gold":0.0,"wood":0.0}
	l.train_t=0
	l._support_tick(b,1)
	check(l.ai_trained==0,"unfunded camps cannot add reinforcements")
	b.faction_res[1]={"gold":200.0,"wood":200.0}
	l.train_t=0
	l._support_tick(b,1)
	check(l.ai_trained==2 and b.faction_gold(1)<200,"both camps pay shared troop costs")
	l.signal_left=90
	l.train_t=0
	l._support_tick(b,1)
	check(l.ai_trained==3 and l.escorts[-1].get_meta("source_lane")==0,"signal pauses only inner production, outside threat remains")
	l.posts[0].take_damage(99999,l.strategist,true,true)
	l.train_t=0
	l._support_tick(b,1)
	check(l.ai_trained==3,"destroyed outside camp plus signal stops both active sources")
	l.signal_left=0
	l.train_t=0
	l._support_tick(b,1)
	check(l.ai_trained==4 and l.escorts[-1].get_meta("source_lane")==1,"inner camp resumes paid recruitment after signal window")
	# Actual fire dispatch rejects missing inside actors, without erasing camp.
	l.scout.position=b.map.cell_to_world(l.FIRE_CELL+Vector2i(0,1))
	_click(b,[l.scout],l.FIRE_CELL)
	await _wait(4)
	check(not l.signaled and not b.mission.actions.daming_fire.done,"early signal rejects absent prison agents and remains retryable")
	check(alive(l.hall) and b.pop_cap>24,"failed spy task preserves established economy")
	var gate_visual=load("res://scripts/campaign_gate_visual.gd")
	var size=Vector2(512,512)
	var tr: Transform2D=gate_visual.source_transform(l.gate,size)
	var endpoint: Vector2=b.map.project(Vector2(-64,0))
	check((tr*(l.gate.get_meta("campaign_gate_source_left")*size)).distance_to(-endpoint)<0.01 and (tr*(l.gate.get_meta("campaign_gate_source_right")*size)).distance_to(endpoint)<0.01,"authored city gate feet meet correct wall ends")
	check(absf(tr.y.x)<0.001 and tr.y.y>0,"mirrored city gate roof stays upright")
	l.gate.take_damage(99999,l.strategist,true,true)
	check(l.gate_open and b.mission.has_event("daming_gate_breached"),"direct gate damage opens route without choosing a story action")
	check(not b.map.find_path(l.strategist.position,b.map.cell_to_world(l.PRISON_CHECK)).is_empty(),"destroyed gate restores actual outside-to-city path")
	l.scout.take_damage(99999,l.posts[1],true,true)
	check(b.phase==b.Phase.FIGHT and b.mission.actions.daming_fire.actor_button.disabled,"lost scout blocks optional fire but leaves core rescue playable")
	l.lu.take_damage(99999,l.posts[1],true,true)
	check(b.phase==b.Phase.END and not b.mission.has_event("daming_victory"),"bound prisoner death correctly fails the core mission")
func _economy_dm(b) -> void:
	_mine_idle_workers(b)
	var own: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_building)
	var reserve_gold := 0
	if not own.any(func(u): return u.is_constructing):
		var key := ""
		if b.pop_cap-b.used_pop()-b._queued_pop()<7 and b.pop_cap<84: key="house"
		elif not own.any(func(u): return u.key=="siege_workshop"): key="siege_workshop"
		elif own.filter(func(u): return u.key=="barracks").size()<2: key="barracks"
		if key!="" and not _place(b,key): reserve_gold=int(b._defs[key].cost_gold)
	var workers: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_worker)
	var cata_count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="siege_cata").size()
	var ram_count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="siege_ram").size()
	for building in own:
		if building.is_constructing or not building._train_queue.is_empty(): continue
		var key := ""
		if building.key=="hall" and workers.size()<10: key="lou_luo"
		elif building.key=="barracks" and (cata_count>=2 or b.gold>135): key=["liang_qiang","liang_gong","liang_dao","liang_gong"][units_queued%4]
		elif building.key=="siege_workshop":
			if cata_count<2: key="siege_cata"
			elif ram_count<2: key="siege_ram"
		if key!="" and b.gold>=int(b._defs[key].cost_gold)+reserve_gold and b.queue_train(building,key,false):
			units_queued+=1
			units_queued_by_key[key]=int(units_queued_by_key.get(key,0))+1
	for hero in b.units:
		if alive(hero) and hero.faction==0 and hero.is_hero and hero.key in b.level.FIELD_KEYS:
			for slot in range(4):
				if hero.can_learn(slot): b.learn_slot(hero,slot)
func _skills_dm(b,army: Array) -> void:
	for hero in army:
		if not hero.is_hero or hero._cast_t>0: continue
		var foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and u.fog_visible and not u.is_building and hero.position.distance_to(u.position)<230)
		if foes.is_empty(): continue
		foes.sort_custom(func(a,z): return hero.position.distance_to(a.position)<hero.position.distance_to(z.position))
		for slot in [0,1,3]:
			if slot>=hero.slot_count() or not hero.slot_ready(slot): continue
			b.select_members([hero],false)
			b._cast_ability_slot(slot)
			if b._ability_armed!="": b._cast_armed_at(b.to_screen(foes[0].position))
			skill_orders+=1
			break
func _play_dm(b) -> void:
	var l=b.level
	var time := 0.0
	var next_log := 0.0
	var start_hall=l.hall
	var phase := "outpost"
	var spy_phase := "admit"
	var captured := {}
	while b.phase==b.Phase.FIGHT and time<900:
		_economy_dm(b)
		var army: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and not u.is_worker and not u.is_building and not u.is_noncombat and u.key not in l.SPY_KEYS)
		var target=null
		var cell: Vector2i=l.OUTPOST
		if phase=="outpost":
			if alive(l.posts[0]): target=l.posts[0]
			else: phase="gate_tower"
		if phase=="gate_tower":
			cell=l.GATE_APPROACH
			if alive(l.towers[0]): target=l.towers[0]
			else: phase="gate"
		if phase=="gate":
			cell=l.GATE_APPROACH
			if l.gate_open: phase="prison_tower"
			elif route=="assault": target=l.gate
			elif l.signaled and not l._guarded(b,l.GATE_APPROACH,150):
				var opener=b.find_unit("lu_zhishen")
				if not alive(opener): opener=b.find_unit("wu_song")
				_action(b,opener,"daming_gate")
				army.erase(opener)
		if phase=="prison_tower":
			cell=Vector2i(22,25)
			if alive(l.towers[1]): target=l.towers[1]
			else: phase="rescue"
		if phase=="rescue":
			cell=l.PRISON_CHECK
			if not l.rescued and l.prison_open and not l._guarded(b,l.JAIL_ACTION,120) and not l._guarded(b,l.PRISON_CHECK,150):
				var rescuer=l.chai if route=="signal" and alive(l.chai) else l.strategist
				if not alive(rescuer): rescuer=army.filter(func(u): return u.key in l.RESCUERS)[0] if not army.is_empty() else null
				if alive(rescuer):
					_action(b,rescuer,"daming_rescue")
					army.erase(rescuer)
			if l.rescued: phase="extract"
		if phase=="extract":
			cell=Vector2i(30,30)
			for prisoner in [l.lu,l.shi]:
				if alive(prisoner): _click(b,[prisoner],l.EXIT_CELL)
		# Spies act while the same economy and field army keep running.
		if route=="signal" and not l.signaled:
			if spy_phase=="admit":
				_click(b,[l.yue],l.PRISON_CHECK+Vector2i(1,0))
				_action(b,l.chai,"daming_admit")
				if l.prison_open: spy_phase="inside"
			elif spy_phase=="inside":
				_click(b,[l.chai,l.yue],l.PRISON_INSIDE)
				if l._inside_prison(b,l.chai) and l._inside_prison(b,l.yue): spy_phase="ready"
			if spy_phase=="ready" and phase=="gate": _action(b,l.scout,"daming_fire")
		elif route=="signal" and l.signaled and alive(l.scout): _click(b,[l.scout],l.SAFEHOUSE)
		if army.size()>=8 or time>120:
			# Do not overwrite an active actor's manual hold/action intent.
			army=army.filter(func(u): return b.mission._actor!=u)
			if alive(target) and b.is_visible_world(target.position):
				b.select_members(army,false)
				b._issue_order(b.to_screen(target.position),false)
				orders+=1
			else: _click(b,army,cell,true)
		_skills_dm(b,army)
		if OS.get_environment("DAMING_VISUAL")=="1" and DisplayServer.get_name()!="headless":
			for shot in [["fire_signal",l.signaled,l.FIRE_CELL],["gate_open",l.gate_open,l.SOUTH_GATE],["prisoners_freed",l.rescued,l.PRISON_INSIDE]]:
				if shot[1] and not captured.has(shot[0]):
					captured[shot[0]]=true
					b.camera.zoom=Vector2.ONE*1.1
					b.center_camera_cell(shot[2])
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(out_dir+"/"+shot[0]+".png")
		if time>=next_log:
			print("[daming-play] t=",int(time)," phase=",phase," spies=",spy_phase," army=",army.size()," cover=",l.spies.map(func(u): return alive(u) and u._invis_t>0)," gate=",l.gate_open," fire=",l.signaled," prison=",l.prison_open," rescued=",l.rescued," hall=",l.hall.hp if alive(l.hall) else 0)
			next_log+=60
		await _wait(1.25)
		time+=1.25
	check(b.phase==b.Phase.END and b.mission.has_event("daming_victory"),route+" route wins using real economy and battle")
	check(buildings_started>=2 and units_queued>=8 and units_queued_by_key.get("siege_cata",0)>=1,"route uses construction and paid army/siege production")
	check(l.hall==start_hall and alive(l.hall),"camp survives without phase redeployment")
	check(l.lu.story_outcome=="retreated" and l.shi.story_outcome=="retreated","same two prisoners actually reach exit alive")
	check(not alive(l.posts[0]),"route cuts paid outside reinforcement source")
	var result: Dictionary=b.mission.result_snapshot(b.mission.has_event("daming_victory"))
	if OS.get_environment("DAMING_VISUAL")=="1" and DisplayServer.get_name()!="headless":
		b.center_camera_cell(l.EXIT_CELL)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir+"/signal_result.png")
	if route=="signal":
		check(l.signaled and not b.mission.has_event("daming_gate_breached"),"infiltration signal allows intact gate to open")
		check(result.story_complete and result.story_done==3,"live signal route completes all three story contracts")
	play_metrics={"game_seconds":time,"phase":phase,"spy_phase":spy_phase,"buildings_started":buildings_started,"units_queued":units_queued,"units_queued_by_key":units_queued_by_key,"orders":orders,"skill_orders":skill_orders,"ai_trained":l.ai_trained,"camp_hp":l.hall.hp,"prisoner_hp":[l.lu.hp,l.shi.hp],"result":result,"events":b.mission.events.keys()}
