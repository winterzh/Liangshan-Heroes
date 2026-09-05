extends Node2D
## 第5关视觉样板。地形通行由 liangshan_layout 在 bake 前设置；此处只渲染。
## 现有树木图集 + 固定光向投影；无需新增外部美术。

var _map: GameMap
var _battle: Node
var _trees: Array[ScenerySprite] = []
var _guard_posts: Array[ScenerySprite] = []
var _ground_shadows: Array = []
# Static props never move during the level. Keep their terrain-conforming
# contact patches and source-texture casts as cached meshes instead of replaying
# six CanvasItem commands for every tree/prop whenever scenery redraws.
var _ground_shadow_contact_mesh: ArrayMesh
var _ground_shadow_cast_meshes: Array = []
var _banks: Array = []
var _visibility_tick := 0.0
const Entrance := preload("res://scripts/liangshan_entrance.gd")
const Layout := preload("res://scripts/liangshan_layout.gd")
const CampaignFlagOverlay := preload("res://scripts/campaign_flag_overlay.gd")
const WorldShadow := preload("res://scripts/world_shadow.gd")
const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
var _entrance: Node2D
var _sprites: Array[Node2D] = []
var _reed_stems := PackedVector2Array()
var _reed_leaves := PackedVector2Array()
var _reed_heads := PackedVector2Array()
var _reed_stem_anchors := PackedVector2Array()
var _reed_leaf_anchors := PackedVector2Array()
var _reed_head_anchors := PackedVector2Array()
var _reed_cells := PackedVector2Array()
var _reed_mesh: ArrayMesh
var _reed_visibility_signature := -1
var _routed_reed_count := 0
const STATIC_CONTACT_SEGMENTS := 12
const HALL_CELL := Vector2i(16,30)


