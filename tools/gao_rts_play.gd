extends "res://tools/zhujiazhuang_rts_test.gd"
## GAO_ROUTE=assault|story, GAO_VISUAL=1. Real player commands/costs/combat.
## No money, damage, unit, position or mission-result injection in this tool.
var skill_orders := 0
var captured := {}
var story_phase := "lure"
var last_land_order := ""
var recovering := {}
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	route=OS.get_environment("GAO_ROUTE")
	if route=="": route="assault"
	out_dir="res://.godot/gao_rts/"+route
	DirAccess.make_dir_recursive_absolute(out_dir)
	build_cells=[Vector2i(24,26),Vector2i(26,40),Vector2i(14,42),Vector2i(10,43),Vector2i(21,40),Vector2i(26,23),Vector2i(9,31),Vector2i(15,24)]
	var b=await _start("",4)
	Engine.time_scale=4
	await _play_gao(b)
	var report={"route":route,"checks":checks,"passed":failures.is_empty(),"failures":failures,"metrics":play_metrics,"scope":"actual economy and combat controlled through player commands; automated, not human fun acceptance"}
	FileAccess.open(out_dir+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[gao-play-result] ",JSON.stringify(report))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
func _economy_gao(b) -> void:
	_mine_idle_workers(b)
	var own: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_building)
	var yards: Array=own.filter(func(u): return u.key=="shipyard")
	if yards.is_empty() and b.can_afford(100,100):
		var workers: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_worker and u._state!=6)
		if not workers.is_empty():
			b.select_single(workers[0],false); b.arm_build("shipyard")
			var before: int=b.units.size()
			b._try_place_building(b.to_screen(b.map.cell_to_world(b.level.YARD_SITE)))
			if b.units.size()>before: buildings_started+=1
	elif not own.any(func(u): return u.is_constructing):
		if b.pop_cap-b.used_pop()-b._queued_pop()<6 and b.pop_cap<84: _place(b,"house")
		elif own.filter(func(u): return u.key=="barracks").size()<2: _place(b,"barracks")
	var ship_count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.key in b.level.SHIP_KEYS and u.key!="zhang_shun_boat").size()
	var troop_count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.key in ["liang_gong","liang_qiang","liang_dao"]).size()
	var worker_count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_worker).size()
	for building in own:
		if building.is_constructing or not building._train_queue.is_empty(): continue
		var key := ""
		if building.key=="shipyard" and ship_count<11:
			key="liangshan_warship"
			_click(b,[building],Vector2i(35,50))
		elif building.key=="hall" and worker_count<9: key="lou_luo"
		elif building.key=="barracks" and troop_count<18 and (ship_count>=6 or troop_count<9 or b.gold>150): key=["liang_qiang","liang_gong","liang_dao"][units_queued%3]
		if key!="" and b.queue_train(building,key,false):
			units_queued+=1
			units_queued_by_key[key]=int(units_queued_by_key.get(key,0))+1
	for u in b.units:
		if alive(u) and u.faction==0 and u.is_hero:
			for slot in range(4):
				if u.can_learn(slot): u.learn(slot)
func _skills(b,army: Array) -> void:
	for hero in army:
		if not hero.is_hero or hero._cast_t>0: continue
		var foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building and b.is_visible_world(u.position) and u.position.distance_to(hero.position)<240)
		if foes.is_empty(): continue
		for slot in [1,0,3]:
			if slot>=hero.slot_count() or not hero.slot_ready(slot): continue
			b.select_members([hero],false); b._cast_ability_slot(slot)
			if b._ability_armed!="": b._cast_armed_at(b.to_screen(foes[0].position))
			skill_orders+=1; break
func _attack(b,army: Array,target,cell: Vector2i) -> void:
	if army.is_empty(): return
	if alive(target) and b.is_visible_world(target.position):
		b.select_members(army,false)
		b._issue_order(b.to_screen(target.position),false)
		orders+=1
	else: _click(b,army,cell,true)
