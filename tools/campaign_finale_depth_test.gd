extends SceneTree
## GT-1/GT-2/GT-3 bounded gameplay fixtures. Mission actions use the real
## navigation/task callback. Combat is frozen only after an action reaches its
## site so route, finite-force and recoverable-failure boundaries stay stable.

const OUT_DIR := "res://qa/campaign_gameplay_depth_20260901/finale"
var failures: Array[String] = []
var checks := 0
var evidence: Array = []

func _initialize() -> void: _run.call_deferred()

func check(ok: bool,name: String) -> void:
	checks += 1
	print("[finale-depth] ",name," ","PASS" if ok else "FAIL")
	if not ok: failures.append(name)

func _start():
	seed(5088120)
	var campaign=root.get_node("Campaign")
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id=="level5": campaign.current=i
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene=b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	Engine.time_scale=4.0
	return b

func _dispose(b) -> void:
	evidence.append({"stage":b.level.stage,"events":b.mission.events.keys(),"phase":b.phase})
	if current_scene==b: current_scene=null
	b.queue_free()
	await process_frame
	await process_frame

func _act(b,id: String,limit := 1800) -> bool:
	if not b.mission.request_action(id): return false
	var frames:=0
	while b.mission.active_action_id==id and b.phase!=b.Phase.END and frames<limit:
		await process_frame
		frames+=1
	if frames>=limit:
		print("[finale-depth-timeout] ",id," stage=",b.level.stage," actor=",b.mission._actor)
	return frames<limit and b.phase!=b.Phase.END and b.mission.active_action_id==""

func _place(b,u,cell: Vector2i) -> void:
	u.order_stop()
	u.position=b.map.cell_to_world(cell)
	b.map.sync_render_position(u)

func _freeze_units(b) -> void:
	for u in b.units:
		if is_instance_valid(u): u.set_physics_process(false)

func _resolve_live(arr: Array,count := -1,outcome := "subdued") -> int:
	var resolved:=0
	for u in arr:
		if is_instance_valid(u) and u.hp>0.0 and u.story_outcome=="":
			u.resolve_story(outcome)
			resolved+=1
			if count>=0 and resolved>=count: break
	return resolved

func _route_case(side: bool) -> void:
	var b=await _start()
	var l=b.level
	var route_id: String="lure_side" if side else "lure"
	var route_name: String="side" if side else "main"
	var side_path: PackedVector2Array=b.map.find_path(b.map.cell_to_world(l.SIDE_LURE_CELL),b.map.cell_to_world(l.SIDE_RETURN_CELL),0,"water")
	if not side:
		check(b.map.t_at(l.SIDE_AMBUSH_CELL.x,l.SIDE_AMBUSH_CELL.y)==b.map.T.WATER and side_path.size()>0,"side_channel_is_real_connected_water_not_decor")
		check(b.map.is_open_cell(l.SIDE_AMBUSH_CELL,"water") and not b.map.is_open_cell(l.SIDE_AMBUSH_CELL,"land"),"land_army_cannot_enter_side_channel")
		var bank:=Vector2i(31,28)
		check(b.map.is_open_cell(bank,"land") and not b.map.is_open_cell(bank,"water"),"warship_cannot_mount_shore_bow_position")
	check(await _act(b,route_id),route_name+"_lure_action_uses_real_water_navigation")
	var side_orders: int=l.enemy_fleet.filter(func(ship): return ship.get_meta("lure_lane","")=="side").size()
	var main_orders: int=l.enemy_fleet.filter(func(ship): return ship.get_meta("lure_lane","")=="main").size()
	check(l.lure_route==route_name and b.mission.has_event("lure_route_"+route_name),route_name+"_route_choice_recorded_once")
	check((side_orders==3 and main_orders==2) if side else (side_orders==0 and main_orders==5),route_name+"_changes_official_approach_directions")
	# Freeze Liangshan fire so this check observes the official ships' actual route,
	# rather than winning the combat before a live ship reaches the chosen ambush.
	for u in b.units:
		if is_instance_valid(u) and u.faction==0: u.set_physics_process(false)
	var travel_frames:=0
	while not l.lure_complete and b.phase!=b.Phase.END and travel_frames<1800:
		await process_frame
		travel_frames+=1
	check(l.lure_complete and b.mission.has_event("fleet_in_ambush"),route_name+"_requires_live_ship_inside_its_ambush")
	_freeze_units(b)
	check(_resolve_live(l.enemy_fleet)==5,route_name+"_uses_same_finite_five_official_ships")
	l.process(b,0.1)
	check(l.stage=="fire_prepare" and l.enemy_fleet.size()==5 and l.fleet.size()==5,route_name+"_completion_redeploys_finite_second_fleet")
	await _dispose(b)

