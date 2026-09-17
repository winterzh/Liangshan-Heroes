extends Node
## Actual menu -> ordinary player commands -> real save/exit -> new process.
## This is an acceptance attempt, not a deterministic victory fixture.
const MenuScene = preload("res://scenes/menu.tscn")
const BattleScript = preload("res://scripts/battle.gd")
const Classic = preload("res://scripts/levels/skirmish.gd")
const Slot = preload("res://scripts/run_slot_store.gd")
const Policy = preload("res://tools/classic30_player_commands.gd")
const LocalLifecycle = preload("res://scripts/run_local_lifecycle.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const InflightObserver = preload("res://tools/classic30_inflight_observer.gd")
const CASES := ["public_gate", "new_economy", "resume_combat", "resume_transition", "resume_victory", "terminal_reject_1", "terminal_reject_2", "diagnostic"]
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	set_process(false)
	_process_started = Time.get_ticks_msec()
	if not _private_profile():
		print("CLASSIC30 PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	var parsed: Variant = _read_json(OS.get_environment("LSH_CLASSIC30_CONTROL"))
	if not parsed is Dictionary or parsed.get("case", "") not in CASES:
		print("CLASSIC30 CONTROL_REQUIRED")
		get_tree().quit(2)
		return
	config = parsed
	var run_root := OS.get_environment("LSH_CLASSIC30_RUN").replace("\\", "/").trim_suffix("/")
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
		if not prior is Dictionary or prior.get("run_id") != config.get("run_id"):
			print("CLASSIC30 PREVIOUS_STATE_REQUIRED")
			get_tree().quit(2)
			return
		state = prior
		_loaded_from_pid = int(state.get("pid", 0))
	else:
		state = {"version": 1, "run_id": config.run_id, "waves": [], "resumes": [], "seen_units": {},
			"action_counts": {}, "constructed": [], "trained": {}, "resource_start": {},
			"max_wave": 0, "fight_origin_tick": 0, "victory": false, "terminal_rejections": [],
			"checkpoints": [], "normal_start": false, "initial_orders_paid": false}
	_events = FileAccess.open(config.events, FileAccess.WRITE)
	if _events == null:
		print("CLASSIC30 EVENT_FILE_REQUIRED")
		get_tree().quit(2)
		return
	flow = get_node("/root/ContinueFlow")
	policy = Policy.new()
	_boot.call_deferred()

func _private_profile() -> bool:
	if not OS.has_feature("editor") or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("LSH_CLASSIC30_QA") != "1": return false
	var profile := OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").trim_suffix("/")
	var run_root := OS.get_environment("LSH_CLASSIC30_RUN").replace("\\", "/").trim_suffix("/")
	if not profile.is_absolute_path() or not run_root.is_absolute_path() or profile.is_empty() or run_root.is_empty(): return false
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
	_check("public entry constant remains false", flow.PLAYER_ENTRY_ENABLED == false)
	_check("default 60 Hz and speed", Engine.physics_ticks_per_second == 60 and get_node("/root/Settings").game_speed == 1.0)
	_check("SDK unavailable in private profile", not get_node("/root/SteamService").available)
	var menu: Node = MenuScene.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	if config.case == "public_gate":
		_check("public continue hidden", not flow.is_enabled() and _named(menu, "ContinueBattle") == null)
		_check("direct public continue refused", flow.request_continue(menu).get("code") == "CONTINUE_NOT_RELEASED")
		_finish("public_gate_verified", true)
		return
	if not _check("isolated continue enabled", flow.is_enabled()): _finish("gate_failure", false); return
	flow.operation_finished.connect(_operation)
	if config.case in ["new_economy", "diagnostic"]:
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
		_received = false
		if not _press(_named(menu, "ContinueBattle"), "continue saved battle"): _finish("continue_button_failure", false); return
		await _wait_operation()
		if String(config.case).begins_with("terminal_reject"):
			var code: String = _result.get("code", "")
			var refused: bool = _received and not _result.get("ok", false) and code in ["RUN_TERMINAL", "LOCAL_RUN_TERMINAL", "CONTINUE_RUN_TERMINAL", "SLOT_TERMINAL"]
			_check("terminal refusal has explicit terminal reason", refused, code)
			_check("terminal refusal retains actual menu", get_tree().current_scene == menu and is_instance_valid(menu))
			_check("terminal refusal cannot activate simulation", get_tree().current_scene.get_script() != BattleScript)
			if refused:
				state.terminal_rejections.append({"case": config.case, "pid": OS.get_process_id(), "code": code})
				_press(_named(flow, "CloseError"), "dismiss terminal refusal")
			_finish("terminal_refused" if refused else "terminal_replay_not_rejected", refused)
			return
		if not _check("continue succeeded", _received and _result.get("ok", false), _result): _finish("restore_failure", false); return
		battle = get_tree().current_scene
		if not _check("restored real classic battle", battle.get_script() == BattleScript): _finish("restore_identity_failure", false); return
		_check("saved pause intent restored", get_tree().paused and battle.hud._pause_root.visible)
		_check("different process after save", _loaded_from_pid > 0 and _loaded_from_pid != OS.get_process_id())
		var differences: Array = []
		_compare(state.snapshot, _snapshot(), "world", differences)
		_check("restored observed gameplay state", differences.is_empty(), differences.slice(0, 30))
		var disk: Dictionary = Slot.new().read_slot()
		_check("read keeps original saved slot", disk.get("ok", false) and disk.get("file_sha256") == state.slot_sha256)
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
	state.snapshot = _snapshot()
	_trigger["held_witness"] = state.snapshot.inflight_witness.duplicate(true)
	if _trigger.kind == "combat":
		_check("actual HELD combat boundary retains in-flight action", int(_trigger.held_witness.get("enemies", 0)) > 0 and int(_trigger.held_witness.get("in_flight", 0)) > 0, _trigger.held_witness)
	state.slot_sha256 = disk.file_sha256
	state.saved_seconds = _seconds()
	state.checkpoints.append(_trigger)
	state.pid = OS.get_process_id()
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
	await get_tree().process_frame
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
	state.settlement_text = {"title": battle.hud._end_title.text, "summary": battle.hud._end_sub.text, "tally": battle.hud._end_tally.text}
	_finish("natural_victory", checks.all(func(row: Dictionary) -> bool: return row.passed))

func _screenshot(stem: String) -> void:
	DirAccess.make_dir_recursive_absolute(config.screenshots)
	var path: String = String(config.screenshots).path_join(String(config.case) + "_" + stem + ".png")
	var screen_image: Image = get_viewport().get_texture().get_image()
	_check("screenshot saved " + stem, screen_image != null and screen_image.save_png(path) == OK)

func _report(outcome: String, passed: bool) -> void:
	var output := {"suite": "classic30-continue-acceptance", "run_id": config.run_id, "case": config.case,
		"pid": OS.get_process_id(), "outcome": outcome, "passed": passed, "checks": checks,
		"summary": _summary(), "state_sha256": FileAccess.get_sha256(config.state), "events_sha256": FileAccess.get_sha256(config.events),
		"seconds_in_process": float(Time.get_ticks_msec() - _process_started) / 1000.0,
		"source_sha256": config.source_sha256, "real_steam": false, "player_entry_enabled": false,
		"manual_player_test": false, "performance_acceptance": false,
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
	state.pid = OS.get_process_id()
	state.last_outcome = outcome
	state.saved_seconds = _seconds()
	_write(config.state, state)
	passed = passed and checks.all(func(row: Dictionary) -> bool: return row.passed)
	_report(outcome, passed)
	if _events != null: _events.close()
	get_node("/root/Sfx").shutdown()
	get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
