extends Node
const Slot = preload("res://scripts/run_slot_store.gd")
const Session = preload("res://scripts/run_world_session.gd")
var flow: Node
var battle: Variant
var checks: Array = []
var mode := ""
var source: Dictionary = {}
var received := false
var result: Dictionary = {}
var atmosphere_phase := -1.0

class ReleaseFaultSlot extends "res://scripts/run_slot_store.gd":
	var fail_release := true
	func release() -> Dictionary:
		if fail_release:
			fail_release = false
			return bad("LOCK_RELEASE")
		return super()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	flow = get_node("/root/ContinueFlow")
	mode = OS.get_environment("LSH_CONTINUE_FLOW_CASE")
	if mode != "public_gate" and not flow.is_enabled():
		print("PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	_run.call_deferred()

func check(name: String, passed: bool) -> bool:
	checks.append({"name": name, "passed": passed})
	if not passed: print("FAIL " + name)
	return passed

func write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value)); file.flush(); file.close()

func report() -> void:
	var passed := not checks.is_empty() and checks.all(func(c): return c.passed)
	write(OS.get_environment("LSH_CONTINUE_FLOW_REPORT"), {"passed": passed, "checks": checks, "case": mode, "pid": OS.get_process_id(), "result": result, "real_steam": false, "full_30_waves": false})
	print("CONTINUE_FLOW_QA " + mode + " " + str(checks.size()) + " " + str(passed))

func finish() -> void:
	report()
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if checks.all(func(c): return c.passed) else 1)

func menu() -> Node:
	var node: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(node); get_tree().current_scene = node
	return node

func clicked(node: Node, name: String) -> bool:
	var button := node.find_child(name, true, false) as Button
	if not check("button exists " + name, button != null): return false
	button.pressed.emit()
	return true

func capture_ui(stem: String) -> void:
	var localize := get_node("/root/Localize")
	var original: String = localize.locale
	var folder := OS.get_environment("LSH_CONTINUE_FLOW_REPORT").get_base_dir().path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	for language in ["zh_CN", "zh_TW", "en", "ja"]:
		localize.set_language(language, false)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var visible := get_viewport().get_visible_rect()
		var stack: Array = [flow._overlay]
		var fits := true
		while not stack.is_empty():
			var control: Node = stack.pop_back()
			if control is Control and control.is_visible_in_tree() and (control is Button or control is Label): fits = fits and visible.encloses(control.get_global_rect())
			stack.append_array(control.get_children())
		check(stem + " controls visible " + language, fits)
		check(stem + " screenshot saved " + language, get_viewport().get_texture().get_image().save_png(folder.path_join(stem + "_" + language + ".png")) == OK)
	localize.set_language(original, false)

func _operation(value: Dictionary) -> void:
	received = true
	result = value.duplicate(true)

func wait_operation() -> void:
	for _i in range(180):
		if received: return
		await get_tree().process_frame
	check("operation completed within frame budget", false)

func field_record() -> Dictionary:
	var ids: Array = []
	for unit: Variant in battle.units: ids.append(str(unit.entity_id))
	return {"gold": battle.gold, "wood": battle.wood, "wave": battle.level._wave, "wave_t": battle.level._wave_t, "next_entity_id": str(battle.next_entity_id), "units": ids, "training": battle.level.hall._train_queue.duplicate(), "train_t": battle.level.hall._train_t, "kills": battle.kills, "valid_kills": battle._steam_valid_kills}

func _saved(value: Dictionary) -> void:
	_operation(value)
	if not check("save operation succeeds", value.ok):
		if value.get("code") == "ENVIRONMENT_SHADER_OR_RECT": _environment_diagnostics()
		finish(); return
	check("successful save holds current battle", get_tree().current_scene == battle and battle._save_barrier.health().ok)
	for layer in battle.get_children():
		if layer.get_script() == Session.Core.B.AtmosphereLayer:
			check("capture synchronizes derived screen geometry", layer.screen.transform.is_equal_approx(layer.get_global_transform_with_canvas().affine_inverse()))
			if atmosphere_phase >= 0.0: check("capture does not advance atmosphere phase", layer.phase == atmosphere_phase)
	var stored: Dictionary = Slot.new().read_slot()
	check("successful save matches closed disk", stored.ok and stored.file_sha256 == value.file_sha256)
	check("test cannot credit Steam", battle._steam_run_id == 0 and stored.document.binding == {"kind": "uncredited"})
	source = {"state": field_record(), "generation": value.generation, "pid": OS.get_process_id()}
	write(OS.get_environment("LSH_CONTINUE_FLOW_STATE"), source)
	await get_tree().process_frame
	check("normal save-and-exit lifecycle requested", get_node("/root/AppLifecycle").quit_started() and get_node("/root/AppLifecycle").quit_reason() == "continue_saved")
	report()