func setup(game_map: GameMap) -> void:
	_map = game_map
	_battle = _map.get_parent().get_parent()
	var level_id := _active_campaign_level_id()
	name = "LiangshanVisualSample"
	process_priority = 1000  # 单位物理和特效位置更新之后，再同步绘制高度。
	_setup_coast_material()
	# 使用局部 RNG，不能消耗战斗随机序列。
	var rng := RandomNumberGenerator.new()
	rng.seed = 5088120
	for y in range(_map.h):
		for x in range(_map.w):
			var terrain := _map.t_at(x, y)
			var core := terrain == GameMap.T.FOREST and (x*73+y*157+x*y*19)%31<7
			var edge := terrain == GameMap.T.GRASS and (x * 31 + y * 13) % 11 == 0 and _near_forest(x, y)
			if core or edge:
				var p := _map.cell_to_world(Vector2i(x, y))
				p += Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
				var kind: String = ["tree1", "tree", "tree1", "tree2"][rng.randi_range(0, 3)]
				var tex := Art.object_texture(kind)
				var tree_routes := ["tree_broad","tree_young","willow_old"]
				var tree_route: String = tree_routes[posmod(x*17+y*29,tree_routes.size())]
				var routed_tree := EnvironmentArt.object(level_id,tree_route)
				var tree_metrics := EnvironmentArt.calibrated_visual_metrics("object",level_id,tree_route)
				if routed_tree!=null and not tree_metrics.is_empty(): tex=routed_tree
				if tex == null:
					continue
				var size := rng.randf_range(90.0, 138.0) if core else rng.randf_range(48.0, 78.0)
				var tree_foot := float(tree_metrics.get("foot",0.91))
				var tree := _add_sprite(tex, p, size, tree_foot, true)
				tree.set_meta("campaign_environment_route",tree_route)
				tree.modulate = Color(rng.randf_range(0.83, 0.98), rng.randf_range(0.90, 1.0), 0.85)
				_trees.append(tree)
				_ground_shadows.append({"p": p, "tex": tex, "s": size, "foot": tree_foot, "alpha": 0.22})
			_cache_banks(x, y, terrain)
			if terrain == GameMap.T.REEDS and (x*17+y*31)%3!=0:
				_cache_reeds(x,y)
	_build_reed_mesh()
	# 从旧装饰列表复制视觉，原列表本身保持不变。
	for d in _map.decor:
		var tex: Texture2D = null
		var flag_rect: Array = []
		var routed_flag := false
		var decor_foot := 0.8
		if d.size()>3:
			# Blank source flag and runtime lettering are an atomic pair. Until the
			# accepted source SHA has a calibrated rect, keep the current banner.
			var candidate := EnvironmentArt.static_flag(level_id,String(d[3]))
			var measured = EnvironmentArt.calibrated_text_rect("static_flag",level_id,
				String(d[3]),"default",String(d[3]))
			if candidate!=null and measured is Array and measured.size()==4:
				tex=candidate
				flag_rect=measured
				var flag_metrics := EnvironmentArt.calibrated_visual_metrics("static_flag",level_id,String(d[3]))
				if not flag_metrics.is_empty():
					decor_foot=float(flag_metrics.get("foot",decor_foot))
					routed_flag=true
		if tex==null: tex=Art.terrain_texture(d[0])
		if tex == null:
			continue
		var p := _map.cell_to_world(d[1])
		var size: float = d[2]
		var decor_sprite := _add_sprite(tex, p, size, decor_foot, false)
		if d.size()>3:
			decor_sprite.set_meta("campaign_environment_static_flag",String(d[3]))
			if routed_flag:
				decor_sprite.set_meta("campaign_environment_route",String(d[3]))
		# 四元 decor 是未来的可选旗号地点 marker。现有三元通用 banner 保持无字；
		# 这里不从贴图名或阵营自动猜旗文。
		if d.size() > 3:
			_add_flag_overlay(String(d[3]), p, size, decor_foot, String(d[0]), level_id,flag_rect,routed_flag)
		if d[0] not in ["boat", "bridge"]:
			_ground_shadows.append({"p": p, "tex": tex, "s": size, "foot": decor_foot, "alpha": 0.22})
	# The hall's Unit remains the gameplay collider/health owner. Render its exact
	# accepted bitmap here, in the same static depth/shadow route as the stockade,
	# so transparent padding is never passed through the legacy building canvas.
	if level_id=="level5":
		var hall_tex := EnvironmentArt.object(level_id,"zhongyi_hall")
		var hall_metrics := EnvironmentArt.calibrated_visual_metrics("object",level_id,"zhongyi_hall")
		if hall_tex!=null and not hall_metrics.is_empty():
			var hall_p := _map.cell_to_world(_map.get_meta("liangshan_hall_cell",HALL_CELL))
			var hall_size := GameMap.building_visual_px(GameMap.footprint_half_for(58.0))
			var hall_foot := float(hall_metrics.get("foot",0.78))
			var hall_sprite := _add_sprite(hall_tex,hall_p,hall_size,hall_foot,false)
			hall_sprite.set_meta("campaign_environment_route","zhongyi_hall")
			_ground_shadows.append({"p":hall_p,"tex":hall_tex,"s":hall_size,
				"foot":hall_foot,"alpha":0.25,"route":"zhongyi_hall"})
	_entrance = Entrance.new()
	# 哨楼脚点在既有墙格上，不在院内凭空增加可穿行建筑。
	var gate_cell: Vector2i = Layout.gate_for(_map)
	var east_gate_cell: Vector2i = Layout.east_gate_for(_map)
	for cell in [gate_cell+Vector2i(-3,0),east_gate_cell+Vector2i(0,3)]:
		var p := _map.cell_to_world(cell)
		var tex := EnvironmentArt.object(level_id,"watchtower")
		var tower_metrics := EnvironmentArt.calibrated_visual_metrics("object",level_id,"watchtower")
		if tex==null or tower_metrics.is_empty(): tex=Art.terrain_texture("tower")
		var tower_size := 216.0 if not tower_metrics.is_empty() else 104.0
		var tower_foot := float(tower_metrics.get("foot",0.86))
		var tower := _add_sprite(tex,p,tower_size,tower_foot,false)
		tower.set_meta("campaign_environment_route","watchtower")
		tower.modulate = Color(0.88,0.86,0.75)
		_guard_posts.append(tower)
		_ground_shadows.append({"p":p,"tex":tex,"s":tower_size,"foot":tower_foot,"alpha":0.20})
	add_child(_entrance)
	_entrance.setup(_map)
	_build_ground_shadow_meshes()
	queue_redraw()