func _shot(b,label: String,cell: Vector2i) -> void:
	if OS.get_environment("GAO_VISUAL")!="1" or DisplayServer.get_name()=="headless" or captured.has(label): return
	captured[label]=true
	b.camera.zoom=Vector2.ONE
	b.center_camera_cell(cell)
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir+"/"+label+".png")
func _story(b,time: float) -> void:
	var l=b.level
	match story_phase:
		"lure":
			# Prepare a paid screen before inviting the first fleet into the harbor.
			# An immediate lure previously exposed the irreplaceable escort ships.
			if b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="liangshan_warship").size()>=2:
				_action(b,b.find_unit("ruan_xiaoqi_boat"),"gao_lure_side")
			if l.lure_started:
				_click(b,[b.find_unit("ruan_xiaoqi_boat")],Vector2i(36,49))
				story_phase="wind"
		"wind":
			_action(b,b.find_unit("gongsun_sheng"),"gao_wind")
			if b.mission.has_event("gongsun_wind"): story_phase="prepare"
		"prepare":
			_action(b,b.find_unit("liu_tang"),"gao_prepare")
			if l.fire_prepared: story_phase="fire"
		"fire":
			if time>280:
				var escorts: Array=[b.find_unit("ruan_xiaoer_boat"),b.find_unit("ruan_xiaowu_boat")].filter(func(u): return alive(u))
				_click(b,escorts,l.FIRE_POINTS[1]+Vector2i(-1,1))
				_action(b,l.fireboat,"gao_fire_1")
			else:
				var escorts: Array=[b.find_unit("ruan_xiaoer_boat"),b.find_unit("ruan_xiaowu_boat")].filter(func(u): return alive(u))
				_click(b,escorts,l.FIRE_SAFE)
			if l.fire_lit: story_phase="withdraw"
		"withdraw":
			var five=b.find_unit("ruan_xiaowu_boat")
			if alive(five): _click(b,[five],l.FIRE_SAFE)
			_action(b,b.find_unit("ruan_xiaoer_boat"),"gao_fire_withdraw")
			if b.mission.has_event("fire_escort_safe"): story_phase="battle"
		"battle":
			if l.flagship_disabled and not alive(l.posts[0]): story_phase="seal"
		"seal":
			var two=b.find_unit("ruan_xiaoer_boat")
			_action(b,two if alive(two) else b.find_unit("ruan_xiaowu_boat"),"gao_seal")
			if l.port_sealed: story_phase="recover"
		"recover":
			_action(b,b.find_unit("zhang_shun_boat"),"gao_scuttle")
			if l.recovered: story_phase="land"
		"land":
			_action(b,l.carrier,"gao_land")
			if l.landed: story_phase="escort"
