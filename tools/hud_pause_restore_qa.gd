extends Node
## Focused real HUD/activation regression. Synthetic host supplies installation
## boundaries only; this is not a full Battle finish/save/continue acceptance.
const H := preload("res://scripts/hud.gd")
const HudState := preload("res://scripts/run_hud_state.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
var checks: Array = []
var codec := Codec.new()

class FixtureOwner extends Node:
	var hud: Variant = null
	var signal_installs := 0
	func _prepared_clock_entry_valid() -> bool: return true
	func _connect_hud_signals() -> void: signal_installs += 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("LSH_HUD_PAUSE_PROFILE").replace("\\", "/").simplify_path()
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("HUD_PAUSE_RESTORE_QA PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: push_error(label)

func unbind_branch(node: Node) -> void:
	Localize.unbind(node)
	for child: Node in node.get_children(true): unbind_branch(child)

func all_gated(node: Node) -> bool:
	if node.process_mode != Node.PROCESS_MODE_DISABLED or not node.is_blocking_signals(): return false
	for child: Node in node.get_children(true):
		if not all_gated(child): return false
	return true

func wire_action_counts(hud: Variant, effects: Array) -> void:
	hud.restart.connect(func() -> void: effects[0] += 1)
	hud.to_menu.connect(func() -> void: effects[0] += 1)
	hud.quit_game.connect(func() -> void: effects[0] += 1)

func ordinary_cases(flow: Variant) -> void:
	var hud := H.new(); add_child(hud)
	var effects := [0]; wire_action_counts(hud, effects)
	hud.show_pause()
	check("ordinary pause initially focuses resume", get_viewport().gui_get_focus_owner() == hud._pause_resume_button)
	for action: String in ["restart", "menu", "quit"]:
		hud._request_pause_action(action)
		check("busy normal request rejects " + action, hud._pause_pending_action.is_empty() and hud._pause_options.visible and not hud._pause_confirm.visible)
	# Exercise the actual shipped buttons and their connected closures as well.
	for index: int in [2, 3, 4]:
		var button: Button = hud._pause_options.get_child(index)
		button.pressed.emit()
		check("busy normal button rejects " + str(index), hud._pause_pending_action.is_empty() and not hud._pause_confirm.visible)
	check("busy ordinary clicks have no departure effect or focus change", effects[0] == 0 and get_viewport().gui_get_focus_owner() == hud._pause_resume_button)
	hud.set_meta("_run_hud_prepared", true)
	hud._request_pause_action("menu")
	check("metadata without input gates cannot bypass busy", hud._pause_pending_action.is_empty())
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	hud._request_pause_action("menu")
	check("disabled processing without blocked signals cannot bypass busy", hud._pause_pending_action.is_empty())
	hud.process_mode = Node.PROCESS_MODE_ALWAYS; hud.set_block_signals(true)
	hud._request_pause_action("menu")
	check("blocked signals without disabled processing cannot bypass busy", hud._pause_pending_action.is_empty())
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = false; hud._request_pause_action("menu"); get_tree().paused = true
	check("prepared metadata outside paused installation cannot bypass busy", hud._pause_pending_action.is_empty())
	hud.set_meta("_run_hud_prepared", false); hud._request_pause_action("menu")
	check("false prepared metadata cannot bypass busy", hud._pause_pending_action.is_empty())
	check("busy still active throughout ordinary rejection", flow.busy() and effects[0] == 0)
	unbind_branch(hud); hud.free()

func restored_case(flow: Variant, anchor: Button, action: String) -> void:
	flow.phase = flow.Phase.RESTORING
	anchor.grab_focus()
	var owner := FixtureOwner.new(); owner.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(owner)
	var hud := H.new(); owner.hud = hud
	hud.visible = false; hud.process_mode = Node.PROCESS_MODE_DISABLED; hud.set_block_signals(true)
	hud.set_meta("_run_hud_prepared", true); owner.add_child(hud)
	var effects := [0]; wire_action_counts(hud, effects)
	var prefix := "restored " + action + ": "
	check(prefix + "real HUD ready and fully gated", hud.is_node_ready() and all_gated(hud))
	# Same shipped entry used by run_hud_state.finish for pause.pending.
	hud.show_pause(); hud._request_pause_action(action)
	check(prefix + "pending survives ContinueFlow busy", flow.busy() and hud._pause_pending_action == action)
	check(prefix + "confirmation replaces options", hud._pause_root.visible and hud._pause_confirm.visible and not hud._pause_options.visible)
	var title: String = {"restart": "重新开始本局？", "menu": "返回主菜单？", "quit": "退出游戏？"}[action]
	var confirm: String = {"restart": "确认重新开始", "menu": "确认返回主菜单", "quit": "确认退出游戏"}[action]
	check(prefix + "correct localized confirmation title", hud._pause_confirm_title.text == Localize.text(title))
	check(prefix + "correct localized destructive button", hud._pause_confirm_button.text == Localize.text(confirm))
	check(prefix + "warning and cancel label are populated", not hud._pause_confirm_text.text.is_empty() and not hud._pause_cancel_button.text.is_empty())
	check(prefix + "preparation keeps existing focus", get_viewport().gui_get_focus_owner() == anchor)
	check(prefix + "all widgets remain gated", all_gated(hud) and not hud.visible)
	hud._pause_confirm_button.pressed.emit(); hud._pause_cancel_button.pressed.emit()
	check(prefix + "blocked real confirmation and cancellation signals have no effect", effects[0] == 0 and hud._pause_pending_action == action and hud._pause_confirm.visible)
	hud._confirm_pause_action()
	check(prefix + "direct destructive handler remains busy blocked", effects[0] == 0 and hud._pause_pending_action == action)
	hud._request_pause_action("execute")
	check(prefix + "internal preparation still rejects unknown action", hud._pause_pending_action == action)
	# Real Messages and HudState activation, with only the Battle installation
	# boundary supplied by the synthetic owner. No fake activation or focus code.
	var module := HudState.new()
	var empty_messages := {"schema": "hud_messages_v1", "log": [], "unread": 0, "expanded": false, "scroll": Vector2i.ZERO, "scroll_pending": false, "toasts": []}
	var messages: Dictionary = module._messages.restore(hud, codec.encode(empty_messages).value)
	check(prefix + "real message adapter prepares empty history", messages.ok)
	hud._gate_run_prepared_ui()
	module._owner = owner; module._finished = true; module._frame = Engine.get_process_frames()
	module._raw = {"pause": {"visible": true, "pending": action}, "canvas": {"visible": true}, "activation": {"mode": Node.PROCESS_MODE_ALWAYS, "blocked": false, "priority": 0, "physics_priority": 0, "process": true, "physics": false, "input": true, "shortcut": false, "unhandled": false, "unhandled_key": false}}
	var activated: Dictionary = module.activate()
	check(prefix + "real HudState activates in same paused turn", activated.ok)
	check(prefix + "activation installs signals exactly once", owner.signal_installs == 1)
	check(prefix + "activation removes preparation marker and opens visibility", not hud.has_meta("_run_hud_prepared") and hud.visible and not hud.is_blocking_signals())
	check(prefix + "actual activation focuses cancel", get_viewport().gui_get_focus_owner() == hud._pause_cancel_button)
	check(prefix + "destructive confirmation never takes default focus", not hud._pause_confirm_button.has_focus())
	check(prefix + "activation preserves pending and message state", hud._pause_pending_action == action and hud._message_log.is_empty())
	check(prefix + "duplicate activation rejected", not module.activate().ok and owner.signal_installs == 1)
	hud._request_pause_action("quit" if action != "quit" else "menu")
	hud._pause_confirm_button.pressed.emit()
	check(prefix + "normal controls remain busy blocked after marker removal", hud._pause_pending_action == action and effects[0] == 0)
	flow.phase = flow.Phase.IDLE
	hud._pause_cancel_button.pressed.emit()
	check(prefix + "real cancel clears pending and shows options", hud._pause_pending_action.is_empty() and not hud._pause_confirm.visible and hud._pause_options.visible)
	check(prefix + "cancel returns keyboard focus to resume", get_viewport().gui_get_focus_owner() == hud._pause_resume_button)
	check(prefix + "cancellation emits no departure", effects[0] == 0)
	hud._request_pause_action(action)
	check(prefix + "idle player request still opens confirmation", hud._pause_pending_action == action and hud._pause_confirm.visible)
	check(prefix + "idle request focuses cancel", get_viewport().gui_get_focus_owner() == hud._pause_cancel_button)
	hud._pause_confirm_button.pressed.emit()
	check(prefix + "idle explicit confirmation emits one departure", effects[0] == 1 and hud._pause_pending_action.is_empty())
	unbind_branch(hud); owner.free()

func run() -> void:
	var flow: Variant = get_node_or_null("/root/ContinueFlow")
	check("actual ContinueFlow is installed", flow != null)
	if flow == null: finish(); return
	var old_phase: int = flow.phase
	var old_paused: bool = get_tree().paused
	get_tree().paused = true; flow.phase = flow.Phase.RESTORING
	ordinary_cases(flow)
	var anchor := Button.new(); anchor.text = "External focus"; add_child(anchor)
	for action: String in ["restart", "menu", "quit"]: restored_case(flow, anchor, action)
	anchor.free(); flow.phase = old_phase; get_tree().paused = old_paused
	finish()

func finish() -> void:
	var passed: bool = checks.size() >= 90
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"passed": passed, "checks": checks, "scope": "actual HUD pause request and activation with synthetic installation host", "full_world": false, "real_steam": false, "pid": OS.get_process_id()}
	var file := FileAccess.open(OS.get_environment("LSH_HUD_PAUSE_REPORT"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(report, "  ")); file.close()
	print("HUD_PAUSE_RESTORE_QA ", JSON.stringify(report))
	get_tree().quit(0 if passed else 1)