func _setup_coast_material() -> void:
	var surface_data: Dictionary = _map.natural_surface_maps()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/liangshan_coast.gdshader")
	mat.set_shader_parameter("land_mask", ImageTexture.create_from_image(surface_data.land))
	mat.set_shader_parameter("surface_weights", ImageTexture.create_from_image(surface_data.weights))
	mat.set_shader_parameter("map_size", Vector2(_map.w, _map.h))
	mat.set_shader_parameter("natural_surface_enabled", _map.natural_surface_enabled)
	mat.set_shader_parameter("natural_blend_min_px", float(surface_data.blend_min_px))
	mat.set_shader_parameter("natural_blend_max_px", float(surface_data.blend_max_px))
	mat.set_shader_parameter("natural_warp_px", float(surface_data.warp_px))
	mat.set_shader_parameter("natural_seed", float(int(surface_data.seed) % 4096))
	_map.set_meta("natural_surface_contract", {
		"enabled": _map.natural_surface_enabled,
		"class_counts": surface_data.class_counts,
		"protected_cells": surface_data.protected_cells,
		"weight_sha256": surface_data.weight_sha256,
		"land_sha256": surface_data.land_sha256,
		"blend_min_px": surface_data.blend_min_px,
		"blend_max_px": surface_data.blend_max_px,
		"warp_px": surface_data.warp_px,
		"seed": surface_data.seed,
	})
	if _map.height_field != null:
		mat.set_shader_parameter("height_enabled", true)
		mat.set_shader_parameter("height_map", _map.height_field.texture)
		mat.set_shader_parameter("elevation_scale", _map.height_field.MAX_HEIGHT)
	var water := Art.terrain_texture("water") as AtlasTexture
	var shore := Art.terrain_texture("shore") as AtlasTexture
	var grass := Art.terrain_texture("grass2") as AtlasTexture
	# 江州和大名府以铺砌广场作为硬质底材，其余关卡继续用土路底材。
	var hard_key := "plaza" if _map.environment_style in ["level2", "level8"] else "road"
	var hard := Art.terrain_texture(hard_key) as AtlasTexture
	var dry := Art.terrain_texture("dryhill") as AtlasTexture
	var field := Art.terrain_texture("field") as AtlasTexture
	var active_level_id := _active_campaign_level_id()
	var routed_surfaces := {
		"surface_forest_earth":["surface_forest_texture","use_surface_forest_texture"],
		"surface_dry_earth":["surface_dry_texture","use_surface_dry_texture"],
		"surface_wet_bank":["surface_wet_texture","use_surface_wet_texture"],
		"surface_compacted_stone":["surface_hard_texture","use_surface_hard_texture"],
		"surface_field":["surface_field_texture","use_surface_field_texture"],
	}
	var routed_surface_evidence := {}
	for surface_key in routed_surfaces:
		var binding: Array = routed_surfaces[surface_key]
		var routed: Texture2D = EnvironmentArt.surface(active_level_id,surface_key)
		var enabled := routed!=null
		mat.set_shader_parameter(binding[1],enabled)
		if enabled: mat.set_shader_parameter(binding[0],routed)
		routed_surface_evidence[surface_key]={"allowed_path":EnvironmentArt.surface_path(active_level_id,surface_key),"loaded":enabled,"sampling_mode":"map_clamped" if enabled else "atlas_tile_uv","repeat_enabled":false if enabled else true}
	var surface_contract: Dictionary = _map.get_meta("natural_surface_contract",{}).duplicate(true)
	surface_contract["campaign_level_id"]=active_level_id
	surface_contract["routed_surfaces"]=routed_surface_evidence
	_map.set_meta("natural_surface_contract",surface_contract)
	mat.set_shader_parameter("terrain_atlas", water.atlas)
	mat.set_shader_parameter("terrain_atlas2", dry.atlas)
	for pair in [["water_region", water], ["shore_region", shore],
		["grass_region", grass], ["road_region", hard]]:
		var region: Rect2 = pair[1].region
		var size: Vector2 = pair[1].atlas.get_size()
		mat.set_shader_parameter(pair[0], Vector4(region.position.x / size.x, region.position.y / size.y,
			region.size.x / size.x, region.size.y / size.y))
	for pair in [["dry_region", dry], ["field_region", field]]:
		var region: Rect2 = pair[1].region
		var size: Vector2 = pair[1].atlas.get_size()
		mat.set_shader_parameter(pair[0], Vector4(region.position.x / size.x, region.position.y / size.y,
			region.size.x / size.x, region.size.y / size.y))
	# 各关只调同一组现有地表贴图的综合色，不写回地图数据，也不改变高度。
	var terrain_tints: Array
	match _map.environment_style:
		"level1": # 黄泥冈：炎热黄土和枯草。
			terrain_tints = [Color(0.70,0.74,0.56),Color(0.92,0.84,0.66),Color(0.72,0.75,0.57),Color(0.90,0.82,0.66),Color(0.82,0.78,0.57)]
		"level2": # 江州：灰褐城地，江岸略湿。
			terrain_tints = [Color(0.68,0.70,0.60),Color(0.82,0.75,0.62),Color(0.66,0.72,0.62),Color(0.78,0.76,0.70),Color(0.72,0.71,0.56)]
		"level3": # 独龙冈：庄田、土路和寨墙。
			terrain_tints = [Color(0.66,0.74,0.56),Color(0.84,0.77,0.61),Color(0.68,0.73,0.58),Color(0.82,0.76,0.63),Color(0.78,0.79,0.51)]
		"level4": # 连环马伏地：芦苇、湿草和田埂。
			terrain_tints = [Color(0.62,0.72,0.55),Color(0.78,0.73,0.60),Color(0.63,0.72,0.57),Color(0.78,0.73,0.62),Color(0.73,0.76,0.52)]
		"level6": # 野猪林：暗绿林地和偏干的山道。
			terrain_tints = [Color(0.56,0.65,0.49),Color(0.78,0.70,0.55),Color(0.60,0.66,0.52),Color(0.75,0.68,0.56),Color(0.67,0.69,0.48)]
		"level7": # 快活林：城外土路和市口院地。
			terrain_tints = [Color(0.66,0.72,0.55),Color(0.84,0.75,0.59),Color(0.67,0.71,0.57),Color(0.83,0.76,0.63),Color(0.75,0.75,0.51)]
		"level8": # 大名府：夜色会在上层继续压暗，先保持砖土可辨。
			terrain_tints = [Color(0.67,0.69,0.61),Color(0.79,0.72,0.62),Color(0.63,0.68,0.61),Color(0.76,0.75,0.72),Color(0.70,0.70,0.57)]
		_: # 梁山：湿润草岸。
			terrain_tints = [Color(0.64,0.73,0.58),Color(0.80,0.77,0.64),Color(0.69,0.75,0.61),Color(0.82,0.78,0.67),Color(0.74,0.76,0.57)]
	for i in range(5):
		mat.set_shader_parameter(["grass_tint","dry_tint","wet_tint","hard_tint","field_tint"][i], terrain_tints[i])
	_map.material = mat


