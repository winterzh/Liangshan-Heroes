extends Node

const Adapter = preload("res://unit_candidate_adapter_v4.gd")
const DIRECTIONS = ["se", "sw", "ne", "nw"]
const VECTORS = [Vector2.RIGHT, Vector2.DOWN, Vector2.UP, Vector2.LEFT]
var units: Array = []
var worlds: Array = []
var samples: Array = []
var seen: Dictionary = {}

class Labels extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,880,620), Color("25312d"))
		draw_string(ThemeDB.fallback_font, Vector2(18,24), "Shi Qian | Actual Unit orders/physics/draw | detached grass fixture", HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(18,48), "No production routing, Battle collision, mission, reward or campaign qualification", HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		for column in range(4):
			for row in range(2):
				var target := Vector2(110+column*220,200+row*340)
				draw_line(target-Vector2(88,0), target+Vector2(88,0), Color("627467"),1)
				draw_line(target-Vector2(0,4),target+Vector2(0,4),Color("9bc985"),1)
				draw_string(ThemeDB.fallback_font,target+Vector2(-70,30), ["SE","SW","NE","NW"][column]+(" | 1x world" if row==0 else " | 4x world"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)

func _ready() -> void: call_deferred("_run")

func _camera() -> void:
	for i in range(units.size()):
		var u: Unit = units[i]
		var world: Node2D = worlds[i]
		var zoom := 1.0 if i < 4 else 4.0
		world.transform = GameMap.ISO.scaled(Vector2.ONE*zoom)
		world.position = Vector2(110+(i%4)*220,200+(i/4)*340) - (GameMap.ISO*u.position)*zoom

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(880,620)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(Labels.new())
	var map := GameMap.new()
	map.init_map(60,60,"candidate_fixture",GameMap.T.GRASS)
	map.bake()
	map.visible = false
	vp.add_child(map)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://unit_candidate.json"))
	for i in range(8):
		var world := Node2D.new()
		vp.add_child(world)
		var u = Adapter.new()
		u.setup("shi_qian",{"name":"Shi Qian candidate","hp":110,"atk":0,"speed":82,"hero":false,"noncombat":true,"slots":0},Unit.FACTION_LIANG,null,map)
		u.passive = true
		u.stance = Unit.STANCE_PASSIVE
		u.position = Vector2(900,900)
		u.animation_direction = DIRECTIONS[i%4]
		u.load_candidate(String(config.character))
		world.add_child(u)
		units.append(u)
		worlds.append(world)
	_camera()
	var saved := true
	for frame in range(80):
		if frame in [6,36,54]:
			for i in range(units.size()):
				var u: Unit = units[i]
				var delta: Vector2 = VECTORS[i%4] * (1.0 if frame != 54 else -1.0)
				u.order_move(u.position + delta*300)
		if frame in [29,70]:
			for u in units: u.order_stop()
		await get_tree().create_timer(0.08).timeout
		_camera()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := "unit_live_%03d.png" % frame
		saved = saved and vp.get_texture().get_image().save_png("res://"+capture) == OK
		var rows: Array = []
		for i in range(units.size()):
			var u = units[i]
			var state: String = u.sampled_state
			var direction: String = u.animation_direction
			var index: int = u.sampled_index
			seen[state+"_"+direction+"_"+str(index)] = true
			rows.append({"unit":i,"position":[u.position.x,u.position.y],"state":state,"direction":direction,"index":index,"move_blend":u._move_blend,"phase":u._anim_t,"key":u.key,"hp":u.hp,"max_hp":u.max_hp,"atk":u.atk,"base_speed":u.base_speed,"hero":u.is_hero,"noncombat":u.is_noncombat,"slots":u.setup_def.get("slots",-1),"real_frames":u._real_frames,"directional":u._frame_directional})
		samples.append({"frame":frame,"capture":capture,"units":rows})
	var checks: Array = []
	for direction in DIRECTIONS:
		checks.append({"check":"idle_"+direction,"passed":seen.has("idle_"+direction+"_0")})
		for index in range(4):
			checks.append({"check":"walk_"+direction+"_"+str(index),"passed":seen.has("walk_"+direction+"_"+str(index))})
	for i in range(8):
		var initial: Array = samples[5].units[i].position
		var moved: Array = samples[28].units[i].position
		checks.append({"check":"physical_move_"+str(i),"passed":Vector2(initial[0],initial[1]).distance_to(Vector2(moved[0],moved[1]))>50.0})
		checks.append({"check":"stop_idle_"+str(i),"passed":samples[35].units[i].move_blend<0.01 and samples[35].units[i].state=="idle"})
		checks.append({"check":"reverse_"+str(i),"passed":samples[69].units[i].direction!=DIRECTIONS[i%4]})
	for i in range(8):
		var u: Unit = units[i]
		checks.append({"check":"wounded_identity_"+str(i),"passed":u.key=="shi_qian" and u.hp==110.0 and u.max_hp==110.0 and u.atk==0.0 and u.base_speed==82.0 and not u.is_hero and u.is_noncombat and int(u.setup_def.get("slots",-1))==0 and u.ability.is_empty()})
	var passed := saved
	for check in checks: passed = passed and check.passed
	for sample in samples:
		for row in sample.units: passed = passed and row.real_frames and row.directional
	var f := FileAccess.open("res://unit_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":passed,"checks":checks,"samples":samples,"seen":seen.keys(),"scope":"Actual Unit inherited orders, movement, direction, phase and drawing with fixture-only frame resolver. Detached grass map, null Battle, no production/campaign qualification."},"  "))
	get_tree().quit(0 if passed else 1)
