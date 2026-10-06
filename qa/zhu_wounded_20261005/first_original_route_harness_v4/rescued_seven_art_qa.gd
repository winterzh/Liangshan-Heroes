extends "res://tools/art_character_direction4_qa.gd"
## Opening inventory uses the registered runtime chapters, not legacy LEVEL_SPECS.
## Zhu contacts/combat positions and frozen nonparticipants are explicit fixtures.
var opening_rows: Array = []

func _frame_record(frame) -> Dictionary:
	if frame == null: return {"present":false}
	var row := {"present":true,"source":_texture_source(frame),"pose":_texture_pose(frame)}
	if frame is AtlasTexture:
		row["authored_direction4"] = frame.get_meta("authored_direction4",false)
	return row

func _opening_inventory() -> void:
	var campaign = root.get_node("Campaign")
	var art = root.get_node("Art")
	var proof_path := "res://tools/contracts/current_campaign_opening_20261005/snapshot.json"
	if FileAccess.file_exists(proof_path):
		var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(proof_path))
		var same_inputs: bool = art_identity_before.get("source_sha256","")==proof.installed_source_sha256
		for path in proof.input_sha256:
			if FileAccess.get_sha256("res://"+path)!=proof.input_sha256[path]:same_inputs=false
		for path in proof.source_evidence_sha256:
			if FileAccess.get_sha256("res://"+path)!=proof.source_evidence_sha256[path]:same_inputs=false
		if same_inputs:
			check(proof.opening_checks_passed and proof.openings.size()==8,"prior eight-opening subcase passed with identical frozen inputs")
			for i in range(8):
				check(proof.openings[i].chapter==campaign.LEVELS[i].id and proof.openings[i].registered_script==campaign.LEVELS[i].script,"reused opening belongs to current registration "+str(i))
			opening_rows=proof.openings;art_rows=opening_rows
			art_runtime.append({"case":"opening_evidence_reuse","same_installed_source_identity":true,"all_input_hashes_unchanged":true,"evidence_hashes_verified":true,"source_report":proof.source_report,"scope":"Previously passed opening subcase; earlier whole run failed later evacuation. No fresh opening rendering claim."})
			return
	for i in range(campaign.LEVELS.size()):
		var b = await _start("",i)
		_freeze_nonparticipants(b)
		var spec: Dictionary = campaign.LEVELS[i]
		check(b.level.get_script().resource_path==spec.script and b.phase==b.Phase.FIGHT,"registered chapter actually started "+spec.id)
		check(b._gameplay_rng_issue.is_empty(),"opening RNG/entity creation intact "+spec.id)
		var rows: Array = []
		var identities := {}
		for u in b.units:
			check(is_instance_valid(u) and not u.key.is_empty(),"opening original unit key "+spec.id+" "+u.key)
			var identity: String = u.key+"|"+u.art_variant+"|"+str(u.faction)
			if identities.has(identity):
				rows[identities[identity]].count += 1
				continue
			identities[identity]=rows.size()
			var row := {"key":u.key,"variant":u.art_variant,"faction":u.faction,"count":1,
				"is_building":u.is_building,"is_resource":u.is_resource,"is_noncombat":u.is_noncombat,
				"is_captive":u.is_captive,"is_hero":u.is_hero,"portrait":_frame_record(u.ui_portrait_texture()),
				"observed_body":_frame_record(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction)),
				"queries":[],"production_keys":u.setup_def.get("produces",[]),"abilities":u.ability_slots.duplicate()}
			if not u.is_building and not u.is_resource:
				for d in ART_DIRS:
					for state in ["idle","walk","attack","hurt","death","down"]:
						var frames: Array = art.unit_anim_frames(u.key,state,d,u.visual_art_variant())
						row.queries.append({"state":state,"direction":d,"frames":frames.size(),
							"first":_frame_record(frames[0] if not frames.is_empty() else null),
							"directional_route":art.unit_anim_uses_directional_source(u.key,state,d,u.visual_art_variant()),
							"scope":"resource lookup only, not an observed action or visual acceptance"})
			rows.append(row)
		opening_rows.append({"chapter":spec.id,"registered_script":spec.script,"units":rows,
			"original_unit_count":b.units.size(),"mission_actions":b.mission.actions.keys(),
			"story_goals":b.level.campaign_story_goals(),"scope":"Actual opening deployment and resource queries; delayed spawns/phase changes remain unobserved."})
		await _dispose(b)
	check(opening_rows.size()==8,"all eight current registered openings inventoried")
	art_rows=opening_rows

