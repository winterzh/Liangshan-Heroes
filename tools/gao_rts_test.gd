extends "res://tools/zhujiazhuang_rts_test.gd"
## Actual new chapter startup/map/economy followed by labelled outcome fixtures.
func _build_at(b,key: String,cell: Vector2i,worker):
	b.select_single(worker,false)
	b.arm_build(key)
	b._try_place_building(b.to_screen(b.map.cell_to_world(cell)))
	var found: Array=b.units.filter(func(u): return alive(u) and u.key==key and b.map.world_to_cell(u.position)==cell)
	return found[0] if not found.is_empty() else null
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b=await _start("",4)
	Engine.time_scale=4
	var l=b.level
	check(l.get_script().resource_path.ends_with("level5_gao_rts.gd") and l.id()=="level5","menu enters persistent Gao while preserving chapter ID")
	check(b.economy and b.fog and b.current_age==3 and b._defs.has("shipyard"),"chapter enables economy, fog and paid shore production")
	check(b.used_pop()==36 and b.pop_cap==44,"initial workers, heroes, troops and four ships reserve honest population")
	for key in ["song_jiang","wu_yong","liu_tang","gongsun_sheng","liang_qiang","liang_gong","siege_ram"]:
		check(b._defs[key]==Defs.UNITS[key],"shared combat and costs unchanged: "+key)
	check(l.water_groups.map(func(g): return g.size())==[3,5,6] and l.land_groups.map(func(g): return g.size())==[4,6,8],"all three finite land and water forces are deployed from the start")
	var ships: Array=b.units.filter(func(u): return u.movement_profile=="water")
	check(ships.all(func(u): return b.map.is_open_world(u.position,"water")),"every starting ship is on navigable water")
	for cell in [l.LAND_POST,l.LAND_FRONT,l.YARD_SITE,l.LANDING,l.WIND]:
		var point: Vector2=b.map.cell_to_world(cell)
		# A producer itself blocks its center; validate the neighboring approach.
		if cell==l.LAND_POST: point=b.map.cell_to_world(cell+Vector2i(0,3))
		check(not b.map.find_path(l.song.position,point).is_empty(),"land approach connects without crossing water: "+str(cell))
	var water_start: Vector2=b.map.cell_to_world(l.LANDING_WATER)
	for cell in [l.SEA_FRONT,l.FIRE_SAFE,l.FIRE_POINTS[0],l.FIRE_POINTS[1],Vector2i(37,39),Vector2i(51,8),Vector2i(51,34)]:
		var point: Vector2=b.map.cell_to_world(cell)
		check(b.map.is_open_world(point,"water") and not b.map.find_path(water_start,point,0,"water").is_empty(),"water route connects: "+str(cell))
	check(not b.map._segment_open(l.song.position,water_start),"land cannot shortcut to sea")
	check(b.building_terrain_valid("shipyard",l.YARD_SITE),"dedicated shore supports real shipyard footprint and berth")
	check(l.posts[1].get_meta("production_berth")!=Vector2i(-1,-1),"enemy shipyard also has a valid fixed water berth")
	var g: int=b.gold
	var w: int=b.wood
	await _wait(20)
	check(b.gold>g and b.wood>w,"workers collect and unload actual gold and wood")
	var worker=l.workers[0]
	var yard=_build_at(b,"shipyard",l.YARD_SITE,worker)
	check(alive(yard) and yard.is_constructing,"player build command starts real shore construction")
	if not alive(yard): await _finish_gao(b); return
	await _wait(48)
	check(not yard.is_constructing,"worker reaches shore and finishes construction")
	_click(b,[yard],Vector2i(33,51))
	g=b.gold; w=b.wood
	check(b.queue_train(yard,"liangshan_warship",false) and b.gold==g-90 and b.wood==w-65,"ship queue spends actual shared naval price")
	await _wait(29)
	check(alive(b.find_unit("liangshan_warship")) and yard._train_queue.is_empty(),"paid ship launches in actual campaign map")
	check(b.find_unit("liangshan_warship").position.distance_to(b.map.cell_to_world(l.YARD_SITE))>85,"launched ship leaves the shore toward water rally")
	# Boundary fixtures: stop live fighting while checking timers and outcomes.
	for u in b.units: u.set_physics_process(false)
	for wave in l.waves: wave.time=99999
	l.production_t=[99999.0,99999.0]
	# Embark bookkeeping fixture: the live route separately covers the order.
	var liu=b.find_unit("liu_tang")
	var used_before: int=b.used_pop()
	w=b.wood
	l.on_mission_action(b,"gao_prepare",liu)
	check(l.fire_prepared and b.wood==w-60,"preparing fireboat spends its 60 wood exactly once")
	check(liu.story_outcome=="embarked" and b.used_pop()==used_before,"embarked Liu retains hero and population reservation")
	check(b._train_block_reason(l.hall,"liu_tang")=="hero_exists","embarked Liu cannot be recruited again")
	l.fireboat.take_damage(10000,null,false,true)
	check(b.find_unit("liu_tang")==null and b.used_pop()==used_before-3,"actual crew-boat loss releases embarked hero and population")
	check(b._train_block_reason(l.hall,"liu_tang")!="hero_exists" and b.mission.has_event("liu_tang_lost"),"lost embarked hero can be paid for again without duplicate reservation")
	var ids: Array=b.units.map(func(u): return u.get_instance_id())
	l._send_wave(b,0); l._send_wave(b,1); l._send_wave(b,2)
	check(ids==b.units.map(func(u): return u.get_instance_id()) and alive(yard),"sending all expeditions preserves every camp and unit instance")
	check(l.land_groups[0][0]._amove_dest==b.map.cell_to_world(l.LAND_FRONT) or l.land_groups[0][0]._target!=null,"enemy land force receives an active combat order")
	l.production_t=[0.0,0.0]
	b.faction_res[1]={"gold":560.0,"wood":400.0}
	var previous: Array=l.produced.duplicate()
	var spent_g: int=l.ai_spent_gold
	var spent_w: int=l.ai_spent_wood
	l._production(b,0.1)
	check(l.produced==[previous[0]+1,previous[1]+1] and l.ai_spent_gold-spent_g==115 and l.ai_spent_wood-spent_w==73,"both enemy producers pay separate faction resources before spawning")
	var after_production: Array=l.produced.duplicate()
	var count: int=b.units.size()
	l._production(b,0.1)
	check(b.units.size()==count,"enemy production cannot ignore training interval")
	l.posts[0].take_damage(10000,null,false,true)
	l.posts[1].take_damage(10000,null,false,true)
	l.production_t=[0.0,0.0]
	l._production(b,100)
	check(b.units.size()<=count and l.produced==after_production,"destroyed source stops its production immediately")
	check(b.mission.has_event("gao_land_post_destroyed") and b.mission.has_event("gao_sea_post_destroyed"),"source destruction records real map progress")
	# No teleport/forced outcome below is treated as a playable route.
	for group in l.water_groups+l.land_groups:
		for u in group:
			if alive(u): u.take_damage(10000,null,false,true)
	for u in l.support:
		if alive(u): u.take_damage(10000,null,false,true)
	l.flagship.take_damage(10000,null,false,true)
	await process_frame
	check(l.flagship_disabled and l.flagship.story_outcome=="subdued" and l.flagship.hp==1,"actual damage disables flagship with nonlethal story state")
	await _wait(0.4)
	check(l.core_ready and is_instance_valid(l.end_button) and b.phase==b.Phase.FIGHT,"cleared main threats offer explicit basic ending while capture remains optional")
	l.end_button.pressed.emit()
	check(b.phase==b.Phase.END and b.mission.has_event("gao_basic_victory"),"player ending button completes basic victory without capture tasks")
	await _dispose(b)
	for mode in ["skirmish","skirmish_ai"]:
		b=await _start(mode)
		check(not b._defs.has("shipyard") and not b._defs.has("liangshan_warship"),mode+" remains isolated from chapter naval definitions")
		await _dispose(b)
	b=await _start("",4)
	check(b.economy and b.level.elapsed<2 and b.level.produced==[0,0],"restart creates a fresh persistent chapter")
	await _finish_gao(b)
func _finish_gao(b) -> void:
	var folder: String="res://.godot/gao_rts"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/contracts.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"\t"))
	print("[gao-rts] ",checks," checks, failures=",failures.size())
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