func _active_campaign_level_id() -> String:
	# 自由驻守复用梁山泊已验收的环境素材时，只覆盖美术路由；关卡ID、存档和玩法仍是skirmish。
	var liangshan_art_id := String(_map.get_meta("liangshan_art_level_id", ""))
	if not liangshan_art_id.is_empty(): return liangshan_art_id
	if not _map.environment_style.is_empty(): return _map.environment_style
	if _battle!=null and _battle.get("level")!=null and _battle.level!=null:
		return String(_battle.level.id())
	return ""


func _near_forest(x: int, y: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if _map.t_at(x + dx, y + dy) == GameMap.T.FOREST:
				return true
	return false


func _cache_reeds(x: int, y: int) -> void:
	# 短苇丛批量画在地面层，水道与士兵上半身始终可读；不用几百个逐帧节点。
	var rng := RandomNumberGenerator.new()
	rng.seed = 5088120+x*131+y*317
	var world_p := _map.cell_to_world(Vector2i(x,y))
	var p := _map.project(world_p)
	_reed_cells.append(world_p)
	# Keep the dense line mesh. Only four authored anchor clumps may add a routed
	# bitmap, so accepted art cannot turn hundreds of reed cells into Nodes.
	if _routed_reed_count<4:
		var routes := ["reeds_short","reeds_tall","reeds_bent","reeds_seeded"]
		var route_key: String = routes[_routed_reed_count]
		var routed := EnvironmentArt.object(_active_campaign_level_id(),route_key)
		var reed_metrics := EnvironmentArt.calibrated_visual_metrics("object",_active_campaign_level_id(),route_key)
		if routed!=null and not reed_metrics.is_empty():
			var reed_foot := float(reed_metrics.get("foot",0.90))
			var reed := _add_sprite(routed,world_p,70.0,reed_foot,false)
			reed.set_meta("campaign_environment_route",route_key)
			_ground_shadows.append({"p":world_p,"tex":routed,"s":70.0,"foot":reed_foot,"alpha":0.12})
		_routed_reed_count+=1
	for i in range(8):
		var foot := p+Vector2(rng.randf_range(-18,18),rng.randf_range(-7,7))
		var top := foot+Vector2(rng.randf_range(-5,5),-rng.randf_range(12,26))
		_reed_stems.append_array(PackedVector2Array([foot,top]))
		_reed_stem_anchors.append_array(PackedVector2Array([world_p,world_p]))
		var leaf := foot.lerp(top,0.52)
		_reed_leaves.append_array(PackedVector2Array([leaf,leaf+Vector2(-6,-5),leaf,leaf+Vector2(6,-6)]))
		_reed_leaf_anchors.append_array(PackedVector2Array([world_p,world_p,world_p,world_p]))
		if i%2==0:
			_reed_heads.append_array(PackedVector2Array([top,top+Vector2(1,-4)]))
			_reed_head_anchors.append_array(PackedVector2Array([world_p,world_p]))


func _build_reed_mesh() -> void:
	# 合为一个静态线网格。数千条抗锯齿Canvas线段会产生大量绘制开销。
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for group in [[_reed_stems,_reed_stem_anchors,Color(0.40,0.43,0.25,0.9)],
		[_reed_leaves,_reed_leaf_anchors,Color(0.39,0.46,0.26,0.8)],
		[_reed_heads,_reed_head_anchors,Color(0.58,0.53,0.36,0.9)]]:
		var points: PackedVector2Array = group[0]
		var anchors: PackedVector2Array = group[1]
		for i in range(points.size()):
			var p: Vector2 = points[i]
			var color: Color = group[2]
			if _fog_visibility_ready() and not _fog_anchor_revealed(anchors[i],28.0):
				color.a = 0.0
			vertices.append(Vector3(p.x,p.y,0))
			colors.append(color)
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	_reed_mesh = ArrayMesh.new()
	_reed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
	_reed_visibility_signature = _current_reed_visibility_signature()
	queue_redraw()


func _fog_visibility_ready() -> bool:
	return _battle != null and bool(_battle.fog) \
		and _battle._vision.size() == _map.w * _map.h


func _fog_anchor_revealed(anchor: Vector2, rise_px: float) -> bool:
	if not _fog_visibility_ready():
		return true
	if not _battle.is_explored_world(anchor):
		return false
	# 平面迷雾只能盖住脚点所在格；直立物件的树冠、门楼和旗尖会向屏幕
	# 上方伸出。把其视觉顶部反投影回世界，再要求该处也已探索。
	var top_probe := anchor + GameMap.ISO_INV.basis_xform(Vector2(0,-rise_px))
	return _battle.is_explored_world(top_probe)


func _fog_node_revealed(node: Node2D) -> bool:
	return _fog_anchor_revealed(node.position,float(node.get_meta("fog_clearance_px",64.0)))


func _current_reed_visibility_signature() -> int:
	if not _fog_visibility_ready():
		return -1
	var signature := 17
	for p in _reed_cells:
		signature = posmod(signature * 31 + (1 if _fog_anchor_revealed(p,28.0) else 0), 2147483629)
	return signature


func _refresh_fog_visibility() -> void:
	var fog_ready := _fog_visibility_ready()
	for sprite in _sprites:
		if is_instance_valid(sprite):
			sprite.visible = not fog_ready or _fog_node_revealed(sprite)
	if is_instance_valid(_entrance):
		for part in _entrance.get_children():
			if part is Node2D:
				part.visible = not fog_ready or _fog_node_revealed(part)
	var reed_signature := _current_reed_visibility_signature()
	if reed_signature != _reed_visibility_signature:
		_build_reed_mesh()


func fog_visibility_summary() -> Dictionary:
	var unexplored := 0
	var visible_unexplored := 0
	if _fog_visibility_ready():
		var nodes: Array = _sprites.duplicate()
		if is_instance_valid(_entrance):
			for part in _entrance.get_children():
				if part is Node2D:
					nodes.append(part)
		for node in nodes:
			if is_instance_valid(node) and not _fog_node_revealed(node):
				unexplored += 1
				if node.visible:
					visible_unexplored += 1
	return {"fog_ready": _fog_visibility_ready(), "unexplored_scenery": unexplored,
		"visible_unexplored_scenery": visible_unexplored,
		"reed_visibility_signature": _reed_visibility_signature}


func _shadow_texture_info(tex: Texture2D) -> Dictionary:
	# `draw_texture_rect()` applies an AtlasTexture's source region itself. Mesh
	# drawing receives the backing page instead, so retain the same region in UV.
	var atlas := tex as AtlasTexture
	if atlas != null and atlas.atlas != null:
		var size := atlas.atlas.get_size()
		if size.x > 0.0 and size.y > 0.0:
			# Canvas AtlasTexture clips at its source rectangle. A raw mesh with
			# linear filtering otherwise samples the neighbouring atlas tile along
			# a cast quad's outer edge, creating a visible diagonal seam. Half a
			# source texel reproduces the clipped edge without changing geometry.
			var inset := Vector2(0.5 / size.x, 0.5 / size.y)
			return {"texture": atlas.atlas,
				"uv": Rect2(atlas.region.position / size + inset, atlas.region.size / size - inset * 2.0)}
	return {"texture": tex, "uv": Rect2(Vector2.ZERO, Vector2.ONE)}


func _append_mesh_quad(vertices: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, indices: PackedInt32Array, transform: Transform2D,
		rect: Rect2, uv_rect: Rect2, color: Color) -> void:
	var first := vertices.size()
	for raw_point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]:
		var point: Vector2 = raw_point
		var transformed: Vector2 = transform * point
		vertices.append(Vector3(transformed.x, transformed.y, 0.0))
	uvs.append_array(PackedVector2Array([
		uv_rect.position, Vector2(uv_rect.end.x, uv_rect.position.y), uv_rect.end,
		Vector2(uv_rect.position.x, uv_rect.end.y),
	]))
	for _i in range(4):
		colors.append(color)
	indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))


