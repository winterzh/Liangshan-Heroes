extends "res://tools/zhujiazhuang_rts_test.gd"
## Integration fixture for shared naval economy, including current chapter opt-in.
## Uses real build/queue/rally/cancel/repair commands and elapsed game time.
## Terrain, budgets and blocked berths below are deliberate boundary fixtures.
var Naval
const YARD := Vector2i(27,25)
const BERTH := Vector2i(30,25)

func _place_at(b,key: String,cell: Vector2i,worker):
	b.select_single(worker,false)
	b.arm_build(key)
	b._try_place_building(b.to_screen(b.map.cell_to_world(cell)))
	return b.units.filter(func(u): return alive(u) and u.key==key and b.map.world_to_cell(u.position)==cell)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	Engine.time_scale=4
	var b=await _start("",4)
	Engine.time_scale=4
	Naval=load("res://scripts/naval_production.gd")
	check(b._defs.has("shipyard") and b.economy,"Gao campaign explicitly enables the naval economy")
	b.clear_campaign_section()
	b.level=load("res://scripts/level_base.gd").new()
	b.mission.begin("naval_fixture","船坞验证","受控场地：真实建造与付费下水")
	b.map.fill_rect(0,0,60,60,b.map.T.WATER)
	b.map.fill_rect(0,0,29,60,b.map.T.GRASS)
	b.map.bake()
	Naval.configure(b._defs)
	b.economy=true
	b.current_age=3
	b.gold=500
	b.wood=500
	b.pop_cap=60
	b.fog=false
	var worker=b.spawn_at("lou_luo",0,Vector2i(24,25))
	await process_frame
	check(b.build_menu_cat("build").any(func(d): return d.key=="shipyard"),"shore yard appears in worker build menu only after opt-in")
	check(b.building_visual_texture("shipyard")!=null,"yard and build preview reuse the existing dock artwork")
	check(not b.building_terrain_valid("shipyard",Vector2i(12,25)),"inland footprint rejects missing berth")
	check(not b.building_terrain_valid("shipyard",Vector2i(31,25)),"water footprint rejects land construction")
	check(b.building_terrain_valid("shipyard",YARD),"shore footprint and collision envelope fit")
	check(_place_at(b,"shipyard",Vector2i(12,25),worker).is_empty() and b.gold==500 and b.wood==500,"invalid placement spends nothing")
	var built=_place_at(b,"shipyard",YARD,worker)
	check(built.size()==1 and b.gold==400 and b.wood==400,"actual build command spends 100 gold and 100 wood")
	if built.is_empty(): await _finish(b); return
	var yard=built[0]
	check(yard.is_constructing and yard.build_progress==0,"yard starts as an unfinished construction site")
	check(yard.get_meta("production_berth")==BERTH,"fixed berth recorded on the water side")
	check(not b.queue_train(yard,"liangshan_warship",false),"unfinished yard cannot train")
	await _wait(15)
	check(yard.is_constructing and yard.build_progress>0 and yard.build_progress<30,"worker walks to site and spends real construction time")
	await _wait(22)
	check(not yard.is_constructing and yard.hp==yard.max_hp,"worker completes yard without fixture advance_build")
	check(not b.map.is_open_cell(YARD) and b.map.is_open_cell(BERTH,"water"),"finished footprint blocks land while leaving berth open")
	check(b.production_exit_cell(yard,"liangshan_warship")==BERTH,"launch uses water berth instead of nearest land")
	# Use the same player command used on the minimap to set a water rally.
	_click(b,[yard],Vector2i(37,25))
	check(yard.has_rally and b.map.world_to_cell(yard.rally)==Vector2i(37,25),"player right-click sets water rally")
	check(b.queue_train(yard,"liangshan_warship",false) and b.gold==310 and b.wood==335,"ship order spends 90 gold and 65 wood")
	check(b._queued_pop()==3 and b.used_pop()==1,"paid queued ship reserves three population")
	await _wait(14)
	check(b.find_unit("liangshan_warship")==null and yard._train_t>0,"ship is not created before training finishes")
	await _wait(17)
	var ship=b.find_unit("liangshan_warship")
	check(alive(ship) and yard._train_queue.is_empty(),"ship launches after 28 seconds")
	if not alive(ship): await _finish(b); return
	check(ship.movement_profile=="water" and b.map.is_open_world(ship.position,"water"),"trained ship occupies legal water")
	check(ship.position.distance_to(b.map.cell_to_world(BERTH))>65,"ship follows real rally movement after launch")
	check(b.used_pop()==4 and b._queued_pop()==0,"population transfers from queue to live ship exactly once")
	check(b.gold==310 and b.wood==335,"completion does not charge a second time")
	# Boundary: dynamic obstruction covers the entire fixed berth. A distant
	# open sea still exists, but the completed ship must not teleport there.
	b.map.block_footprint(BERTH,2,true)
	check(b.production_exit_cell(yard,"liangshan_warship")==Naval.INVALID,"blocked outlet cannot use distant open water")
	check(b.queue_train(yard,"liangshan_warship",false),"blocked exit may retain a paid production order")
	check(b.queue_train(yard,"liangshan_warship",false),"second paid order queues normally")
	await _wait(30)
	check(yard.production_blocked and yard._train_t==0 and yard._train_queue.size()==2,"completed head stays at zero and preserves following order")
	check(b.units.filter(func(u): return u.key=="liangshan_warship").size()==1 and b._queued_pop()==6,"blocked production loses neither a ship nor population reservation")
	b.select_single(yard,false)
	b.hud._refresh_panel()
	check("等待下水" in b.hud._info_stats.text,"selected yard explains blocked berth instead of a stuck countdown")
	var g: int=b.gold
	var w: int=b.wood
	b.cancel_train(yard,1)
	check(yard.production_blocked and yard._train_queue.size()==1 and b.gold==g+90 and b.wood==w+65,"cancelling tail refunds only tail and preserves ready head")
	await _wait(2)
	check(yard._train_queue.size()==1 and b.gold==g+90,"retries do not duplicate ships or refunds")
	b.map.block_footprint(BERTH,2,false)
	await _wait(1)
	check(not yard.production_blocked and yard._train_queue.is_empty(),"clearing berth launches completed ship within retry interval")
	check(b.units.filter(func(u): return u.key=="liangshan_warship").size()==2,"exactly one retained ship appears after obstruction clears")
	# Boundary: cancelling a completed head must remove all waiting state, and
	# a later order must take the full training time again.
	b.map.block_footprint(BERTH,2,true)
	check(b.queue_train(yard,"liangshan_warship",false),"new order after resumed production is accepted")
	await _wait(29)
	g=b.gold
	w=b.wood
	b.cancel_train(yard,0)
	check(yard._train_queue.is_empty() and not yard.production_blocked and yard._train_t==0,"cancelling ready head clears blocked state")
	check(b.gold==g+90 and b.wood==w+65 and b._queued_pop()==0,"ready-head cancellation refunds once and frees population")
	b.map.block_footprint(BERTH,2,false)
	check(b.queue_train(yard,"liangshan_warship",false) and yard._train_t==28,"next order starts full duration instead of reusing completion")
	b.cancel_train(yard,0)
	# Boat occupancy, independent from terrain blocking.
	var blockers: Array=[]
	for c in Naval.candidates(b,yard,25):
		var blocker=b.spawn_at("liangshan_warship",0,c)
		blocker.set_physics_process(false)
		blockers.append(blocker)
	check(b.production_exit_cell(yard,"liangshan_warship")==Naval.INVALID,"live boats occupying all slipway cells also hold production")
	for blocker in blockers:
		b.units.erase(blocker)
		blocker.queue_free()
	await process_frame
	check(b.production_exit_cell(yard,"liangshan_warship")!=Naval.INVALID,"clearing parked boats restores outlet")
	# Real worker repair, followed by a destroyed producer and a rebuilt yard.
	yard.hp=yard.max_hp*0.5
	var damaged_hp: float=yard.hp
	g=b.gold
	w=b.wood
	b.select_single(worker,false)
	b._issue_order(b.to_screen(yard.position),false)
	await _wait(12)
	check(yard.hp>damaged_hp and (b.gold<g or b.wood<w),"worker repairs shore yard through player order and pays repair materials")
	b.select_single(worker,false)
	b._order_stop()
	check(b.queue_train(yard,"liangshan_warship",false),"yard queues a ship before destruction boundary")
	yard.take_damage(yard.max_hp*5,null,false,true)
	await process_frame
	check(not alive(yard) and b._queued_pop()==0 and b.map.is_open_cell(YARD),"destroyed yard releases footprint and no longer reserves queued population")
	var boats_before: int=b.units.filter(func(u): return u.key=="liangshan_warship").size()
	await _wait(29)
	check(b.units.filter(func(u): return u.key=="liangshan_warship").size()==boats_before,"destroyed producer cannot emit its unfinished ship later")
	var replacement=_place_at(b,"shipyard",YARD,worker)
	check(replacement.size()==1 and replacement[0]!=yard,"worker can rebuild on the released original footprint")
	if replacement.is_empty(): await _finish(b); return
	await _wait(33)
	yard=replacement[0]
	check(not yard.is_constructing and yard.get_meta("production_berth")==BERTH,"replacement completes with a fresh berth and empty queue")
	# Shore orientation and radius/boundary contracts.
	for direction in Naval.DIRECTIONS:
		b.map.fill_rect(3,3,13,13,b.map.T.WATER)
		b.map.fill_rect(7,7,3,3,b.map.T.GRASS)
		for other in Naval.DIRECTIONS:
			if other!=direction:
				var c: Vector2i=Vector2i(8,8)+other*2
				b.map.set_cell_t(c.x,c.y,b.map.T.CLIFF)
		b.map.bake()
		check(Naval.berth(b.map,Vector2i(8,8),1)==Vector2i(8,8)+direction*3,"berth follows shoreline axis "+str(direction))
	check(not Naval.clear_water(b.map,Vector2i(59,25),25),"collision envelope cannot extend beyond map boundary")
	# Existing land training still uses its own navigation profile.
	var barracks=b.spawn_at("barracks",0,Vector2i(19,35))
	check(b.map.is_open_cell(b.production_exit_cell(barracks,"liang_qiang")),"land production retains a legal land exit")
	check(b.queue_train(barracks,"liang_qiang",false),"shared land queue still accepts ordinary spear cost")
	await _wait(18)
	check(alive(b.find_unit("liang_qiang")) and barracks._train_queue.is_empty(),"ordinary land troop completes after naval queue changes")
	await _dispose(b)
	for mode in ["skirmish","skirmish_ai"]:
		b=await _start(mode)
		check(not b._defs.has("shipyard") and not b._defs.has("liangshan_warship"),mode+" does not inherit scoped naval definitions")
		await _dispose(b)
	b=await _start("",4)
	check(b._defs.has("shipyard") and b.economy and b.level.id()=="level5" and b.level.produced==[0,0],"restarting Gao restores fresh chapter economy without fixture state")
	await _finish(b)

func _finish(b) -> void:
	print("[naval-production] ",checks," checks, failures=",failures.size())
	await _dispose(b)
	quit(0 if failures.is_empty() and checks==57 else 1)
