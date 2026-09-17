extends Node
## Nine natural processes at normal time scale in a guarded private profile.
## Actual mission orders, movement, and player ability controls only.
## No actor teleport, stage callback, fixture damage, or direct victory call.
const B := preload("res://scripts/battle.gd")
const Kuai := preload("res://scripts/levels/level7_kuaihuolin_short.gd")
const U := preload("res://scripts/unit.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level7_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const SceneryState := preload("res://scripts/run_scenery_state.gd")
const CASES := ["level7_cross_save", "level7_cross_drill", "level7_cross_fist", "level7_cross_rush", "level7_cross_opening", "level7_cross_subdued", "level7_cross_terms", "level7_cross_finish", "level7_terminal_reject"]
const HANDOFF := "user://level7_handoff.json"
const SLOT_ROOT := "user://level7_continue/v1"
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
var seen_special := -1
var attack_wait := 0.0
var casts := {}
var charge_travel := 0.0
var min_hp := INF
var controller_seconds := 0.0

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
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.to_lower() + "/appdata/")
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL7_RESTORE_QA PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	report_path = OS.get_environment("LSH_LEVEL7_STATE")
	if report_path.is_empty(): report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	mode = OS.get_environment("LSH_LEVEL7_CASE")
	nonce = OS.get_environment("LSH_LEVEL7_NONCE")
	run.call_deferred()


func run() -> void:
	print("KUAI_PROCESS_START ", mode, " pid=", OS.get_process_id())
	if not check("known process case and nonempty nonce", mode in CASES and not nonce.is_empty() and not report_path.is_empty()): finish(); return
	if not check("natural route uses normal time scale", is_equal_approx(Engine.time_scale, 1.0)): finish(); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("trusted runtime identity", trusted.get("ok", false) and trusted.get("save_eligible", false)): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("Kuaihuolin runtime prepared", pack.get("ok", false)): print(pack); finish(); return
	runtime = pack.runtime
	if mode == CASES[0]:
		var b: Node = await _launch()
		if not check("real Kuaihuolin battle launched", is_instance_valid(b)): finish(); return
		await _initial(b)
	else:
		var b: Node = await _restore()
		if mode == CASES[8] or not is_instance_valid(b): finish(); return
		get_tree().paused = false
		match mode:
			"level7_cross_drill": await _drill(b)
			"level7_cross_fist": await _fist(b)
			"level7_cross_rush": await _rush(b)
			"level7_cross_opening": await _opening(b)
			"level7_cross_subdued": await _subdued(b)
			"level7_cross_terms": await _terms(b)
			"level7_cross_finish": await _victory(b)
	finish()


func _launch() -> Node:
	var campaign := get_node("/root/Campaign")
	var flags: Dictionary = Profiles.install_flags(Profiles.KUAI_ID)
	if not check("installed Kuaihuolin launch flags", flags.get("ok", false)): return null
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
	if b == null or b.get_script() != B or b.level.get_script() != Kuai: return null
	b.hud._intro_root.hide(); b.hud.intro_done.emit()
	if b.phase == B.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	b._official_context = Profiles.KUAI_CONTEXT.duplicate(true)
	b._save_barrier.configure(b, b._run_clock, Profiles.KUAI_CONTEXT)
	return b

func _id(unit) -> String:
	return str(unit.entity_id) if is_instance_valid(unit) else ""

func _vec(value: Vector2) -> Variant:
	return [value.x, value.y] if value.is_finite() else "none"


