extends SceneTree
## FIXTURE TESTS ONLY: chapter state/starting positions are deliberately fast-forwarded.
## Real damage, actual mission callbacks and normal movement test edge rejection, not a playthrough.
const STEP := 0.05
var results: Array = []
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _record(name: String, passed: bool, details: Dictionary) -> void:
	details["case"] = name
	details["passed"] = passed
	details["fixture"] = true
	results.append(details)
	if not passed: failures.append(name)
	print("[edge-fixture] ", JSON.stringify(details))

func _start(id: String):
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]: campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == id: campaign.current = i
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b._smoke = false
	b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	return b

func _dispose(b) -> void:
	b.queue_free()
	await process_frame
	await process_frame

func _step(b, delta := STEP) -> void:
	# Controlled full battle frame: DOT -> task -> level checks, then real unit navigation.
	b._physics_process(delta)
	if b.phase != b.Phase.FIGHT: return
	for u in b.units.duplicate():
		if is_instance_valid(u): u._physics_process(delta)

func _prepare_return_fixture(b):
	var l = b.level
	l.stage = "return_prisoner"
	l.recovered_gao = true
	l.transfer_done = false
	var boat = b.spawn_at("zhang_shun_boat", 0, l.PRISONER_DOCK_WATER)
	boat.set_physics_process(false)
	boat.set_meta("carried_story_person", "高俅")
	l.fleet.append(boat)
	b.mission.begin("edge_return_fixture", "夹具：押俘返航已完成", "只测试码头交接边界，不是主线通关。")
	b.mission.add_action("land_gao", "夹具：真实码头交接", l.PRISONER_DOCK_WATER, ["zhang_shun_boat"], 1.0, 24.0)
	return boat

func _prepare_capture_fixture(b) -> bool:
	_prepare_return_fixture(b)
	var accepted: bool = b.mission.request_action("land_gao")
	b.mission.tick(1.1)
	for u in b.units: u.set_physics_process(false)
	return accepted and b.level.stage == "capture_gao" and b.level.transfer_done and b.mission.has_event("gao_landed")

func _same_frame_death(key: String) -> void:
	var b = await _start("level5")
	var prepared := _prepare_capture_fixture(b)
	var l = b.level
	var victim = l.hall if key == "hall" else b.find_unit(key)
	var accepted: bool = b.mission.request_action("capture_gao")
	b.mission.tick(1.9)
	var progress_before: float = b.mission._progress
	var hp_before: float = victim.hp
	# Use production DOT creation/dispatch and take_damage. No hp=0 or direct lose call.
	b._add_ground_dot(victim.position, 4.0, 1000000.0, 1.0, null, 0)
	# Production DOT ticks every 0.5s. Prime 0.4s without damage, so the next battle frame crosses that tick.
	b._ground_dot_pass(0.4)
	var primed_without_damage: bool = is_equal_approx(victim.hp, hp_before)
	b._physics_process(0.2)
	var lost_immediately: bool = b.phase == b.Phase.END and not b.mission.has_event("gao_captured") and victim.hp <= 0.0
	# Also exercise a stale story callback after the same real death: no success mark may appear.
	l.on_unit_resolved(b, l.gao, "captured")
	var stale_safe: bool = not b.mission.has_event("gao_captured")
	var terminal_metric: Dictionary = b.mission.stage_metrics[-1]
	var terminal_interrupted: bool = terminal_metric.stage == "capture_gao" and terminal_metric.task_interruptions == 1
	_record("dot_same_frame_" + key, prepared and accepted and progress_before >= 1.89 and primed_without_damage and lost_immediately and stale_safe and terminal_interrupted, {
		"fixture_note": "Fast-forward to capture at 1.9/2s; production 0.5s DOT primed for 0.4s without damage; both are due in the next full 0.2s battle frame.",
		"primed_without_damage": primed_without_damage,
		"task_progress_before": progress_before, "hp_before": hp_before, "hp_after": victim.hp,
		"immediate_defeat": lost_immediately, "stale_callback_safe": stale_safe, "terminal_interruption_counted": terminal_interrupted, "gao_outcome": l.gao.story_outcome,
		"events": b.mission.events.keys(), "stage_metrics": b.mission.stage_metrics})
	await _dispose(b)

