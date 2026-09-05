extends "res://tools/zhujiazhuang_rts_test.gd"
## JZ_ROUTE=direct|story, JZ_VISUAL=1. Real orders/costs/combat, no fixtures.
var phase := "approach"
var recruited := 0
var skill_orders := 0
var pictures := {}
var route_index := 0
var max_troops := 0
var resting := {}
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	route=OS.get_environment("JZ_ROUTE")
	if route=="": route="direct"
	out_dir="res://.godot/jiangzhou_rts/"+route
	if OS.get_environment("JZ_VISUAL")=="1": out_dir+="_rendered"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size=Vector2i(1440,900)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	var b=await _start("",1)
	Engine.time_scale=4
	await _play_rescue(b)
	var report={"route":route,"checks":checks,"passed":failures.is_empty(),"failures":failures,"metrics":play_metrics,"scope":"real player commands, money, queue time and combat; automated full-state planning, not human fun acceptance"}
	FileAccess.open(out_dir+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[jiangzhou-play-result] ",JSON.stringify(report))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
func _shot(b,name: String,cell: Vector2i) -> void:
	if OS.get_environment("JZ_VISUAL")!="1" or DisplayServer.get_name()=="headless" or pictures.has(name): return
	pictures[name]=true
	b.camera.zoom=Vector2.ONE
	b.center_camera_cell(cell)
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out_dir+"/"+name+".png")==OK,"saved live "+name+" screenshot")
func _reinforce(b) -> void:
	for camp in b.level.camps:
		if not alive(camp) or not camp._train_queue.is_empty(): continue
		var key: String=["liang_qiang","liang_gong","liang_dao"][recruited%3]
		_click(b,[camp],Vector2i(22,28) if phase in ["approach","cache","fight","rescue"] else Vector2i(20,38))
		if b.queue_train(camp,key,false): recruited+=1
	for u in b.units:
		if alive(u) and u.faction==0 and u.is_hero:
			for slot in range(4):
				if u.can_learn(slot): u.learn(slot)
func _attack(b,army: Array,foe,cell: Vector2i) -> void:
	if army.is_empty(): return
	if alive(foe) and b.is_visible_world(foe.position):
		b.select_members(army,false); b._issue_order(b.to_screen(foe.position),false); orders+=1
	else: _click(b,army,cell,true)
func _skills(b,army: Array) -> void:
	for u in army:
		if not u.is_hero or u._cast_t>0: continue
		var foes: Array=b.units.filter(func(v): return alive(v) and v.faction==1 and not v.is_building and b.is_visible_world(v.position) and u.position.distance_to(v.position)<200)
		if foes.is_empty(): continue
		for slot in [0,1,3]:
			if slot>=u.slot_count() or not u.slot_ready(slot): continue
			b.select_members([u],false); b._cast_ability_slot(slot)
			if b._ability_armed!="": b._cast_armed_at(b.to_screen(foes[0].position))
			skill_orders+=1; break