func _state(b: Node) -> Dictionary:
	var l: Variant = b.level
	var result := {"level": {}, "mission": {}, "roles": {}, "units": [], "active": [], "selection": [], "tells": {}, "next_entity_id": str(b.next_entity_id), "next_tick": b._run_clock._next_tick}
	for key in ["drunk", "st", "special_index", "heavy_dodges", "rush_dodges", "controls_generation", "opening_serial", "step_serial", "counter_hits", "boss_on", "dodged", "story_step_primed", "charge_running", "victory", "smoke_t", "fist_cd", "fist_windup", "steady_left", "exposed_left", "special_kind"]: result.level[key] = l.get(key)
	for key in ["fist_at", "drill_origin", "rush_from", "rush_end", "step_origin"]: result.level[key] = _vec(l.get(key))
	for key in ["stage_id", "events", "active_action_id", "_progress", "_retry", "_generation"]:
		var member: Variant = b.mission.get(key)
		result.mission[key] = member.duplicate(true) if member is Dictionary or member is Array else member
	result.mission["actions"] = {}
	for key in b.mission.actions:
		var action: Dictionary = b.mission.actions[key]
		result.mission.actions[key] = {"done": action.done, "duration": action.duration, "cell": [action.cell.x, action.cell.y]}
	for key in ["wu", "shi", "sign", "menshen"]: result.roles[key] = _id(l.get(key))
	result.roles["taverns"] = l.taverns.map(func(row): return {"id": _id(row.u), "drunk": row.drunk})
	for key in ["fist_marker", "drill_marker"]:
		var marker: Variant = l.get(key)
		result.tells[key] = null
		if is_instance_valid(marker):
			result.tells[key] = {"kind": marker.kind, "progress": marker.progress, "extent": marker.extent, "position": _vec(marker.position), "rotation": marker.rotation, "z": marker.z_index, "visible": marker.visible, "height": marker.get_meta("render_height", 0.0), "tell_kind": marker.get_meta("tell_kind", "")}
	for u in b.units_root.get_children():
		var row := {"id": _id(u), "key": u.key, "position": _vec(u.position), "hp": u.hp, "max_hp": u.max_hp, "variant": u.art_variant, "outcome": u.story_outcome, "visible": u.visible, "passive": u.passive, "state": u._state, "target": _id(u._target), "dying": u._dying, "death_time": u._death_t, "abilities": u.ability_slots.duplicate(true), "attack": u.atk, "base_attack": u._base_atk, "stun": u._stun_t, "cast": u._cast_t, "pose": u.get_meta("story_pose", ""), "pose_time": u._story_pose_t, "path": [], "path_index": u._path_i, "order_serial": u._order_serial, "manual_active": u.manual_order_active, "manual_time": u.manual_order_t, "intent_active": u.mission_order_active, "intent_target": _vec(u.mission_order_target), "intent_token": u.mission_order_token}
		for key in ["_drunk_t", "_drunk_lo", "_drunk_hi", "_drunk_reroll", "_drunk_move", "_drunk_atk", "_charge_t", "_charge_dash", "_charge_dmg", "_charge_width", "_charge_slow", "_charge_slow_dur", "_charge_ability_id"]: row[key] = u.get(key)
		row["charge_dir"] = _vec(u._charge_dir)
		row["charge_hit"] = u._charge_hit.map(func(target): return _id(target))
		row["damage_reduction"] = u._damage_reduction_sources.duplicate(true)
		for point in u._path: row.path.append(_vec(point))
		result.units.append(row)
	for u in b.units: result.active.append(_id(u))
	for u in b.selection: result.selection.append(_id(u))
	return JSON.parse_string(JSON.stringify(result))

func _controller() -> Dictionary:
	return {"seen_special": seen_special, "attack_wait": attack_wait, "casts": casts, "charge_travel": charge_travel, "min_hp": min_hp, "seconds": controller_seconds}

func _restore_controller(value: Dictionary) -> void:
	seen_special = int(value.seen_special); attack_wait = float(value.attack_wait)
	casts = value.casts.duplicate(true); charge_travel = float(value.charge_travel)
	min_hp = float(value.min_hp); controller_seconds = float(value.seconds)

