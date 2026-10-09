extends "res://tools/art_character_direction4_qa.gd"
## Normal cast timers, legal restored level-six learning, original chapter actors.
## Capture actual mid/late physics phases; subject frozen only after reaching them.
const VECTORS := [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]

class CastPhaseProbe extends Node:
	var subject
	var threshold := 0.0
	var captured := false
	var actual_phase := 0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(subject) or subject._cast_t<=0.0:return
		actual_phase=1.0-subject._cast_t/subject._cast_dur
		if actual_phase<threshold:return
		captured=true;subject.set_physics_process(false);set_physics_process(false)

func _cast_snapshot(u) -> Dictionary:
	var art=root.get_node("Art")
	var frame=u._anim_frame_for_state(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction))
	return {"actor":u.key,"direction":u.animation_direction,"variant":u.visual_art_variant(),"cast_t":u._cast_t,"cast_dur":u._cast_dur,
		"phase":1.0-u._cast_t/u._cast_dur,"source":_texture_source(frame),"pose":_texture_pose(frame),"hp":u.hp,"max_hp":u.max_hp,
		"hero_level":u.hero_level,"portrait":_texture_source(u.ui_portrait_texture()),"viewport":[root.size.x,root.size.y]}

func _cast_shot(b,u,label: String) -> void:
	b.center_camera_cell(b.map.world_to_cell(u.position));u.queue_redraw()
	b._refresh_run_capture_presentation()
	check(not u.is_physics_processing() and u._cast_t>0.0,"actual pending cast phase held for view "+label)
	var before:=_cast_snapshot(u)
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image();var path:=art_output.path_join(label+".png")
	check(img.get_size()==root.size and img.save_png(path)==OK,"actual cast viewport saved "+label)
	check(_cast_snapshot(u).phase==before.phase,"render does not manufacture cast phase "+label)
	art_images.append({"name":label,"path":path,"sha256":FileAccess.get_sha256(path)})
	art_runtime.append({"case":label,"observed":before,"scope":"Actual cast timer reached through normal physics, then held for phase view. Camera/terrain/nonparticipants and legal restored level-six/rank-one are explicit fixtures; not continuous cast playback or natural progression."})

func _phase(b,u,label: String,threshold: float,resize: bool) -> void:
	var probe:=CastPhaseProbe.new();probe.subject=u;probe.threshold=threshold;root.add_child(probe)
	u.set_physics_process(true)
	for tick in range(120):
		if probe.captured:break
		await physics_frame
	check(probe.captured,"normal cast reaches requested phase "+label)
	if probe.captured:
		check(probe.actual_phase>=threshold and probe.actual_phase<threshold+0.15,"captured bounded cast phase "+label)
		check(b.is_cast_pending(u,-1),"original pending cast retained "+label)
		var sizes: Array=[Vector2i(1280,720),Vector2i(1440,960),Vector2i(1920,1080)] if resize else [Vector2i(1440,960)]
		for size: Vector2i in sizes:
			root.size=size;await process_frame;await process_frame
			await _cast_shot(b,u,label+"_"+str(size.x)+"x"+str(size.y))
	probe.queue_free()

func _case(key: String,index: int,dir_index: int) -> void:
	root.size=Vector2i(1440,960)
	var b=await _start("",index);_freeze_nonparticipants(b)
	var u=b.find_unit(key);check(alive(u) and u.art_variant.is_empty(),"original ordinary cast actor "+key)
	if not alive(u):await _dispose(b);return
	var cell:=_clear_art_patch(b);check(cell.x>=0,"existing cast terrain "+key)
	if cell.x<0:await _dispose(b);return
	var center: Vector2=b.map.cell_to_world(cell);var v: Vector2=VECTORS[dir_index];var d: String=ART_DIRS[dir_index]
	var foes: Array=b.units.filter(func(e):return alive(e) and e.faction==1 and (e.is_hero if key=="lin_chong" else not e.is_building and not e.is_resource and not e.is_noncombat and not e.is_worker))
	foes.sort_custom(func(a,z):return a.max_hp>z.max_hp)
	check(not foes.is_empty(),"original rule-valid combat target "+key)
	if foes.is_empty():await _dispose(b);return
	var enemy=foes[0];u.position=center;enemy.position=center+v*60.0;b._grid_build()
	u.passive=true;u.auto_micro=false;enemy.passive=true;enemy.auto_micro=false
	b.fog=false
	if is_instance_valid(b._fog_layer):b._fog_layer.hide()
	b.camera.zoom=Vector2.ONE*2.7;b.select_members([u],false)
	# Set facing using a genuine short movement command before self-target casts.
	u.set_physics_process(true);u.order_move(center+v*20.0)
	for tick in range(120):
		if u.animation_direction==d and u.position.distance_to(center)>2.0:break
		await physics_frame
	u.order_stop();await _wait(0.8);u.set_physics_process(false)
	check(u.animation_direction==d,"normal order establishes cast direction "+key+" "+d)
	u.restore_progress(6,0.0,6,[0,0,0,0])
	var portrait:=_texture_source(u.ui_portrait_texture())
	for slot in range(4):
		if key=="lin_chong" and slot==2:continue # Passive has no cast windup; existing passive hit evidence remains.
		check(u.hero_level==6 and u.can_learn(slot),"legal rank-one learning "+key+" "+str(slot))
		b.learn_slot(u,slot);check(int(u.ability_slots[slot].rank)==1,"actual point-spending learning "+key+" "+str(slot))
		for other in b.units:
			if is_instance_valid(other) and other!=u:other.order_stop();other.set_physics_process(false)
		check(alive(enemy),"original skill target remains alive")
		var aid: String=u.ability_slots[slot].id;var prefix:=key+"_"+str(slot)+"_"+d
		b.cast_ability(u,slot,true)
		if bool(b._abilities[aid].targeted):b._cast_armed_at(b.to_screen(enemy.position))
		check(u._cast_t>0.0 and b.is_cast_pending(u,slot),"normal player cast starts "+prefix)
		if u._cast_t<=0.0:continue
		await _phase(b,u,prefix+"_mid",0.50,false)
		await _phase(b,u,prefix+"_late",0.84,true)
		u.set_physics_process(true)
		for tick in range(180):
			if u._cast_t<=0.0 and not b.is_cast_pending(u,slot):break
			await physics_frame
		check(u._cast_t<=0.0 and not b.is_cast_pending(u,slot) and float(u.ability_slots[slot].get("cd_t",0.0))>0.0,"actual cast settles normally "+prefix)
		u.order_stop();u.passive=true;await _wait(0.4);u.set_physics_process(false)
		check(_texture_source(u.ui_portrait_texture())==portrait and u.art_variant.is_empty(),"cast preserves ordinary identity "+prefix)
		check(b._gameplay_rng_issue.is_empty(),"cast keeps healthy gameplay stream "+prefix)
	await _dispose(b)

func _run() -> void:
	art_output=OS.get_environment("ART_QA_OUT");art_visual=true;art_character="ordinary_skill_clearance_v16a"
	if not _art_profile_guard():quit(1);return
	root.size=Vector2i(1440,960);root.position=Vector2i(30000,30000);root.unfocusable=true
	check(is_equal_approx(Engine.time_scale,1.0),"normal cast clock")
	for i in range(4):await _case("lin_chong",2,i)
	for i in range(4):await _case("wu_song",7,i)
	_art_finish()
