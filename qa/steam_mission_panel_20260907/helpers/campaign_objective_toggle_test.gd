extends SceneTree
## Focused, frozen UI fixtures with real viewport mouse input.
## No campaign route, performance, human playtest, or save/reload claim.

var output_dir := ""
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("[mission-toggle] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Mission toggle QA requires the graphical renderer.")
		quit(2)
		return
	output_dir = OS.get_environment("CAMPAIGN_TOGGLE_OUT")
	if output_dir == "":
		push_error("CAMPAIGN_TOGGLE_OUT must name a fresh evidence directory.")
		quit(2)
		return
	if FileAccess.file_exists(output_dir.path_join("report.json")):
		push_error("Refusing to overwrite an existing mission toggle report.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create mission toggle evidence directory.")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	OS.set_environment("LEVEL", "")
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.title = "Liangshan mission panel toggle QA"
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	var campaign = root.get_node("Campaign")
	var records_before: Dictionary = campaign.records.duplicate(true)
	var current_before: int = campaign.current
	var unlocked_before: int = campaign.unlocked
	var save_path: String = campaign.SAVE_PATH
	var save_existed := FileAccess.file_exists(save_path)
	var save_before := FileAccess.get_file_as_bytes(save_path) if save_existed else PackedByteArray()
	for level_id in ["level3", "level2", "level5"]:
		await _test_case(level_id, Vector2i(1280, 720))
	await _test_case("level3", Vector2i(1920, 1080))
	_check(FileAccess.file_exists(save_path) == save_existed and
		(not save_existed or FileAccess.get_file_as_bytes(save_path) == save_before),
		"campaign save bytes unchanged")
	campaign.records = records_before
	campaign.current = current_before
	campaign.unlocked = unlocked_before
	var report := {
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"samples": samples, "renderer": DisplayServer.get_name(),
		"user_data_dir": OS.get_user_data_dir(), "save_writes": false,
		"scope": "Frozen live campaign HUD: actual toggle and locator mouse clicks, released map input, hidden-state updates, layout and scrolling.",
		"human_playtest": false, "performance_test": false, "full_campaign_route": false,
	}
	var report_file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if report_file == null:
		push_error("Cannot write mission toggle report.")
		quit(2)
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("[mission-toggle-result] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _start(level_id: String, view_size: Vector2i):
	root.size = view_size
	root.content_scale_size = view_size
	DisplayServer.window_set_size(view_size)
	var campaign = root.get_node("Campaign")
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(key, false)
	campaign.current = campaign.index_for_id(level_id)
	seed(5088120)
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle._on_start_battle()
	await physics_frame
	await physics_frame
	for i in range(4):
		await process_frame
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	battle.camera.set_physics_process(false)
	for unit in battle.units:
		if is_instance_valid(unit):
			unit.set_physics_process(false)
	battle.hud.set_top(battle.level.top_status(battle))
	await _settle(battle)
	return battle


func _settle(battle) -> void:
	battle.mission.tick(0.0)
	for i in range(6):
		await process_frame
	battle.mission.tick(0.0)
	for i in range(3):
		await process_frame


func _authority(battle) -> Dictionary:
	var units: Array = []
	for unit in battle.units:
		if not is_instance_valid(unit):
			continue
		units.append([unit.get_instance_id(), unit.position, unit.hp, unit._state,
			unit._order_serial, unit._queue.duplicate(true), unit._path.duplicate(), unit._path_i,
			unit.manual_order_active, unit.manual_order_t, unit.mission_order_active,
			unit.mission_order_target, unit.mission_order_token])
	return {"units": units, "gold": battle.gold, "wood": battle.wood,
		"active_action": battle.mission.active_action_id, "progress": battle.mission._progress,
		"events": battle.mission.events.duplicate(true)}


func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	await process_frame


func _mouse_button(point: Vector2, pressed: bool, button_index := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button_index
	event.pressed = pressed
	root.push_input(event)
	await process_frame


func _click(button: Button, label: String) -> void:
	_check(button != null and button.is_visible_in_tree(), label + " is visible for real GUI input")
	if button == null or not button.is_visible_in_tree():
		return
	var point := button.get_global_rect().get_center()
	await _move_mouse(point)
	await _mouse_button(point, true)
	await _mouse_button(point, false)


func _inside(rect: Rect2, view_size: Vector2i) -> bool:
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= view_size.x + 0.5 and rect.end.y <= view_size.y + 0.5


func _rect(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y, "bottom": rect.end.y, "right": rect.end.x}


func _capture(battle, label: String, view_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var path := output_dir.path_join(label + ".png")
	var resolution_ok := frame != null and not frame.is_empty() and frame.get_size() == view_size
	var saved := resolution_ok and frame.save_png(path) == OK
	_check(saved, label + " actual frame saved at requested resolution")
	var panel: Control = battle.mission._panel
	var toggle: Button = battle.mission._toggle
	samples.append({"id": label, "level_id": battle.level.id(), "view_size": [view_size.x, view_size.y],
		"png": path, "png_ok": saved, "sha256": FileAccess.get_sha256(path) if saved else "",
		"expanded": battle.mission._expanded, "panel": _rect(panel.get_global_rect()),
		"toggle": _rect(toggle.get_global_rect()), "toggle_text": toggle.text,
		"details_visible": battle.mission._details.is_visible_in_tree(),
		"bottom_command_panel": _rect(battle.hud._bottom_panel.get_global_rect())})


func _test_case(level_id: String, view_size: Vector2i) -> void:
	var label := "%s_%dx%d" % [level_id, view_size.x, view_size.y]
	var battle = await _start(level_id, view_size)
	var mission = battle.mission
	var panel: Control = mission._panel
	var toggle: Button = mission._toggle
	_check(battle.phase == battle.Phase.FIGHT and panel.is_visible_in_tree(), label + " starts live HUD")
	_check(not mission._expanded and not mission._details.is_visible_in_tree() and
		toggle.text == "▶ 任务目标" and toggle.toggle_mode and not toggle.button_pressed,
		label + " details default collapsed with unchecked toggle")
	_check(panel.custom_minimum_size.x == 148.0 and panel.size.y <= 76.0 and
		_inside(panel.get_global_rect(), view_size), label + " collapsed panel occupies only compact control")
	_check(toggle.focus_mode == Control.FOCUS_NONE, label + " toggle cannot capture later keyboard commands")
	await _capture(battle, label + "_collapsed", view_size)
	var authority_before := _authority(battle)
	await _click(toggle, label + " expand")
	await _settle(battle)
	_check(mission._expanded and mission._details.is_visible_in_tree() and toggle.button_pressed and
		toggle.text == "▼ 收起任务" and panel.custom_minimum_size.x == 286.0,
		label + " actual click expands original details")
	_check(_authority(battle) == authority_before and not battle._dragging, label + " expand click issues no world command")
	var expanded_rect := panel.get_global_rect()
	_check(_inside(expanded_rect, view_size) and expanded_rect.end.y <= battle.hud._bottom_panel.get_global_rect().position.y - 6.0,
		label + " expanded details stay inside viewport above command cards")
	_check(mission._title.is_visible_in_tree() and mission._objective.is_visible_in_tree() and
		mission._status.is_visible_in_tree(), label + " title instructions and feedback remain visible")
	if level_id == "level2":
		_check(mission.story_goals.size() == 4 and mission._story.is_visible_in_tree(), label + " four optional goals are retained")
	await _capture(battle, label + "_expanded", view_size)
	var locator: Button = null
	for action_id in mission.actions:
		var candidate = mission.actions[action_id].get("button")
		if candidate is Button and not candidate.disabled:
			locator = candidate
			break
	_check(locator != null, label + " has a normal locator")
	if locator != null:
		if mission._scroll != null:
			mission._scroll.ensure_control_visible(locator)
			await _settle(battle)
		authority_before = _authority(battle)
		await _click(locator, label + " locator")
		_check(_authority(battle) == authority_before and not battle._dragging, label + " locator focuses without issuing movement")
	await _click(toggle, label + " collapse")
	await _settle(battle)
	_check(not mission._expanded and not mission._details.is_visible_in_tree() and panel.size.y <= 76.0 and
		panel.size.x < expanded_rect.size.x, label + " closing shrinks both hit area dimensions")
	var released_point := Vector2(expanded_rect.position.x + 24.0, panel.get_global_rect().end.y + 24.0)
	_check(expanded_rect.has_point(released_point) and not panel.get_global_rect().has_point(released_point), label + " map probe is in freed former detail area")
	await _move_mouse(released_point)
	var hovered: Control = root.gui_get_hovered_control()
	_check(hovered == null or (hovered != panel and not panel.is_ancestor_of(hovered)), label + " hidden detail descendants cannot receive hover")
	await _mouse_button(released_point, true)
	_check(battle._dragging, label + " freed area receives normal map left press")
	await _mouse_button(released_point, false)
	var elapsed_before: float = mission.elapsed
	var total_before: float = mission.total_game_seconds
	mission.tick(0.25)
	_check(is_equal_approx(mission.elapsed, elapsed_before + 0.25) and
		is_equal_approx(mission.total_game_seconds, total_before + 0.25), label + " collapsed mission keeps advancing elapsed time")
	var refreshed_text := "折叠更新夹具：目标状态保持最新。"
	mission.set_objective(refreshed_text)
	mission.set_title("折叠更新夹具")
	mission._refresh_campaign_text()
	await _settle(battle)
	_check(not mission._details.is_visible_in_tree(), label + " objective refresh cannot reopen hidden details")
	await _click(toggle, label + " reopen refreshed")
	await _settle(battle)
	_check(mission._objective.text == refreshed_text and mission._objective.is_visible_in_tree() and
		mission._title.text == "折叠更新夹具", label + " reopening shows the latest hidden updates")
	if level_id == "level5":
		await _long_list(battle, label, view_size)
	mission.begin("toggle_expanded_fixture", "展开状态阶段切换", "状态切换只更新任务内容。")
	await _settle(battle)
	_check(mission._expanded and mission._details.is_visible_in_tree(), label + " stage transition preserves expanded choice")
	await _click(toggle, label + " close before transition")
	mission.begin("toggle_collapsed_fixture", "收起状态阶段切换", "状态切换只更新任务内容。")
	await _settle(battle)
	_check(not mission._expanded and not mission._details.is_visible_in_tree(), label + " stage transition preserves collapsed choice")
	battle.phase = battle.Phase.END
	mission.tick(0.0)
	_check(not panel.is_visible_in_tree() and not toggle.is_visible_in_tree(), label + " end phase hides shell and toggle")
	await _dispose(battle)


func _long_list(battle, label: String, view_size: Vector2i) -> void:
	var mission = battle.mission
	for i in range(12):
		mission.add_action("toggle_layout_%d" % i, "后续任务滚动检查 %d" % i,
			Vector2i(45, 20 + i), ["liangshan_warship"], 1)
	await _settle(battle)
	var scroll: ScrollContainer = mission._scroll
	_check(scroll != null and scroll.is_visible_in_tree() and scroll.size.y >= 80.0, label + " long list has visible scroll area")
	if scroll == null:
		return
	_check(scroll.get_v_scroll_bar().max_value > scroll.size.y, label + " long list overflows into real scrollbar")
	var point := scroll.get_global_rect().get_center()
	await _move_mouse(point)
	for i in range(40):
		await _mouse_button(point, true, MOUSE_BUTTON_WHEEL_DOWN)
		await _mouse_button(point, false, MOUSE_BUTTON_WHEEL_DOWN)
	var last: Button = mission._buttons.get_child(-1)
	_check(scroll.scroll_vertical > 0 and scroll.get_global_rect().encloses(last.get_global_rect()), label + " actual wheel input reaches last locator")
	_check(mission._panel.get_global_rect().end.y <= battle.hud._bottom_panel.get_global_rect().position.y - 6.0,
		label + " long expanded list stays above command cards")
	await _capture(battle, label + "_long_scrolled", view_size)


func _dispose(battle) -> void:
	if is_instance_valid(battle.hud.minimap):
		battle.hud.minimap._bg = null
	if is_instance_valid(battle._fog_layer):
		battle._fog_layer.tex = null
	battle._fog_tex = null
	if battle.map.height_field != null:
		battle.map.height_field.texture = null
	battle.map.material = null
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for cursor_name in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(cursor_name, null)
	current_scene = null
	battle.queue_free()
	await process_frame
	await process_frame
