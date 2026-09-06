extends SceneTree
## External QA of the exact mounted release PCK. Run only through the sibling runner.
## Real menu/Settings/SettingsPanel, real Viewport input; no game source substitution.
const VIEW := Vector2i(1280, 720)
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var events: Array[Dictionary] = []
var mode := ""
var report_path := ""
var screenshot_path := ""
var screenshot_sha256 := ""
var pack_path := ""
var pack_sha256 := ""
var settings_file_before := ""
var settings_file_after := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String, detail: Variant = null) -> bool:
	checks.append({"label": label, "passed": ok, "detail": detail})
	if not ok:
		failures.append(label)
	print("PACKAGE_SETTINGS_CHECK ", "PASS " if ok else "FAIL ", label)
	return ok

func _settle(count: int = 3) -> void:
	for unused in range(count):
		await process_frame

func _norm(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()

func _inside(path: String, parent: String) -> bool:
	return not parent.is_empty() and _norm(path).begins_with(_norm(parent) + "/")

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"

func _button(node: Node, caption: String = "") -> Button:
	if node is Button and node.is_visible_in_tree() and (caption.is_empty() or node.text == caption):
		return node
	for child in node.get_children():
		var found: Button = _button(child, caption)
		if found != null:
			return found
	return null

func _panel(node: Node) -> Control:
	if node is Control and node.get_script() != null and node.get_script().resource_path == "res://scripts/settings_panel.gd":
		return node
	for child in node.get_children():
		var found: Control = _panel(child)
		if found != null:
			return found
	return null

func _fits(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var visible := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible = visible.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return visible.encloses(control.get_global_rect())

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _click(button: Button, label: String) -> bool:
	await _settle()
	if not _check(_fits(button) and not button.disabled, label + " button visible and enabled"):
		return false
	var point := button.get_global_rect().get_center()
	var pressed_count := [0]
	var observer := func() -> void: pressed_count[0] += 1
	button.pressed.connect(observer)
	_motion(point)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event, true)
		await _settle(1)
	if is_instance_valid(button):
		button.pressed.disconnect(observer)
	events.append({"action": label, "position": [point.x, point.y], "pressed_count": pressed_count[0]})
	return _check(pressed_count[0] == 1, label + " exactly one real pressed signal")

func _reveal(button: Button) -> bool:
	if button == null:
		return _check(false, "effects button exists")
	var ancestor: Node = button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if not _check(ancestor is ScrollContainer, "effects button belongs to actual scroll container"):
		return false
	var scroll: ScrollContainer = ancestor
	var row: Control = button.get_parent().get_parent()
	for attempt in range(32):
		if _fits(row):
			break
		var point := scroll.get_global_rect().position + Vector2(20.0, scroll.size.y * 0.5)
		_motion(point)
		var before := scroll.scroll_vertical
		var direction := MOUSE_BUTTON_WHEEL_DOWN if row.get_global_rect().get_center().y > scroll.get_global_rect().get_center().y else MOUSE_BUTTON_WHEEL_UP
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = direction
			event.pressed = down
			event.factor = 1.0
			root.push_input(event, true)
		await _settle(2)
		events.append({"action": "wheel", "before": before, "after": scroll.scroll_vertical})
		if not _check(before != scroll.scroll_vertical, "real wheel changes scroll offset"):
			return false
	return _check(_fits(row) and _fits(button), "effects row fully inside viewport and scroll clipping")

func _run() -> void:
	await process_frame
	mode = OS.get_environment("SH_STEAM_QA_MODE")
	report_path = OS.get_environment("SH_STEAM_QA_REPORT")
	screenshot_path = OS.get_environment("SH_STEAM_QA_SCREENSHOT") if mode == "write" else ""
	pack_path = OS.get_environment("SH_STEAM_QA_EXE_PATH")
	var user_root := OS.get_environment("SH_STEAM_QA_USER_ROOT")
	# Refuse all output and preference actions if runner isolation is absent.
	if not _inside(OS.get_user_data_dir(), user_root) or not _inside(report_path, user_root.get_base_dir()) or (mode == "write" and not _inside(screenshot_path, user_root.get_base_dir())):
		print("PACKAGE_SETTINGS_ISOLATION_REJECTED")
		quit(2)
		return
	# Godot consumes startup options; the owned Python launch receipt verifies
	# --main-pack and the exact path. Record remaining arguments without treating
	# absence of consumed engine flags as a package failure.
	pack_sha256 = _hash(pack_path)
	_check(pack_sha256 == OS.get_environment("SH_STEAM_QA_EXE_SHA256") and pack_sha256.length() == 64, "mounted EXE hash equals runner verified build")
	_check(mode in ["write", "read"], "known independent process mode")
	_check(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_driver_name().to_lower() == "vulkan", "real Vulkan rendering")
	root.size = VIEW
	root.content_scale_size = VIEW
	AudioServer.set_bus_mute(0, true)
	var settings: Node = root.get_node_or_null("Settings")
	_check(settings != null and settings.get_script().resource_path == "res://scripts/settings.gd", "real packaged Settings autoload")
	var codec: Resource = load("res://scripts/run_state_value_codec.gd")
	_check(codec is Script, "packaged value codec script loads; no continuation claim")
	if not failures.is_empty():
		_finish()
		return
	settings_file_before = _hash("user://settings.cfg")
	_check(settings_file_before == "absent" if mode == "write" else settings_file_before != "absent", "settings file fresh for write and present for restart")
	_check(settings.get("effects_quality") == ("standard" if mode == "write" else "reduced"), "actual autoload quality default or independently restored")
	var menu_scene: PackedScene = load("res://scenes/menu.tscn")
	if not _check(menu_scene != null, "packaged menu loads"):
		_finish()
		return
	var menu: Control = menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await _settle(5)
	menu.call("_show_settings")
	await _settle()
	var panel: Control = _panel(menu)
	if not _check(panel != null, "production menu opens packaged SettingsPanel"):
		_finish()
		return
	_check(panel.z_index == 300 and panel.mouse_filter == Control.MOUSE_FILTER_STOP, "modal z_index 300 and mouse input boundary")
	_check(panel.process_mode == Node.PROCESS_MODE_ALWAYS, "actual modal processes during pause")
	paused = true
	var standard: Button = _button(panel, "标准")
	var reduced: Button = _button(panel, "精简")
	if not _check(standard != null and reduced != null, "both quality controls present") or not await _reveal(reduced):
		_finish()
		return
	_check(standard.button_pressed == (mode == "write") and reduced.button_pressed == (mode == "read"), "quality selection matches actual autoload")
	if mode == "write":
		await _click(reduced, "select reduced")
		_check(settings.get("effects_quality") == "reduced" and reduced.button_pressed and not standard.button_pressed, "real button updates setting and exclusive selection")
		_check(paused, "quality selection preserves paused state")
		await _settle(3)
		await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		_check(capture != null and not capture.is_empty() and capture.get_size() == VIEW, "actual viewport capture is 1280x720")
		if capture != null and not capture.is_empty():
			var error: Error = capture.save_png(screenshot_path)
			_check(error == OK, "actual settings screenshot saved")
			if error == OK:
				screenshot_sha256 = _hash(screenshot_path)
	var panel_ref: WeakRef = weakref(panel)
	await _click(_button(panel, "←  返回（保存）"), "close and save")
	await _settle(3)
	_check(panel_ref.get_ref() == null and _panel(menu) == null, "closed modal really freed without remaining settings overlay")
	_check(paused, "closing settings preserves pause until caller resumes")
	var saved := ConfigFile.new()
	_check(saved.load("user://settings.cfg") == OK and saved.get_value("show", "effects_quality", "absent") == "reduced", "production close persisted reduced to private settings")
	settings_file_after = _hash("user://settings.cfg")
	if mode == "read":
		_check(settings_file_after == settings_file_before, "restart and unchanged close preserve exact settings bytes")
	paused = false
	await _settle()
	var menu_button: Button = _button(menu)
	if _check(_fits(menu_button), "underlying actual menu button remains visible"):
		_motion(menu_button.get_global_rect().get_center())
		await _settle()
		var hovered: Control = root.gui_get_hovered_control()
		_check(hovered == menu_button or (hovered != null and menu_button.is_ancestor_of(hovered)), "closed modal no longer intercepts menu hover")
	_check(root.size == VIEW and root.get_visible_rect().size == Vector2(VIEW), "requested physical and logical resolution retained")
	_finish()

func _finish() -> void:
	paused = false
	var report := {
		"schema": 1, "mode": mode, "complete": true, "passed": failures.is_empty(),
		"checks": checks, "check_count": checks.size(), "failures": failures, "events": events,
		"pid": OS.get_process_id(), "actual_user_dir": OS.get_user_data_dir(),
		"remaining_cmdline_args": Array(OS.get_cmdline_args()),
		"resource_root": ProjectSettings.globalize_path("res://"),
		"executable_sha256": pack_sha256, "mounted_pack": pack_path,
		"source_commit": OS.get_environment("SH_STEAM_QA_SOURCE_COMMIT"),
		"qa_script_path": get_script().resource_path,
		"qa_script_raw_sha256": _hash(get_script().resource_path),
		"screenshot_path": screenshot_path, "screenshot_sha256": screenshot_sha256,
		"settings_file_before": settings_file_before, "settings_file_after": settings_file_after,
		"resolution": [root.size.x, root.size.y], "rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"),
		"scope": "Mounted release PCK: real settings input and two-process persistence; synthetic paused menu checks modal lifetime, not the complete battle pause flow. Screenshot requires separate visual review. Codec load only, no battle continuation.",
		"human_visual_review": false,
	}
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("PACKAGE_SETTINGS_RESULT ", JSON.stringify({"passed": report["passed"], "checks": checks.size(), "report": report_path}))
	quit(0 if failures.is_empty() else 1)
