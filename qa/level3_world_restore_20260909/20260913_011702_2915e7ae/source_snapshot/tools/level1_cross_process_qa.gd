extends "res://tools/level1_world_restore_qa.gd"
## Six real processes share an isolated slot. No actor teleport, stage injection,
## timer acceleration, or direct mission completion in the live wine route.
const SceneryState := preload("res://scripts/run_scenery_state.gd")
const HuangVisual := preload("res://scripts/run_level1_visual_state.gd")
var runtime: Dictionary = {}
var slot_root := "user://level1_continue/v1"
var mode := ""
var handoff: Dictionary = {}
var observations: Array = []
var orders := 0
var restored_session: RefCounted

func run() -> void:
	mode = OS.get_environment("LSH_LEVEL1_RESTORE_MODE")
	print("HUANG_PROCESS_START ", mode, " pid=", OS.get_process_id())
	trusted = Provider.new().resolve_runtime_identity()
	if not check("trusted runtime identity", trusted.get("save_eligible", false)): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("Huang runtime prepared", pack.ok): finish(); return
	runtime = pack.runtime
	if mode == "level1_cross_save":
		var battle: Node = await _launch()
		if not check("real Huang battle launched", is_instance_valid(battle)): finish(); return
		if not check("partially entered convoy", battle.level.convoy.size() > 0 and battle.level.convoy.size() < 15): finish(); return
		check("wine seller and wine props absent", battle.find_unit("bai_sheng") == null and _wine_count(battle) == 0)
		await _save_next(battle)
	else:
		var battle: Node = await _restore()
		if mode == "level1_terminal_reject": finish(); return
		if not is_instance_valid(battle): finish(); return
		get_tree().paused = false
		match mode:
			"level1_cross_arrival": await _arrival(battle)
			"level1_cross_wine": await _wine(battle)
			"level1_cross_cargo": await _cargo(battle)
			"level1_cross_finish": await _victory(battle)
			_: check("known cross-process mode", false)
	finish()

