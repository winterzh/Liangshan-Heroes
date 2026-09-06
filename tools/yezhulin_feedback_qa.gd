extends "res://tools/zhujiazhuang_rts_test.gd"
## Regression QA for Yezhulin stop hints and readable order feedback.
## This is a controlled input/feedback
## fixture, NOT a live route, AI/combat acceptance, visual QA or performance run.
## Battle/unit automatic processing is disabled only inside this QA fixture;
## mission.tick -> level.process are stepped explicitly at their production order.
var feedback_cases: Array[Dictionary] = []
var completed_feedback_cases := 0
var feedback_out := "res://.godot/yezhulin_feedback"

func _freeze_fixture(b) -> void:
	b.set_process(false)
	b.set_physics_process(false)
	for u in b.units:
		if is_instance_valid(u): u.set_physics_process(false)

func _step_feedback(b, seconds: float) -> void:
	# Fixed 0.1-second slices exercise multiple 0.3-second help refreshes.
	var left := seconds
	while left > 0.000001:
		var dt := minf(0.1, left)
		b.mission.tick(dt)
		b.level.process(b, dt)
		left -= dt

func _rescue_fixture():
	var b = await _start("", 5)
	_freeze_fixture(b)
	var l = b.level
	# Explicit position fixture: let the real checkpoint create its real action.
	l.lin_freed.position = b.map.cell_to_world(l.PINE)
	l.lu.position = b.map.cell_to_world(l.PINE) + Vector2(0, -100)
	l.process(b, 0.0)
	_freeze_fixture(b)
	check(l.st == l.RESCUE and b.mission.actions.has("intercept"), "fixture reaches actual rescue checkpoint and action")
	if l.st != l.RESCUE or not b.mission.actions.has("intercept"):
		await _dispose(b)
		return null
	var target: Vector2 = b.map.cell_to_world(b.mission.actions.intercept.cell)
	l.lu.position = target + Vector2(10, 0)
	check(is_equal_approx(float(b.mission.actions.intercept.duration), 0.8), "production intercept retains 0.8-second duration")
	return b

func _task_click(b, actor) -> void:
	b.select_single(actor, false)
	b._issue_order(b.to_screen(b.map.cell_to_world(b.mission.actions.intercept.cell)), false)
	orders += 1

func _wrong_actor(b):
	# Bound Lin is a captive building; use an explicitly injected ordinary soldier
	# so the real selected-mover parser reaches its wrong-person explanation.
	var wrong = b.spawn_at("liang_qiang", 0, b.level.PINE + Vector2i(4, -4))
	wrong.set_physics_process(false)
	_task_click(b, wrong)
	return wrong

func _record_feedback_case(name: String, details: Dictionary) -> void:
	details["case"] = name
	feedback_cases.append(details)
	completed_feedback_cases += 1

func _wrong_person_readability() -> void:
	var b = await _rescue_fixture()
	if b == null: return
	var l = b.level
	var serial: int = l.lu._order_serial
	var wrong = _wrong_actor(b)
	var reason: String = b.mission._status.text
	var deadline: float = l.exec_timer
	check(reason.contains("需要鲁智深") and reason.contains("右键"), "actual wrong-person order explains who and what to click")
	_step_feedback(b, 2.0)
	check(b.mission._status.text == reason, "wrong-person explanation survives repeated help refreshes for 2 seconds")
	check(is_equal_approx(deadline - l.exec_timer, 2.0), "readability window does not pause the rescue deadline")
	check(not l.rescued and b.mission.active_action_id == "" and l.lu._order_serial == serial and b.selection == [wrong], "wrong-person feedback does not select, dispatch or rescue with Lu")
	_step_feedback(b, 1.0)
	check(b.mission._status.text != reason and b.mission._status.text.contains("站稳0.8秒"), "ordinary help returns after the bounded feedback interval")
	_record_feedback_case("wrong_person", {"reason": reason, "deadline_advanced": deadline - l.exec_timer, "returned_guidance": b.mission._status.text})
	await _dispose(b)

func _new_order_and_duration() -> void:
	var b = await _rescue_fixture()
	if b == null: return
	var l = b.level
	_wrong_actor(b)
	var reason: String = b.mission._status.text
	_task_click(b, l.lu)
	check(b.mission._status.text != reason and b.mission._status.text.contains("正在前往"), "correct new player order immediately supersedes held explanation")
	_step_feedback(b, 0.39)
	check(b.mission.active_action_id == "intercept" and b.mission._status.text.contains("%"), "real task progress immediately supersedes guidance")
	_step_feedback(b, 0.39)
	check(not l.rescued and is_equal_approx(float(b.mission._progress), 0.78), "intercept has not completed at 0.78 seconds")
	_step_feedback(b, 0.03)
	check(l.rescued and l.st == l.CARE and b.mission.has_event("action:intercept:intercept"), "one player order completes the original 0.8-second intercept")
	_record_feedback_case("new_order_and_duration", {"rescued": l.rescued, "stage": b.mission.stage_id, "events": b.mission.events.keys()})
	await _dispose(b)

