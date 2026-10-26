extends "base.gd"
## Display-only matrix on a naturally saved, independently restored live world.
## Selection, camera focus and the task toggle use ordinary presentation APIs.
## No actors, cargo, task actions, clocks or victory fields are manufactured.
const LANGUAGES := ["zh_CN", "zh_TW", "en", "ja"]
const SIZES := [Vector2i(1280, 720), Vector2i(960, 720), Vector2i(1920, 1080)]
const TEXT_KEYS := [
	"▼ 收起任务", "查看 · %s", "%s · 推第%d车（%d担）出冈",
	"弃枣装车 · 七车装十一担",
	"先让七星到各自的枣车旁，右键取车标记。再右键货担旁的装车标记，推车过去弃枣、装入财物；装好后由你下令推到西口。七车共载十一担，白胜同行。"
]
var samples: Array = []
var catalog: Dictionary = {}

func _rect(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}

func _positions(level: Variant) -> Array:
	return level.actors.map(func(actor): return [actor.entity_id, actor.position.x, actor.position.y])

func _hold(battle: Variant, label: String) -> bool:
	var profiles: Script = load("res://scripts/run_official_restore_profile.gd")
	battle._save_barrier.configure(battle, battle._run_clock, profiles.HG_CONTEXT)
	hold_ready = false
	hold_error = ""
	var ready_callback := func(_context): hold_ready = true
	var rejected_callback := func(code): hold_error = String(code)
	battle._save_barrier.capture_ready.connect(ready_callback, CONNECT_ONE_SHOT)
	battle._save_barrier.capture_rejected.connect(rejected_callback, CONNECT_ONE_SHOT)
	var requested: Dictionary = battle._save_barrier.request_capture()
	check(requested.get("ok", false), label + ": actual capture barrier requested")
	if requested.get("ok", false):
		for frame in range(240):
			await get_tree().process_frame
			if hold_ready or hold_error != "": break
	if battle._save_barrier.capture_ready.is_connected(ready_callback):
		battle._save_barrier.capture_ready.disconnect(ready_callback)
	if battle._save_barrier.capture_rejected.is_connected(rejected_callback):
		battle._save_barrier.capture_rejected.disconnect(rejected_callback)
	var held: bool = hold_ready and hold_error.is_empty() and battle._save_barrier.health().get("ok", false)
	check(held, label + ": actual barrier drained, froze clock and disabled inputs")
	if not held: print("UI_HOLD ", requested, " ", hold_error, " ", battle._save_barrier.health())
	return held

func _translated_keys(localize: Variant, language: String, label: String) -> void:
	for source: String in TEXT_KEYS:
		var entry: Variant = catalog.get(source)
		var present: bool = typeof(entry) == TYPE_DICTIONARY
		if language != "zh_CN":
			present = present and typeof(entry.get(language)) == TYPE_STRING and not String(entry.get(language, "")).is_empty()
		check(present, label + ": catalog contains " + source)
		if present:
			var expected: String = source if language == "zh_CN" else entry[language]
			check(localize.text(source) == expected, label + ": live translator uses catalog " + source)

func _delivery_labels(battle: Variant, localize: Variant, label: String) -> Array:
	var results: Array = []
	var found := 0
	for action_id: String in battle.mission.actions:
		if not action_id.begins_with("force_deliver_"): continue
		var action: Dictionary = battle.mission.actions[action_id]
		var parts := action_id.split("_")
		var index: int = String(parts[2]).to_int()
		var actor: Variant = battle.level.cargo.get(index)
		if not is_instance_valid(actor): continue
		var source_name: String = battle._defs[actor.key].name
		var weight := 2 if index < 4 else 1
		var expected_label: String = localize.format_text("%s · 推第%d车（%d担）出冈", [source_name, index + 1, weight])
		var expected_button: String = localize.format_text("查看 · %s", [expected_label])
		var button: Variant = action.button
		var valid: bool = is_instance_valid(button) and button is Button and button.text == expected_button
		check(valid, label + ": restored delivery button " + action_id + " follows current language")
		results.append({"action": action_id, "expected": expected_button, "actual": button.text if is_instance_valid(button) else ""})
		found += 1
	check(found == 7, label + ": seven real carried-cart delivery labels inspected")
	return results

