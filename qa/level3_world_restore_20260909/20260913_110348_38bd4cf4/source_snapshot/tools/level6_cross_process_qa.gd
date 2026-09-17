extends Node
## Seven isolated real processes follow the installed south route. All travel
## comes from player minimap orders; no actor teleport, stage injection, direct
## action completion, fixture combat or accelerated clock is used here.
const B := preload("res://scripts/battle.gd")
const Yezhu := preload("res://scripts/levels/level6_yezhulin.gd")
const U := preload("res://scripts/unit.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level6_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const SceneryState := preload("res://scripts/run_scenery_state.gd")
const CASES := ["level6_cross_save", "level6_cross_rescue", "level6_cross_care",
	"level6_cross_escort", "level6_cross_leave", "level6_cross_finish", "level6_terminal_reject"]
const HANDOFF := "user://level6_handoff.json"
const SLOT_ROOT := "user://level6_continue/v1"

var checks: Array = []
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var mode := ""
var report_path := ""
var nonce := ""
var handoff: Dictionary = {}
var lineage: Dictionary = {}
var observations: Array = []
var orders := 0
var held := false
var rejected := ""
var restored_session: RefCounted

func check(label: String, passed: bool) -> bool:
	checks.append({"label": label, "passed": passed})
	if not passed: print("FAIL ", label)
	return passed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("LSH_LEVEL3_RESTORE_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL6_RESTORE_QA PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	report_path = OS.get_environment("LSH_LEVEL6_STATE")
	if report_path.is_empty(): report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	mode = OS.get_environment("LSH_LEVEL6_CASE")
	nonce = OS.get_environment("LSH_LEVEL6_NONCE")
	run.call_deferred()

func run() -> void:
	print("YEZHU_PROCESS_START ", mode, " pid=", OS.get_process_id())
	if not check("known process case and nonempty nonce", mode in CASES and not nonce.is_empty() and not report_path.is_empty()): finish(); return
	if not check("natural route uses normal time scale", is_equal_approx(Engine.time_scale, 1.0)): finish(); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("trusted runtime identity", trusted.get("ok", false) and trusted.get("save_eligible", false)): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("Yezhulin runtime prepared", pack.get("ok", false)): print(pack); finish(); return
	runtime = pack.runtime
	if mode == CASES[0]:
		var battle: Node = await _launch()
		if not check("real Yezhulin battle launched", is_instance_valid(battle)): finish(); return
		await _stalk(battle)
	else:
		var battle: Node = await _restore()
		if mode == CASES[6] or not is_instance_valid(battle): finish(); return
		get_tree().paused = false
		match mode:
			"level6_cross_rescue": await _rescue(battle)
			"level6_cross_care": await _care(battle)
			"level6_cross_escort": await _escort(battle)
			"level6_cross_leave": await _leave(battle)
			"level6_cross_finish": await _victory(battle)
	finish()

func _launch() -> Node:
	var campaign := get_node("/root/Campaign")
	var flags: Dictionary = Profiles.install_flags(Profiles.YEZHU_ID)
	if not check("installed Yezhulin launch flags", flags.get("ok", false)): return null
	for key: String in flags.flags: campaign.set(key, flags.flags[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	var b: Node = get_tree().current_scene
	if b == null or b.get_script() != B or b.level.get_script() != Yezhu: return null
	b.hud._intro_root.hide(); b.hud.intro_done.emit()
	if b.phase == B.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	b._official_context = Profiles.YEZHU_CONTEXT.duplicate(true)
	b._save_barrier.configure(b, b._run_clock, Profiles.YEZHU_CONTEXT)
	return b

func _id(unit) -> String:
	return str(unit.entity_id) if is_instance_valid(unit) else ""

func _vec(value: Vector2) -> Variant:
	return [value.x, value.y] if value.is_finite() else "none"

func _state(b: Node) -> Dictionary:
	var value := {"level": {}, "mission": {}, "roles": {}, "units": [], "active": [], "selection": [],
		"gold": b.gold, "wood": b.wood, "kills": b.kills, "next_entity_id": str(b.next_entity_id), "next_tick": b._run_clock._next_tick}
	for key in ["st", "exec_timer", "rescued", "alarm", "wave_t", "wave_n", "smoke_t", "tracking_done", "treated",
		"shadow_route", "shadow_attention", "shadow_cautioned", "shadow_warning", "care_t", "rest_reached",
		"escort_player_token", "player_control_guard_fired", "help_t", "victory"]:
		value.level[key] = b.level.get(key)
	value.level.escort_player_target = _vec(b.level.escort_player_target)
	value.level.escort_orders = {}
	for key in b.level.escort_orders: value.level.escort_orders[str(key)] = b.level.escort_orders[key]
	for key in ["stage_id", "events", "active_action_id", "_progress", "_retry", "_generation"]:
		var member = b.mission.get(key)
		value.mission[key] = member.duplicate(true) if member is Dictionary or member is Array else member
	value.mission.actions = {}
	for key in b.mission.actions:
		var action: Dictionary = b.mission.actions[key]
		value.mission.actions[key] = {"done": action.done, "duration": action.duration, "cell": [action.cell.x, action.cell.y]}
	for key in ["lu", "lin_bound", "lin_freed"]: value.roles[key] = _id(b.level.get(key))
	value.roles.escorts = b.level.escorts.map(func(u): return _id(u))
	for unit in b.units_root.get_children():
		var row := {"id": _id(unit), "key": unit.key, "position": _vec(unit.position), "hp": unit.hp, "max_hp": unit.max_hp,
			"faction": unit.faction, "outcome": unit.story_outcome, "variant": unit.art_variant, "visible": unit.visible,
			"passive": unit.passive, "noncombat": unit.is_noncombat, "state": unit._state, "serial": unit._order_serial,
			"path_index": unit._path_i, "path": [], "intent_active": unit.mission_order_active,
			"intent_token": unit.mission_order_token, "intent_target": _vec(unit.mission_order_target),
			"manual_active": unit.manual_order_active, "manual_time": unit.manual_order_t,
			"pose": unit.get_meta("story_pose", ""), "pose_time": unit._story_pose_t, "stun_time": unit._stun_t,
			"speed_multiplier": unit.temp_speed, "speed_duration": unit._temp_speed_t,
			"assist_partner": _id(unit.story_assist_partner), "assist_owner": _id(unit.story_assist_owner)}
		for point in unit._path: row.path.append(_vec(point))
		value.units.append(row)
	for unit in b.units: value.active.append(_id(unit))
	for unit in b.selection: value.selection.append(_id(unit))
	return JSON.parse_string(JSON.stringify(value))

func _audit_roles(b: Node) -> void:
	var ids: Array = b.units_root.get_children().map(func(u): return _id(u))
	var unique := {}
	for id in ids: unique[id] = true
	check("four actual entities without duplicate IDs", ids.size() == 4 and ids.size() == unique.size() and b.units.size() == 4)
	check("original Lu and two guards retained", _id(b.level.lu) == lineage.lu and b.level.escorts.map(func(u): return _id(u)) == lineage.escorts)
	check("both original guards alive", b.level.escorts.size() == 2 and b.level.escorts.all(func(u): return is_instance_valid(u) and u.hp > 0 and u.story_outcome == ""))
	if b.level.st == b.level.STALK:
		check("original prisoner still escorted", _id(b.level.lin_freed) == lineage.original_lin and not is_instance_valid(b.level.lin_bound))
	elif not is_instance_valid(b.level.lin_freed):
		check("prisoner replaced by one real bound Lin", _id(b.level.lin_bound) == lineage.bound_lin and not ids.has(lineage.original_lin) and b.level.lin_bound.key == "lin_chong_bound")
	else:
		check("both obsolete prisoner entities removed", not ids.has(lineage.original_lin) and not ids.has(lineage.bound_lin) and not is_instance_valid(b.level.lin_bound))
		check("freed Lin has new identity and escort appearance", _id(b.level.lin_freed) == lineage.escort_lin and b.level.lin_freed.art_variant == "lin_chong_escort")
	check("natural route did not inject combat or phantom reinforcements", b.kills == 0 and not b.mission.has_event("yezhulin_early_force") and not b.mission.has_event("yezhulin_escort_lost") and b.level.wave_n == 0)

func _on_held(_clock: Dictionary) -> void: held = true
func _on_rejected(code: String) -> void: rejected = code

func _save_next(b: Node) -> void:
	if not b._save_barrier.capture_ready.is_connected(_on_held): b._save_barrier.capture_ready.connect(_on_held)
	if not b._save_barrier.capture_rejected.is_connected(_on_rejected): b._save_barrier.capture_rejected.connect(_on_rejected)
	held = false; rejected = ""
	get_tree().paused = true
	var requested: Dictionary = b._save_barrier.request_capture()
	if not check("real pause capture requested", requested.get("ok", false)): print(requested); return
	for frame in range(180):
		await get_tree().process_frame
		if held or not rejected.is_empty(): break
	if not check("save barrier held healthy", held and rejected.is_empty() and b._save_barrier.state == b._save_barrier.State.HELD and b._save_barrier.health().ok):
		print("YEZHU_BARRIER_FAILED ", rejected, " ", b._save_barrier.health()); return
	var saver := Session.new(trusted, runtime, SLOT_ROOT)
	var saved: Dictionary = saver.save_held(b)
	if not check("full Session save succeeds", saved.get("ok", false)): print("YEZHU_SAVE_FAILED ", saved); return
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.YEZHU_CONTEXT).capture(b.map)
	if not check("trusted Yezhulin scenery captured", display.get("ok", false)): print(display); return
	check("chapter-specific scenery schema", display.value.schema == "level6_scenery_state_v1")
	check("Huang adapter rejects Yezhulin scenery", not SceneryState.new(trusted.content_version, Profiles.HG_CONTEXT).validate(display.value).ok)
	_audit_roles(b)
	var state := _state(b)
	observations.append({"saved": state})
	var file := FileAccess.open(HANDOFF, FileAccess.WRITE)
	if not check("handoff writable", file != null): return
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "nonce": nonce, "mode": mode,
		"sha256": saved.file_sha256, "state": state, "display": display.value, "lineage": lineage,
		"content_version": trusted.content_version})); file.close()
	await _shot(b, "_saved")
	b.queue_free(); await get_tree().process_frame