func _fire_case(point_name: String,with_blocked_withdraw: bool) -> void:
	var b=await _start()
	var l=b.level
	l._start_land(b)
	await process_frame
	check(l.stage=="fire_prepare" and l.enemy_fleet.size()==5 and l.fleet.size()==5 and l.fire_escorts.size()==2,point_name+"_fire_stage_uses_one_existing_fleet_and_two_escorts")
	check(b.map.is_open_world(l.wind_leader.position,"land") and b.map.is_open_world(l.fire_leader.position,"land") and l.fireboat.key=="liu_tang_fireboat",point_name+"_gongsun_and_liu_tang_are_real_onsite_actors")
	check(await _act(b,"raise_wind") and l.fire_wind_ready and b.mission.has_event("gongsun_wind"),point_name+"_gongsun_physically_completes_wind_rite")
	check(await _act(b,"prepare_fireboat") and l.fire_prepared and b.mission.has_event("liu_tang_fire_leader") and l.fire_leader.story_outcome=="embarked" and l.fireboat.get_meta("story_commander","")=="liu_tang",point_name+"_liu_tang_physically_prepares_and_boards_fireboat")
	check(await _act(b,"fire_"+point_name) and l.fire_point==point_name,point_name+"_choice_sails_fireboat_to_connected_chain")
	_freeze_units(b)
	var chosen: Vector2i=l.FIRE_NORTH_CELL if point_name=="north" else l.FIRE_SOUTH_CELL
	_place(b,l.fireboat,l.FIRE_SAFE_CELL)
	l.on_mission_action(b,"ignite_fireboat",l.fireboat)
	check(not l.fire_lit and b.mission.has_event("fire_ignite_blocked"),point_name+"_offsite_ignition_cannot_burn_chain")
	_place(b,l.fireboat,chosen)
	check(await _act(b,"ignite_fireboat") and l.fire_lit and l.stage=="fire_withdraw",point_name+"_onsite_ignition_commits_selected_point")
	var disabled: int=l.enemy_fleet.filter(func(ship): return ship.story_outcome=="subdued").size()
	var remaining: int=l.enemy_fleet.filter(func(ship): return ship.story_outcome=="").size()
	check(disabled==3 and remaining==2 and l.fireboat.story_outcome=="retreated",point_name+"_fire_spreads_to_three_linked_ships_not_whole_map")
	for escort in l.fire_escorts: _place(b,escort,l.FIRE_SAFE_CELL)
	if with_blocked_withdraw:
		var pursuer=l.enemy_fleet.filter(func(ship): return ship.story_outcome=="")[0]
		_place(b,pursuer,l.FIRE_SAFE_CELL+Vector2i(0,-2))
		check(await _act(b,"fire_withdraw") and l.stage=="fire_withdraw" and b.mission.has_event("fire_withdraw_pursued"),"nearby_surviving_ship_blocks_escort_withdrawal")
	check(_resolve_live(l.enemy_fleet,-1,"retreated")==2,"two_surviving_ships_can_be_driven_off_without_new_spawns")
	for escort in l.fire_escorts: _place(b,escort,l.FIRE_SAFE_CELL)
	check(await _act(b,"fire_withdraw") and l.fire_withdrawn and l.stage=="land_ambush",point_name+"_both_escorts_withdraw_then_land_fight_only_closes_act")
	await _dispose(b)

func _fireboat_loss_case() -> void:
	var b=await _start()
	b.level._start_land(b)
	await process_frame
	b.level.fireboat.take_damage(1000000.0,null,true,true)
	b.level.process(b,0.1)
	await process_frame
	check(b.phase==b.Phase.FIGHT and b.level.stage=="fire_direct" and not b.level.fire_lit and b.mission.story_goals.gao_fire.state==b.mission.STORY_MISSED,"unique_fireboat_loss_forfeits_only_story_seal_and_opens_direct_battle")
	_resolve_live(b.level.enemy_fleet)
	b.level.process(b,0.1)
	check(b.phase==b.Phase.FIGHT and b.level.stage=="land_ambush","surviving_fleet_can_finish_second_invasion_after_fireboat_loss")
	await _dispose(b)

