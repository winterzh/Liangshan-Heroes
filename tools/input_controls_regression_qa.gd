extends SceneTree
## Run only in a copied project with a custom, isolated user-data directory.
## Required env: STEAM_DISABLED=1 CAMPAIGN_QA=1 LSH_INPUT_QA_PROJECT=<copy>
## LSH_INPUT_QA_PROFILE=<exact OS.get_user_data_dir()>; never change HOME.
## Launch: Godot --headless --path <copy> --script res://tools/input_controls_regression_qa.gd
## Production scripts load after autoload initialization, including with --script.
var checks: Array = []
var observations: Array = []
var failures: Array = []

class InputRecorder extends Node:
	var events: Array = []
	func _input(event: InputEvent) -> void:
		if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
			events.append({"type": event.get_class(), "device": event.device})

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	if not ok:
		failures.append(label)
		push_error("INPUT_CONTROLS_QA: " + label)

func observe(label: String, data: Dictionary) -> void:
	observations.append({"label": label, "values": data})

func _settle(count := 2) -> void:
	for i in range(count): await process_frame

func _private_profile_valid() -> bool:
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	var expected_project := OS.get_environment("LSH_INPUT_QA_PROJECT").replace("\\", "/").simplify_path().trim_suffix("/")
	var profile := OS.get_user_data_dir().replace("\\", "/").simplify_path().trim_suffix("/")
	var expected_profile := OS.get_environment("LSH_INPUT_QA_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	return expected_project.is_absolute_path() and project == expected_project \
		and expected_profile.is_absolute_path() and profile == expected_profile \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-") \
		and OS.get_environment("CAMPAIGN_QA") == "1" and OS.get_environment("STEAM_DISABLED") == "1"

