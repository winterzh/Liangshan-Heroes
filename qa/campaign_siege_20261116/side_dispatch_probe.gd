extends "res://tools/zhujiazhuang_rts_test.gd"

const BUTTON := "zhu_send_sun_li"
const ACTION := "zhu_rts_inside"

func _click_control(button: Button) -> bool:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		return false
	button.pressed.emit()
	return true


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.size = Vector2i(960, 540)
	AudioServer.set_bus_mute(0, true)
	var b = await _start("", 2)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for unit in b.units:
		unit.set_physics_process(false)
	var level = b.level
	if b.phase != b.Phase.FIGHT:
		b.phase = b.Phase.FIGHT
		level.on_start(b)
	var mission = b.mission
	check(mission.find_level_button(BUTTON) == null, "the order stays hidden until Sun Li is available")
	level.on_mission_action(b, "zhu_rts_recon", level.song)
	var sun = level.sun
	sun.set_physics_process(false)
	var button: Button = mission.find_level_button(BUTTON)
	check(button != null and button.get_index() == 0, "the real chapter gives the current shortcut first")
	if button == null:
		await _finish(b)
		return
	mission._panel.show()
	mission._toggle.button_pressed = true
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	var locales := {}
	for locale in ["zh_CN", "zh_TW", "en", "ja"]:
		root.get_node("Localize").set_language(locale, false)
		for frame in range(6): await process_frame
		RenderingServer.force_draw(false)
		var rect := button.get_global_rect()
		var clip: Rect2 = mission._detail_scroll.get_global_rect()
		locales[locale] = button.text
		var expected: String = "派孙立去偏门" if locale == "zh_CN" else catalog["派孙立去偏门"][locale]
		var tip_source := "派孙立前往偏门旗标接应。等他到场并完成接应后，军队才能从偏门进入。"
		var tooltip: String = tip_source if locale == "zh_CN" else catalog[tip_source][locale]
		check(button.is_visible_in_tree() and clip.encloses(rect) and b.hud.command_panel_top() >= rect.end.y
			and button.text == expected and button.tooltip_text == tooltip, locale + " visible translated button and tooltip")
	root.get_node("Localize").set_language("zh_CN", false)
	for frame in range(5): await process_frame

	b.select_single(level.song, false)
	var before: int = sun._order_serial
	var song_serial: int = level.song._order_serial
	var camera_position: Vector2 = b.camera.position
	var target: Vector2 = b.map.cell_to_world(mission.actions[ACTION].cell)
	var origin: Vector2 = sun.position
	var cell: Vector2i = b.map.world_to_cell(origin)
	b.map.block_footprint(cell, 0, true)
	check(_click_control(button) and sun._order_serial == before and not sun.mission_order_active,
		"a temporarily blocked route preserves Sun Li's existing order")
	b.map.block_footprint(cell, 0, false)
	check(_click_control(button) and sun._order_serial == before + 1 and sun.mission_order_active
		and sun.mission_order_target == target and not sun._path.is_empty(), "the installed button signal sends the normal mission move")
	check(level.song._order_serial == song_serial and b.selection == [level.song] and b.camera.position == camera_position,
		"the front line keeps its orders, selection and camera")
	check(not level.inside_open and not mission.has_event("zhu_gate_opened"), "dispatch leaves both the gate and the story reward untouched")
	var dispatch: int = sun._order_serial
	var token: int = sun.mission_order_token
	check(_click_control(button) and sun._order_serial == dispatch and sun.mission_order_token == token,
		"repeated clicks preserve the active route exactly")
	b.select_single(sun, false)
	b._order_stop()
	check(not sun.mission_order_active and sun._path.is_empty(), "the standard stop command cancels the route")
	check(_click_control(button) and sun.mission_order_active and sun.mission_order_token != token,
		"the button can dispatch a fresh route after Stop")

	level.defense_state = "feint"
	mission.events[level.FEINT_SHIFTS[0]] = true
	var opened_at := -1
	var action_started_at := -1
	for i in range(5400):
		b._grid_build()
		sun._physics_process(1.0 / 60.0)
		mission.tick(1.0 / 60.0)
		if action_started_at < 0 and mission.active_action_id == ACTION:
			action_started_at = i
		if level.inside_open:
			opened_at = i
			break
	check(sun.position.distance_to(origin) > 100.0 and sun.position.distance_to(target) <= float(mission.actions[ACTION].reach)
		and action_started_at >= 0, "Sun Li physically travels the authored map to handle the gate")
	check(opened_at >= action_started_at + 299 and mission.has_event("zhu_gate_opened")
		and mission.has_event(level.FEINT_AT_SIDE) and not level.main_breached,
		"the real five-second handoff opens only the side gate and records the existing feint result")
	level._update_inside_shortcut(b)
	check(mission.find_level_button(BUTTON) == null, "the command is removed once the gate is open")
	var audit: Dictionary = load("res://scripts/run_campaign_level_state.gd").new().audit_declarations("level3")
	check(audit.ok, "the existing persisted level declaration remains valid")
	print("ZHU_SIDE_DISPATCH ", JSON.stringify({"checks": checks, "failures": failures, "size": [root.size.x, root.size.y],
		"locales": locales, "walk_seconds": float(action_started_at) / 60.0, "opened_seconds": float(opened_at) / 60.0}))
	await _finish(b)


func _finish(b) -> void:
	await _dispose(b)
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)