func _append_contact_fans(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, anchor: Vector2, ground: Transform2D, size: float) -> void:
	var transform := Transform2D(0.0, anchor) * ground
	var color := Color(0.04, 0.08, 0.06, 0.21 * 0.25)
	for layer in range(WorldShadow.FULL_CONTACT_LAYERS):
		var radius := size * 0.19 * (1.20 - float(layer) * 0.16)
		var first := vertices.size()
		var center := transform * WorldShadow.CONTACT_OFFSET
		vertices.append(Vector3(center.x, center.y, 0.0))
		colors.append(color)
		for segment in range(STATIC_CONTACT_SEGMENTS):
			var angle := TAU * float(segment) / float(STATIC_CONTACT_SEGMENTS)
			var point := transform * (WorldShadow.CONTACT_OFFSET + Vector2(cos(angle), sin(angle)) * radius)
			vertices.append(Vector3(point.x, point.y, 0.0))
			colors.append(color)
		for segment in range(STATIC_CONTACT_SEGMENTS):
			indices.append_array(PackedInt32Array([first, first + 1 + segment,
				first + 1 + posmod(segment + 1, STATIC_CONTACT_SEGMENTS)]))


func _make_shadow_mesh(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, uvs := PackedVector2Array()) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_ground_shadow_meshes() -> void:
	_ground_shadow_contact_mesh = null
	_ground_shadow_cast_meshes.clear()
	var contact_vertices := PackedVector3Array()
	var contact_colors := PackedColorArray()
	var contact_indices := PackedInt32Array()
	var cast_groups: Dictionary = {}
	for raw in _ground_shadows:
		var shadow: Dictionary = raw
		var tex := shadow.tex as Texture2D
		if tex == null:
			continue
		var anchor: Vector2 = shadow.p - Vector2.ONE * _map.height_at(shadow.p)
		var ground: Transform2D = _map.ground_basis(shadow.p)
		var size: float = shadow.s
		_append_contact_fans(contact_vertices, contact_colors, contact_indices, anchor, ground, size)
		var info := _shadow_texture_info(tex)
		var texture: Texture2D = info.texture
		if texture == null:
			continue
		var key := texture.get_rid().get_id()
		if not cast_groups.has(key):
			cast_groups[key] = {"texture": texture, "quads": []}
		var rect := Rect2(-size * 0.5, -size * float(shadow.foot), size, size)
		var cast := Transform2D(Vector2(1.0, 0.0), WorldShadow.CAST_SHEAR, WorldShadow.CAST_OFFSET)
		cast_groups[key].quads.append({"transform": Transform2D(0.0, anchor) * ground * GameMap.ISO_INV * cast,
			"rect": rect, "uv": info.uv, "alpha": float(shadow.alpha)})
	_ground_shadow_contact_mesh = _make_shadow_mesh(contact_vertices, contact_colors, contact_indices)
	for group in cast_groups.values():
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for raw_quad in group.quads:
			var quad: Dictionary = raw_quad
			var alpha: float = quad.alpha
			_append_mesh_quad(vertices, uvs, colors, indices, quad.transform, (quad.rect as Rect2).grow(1.0),
				quad.uv, Color(0.03, 0.06, 0.04, alpha * 0.35))
			_append_mesh_quad(vertices, uvs, colors, indices, quad.transform, quad.rect, quad.uv,
				Color(0.03, 0.06, 0.04, alpha * 0.65))
		var mesh := _make_shadow_mesh(vertices, colors, indices, uvs)
		if mesh != null:
			_ground_shadow_cast_meshes.append({"mesh": mesh, "texture": group.texture, "anchors": group.quads.size()})


