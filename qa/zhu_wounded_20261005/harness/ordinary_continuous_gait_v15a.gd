extends "res://tools/art_character_direction4_qa.gd"
## Original chapter actors and normal movement; no animation/physics pause on subject.
## Clear-terrain placement, frozen nonparticipants, fog-off and zoom are fixtures.
const VECTORS := [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]

func _observed(u) -> Dictionary:
	var art=root.get_node("Art")
	var frame=u._anim_frame_for_state(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction))
	return {"key":u.key,"direction":u.animation_direction,"position":[u.position.x,u.position.y],
		"anim_t":u._anim_t,"move_blend":u._move_blend,"pose":_texture_pose(frame),"source":_texture_source(frame),
		"physics_enabled":u.is_physics_processing(),"hp":u.hp,"portrait":_texture_source(u.ui_portrait_texture()),
		"draw_scale":u._frame_draw_scale(frame),"draw_offset":str(u._frame_draw_offset(frame,u.radius*3.7*u.visual_scale*u._frame_draw_scale(frame)))}

func _live_shot(b,u,label: String) -> void:
	# Follow the continuously moving actor; do not pause its physics or clock.
	b.center_camera_cell(b.map.world_to_cell(u.position));u.queue_redraw()
	var before:=_observed(u)
	await RenderingServer.frame_post_draw
	var after:=_observed(u)
	var img:=root.get_texture().get_image()
	var path:=art_output.path_join(label+".png")
	check(img.get_size()==root.size,"actual viewport dimensions "+label)
	check(img.save_png(path)==OK,"continuous native viewport saved "+label)
	art_images.append({"name":label,"path":path,"sha256":FileAccess.get_sha256(path)})
	art_runtime.append({"case":label,"before_render":before,"after_render":after,"viewport":[root.size.x,root.size.y],
		"subject_paused":false,"scope":"Normal rendered motion between two observations; phase may advance during render. No manufactured animation values."})

func _chapter_gait(key: String,index: int) -> void:
	var b=await _start("",index);_freeze_nonparticipants(b)
	var u=b.find_unit(key)
	check(alive(u) and u.is_hero and u.art_variant.is_empty(),"original ordinary gait actor "+key)
	if not alive(u):await _dispose(b);return
	var cell:=_clear_art_patch(b);check(cell.x>=0,"clear real terrain "+key)
	if cell.x<0:await _dispose(b);return
	var center: Vector2=b.map.cell_to_world(cell)
	var original: Dictionary={"atk":u.atk,"hp":u.hp,"max_hp":u.max_hp,"speed":u.base_speed,"portrait":_texture_source(u.ui_portrait_texture())}
	b.fog=false
	if is_instance_valid(b._fog_layer):b._fog_layer.hide()
	b.camera.zoom=Vector2.ONE*2.7
	b.select_members([u],false)
	u.passive=true;u.auto_micro=false;u.set_physics_process(true)
	for i in range(4):
		var d: String=ART_DIRS[i];var v: Vector2=VECTORS[i]
		u.order_stop();await _wait(0.8)
		u.position=center-v*72.0;b._grid_build()
		var start: Vector2=u.position
		u.order_move(center+v*72.0)
		var seen: Dictionary={};var sampled: Dictionary={};var count:=0
		var started:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-started<12000 and count<8:
			await physics_frame
			# Preserve real four-vote turn hysteresis; sample only after it settles.
			if u._move_blend<=0.3 or u.animation_direction!=d:continue
			var frame=u._anim_frame_for_state(root.get_node("Art").unit_texture(key,"",u.animation_direction))
			var pose:=_texture_pose(frame);seen[pose]=true
			var cycle: int=floori(u._anim_t/TAU)
			var token:=pose+":"+str(cycle)
			if sampled.has(token):continue
			sampled[token]=true
			check(u.animation_direction==d,"actual ordered gait direction "+key+" "+d)
			check(_texture_source(frame).begins_with("res://assets/characters/"+key+"_traits_20261006/"),"actual own gait source "+key+" "+d)
			await _live_shot(b,u,key+"_"+d+"_live_"+str(count));count+=1
		check(count==8 and seen.size()==4,"continuous two-cycle samples visit all four gait poses "+key+" "+d)
		check(u.position.distance_to(start)>30.0,"real movement advances actor "+key+" "+d)
		check(u.is_physics_processing(),"subject physics never frozen for gait capture "+key+" "+d)
		art_runtime.append({"case":"gait_summary","actor":key,"direction":d,"samples":count,"poses_seen":seen.keys(),
			"elapsed_ms":Time.get_ticks_msec()-started,"distance":u.position.distance_to(start),"subject_paused":false})
		u.order_stop();await _wait(0.8)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1440,960),Vector2i(1920,1080)]:
		root.size=size;await process_frame;await process_frame
		u.position=center;b._grid_build();u.order_stop();await _wait(0.5)
		await _live_shot(b,u,key+"_idle_"+str(size.x)+"x"+str(size.y))
	check(u.atk==original.atk and u.hp==original.hp and u.max_hp==original.max_hp and u.base_speed==original.speed,"gait keeps original numeric definitions "+key)
	check(_texture_source(u.ui_portrait_texture())==original.portrait,"gait keeps standard portrait "+key)
	root.size=Vector2i(1440,960)
	await _dispose(b)

func _run() -> void:
	art_output=OS.get_environment("ART_QA_OUT");art_visual=true;art_character="ordinary_continuous_gait_v15a"
	if not _art_profile_guard():quit(1);return
	root.size=Vector2i(1440,960);root.position=Vector2i(30000,30000);root.unfocusable=true
	check(is_equal_approx(Engine.time_scale,1.0),"normal engine clock")
	await _chapter_gait("lin_chong",2)
	await _chapter_gait("wu_song",7)
	_art_finish()
