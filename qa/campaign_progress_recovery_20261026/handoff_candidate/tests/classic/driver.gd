extends Node
## Actual menu -> ordinary player commands -> real save/exit -> new process.
## This is an acceptance attempt, not a deterministic victory fixture.
const MenuScene = preload("res://scenes/menu.tscn")
const BattleScript = preload("res://scripts/battle.gd")
const Classic = preload("res://scripts/levels/skirmish.gd")
const Slot = preload("res://scripts/run_slot_store.gd")
const Policy = preload("policy.gd")
const LocalLifecycle = preload("res://scripts/run_local_lifecycle.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const InflightObserver = preload("inflight.gd")
const Provider = preload("res://scripts/run_content_identity.gd")
const Codec = preload("res://scripts/run_state_value_codec.gd")
const SLOT_ROOT := "user://continue/v1"
const CASES := ["new_economy", "resume_combat", "resume_transition", "resume_victory", "terminal_reject_1", "terminal_reject_2"]
var trusted: Dictionary = {}
var startup: Dictionary = {}
var config: Dictionary = {}
var state: Dictionary = {}
var checks: Array = []
var battle: Variant = null
var flow: Variant = null
var policy: RefCounted
var _births: Array = []
var _recent_births: Array = []
var _events: FileAccess
var _received := false
var _result: Dictionary = {}
var _saving := false
var _finished := false
var _playing := false
var _next_progress := 0
var _process_started := 0
var _first_tick := 0
var _last_sample_tick := 0
var _last_wave := 0
var _loaded_from_pid := 0
var _trigger: Dictionary = {}

var _perf_frames: Array[float] = []
var _perf_windows: Array = []
var _perf_previous := 0
var _perf_elapsed := 0.0
var _perf_peak_units := 0
var _perf_peak_memory := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	set_process(false)
	_process_started = Time.get_ticks_msec()
	if not _private_profile():
		print("CLASSIC30 PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	var control_path := OS.get_environment("CC_CONTROL")
	var parsed: Variant = _read_json(control_path)
	if not parsed is Dictionary or parsed.get("case", "") not in CASES or parsed.get("case") != OS.get_environment("CC_MODE") \
		or FileAccess.get_sha256(control_path) != OS.get_environment("CC_CONTROL_SHA256") \
		or parsed.get("run_id") != OS.get_environment("CC_NONCE"):
		print("CLASSIC30 CONTROL_REQUIRED")
		get_tree().quit(2)
		return
	config = parsed
	var run_root := OS.get_environment("CC_RUN").replace("\\", "/").trim_suffix("/")
	for key in ["report", "state", "events", "progress", "screenshots"]:
		if not String(config.get(key, "")).replace("\\", "/").begins_with(run_root + "/"):
			print("CLASSIC30 OUTPUT_OUTSIDE_PRIVATE_RUN")
			get_tree().quit(2)
			return
	if not String(config.get("previous_state", "")).is_empty():
		var previous: String = config.previous_state
		if not previous.replace("\\", "/").begins_with(run_root + "/") or FileAccess.get_sha256(previous) != config.get("previous_sha256", ""):
			print("CLASSIC30 PREVIOUS_STATE_IDENTITY")
			get_tree().quit(2)
			return
		var prior: Variant = _read_json(previous)
		if not prior is Dictionary or prior.get("run_id") != config.get("run_id") \
			or prior.get("profile") != OS.get_environment("CC_PROFILE") or prior.get("slot_root") != SLOT_ROOT \
			or prior.get("process_nonce") == OS.get_environment("CC_PROCESS_NONCE"):
			print("CLASSIC30 PREVIOUS_STATE_REQUIRED")
			get_tree().quit(2)
			return
		state = prior
		_loaded_from_pid = int(state.get("pid", 0))
		var previous_report: String = config.get("previous_report", "")
		if not previous_report.replace("\\", "/").begins_with(run_root + "/"):
			push_error("CLASSIC30_PREDECESSOR_REPORT_SCOPE"); get_tree().quit(2); return
		var prior_report: Variant = _read_json(previous_report)
		var previous_index: int = CASES.find(String(config.case)) - 1
		if previous_index < 0 or FileAccess.get_sha256(config.get("previous_report", "")) != config.get("previous_report_sha256") \
			or typeof(prior_report) != TYPE_DICTIONARY or not prior_report.get("passed", false) \
			or prior_report.get("case") != CASES[previous_index] or prior_report.get("run_id") != config.run_id \
			or prior_report.get("state_sha256") != config.previous_sha256 \
			or prior_report.get("process_nonce") != state.process_nonce:
			push_error("CLASSIC30_PREDECESSOR_REPORT_CHAIN"); get_tree().quit(2); return
	else:
		if config.case != "new_economy":
			push_error("CLASSIC30_PREDECESSOR_REQUIRED"); get_tree().quit(2); return
		state = {"version": 1, "run_id": config.run_id, "waves": [], "resumes": [], "seen_units": {},
			"action_counts": {}, "constructed": [], "trained": {}, "resource_start": {},
			"max_wave": 0, "fight_origin_tick": 0, "victory": false, "terminal_rejections": [],
			"checkpoints": [], "normal_start": false, "initial_orders_paid": false}
	_events = FileAccess.open(config.events, FileAccess.WRITE)
	if _events == null:
		print("CLASSIC30 EVENT_FILE_REQUIRED")
		get_tree().quit(2)
		return
	# This slice does not collect or certify performance.
	flow = get_node("/root/ContinueFlow")
	policy = Policy.new()
	_boot.call_deferred()

func _private_profile() -> bool:
	if not OS.has_feature("editor") or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): return false
	if OS.get_environment("LSH_CONTINUE_FLOW_QA") != "1" or OS.get_environment("CC_PROFILE") != OS.get_environment("LSH_CONTINUE_FLOW_PROFILE"): return false
	var profile := OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").trim_suffix("/")
	var run_root := OS.get_environment("CC_RUN").replace("\\", "/").trim_suffix("/")
	if not profile.is_absolute_path() or not run_root.is_absolute_path() or profile.is_empty() or run_root.is_empty(): return false
	if ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower() != OS.get_environment("CC_PROJECT").replace("\\", "/").trim_suffix("/").to_lower(): return false
	if not LocalLifecycle._hex(OS.get_environment("CC_PROCESS_NONCE"), 32): return false
	if OS.get_environment("CC_NONCE").is_empty(): return false
	if ".." in profile.split("/") or ".." in run_root.split("/"): return false
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		if OS.get_environment(key).replace("\\", "/").trim_suffix("/") != profile.path_join(key.to_lower()): return false
	return OS.get_user_data_dir().replace("\\", "/").begins_with(profile.path_join("appdata") + "/")

func _read_json(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

func _write(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "", true, true)); file.flush()
	var good: bool = file.get_error() == OK
	file.close()
	return good

func _check(name: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"name": name, "passed": passed, "detail": detail})
	if not passed: print("CLASSIC30 CHECK_FAILED " + name)
	return passed