func _to_safe_scuttle(b,hard_rush: bool) -> bool:
	var l=b.level
	l._start_final_fleet(b)
	await process_frame
	if not await _act(b,"sortie"): return false
	_freeze_units(b)
	_place(b,l.flagship,l.FINAL_FLAG_CELL)
	if hard_rush:
		check(not b.mission.actions.has("seal_port"),"seal_port_task_is_not_exposed_before_three_escorts_are_suppressed")
		var zhang=b.find_unit("zhang_shun_boat")
		_place(b,zhang,l.FINAL_SCUTTLE_CELL)
		if not await _act(b,"scuttle"): return false
		var aimed: int=l.enemy_fleet.filter(func(ship): return ship.story_outcome=="" and ship._target==zhang).size()
		check(l.stage=="final_fleet" and l.hard_rushes==1 and aimed==5,"zhang_hard_rush_draws_all_existing_escorts_and_is_recoverable")
	if _resolve_live(l.enemy_fleet,3)!=3: return false
	l.process(b,0.1)
	if not l.escort_suppressed: return false
	if hard_rush:
		check(b.mission.actions.has("seal_port"),"seal_port_task_opens_when_the_three_escort_threshold_is_reached")
	var seal_actor=b.find_unit("ruan_xiaoer_boat")
	_place(b,seal_actor,l.FINAL_SEAL_CELL)
	b.selection=[seal_actor]
	if not await _act(b,"seal_port"): return false
	var remaining: int=l.enemy_fleet.filter(func(ship): return ship.story_outcome=="retreated").size()
	check(l.port_sealed and l.flagship.base_speed==0.0 and l.flagship.story_outcome=="subdued" and remaining==2,"three_escort_suppression_plus_port_seal_disables_flagship_and_retires_two")
	var zhang=b.find_unit("zhang_shun_boat")
	zhang.set_physics_process(true)
	b.selection=[zhang]
	return await _act(b,"scuttle") and l.stage=="water_rescue"

func _vanguard_composition_case() -> void:
	var b=await _start()
	var l=b.level
	l._start_final_fleet(b)
	await process_frame
	var vanguards: Array=l.enemy_fleet.filter(func(ship): return is_instance_valid(ship) and ship.key=="official_vanguard")
	var ordinary: Array=l.enemy_fleet.filter(func(ship): return is_instance_valid(ship) and ship.key=="imperial_warship")
	check(l.stage=="final_fleet" and l.enemy_fleet.size()==5 and is_instance_valid(l.flagship) and l.flagship.key=="gao_flagship","finale_keeps_five_compressed_front_ships_plus_separate_gao_center")
	check(is_instance_valid(l.flagship) and String(l.flagship.get_meta("campaign_flag_context",""))=="chapter80_gao_flagship","gao_command_flag_is_bound_only_to_chapter80_flagship_context")
	check(vanguards.size()==1 and ordinary.size()==4,"finale_replaces_one_regular_ship_with_one_vanguard_headship")
	if vanguards.size()==1:
		var vanguard=vanguards[0]
		check(l.vanguard_headship==vanguard and String(vanguard.setup_def.get("campaign_object",""))=="official_vanguard","vanguard_headship_reference_and_own_campaign_object_are_bound")
		check(String(vanguard.get_meta("campaign_flag_context",""))=="chapter80_vanguard_headship" and vanguard._campaign_flag_object_key()=="official_vanguard","vanguard_pair_flag_is_bound_only_to_chapter80_headship_context")
	else:
		check(false,"vanguard_headship_reference_and_own_campaign_object_are_bound")
		check(false,"vanguard_pair_flag_is_bound_only_to_chapter80_headship_context")
	check(ordinary.all(func(ship): return ship._campaign_flag_object_key().is_empty()),"ordinary_finale_official_ships_remain_unlettered")
	l._reset_section(b)
	await process_frame
	check(l.vanguard_headship==null and l.enemy_fleet.is_empty(),"section_reset_clears_vanguard_headship_and_context_owner")
	await _dispose(b)

func _final_recovery_case() -> void:
	var b=await _start()
	check(await _to_safe_scuttle(b,true),"hard_rush_can_be_repaired_then_real_scuttle_opens_water_rescue")
	check(b.mission.has_event("escort_suppressed") and b.mission.has_event("port_sealed") and b.mission.has_event("flagship_scuttled"),"suppression_seal_scuttle_chain_has_visible_events")
	await _dispose(b)