func _audit_roles(b: Node) -> void:
	var l: Variant = b.level
	var expected: Array = [l.wu, l.shi]
	for row in l.taverns: expected.append(row.u)
	expected.append(l.menshen); expected.append(l.sign)
	check("all eight original identities survive without replacement", expected.map(func(u): return _id(u)) == lineage.entities and b.units_root.get_child_count() == 8 and b.units.size() == 8 and expected.all(func(u): return is_instance_valid(u) and u.hp > 0.0 and not u._dying and b.units.has(u)))
	check("four tavern flags and attack increments retained", l.taverns.filter(func(row): return row.drunk).size() == l.drunk and l.wu._base_atk == 26.0 + 5.0 * l.drunk)
	check("noncombat companion keeps authored health and combat boundary", l.shi.is_noncombat and l.shi.max_hp == 210.0 and l.shi.atk == 0.0)
	check("installed duel statistics retain original maxima", l.wu.max_hp == 440.0 and l.menshen.max_hp == 800.0)
	if l.st == l.RETURN_SHOP: check("subdued Menshen is living and active", l.menshen.story_outcome == "subdued" and l.menshen.hp > 0.0 and b.units.has(l.menshen) and not l.menshen._dying)
	for field in ["fist_marker", "drill_marker"]:
		var marker: Variant = l.get(field)
		if is_instance_valid(marker): check("installed native tell binds restored FX root " + field, marker.get_script() == Kuai.DuelTell and marker.get_parent() == b.fx_root)


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
		print("KUAI_BARRIER_FAILED ", rejected, " ", b._save_barrier.health()); return
	if mode == "level7_cross_rush":
		var l: Variant = b.level
		if not check("held checkpoint retains actual in-flight rush", l.charge_running and l.menshen._charge_dash > 0.0 and l.menshen.position.distance_to(l.rush_from) > 1.0 and is_instance_valid(l.fist_marker) and l.fist_marker.progress == 1.0): return
	if mode == "level7_cross_opening":
		var l: Variant = b.level
		if not check("held checkpoint retains moved W before E credit", l.exposed_left > 0.6 and l.step_serial == l.opening_serial and l.opening_serial > 0 and l.wu.position.distance_to(l.step_origin) >= 24.0 and l.counter_hits == 0 and not b.mission.has_event("mengzhou_signature")): return
	var saver := Session.new(trusted, runtime, SLOT_ROOT)
	var saved: Dictionary = saver.save_held(b)
	if not check("full Session save succeeds", saved.get("ok", false)): print("KUAI_SAVE_FAILED ", saved); return
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.KUAI_CONTEXT).capture(b.map)
	if not check("trusted Kuaihuolin scenery captured", display.get("ok", false)): print(display); return
	check("chapter-specific scenery schema", display.value.schema == "level7_scenery_state_v1")
	check("Huang adapter rejects Kuaihuolin scenery", not SceneryState.new(trusted.content_version, Profiles.HG_CONTEXT).validate(display.value).ok)
	_audit_roles(b)
	var state := _state(b)
	observations.append({"saved": state})
	var file := FileAccess.open(HANDOFF, FileAccess.WRITE)
	if not check("handoff writable", file != null): return
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "nonce": nonce, "mode": mode,
		"sha256": saved.file_sha256, "state": state, "display": display.value, "lineage": lineage,
		"content_version": trusted.content_version, "controller": _controller()})); file.close()
	await _shot(b, "_saved")
	b.queue_free(); await get_tree().process_frame

func _restore() -> Node:
	var file := FileAccess.open(HANDOFF, FileAccess.READ)
	if not check("previous process handoff exists", file != null): return null
	var decoded = JSON.parse_string(file.get_as_text()); file.close()
	if not check("handoff fields valid", decoded is Dictionary and decoded.has_all(["pid", "nonce", "mode", "sha256", "state", "display", "lineage", "content_version", "controller"])): return null
	handoff = decoded
	lineage = handoff.lineage.duplicate(true)
	_restore_controller(handoff.controller)
	if not check("distinct process identity and nonce", handoff.pid != OS.get_process_id() and handoff.nonce != nonce and not String(handoff.nonce).is_empty()): return null
	var preceding: String = CASES[6] if mode == CASES[8] else CASES[CASES.find(mode) - 1]
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
	if mode == CASES[8]:
		check("victory rejects pre-terminal slot specifically", not prepared.ok and prepared.get("code", "") == "LOCAL_RUN_TERMINAL")
		check("menu retained after terminal refusal", get_tree().current_scene == menu and is_instance_valid(menu))
		observations.append({"terminal_refusal": prepared})
		restored_session.dispose(); return null
	if not check("Session prepare succeeds", prepared.get("ok", false)): print("KUAI_PREPARE_FAILED ", prepared); restored_session.dispose(); return null
	var installed: Dictionary = await restored_session.commit_restore_async()
	if not check("Session commit succeeds", installed.get("ok", false)): print("KUAI_COMMIT_FAILED ", installed); restored_session.dispose(); return null
	var b: Node = installed.battle
	check("restored paused without advancing", get_tree().paused and b.phase == B.Phase.FIGHT and b.level.get_script() == Kuai)
	var actual := _state(b)
	for key in handoff.state:
		if not check("restored " + key + " matches disk", actual.get(key) == handoff.state[key]):
			print("KUAI_STATE_MISMATCH ", key, " saved=", handoff.state[key], " actual=", actual.get(key))
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.KUAI_CONTEXT).capture(b.map)
	check("scenery nodes and materials match disk", display.get("ok", false) and display.value == handoff.display)
	check("restored scenery activated", not b.map.sample_scenery.is_blocking_signals())
	_audit_roles(b)
	observations.append({"restored": actual})
	await _shot(b, "_restored")
	return b


