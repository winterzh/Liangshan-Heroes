extends "res://tools/zhujiazhuang_rts_test.gd"
## Isolated navigation and one-click combat regression; not campaign balance.
func legal_path(map,origin: Vector2,path: PackedVector2Array,profile := "land") -> bool:
	if path.is_empty(): return false
	for point in path:
		if not map.is_open_world(point,profile) or not map._segment_open(origin,point,profile): return false
		origin=point
	return true
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var Map=load("res://scripts/game_map.gd")
	var map=Map.new()
	map.init_map(24,18,"town",Map.T.GRASS)
	map.fill_rect(10,0,1,18,Map.T.HALL)
	map.bake()
	var start: Vector2=map.cell_to_world(Vector2i(3,13))
	var target: Vector2=map.cell_to_world(Vector2i(13,5))
	check(map.find_path(start,target).is_empty(),"ordinary move rejects a closed compartment")
	var path: PackedVector2Array=map.find_firing_path(start,target,164)
	check(legal_path(map,start,path),"ranged approach follows only reachable land and legal segments")
	check(not path.is_empty() and path[-1].distance_to(target)<=160,"ranged endpoint is actually within attack range")
	check(map.find_firing_path(start,target,90).is_empty(),"target beyond range across wall has no fake approach")
	check(map.find_firing_path(Vector2(-1,10),target,400).is_empty(),"outside-map origin cannot be clamped onto land")
	check(map.find_firing_path(map.cell_to_world(Vector2i(10,5)),target,400).is_empty(),"blocked origin cannot teleport out")
	check(map.find_firing_path(start,target,0).is_empty(),"zero-range weapon gets no firing path")
	check(legal_path(map,start,map.find_firing_path(start,target,164,1)),"enemy faction uses its own legal navigation")
	# Open/re-close a real navigation tile; no stale cache or phantom passage.
	map.set_cell_t(10,8,Map.T.ROAD)
	map.bake()
	check(legal_path(map,start,map.find_path(start,target)),"opening wall restores ordinary route")
	map.block_footprint(Vector2i(10,8),0,true)
	check(map.find_path(start,target).is_empty(),"reclosed dynamic gate blocks ordinary route again")
	check(legal_path(map,start,map.find_firing_path(start,target,164)),"ranged approach recomputes after gate closes")
	map.init_map(24,18,"marsh",Map.T.WATER)
	map.fill_rect(10,0,1,18,Map.T.GRASS)
	map.bake()
	var water_path: PackedVector2Array=map.find_firing_path(start,target,164,0,"water")
	check(legal_path(map,start,water_path,"water"),"ship firing approach never crosses land divider")
	check(not water_path.is_empty() and water_path[-1].distance_to(target)<=160,"ship endpoint is in weapon range")
	check(map.find_firing_path(start,target,164).is_empty(),"land profile cannot use ship origin")
	map.free()
	var b=await _start("",7)
	Engine.time_scale=4
	# Durable, frozen tower and stopped armies isolate one actual attack command.
	for u in b.units: u.set_physics_process(false)
	b.fog=false
	var tower=b.level.towers[0]
	var catapult=b.spawn_at("siege_cata",0,Vector2i(26,52))
	var melee=b.spawn_at("liang_qiang",0,Vector2i(25,52))
	var origin: Vector2=catapult.position
	var melee_origin: Vector2=melee.position
	var hp_before: float=tower.hp
	await _wait(0.5)
	check(b.map.find_path(origin,tower.position).is_empty(),"actual Daming tower compartment is closed")
	var began: int=Time.get_ticks_usec()
	for i in range(20): b.map.find_firing_path(origin,tower.position,catapult.atk_range+catapult.radius+tower.radius)
	var mean_ms: float=float(Time.get_ticks_usec()-began)/20000.0
	check(mean_ms<20,"Daming partial search average below 20 ms on QA host")
	b.select_members([catapult,melee],false)
	b._issue_order(b.to_screen(tower.position),false)
	check(catapult._target==tower and melee._target==tower,"one player click dispatches actual explicit tower attack")
	var moved_legally := true
	var prev: Vector2=catapult.position
	for i in range(180):
		await _wait(0.25)
		moved_legally=moved_legally and b.map.is_open_world(catapult.position) and b.map._segment_open(prev,catapult.position)
		prev=catapult.position
		if tower.hp<hp_before: break
	check(catapult.position.distance_to(origin)>100,"catapult approaches from distant field without manual staging")
	check(tower.hp<hp_before,"single attack order actually damages tower across closed wall")
	check(moved_legally and not b.level.gate_open,"actual movement never crosses wall or opens gate")
	check(melee.position.distance_to(melee_origin)<30,"melee receives no ranged fallback through wall")
	# H retains stationary behavior when an unreachable target is auto-acquired.
	catapult.order_hold_position()
	var held: Vector2=catapult.position
	tower.position+=Vector2(0,-450)
	await _wait(4)
	check(catapult.position.distance_to(held)<1 and catapult._hold_order_active,"Hold Position never advances toward out-of-range target")
	play_metrics={"partial_search_mean_ms":mean_ms,"catapult_distance":origin.distance_to(held),"damage":hp_before-tower.hp}
	await _dispose(b)
	Engine.time_scale=1
	check(checks==22,"all expected ranged navigation assertions executed")
	var folder="res://qa/daming_rts_20260905"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/ranged.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"metrics":play_metrics,"scope":"isolated navigation and input fixtures"},"\t"))
	quit(0 if failures.is_empty() else 1)