func _contact(b, actor, action_id: String) -> bool:
	var action: Dictionary = b.mission.actions[action_id]
	actor.position=b.map.cell_to_world(action.cell) # Contact placement fixture; timed action remains normal.
	actor.passive=true;actor.auto_micro=false;actor.set_physics_process(true)
	b._grid_build();_action(b,actor,action_id)
	for tick in range(160):
		if action.done:break
		await _wait(0.1)
	check(action.done,"normal player command and timed callback "+action_id)
	actor.set_physics_process(false)
	return action.done

func _wait_members(b, members: Array, cell: Vector2i, radius: float) -> bool:
	var target: Vector2 = b.map.cell_to_world(cell)
	var hit = b._enemy_at(b.to_screen(target))
	check(hit==null,"evacuation ground click does not target an enemy "+str(cell))
	if hit!=null:
		art_runtime.append({"case":"evacuation_order_blocked_by_fixture","cell":[cell.x,cell.y],"enemy":hit.key})
		return false
	_click(b,members,cell)
	for tick in range(480):
		if members.all(func(u):return alive(u) and u.position.distance_to(target)<radius and (cell!=Vector2i(52,29) or u.position.distance_to(b.level.hall.position)<190)):return true
		# New background training is still real, but its actors join the nonparticipant fixture.
		for u in b.units:
			if u not in members and is_instance_valid(u):u.passive=true;u.set_physics_process(false)
		await _wait(0.25)
	art_runtime.append({"case":"evacuation_timeout","cell":[cell.x,cell.y],"members":members.map(func(u):return {"key":u.key,"position":[u.position.x,u.position.y],"target_distance":u.position.distance_to(target),"state":u._state})})
	return false

func _clear_inner_defenders(b) -> void:
	# Frozen enemies are still real collision blockers. Clear them with original
	# Lin Chong's ordinary attacks instead of teleporting evacuees or removing foes.
	var fighter = b.find_unit("lin_chong")
	check(alive(fighter),"original Lin Chong available for actual route clearance")
	if not alive(fighter):return
	var defenders: Array = b.units.filter(func(u):return alive(u) and u.faction==1 and not u.is_building and not u.is_resource and not u.is_worker and u.position.x<b.map.cell_to_world(Vector2i(19,0)).x)
	for guard in b.level.resource_guards:
		if alive(guard) and guard not in defenders:defenders.append(guard)
	for enemy in defenders:
		var hp_before: float = enemy.hp
		var key: String = enemy.key
		var instance: int = enemy.get_instance_id()
		fighter.position=enemy.position+Vector2(24,0) # Explicit melee contact fixture only.
		fighter.auto_micro=false;fighter.set_physics_process(true)
		b._grid_build();b.select_members([fighter],false);b.minimap_order(enemy.position,false);orders+=1
		for tick in range(480):
			if not alive(enemy):break
			await _wait(0.25)
		check(not alive(enemy),"original Lin ordinary attack clears inner defender "+key+" "+str(instance))
		art_runtime.append({"case":"ordinary_defender_clearance","key":key,"original_instance":instance,"original_hp":hp_before,"normal_player_attack":true,"damage_injected":false,"actor_injected":false,"attacker_contact_fixture":true,"defender_frozen":true,"cleared":not alive(enemy)})
		fighter.order_stop();fighter.set_physics_process(false)
	check(not b.level.manor_fallen and alive(b.level.enemy_base),"inner clearance retains real manor core and no victory")

