extends Node2D
## 码头木板、台地岩土立面和敞开寨门。与寻路共用 Layout，物件不另改坐标。
const Layout := preload("res://scripts/liangshan_layout.gd")
const GateVisual := preload("res://scripts/liangshan_gate.gd")
const Stockade := preload("res://scripts/liangshan_stockade.gd")
const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
const CampaignArtEvent := preload("res://scripts/campaign_art_event.gd")
var _map: GameMap
var _gate_parts: Array[Node2D] = []
var _wall_parts: Array[Node2D] = []
var _side_gate_parts: Array[Node2D] = []
var _tick := 0.0
var _stockade_texture: Texture2D
var _stockade_metrics: Dictionary = {}
var _dock_straight_texture: Texture2D
var _dock_head_texture: Texture2D
var _gate_cell := Layout.GATE
var _east_gate_cell := Layout.EAST_GATE
var _bank_ridges: Array[PackedVector2Array] = []
var _rts_layout := false

func setup(map: GameMap) -> void:
	_map = map
	_rts_layout=Layout.is_rts_layout(map)
	_gate_cell=Layout.gate_for(map)
	_east_gate_cell=Layout.east_gate_for(map)
	_bank_ridges=Layout.bank_ridges_for(map)
	_stockade_texture=EnvironmentArt.object("level5","stockade_segment")
	_stockade_metrics=EnvironmentArt.calibrated_visual_metrics("object","level5","stockade_segment")
	_dock_straight_texture=EnvironmentArt.object("level5","dock_straight")
	_dock_head_texture=EnvironmentArt.object("level5","dock_head_t")
	var main_plaque := "山前关" if _rts_layout else "梁山"
	var east_plaque := "东山关" if _rts_layout else "东门"
	for cell in [_gate_cell+Vector2i(-2,0),_gate_cell+Vector2i(2,0)]:
		var post := GateVisual.new()
		# 南侧正门跨 X 轴墙段；ISO 投影后应沿右下斜向展开。
		post.facing = 1.0
		post.plaque_text = main_plaque
		post.sealed = _rts_layout
		if _rts_layout:
			var to_center := map.project(map.cell_to_world(_gate_cell))-map.project(map.cell_to_world(cell))
			post.closed_leaf_end = Vector2(to_center.x*post.facing,to_center.y)
		post.set_meta("fog_clearance_px",74.0)
		post.position = map.cell_to_world(cell)
		post.z_as_relative = false
		post.z_index = 1 + int(map.project(post.position).y)
		add_child(post)
		_gate_parts.append(post)
	var lintel := GateVisual.new()
	lintel.lintel = true
	lintel.facing = 1.0
	lintel.plaque_text = main_plaque
	lintel.set_meta("fog_clearance_px",138.0)
	lintel.position = map.cell_to_world(_gate_cell+Vector2i(2,0))
	lintel.z_as_relative = false
	lintel.z_index = 1 + int(map.project(lintel.position).y)
	add_child(lintel)
	_gate_parts.append(lintel)
	var main_gate_texture := EnvironmentArt.object("level5","main_gate")
	var main_gate_metrics := EnvironmentArt.calibrated_visual_metrics("object","level5","main_gate")
	var gate_rect = EnvironmentArt.calibrated_text_rect("object","level5","main_gate",
		"default","level5_main_gate_plaque")
	# 旧的整张寨门位图只有一个正面朝下视角。驻守战有两条互相垂直的
	# 墙轴，继续套用它会让门楼和墙体脱节；RTS 布局统一使用可按轴翻向
	# 的原生门架。第五关剧情场景仍保留已验收位图，不被这次修改影响。
	if not _rts_layout and main_gate_texture!=null and not main_gate_metrics.is_empty():
		for part in _gate_parts: part.replacement_texture=main_gate_texture
		lintel.replacement_owner=true
		# The accepted gate plaque remains blank: the manifest has no approved
		# original-text source for it. A later source-bound rect may enable text.
		if gate_rect is Array and gate_rect.size()==4:
			lintel.replacement_text_rect=gate_rect
		lintel.replacement_size=320.0
		lintel.replacement_foot=float(main_gate_metrics.get("foot",0.82))
		lintel.position=map.cell_to_world(_gate_cell)
		lintel.z_index=1+int(map.project(lintel.position).y)
		lintel.set_meta("campaign_environment_route","main_gate")
	for cell in [_east_gate_cell+Vector2i(0,-2),_east_gate_cell+Vector2i(0,2),_east_gate_cell+Vector2i(0,2)]:
		var part := GateVisual.new()
		part.position = map.cell_to_world(cell)
		part.facing = -1.0
		part.simple = false
		part.plaque_text = east_plaque
		part.set_meta("fog_clearance_px",138.0 if _side_gate_parts.size()==2 else 74.0)
		part.lintel = _side_gate_parts.size()==2
		part.sealed = _rts_layout and not part.lintel
		if part.sealed:
			var to_center := map.project(map.cell_to_world(_east_gate_cell))-map.project(map.cell_to_world(cell))
			part.closed_leaf_end = Vector2(to_center.x*part.facing,to_center.y)
		part.z_as_relative = false
		part.z_index = 1+int(map.project(part.position).y)
		add_child(part)
		_side_gate_parts.append(part)
	_setup_stockade()
	var dock_cell := Layout.dock_for(map)
	_add_dock_replacement(_dock_straight_texture,dock_cell+Vector2i(0,-2),142.0,"dock_straight")
	_add_dock_replacement(_dock_head_texture,dock_cell+Vector2i(0,1),154.0,"dock_head_t")
	queue_redraw()


