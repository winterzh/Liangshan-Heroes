extends Node
## Explicit component fixtures, separate from the natural seven-process route.
## Position/stage setup exercises real replacement, resolution and death callbacks.
const B := preload("res://scripts/battle.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Yezhu := preload("res://scripts/levels/level6_yezhulin.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level6_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Core := preload("res://scripts/run_battle_world_core.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const UnitGraph := preload("res://scripts/run_unit_graph.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const Scenery := preload("res://scripts/run_scenery_state.gd")
var checks: Array = []
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var report_path := ""
var held := false
var rejected := ""
var observations: Array = []
var restored_session: RefCounted
var codec := Codec.new()

func check(label: String, passed: bool) -> bool:
	checks.append({"label": label, "passed": passed})
	if not passed: print("FAIL ", label)
	return passed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("LSH_LEVEL3_RESTORE_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.to_lower() + "/appdata/")
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL6_COMPONENT PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	run.call_deferred()

func run() -> void:
	trusted = Provider.new().resolve_runtime_identity()
	if not check("trusted content identity", trusted.get("save_eligible", false)): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("installed Yezhulin runtime", pack.ok and Profiles._installed(Profiles.YEZHU_ID)): finish(); return
	runtime = pack.runtime
	check("runtime does not deploy or change art", not pack.deploy_or_start_called and not pack.global_art_changed)
	check("uninstalled chapter still rejected", not Profiles.select_context({"mode": "campaign", "level_id": "level4", "waves": 0}, trusted).ok)
	var b: Node = await _launch()
	if not is_instance_valid(b): finish(); return
	b = await _roundtrip(b, "stalk")
	if not is_instance_valid(b): finish(); return
	var old_lin: int = b.level.lin_freed.entity_id
	# Early-force fixture: position the existing actors in a safe clearing, then
	# use actual resolution callbacks. No reward or completed chapter is injected.
	var l: Variant = b.level
	l.lin_freed.order_stop(); l.lin_freed.position = b.map.cell_to_world(l.PINE)
	l.lu.order_stop(); l.lu.position = l.lin_freed.position + Vector2(45, 0)
	for index in range(2):
		l.escorts[index].order_stop()
		l.escorts[index].position = l.lin_freed.position + Vector2(-45, -35 if index == 0 else 35)
	for u in b.units: b.map.sync_render_position(u)
	l.escorts[0].resolve_story("subdued")
	l.escorts[1].resolve_story("subdued")
	await get_tree().process_frame
	if not check("early-force callback replaces walking Lin with bound Lin", l.st == l.CARE and l.lin_freed == null and is_instance_valid(l.lin_bound) and l.lin_bound.entity_id != old_lin and b.mission.has_event("yezhulin_early_force")): finish(); return
	check("subdued guards remain active", l.escorts.all(func(u): return u.story_outcome == "subdued" and b.units.has(u)))
	b = await _roundtrip(b, "subdued")
	if not is_instance_valid(b): finish(); return
	l = b.level
	var bound_id: int = l.lin_bound.entity_id
	l.process(b, 1.9)
	await get_tree().process_frame
	if not check("real untie callback creates third Lin identity", l.lin_bound == null and is_instance_valid(l.lin_freed) and l.lin_freed.entity_id not in [old_lin, bound_id] and b.mission.has_event("untie")): finish(); return
	check("replaced Lin nodes drained", b.units_root.get_children().all(func(u): return u.entity_id not in [old_lin, bound_id]))
	b = await _roundtrip(b, "untied")
	if not is_instance_valid(b): finish(); return
	l = b.level
	l.process(b, 2.5)
	await get_tree().process_frame
	if not check("real care callback rehabilitates subdued guards", l.st == l.ESCAPE and l.treated and l.escorts.all(func(u): return u.story_outcome == "" and u.faction == U.FACTION_LIANG and u.is_noncombat)): finish(); return
	b.select_members([l.lin_freed], false)
	b.minimap_order(b.map.cell_to_world(l.REST), false)
	l.process(b, 0.0)
	check("player escort order adopted for all four actors", l.escort_player_token > 0 and l.escort_orders.size() == 4 and l._escort_group().all(func(u): return u.mission_order_token == l.escort_player_token))
	b = await _roundtrip(b, "escort")
	if not is_instance_valid(b): finish(); return
	l = b.level
	var guard: Variant = l.escorts[0]
	var guard_id: int = guard.entity_id
	# Existing short-test death fixture: ordinary hits subdue escorts. Clearing
	# their defeat outcome here is explicit fault setup, not natural gameplay.
	guard.defeat_outcome = ""
	guard.take_damage(10000.0, null, false, true)
	check("death fixture uses real callback and keeps dying node", guard.hp == 0.0 and guard._dying and not b.units.has(guard) and guard.get_parent() == b.units_root and b.mission.has_event("yezhulin_escort_lost"))
	b = await _roundtrip(b, "dying_guard")
	if not is_instance_valid(b): finish(); return
	l = b.level; guard = l.escorts[0]
	# Advance the real death-strip process explicitly while the component stays
	# paused, so the separate stale-order-reference boundary is deterministic.
	guard._physics_process(U.DEATH_DUR + 0.1)
	await get_tree().process_frame
	check("expired guard leaves historical order key", not is_instance_valid(l.escorts[0]) and l.escort_orders.has(guard_id))
	check("expired fixture retains stale shadow before capture", not b.world.get_node("WorldShadowBatch").retained_dying_units.is_empty())
	b = await _roundtrip(b, "expired_guard")
	if is_instance_valid(b):
		check("three survivors retain player control after restore", b.level._escort_group().size() == 3 and b.level.escort_orders.has(guard_id))
		b.queue_free(); await get_tree().process_frame
	finish()

func _launch() -> Node:
	var campaign := get_node("/root/Campaign")
	for key in Profiles.YEZHU_FLAGS: campaign.set(key, Profiles.YEZHU_FLAGS[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	var b: Node = get_tree().current_scene
	if not check("actual Yezhulin scene launched", b != null and b.get_script() == B and b.level.get_script() == Yezhu): return null
	b.hud._intro_root.hide(); b.hud.intro_done.emit()
	if b.phase == B.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	b._official_context = Profiles.YEZHU_CONTEXT.duplicate(true)
	b._save_barrier.configure(b, b._run_clock, Profiles.YEZHU_CONTEXT)
	get_tree().paused = true
	return b

func _on_held(_value: Dictionary) -> void: held = true
func _on_rejected(value: String) -> void: rejected = value

func _state(b: Node) -> Dictionary:
	var id_to_unit := {}; var ids := {}; var units: Array = []
	for u in b.units_root.get_children(true):
		ids[u] = str(u.entity_id); id_to_unit[str(u.entity_id)] = u
		var path: Array = []
		for point in u._path: path.append(point)
		units.append([u.entity_id, u.key, u.position, u.hp, u._dying, u._death_t, u.faction, u.story_outcome, u.art_variant, u._story_pose_t, u._pose_previous_variant, u.mission_order_token, null if u.mission_order_target == Vector2.INF else u.mission_order_target, u._order_serial, u._group_cap, path, u.manual_order_active])
	var level: Dictionary = LevelState.new().capture(b.level, "level6", trusted.content_version, id_to_unit, b.next_entity_id, {}, {"mission_token": "mission:level6:core", "deferred_drained": true})
	check("component state Level capture", level.ok)
	var state := {"level": level.get("record", {}), "units": units, "active": b.units.map(func(u): return str(u.entity_id)), "selection": b.selection.map(func(u): return str(u.entity_id)), "mission": [b.mission.stage_id, b.mission.events.duplicate(true), b.mission.active_action_id, b.mission._progress, b.mission._retry, b.mission._generation]}
	var packed: Dictionary = codec.encode(state)
	check("component state codec", packed.ok)
	return packed

func _roundtrip(b: Node, label: String) -> Node:
	print("LEVEL6_COMPONENT_ROUNDTRIP ", label)
	# Separate local-only slots prevent fixture mutations from changing a prior
	# receipt's scope or overwriting the route's checkpoints.
	var slot_root := "user://level6_component_" + label + "/v1"
	b._continue_receipt = null
	held = false; rejected = ""
	b._save_barrier.capture_ready.connect(_on_held, CONNECT_ONE_SHOT)
	b._save_barrier.capture_rejected.connect(_on_rejected, CONNECT_ONE_SHOT)
	var requested: Dictionary = b._save_barrier.request_capture()
	if not check(label + " capture request", requested.ok): return null
	for frame in range(180):
		await get_tree().process_frame
		if held or rejected != "": break
	if not check(label + " held boundary", held and rejected == "" and b._save_barrier.health().ok): print("BARRIER ", rejected); return null
	var before := _state(b)
	if not before.ok: return null
	var source_buttons: Array = []
	for candidate in b.mission._buttons.get_children():
		source_buttons.append(candidate.get_meta("campaign_presentation_v1", {}).duplicate(true))
	if label == "expired_guard":
		check("capture boundary prunes expired shadow reference", b.world.get_node("WorldShadowBatch").retained_dying_units.is_empty())
	var scenery: Dictionary = Scenery.new(trusted.content_version, Profiles.YEZHU_CONTEXT).capture(b.map)
	if not check(label + " scenery captured", scenery.ok): print(scenery); return null
	var session := Session.new(trusted, runtime, slot_root)
	var saved: Dictionary = session.save_held(b)
	if not check(label + " actual Session save", saved.ok): print("SAVE ", saved); return null
	var read: Dictionary = Store.new(slot_root).read_slot()
	if not check(label + " closed slot readable", read.ok): return null
	check(label + " slot exact official context", read.document.context == Profiles.YEZHU_CONTEXT and read.document.world.profile.id == Profiles.YEZHU_ID)
	if label in ["stalk", "subdued", "escort", "dying_guard"]: _negative_graph(read.document.world, label)
	b.queue_free(); await get_tree().process_frame
	if restored_session != null: restored_session.dispose(); restored_session = null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	restored_session = Session.new(trusted, runtime, slot_root)
	var prepared: Dictionary = restored_session.prepare_restore(menu)
	if not check(label + " private Session prepare", prepared.ok): print("PREPARE ", prepared); return null
	var committed: Dictionary = await restored_session.commit_restore_async()
	if not check(label + " actual Session install", committed.ok): print("INSTALL ", committed); return null
	var restored: Node = committed.battle
	var after := _state(restored)
	check(label + " recorded gameplay state equal while paused", get_tree().paused and after.ok and before == after)
	var after_scenery: Dictionary = Scenery.new(trusted.content_version, Profiles.YEZHU_CONTEXT).capture(restored.map)
	check(label + " native marsh scenery equal", after_scenery.ok and after_scenery.value == scenery.value)
	check(label + " slot not rewritten on read", Store.new(slot_root).read_slot().file_sha256 == read.file_sha256)
	var restored_buttons: Array = []
	for candidate in restored.mission._buttons.get_children():
		var descriptor: Variant = candidate.get_meta("campaign_presentation_v1", {})
		restored_buttons.append(descriptor)
	check(label + " fixed selection buttons match source stage", restored_buttons == source_buttons)
	if label == "untied": check("care interval has no selection button", restored_buttons.is_empty())
	for candidate in restored.mission._buttons.get_children():
		var descriptor: Dictionary = candidate.get_meta("campaign_presentation_v1", {})
		if descriptor.get("kind") != "level": continue
		var button_id: String = descriptor.get("button_id", "")
		if check(label + " only installed selection callback", button_id in ["pine_group", "pine_lu"]):
			candidate.pressed.emit()
			check(label + " fixed callback selects current live identities", restored.selection == (restored.level._escort_group() if button_id == "pine_group" else [restored.level.lu]))
	if label == "expired_guard":
		check("restored shadow excludes expired guard", restored.world.get_node("WorldShadowBatch").retained_dying_units.is_empty())
	observations.append({"fixture": label, "slot_sha256": read.file_sha256, "entities": restored.units_root.get_children().map(func(u): return {"id": u.entity_id, "key": u.key, "dying": u._dying})})
	return restored

func _graph() -> RefCounted:
	return UnitGraph.new(UnitState, Identity, Codec, U, Inventory, B, M, Profiles.YEZHU_CONTEXT)

func _reject_graph(world: Dictionary, label: String) -> void:
	var result: Dictionary = _graph().validate(world.sections.units, trusted.content_version, world.sections.level, world.profile.mission_token)
	check(label, result.get("ok") == false and result.get("code", "") != "")

func _negative_graph(world: Dictionary, fixture: String) -> void:
	if fixture == "stalk":
		var root_payload: Dictionary = codec.decode(world.sections.root.payload)
		if check("root negative payload decoded", root_payload.ok):
			root_payload.value.values.economy = true
			var root_encoded: Dictionary = codec.encode(root_payload.value)
			if check("root economy negative encoded", root_encoded.ok):
				var root_record: Dictionary = world.sections.root.duplicate(true)
				root_record.payload = root_encoded.value
				var known := {}
				for id in world.sections.units.root_order: known[id] = true
				var identity := Identity.new(U)
				identity.declare_entities(known)
				var core := Core.new(trusted, runtime, {}, null, Profiles.YEZHU_CONTEXT)
				var rejected_root: Dictionary = core._root_state(identity).validate(root_record, trusted.content_version, known)
				check("Yezhulin economy loop injection rejected", not rejected_root.ok and rejected_root.get("code") == "LEVEL6_ECONOMY_UNSUPPORTED")
				identity.dispose(); core.dispose()
	var level_result: Dictionary = codec.decode(world.sections.level.payload)
	if not check(fixture + " negative setup decodes Level", level_result.ok): return
	var refs: Dictionary = level_result.value.references
	var bad := world.duplicate(true)
	bad.sections.units.schema = "level1_unit_graph_v1"
	_reject_graph(bad, fixture + " foreign graph schema rejected")
	for field in ["lin_bound", "lin_freed"]:
		var value: Dictionary = level_result.value.duplicate(true)
		value.references[field] = null if value.references[field] != null else refs.lu
		var encoded: Dictionary = codec.encode(value)
		if not check(fixture + " encode malformed " + field, encoded.ok): continue
		bad = world.duplicate(true); bad.sections.level.payload = encoded.value
		_reject_graph(bad, fixture + " missing or wrong Lin role rejected " + field)
	var value: Dictionary = level_result.value.duplicate(true)
	value.references.escorts.reverse()
	var encoded: Dictionary = codec.encode(value)
	if check(fixture + " encode swapped guards", encoded.ok):
		bad = world.duplicate(true); bad.sections.level.payload = encoded.value
		_reject_graph(bad, fixture + " guard roles cannot swap")
	bad = world.duplicate(true)
	var guard_id: String = refs.escorts[0]
	if fixture == "dying_guard": bad.sections.units.active_order.append(guard_id)
	else: bad.sections.units.active_order.erase(guard_id)
	_reject_graph(bad, fixture + " active membership rejected")
	var unit_index: int = world.sections.units.root_order.find(refs.lu)
	var unit_decoded: Dictionary = codec.decode(world.sections.units.records[unit_index].payload)
	if check(fixture + " decode Lu negative", unit_decoded.ok):
		for bad_pose in [[], "foreign_pose"]:
			var payload: Dictionary = unit_decoded.value.duplicate(true)
			payload.metadata["story_pose"] = {"kind": "value", "value": bad_pose}
			encoded = codec.encode(payload)
			if not check(fixture + " encode pose " + str(typeof(bad_pose)), encoded.ok): continue
			bad = world.duplicate(true); bad.sections.units.records[unit_index].payload = encoded.value
			_reject_graph(bad, fixture + " invalid pose rejected " + str(typeof(bad_pose)))

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row): return row.passed)
	var report := {"mode": "level6_component", "chapter": "level6", "passed": passed, "checks": checks, "pid": OS.get_process_id(), "process_nonce": OS.get_environment("LSH_LEVEL6_NONCE"), "fixture": true, "natural_route": false, "observations": observations, "real_steam": false}
	if report_path != "":
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LEVEL6_COMPONENT_COMPLETE ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
