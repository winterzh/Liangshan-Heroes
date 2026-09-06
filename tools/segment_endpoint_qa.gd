extends "res://tools/segment_navigation_qa.gd"
## Adds float32 grid-edge probes to the inherited eight-map and crowd replay.

func _snapshot_spec() -> Dictionary:
	return {"path":"res://tools/contracts/navigation/segment_before_66d27aa.txt","sha256":"dd28da8a1749a230b76428a88ec7ee70d86d438973a18bd95d53fb74b66d6ab1"}

func _output_path() -> String:
	return "res://.godot/segment_endpoint_qa"

func _adjacent_float32(value: float, increment: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0,value)
	bytes.encode_u32(0,bytes.decode_u32(0)+increment)
	return bytes.decode_float(0)

func _edge_values(cell_count: int) -> Array:
	var values := [-0.000001,0.0]
	for cell in range(1,cell_count+1):
		var edge := float(cell*32)
		values.append(_adjacent_float32(edge,-1))
		values.append(edge)
		values.append(_adjacent_float32(edge,1))
	return values

func _boundary_cases() -> void:
	super()
	var Map = load("res://scripts/game_map.gd")
	var precision_count := 0
	var layout_count := 0
	for size in [Vector2i(1,1),Vector2i(7,5),Vector2i(65,33)]:
		var map=Map.new()
		map.init_map(size.x,size.y,"marsh",Map.T.GRASS)
		for y in range(size.y):
			for x in range(size.x):
				if (x+2*y)%7==0: map.set_cell_t(x,y,Map.T.CLIFF)
				elif (x+3*y)%5==0: map.set_cell_t(x,y,Map.T.WATER)
		map.bake()
		var old=_reference(map)
		var mismatches := 0
		var xs:=_edge_values(size.x)
		var ys:=_edge_values(size.y)
		for x in xs:
			for y in ys:
				var a:=Vector2(x,y)
				# Exact endpoint and both directions across a nearby tile corner.
				for offset in [Vector2.ZERO,Vector2(0.125,-0.125),Vector2(-0.125,0.125)]:
					for profile in ["land","water","unsupported"]:
						if old._segment_open(a,a+offset,profile)!=map._segment_open(a,a+offset,profile): mismatches+=1
						precision_count+=1
		check(mismatches==0,"float32 neighbors of every grid line agree on %sx%s map"%[size.x,size.y])
		layout_count+=1
		old.free();map.free()
	var map=Map.new()
	map.init_map(4,4,"marsh",Map.T.GRASS);map.bake()
	var old=_reference(map)
	var a:=Vector2(48,48);var z:=Vector2(63.5,63.5)
	check(map._segment_open(a,z) and old._segment_open(a,z),"same-cell direct navigation mutation starts open")
	map.astar.set_point_solid(Vector2i(1,1),true)
	check(not map._segment_open(a,z) and not old._segment_open(a,z),"direct AStar blocking affects the very next query")
	map.astar.set_point_solid(Vector2i(1,1),false)
	check(map._segment_open(a,z) and old._segment_open(a,z),"direct AStar unblocking affects the very next query")
	map.astar_water.set_point_solid(Vector2i(1,1),false)
	check(map._segment_open(a,z,"water") and old._segment_open(a,z,"water"),"water navigation uses its own live grid")
	map.astar_water.set_point_solid(Vector2i(1,1),true)
	check(not map._segment_open(a,z,"water") and not old._segment_open(a,z,"water") and map._segment_open(a,z),"water reblocking leaves land passage open")
	map.set_cell_t(1,1,Map.T.CLIFF);map.bake()
	check(not map._segment_open(a,z) and not old._segment_open(a,z),"same-size map rebake updates endpoint blocking")
	map.set_cell_t(1,1,Map.T.GRASS);map.bake()
	check(map._segment_open(a,z) and old._segment_open(a,z),"same-size map rebake restores open endpoint")
	old.free();map.free()
	check(layout_count==3 and precision_count==182817,"all grid-edge precision fixtures completed")
	report["endpoint_precision"]={"layouts":layout_count,"comparisons":precision_count,"scope":"Float32 predecessor/exact/successor at every tile boundary; three profiles and three short-segment offsets."}
