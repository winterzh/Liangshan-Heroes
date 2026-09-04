extends "res://scripts/liangshan_scenery.gd"
## 复用梁山的岸线、批量苇丛、地面阴影与树冠避让；布局来自各关配置。
const Config := preload("res://scripts/campaign_environment.gd")
const CampaignArt := preload("res://scripts/campaign_art.gd")
const Stockade := preload("res://scripts/liangshan_stockade.gd")
const CityWall := preload("res://scripts/campaign_city_wall.gd")
const Passage := preload("res://scripts/campaign_passage.gd")
var _walls: Array[Node2D] = []
var _style := ""
var _lantern_texture: GradientTexture2D
var _cuiyun_light: PointLight2D

func setup(game_map: GameMap) -> void:
	_map = game_map
	_battle = _map.get_parent().get_parent()
	_style = _map.environment_style
	if _style=="level8":
		var dusk := CanvasModulate.new()
		dusk.name="LanternNight"
		dusk.color=Color(0.62,0.67,0.79)
		add_child(dusk)
	name = "CampaignEnvironment"
	process_priority = 1000
	_setup_coast_material()
	if _style=="level8" and _map.material is ShaderMaterial:
		_map.material.set_shader_parameter("scene_tint",Color(0.72,0.77,0.87))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5088120+int(_style.trim_prefix("level"))*103
	for y in range(_map.h):
		for x in range(_map.w):
			var t := _map.t_at(x,y)
			var grove := t==GameMap.T.FOREST or (Config.dry_woods(_style) and t in [GameMap.T.CLIFF,GameMap.T.REEDS])
			var core := grove and (x*73+y*157+x*y*19)%31 < (3 if Config.dry_woods(_style) else 5)
			var edge := t==GameMap.T.GRASS and (x*31+y*13)%29==0 and _near_forest(x,y)
			if core or edge:
				var p := _map.cell_to_world(Vector2i(x,y))+Vector2(rng.randf_range(-7,7),rng.randf_range(-7,7))
				var tex := Art.object_texture("tree") if Config.dry_woods(_style) else Art.object_texture("tree1" if (x+y)%3!=0 else "tree2")
				var size := rng.randf_range(102,146) if core else rng.randf_range(62,95)
				var tree := _add_sprite(tex,p,size,0.90,true)
				tree.modulate = Color(0.81,0.87,0.72)
				_trees.append(tree)
				_ground_shadows.append({"p":p,"tex":tex,"s":size,"foot":0.90,"alpha":0.18})
			_cache_banks(x,y,t)
			if t==GameMap.T.REEDS and not Config.dry_woods(_style) and (x*17+y*31)%3!=0:
				_cache_reeds(x,y)
	_build_reed_mesh()
	for d in _map.decor:
		if d[0]==Config.SCOPED_OBJECT_MARKER:
			_add_campaign_environment_object(d)
			continue
		if d[0]==Config.SCOPED_OVERLAY_MARKER:
			_add_campaign_environment_overlay(d)
			continue
		if _style=="level8" and d[0]=="prison_gate": continue # The real passage draws this art in its actual open/closed state.
		if d[0]=="market_stall":
			var stall_kind := str(d[3]) if d.size()>3 else "wine"
			var stall_position := _map.cell_to_world(d[1])
			if not (_style=="level8" and stall_kind=="lantern" \
					and _add_direct_campaign_object(stall_position,d[2],"lantern_stall","",0.82,false,true)):
				_add_story_stall(stall_position,d[2],stall_kind)
			if _style=="level8": _add_lantern_light(d[1],0.55)
			continue
		if d[0]=="crowd":
			_add_story_crowd(_map.cell_to_world(d[1]),int(d[3]) if d.size()>3 else 0)
			continue
		if d[0]=="story_sign":
			_add_story_sign(_map.cell_to_world(d[1]),d[2],str(d[3]) if d.size()>3 else "")
			continue
		var tex := Art.campaign_object_texture(d[0])
		if tex==null: tex=Art.terrain_texture(d[0])
		if tex==null: tex=Art.object_texture(d[0])
		if tex==null: continue
		var p := _map.cell_to_world(d[1])
		var sprite := _add_sprite(tex,p,d[2],0.82,false)
		sprite.set_meta("campaign_object", d[0])
		# Non-Level5 campaigns use this derived scenery loop rather than the base
		# Liangshan loop. Preserve the same strict marker + level + decor-key gate;
		# arbitrary four-field decor records must never become lettered banners.
		if d.size()>3 and not CampaignArt.static_flag_route(String(d[3]),_style,String(d[0])).is_empty():
			sprite.set_meta("campaign_environment_static_flag",String(d[3]))
			_add_flag_overlay(String(d[3]),p,float(d[2]),0.82,String(d[0]),_style)
		if d[0] not in ["boat","dock","bridge","banner","rocks"]: _trees.append(sprite)
		if d[0] not in ["boat","dock","bridge"]:
			_ground_shadows.append({"p":p,"tex":tex,"s":d[2],"foot":0.82,"alpha":0.18})
	if _style=="level3":
		for segment in [[Vector2(20,14),Vector2(20,26)],[Vector2(20,30),Vector2(20,43)],
			[Vector2(18,9),Vector2(54,9)],[Vector2(18,47),Vector2(54,47)]]:
			_add_wall(segment[0],segment[1])
	if _style=="level8":
		for segment in [[Vector2(7,4),Vector2(52,4)],[Vector2(7,4),Vector2(7,39)],
			[Vector2(52,4),Vector2(52,39)],[Vector2(7,39),Vector2(28,39)],
			[Vector2(32,39),Vector2(32.5,39)],[Vector2(33.5,39),Vector2(52,39)]]:
			_add_wall(segment[0],segment[1])
		_add_passage(Vector2i(33,39),"偏门")
		for segment in [[Vector2(15,13),Vector2(21,13)],[Vector2(15,13),Vector2(15,20)],
			[Vector2(21,13),Vector2(21,20)],[Vector2(15,20),Vector2(18.5,20)],[Vector2(19.5,20),Vector2(21,20)]]:
			_add_wall(segment[0],segment[1],62.0)
		_add_passage(Vector2i(19,20),"牢门")
		_cuiyun_light=_add_lantern_light(Vector2i(37,15),0.45)
	queue_redraw()