func gate_orientation_summary() -> Dictionary:
	return {
		"rts_layout": _rts_layout,
		"main_axis": "x",
		"main_facing": _gate_parts[-1].facing if not _gate_parts.is_empty() else 0.0,
		"main_plaque": _gate_parts[-1].plaque_text if not _gate_parts.is_empty() else "",
		"main_uses_fixed_bitmap": _gate_parts[-1].replacement_texture != null if not _gate_parts.is_empty() else false,
		"east_axis": "y",
		"east_facing": _side_gate_parts[-1].facing if not _side_gate_parts.is_empty() else 0.0,
		"east_plaque": _side_gate_parts[-1].plaque_text if not _side_gate_parts.is_empty() else "",
	}


func _add_dock_replacement(texture: Texture2D, cell: Vector2i, size: float, route_key: String) -> void:
	if texture==null: return
	var sprite := CampaignArtEvent.new()
	sprite.texture=texture; sprite.size=size; sprite.duration=-1.0; sprite.life=-1.0
	var metrics := EnvironmentArt.calibrated_visual_metrics("object","level5",route_key)
	if not metrics.is_empty(): sprite.foot=float(metrics.get("foot",sprite.foot))
	sprite.position=_map.cell_to_world(cell)
	sprite.set_meta("fog_clearance_px",size*0.62)
	sprite.z_as_relative=false
	sprite.z_index=1+int(_map.project(sprite.position).y)
	sprite.set_meta("campaign_environment_route",route_key)
	add_child(sprite)
	_map.sync_render_position(sprite)

func _setup_stockade() -> void:
	# 直线分段沿新布局的不可走边界布置，不再画圆弧花园栅栏。
	for ridge in _bank_ridges:
		for i in range(ridge.size()-1):
			var spacing := 3.2
			var steps := maxi(1,ceili(ridge[i].distance_to(ridge[i+1])/spacing))
			for j in range(steps):
				var a: Vector2 = ridge[i].lerp(ridge[i+1],float(j)/steps)*GameMap.CELL
				var b: Vector2 = ridge[i].lerp(ridge[i+1],float(j+1)/steps)*GameMap.CELL
				_add_wall(a,b)

func _add_wall(a: Vector2,b: Vector2) -> void:
	var wall := Stockade.new()
	wall.position = a
	wall.end_local = _map.project(b)-_map.project(a)
	if _rts_layout:
		wall.height_scale=88.0
	wall.set_meta("fog_clearance_px",wall.height_scale)
	# Both axes use the same accepted timber source with its two real foot
	# anchors. The renderer handles the axis; no differently stretched strips
	# meet at the corner, and no image is edited or replaced.
	if _stockade_texture!=null:
		wall.campaign_texture=_stockade_texture
		wall.campaign_route="stockade_segment"
		wall.campaign_visible_bbox=_stockade_metrics.get("visible_bbox_xywh",[])
		wall.set_meta("campaign_environment_route","stockade_segment")
	wall.salt = _wall_parts.size()
	wall.z_as_relative = false
	wall.z_index = 1+int(maxf(_map.project(a).y,_map.project(b).y))
	add_child(wall)
	_wall_parts.append(wall)
	_map.sync_render_position(wall)

