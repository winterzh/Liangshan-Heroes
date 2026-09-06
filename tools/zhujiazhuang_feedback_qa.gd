extends "res://tools/zhujiazhuang_rts_test.gd"
## Regression QA for rescued-unit controls, scrolling, and contextual defeat advice.
## Actual GUI input + frozen interaction/death fixtures; not combat route evidence.
## ZHU_FEEDBACK_OUT defaults to ignored .godot storage. Actual renderer required.
var feedback_output := "res://.godot/scratchpad/zhujiazhuang_feedback_qa"
var feedback_samples: Array = []

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var found := _find_button(child, caption)
		if found != null: return found
	return null

func _freeze(b) -> void:
	b.set_physics_process(false)
	b.set_process(false)
	for u in b.units:
		if is_instance_valid(u): u.set_physics_process(false)

func _fixture():
	var b = await _start()
	Engine.time_scale = 1.0
	# Let normal first-frame fog, world visibility, and top HUD settle before
	# freezing the explicit input fixture; screenshots must show the battle.
	await physics_frame
	await physics_frame
	await process_frame
	_freeze(b)
	check(b.phase == b.Phase.FIGHT and b.level.elapsed > 0.0 and b.is_visible_world(b.level.hall.position),
		"fixture starts the live campaign and reveals camp before simulation freezes")
	return b

func _authority(b) -> Dictionary:
	var state: Array = []
	for u in b.units:
		if not is_instance_valid(u): continue
		state.append([u.get_instance_id(), u.position, u.hp, u._state,
			u._order_serial, u._queue.duplicate(true), u._path.duplicate(), u._path_i,
			u.manual_order_active, u.manual_order_t, u.mission_order_active,
			u.mission_order_arrival_t, u.mission_order_target, u.mission_order_token])
	return {"units": state, "active_action": b.mission.active_action_id,
		"progress": b.mission._progress, "events": b.mission.events.duplicate(true),
		"elapsed": b.level.elapsed, "gold": b.gold, "wood": b.wood}

func _layout(b) -> void:
	# Frozen simulation: delta=0 only lays out the real mission controls.
	b.mission.tick(0.0)
	for i in range(6): await process_frame
	b.mission.tick(0.0)
	for i in range(3): await process_frame

func _gui_click(b, button: Button, label: String) -> void:
	check(button != null, label + " button exists")
	if button == null: return
	if b.mission._scroll != null and b.mission._scroll.is_ancestor_of(button):
		b.mission._scroll.ensure_control_visible(button)
	for i in range(3): await process_frame
	check(button.is_visible_in_tree(), label + " button is visible before actual GUI click")
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

func _save_image(b, label: String) -> void:
	await RenderingServer.frame_post_draw
	var file := feedback_output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(file) == OK, label + " actual screenshot saved")
	feedback_samples.append({"name": label, "file": file, "sha256": FileAccess.get_sha256(file),
		"panel": str(b.mission._panel.get_global_rect()), "size": str(root.size)})

func _check_layout(b, label: String) -> void:
	# Keep stage screenshots over the already visible camp; isolated rescue
	# placement must not leave later layout evidence looking into unseen fog.
	b.center_camera_cell(b.level.CAMP)
	b.hud.set_top(b.level.top_status(b))
	await _layout(b)
	check(b.mission._scroll != null, label + " has mission scroll container")
	if b.mission._scroll == null: return
	var last = b.mission._buttons.get_child(-1)
	b.mission._scroll.ensure_control_visible(last)
	for i in range(3): await process_frame
	check(b.mission._scroll.get_global_rect().encloses(last.get_global_rect()), label + " final button can scroll fully into view")
	check(b.mission._panel.get_global_rect().end.y <= b.hud._bottom_panel.get_global_rect().position.y - 6,
		label + " objective panel stays above command cards")
	await _save_image(b, label)

func _rescue_with_player_order(b) -> void:
	# Explicit isolated placement only: do not claim a real attack/rescue route.
	var action: Dictionary = b.mission.actions.zhu_rts_rescue
	var actor = b.find_unit("lin_chong")
	actor.position = b.map.cell_to_world(action.cell)
	b._grid_build()
	b.select_single(actor, false)
	b._issue_order(b.to_screen(actor.position) + Vector2(0, -22), false)
	for i in range(32): b.mission.tick(0.1)
	check(b.level.prisoners_freed and action.done, "actual mission-target player order completes isolated rescue")
	check(b.mission.has_event("zhu_prisoners_freed"), "rescue emits its normal event")

