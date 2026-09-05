extends "res://tools/zhujiazhuang_rts_test.gd"
## Exact resources, invalid-frame rejection, costume isolation and real orders.
## SJ_VISUAL=1 uses Vulkan and also saves an actual Unit pose matrix.
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const COUNTS := {"idle":1, "walk":2, "attack":3, "death":4}
var sj_out := "res://.godot/song_jiang_direction4/runtime"
var frame_rows: Array = []
var runtime_rows: Array = []

func _source(frame) -> String:
	return frame.atlas.resource_path if frame is AtlasTexture else frame.resource_path

func _sj_contracts() -> void:
	var art = root.get_node("Art")
	var ca = load("res://scripts/campaign_art.gd")
	for direction in DIRECTIONS:
		for state in COUNTS:
			var path := "res://assets/anim/song_jiang_%s_%s.tres" % [state,direction]
			var frames: Array = art.unit_anim_frames("song_jiang",state,direction)
			check(art._resolve_generic_directional_path("song_jiang",state,direction)==path,"exact SpriteFrames "+state+" "+direction)
			check(frames.size()==COUNTS[state],"frame count "+state+" "+direction)
			check(art.unit_anim_uses_directional_source("song_jiang",state,direction),"no mirror "+state+" "+direction)
			var sources: Array = []
			for frame in frames:
				check(frame is AtlasTexture and frame.get_width()==frame.get_height(),"square atlas frame "+state+" "+direction)
				check(_source(frame).begins_with("res://assets/characters/song_jiang_direction4_20260906/"),"consistent gold robe "+state+" "+direction)
				check(frame.has_meta("draw_offset_px"),"authored ground alignment "+state+" "+direction)
				sources.append(_source(frame))
			if state != "idle" and frames.size()>1:
				check(sources[0]!=sources[1],"authored action differs from idle "+state+" "+direction)
			if state=="death" and frames.size()==4:
				check(sources[1]!=sources[2] and sources[2]==sources[3],"collapse then held prone terminal "+direction)
			frame_rows.append({"state":state,"direction":direction,"sources":sources,"frames":frames.size()})
		check(art.unit_anim_frames("song_jiang","down",direction).is_empty(),"down cannot borrow death or idle "+direction)
		check(_source(art.unit_anim_frames("song_jiang","hurt",direction)[0]).contains("idle_"),"hurt retains costume via idle fallback "+direction)
		for variant in ["song_jiang_bound","song_jiang_rescued"]:
			var vf: Array = art.unit_anim_frames("song_jiang","idle",direction,variant)
			check(not vf.is_empty() and _source(vf[0])==ca.animation_path(variant,"idle",direction),"campaign costume priority "+variant+" "+direction)
		check(art._resolve_generic_directional_path("guan_dao","walk",direction).ends_with(".png"),"legacy PNG direction path retained "+direction)
	check(art.unit_anim_frames("song_jiang","idle","north").is_empty(),"invalid direction rejected")
	check(not art.unit_anim_uses_directional_source("song_jiang","idle","north"),"invalid direction cannot claim authored art")
	# Real ResourceSaver round trip exercises .tres decoding, not a mock loader.
	var scratch := sj_out+"/fixtures"
	DirAccess.make_dir_recursive_absolute(scratch)
	var sf := SpriteFrames.new()
	ResourceSaver.save(sf,scratch+"/empty.tres")
	check(art._load_generic_directional_frames(scratch+"/empty.tres").is_empty(),"empty SpriteFrames rejected")
	var nonsquare := AtlasTexture.new()
	nonsquare.atlas = load("res://assets/characters/song_jiang_direction4_20260906/idle_se.png")
	nonsquare.region = Rect2(0,0,10,20)
	sf.add_frame(&"default",nonsquare)
	ResourceSaver.save(sf,scratch+"/nonsquare.tres")
	check(art._load_generic_directional_frames(scratch+"/nonsquare.tres").is_empty(),"non-square SpriteFrames rejected")
	sf.clear(&"default")
	sf.add_frame(&"default",null)
	ResourceSaver.save(sf,scratch+"/null.tres")
	check(art._load_generic_directional_frames(scratch+"/null.tres").is_empty(),"null SpriteFrames rejected")
	ResourceSaver.save(Resource.new(),scratch+"/wrong_type.tres")
	check(art._load_generic_directional_frames(scratch+"/wrong_type.tres").is_empty(),"wrong resource type rejected")
	check(art._load_generic_directional_frames("").is_empty(),"empty source path rejected")

func _open_patch(b) -> Vector2i:
	for x in range(8,b.map.w-8):
		for y in range(8,b.map.h-8):
			var cell := Vector2i(x,y)
			var open := true
			for dx in range(-3,4):
				for dy in range(-3,4):
					if not b.map.is_open_world(b.map.cell_to_world(cell+Vector2i(dx,dy))): open=false
			if not open: continue
			var pos: Vector2 = b.map.cell_to_world(cell)
			if b.units.any(func(u): return is_instance_valid(u) and u.position.distance_to(pos)<180): continue
			return cell
	return Vector2i(-1,-1)