func alive(u: Variant) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
	controller_seconds += seconds

func _until(b: Node, predicate: Callable, limit: float) -> bool:
	var elapsed := 0.0
	while not predicate.call() and b.phase != B.Phase.END and elapsed < limit:
		await _wait(0.05); elapsed += 0.05
	return bool(predicate.call())

func _move(b: Node, actor: Variant, point: Vector2) -> void:
	if not alive(actor): return
	b.select_single(actor, false); b.minimap_order(point, false); orders += 1

func _attack(b: Node) -> void:
	if not alive(b.level.wu) or not alive(b.level.menshen): return
	b.select_single(b.level.wu, false)
	b._issue_order(b.to_screen(b.level.menshen.position), false); orders += 1

func _cast(b: Node, slot: int) -> bool:
	var actor: Variant = b.level.wu
	if not alive(actor) or not actor.slot_ready(slot) or actor._cast_t > 0.0: return false
	b.select_single(actor, false); b._cast_ability_slot(slot)
	await _until(b, func(): return not is_instance_valid(actor) or actor._cast_t <= 0.0, 1.2)
	if is_instance_valid(actor) and not actor.slot_ready(slot):
		casts[str(slot)] = int(casts.get(str(slot), 0)) + 1
		orders += 1
		return true
	return false

func _perform(b: Node, actor: Variant, action_id: String, limit := 75.0) -> bool:
	if not check("authored mission action available " + action_id, alive(actor) and b.mission.actions.has(action_id)):
		return false
	var marker: String = "action:" + b.mission.stage_id + ":" + action_id
	_move(b, actor, b.map.cell_to_world(b.mission.actions[action_id].cell))
	if not check("real original ground intent for " + action_id, actor.mission_order_active): return false
	var completed: bool = await _until(b, func(): return b.mission.has_event(marker), limit)
	if not check("actual walking and interaction complete " + action_id, completed): await _failure(b, action_id)
	return completed

func _initial(b: Node) -> void:
	var l: Variant = b.level
	var entities: Array = [l.wu, l.shi]
	for row in l.taverns: entities.append(row.u)
	entities.append(l.menshen); entities.append(l.sign)
	lineage = {"entities": entities.map(func(u): return _id(u)), "shi_start": _vec(l.shi.position)}
	min_hp = l.wu.hp
	check("current short player-controlled chapter", l.story_contract_version() == 2 and not b._smoke and not b.economy and not b.ai_friendly)
	_move(b, l.shi, b.map.cell_to_world(Vector2i(44, 25)))
	if not await _perform(b, l.wu, "drink_0"): return
	check("first checkpoint keeps unfinished optional road preparation", l.drunk == 1 and l.st == l.ROAD and not b.mission.has_event("road_step_practiced") and not l.victory)
	await _save_next(b)

func _drill(b: Node) -> void:
	for index in [1, 2, 3]:
		if not await _perform(b, b.level.wu, "drink_" + str(index)): return
	if not await _perform(b, b.level.wu, "practice_step"): return
	check("natural four-tavern route reaches active optional practice", b.level.drunk == 4 and b.level.st == b.level.STEP_DRILL and is_instance_valid(b.level.drill_marker) and not b.mission.has_event("road_step_practiced"))
	check("Shi En walked to his safe waiting area", b.level.shi.position.distance_to(b.map.cell_to_world(Vector2i(44, 25))) < 100.0 and b.level.shi.hp == b.level.shi.max_hp)
	await _save_next(b)

