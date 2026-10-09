extends "res://tools/art_character_direction4_qa.gd"
## Candidate Wu death and corrected Lin SW lookup only in private ArtDB; original level-one combat damage.
## Adds actual shadow retention/pruning and unaffected ordinary/story route guards.
const VECTORS := [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]
const SHADOW_NODE := "WorldShadowBatch"

class CompletionProbe extends Node:
	var subject
	var enemy
	var battle
	var slot := -1
	var captured := false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(subject):return
		var ready: bool = subject._dying and subject.hp<=0.0 if slot<0 else float(subject.ability_slots[slot].get("cd_t",0.0))>0.0 and subject._cast_t<=0.0 and not battle.is_cast_pending(subject,slot)
		if not ready:return
		captured=true;subject.set_physics_process(false)
		if is_instance_valid(enemy):enemy.set_physics_process(false)
		set_physics_process(false)

class DeathPhaseProbe extends Node:
	var subject
	var threshold := 0.0
	var captured := false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(subject):return
		if subject._dying and subject._death_t>=threshold:
			captured=true;subject.set_physics_process(false);set_physics_process(false)

func _snapshot(u) -> Dictionary:
	var frame
	var slot := -1
	if u._dying:
		var frames: Array=root.get_node("Art").unit_anim_frames(u.key,"death",u.animation_direction,u.visual_art_variant())
		slot=mini(int(clampf(u._death_t/u.DEATH_DUR,0.0,1.0)*frames.size()),frames.size()-1)
		frame=frames[slot] if not frames.is_empty() else null
	else:
		frame=u._anim_frame_for_state(root.get_node("Art").unit_texture(u.key,u.visual_art_variant(),u.animation_direction))
	return {"key":u.key,"variant":u.visual_art_variant(),"direction":u.animation_direction,"hp":u.hp,"max_hp":u.max_hp,"atk":u.atk,"hero_level":u.hero_level,
		"dying":u._dying,"death_t":u._death_t,"death_resource_slot":slot,"cast_t":u._cast_t,"lunge":u._lunge,
		"source":_texture_source(frame),"pose":_texture_pose(frame),"render_directional":u._frame_directional,
		"portrait":_texture_source(u.ui_portrait_texture()),"position":[u.position.x,u.position.y],
		"scope":"Actual Unit state, resource query and original viewport. Death local selection recorded using unchanged renderer rule; visual verified separately."}

func _shot(b,u,label: String) -> void:
	# Explicit fog-off visual fixture also hides the old fog texture. Merely
	# setting fog=false stops its updates and can leave the unexplored black layer.
	b.fog=false
	if is_instance_valid(b._fog_layer):b._fog_layer.hide()
	b.camera.zoom=Vector2.ONE*2.7;b.center_camera_cell(b.map.world_to_cell(u.position));b._grid_build()
	await physics_frame
	check(u.visible,"actual subject visible before capture "+label)
	u.queue_redraw()
	if u.hp>0.0:b.select_members([u],false)
	await _art_screenshot(b,label,u)
	art_runtime.append({"case":label,"observed":_snapshot(u)})