func _restore() -> Node:
	var file := FileAccess.open(HANDOFF, FileAccess.READ)
	if not check("previous process handoff exists", file != null): return null
	var decoded = JSON.parse_string(file.get_as_text()); file.close()
	if not check("handoff fields valid", decoded is Dictionary and decoded.has_all(["pid", "nonce", "mode", "sha256", "state", "display", "lineage", "content_version"])): return null
	handoff = decoded
	lineage = handoff.lineage.duplicate(true)
	if not check("distinct process identity and nonce", handoff.pid != OS.get_process_id() and handoff.nonce != nonce and not String(handoff.nonce).is_empty()): return null
	var preceding: String = CASES[4] if mode == CASES[6] else CASES[CASES.find(mode) - 1]
	if not check("correct preceding checkpoint", handoff.mode == preceding): return null
	if not check("same frozen production version", handoff.content_version == trusted.content_version): return null
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("same saved slot bytes", slot.get("ok", false) and slot.file_sha256 == handoff.sha256): return null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	restored_session = Session.new(trusted, runtime, SLOT_ROOT)
	var prepared: Dictionary = restored_session.prepare_restore(menu)
	if mode == CASES[6]:
		check("victory rejects pre-terminal slot specifically", not prepared.ok and prepared.get("code", "") == "LOCAL_RUN_TERMINAL")
		check("menu retained after terminal refusal", get_tree().current_scene == menu and is_instance_valid(menu))
		observations.append({"terminal_refusal": prepared})
		restored_session.dispose(); return null
	if not check("Session prepare succeeds", prepared.get("ok", false)): print("YEZHU_PREPARE_FAILED ", prepared); restored_session.dispose(); return null
	var installed: Dictionary = await restored_session.commit_restore_async()
	if not check("Session commit succeeds", installed.get("ok", false)): print("YEZHU_COMMIT_FAILED ", installed); restored_session.dispose(); return null
	var b: Node = installed.battle
	check("restored paused without advancing", get_tree().paused and b.phase == B.Phase.FIGHT and b.level.get_script() == Yezhu)
	var actual := _state(b)
	for key in handoff.state:
		if not check("restored " + key + " matches disk", actual.get(key) == handoff.state[key]):
			print("YEZHU_STATE_MISMATCH ", key, " saved=", handoff.state[key], " actual=", actual.get(key))
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.YEZHU_CONTEXT).capture(b.map)
	check("scenery nodes and materials match disk", display.get("ok", false) and display.value == handoff.display)
	check("restored scenery activated", not b.map.sample_scenery.is_blocking_signals())
	_audit_roles(b)
	observations.append({"restored": actual})
	await _shot(b, "_restored")
	return b