func _event(kind: String, detail: Dictionary) -> void:
	if _events == null: return
	_events.store_line(JSON.stringify({"kind": kind, "pid": OS.get_process_id(), "case": config.case,
		"sim_seconds": _seconds(), "detail": detail}, "", true, true))
	_events.flush()

func _seconds() -> float:
	if not is_instance_valid(battle): return 0.0
	return float(int(battle._run_clock._next_tick) - int(state.fight_origin_tick)) / 60.0

func _source_checks(label: String) -> void:
	var changed: Array = []
	for path: String in config.source_sha256:
		if FileAccess.get_sha256("res://" + path) != config.source_sha256[path]: changed.append(path)
	_check("frozen source " + label, changed.is_empty(), changed)
	var actual: Dictionary = Provider.new().resolve_runtime_identity()
	var valid: bool = actual.get("ok",false) and actual.get("save_eligible",false) and actual.get("source_mode",false) \
		and actual.get("content_version") == OS.get_environment("CC_EXPECTED_CONTENT_VERSION") \
		and actual.get("engine_binary_sha256") == OS.get_environment("CC_EXPECTED_ENGINE_SHA256")
	_check("actual candidate identity " + label, valid)
	if trusted.is_empty() and valid: trusted = actual.duplicate(true)
	elif valid: _check("same installed identity " + label, actual == trusted)
	if state.has("identity"):
		# Plain JSON turns Godot integers into floats. Keep the exact typed
		# identity separately, just as the gameplay/terminal observations do.
		var exact_identity: Dictionary = Codec.new().encode(actual)
		_check("predecessor has exact typed candidate identity", exact_identity.ok \
			and exact_identity.get("value") == state.get("exact_identity"))
		_check("predecessor identity summary matches actual provider", \
			JSON.parse_string(JSON.stringify(actual, "", true, true)) == JSON.parse_string(JSON.stringify(state.identity, "", true, true)))

func _press(button: Variant, purpose: String) -> bool:
	if not _check("usable button " + purpose, is_instance_valid(button) and button is Button and button.is_visible_in_tree() and not button.disabled): return false
	_event("button", {"purpose": purpose, "name": button.name, "text": button.text})
	button.pressed.emit()
	return true

func _named(parent: Node, name: String) -> Variant:
	return parent.find_child(name, true, false)

func _text_button(parent: Node, text: String, prefix := false) -> Variant:
	var stack: Array = [parent]
	var result: Variant = null
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.is_visible_in_tree() and (node.text.begins_with(text) if prefix else node.text == text):
			if result != null: return null
			result = node
		stack.append_array(node.get_children())
	return result