func _fist(b: Node) -> void:
	var l: Variant = b.level
	await _cast(b, 1)
	_move(b, l.wu, l.drill_origin + Vector2(0, -130))
	if not check("actual movement completes the restored practice circle", await _until(b, func(): return b.mission.has_event("road_step_practiced"), 12.0)): await _failure(b, "practice_move"); return
	if not await _perform(b, l.wu, "provoke"): return
	if not check("actual duel reaches a live heavy windup", await _duel_until(b, func(): return l.fist_windup > 0.5 and l.special_kind == "heavy", 45.0, false)): await _failure(b, "heavy_tell"); return
	check("first real heavy tell precedes damage or signature credit", is_instance_valid(l.fist_marker) and l.fist_marker.kind == "heavy" and not b.mission.has_event("mengzhou_signature"))
	await _save_next(b)

func _rush(b: Node) -> void:
	var l: Variant = b.level
	var in_flight: Callable = func(): return l.charge_running and l.menshen._charge_dash > 0.0 and l.menshen.position.distance_to(l.rush_from) > 1.0 and is_instance_valid(l.fist_marker) and l.fist_marker.progress == 1.0
	if not check("restored heavy is avoided before an actual in-flight rush", await _duel_until(b, in_flight, 60.0, false, true)): await _failure(b, "rush_in_flight"); return
	check("rush checkpoint is after real movement with completed tell and remaining dash", l.heavy_dodges > 0 and l.special_kind == "rush" and l.fist_windup == 0.0 and l.fist_marker.kind == "rush" and l.menshen.position.distance_to(l.rush_from) > 1.0 and l.menshen._charge_dash > 0.0 and l.fist_marker.progress == 1.0)
	await _save_next(b)

func _opening(b: Node) -> void:
	var l: Variant = b.level
	var prior: Dictionary = handoff.state.level
	var restored_position: Vector2 = l.menshen.position
	var ready: Callable = func(): return l.exposed_left > 0.6 and not l.charge_running and l.step_serial == l.opening_serial and l.opening_serial == int(prior.special_index) and l.wu.position.distance_to(l.step_origin) >= 24.0 and l.counter_hits == 0
	if not check("real W movement reaches a current opening before E", await _duel_until(b, ready, 90.0, false)): await _failure(b, "moved_w_opening"); return
	if not check("both distinct specials really missed before first E", l.heavy_dodges > 0 and l.rush_dodges > 0 and not b.mission.has_event("mengzhou_signature")): await _failure(b, "distinct_dodges"); return
	# The authored rush endpoint is clipped by map collision, so valid movement
	# may be shorter than 100px. Bind completion to the exact saved in-flight
	# special, continued real movement, and its native miss result instead.
	if not check("same restored rush actually moves and finishes without hitting either actor", l.special_index == int(prior.special_index) and l.special_kind == "rush" and l.rush_dodges == int(prior.rush_dodges) + 1 and l.heavy_dodges == int(prior.heavy_dodges) and l.menshen._charge_dash == 0.0 and l.menshen._charge_t == 0.0 and not l.menshen._charge_hit.has(l.wu) and not l.menshen._charge_hit.has(l.shi) and l.menshen.position.distance_to(restored_position) > 1.0): await _failure(b, "restored_rush_completion"); return
	await _save_next(b)

func _subdued(b: Node) -> void:
	var l: Variant = b.level
	if not check("restored opening continues through real player combat to subdual", await _duel_until(b, func(): return l.st == l.RETURN_SHOP and l.menshen.story_outcome == "subdued", 240.0, true)): await _failure(b, "subdual"); return
	check("actual current-window E earns footwork and counter credit", b.mission.has_event("mengzhou_signature") and l.counter_hits > 0 and int(casts.get("2", 0)) > 0)
	check("subdual retains living foe and pending terms", l.menshen.hp > 0.0 and b.units.has(l.menshen) and not l.menshen._dying and not l.victory and not b.mission.has_event("terms"))
	await _save_next(b)

func _terms(b: Node) -> void:
	if not await _perform(b, b.level.wu, "terms"): return
	check("real terms finish before Shi En takes over", b.mission.has_event("terms") and not b.mission.has_event("restore_shop") and not b.level.victory)
	await _save_next(b)