func _legacy_environment_texture(key: String, state := "default") -> Texture2D:
	if key.is_empty(): return null
	var texture := Art.campaign_object_texture(key,state)
	if texture==null: texture=Art.terrain_texture(key)
	if texture==null: texture=Art.object_texture(key)
	return texture


func _add_direct_campaign_object(p: Vector2, size: float, route_key: String,
		fallback_key := "", foot := 0.82, tree := false, casts_shadow := true,
		state := "default") -> bool:
	var texture := EnvironmentArt.object(_style,route_key,state)
	if texture==null: texture=_legacy_environment_texture(fallback_key,state)
	if texture==null: return false
	var sprite := _add_sprite(texture,p,size,foot,tree)
	if tree: _trees.append(sprite)
	sprite.set_meta("campaign_environment_route",route_key)
	sprite.set_meta("campaign_environment_state",state)
	sprite.set_meta("campaign_environment_fallback_key",fallback_key)
	# Existing story transitions search this metadata; keep it scoped to the
	# manifest route instead of a new ArtDB key.
	sprite.set_meta("campaign_object",route_key)
	if casts_shadow:
		_ground_shadows.append({"p":p,"tex":texture,"s":size,"foot":foot,"alpha":0.18})
	return true


func _add_campaign_environment_object(d: Array) -> void:
	var p := _map.cell_to_world(d[1])
	var fallback_key := str(d[4]) if d.size()>4 else ""
	var foot := float(d[5]) if d.size()>5 else 0.82
	var tree := bool(d[6]) if d.size()>6 else false
	var casts_shadow := bool(d[7]) if d.size()>7 else true
	_add_direct_campaign_object(p,float(d[2]),str(d[3]),fallback_key,foot,tree,casts_shadow)


func _add_campaign_environment_overlay(d: Array) -> void:
	var texture := EnvironmentArt.overlay(_style,str(d[3]))
	if texture==null: return
	var overlay := CampaignGroundOverlay.new()
	overlay.tex=texture
	overlay.size=float(d[2])
	overlay.position=_map.cell_to_world(d[1])
	overlay.z_as_relative=false
	overlay.z_index=0
	overlay.set_meta("campaign_environment_route",str(d[3]))
	add_child(overlay)
	_sprites.append(overlay)
	_map.sync_render_position(overlay)

