extends CanvasLayer
## Normal-scene save/continue orchestration. Public entry remains closed until
## all nine modes and the durable Steam publisher pass acceptance.
## QA enters the same UI/transactions only in an isolated, Steam-disabled profile.
signal operation_finished(result: Dictionary)
const PLAYER_ENTRY_ENABLED := false
const Slot = preload("res://scripts/run_slot_store.gd")
const Session = preload("res://scripts/run_world_session.gd")
const ContentIdentity = preload("res://scripts/run_content_identity.gd")
enum Phase { IDLE, CONFIRM, SAVING, RESTORING, ERROR, EXITING, EXIT_CONFIRM, SETTLING }
var phase := Phase.IDLE
var last_result: Dictionary = {}
var _source: Node
var _expected: Dictionary = {}
var _session: RefCounted
var _overlay: Control
var _graph: RefCounted
var _graph_owner: WeakRef
var _before_paused := false
var _menu_buttons: Array = []
var _terminal: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	set_process(false)
	set_process_input(false)

func is_enabled() -> bool:
	# Do not turn this into a settings toggle or accept an activation flag from a save.
	if PLAYER_ENTRY_ENABLED: return false # Production publisher/whitelist is still absent.
	if not OS.has_feature("editor") or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("LSH_CONTINUE_FLOW_QA") != "1": return false
	var profile := OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").trim_suffix("/")
	if not profile.is_absolute_path() or profile.is_empty(): return false
	for name in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		if OS.get_environment(name).replace("\\", "/").trim_suffix("/") != profile.path_join(name.to_lower()): return false
	return OS.get_user_data_dir().replace("\\", "/").begins_with(profile.path_join("appdata") + "/")

func busy() -> bool:
	return phase != Phase.IDLE

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func add_continue_entry(parent: Control, menu: Node) -> void:
	if not is_enabled(): return
	var button := _button("继续上次战斗", func() -> void: request_continue(menu))
	button.name = "ContinueBattle"
	parent.add_child(button)
	parent.move_child(button, 0)

func add_save_entry(parent: Control, hud: Node) -> void:
	if not is_enabled(): return
	# HUD builds before setup(owner); resolve its Battle at click time, also for
	# private restored HUDs whose owner is attached during component activation.
	var button := _button("保存并退出游戏", func() -> void: request_save_exit(hud.battle))
	button.name = "SaveAndExit"
	parent.add_child(button)

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	Localize.bind_text(button, text)
	button.custom_minimum_size = Vector2(300, 48)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button

func _show(message: String, confirm: String = "") -> void:
	_clear_overlay()
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.035, 0.025, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_overlay = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 640
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var label := Label.new()
	label.name = "Status"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 640
	label.add_theme_font_size_override("font_size", 24)
	Localize.bind_render(label, func() -> String:
		var translated := PackedStringArray()
		for part in message.split("\n\n"): translated.append(Localize.text(part))
		return "\n\n".join(translated))
	box.add_child(label)
	if not confirm.is_empty():
		var failed_exit := phase == Phase.EXIT_CONFIRM
		var cancel_button := _button("取消", _cancel_failed_exit if failed_exit else cancel)
		cancel_button.name = "CancelSave"
		box.add_child(cancel_button)
		var accept := _button(confirm, _confirm_failed_exit if failed_exit else confirm_save)
		accept.name = "ConfirmSave"
		box.add_child(accept)
		cancel_button.grab_focus()
	elif phase == Phase.ERROR:
		if last_result.get("battle_held", false):
			var pending_save: bool = last_result.get("pending_save", false)
			var retry: Button
			if last_result.get("terminal_pending", false):
				retry = _button("重试结算", retry_terminal)
				retry.name = "RetryTerminal"
				box.add_child(retry)
			elif not pending_save or last_result.get("retryable", false):
				retry = _button("重试保存" if pending_save else "重试恢复战斗", retry_save if pending_save else retry_release)
				retry.name = "RetrySave" if pending_save else "RetryRelease"
				box.add_child(retry)
			var leave := _button("退出游戏", _request_failed_exit)
			leave.name = "LeaveHeldBattle"
			box.add_child(leave)
			if retry != null: retry.grab_focus()
			else: leave.grab_focus()
		else:
			var close := _button("返回", dismiss_error)
			close.name = "CloseError"
			box.add_child(close)
			close.grab_focus()
	set_process_input(true)