func _interrupted_feedback(kind: String) -> void:
	var b = await _rescue_fixture()
	if b == null: return
	var l = b.level
	_task_click(b, l.lu)
	_step_feedback(b, 0.2)
	check(b.mission.active_action_id == "intercept", kind + " begins from an actual player-initiated action")
	match kind:
		"stop":
			b.select_single(l.lu, false)
			b._order_stop()
		"left_range":
			# Explicit displacement boundary, not a real movement-route claim.
			l.lu.position = b.map.cell_to_world(b.mission.actions.intercept.cell) + Vector2(80, 0)
			_step_feedback(b, 3.01)
		"invalid_actor":
			# Captivity isolates the action-invalid branch without killing the level.
			l.lu.is_captive = true
			_step_feedback(b, 0.1)
	var reason: String = b.mission._status.text
	var expected: String = {"stop": "玩家已改令", "left_range": "离开办理范围", "invalid_actor": "人物已无法行动"}[kind]
	check(reason.contains(expected), kind + " reports its actual interruption reason")
	var deadline: float = l.exec_timer
	_step_feedback(b, 2.0)
	check(b.mission._status.text == reason, kind + " explanation survives repeated help for 2 seconds")
	check(b.mission.active_action_id == "" and not l.rescued and is_zero_approx(float(b.mission._progress)), kind + " cancels progress and does not silently restart the consumed command")
	check(is_equal_approx(deadline - l.exec_timer, 2.0) and b.phase == b.Phase.FIGHT, kind + " leaves the live deadline running")
	_record_feedback_case(kind, {"reason": reason, "deadline_advanced": deadline - l.exec_timer, "rescued": l.rescued})
	await _dispose(b)

func _blocked_and_stage_reset() -> void:
	var b = await _rescue_fixture()
	if b == null: return
	var reason := "边界夹具：此现场暂不可办理。"
	b.mission.block_action("intercept", reason)
	_task_click(b, b.level.lu)
	_step_feedback(b, 2.0)
	check(b.mission._status.text == reason and b.mission.active_action_id == "", "explicit blocked-action fixture keeps its reason and rejects a real player task order")
	# This exercises stage replacement of a fresh, still-held diagnostic.
	b.mission.block_action("intercept", reason + "（阶段切换前新原因）")
	b.mission.begin("feedback_reset_fixture", "阶段切换夹具", "检查旧原因不带入新阶段。")
	b.level._update_help(b)
	check(b.mission._status.text != reason and b.mission._status.text.contains("站稳0.8秒"), "stage transition clears a pending old diagnostic")
	_record_feedback_case("blocked_and_stage_reset", {"reason": reason, "new_status": b.mission._status.text})
	await _dispose(b)