func _play_gao(b) -> void:
	var l=b.level
	var time := 0.0
	var next_log := 0.0
	var start_hall=l.hall
	b.select_members([l.song],false)
	b._issue_order(b.to_screen(l.hall.position),false)
	await _shot(b,"camp",Vector2i(23,38))
	while b.phase==b.Phase.FIGHT and time<1100:
		_economy_gao(b)
		if route=="story": _story(b,time)
		var army: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u!=l.song and not u.is_worker and not u.is_building and not u.is_noncombat and u.movement_profile=="land" and b.mission._actor!=u)
		if route=="story":
			army=army.filter(func(u): return not (u.key=="gongsun_sheng" and story_phase in ["lure","wind"]) and not (u.key=="liu_tang" and story_phase in ["lure","wind","prepare"]))
		var land_target=null
		var land_cell := Vector2i(29,32)
		if route=="story" and story_phase in ["land","escort"]:
			if l.landed and alive(l.prisoner): _click(b,army+[l.prisoner],l.HALL+Vector2i(0,4))
			else: _click(b,army,l.LANDING+Vector2i(0,-2))
		else:
			var land_foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building and u.movement_profile=="land")
			land_foes.sort_custom(func(a,z): return a.position.distance_to(l.hall.position)<z.position.distance_to(l.hall.position))
			if not land_foes.is_empty() and (army.size()>=12 or land_foes[0].position.distance_to(l.hall.position)<520):
				land_target=land_foes[0]; land_cell=b.map.world_to_cell(land_target.position)
			elif army.size()>=12 and alive(l.posts[0]): land_target=l.posts[0]; land_cell=l.LAND_POST
			_attack(b,army,land_target,land_cell)
			_skills(b,army)
		var fleet: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.key in l.SHIP_KEYS and u.key!="zhang_shun_boat" and b.mission._actor!=u)
		if route=="story":
			if story_phase in ["lure","wind"]: fleet=fleet.filter(func(u): return u.key!="ruan_xiaoqi_boat")
			# Preserve the two rescue ships for their explicit task, with ordinary
			# paid ships screening them. Moving to the fire point starts before
			# the second wave, so task actors do not cross an engaged front late.
			if story_phase in ["lure","wind","prepare","fire","withdraw"]:
				fleet=fleet.filter(func(u): return u.key not in ["ruan_xiaoer_boat","ruan_xiaowu_boat"])
				if story_phase in ["lure","wind","prepare"]:
					for key in ["ruan_xiaoer_boat","ruan_xiaowu_boat"]:
						var rescue=b.find_unit(key)
						if alive(rescue): _click(b,[rescue],l.FIRE_SAFE)
			if story_phase=="seal":
				var seal_key: String="ruan_xiaoer_boat" if alive(b.find_unit("ruan_xiaoer_boat")) else "ruan_xiaowu_boat"
				fleet=fleet.filter(func(u): return u.key!=seal_key)
			for u in fleet.duplicate():
				if u.key in ["ruan_xiaoer_boat","ruan_xiaowu_boat"]:
					if u.hp<u.max_hp*0.7: recovering[u.key]=true
					if u.hp>=u.max_hp*0.95: recovering.erase(u.key)
					if recovering.has(u.key):
						_click(b,[u],Vector2i(29,53))
						fleet.erase(u)
		var sea_target=null
		var sea_cell := Vector2i(39,45)
		var naval_foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and u.movement_profile=="water")
		naval_foes.sort_custom(func(a,z): return a.position.distance_to(b.map.cell_to_world(l.SEA_FRONT))<z.position.distance_to(b.map.cell_to_world(l.SEA_FRONT)))
		if not naval_foes.is_empty() and (fleet.size()>=6 or naval_foes[0].position.distance_to(b.map.cell_to_world(l.SEA_FRONT))<360):
			sea_target=naval_foes[0]; sea_cell=b.map.world_to_cell(sea_target.position)
		if route=="story" and story_phase in ["fire","withdraw"]:
			sea_target=null; sea_cell=Vector2i(39,45)
		elif fleet.size()>=6 and alive(l.posts[1]) and time>260 and (naval_foes.is_empty() or naval_foes[0].position.distance_to(b.map.cell_to_world(l.SEA_FRONT))>440):
			sea_target=l.posts[1]; sea_cell=l.SEA_POST
		if route=="story" and not b.mission.has_event("fleet_in_ambush") and l._count(l.water_groups[0])>0:
			# Let an actual enemy enter the trap instead of intercepting it at sea.
			sea_target=null; sea_cell=Vector2i(34,50)
		_attack(b,fleet,sea_target,sea_cell)
		if route=="assault" and l.core_ready: l.end_button.pressed.emit()
		if l.fire_lit: await _shot(b,"fire",l.FIRE_POINTS[1])
		if l.recovered: await _shot(b,"prisoner_aboard",b.map.world_to_cell(l.carrier.position))
		if l.landed: await _shot(b,"landed",l.LANDING)
		if time>=next_log:
			print("[gao-play] t=",int(time)," story=",story_phase," army=",army.size()," fleet=",fleet.size()," land=",l.land_groups.map(func(g): return l._count(g))," sea=",l.water_groups.map(func(g): return l._count(g))," flagship=",l.flagship.hp," g=",b.gold," w=",b.wood," pop=",b.used_pop(),"/",b.pop_cap," hall=",l.hall.hp)
			next_log+=60
			if route=="story":
				print("[gao-story] active=",b.mission.active_action_id," fire=",l.fire_lit," smallboat=",[l.fireboat.hp,b.map.world_to_cell(l.fireboat.position)] if alive(l.fireboat) else []," escorts=",["ruan_xiaoer_boat","ruan_xiaowu_boat"].map(func(key):
					var u=b.find_unit(key)
					return [key,u.hp,b.map.world_to_cell(u.position)] if alive(u) else [key,"lost"]))
		if route=="story" and story_phase=="fire" and l._count(l.water_groups[1])==0 and not l.fire_lit:
			check(false,"fire opportunity lost during actual battle; abort failed story route")
			break
		await _wait(2)
		time+=2
	var won: bool=b.mission.has_event("gao_basic_victory") or b.mission.has_event("gao_captured")
	check(b.phase==b.Phase.END and won,route+" wins through actual construction, production and combat")
	check(buildings_started>=2 and units_queued_by_key.get("liangshan_warship",0)>=3,route+" builds economy and pays for at least three replacement warships")
	check(l.hall==start_hall and alive(l.hall),route+" preserves original camp across three expeditions")
	check(l._core_threats_clear(),route+" defeats all core land/water forces and disables flagship")
	if route=="story":
		check(b.mission.has_event("fire_escort_safe"),"live story route performs fire attack and extracts both escort ships")
		check(l.landed and b.mission.has_event("gao_captured"),"live story route carries prisoner by water then escorts him to hall")
		check(b.mission.result_snapshot(won).story_complete,"live story route completes all four story goals")
	play_metrics={"game_seconds":time,"buildings_started":buildings_started,"units_queued":units_queued,"units_queued_by_key":units_queued_by_key,"orders":orders,"skill_orders":skill_orders,"enemy_paid_produced":l.produced,"enemy_spent_gold":l.ai_spent_gold,"enemy_spent_wood":l.ai_spent_wood,"camp_hp":l.hall.hp,"story_phase":story_phase,"events":b.mission.events.keys(),"result":b.mission.result_snapshot(won)}
	await _shot(b,"result",l.HALL+Vector2i(0,4))
