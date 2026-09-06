extends SceneTree
## DM-2/DM-3 bounded fixtures. Combat is frozen only after the real infiltration,
## fire response and gate passage; line actions still use real movement, range,
## finite units and mission callbacks. No HP/count tuning is performed.

const OUT_DIR := "res://qa/campaign_gameplay_depth_20260901/daming"
const FACTION_GUAN := 1 # Avoid loading Unit before project autoloads in a SceneTree test.
var failures: Array[String] = []
var checks := 0
var cases: Array = []

func _initialize() -> void: _run.call_deferred()

func check(ok: bool,name: String) -> void:
	checks += 1
	print("[daming-depth] ",name," ","PASS" if ok else "FAIL")
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
	b.queue_free()
	await process_frame
	await process_frame

func _act(b,id: String,limit := 1800) -> bool:
	if not b.mission.request_action(id): return false
	var frames := 0
	while b.mission.active_action_id == id and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	return frames < limit and b.phase != b.Phase.END and b.mission.active_action_id == ""

func _place(b,u,cell: Vector2i) -> void:
	u.order_stop()
	u.position = b.map.cell_to_world(cell)
	b.map.sync_render_position(u)

func _army_ids(l) -> Array:
	return l.outside_army.map(func(u): return u.get_instance_id())

func _freeze_battle(b) -> void:
	for u in b.units:
		if is_instance_valid(u) and not u.is_noncombat: u.set_physics_process(false)

func _park_response(b,l) -> void:
	for i in range(l.outside_army.size()):
		var u = l.outside_army[i]
		if l._effective(u): _place(b,u,Vector2i(27+i%5,47+i/5))

func _responders(b,l,cell: Vector2i,count: int) -> Array:
	_park_response(b,l)
	var chosen: Array = []
	for u in l.outside_army:
		if l._can_control(u) and u.key in l.ESCORT_KEYS:
			_place(b,u,cell+Vector2i(chosen.size()%2,chosen.size()/2))
			chosen.append(u)
			if chosen.size() == count: break
	if not chosen.is_empty(): b.selection = [chosen[0]]
	return chosen

func _suppress_line(b,l,line: String) -> void:
	var cell: Vector2i = l._pressure_cell(line)
	var distance: float = 180.0 if line == "street" else 210.0
	for u in b.units:
		if l._can_control(u) and u.faction == FACTION_GUAN and not u.is_building and l._near(b,u,cell,distance):
			u.apply_stun(1000.0)

func _suppress_at(b,l,cell: Vector2i,distance: float) -> void:
	for u in b.units:
		if l._can_control(u) and u.faction == FACTION_GUAN and not u.is_building and l._near(b,u,cell,distance):
			u.apply_stun(1000.0)

func _active_enemies(b,l) -> int:
	var total := 0
	for u in b.units:
		if l._effective(u) and u.faction == FACTION_GUAN and not u.is_building: total += 1
	return total

func _wait_people(b,limit := 1000) -> bool:
	var frames := 0
	while not b.mission.has_event("daming_civilians_spared") and not b.mission.has_event("daming_people_lost") and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	return b.mission.has_event("daming_civilians_spared")

func _wait_line_lost(b,l,line: String,limit := 180) -> bool:
	var frames := 0
	while (l.street_secured if line == "street" else l.jail_secured) and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	return not (l.street_secured if line == "street" else l.jail_secured)

func _to_rescue(b,initial_ids: Array) -> bool:
	b._smoke = true
	var frames := 0
	while b.level.stage != "gate" and b.phase != b.Phase.END and frames < 6500:
		await process_frame
		frames += 1
	b._smoke = false
	if b.level.stage != "gate" or b.phase == b.Phase.END: return false
	var l = b.level
	_freeze_battle(b)
	_suppress_line(b,l,"street") # also controls the two gate-side defenders when close
	for u in b.units:
		if l._can_control(u) and u.faction == FACTION_GUAN and l._near(b,u,Vector2i(30,42),160.0): u.apply_stun(1000.0)
	var chosen = _responders(b,l,Vector2i(30,43),2)
	if chosen.size() < 2: return false
	if not await _act(b,"daming_open_gate"): return false
	return l.stage == "rescue" and l.gate_open and _army_ids(l) == initial_ids

