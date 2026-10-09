extends "res://tools/art_character_direction4_qa.gd"
## Current production ArtDB/Unit copied without patches. Actual default routing.
## Original Battle, actors, stats, Unit state priorities and melee damage remain.
## Contact placement, frozen nonparticipants, fog-off and camera zoom are fixtures.
const VECTORS := [Vector2.RIGHT, Vector2.DOWN, Vector2.UP, Vector2.LEFT]

class PhaseProbe extends Node:
	var subject
	var enemy
	var late := false
	var captured := false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(subject): return
		var eligible: bool = subject._lunge>0.84 if not late else subject._lunge<=0.30 and subject._lunge>0.15
		if not eligible: return
		captured=true;subject.set_physics_process(false);enemy.set_physics_process(false);set_physics_process(false)

func _phase_shot(b,u,enemy,label: String,late: bool) -> void:
	var probe:=PhaseProbe.new();probe.subject=u;probe.enemy=enemy;probe.late=late
	root.add_child(probe)
	for tick in range(600):
		if probe.captured:break
		await physics_frame
	check(probe.captured,"actual attack phase captured "+label)
	if probe.captured:
		await _shot(b,u,label)
		if u.key=="wu_song":
			var art=root.get_node("Art")
			var frame=u._anim_frame_for_state(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction))
			var expected: Array=art.unit_anim_frames(u.key,"attack",u.animation_direction)
			check(_texture_pose(frame)==_texture_pose(expected[4 if late else 0]),"real six-slot Wu phase source "+label)
			check(u._authored_direction4_attack_active() and is_zero_approx(u._programmatic_swing_scale()),"candidate avoids duplicate sword motion "+label)
	probe.queue_free()

class ActionProbe extends Node:
	var subject
	var enemy
	var kind := ""
	var before_hp := 0.0
	var captured := false
	var observation := {}
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(subject) or not is_instance_valid(enemy): return
		var hit: bool = enemy.hp < before_hp if kind == "attack" else subject.hp < before_hp
		if not hit: return
		var art = get_tree().root.get_node("Art")
		var frame = subject._anim_frame_for_state(art.unit_texture(subject.key, subject.visual_art_variant(), subject.animation_direction))
		observation = {"kind":kind,"before_hp":before_hp,"after_hp":enemy.hp if kind == "attack" else subject.hp,
			"subject_hp":subject.hp,"enemy_hp":enemy.hp,"direction":subject.animation_direction,
			"lunge":subject._lunge,"flinch_squared":subject._flinch.length_squared(),"cast_t":subject._cast_t,
			"source":frame.atlas.resource_path if frame is AtlasTexture else frame.resource_path,
			"region":str(frame.region) if frame is AtlasTexture else "","frame_directional":subject._frame_directional,
			"programmatic_swing_scale":subject._programmatic_swing_scale(),"authored_attack_active":subject._authored_direction4_attack_active()}
		captured = true
		subject.set_physics_process(false)
		enemy.set_physics_process(false)
		set_physics_process(false)

func _body(u) -> Dictionary:
	var art = root.get_node("Art")
	var frame = u._anim_frame_for_state(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction))
	return {"key":u.key,"variant":u.visual_art_variant(),"direction":u.animation_direction,
		"source":_texture_source(frame),"pose":_texture_pose(frame),"hp":u.hp,"lunge":u._lunge,
		"flinch_squared":u._flinch.length_squared(),"move_blend":u._move_blend,"cast_t":u._cast_t,
		"position":[u.position.x,u.position.y],"portrait":_texture_source(u.ui_portrait_texture()),
		"draw_scale":frame.get_meta("draw_scale",1.0),"draw_offset_px":str(frame.get_meta("draw_offset_px",Vector2.ZERO))}

func _shot(b, u, label: String) -> void:
	u.queue_redraw()
	b.select_members([u],false)
	await _art_screenshot(b,label,u)
	art_runtime.append({"case":label,"observed":_body(u)})