func _boot() -> void:
	_source_checks("before")
	if checks.any(func(row: Dictionary) -> bool: return not row.passed): _finish("identity_failure", false); return
	if not _check("real GL renderer", DisplayServer.get_name() != "headless"): _finish("renderer_failure", false); return
	AudioServer.set_bus_mute(0, true)
	Localize.set_language("zh_CN", false)
	var startup_deadline: int = Time.get_ticks_msec() + 30000
	while not flow.can_launch() and Time.get_ticks_msec() < startup_deadline:
		await get_tree().process_frame
	startup = flow.last_result.duplicate(true)
	if not _check("real startup recovery completed before menu commands", flow.can_launch() and startup.get("startup_checked",false), startup):
		_finish("startup_failure", false); return
	_check("classic player release enabled", flow.PLAYER_ENTRY_ENABLED == true)
	_check("default 60 Hz and speed", Engine.physics_ticks_per_second == 60 and get_node("/root/Settings").game_speed == 1.0)
	_check("SDK unavailable in private profile", not get_node("/root/SteamService").available)
	var menu: Node = MenuScene.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	if config.case == "public_gate":
		_check("editor continue requires private profile", not flow.is_enabled() and _named(menu, "ContinueBattle") == null)
		_check("direct public continue refused", flow.request_continue(menu).get("code") == "CONTINUE_NOT_RELEASED")
		_finish("public_gate_verified", true)
		return
	if not _check("isolated continue enabled", flow.is_enabled()): _finish("gate_failure", false); return
	flow.operation_finished.connect(_operation)
	if config.case in ["new_economy", "diagnostic"]:
		_check("fresh profile has no continue slot", Slot.new(SLOT_ROOT).read_slot().get("code") == "NO_SLOT")
		if not _press(_text_button(menu, Localize.text("🛡  驻守战"), true), "defense module"): _finish("menu_failure", false); return
		await get_tree().process_frame
		var campaign := get_node("/root/Campaign")
		if not _check("normal menu defaults", not campaign.ai_friendly and not campaign.scale_on): _finish("nonstandard_options", false); return
		if not _press(_text_button(menu, Localize.text("🛡  30 关 · 经典（推荐）")), "classic 30"): _finish("menu_failure", false); return
		for _frame in range(3600):
			await get_tree().process_frame
			if get_tree().current_scene != null and get_tree().current_scene.get_script() == BattleScript: break
		battle = get_tree().current_scene
		if not _check("normal menu launched actual battle", battle != null and battle.get_script() == BattleScript): _finish("launch_failure", false); return
		_attach_battle()
		_check("ordinary starting economy", battle.gold == 250 and battle.wood == 150 and battle.pop_cap == 20)
		_check("ordinary starting units", battle.units.filter(func(u: Variant) -> bool: return u.is_worker).size() == 5 and battle.count_alive(0, "liang_dao") == 2)
		for u: Variant in battle.units:
			if u.is_resource: state.resource_start[str(u.entity_id)] = {"kind": u.res_kind, "amount": u.res_left}
		while battle.hud._intro_root.visible:
			if not _press(battle.hud._intro_btn, "advance original intro"): _finish("intro_failure", false); return
			if battle.hud._intro_root.visible: await get_tree().process_frame
		state.fight_origin_tick = int(battle._run_clock._next_tick)
		state.normal_start = battle.phase == 2 and battle.level._started and battle.level._wave == 0 and is_equal_approx(battle.level._wave_t, 120.0)
		if not _check("normal introduction starts first preparation", state.normal_start): _finish("normal_start_failure", false); return
		# The intro signal changes phase immediately, but normal fog is populated
		# by the next real FIGHT physics step. Wait for that visible world instead
		# of filtering every building site against the still-empty intro sight map.
		# Keep the original fight clock: this wait consumes ordinary preparation time.
		var vision_before: bool = battle.is_visible_world(battle.level.hall.position)
		var vision_deadline: int = Time.get_ticks_msec() + 10000
		while not battle.is_visible_world(battle.level.hall.position) and Time.get_ticks_msec() < vision_deadline:
			await get_tree().process_frame
		var vision_ready: bool = battle.is_visible_world(battle.level.hall.position) and battle.phase == 2 and _seconds() <= 2.0
		state.initial_vision = {"visible_before_wait": vision_before, "visible_after_wait": battle.is_visible_world(battle.level.hall.position), "sim_seconds": _seconds()}
		_event("initial_vision_ready", state.initial_vision)
		if not _check("normal visibility before player construction", vision_ready, state.initial_vision): _finish("initial_visibility_failure", false); return
		policy.initial_orders(battle, _seconds())
		_drain_actions()
		state.initial_orders_paid = int(state.action_counts.get("build", 0)) > 0 and int(state.action_counts.get("train", 0)) > 0
		_check("initial paid construction and training", state.initial_orders_paid)
	else:
		var before_continue: Dictionary = _durable_snapshot()
		_check("predecessor same slot binding before continue", before_continue.get("slot_sha256") == state.get("slot_sha256") \
			and before_continue.get("binding") == state.get("slot_binding"))
		if String(config.case).begins_with("terminal_reject"):
			var exact_terminal: Dictionary = Codec.new().encode(before_continue)
			_check("terminal predecessor preserves exact disk and reward snapshot", exact_terminal.ok and exact_terminal.get("value") == state.get("exact_terminal"))
		if checks.any(func(row: Dictionary) -> bool: return not row.passed): _finish("predecessor_boundary_failure", false); return
		_received = false
		if not _press(_named(menu, "ContinueBattle"), "continue saved battle"): _finish("continue_button_failure", false); return
		await _wait_operation()
		if String(config.case).begins_with("terminal_reject"):
			var code: String = _result.get("code", "")
			var refused: bool = _received and not _result.get("ok", false) and code in ["RUN_TERMINAL", "LOCAL_RUN_TERMINAL", "CONTINUE_RUN_TERMINAL", "SLOT_TERMINAL"]
			_check("terminal refusal has explicit terminal reason", refused, code)
			_check("terminal refusal retains actual menu", get_tree().current_scene == menu and is_instance_valid(menu))
			_check("terminal refusal cannot activate simulation", get_tree().current_scene.get_script() != BattleScript)
			_check("terminal refusal leaves slot lifecycle CFG and rewards unchanged", _durable_snapshot() == before_continue)
			_check("terminal refusal cannot mount a private battle", get_tree().root.get_children().all(func(node): return node.get_script() != BattleScript))
			if refused:
				state.terminal_rejections.append({"case": config.case, "pid": OS.get_process_id(), "code": code})
				_press(_named(flow, "CloseError"), "dismiss terminal refusal")
			_finish("terminal_refused" if refused else "terminal_replay_not_rejected", refused)
			return
		if not _check("continue succeeded", _received and _result.get("ok", false), _result): _finish("restore_failure", false); return
		battle = get_tree().current_scene
		if not _check("restored real classic battle", battle.get_script() == BattleScript): _finish("restore_identity_failure", false); return
		_check("saved pause intent restored", get_tree().paused and battle.hud._pause_root.visible)
		_check("different process nonce after save", _loaded_from_pid > 0 and state.process_nonce != OS.get_environment("CC_PROCESS_NONCE"))
		var differences: Array = []
		_compare(state.snapshot, _snapshot(), "world", differences)
		_check("restored observed gameplay state", differences.is_empty(), differences.slice(0, 30))
		var exact: Dictionary = Codec.new().encode(_snapshot())
		_check("lossless typed paused observation survives restore", exact.ok and exact.get("value") == state.get("exact_snapshot"))
		var disk: Dictionary = Slot.new().read_slot()
		_check("read keeps original saved slot", disk.get("ok", false) and disk.get("file_sha256") == state.slot_sha256)
		_check("restored same classic lifecycle token and binding", disk.ok and disk.document.binding == state.slot_binding \
			and battle._continue_receipt != null and battle._continue_receipt.get_script() == LocalLifecycle \
			and battle._continue_receipt.token == state.slot_binding.token)
		if checks.any(func(row: Dictionary) -> bool: return not row.passed): _finish("restore_mismatch", false); return
		state.resumes.append({"from_pid": _loaded_from_pid, "pid": OS.get_process_id(), "wave": battle.level._wave, "slot_sha256": state.slot_sha256, "differences": differences})
		_attach_battle()
		if not _press(battle.hud._pause_resume_button, "resume saved pause"): _finish("resume_button_failure", false); return
	_first_tick = int(battle._run_clock._next_tick)
	_last_sample_tick = _first_tick
	_last_wave = int(battle.level._wave)
	_guard()
	if checks.any(func(row: Dictionary) -> bool: return not row.passed): _finish("initial_guard_failure", false); return
	_playing = true
	set_process(true)
	_event("playing", _summary())