func _victory(b: Node) -> void:
	if not await _perform(b, b.level.shi, "restore_shop"): return
	for frame in range(180):
		if b._continue_receipt != null and b._continue_receipt._committed_terminal and b.hud._end_root.visible: break
		await get_tree().process_frame
	check("real shop takeover reaches a durable terminal result", b.level.victory and b.phase == B.Phase.END and b._continue_receipt != null and b._continue_receipt._committed_terminal and b.hud._end_root.visible)
	check("Wu and Shi survive while Menshen stays subdued", alive(b.level.wu) and alive(b.level.shi) and b.level.menshen.story_outcome == "subdued" and b.level.menshen.hp > 0.0)
	var result: Dictionary = b.mission.result_snapshot(true)
	check("all four story goals earned by the actual natural route", result.story_complete and result.story_done == 4 and result.story_total == 4)
	_audit_roles(b)
	observations.append({"victory": _state(b), "result": result, "controller": _controller()})
	get_tree().paused = true
	await _shot(b, "_victory")
	# Preserve process seven's pre-terminal bytes for the ninth process refusal.
	b.queue_free(); await get_tree().process_frame

func _duel_until(b: Node, predicate: Callable, limit: float, allow_damage: bool, sample_physics := false) -> bool:
	var elapsed := 0.0
	var previous: Vector2 = b.level.menshen.position
	while not predicate.call() and b.phase != B.Phase.END and b.level.st == b.level.SHOWDOWN and elapsed < limit:
		var l: Variant = b.level
		if l.charge_running: charge_travel += previous.distance_to(l.menshen.position)
		previous = l.menshen.position
		min_hp = minf(min_hp, l.wu.hp)
		if l.fist_windup > 0.0 and seen_special != l.special_index:
			seen_special = l.special_index
			await _cast(b, 1)
			var direction: Vector2 = l.rush_from.direction_to(l.rush_end) if l.special_kind == "rush" else l.menshen.position.direction_to(l.wu.position)
			var origin: Vector2 = l.wu.position if l.special_kind == "rush" else l.menshen.position
			var offset: Vector2 = direction.orthogonal() * (110.0 if l.special_kind == "rush" else 86.0)
			var destination: Vector2 = origin + offset
			if not b.map._segment_open(l.wu.position, destination, "land"): destination = origin - offset
			_move(b, l.wu, destination)
		elif l.fist_windup <= 0.0 and not l.charge_running:
			if l.exposed_left > 0.0:
				if allow_damage and l.wu.position.distance_to(l.menshen.position) <= 88.0: await _cast(b, 2)
				elif l.wu._state != l.wu.ST_MOVE: _move(b, l.wu, l.menshen.position + l.menshen.position.direction_to(l.wu.position) * 64.0)
			else:
				if l.wu.hp < l.wu.max_hp - 60.0: await _cast(b, 3)
				if allow_damage and l.wu.position.distance_to(l.menshen.position) < 80.0: await _cast(b, 0)
				if attack_wait <= 0.0:
					if allow_damage: _attack(b)
					elif l.wu._state != l.wu.ST_MOVE: _move(b, l.wu, l.menshen.position + l.menshen.position.direction_to(l.wu.position) * 95.0)
					attack_wait = 0.7
		var delta := 0.05
		if sample_physics:
			# Observe after a completed physics frame; the caller enters the real
			# pause barrier immediately when the live charge predicate is seen.
			await get_tree().physics_frame
			await get_tree().process_frame
			delta = 1.0 / 60.0
			controller_seconds += delta
		else: await _wait(delta)
		elapsed += delta; attack_wait -= delta
	return bool(predicate.call())


func _failure(b: Node, label: String) -> void:
	get_tree().paused = true
	observations.append({"failure": label, "state": _state(b)})
	print("KUAI_ROUTE_FAILED ", label, " state=", _state(b))
	await _shot(b, "_failure")

func _shot(b: Node, suffix: String) -> void:
	var patient: Node = b.level.wu
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
		"chapter": "level7", "full_world": true, "observations": observations, "orders": orders,
		"actor_teleports": 0, "stage_injections": 0, "clock_acceleration": false,
		"previous_pid": handoff.get("pid", 0), "process_nonce": nonce, "lineage": lineage, "controller": _controller(),
		"scope": "real optional four-tavern route, actual practice movement, heavy and rush tells, W movement before E, living subdual, terms and shop takeover; no injected stage or actor position"}
	var file := FileAccess.open(report_path, FileAccess.WRITE) if not report_path.is_empty() else null
	if file == null:
		print("KUAI_REPORT_WRITE_FAILED ", report_path)
		passed = false
	else:
		file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LEVEL7_CROSS_PROCESS_QA_COMPLETE ", mode, " ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
