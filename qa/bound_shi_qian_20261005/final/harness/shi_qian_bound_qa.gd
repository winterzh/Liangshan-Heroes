extends "res://tools/art_character_direction4_qa.gd"
## Real current-RTS prisoners and player right-click mission completion.
## Only rescuer contact position, frozen nonparticipants and pose photos are fixtures.

func _bound_contracts() -> void:
	var art = root.get_node("Art")
	var ca = load("res://scripts/campaign_art.gd")
	var unique := {}
	for d in ART_DIRS:
		var frames: Array = art.unit_anim_frames("shi_qian","idle",d,"bound_shi_qian")
		check(frames.size()==1 and _texture_source(frames[0])=="res://assets/characters/shi_qian_bound_20261005/bound.png", "native bound Shi Qian exact idle "+d)
		if frames.is_empty(): continue
		unique[_texture_pose(frames[0])] = true
		check(frames[0] is AtlasTexture and frames[0].get_meta("authored_direction4",false) and frames[0].get_width()==frames[0].get_height(), "authored square atlas with draw metadata "+d)
		check(art.unit_texture("shi_qian","bound_shi_qian",d)==frames[0] or _texture_pose(art.unit_texture("shi_qian","bound_shi_qian",d))==_texture_pose(frames[0]), "texture and frame route agree "+d)
		for state in ["walk","hurt"]:
			check(_texture_pose(art.unit_anim_frames("shi_qian",state,d,"bound_shi_qian")[0])==_texture_pose(frames[0]) and not art.campaign_variant_has_animation("bound_shi_qian",state,d), "unarmed standing fallback does not claim authored "+state+" "+d)
		for state in ["attack","gather","death","down"]:
			check(art.unit_anim_frames("shi_qian",state,d,"bound_shi_qian").is_empty() and not art.unit_anim_uses_directional_source("shi_qian",state,d,"bound_shi_qian"), "no generic weapon/terminal borrowing "+state+" "+d)
		check(art.campaign_variant_has_direction("bound_shi_qian",d) and art.campaign_variant_has_animation("bound_shi_qian","idle",d), "native variant query agrees "+d)
		check(art.unit_texture("guan_sheng","bound_shi_qian",d)==null and art.unit_anim_frames("guan_sheng","idle",d,"bound_shi_qian").is_empty() and not art.unit_anim_uses_directional_source("guan_sheng","idle",d,"bound_shi_qian"), "wrong owner rejected "+d)
	check(unique.size()==4,"four independently sampled native views")
	for d in ["","bad"]:
		check(art.unit_anim_frames("shi_qian","idle",d,"bound_shi_qian").is_empty() and not art.unit_anim_uses_directional_source("shi_qian","idle",d,"bound_shi_qian"), "empty/invalid animation direction rejected "+d)
	check(art.unit_texture("shi_qian","bound_shi_qian","bad")==null,"invalid static direction rejected")
	check(ca.portrait_owner("bound_shi_qian")=="shi_qian" and ca.native_bound_owner("bound_qin_ming")=="qin_ming","native bound registry owns Shi Qian and preserves native Qin owner")

func _art_screenshot(b, name: String, subject = null) -> void:
	await super._art_screenshot(b,name,subject)
	if not art_visual or not name.begins_with("shi_bound_current_"): return
	# This fixed original-prisoner scene has no large opaque white UI panels.
	# Missing texture RIDs previously rendered Qin as a 10000-pixel white block.
	var photo: Image = root.get_texture().get_image()
	var white := 0
	for y in range(250,800):
		for x in range(400,1100):
			var c := photo.get_pixel(x,y)
			if c.r>0.99 and c.g>0.99 and c.b>0.99: white+=1
	check(white<500,"stationary original prisoner scene has no missing-texture white block "+name)