func _controls_and_layout(size: Vector2i) -> void:
	root.size = size
	root.content_scale_size = size
	DisplayServer.window_set_size(size)
	var b = await _fixture()
	var l = b.level
	check(_find_button(b.mission._buttons, "选中 · 时迁") == null and
		_find_button(b.mission._buttons, "选中 · 获救队伍") == null and
		_find_button(b.mission._buttons, "查看 · 前营") == null, "evacuation controls absent before rescue")
	await _check_layout(b, "start_" + str(size.x))
	l._introduce_sun(b)
	_freeze(b)
	await _check_layout(b, "sun_" + str(size.x))
	# Actual death callback in a frozen fixture, not a siege route.
	l.side_gate.take_damage(l.side_gate.max_hp * 20.0, null, false, true)
	await _check_layout(b, "side_gate_destroyed_" + str(size.x))
	check(not b.mission.actions.zhu_rts_inside.done and not b.mission.actions.zhu_rts_inside.marker.visible,
		"destroyed side gate remains an unsuccessful closed inside action")
	_rescue_with_player_order(b)
	await _check_layout(b, "rescued_" + str(size.x))
	var action_count: int = b.mission.actions.size()
	var buttons_count: int = b.mission._buttons.get_child_count()
	l.on_mission_action(b, "zhu_rts_rescue", l.song)
	check(b.mission._buttons.get_child_count() == buttons_count, "duplicate rescue callback cannot add duplicate controls")
	var before := _authority(b)
	await _gui_click(b, _find_button(b.mission._buttons, "选中 · 时迁"), "Shi Qian selection")
	check(b.selection == [l.prisoners[0]], "single selector uses actual rescued Shi Qian instance")
	check(_authority(b) == before, "single selector cannot move/order/advance any unit or mission")
	before = _authority(b)
	await _gui_click(b, _find_button(b.mission._buttons, "选中 · 获救队伍"), "evacuee selection")
	check(b.selection == l.prisoners and b.selection.size() == 7, "group selector selects only the seven wounded evacuees")
	check(_authority(b) == before, "group selector cannot move/order/advance any unit or mission")
	var selected_before: Array = b.selection.duplicate()
	before = _authority(b)
	await _gui_click(b, _find_button(b.mission._buttons, "查看 · 前营"), "camp locator")
	check(b.camera.position.distance_to(b.to_screen(b.map.cell_to_world(l.CAMP))) < 0.01, "camp locator moves camera to actual camp")
	check(b.selection == selected_before and _authority(b) == before, "camp locator preserves selection and all battle orders")
	check(b.mission.actions.size() == action_count, "selection/locator controls do not register extra mission flags")
	var serials: Array = l.prisoners.map(func(u): return u._order_serial)
	# Normal player ground order, outside the camp footprint (not a garrison click).
	b._issue_order(b.to_screen(b.map.cell_to_world(l.CAMP + Vector2i(-5, 0))), false)
	check(range(l.prisoners.size()).all(func(i): return l.prisoners[i]._order_serial > serials[i]),
		"a separate real player ground order is required to start retreating")
	# Mixed availability must be filtered at click time, not captured at rescue.
	l.prisoners[1].take_damage(l.prisoners[1].max_hp * 20.0, null, false, true)
	check(b.phase == b.Phase.FIGHT and b.mission.has_event("zhu_prisoner_lost"), "optional evacuee death misses story goal without core defeat")
	l.prisoners[2].garrisoned = true
	l.prisoners[3].is_captive = true
	l.prisoners[4].faction = 1
	l.prisoners[5].resolve_story("retreated")
	before = _authority(b)
	await _gui_click(b, _find_button(b.mission._buttons, "选中 · 获救队伍"), "filtered evacuee selection")
	check(b.selection == [l.prisoners[0], l.prisoners[6]], "group selection filters dead/garrisoned/captive/enemy/resolved members live")
	check(_authority(b) == before, "filtering selection does not change excluded members or orders")
	l.prisoners[0].garrisoned = true
	l.prisoners[6].garrisoned = true
	b.select_single(l.song, false)
	before = _authority(b)
	await _gui_click(b, _find_button(b.mission._buttons, "选中 · 获救队伍"), "empty evacuee selection")
	check(b.selection == [l.song] and _authority(b) == before and b.mission._status.text.contains("没有可选择的获救者"),
		"empty live group explains unavailability without selecting outsiders or changing orders")
	l.prisoners[0].garrisoned = false
	l.prisoners[6].garrisoned = false
	# Separate frozen late-game layout fixture: place the rescued objective near
	# camp and destroy the actual enemy hall, then let the level add finish action.
	l.prisoners[0].position = l.hall.position + Vector2(48, 0)
	l.enemy_base.take_damage(l.enemy_base.max_hp * 20.0, null, false, true)
	l.strategic_clock = 0.0
	l.process(b, 0.0)
	check(b.mission.actions.has("zhu_rts_finish"), "late fixture exposes ordinary finish action")
	await _check_layout(b, "finish_ready_" + str(size.x))
	before = _authority(b)
	await _gui_click(b, b.mission.actions.zhu_rts_finish.button, "finish locator")
	check(b.phase == b.Phase.FIGHT and _authority(b) == before, "viewing final task never orders Song Jiang or auto-finishes")
	await _dispose(b)