func _add_lantern_light(cell: Vector2i,energy: float) -> PointLight2D:
	if _lantern_texture==null:
		var gradient := Gradient.new()
		gradient.colors=PackedColorArray([Color.WHITE,Color(0,0,0,0)])
		_lantern_texture=GradientTexture2D.new()
		_lantern_texture.gradient=gradient
		_lantern_texture.width=128
		_lantern_texture.height=128
		_lantern_texture.fill=GradientTexture2D.FILL_RADIAL
		_lantern_texture.fill_from=Vector2(0.5,0.5)
		_lantern_texture.fill_to=Vector2(0.5,1.0)
	var lamp := PointLight2D.new()
	lamp.texture=_lantern_texture
	lamp.texture_scale=1.8
	lamp.color=Color(1.0,0.68,0.32)
	lamp.energy=energy
	lamp.shadow_enabled=false
	lamp.position=_map.cell_to_world(cell)
	add_child(lamp)
	return lamp

func _add_passage(cell: Vector2i,caption: String) -> void:
	var door := Passage.new()
	door.map=_map
	door.caption=caption
	if caption=="牢门": door.object_key="prison_gate"
	door.position=_map.cell_to_world(cell)
	door.z_as_relative=false
	door.z_index=clampi(int(_map.project(door.position).y),1,3400)
	add_child(door)
	_walls.append(door)
	_map.sync_render_position(door)

func _add_story_stall(p: Vector2,size: float,kind: String) -> void:
	var stall := StoryStall.new()
	stall.size=size
	stall.kind=kind
	stall.position=p
	stall.z_index=clampi(int(_map.project(p).y),1,3400)
	add_child(stall)
	_sprites.append(stall)

func _add_story_crowd(p: Vector2,variant: int) -> void:
	var crowd := StoryCrowd.new()
	crowd.variant=variant
	crowd.position=p
	crowd.z_index=clampi(int(_map.project(p).y),1,3400)
	add_child(crowd)
	_sprites.append(crowd)

func _add_story_sign(p: Vector2,size: float,label: String) -> void:
	var sign := StorySign.new()
	sign.size=size
	sign.label=label
	sign.position=p
	sign.z_index=clampi(int(_map.project(p).y),1,3400)
	add_child(sign)
	_sprites.append(sign)

func _add_wall(a: Vector2,z: Vector2,height_override := 0.0) -> void:
	var n := int(ceil(a.distance_to(z)/1.7))
	for i in range(n):
		var from: Vector2 = (a.lerp(z,float(i)/n)+Vector2(0.5,0.5))*32
		var to: Vector2 = (a.lerp(z,float(i+1)/n)+Vector2(0.5,0.5))*32
		var wall = CityWall.new() if _style=="level8" else Stockade.new()
		# 庄园是护庄寨栅，不把反复拉高的木墙画成断崖台地。
		# 城市使用砖土墙体，庄园复用木寨栅；与逻辑墙格一致。
		wall.height_scale = 78.0 if _style=="level3" else 108.0
		if height_override>0.0: wall.height_scale=height_override
		wall.position = from
		wall.end_local = _map.project(to)-_map.project(from)
		wall.z_as_relative = false
		wall.z_index = clampi(int((_map.project(from).y+_map.project(to).y)*0.5),1,3400)
		add_child(wall)
		_walls.append(wall)
		_map.sync_render_position(wall)

func _sync_elevated_nodes() -> void:
	for unit in _battle.units:
		if is_instance_valid(unit): _map.sync_render_position(unit)
	for sprite in _sprites+_walls: _map.sync_render_position(sprite)
	if is_instance_valid(_battle.fx_root):
		for effect in _battle.fx_root.get_children():
			if effect is Node2D: _map.sync_render_position(effect)