func _capture_positive_control() -> void:
	var b = await _start("level5")
	var prepared := _prepare_capture_fixture(b)
	var accepted: bool = b.mission.request_action("capture_gao")
	b.mission.tick(1.9)
	b._physics_process(0.2)
	_record("capture_alive_control", prepared and accepted and b.phase == b.Phase.END and b.mission.has_event("gao_captured"), {
		"fixture_note": "Identical final capture fixture without lethal DOT; proves the pending task would otherwise complete.",
		"gao_outcome": b.level.gao.story_outcome, "events": b.mission.events.keys()})
	await _dispose(b)

func _early_clear(dead_inside: bool) -> void:
	var b = await _start("level5")
	var l = b.level
	if dead_inside:
		# Keep four living ships outside and destroy only the hull inside.  This
		# directly tests that the dead hull cannot satisfy the authored lure.
		l.lure_started = true
		l.lure_route = "main"
		l.enemy_fleet[0].position = b.map.cell_to_world(Vector2i(41, 32))
		l.enemy_fleet[0].take_damage(1000000.0, null, false, true)
	else:
		for ship in l.enemy_fleet: ship.take_damage(1000000.0, null, false, true)
	b._physics_process(STEP)
	var stale_direct_rejected := true
	if dead_inside:
		# Even a stale callback from the now-disabled alternative action cannot
		# replace an already-started authored route.
		l.on_mission_action(b,"first_direct",l.fleet[0])
		stale_direct_rejected = l.lure_route == "main" and not l.first_direct \
				and not b.mission.has_event("gao_first_direct")
	var live_officials: int = l._alive(l.enemy_fleet)
	var passed: bool
	var note: String
	if dead_inside:
		passed = b.phase == b.Phase.FIGHT and l.stage == "water_lure" and l.lure_started \
				and not l.lure_complete and live_officials == 4 \
				and not b.mission.has_event("fleet_in_ambush") and not b.mission.has_event("first_defeat") \
				and b.mission.story_goals.gao_lure.state == b.mission.STORY_PENDING and stale_direct_rejected
		note = "One destroyed hull is inside the main ambush while four living ships remain outside; the dead hull must not complete the lure."
	else:
		passed = b.phase == b.Phase.FIGHT and l.stage == "fire_prepare" and l.first_direct \
				and not l.lure_complete and live_officials == 5 \
				and b.mission.has_event("gao_first_direct") and b.mission.has_event("first_defeat") \
				and not b.mission.has_event("fleet_in_ambush") \
				and b.mission.story_goals.gao_lure.state == b.mission.STORY_MISSED
		note = "Overwhelming direct damage clears all five ships before entry; free play advances by the direct route without awarding the authored lure."
	_record("dead_hull_cannot_lure" if dead_inside else "fleet_killed_before_lure", passed, {
		"fixture_note": note, "destroyed_initial_ships": 1 if dead_inside else 5,
		"current_stage_live_officials": live_officials, "lure_goal_state": b.mission.story_goals.gao_lure.state,
		"first_direct": l.first_direct, "stale_direct_rejected": stale_direct_rejected,
		"lure_started": l.lure_started, "lure_complete": l.lure_complete, "stage": l.stage, "events": b.mission.events.keys()})
	await _dispose(b)

