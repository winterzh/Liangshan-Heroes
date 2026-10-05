extends "res://tools/art_character_direction4_qa.gd"
## Current original seven prisoners. Normal timed player rescue; explicit photo fixtures.
const SUBJECTS := ["yang_lin","huang_xin","wang_ying","deng_fei"]

func _art_identity() -> Dictionary:
	var provider = load("res://scripts/run_content_identity.gd").new()
	var result: Dictionary = provider.resolve_runtime_identity()
	check(bool(result.get("ok",false)),"installed content identity resolves for entire captive batch")
	if not bool(result.get("ok",false)):return result
	for key in SUBJECTS:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/direction4/bound_"+key+"_20261005.json"))
		var selected: Array = manifest.resources.duplicate()
		for source in manifest.sources.values():selected.append(source.path)
		for raw in selected:
			var relative := String(raw).trim_prefix("res://")
			check(provider._files.has(relative),"batch character file included in installed identity: "+relative)
	return result

func _bound_contracts() -> void:
	var art = root.get_node("Art")
	var ca = load("res://scripts/campaign_art.gd")
	for key in SUBJECTS:
		var variant: String = "bound_"+key
		var unique := {}
		for d in ART_DIRS:
			var frames: Array = art.unit_anim_frames(key,"idle",d,variant)
			check(frames.size()==1 and _texture_source(frames[0])=="res://assets/characters/"+key+"_bound_20261005/bound.png","exact native captive idle "+key+" "+d)
			if frames.is_empty(): continue
			unique[_texture_pose(frames[0])] = true
			check(frames[0] is AtlasTexture and frames[0].get_meta("authored_direction4",false) and frames[0].get_width()==frames[0].get_height(),"square authored atlas "+key+" "+d)
			check(_texture_pose(art.unit_texture(key,variant,d))==_texture_pose(frames[0]),"static and animated route agree "+key+" "+d)
			for state in ["walk","hurt"]:
				check(_texture_pose(art.unit_anim_frames(key,state,d,variant)[0])==_texture_pose(frames[0]) and not art.campaign_variant_has_animation(variant,state,d),"standing fallback not authored "+key+" "+state+" "+d)
			for state in ["attack","gather","death","down"]:
				check(art.unit_anim_frames(key,state,d,variant).is_empty() and not art.unit_anim_uses_directional_source(key,state,d,variant),"no weapon or terminal borrowing "+key+" "+state+" "+d)
			check(art.campaign_variant_has_direction(variant,d) and art.campaign_variant_has_animation(variant,"idle",d),"variant queries agree "+key+" "+d)
			check(art.unit_texture("guan_sheng",variant,d)==null and art.unit_anim_frames("guan_sheng","idle",d,variant).is_empty() and not art.unit_anim_uses_directional_source("guan_sheng","idle",d,variant),"wrong owner rejected "+key+" "+d)
			check(frames[0].get_instance_id()==art.unit_anim_frames(key,"hurt",d,variant)[0].get_instance_id(),"native frames retained across queries "+key+" "+d)
		check(unique.size()==4,"four independent sampled native views "+key)
		for d in ["","bad"]:
			check(art.unit_anim_frames(key,"idle",d,variant).is_empty() and not art.unit_anim_uses_directional_source(key,"idle",d,variant),"invalid animation direction rejected "+key+" "+d)
		check(art.unit_texture(key,variant,"bad")==null and ca.portrait_owner(variant)==key and ca.native_bound_owner(variant)==key,"native registry and portrait owner "+key)

func _art_screenshot(b, name: String, subject = null) -> void:
	await super._art_screenshot(b,name,subject)
	if not art_visual or not "_bound_current_" in name: return
	# Original prisoner viewport fixture contains no opaque white panels.
	var photo: Image = root.get_texture().get_image()
	var white := 0
	for y in range(250,800):
		for x in range(400,1100):
			var c := photo.get_pixel(x,y)
			if c.r>0.99 and c.g>0.99 and c.b>0.99: white+=1
	check(white<500,"original prisoner scene has no missing texture white block "+name)