func _environment_diagnostics() -> void:
	var module := preload("res://scripts/run_environment_state.gd").new()
	for layer in battle.get_children():
		if layer.get_script() != Session.Core.B.AtmosphereLayer: continue
		var template := Session.Core.B.AtmosphereLayer.new()
		var mismatch: Dictionary = {}
		for key: String in module.RECT_FIXED:
			if key not in ["offset_right", "offset_bottom"] and layer.rect.get(key) != template.rect.get(key): mismatch[key] = [str(layer.rect.get(key)), str(template.rect.get(key))]
		for key: String in module.UNIFORMS:
			if layer.rect.material.get_shader_parameter(key) != template.rect.material.get_shader_parameter(key): mismatch["uniform_" + key] = [str(layer.rect.material.get_shader_parameter(key)), str(template.rect.material.get_shader_parameter(key))]
		mismatch["geometry"] = [str(layer.rect.size), str(layer.get_viewport_rect().size), str(layer.screen.transform), str(layer.get_global_transform_with_canvas().affine_inverse())]
		mismatch["phase"] = [layer.phase, layer.rect.material.get_shader_parameter("phase")]
		mismatch["screen_safe"] = module._environment_safe(layer.screen, layer.rect)
		mismatch["shader_equal"] = layer.rect.material.shader.code == template.rect.material.shader.code
		mismatch["rect_connections"] = []
		for signal_info in layer.rect.get_signal_list():
			for connection in layer.rect.get_signal_connection_list(signal_info.name): mismatch.rect_connections.append(str(connection))
		print("ENVIRONMENT_DIAGNOSTICS " + JSON.stringify(mismatch))
		template.free()