func _draw() -> void:
	if _map == null:
		return
	draw_set_transform_matrix(GameMap.ISO_INV)
	_draw_terrace()
	# 铺石主路由Layout铺设，与厅前同一种纹理，不再叠一块不同材质的台阶。
	# 同一片真实可行走的 T.DOCK，不拿桥贴图重复填格。
	var dock_axis_x := _gate_cell.x
	for y in range(46, 51):
		if y<=48 and _dock_straight_texture!=null: continue
		if y>=49 and _dock_head_texture!=null: continue
		var left := dock_axis_x-2 if y >= 49 else dock_axis_x-1
		var right := dock_axis_x+3 if y >= 49 else dock_axis_x+2
		for board in range(4):
			var by := float(y) + float(board) * 0.25
			var pts := PackedVector2Array([_screen(Vector2(left, by)), _screen(Vector2(right, by)),
				_screen(Vector2(right, by + 0.245)), _screen(Vector2(left, by + 0.245))])
			var tone := float((y * 7 + board * 3) % 5) * 0.025
			draw_colored_polygon(pts, Color("806441").lightened(tone))
			draw_line(pts[3], pts[2], Color("493b29"), 1.6, true)
			draw_line(pts[0].lerp(pts[3], 0.45), pts[1].lerp(pts[2], 0.45), Color(0.68, 0.55, 0.35, 0.35), 0.8, true)
		for x in [left, right]:
			var p := _screen(Vector2(x, y + 0.5))
			draw_line(p + Vector2(0, 9), p - Vector2(0, 7), Color("493522"), 4.5, true)
			draw_circle(p - Vector2(0, 7), 2.8, Color("b39361"), true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _screen(cell: Vector2) -> Vector2:
	return _map.project(cell * GameMap.CELL)

func _draw_terrace() -> void:
	var rock := Art.terrain_texture("cliff") as AtlasTexture
	var uv := _rock_uv(rock)
	for ridge in _bank_ridges:
		var points := PackedVector2Array()
		for i in range(ridge.size() - 1):
			var steps := maxi(1, ceili(ridge[i].distance_to(ridge[i + 1]) / 0.65))
			for j in range(steps):
				points.append(ridge[i].lerp(ridge[i + 1], float(j) / steps))
		points.append(ridge[-1])
		var inner := PackedVector2Array()
		var outer := PackedVector2Array()
		var normals := PackedVector2Array()
		for i in range(points.size()):
			var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var width := 0.33 + sin(points[i].x * 8.3 + points[i].y * 2.7) * 0.06
			normals.append(normal)
			inner.append(_screen(points[i] - normal * width))
			outer.append(_screen(points[i] + normal * width))
		for i in range(points.size() - 1):
			var n := normals[i]
			if n.x + n.y > 0.05:
				_face(outer[i], outer[i + 1], _ridge_depth(points[i]), _ridge_depth(points[i + 1]), i)
			else:
				draw_line(outer[i], outer[i + 1], Color(0.08, 0.14, 0.07, 0.40), 5.0, true)
			var cap := PackedVector2Array([inner[i],inner[i+1],outer[i+1],outer[i]])
			draw_colored_polygon(cap,Color("797460").darkened(float(i%5)*0.025))
			draw_polygon(cap,PackedColorArray([Color(0.85,0.81,0.71,0.18)]),uv,rock.atlas)
			var crack := inner[i].lerp(outer[i],0.65)
			draw_polyline(PackedVector2Array([inner[i],crack+Vector2(2,-1),outer[i]]),Color(0.25,0.26,0.20,0.55),0.85,true)
			if i % 3 != 0:
				draw_line(inner[i],inner[i].lerp(inner[i+1],0.65),Color(0.28,0.34,0.17,0.55),2.0,true)
			if i % 4 == 2:
				var p := _screen(points[i])
				var size := 26.0 + float(i % 3) * 7.0
				draw_texture_rect(Art.terrain_texture("rocks"), Rect2(p - Vector2(size * 0.5, size * 0.78), Vector2.ONE * size), false, Color(0.73, 0.81, 0.66))

func _ridge_depth(p: Vector2) -> float:
	# 低石脚承托木墙，不再用高岩圈暗示院内土丘。
	return 4.0 + sin(p.x * 1.7 + p.y * 0.8) * 1.2

func _rock_uv(rock: AtlasTexture) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		uv.append((rock.region.position + corner * rock.region.size) / rock.atlas.get_size())
	return uv

func _face(a: Vector2, b: Vector2, depth_a: float, depth_b: float, salt: int) -> void:
	var drop_a := Vector2(0, depth_a)
	var drop_b := Vector2(0, depth_b)
	var rock := Art.terrain_texture("cliff") as AtlasTexture
	var face := PackedVector2Array([a,b,b+drop_b,a+drop_a])
	draw_polygon(face,PackedColorArray([Color("7c7766"),Color("726e5d"),Color("494b3c"),Color("575545")]))
	draw_polygon(face,PackedColorArray([Color(0.82,0.79,0.69,0.16)]),_rock_uv(rock),rock.atlas)
	draw_line(a.lerp(b,0.55),a.lerp(b,0.42)+drop_a*0.7,Color(0.21,0.23,0.18,0.6),1.0,true)
	draw_line(a, b, Color(0.48, 0.53, 0.35, 0.45), 1.1, true)
	draw_line(a + drop_a, b + drop_b, Color(0.10, 0.14, 0.09, 0.35), 3.0, true)
	for i in range(3):
		var p := (a + drop_a).lerp(b + drop_b, float(i + 1) / 4.0)
		var h := 2.0 + float((salt * 7 + i * 11) % 6)
		draw_line(p, p + Vector2(-2, -h), Color(0.25, 0.32, 0.15, 0.8), 1.3, true)
		draw_line(p, p + Vector2(3, -h * 0.7), Color(0.34, 0.38, 0.19, 0.7), 1.0, true)

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.1 or _map == null:
		return
	_tick = 0.0
	var battle: Node = _map.get_parent().get_parent()
	if _rts_layout:
		_sync_gate_state(_gate_parts,"main",battle.units)
		_sync_gate_state(_side_gate_parts,"east",battle.units)
	_fade_gate(_gate_parts,Rect2(Vector2(_gate_cell)+Vector2(-2.5,-1.5),Vector2(6,3)),battle.units)
	_fade_gate(_side_gate_parts,Rect2(Vector2(_east_gate_cell)+Vector2(-1.5,-2.5),Vector2(3,6)),battle.units)
	for wall in _wall_parts:
		var wall_fades := false
		for unit in battle.units:
			if is_instance_valid(unit) and unit.hp>0 and unit.visible and not unit.is_building and unit.z_index<=wall.z_index:
				if wall.body_overlaps(_map.project(unit.position)-_map.project(wall.position)):
					wall_fades = true
					break
		# 不再把整段寨墙淡到近乎消失；保留遮挡关系，避免贴墙单位被误读为穿墙。
		wall.modulate.a = 0.72 if wall_fades else 1.0

func _sync_gate_state(parts: Array[Node2D], gate_id: String, units: Array) -> void:
	var alive := false
	for unit in units:
		if is_instance_valid(unit) and unit.hp>0 and String(unit.get_meta("liangshan_gate_id",""))==gate_id:
			alive = true
			break
	for part in parts:
		var should_seal: bool = alive and not part.lintel
		if part.sealed != should_seal:
			part.sealed = should_seal
			part.queue_redraw()

func _fade_gate(parts: Array[Node2D],zone: Rect2,units: Array) -> void:
	var fade := false
	var roof := parts[-1]
	var roof_origin := _map.project(roof.position)
	for unit in units:
		if not is_instance_valid(unit) or unit.hp<=0 or not unit.visible or unit.is_building:
			continue
		if zone.has_point(unit.position/GameMap.CELL):
			fade = true
			break
		if unit.z_index<=roof.z_index:
			var foot: Vector2 = _map.project(unit.position)-roof_origin
			if roof.occludes_body(Rect2(foot+Vector2(-12,-38),Vector2(24,40))):
				fade = true
				break
	var gate_sealed := parts.any(func(part): return part.sealed)
	for part in parts:
		part.modulate.a = (0.78 if gate_sealed else 0.48) if fade else 1.0