func _key_event(b, code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	b._unhandled_input(event)
	b.level._enforce_post_rescue_escort_control(b)

func _escort_order(b) -> void:
	b.select_single(b.level.lu, false)
	# A plain ground destination avoids task/actor restrictions during key tests.
	b._issue_order(b.to_screen(b.map.cell_to_world(Vector2i(34, 20))), false)
	orders += 1
	b.level._enforce_post_rescue_escort_control(b)

func _all_stopped(group: Array) -> bool:
	return group.all(func(u): return u._state == 0 and u._path.is_empty() and u.mission_order_token == 0)

func _dynamic_stop_hint(settings) -> void:
	var b = await _start("", 5)
	_freeze_fixture(b)
	var l = b.level
	# Explicit care/outcome boundary fixture reused from the current chapter QA.
	l._begin_open_rescue(b, "feedback QA boundary fixture")
	for guard in l.escorts: guard.resolve_story("subdued")
	l.lu.position = l.lin_bound.position + Vector2(40, 0)
	l.process(b, 2.0)
	_freeze_fixture(b)
	l.process(b, 3.0)
	_freeze_fixture(b)
	check(l.st == l.ESCAPE and l._escort_group().size() == 4, "controlled care fixture reaches the actual four-person escort")
	if l.st != l.ESCAPE or l._escort_group().size() != 4:
		await _dispose(b)
		return
	var group: Array = l._escort_group()
	check(_all_stopped(group), "rescued party waits before any new player order")
	var before: Array = group.map(func(u): return u._order_serial)
	var shortcuts: Array = b.mission._buttons.get_children().filter(func(node): return node is Button and not node.is_queued_for_deletion() and node.text == "选中 · 相送队伍")
	check(shortcuts.size() == 1, "current escort stage exposes one real selection shortcut")
	if shortcuts.size() == 1: shortcuts[0].pressed.emit()
	l.process(b, 0.3)
	check(b.selection.size() == group.size() and group.map(func(u): return u._order_serial) == before and _all_stopped(group), "selection shortcut and help select the party without inventing escort movement")
	settings.reset_keybinds()
	b.hud.set_touch_ui(false)
	_escort_order(b)
	var default_hint: String = b.mission._status.text
	check(default_hint.contains("按S") and l.escort_player_target != Vector2.INF, "default stop hint names S after an actual player route")
	check(group.all(func(u): return u.mission_order_token > 0), "player route retains group movement authorization")
	_key_event(b, KEY_S)
	check(_all_stopped(group), "default S input stops the entire escort")
	check(settings.rebind_key("stop", KEY_J), "existing settings API accepts in-memory stop rebinding")
	_escort_order(b)
	var rebound_hint: String = b.mission._status.text
	check(rebound_hint.contains("按J") and not rebound_hint.contains("按S"), "route hint follows the rebound stop key")
	before = group.map(func(u): return u._order_serial)
	_key_event(b, KEY_S)
	check(group.map(func(u): return u._order_serial) == before and l.escort_player_target != Vector2.INF, "former S key no longer cancels the authorized escort route")
	_key_event(b, KEY_J)
	check(_all_stopped(group), "rebound J input stops all four companions")
	b.hud.set_touch_ui(true) # Real lazy-built controls; not rendered touch layout QA.
	_escort_order(b)
	var touch_hint: String = b.mission._status.text
	check(touch_hint.contains("点“■停”") and not touch_hint.contains("按J"), "touch hint names the existing stop button")
	check(is_instance_valid(b.hud._act_stop) and b.hud._act_stop.text == "■停", "hint label matches the real touch control")
	if is_instance_valid(b.hud._act_stop): b.hud._act_stop.pressed.emit()
	l._enforce_post_rescue_escort_control(b)
	check(_all_stopped(group), "actual stop-button signal stops the whole escort")
	_record_feedback_case("dynamic_stop_hint", {"default": default_hint, "rebound": rebound_hint, "touch": touch_hint})
	await _dispose(b)

func _file_signature(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "<absent>"

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	var settings = root.get_node("Settings")
	var original_keys: Dictionary = settings.keybinds.duplicate(true)
	var original_auto: int = settings.auto_micro_level
	var original_edge: bool = settings.edge_scroll
	var original_scale: float = Engine.time_scale
	var saves_before := {"campaign": _file_signature("user://campaign.cfg"), "settings": _file_signature("user://settings.cfg")}
	settings.edge_scroll = false
	Engine.time_scale = 1.0
	# Fail clearly if production feedback integration is unavailable.
	var probe = await _start("", 5)
	_freeze_fixture(probe)
	var applied: bool = probe.mission.has_method("set_feedback") and probe.mission.has_method("set_guidance")
	check(applied, "feedback patch is applied before behavior verification")
	await _dispose(probe)
	if applied:
		await _wrong_person_readability()
		await _new_order_and_duration()
		for kind in ["stop", "left_range", "invalid_actor"]:
			await _interrupted_feedback(kind)
		await _blocked_and_stage_reset()
		await _dynamic_stop_hint(settings)
	settings.keybinds = original_keys
	settings.keybinds_changed.emit()
	settings.auto_micro_level = original_auto
	settings.edge_scroll = original_edge
	Engine.time_scale = original_scale
	var saves_after := {"campaign": _file_signature("user://campaign.cfg"), "settings": _file_signature("user://settings.cfg")}
	check(saves_before == saves_after, "behavior QA leaves campaign and settings save bytes unchanged")
	check(completed_feedback_cases == 7, "all seven behavior fixtures completed without an aborted case")
	DirAccess.make_dir_recursive_absolute(feedback_out)
	var passed := failures.is_empty() and completed_feedback_cases == 7
	var report := {"passed": passed, "checks": checks, "failures": failures, "completed_cases": completed_feedback_cases,
		"cases": feedback_cases, "save_before": saves_before, "save_after": saves_after,
		"scope": "controlled fixed-step input/feedback boundary fixtures; not a live route, visual or performance acceptance"}
	var file := FileAccess.open(feedback_out + "/report.json", FileAccess.WRITE)
	if file == null:
		push_error("Could not write feedback QA report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[yezhulin-feedback-result] ", checks, " checks; completed_cases=", completed_feedback_cases, "; failures=", failures)
	quit(0 if passed else 1)
