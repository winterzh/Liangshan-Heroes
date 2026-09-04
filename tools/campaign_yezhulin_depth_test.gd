extends SceneTree
## Natural-flow checks for the opening campaign chapter. The hostile escort
## advances the opening story; after rescue, all four friendlies require player orders.

var failures: Array[String] = []
var checks := 0
var evidence: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("[yezhulin-flow] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _start():
	seed(5088120)
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == "level6":
			campaign.current = i
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b._smoke = false
	Engine.time_scale = 6.0
	return b

func _wait_until(predicate: Callable, limit := 6000) -> bool:
	var frames := 0
	while not predicate.call() and frames < limit:
		await process_frame
		frames += 1
	return bool(predicate.call())

func _place(b, u, p: Vector2) -> void:
	u.order_stop()
	u.position = p
	b.map.sync_render_position(u)

func _capture_convoy_if_rendered(b, l) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var output_dir := ProjectSettings.globalize_path("res://qa/campaign_yezhulin_player_command_20260904/visual")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		return ""
	b.camera.position = b.to_screen(l.lin_freed.position)
	b.camera.zoom = Vector2.ONE * 1.25
	b.camera.force_update_scroll()
	b._grid_build()
	b.mission.tick(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot_path := output_dir.path_join("level6_player_control_choice_1280.png")
	var frame_image := root.get_texture().get_image()
	if frame_image == null or frame_image.is_empty() or frame_image.get_size() != Vector2i(1280, 720):
		return ""
	return screenshot_path if frame_image.save_png(screenshot_path) == OK else ""

func _manual_action(b, actor, action_id: String, limit := 2400) -> bool:
	if not b.mission.actions.has(action_id):
		return false
	var stage_id: String = b.mission.stage_id
	var destination: Vector2 = b.map.cell_to_world(b.mission.actions[action_id].cell)
	b.select_single(actor, false)
	b._issue_order(b.to_screen(destination), false)
	var event_id := "action:%s:%s" % [stage_id, action_id]
	return await _wait_until(func(): return b.mission.has_event(event_id) or b.phase == b.Phase.END, limit) \
		and b.mission.has_event(event_id)

func _manual_story_escort_action(b, l, action_id: String, limit := 3600) -> Dictionary:
	if not b.mission.actions.has(action_id):
		return {"passed": false, "propagated": false, "max_lu_gap": INF, "max_guard_gap": INF}
	var stage_id: String = b.mission.stage_id
	var destination: Vector2 = b.map.cell_to_world(b.mission.actions[action_id].cell)
	# Reproduce the player's report: only Lin Chong is selected. The story-level
	# formation must convert this one player destination into the four-person escort.
	b.select_single(l.lin_freed, false)
	b._issue_order(b.to_screen(destination), false)
	var event_id := "action:%s:%s" % [stage_id, action_id]
	var propagated := false
	var max_lu_gap := 0.0
	var max_guard_gap := 0.0
	var frames := 0
	while not b.mission.has_event(event_id) and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
		var group: Array = l._escort_group()
		if group.size() == 4:
			propagated = propagated or group.all(func(u): return u.manual_order_active or u.mission_order_arrival_t > 0.0)
			max_lu_gap = maxf(max_lu_gap, l.lu.position.distance_to(l.lin_freed.position))
			for guard in l.escorts:
				max_guard_gap = maxf(max_guard_gap, guard.position.distance_to(l.lin_freed.position))
	return {"passed": b.mission.has_event(event_id), "propagated": propagated,
		"max_lu_gap": max_lu_gap, "max_guard_gap": max_guard_gap}

func _dispose(b) -> void:
	if is_instance_valid(b):
		b.queue_free()
	await process_frame
	await process_frame

func _idle_failure_case() -> void:
	var b = await _start()
	check(b.mission.actions.is_empty() and b.mission._buttons.get_child_count() == 0,
		"开场没有代玩式自动寻路按钮")
	var ended := await _wait_until(func(): return b.phase == b.Phase.END, 6000)
	check(ended and b.mission.has_event("yezhulin_missed_rescue") and not b.mission.has_event("yezhulin_victory"),
		"鲁智深完全不跟时押送剧情仍继续，到松树后林冲遇害并失败")
	evidence.append({"case":"idle_failure", "events":b.mission.events.keys(), "stage":b.mission.stage_id})
	await _dispose(b)

func _follow_and_rescue_case() -> void:
	var b = await _start()
	var l = b.level
	_place(b, l.lu, b.map.cell_to_world(Vector2i(34, 16)))
	var rescue_ready := await _wait_until(func(): return l.st == l.RESCUE or b.phase == b.Phase.END, 6000)
	var hidden_action: Dictionary = b.mission.actions.get("intercept", {})
	check(rescue_ready and l.st == l.RESCUE and l.shadow_route == "north_pines" \
			and is_equal_approx(l.exec_timer, 34.0),
		"北侧松林真实站位会进入较近但反应时间较短的拦棍窗口")
	check(not hidden_action.is_empty() and b.mission._buttons.get_child_count() == 0 \
			and not bool(hidden_action.get("show_button", true)) and hidden_action.marker.show_caption,
		"拦棍只显示场景标记，左侧不出现自动派遣按钮")
	check(await _manual_action(b, l.lu, "intercept"), "拦棍仍由玩家真实右键、移动和到位计时完成")
	check(await _wait_until(func(): return l.st == l.ESCAPE, 2400) \
			and b.mission.has_event("untie") and b.mission.has_event("tend_feet"),
		"拦棍后解缚与照伤作为现场演出自然继续")
	var group: Array = [l.lin_freed, l.lu] + l.escorts
	check(group.all(func(u): return is_instance_valid(u) and u.faction == l.lu.faction \
			and u.story_outcome == "" and not u.garrisoned),
		"救人后林冲、鲁智深与两名解差都进入玩家可选编组")
	check(b.mission.actions.has("rest_stop") and not b.mission.actions.has("leave_forest") \
			and b.mission._buttons.get_child_count() == 1,
		"救人后只开放四人歇脚，不再提供林冲单独出林路线")
	var waiting_positions: Array[Vector2] = []
	for unit in group:
		waiting_positions.append(unit.position)
	b.select_single(l.lin_freed, false)
	var lin_serial_before: int = l.lin_freed._order_serial
	b.mission.actions["rest_stop"].button.emit_signal("pressed")
	for _i in range(180):
		await process_frame
	var nobody_taken_over := true
	for i in range(group.size()):
		nobody_taken_over = nobody_taken_over and group[i].position.distance_to(waiting_positions[i]) < 2.0 \
			and group[i]._state == 0 and group[i]._path.is_empty()
	check(nobody_taken_over and b.mission.active_action_id == "" \
			and l.lin_freed._order_serial == lin_serial_before,
		"只选林冲点击查看并等待，四人位置、路径和命令序号都不变")
	var rogue_start: Vector2 = l.lin_freed.position
	l.lin_freed.order_move(b.map.cell_to_world(l.EXIT_W))
	for _i in range(6):
		await process_frame
	check(l.lin_freed.position.distance_to(rogue_start) < 2.0 and l.lin_freed._state == 0 \
			and b.mission.has_event("post_rescue_auto_move_blocked"),
		"没有玩家输入凭证的林冲单走命令会被关卡当帧拦停")
	var rest_move := await _manual_story_escort_action(b, l, "rest_stop")
	check(bool(rest_move.passed) and bool(rest_move.propagated) and b.mission.has_event("warn_escorts") \
			and float(rest_move.max_lu_gap) <= 96.0 and float(rest_move.max_guard_gap) <= 96.0,
		"只给林冲一次玩家路线，鲁智深领队、董超薛霸夹扶，四人结队到歇脚处")
	check(b.mission.stage_id == "escort_exit" and b.mission.actions.has("leave_forest") \
			and b.mission._buttons.get_child_count() == 1,
		"四人歇脚到齐后才开放下一段结队出林")
	b._set_selection(group)
	var convoy_capture := await _capture_convoy_if_rendered(b, l)
	await _wait_until(func(): return group.all(func(u): return u._path_i >= u._path.size()), 1200)
	var after_rest: Array[Vector2] = []
	for unit in group:
		after_rest.append(unit.position)
	for _i in range(60):
		await process_frame
	var waits_for_second_order := true
	for i in range(group.size()):
		waits_for_second_order = waits_for_second_order and group[i].position.distance_to(after_rest[i]) < 2.0
	check(waits_for_second_order, "歇脚完成后仍等待玩家第二条出林命令")
	var exit_move := await _manual_story_escort_action(b, l, "leave_forest")
	check(bool(exit_move.passed) and bool(exit_move.propagated) \
			and float(exit_move.max_lu_gap) <= 96.0 and float(exit_move.max_guard_gap) <= 96.0,
		"玩家第二次只点一人下令，四人仍保持原著相送关系出林")
	var exit_ended := await _wait_until(func(): return b.phase == b.Phase.END, 600)
	check(exit_ended,
		"四人真实抵达林口后完成核心通关")
	check(b.phase == b.Phase.END and b.mission.has_event("yezhulin_victory") and b.mission.has_event("yezhulin_four_left"),
		"林冲不能单独结算；歇脚、警诫和四人同出均来自两次玩家路线")
	evidence.append({"case":"manual_follow", "events":b.mission.events.keys(), "stage_metrics":b.mission.stage_metrics,
		"player_route_orders":2, "rest_move":rest_move, "exit_move":exit_move, "visual_capture":convoy_capture})
	await _dispose(b)

func _close_warning_case() -> void:
	var b = await _start()
	var l = b.level
	_place(b, l.lu, l.escorts[0].position + Vector2(32, 0))
	var close_frames := 0
	while not l.shadow_warning and l.st == l.STALK and close_frames < 120:
		_place(b, l.lu, l.escorts[0].position + Vector2(32, 0))
		await process_frame
		close_frames += 1
	_place(b, l.lu, b.map.cell_to_world(Vector2i(34, 16)))
	check(await _wait_until(func(): return l.st == l.RESCUE or b.phase == b.Phase.END, 6000) \
			and l.shadow_cautioned and l.shadow_warning and is_equal_approx(l.exec_timer, 24.0),
		"贴得过近不卡剧情，但会缩短拦棍时间")
	evidence.append({"case":"close_warning", "events":b.mission.events.keys(), "timer":l.exec_timer})
	await _dispose(b)

func _recoverable_caution_south_case() -> void:
	var b = await _start()
	var l = b.level
	var caution_frames := 0
	while not l.shadow_cautioned and l.st == l.STALK and caution_frames < 60:
		_place(b, l.lu, l.escorts[0].position + Vector2(72, 0))
		await process_frame
		caution_frames += 1
	_place(b, l.lu, b.map.cell_to_world(Vector2i(34, 25)))
	check(await _wait_until(func(): return l.st == l.RESCUE or b.phase == b.Phase.END, 6000) \
			and l.shadow_cautioned and not l.shadow_warning and l.shadow_route == "south_reeds" \
			and is_equal_approx(l.exec_timer, l.EXEC_TIME),
		"第一次靠近警告可挽回；退到南侧芦丛后保留完整拦棍时间")
	evidence.append({"case":"recoverable_caution_south", "events":b.mission.events.keys(),
		"timer":l.exec_timer, "route":l.shadow_route})
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
		root.title = "野猪林结队出林视觉回归"
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	await _idle_failure_case()
	await _follow_and_rescue_case()
	await _close_warning_case()
	await _recoverable_caution_south_case()
	var report_dir := ProjectSettings.globalize_path("res://qa/campaign_yezhulin_player_command_20260904")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var report := {"passed":failures.is_empty(), "checks":checks, "failures":failures, "cases":evidence,
		"scope":"Natural chapter flow, recoverable stealth warning, hidden manual intercept, hard player-order guard, and two real four-person escort orders after rescue. Automated fixture; not human pacing evidence."}
	var file := FileAccess.open(report_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[yezhulin-flow-result] ", JSON.stringify(report))
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