func _zhu_evacuation() -> void:
	var b = await _start("",2)
	_freeze_nonparticipants(b)
	b.fog=false
	if is_instance_valid(b._fog_layer):b._fog_layer.hide()
	var l = b.level
	var art = root.get_node("Art")
	var ids: Array = l.prisoners.map(func(u):return u.get_instance_id())
	var shi = l.prisoners[1]
	var before: Dictionary = {"hp":shi.hp,"portrait":_texture_pose(shi.ui_portrait_texture())}
	var prior_portraits := {}
	for u in l.prisoners: prior_portraits[u.key] = _texture_pose(u.ui_portrait_texture())
	check(shi.key=="shi_xiu" and shi.art_variant=="bound_shi_xiu" and shi.is_captive,"current original Shi Xiu bound deployment")
	for d in ART_DIRS:
		shi.animation_direction=d;shi.face_left=d in ["sw","nw"]
		var f = shi._anim_frame_for_state(art.unit_texture(shi.key,shi.art_variant,d))
		check(not art.unit_anim_frames(shi.key,"idle",d,shi.art_variant).is_empty() and shi._frame_directional,"Shi Xiu existing dedicated bound direction "+d)
		art_runtime.append({"case":"shi_xiu_bound","direction":d,"frame":_frame_record(f),"portrait":_frame_record(shi.ui_portrait_texture())})
		shi.queue_redraw();await _art_screenshot(b,"shi_xiu_bound_current_"+d,shi)
	if not await _contact(b,l.song,"zhu_rts_recon"):await _dispose(b);return
	check(is_instance_valid(l.sun) and b.mission.actions.has("zhu_rts_inside"),"normal recon introduces original Sun Li")
	if not await _contact(b,l.sun,"zhu_rts_inside"):await _dispose(b);return
	check(l.inside_open and l.side_gate.story_outcome=="retreated" and b.mission.has_event("zhu_gate_opened"),"normal inside callback opens actual gate navigation")
	if not await _contact(b,l.song,"zhu_rts_rescue"):await _dispose(b);return
	check(l.prisoners_freed and ids==l.prisoners.map(func(u):return u.get_instance_id()),"normal rescue retains all seven original captives")
	await _rescued_routes(b,prior_portraits)
	for d in ART_DIRS:
		shi.animation_direction=d;shi.face_left=d in ["sw","nw"];shi._move_blend=1.0;shi._anim_t=0.0
		var f = shi._anim_frame_for_state(art.unit_texture(shi.key,shi.visual_art_variant(),d))
		check(shi.art_variant.is_empty() and shi.hp==before.hp and _texture_pose(shi.ui_portrait_texture())==before.portrait,"Shi Xiu rescued original HP portrait and scoped unarmed body "+d)
		art_runtime.append({"case":"shi_xiu_rescued","direction":d,"frame":_frame_record(f),"directional":shi._frame_directional,"portrait":_frame_record(shi.ui_portrait_texture())})
		shi.queue_redraw();await _art_screenshot(b,"shi_xiu_rescued_current_"+d,shi)
	await _clear_inner_defenders(b)
	if not failures.is_empty():await _dispose(b);return
	var members: Array = l.prisoners.duplicate()
	var starts := {}
	for u in members:
		starts[u.key]=u.position
		u._move_blend=0.0;u.set_physics_process(true)
	check(not l._finish_ready() and not b.mission.has_event("zhu_seven_safe"),"rescue alone does not award safe return")
	# Existing map routes through the genuinely opened side gate. No captive teleport.
	for cell in [Vector2i(16,23),Vector2i(25,18),Vector2i(43,18),Vector2i(52,29)]:
		var reached := await _wait_members(b,members,cell,105.0)
		check(reached,"all original seven normal player movement waypoint "+str(cell))
		await _art_screenshot(b,"seven_evac_"+str(cell.x)+"_"+str(cell.y),members[0])
		if not reached:await _dispose(b);return
	for u in members:
		check(alive(u) and not u.is_captive and u.is_noncombat and u.atk==0 and u.ability_slots.is_empty() and u.position.distance_to(l.hall.position)<190,"same original wounded actor actually back near camp "+u.key)
		art_runtime.append({"case":"seven_actual_return","key":u.key,"same_actor":u.get_instance_id() in ids,
			"distance_moved":u.position.distance_to(starts[u.key]),"camp_distance":u.position.distance_to(l.hall.position),
			"actor_teleported":false,"player_movement":true,"variant":u.art_variant,"visual_variant":u.visual_art_variant(),"noncombat":u.is_noncombat})
	check(not l.manor_fallen and not l._finish_ready() and not b.mission.has_event("zhu_seven_safe"),"return before manor destruction still cannot settle")
	art_runtime.append({"case":"evacuation_scope","contact_position_fixture":true,"nonparticipants_frozen":true,
		"prisoners_injected_or_teleported":false,"gate_opened_by_normal_timed_action":true,"inner_defenders_cleared_by_normal_attacks":true,"manor_combat_or_full_victory":false,"time_scale":Engine.time_scale})
	await _dispose(b)

func _run() -> void:
	if not _art_profile_guard():quit(2);return
	AudioServer.set_bus_mute(0,true);Engine.time_scale=1.0
	art_character="rescued_seven_current";art_manifest_path=OS.get_environment("ART_MANIFEST");art_output=OS.get_environment("ART_QA_OUT");art_visual=OS.get_environment("ART_VISUAL")=="1"
	check(art_output.is_absolute_path(),"external output")
	DirAccess.make_dir_recursive_absolute(art_output)
	art_manifest=JSON.parse_string(FileAccess.get_file_as_string(art_manifest_path))
	if art_visual:
		root.unfocusable=true;root.size=Vector2i(1440,960);root.content_scale_size=root.size;DisplayServer.window_set_size(root.size)
	await process_frame
	art_identity_before=_art_identity()
	await _opening_inventory()
	if failures.is_empty():await _zhu_evacuation()
	art_identity_after=_art_identity()
	check(art_identity_before.get("source_sha256")==art_identity_after.get("source_sha256"),"identity stable across current eight openings and original evacuation")
	_art_finish()

