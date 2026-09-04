extends SceneTree
## ZJ-2/ZJ-3 spatial-state and free-play fixtures. The authored route uses
## request_action and real movement; the deviation fixture proves that an early
## second fight and a direct third assault lose story goals without losing the
## tactical core. Direct section entry and lethal damage remain labelled boundary
## fixtures, not human-play or pacing proof.

const OUT_DIR := "res://qa/campaign_gameplay_depth_20260901/zhujiazhuang"
var failures: Array[String] = []
var assertions := 0
var cases: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	print("[zhujiazhuang-depth] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _story_state(b, goal_id: String) -> String:
	if not b.mission.story_goals.has(goal_id): return "missing"
	return String(b.mission.story_goals[goal_id].state)

func _start():
	seed(5088120)
	var campaign = root.get_node("Campaign")
	campaign.current = campaign.index_for_id("level3")
	campaign.arena = false
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.scenario = false
	campaign.custom_defense = false
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

func _action(b, action_id: String, limit := 1800) -> bool:
	if not b.mission.request_action(action_id): return false
	var frames := 0
	while b.mission.active_action_id == action_id and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	return frames < limit and b.mission.active_action_id == ""

func _wait_for(b, predicate: Callable, limit := 1800) -> bool:
	var frames := 0
	while not predicate.call() and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	return bool(predicate.call())

func _move_away(b, actor, cell: Vector2i, from_cell: Vector2i, distance := 120.0) -> bool:
	actor.order_move(b.map.cell_to_world(cell))
	return await _wait_for(b,func(): return is_instance_valid(actor) and actor.position.distance_to(b.map.cell_to_world(from_cell)) > distance,600)

func _ids(units: Array) -> Array[int]:
	var out: Array[int] = []
	for u in units:
		if is_instance_valid(u): out.append(u.get_instance_id())
	return out

func _freeze_units(b) -> void:
	for u in b.units:
		if is_instance_valid(u): u.set_physics_process(false)

func _second_roles_and_handoff() -> void:
	var b = await _start()
	var l = b.level
	l._second_day(b) # Boundary fixture: isolates the authored second deployment.
	await process_frame
	check(l.second_spears.size() == 4 and l.second_spears.all(func(u): return is_instance_valid(u) and u.passive),"second deployment keeps all four spears from auto-attacking before formation")
	check(await _action(b,"zhu_song_safe") and b.mission.has_event("zhu_song_safe"),"Song Jiang actually reaches and records the protected retreat point")
	check(await _move_away(b,l.song,Vector2i(50,20),l.SECOND_SONG_SAFE),"a player move can pull Song Jiang out of the protected area")
	check(await _action(b,"zhu_lin_intercept") and await _action(b,"zhu_hua_cover"),"Lin Chong and Hua Rong execute their separate real positioning actions")
	check(l.stage == "second" and not b.mission.has_event("zhu_second_formation") and b.mission.actions.has("zhu_song_safe") and not b.mission.actions.zhu_song_safe.done,"Song Jiang's lost position blocks combat and reopens only his assignment")
	check(await _action(b,"zhu_song_safe") and b.mission.has_event("zhu_second_formation") and l.stage == "second","returning Song Jiang repairs the same formation without restarting")
	check(l._role_at(b,l.song,l.SECOND_SONG_SAFE) and l._role_at(b,l.lin,l.SECOND_LIN_INTERCEPT) and l._role_at(b,l.hua,l.SECOND_HUA_COVER),"all three spatial roles are simultaneously true when combat opens")
	b._smoke = true
	var captured := await _wait_for(b,func(): return l.stage == "send_hu",1800)
	b._smoke = false
	check(captured and l.hu.story_outcome == "captured" and l.hu.faction == 1 and l.hu.visible,"normal combat captures Hu Sanniang alive without changing faction")
	var capture_pos: Vector2 = l.hu.position
	var escort_requested: bool = b.mission.request_action("zhu_escort_hu")
	var visible_follow := false
	var frames := 0
	while l.stage == "send_hu" and b.phase != b.Phase.END and frames < 1200:
		await process_frame
		frames += 1
		if is_instance_valid(l.hu) and is_instance_valid(l.lin) and l.hu.visible \
				and l.hu.position.distance_to(capture_pos) > 120.0 and l.hu.position.distance_to(l.lin.position) <= 72.0:
			visible_follow = true
	check(escort_requested and visible_follow,"captured Hu Sanniang visibly follows Lin Chong along the escort route")
	check(l.stage == "hu_handoff" and b.mission.has_event("zhu_hu_at_handoff") and l._escort_pair_at_handoff(b),"old escort action reaches camp only with both captor and captive present")
	check(l.hu.story_outcome == "captured" and l.hu.faction == 1 and l.hu.visible,"Hu Sanniang remains a visible captured enemy during handoff")
	check(await _action(b,"zhu_hu_handoff") and b.mission.has_event("zhu_hu_departed"),"Lin Chong performs the separate visible camp handoff")
	await process_frame
	check(l.stage == "infiltrate" and b.find_unit("hu_sanniang") == null,"only the completed handoff advances to the third deployment")
	cases.append({"name":"second_roles_and_handoff","fixture":"direct authored second-day deployment; all accepted tasks and combat use production movement/combat","visible_follow":visible_follow,"events":b.mission.events.keys(),"stage_metrics":b.mission.stage_metrics})
	await _dispose(b)

func _free_route_core_victory() -> void:
	var b = await _start()
	var l = b.level
	l._second_day(b) # Boundary fixture: enter the second deployment directly.
	await process_frame
	var captured_hu = l.hu
	for attacker in [l.lin,l.hua]+l.second_spears:
		if is_instance_valid(attacker): attacker.order_attack(l.hu)
	var free_fight := await _wait_for(b,func(): return b.mission.has_event("zhu_second_freefight"),600)
	_freeze_units(b)
	check(free_fight and b.phase != b.Phase.END and not b.mission.has_event("zhu_second_formation"),"manual attack before the protected formation opens a recoverable free fight")
	check(_story_state(b,"zhu_capture") == "missed","wrong second-fight formation misses only the named capture story goal")
	if is_instance_valid(captured_hu) and captured_hu.story_outcome == "":
		captured_hu.resolve_story("captured")
	check(is_instance_valid(captured_hu) and captured_hu.story_outcome == "captured" and captured_hu.faction == 1,"freely subdued Hu Sanniang remains a captured enemy rather than changing sides")
	var third_opened := await _wait_for(b,func(): return l.stage == "infiltrate",600)
	check(third_opened and b.phase != b.Phase.END and not b.mission.actions.has("zhu_escort_hu"),"free capture skips the authored escort but still opens the third deployment")
	l._start_third_free_assault(b)
	check(l.stage == "assault" and l.free_third_assault and _story_state(b,"zhu_inside") == "missed" and b.phase != b.Phase.END,"direct manor assault forfeits the inside-agent goal without ending the chapter")
	var rescuer = l.song
	rescuer.order_stop()
	rescuer.position = b.map.cell_to_world(l.PRISON_CELL+Vector2i(2,0))
	b.map.sync_render_position(rescuer)
	l._third_free_tick(b)
	check(b.mission.has_event("zhu_prisoners_freed") and l.prisoner_groups.size() == 2 and l.prisoners.all(func(u): return not u.is_captive),"any surviving fighter can break the prison carts on the direct route")
	var casualty = l.prisoners[0]
	casualty.take_damage(1000000.0,rescuer) # Lethal boundary fixture after free-route release.
	await process_frame
	check(b.phase != b.Phase.END and b.mission.has_event("zhu_prisoner_lost") and _story_state(b,"zhu_seven") == "missed","a rescued-prisoner loss removes only the seven-survivor story goal")
	_freeze_units(b)
	if is_instance_valid(l.gate): l.gate.resolve_story("subdued")
	for key in ["zhu_long","zhu_hu","zhu_biao","luan_tingyu"]:
		var foe = b.find_unit(key)
		if is_instance_valid(foe) and foe.story_outcome == "": foe.take_damage(1000000.0)
	var ended := await _wait_for(b,func(): return b.phase == b.Phase.END,600)
	var result: Dictionary = b.mission.result_snapshot(true)
	check(ended and b.mission.has_event("zhu_victory") and bool(result.get("core_cleared",false)),"direct gate breach and commander defeat still clear the tactical core")
	check(not bool(result.get("story_complete",true)) and result.get("missed_ids",[]).has("zhu_capture") and result.get("missed_ids",[]).has("zhu_inside") and result.get("missed_ids",[]).has("zhu_seven"),"free-route victory settles as an incomplete story run rather than a false original result")
	cases.append({"name":"free_route_core_victory","fixture":"manual second-fight attack orders, direct third assault, free prison breach and lethal prisoner boundary fixture","ended":ended,"story_result":result,"events":b.mission.events.keys()})
	await _dispose(b)

func _third_timing_and_recovery() -> void:
	var b = await _start()
	var l = b.level
	l._third_day(b) # Boundary fixture: isolates the authored third deployment.
	await process_frame
	check(await _action(b,"zhu_enter_manor") and b.mission.has_event("zhu_sun_entered"),"Sun Li uses the original admission action before interior work exists")
	check(b.mission.actions.zhu_free_prisoners.actors == ["gu_dasao"] and b.mission.actions.zhu_inner_support.actors == ["sun_li"] and b.mission.actions.zhu_outer_position.actors == ["song_jiang"],"rescue, inner support, and outside command have distinct named actors")
	check(await _action(b,"zhu_inner_support") and await _action(b,"zhu_open_gate"),"Sun Li can secure the inner gate and open it before the other work finishes")
	check(l.stage == "inside" and not l.assault_started and b.mission.has_event("zhu_gate_opened") and l.gate.story_outcome == "retreated","opening the gate early changes passage but does not auto-start the assault")
	check(await _action(b,"zhu_attack_signal") and l.stage == "inside" and not b.mission.actions.zhu_attack_signal.done and not b.mission.has_event("zhu_assault_ordered"),"an early attack signal is refused and remains retryable")
	check(await _action(b,"zhu_outer_position") and await _action(b,"zhu_free_prisoners"),"Song Jiang takes the outside position while Gu Dasao performs the separate rescue")
	check(l.prisoner_groups.size() == 2 and l.prisoner_groups[0].size() == 4 and l.prisoner_groups[1].size() == 3,"the seven prisoners are assigned to distinct groups of four and three")
	var all_group_ids: Array[int] = _ids(l.prisoner_groups[0]) + _ids(l.prisoner_groups[1])
	var unique_group_ids: Dictionary = {}
	for id in all_group_ids: unique_group_ids[id] = true
	check(all_group_ids.size() == 7 and unique_group_ids.size() == 7,"no prisoner is duplicated between withdrawal groups")
	check(await _action(b,"zhu_attack_signal") and l.stage == "inside" and not b.mission.actions.zhu_attack_signal.done,"opening plus initial release is still insufficient before both groups reach the inner court")
	check(not l._group_at_rally(b,l.prisoner_groups[0],l.PRISON_RALLY_A) and not l._group_at_rally(b,l.prisoner_groups[1],l.PRISON_RALLY_B),"released prisoners wait for player orders instead of auto-walking to the inner court")
	b._set_selection(l.prisoner_groups[0])
	b._issue_order(b.to_screen(b.map.cell_to_world(l.PRISON_RALLY_A)))
	b._set_selection(l.prisoner_groups[1])
	b._issue_order(b.to_screen(b.map.cell_to_world(l.PRISON_RALLY_B)))
	var groups_safe := await _wait_for(b,func(): return b.mission.has_event("zhu_prison_group_a_safe") and b.mission.has_event("zhu_prison_group_b_safe"),1200)
	check(groups_safe and l._group_at_rally(b,l.prisoner_groups[0],l.PRISON_RALLY_A) and l._group_at_rally(b,l.prisoner_groups[1],l.PRISON_RALLY_B),"both groups physically reach their separate inner-court rallies after two real player commands")
	check(await _action(b,"zhu_attack_signal") and l.stage == "assault" and l.assault_started and b.mission.has_event("zhu_assault_ordered"),"the same signal succeeds after all inner and outer positions recover")
	check(l.prisoner_groups[0].all(func(u): return is_instance_valid(u) and u.hp > 0.0) and l.prisoner_groups[1].all(func(u): return is_instance_valid(u) and u.hp > 0.0),"all seven rescued prisoners remain alive when the pincer begins")
	cases.append({"name":"third_timing_and_recovery","fixture":"direct authored third-day deployment; admission and all successful/rejected tasks use request_action","group_sizes":[l.prisoner_groups[0].size(),l.prisoner_groups[1].size()],"events":b.mission.events.keys(),"stage_metrics":b.mission.stage_metrics})
	await _dispose(b)

func _third_duplicate_death_restart() -> void:
	var b = await _start()
	var l = b.level
	l._third_day(b)
	await process_frame
	check(await _action(b,"zhu_enter_manor"),"restart/death fixture first performs the real admission action")
	l.on_mission_action(b,"zhu_free_prisoners",l.sun) # Invalid-callback boundary fixture.
	check(not b.mission.has_event("zhu_prisoners_freed") and l.prisoner_groups.is_empty() and l.prisoners.all(func(u): return u.is_captive),"wrong actor and unfinished action cannot free prisoners")
	check(await _action(b,"zhu_free_prisoners") and b.mission.has_event("zhu_prisoners_freed"),"Gu Dasao can recover by completing the original rescue action")
	var group_ids_before: Array[int] = _ids(l.prisoner_groups[0]) + _ids(l.prisoner_groups[1])
	var report_before: int = b.mission.report.size()
	l.on_mission_action(b,"zhu_free_prisoners",l.gu) # Duplicate-callback boundary fixture.
	var group_ids_after: Array[int] = _ids(l.prisoner_groups[0]) + _ids(l.prisoner_groups[1])
	check(group_ids_before == group_ids_after and b.mission.report.size() == report_before,"duplicate rescue callback neither reallocates groups nor repeats its report")
	var casualty = l.prisoner_groups[0][0]
	casualty.take_damage(1000000.0,l.gu) # Impossible friendly-fire boundary fixture before assault.
	await process_frame
	check(b.phase != b.Phase.END and b.mission.has_event("zhu_prisoner_lost") and _story_state(b,"zhu_seven") == "missed","an injected pre-assault prisoner loss no longer triggers a false hard failure")
	await _dispose(b)
	b = await _start()
	l = b.level
	check(l.stage == "scout" and l.prisoners.is_empty() and l.prisoner_groups.is_empty() and b.mission.events.is_empty(),"full restart clears cross-day units, groups, and mission events")
	l._third_day(b)
	await process_frame
	check(l.prisoners.size() == 7 and l.prisoner_groups.is_empty() and l.prisoners.all(func(u): return is_instance_valid(u) and u.hp > 0.0 and u.is_captive),"new third-day deployment creates exactly seven fresh bound prisoners")
	cases.append({"name":"third_duplicate_death_restart","fixture":"wrong/duplicate callbacks and lethal damage are explicit edge fixtures; restart is a fresh scene instance","fresh_prisoner_ids":_ids(l.prisoners),"events_after_restart":b.mission.events.keys()})
	await _dispose(b)

func _original_full_route() -> void:
	var b = await _start()
	b._smoke = true
	var ended := await _wait_for(b,func(): return b.phase == b.Phase.END,18000)
	b._smoke = false
	var result: Dictionary = b.mission.result_snapshot(true)
	check(ended and b.mission.has_event("zhu_victory") and bool(result.get("core_cleared",false)),"the full authored three-day route still reaches base victory")
	check(bool(result.get("story_complete",false)) and int(result.get("story_done",0)) == 4 and result.get("missed_ids",[]).is_empty(),"the original route completes all four named story goals and earns the seal")
	check(b.mission.has_event("zhu_second_formation") and b.mission.has_event("zhu_hu_captured") and b.mission.has_event("zhu_hu_departed") and b.mission.has_event("zhu_assault_ordered"),"the sealed run contains formation, enemy capture, escort handoff and inside-out assault evidence")
	cases.append({"name":"original_full_route","fixture":"production smoke driver uses request_action, movement and ordinary combat from the chapter start","ended":ended,"story_result":result,"events":b.mission.events.keys(),"stage_metrics":b.mission.stage_metrics})
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	var campaign = root.get_node("Campaign")
	var save_existed: bool = FileAccess.file_exists(campaign.SAVE_PATH)
	var save_before: PackedByteArray = FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_existed else PackedByteArray()
	await _second_roles_and_handoff()
	await _free_route_core_victory()
	await _third_timing_and_recovery()
	await _third_duplicate_death_restart()
	await _original_full_route()
	var save_exists_now: bool = FileAccess.file_exists(campaign.SAVE_PATH)
	var save_after: PackedByteArray = FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	var save_unchanged: bool = save_existed == save_exists_now and save_before == save_after
	check(save_unchanged,"CAMPAIGN_QA leaves campaign progress unchanged")
	var report := {"passed":failures.is_empty(),"assertions":assertions,"failures":failures,"cases":cases,"campaign_qa":OS.get_environment("CAMPAIGN_QA"),"save_unchanged":save_unchanged,"scope":"authored spatial fixtures, one bounded free-route core victory, and one complete original-route playthrough","timing_note":"Any stage_metrics here use fixed-fps60 FIGHT simulation at time_scale4. They are neither human pacing nor 15-25 minute acceptance evidence."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var file := FileAccess.open(OUT_DIR+"/depth_v1.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t"))
	print("[zhujiazhuang-depth-result] ",JSON.stringify(report))
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