func _current_rescue() -> void:
	var b = await _start("",2)
	_freeze_nonparticipants(b)
	b.fog=false
	if is_instance_valid(b._fog_layer): b._fog_layer.hide()
	var level = b.level
	var art = root.get_node("Art")
	check(level.get_script().resource_path=="res://scripts/levels/level3_zhujiazhuang_rts.gd" and b.phase==b.Phase.FIGHT and level.prisoners.size()==7,"actual current chapter original seven-prisoner deployment")
	var ids: Array = level.prisoners.map(func(p):return p.get_instance_id())
	var originals := {}
	for u in level.prisoners:
		originals[u.key]={"id":u.get_instance_id(),"stats":[u.hp,u.max_hp,u.atk,u.atk_cd,u.atk_range,u.radius],"portrait":_texture_pose(u.ui_portrait_texture())}
		if u.key not in SUBJECTS: continue
		check(u.faction==2 and u.is_captive and u.is_noncombat and u.is_hero and u.base_speed==0 and u.atk==0 and u.ability.is_empty() and u.ability_slots.is_empty(),"original neutral captive restrictions "+u.key)
		check(_texture_pose(u.ui_portrait_texture())==_texture_pose(art.portrait_texture(u.key)),"bound current UI portrait cell "+u.key)
		u.fog_visible=true;u.show()
		for d in ART_DIRS:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			var actual = u._anim_frame_for_state(art.unit_texture(u.key,u.art_variant,d))
			check(_texture_pose(actual)==_texture_pose(art.unit_anim_frames(u.key,"idle",d,u.art_variant)[0]) and u._frame_directional and not u._authored_direction4_attack_active(),"original renderer no mirror "+u.key+" "+d)
			u.queue_redraw();await _art_screenshot(b,u.key+"_bound_current_"+d,u)
	# Previously qualified two native bodies and Shi Xiu stay owned by originals.
	for u in level.prisoners:
		if u.key in SUBJECTS: continue
		for d in ART_DIRS:
			var frames: Array = art.unit_anim_frames(u.key,"idle",d,u.art_variant)
			check(not frames.is_empty() and art.unit_anim_uses_directional_source(u.key,"idle",d,u.art_variant),"existing native captive route retained "+u.key+" "+d)
		check(_texture_pose(u.ui_portrait_texture())==originals[u.key].portrait,"existing captive portrait unchanged "+u.key)
	var song = level.song
	var action: Dictionary = b.mission.actions.zhu_rts_rescue
	check(not action.done and action.duration==3.0 and not level.prisoners_freed,"original ordinary three-second rescue pending")
	song.position=b.map.cell_to_world(action.cell)
	song.passive=true;song.auto_micro=false;song.set_physics_process(true)
	b._grid_build();_action(b,song,"zhu_rts_rescue")
	for tick in range(160):
		if level.prisoners_freed:break
		await _wait(0.1)
	check(action.done and level.prisoners_freed and b.mission.has_event("zhu_prisoners_freed") and orders==1,"normal player right-click and timed callback rescue originals")
	_freeze_nonparticipants(b)
	check(ids==level.prisoners.map(func(p):return p.get_instance_id()),"rescue retains all original seven actors")
	for u in level.prisoners:
		check(u.faction==0 and not u.is_captive and not u.is_hero and u.is_noncombat and u.base_speed==82 and u.art_variant.is_empty() and u.atk==0 and u.ability_slots.is_empty(),"rescued wounded noncombat restrictions "+u.key)
		check(originals[u.key].stats==[u.hp,u.max_hp,u.atk,u.atk_cd,u.atk_range,u.radius] and originals[u.key].portrait==_texture_pose(u.ui_portrait_texture()),"original HP combat and portrait preserved "+u.key)
		if u.key not in SUBJECTS:continue
		for d in ART_DIRS:
			u.animation_direction=d;u.face_left=d in ["sw","nw"];u._move_blend=1.0;u._anim_t=0.0
			var actual = u._anim_frame_for_state(art.unit_texture(u.key,"",d))
			check(_texture_pose(actual)==_texture_pose(art.unit_anim_frames(u.key,"walk",d)[0]) and u._frame_directional==art.unit_anim_uses_directional_source(u.key,"walk",d),"existing rescued walk and facing retained "+u.key+" "+d)
			u.queue_redraw();await _art_screenshot(b,u.key+"_rescued_current_"+d,u)
		var before: Vector2 = u.position
		u._move_blend=0.0;u.set_physics_process(true);u.order_move(before+Vector2(32,0))
		await _wait(1.0)
		check(u.position.distance_to(before)>4.0 and u.is_noncombat and u.atk==0,"same wounded actor ordinary movement "+u.key)
		u.set_physics_process(false)
		art_runtime.append({"case":"current_rts_rescue","key":u.key,"actor_injected":false,"same_actor":u.get_instance_id()==originals[u.key].id,"original_prisoners":ids.size(),"normal_player_order":orders==1,"normal_timed_action":action.done,"mission_event":b.mission.has_event("zhu_prisoners_freed"),"hp_stats_unchanged":originals[u.key].stats==[u.hp,u.max_hp,u.atk,u.atk_cd,u.atk_range,u.radius],"is_noncombat":u.is_noncombat,"base_speed":u.base_speed,"variant":u.art_variant,"contact_position_fixture":true,"nonparticipants_frozen":true,"battle_coordinator_paused":false,"time_scale":Engine.time_scale})
	check(not b.mission.has_event("zhu_victory") and b.phase==b.Phase.FIGHT,"no full chapter victory claimed")
	await _dispose(b)

func _run() -> void:
	if not _art_profile_guard():quit(2);return
	AudioServer.set_bus_mute(0,true);Engine.time_scale=1.0
	art_character="zhu_captives_bound";art_manifest_path=OS.get_environment("ART_MANIFEST");art_output=OS.get_environment("ART_QA_OUT");art_visual=OS.get_environment("ART_VISUAL")=="1"
	check(art_output.is_absolute_path(),"external QA output")
	DirAccess.make_dir_recursive_absolute(art_output)
	art_manifest=JSON.parse_string(FileAccess.get_file_as_string(art_manifest_path))
	if art_visual:
		root.unfocusable=true;root.size=Vector2i(1440,960);root.content_scale_size=root.size;DisplayServer.window_set_size(root.size)
	await process_frame
	art_identity_before=_art_identity()
	_bound_contracts()
	if failures.is_empty():await _current_rescue()
	art_identity_after=_art_identity()
	check(art_identity_before.get("source_sha256")==art_identity_after.get("source_sha256"),"installed identity unchanged across current rescue")
	_art_finish()
