extends "res://tools/zhujiazhuang_rts_test.gd"
## LHMR_TEST=contracts|defend|raid. Live routes use paid production and normal
## commands. Contract fixtures that reposition/freeze entities are separate.
var skill_orders := 0
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	route=OS.get_environment("LHMR_TEST")
	if route=="": route="contracts"
	out_dir="res://qa/lianhuanma_rts_20260905"
	build_cells=[Vector2i(5,28),Vector2i(5,35),Vector2i(12,36),Vector2i(17,36),Vector2i(12,23),Vector2i(16,24),Vector2i(9,43),Vector2i(20,34)]
	var b=await _start("",3)
	Engine.time_scale=4
	if route=="contracts": await _contracts_lhm(b)
	else: await _play_lhm(b)
	await _dispose(b)
	if route=="contracts":
		b=await _start("skirmish")
		check(b._defs.gou_lian==Defs.UNITS.gou_lian,"hook recruitment overrides do not leak to defense")
		check(b._defs.barracks==Defs.UNITS.barracks,"chapter barracks menu does not leak to defense")
		await _dispose(b)
	check(checks==({"contracts":42,"defend":5,"raid":6}.get(route,0)),"all expected route assertions executed")
	Engine.time_scale=1
	DirAccess.make_dir_recursive_absolute(out_dir)
	var result := {"route":route,"checks":checks,"passed":failures.is_empty(),"failures":failures,"metrics":play_metrics,"scope":"isolated boundary fixtures" if route=="contracts" else "automated actual economy/combat, not human fun acceptance"}
	FileAccess.open(out_dir+"/"+route+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("[lhm-rts] ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
func _contracts_lhm(b) -> void:
	var l=b.level
	check(b.level.get_script().resource_path.ends_with("level4_lianhuanma_rts.gd"),"campaign level4 menu loads the persistent RTS level")
	check(b.economy and b.fog and b.used_pop()==20 and b.pop_cap==24,"real economy and opening population are consistent")
	check(b._defs.barracks.produces.has("gou_lian") and b._defs.gou_lian.cost_gold==36 and b._defs.gou_lian.pop==2,"hook soldiers have explicit paid recruitment")
	for key in ["liang_dao","liang_qiang","liang_gong","liang_ma","caltrop_tower","arrow_tower","siege_cata"]:
		check(b._defs[key]==Defs.UNITS[key],"shared combat/economy unchanged: "+key)
	for field in ["hp","atk","cd","range","speed","bonus_cav"]: check(b._defs.gou_lian[field]==Defs.UNITS.gou_lian[field],"hook combat definition unchanged: "+field)
	check(l.riders.size()==12,"all twelve finite riders exist from deployment")
	for cell in [l.LANES[0],l.LANES[1],l.NORTH_POST,l.SOUTH_POST,l.ENEMY_CAMP,l.DRILL]:
		check(not b.map.find_path(l.song.position,b.map.cell_to_world(cell)).is_empty(),"strategic destination reachable: "+str(cell))
	var gold_before: int=b.gold
	var wood_before: int=b.wood
	await _wait(20)
	check(b.gold>gold_before and b.wood>wood_before,"workers gather and unload both resources")
	check(_place(b,"house"),"player can place a population building")
	await _wait(25)
	check(b.pop_cap>24,"worker finishes house and adds population")
	var barracks=b.units.filter(func(u): return u.faction==0 and u.key=="barracks")[0]
	var before: int=b.gold
	check(b.queue_train(barracks,"gou_lian",false) and b.gold==before-36,"hook recruitment debits actual gold")
	await _wait(21)
	check(b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="gou_lian").size()==3,"paid hook soldier appears after real training time")
	# Isolate finite enemy-account contracts from their miners and battle.
	for worker in l.enemy_workers: worker.set_physics_process(false)
	b.faction_res[1]={"gold":0.0,"wood":0.0}
	var old_trained: int=l.ai_trained
	l.escort_t=0
	l._support_tick(b,1)
	check(l.ai_trained==old_trained,"unfunded supply posts cannot spawn escorts")
	b.faction_res[1]={"gold":200.0,"wood":200.0}
	l.escort_t=0
	l._support_tick(b,1)
	check(l.ai_trained==old_trained+2 and b.faction_gold(1)<200,"both live supply posts pay for escorts")
	var old_time: float=l.waves[0].time
	l.posts[0].take_damage(999999,l.song,true,true)
	check(l.waves[0].time==old_time+45 and b.mission.has_event("lhm_supply_0"),"raiding source delays unsent north riders and records result")
	old_trained=l.ai_trained
	l.escort_t=0
	l._support_tick(b,1)
	check(l.ai_trained==old_trained+1,"destroyed supply post stops only its own future escorts")
	l._send_wave(b,1)
	var wave_before: bool=l.waves[1].sent
	l.posts[1].take_damage(999999,l.song,true,true)
	check(wave_before and l.waves[1].sent and l.riders.size()==12,"destroyed supply cannot erase or duplicate launched riders")
	old_trained=l.ai_trained
	l.escort_t=0
	l._support_tick(b,1)
	check(l.ai_trained==old_trained,"two destroyed posts end escort production")
	# Real attacks after a clearly labelled placement fixture.
	for u in b.units:
		if u.faction==1: u.set_physics_process(false)
	var rider=l.riders[0]
	var neighbor=l.riders[1]
	rider.position=b.map.cell_to_world(l.LANES[0])
	neighbor.position=rider.position+Vector2(110,0)
	l._rider_tick(b)
	check(rider._damage_reduction_sources.has(l.LINK_SOURCE),"nearby linked riders receive formation protection")
	neighbor.position+=Vector2(400,0)
	l._rider_tick(b)
	check(not rider._damage_reduction_sources.has(l.LINK_SOURCE),"isolated rider loses linked protection")
	var hooks: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="gou_lian")
	for i in range(hooks.size()):
		hooks[i].position=rider.position+Vector2(-36-i*20,10)
		hooks[i].order_hold_position()
		hooks[i].set_physics_process(false)
	hooks[1]._disarm_t=10
	hooks[2].position+=Vector2(300,0)
	hooks[0]._target=rider
	l._rider_tick(b)
	check(not bool(rider.get_meta("formation_broken")),"one effective hook soldier cannot break a rider")
	hooks[1]._disarm_t=0
	hooks[0].set_physics_process(true)
	hooks[1].set_physics_process(true)
	b.fog=false
	for u in b.units: u.fog_visible=true; u.show()
	await _wait(0.5) # Rebuild battle spatial index after the placement fixture.
	b.select_members([hooks[0],hooks[1]],false)
	b._issue_order(b.to_screen(rider.position),false)
	await _wait(1.5)
	print("[hook-contract] hp=",rider.hp," broken=",rider.get_meta("formation_broken")," terrain=",b.map.t_world(rider.position)," hooks=",l._hook_team(b,rider).size()," target=",hooks[0]._target," state=",hooks[0]._state)
	check(bool(rider.get_meta("formation_broken")) and rider.hp<rider.max_hp,"two actual hook attackers break and damage an impeded rider")
	var old_hall=l.hall
	l.lhm_killed=12 # Boundary: victory must still require enemy HQ.
	await _wait(0.5)
	check(b.phase==b.Phase.FIGHT and l.hall==old_hall,"defeating riders alone neither wins nor resets the camp")
	l.hall.take_damage(999999,l.hu,true,true)
	check(b.phase==b.Phase.END and not b.mission.has_event("lhm_victory"),"mid-campaign hall loss ends in defeat")