func _until(b: Node, predicate: Callable, seconds: float) -> bool:
	var start: int = b._run_clock._next_tick
	var deadline: int = Time.get_ticks_msec() + int(maxf(seconds * 3.0, 30.0) * 1000.0)
	while not predicate.call() and b.phase == B.Phase.FIGHT and (b._run_clock._next_tick - start) / 60.0 < seconds and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return bool(predicate.call())

func _move(b: Node, actor: Node, cell: Vector2i) -> bool:
	b.select_members([actor], false)
	b.minimap_order(b.map.cell_to_world(cell), false)
	orders += 1
	print("YEZHU_ORDER ", actor.key, " cell=", cell, " active=", actor.mission_order_active, " target=", actor.mission_order_target)
	return check("actual ground order accepted for " + actor.key, actor.mission_order_active and actor.mission_order_token > 0 and actor.mission_order_target.distance_to(b.map.cell_to_world(cell)) < 0.01)

func _order_action(b: Node, actor: Node, action_id: String) -> bool:
	if not check("actual action available " + action_id, is_instance_valid(actor) and b.mission.actions.has(action_id)): return false
	return _move(b, actor, b.mission.actions[action_id].cell)

func _stalk(b: Node) -> void:
	var l = b.level
	if not check("actual chapter has four actors and no smoke driver", l.st == l.STALK and b.units.size() == 4 and not b._smoke and not b.economy): return
	lineage = {"lu": _id(l.lu), "escorts": l.escorts.map(func(u): return _id(u)), "original_lin": _id(l.lin_freed), "bound_lin": "", "escort_lin": ""}
	var lu_start: Vector2 = l.lu.position
	var lin_start: Vector2 = l.lin_freed.position
	if not _move(b, l.lu, Vector2i(34, 25)): return
	if not check("both shadowing actors actually move", await _until(b, func(): return is_instance_valid(l.lin_freed) and l.lu.position.distance_to(lu_start) > 80 and l.lin_freed.position.distance_to(lin_start) > 60, 8)): return
	if not check("saved in ongoing shadow route", l.st == l.STALK and not l.tracking_done and not l.lu._path.is_empty() and not l.lin_freed._path.is_empty()): return
	await _save_next(b)

