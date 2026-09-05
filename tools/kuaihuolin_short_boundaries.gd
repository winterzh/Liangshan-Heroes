extends "res://tools/kuaihuolin_short_test.gd"
## Explicit frozen fixtures. Positions, cooldowns and phase are injected here;
## skill damage still resolves through Battle._do_ability, not event fabrication.
func _fixture():
	var b=await _start("",6)
	b.set_process(false); b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	return b

func _dispatch(b,slot: int) -> void:
	var u=b.level.wu
	u._stun_t=0; u._cast_t=0; u.ability_slots[slot].cd_t=0
	b._do_ability(u,slot,u.position)
	await process_frame

func _opening(b) -> void:
	var l=b.level
	l.menshen.position=Vector2(1600,640); l.wu.position=Vector2(1680,640)
	l._begin_special(b)
	l.wu.position=l.fist_at+Vector2(0,130)
	l._duel_tick(b,l.fist_windup+0.01)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1"); AudioServer.set_bus_mute(0,true)
	Engine.time_scale=1
	var b=await _fixture()
	var l=b.level
	var atk: float=l.wu.atk
	l.on_mission_action(b,"drink_3",l.shi)
	check(l.drunk==0 and l.wu.atk==atk,"wrong actor cannot drink for Wu Song")
	l.on_mission_action(b,"drink_3",l.wu)
	check(l.drunk==1 and l.wu.atk==atk+5 and b.mission.has_event("drink_3"),"out-of-order fourth tavern is an independent preparation choice")
	l.on_mission_action(b,"drink_3",l.wu)
	check(l.drunk==1 and l.wu.atk==atk+5,"repeated tavern callback cannot duplicate attack or drink credit")
	l._start_step_drill(b)
	l._complete_step_drill(b,"injected_callback")
	check(l.st==l.STEP_DRILL and not b.mission.has_event("road_step_practiced"),"callback without movement cannot pass practice")
	l.wu.position=l.drill_origin+Vector2(80,0); l.process(b,0.01)
	check(not b.mission.has_event("road_step_practiced"),"still-near-circle fixture does not pass practice")
	l.wu.position=l.drill_origin+Vector2(100,0); l.process(b,0.01)
	check(b.mission.has_event("road_step_practiced") and l.st==l.ROAD,"leaving the practice area unlocks remaining choices")
	l.wu.position=l.menshen.position+Vector2(100,0); l.process(b,0.01)
	check(l.st==l.ROAD,"mere shop proximity does not open the duel")
	l._open_showdown(b,true)
	l.menshen.position=Vector2(1600,640); l.wu.position=Vector2(1680,640)
	b.mission.mark("dodge_heavy","explicit stale historical event fixture")
	var hp: float=l.menshen.hp
	await _dispatch(b,1); await _dispatch(b,2)
	check(l.menshen.hp<hp and not b.mission.has_event("mengzhou_signature"),"actual E damage with historical dodge and stationary W does not grant signature")
	_opening(b)
	check(l.exposed_left>0 and not l.menshen._damage_reduction_sources.has(l.BRACE_SOURCE),"missed current heavy creates a finite unbraced window")
	l.wu.position=l.menshen.position+Vector2(80,0)
	await _dispatch(b,1); hp=l.menshen.hp
	await _dispatch(b,2)
	check(l.menshen.hp<hp and not b.mission.has_event("mengzhou_signature"),"current opening plus stationary W and actual E hit still lacks footwork")
	await _dispatch(b,1)
	l.wu.position+=Vector2(0,32)
	hp=l.menshen.hp
	await _dispatch(b,2)
	check(l.menshen.hp<hp and b.mission.has_event("mengzhou_signature") and l.counter_hits>=2,"current W movement and actual nearby E damage grants signature in the boundary fixture")
	l._duel_tick(b,l.exposed_left+0.01)
	check(l.exposed_left==0 and l.step_serial==-1 and l.opening_serial==-1 and l.menshen._damage_reduction_sources.has(l.BRACE_SOURCE),"window expiry restores guard and consumes stale step/opening tokens")
	await _dispose(b)

	b=await _fixture(); l=b.level; l._open_showdown(b,true)
	_opening(b)
	l.wu.position=l.menshen.position+Vector2(300,0)
	await _dispatch(b,1); l.wu.position+=Vector2(0,32)
	hp=l.menshen.hp; await _dispatch(b,2)
	check(l.menshen.hp==hp and not b.mission.has_event("mengzhou_signature") and l.counter_hits==0,"out-of-range E cannot claim damage, counter or signature")
	check(float(l.wu.ability_slots[2].cd_t)>0,"whiffed E still consumes its normal cooldown")
	l._duel_tick(b,l.exposed_left+0.01)
	l.special_index=1; l.menshen.position=Vector2(1600,640); l.wu.position=Vector2(1735,640)
	l._begin_special(b)
	check(l.special_kind=="rush" and l.fist_marker.get_meta("tell_kind")=="rush","rush has a distinct corridor and locked direction")
	l.wu.position+=Vector2(0,120)
	l._duel_tick(b,l.fist_windup+0.01)
	var origin: Vector2=l.menshen.position
	# The actual shared charge integration is stepped deterministically here.
	for i in range(30):
		if l.menshen._charge_dash>0: l.menshen._do_charge_step(1.0/60.0)
	l._duel_tick(b,0.01)
	check(l.menshen.position.distance_to(origin)>150 and l.rush_dodges==1 and l.exposed_left>0,"missed charge physically travels before opening its counter window")
	l._duel_tick(b,l.exposed_left+0.01)
	l.special_index=1; l.menshen.position=Vector2(1600,640); l.wu.position=Vector2(1680,640)
	l._begin_special(b); l._duel_tick(b,l.fist_windup+0.01)
	hp=l.wu.hp
	for i in range(30):
		if l.menshen._charge_dash>0: l.menshen._do_charge_step(1.0/60.0)
	l._duel_tick(b,0.01)
	check(l.menshen._charge_hit.count(l.wu)==1 and l.wu.hp<hp,"actual charge hits a standing victim exactly once")
	check(l.exposed_left==0 and l.step_serial==-1,"landed charge grants no false dodge opening")
	l.special_index=1; l.menshen.position=Vector2(1600,640); l.wu.position=Vector2(1680,640)
	l._begin_special(b); l._duel_tick(b,l.fist_windup+0.01)
	l.menshen.resolve_story("subdued")
	check(l.st==l.RETURN_SHOP and not l.charge_running and l.menshen._charge_dash==0 and not is_instance_valid(l.fist_marker),"nonlethal defeat clears active charge, tell and combat phase")
	check(not b.mission.has_event("terms") and not l.victory,"subduing does not automatically speak terms or restore the shop")
	l.on_mission_action(b,"restore_shop",l.wu)
	check(not l.victory,"Wu Song cannot stand in for Shi En's takeover")
	await _dispose(b)
	for terrain in ["CLIFF","WATER"]:
		b=await _fixture(); l=b.level; l._open_showdown(b,true)
		b.map.set_cell_t(38,19,b.map.T[terrain])
		b.map.bake()
		l.special_index=1
		l.menshen.position=b.map.cell_to_world(Vector2i(35,19))
		l.wu.position=b.map.cell_to_world(Vector2i(40,19))
		l._begin_special(b); l._duel_tick(b,l.fist_windup+0.01)
		for i in range(30):
			if l.menshen._charge_dash>0: l.menshen._do_charge_step(1.0/60.0)
		check(l.menshen.position.x<38*32 and b.map.is_open_cell(b.map.world_to_cell(l.menshen.position)),"actual charge stops before "+terrain+" instead of teleporting through it")
		await _dispose(b)

	for key in ["wu","shi"]:
		b=await _fixture(); l=b.level
		l.get(key).take_damage(100000,null,true)
		check(b.phase==b.Phase.END and not l.victory,key+" actual death ends the chapter explicitly")
		await _dispose(b)
	b=await _fixture(); l=b.level; l._open_showdown(b,true)
	_opening(b)
	l.wu.position=l.menshen.position+Vector2(60,0)
	await _dispatch(b,1); l.wu.position+=Vector2(0,32)
	l.menshen.hp=1 # Explicit nonlethal finishing-hit boundary.
	await _dispatch(b,2)
	check(l.menshen.story_outcome=="subdued" and b.mission.has_event("mengzhou_signature"),"one-HP nonlethal finishing kick keeps actual signature credit")
	await _dispose(b)
	b=await _fixture(); l=b.level
	check(l.st==l.ROAD and l.drunk==0 and l.special_index==0 and l.counter_hits==0 and not l.victory,"fresh scene resets preparation, specials and result")
	check(l.step_serial==-1 and l.opening_serial==-1 and not l.charge_running and not is_instance_valid(l.drill_marker),"fresh scene has no pending combo, charge or practice marker")
	var old_id: int=b.get_instance_id()
	l.wu.take_damage(100000,null,true)
	var retry=b.hud.find_children("*","Button",true,false).filter(func(n): return n.text=="重打本关")
	if retry.size()==1: retry[0].pressed.emit()
	await _until(func(): return is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id,10)
	b=current_scene
	check(retry.size()==1 and b.get_instance_id()!=old_id and b.level.id()=="level7" and b.level.st==b.level.ROAD and b.level.drunk==0,"actual defeat-screen restart loads a fresh current chapter")
	await _dispose(b)
	for mode in ["skirmish","arena"]:
		b=await _start(mode,4)
		check(b._defs.wu_song==Defs.UNITS.wu_song and b._defs.jiang_menshen==Defs.UNITS.jiang_menshen,mode+" retains shared hero definitions without duel overrides")
		await _dispose(b)
	DirAccess.make_dir_recursive_absolute("res://.godot/kuaihuolin_short/boundaries")
	FileAccess.open("res://.godot/kuaihuolin_short/boundaries/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Explicitly injected phase/position/cooldown boundary fixtures; shared skill damage and charge integration are real. Live routes are separate."},"\t"))
	print("[kh-boundaries] ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() and checks==31 else 1)