func _ensure_ground_shadow_meshes() -> void:
	# CampaignScenery overrides setup(), so build lazily from _draw after either
	# subclass has finished filling the inherited anchor list.
	if _ground_shadows.is_empty() or (_ground_shadow_contact_mesh != null and not _ground_shadow_cast_meshes.is_empty()):
		return
	_build_ground_shadow_meshes()


func shadow_batch_summary() -> Dictionary:
	var uses_batch := WorldShadow.scenery_batch_enabled() and _ground_shadow_contact_mesh != null \
		and not _ground_shadow_cast_meshes.is_empty()
	return {"anchors": _ground_shadows.size(), "uses_mesh_batch": uses_batch,
		"contact_mesh": _ground_shadow_contact_mesh != null,
		"cast_texture_groups": _ground_shadow_cast_meshes.size(),
		"draw_submissions": 1 + _ground_shadow_cast_meshes.size() if uses_batch else _ground_shadows.size() * 6,
		"route": "static_mesh" if uses_batch else "legacy_local_outline"}


func _draw_legacy_ground_shadows() -> void:
	for shadow in _ground_shadows:
		var p: Vector2 = shadow.p - Vector2.ONE * _map.height_at(shadow.p)
		var ground: Transform2D = _map.ground_basis(shadow.p)
		var s: float = shadow.s
		WorldShadow.draw_scenery_shadow(self, shadow.tex, p, s, float(shadow.foot), float(shadow.alpha), ground)