func _attach_battle() -> void:
	battle.units_root.child_entered_tree.connect(_unit_added)
	for u: Variant in battle.units: _remember(u, true)

func _unit_added(u: Node) -> void:
	if u.get_script() != preload("res://scripts/unit.gd"): return
	_births.append({"unit": u, "wave_before": int(battle.level._wave), "tick": int(battle._run_clock._next_tick)})
	if not u.died.is_connected(_died): u.died.connect(_died)

func _died(u: Variant) -> void:
	_remember(u, false)
	_event("death", {"id": str(u.entity_id), "key": u.key, "faction": u.faction, "hero": u.is_hero})

func _remember(u: Variant, existing: bool) -> void:
	if not is_instance_valid(u) or u.entity_id <= 0 or u.key == "": return
	var token := str(u.entity_id)
	if not u.died.is_connected(_died): u.died.connect(_died)
	if state.seen_units.has(token): return
	state.seen_units[token] = {"key": u.key, "faction": u.faction}
	if not existing and u.faction == 0 and not u.is_building and not u.is_resource and not u.is_summon:
		state.trained[u.key] = int(state.trained.get(u.key, 0)) + 1
	_event("unit_observed", {"id": token, "key": u.key, "faction": u.faction, "existing": existing})

func _observe() -> void:
	for entry: Dictionary in _births:
		var u: Variant = entry.unit
		if not is_instance_valid(u): continue
		_remember(u, false)
		if u.faction == 1 and not u.is_summon:
			_recent_births.append({"id": str(u.entity_id), "key": u.key, "wave_before": entry.wave_before, "tick": entry.tick})
	_births.clear()
	for u: Variant in battle.units:
		if not is_instance_valid(u): continue
		_remember(u, true)
		if u.faction == 0 and u.is_building and not u.is_resource and not u.is_constructing and u.setup_def.get("buildable", false) and str(u.entity_id) not in state.constructed:
			state.constructed.append(str(u.entity_id))
			_event("construction_completed", {"id": str(u.entity_id), "key": u.key})
	var wave: int = battle.level._wave
	if wave != _last_wave:
		_check("wave advances one at a time " + str(wave), wave == _last_wave + 1 and wave >= 1 and wave <= 30)
		if wave < 1 or wave > 30: return
		var actual: Array = _recent_births.filter(func(row: Dictionary) -> bool: return int(row.wave_before) == wave - 1 and int(row.tick) >= _last_sample_tick)
		var expected: Array = []
		for group: Array in Classic.WAVES[wave - 1].groups:
			for _i in range(int(group[1])): expected.append(String(group[0]))
		for _i in range(1 if wave <= 10 else 2): expected.append("siege_cata")
		var keys: Array = actual.map(func(row: Dictionary) -> String: return row.key)
		_check("actual complete enemy roster wave " + str(wave), keys == expected, {"expected": expected, "actual": actual})
		var expected_time := 0.0
		for index in range(wave): expected_time += float(Classic.WAVES[index].t)
		_check("normal wave schedule " + str(wave), _seconds() >= expected_time - 0.04 and _seconds() <= expected_time + 1.0, {"expected_seconds": expected_time, "actual_seconds": _seconds()})
		var row := {"wave": wave, "pid": OS.get_process_id(), "sim_seconds": _seconds(), "enemy_roster": actual, "expected_count": expected.size(), "hall_hp": battle.level.hall.hp}
		state.waves.append(row)
		state.max_wave = wave
		_event("wave", row)
		_last_wave = wave
	_last_sample_tick = int(battle._run_clock._next_tick)
	_recent_births = _recent_births.filter(func(row: Dictionary) -> bool: return int(row.tick) >= _last_sample_tick)

