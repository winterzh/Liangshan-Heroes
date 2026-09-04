extends SceneTree
## Boundary fixtures are explicitly separate from campaign_later_playthrough's unmodified combat.
## Identity actions and retries use request_action, movement, duration and the real callback.
var failures: Array[String] = []
var checks := 0
var evidence: Array = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,name: String) -> void:
	checks += 1
	print("[daming-v3] ",name," ","PASS" if ok else "FAIL")
	if not ok: failures.append(name)
func _start():
	seed(5088120)
	var campaign = root.get_node("Campaign")
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == "level8": campaign.current = i
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	Engine.time_scale = 4.0
	return b
func _dispose(b) -> void:
	evidence.append({"stage":b.level.stage,"events":b.mission.events.keys(),"total_game_seconds":b.mission.total_game_seconds,"stage_metrics":b.mission.stage_metrics})
	b.queue_free()
	await process_frame
	await process_frame
func _act(b,id: String,limit := 1500) -> bool:
	if not b.mission.request_action(id): return false
	var frames := 0
	while b.mission.active_action_id == id and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	if frames >= limit:
		print("[daming-timeout] ",id," actor=",b.mission._actor.key," pos=",b.mission._actor.position," path=",b.mission._actor._path)
		for u in b.level.guards:
			if is_instance_valid(u) and u.position.distance_to(b.mission._actor.position)<160.0: print("[daming-blocker] ",u.key," pos=",u.position)
	return b.phase != b.Phase.END and b.mission.active_action_id == ""
func _drive_until(b,stage: String,limit := 5000) -> bool:
	b._smoke = true
	var frames := 0
	while b.level.stage != stage and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	b._smoke = false
	return b.level.stage == stage and b.phase != b.Phase.END