func _defeat_case(kind: String) -> void:
	var b = await _fixture()
	var l = b.level
	if kind == "shi_rescued": _rescue_with_player_order(b)
	var victim = l.hall if kind == "hall" else l.song if kind == "song" else l.prisoners[0]
	victim.take_damage(victim.max_hp * 20.0, null, false, true)
	check(b.phase == b.Phase.END and b.hud._end_root.visible, kind + " real death reaches normal defeat panel")
	var line: String = b.hud._end_sub.text
	match kind:
		"hall": check(line.contains("前营被攻破") and line.contains("右键受损建筑可修理") and not line.contains("宋江阵亡"), "hall failure explains defending and repair")
		"song": check(line.contains("宋江阵亡") and line.contains("普通兵侦察、掩护") and not line.contains("前营被攻破"), "Song Jiang failure explains safer support")
		"shi_captive": check(line.contains("营救失败") and line.contains("囚徒附近威胁") and not line.contains("护送失败"), "captive death uses rescue-stage advice")
		"shi_rescued": check(line.contains("护送失败") and line.contains("不会自行撤离") and not line.contains("营救失败"), "rescued Shi Qian death explains escort and manual retreat")
	check(line.contains("基础通关：未完成") and not b.mission.has_event("zhu_victory"), kind + " defeat never awards core success")
	# Repeated signal handling must not replace frozen end result.
	l.on_unit_died(b, victim)
	check(b.hud._end_sub.text == line, kind + " repeat failure callback does not duplicate settlement text")
	var restart := _find_button(b.hud._end_root, "重打本关")
	var menu := _find_button(b.hud._end_root, "战役地图")
	check(restart != null and menu != null, kind + " restart and map entries remain present")
	for i in range(4): await process_frame
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(b.hud._end_sub.get_global_rect()), kind + " defeat advice fits the viewport")
	await _save_image(b, "defeat_" + kind)
	if kind == "song":
		var previous: int = b.get_instance_id()
		await _gui_click(b, restart, "defeat restart")
		for i in range(20):
			if current_scene != null and current_scene.get_instance_id() != previous: break
			await process_frame
		b = current_scene
		check(b != null and b.get_instance_id() != previous and b.level.id() == "level3", "real restart button opens a new instance of the same chapter")
		if b != null: _freeze(b)
	if b != null: await _dispose(b)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Actual renderer is required for this GUI QA")
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	root.get_node("Settings").edge_scroll = false
	Engine.max_fps = 60
	if not OS.get_environment("ZHU_FEEDBACK_OUT").is_empty(): feedback_output = OS.get_environment("ZHU_FEEDBACK_OUT")
	DirAccess.make_dir_recursive_absolute(feedback_output)
	for size in [Vector2i(1280, 720), Vector2i(1440, 900)]: await _controls_and_layout(size)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	for kind in ["hall", "song", "shi_captive", "shi_rescued"]: await _defeat_case(kind)
	var report := {"checks": checks, "passed": failures.is_empty(), "failures": failures,
		"samples": feedback_samples, "scope": "real GUI input; frozen and explicitly placed interaction/death fixtures; not live combat or first-player acceptance"}
	var file := FileAccess.open(feedback_output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not create feedback QA report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[zhu-feedback] ", checks, " checks; failures=", failures)
	quit(0 if failures.is_empty() else 1)