func _economy_lhm(b) -> void:
	_mine_idle_workers(b)
	var own: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_building)
	var reserve_gold := 0
	if not own.any(func(u): return u.is_constructing):
		var building_key := ""
		if b.pop_cap-b.used_pop()-b._queued_pop()<8 and b.pop_cap<84: building_key="house"
		elif own.filter(func(u): return u.key=="barracks").size()<2: building_key="barracks"
		elif not own.any(func(u): return u.key=="siege_workshop"): building_key="siege_workshop"
		if building_key!="" and not _place(b,building_key): reserve_gold=int(b._defs[building_key].cost_gold)
	var worker_count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_worker).size()
	for building in own:
		if building.is_constructing or not building._train_queue.is_empty(): continue
		var key := ""
		if building.key=="barracks": key=["gou_lian","liang_gong","liang_qiang","gou_lian","liang_dao"][units_queued%5]
		elif building.key=="siege_workshop" and b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="siege_ram").size()<2: key="siege_ram"
		elif building.key=="hall" and worker_count<10: key="lou_luo"
		if key!="" and b.gold>=int(b._defs[key].cost_gold)+reserve_gold and b.queue_train(building,key,false):
			units_queued+=1
			units_queued_by_key[key]=int(units_queued_by_key.get(key,0))+1
	for hero in b.units:
		if alive(hero) and hero.faction==0 and hero.is_hero:
			for slot in range(4):
				if hero.can_learn(slot): hero.learn(slot)
func _skills_lhm(b,army: Array) -> void:
	for hero in army:
		if not hero.is_hero or hero._cast_t>0: continue
		var foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and u.fog_visible and not u.is_building and hero.position.distance_to(u.position)<250)
		if foes.is_empty(): continue
		foes.sort_custom(func(a,z): return hero.position.distance_to(a.position)<hero.position.distance_to(z.position))
		for slot in [1,0,3]:
			if slot>=hero.slot_count() or not hero.slot_ready(slot): continue
			b.select_members([hero],false)
			b._cast_ability_slot(slot)
			if b._ability_armed!="": b._cast_armed_at(b.to_screen(foes[0].position))
			skill_orders+=1
			break
