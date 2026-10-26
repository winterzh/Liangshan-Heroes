extends "base.gd"
## Viewport input routing against installed production scenes. Fixture startup
## and selection use base/ordinary APIs; every tested key and click goes through
## Window.push_input, never Battle._input/_unhandled_input or pause callbacks.
## This worker cannot qualify native release EXE or desktop OS keyboard routing.
var input_events: Array = []
var screenshots: Array = []
var tooltip_samples: Array = []
var screenshot_folder := ""

func _frames(count := 3) -> void:
	for frame in range(count): await get_tree().process_frame

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _key_edge(code: int, pressed: bool, echo: bool, label: String) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	root.push_input(event, true)
	input_events.append({"label": label, "keycode": code, "pressed": pressed,
		"echo": echo, "paused_after_dispatch": get_tree().paused})

func _tap(code: int, label: String) -> void:
	for pressed in [true, false]:
		_key_edge(code, pressed, false, label)
		await get_tree().process_frame

func _button(node: Node, source_caption: String) -> Button:
	var caption: String = root.get_node("Localize").text(source_caption)
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found := _button(child, source_caption)
		if found != null: return found
	return null

func _gui_click(button: Button, label: String) -> bool:
	await _frames()
	var usable := is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
	if usable: usable = root.get_visible_rect().grow(1.0).encloses(button.get_global_rect())
	check(usable, label + ": actual button is visible and inside viewport")
	if not usable: return false
	var count := [0]
	var observe := func(): count[0] += 1
	button.pressed.connect(observe)
	var point := button.get_global_rect().get_center()
	_motion(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await get_tree().process_frame
	if is_instance_valid(button) and button.pressed.is_connected(observe): button.pressed.disconnect(observe)
	check(count[0] == 1, label + ": viewport mouse dispatch activated button exactly once")
	return count[0] == 1

func _state(battle: Variant) -> Dictionary:
	var units: Array = []
	for unit: Variant in battle.units:
		if is_instance_valid(unit): units.append([unit.get_instance_id(), unit.position, unit.hp])
	# Ordinary pause is not a save hold: clock.capture() correctly rejects it.
	# Read the serial without mutating the clock or manufacturing a held state.
	return {"tick": battle._run_clock._next_tick, "mission_seconds": battle.mission.total_game_seconds,
		"phase": battle.phase, "units": units, "events": battle.mission.events.duplicate(true)}

func _tooltip_labels(node: Node, wanted: String, owner: Control, in_popup := false) -> Array:
	var found: Array = []
	if node is Window and not node.visible: return found
	var popup: bool = in_popup or (node is PopupPanel and node.visible)
	if popup and node is Label and node != owner and node.is_visible_in_tree() and node.text == wanted:
		found.append({"path": str(node.get_path()), "text": node.text})
	# Godot owns tooltip PopupPanel/Label as internal nodes, so include them.
	for child: Node in node.get_children(true): found.append_array(_tooltip_labels(child, wanted, owner, popup))
	return found

func _hover_tooltip(control: Control, label: String) -> bool:
	await _frames()
	var usable := is_instance_valid(control) and control.is_visible_in_tree() and not control.tooltip_text.is_empty()
	if usable: usable = root.get_visible_rect().grow(1.0).encloses(control.get_global_rect())
	check(usable, label + ": actual production tooltip owner is visible")
	if not usable: return false
	_motion(root.get_visible_rect().get_center())
	await _frames(2)
	_motion(control.get_global_rect().get_center())
	var matches: Array = []
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await _wait(0.05)
		matches = _tooltip_labels(root, control.tooltip_text, control)
		if not matches.is_empty(): break
	check(not matches.is_empty(), label + ": real engine tooltip PopupPanel and matching Label became visible")
	tooltip_samples.append({"label": label, "owner": str(control.get_path()),
		"expected_text": control.tooltip_text, "visible_popup_labels": matches})
	if not matches.is_empty(): _screenshot(label)
	return not matches.is_empty()

func _screenshot(label: String) -> void:
	RenderingServer.force_draw(false)
	var picture: Image = root.get_texture().get_image()
	var path := screenshot_folder.path_join(label + ".png")
	var saved := picture != null and not picture.is_empty() and picture.save_png(path) == OK
	check(saved, label + ": actual viewport screenshot saved")
	if saved: screenshots.append({"label": label, "path": path, "sha256": FileAccess.get_sha256(path)})

func _pause_with_tooltip(battle: Variant, owner: Control, label: String) -> bool:
	if not await _hover_tooltip(owner, label): return false
	_key_edge(KEY_ESCAPE, true, false, label + " first Escape press")
	check(get_tree().paused and battle.hud._pause_root.visible,
		label + ": first Escape press pauses immediately while a real tooltip is showing")
	_key_edge(KEY_ESCAPE, true, true, label + " held-key echo")
	_key_edge(KEY_ESCAPE, false, false, label + " Escape release")
	await _frames()
	check(get_tree().paused and battle.hud._pause_root.visible,
		label + ": echo and release do not resume or duplicate the transition")
	check(root.gui_get_focus_owner() == battle.hud._pause_resume_button,
		label + ": real pause menu owns keyboard focus")
	var before := _state(battle)
	await _wait(0.25)
	check(_state(battle) == before, label + ": clock, mission time, units and events stay frozen under pause")
	_screenshot(label + "_paused")
	await _tap(KEY_ESCAPE, label + " focused pause resume")
	check(not get_tree().paused and not battle.hud._pause_root.visible,
		label + ": one Escape resumes without being handled again by Battle")
	await _wait(0.15)
	check(battle._run_clock._next_tick > before.tick and battle.mission.total_game_seconds > before.mission_seconds,
		label + ": real clock and mission time advance after resume")
	return failures.is_empty()

func _capture_guard(battle: Variant) -> bool:
	_motion(root.get_visible_rect().get_center())
	await _frames()
	var profiles: Script = load("res://scripts/run_official_restore_profile.gd")
	battle._save_barrier.configure(battle, battle._run_clock, profiles.HG_CONTEXT)
	hold_ready = false
	hold_error = ""
	var ready_callback := func(_context): hold_ready = true
	var rejected_callback := func(code): hold_error = String(code)
	battle._save_barrier.capture_ready.connect(ready_callback, CONNECT_ONE_SHOT)
	battle._save_barrier.capture_rejected.connect(rejected_callback, CONNECT_ONE_SHOT)
	var requested: Dictionary = battle._save_barrier.request_capture()
	check(requested.get("ok", false) and battle._run_capture_input_closed() and not get_tree().paused,
		"capture: actual request closes input before the idle boundary pauses the tree")
	if requested.get("ok", false):
		# Dispatch synchronously in REQUESTED, before process_frame can hide a
		# missing capture guard behind the ordinary tree.paused guard.
		_key_edge(KEY_ESCAPE, true, false, "capture REQUESTED Escape press")
		_key_edge(KEY_ESCAPE, false, false, "capture REQUESTED Escape release")
		check(not get_tree().paused and not battle.hud._pause_root.visible and battle._run_capture_input_closed(),
			"capture: Escape cannot open pause while input is closed but tree is still running")
		for frame in range(240):
			await get_tree().process_frame
			if hold_ready or hold_error != "": break
	if battle._save_barrier.capture_ready.is_connected(ready_callback): battle._save_barrier.capture_ready.disconnect(ready_callback)
	if battle._save_barrier.capture_rejected.is_connected(rejected_callback): battle._save_barrier.capture_rejected.disconnect(rejected_callback)
	var held: bool = hold_ready and hold_error.is_empty() and battle._save_barrier.health().get("ok", false)
	check(held, "capture: real barrier reaches healthy HELD state")
	if not held:
		print("CONTROLS_CAPTURE ", requested, " ", hold_error, " ", battle._save_barrier.health())
		return false
	var clock_before: Dictionary = battle._run_clock.capture()
	var world_before := _state(battle)
	await _tap(KEY_ESCAPE, "capture HELD Escape")
	await _frames()
	check(clock_before.get("ok", false) and battle._run_clock.capture() == clock_before and _state(battle) == world_before,
		"capture: Escape leaves actual held clock and world unchanged")
	check(get_tree().paused and not battle.hud._pause_root.visible and battle._save_barrier.health().get("ok", false),
		"capture: Escape cannot bypass held input or replace capture with a pause menu")
	var released: Dictionary = battle._save_barrier.release_capture()
	check(released.get("ok", false) and not get_tree().paused and not battle._run_capture_input_closed(),
		"capture: real release restores the previously running world")
	return failures.is_empty()

func _finish() -> void:
	report({"scope": "production_viewport_escape_routing", "input_dispatch": "Window.push_input",
		"fixture_setup": "base._start plus ordinary selection and official capture APIs",
		"input_events": input_events, "tooltip_samples": tooltip_samples, "screenshots": screenshots,
		"desktop_os_keyboard_tested": false, "human_acceptance": false})

func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): _finish(); return
	check(DisplayServer.get_name() != "headless", "controls regression requires a real renderer and engine GUI tooltips")
	if not failures.is_empty(): _finish(); return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var settings: Variant = root.get_node("Settings")
	settings.edge_scroll = false
	settings.game_speed = 1.0
	Engine.time_scale = 1.0
	AudioServer.set_bus_mute(0, true)
	check(root.get_node("Localize").set_language("en", false), "controls: English locale selected without writing preferences")
	screenshot_folder = OS.get_environment("HG_OUTPUT_ROOT").path_join("screenshots")
	check(DirAccess.make_dir_recursive_absolute(screenshot_folder) == OK, "controls screenshot directory created")
	var battle: Variant = await _start()
	await _wait(0.15)
	check(battle.phase == battle.Phase.FIGHT and battle.level.id() == "level1" and not get_tree().paused,
		"controls fixture is the actual running Huangnigang chapter")
	check(battle.level.actors.size() == 7, "controls fixture uses the seven real starting merchants")
	if not failures.is_empty(): _finish(); return
	battle.select_members(battle.level.actors.duplicate(), false)
	await _frames()
	_key_edge(KEY_ESCAPE, false, false, "unpaused Escape release only")
	_key_edge(KEY_ESCAPE, true, true, "unpaused Escape echo only")
	_key_edge(KEY_ESCAPE, false, false, "unpaused echo cleanup release")
	await _frames()
	check(not get_tree().paused and not battle.hud._pause_root.visible,
		"release and repeated-key echo cannot open pause in an active battle")
	if not failures.is_empty(): _finish(); return
	if not await _pause_with_tooltip(battle, battle.mission._toggle, "mission_tooltip"): _finish(); return
	if not await _pause_with_tooltip(battle, battle.hud._info_name, "group_title_tooltip"): _finish(); return
	_motion(root.get_visible_rect().get_center())
	await _frames()
	await _tap(settings.key_for("amove"), "arm attack-move via configured key")
	check(battle.is_armed() and battle._amove_armed, "configured key arms actual attack-move targeting")
	await _tap(KEY_ESCAPE, "cancel targeting")
	check(not battle.is_armed() and not get_tree().paused and not battle.hud._pause_root.visible,
		"first Escape cancels actual targeting without pausing")
	await _tap(KEY_ESCAPE, "pause after targeting cancellation")
	check(get_tree().paused and battle.hud._pause_root.visible, "next Escape opens pause after targeting is clear")
	if not failures.is_empty(): _finish(); return
	if not await _gui_click(_button(battle.hud._pause_options, "返回主菜单"), "request menu departure"): _finish(); return
	check(get_tree().paused and current_scene == battle and battle.hud._pause_confirm.visible,
		"menu request keeps actual battle paused behind confirmation")
	check(root.gui_get_focus_owner() == battle.hud._pause_cancel_button, "departure confirmation focuses cancel")
	await _tap(KEY_ESCAPE, "cancel menu departure")
	check(get_tree().paused and current_scene == battle and battle.hud._pause_root.visible
		and not battle.hud._pause_confirm.visible and battle.hud._pause_pending_action == "",
		"one Escape cancels departure and stays paused without resuming")
	if not await _gui_click(_button(battle.hud._pause_options, "⚙ 设置"), "open settings from pause"): _finish(); return
	var panel: Node = null
	for child: Node in battle.hud.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/settings_panel.gd": panel = child
	check(is_instance_valid(panel) and get_tree().paused and not battle.hud._pause_root.visible,
		"actual Settings modal replaces pause menu while gameplay remains paused")
	if not is_instance_valid(panel): _finish(); return
	var settings_ref: WeakRef = weakref(panel)
	await _tap(KEY_ESCAPE, "close settings modal")
	check(settings_ref.get_ref() == null and get_tree().paused and battle.hud._pause_root.visible,
		"Settings handles Escape and returns to pause without Battle stealing or replaying it")
	await _tap(KEY_ESCAPE, "resume after settings")
	check(not get_tree().paused and not battle.hud._pause_root.visible, "next Escape resumes after Settings returns")
	if not failures.is_empty(): _finish(); return
	if not await _gui_click(battle.hud._inventory_toggle, "open actual inventory"): _finish(); return
	check(battle.hud._inventory_popup.visible and battle.hud._inventory_popup_open, "actual inventory drawer is open")
	await _tap(KEY_ESCAPE, "pause with inventory open")
	check(get_tree().paused and battle.hud._pause_root.visible and battle.hud._inventory_popup_open,
		"inventory retains its existing drawer state while Escape opens pause")
	await _tap(KEY_ESCAPE, "resume with inventory open")
	check(not get_tree().paused and not battle.hud._pause_root.visible and battle.hud._inventory_popup.visible,
		"Escape resumes to the existing inventory drawer")
	if not await _gui_click(battle.hud._inventory_toggle, "close actual inventory"): _finish(); return
	if not failures.is_empty(): _finish(); return
	if not await _capture_guard(battle): _finish(); return
	await _tap(KEY_ESCAPE, "pause for confirmed return")
	if not await _gui_click(_button(battle.hud._pause_options, "返回主菜单"), "request final menu departure"): _finish(); return
	var battle_ref: WeakRef = weakref(battle)
	if not await _gui_click(battle.hud._pause_confirm_button, "confirm actual return to menu"): _finish(); return
	await _frames(8)
	check(battle_ref.get_ref() == null and current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn"
		and not get_tree().paused, "confirmed return frees actual battle, opens production menu and releases tree pause")
	_screenshot("returned_menu")
	_finish()