func _death(key: String,index: int,dir_index: int) -> void:
	var b=await _start("",index);_freeze_nonparticipants(b)
	var u=b.find_unit(key);check(alive(u) and u.hero_level==1 and u.art_variant.is_empty(),"original unmodified level-one death actor "+key)
	if not alive(u):await _dispose(b);return
	var cell:=_clear_art_patch(b);check(cell.x>=0,"existing death contact terrain")
	if cell.x<0:await _dispose(b);return
	var foes: Array=b.units.filter(func(e):return alive(e) and e.faction==1 and not e.is_building and not e.is_resource and not e.is_noncombat and not e.is_ranged)
	foes.sort_custom(func(a,z):return a.atk>z.atk);check(not foes.is_empty(),"original lethal melee opponent")
	if foes.is_empty():await _dispose(b);return
	var enemy=foes[0];var center: Vector2=b.map.cell_to_world(cell);var d: String=ART_DIRS[dir_index]
	u.position=center;enemy.position=center+VECTORS[dir_index]*24.0;u.animation_direction=d;u.auto_micro=false;u.passive=true
	b.fog=false;b._grid_build();var before:=_snapshot(u)
	art_runtime.append({"case":"death_fixture","actor":key,"direction":d,"original":before,"opponent":{"key":enemy.key,"atk":enemy.atk,"hp":enemy.hp},
		"fixture":"Contact placement and frozen subject/nonparticipants; original enemy physics/orders/damage and original level-one hero HP/armor. No injected damage or altered stats."})
	var probe:=CompletionProbe.new();probe.subject=u;probe.enemy=enemy;probe.battle=b;root.add_child(probe)
	enemy.auto_micro=false;enemy.passive=false;enemy.set_physics_process(true);enemy.order_attack(u,false,true)
	for tick in range(7200):
		if probe.captured:break
		await physics_frame
	check(probe.captured,"actual lethal attack triggers dying "+key+" "+d)
	if not probe.captured:probe.queue_free();await _dispose(b);return
	check(u.hp<=0.0 and u.max_hp==before.max_hp and u.atk==before.atk,"death original numeric definitions preserved")
	check(u not in b.units and u not in b.selection,"dead actor leaves live registry/selection")
	var shadow=b.world.get_node_or_null(SHADOW_NODE)
	check(is_instance_valid(shadow) and u in shadow.retained_dying_units,"dying hero retained by normal render shadow batch")
	art_runtime.append({"case":"dying_shadow","actor":key,"direction":d,"summary":shadow.summary() if is_instance_valid(shadow) else {"exists":false}})
	var actor_id: int=u.get_instance_id();probe.queue_free()
	for stage in range(4):
		var threshold: float=[0.07,0.40,0.77,1.12][stage]
		var phase:=DeathPhaseProbe.new();phase.subject=u;phase.threshold=threshold;root.add_child(phase);u.set_physics_process(true)
		for tick in range(240):
			if phase.captured:break
			await physics_frame
		check(phase.captured,"actual death timer phase "+key+" "+d+" "+str(stage))
		if phase.captured:
			await _shot(b,u,key+"_"+d+"_death_"+str(stage))
			if key=="wu_song":check(u._frame_directional and String(_snapshot(u).source).contains("_traits_20261006/"),"new Wu death uses own directional body")
			if key=="lin_chong" and d=="sw":check(u._frame_directional and String(_snapshot(u).source).ends_with("death_sw2_v10.png"),"corrected Lin SW death uses own native source")
		phase.queue_free()
	u.set_physics_process(true)
	for tick in range(180):
		if not is_instance_valid(u):break
		await physics_frame
	await process_frame
	await process_frame
	check(is_instance_valid(shadow) and shadow.retained_dying_units.all(func(e):return is_instance_valid(e) and e.get_instance_id()!=actor_id),"released actor pruned from normal shadow retention")
	art_runtime.append({"case":"released_shadow","actor":key,"direction":d,"summary":shadow.summary() if is_instance_valid(shadow) else {"exists":false}})
	check(not is_instance_valid(u),"normal death timer releases Unit node "+key+" "+d)
	check(b.units.all(func(e):return not is_instance_valid(e) or e.get_instance_id()!=actor_id),"released corpse never returns to combat registry")
	art_runtime.append({"case":"death_released","actor":key,"direction":d,"node_id":actor_id,"unit_freed":not is_instance_valid(u)})
	await _dispose(b)


func _queries() -> void:
	var art=root.get_node("Art")
	var baseline: Array=JSON.parse_string(FileAccess.get_file_as_string("res://ordinary_predeath_query_baselines.json"))
	for row in baseline:
		var frames: Array=art.unit_anim_frames(row.key,row.state,row.direction)
		var poses: Array=frames.map(func(frame):return _texture_pose(frame))
		if row.state=="death" and (row.key=="wu_song" or (row.key=="lin_chong" and row.direction=="sw")):
			check(frames.size()==4 and art.unit_anim_uses_directional_source(row.key,row.state,row.direction),"pilot native directional death  "+row.direction)
			check(frames.all(func(frame):return frame is AtlasTexture and bool(frame.get_meta("authored_direction4",false)) and frame.has_meta("draw_offset_px") and frame.has_meta("draw_scale")),"production death native metadata "+row.direction)
		else:
			check(poses==row.candidate,"other qualified ordinary route unchanged "+row.key+" "+row.state+" "+row.direction)
		art_rows.append({"key":row.key,"state":row.state,"direction":row.direction,"before":row.candidate,"current":poses,"scope":"resource query, not observed action"})
	for pair in [["lin_chong","lin_chong_prisoner"],["lin_chong","lin_chong_escort"],["wu_song","wu_song_mengzhou"]]:
		for direction in ART_DIRS:
			for state in ["idle","walk","attack","hurt","death","down"]:
				var frames: Array=art.unit_anim_frames(pair[0],state,direction,pair[1])
				check(frames.all(func(frame):return not _texture_source(frame).contains("_traits_20261006/")),"story body excludes ordinary death/gait/combat "+pair[1]+" "+state+" "+direction)
				if state in ["idle","walk"]:check(not frames.is_empty(),"story body retained "+pair[1]+" "+state+" "+direction)

func _run() -> void:
	art_output=OS.get_environment("ART_QA_OUT");art_visual=OS.get_environment("ART_VISUAL")=="1";art_character="ordinary_death_production_v14"
	if not _art_profile_guard():quit(1);return
	root.size=Vector2i(1440,960);root.position=Vector2i(30000,30000);root.unfocusable=true
	check(is_equal_approx(Engine.time_scale,1.0),"normal engine clock")
	_queries()
	for key in ["lin_chong","wu_song"]:
		for direction in range(4):await _death(key,2 if key=="lin_chong" else 7,direction)
	_art_finish()