func _launch() -> Node:
	var campaign := get_node("/root/Campaign")
	for key: String in Profiles.HG_FLAGS: campaign.set(key, Profiles.HG_FLAGS[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	var battle: Node = get_tree().current_scene
	if battle == null or battle.get_script() != B or battle.level.get_script() != Huang: return null
	battle.hud._intro_root.hide(); battle.hud.intro_done.emit()
	if battle.phase == B.Phase.DEPLOY: battle.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	battle._official_context = Profiles.HG_CONTEXT.duplicate(true)
	battle._save_barrier.configure(battle, battle._run_clock, Profiles.HG_CONTEXT)
	return battle

func _on_held(_clock: Dictionary) -> void: held = true
func _on_rejected(code: String) -> void: rejected = code

func _wine_count(b: Node) -> int:
	var count := 0
	for node in b.fx_root.get_children():
		if node.get_meta("campaign_environment_route", "") in ["wine_buckets", "wine_bowls"]: count += 1
	return count

func _state(b: Node) -> Dictionary:
	var value := {"level": {}, "mission": {}, "roles": {}, "units": [], "active": [], "wine_props": _wine_count(b), "cart_count": b.level.jujube_carts.size(), "gold": b.gold, "wood": b.wood}
	for key in ["st", "convoy_entry_t", "rest_t", "exposure", "wine_step", "team_t", "attention_left", "distraction_serial", "clean_trial", "scoop_prepared", "sale_drugged", "drug_done", "delivered", "force_started", "victory"]:
		value.level[key] = b.level.get(key)
	for key in ["stage_id", "events", "active_action_id", "_progress", "_retry", "_generation"]: value.mission[key] = b.mission.get(key).duplicate(true) if b.mission.get(key) is Dictionary else b.mission.get(key)
	value.mission["actions"] = b.mission.actions.keys()
	for key in ["actors", "convoy", "bundles"]: value.roles[key] = b.level.get(key).map(func(u): return str(u.entity_id))
	value.roles["cart"] = str(b.level.cart.entity_id)
	value.roles["yang"] = str(b.level.yang.entity_id)
	value.roles["cargo"] = {}
	for key in b.level.cargo: value.roles.cargo[str(key)] = str(b.level.cargo[key].entity_id)
	for u in b.units_root.get_children():
		value.units.append({"id": str(u.entity_id), "key": u.key, "x": u.position.x, "y": u.position.y, "hp": u.hp,
			"outcome": u.story_outcome, "visible": u.visible, "wine": u.get_meta("carrying_wine", false), "tribute": u.get_meta("carrying_tribute", -1)})
	for u in b.units: value.active.append(str(u.entity_id))
	# Normalize engine numeric types exactly as the on-disk handoff will be read.
	return JSON.parse_string(JSON.stringify(value))

func _write_handoff(value: Dictionary) -> void:
	var file := FileAccess.open("user://level1_handoff.json", FileAccess.WRITE)
	if not check("handoff writable", file != null): return
	file.store_string(JSON.stringify(value)); file.close()

func _save_next(b: Node) -> void:
	if not b._save_barrier.capture_ready.is_connected(_on_held): b._save_barrier.capture_ready.connect(_on_held)
	if not b._save_barrier.capture_rejected.is_connected(_on_rejected): b._save_barrier.capture_rejected.connect(_on_rejected)
	var saved: Dictionary = await _pause_save(b, runtime, slot_root)
	if not check("full Session save succeeds", saved.get("ok", false)):
		print("SAVE_FAILED ", saved); return
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.HG_CONTEXT).capture(b.map)
	if not check("trusted Huang scenery captured", display.ok): print(display); return
	check("chapter-specific scenery schema", display.value.schema == "level1_scenery_state_v1")
	check("Zhu adapter rejects Huang display", not SceneryState.new(trusted.content_version, Profiles.ZHU_CONTEXT).validate(display.value).ok)
	var bad: Dictionary = display.value.duplicate(true)
	bad.context.level_id = "level3"
	check("tampered chapter context rejected", not SceneryState.new(trusted.content_version, Profiles.HG_CONTEXT).validate(bad).ok)
	var state := _state(b)
	_audit_props(b)
	if not b.level.cargo.is_empty(): _audit_cargo_slot(b)
	observations.append({"saved": state})
	_write_handoff({"pid": OS.get_process_id(), "nonce": OS.get_environment("LSH_WORLD_RESTORE_NONCE"), "mode": mode, "sha256": saved.file_sha256, "state": state, "display": display.value, "content_version": trusted.content_version})
	await _shot(b)
	b.queue_free(); await get_tree().process_frame

func _restore() -> Node:
	var file := FileAccess.open("user://level1_handoff.json", FileAccess.READ)
	if not check("previous process handoff exists", file != null): return null
	handoff = JSON.parse_string(file.get_as_text()); file.close()
	check("new process identity", handoff.nonce != OS.get_environment("LSH_WORLD_RESTORE_NONCE"))
	var sequence := ["level1_cross_save", "level1_cross_arrival", "level1_cross_wine", "level1_cross_cargo", "level1_cross_finish", "level1_terminal_reject"]
	check("correct preceding checkpoint", handoff.mode == sequence[sequence.find(mode) - 1] if mode != "level1_terminal_reject" else handoff.mode == "level1_cross_cargo")
	check("same frozen production version", handoff.content_version == trusted.content_version)
	var slot: Dictionary = Store.new(slot_root).read_slot()
	if not check("same saved slot bytes", slot.ok and slot.file_sha256 == handoff.sha256): return null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	restored_session = Session.new(trusted, runtime, slot_root)
	var prepared: Dictionary = restored_session.prepare_restore(menu)
	if mode == "level1_terminal_reject":
		check("victory rejects pre-terminal slot", not prepared.ok and String(prepared.get("code", "")).begins_with("LOCAL_"))
		check("menu retained after terminal refusal", get_tree().current_scene == menu and is_instance_valid(menu))
		restored_session.dispose(); return null
	if not check("Session prepare succeeds", prepared.ok): print("PREPARE_FAILED ", prepared); restored_session.dispose(); return null
	var installed: Dictionary = await restored_session.commit_restore_async()
	if not check("Session commit succeeds", installed.ok): print("COMMIT_FAILED ", installed); restored_session.dispose(); return null
	var b: Node = installed.battle
	check("restored paused without advancing", get_tree().paused and b.phase == B.Phase.FIGHT)
	var actual := _state(b)
	for key in handoff.state:
		if not check("restored " + key + " matches disk", actual[key] == handoff.state[key]):
			print("STATE_MISMATCH ", key, " saved=", handoff.state[key], " actual=", actual[key])
	var display: Dictionary = SceneryState.new(trusted.content_version, Profiles.HG_CONTEXT).capture(b.map)
	check("scenery nodes material heights match disk", display.ok and display.value == handoff.display)
	check("scenery activated", not b.map.sample_scenery.is_blocking_signals())
	check("cart alias preserved", b.level.cart == b.level.bundles[0])
	observations.append({"restored": actual})
	await _shot(b)
	return b

func _until(b: Node, predicate: Callable, seconds: float) -> bool:
	var start: int = b._run_clock._next_tick
	var deadline: int = Time.get_ticks_msec() + int(maxf(seconds * 3.0, 30.0) * 1000.0)
	while not predicate.call() and b.phase == B.Phase.FIGHT and (b._run_clock._next_tick - start) / 60.0 < seconds and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return bool(predicate.call())

func _move(b: Node, members: Array, cell: Vector2i) -> void:
	b.select_members(members, false)
	b.minimap_order(b.map.cell_to_world(cell), false)
	orders += 1

func _order_action(b: Node, unit: Node, id: String) -> bool:
	if not check("available action " + id, is_instance_valid(unit) and b.mission.actions.has(id)): return false
	_move(b, [unit], b.mission.actions[id].cell)
	print("HUANG_ORDER ", id, " actor=", unit.key, " intent=", unit.mission_order_active, " target=", unit.mission_order_target)
	return check("action order resolves to real ground movement " + id, unit.mission_order_active and unit.mission_order_token > 0)

func _action(b: Node, unit: Node, id: String, seconds := 40.0) -> bool:
	var event: String = "action:%s:%s" % [b.mission.stage_id, id]
	if not _order_action(b, unit, id): return false
	var completed := await _until(b, func(): return b.mission.has_event(event), seconds)
	if not check("actual move and action completed " + id, completed):
		print("ACTION_FAILED ", id, " stage=", b.level.st, " mission=", b.mission.stage_id, " actor=", unit.position, " exposure=", b.level.exposure, " action=", b.mission.actions.get(id), " cargo=", b.level.cargo, " intent=", unit.mission_order_active, " target=", unit.mission_order_target, " unit_state=", unit._state)
	else: print("HUANG_ACTION_COMPLETE ", id)
	return completed

func _arrival(b: Node) -> void:
	var l = b.level
	if not check("restored column reaches inquiry", await _until(b, func(): return b.mission.has_event("yang_inquired"), 80)): return
	check("exact fifteen convoy members after remaining entries", l.convoy.size() == 15 and l.convoy.filter(func(u): return u.key == "jun_han").size() == 11)
	if not await _action(b, b.find_unit("liu_tang"), "answer_yang"): return
	var bai = b.find_unit("bai_sheng")
	if not check("Bai appears once after answer", is_instance_valid(bai) and l.actors.size() == 8): return
	var start: Vector2 = bai.position
	if not _order_action(b, bai, "bring_wine"): return
	if not check("Bai actually travels carrying wine", await _until(b, func(): return bai.position.distance_to(start) > 120, 15)): return
	check("saved before unloading", l.st == l.ARRIVAL and bai.get_meta("carrying_wine", false) and _wine_count(b) == 0)
	await _save_next(b)

func _wine(b: Node) -> void:
	var l = b.level
	if not check("restored Bai finishes original unloading order", await _until(b, func(): return b.mission.has_event("bai_unloaded"), 50)): return
	check("one barrel and one bowl prop", _wine_count(b) == 2 and l.actors.size() == 8 and l.jujube_carts.size() == 7)
	_move(b, [b.find_unit("wu_yong")], l.WU_STATION)
	_move(b, [b.find_unit("bai_sheng")], l.BAI_STATION)
	if not await _action(b, b.find_unit("liu_tang"), "taste_wine"): return
	if not check("wine partners at actual stations", await _until(b, func(): return l._team_ready(b), 20)): return
	if not await _action(b, b.find_unit("liu_tang"), "distract_yang"): return
	if not check("nonempty cooperative timer", await _until(b, func(): return l.team_t >= 0.5, 5) and l.team_t < 3.0 and not l.drug_done): return
	await _save_next(b)

func _cargo(b: Node) -> void:
	var l = b.level
	if not check("restored handoff timer finishes wine scheme", await _until(b, func(): return l.drug_done, 8)): return
	check("fifteen alive unconscious guards and zero kills", l.convoy.size() == 15 and l.convoy.all(func(u): return u.hp > 0 and u.story_outcome == "unconscious") and b.kills == 0)
	if not await _action(b, b.find_unit("liu_tang"), "force_take_0_0"): return
	check("load is carried by same actor", l.cargo.get(0) == b.find_unit("liu_tang") and l.cargo[0].get_meta("carrying_tribute", -1) == 0)
	check("original load inactive and hidden", not b.units.has(l.bundles[0]) and not l.bundles[0].visible)
	if not _order_action(b, b.find_unit("liu_tang"), "force_deliver_0_0"): return
	var origin: Vector2 = b.find_unit("liu_tang").position
	if not check("loaded actor moves toward exit", await _until(b, func(): return b.find_unit("liu_tang").position.distance_to(origin) > 80, 8)): return
	await _save_next(b)

func _victory(b: Node) -> void:
	var l = b.level
	if not check("restored carrier completes first delivery", await _until(b, func(): return l.delivered == 1, 50)): return
	for index in [1, 2]:
		var carrier = b.find_unit("ruan_xiaowu" if index == 1 else "ruan_xiaoqi")
		if not await _action(b, carrier, "force_take_%d_0" % index): return
		if not await _action(b, carrier, "force_deliver_%d_0" % index, 55): return
	check("three original loads delivered once", l.delivered == 3 and l.cargo.is_empty() and l.bundles.all(func(u): return b.units.has(u) and u.visible))
	_move(b, l.actors, l.GATE_W)
	if not check("actual survivors reach victory", await _until(b, func(): return l.victory, 55)): return
	check("eight survive and no duplicate props", l.actors.size() == 8 and l.convoy.size() == 15 and _wine_count(b) == 2)
	check("all wine story goals earned", b.mission.result_snapshot(true).story_complete)
	check("terminal lifecycle exists", b._continue_receipt != null)
	# Leave the prior carried-load slot intact for a sixth process to reject.
	await _shot(b)
	b.queue_free(); await get_tree().process_frame

func _shot(b: Node) -> void:
	var path := report_path.get_basename() + ("_saved" if held else "_restored") + ".png"
	b.center_camera_cell(b.level.SALE_WINE if b.level.st in [b.level.ARRIVAL, b.level.WINE] else b.level.TOP)
	b.camera.force_update_scroll()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if b.phase == B.Phase.FIGHT:
		check("restored selection controls bottom panel", b.hud._bottom_collapsed == b.selection.is_empty())
		if b.hud.msg_box.visible:
			check("paused messages remain above command panel", b.hud.msg_box.get_global_rect().end.y <= b.hud._bottom_panel.get_global_rect().position.y - 6.0)
	check("actual viewport screenshot", get_viewport().get_texture().get_image().save_png(path) == OK)

func _audit_props(b: Node) -> void:
	var cart: Node2D = b.level.jujube_carts[0]
	check("installed cart node supported", HuangVisual.node_supported(cart))
	cart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	check("unrecorded texture filter rejected", not HuangVisual.node_supported(cart))
	cart.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	cart.add_to_group("restore_negative_fixture")
	check("unrecorded group rejected", not HuangVisual.node_supported(cart))
	cart.remove_from_group("restore_negative_fixture")
	cart.child_order_changed.connect(cart.queue_redraw)
	check("foreign signal callback rejected", not HuangVisual.node_supported(cart))
	cart.child_order_changed.disconnect(cart.queue_redraw)
	var sign_node: Node = b.level.field_signs[0]
	Localize.language_changed.disconnect(sign_node._on_language_changed)
	check("missing language callback rejected", not HuangVisual.node_supported(sign_node))
	Localize.language_changed.connect(sign_node._on_language_changed)
	check("original props restored after negative checks", HuangVisual.node_supported(cart) and HuangVisual.node_supported(sign_node))

func _audit_cargo_slot(b: Node) -> void:
	var slot: Dictionary = Store.new(slot_root).read_slot()
	if not check("carried slot available for negative validation", slot.ok): return
	var s: Dictionary = slot.document.world.sections
	var graph := UnitGraph.new(UnitState, Identity, Codec, U, Inventory, B, M, Profiles.HG_CONTEXT)
	var tokens := {}
	var by_node: Dictionary = HuangVisual.tokens(b.level)
	for node in by_node: tokens[by_node[node]] = true
	var mission_token: String = slot.document.world.profile.mission_token
	var version: String = trusted.content_version
	check("carried graph baseline validates", graph.validate(s.units, version, s.level, mission_token, tokens).ok)
	var bad: Dictionary = s.units.duplicate(true)
	bad.active_order.append(str(b.level.bundles[0].entity_id))
	check("hidden carried bundle cannot enter active order", graph.validate(bad, version, s.level, mission_token, tokens).get("code") == "LEVEL1_CARRIED_MEMBERSHIP")
	bad = s.units.duplicate(true)
	for row in bad.records:
		if row.entity_id != str(b.find_unit("wu_yong").entity_id): continue
		var payload: Dictionary = Codec.new().decode(row.payload).value
		payload.metadata.carrying_tribute = {"kind": "value", "value": 0}
		row.payload = Codec.new().encode(payload).value
	check("orphan carrier metadata rejected", graph.validate(bad, version, s.level, mission_token, tokens).get("code") == "LEVEL1_ORPHAN_CARRIER")
	var bad_level: Dictionary = s.level.duplicate(true)
	var level_payload: Dictionary = Codec.new().decode(bad_level.payload).value
	level_payload.references.cargo[0] = str(b.level.yang.entity_id)
	bad_level.payload = Codec.new().encode(level_payload).value
	check("convoy member cannot become cargo carrier", graph.validate(s.units, version, bad_level, mission_token, tokens).get("code") == "LEVEL1_CARRIER_REFERENCE")

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(c): return c.passed)
	var report := {"passed": passed, "checks": checks, "pid": OS.get_process_id(), "mode": mode,
		"chapter": "level1", "full_world": true, "observations": observations, "orders": orders,
		"actor_teleports": 0, "stage_injections": 0, "previous_pid": handoff.get("pid", 0), "process_nonce": OS.get_environment("LSH_WORLD_RESTORE_NONCE")}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LEVEL1_CROSS_PROCESS_QA_COMPLETE ", mode, " ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