func _run() -> void:
	get_node("/root/Settings").game_speed = 1.0
	get_node("/root/Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	check("Steam disabled", OS.get_environment("STEAM_DISABLED") == "1")
	var m := menu()
	await get_tree().process_frame
	if mode == "public_gate":
		check("player gate remains closed", not flow.is_enabled())
		check("normal menu hides continue", m.find_child("ContinueBattle", true, false) == null)
		check("direct request remains denied", flow.request_continue(m).code == "CONTINUE_NOT_RELEASED")
		check("no slot created", Slot.new().read_slot().code == "NO_SLOT")
		finish(); return
	check("isolated flow enabled", flow.is_enabled())
	check("real menu continue button", m.find_child("ContinueBattle", true, false) != null)
	flow.operation_finished.connect(_operation)
	if mode == "no_slot":
		clicked(m, "ContinueBattle")
		check("double read rejected", flow.request_continue(m).code == "OPERATION_BUSY")
		await wait_operation()
		check("empty read error", not result.ok and result.code == "NO_SLOT")
		check("read failure retains menu", get_tree().current_scene == m and is_instance_valid(m))
		check("read failure restores pause", not get_tree().paused)
		clicked(flow, "CloseError")
		check("error close releases operation", not flow.busy())
		check("empty read does not initialize slot", Slot.new().read_slot().code == "NO_SLOT")
		finish(); return
	if mode == "capture":
		var campaign := get_node("/root/Campaign")
		for key in Session.FLAGS: campaign.set(key, Session.FLAGS[key])
		campaign.defense_hero_cap = 4; campaign.ai_friendly = false
		m._launch()
		for _i in range(90):
			await get_tree().process_frame
			if get_tree().current_scene != null and get_tree().current_scene.get_script() == Session.Core.B: break
		battle = get_tree().current_scene
		if not check("menu starts actual classic battle", battle.get_script() == Session.Core.B): finish(); return
		battle.hud._intro_root.hide(); battle.hud.intro_done.emit()
		for _i in range(10): await get_tree().physics_frame
		await get_tree().process_frame
		check("classic normal fight started", battle.phase == 2 and battle.level._started and battle.gameplay_rng_fault().is_empty())
		var worker: Variant = null
		for unit: Variant in battle.units:
			if unit.is_worker and unit.faction == 0: worker = unit; break
		if not check("real worker exists", worker != null): finish(); return
		check("paid training queued", battle.queue_train(battle.level.hall, worker.key, false))
		battle._open_pause()
		for layer in battle.get_children():
			if layer.get_script() == Session.Core.B.AtmosphereLayer: atmosphere_phase = layer.phase
		battle.camera.position += Vector2(37.0, 23.0)
		battle.camera.force_update_scroll()
		flow.operation_finished.disconnect(_operation)
		flow.operation_finished.connect(_saved)
		clicked(battle.hud, "SaveAndExit")
		check("double save rejected", flow.request_save_exit(battle).code == "OPERATION_BUSY")
		return
	# A separate process loads the exact saved slot through the actual menu UI.
	source = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LSH_CONTINUE_FLOW_STATE")))
	var before: Dictionary = Slot.new().inspect_slot()
	var obstruction: String = Slot.new().directory.path_join("blocked.json")
	if mode == "restore_and_overwrite":
		write(obstruction, {})
		clicked(m, "ContinueBattle")
		await wait_operation()
		check("invalid directory layout rejects restore", not result.ok and result.code == "UNKNOWN_FILE")
		check("invalid read keeps original menu", get_tree().current_scene == m and is_instance_valid(m))
		clicked(flow, "CloseError")
		DirAccess.remove_absolute(obstruction)
		check("invalid read did not replace slot", Slot.new().inspect_slot() == before)
		received = false
	clicked(m, "ContinueBattle")
	check("restore duplicate operation denied", flow.request_continue(m).code == "OPERATION_BUSY")
	await wait_operation()
	if not check("menu continue installed actual world", result.ok): finish(); return
	battle = get_tree().current_scene
	check("restored world still classic", battle.get_script() == Session.Core.B and battle._official_context == Slot.CONTEXT)
	check("cross-process identity", int(source.pid) != OS.get_process_id())
	check("paused intent restored", get_tree().paused)
	check("restored economy", battle.gold == source.state.gold and battle.wood == source.state.wood)
	check("restored wave phase", battle.level._wave == source.state.wave and is_equal_approx(battle.level._wave_t, source.state.wave_t))
	check("restored training queue", JSON.stringify(battle.level.hall._train_queue) == JSON.stringify(source.state.training) and is_equal_approx(battle.level.hall._train_t, source.state.train_t))
	check("restored entity allocation", str(battle.next_entity_id) == source.state.next_entity_id)
	check("read retains exact disk slot", Slot.new().inspect_slot() == before)
	check("restored HUD includes save", battle.hud.find_child("SaveAndExit", true, false) != null)
	if mode == "pending_retry":
		# Fault injection stays in this private fixture. The ordinary production
		# UI/session path above is unchanged; retry uses its actual retained state.
		check("pending fixture requests real barrier", battle.request_run_capture().ok)
		await battle._save_barrier.capture_ready
		var trusted: Dictionary = preload("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
		var session := Session.new(trusted, {"defs": battle._defs, "abilities": battle._abilities, "items": battle._items})
		session._store = ReleaseFaultSlot.new()
		var failed: Dictionary = session.save_held(battle, flow._graph, {"revision": before.revision, "file_sha256": before.file_sha256})
		if not check("post-commit unlock failure retains transaction", not failed.ok and failed.get("pending_save", false) and failed.get("retryable", false)):
			result = failed; finish(); return
		flow._session = session; flow._source = battle; flow.phase = flow.Phase.SAVING
		flow._fail(failed, false)
		check("pending failure keeps exact session and world held", flow._session == session and flow.last_result.battle_held and battle._save_barrier.health().ok)
		check("new store cannot impersonate live owner", Slot.new().inspect_slot().code == "WRITER_ALIVE")
		check("pending session refuses disposal", not session.dispose().ok and session.has_pending_save())
		flow.dismiss_error(); flow.retry_release()
		check("pending save cannot dismiss or resume world", flow.phase == flow.Phase.ERROR and get_tree().paused and battle._save_barrier.health().ok)
		await capture_ui("pending_save")
		flow.operation_finished.disconnect(_operation)
		flow.operation_finished.connect(_saved)
		clicked(flow, "RetrySave")
		check("owned retry uses original generation", result.ok and result.get("owned_retry", false) and int(result.generation) == int(before.revision) + 1)
		return
	if mode == "held_error":
		received = false
		clicked(battle.hud, "SaveAndExit")
		clicked(flow, "ConfirmSave")
		battle._run_clock.abort_step("QA_INJECTED_CLOCK_FAULT")
		await wait_operation()
		check("release failure retains held world", result.get("battle_held", false) and get_tree().paused and battle._save_barrier.state == battle._save_barrier.State.HELD)
		await capture_ui("held_error")
		flow.dismiss_error()
		check("direct dismissal cannot remove held error", flow.phase == flow.Phase.ERROR and is_instance_valid(flow._overlay))
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
		flow._input(escape)
		check("escape preserves held error controls", flow.find_child("RetryRelease", true, false) != null)
		clicked(flow, "RetryRelease")
		check("failed recovery retains actionable overlay", flow.phase == flow.Phase.ERROR and flow.find_child("LeaveHeldBattle", true, false) != null)
		clicked(flow, "LeaveHeldBattle")
		check("failed exit asks with cancel focused", flow.phase == flow.Phase.EXIT_CONFIRM and flow.get_viewport().gui_get_focus_owner().name == "CancelSave")
		clicked(flow, "CancelSave")
		check("cancel failed exit retains world", get_tree().current_scene == battle and flow.phase == flow.Phase.ERROR and get_tree().paused)
		check("held error did not write slot", Slot.new().inspect_slot() == before)
		clicked(flow, "LeaveHeldBattle")
		clicked(flow, "ConfirmSave")
		check("explicit failed exit uses lifecycle", get_node("/root/AppLifecycle").quit_started() and get_node("/root/AppLifecycle").quit_reason() == "continue_failed")
		report(); return
	if mode == "restore_again":
		var time_before: float = battle.level._wave_t
		battle._close_pause()
		for _i in range(15): await get_tree().physics_frame
		await get_tree().process_frame
		check("second process resume advances simulation", battle.level._wave_t != time_before and battle.gameplay_rng_fault().is_empty())
		finish(); return
	var train_before: float = battle.level.hall._train_t
	battle._close_pause()
	for _i in range(20): await get_tree().physics_frame
	await get_tree().process_frame
	check("production continues after restore", battle.level.hall._train_t != train_before)
	battle._open_pause()
	clicked(battle.hud, "SaveAndExit")
	check("existing slot asks confirmation", flow.phase == flow.Phase.CONFIRM)
	check("confirmation focuses cancel", flow.get_viewport().gui_get_focus_owner().name == "CancelSave")
	check("opening confirmation does not write", Slot.new().inspect_slot() == before)
	await capture_ui("overwrite_confirm")
	clicked(flow, "CancelSave")
	check("cancel preserves world and slot", not flow.busy() and get_tree().current_scene == battle and Slot.new().inspect_slot() == before)
	clicked(battle.hud, "SaveAndExit")
	var current: Dictionary = Slot.new().read_slot()
	var competing: Dictionary = Slot.new().write_slot(current.document)
	check("competing legitimate save committed", competing.ok)
	var newer: Dictionary = Slot.new().inspect_slot()
	clicked(flow, "ConfirmSave")
	check("stale confirmation refuses overwrite", not flow.last_result.ok and flow.last_result.code == "SLOT_CHANGED")
	check("newer slot retained", Slot.new().inspect_slot() == newer)
	clicked(flow, "CloseError")
	battle._close_pause()
	check("unpaused internal caller opens overwrite prompt", flow.request_save_exit(battle).get("confirmation_required", false) and get_tree().paused)
	current = Slot.new().read_slot()
	check("competing save during unpaused prompt", Slot.new().write_slot(current.document).ok)
	newer = Slot.new().inspect_slot()
	clicked(flow, "ConfirmSave")
	check("pre-barrier failure restores unpaused intent", flow.last_result.code == "SLOT_CHANGED" and not get_tree().paused)
	clicked(flow, "CloseError")
	check("error dismissal leaves simulation unpaused", not get_tree().paused and not flow.busy())
	battle._open_pause()
	check("malformed expectation rejected", Slot.new().check_expected({"revision": "1", "file_sha256": "x"}).code == "SLOT_EXPECTATION")
	clicked(battle.hud, "SaveAndExit")
	received = false
	clicked(flow, "ConfirmSave")
	write(obstruction, {})
	await wait_operation()
	check("disk failure retains world", not result.ok and get_tree().current_scene == battle and is_instance_valid(battle))
	check("disk failure releases input barrier", battle._save_barrier.state == battle._save_barrier.State.IDLE)
	DirAccess.remove_absolute(obstruction)
	check("pre-write disk failure preserves old slot", Slot.new().inspect_slot() == newer)
	clicked(flow, "CloseError")
	flow.operation_finished.disconnect(_operation)
	flow.operation_finished.connect(_saved)
	clicked(battle.hud, "SaveAndExit")
	clicked(flow, "ConfirmSave")
	check("second confirm refused during save", flow.confirm_save().code == "CONFIRMATION_NOT_PENDING")