func _current_rescue() -> void:
	var b = await _start("",2)
	_freeze_nonparticipants(b)
	b.fog=false
	if is_instance_valid(b._fog_layer): b._fog_layer.hide()
	var level = b.level
	var u = level.prisoners[0]
	var art = root.get_node("Art")
	check(level.get_script().resource_path=="res://scripts/levels/level3_zhujiazhuang_rts.gd" and b.phase==b.Phase.FIGHT and level.prisoners.size()==7 and u.key=="shi_qian", "actual current chapter original seven-prisoner deployment")
	var actor_id: int = u.get_instance_id()
	var ids: Array = level.prisoners.map(func(p): return p.get_instance_id())
	var stats := [u.hp,u.max_hp,u.atk,u.atk_cd,u.atk_range,u.radius]
	var portrait: String = _texture_pose(u.ui_portrait_texture())
	check(u.faction==2 and u.is_captive and u.is_noncombat and u.is_hero and u.base_speed==0 and u.atk==0 and u.ability.is_empty() and u.ability_slots.is_empty(), "original neutral bound noncombat restrictions unchanged")
	check(_texture_source(u.ui_portrait_texture())=="res://assets/portraits18.png" and _texture_pose(u.ui_portrait_texture())==_texture_pose(art.portrait_texture("shi_qian")), "bound UI keeps current Shi Qian portrait cell")
	u.fog_visible=true;u.show()
	for d in ART_DIRS:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		var actual = u._anim_frame_for_state(art.unit_texture(u.key,u.art_variant,d))
		check(_texture_pose(actual)==_texture_pose(art.unit_anim_frames("shi_qian","idle",d,"bound_shi_qian")[0]) and u._frame_directional and not u._authored_direction4_attack_active(), "original captive renderer selects native idle without mirror "+d)
		u.queue_redraw()
		await _art_screenshot(b,"shi_bound_current_"+d,u)
	for p in level.prisoners:
		if p.key in ["shi_qian","shi_xiu","qin_ming"]: continue
		var bound_frames: Array = art.unit_anim_frames(p.key,"idle","se",p.art_variant)
		var generic_frames: Array = art.unit_anim_frames(p.key,"idle","se")
		check(bound_frames.size()==generic_frames.size() and (bound_frames.is_empty() or _texture_pose(bound_frames[0])==_texture_pose(generic_frames[0])) and art.unit_texture(p.key,p.art_variant,"se")==art.unit_texture(p.key,"","se"), "other programmatic prisoner static/animation route unchanged "+p.key)
	var qin = level.prisoners[2]
	for d in ART_DIRS:
		var qin_frames: Array = art.unit_anim_frames("qin_ming","idle",d,"bound_qin_ming")
		check(qin_frames.size()==1 and _texture_source(qin_frames[0])=="res://assets/characters/qin_ming_bound_20261005/bound.png" and art.unit_anim_uses_directional_source("qin_ming","idle",d,"bound_qin_ming"),"native Qin captive route retained "+d)
		check(qin_frames[0].get_instance_id()==art.unit_anim_frames("qin_ming","idle",d,"bound_qin_ming")[0].get_instance_id(),"native Qin frames retained across draw queries "+d)
		var shi_frames: Array = art.unit_anim_frames("shi_qian","idle",d,"bound_shi_qian")
		check(shi_frames[0].get_instance_id()==art.unit_anim_frames("shi_qian","hurt",d,"bound_shi_qian")[0].get_instance_id(),"Shi idle and standing fallback share retained frames "+d)
	check(_texture_source(qin.ui_portrait_texture())=="res://assets/characters/hero_portraits_aligned_20260926/qin_ming.png","Qin captive portrait retained")
	var song = level.song
	var action: Dictionary = b.mission.actions.zhu_rts_rescue
	check(not action.done and action.duration==3.0 and not level.prisoners_freed,"original three-second rescue action pending")
	# Contact position avoids testing gates/battle difficulty in an art batch.
	song.position=b.map.cell_to_world(action.cell)
	song.passive=true; song.auto_micro=false; song.set_physics_process(true)
	b._grid_build()
	_action(b,song,"zhu_rts_rescue")
	for tick in range(160):
		if level.prisoners_freed: break
		await _wait(0.1)
	check(action.done and level.prisoners_freed and b.mission.has_event("zhu_prisoners_freed") and orders==1,"player right-click and ordinary timed mission callback rescue originals")
	_freeze_nonparticipants(b)
	check(ids==level.prisoners.map(func(p):return p.get_instance_id()) and u.get_instance_id()==actor_id and b.units.has(u),"rescue retains original seven actors")
	for p in level.prisoners:
		check(p.faction==0 and not p.is_captive and not p.is_hero and p.is_noncombat and p.base_speed==82 and p.art_variant.is_empty() and p.atk==0 and p.ability_slots.is_empty(),"rescued wounded noncombat state unchanged "+p.key)
	check(stats==[u.hp,u.max_hp,u.atk,u.atk_cd,u.atk_range,u.radius] and portrait==_texture_pose(u.ui_portrait_texture()),"rescue preserves combat values HP and portrait")
	for d in ART_DIRS:
		u.animation_direction=d;u.face_left=d in ["sw","nw"];u._move_blend=1.0;u._anim_t=0.0
		var actual = u._anim_frame_for_state(art.unit_texture(u.key,"",d))
		check(_texture_pose(actual)==_texture_pose(art.unit_anim_frames("shi_qian","walk",d)[0]) and u._frame_directional==art.unit_anim_uses_directional_source("shi_qian","walk",d),"same rescued actor resumes existing generic walk/facing "+d)
		u.queue_redraw();await _art_screenshot(b,"shi_rescued_current_"+d,u)
	# Real evacuation order after rescue, not pose-matrix movement.
	u._move_blend=0.0;u.set_physics_process(true)
	var before: Vector2 = u.position
	var target: Vector2 = before+Vector2(32,0)
	u.order_move(target)
	await _wait(1.0)
	check(u.position.distance_to(before)>4.0 and u.is_noncombat and u.atk==0,"same rescued wounded actor executes ordinary movement")
	u.set_physics_process(false)
	check(not b.mission.has_event("zhu_victory") and b.phase==b.Phase.FIGHT,"no complete chapter victory claimed")
	art_runtime.append({"case":"shi_current_rts_rescue","actor_injected":false,"same_actor":u.get_instance_id()==actor_id,"original_prisoners":ids.size(),"normal_player_order":orders==1,"normal_timed_action":action.done,"mission_event":b.mission.has_event("zhu_prisoners_freed"),"hp_stats_unchanged":stats==[u.hp,u.max_hp,u.atk,u.atk_cd,u.atk_range,u.radius],"is_noncombat":u.is_noncombat,"base_speed":u.base_speed,"variant":u.art_variant,"contact_position_fixture":true,"nonparticipants_frozen":true,"battle_coordinator_paused":false,"time_scale":Engine.time_scale})
	await _dispose(b)

func _run() -> void:
	if not _art_profile_guard(): quit(2);return
	AudioServer.set_bus_mute(0,true);Engine.time_scale=1.0
	art_character="bound_shi_qian";art_manifest_path=OS.get_environment("ART_MANIFEST");art_output=OS.get_environment("ART_QA_OUT");art_visual=OS.get_environment("ART_VISUAL")=="1"
	check(art_output.is_absolute_path(),"external QA output")
	DirAccess.make_dir_recursive_absolute(art_output)
	art_manifest=JSON.parse_string(FileAccess.get_file_as_string(art_manifest_path))
	if art_visual:
		root.unfocusable=true;root.size=Vector2i(1440,960);root.content_scale_size=root.size;DisplayServer.window_set_size(root.size)
	await process_frame
	art_identity_before=_art_identity()
	_bound_contracts()
	if failures.is_empty(): await _current_rescue()
	art_identity_after=_art_identity()
	check(art_identity_before.get("source_sha256")==art_identity_after.get("source_sha256"),"installed identity unchanged across actual rescue QA")
	_art_finish()