func _queries() -> void:
	var art = root.get_node("Art")
	var baseline: Array=JSON.parse_string(FileAccess.get_file_as_string("res://ordinary_preintegration_query_baselines.json"))
	for key in ["wu_song","lin_chong"]:
		for direction in ART_DIRS:
			for state in ["idle","walk","attack","hurt","death","down"]:
				var old_poses: Array=[]
				for row in baseline:
					if row.key==key and row.state==state and row.direction==direction:old_poses=row.baseline;break
				var proposed: Array = art.unit_anim_frames(key,state,direction)
				var poses: Array = proposed.map(func(frame):return _texture_pose(frame))
				if state in ["idle","walk"]:
					check(proposed.size()==(1 if state=="idle" else 4),"candidate frame count "+key+" "+state+" "+direction)
					check(_texture_source(proposed[0]).begins_with("res://assets/characters/"+key+"_traits_20261006/"),"candidate exact owner "+key+" "+state+" "+direction)
				elif key=="wu_song" and state in ["attack","hurt"]:
					check(proposed.size()==(6 if state=="attack" else 1),"new Wu combat frame count "+state+" "+direction)
					check(art.unit_anim_uses_directional_source(key,state,direction),"new Wu combat no legacy mirror "+state+" "+direction)
					for frame in proposed:
						check(frame is AtlasTexture and bool(frame.get_meta("authored_direction4",false)) and frame.has_meta("draw_offset_px") and frame.has_meta("draw_scale"),"actual native combat metadata "+state+" "+direction)
				else:
					check(poses==old_poses,"existing action untouched "+key+" "+state+" "+direction)
				art_rows.append({"key":key,"state":state,"direction":direction,"baseline":old_poses,"candidate":poses,"scope":"resource query, not observed action"})
	for pair in [["lin_chong","lin_chong_prisoner"],["lin_chong","lin_chong_escort"],["wu_song","wu_song_mengzhou"]]:
		for direction in ART_DIRS:
			for state in ["idle","walk","attack","hurt","death","down"]:
				var proposed: Array = art.unit_anim_frames(pair[0],state,direction,pair[1]).map(func(frame):return _texture_pose(frame))
				check(proposed.all(func(pose):return not String(pose).contains("_traits_20261006/")),"story appearance excludes ordinary family "+pair[1]+" "+state+" "+direction)
				if state in ["idle","walk"]:check(not proposed.is_empty(),"story body remains present "+pair[1]+" "+state+" "+direction)