func _process(_delta: float) -> void:
	if _finished or not _playing or not is_instance_valid(battle): return
	_observe()
	if Time.get_ticks_msec() >= _next_progress:
		_next_progress = Time.get_ticks_msec() + 10000
		_guard()
		var progress: Dictionary = _summary()
		_write(config.progress, progress)
		_event("progress", progress)
	if checks.any(func(row: Dictionary) -> bool: return not row.passed): _finish("invariant_failure", false); return
	if flow.busy():
		if flow.phase == flow.Phase.ERROR and flow.last_result.get("terminal_pending", false):
			_finish("terminal_storage_failure", false)
		return
	if battle.phase == 3:
		_terminal.call_deferred()
		_playing = false
		return
	if _saving or get_tree().paused: return
	if config.case == "diagnostic" and _seconds() >= float(config.diagnostic_seconds):
		_finish("diagnostic_duration_reached", true)
		return
	if _seconds() >= float(config.max_sim_seconds): _finish("normal_play_time_limit", false); return
	var witness: Dictionary = _summary()
	if config.case == "new_economy" and _seconds() >= 8.0 and witness.constructing > 0 and witness.training > 0 and witness.resource_extracted > 0.0:
		_request_save("economy", witness)
		return
	if config.case == "new_economy" and _seconds() > 100.0: _finish("economy_checkpoint_not_reached", false); return
	if config.case == "resume_combat" and _seconds() >= float(state.saved_seconds) + 2.0 and witness.enemies > 0 and witness.in_flight > 0:
		_request_save("combat", witness)
		return
	if config.case == "resume_transition" and int(battle.level._wave) > int(state.snapshot.level.wave) and int(battle.level._wave) < 30:
		var remaining: float = Classic.WAVES[int(battle.level._wave)].t
		if battle.level._wave_t >= remaining - 0.5:
			_request_save("wave_transition", witness)
			return
	policy.tick(battle, _seconds())
	_drain_actions()

func _drain_actions() -> void:
	for action: Dictionary in policy.take_actions():
		state.action_counts[action.kind] = int(state.action_counts.get(action.kind, 0)) + 1
		if action.kind in ["build", "train"]:
			var detail: Dictionary = action.detail
			_check("paid command " + action.kind + " " + str(state.action_counts[action.kind]),
				is_equal_approx(float(detail.before[0]) - float(detail.after[0]), float(detail.definition_cost[0])) and is_equal_approx(float(detail.before[1]) - float(detail.after[1]), float(detail.definition_cost[1])))
		_event("player_command", action)

func _guard() -> void:
	var okay: bool = Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 and get_node("/root/Settings").game_speed == 1.0
	okay = okay and not battle.ai_friendly and not get_node("/root/Campaign").ai_friendly and not get_node("/root/Campaign").scale_on
	okay = okay and not battle._smoke and not battle._prof_on and not battle._no_opt and get_node("/root/Settings").auto_micro_level == 0
	okay = okay and battle.enemy_count_mult() == 1.0 and battle.enemy_hp_mult() == 1.0 and battle.enemy_atk_mult() == 1.0
	okay = okay and battle.level.get_script() == Classic and get_node("/root/Campaign").defense_waves == 30 and not get_node("/root/Campaign").defense_random
	okay = okay and battle._steam_run_id == 0 and not get_node("/root/SteamService").available
	okay = okay and battle.gameplay_rng_fault().is_empty() and battle._run_clock.fault().is_empty()
	if not okay:
		var detail := _summary()
		detail["settings_auto_micro"] = get_node("/root/Settings").auto_micro_level
		detail["settings_game_speed"] = get_node("/root/Settings").game_speed
		detail["campaign_ai_friendly"] = get_node("/root/Campaign").ai_friendly
		detail["campaign_scale_on"] = get_node("/root/Campaign").scale_on
		detail["battle_ai_friendly"] = battle.ai_friendly
		detail["diagnostic_flags"] = [battle._smoke, battle._prof_on, battle._no_opt]
		_check("ordinary classic rules remain unchanged", false, detail)

func _summary() -> Dictionary:
	if not is_instance_valid(battle): return {"case": config.get("case", ""), "pid": OS.get_process_id(), "sim_seconds": 0.0}
	var training := 0
	var constructing := 0
	var resource_extracted := 0.0
	var heroes: Array = []
	for u: Variant in battle.units:
		if not is_instance_valid(u): continue
		if u.faction == 0 and u.is_constructing: constructing += 1
		if u.faction == 0: training += u._train_queue.size()
		if u.is_resource and state.resource_start.has(str(u.entity_id)):
			resource_extracted += maxf(0.0, float(state.resource_start[str(u.entity_id)].amount) - u.res_left)
		if u.faction == 0 and u.is_hero: heroes.append({"key": u.key, "hp": u.hp, "max_hp": u.max_hp, "level": u.hero_level})
	var in_flight: int = battle._pending_casts.size() + battle._pending_item_casts.size()
	for effect: Node in battle.fx_root.get_children():
		if effect.get_script() == ProjectileScript and not effect.is_queued_for_deletion(): in_flight += 1
	return {"case": config.case, "pid": OS.get_process_id(), "sim_seconds": _seconds(), "phase": battle.phase,
		"wave": battle.level._wave, "wave_timer": battle.level._wave_t, "gold": battle.gold, "wood": battle.wood,
		"hall_hp": battle.level.hall.hp, "enemies": battle.enemies_alive(), "kills": battle.kills,
		"valid_kills": battle._steam_valid_kills, "units": battle.units.size(), "training": training,
		"constructing": constructing, "resource_extracted": resource_extracted, "in_flight": in_flight, "heroes": heroes,
		"physics_hz": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale, "clock_fault": battle._run_clock.fault(),
		"gameplay_fault": battle.gameplay_rng_fault(), "action_counts": state.action_counts.duplicate()}