func _legacy_failure_case(case_name: String) -> void:
	var b=await _start()
	var ready:=true
	var passed:=false
	match case_name:
		"lure_loss":
			b.find_unit("ruan_xiaoqi_boat").take_damage(1000000.0,null,true,true)
			b.level.process(b,0.1)
			ready=b.phase==b.Phase.FIGHT and b.level.first_direct and b.mission.has_event("gao_first_direct") and b.mission.story_goals.gao_lure.state==b.mission.STORY_MISSED
			_resolve_live(b.level.enemy_fleet)
			b.level.process(b,0.1)
			passed=ready and b.phase==b.Phase.FIGHT and b.level.stage=="fire_prepare"
		"specialist_loss":
			b.level._start_final_fleet(b)
			await process_frame
			b.find_unit("zhang_shun_boat").take_damage(1000000.0,null,true,true)
			b.level.process(b,0.1)
			ready=b.phase==b.Phase.FIGHT and b.level.final_direct and b.level.lure_started \
				and b.mission.has_event("gao_capture_route_lost") and b.mission.has_event("gao_final_direct") \
				and b.mission.story_goals.gao_capture.state==b.mission.STORY_MISSED
			_freeze_units(b)
			b.level.flagship.resolve_story("subdued")
			passed=ready and b.phase==b.Phase.END and b.mission.has_event("flagship_repelled") and not b.mission.has_event("gao_captured")
		"rescue_loss", "return_loss":
			ready=await _to_safe_scuttle(b,false)
			if ready and case_name=="return_loss":
				var zhang=b.find_unit("zhang_shun_boat")
				b.selection=[zhang]
				ready=await _act(b,"recover_gao") and b.level.stage=="return_prisoner"
			if ready:
				b.find_unit("zhang_shun_boat").take_damage(1000000.0,null,true,true)
				b.level.process(b,0.1)
			passed=ready and b.phase==b.Phase.END and b.mission.has_event("gao_escaped") and not b.mission.has_event("gao_captured") and b.mission.story_goals.gao_capture.state==b.mission.STORY_MISSED
	await process_frame
	await process_frame
	check(passed,"former_"+case_name+"_loss_is_recoverable_or_settles_base_victory")
	await _dispose(b)

func _restart_case() -> void:
	var b=await _start()
	var l=b.level
	check(l.stage=="water_lure" and l.lure_route=="" and not l.fire_wind_ready and not l.fire_prepared and not l.fire_lit and not l.fire_withdrawn,"restart_clears_route_wind_and_fireboat_state")
	check(not l.port_sealed and not l.escort_suppressed and l.hard_rushes==0 and not l.transfer_done and not l.recovered_gao,"restart_clears_finale_seal_rescue_and_transfer_state")
	await _dispose(b)

func _write_report() -> void:
	var absolute:=ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	if checks!=59: failures.append("expected_59_checks_got_%d"%checks)
	var result:={"passed":failures.is_empty(),"checks":checks,"expected_checks":59,"failures":failures,"evidence":evidence,
		"scope":"GT-1 connected two-route water approach, GT-2 Gongsun Sheng wind rite plus Liu Tang finite linked fireboat and escort withdrawal, GT-3 chapter80 one-vanguard-plus-four-ordinary compressed front squad, suppression/seal/scuttle recovery plus legacy losses",
		"fixture_boundary":"Every task action reaches its real map cell through CampaignMission. Units are frozen only after arrival for deterministic finite-force boundary checks; no HP, stats or spawn counts are tuned. Explicit take_damage appears only in named loss cases."}
	var file:=FileAccess.open(OUT_DIR+"/depth_contract.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")+"\n")
	print("[finale-depth-result] ",JSON.stringify(result))

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").auto_micro_level=0
	AudioServer.set_bus_mute(0,true)
	await _route_case(false)
	await _route_case(true)
	await _fire_case("north",true)
	await _fire_case("south",false)
	await _fireboat_loss_case()
	await _vanguard_composition_case()
	await _final_recovery_case()
	for case_name in ["lure_loss","specialist_loss","rescue_loss","return_loss"]:
		await _legacy_failure_case(case_name)
	await _restart_case()
	_write_report()
	Engine.time_scale=1.0
	quit(0 if failures.is_empty() else 1)