func _play_lhm(b) -> void:
	var l=b.level
	var time := 0.0
	var next_log := 0.0
	var phase := "north"
	var assault_ready := false
	var starting_hall=l.hall
	b.select_members([l.song],false)
	b._issue_order(b.to_screen(l.hall.position),false) # Normal garrison command protects the commander.
	while b.phase==b.Phase.FIGHT and time<900:
		_economy_lhm(b)
		# Keep the fragile required commander at camp; front-line heroes and
		# replaceable troops do the fighting. No health/stat changes in live routes.
		var army: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u!=l.song and not u.is_worker and not u.is_building and not u.is_noncombat)
		var target_cell: Vector2i=l.LANES[0]
		var target=null
		var attack_move := true
		if route=="raid":
			if alive(l.posts[0]): target=l.posts[0]; target_cell=l.NORTH_POST
			elif phase=="north": phase="redeploy_south"
			if phase=="redeploy_south":
				target_cell=Vector2i(28,41)
				attack_move=false
				if army.filter(func(u): return u.position.distance_to(b.map.cell_to_world(target_cell))<180).size()>=mini(8,army.size()): phase="raid_south"
			if phase=="raid_south":
				if alive(l.posts[1]): target=l.posts[1]; target_cell=l.SOUTH_POST
				else: phase="hold_north"
			if phase in ["hold_north","hold_south"]:
				if l.riders.filter(func(u): return alive(u) and int(u.get_meta("wave_group"))==0).is_empty(): phase="hold_south"
				target_cell=l.LANES[0] if phase=="hold_north" else l.LANES[1]
				if l.lhm_killed>=12: phase="counter"
		else:
			if l.riders.filter(func(u): return alive(u) and int(u.get_meta("wave_group"))==0).is_empty(): phase="south"
			if l.lhm_killed>=12: phase="counter"
			if phase=="south": target_cell=l.LANES[1]
		if phase=="counter":
			if army.size()<8: assault_ready=false
			if not assault_ready:
				target_cell=Vector2i(34,32)
				attack_move=false
				if army.filter(func(u): return u.position.distance_to(b.map.cell_to_world(target_cell))<220).size()>=18: assault_ready=true
			var survivors: Array=l.riders.filter(func(u): return alive(u))
			if assault_ready:
				if not survivors.is_empty(): target=survivors[0]; target_cell=b.map.world_to_cell(target.position)
				elif alive(l.hu): target=l.hu; target_cell=Vector2i(49,29)
				elif alive(l.han): target=l.han; target_cell=Vector2i(49,33)
				elif alive(l.enemy_base): target=l.enemy_base; target_cell=l.ENEMY_CAMP
		if army.size()>=8 or time>120:
			if alive(target) and target.visible:
				b.select_members(army,false)
				b._issue_order(b.to_screen(target.position),false)
				orders+=1
			else: _click(b,army,target_cell,attack_move)
		_skills_lhm(b,army)
		if time>=next_log:
			print("[lhm-play] t=",int(time)," phase=",phase," army=",army.size()," riders=",l.lhm_killed," hooks=",l.broken_count," posts=",l.posts.filter(func(u): return alive(u)).size()," g=",b.gold," w=",b.wood," hall=",l.hall.hp)
			next_log+=60
		await _wait(1.25)
		time+=1.25
	check(b.phase==b.Phase.END and b.mission.has_event("lhm_victory"),route+" route wins through real economy and combat")
	check(buildings_started>=2 and units_queued>=8,route+" route uses building and paid recruitment")
	check(l.hall==starting_hall and alive(l.hall),route+" keeps original camp alive across phases")
	check(l.lhm_killed==12 and l.manor_fallen,route+" clears finite riders and enemy headquarters")
	check(l.broken_count>0,route+" army performs actual hook counterplay")
	if route=="raid": check(b.mission.has_event("lhm_supply_0") and b.mission.has_event("lhm_supply_1"),"raiding stops both escort sources")
	play_metrics={"game_seconds":time,"riders_defeated":l.lhm_killed,"hook_broken":l.broken_count,"camp_hp":l.hall.hp,"song_hp":l.song.hp,"buildings_started":buildings_started,"units_queued":units_queued,"units_queued_by_key":units_queued_by_key,"ai_trained":l.ai_trained,"orders":orders,"skill_orders":skill_orders,"result":b.mission.result_snapshot(b.mission.has_event("lhm_victory")),"events":b.mission.events.keys()}