func _snapshot() -> Dictionary:
	var inflight: Dictionary = InflightObserver.new().capture(battle, _saving)
	_check("paused in-flight observation captured", inflight.get("ok", false), inflight.get("code", ""))
	var units: Array = []
	for u: Variant in battle.units:
		if not is_instance_valid(u): continue
		units.append({"id": str(u.entity_id), "key": u.key, "faction": u.faction, "hp": u.hp, "max_hp": u.max_hp,
			"position": [u.position.x, u.position.y], "state": u._state, "construction": u.is_constructing,
			"build_progress": u.build_progress, "queue": u._train_queue.duplicate(), "train_t": u._train_t,
			"carry": [u._carry_kind, u._carry_amt, u._gather_t], "resource_left": u.res_left,
			"hero": [u.hero_level, u.hero_xp, u.skill_points], "abilities": u.ability_slots.duplicate(true),
			"research": [u._research_key, u._research_t], "target": _unit_id(u._target), "gather": _unit_id(u._gather_node), "builder_target": _unit_id(u._build_site)})
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	return {"gold": battle.gold, "wood": battle.wood, "kills": battle.kills, "valid_kills": battle._steam_valid_kills,
		"auto_micro_level": get_node("/root/Settings").auto_micro_level,
		"inflight": inflight.get("value", {}), "inflight_witness": inflight.get("witness", {}),
		"next_entity_id": str(battle.next_entity_id), "clock_next": str(battle._run_clock._next_tick),
		"level": {"wave": battle.level._wave, "timer": battle.level._wave_t, "started": battle.level._started, "spawned": battle.level._wave_spawned},
		"units": units, "hero_progress": battle.hero_progress.duplicate(true), "hero_combat_stats": battle.hero_combat_stats.duplicate(true),
		"pending_cast_count": battle._pending_casts.size(), "walk_cast_count": battle._walk_casts.size(), "fx_count": battle.fx_root.get_child_count()}

func _unit_id(u: Variant) -> String:
	return str(u.entity_id) if is_instance_valid(u) else ""

func _compare(expected: Variant, actual: Variant, path: String, differences: Array) -> void:
	if typeof(expected) in [TYPE_INT, TYPE_FLOAT] and typeof(actual) in [TYPE_INT, TYPE_FLOAT]:
		if absf(float(expected) - float(actual)) > maxf(0.000001, absf(float(expected)) * 0.0000001): differences.append(path)
	elif expected is Dictionary and actual is Dictionary:
		if expected.size() != actual.size(): differences.append(path + ".keys")
		for key: Variant in expected:
			if not actual.has(key): differences.append(path + ".missing:" + str(key))
			else: _compare(expected[key], actual[key], path + "." + str(key), differences)
	elif expected is Array and actual is Array:
		if expected.size() != actual.size(): differences.append(path + ".length")
		for index in range(mini(expected.size(), actual.size())): _compare(expected[index], actual[index], path + "[" + str(index) + "]", differences)
	elif expected != actual: differences.append(path)

func _request_save(kind: String, witness: Dictionary) -> void:
	_saving = true
	_trigger = {"kind": kind, "witness": witness.duplicate(true), "pid": OS.get_process_id()}
	_event("checkpoint_trigger", _trigger)
	# Desktop has no touch-only menu button. Use the actual viewport keyboard
	# route; Esc first cancels an armed command or exits a worker submenu.
	for attempt in range(3):
		if get_tree().paused and battle.hud._pause_root.visible: break
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		_event("keyboard", {"key": "Escape", "purpose": "open actual pause menu", "attempt": attempt})
		get_viewport().push_input(key)
		key = key.duplicate()
		key.pressed = false
		get_viewport().push_input(key)
		await get_tree().process_frame
	if not _check("pause opens before save", get_tree().paused and battle.hud._pause_root.visible): _finish("pause_input_failure", false); return
	# Only the test's tree observer is removed. Production capture correctly
	# refuses arbitrary world-container signals; the paused world cannot spawn.
	_observe()
	if battle.units_root.child_entered_tree.is_connected(_unit_added):
		battle.units_root.child_entered_tree.disconnect(_unit_added)
	_screenshot(kind + "_before_save")
	if not _press(_named(battle.hud, "SaveAndExit"), "save and exit"): _finish("save_button_failure", false); return
	if flow.phase == flow.Phase.CONFIRM:
		if not _press(_named(flow, "ConfirmSave"), "confirm overwrite"): _finish("confirm_button_failure", false)

