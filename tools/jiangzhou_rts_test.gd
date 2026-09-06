extends "res://tools/zhujiazhuang_rts_test.gd"
## Real initial production, then explicitly frozen combat/outcome fixtures.
func _until(b,predicate: Callable,seconds: float) -> bool:
	var t := 0.0
	while t<seconds and b.phase==b.Phase.FIGHT:
		if predicate.call(): return true
		await _wait(0.25); t+=0.25
	return predicate.call()
func _act_until(b,actor,key: String,predicate: Callable,seconds: float) -> bool:
	var t := 0.0
	while t<seconds and b.phase==b.Phase.FIGHT:
		if predicate.call(): return true
		_action(b,actor,key)
		await _wait(1); t+=1
	if not predicate.call() and alive(actor):
		var a: Dictionary=b.mission.actions[key]
		var dest: Vector2=b.map.cell_to_world(a.cell)
		print("[jiangzhou-action-timeout] ",key," cell=",b.map.world_to_cell(actor.position)," dist=",actor.position.distance_to(dest)," segment=",b.map._segment_open(actor.position,dest,actor.movement_profile)," active=",b.mission.active_action_id," status=",b.mission._status.text)
		print("[jiangzhou-action-debug] state=",actor._state," path=",actor._path," nearby=",b.units.filter(func(u): return u!=actor and alive(u) and u.position.distance_to(actor.position)<100).map(func(u): return [u.key,u.faction,u.position, u.radius])," actor_pos=",actor.position)
	return predicate.call()
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b=await _start("",1)
	Engine.time_scale=4
	var l=b.level
	var unit_type=load("res://scripts/unit.gd")
	check(l.id()=="level2" and l.get_script().resource_path.ends_with("level2_jiangzhou_rts.gd"),"menu uses limited-supply rescue with compatible chapter ID")
	check(b.economy and b.fog and b.gold==190 and b.wood==120,"finite starting purse and fog are enabled")
	check(not b.units.any(func(u): return u.is_worker or u.is_resource),"emergency chapter has no mining, chopping or automatic income units")
	check(l.camps.size()==2 and l.camps.all(func(u): return b._trainable_keys(u)==Defs.UNITS.barracks.produces),"both real reinforcement camps share the normal troop roster")
	check(b.research_menu(l.camps[0]).is_empty(),"emergency camp offers no tech waiting loop")
	for key in ["chao_gai","li_kui","hua_rong","yan_shun","liang_dao","liang_qiang","liang_gong","liang_ma","arrow_tower"]:
		check(b._defs[key]==Defs.UNITS[key],"shared combat and troop cost unchanged: "+key)
	check(b.find_unit("li_kui").art_variant=="li_kui_jiangzhou","Jiangzhou keeps its accepted bare-chested Li Kui variant")
	check(l.pursuit.size()==6 and l.towers.size()==2 and b.find_unit("cai_jiu")!=null,"real reserve, route defenses and Cai Jiu exist from deployment")
	var starting_pop: int=b.used_pop()
	print("[jiangzhou-contract] initial_pop=",starting_pop," cap=",b.pop_cap)
	check(starting_pop<b.pop_cap and b.pop_cap==36,"initial army leaves honest population room for paid reinforcements")
	for cell in [l.SCAFFOLD+Vector2i(-1,1),l.CACHE_CELLS[0]+Vector2i(0,2),l.CACHE_CELLS[1]+Vector2i(0,2),l.BAILONG,l.DOCK,l.DOCK+Vector2i(2,0)]:
		check(not b.map.find_path(b.find_unit("chao_gai").position,b.map.cell_to_world(cell)).is_empty(),"real land route reaches "+str(cell))
	var hp: Array=l.NAMED.map(func(key): return b.find_unit(key).hp)
	await _wait(6)
	check(not l.alarm and hp==l.NAMED.map(func(key): return b.find_unit(key).hp),"waiting guards and arrow towers cannot damage heroes before uprising")
	check(b.gold==190 and b.wood==120,"waiting alone generates no gold or wood")
	var g: int=b.gold; var w: int=b.wood
	_click(b,[l.camps[0]],Vector2i(16,29))
	check(b.queue_train(l.camps[0],"liang_qiang",false) and b.gold==g-24 and b.wood==w-14,"spear order pays shared price")
	check(b.queue_train(l.camps[1],"liang_gong",false) and b.gold==g-48 and b.wood==w-28,"second camp spends the same finite purse independently")
	check(b._queued_pop()==2,"paid queues reserve two population before units exist")
	await _wait(18)
	check(l.camps.all(func(u): return u._train_queue.is_empty()) and b.used_pop()==starting_pop+2,"both troops finish after real training time and population transfers once")
	check(b.units.filter(func(u): return u.faction==0 and u.key in ["liang_dao","liang_qiang","liang_gong","liang_ma"]).all(func(u): return u.stance==unit_type.STANCE_PASSIVE) and not l.alarm,"new paid recruits wait for the uprising just like the original rescue party")
	# Remaining checks are explicit boundary fixtures, not a combat route.
	l._uprising(b,b.find_unit("chao_gai"))
	for u in b.units: u.set_physics_process(false)
	var original_heng=l.named_units.zhang_heng
	b._do_summon(original_heng,Defs.ABILITIES.zhang_heng_q.effect,1)
	var copies: Array=b.units.filter(func(u): return u.is_summon and u.key=="zhang_heng")
	check(copies.size()==2,"real Zhang Heng skill creates two copies with the same character key")
	check(copies.all(func(u): return not b.mission._valid_action_actor(u,{"actors":["zhang_heng"]}) and not b.mission._valid_action_actor(u,{"actors":[]})),"copies cannot impersonate named or generic mission actors")
	check(b.mission._valid_action_actor(original_heng,{"actors":["zhang_heng"]}),"original Zhang Heng remains eligible for manual mission actions")
	for copy in copies: copy.take_damage(10000,null,false,true)
	check(not b.mission.has_event("jiangzhou_named_lost") and l.named_units.zhang_heng==original_heng and alive(original_heng),"copy deaths cannot mark the original hero lost or replace his identity")
	l.exec_left=9999
	l.train_left=0
	b.faction_res[1]={"gold":0.0,"wood":0.0}
	var before: int=b.units.size()
	l._produce(b,1)
	check(b.units.size()==before and l.enemy_produced==0,"enemy post cannot create reinforcements without resources")
	b.faction_res[1]={"gold":160.0,"wood":100.0}
	l.train_left=0
	l._produce(b,1)
	check(l.enemy_produced==1 and l.enemy_spent_gold==25 and l.enemy_spent_wood==8,"enemy reinforcement debits its own actual budget")
	for u in l.reinforcements: u.set_physics_process(false)
	l._produce(b,0.1)
	check(l.enemy_produced==1,"enemy source respects its normal training interval")
	l.post.take_damage(10000,null,false,true)
	l.train_left=0; l._produce(b,100)
	check(l.enemy_produced==1 and b.mission.has_event("jiangzhou_post_destroyed"),"destroyed post immediately stops its source")
	var chao=b.find_unit("chao_gai")
	g=b.gold; w=b.wood
	l.on_mission_action(b,"cache_0",chao)
	check(not l.cache_taken[0] and b.gold==g and b.wood==w and not b.mission.actions.cache_0.done,"nearby guard denies supplies without consuming the action or paying")
	for u in b.units.duplicate():
		if alive(u) and u.faction==1 and u.position.distance_to(l.caches[0].position)<180: u.take_damage(10000,null,false,true)
	chao.set_physics_process(true); chao.set_stance(unit_type.STANCE_PASSIVE)
	g=b.gold; w=b.wood
	check(await _act_until(b,chao,"cache_0",func(): return l.cache_taken[0],20),"real manual movement claims cleared supplies")
	check(b.gold==g+100 and b.wood==w+60,"cleared cache credits exactly 100 gold and 60 wood")
	l.on_mission_action(b,"cache_0",chao)
	check(b.gold==g+100 and b.wood==w+60,"same cache cannot be claimed twice")
	check(l.pursuit.all(func(u): return u.passive and u._target==null),"unreleased reserve is still waiting before rescue")
	for u in l.executioners: u.take_damage(10000,null,false,true)
	# The boundary fixture freezes guards: clear the corridor explicitly.
	# A real rescue command must not phase through the surviving west guards.
	for u in l.city_guards:
		if alive(u): u.take_damage(10000,null,false,true)
	await _wait(0.4)
	check(l.execution_halted and b.mission.actions.has("free_song") and b.mission.actions.has("free_dai"),"actual executioner deaths unlock separate rescue actions")
	var halted_at: float=l.exec_left
	await _wait(1)
	check(l.exec_left==halted_at,"stopping execution stops the deadline permanently")
	_click(b,[chao],l.SCAFFOLD+Vector2i(0,1))
	await _wait(3)
	check(l.song_freed==null and l.dai_freed==null,"ambiguous midpoint command cannot rescue either prisoner")
	l.song_bound.take_damage(40,null,false,true)
	check(await _act_until(b,chao,"free_song",func(): return l.song_freed!=null,30),"real manual command separately frees Song")
	if l.song_freed==null:
		await _dispose(b); quit(1); return
	check(l.dai_freed==null and not b.mission.has_event("free_dai"),"freeing Song does not silently free Dai")
	print("[rescued-fields] ",[l.song_freed.hp,l.song_freed.max_hp,l.song_freed.atk,l.song_freed.is_hero,l.song_freed.is_noncombat,l.song_freed.ability_slots,l.song_freed.aura])
	check(l.song_freed.hp==160 and l.song_freed.max_hp==200 and l.song_freed.atk==0 and not l.song_freed.is_hero and l.song_freed.is_noncombat and l.song_freed.ability_slots.is_empty() and l.song_freed.aura=="","rescued Song keeps his wound and cannot fight, cast or grant auras")
	var reserve_ids: Array=l.pursuit.map(func(u): return u.get_instance_id())
	check(not l.pursuit_sent and l.pursuit_left>17,"first rescue gives a real 20-second pursuit warning")
	check(await _act_until(b,chao,"free_dai",func(): return l.dai_freed!=null,10),"a fresh independent command frees Dai")
	check(b.phase==b.Phase.FIGHT and not l.victory,"freeing both is not victory")
	check(await _until(b,func(): return l.pursuit_sent,21),"existing north reserve starts after its warning")
	check(reserve_ids==l.pursuit.map(func(u): return u.get_instance_id()),"pursuit moves existing soldiers without spawning a replacement group")
	# Prevent fixture enemies from sharing a landing area while moving prisoners.
	for u in b.units.duplicate():
		if alive(u) and u.faction==1: u.take_damage(10000,null,false,true)
	g=b.gold; w=b.wood
	check(await _act_until(b,chao,"cache_1",func(): return l.cache_taken[1],30),"cleared south supplies are independently reachable by a real order")
	check(b.gold==g+100 and b.wood==w+60 and l.cache_taken==[true,true],"second cache pays exactly once without replenishing the first")
	var shun=b.find_unit("zhang_shun"); var heng=b.find_unit("zhang_heng")
	shun.set_physics_process(true)
	_click(b,[l.song_freed,l.dai_freed,shun],l.BAILONG)
	check(await _until(b,func(): return [l.song_freed,l.dai_freed,shun].all(func(u): return l._near(b,u,l.BAILONG,130)),40),"both rescued men and Zhang Shun actually reach the temple")
	check(not l.meeting and not b.mission.has_event("bailong"),"three arrivals cannot substitute for the missing Zhang Heng")
	heng.set_physics_process(true)
	_click(b,[heng],l.BAILONG)
	check(await _until(b,func(): return l.meeting,10),"four real arrivals complete the optional temple meeting")
	check(not l.rally and not b.mission.has_event("jiangzhou_named_survive"),"temple meeting does not teleport the army or credit full evacuation")
	check(await _act_until(b,l.song_freed,"board_song",func(): return l.song_freed.story_outcome=="embarked",40),"Song actually walks to dock and boards through a manual command")
	check(not l.victory and not is_instance_valid(l.depart_button),"one passenger is insufficient to offer victory")
	_click(b,[l.dai_freed],l.DOCK+Vector2i(1,-1))
	check(await _until(b,func(): return l.dai_freed.position.distance_to(b.map.cell_to_world(l.DOCK+Vector2i(1,-1)))<25,40),"Dai actually reaches the adjacent non-action dock point")
	await _wait(2)
	check(l.dai_freed.story_outcome=="" and not b.mission.has_event("board_dai"),"standing near a boarding flag does not auto-board without the right command")
	var foe=b.spawn_at("guan_dao",1,l.DOCK+Vector2i(2,1)); foe.set_physics_process(false)
	_action(b,l.dai_freed,"board_dai")
	await _wait(3)
	check(l.dai_freed.story_outcome=="" and not b.mission.actions.board_dai.done,"live pursuer blocks boarding and leaves it retryable")
	check(not b.mission.actions.board_dai.actor_button.disabled,"blocked boarding restores the actor-selection button for retry")
	foe.take_damage(10000,null,false,true)
	check(await _act_until(b,l.dai_freed,"board_dai",func(): return l.dai_freed.story_outcome=="embarked",8),"boarding succeeds after clearing the actual dock threat")
	await _wait(0.4)
	check(is_instance_valid(l.depart_button) and b.phase==b.Phase.FIGHT,"both passengers offer explicit departure without requiring optional goals")
	l.depart_button.pressed.emit()
	check(l.victory and b.phase==b.Phase.END and b.mission.has_event("all_embarked"),"departure button completes core rescue without fake meeting or full-army credit")
	check(not b.mission.has_event("jiangzhou_named_survive"),"living named heroes elsewhere do not count as evacuated")
	var reports: int=b.mission.report.size()
	l.depart_button.pressed.emit()
	check(b.mission.report.size()==reports and b.phase==b.Phase.END,"repeated departure cannot settle or award the mission twice")
	await _dispose(b)
	# Independent failure fixtures use current scenes, not stale references.
	b=await _start("",1); l=b.level
	l.exec_left=0.01
	await _wait(0.3)
	check(b.phase==b.Phase.END and not l.victory,"uninterrupted execution deadline fails the mission")
	await _dispose(b)
	b=await _start("",1); l=b.level
	l.song_bound.take_damage(10000,null,false,true)
	l._finish(b)
	check(b.phase==b.Phase.END and not l.victory,"prisoner death cannot be replaced by a stale finish call")
	await _dispose(b)
	b=await _start("",1); l=b.level
	l.exec_left=9999
	for u in b.units: u.set_physics_process(false)
	check(b.queue_train(l.camps[0],"liang_qiang",false),"last paid rescue replacement can be queued before the army is lost")
	for u in b.units.duplicate():
		if u.faction==0 and u.key in l.RESCUERS: u.take_damage(10000,null,false,true)
	l.camps[0].set_physics_process(true)
	await _wait(0.4)
	check(b.phase==b.Phase.FIGHT,"army loss keeps the mission alive while a real paid replacement is training")
	await _wait(18)
	check(b.phase==b.Phase.FIGHT and b.units.any(func(u): return alive(u) and u.key=="liang_qiang"),"the queued replacement actually arrives and can continue rescue")
	for u in b.units.duplicate():
		if u.faction==0 and u.key in l.RESCUERS: u.take_damage(10000,null,false,true)
	b.gold=0; b.wood=0
	await _wait(0.4)
	check(b.phase==b.Phase.END and not l.victory,"no rescuers, queue or affordable replacement ends clearly instead of softlocking")
	await _dispose(b)
	for mode in ["skirmish","skirmish_ai"]:
		b=await _start(mode)
		check(b._defs.song_jiang==Defs.UNITS.song_jiang and b._defs.dai_zong==Defs.UNITS.dai_zong and b._defs.barracks==Defs.UNITS.barracks,mode+" keeps normal heroes and research roster after Jiangzhou")
		await _dispose(b)
	b=await _start("",1)
	check(not b.level.alarm and b.level.cache_taken==[false,false] and b.level.enemy_produced==0 and b.gold==190,"restarting resets resources, caches, alarm and enemy production")
	var folder := "res://.godot/jiangzhou_rts"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/contracts.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"real initial production then labelled combat/outcome fixtures and actual manual movements"},"\t"))
	print("[jiangzhou-contract-result] ",checks," checks, failures=",failures.size())
	await _dispose(b)
	quit(0 if failures.is_empty() and checks==80 else 1)