func _rescue(b: Node) -> void:
	var l = b.level
	if not check("restored escort naturally reaches pine checkpoint", await _until(b, func(): return l.st == l.RESCUE, 30)): await _failure(b, "pine_checkpoint"); return
	lineage.bound_lin = _id(l.lin_bound)
	check("actual southern shadow route earned", l.shadow_route == "south_reeds" and b.mission.has_event("shadow_route_chosen") and b.mission.has_event("observe"))
	check("original guards still threatening before rescue", l.escorts.all(func(u): return u.faction == U.FACTION_GUAN and u.hp == u.max_hp))
	if not _order_action(b, l.lu, "intercept"): return
	if not check("actual intercept progress begins before deadline", await _until(b, func(): return b.mission.active_action_id == "intercept" and b.mission._progress >= 0.2, 25)): await _failure(b, "intercept_start"); return
	if not check("saved partial intercept with running deadline", l.st == l.RESCUE and not l.rescued and l.exec_timer > 0 and l.exec_timer < l.EXEC_TIME and b.mission._progress < 0.8): return
	await _save_next(b)

func _care(b: Node) -> void:
	var l = b.level
	if not check("restored original intercept command completes", await _until(b, func(): return l.st == l.CARE and l.care_t >= 0.35, 5)): await _failure(b, "intercept_resume"); return
	if not check("mercy scene retains bound patient and nonzero care timer", is_instance_valid(l.lin_bound) and not is_instance_valid(l.lin_freed) and l.care_t < 1.8 and b.mission.stage_id == "mercy" and l.rescued): return
	check("Lu actually emerges with saved intercept pose", String(l.lu.get_meta("story_pose", "")) == "intercept" and l.lu._story_pose_t > 0)
	check("both guards spared and stunned in place", l.escorts.all(func(u): return u.hp == u.max_hp and u.faction == U.FACTION_LIANG and u.is_noncombat and u._stun_t > 0))
	check("Lin plea and real intercept event present", b.mission.has_event("intercept") and b.mission.has_event("action:intercept:intercept") and b.hud.msg_box.visible)
	await _save_next(b)

