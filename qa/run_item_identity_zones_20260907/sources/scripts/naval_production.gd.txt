extends RefCounted
## Opt-in shore production. A berth is fixed when a yard is placed; completed
## ships never use the global nearest-open fallback to jump to another lake.
const INVALID := Vector2i(-1,-1)
const DIRECTIONS := [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]

static func clear_water(map: GameMap, cell: Vector2i, radius: float) -> bool:
	var p := map.cell_to_world(cell)
	# Check the complete collision envelope, including diagonals and boundaries.
	for y in [-1,0,1]:
		for x in [-1,0,1]:
			if not map.is_open_world(p+Vector2(x,y)*(radius+3.0),"water"): return false
	return true

static func berth(map: GameMap, cell: Vector2i, half: int) -> Vector2i:
	for direction in DIRECTIONS:
		var candidate: Vector2i=cell+direction*(half+2)
		# The first tile beyond the footprint must already be water. No launching
		# over cliffs, a strip of land, another dock or an intervening building.
		if map.is_open_cell(cell+direction*(half+1),"water") and clear_water(map,candidate,25):
			return candidate
	return INVALID

static func candidates(b, building, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	var anchor: Vector2i=building.get_meta("production_berth",INVALID)
	if anchor==INVALID: return result
	var center: Vector2i=b.map.world_to_cell(building.position)
	var direction := Vector2i(signi(anchor.x-center.x),signi(anchor.y-center.y))
	var side := Vector2i(-direction.y,direction.x)
	for outward in range(3):
		for lateral in [0,-1,1]:
			var candidate: Vector2i=anchor+direction*outward+side*lateral
			if clear_water(b.map,candidate,radius) and b.map._segment_open(b.map.cell_to_world(anchor),b.map.cell_to_world(candidate),"water"):
				result.append(candidate)
	return result

static func exit_cell(b, building, definition: Dictionary) -> Vector2i:
	var radius := float(definition.get("radius",25))
	for candidate in candidates(b,building,radius):
		var p: Vector2=b.map.cell_to_world(candidate)
		var occupied: bool=b.units.any(func(u):
			return is_instance_valid(u) and u.hp>0 and not u.garrisoned and not u.is_resource \
				and u.story_outcome=="" and u.position.distance_to(p)<radius+u.radius+6)
		if not occupied: return candidate
	return INVALID

static func configure(defs: Dictionary) -> void:
	# Scoped definitions; chapters explicitly opt in, leaving defense and the
	# existing global warship definition unchanged.
	defs["shipyard"]={"name":"船坞","hp":900,"atk":0,"cd":1,"range":0,"speed":0,"radius":30,
		"building":true,"buildable":true,"build_cat":"build","build_order":7,
		"cost_gold":100,"cost_wood":100,"build_time":30.0,"requires_shore":true,
		"building_art_key":"dock","produces":["liangshan_warship"],
		"desc":"建在岸边，保留开阔水面。花金木造战船，右键水面设集结点；堵口时成船留在队列。"}
	defs["liangshan_warship"].merge({"cost_gold":90,"cost_wood":65,"train_time":28.0,"pop":3},true)