func _trigger_pursuit(b,l) -> int:
	var before_ids := {}
	for u in b.units:
		if is_instance_valid(u): before_ids[u.get_instance_id()] = true
	_place(b,l.lu,Vector2i(30,28))
	var frames := 0
	while not l.reinforcements_sent and b.phase != b.Phase.END and frames < 60:
		await process_frame
		frames += 1
	await process_frame
	var added := 0
	for u in b.units:
		if is_instance_valid(u) and not before_ids.has(u.get_instance_id()) and u.faction == FACTION_GUAN and not u.is_building: added += 1
	return added

func _street_first_case() -> void:
	var b = await _start()
	var l = b.level
	var ids := _army_ids(l)
	check(await _to_rescue(b,ids),"street_first_real_fire_gate_and_same_finite_army")
	check(l.outside_army.size() == 11 and not l.reinforcements_sent,"no_response_spawn_before_prisoners_advance")
	_suppress_line(b,l,"street")
	check(_responders(b,l,l.MAIN_STREET_CELL,2).size() == 2 and await _act(b,"daming_secure_street"),"street_first_two_responders_execute_real_line_action")
	check(l.street_secured and l.first_pressure_line == "street" and l.jail_pressure_debt and b.mission.has_event("daming_street_first") and String(b.mission.actions.daming_secure_jail.label).contains("3人"),"street_first_visibly_tightens_jail_line")
	_suppress_line(b,l,"jail")
	_responders(b,l,l.JAIL_LINE_CELL,2)
	check(await _act(b,"daming_secure_jail") and not l.jail_secured and b.mission.has_event("daming_jail_manpower_short"),"tightened_jail_line_rejects_only_two_responders")
	_responders(b,l,l.JAIL_LINE_CELL,3)
	check(await _act(b,"daming_secure_jail") and l._pressure_lines_ready(b),"third_responder_recovers_jail_line_without_new_units")
	# Protecting people before opening the shackles physically sends Wu Yong away
	# while both line actions remain held by the finite response force.
	_place(b,l.strategist,l.PEOPLE_CELL)
	b.selection = [l.strategist]
	check(await _act(b,"daming_spare_people") and l.people_timing == "early" and b.mission.has_event("daming_people_timing_early"),"early_civilian_order_competes_before_unlock")
	check(await _wait_people(b) and not l.rescued,"early_civilians_reach_real_safe_alley_before_unlock")
	# A stunned jail guard recovers: the secured line must actually be won again.
	var recovered_guard = null
	for u in l.guards:
		if l._effective(u):
			recovered_guard = u
			break
	if recovered_guard != null:
		_place(b,recovered_guard,l.JAIL_LINE_CELL)
		recovered_guard._stun_t = 0.0
		recovered_guard._disarm_t = 0.0
	check(await _wait_line_lost(b,l,"jail") and b.mission.has_event("daming_jail_line_lost"),"single_jail_line_recovery_causes_real_loss")
	_place(b,l.chai,l.JAIL_ACTION)
	b.selection = [l.chai]
	check(await _act(b,"daming_unlock") and not l.rescued and b.mission.has_event("daming_unlock_lines_blocked"),"lost_single_line_blocks_unlock_but_does_not_fail_mission")
	_suppress_line(b,l,"jail")
	_responders(b,l,l.JAIL_LINE_CELL,3)
	check(await _act(b,"daming_secure_jail") and l.jail_secured,"lost_jail_line_can_be_recovered")
	_place(b,l.chai,l.JAIL_ACTION)
	b.selection = [l.chai]
	check(await _act(b,"daming_unlock") and l.rescued,"recovered_two_lines_allow_original_unlock_action")
	var pursuit := await _trigger_pursuit(b,l)
	check(pursuit == 2 and l.reinforcements_sent,"early_safe_civilians_reduce_existing_pursuit_to_two")
	for u in b.units:
		if is_instance_valid(u) and u.faction == FACTION_GUAN: u.set_physics_process(false)
	_place(b,l.lu,l.EXIT_CELL)
	b.selection = [l.lu]
	check(await _act(b,"daming_lu_exit") and b.mission.has_event("daming_lu_safe"),"street_first_recovered_route_allows_lu_exit")
	var route_recovered := true
	if not l._pressure_lines_ready(b):
		if l.street_secured: await _wait_line_lost(b,l,"street")
		_suppress_line(b,l,"street")
		_responders(b,l,l.MAIN_STREET_CELL,l._pressure_required("street"))
		route_recovered = await _act(b,"daming_secure_street") and l._pressure_lines_ready(b)
	check(route_recovered,"even_two_early_pursuers_can_reopen_but_not_permanently_break_main_street")
	_place(b,l.shi,l.EXIT_CELL)
	b.selection = [l.shi]
	await _act(b,"daming_shi_exit") # Terminal victory makes _act return false by design.
	var victory_frames := 0
	while not b.mission.has_event("daming_victory") and b.phase != b.Phase.END and victory_frames < 60:
		await process_frame
		victory_frames += 1
	if not b.mission.has_event("daming_victory"):
		print("[daming-depth-victory-debug] shi_safe=",b.mission.has_event("daming_shi_safe")," lu_safe=",b.mission.has_event("daming_lu_safe")," lines=",l.street_secured,"/",l.jail_secured," contested=",l._pressure_contested(b,"street"),"/",l._pressure_contested(b,"jail")," phase=",b.phase)
	check(b.phase == b.Phase.END and b.mission.has_event("daming_victory"),"street_first_recovered_route_allows_both_prisoners_alive_victory")
	cases.append({"order":"street_first","opposite_required":l._pressure_required("jail"),"people_timing":l.people_timing,"pursuit":pursuit,"army_ids":ids,"line_recoveries":[l.street_recoveries,l.jail_recoveries]})
	await _dispose(b)