func _dock_edges() -> void:
	var b = await _start("level5")
	var l = b.level
	var boat = _prepare_return_fixture(b)
	var water: Vector2i = l.PRISONER_DOCK_WATER
	var land: Vector2i = l.PRISONER_DOCK_LAND
	var adjacent: bool = (water-land).abs().x + (water-land).abs().y == 1
	var types: bool = b.map.t_at(land.x,land.y) == b.map.T.DOCK and b.map.t_at(water.x,water.y) == b.map.T.WATER
	var domains: bool = b.map.is_open_cell(land,"land") and not b.map.is_open_cell(land,"water") and b.map.is_open_cell(water,"water") and not b.map.is_open_cell(water,"land")
	boat.position = b.map.cell_to_world(water+Vector2i(2,0))
	l.on_mission_action(b,"land_gao",boat)
	var remote_rejected: bool = not l.transfer_done and l.gao == null
	boat.position = b.map.cell_to_world(water)
	b.map.set_cell_t(land.x,land.y,b.map.T.SHORE)
	l.on_mission_action(b,"land_gao",boat)
	var missing_planks_rejected: bool = not l.transfer_done and l.gao == null
	b.map.set_cell_t(land.x,land.y,b.map.T.DOCK)
	var accepted: bool = b.mission.request_action("land_gao")
	b.mission.tick(1.1)
	var landed_exactly: bool = l.transfer_done and is_instance_valid(l.gao) and b.map.world_to_cell(l.gao.position) == land
	var count_before: int = b.units.filter(func(u): return is_instance_valid(u) and u.key=="gao_qiu").size()
	l.on_mission_action(b,"land_gao",boat)
	var duplicate_safe: bool = b.units.filter(func(u): return is_instance_valid(u) and u.key=="gao_qiu").size() == count_before and count_before == 1
	_record("dock_adjacent_and_atomic", adjacent and types and domains and remote_rejected and missing_planks_rejected and accepted and landed_exactly and duplicate_safe, {
		"fixture_note": "Boat start/terrain are fixture-controlled; actual task and landing callback validate distance, water and dock planks.",
		"water_cell": str(water), "land_cell": str(land), "adjacent": adjacent, "terrain_types": types, "movement_domains": domains,
		"remote_rejected": remote_rejected, "missing_planks_rejected": missing_planks_rejected,
		"landed_exactly": landed_exactly, "duplicate_safe": duplicate_safe})
	await _dispose(b)

func _lin_backtrack() -> void:
	var b = await _start("level6")
	var l = b.level
	# Fixture skips the rescue chapter only. The player-facing exit is now an explicit
	# arrival action, so committing it at the real exit must settle atomically.
	l.st = l.ESCAPE
	l.treated = true
	l.rescued = true
	l.rest_reached = true
	l.lin_freed.position = b.map.cell_to_world(l.EXIT_W)
	l.lin_freed.order_stop()
	l.lu.position = b.map.cell_to_world(l.EXIT_W + Vector2i(-1,0))
	l.lu.order_stop()
	for i in range(l.escorts.size()):
		l.escorts[i].position = b.map.cell_to_world(l.EXIT_W+Vector2i(i,1))
		l.escorts[i].order_stop()
	b.mission.mark("warn_escorts", "夹具：已完成警诫")
	b.mission.begin("edge_forest_exit_fixture", "夹具：护送到林口", "测试真实抵达并完成出林动作后立即结算，不能抢帧反悔。")
	b.mission.add_action("leave_forest", "林冲出林", l.EXIT_W, ["lin_chong"], 1.0, 24.0)
	var requested: bool = b.mission.request_action("leave_forest")
	b.mission.tick(1.1)
	var exit_completed: bool = b.mission.has_event("leave_forest")
	_step(b)
	var won_on_arrival: bool = b.phase == b.Phase.END and b.mission.has_event("yezhulin_victory") \
		and b.mission.has_event("yezhulin_four_left")
	l.lin_freed.order_move(b.map.cell_to_world(Vector2i(12,20)))
	_step(b)
	var terminal_sticky: bool = b.phase == b.Phase.END and b.mission.has_event("yezhulin_victory")
	_record("lin_exit_arrival_atomic", requested and exit_completed and won_on_arrival and terminal_sticky, {
		"fixture_note": "Starts after rescue with all four at the real exit. Completing the explicit arrival action settles atomically; a later order cannot undo the terminal result.",
		"exit_completed": exit_completed, "won_on_arrival": won_on_arrival,
		"terminal_sticky": terminal_sticky, "fixture_game_seconds": b.mission.total_game_seconds})
	await _dispose(b)