func _place(b,u,cell: Vector2i) -> void:
	u.order_stop()
	u.position = b.map.cell_to_world(cell)
	b.map.sync_render_position(u)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	var b = await _start()
	var l = b.level
	check(l.stage == "approach" and b.map.world_to_cell(l.scout.position).y > 39 and b.map.world_to_cell(l.chai.position).y > 39 and b.map.world_to_cell(l.yue.position).y > 39,"all_three_infiltrators_start_outside")
	check(b.find_unit("song_jiang") == null and is_instance_valid(l.strategist),"song_jiang_stays_on_mountain_wu_yong_commands")
	check(not b.map.is_open_cell(l.WICKET) and not b.map.is_open_cell(l.PRISON_DOOR) and not b.map.is_open_cell(l.SOUTH_GATE),"all_three_gates_initially_blocked")
	check(not b.mission.request_action("daming_signal") and not b.mission.request_action("daming_unlock") and not b.mission.request_action("daming_lu_exit"),"cannot_skip_identity_fire_rescue_chain")
	var army_ids := []
	var army_cells := []
	for u in l.outside_army:
		army_ids.append(u.get_instance_id())
		army_cells.append(b.map.world_to_cell(u.position))
	check(l.outside_army.size() == 11 and l.outside_army.all(func(u): return not u.is_physics_processing() and u.ability_slots.is_empty()),"finite_outside_army_present_but_waits_for_fire")
	check(await _act(b,"daming_city_check"),"unprepared_city_identity_attempt_reaches_guard")
	check(b.mission.has_event("daming_city_identity_failed") and not l.wicket_open and not b.mission.actions.daming_city_check.done,"city_identity_failure_keeps_gate_closed_and_retryable")
	check(await _drive_until(b,"infiltrate"),"recover_city_identity_and_walk_party_through_wicket")
	check(l._party_inside_city(b) and not b.map.is_open_cell(l.WICKET) and not l.gate_open,"party_walked_inside_wicket_reclosed_main_gate_still_shut")
	var chai_position: Vector2 = l.chai.position
	_place(b,l.chai,Vector2i(54,36))
	check(not l._party_inside_city(b),"same_y_outside_east_wall_does_not_count_as_city_reunion")
	l.chai.position = chai_position
	b.map.sync_render_position(l.chai)
	var unchanged := true
	for i in range(l.outside_army.size()):
		unchanged = unchanged and l.outside_army[i].get_instance_id() == army_ids[i] and b.map.world_to_cell(l.outside_army[i].position) == army_cells[i]
	check(unchanged,"outside_army_not_teleported_or_spawned_by_infiltration")
	check(await _act(b,"daming_prison_check"),"unprepared_prison_identity_attempt_reaches_checkpoint")
	if not b.mission.has_event("daming_prison_identity_failed"):
		await _dispose(b)
		quit(1)
		return
	check(b.mission.has_event("daming_prison_identity_failed") and not l.officer_cover and not l.prison_door_open and not b.mission.actions.daming_prison_check.done,"prison_identity_failure_is_recoverable_and_door_stays_closed")
	check(await _drive_until(b,"gaol_entry"),"officer_disguise_and_two_person_checkpoint_recover")
	check(l.officer_cover and l.prison_door_open and l.chai.art_variant == "chai_jin_officer" and l.yue.art_variant == "yue_he_officer","officer_visuals_and_real_prison_passage_ready")
	check(not b.mission.request_action("daming_signal"),"cannot_light_fire_before_both_jail_infiltrators_positioned")
	check(await _drive_until(b,"signal"),"both_infiltrators_walk_through_prison_door")
	check(b.map.world_to_cell(l.chai.position).y < 20 and b.map.world_to_cell(l.yue.position).y < 20 and l.lu.is_captive and l.shi.is_captive,"jail_positioning_does_not_automatically_free_prisoners")
	# A previously positioned infiltrator can be moved by the player; historical flags must not suffice.
	l.yue.order_move(b.map.cell_to_world(l.PRISON_CHECK))
	var leave_frames := 0
	while b.map.world_to_cell(l.yue.position).y < 22 and leave_frames < 600:
		await process_frame
		leave_frames += 1
	l.yue.order_stop()
	check(not l._jail_infiltrators_ready(b) and b.mission.has_event("daming_yue_positioned"),"infiltrator_can_leave_real_jail_despite_historical_ready_flag")
	_place(b,l.scout,l.FIRE_CELL)
	check(await _act(b,"daming_signal"),"fire_rechecks_actual_infiltrator_presence_at_commit")
	check(b.mission.has_event("daming_inner_party_missing") and not b.mission.has_event("daming_fire_lit") and not b.mission.actions.daming_signal.done,"historical_ready_flag_cannot_replace_infiltrator_still_in_jail")
	check(await _act(b,"daming_yue_inside") and l._jail_infiltrators_ready(b),"returning_infiltrator_walks_back_and_restores_fire_readiness")
	# Exposure fixture: hold a real patrol close for the actual observation threshold.
	var scout_hp: float = l.scout.hp
	for u in l.patrols:
		u.set_physics_process(false)
	_place(b,l.patrols[0],b.map.world_to_cell(l.scout.position)+Vector2i(-1,0))
	l._tick_infiltration(b,2.1)
	check(l.alarmed and not l.scout_cover and b.mission.has_event("daming_alarm"),"sustained_visible_patrol_exposure_invalidates_scout_cover")
	_place(b,l.scout,l.FIRE_CELL)
	check(await _act(b,"daming_signal"),"exposed_scout_attempts_fire_at_real_site")
	check(not b.mission.has_event("daming_fire_lit") and not b.mission.actions.daming_signal.done,"exposed_fire_attempt_blocked_and_retryable")
	# End the exposure-position fixture before testing recovery navigation: a frozen guard
	# planted at the cover route would create an artificial, permanent body blocker.
	for u in l.patrols: _place(b,u,u.get_meta("patrol_route")[0])
	check(await _act(b,"daming_east_alley"),"scout_takes_real_east_alley_route_around_frozen_patrol_fixture")
	check(await _act(b,"daming_crowd_cover"),"scout_walks_to_crowd_cover_to_recover")
	check(not l.alarmed and l.scout_cover and b.mission.has_event("daming_crowd_cover_used") and is_equal_approx(scout_hp,l.scout.hp),"crowd_cover_restores_identity_without_healing")
	check(not b.mission.request_action("daming_crowd_cover"),"same_crowd_cover_cannot_be_claimed_twice")
	for u in l.patrols:
		_place(b,u,u.get_meta("patrol_route")[0])
		u.set_physics_process(true)
	check(await _drive_until(b,"gate"),"recovered_scout_returns_and_lights_signal")
	var same_army := true
	for i in range(l.outside_army.size()): same_army = same_army and l.outside_army[i].get_instance_id() == army_ids[i] and l.outside_army[i].is_physics_processing()
	check(same_army and l.guards.size() == 12,"signal_releases_same_army_no_extra_guard_wave")
	# Tactical boundary fixtures: freeze combat only, leave real task callback / proximity checks running.
	for u in l.outside_army:
		u.set_physics_process(false)
		u.ability_slots.clear()
		_place(b,u,Vector2i(27,49))
	for u in l.guards: u.set_physics_process(false)
	var monk = b.find_unit("lu_zhishen")
	var wu = b.find_unit("wu_song")
	_place(b,monk,Vector2i(30,43))
	b.selection = [monk]
	check(await _act(b,"daming_open_gate"),"gate_interaction_attempted_while_defenders_control_it")
	check(b.mission.has_event("daming_gate_blocked") and not l.gate_open and not b.mission.actions.daming_open_gate.done,"live_gate_guards_block_takeover_and_allow_retry")
	for u in l.guards:
		if l._near(b,u,Vector2i(30,42),160.0): u.apply_stun(1000.0)
	check(await _act(b,"daming_open_gate"),"gate_retried_with_controlled_guards_but_only_one_ally")
	check(b.mission.has_event("daming_response_missing") and not l.gate_open,"one_hero_cannot_substitute_for_arriving_response_force")
	_place(b,wu,Vector2i(31,43))
	check(await _act(b,"daming_open_gate"),"two_actual_allies_and_controlled_guards_allow_takeover")
	check(l.gate_open and b.map.is_open_cell(l.SOUTH_GATE) and b.mission.has_event("daming_response_arrived"),"takeover_opens_real_south_gate_footprint")
	b.selection = [l.chai]
	check(await _act(b,"daming_unlock"),"unlock_attempt_reaches_captives_with_jail_guards_active")
	check(b.mission.has_event("daming_jail_blocked") and not l.rescued and l.lu.is_captive and not b.mission.actions.daming_unlock.done,"jail_guard_control_blocks_freeing_and_allows_retry")
	for u in l.guards:
		if l._near(b,u,l.PRISON_CHECK,210.0) or l._near(b,u,l.JAIL_ACTION,144.0): u.apply_stun(1000.0)
	check(await _act(b,"daming_unlock"),"controlled_jail_guards_allow_actual_unlock_retry")
	check(l.rescued and not l.lu.is_captive and not l.shi.is_captive and l.lu.hp > 0 and l.shi.hp > 0,"both_prisoners_freed_alive_and_mobile")
	check(not b.mission.request_action("daming_unlock") and not b.mission.request_action("daming_signal"),"completed_fire_and_unlock_cannot_repeat")
	# Visible optional objective also requires actual movement before reward.
	_place(b,l.strategist,l.PEOPLE_CELL)
	b.selection = [l.strategist]
	check(await _act(b,"daming_spare_people"),"wu_yong_reaches_visible_households")
	check(b.mission.has_event("daming_people_escorting") and not b.mission.has_event("daming_civilians_spared"),"issuing_protect_order_does_not_instantly_credit_safe_civilians")
	var frames := 0
	while not b.mission.has_event("daming_civilians_spared") and frames < 900:
		await process_frame
		frames += 1
	check(b.mission.has_event("daming_civilians_spared") and l.civilians.all(func(u): return u.story_outcome == "retreated" and u.hp > 0),"all_three_civilians_actually_reach_safe_alley")
	l.shi.take_damage(1000000.0)
	check(b.phase == b.Phase.END and not b.mission.has_event("daming_victory"),"rescued_prisoner_death_fails_even_after_all_gate_events")
	check(not b.mission.request_action("daming_lu_exit"),"exit_cannot_repair_prisoner_death")
	await _dispose(b)
	b = await _start()
	l = b.level
	check(l.stage == "approach" and b.mission.events.is_empty() and not l.scout_cover and not l.officer_cover and not l.alarmed and not l.reinforcements_sent,"restart_resets_identity_alarm_pursuit_and_events")
	check(not b.map.is_open_cell(l.WICKET) and not b.map.is_open_cell(l.PRISON_DOOR) and l.lu.is_captive and l.shi.is_captive,"restart_rebuilds_closed_passages_and_bound_prisoners")
	l.lu.take_damage(1000000.0)
	check(b.phase == b.Phase.END and not b.mission.has_event("daming_victory"),"bound_prisoner_death_still_fails")
	await _dispose(b)
	print("[daming-v3-result] ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"fixture_note":"position/stun/frozen-combat boundaries; use separate unmodified playthrough for timing and combat proof","cases":evidence}))
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