func _escort(b: Node) -> void:
	var l = b.level
	if not check("restored care naturally unties and tends Lin", await _until(b, func(): return l.st == l.ESCAPE and l.treated, 9)): await _failure(b, "care_resume"); return
	lineage.escort_lin = _id(l.lin_freed)
	check("both automatic care events earned", b.mission.has_event("untie") and b.mission.has_event("tend_feet") and not l.rest_reached)
	check("wounded escort Lin cannot fight", l.lin_freed.is_noncombat and l.lin_freed.atk == 0 and l.lin_freed.aura == "")
	var before: Array = l._escort_group().map(func(u): return u.position)
	var tick: int = b._run_clock._next_tick
	if not check("care leaves a real wait for player input", await _until(b, func(): return b._run_clock._next_tick - tick >= 60, 2) and range(4).all(func(i): return l._escort_group()[i].position.distance_to(before[i]) < 3)): return
	var origin: Vector2 = l.lin_freed.position
	if not _order_action(b, l.lin_freed, "rest_stop"): return
	if not check("four-person escort actually departs for rest", await _until(b, func(): return l.lin_freed.position.distance_to(origin) > 100, 10)): await _failure(b, "escort_departure"); return
	if not check("saved authorized escort before rest", not l.rest_reached and l.escort_orders.size() == 4 and l.escort_player_token > 0 and l._escort_group().all(func(u): return u.mission_order_token == l.escort_player_token and not u._path.is_empty())): return
	await _save_next(b)

func _leave(b: Node) -> void:
	var l = b.level
	# The production rest action can ask for a fresh click if companions arrive
	# later. Honor that request only after all four physically reach its radius.
	var retries := 0
	var started: int = b._run_clock._next_tick
	var last_retry: int = started
	var deadline: int = Time.get_ticks_msec() + 150000
	while not l.rest_reached and b.phase == B.Phase.FIGHT and (b._run_clock._next_tick - started) / 60.0 < 50 and Time.get_ticks_msec() < deadline:
		if retries < 3 and b._run_clock._next_tick - last_retry >= 120 and b.mission.active_action_id == "" and not b.mission.actions.rest_stop.done and l._survivors_near(b.map.cell_to_world(l.REST), 96):
			if not _order_action(b, l.lin_freed, "rest_stop"): return
			retries += 1; last_retry = b._run_clock._next_tick
		await get_tree().process_frame
	if not check("restored original route reaches real four-person rest", l.rest_reached): await _failure(b, "rest_resume"); return
	check("rest and spare-guards story credit earned", b.mission.has_event("rest_stop") and b.mission.has_event("warn_escorts") and l._survivors_near(b.map.cell_to_world(l.REST), 96))
	observations.append({"rest_retries": retries, "rest": _state(b)})
	var origin: Vector2 = l.lin_freed.position
	if not _order_action(b, l.lin_freed, "leave_forest"): return
	if not check("four actors travel on separate exit command", await _until(b, func(): return l.lin_freed.position.distance_to(origin) > 100, 10)): await _failure(b, "leave_departure"); return
	if not check("saved exit convoy before terminal", l.rest_reached and not l.victory and not b.mission.has_event("leave_forest") and l.escort_orders.size() == 4 and l._escort_group().all(func(u): return u.mission_order_token == l.escort_player_token and not u._path.is_empty())): return
	await _save_next(b)