func _metrics_edges() -> void:
	var b = await _start("level6")
	var m = b.mission
	var cell: Vector2i = b.map.world_to_cell(b.level.lu.position)
	m.begin("edge_metrics_a", "夹具：计时A", "替换一次任务，再被阶段切换取消一次。")
	var total_before: float = m.total_game_seconds
	m.add_action("edge_a", "夹具A", cell,["lu_zhishen"],10.0)
	m.add_action("edge_b", "夹具B", cell,["lu_zhishen"],10.0)
	var requested: bool = m.request_action("edge_a")
	m.tick(0.5)
	requested = m.request_action("edge_b") and requested
	m.tick(0.25)
	m.begin("edge_metrics_b", "夹具：计时B", "已完成任务正常转场，不计为中断。")
	var previous: Dictionary = m.stage_metrics[-1]
	m.add_action("edge_completed", "夹具完成", cell,["lu_zhishen"],0.1)
	requested = m.request_action("edge_completed") and requested
	m.tick(0.1)
	m.begin("edge_metrics_c", "夹具：计时C", "对终局关闭去重。")
	var completed: Dictionary = m.stage_metrics[-1]
	m.tick(0.2)
	m.finish_metrics(false)
	var closed_count: int = m.stage_metrics.size()
	m.finish_metrics(false)
	var count_safe: bool = closed_count == m.stage_metrics.size()
	var accurate: bool = previous.accepted_task_commands == 2 and previous.task_interruptions == 2 and absf(previous.game_seconds-0.75)<0.00001 and completed.task_interruptions == 0 and absf(completed.game_seconds-0.1)<0.00001
	var total_safe: bool = absf(m.total_game_seconds-total_before-1.05)<0.00001
	_record("metrics_cancel_complete_close", requested and accurate and count_safe and total_safe, {"fixture_note":"Artificial 0.5/0.25/0.1/0.2s mission ticks isolate accounting; never human timing.", "two_interruptions": previous, "completed_stage": completed, "duplicate_close_safe": count_safe, "total_seconds_exact": total_safe})
	await _dispose(b)

func _metrics_terminal_action(victory: bool) -> void:
	var b = await _start("level6")
	var m = b.mission
	var cell: Vector2i = b.map.world_to_cell(b.level.lu.position)
	m.begin("edge_terminal_task", "夹具：终局中断", "任务进行中结束，重复结算不能重复计数。")
	m.add_action("edge_pending", "夹具进行中", cell, ["lu_zhishen"], 10.0)
	var requested: bool = m.request_action("edge_pending")
	m.tick(0.25)
	var pending: bool = m.active_action_id == "edge_pending" and m._progress > 0.0
	var before_count: int = m.stage_metrics.size()
	m.finish_metrics(victory)
	var recorded: Dictionary = m.stage_metrics[-1].duplicate(true)
	# Test repeated and conflicting close attempts while the canceled task ID still exists.
	m.finish_metrics(victory)
	m.finish_metrics(not victory)
	var counted_once: bool = m.stage_metrics.size() == before_count + 1 and m._stage_interruptions == 1 and m.stage_metrics[-1] == recorded
	var accurate: bool = recorded.accepted_task_commands == 1 and recorded.task_interruptions == 1 and absf(recorded.game_seconds - 0.25) < 0.00001 and recorded.end_reason == ("victory" if victory else "defeat")
	_record("metrics_terminal_" + ("victory" if victory else "defeat"), requested and pending and counted_once and accurate, {
		"fixture_note": "A real accepted task is pending after an artificial 0.25s tick; explicit terminal metric closure tests accounting only, never a victory or playthrough.",
		"task_was_pending": pending, "closed_stage": recorded, "duplicate_and_conflicting_close_safe": counted_once})
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	Engine.time_scale = 1.0
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	for key in ["hall", "song_jiang", "wu_yong"]: await _same_frame_death(key)
	await _capture_positive_control()
	await _early_clear(false)
	await _early_clear(true)
	await _dock_edges()
	await _lin_backtrack()
	await _metrics_edges()
	await _metrics_terminal_action(false)
	await _metrics_terminal_action(true)
	if results.size() != 11: failures.append("incomplete_fixture_run_expected_11")
	var directory := ProjectSettings.globalize_path("res://qa/campaign_edges")
	DirAccess.make_dir_recursive_absolute(directory)
	var out := FileAccess.open(directory.path_join("fixtures.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"fixture_only": true, "not_playthrough_or_pacing_evidence": true, "passed": failures.is_empty(), "failures": failures, "results": results}, "\t"))
	out.close()
	print("[edge-summary] ", JSON.stringify({"fixture_only":true,"passed":failures.is_empty(),"failures":failures,"cases":results.size()}))
	quit(0 if failures.is_empty() else 1)
