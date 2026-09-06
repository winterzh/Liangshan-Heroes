extends "res://tools/zhujiazhuang_rts_test.gd"
## Exact resources, invalid-frame rejection, costume isolation and real orders.
## LC_VISUAL=1 uses Vulkan and also saves an actual Unit pose matrix.
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const COUNTS := {"idle":1, "walk":4, "attack":5, "hurt":1, "death":4}
var lc_out := "res://.godot/lin_chong_direction4/runtime"
var frame_rows: Array = []
var runtime_rows: Array = []

func _source(frame) -> String:
	return frame.atlas.resource_path if frame is AtlasTexture else frame.resource_path

func _pose_id(frame) -> String:
	return _source(frame)+str(frame.region) if frame is AtlasTexture else _source(frame)

func _lc_contracts() -> void:
	var art = root.get_node("Art")
	var ca = load("res://scripts/campaign_art.gd")
	for direction in DIRECTIONS:
		for state in COUNTS:
			var path := "res://assets/anim/lin_chong_%s_%s.tres" % [state,direction]
			var frames: Array = art.unit_anim_frames("lin_chong",state,direction)
			check(art._resolve_generic_directional_path("lin_chong",state,direction)==path,"exact SpriteFrames "+state+" "+direction)
			check(frames.size()==COUNTS[state],"frame count "+state+" "+direction)
			check(art.unit_anim_uses_directional_source("lin_chong",state,direction),"no mirror "+state+" "+direction)
			var sources: Array = []
			for frame in frames:
				check(frame is AtlasTexture and frame.get_width()==frame.get_height(),"square atlas frame "+state+" "+direction)
				check(_source(frame).begins_with("res://assets/characters/lin_chong_direction4_20260906/"),"consistent dark spear armor "+state+" "+direction)
				check(frame.has_meta("draw_offset_px"),"authored ground alignment "+state+" "+direction)
				sources.append(_pose_id(frame))
			if state=="walk" and frames.size()==4:
				check(sources[0]==sources[2] and sources[1]!=sources[3] and sources[0]!=sources[1],"distinct alternate steps around the neutral pose "+direction)
			if state=="attack" and frames.size()==5:
				check(sources[0]==sources[1] and sources[2]==sources[3] and sources[0]!=sources[2] and sources[2]!=sources[4],"windup then thrust aligned with spear damage phase "+direction)
			if state=="death" and frames.size()==4:
				check(sources[1]!=sources[2] and sources[2]==sources[3],"collapse then held prone terminal "+direction)
			frame_rows.append({"state":state,"direction":direction,"sources":sources,"frames":frames.size()})
		check(art.unit_anim_frames("lin_chong","down",direction).is_empty(),"down cannot borrow death or idle "+direction)
		check(_pose_id(art.unit_anim_frames("lin_chong","hurt",direction)[0])!=_pose_id(art.unit_anim_frames("lin_chong","idle",direction)[0]),"hurt uses an independent recoiling pose "+direction)
		for variant in ["lin_chong_bound","lin_chong_prisoner","lin_chong_escort"]:
			var vf: Array = art.unit_anim_frames("lin_chong","idle",direction,variant)
			check(not vf.is_empty() and _source(vf[0])==ca.animation_path(variant,"idle",direction),"campaign costume priority "+variant+" "+direction)
			check(art.unit_anim_frames("lin_chong","death",direction,variant).is_empty(),"new armored death cannot replace campaign costume "+variant+" "+direction)
			check(not art.unit_anim_uses_directional_source("lin_chong","death",direction,variant),"campaign missing death retains procedural direction "+variant+" "+direction)
		check(art._resolve_generic_directional_path("guan_dao","walk",direction).ends_with(".png"),"legacy PNG direction path retained "+direction)
	check(art.unit_anim_frames("lin_chong","idle","north").is_empty(),"invalid direction rejected")
	check(not art.unit_anim_uses_directional_source("lin_chong","idle","north"),"invalid direction cannot claim authored art")
	# Real ResourceSaver round trip exercises .tres decoding, not a mock loader.
	var scratch := lc_out+"/fixtures"
	DirAccess.make_dir_recursive_absolute(scratch)
	var sf := SpriteFrames.new()
	ResourceSaver.save(sf,scratch+"/empty.tres")
	check(art._load_generic_directional_frames(scratch+"/empty.tres").is_empty(),"empty SpriteFrames rejected")
	var nonsquare := AtlasTexture.new()
	nonsquare.atlas = load("res://assets/characters/lin_chong_direction4_20260906/se.png")
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
		var u = b.spawn_unit("lin_chong",0,origin)
		u.auto_micro = false
		b.select_single(u,false)
		b.minimap_order(origin+map_script.ISO_INV*screen_vectors[i],false)
		await _wait(0.65)
		check(u.position.distance_to(origin)>4,"player move changes real position "+d)
		check(u.animation_direction==d,"move selects whole-body facing "+d)
		var selected_frame = u._anim_frame_for_state(art.unit_texture("lin_chong"))
		check(u._frame_directional and _source(selected_frame).contains("lin_chong_direction4_20260906"),"moving Unit uses new costume "+d)
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
		u._anim_frame_for_state(art.unit_texture("lin_chong"))
		check(u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()),"authored strike avoids second whole-sprite swing "+d)
		if visual and i==0:
			b.fog=false
			b.camera.zoom=Vector2.ONE*2.7
			b.center_camera_cell(b.map.world_to_cell(u.position))
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(lc_out+"/live_melee.png")==OK,"live melee screenshot saved")
		var attacks: Array=art.unit_anim_frames("lin_chong","attack",d)
		check(_pose_id(u._anim_frame_for_state(art.unit_texture("lin_chong")))==_pose_id(attacks[2]),"actual damage occurs during authored thrust "+d)
		u.take_damage(7,target,false,true)
		var hurt_frame=u._anim_frame_for_state(art.unit_texture("lin_chong"))
		check(_pose_id(hurt_frame)==_pose_id(art.unit_anim_frames("lin_chong","hurt",d)[0]),"real incoming hit selects recoil frame "+d)
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
	_label(canvas,"林冲 · 实际 Unit 绘制 · 四向姿态检查（固定帧夹具）",Vector2(24,12))
	var art_world := Node2D.new()
	art_world.transform=load("res://scripts/game_map.gd").ISO.scaled(Vector2.ONE*2.3)
	canvas.add_child(art_world)
	var labels := ["站立", "迈步 A", "迈步 B", "收枪", "刺枪", "受击", "失衡跪倒", "倒地末帧"]
	for row in range(8):
		_label(canvas,labels[row],Vector2(30,110+row*145))
		for col in range(4):
			var ground := Vector2(300+col*280,165+row*145)
			if row==0: _label(canvas,DIRECTIONS[col].to_upper(),Vector2(ground.x-12,54))
			var u = b.spawn_unit("lin_chong",0,b.map.cell_to_world(Vector2i(18,36)))
			b.units.erase(u)
			u.reparent(art_world,false)
			u.position=art_world.transform.affine_inverse()*ground
			u.set_physics_process(false)
			u.set_process(false)
			u.animation_direction=DIRECTIONS[col]
			u.face_left=col in [1,3]
			u.display_name=""
			u.fog_visible=true
			u._move_blend=1.0 if row in [1,2] else 0.0
			u._anim_t=TAU*(0.30 if row==1 else 0.80) if row in [1,2] else 0.0
			u._lunge=(0.9 if row==3 else 0.45) if row in [3,4] else 0.0
			u._flinch=Vector2(2,0) if row==5 else Vector2.ZERO
			u._dying=row>=6
			if row>=6: u.hp=0
			u._death_t=u.DEATH_DUR*(0.32 if row==6 else 0.60)
			u.selected=row<6
			u.show()
			u.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(lc_out+"/unit_pose_matrix.png")==OK,"thirty-two actual Unit poses saved")
	canvas.queue_free()
	await process_frame
	b.world.show()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	if not OS.get_environment("LC_QA_OUT").is_empty(): lc_out=OS.get_environment("LC_QA_OUT")
	DirAccess.make_dir_recursive_absolute(lc_out)
	var visual := OS.get_environment("LC_VISUAL")=="1"
	if visual:
		root.size=Vector2i(1440,1300)
		root.content_scale_size=root.size
		DisplayServer.window_set_size(root.size)
	await process_frame
	_lc_contracts()
	if not failures.is_empty():
		FileAccess.open(lc_out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frame_rows,"runtime":runtime_rows,"visual":visual},"\t")+"\n")
		print("[lin-chong-direction4] resource contracts failed before gameplay: ",failures)
		quit(1)
		return
	var b = await _start("skirmish",4)
	await _orders(b,visual)
	if visual: await _matrix(b)
	await _dispose(b)
	FileAccess.open(lc_out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frame_rows,"runtime":runtime_rows,"visual":visual},"\t")+"\n")
	print("[lin-chong-direction4] ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