func _rescued_routes(b, prior_portraits: Dictionary) -> void:
	var art = root.get_node("Art")
	var l = b.level
	var registry = load("res://scripts/campaign_art.gd")
	for u in l.prisoners:
		var v: String = "zhu_wounded_" + u.key
		check(u.visual_art_variant()==v and u.art_variant.is_empty(),"derived original rescued role with legacy empty save field "+u.key)
		check(u.hp==110 and u.max_hp==110 and u.base_speed==82 and u.atk==0 and not u.is_hero and u.is_noncombat and u.ability_slots.is_empty(),"rescue preserves original noncombat stats "+u.key)
		for d in ART_DIRS:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			var idle: Array = art.unit_anim_frames(u.key,"idle",d,v)
			var walk: Array = art.unit_anim_frames(u.key,"walk",d,v)
			check(idle.size()==1 and walk.size()==4,"original resolver has one idle and four authored walk phases "+u.key+" "+d)
			if idle.is_empty() or walk.size()!=4: continue
			var expected: String = registry.native_body_path(v,"idle",d)
			check(expected.contains(registry.NATIVE_WOUNDED_FAMILIES[u.key]) and art.campaign_variant_has_direction(v,d) and art.campaign_variant_has_animation(v,"walk",d),"matching family and exact authored direction "+u.key+" "+d)
			u._move_blend=0.0
			var f = u._anim_frame_for_state(art.unit_texture(u.key,v,d))
			check(_texture_pose(f)==_texture_pose(idle[0]) and u._frame_directional,"original idle draw has native frame and no mirror "+u.key+" "+d)
			for i in range(4):
				u._move_blend=1.0;u._anim_t=(i+0.1)*TAU/4.0
				f=u._anim_frame_for_state(art.unit_texture(u.key,v,d))
				check(_texture_pose(f)==_texture_pose(walk[i]) and u._frame_directional,"original walk draw authored phase "+u.key+" "+d+" "+str(i))
			check(_texture_pose(art.unit_anim_frames(u.key,"hurt",d,v)[0])==_texture_pose(idle[0]) and not art.campaign_variant_has_animation(v,"hurt",d),"hurt uses same standing body without separate animation claim "+u.key+" "+d)
			for state in ["attack","gather","assisted","death","down"]:
				check(art.unit_anim_frames(u.key,state,d,v).is_empty(),"unarmed missing state rejects armed fallback "+u.key+" "+d+" "+state)
			var rest = u._rest_frame(art.unit_texture(u.key,v,d))
			check(_texture_pose(rest)==_texture_pose(walk[1]) and u._frame_directional,"procedural terminal rest retains unarmed authored direction "+u.key+" "+d)
			var same: bool = _texture_pose(u.ui_portrait_texture())==prior_portraits[u.key]
			check(same,"rescued selection UI retains standard owner portrait "+u.key+" "+d)
			check(art.unit_anim_frames("lin_chong","walk",d,v).is_empty() and art.unit_texture("lin_chong",v,d)==null and art.ui_portrait_texture("lin_chong",v)==null,"cross-owner resource and UI rejected "+u.key+" "+d)
			art_runtime.append({"case":"rescued_native_route","key":u.key,"direction":d,"variant":v,"idle":_frame_record(idle[0]),"walk":walk.map(func(x):return _frame_record(x)),"same_portrait":same,"directional":u._frame_directional,"sampled_phases_fixture":true})
		check(art.unit_anim_frames(u.key,"walk","east",v).is_empty() and art.unit_texture(u.key,v,"east")==null,"invalid direction does not borrow another view "+u.key)
		# Role exclusions are reversible query fixtures on the original actor.
		u.is_noncombat=false;check(u.visual_art_variant().is_empty(),"combat role excluded "+u.key);u.is_noncombat=true
		var index: int = l.prisoners.find(u)
		l.prisoners.remove_at(index);check(u.visual_art_variant().is_empty(),"same-key nonmember excluded "+u.key);l.prisoners.insert(index,u)
		u.art_variant="bound_"+u.key;check(u.visual_art_variant()==u.art_variant,"explicit story variant retains priority "+u.key);u.art_variant=""
		u._move_blend=0.0;u._anim_t=0.0
	for d in ART_DIRS:
		for u in l.prisoners: u.animation_direction=d;u.face_left=d in ["sw","nw"];u.queue_redraw()
		await _art_screenshot(b,"seven_rescued_native_"+d,l.prisoners[0])
	var positions: Array = l.prisoners.map(func(u):return u.position)
	l.activate_mission_button(b,"zhu_select_shi_qian")
	check(b.selection.size()==1 and b.selection[0]==l.prisoners[0],"actual mission button selects original Shi Qian")
	l.activate_mission_button(b,"zhu_select_rescued")
	check(b.selection.size()==7 and l.prisoners.all(func(u):return u in b.selection),"actual mission button selects seven original evacuees")
	check(positions==l.prisoners.map(func(u):return u.position),"selection buttons do not teleport evacuees")