func _operation(value: Dictionary) -> void:
	_result = value.duplicate(true)
	_received = true
	if not _saving: return
	if not _check("real save operation completed", value.get("ok", false), value): _finish("save_failure", false); return
	_observe()
	var disk: Dictionary = Slot.new().read_slot()
	_check("save matches closed disk", disk.get("ok", false) and disk.get("file_sha256") == value.get("file_sha256"))
	if not disk.get("ok", false): _finish("saved_slot_unreadable", false); return
	_check("private local binding remains uncredited", LocalLifecycle.validate_binding(disk.document.binding).get("ok", false) and battle._steam_run_id == 0)
	_check("classic slot context and identity remain exact", disk.document.schema == Slot.SCHEMA and disk.document.context == Slot.CONTEXT \
		and disk.document.world.content_version == trusted.content_version and disk.document.world.engine_sha256 == trusted.engine_binary_sha256)
	_check("one new slot generation per real save", int(disk.document.generation) == state.checkpoints.size() + 1)
	if state.has("slot_binding"):
		_check("resave retains original token and active receipt SHA", disk.document.binding == state.slot_binding)
	else:
		state.slot_binding = disk.document.binding.duplicate(true)
	_check("saved live world holds same real classic receipt", battle._continue_receipt != null \
		and battle._continue_receipt.get_script() == LocalLifecycle and battle._continue_receipt.token == state.slot_binding.token)
	var lifecycle: Dictionary = _classic_receipt(state.slot_binding.token)
	_check("classic receipt remains generation one active across saves", lifecycle.get("ok", false) and lifecycle.get("revision") == 1 \
		and lifecycle.get("document", {}).get("state") == "active" and lifecycle.get("sha256") == state.slot_binding.receipt_sha256)
	state.snapshot = _snapshot()
	var encoded: Dictionary = Codec.new().encode(state.snapshot)
	_check("snapshot encodes with production lossless value codec", encoded.ok)
	state.exact_snapshot = encoded.get("value", {})
	_trigger["held_witness"] = state.snapshot.inflight_witness.duplicate(true)
	if _trigger.kind == "combat":
		_check("actual HELD combat boundary retains in-flight action", int(_trigger.held_witness.get("enemies", 0)) > 0 and int(_trigger.held_witness.get("in_flight", 0)) > 0, _trigger.held_witness)
	state.slot_sha256 = disk.file_sha256
	state.saved_seconds = _seconds()
	state.checkpoints.append(_trigger)
	_stamp_state()
	_write(config.state, state)
	_source_checks("after")
	_report("saved_exit_pending", checks.all(func(row: Dictionary) -> bool: return row.passed))
	# Production owns the actual exit. Its three release frames give this test
	# observer a frame to retain the real lifecycle reason before process exit.
	await get_tree().process_frame
	_check("production save-and-exit lifecycle", get_node("/root/AppLifecycle").quit_started() and get_node("/root/AppLifecycle").quit_reason() == "continue_saved")
	_report("saved_and_exiting", checks.all(func(row: Dictionary) -> bool: return row.passed))
	_finished = true

func _wait_operation() -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while not _received and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	_check("operation returns within 60 seconds", _received)

func _terminal() -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while (flow.busy() or not battle.hud._end_root.visible or not flow.last_result.get("terminal_completed",false)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check("classic terminal waits for durable flow and actual HUD", not flow.busy() and battle.hud._end_root.visible \
		and flow.last_result.get("terminal_completed",false) and flow.last_result.get("local_terminal",false) \
		and not flow.last_result.get("campaign_progress_committed",true))
	var won: bool = battle.hud._end_root.visible and battle.hud._end_title.text == Localize.text("旗开得胜！") and battle.level._wave == 30 and battle.enemies_alive() == 0 and battle.level.hall.hp > 0.0
	state.victory = won
	state.terminal_summary = _summary()
	_screenshot("victory" if won else "defeat")
	if not won:
		_finish("normal_play_defeat", config.case == "diagnostic")
		return
	_check("all thirty waves occurred naturally", state.waves.size() == 30 and state.max_wave == 30)
	_check("all expected ordinary enemies observed", state.waves.reduce(func(total: int, row: Dictionary) -> int: return total + row.enemy_roster.size(), 0) == 778)
	_check("nonzero normal combat score", battle.kills > 0 and battle._steam_valid_kills > 0)
	_check("paid recruits completed", not state.trained.is_empty())
	_check("paid buildings completed", not state.constructed.is_empty())
	_check("normal skills learned and cast", state.action_counts.get("learn", 0) > 0 and state.action_counts.get("cast", 0) > 0)
	if config.case != "diagnostic":
		_check("three distinct save phases and process restores", state.checkpoints.size() == 3 and state.resumes.size() == 3)
	var terminal: Dictionary = _durable_snapshot()
	_check("classic generation two terminal has same run token", terminal.get("lifecycle",{}).get("revision") == 2 \
		and terminal.get("lifecycle",{}).get("document",{}).get("state") == "terminal" \
		and terminal.get("lifecycle",{}).get("document",{}).get("victory",false) \
		and terminal.get("binding") == state.slot_binding and battle._continue_receipt.token == state.slot_binding.token)
	_check("natural terminal keeps the last active slot unchanged", terminal.get("slot_sha256") == state.slot_sha256 \
		and terminal.get("slot_generation") == 3)
	state.terminal_snapshot = terminal
	var encoded: Dictionary = Codec.new().encode(terminal)
	_check("terminal boundary encodes losslessly", encoded.ok)
	state.exact_terminal = encoded.get("value",{})
	state.settlement_text = {"title": battle.hud._end_title.text, "summary": battle.hud._end_sub.text, "tally": battle.hud._end_tally.text}
	_finish("natural_victory", checks.all(func(row: Dictionary) -> bool: return row.passed))

func _screenshot(stem: String) -> void:
	DirAccess.make_dir_recursive_absolute(config.screenshots)
	var path: String = String(config.screenshots).path_join(String(config.case) + "_" + stem + ".png")
	RenderingServer.force_draw(false)
	var screen_image: Image = get_viewport().get_texture().get_image()
	_check("screenshot saved " + stem, screen_image != null and screen_image.save_png(path) == OK)

func _report(outcome: String, passed: bool) -> void:
	var output := {"schema":"handoff_classic30_regression_v1", "suite": "classic30-continue-regression", "run_id": config.run_id, "case": config.case,
		"mode":config.case, "batch_nonce":OS.get_environment("CC_NONCE"), "process_nonce":OS.get_environment("CC_PROCESS_NONCE"),
		"profile":OS.get_environment("CC_PROFILE"), "slot_root":SLOT_ROOT, "trusted_identity":trusted,
		"startup":startup, "native_release":false, "os_input":false, "human_acceptance":false, "published":false,
		"pid": OS.get_process_id(), "outcome": outcome, "passed": passed, "checks": checks,
		"summary": _summary(), "state_sha256": FileAccess.get_sha256(config.state), "events_sha256": FileAccess.get_sha256(config.events),
		"seconds_in_process": float(Time.get_ticks_msec() - _process_started) / 1000.0,
		"source_sha256": config.source_sha256, "real_steam": false, "public_player_entry_tested": false, "release_config_enabled": flow.PLAYER_ENTRY_ENABLED,
		"manual_player_test": false, "performance_acceptance": false, "rendered_performance": _performance_report(),
		"full_30_wave_victory": state.get("victory", false), "terminal_rejection_count": state.terminal_rejections.size(),
		"diagnostic_only": config.case == "diagnostic"}
	_write(config.report, output)
	print("CLASSIC30 " + JSON.stringify({"case": config.case, "outcome": outcome, "passed": passed, "wave": state.max_wave}))

func _finish(outcome: String, passed: bool) -> void:
	if _finished: return
	_finished = true
	_playing = false
	set_process(false)
	_source_checks("after")
	_stamp_state()
	state.last_outcome = outcome
	state.saved_seconds = _seconds()
	_write(config.state, state)
	passed = passed and checks.all(func(row: Dictionary) -> bool: return row.passed)
	_report(outcome, passed)
	if _events != null: _events.close()
	get_node("/root/Sfx").shutdown()
	get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)