func _process(delta: float) -> void:
	super._process(delta)
	# 沿用父层每0.1秒的遮挡检查节拍；只让建筑本体变淡，血条/名字不消失。
	if _visibility_tick != 0.0: return
	for building in _battle.units:
		if not is_instance_valid(building) or not building.is_building or building.is_captive: continue
		var size: float = GameMap.building_visual_px(GameMap.footprint_half_for(building.radius))
		var roof := Rect2(_map.project(building.position)+Vector2(-size*0.4,-size*0.75),Vector2(size*0.8,size*0.72))
		var fade := false
		for unit in _battle.units:
			if not is_instance_valid(unit) or unit.hp<=0 or (unit.is_building and not unit.is_captive): continue
			if unit.z_index>building.z_index: continue
			if roof.intersects(Rect2(_map.project(unit.position)+Vector2(-12,-38),Vector2(24,40))): fade=true; break
		var alpha := 0.45 if fade else 1.0
		if building.get_meta("environment_roof_alpha",1.0)!=alpha:
			building.set_meta("environment_roof_alpha",alpha)
			building.queue_redraw()
	for wall in _walls:
		var fade := false
		for unit in _battle.units:
			if is_instance_valid(unit) and unit.hp>0 and not unit.is_building and wall.z_index>unit.z_index:
				if wall.body_overlaps(_map.project(unit.position)-_map.project(wall.position)):
					fade=true
		wall.modulate.a=0.45 if fade else 1.0

func draw_unit_shadow(unit: Node2D,death_f: float) -> void:
	if unit.is_bound_person():
		_draw_contact(unit,unit.radius*0.8,0.20)
		return
	super.draw_unit_shadow(unit,death_f)

func set_story_object_state(key: String, state: String) -> void:
	if key=="cuiyun_tower" and is_instance_valid(_cuiyun_light):
		_cuiyun_light.energy=1.15 if state=="signal" else 0.45
	for sprite in _sprites:
		if is_instance_valid(sprite) and sprite.get_meta("campaign_object","")==key:
			var route_key := str(sprite.get_meta("campaign_environment_route",key))
			var texture := EnvironmentArt.object(_style,route_key,state)
			var fallback_key := explicit_environment_fallback(sprite)
			if texture==null: texture=_legacy_environment_texture(fallback_key,state)
			if texture==null: continue
			sprite.tex=texture
			sprite.set_meta("campaign_environment_state",state)
			sprite.queue_redraw()


static func explicit_environment_fallback(sprite: Node) -> String:
	# Never infer a fallback from the story key. Only the level-scoped marker
	# that created this sprite may opt into an existing legacy asset.
	return String(sprite.get_meta("campaign_environment_fallback_key",""))

class StoryStall extends Node2D:
	var size := 64.0
	var kind := "wine"
	func _draw() -> void:
		# 素布棚、木案和酒坛：和军帐区别开，表示路边酒肆/市面摊位。
		draw_set_transform_matrix(GameMap.ISO_INV)
		var labels := {"wine":"酒","inn":"店","goods":"货","dice":"赌","money":"兑","lantern":"灯"}
		var colors := {"wine":Color("e6d7b1"),"inn":Color("c8aa7b"),"goods":Color("b98563"),"dice":Color("a9684e"),"money":Color("6f8790"),"lantern":Color("b55536")}
		var cloth: Color = colors.get(kind,Color("b98563"))
		var label: String = labels.get(kind,"市")
		var shade := Color("7a4e32")
		var s := size
		draw_line(Vector2(-s*0.34,0),Vector2(-s*0.34,-s*0.63),shade,3.0)
		draw_line(Vector2(s*0.34,0),Vector2(s*0.34,-s*0.63),shade,3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-s*0.43,-s*0.62),Vector2(s*0.43,-s*0.62),Vector2(s*0.31,-s*0.37),Vector2(-s*0.31,-s*0.37)]),cloth)
		draw_rect(Rect2(-s*0.30,-s*0.23,s*0.60,s*0.10),shade)
		if kind=="wine":
			for x in [-0.17,0.04,0.22]:
				draw_circle(Vector2(x*s,-s*0.13),s*0.075,Color("735038"))
		draw_rect(Rect2(-s*0.12,-s*0.73,s*0.24,s*0.18),Color("ede5d0"))
		draw_string(ThemeDB.fallback_font,Vector2(-8,-s*0.58),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("3b2920"))
		draw_set_transform_matrix(Transform2D.IDENTITY)

