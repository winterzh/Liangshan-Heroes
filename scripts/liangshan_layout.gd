extends RefCounted
## 门、墙、路使用共同布局；墙体与通行格一致，院内不造土丘。
const HALL_APPROACH := Vector2i(16,34)
const GATE := Vector2i(16,40)
const EAST_GATE := Vector2i(22,31)
const DOCK := Vector2i(16,49)
const TERRACE := Rect2i(10,27,13,14)
const COURT := Rect2i(11,28,11,12)
const RTS_GATE := Vector2i(18,44)
const RTS_EAST_GATE := Vector2i(31,32)
const RTS_DOCK := Vector2i(18,49)
const RTS_TERRACE := Rect2i(5,20,27,25)
const RTS_COURT := Rect2i(6,21,25,23)

static func is_rts_layout(map: GameMap) -> bool:
	return bool(map.get_meta("liangshan_rts_court",false))

static func gate_for(map: GameMap) -> Vector2i:
	return RTS_GATE if is_rts_layout(map) else GATE

static func east_gate_for(map: GameMap) -> Vector2i:
	return RTS_EAST_GATE if is_rts_layout(map) else EAST_GATE

static func dock_for(map: GameMap) -> Vector2i:
	return RTS_DOCK if is_rts_layout(map) else DOCK

static func terrace_for(map: GameMap) -> Rect2i:
	return RTS_TERRACE if is_rts_layout(map) else TERRACE

static func court_for(map: GameMap) -> Rect2i:
	return RTS_COURT if is_rts_layout(map) else COURT

static func bank_ridges() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([Vector2(22.5,29.5),Vector2(22.5,27.5),Vector2(10.5,27.5),
			Vector2(10.5,40.5),Vector2(14.5,40.5)]),
		PackedVector2Array([Vector2(18.5,40.5),Vector2(22.5,40.5),Vector2(22.5,33.5)])]

static func bank_ridges_for(map: GameMap) -> Array[PackedVector2Array]:
	if not is_rts_layout(map):
		return bank_ridges()
	return [
		PackedVector2Array([Vector2(5.5,20.5),Vector2(31.5,20.5)]),
		PackedVector2Array([Vector2(5.5,20.5),Vector2(5.5,44.5)]),
		PackedVector2Array([Vector2(5.5,44.5),Vector2(15.5,44.5)]),
		PackedVector2Array([Vector2(20.5,44.5),Vector2(31.5,44.5)]),
		PackedVector2Array([Vector2(31.5,20.5),Vector2(31.5,29.5)]),
		PackedVector2Array([Vector2(31.5,34.5),Vector2(31.5,44.5)]),
	]

static func enabled() -> bool:
	return OS.get_environment("LIANGSHAN_VISUAL_BASELINE") != "1"

static func is_ramp(cell: Vector2i) -> bool:
	return (cell.y==GATE.y and cell.x>=15 and cell.x<=17) \
		or (cell.x==EAST_GATE.x and cell.y>=30 and cell.y<=32)

static func is_bank(cell: Vector2i) -> bool:
	if not TERRACE.has_point(cell) or is_ramp(cell):
		return false
	return cell.x==10 or cell.x==22 or cell.y==27 or cell.y==40

static func paint(map: GameMap) -> void:
	var rts := is_rts_layout(map)
	var terrace := terrace_for(map)
	var court := court_for(map)
	var gate := gate_for(map)
	var east_gate := east_gate_for(map)
	# 整理院地，清掉旧门前树林和拼块，厅堂本体仍由关卡另行设置。
	map.fill_rect(court.position.x,court.position.y,court.size.x,court.size.y,
		GameMap.T.GRASS if rts else GameMap.T.DRYHILL)
	if rts:
		# 外院保留可建草地，只有厅堂核心是夯土地；避免一整块规则黄土台地。
		map.fill_ellipse(Vector2(18,31),9,7,GameMap.T.DRYHILL,[GameMap.T.GRASS])
	var axis_x := 18 if rts else 16
	map.paint_path([Vector2(axis_x,33),Vector2(axis_x,46)],1,GameMap.T.ROAD)
	map.fill_rect(axis_x-2,32,5,4,GameMap.T.PLAZA)
	map.fill_rect(axis_x-1,35,3,10 if rts else 8,GameMap.T.PLAZA)
	map.paint_path([Vector2(axis_x+2,32),Vector2(east_gate),Vector2(east_gate+Vector2i(1,0))],1,GameMap.T.ROAD)
	map.fill_rect(axis_x-1,46,3,4,GameMap.T.DOCK)
	map.fill_rect(axis_x-2,49,5,2,GameMap.T.DOCK)
	for y in range(terrace.position.y,terrace.end.y):
		for x in range(terrace.position.x,terrace.end.x):
			var cell := Vector2i(x,y)
			var gate_half := 2 if rts else 1
			var ramp := (cell.y==gate.y and cell.x>=gate.x-gate_half and cell.x<=gate.x+gate_half) \
				or (cell.x==east_gate.x and cell.y>=east_gate.y-gate_half and cell.y<=east_gate.y+gate_half)
			var bank := not ramp and (cell.x==terrace.position.x or cell.x==terrace.end.x-1 \
				or cell.y==terrace.position.y or cell.y==terrace.end.y-1)
			if bank:
				map.set_cell_t(x,y,GameMap.T.CLIFF)
