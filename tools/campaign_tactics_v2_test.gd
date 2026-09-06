extends SceneTree
## Authored interaction paths plus explicit placement/damage fixtures for tactical edge cases.
var failures: Array[String] = []
var assertions := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions+=1
	print("[tactics-v2] ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _start(id: String):
	seed(5088120)
	var c=root.get_node("Campaign")
	c.current=c.index_for_id(id)
	c.arena=false; c.skirmish=false; c.skirmish_ai=false; c.scenario=false; c.custom_defense=false
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b); current_scene=b
	await process_frame
	b.hud._intro_root.hide(); b._on_intro_done(); b.hud._on_start_pressed()
	Engine.time_scale=4.0
	return b
func _dispose(b) -> void:
	b.queue_free(); await process_frame; await process_frame
func _action(b,id: String,event: String,limit := 1800) -> bool:
	if not b.mission.request_action(id): return false
	for i in range(limit):
		await process_frame
		if b.mission.has_event(event): return true
		if b.phase==b.Phase.END: return false
	return false
func _hooks(b) -> Array:
	return b.units.filter(func(u): return is_instance_valid(u) and u.faction==0 and u.key in ["xu_ning","gou_lian"])
func _place(u,pos: Vector2) -> void:
	u.order_stop(); u.position=pos; u._stun_t=0.0; u._disarm_t=0.0
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").auto_micro_level=0
	AudioServer.set_bus_mute(0,true)
	var b=await _start("level3")
	check(b.lit_cells.is_empty(),"unexplored route is not highlighted at start")
	b.level.on_ability(b,b.level.shi,"shi_xiu_path",Vector2.ZERO)
	check(b.lit_cells.is_empty(),"route ability cannot reveal unobserved turns")
	check(await _action(b,"zhu_white_poplar","zhu_route_known"),"Shi Xiu actually walks to identify white poplar")
	check(b.lit_cells.has(b.level.FORK2_CELL) and not b.lit_cells.has(b.level.FORK3_CELL) and not b.lit_cells.has(b.level.GATE_CELL),"only first explored route section is highlighted")
	check(await _action(b,"zhu_recon_gate","zhu_gate_scouted"),"Shi Xiu actually scouts next turn")
	check(b.lit_cells.has(b.level.FORK3_CELL) and not b.lit_cells.has(b.level.GATE_CELL) and not b.lit_cells.has(b.level.COURT_CELL),"scouting extends route without revealing gate or courtyard")
	await _dispose(b)
	b=await _start("level3")
	b.level._second_day(b)
	check(b.level.stage=="second" and b.level.second_spears.size()==4 and b.level.second_spears.all(func(u): return u.passive) and ["zhu_song_safe","zhu_lin_intercept","zhu_hua_cover"].all(func(id): return b.mission.actions.has(id)),"second attack starts with four held spears and three separate spatial assignments")
	check(await _action(b,"zhu_song_safe","zhu_song_safe"),"Song Jiang actually reaches the protected retreat point")
	check(await _action(b,"zhu_lin_intercept","zhu_lin_intercept"),"Lin Chong actually reaches the intercept point")
	check(await _action(b,"zhu_hua_cover","zhu_hua_cover") and b.mission.has_event("zhu_second_formation"),"Hua Rong's actual cover action completes the three-part formation")
	check(b.level._role_at(b,b.level.song,b.level.SECOND_SONG_SAFE) and b.level._role_at(b,b.level.lin,b.level.SECOND_LIN_INTERCEPT) and b.level._role_at(b,b.level.hua,b.level.SECOND_HUA_COVER),"second attack opens only while all three roles remain in place")
	await _dispose(b)
	b=await _start("level3")
	b.level._third_day(b)
	check(b.level.stage=="infiltrate" and b.map.world_to_cell(b.level.sun.position).x>=24,"Sun Li starts outside the closed manor")
	check(not b.mission.request_action("zhu_free_prisoners") and not b.mission.request_action("zhu_open_gate"),"cannot rescue or open gate before admission")
	check(await _action(b,"zhu_enter_manor","zhu_sun_entered"),"Sun Li walks to gate and completes identity admission")
	check(b.level.stage=="inside" and b.map.world_to_cell(b.level.sun.position).x<19 and b.map.world_to_cell(b.level.gu.position).x<19,"only admitted guests enter the manor")
	check(not b.map.is_open_world(b.level.gate.position,"land") and b.map.world_to_cell(b.level.song.position).x>23,"admission keeps gate closed to outside army")
	check(not b.mission.request_action("zhu_enter_manor") and b.level.prisoners.size()==7 and b.level.prisoners.all(func(u): return u.is_captive),"admission does not repeat or auto-release prisoners")
	check(b.mission.actions.zhu_free_prisoners.actors==["gu_dasao"] and b.mission.actions.zhu_inner_support.actors==["sun_li"] and b.mission.actions.zhu_outer_position.actors==["song_jiang"],"inside rescue inner support and outside command are assigned to distinct named actors")
	check(await _action(b,"zhu_free_prisoners","zhu_prisoners_freed"),"inside rescue requires a separate actual interaction")
	check(b.level.prisoner_groups.size()==2 and b.level.prisoner_groups[0].size()==4 and b.level.prisoner_groups[1].size()==3,"seven prisoners withdraw as authored groups of four and three")
	check(not b.map.is_open_world(b.level.gate.position,"land"),"rescuing prisoners still does not auto-open gate")
	check(await _action(b,"zhu_inner_support","zhu_inner_support_ready"),"Sun Li separately occupies the inner gate support point")
	check(await _action(b,"zhu_outer_position","zhu_outer_ready"),"Song Jiang separately positions the outside army")
	check(await _action(b,"zhu_open_gate","zhu_gate_opened"),"Sun Li walks to the inner gate and opens it")
	check(b.level.stage=="inside" and not b.level.assault_started and b.level.gate.story_outcome=="retreated","opening the gate does not auto-start the pincer")
	var group_wait:=0
	while not (b.mission.has_event("zhu_prison_group_a_safe") and b.mission.has_event("zhu_prison_group_b_safe")) and group_wait<1200:
		await process_frame
		group_wait+=1
	check(group_wait<1200 and b.level._group_at_rally(b,b.level.prisoner_groups[0],b.level.PRISON_RALLY_A) and b.level._group_at_rally(b,b.level.prisoner_groups[1],b.level.PRISON_RALLY_B),"both prisoner groups physically reach their separate inner-court rallies")
	check(await _action(b,"zhu_attack_signal","zhu_assault_ordered"),"Song Jiang issues a separate attack signal after inner and outer work is ready")
	check(b.level.stage=="assault" and b.level.assault_started,"admission rescue support opening and command lead to assault in order")
	await _dispose(b)
	b=await _start("level4")
	check(await _action(b,"lhm_drill","lhm_drill_started"),"Xu Ning actually performs first teaching action")
	check(not is_instance_valid(b.level.dummy) and not b.mission.request_action("lhm_to_battle"),"no target or transition before a partner joins")
	check(await _action(b,"lhm_partner","lhm_drill_pair_ready"),"a hook soldier actually joins the training pair")
	var members: Array=_hooks(b)
	var far: Vector2=b.map.cell_to_world(Vector2i(6,55))
	for u in members: _place(u,far)
	_place(b.level.xu,b.level.dummy.position+Vector2(-32,0))
	b.level.dummy.take_damage(1000000.0,b.level.xu)
	check(not b.mission.has_event("lhm_drill_complete") and not b.mission.actions.lhm_partner.done,"solo target defeat fails training but leaves retry available")
	var partner=members.filter(func(u): return u.key=="gou_lian")[0]
	_place(partner,b.map.cell_to_world(b.level.DRILL_CELL)+Vector2(0,32))
	check(b.mission.request_action("lhm_partner"),"training partner inspection can be retried")
	b.mission.tick(2.1)
	check(is_instance_valid(b.level.dummy) and b.level.dummy.story_outcome=="","retry sets a fresh practice target without restarting chapter")
	check(await _action(b,"lhm_training_lure","lhm_training_lure_entered"),"Tang Long actually enters the drill route to draw the practice rider")
	b.level.dummy.take_damage(1000000.0,b.level.xu)
	check(not b.mission.has_event("lhm_drill_complete") and not b.mission.actions.lhm_partner.done,"paired strike before the lure withdraws is refused and remains retryable")
	_place(b.level.xu,b.map.cell_to_world(b.level.DRILL_CELL)+Vector2(-32,0))
	_place(partner,b.map.cell_to_world(b.level.DRILL_CELL)+Vector2(32,0))
	check(b.mission.request_action("lhm_partner"),"training can rebuild the practice target after a premature paired strike")
	_place(b.mission._actor,b.map.cell_to_world(b.level.DRILL_CELL+Vector2i(0,1)))
	b.mission.tick(2.1)
	check(b.mission.request_action("lhm_training_lure"),"lure action can be retried without restarting the chapter")
	_place(b.mission._actor,b.map.cell_to_world(b.level.DRILL_LURE_ENTRY))
	b.mission.tick(1.3)
	_place(b.level.training_lure,b.map.cell_to_world(b.level.DRILL_LURE_RETREAT))
	_place(b.level.dummy,b.map.cell_to_world(b.level.DRILL_CELL))
	b.level.process(b,0.01)
	check(b.level.training_lure_withdrew and b.mission.has_event("lhm_training_lure_withdrew"),"lure reaches the safe point outside the drill strike lane")
	b.level.dummy.take_damage(1000000.0,b.level.xu)
	check(b.mission.has_event("lhm_drill_complete") and b.kills==0,"withdrawn lure plus paired strike completes teaching without a kill")
	await _dispose(b)
	b=await _start("level4")
	b.level._deploy_battle(b)
	members=_hooks(b)
	far=b.map.cell_to_world(Vector2i(6,55))
	for u in members: _place(u,far)
	var west: Vector2=b.map.cell_to_world(b.level.REED_W)
	var south: Vector2=b.map.cell_to_world(b.level.REED_S)
	_place(members[0],west)
	check(b.mission.request_action("lhm_west_ambush"),"single gunner can inspect west site")
	b.mission.tick(3.1)
	check(not b.mission.has_event("lhm_west_ready") and not b.mission.actions.lhm_west_ambush.done,"single gunner cannot prepare ambush and inspection remains retryable")
	_place(members[1],west+Vector2(32,0))
	check(b.mission.request_action("lhm_west_ambush"),"west inspection retries after second gunner arrives")
	b.mission.tick(3.1)
	check(b.mission.has_event("lhm_west_ready"),"two effective gunners prepare west ambush")
	_place(members[2],south); _place(members[3],south+Vector2(32,0))
	check(b.mission.request_action("lhm_south_ambush"),"south pair inspects site")
	b.mission.tick(3.1)
	check(b.mission.has_event("lhm_south_ready") and b.mission.actions.has("lhm_signal"),"both prepared teams unlock command signal")
	_place(members[2],far); _place(members[3],far)
	check(b.mission.request_action("lhm_signal"),"commander can recheck departure order")
	b.mission.tick(2.1)
	check(b.level.stage=="prepare" and b.level.riders.is_empty() and not b.mission.actions.lhm_signal.done,"departed south team blocks signal without permanently consuming it")
	_place(members[2],south); _place(members[3],south+Vector2(32,0))
	check(b.mission.request_action("lhm_signal"),"signal can retry once both teams return")
	b.mission.tick(2.1)
	check(b.level.stage=="battle" and b.level.riders.size()==12,"returning teams launch exactly the authored twelve riders")
	for u in members: _place(u,far)
	var rider=b.level.riders[0]
	_place(rider,west)
	_place(members[0],west+Vector2(-32,0))
	var before: int=b.level.broken_count
	b.level.process(b,0.01)
	check(not bool(rider.get_meta("formation_broken")) and rider._damage_reduction_sources.has(4704) and b.level.broken_count==before,"waiting front wave cannot be broken before an actual lure action")
	check(b.mission.request_action("lhm_front_lure"),"front lure action accepts an eligible hero")
	_place(b.mission._actor,b.map.cell_to_world(b.level._lane_entry(b.level.first_lane)))
	b.mission.tick(1.3)
	_place(members[1],west+Vector2(32,0))
	b.level.process(b,0.01)
	check(b.level.wave_phase=="front_withdraw" and not bool(rider.get_meta("formation_broken")),"two gunners still cannot break armor while the lure remains in the strike lane")
	_place(members[1],far)
	_place(b.level.front_lure,b.map.cell_to_world(b.level._lane_retreat(b.level.first_lane)))
	b.level.process(b,0.01)
	check(b.level.wave_phase=="front_charge" and b.mission.has_event("lhm_front_lure_withdrew") and not bool(rider.get_meta("formation_broken")),"front lure withdrawal opens the first ambush window without bypassing the pair requirement")
	b.level.process(b,0.01)
	check(not bool(rider.get_meta("formation_broken")),"one gunner cannot break armor after the ambush window opens")
	_place(members[1],west+Vector2(32,0))
	members[1].resolve_story("captured")
	b.level.process(b,0.01)
	check(not bool(rider.get_meta("formation_broken")),"captured gunner cannot supply the second pair member")
	_place(members[2],west+Vector2(0,32)); members[2]._stun_t=3.0
	b.level.process(b,0.01)
	check(not bool(rider.get_meta("formation_broken")),"stunned gunner cannot supply the second pair member")
	members[2]._stun_t=0.0; members[2]._disarm_t=3.0
	b.level.process(b,0.01)
	check(not bool(rider.get_meta("formation_broken")),"disarmed gunner cannot supply the second pair member")
	members[2]._disarm_t=0.0
	b.level.process(b,0.01)
	check(bool(rider.get_meta("formation_broken")) and not rider._damage_reduction_sources.has(4704) and b.level.broken_count==before+1,"second effective gunner restores cooperation and actually breaks armor")
	b.level.process(b,0.01)
	check(b.level.broken_count==before+1,"the same rider cannot grant repeated formation-break events")
	await _dispose(b)
	check(assertions==60,"all original tactical semantics plus Zhujiazhuang depth and lure-space assertions executed")
	print("[tactics-v2-result] ",JSON.stringify({"passed":failures.is_empty(),"assertions":assertions,"failures":failures}))
	Engine.time_scale=1.0
	quit(0 if failures.is_empty() else 1)