func _clear_overlay() -> void:
	if is_instance_valid(_overlay): _overlay.free()
	_overlay = null
	set_process_input(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if phase == Phase.CONFIRM: cancel()
		elif phase == Phase.EXIT_CONFIRM: _cancel_failed_exit()
		elif phase == Phase.ERROR: dismiss_error()
		get_viewport().set_input_as_handled()

func request_save_exit(battle: Node) -> Dictionary:
	if not is_enabled(): return _bad("CONTINUE_NOT_RELEASED")
	if busy(): return _bad("OPERATION_BUSY")
	if not is_instance_valid(battle) or battle != get_tree().current_scene or battle.get_script() != Session.Core.B: return _bad("CURRENT_BATTLE_REQUIRED")
	_source = battle
	_before_paused = get_tree().paused
	var supported: Dictionary = battle._save_barrier._scope()
	if not supported.ok: return _fail(supported, false)
	var read: Dictionary = Slot.new().inspect_slot()
	if not read.ok: return _fail(read, false)
	_expected = {"revision": read.revision, "file_sha256": read.file_sha256}
	if read.exists:
		phase = Phase.CONFIRM
		get_tree().paused = true
		_show("覆盖上次的战斗存档？\n\n本机只保留一个继续槽。成功保存后会替换上次存档，取消将留在当前战斗。", "确认覆盖并保存")
		return {"ok": true, "confirmation_required": true}
	return _begin_save()

func cancel() -> void:
	if phase != Phase.CONFIRM: return
	get_tree().paused = _before_paused
	phase = Phase.IDLE
	_source = null
	_expected.clear()
	_clear_overlay()

func confirm_save() -> Dictionary:
	if phase != Phase.CONFIRM: return _bad("CONFIRMATION_NOT_PENDING")
	return _begin_save()

func _begin_save() -> Dictionary:
	phase = Phase.SAVING
	if not is_instance_valid(_source) or _source != get_tree().current_scene: return _fail(_bad("CURRENT_BATTLE_REQUIRED"), false)
	var matching: Dictionary = Slot.new().check_expected(_expected)
	if not matching.ok: return _fail(matching, false)
	_show("正在保存战斗，请稍候…")
	# Restore the prior pause intent before the barrier records it.
	get_tree().paused = _before_paused
	_source._save_barrier.capture_ready.connect(_capture_ready, CONNECT_ONE_SHOT)
	_source._save_barrier.capture_rejected.connect(_capture_rejected, CONNECT_ONE_SHOT)
	var requested: Dictionary = _source.request_run_capture()
	if not requested.ok:
		_disconnect_capture()
		return _fail(requested, false)
	return {"ok": true, "pending": true}

func _disconnect_capture() -> void:
	if not is_instance_valid(_source): return
	var barrier: Node = _source._save_barrier
	if barrier.capture_ready.is_connected(_capture_ready): barrier.capture_ready.disconnect(_capture_ready)
	if barrier.capture_rejected.is_connected(_capture_rejected): barrier.capture_rejected.disconnect(_capture_rejected)

func _capture_rejected(code: String) -> void:
	if phase != Phase.SAVING: return
	_disconnect_capture()
	_fail(_bad(code), false)

func _capture_ready(_clock: Dictionary) -> void:
	_disconnect_capture()
	if phase != Phase.SAVING: return
	# Even an unchanged prompt cannot authorize overwriting a new slot written by
	# another process while the input barrier was draining.
	var trusted := ContentIdentity.new().resolve_runtime_identity()
	if not trusted.ok: _fail(trusted, false); return
	var runtime := {"defs": _source._defs, "abilities": _source._abilities, "items": _source._items}
	_session = Session.new(trusted, runtime)
	var retained: Variant = _graph if _graph_owner != null and _graph_owner.get_ref() == _source else null
	var result: Dictionary = _session.save_held(_source, retained, _expected)
	if not result.ok: _fail(result, false); return
	_save_complete(result)

func _save_complete(result: Dictionary) -> void:
	_session.dispose(); _session = null
	phase = Phase.EXITING
	last_result = result.duplicate(true)
	_show("存档已保存，正在退出…")
	operation_finished.emit(last_result)
	get_node("/root/AppLifecycle").request_quit("continue_saved")

func _runtime() -> Dictionary:
	var defs: Dictionary = Defs.UNITS.duplicate(true)
	var abilities: Dictionary = Defs.ABILITIES.duplicate(true)
	Defs.apply_content_pack(defs, abilities)
	AbilityVisuals.apply(defs, abilities)
	return {"defs": defs, "abilities": abilities, "items": Defs.ITEMS.duplicate(true)}

func request_continue(menu: Node) -> Dictionary:
	if not is_enabled(): return _bad("CONTINUE_NOT_RELEASED")
	if busy(): return _bad("OPERATION_BUSY")
	if not is_instance_valid(menu) or menu != get_tree().current_scene or menu.get_script() != Session.MenuScript: return _bad("CURRENT_MENU_REQUIRED")
	phase = Phase.RESTORING
	_source = menu
	_before_paused = get_tree().paused
	get_tree().paused = true
	_show("正在读取战斗，请稍候…")
	_freeze_menu(menu)
	_restore.call_deferred()
	return {"ok": true, "pending": true}

func _freeze_menu(menu: Node) -> void:
	var stack: Array = [menu]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is BaseButton:
			_menu_buttons.append({"node": node, "disabled": node.disabled})
			node.disabled = true
		stack.append_array(node.get_children())

func _unfreeze_menu() -> void:
	for row in _menu_buttons:
		if is_instance_valid(row.node): row.node.disabled = row.disabled
	_menu_buttons.clear()

func _restore() -> void:
	if phase != Phase.RESTORING: return
	var trusted := ContentIdentity.new().resolve_runtime_identity()
	if not trusted.ok: _fail(trusted, true); return
	_session = Session.new(trusted, _runtime())
	var prepared: Dictionary = _session.prepare_restore(_source)
	if not prepared.ok: _fail(prepared, true); return
	var installed: Dictionary = _session.commit_restore()
	if not installed.ok: _fail(installed, true); return
	_session.dispose(); _session = null
	if _graph != null: _graph.dispose()
	_graph = installed.identity
	_graph_owner = weakref(installed.battle)
	_menu_buttons.clear()
	_source = null
	phase = Phase.IDLE
	_clear_overlay()
	last_result = {"ok": true, "generation": installed.generation, "paused": installed.paused, "steam_credit": installed.steam_credit}
	set_process(true)
	operation_finished.emit(last_result)

func _process(_delta: float) -> void:
	if _graph_owner != null and _graph_owner.get_ref() == null:
		_graph.dispose(); _graph = null; _graph_owner = null
		set_process(false)

func _fail(result: Dictionary, restoring: bool) -> Dictionary:
	var pending_save: bool = _session != null and _session.has_pending_save()
	if pending_save:
		result = result.duplicate(true)
		result["pending_save"] = true
		result["battle_held"] = true
	elif _session != null:
		_session.dispose(); _session = null
	if not pending_save and not restoring and is_instance_valid(_source) and _source.get_script() == Session.Core.B:
		var barrier: Node = _source._save_barrier
		if barrier.state == barrier.State.HELD:
			var released: Dictionary = barrier.release_capture()
			if not released.ok: result = {"ok": false, "code": released.code, "original_error": result.get("code", ""), "battle_held": true}
		elif barrier.state == barrier.State.IDLE:
			# A prompt may pause an otherwise running battle. Rejection before
			# requesting the barrier must restore that caller's pause intent too.
			get_tree().paused = _before_paused
	if restoring: get_tree().paused = _before_paused
	_unfreeze_menu()
	phase = Phase.ERROR
	last_result = result.duplicate(true)
	_show(_held_message() if result.get("battle_held", false) else _error_message(String(result.get("code", "")), restoring))
	operation_finished.emit(last_result)
	return last_result

func _error_message(code: String, restoring: bool) -> String:
	if code == "NO_SLOT": return "没有可继续的战斗存档。"
	if code == "SLOT_CHANGED": return "存档已变化，请重新操作并确认。"
	if code in ["OWNER", "ACCOUNT_MISMATCH"]: return "此存档所属的Steam账号与当前账号不一致。"
	if "TERMINAL" in code or "SETTLED" in code: return "这场战斗已经结束，不能再次继续或领取结算。"
	if "CONTENT" in code or "SCHEMA" in code or "VERSION" in code or "ENGINE" in code: return "存档内容与当前安装版本不一致，暂时无法继续。"
	if "STEAM" in code or "RECEIPT" in code: return "当前Steam进度无法安全绑定存档，请保留当前战斗。"
	if "CLASSIC" in code or code == "UNSUPPORTED_CAPTURE_ENVIRONMENT": return "当前玩法尚不支持中途保存。"
	return "读取失败，原存档已保留。" if restoring else "保存未能确认完成，当前战斗已保留。请检查存储后重试。"

func dismiss_error() -> void:
	if phase != Phase.ERROR: return
	if last_result.get("battle_held", false): return
	phase = Phase.IDLE
	_source = null
	_expected.clear()
	_clear_overlay()

func _held_message() -> String:
	if last_result.get("terminal_pending", false): return "战斗已结束，但结束记录尚未保存，结算暂未发放。请检查存储后重试结算，或退出游戏。"
	if last_result.get("pending_save", false):
		if last_result.get("retryable", false): return "存档写入尚未完成，战斗已保持暂停。请检查存储后重试保存，或退出游戏。已有文件会保留。"
		return "存档状态暂时无法安全确认，战斗已保持暂停。请退出游戏并检查存储，已有文件会保留。"
	return "战斗暂时无法安全恢复，已保持暂停。可以重试恢复，或退出游戏。尚未确认保存的进度可能丢失。"

func retry_save() -> void:
	if phase != Phase.ERROR or _session == null or not _session.has_pending_save() or not last_result.get("retryable", false): return
	phase = Phase.SAVING
	_show("正在保存战斗，请稍候…")
	var retried: Dictionary = _session.retry_pending_save(_source)
	if not retried.ok: _fail(retried, false); return
	_save_complete(retried)

func retry_release() -> void:
	if phase != Phase.ERROR or not last_result.get("battle_held", false) or not is_instance_valid(_source): return
	if last_result.get("pending_save", false) or last_result.get("terminal_pending", false): return
	var released: Dictionary = _source._save_barrier.release_capture()
	if not released.ok:
		last_result["release_error"] = released.code
		_show(_held_message())
		return
	last_result["battle_held"] = false
	_show(_error_message(String(last_result.get("original_error", last_result.code)), false))

func _request_failed_exit() -> void:
	if phase != Phase.ERROR or not last_result.get("battle_held", false): return
	phase = Phase.EXIT_CONFIRM
	_show("退出游戏？\n\n尚未确认保存的进度可能丢失。已有存档文件将保留。", "确认退出游戏")

func _cancel_failed_exit() -> void:
	if phase != Phase.EXIT_CONFIRM: return
	phase = Phase.ERROR
	_show(_held_message())

func _confirm_failed_exit() -> void:
	if phase != Phase.EXIT_CONFIRM: return
	phase = Phase.EXITING
	get_node("/root/AppLifecycle").request_quit("continue_failed")

func finish_local_battle(battle: Node, victory: bool, line: String) -> void:
	# Battle enters END first. Defer disk work until the current physics step
	# has closed, and issue no rewards or settlement UI before durable closure.
	if not _terminal.is_empty(): return
	var cancel_save: bool = has_capture_request(battle)
	if cancel_save: _disconnect_capture()
	_terminal = {"victory": victory, "line": line, "cancel_save": cancel_save}
	_source = battle
	_before_paused = get_tree().paused
	phase = Phase.SETTLING
	_expected.clear()
	_clear_overlay()
	get_tree().process_frame.connect(_commit_terminal, CONNECT_ONE_SHOT)

func has_capture_request(battle: Node) -> bool:
	return phase == Phase.SAVING and _source == battle and battle._save_barrier != null and battle._save_barrier.input_closed()

func _commit_terminal() -> void:
	if phase != Phase.SETTLING or _terminal.is_empty(): return
	if Engine.is_in_physics_frame():
		get_tree().process_frame.connect(_commit_terminal, CONNECT_ONE_SHOT)
		return
	get_tree().paused = true
	if not is_instance_valid(_source) or _source != get_tree().current_scene or (_source._continue_receipt == null and not _terminal.cancel_save):
		_terminal_failed(_bad("LOCAL_TERMINAL_SOURCE_CHANGED")); return
	if _terminal.cancel_save:
		var cancelled: Dictionary = _source._save_barrier.cancel_for_terminal()
		if not cancelled.ok: _terminal_failed(cancelled); return
	var ended: Dictionary = {"ok": true} if _source._continue_receipt == null else _source._continue_receipt.terminal(_terminal.victory)
	if not ended.ok:
		_terminal_failed(ended); return
	var completed: Node = _source
	var outcome := _terminal.duplicate(true)
	_terminal.clear(); _source = null
	phase = Phase.IDLE
	_clear_overlay()
	get_tree().paused = _before_paused
	completed._complete_end(outcome.victory, outcome.line)
	last_result = {"ok": true, "terminal_completed": true, "local_terminal": completed._continue_receipt != null}
	operation_finished.emit(last_result)

func _terminal_failed(reason: Dictionary) -> void:
	last_result = reason.duplicate(true)
	last_result["battle_held"] = true
	last_result["terminal_pending"] = true
	phase = Phase.ERROR
	_show(_held_message())
	operation_finished.emit(last_result)

func retry_terminal() -> void:
	if phase != Phase.ERROR or not last_result.get("terminal_pending", false): return
	phase = Phase.SETTLING
	_clear_overlay()
	get_tree().process_frame.connect(_commit_terminal, CONNECT_ONE_SHOT)