func _sample(battle: Variant, localize: Variant, language: String, size: Vector2i, group: bool, folder: String) -> void:
	var selection_name := "seven_selected" if group else "ruan_xiaoqi_selected"
	var label := "%s_%dx%d_%s" % [language, size.x, size.y, selection_name]
	root.size = size
	DisplayServer.window_set_size(size)
	check(localize.set_language(language, false), label + ": language switched without saving preference")
	if group:
		battle.select_members(battle.level.cargo.values(), false)
	else:
		battle.focus_unit(battle.level.cargo[6])
	battle.mission._toggle.button_pressed = true
	# Run only normal production frames so its mission/HUD resize paths settle.
	# Pause before requesting the real barrier; released capture remains paused.
	get_tree().paused = false
	for frame in range(4): await get_tree().process_frame
	get_tree().paused = true
	for frame in range(3): await get_tree().process_frame
	if not await _hold(battle, label): return
	var positions_before := _positions(battle.level)
	var events_before: Dictionary = battle.mission.events.duplicate(true)
	var score_before: int = battle.level.delivered
	var image_path := folder.path_join(label + ".png")
	# A static offscreen held window need not emit another frame_post_draw.
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	var visible: Rect2 = root.get_visible_rect()
	var panel: Rect2 = battle.mission._panel.get_global_rect()
	var scroll: Rect2 = battle.mission._detail_scroll.get_global_rect()
	var bottom: Rect2 = battle.hud._bottom_panel.get_global_rect()
	var scale := Vector2(image.get_width(), image.get_height()) / visible.size
	var physical := Rect2(Vector2.ZERO, Vector2(image.get_width(), image.get_height()))
	var physical_panel := Rect2((panel.position - visible.position) * scale, panel.size * scale)
	var physical_bottom := Rect2((bottom.position - visible.position) * scale, bottom.size * scale)
	check(Vector2i(image.get_width(), image.get_height()) == size, label + ": screenshot has requested physical dimensions")
	check(battle.mission._panel.is_visible_in_tree() and battle.mission._expanded and battle.mission._details.is_visible_in_tree(), label + ": real dense task panel is expanded")
	check(battle.hud._bottom_panel.is_visible_in_tree() and not battle.hud._bottom_collapsed, label + ": actual selected-unit command panel is open")
	check(visible.grow(1.0).encloses(panel) and visible.grow(1.0).encloses(bottom), label + ": task and command panels fit logical viewport")
	check(physical.grow(1.0).encloses(physical_panel) and physical.grow(1.0).encloses(physical_bottom), label + ": task and command panels fit physical screenshot")
	check(panel.end.y <= bottom.position.y - 6.0 and not panel.intersects(bottom), label + ": task panel leaves six logical pixels above command panel")
	check(panel.grow(1.0).encloses(scroll), label + ": objective scroll viewport stays inside task panel")
	var buttons: Array = battle.mission._buttons.get_children().filter(func(node): return node is Button and node.is_visible_in_tree())
	check(buttons.size() >= 7, label + ": actual task list exercises at least seven locator buttons")
	var button_widths_ok := true
	for button: Button in buttons:
		var rect := button.get_global_rect()
		button_widths_ok = button_widths_ok and rect.position.x >= scroll.position.x - 1.0 and rect.end.x <= scroll.end.x + 1.0 and rect.size.y >= 32.0
	check(button_widths_ok, label + ": scrolling task labels fit horizontally and retain button height")
	check(battle.selection.size() == (7 if group else 1), label + ": ordinary selection API displays requested carrier selection")
	check(battle.level.cargo.size() == 7 and battle.level.delivered == 0, label + ": all seven carts remain genuinely carried before any delivery")
	_translated_keys(localize, language, label)
	var labels := _delivery_labels(battle, localize, label)
	check(image.save_png(image_path) == OK, label + ": actual viewport screenshot saved")
	check(_positions(battle.level) == positions_before and battle.mission.events == events_before and battle.level.delivered == score_before, label + ": screenshot and text inspection do not advance held gameplay")
	check(battle._save_barrier.health().get("ok", false), label + ": barrier remains healthy through inspection")
	samples.append({"language": language, "physical_size": [size.x, size.y], "selection": selection_name,
		"viewport": _rect(visible), "task_panel": _rect(panel), "task_scroll": _rect(scroll), "command_panel": _rect(bottom),
		"physical_task_panel": _rect(physical_panel), "physical_command_panel": _rect(physical_bottom),
		"buttons": buttons.size(), "delivery_labels": labels, "carrier_positions": positions_before,
		"image": image_path, "sha256": FileAccess.get_sha256(image_path)})
	var released: Dictionary = battle._save_barrier.release_capture()
	check(released.get("ok", false) and get_tree().paused, label + ": actual barrier releases safely back to paused world")

func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): report(); return
	check(DisplayServer.get_name() != "headless", "UI matrix requires a real renderer")
	if not failures.is_empty(): report(); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	check(typeof(parsed) == TYPE_DICTIONARY, "installed localization catalog is a dictionary")
	if typeof(parsed) != TYPE_DICTIONARY: report(); return
	catalog = parsed
	var battle: Variant = await restore_checkpoint()
	if battle == null: report(); return
	var localize: Variant = root.get_node("Localize")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").game_speed = 1.0
	Engine.time_scale = 1.0
	AudioServer.set_bus_mute(0, true)
	var folder := OS.get_environment("HG_OUTPUT_ROOT").path_join("screenshots")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "private UI screenshot directory created")
	for size: Vector2i in SIZES:
		for language: String in LANGUAGES:
			await _sample(battle, localize, language, size, false, folder)
			if not failures.is_empty(): break
			await _sample(battle, localize, language, size, true, folder)
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	var store: Variant = load("res://scripts/run_slot_store.gd").new("user://hg_transport_world/v1")
	check(store.read_slot().get("file_sha256", "") == source_checkpoint.saved_sha256, "UI inspection preserves original cross-process slot bytes")
	check(samples.size() == LANGUAGES.size() * SIZES.size() * 2, "complete four-language three-size two-selection UI matrix")
	report({"scope": "Natural wine-route save, independent restore and held rendered UI matrix",
		"samples": samples, "producer_pid": producer_report.pid, "producer_checkpoint": source_checkpoint,
		"coordinates_or_mission_state_injected": false, "full_campaign_continue_accepted": false,
		"full_art_accepted": false, "human_visual_review_completed": false})
