extends Node
const Actor = preload("res://ordinary_gait_comparison_actor_v5.gd")
const DIRS := ["se","sw","ne","nw"]
const VECTORS := [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]
var units: Array = []
var worlds: Array = []
var samples: Array = []
var checks: Array = []
var selected_key := ""

class Labels extends Node2D:
	var character := ""
	func _draw() -> void:
		draw_rect(Rect2(0,0,1040,1420),Color("25312d"))
		draw_string(ThemeDB.fallback_font,Vector2(18,24),character+" | baseline ordinary art versus candidate upright idle/four-phase walk",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(18,50),"Detached diagnostic. Original ordinary stats/skills, inherited orders/physics/draw. Not original Battle or production acceptance.",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		for row in range(4):
			var foot: int = [220,450,900,1350][row]
			for column in range(4):
				var at := Vector2(130+column*260,foot)
				draw_line(at-Vector2(110,0),at+Vector2(110,0),Color("627467"),1)
				draw_line(at-Vector2(0,4),at+Vector2(0,4),Color("9bc985"),1)
				draw_string(ThemeDB.fallback_font,at+Vector2(-110,27),["se","sw","ne","nw"][column]+(" | candidate" if row%2==1 else " | baseline")+(" | 1x" if row<2 else " | 4x"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)

func _ready() -> void:_run.call_deferred()

func _camera() -> void:
	for i in range(units.size()):
		var row: int = i/4
		var zoom := 1.0 if row<2 else 4.0
		worlds[i].transform=GameMap.ISO.scaled(Vector2.ONE*zoom)
		worlds[i].position=Vector2(130+(i%4)*260,[220,450,900,1350][row])-(GameMap.ISO*units[i].position)*zoom

func _pose(frame: Texture2D) -> Dictionary:
	if frame==null:return {"present":false}
	if frame is AtlasTexture:
		return {"present":true,"source":frame.atlas.resource_path,"region":[frame.region.position.x,frame.region.position.y,frame.region.size.x,frame.region.size.y],"draw_scale":frame.get_meta("draw_scale",1.0),"directional":frame.get_meta("authored_direction4",false)}
	return {"present":true,"source":frame.resource_path}

func _run() -> void:
	var profile := OS.get_environment("ORDINARY_GAIT_QA_PROFILE").replace("\\","/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe=safe and OS.get_environment(key).replace("\\","/").simplify_path().to_lower()==(profile+"/"+key.to_lower()).to_lower()
	safe=safe and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile.to_lower()+"/appdata/") and OS.get_environment("STEAM_DISABLED")=="1" and OS.get_environment("CAMPAIGN_QA")=="1"
	if not safe:print("ORDINARY_GAIT_QA PRIVATE_PROFILE_REQUIRED");get_tree().quit(2);return
	assert(Engine.time_scale==1.0)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ordinary_gait_comparison.json"))
	selected_key=config.key
	assert(selected_key in ["wu_song","lin_chong"])
	var vp := SubViewport.new();vp.size=Vector2i(1040,1420);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp)
	var labels := Labels.new();labels.character=selected_key;vp.add_child(labels)
	var map := GameMap.new();map.init_map(60,60,"ordinary_idle_diagnostic",GameMap.T.GRASS);map.bake();map.visible=false;vp.add_child(map)
	for i in range(16):
		var world := Node2D.new();vp.add_child(world)
		var u = Actor.new()
		u.setup(selected_key,Defs.UNITS[selected_key].duplicate(true),Unit.FACTION_LIANG,null,map)
		u.passive=true;u.auto_micro=false;u.stance=Unit.STANCE_PASSIVE
		u.position=Vector2(900,900);u.animation_direction=DIRS[i%4]
		u.use_candidate_family=(i/4)%2==1
		u.load_gait_family(config.family)
		world.add_child(u);units.append(u);worlds.append(world)
	_camera()
	var saved := true
	for frame in range(80):
		if frame in [6,36,54]:
			for i in range(units.size()):units[i].order_move(units[i].position+VECTORS[i%4]*(300.0 if frame!=54 else -300.0))
		if frame in [29,70]:
			for u in units:u.order_stop()
		await get_tree().create_timer(0.08).timeout
		_camera();await get_tree().process_frame;await RenderingServer.frame_post_draw
		var capture := "ordinary_gait_live_%03d.png" % frame
		saved=saved and vp.get_texture().get_image().save_png("res://"+capture)==OK
		var rows := []
		for i in range(units.size()):
			var u = units[i]
			rows.append({"unit":i,"candidate":u.use_candidate_family,"native_family_applied":u.sampled_candidate_family,
				"key":u.key,"hp":u.hp,"max_hp":u.max_hp,"speed":u.base_speed,"attack":u.atk,"hero":u.is_hero,"noncombat":u.is_noncombat,"slots":u.ability_slots.size(),
				"position":[u.position.x,u.position.y],"state":u.sampled_state,"direction":u.animation_direction,"move_blend":u._move_blend,"phase":u._anim_t,"frame_index":u.sampled_frame_index,
				"frame":_pose(u.sampled_frame),"real_frames":u._real_frames,"directional":u._frame_directional})
		samples.append({"frame":frame,"capture":capture,"units":rows})
	for i in range(units.size()):
		var u = units[i]
		checks.append({"check":"ordinary_identity_"+str(i),"passed":u.key==selected_key and u.is_hero and not u.is_noncombat and u.ability_slots.size()==4 and u.hp>0 and u.art_variant.is_empty()})
		var initial: Array = samples[5].units[i].position
		var moved: Array = samples[28].units[i].position
		checks.append({"check":"inherited_move_"+str(i),"passed":Vector2(initial[0],initial[1]).distance_to(Vector2(moved[0],moved[1]))>50})
		checks.append({"check":"stop_idle_"+str(i),"passed":samples[35].units[i].move_blend<0.01 and samples[35].units[i].state=="idle"})
		checks.append({"check":"reverse_"+str(i),"passed":samples[69].units[i].direction!=DIRS[i%4]})
		if u.use_candidate_family:
			checks.append({"check":"native_candidate_idle_"+str(i),"passed":samples[5].units[i].native_family_applied and samples[35].units[i].native_family_applied and samples[5].units[i].directional})
			checks.append({"check":"native_candidate_walk_"+str(i),"passed":samples.any(func(s):return s.units[i].state=="walk" and s.units[i].native_family_applied)})
	var seen: Dictionary = {}
	for sample in samples:
		for row in sample.units:
			if row.candidate and row.native_family_applied and row.state=="walk":
				seen[row.direction+"_"+str(row.frame_index)]=true
	for d in DIRS:
		for phase in range(4):
			checks.append({"check":"four_authored_walk_phases_"+d+"_"+str(phase),"passed":seen.has(d+"_"+str(phase))})
	var passed := saved and checks.all(func(c):return c.passed)
	for sample in samples:
		for row in sample.units:passed=passed and row.frame.present
	var f := FileAccess.open("res://ordinary_gait_motion_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":passed,"checks":checks,"samples":samples,"key":selected_key,"engine_time_scale":Engine.time_scale,"seen":seen,"scope":"Detached ordinary hero definitions/skills and actual inherited Unit physics/draw. Candidate upright idle and four-phase walk substitution only; ordinary combat remains production Art. Visual diagnostic, not production routing/Battle/collision/combat/UI/save/platform qualification."},"\t"));f.close()
	get_tree().quit(0 if passed else 1)