func _add_sprite(tex: Texture2D, p: Vector2, size: float, foot: float, tree: bool) -> ScenerySprite:
	var sprite := ScenerySprite.new()
	sprite.tex = tex
	sprite.size = size
	sprite.foot = foot
	sprite.is_tree = tree
	sprite.position = p
	sprite.set_meta("fog_clearance_px",maxf(24.0,size*maxf(0.35,foot-0.22)))
	sprite.z_as_relative = false
	sprite.z_index = clampi(1 + int(_map.project(p).y), 1, 3400)
	add_child(sprite)
	_sprites.append(sprite)
	_map.sync_render_position(sprite)
	return sprite


func _add_flag_overlay(marker: String, p: Vector2, size: float, foot: float, decor_key: String,
		level_id: String, normalized_rect: Array = [], text_only := false) -> void:
	var overlay := CampaignFlagOverlay.new()
	if not overlay.configure_static_marker(marker,size,foot,level_id,decor_key,
			normalized_rect,text_only):
		return
	overlay.position = p
	overlay.set_meta("fog_clearance_px",maxf(24.0,size*maxf(0.35,foot-0.22)))
	overlay.z_as_relative = false
	overlay.z_index = clampi(2 + int(_map.project(p).y), 1, 3400)
	add_child(overlay)
	_sprites.append(overlay)
	_map.sync_render_position(overlay)


func _cache_banks(x: int, y: int, terrain: int) -> void:
	if terrain in [GameMap.T.WATER, GameMap.T.ROAD, GameMap.T.DOCK]:
		return
	var origin := Vector2(x, y) * GameMap.CELL
	for side in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbour := _map.t_at(x + side.x, y + side.y)
		var coast := neighbour == GameMap.T.WATER
		var terrace := terrain in [GameMap.T.GRASS, GameMap.T.FOREST] \
			and neighbour in [GameMap.T.MARSH, GameMap.T.REEDS]
		if not coast and not terrace:
			continue
		var a := origin
		var b := origin
		if side == Vector2i(1, 0):
			a += Vector2(GameMap.CELL, 0)
			b += Vector2(GameMap.CELL, GameMap.CELL)
		elif side == Vector2i(0, 1):
			a += Vector2(0, GameMap.CELL)
			b += Vector2(GameMap.CELL, GameMap.CELL)
		elif side == Vector2i(-1, 0):
			b += Vector2(0, GameMap.CELL)
		else:
			b += Vector2(GameMap.CELL, 0)
		_banks.append({"a": _map.project(a), "b": _map.project(b),
			"front": side.x + side.y > 0, "coast": coast, "tone": (x * 17 + y * 31) % 4})