func _make_battle(touch: bool):
	OS.set_environment("TOUCH_UI", "1" if touch else "0")
	var campaign = root.get_node("Campaign")
	for key in ["arena", "skirmish_ai", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(key, false)
	campaign.skirmish = true
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	# Freeze gameplay while keeping genuine GUI/camera event routing active.
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	battle.phase = 2 # Battle.Phase.FIGHT
	battle.hud._intro_root.hide()
	battle.hud._end_root.hide()
	battle.hud.start_btn.hide()
	for unit in battle.units:
		unit.set_physics_process(false)
	await _settle()
	check(battle.gameplay_rng_fault().is_empty(), "valid battle fixture")
	return battle

func _release_battle(battle) -> void:
	current_scene = null
	battle.queue_free()
	await _settle()

func _hud_state(hud) -> Dictionary:
	return {"touch_ui": hud.touch_ui, "selected_count": hud._sel_ref.size(),
		"collapsed": hud._bottom_collapsed,
		"portrait": hud._port_holder.is_visible_in_tree(),
		"info": hud._info_box.is_visible_in_tree(),
		"commands": hud._skill_bar.is_visible_in_tree(),
		"command_count": hud._skill_bar.get_child_count(),
		"selection_grid": hud._sel_grid.get_parent().is_visible_in_tree(),
		"unselected_hint": hud._bottom_hint.is_visible_in_tree(),
		"minimap": str(hud.minimap.custom_minimum_size),
		"panel_top": hud._bottom_panel.offset_top,
		"camera_panel_height": hud.battle.camera.PANEL_H}

func _check_panel(battle, expanded: bool, label: String) -> void:
	var hud = battle.hud
	var state := _hud_state(hud)
	observe(label, state)
	for key in ["portrait", "info", "commands", "selection_grid"]:
		check(bool(state[key]) == expanded, label + ": " + key)
	check(bool(state.collapsed) != expanded and bool(state.unselected_hint) != expanded,
		label + ": collapse and hint match selection/input mode")
	var height := 158.0 if expanded else 92.0
	var safe: Vector4 = hud._logical_safe_insets()
	check(is_equal_approx(hud._bottom_panel.offset_top, -height - safe.w), label + ": physical panel height")
	check(is_equal_approx(float(state.camera_panel_height), height), label + ": camera panel height")
	check(hud.minimap.custom_minimum_size == (Vector2(132, 132) if expanded else Vector2(72, 72)),
		label + ": minimap size")

func _find_unit(battle, kind: String):
	for unit in battle.units:
		if unit.faction != 0 or unit.hp <= 0.0: continue
		if kind == "worker" and unit.is_worker: return unit
		if kind == "building" and unit.is_building and unit.setup_def.has("produces"): return unit
	return null

func _spawn_hero(battle):
	var hero = battle.spawn_unit("lin_chong", 0, battle.map.cell_to_world(
		battle.map.nearest_open(battle.level.camera_start_cell() + Vector2i(3, 3))))
	hero.set_physics_process(false)
	hero.auto_micro = false
	return hero

func _selection_case(battle, unit, label: String) -> void:
	check(is_instance_valid(unit), label + ": fixture unit exists")
	if not is_instance_valid(unit): return
	battle.select_single(unit, false)
	await _settle()
	_check_panel(battle, true, label)
	check(battle.hud._skill_bar.get_child_count() > 0, label + ": actionable commands present")

func _reset_skill(battle, hero) -> void:
	battle.cancel_armed()
	hero._hero_leveled = true
	hero.hero_level = 5
	hero.skill_points = 2
	hero.ability_slots[0]["rank"] = 1
	hero.ability_slots[0]["cd_t"] = 0.0

func _click_skill(button, point: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	button._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.pressed = false
	button._gui_input(release)

func _skill_button(battle, hero, compact: bool):
	var rows: Array = battle.hud._skill_rail.get_children() if compact else [battle.hud._skill_bar]
	for row in rows:
		for child in row.get_children():
			if child.has_method("_can_aim_cast") and child.hero == hero and child.slot == 0:
				return child
	return null

func _skill_click_case(battle, hero, compact: bool, point: Vector2, learns: bool, label: String) -> void:
	_reset_skill(battle, hero)
	var button = _skill_button(battle, hero, compact)
	check(button != null, label + ": production button exists")
	if button == null: return
	_click_skill(button, point)
	observe(label, {"point": str(point), "rank": hero.ability_slots[0]["rank"],
		"points": hero.skill_points, "armed": battle._ability_armed})
	check(int(hero.ability_slots[0]["rank"]) == (2 if learns else 1), label + ": correct rank")
	check(hero.skill_points == (1 if learns else 2), label + ": correct point cost")
	check(battle._ability_armed == ("" if learns else "lin_thrust"), label + ": learn/cast distinction")
	battle.cancel_armed()

func _mobile_rail_learning_contract(battle, hero) -> void:
	_reset_skill(battle, hero)
	var button = _skill_button(battle, hero, true)
	check(_skill_button(battle, hero, false) == null, "mobile command card has no duplicate hero skills")
	check(button != null and button.is_visible_in_tree(), "mobile right rail remains the visible learning control")
	if button == null: return
	var center: Vector2 = button._learn_plus_center()
	check(Rect2(Vector2.ZERO, button.size).has_point(center) and button._is_learn_hit(center),
		"mobile right rail rendered plus center is inside its production hit region")
	_click_skill(button, center)
	check(int(hero.ability_slots[0]["rank"]) == 2 and hero.skill_points == 1 and battle._ability_armed == "",
		"mobile right rail plus learns exactly once without arming a spell")
	observe("mobile single skill surface", {"size": str(button.size), "center": str(center),
		"radius": button._learn_plus_radius(), "rank": hero.ability_slots[0]["rank"], "points": hero.skill_points})
	battle.cancel_armed()

func _dispatch(event: InputEvent, watcher: InputRecorder, camera, label: String, touch: bool) -> void:
	watcher.events.clear()
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	observe(label, {"events": watcher.events.duplicate(true), "touch_mode": camera.touch_mode})
	check(not watcher.events.is_empty(), label + ": real Viewport input received")
	check(camera.touch_mode == touch, label + ": correct camera input mode")

func _touch_event(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event

func _drag_event(index: int, position: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	return event

func _touch_sequence(battle) -> void:
	var watcher := InputRecorder.new()
	root.add_child(watcher)
	var camera = battle.camera
	var old_emulation := Input.emulate_mouse_from_touch
	var old_accumulation := Input.use_accumulated_input
	Input.emulate_mouse_from_touch = true
	Input.use_accumulated_input = false
	await _dispatch(_touch_event(0, Vector2(650, 280), true), watcher, camera, "first finger down", true)
	await _dispatch(_drag_event(0, Vector2(640, 280), Vector2(-10, 0)), watcher, camera, "single finger drag", true)
	check(watcher.events.any(func(e): return e.type == "InputEventMouseMotion" and e.device == -1),
		"drag exercised Godot's synthetic mouse event")
	await _dispatch(_touch_event(1, Vector2(710, 280), true), watcher, camera, "second finger down", true)
	await _dispatch(_drag_event(1, Vector2(720, 280), Vector2(10, 0)), watcher, camera, "second finger drag", true)
	await _dispatch(_drag_event(0, Vector2(630, 280), Vector2(-10, 0)), watcher, camera, "pinch first finger drag", true)
	await _dispatch(_touch_event(1, Vector2(720, 280), false), watcher, camera, "second finger released", true)
	await _dispatch(_touch_event(0, Vector2(630, 280), false), watcher, camera, "first finger released", true)
	check(camera._touches.is_empty(), "all fingers cleared after gesture")
	var mouse := InputEventMouseMotion.new()
	mouse.device = 0
	mouse.position = Vector2(640, 280)
	mouse.relative = Vector2(10, 0)
	await _dispatch(mouse, watcher, camera, "real mouse resumes desktop camera", false)
	Input.emulate_mouse_from_touch = old_emulation
	Input.use_accumulated_input = old_accumulation
	watcher.queue_free()

func _run() -> void:
	await process_frame
	if not _private_profile_valid():
		print("INPUT_CONTROLS_QA PRIVATE_PROFILE_REQUIRED")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var old_touch := OS.get_environment("TOUCH_UI")
	var settings = root.get_node("Settings")
	settings.edge_scroll = true
	settings.muted = true
	settings.apply_audio()
	var desktop = await _make_battle(false)
	_check_panel(desktop, false, "desktop empty selection")
	await _selection_case(desktop, _find_unit(desktop, "worker"), "desktop selected worker")
	desktop._set_selection([])
	await _settle()
	_check_panel(desktop, false, "desktop selection cleared")
	var desktop_hero = _spawn_hero(desktop)
	await _selection_case(desktop, desktop_hero, "desktop expanded again")
	_skill_click_case(desktop, desktop_hero, false, Vector2(55, 48), true, "desktop plus center")
	desktop._set_selection([])
	await _release_battle(desktop)
	# The preceding scene deliberately leaves the static camera panel height collapsed.
	var mobile = await _make_battle(true)
	_check_panel(mobile, true, "mobile cold start")
	await _selection_case(mobile, _find_unit(mobile, "worker"), "mobile selected worker")
	await _selection_case(mobile, _find_unit(mobile, "building"), "mobile selected producer")
	var mobile_hero = _spawn_hero(mobile)
	await _selection_case(mobile, mobile_hero, "mobile selected hero")
	var rail_button = _skill_button(mobile, mobile_hero, true)
	var plus_center: Vector2 = rail_button._learn_plus_center() if rail_button != null else Vector2.ZERO
	var plus_radius: float = rail_button._learn_plus_radius() if rail_button != null else 0.0
	# Use the production drawing geometry after responsive layout. The first
	# point is visibly inside the plus; the last is beyond its touch tolerance.
	_skill_click_case(mobile, mobile_hero, true, plus_center - Vector2.ONE.normalized() * (plus_radius - 1.0), true, "compact plus upper-left regression")
	_skill_click_case(mobile, mobile_hero, true, plus_center, true, "compact plus center")
	_skill_click_case(mobile, mobile_hero, true, plus_center + Vector2(0, plus_radius + 5.0), false, "compact below-plus regression")
	_mobile_rail_learning_contract(mobile, mobile_hero)
	mobile._set_selection([])
	await _settle()
	_check_panel(mobile, true, "mobile selection cleared stays expanded")
	await _touch_sequence(mobile)
	await _release_battle(mobile)
	OS.set_environment("TOUCH_UI", old_touch)
	var report := {"passed": failures.is_empty(), "check_count": checks.size(),
		"checks": checks, "failures": failures, "observations": observations,
		"project": ProjectSettings.globalize_path("res://"), "profile": OS.get_user_data_dir()}
	var output := FileAccess.open("res://input_controls_regression_report.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	else:
		check(false, "write regression report")
	print("INPUT_CONTROLS_QA checks=%d failures=%d" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
