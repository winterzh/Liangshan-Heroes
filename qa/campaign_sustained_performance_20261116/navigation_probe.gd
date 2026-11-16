extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 12:
		failures.append(label)

func _old_cell(map, nav: AStarGrid2D, target: Vector2i, origin := Vector2.INF) -> Vector2i:
	var c := Vector2i(clampi(target.x, 0, map.w - 1), clampi(target.y, 0, map.h - 1))
	if not nav.is_point_solid(c): return c
	for r in range(1, maxi(map.w,map.h)):
		var best := Vector2i(-1,-1)
		var best_d := INF
		for dy in range(-r,r+1):
			for dx in range(-r,r+1):
				if maxi(absi(dx),absi(dy)) != r: continue
				var n := c + Vector2i(dx,dy)
				if not nav.is_in_boundsv(n) or nav.is_point_solid(n): continue
				if origin == Vector2.INF: return n
				var d := Vector2(n).distance_squared_to(origin)
				if d < best_d:
					best_d = d
					best = n
		if best.x >= 0: return best
	return Vector2i(-1,-1)

func _old_path(map, from: Vector2, to: Vector2, faction: int, profile: String) -> PackedVector2Array:
	var land_or_water: AStarGrid2D = map.astar_water if profile == "water" else map.astar
	var a := _old_cell(map,land_or_water,map.world_to_cell(from))
	var target: Vector2i = map.world_to_cell(to)
	var b := _old_cell(map,land_or_water,target,Vector2(a))
	var out := PackedVector2Array()
	if a.x < 0 or b.x < 0 or not map.is_open_world(from,profile): return out
	if a == b:
		out.append(to if target == b and map.is_open_world(to,profile) else map.cell_to_world(b))
		return out
	var nav: AStarGrid2D = land_or_water if profile == "water" or faction == 0 else map.astar_guan
	var ids := nav.get_id_path(a,b)
	if ids.is_empty(): return out
	for i in range(1,ids.size()): out.append(map.cell_to_world(ids[i]))
	var smooth: PackedVector2Array = map._smooth_path(from,out,profile)
	if target == b and map.is_open_world(to,profile) and not smooth.is_empty():
		var previous: Vector2 = from if smooth.size() == 1 else smooth[smooth.size()-2]
		if map._segment_open(previous,to,profile): smooth[smooth.size()-1]=to
	return smooth

func _compare_cells(map, target: Vector2i, origin: Vector2i) -> void:
	for profile: String in ["land","water"]:
		var nav: AStarGrid2D = map.astar_water if profile=="water" else map.astar
		_expect(map.nearest_open(target,profile) == _old_cell(map,nav,target), "first dynamic "+str([target,profile]))
		_expect(map.nearest_open_from(target,origin,profile) == _old_cell(map,nav,target,Vector2(origin)), "closest dynamic "+str([target,origin,profile]))
	for faction: int in [0,1]:
		var nav: AStarGrid2D = map.astar_static if faction==0 else map.astar_static_guan
		_expect(map._nearest_static_open(target,faction)==_old_cell(map,nav,target),"first static "+str([target,faction]))
		_expect(map._nearest_static_open_from(target,origin,faction)==_old_cell(map,nav,target,Vector2(origin)),"closest static "+str([target,origin,faction]))

func _time_batch(map, points: Array, profile: String, old: bool) -> int:
	var start := Time.get_ticks_usec()
	var nav: AStarGrid2D = map.astar_water if profile=="water" else map.astar
	for pair: Array in points:
		if old:
			_old_cell(map,nav,pair[0],Vector2(pair[1]))
		else:
			map.nearest_open_from(pair[0],pair[1],profile)
	return Time.get_ticks_usec()-start

func _run() -> void:
	var Map = load("res://scripts/game_map.gd")
	var fixture = Map.new()
	fixture.init_map(17,11,"marsh",Map.T.GRASS)
	fixture.bake()
	_compare_cells(fixture,Vector2i(0,0),Vector2i(8,4))
	_compare_cells(fixture,Vector2i(50,-7),Vector2i(1,2))
	fixture.init_map(17,11,"marsh",Map.T.WATER)
	fixture.set_cell_t(2,5,Map.T.GRASS)
	fixture.set_cell_t(14,5,Map.T.GRASS)
	fixture.bake()
	for y in range(-2,13):
		for x in range(-2,19):
			_compare_cells(fixture,Vector2i(x,y),Vector2i(8,5))
	fixture.block_footprint(Vector2i(2,5),0,true)
	_compare_cells(fixture,Vector2i(0,5),Vector2i(8,5))
	fixture.block_footprint(Vector2i(2,5),0,false)
	_compare_cells(fixture,Vector2i(0,5),Vector2i(8,5))
	fixture.free()

	var level = load("res://scripts/levels/level5_gao_rts.gd").new()
	var map = Map.new()
	map.init_map(level.map_w(),level.map_h(),level.map_theme(),level.map_base())
	seed(5088120)
	level.paint_map(map)
	map.bake()
	var rng := RandomNumberGenerator.new()
	rng.seed=5088120
	for i in range(256):
		var target := Vector2i(rng.randi_range(-4,map.w+3),rng.randi_range(-4,map.h+3))
		var origin := Vector2i(rng.randi_range(-4,map.w+3),rng.randi_range(-4,map.h+3))
		_compare_cells(map,target,origin)
		if i<96:
			for profile: String in ["land","water"]:
				for faction: int in [0,1]:
					var nav: AStarGrid2D = map.astar_water if profile=="water" else map.astar
					var a := _old_cell(map,nav,origin)
					var from: Vector2 = map.cell_to_world(a) if i%4!=0 else map.cell_to_world(origin)
					var to := Vector2(target)*32.0 + Vector2(11.75,23.25)
					_expect(map.find_path(from,to,faction,profile)==_old_path(map,from,to,faction,profile),"map route exact "+str([i,faction,profile]))
	var batch := []
	for n in range(24):
		var target := Vector2i(19+n%8,31+n/8)
		var origin := Vector2i(34+n%5,49+n/5)
		batch.append([target,origin])
		_expect(map.nearest_open_from(target,origin,"water")==_old_cell(map,map.astar_water,target,Vector2(origin)),"fleet shore destination "+str(n))
	var before := []
	var after := []
	for rep in range(11):
		if rep%2==0:
			before.append(_time_batch(map,batch,"water",true))
			after.append(_time_batch(map,batch,"water",false))
		else:
			after.append(_time_batch(map,batch,"water",false))
			before.append(_time_batch(map,batch,"water",true))
	map.free()
	print("NAV_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"reference_batch_us":before,
		"current_batch_us":after,"batch_size":batch.size(),"kind":"authored Gao map, fleet landing targets from inland grid"}))
	quit(0 if failures.is_empty() else 1)
