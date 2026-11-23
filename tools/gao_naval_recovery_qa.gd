extends "res://tools/zhujiazhuang_rts_test.gd"
## Frozen combat fixtures, plus one real return order. No full victory claim.
func _freeze(b) -> void:
	for u in b.units: u.set_physics_process(false)
	for wave in b.level.waves: wave.time=99999.0
	b.level.production_t=[99999.0,99999.0]
	b.fog=false
func _prepare(b):
	var l=b.level
	var hero=b.find_unit("liu_tang")
	l.on_mission_action(b,"gao_wind",b.find_unit("gongsun_sheng"))
	l.on_mission_action(b,"gao_prepare",hero)
	return hero
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var folder:=OS.get_environment("RTS_TEST_OUT")
	DirAccess.make_dir_recursive_absolute(folder)
	var flow := root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 180000
	while not flow.can_launch():
		if flow.phase == flow.Phase.ERROR or Time.get_ticks_msec() >= deadline:
			push_error("Campaign startup phase %s: %s" % [flow.phase, flow.last_result])
			quit(2)
			return
		await process_frame
	var b=await _start("",4)
	_freeze(b)
	var l=b.level
	var wood_before: int=b.wood
	var population: int=b.used_pop()
	var hero=_prepare(b)
	hero.hp-=37 # Injured passenger fixture: returning must not heal him.
	var before: Array=[hero.entity_id,hero.hp,hero.hero_level,hero.hero_xp,hero.inventory.snapshot()]
	check(l.fire_prepared and hero.story_outcome=="embarked" and b.wood==wood_before-60,"original paid embark creates return action")
	check(b.map.is_open_cell(l.LIU_RETURN,"water") and not b.map.find_path(l.fireboat.position,b.map.cell_to_world(l.LIU_RETURN),0,"water").is_empty() and l.LIU_RETURN!=l.LANDING_WATER,"separate return marker is navigable and does not overlap captive handover")
	var enemy=l.water_groups[0][0]
	var enemy_old: Vector2=enemy.position
	enemy.position=b.map.cell_to_world(l.LANDING)
	l.on_mission_action(b,"gao_liu_return",l.fireboat)
	check(hero.story_outcome=="embarked" and not l.fire_abandoned,"enemy at the dock prevents disembarking")
	enemy.position=enemy_old
	l.fireboat.position=b.map.cell_to_world(l.SEA_FRONT)
	l.on_mission_action(b,"gao_liu_return",l.fireboat)
	check(hero.story_outcome=="embarked","boat cannot unload remotely")
	l.fireboat.position=b.map.cell_to_world(l.LIU_RETURN)
	var blocked: Dictionary={}
	for y in range(-2,3):
		for x in range(-2,3):
			var cell: Vector2i=l.LANDING+Vector2i(x,y)
			blocked[cell]=b.map.astar.is_point_solid(cell)
			b.map.astar.set_point_solid(cell,true)
	l.on_mission_action(b,"gao_liu_return",l.fireboat)
	check(hero.story_outcome=="embarked" and l._liu_landing_cell(b)==l.Naval.INVALID,"blocked shore retries without searching a distant landing")
	for cell in blocked: b.map.astar.set_point_solid(cell,blocked[cell])
	b.find_unit("ruan_xiaowu_boat").take_damage(10000,null,false,true)
	check(not b.mission.actions.gao_fire_0.get("blocked_reason","").is_empty() and b.mission.actions.gao_liu_return.get("blocked_reason","").is_empty(),"lost escort blocks impossible fire but keeps original carrier return")
	l._update_wave_objective(b)
	check("返港下船" in b.mission._objective.text and "返港下船" in l.unit_tactical_hint(b,l.fireboat)
		and not "返港下船" in l.unit_tactical_hint(b,b.find_unit("ruan_xiaoer_boat")),
		"fire fallback offers the original carrier a return without assigning it to an empty escort")
	l.fireboat.position=b.map.cell_to_world(l.LANDING_WATER+Vector2i(4,1))
	var origin: Vector2=l.fireboat.position
	l.fireboat.set_physics_process(true)
	_click(b,[l.fireboat],l.LIU_RETURN)
	for i in range(160):
		if b.mission.has_event("gao_liu_returned"): break
		await _wait(0.1)
	l.fireboat.set_physics_process(false)
	check(b.mission.has_event("gao_liu_returned") and l.fireboat.position.distance_to(origin)>32,"normal player return order travels and completes the dock action")
	check(hero==b.find_unit("liu_tang") and before==[hero.entity_id,hero.hp,hero.hero_level,hero.hero_xp,hero.inventory.snapshot()] and b.used_pop()==population-3,"same injured hero returns with growth and equipment; only lost escort frees population")
	check(hero.story_outcome=="" and not hero.passive and hero.stance==hero.STANCE_DEFEND and b.map.is_open_world(hero.position),"returned hero is a normal controllable defender on land")
	check(l.fire_abandoned and l.embarked_liu==null and l.liu_carrier==null and l.fireboat.story_outcome=="retreated" and not l.fireboat.has_meta("story_commander"),"abandonment clears passenger bindings and retires unused fireboat")
	l._update_wave_objective(b)
	check(b.mission._objective.text==l.OPENING_OBJECTIVE and "已返港" in l.unit_tactical_hint(b,hero),
		"before wave one, abandoning the fire route restores the opening objective after Liu Tang is ashore")
	var unit_count: int=b.units.size()
	l.on_mission_action(b,"gao_liu_return",l.fireboat)
	l.on_mission_action(b,"gao_prepare",hero)
	check(b.wood==wood_before-60 and b.units.size()==unit_count and l.embarked_liu==null and b._train_block_reason(l.hall,"liu_tang")=="hero_exists","repeated callbacks neither refund nor duplicate or re-embark the hero")
	await _saved_return(b,hero)
	await _dispose(b)
	# Separate completed-fire fixture; never inherit the abandoned story state.
	b=await _start("",4)
	_freeze(b)
	l=b.level
	hero=_prepare(b)
	var two=b.find_unit("ruan_xiaoer_boat")
	var five=b.find_unit("ruan_xiaowu_boat")
	l.fireboat.position=b.map.cell_to_world(l.FIRE_POINTS[0])
	two.position=l.fireboat.position+Vector2(40,0)
	five.position=l.fireboat.position+Vector2(-40,0)
	l.water_groups[1][0].position=l.fireboat.position+Vector2(100,0)
	l.on_mission_action(b,"gao_fire_0",l.fireboat)
	check(l.fire_lit and l.liu_carrier==two and hero.story_outcome=="embarked","real fire action transfers original hero to Ruan Xiaoer")
	two.position=b.map.cell_to_world(l.FIRE_SAFE)
	five.position=two.position+Vector2(30,0)
	l.on_mission_action(b,"gao_fire_withdraw",two)
	check(b.mission.has_event("fire_escort_safe"),"both existing escort ships can finish the original withdrawal")
	two.position=b.map.cell_to_world(l.LIU_RETURN)
	l.on_mission_action(b,"gao_liu_return",two)
	check(hero.story_outcome=="" and alive(two) and not two.has_meta("carried_story_person") and not l.fire_abandoned and b.mission.has_event("fire_escort_safe") and b.mission.story_goals.gao_fire.state!="missed","successful fire permits later disembarking without consuming escort ship or losing story success")
	l.core_ready=true
	l._capture_failed(b,"fixture: capture carrier lost")
	check("直接点击收兵" in b.mission.objective,"lost capture route after core victory directs player to existing finish button")
	await _dispose(b)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"frozen combat fixtures, one normal return order, Level component and unit role checks; not whole-world continue or full playthrough"},"\t"))
	quit(0 if failures.is_empty() else 1)