func _play_rescue(b) -> void:
	var l=b.level
	var t := 0.0
	var log_at := 0.0
	var camp_ids: Array=l.camps.map(func(u): return u.get_instance_id())
	await _shot(b,"start",Vector2i(18,28))
	while b.phase==b.Phase.FIGHT and t<360:
		_reinforce(b)
		var army: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and not u.is_building and not u.is_worker and not u.is_noncombat)
		max_troops=maxi(max_troops,army.filter(func(u): return u.key in ["liang_dao","liang_qiang","liang_gong","liang_ma"]).size())
		if phase in ["approach","cache","fight","rescue"]: army=army.filter(func(u): return u.key not in ["zhang_shun","zhang_heng"])
		if route=="story" and phase in ["fight","rescue"]:
			for u in army.duplicate():
				if u.key not in l.NAMED: continue
				var retreat_at: float=0.85 if u.key=="li_kui" else (0.65 if u.key=="hua_rong" else 0.5)
				if u.hp<u.max_hp*retreat_at: resting[u.key]=true
				if u.hp>u.max_hp*0.95: resting.erase(u.key)
				if resting.has(u.key):
					army.erase(u); _click(b,[u],Vector2i(21,28))
		if t>=log_at:
			print("[jiangzhou-play] t=",int(t)," phase=",phase," alarm=",l.alarm," exec=",l.exec_left," army=",army.size()," g/w=",[b.gold,b.wood]," trained=",recruited," towers=",l.towers.map(func(u): return u.hp if alive(u) else 0)," enemy=",b.enemies_alive()," pair=",[l.song_freed,l.dai_freed].map(func(u): return [u.hp,b.map.world_to_cell(u.position)] if alive(u) else [])," action=",b.mission.active_action_id," named=",l.NAMED.map(func(key):
				var u=l.named_units.get(key)
				return [key,u.hp,b.map.world_to_cell(u.position),u.story_outcome] if u!=null else [key,"lost"]))
			log_at+=30
		if phase=="approach":
			var staging: Array=army.filter(func(u): return route!="story" or u.key not in ["li_kui","yan_shun"])
			_click(b,staging,Vector2i(22,28))
			var ready: bool=army.filter(func(u): return u.key in ["liang_dao","liang_qiang","liang_gong","liang_ma"]).size()>=(12 if route=="story" else 10)
			if route=="story":
				_click(b,[l.named_units.get("hua_rong")],Vector2i(20,28))
				_action(b,l.named_units.get("li_kui"),"west_street")
				_action(b,l.named_units.get("yan_shun"),"south_lane")
				if ready and b.mission.actions.has("first_axes"):
					var li=l.named_units.get("li_kui")
					var western: Array=l.city_guards.filter(func(u): return alive(u) and u.position.distance_to(l.caches[0].position)<230)
					western.sort_custom(func(a,z): return li.position.distance_to(a.position)<li.position.distance_to(z.position))
					if not western.is_empty(): _attack(b,[li],western[0],b.map.world_to_cell(western[0].position))
				if l.alarm: phase="cache"
			elif ready: phase="cache"
		if phase=="cache":
			if route=="story":
				var yan=l.named_units.get("yan_shun")
				army.erase(yan)
				if alive(yan): _click(b,[yan],Vector2i(21,28)) # Leave the cavalry lane as soon as the signal is given.
			var cache_foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building and u.position.distance_to(l.caches[0].position)<230)
			if not cache_foes.is_empty():
				_attack(b,army,cache_foes[0],b.map.world_to_cell(cache_foes[0].position))
				_skills(b,army)
			else:
				var collector=l.named_units.get("chao_gai")
				_click(b,army.filter(func(u): return u!=collector),Vector2i(21,28))
				_action(b,collector,"cache_0")
			if l.cache_taken[0]: phase="fight"
		if phase=="fight":
			var foes: Array=l.executioners.filter(func(u): return alive(u))
			if not foes.is_empty(): _attack(b,army,foes[0],l.SCAFFOLD)
			_skills(b,army)
			if l.execution_halted: phase="rescue"
		if phase=="rescue":
			if route=="story" and alive(l.towers[0]):
				var guards: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building and u.position.distance_to(b.map.cell_to_world(Vector2i(29,23)))<270)
				guards.sort_custom(func(a,z): return a.position.distance_to(b.map.cell_to_world(Vector2i(29,25)))<z.position.distance_to(b.map.cell_to_world(Vector2i(29,25))))
				if not guards.is_empty():
					_attack(b,army,guards[0],b.map.world_to_cell(guards[0].position)); _skills(b,army)
					await _wait(1); t+=1; continue
			# Stop execution first, then clear the actual arrow fire covering
			# the scaffold before exposing the unarmed prisoners.
			if alive(l.towers[0]):
				_attack(b,army,l.towers[0],b.map.world_to_cell(l.towers[0].position))
				_skills(b,army)
				await _wait(1); t+=1; continue
			var rescuer=l.named_units.get("chao_gai")
			if not alive(rescuer) or rescuer not in army: rescuer=army[0] if not army.is_empty() else null
			if alive(rescuer):
				army.erase(rescuer)
				_action(b,rescuer,"free_song" if l.song_freed==null else "free_dai")
			var foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and not u.is_building)
			foes.sort_custom(func(a,z): return a.position.distance_to(b.map.cell_to_world(l.SCAFFOLD))<z.position.distance_to(b.map.cell_to_world(l.SCAFFOLD)))
			_attack(b,army,foes[0] if not foes.is_empty() else null,l.SCAFFOLD+Vector2i(0,3))
			_skills(b,army)
			if alive(l.song_freed) and alive(l.dai_freed):
				phase="escape"
				await _shot(b,"rescued",l.SCAFFOLD+Vector2i(0,4))
		if phase=="escape":
			if route=="story":
				var boatmen: Array=[l.named_units.zhang_shun,l.named_units.zhang_heng].filter(func(u): return alive(u))
				for u in boatmen: army.erase(u)
				_click(b,boatmen,l.BAILONG)
			var points: Array=l.WEST_ROUTE if route=="story" else l.SOUTH_ROUTE
			var dest: Vector2i=points[mini(route_index,points.size()-1)]
			var pair: Array=[l.song_freed,l.dai_freed].filter(func(u): return alive(u))
			var center: Vector2=b.map.cell_to_world(dest)
			var close: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and (not u.is_building or u.atk>0) and (u.position.distance_to(center)<240 or pair.any(func(p): return p.position.distance_to(u.position)<220)))
			var rear_threats: Array=close.filter(func(u): return pair.any(func(p): return p.position.distance_to(u.position)<220))
			rear_threats.sort_custom(func(a,z): return a.position.distance_to(pair[0].position)<z.position.distance_to(pair[0].position))
			close.sort_custom(func(a,z): return a.position.distance_to(center)<z.position.distance_to(center))
			if not rear_threats.is_empty():
				_attack(b,army,rear_threats[0],b.map.world_to_cell(rear_threats[0].position))
			else: _attack(b,army,close[0] if not close.is_empty() else null,dest)
			_skills(b,army)
			if close.is_empty():
				_click(b,pair,dest)
				if pair.size()==2 and pair.all(func(u): return u.position.distance_to(center)<90): route_index+=1
			else:
				b.select_members(pair,false); b._order_stop()
			if route_index>=points.size():
				if route=="story" and not l.meeting and alive(l.named_units.zhang_shun) and alive(l.named_units.zhang_heng):
					_click(b,[l.named_units.get("zhang_shun"),l.named_units.get("zhang_heng")].filter(func(u): return alive(u)),l.BAILONG)
				else:
					if route=="story": await _shot(b,"meeting",l.BAILONG)
					phase="boarding"
		if phase=="boarding":
			await _shot(b,"boarding",l.DOCK+Vector2i(2,-3))
			# Keep the passenger landing clear. Real guards form a rear line;
			# named heroes withdraw only after the player orders collection.
			var named: Array=army.filter(func(u): return u==l.named_units.get(u.key))
			_click(b,army.filter(func(u): return u not in named),Vector2i(15,46))
			_click(b,named,l.DOCK+Vector2i(0,-2) if route=="story" else Vector2i(14,47))
			if route=="story":
				var leader=l.named_units.get("chao_gai")
				if not alive(leader): leader=army[0] if not army.is_empty() else null
				_action(b,leader,"rally_dock")
			_action(b,l.song_freed,"board_song")
			_action(b,l.dai_freed,"board_dai")
			if is_instance_valid(l.depart_button):
				var all_safe: bool=l.NAMED.all(func(key):
					var u=l.named_units.get(key)
					return u!=null and u.story_outcome=="embarked")
				if route!="story" or all_safe or b.mission.has_event("jiangzhou_named_lost"): l.depart_button.pressed.emit()
		await _wait(1.0)
		t+=1
	check(b.phase==b.Phase.END and l.victory,route+" rescues both prisoners and wins using actual player commands")
	check(recruited>=5 and max_troops>=8,route+" pays for real ordinary reinforcements and fields them")
	check(l.execution_halted and b.mission.has_event("free_song") and b.mission.has_event("free_dai"),route+" stops execution and separately unbinds both prisoners")
	check(l.camps.map(func(u): return u.get_instance_id())==camp_ids,route+" keeps its original reinforcement camps throughout the mission")
	if route=="story": check(b.mission.result_snapshot(l.victory).story_complete,"story completes all four optional goals through real movement and combat")
	play_metrics={"game_seconds":l.elapsed,"controller_wait_seconds":t,"paid_recruits":recruited,"max_ordinary_troops":max_troops,"orders":orders,"skills":skill_orders,"enemy_paid_recruits":l.enemy_produced,"enemy_spent_gold":l.enemy_spent_gold,"enemy_spent_wood":l.enemy_spent_wood,"cache_taken":l.cache_taken,"events":b.mission.events.keys(),"result":b.mission.result_snapshot(l.victory)}
	await _shot(b,"result",l.DOCK)