func _stamp_state() -> void:
	state.pid = OS.get_process_id()
	state.process_nonce = OS.get_environment("CC_PROCESS_NONCE")
	state.profile = OS.get_environment("CC_PROFILE")
	state.slot_root = SLOT_ROOT
	state.identity = trusted.duplicate(true)
	var exact_identity: Dictionary = Codec.new().encode(trusted)
	_check("candidate identity encodes with production lossless value codec", exact_identity.ok)
	state.exact_identity = exact_identity.get("value", {})

func _classic_receipt(token: String) -> Dictionary:
	var receipt := LocalLifecycle.new(token, SLOT_ROOT)
	var head: Dictionary = receipt.open_head()
	if not head.ok: return head
	var files: Dictionary = receipt.inventory()
	if not files.ok: return files
	return {"ok":true, "token":token, "revision":head.revision, "sha256":head.file_sha256,
		"document":head.document.duplicate(true), "inventory":files.items.duplicate(true)}

func _durable_snapshot() -> Dictionary:
	var disk: Dictionary = Slot.new(SLOT_ROOT).read_slot()
	if not disk.ok: return disk
	var campaign: Node = get_node("/root/Campaign")
	var cfg := ConfigFile.new()
	var cfg_path: String = campaign.SAVE_PATH
	var cfg_data := {"exists":FileAccess.file_exists(cfg_path), "sha256":"", "sections":{}}
	if cfg_data.exists:
		cfg_data.sha256 = FileAccess.get_sha256(cfg_path)
		if not _check("CFG read succeeds", cfg.load(cfg_path) == OK): return {"ok":false}
		for section in cfg.get_sections():
			cfg_data.sections[section] = {}
			for key in cfg.get_section_keys(section): cfg_data.sections[section][key] = cfg.get_value(section,key)
		_check("CFG read retains original bytes", FileAccess.get_sha256(cfg_path) == cfg_data.sha256)
	var steam: Node = get_node("/root/SteamService")
	_check("no live SDK or credited session in regression profile", not steam.available and not steam.stats_ready \
		and steam._active_run == 0 and steam._run_counter == 0 and steam._local_runs == null)
	return {"ok":true, "slot_sha256":disk.file_sha256, "slot_generation":disk.document.generation,
		"binding":disk.document.binding.duplicate(true), "lifecycle":_classic_receipt(disk.document.binding.token),
		"cfg":cfg_data, "campaign":{"owner":campaign.cloud_owner, "records":campaign.records.duplicate(true), "unlocked":campaign.unlocked},
		"rewards":{"stats":steam.state.stats.duplicate(true), "unlocked":steam.state.unlocked.duplicate(true), "settled":steam.state.settled.duplicate(true)}}

func _observe_rendered_frame() -> void:
	if not _playing or not is_instance_valid(battle) or get_tree().paused or battle.phase != battle.Phase.FIGHT:
		_perf_previous = 0
		return
	var now := Time.get_ticks_usec()
	if _perf_previous > 0:
		var ms := float(now - _perf_previous) / 1000.0
		_perf_frames.append(ms)
		_perf_elapsed += ms / 1000.0
	_perf_previous = now
	_perf_peak_units = maxi(_perf_peak_units, battle.units.size())
	_perf_peak_memory = maxf(_perf_peak_memory, Performance.get_monitor(Performance.MEMORY_STATIC))
	if _perf_elapsed >= 60.0: _close_performance_window()

func _close_performance_window() -> void:
	if _perf_frames.is_empty(): return
	_perf_frames.sort()
	_perf_windows.append({"seconds":_perf_elapsed, "frames":_perf_frames.size(),
		"fps":float(_perf_frames.size()) / _perf_elapsed,
		"p95_ms":_perf_frames[ceili(_perf_frames.size() * 0.95) - 1],
		"p99_ms":_perf_frames[ceili(_perf_frames.size() * 0.99) - 1],
		"worst_ms":_perf_frames[-1], "peak_units":_perf_peak_units,
		"peak_static_bytes":_perf_peak_memory, "end_wave":battle.level._wave})
	_perf_frames.clear(); _perf_elapsed = 0.0; _perf_peak_units = 0; _perf_peak_memory = 0.0

func _performance_report() -> Dictionary:
	_close_performance_window()
	return {"scope":"rendered normal 30-wave gameplay with command observer; pauses/loading excluded",
		"renderer":RenderingServer.get_current_rendering_method(),
		"windows":_perf_windows, "human_test":false, "hardware_independent_fps_guarantee":false}