func _victory(b: Node) -> void:
	var l = b.level
	if not check("restored original exit command reaches victory", await _until(b, func(): return l.victory, 65)): await _failure(b, "exit_resume"); return
	# The level sets victory during physics; durable local closure and the end
	# panel are produced by ContinueFlow on a subsequent real process frame.
	for frame in range(180):
		if b._continue_receipt != null and b._continue_receipt._committed_terminal and b.hud._end_root.visible: break
		await get_tree().process_frame
	if not check("durable terminal lifecycle precedes real result panel", b._continue_receipt != null and b._continue_receipt._committed_terminal and b.hud._end_root.visible): await _failure(b, "terminal_commit"); return
	check("four actual survivors reach the exit", l._escort_group().size() == 4 and l._survivors_near(b.map.cell_to_world(l.EXIT_W), l.EXIT_R) and l.lin_freed.position.distance_to(b.map.cell_to_world(l.EXIT_W)) < l.EXIT_R)
	check("real exit and all-four events earned", b.mission.has_event("leave_forest") and b.mission.has_event("yezhulin_four_left") and b.mission.has_event("yezhulin_victory"))
	_audit_roles(b)
	var result: Dictionary = b.mission.result_snapshot(true)
	check("all three story goals earned", result.story_complete and result.story_done == 3 and result.story_total == 3)
	check("terminal phase and local lifecycle retained", b.phase == B.Phase.END and b._continue_receipt != null)
	observations.append({"victory": _state(b), "result": result})
	# Keep the preceding in-transit slot and its handoff for process seven.
	await _shot(b, "_victory")
	b.queue_free(); await get_tree().process_frame

func _failure(b: Node, label: String) -> void:
	observations.append({"failure": label, "state": _state(b)})
	print("YEZHU_ROUTE_FAILED ", label, " state=", _state(b))
	await _shot(b, "_failure")

func _shot(b: Node, suffix: String) -> void:
	var patient: Node = b.level.lin_freed if is_instance_valid(b.level.lin_freed) else b.level.lin_bound
	if is_instance_valid(patient): b.center_camera_cell(b.map.world_to_cell(patient.position))
	b.camera.force_update_scroll()
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	if b.phase == B.Phase.FIGHT:
		check("selection controls restored command panel", b.hud._bottom_collapsed == b.selection.is_empty())
		if b.hud.msg_box.visible: check("paused message stays above command panel", b.hud.msg_box.get_global_rect().end.y <= b.hud._bottom_panel.get_global_rect().position.y - 6.0)
	check("native viewport screenshot " + suffix, get_viewport().get_texture().get_image().save_png(report_path.get_basename() + suffix + ".png") == OK)

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(c): return c.passed)
	var report := {"passed": passed, "checks": checks, "pid": OS.get_process_id(), "mode": mode,
		"chapter": "level6", "full_world": true, "observations": observations, "orders": orders,
		"actor_teleports": 0, "stage_injections": 0, "clock_acceleration": false,
		"previous_pid": handoff.get("pid", 0), "process_nonce": nonce, "lineage": lineage,
		"scope": "actual south shadow, intercept, mercy, care and four-person escort across isolated processes; no invented reinforcement route"}
	var file := FileAccess.open(report_path, FileAccess.WRITE) if not report_path.is_empty() else null
	if file == null:
		print("YEZHU_REPORT_WRITE_FAILED ", report_path)
		passed = false
	else:
		file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LEVEL6_CROSS_PROCESS_QA_COMPLETE ", mode, " ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