func _chapter(key: String, index: int) -> void:
	var b = await _start("",index)
	_freeze_nonparticipants(b)
	var u = b.find_unit(key)
	check(alive(u) and u.faction==0 and u.is_hero and u.art_variant.is_empty(),"actual ordinary chapter actor "+key)
	if not alive(u): await _dispose(b); return
	var original := {"key":u.key,"hp":u.hp,"max_hp":u.max_hp,"atk":u.atk,"base_speed":u.base_speed,
		"skills":u.ability_slots.duplicate(),"chapter":b.level.get_script().resource_path,"instance":u.get_instance_id()}
	var cell := _clear_art_patch(b)
	check(cell.x>=0,"existing clear terrain patch "+key)
	if cell.x<0: await _dispose(b); return
	var foes: Array = b.units.filter(func(e):return alive(e) and e.faction==1 and not e.is_building and not e.is_resource and not e.is_worker and not e.is_noncombat and not e.is_ranged)
	check(foes.size()>=4,"original melee enemies for four directions "+key)
	if foes.size()<4: await _dispose(b); return
	var center: Vector2 = b.map.cell_to_world(cell)
	art_runtime.append({"case":"original_actor","actor":original,"fixture_cell":[cell.x,cell.y],"enemy_roster":foes.slice(0,4).map(func(e):return {"key":e.key,"hp":e.hp,"atk":e.atk,"instance":e.get_instance_id()})})
	for i in range(4):
		var d: String = ART_DIRS[i]
		var v: Vector2 = VECTORS[i]
		var enemy = foes[i]
		var enemy_original_position: Vector2 = enemy.position
		# Placement is declared; all subsequent motion and damage use real orders.
		u.order_stop(); enemy.order_stop()
		u.position=center; enemy.position=center+v*24.0
		u.passive=true;u.auto_micro=false
		u.set_physics_process(true)
		await _wait(0.8)
		u.set_physics_process(false)
		u.animation_direction=d
		b._grid_build()
		await _shot(b,u,key+"_"+d+"_idle")
		var idle := _body(u)
		check(idle.move_blend<=0.3 and idle.lunge<=0.0 and idle.flinch_squared<=1.0,"observed resting state "+key+" "+d)
		check(idle.source.begins_with("res://assets/characters/"+key+"_traits_20261006/"),"observed candidate idle "+key+" "+d)
		var attack_probe := ActionProbe.new()
		attack_probe.subject=u;attack_probe.enemy=enemy;attack_probe.kind="attack";attack_probe.before_hp=enemy.hp
		root.add_child(attack_probe)
		u.set_physics_process(true);u.order_attack(enemy,false,true)
		await _phase_shot(b,u,enemy,key+"_"+d+"_windup",false)
		u.set_physics_process(true)
		for tick in range(600):
			if attack_probe.captured: break
			await physics_frame
		check(attack_probe.captured,"normal melee damage captured "+key+" "+d)
		if attack_probe.captured:
			check(attack_probe.observation.lunge>0.0 and attack_probe.observation.flinch_squared<=1.0,"normal attack priority "+key+" "+d)
			if key=="wu_song":
				check(String(attack_probe.observation.source).contains("_traits_20261006/") and attack_probe.observation.frame_directional,"new Wu actual direction and body "+d)
				check(attack_probe.observation.authored_attack_active and is_zero_approx(attack_probe.observation.programmatic_swing_scale),"new Wu full-authored drawing "+d)
			else:
				check(not String(attack_probe.observation.source).contains("_traits_20261006/"),"Lin existing production action "+d)
			art_runtime.append({"case":"real_melee_hit","actor":key,"direction":d,"observation":attack_probe.observation})
			await _shot(b,u,key+"_"+d+"_attack")
		attack_probe.queue_free()
		u.set_physics_process(true)
		await _phase_shot(b,u,enemy,key+"_"+d+"_attack_late",true)
		# Recover normally, retaining original health and ability values.
		u.order_stop();u.passive=true;u.set_physics_process(true)
		await _wait(0.8)
		u.set_physics_process(false)
		var hurt_probe := ActionProbe.new()
		hurt_probe.subject=u;hurt_probe.enemy=enemy;hurt_probe.kind="hurt";hurt_probe.before_hp=u.hp
		root.add_child(hurt_probe)
		enemy.auto_micro=false;enemy.passive=false;enemy.set_physics_process(true);enemy.order_attack(u,false,true)
		for tick in range(600):
			if hurt_probe.captured: break
			await physics_frame
		check(hurt_probe.captured,"normal counter-hit captured "+key+" "+d)
		if hurt_probe.captured:
			check(hurt_probe.observation.flinch_squared>1.0,"normal hurt priority "+key+" "+d)
			var hurt_frames: Array = root.get_node("Art").unit_anim_frames(key,"hurt",d)
			if hurt_frames.is_empty():
				check(String(hurt_probe.observation.source).contains("_traits_20261006/"),"missing authored hurt retains normal candidate-body fallback "+key+" "+d)
			else:
				if key=="wu_song":
					check(String(hurt_probe.observation.source).contains("_traits_20261006/") and hurt_probe.observation.frame_directional,"new Wu real hurt body and direction "+d)
				else:
					check(not String(hurt_probe.observation.source).contains("_traits_20261006/"),"Lin existing production hurt "+d)
			hurt_probe.observation["authored_hurt_frames"]=hurt_frames.size()
			art_runtime.append({"case":"real_counter_hit","actor":key,"direction":d,"observation":hurt_probe.observation})
			await _shot(b,u,key+"_"+d+"_hurt")
		hurt_probe.queue_free()
		enemy.order_stop();enemy.set_physics_process(false)
		enemy.position=enemy_original_position # End this contact placement fixture before movement.
		b._grid_build()
		u.order_stop();u.passive=true;u.set_physics_process(true)
		await _wait(0.8)
		u.order_move(center+v*90.0)
		# A slow rendered timer may expire before sufficient physics ticks.
		# Observe actual movement rather than manufacturing animation state.
		for tick in range(120):
			if u._move_blend>0.3: break
			await physics_frame
		u.set_physics_process(false)
		await _shot(b,u,key+"_"+d+"_walk")
		var walked := _body(u)
		check(walked.move_blend>0.3 and walked.source.begins_with("res://assets/characters/"+key+"_traits_20261006/"),"normal movement returns candidate "+key+" "+d)
		check(u.atk==original.atk and u.max_hp==original.max_hp and u.base_speed==original.base_speed and u.ability_slots==original.skills,"combat stats/skills remain original "+key+" "+d)
		_freeze_nonparticipants(b)
	await _dispose(b)

func _run() -> void:
	art_output=OS.get_environment("ART_QA_OUT")
	art_visual=OS.get_environment("ART_VISUAL")=="1"
	art_character="ordinary_wu_lin_actions_v6"
	if not _art_profile_guard(): quit(1); return
	root.size=Vector2i(1440,960);root.position=Vector2i(30000,30000);root.unfocusable=true
	check(is_equal_approx(Engine.time_scale,1.0),"normal engine clock")
	_queries()
	await _chapter("lin_chong",2)
	await _chapter("wu_song",7)
	_art_finish()
