extends "res://tools/campaign_mode_performance_test.gd"
## Real GUI input and scene transitions; quit dispatch is intercepted to keep QA running.
var quit_dispatches := 0
var end_restart_dispatches := 0

func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var found := _button(child, caption)
		if found != null: return found
	return null

func _click(button: Button) -> void:
	check(button != null and button.is_visible_in_tree(), "requested GUI button is visible")
	if button == null: return
	for i in range(3): await process_frame
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _state(b) -> Dictionary:
	var units := []
	for u in b.units:
		if is_instance_valid(u): units.append([u.get_instance_id(), u.position, u.hp])
	return {"units": units, "phase": b.phase, "events": b.mission.events.duplicate(true) if b.mission != null else {}}

func _capture(hud, label: String, size: Vector2i) -> void:
	root.size = size
	root.content_scale_size = size
	DisplayServer.window_set_size(size)
	for i in range(8): await RenderingServer.frame_post_draw
	var viewport := Rect2(Vector2.ZERO, Vector2(size))
	var bounds: Rect2 = hud._pause_confirm.get_global_rect()
	check(viewport.encloses(bounds), label + " confirmation fits viewport")
	check(hud._pause_confirm_text.get_visible_line_count() == hud._pause_confirm_text.get_line_count(), label + " warning text is not truncated")
	var path := output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, label + " actual renderer capture saved")
	report.samples.append({"file": label + ".png", "size": [size.x, size.y], "sha256": FileAccess.get_sha256(path), "confirmation_rect": str(bounds)})

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Actual renderer required for pause menu QA")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	output = ProjectSettings.globalize_path("res://.godot/pause_menu_qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	Engine.max_fps = 60
	root.get_node("Settings").edge_scroll = false
	AudioServer.set_bus_mute(0, true)
	var save_before := _save_hash()
	var campaign = root.get_node("Campaign")
	var records_before: Dictionary = campaign.records.duplicate(true)
	var unlocked_before: int = campaign.unlocked
	var b = await _start("level6")
	var hud = b.hud
	check(b.phase == b.Phase.FIGHT, "fixture reached an active battle before pausing")
	b._open_pause()
	var before := _state(b)
	for caption in ["重新开始本局", "返回主菜单", "退出游戏"]:
		await _click(_button(hud._pause_options, caption))
		check(paused and current_scene == b and hud._pause_confirm.visible, caption + " first click keeps scene paused")
		check(root.gui_get_focus_owner() == hud._pause_cancel_button, caption + " default keyboard action is cancel")
		for i in range(15): await process_frame
		check(_state(b) == before, caption + " units health and mission stay unchanged during confirmation")
		if caption == "重新开始本局":
			var was_expanded: bool = hud._info_expanded
			await _click(hud._info_toggle)
			check(hud._info_expanded == was_expanded and hud._pause_confirm.visible, "modal blocks the underlying information drawer button")
			await _capture(hud, "restart_1280", Vector2i(1280, 720))
			await _capture(hud, "restart_960", Vector2i(960, 540))
			await _key(KEY_ENTER)
		elif caption == "返回主菜单":
			await _key(KEY_ESCAPE)
		else:
			await _click(hud._pause_cancel_button)
		check(paused and current_scene == b and not hud._pause_confirm.visible and hud._pause_pending_action == "", caption + " cancel returns to pause without dispatch")
	await _click(_button(hud._pause_options, "退出游戏"))
	b._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(paused and not hud._pause_confirm.visible, "Android back cancels confirmation and stays paused")
	b._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not paused and not hud._pause_root.visible, "second Android back resumes battle")
	b._open_pause()
	await _key(KEY_ESCAPE)
	check(not paused and not hud._pause_root.visible, "Escape from ordinary pause resumes battle")
	b._open_pause()
	await _click(_button(hud._pause_options, "重新开始本局"))
	hud.hide_pause()
	hud.show_pause()
	check(hud._pause_pending_action == "" and not hud._pause_confirm.visible, "reopening pause clears stale departure")
	# Keep real scene reload and menu connections; only quit is replaced by a signal spy.
	for connection in hud.quit_game.get_connections(): hud.quit_game.disconnect(connection.callable)
	hud.quit_game.connect(func(): quit_dispatches += 1)
	await _click(_button(hud._pause_options, "退出游戏"))
	await _click(hud._pause_confirm_button)
	hud._confirm_pause_action()
	check(quit_dispatches == 1, "confirmed quit dispatches exactly once despite repeated callback")
	check(not root.get_node("AppLifecycle").quit_started(), "QA intercepts quit before application shutdown")
	hud.show_pause()
	await _click(_button(hud._pause_options, "重新开始本局"))
	var old_scene: WeakRef = weakref(b)
	await _click(hud._pause_confirm_button)
	for i in range(8): await process_frame
	b = current_scene
	check(old_scene.get_ref() == null and b != null and b.scene_file_path == "res://scenes/main.tscn", "confirmed restart actually frees old battle and reloads main scene")
	check(not paused and b.level.id() == "level6" and b.mission.events.is_empty(), "restart preserves chapter and resets mission while unpaused")
	b.hud._intro_root.hide(); b._on_intro_done(); b.hud._on_start_pressed()
	b._open_pause()
	await _click(_button(b.hud._pause_options, "返回主菜单"))
	old_scene = weakref(b)
	await _click(b.hud._pause_confirm_button)
	for i in range(8): await process_frame
	check(old_scene.get_ref() == null and current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn" and not paused, "confirmed return actually reaches main menu and releases paused scene")
	current_scene.queue_free()
	await process_frame
	b = await _start("level7", true)
	b.hud.set_touch_ui(true)
	b._open_pause()
	await _click(_button(b.hud._pause_options, "返回主菜单"))
	check(b.level.id() == "arena" and paused and b.hud._pause_confirm.visible, "sandbox mode also protects active battle")
	await _click(b.hud._menu_btn)
	check(b.hud._pause_confirm.visible and b.hud._pause_pending_action == "menu", "modal blocks the underlying touch menu button")
	await _click(b.hud._pause_cancel_button)
	await _click(_button(b.hud._pause_options, "继续 (Esc)"))
	check(not paused and not b.hud._pause_root.visible, "sandbox cancel and continue resume same scene")
	for connection in b.hud.restart.get_connections(): b.hud.restart.disconnect(connection.callable)
	b.hud.restart.connect(func(): end_restart_dispatches += 1)
	b.phase = b.Phase.END
	b.hud.show_end(false, "QA settlement fixture", 0)
	await _click(_button(b.hud._end_root, "重打本关"))
	check(end_restart_dispatches == 1 and not b.hud._pause_confirm.visible, "settled battle keeps its direct replay action")
	await _dispose(b, true)
	check(campaign.records == records_before and campaign.unlocked == unlocked_before, "chapter records and unlocks are unchanged")
	check(_save_hash() == save_before, "player campaign save bytes unchanged")
	check(report.samples.size() == 2, "both actual renderer size captures completed")
	report["scope"] = "Real GUI mouse/key input, campaign reload/menu transitions and arena cancellation; touch layout and Android back notification simulated on Windows; quit and settlement replay signals intercepted, no OS exit claim."
	report["passed"] = failures.is_empty()
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("[pause-menu-summary] ", JSON.stringify({"passed": failures.is_empty(), "checks": report.mode_checks.size(), "captures": report.samples.size()}))
	quit(0 if failures.is_empty() else 1)