class StoryCrowd extends Node2D:
	const ART_VARIANTS := ["town_vendor", "town_porter", "town_woman", "town_elder"]
	const DIRECTIONS := ["se", "sw", "ne", "nw"]
	const SPRITE_SIZE := 50.0 # Alpha-cutout body height matches an ordinary soldier (~34 px).
	const SPRITE_ANCHOR := Vector2(0.5, 0.82)
	static var _contact_texture: GradientTexture2D
	var variant := 0
	var _idle_texture: Texture2D
	var _direction_override := ""

	func art_variant_key() -> String:
		return ART_VARIANTS[posmod(variant, ART_VARIANTS.size())]

	func idle_direction() -> String:
		if not _direction_override.is_empty(): return _direction_override
		return DIRECTIONS[posmod(floori(float(variant) / ART_VARIANTS.size()), DIRECTIONS.size())]

	func _ready() -> void:
		var scenery = get_parent()
		if scenery.has_method("_add_story_crowd") and scenery._style == "level2":
			# Jiangzhou spectators look toward the scaffold; no combat RNG is consumed.
			var toward: Vector2 = GameMap.ISO * (scenery._map.cell_to_world(Vector2i(30, 18)) - position)
			_direction_override = ("se" if toward.x >= 0.0 else "sw") if toward.y >= 0.0 else ("ne" if toward.x >= 0.0 else "nw")
		# Static scenery: resolve a real direction once, never a mirrored unit fallback.
		if Art.campaign_variant_has_direction(art_variant_key(), idle_direction()):
			var frames: Array = Art.unit_anim_frames("", "idle", idle_direction(), art_variant_key())
			if not frames.is_empty(): _idle_texture = frames[0]
		if _contact_texture == null:
			var gradient := Gradient.new()
			gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
			gradient.colors = PackedColorArray([Color(0.025, 0.04, 0.025, 0.22), Color(0.025, 0.04, 0.025, 0.14), Color(0.025, 0.04, 0.025, 0.0)])
			_contact_texture = GradientTexture2D.new()
			_contact_texture.gradient = gradient
			_contact_texture.width = 64
			_contact_texture.height = 32
			_contact_texture.fill = GradientTexture2D.FILL_RADIAL
			_contact_texture.fill_from = Vector2(0.5, 0.5)
			_contact_texture.fill_to = Vector2(1.0, 0.5)

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		# One soft contact shadow. Texture alpha is blended directly, without chroma key.
		if _contact_texture != null:
			draw_texture_rect(_contact_texture, Rect2(-10, -3, 20, 8), false)
		if _idle_texture != null:
			draw_texture_rect(_idle_texture, Rect2(-SPRITE_ANCHOR * SPRITE_SIZE, Vector2.ONE * SPRITE_SIZE), false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
		# Preserve the former geometric person when art is absent; put its soles at origin.
		draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(0.0, Vector2(0, -9)))
		var cloths := [Color("53677a"),Color("71584a"),Color("687152"),Color("7a4d43")]
		var cloth: Color = cloths[posmod(variant,cloths.size())]
		draw_circle(Vector2(0,-15),3.3,Color("c99971"))
		draw_colored_polygon(PackedVector2Array([Vector2(-5,-10),Vector2(5,-10),Vector2(6,4),Vector2(-6,4)]),cloth)
		draw_line(Vector2(-2,4),Vector2(-3,9),Color("3c3027"),1.8)
		draw_line(Vector2(2,4),Vector2(3,9),Color("3c3027"),1.8)
		draw_set_transform_matrix(Transform2D.IDENTITY)

class StorySign extends Node2D:
	var size := 72.0
	var label := ""
	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var w := maxf(size,54.0)
		draw_line(Vector2(0,4),Vector2(0,-w*0.72),Color("4f3624"),3.2)
		var board := Rect2(-w*0.44,-w*0.70,w*0.88,23.0)
		draw_rect(board,Color("4a2f20"))
		draw_rect(board,Color("c5a364"),false,1.8)
		draw_string(ThemeDB.fallback_font,Vector2(board.position.x,-w*0.53),label,HORIZONTAL_ALIGNMENT_CENTER,board.size.x,14,Color("f4e3b1"))
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Overlay sources are authored fully top-down. Unlike upright scenery this
## draw does not cancel the world's isometric transform; the source therefore
## lies on the terrain plane and never receives an invented foot anchor.
class CampaignGroundOverlay extends Node2D:
	var tex: Texture2D
	var size := 64.0
	func _draw() -> void:
		if tex!=null:
			draw_texture_rect(tex,Rect2(Vector2.ONE*-size*0.5,Vector2.ONE*size),false)
