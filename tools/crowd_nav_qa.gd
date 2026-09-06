extends "res://tools/crowd_neighbor_qa.gd"
const SOLVER_REFERENCE := "res://tools/contracts/crowd_nav/solver_before_9c19c93.txt"
const SOLVER_SHA := "fea12fde5cfcd1d9ff81e32314d73527ad999857118e7982c7b4aee7497cfccd"
var current_solver: GDScript

func _reference_spec() -> Dictionary:
	return {"path":"res://tools/contracts/crowd_nav/dispatch_before_9c19c93.txt","sha256":"5abd13653bc238a29bd790889a3dbbd2610ec535d193ac337426864b7e78c87d"}

func _output_path() -> String:
	return "res://.godot/crowd_nav_qa"

func _float_neighbor(value: float, increment: int) -> float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value)
	bytes.encode_u32(0,bytes.decode_u32(0)+increment)
	return bytes.decode_float(0)

func _pair_grid(units: Array) -> Dictionary:
	var result:={}
	for u in units:
		var key:=Vector2i(floori(u.position.x/64.0),floori(u.position.y/64.0))
		if not result.has(key):result[key]=[]
		result[key].append(u)
	return result

func _pair_step(units: Array, points: Array, map, reference) -> bool:
	_restore(units,points)
	var buckets:=_pair_grid(units)
	reference.call("solve",units,buckets,map,64.0)
	var expected:=_positions(units)
	_restore(units,points)
	current_solver.call("solve",units,buckets,map,64.0)
	position_comparisons+=units.size();sequential_steps+=1
	return _positions(units)==expected

func _navigation_boundaries(b, reference) -> void:
	var pair: Array=b.units.filter(func(u):return not u.is_building and not u.is_resource).slice(0,2)
	var fields:=_state(pair);var initial:=_positions(pair)
	for i in range(pair.size()):
		var u=pair[i];u.hp=100;u.garrisoned=false;u.story_outcome="";u.is_worker=false
		u._state=u.ST_MOVE if i==0 else u.ST_IDLE
	var coords: Array=[-0.000001,0.0,0.000001]
	for value in [32.0,64.0,96.0,128.0]:
		for offset in [-1,0,1]:coords.append(_float_neighbor(value,offset))
	var comparisons:=0
	var Map=load("res://scripts/game_map.gd")
	for layout in ["grass","shore","corner","water"]:
		var map=Map.new();map.init_map(4,4,"marsh",Map.T.WATER if layout=="water" else Map.T.GRASS)
		if layout=="shore":map.fill_rect(2,0,2,4,Map.T.WATER)
		if layout=="corner":map.set_cell_t(1,2,Map.T.CLIFF);map.set_cell_t(2,1,Map.T.CLIFF)
		map.bake()
		for profile in ["land","water","unsupported"]:
			for u in pair:u.movement_profile=profile
			var exact:=true
			for radius in [8.3,20.0,INF,NAN]:
				for u in pair:u.radius=radius
				for x in coords:
					for y in coords:
						for offset in [Vector2(0.75,0.35),Vector2(-0.75,0.35),Vector2(0,0.75)]:
							var point:=Vector2(x,y)
							exact=_pair_step(pair,[point,point+offset],map,reference) and exact;comparisons+=1
			check(exact,"all float32 tile/map boundaries and nonfinite displacement agree: "+layout+" "+profile)
		map.free()
	check(comparisons==32400,"32,400 independent two-body navigation precision fixtures executed")
	report["navigation_precision"]={"pair_steps":comparisons,"positions":comparisons*2,"scope":"Direct complete solver with two actual Units isolates navigation; production population dispatch tested by inherited fixtures. Float32 predecessor/exact/successor at all tile and map edges, shoreline/corner/land/water, finite and nonfinite radii."}
	var map=Map.new();map.init_map(4,4,"marsh",Map.T.GRASS);map.bake()
	for u in pair:u.movement_profile="land";u.radius=20
	var points: Array=[Vector2(48,48),Vector2(49,49)]
	for mutation in ["initial","block","unblock","direct_block","direct_unblock","water_open","water_close","rebake_block","rebake_open"]:
		match mutation:
			"block":map.block_footprint(Vector2i(1,1),0,true)
			"unblock":map.block_footprint(Vector2i(1,1),0,false)
			"direct_block":map.astar.set_point_solid(Vector2i(1,1),true)
			"direct_unblock":map.astar.set_point_solid(Vector2i(1,1),false)
			"water_open":map.astar_water.set_point_solid(Vector2i(1,1),false)
			"water_close":map.astar_water.set_point_solid(Vector2i(1,1),true)
			"rebake_block":map.set_cell_t(1,1,Map.T.CLIFF);map.bake()
			"rebake_open":map.set_cell_t(1,1,Map.T.GRASS);map.bake()
		for profile in ["land","water"]:
			for u in pair:u.movement_profile=profile
			check(_pair_step(pair,points,map,reference),"next solve reads navigation mutation "+mutation+" "+profile)
	map.astar.region=Rect2i();map.astar.update()
	for u in pair:u.movement_profile="land"
	check(_pair_step(pair,[Vector2(16,16),Vector2(112,112)],map,reference),"unprepared navigation adds no eager invalid-point queries for nonoverlapping bodies")
	map.free();_reset_fields(pair,fields);_restore(pair,initial)

func _nav_counted(source: String) -> GDScript:
	var script:=GDScript.new()
	script.source_code=source.replace("map._segment_open(","_qa_segment(map,").replace("nav.is_point_solid(cell)","_qa_cell(nav,cell)")
	script.source_code+='''
static var qa_segments := 0
static var qa_cells := 0
static func _qa_segment(map: GameMap, a: Vector2, b: Vector2, profile: String) -> bool:
	qa_segments+=1
	return map._segment_open(a,b,profile)
static func _qa_cell(nav: AStarGrid2D, cell: Vector2i) -> bool:
	qa_cells+=1
	return nav.is_point_solid(cell)
static func qa_counts() -> Array: return [qa_segments,qa_cells]
'''
	check(script.reload()==OK,"complete solver navigation counters compile")
	return script

func _extra_cases(b, old) -> void:
	await super(b,old)
	current_solver=load("res://scripts/crowd_separation.gd")
	check(FileAccess.get_sha256(SOLVER_REFERENCE)==SOLVER_SHA,"frozen 9c19c93 solver hash matches")
	_navigation_boundaries(b,old._reference_buffer)
	b._perf_bench_setup(200);b._prof_on=false;await process_frame
	var units: Array=b.units.filter(func(u):return not u.is_building and not u.is_resource)
	var points:=_positions(units);var counts:=[];var outputs:=[]
	for path in [SOLVER_REFERENCE,"res://scripts/crowd_separation.gd"]:
		var script:=_nav_counted(FileAccess.get_file_as_string(path))
		_restore(units,points);b._grid_build()
		script.call("solve",b.units,b._mob_grid,b.map,b.GRID_CELL)
		counts.append(script.call("qa_counts"));outputs.append(_positions(units))
	check(outputs[0]==outputs[1],"navigation counters preserve identical complete solver output")
	check(counts[1][0]<counts[0][0] and counts[1][1]>0,"fewer full segment calls with initial cell checks explicitly counted")
	report["navigation_calls"]={"reference_full_segments":counts[0][0],"optimized_full_segments":counts[1][0],"optimized_initial_cell_checks":counts[1][1],"units":units.size(),"scope":"Separate instrumented complete solver; initial occupancy checks reported alongside segment calls, timing includes all snapshot work."}