func _orders(b, visual: bool) -> void:
	var cell := _open_patch(b)
	check(cell.x>=0,"clear live movement patch exists")
	if cell.x<0: return
	for other in b.units: other.set_physics_process(false)
	var origin: Vector2 = b.map.cell_to_world(cell)
	var art = root.get_node("Art")
	var screen_vectors := [Vector2(96,48),Vector2(-96,48),Vector2(96,-48),Vector2(-96,-48)]
	var map_script = load("res://scripts/game_map.gd")
	for i in range(4):
		var d: String = DIRECTIONS[i]
		var u = b.spawn_unit("song_jiang",0,origin)
		u.auto_micro = false
		b.select_single(u,false)
		b.minimap_order(origin+map_script.ISO_INV*screen_vectors[i],false)
		await _wait(0.65)
		check(u.position.distance_to(origin)>4,"player move changes real position "+d)
		check(u.animation_direction==d,"move selects whole-body facing "+d)
		var selected_frame = u._anim_frame_for_state(art.unit_texture("song_jiang"))
		check(u._frame_directional and _source(selected_frame).contains("song_jiang_direction4_20260906"),"moving Unit uses new costume "+d)
		u.order_stop()
		var target = b.spawn_unit("guan_dao",1,u.position+map_script.ISO_INV*screen_vectors[i].normalized()*28)
		target.passive=true
		target.set_physics_process(false)
		var hp_before: float = target.hp
		u.order_attack(target,false,true)
		for tick in range(80):
			await _wait(0.05)
			if target.hp<hp_before and u._lunge>0: break
		check(target.hp<hp_before,"live melee order deals damage "+d)
		check(u.animation_direction==d,"attack locks correct facing "+d)
		u._anim_frame_for_state(art.unit_texture("song_jiang"))
		check(u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()),"authored strike avoids second whole-sprite swing "+d)
		if visual and i==0:
			b.fog=false
			b.camera.zoom=Vector2.ONE*2.7
			b.center_camera_cell(b.map.world_to_cell(u.position))
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(sj_out+"/live_melee.png")==OK,"live melee screenshot saved")
		var captured_dir: String = u.animation_direction
		u.take_damage(99999,null,false,true)
		check(u._dying and not b.units.has(u),"death removes combat actor and starts authored animation "+d)
		check(u.animation_direction==captured_dir,"death preserves facing "+d)
		runtime_rows.append({"direction":d,"damage":hp_before-target.hp,"death_direction":captured_dir})
		target.take_damage(99999,null,false,true)
		await _wait(1.5)
		check(not is_instance_valid(u),"death releases after terminal fade "+d)

func _label(parent, value: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text=value
	label.position=pos
	label.add_theme_font_size_override("font_size",19)
	parent.add_child(label)

func _matrix(b) -> void:
	b.phase=b.Phase.DEPLOY
	b.world.hide()
	b.hud.hide()
	var canvas := CanvasLayer.new()
	canvas.layer=100
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color=Color("29291f")
	background.size=Vector2(root.size)
	canvas.add_child(background)
	_label(canvas,"宋江 · 实际 Unit 绘制 · 四向姿态检查（固定帧夹具）",Vector2(24,12))
	var art_world := Node2D.new()
	art_world.transform=load("res://scripts/game_map.gd").ISO.scaled(Vector2.ONE*2.5)
	canvas.add_child(art_world)
	var labels := ["站立", "迈步", "出剑", "失衡跪倒", "倒地末帧"]
	for row in range(5):
		_label(canvas,labels[row],Vector2(30,150+row*155))
		for col in range(4):
			var ground := Vector2(300+col*280,205+row*155)
			if row==0: _label(canvas,DIRECTIONS[col].to_upper(),Vector2(ground.x-12,54))
			var u = b.spawn_unit("song_jiang",0,b.map.cell_to_world(Vector2i(18,36)))
			b.units.erase(u)
			u.reparent(art_world,false)
			u.position=art_world.transform.affine_inverse()*ground
			u.set_physics_process(false)
			u.set_process(false)
			u.animation_direction=DIRECTIONS[col]
			u.face_left=col in [1,3]
			u.display_name=""
			u.fog_visible=true
			u._move_blend=1.0 if row==1 else 0.0
			u._anim_t=PI*1.15 if row==1 else 0.0
			u._lunge=0.5 if row==2 else 0.0
			u._dying=row>=3
			if row>=3: u.hp=0
			u._death_t=u.DEATH_DUR*(0.32 if row==3 else 0.60)
			u.selected=row<3
			u.show()
			u.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(sj_out+"/unit_pose_matrix.png")==OK,"twenty actual Unit poses saved")
	canvas.queue_free()
	await process_frame
	b.world.show()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	if not OS.get_environment("SJ_QA_OUT").is_empty(): sj_out=OS.get_environment("SJ_QA_OUT")
	DirAccess.make_dir_recursive_absolute(sj_out)
	var visual := OS.get_environment("SJ_VISUAL")=="1"
	if visual:
		root.size=Vector2i(1440,1000)
		DisplayServer.window_set_size(root.size)
	await process_frame
	_sj_contracts()
	var b = await _start("skirmish",4)
	await _orders(b,visual)
	if visual: await _matrix(b)
	await _dispose(b)
	FileAccess.open(sj_out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frame_rows,"runtime":runtime_rows,"visual":visual},"\t")+"\n")
	print("[song-jiang-direction4] ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