func _jail_first_case() -> void:
	var b = await _start()
	var l = b.level
	var ids := _army_ids(l)
	check(await _to_rescue(b,ids),"jail_first_real_fire_gate_and_same_finite_army")
	_suppress_line(b,l,"jail")
	check(_responders(b,l,l.JAIL_LINE_CELL,2).size() == 2 and await _act(b,"daming_secure_jail"),"jail_first_two_responders_execute_real_line_action")
	check(l.jail_secured and l.first_pressure_line == "jail" and l.street_pressure_debt and b.mission.has_event("daming_jail_first") and String(b.mission.actions.daming_secure_street.label).contains("3人"),"jail_first_visibly_tightens_main_street")
	_suppress_line(b,l,"street")
	_responders(b,l,l.MAIN_STREET_CELL,2)
	check(await _act(b,"daming_secure_street") and not l.street_secured and b.mission.has_event("daming_street_manpower_short"),"tightened_main_street_rejects_only_two_responders")
	_responders(b,l,l.MAIN_STREET_CELL,3)
	check(await _act(b,"daming_secure_street") and l._pressure_lines_ready(b),"third_responder_recovers_main_street_without_new_units")
	_place(b,l.chai,l.JAIL_ACTION)
	b.selection = [l.chai]
	check(await _act(b,"daming_unlock") and l.rescued,"jail_first_order_still_reaches_original_unlock")
	var pursuit := await _trigger_pursuit(b,l)
	check(pursuit == 5 and l.reinforcements_sent,"prisoners_leave_before_civilian_safety_launches_five_pursuers")
	for u in b.units:
		if is_instance_valid(u) and u.faction == FACTION_GUAN: u.set_physics_process(false)
	_place(b,l.strategist,l.PEOPLE_CELL)
	b.selection = [l.strategist]
	check(await _act(b,"daming_spare_people") and l.people_timing == "" and b.mission.has_event("daming_people_route_blocked"),"late_five_pursuers_physically_block_civilian_route")
	_suppress_at(b,l,l.PEOPLE_CELL,180.0)
	check(await _act(b,"daming_spare_people") and l.people_timing == "late" and b.mission.has_event("daming_people_timing_late"),"late_civilian_order_records_pursuit_already_committed")
	check(await _wait_people(b) and _active_enemies(b,l) >= pursuit,"late_civilian_safety_does_not_delete_existing_pursuers")
	# Re-open the street with one existing guard and prove a prisoner cannot be
	# credited at the exit until the same finite force restores it.
	var street_guard = null
	for u in l.guards:
		if l._effective(u):
			street_guard = u
			break
	if street_guard != null:
		_place(b,street_guard,l.MAIN_STREET_CELL)
		street_guard._stun_t = 0.0
		street_guard._disarm_t = 0.0
	check(await _wait_line_lost(b,l,"street") and b.mission.has_event("daming_street_line_lost"),"existing_guard_reopens_main_street_after_unlock")
	_place(b,l.lu,l.EXIT_CELL)
	b.selection = [l.lu]
	check(await _act(b,"daming_lu_exit") and l.lu.story_outcome == "" and b.mission.has_event("daming_escape_line_blocked"),"lost_main_street_blocks_prisoner_credit_and_remains_recoverable")
	_suppress_line(b,l,"street")
	_responders(b,l,l.MAIN_STREET_CELL,3)
	check(await _act(b,"daming_secure_street") and l.street_secured,"main_street_recovered_with_original_response_force")
	_place(b,l.lu,l.EXIT_CELL)
	b.selection = [l.lu]
	check(await _act(b,"daming_lu_exit") and b.mission.has_event("daming_lu_safe"),"recovery_allows_same_prisoner_exit_action")
	l.shi.take_damage(1000000.0)
	check(b.phase == b.Phase.END and not b.mission.has_event("daming_victory"),"shi_xiu_death_after_depth_choices_still_fails")
	cases.append({"order":"jail_first","opposite_required":l._pressure_required("street"),"people_timing":l.people_timing,"pursuit":pursuit,"army_ids":ids,"line_recoveries":[l.street_recoveries,l.jail_recoveries]})
	await _dispose(b)