func _draw() -> void:
	if _map == null:
		return
	draw_set_transform_matrix(GameMap.ISO_INV)
	if _reed_mesh!=null:
		draw_mesh(_reed_mesh,null)
	for bank in _banks:
		var a: Vector2 = bank.a
		var b: Vector2 = bank.b
		var depth := 3.0 if bank.coast else 5.0
		if bank.front:
			# 不画等宽亮边，避免把自然坡岸画成一圈水泥路缘。
			var ridge := PackedVector2Array()
			var foot := PackedVector2Array()
			for i in range(6):
				var p := a.lerp(b, float(i) / 5.0)
				var wobble := sin(p.x * 0.47 + p.y * 0.21) * 1.1
				ridge.append(p + Vector2(0, wobble))
				foot.append(p + Vector2(0, depth + wobble + sin(p.x * 0.19) * 0.7))
			var polygon := ridge.duplicate()
			var colors := PackedColorArray()
			var top := Color(0.29, 0.29, 0.17, 0.68)
			var bottom := Color(0.12, 0.18, 0.12, 0.48)
			for i in range(ridge.size()):
				colors.append(top)
			for i in range(foot.size() - 1, -1, -1):
				polygon.append(foot[i])
				colors.append(bottom)
			draw_polygon(polygon, colors)
			draw_polyline(foot, Color(0.08, 0.13, 0.10, 0.22), 1.4, true)
			if bank.tone == 1:
				draw_line(ridge[1], ridge[3], Color(0.54, 0.53, 0.33, 0.25), 1.0, true)
		elif bank.coast:
			draw_line(a, b, Color(0.12, 0.20, 0.17, 0.35), 1.6, true)
		if bank.coast and bank.tone == 2:
			var offset := Vector2(0, depth + 4.0) if bank.front else Vector2(0, -3)
			draw_line(a.lerp(b, 0.20) + offset, a.lerp(b, 0.75) + offset, Color(0.50, 0.65, 0.59, 0.13), 1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if WorldShadow.scenery_batch_enabled():
		_ensure_ground_shadow_meshes()
		if _ground_shadow_contact_mesh != null and not _ground_shadow_cast_meshes.is_empty():
			draw_mesh(_ground_shadow_contact_mesh, null)
			for entry in _ground_shadow_cast_meshes:
				draw_mesh(entry.mesh, entry.texture)
		else:
			# A missing cached resource must never silently drop shadows. This branch
			# is also useful when an incomplete art database is opened in the editor.
			_draw_legacy_ground_shadows()
	else:
		_draw_legacy_ground_shadows()
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 不留完整不透明树冠盖住可通行林地里的士兵。仅作视觉避让。
func _process(delta: float) -> void:
	if _map.height_field != null:
		_sync_elevated_nodes()
	_visibility_tick += delta
	if _visibility_tick < 0.10 or _battle == null:
		return
	_visibility_tick = 0.0
	_refresh_fog_visibility()
	_refresh_canopy_visibility()


func _refresh_canopy_visibility() -> void:
	# Reuse one projection per eligible unit for this synchronous visibility pass.
	# Nothing is cached across ticks, so movement, fog and depth changes stay live.
	if _trees.is_empty() and _guard_posts.is_empty():
		return
	var bodies: Array[Rect2] = []
	var depths := PackedInt32Array()
	for unit in _battle.units:
		if not is_instance_valid(unit) or unit.hp <= 0 or unit.is_building or not unit.visible:
			continue
		bodies.append(Rect2(_map.project(unit.position) + Vector2(-12, -38), Vector2(24, 40)))
		depths.append(unit.z_index)
	for tree in _trees + _guard_posts:
		var fade := false
		var tree_screen := _map.project(tree.position)
		var canopy := Rect2(tree_screen + Vector2(-tree.size * 0.37, -tree.size * 0.87), Vector2(tree.size * 0.74, tree.size * 0.82))
		for i in range(bodies.size()):
			if depths[i] >= tree.z_index:
				continue
			if canopy.intersects(bodies[i]):
				fade = true
				break
		var alpha := 0.40 if fade else 1.0
		if not is_equal_approx(tree.modulate.a, alpha):
			tree.modulate.a = alpha


func _sync_elevated_nodes() -> void:
	for unit in _battle.units:
		if is_instance_valid(unit):
			_map.sync_render_position(unit)
	for sprite in _sprites:
		_map.sync_render_position(sprite)
	for part in _entrance._gate_parts:
		_map.sync_render_position(part)
	for part in _entrance._side_gate_parts:
		_map.sync_render_position(part)
	for part in _entrance._wall_parts:
		_map.sync_render_position(part)
	if is_instance_valid(_battle.fx_root):
		for effect in _battle.fx_root.get_children():
			if effect is Node2D:
				_map.sync_render_position(effect)


func draw_unit_shadow(unit: Node2D, death_f: float) -> void:
	# Compatibility entry point for older scenery callers. Unit now invokes the
	# shared renderer directly, so campaign scenery cannot add a second shadow.
	var tex: Texture2D
	if unit.is_building:
		tex = Art.building_texture(unit.key)
	elif unit.setup_def.has("campaign_object"):
		tex = Art.campaign_object_texture(String(unit.setup_def.campaign_object), String(unit.get_meta("ship_state", "default")), unit.animation_direction)
	else:
		tex = Art.unit_texture(unit.key, unit.art_variant, unit.animation_direction)
	if tex == null and unit.is_building:
		tex = Art.terrain_texture(unit.key)
	var directional := Art.campaign_object_uses_directional_source(String(unit.setup_def.campaign_object), String(unit.get_meta("ship_state", "default")), unit.animation_direction) if unit.setup_def.has("campaign_object") else Art.unit_anim_uses_directional_source(unit._anim_key(), "idle", unit.animation_direction, unit.art_variant)
	WorldShadow.draw_unit(unit, death_f, tex, directional)


static func _draw_contact(canvas: Node2D, radius: float, alpha: float) -> void:
	WorldShadow.draw_contact(canvas, radius, alpha)


static func _draw_cast(canvas: Node2D, tex: Texture2D, rect: Rect2, origin: Vector2, alpha: float, flip := false, ground := Transform2D.IDENTITY) -> void:
	WorldShadow.draw_cast(canvas, tex, rect, origin, alpha, flip, ground)


class ScenerySprite extends Node2D:
	var tex: Texture2D
	var size := 100.0
	var foot := 0.8
	var is_tree := false

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		draw_texture_rect(tex, Rect2(-size * 0.5, -size * foot, size, size), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
