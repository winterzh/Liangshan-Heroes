extends "res://tools/art_character_direction4_qa.gd"
## Original actors/orders; legal level-six restore fixture for skill pictures.
## Death uses untouched original level-one stats and actual enemy attack damage.
const VECTORS := [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]
var case_mode := ""

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

func _skill(key: String,index: int,slot: int,dir_index: int) -> void:
	var b=await _start("",index);_freeze_nonparticipants(b)
	await _wait(0.8)
	check(b.phase==b.Phase.FIGHT,"original chapter actually in fight phase")
	var u=b.find_unit(key);check(alive(u) and u.is_hero and u.art_variant.is_empty(),"original skill actor "+key)
	if not alive(u):await _dispose(b);return
	var cell:=_clear_art_patch(b);check(cell.x>=0,"existing skill contact terrain")
	if cell.x<0:await _dispose(b);return
	var foes: Array=b.units.filter(func(e):return alive(e) and e.faction==1 and not e.is_building and not e.is_resource and not e.is_noncombat and (e.is_hero if key=="lin_chong" and slot==3 else true))
	foes.sort_custom(func(a,z):return a.max_hp>z.max_hp)
	check(not foes.is_empty(),"original valid skill target "+key+" "+str(slot))
	if foes.is_empty():await _dispose(b);return
	var enemy=foes[0];var center: Vector2=b.map.cell_to_world(cell);var d: String=ART_DIRS[dir_index]
	u.position=center;enemy.position=center+VECTORS[dir_index]*60.0;u.animation_direction=d
	u.auto_micro=false;u.passive=true;enemy.auto_micro=false;enemy.passive=true
	b.fog=false;b._grid_build();b.select_members([u],false)
	var base:=_snapshot(u)
	u.restore_progress(6,0.0,6,[0,0,0,0]) # Legal restored-level fixture; not natural leveling evidence.
	check(u.hero_level==6 and u.can_learn(slot),"legal six-level skill gate "+key+" "+str(slot))
	b.learn_slot(u,slot)
	check(int(u.ability_slots[slot].rank)==1,"player learning spends legal skill point")
	var after_learning:=_snapshot(u);var hp_before: float=enemy.hp
	var aid: String=u.ability_slots[slot].id;var prefix:=key+"_"+str(slot)+"_"+d
	art_runtime.append({"case":"skill_fixture","actor":key,"slot":slot,"direction":d,"ability":aid,"original":base,"restored":after_learning,
		"fixture":"Original chapter actor restored via production restore_progress to legal level6/rank1. No stat/skill definitions changed. Not natural leveling or same-version save acceptance."})
	if bool(u.ability_slots[slot].passive):
		check(key=="lin_chong" and slot==2 and u.lin_spear_rank==1,"Lin passive spear rank installed")
		await _shot(b,u,prefix+"_passive")
		u.set_physics_process(true);u.order_attack(enemy,false,true)
		for tick in range(600):
			if enemy.hp<hp_before:break
			await physics_frame
		u.set_physics_process(false)
		check(enemy.hp<hp_before and u._lin_spear_stacks>0,"learned passive normal melee builds spear stack")
		await _shot(b,u,prefix+"_passive_attack")
	else:
		b.cast_ability(u,slot,true)
		if bool(b._abilities[aid].targeted):b._cast_armed_at(b.to_screen(enemy.position))
		check(u._cast_t>0.0 and b.is_cast_pending(u,slot),"normal player skill windup "+prefix)
		await _shot(b,u,prefix+"_cast")
		var probe:=CompletionProbe.new();probe.subject=u;probe.enemy=enemy;probe.battle=b;probe.slot=slot;root.add_child(probe)
		u.set_physics_process(true)
		for tick in range(600):
			if probe.captured:break
			await physics_frame
		check(probe.captured,"normal skill settles and starts cooldown "+prefix)
		match aid:
			"wu_tigers":check(b.units.filter(func(e):return alive(e) and e.key=="tiger_summon" and e.faction==u.faction).size()==2,"actual two tiger summons")
			"wu_wine":check(u._drunk_t>0.0,"actual timed wine buff")
			"wu_blades":check(enemy.hp<hp_before and enemy._def_down>0.0 and enemy._blind_t>0.0,"actual blade damage/armor/blind")
			"wu_drunkgod":check(u._phys_immune_t>0.0,"actual timed drunk-god physical immunity")
			"lin_thrust":check(enemy.hp<hp_before,"actual spear line damage")
			"lin_sweep":check(u._lin_guard_t>0.0,"actual timed spear guard")
			"lin_chrono":check(b._lin_duels.any(func(duel):return duel.caster==u and duel.target==enemy),"actual original enemy hero duel registered")
		await _shot(b,u,prefix+"_effect")
		art_runtime.append({"case":"skill_settled","actor":key,"slot":slot,"direction":d,"ability":aid,"enemy_before_hp":hp_before,"enemy_after_hp":enemy.hp,
			"cooldown":u.ability_slots[slot].get("cd_t",0.0),"fx_nodes":b.fx_root.get_child_count(),"phys_immunity_t":u._phys_immune_t,"drunk_t":u._drunk_t,"lin_guard_t":u._lin_guard_t})
		probe.queue_free()
	check(u.art_variant.is_empty() and _snapshot(u).portrait==base.portrait,"skill keeps body role and standard portrait")
	check(b._gameplay_rng_issue.is_empty(),"skill gameplay stream remains healthy")
	await _dispose(b)

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
		phase.queue_free()
	u.set_physics_process(true)
	for tick in range(180):
		if not is_instance_valid(u):break
		await physics_frame
	await process_frame
	check(not is_instance_valid(u),"normal death timer releases Unit node "+key+" "+d)
	check(b.units.all(func(e):return not is_instance_valid(e) or e.get_instance_id()!=actor_id),"released corpse never returns to combat registry")
	art_runtime.append({"case":"death_released","actor":key,"direction":d,"node_id":actor_id,"unit_freed":not is_instance_valid(u)})
	await _dispose(b)

func _run() -> void:
	art_output=OS.get_environment("ART_QA_OUT");art_visual=OS.get_environment("ART_VISUAL")=="1";case_mode=OS.get_environment("ORDINARY_FINAL_ACTION_CASE");art_character="ordinary_final_actions_v8a_"+case_mode
	if not _art_profile_guard():quit(1);return
	root.size=Vector2i(1440,960);root.position=Vector2i(30000,30000);root.unfocusable=true
	check(is_equal_approx(Engine.time_scale,1.0),"normal engine clock")
	if case_mode.begins_with("skills_"):
		var group: int=int(case_mode.trim_prefix("skills_"));var key: String="lin_chong" if group<4 else "wu_song"
		for d in range(4):await _skill(key,2 if key=="lin_chong" else 7,group%4,d)
	elif case_mode=="death":
		for key in ["lin_chong","wu_song"]:
			for d in range(4):await _death(key,2 if key=="lin_chong" else 7,d)
	else:check(false,"explicit skills/death case required")
	_art_finish()