func _restart_case() -> void:
	var b = await _start()
	var l = b.level
	check(l.stage == "approach" and not l.street_secured and not l.jail_secured and l.first_pressure_line == "" and not l.street_pressure_debt and not l.jail_pressure_debt and l.people_timing == "","restart_resets_both_lines_order_debt_and_civilian_timing")
	check(not l.reinforcements_sent and l.street_recoveries == 0 and l.jail_recoveries == 0 and l.lu.is_captive and l.shi.is_captive,"restart_resets_pursuit_recovery_counts_and_bound_prisoners")
	l.lu.take_damage(1000000.0)
	check(b.phase == b.Phase.END and not b.mission.has_event("daming_victory"),"lu_junyi_death_after_restart_still_fails")
	await _dispose(b)

func _write_report() -> void:
	var absolute := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	if checks != 34: failures.append("expected_34_checks_got_%d"%checks)
	var result := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,
		"scope":"DM-2/DM-3 finite-force line-order, recoverable loss, civilian timing and prisoner survival fixtures",
		"fixture_boundary":"Real pre-fire route/actions and mission callbacks; combat frozen only for deterministic line-control boundaries. No unit, HP, damage or spawn-count edits."}
	var file := FileAccess.open(OUT_DIR+"/depth_contract.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")+"\n")
	print("[daming-depth-result] ",JSON.stringify(result))

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	await _street_first_case()
	await _jail_first_case()
	await _restart_case()
	_write_report()
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