func _saved_return(b,hero) -> void:
	var state=load("res://scripts/run_campaign_level_state.gd").new()
	var ids: Dictionary={}
	for u in b.units: ids[str(u.entity_id)]=u
	var saved: Dictionary=state.capture(b.level,"level5","return:v2",ids,b.next_entity_id,{}, {"mission_token":"return:fixture","deferred_drained":true})
	check(state.audit_declarations("level5").ok and saved.ok,"new abandoned flag and cleared carrier references capture")
	if not saved.ok: print(saved); return
	var codec=load("res://scripts/run_state_value_codec.gd").new()
	var decoded: Dictionary=codec.decode(saved.record.payload).value
	var contract=load("res://scripts/run_level5_unit_contract.gd").new()
	check(contract.configure(decoded).ok,"post-return unit roles accept original hero outside embarked role")
	var unit_state=load("res://scripts/run_unit_state.gd").new(load("res://scripts/run_state_value_codec.gd"),load("res://scripts/unit.gd"),load("res://scripts/hero_inventory.gd"),{"mode":"campaign","level_id":"level5","waves":0},decoded)
	check(contract.values(unit_state._read_explicit(hero)).ok,"returned original hero satisfies installed Gao unit values")
	var detached: Dictionary={}
	for id in ids:
		var u=load("res://scripts/unit.gd").new()
		u.entity_id=int(id)
		u.process_mode=Node.PROCESS_MODE_DISABLED
		u.set_block_signals(true)
		detached[id]=u
	var restored: Dictionary=state.restore(saved.record,"level5","return:v2",detached,b.next_entity_id,{},"return:fixture")
	check(restored.ok and restored.level.fire_abandoned and restored.level.embarked_liu==null and restored.level.liu_carrier==null,"Level round-trip retains abandonment and releases both carrier references")
	decoded.references.embarked_liu=str(hero.entity_id)
	check(not contract.configure(decoded).ok,"inconsistent abandoned run with an embarked passenger is rejected")
	for u in detached.values(): u.free()
