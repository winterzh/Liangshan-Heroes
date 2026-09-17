extends Node
## Installed Level7 adapter checks with fixed forest_wu / forest_shi controls.
## Explicit component fixtures. Positioning, callback and death advancement below
## are fault/stage setup; they are not evidence of the natural player route.
const B := preload("res://scripts/battle.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Kuai := preload("res://scripts/levels/level7_kuaihuolin_short.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level7_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const UnitGraph := preload("res://scripts/run_unit_graph.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const Scenery := preload("res://scripts/run_scenery_state.gd")
const TellState := preload("res://scripts/run_level7_visual_state.gd")
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
		print("LEVEL7_COMPONENT PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	report_path = OS.get_environment("LSH_LEVEL7_STATE")
	if report_path.is_empty(): report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	run.call_deferred()


func run() -> void:
	trusted = Provider.new().resolve_runtime_identity()
	if not check("trusted content identity", trusted.get("save_eligible", false)): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("installed Kuaihuolin runtime", pack.get("ok", false) and Profiles._installed(Profiles.KUAI_ID)): finish(); return
	runtime = pack.runtime
	check("runtime does not deploy or change art", not pack.deploy_or_start_called and not pack.global_art_changed)
	check("uninstalled chapter still rejected", not Profiles.select_context({"mode": "campaign", "level_id": "level4", "waves": 0}, trusted).ok)
	var b: Node = await _launch()
	if not is_instance_valid(b): finish(); return
	b = await _roundtrip(b, "road")
	if not is_instance_valid(b): finish(); return
	# Explicit ability fixture resets only the current actor's cast lock/cooldown,
	# then runs the same Battle resolver and deferred hit callback as the game.
	await _cast_fixture(b, 3)
	check("real R before any tavern creates finite steady wine", b.level.drunk == 0 and b.level.steady_left == 5.0 and b.level.wu._drunk_lo == 1.0 and b.level.wu._drunk_hi == 1.0)
	b = await _roundtrip(b, "sober_steady")
	if not is_instance_valid(b): finish(); return
	b.level.process(b, b.level.steady_left + 0.01)
	check("real steady expiry at zero drinks creates legal persistent wine", b.level.drunk == 0 and b.level.steady_left == 0.0 and b.level.wu._drunk_t == 999.0 and b.level.wu._drunk_lo == 1.0 and b.level.wu._drunk_hi == 1.08)
	b = await _roundtrip(b, "sober_expired")
	if not is_instance_valid(b): finish(); return
	await _cast_fixture(b, 3)
	# Task callbacks are explicit component stage fixtures, not a natural route.
	b.level.on_mission_action(b, "drink_3", b.level.shi)
	check("wrong actor cannot consume a tavern", b.level.drunk == 0)
	b.level.on_mission_action(b, "drink_3", b.level.wu)
	check("drinking during R keeps its timer with the actual wine profile", b.level.drunk == 1 and b.level.steady_left > 0.0 and b.level.wu._drunk_lo == 0.91 and b.level.wu._drunk_hi == 1.08)
	b.level.on_mission_action(b, "drink_3", b.level.wu)
	check("repeat tavern callback does not replay attack or drink credit", b.level.drunk == 1 and b.level.wu._base_atk == 31.0)
	b = await _roundtrip(b, "steady_then_drink")
	if not is_instance_valid(b): finish(); return
	for index in [0, 1, 2]: b.level.on_mission_action(b, "drink_" + str(index), b.level.wu)
	check("all four actual tavern callbacks retain separate flags and attack", b.level.drunk == 4 and b.level.taverns.all(func(row): return row.drunk) and b.level.wu._base_atk == 46.0)
	b.level.process(b, b.level.steady_left + 0.01)
	b = await _roundtrip(b, "four_taverns")
	if not is_instance_valid(b): finish(); return
	await _cast_fixture(b, 3)
	check("real R after four drinks stabilizes both multipliers", b.level.steady_left == 5.0 and b.level.wu._drunk_lo == 1.0 and b.level.wu._drunk_hi == 1.0)
	b = await _roundtrip(b, "four_steady")
	if not is_instance_valid(b): finish(); return
	b.level.process(b, b.level.steady_left + 0.01)
	b.level.on_mission_action(b, "practice_step", b.level.wu)
	check("real practice callback creates the short DuelTell", b.level.st == b.level.STEP_DRILL and is_instance_valid(b.level.drill_marker) and b.level.drill_marker.get_script() == Kuai.DuelTell)
	b = await _roundtrip(b, "drill_tell")
	if not is_instance_valid(b): finish(); return
	# Position injection is deliberately confined to this component fixture.
	b.level.wu.position = b.level.drill_origin + Vector2(100, 0)
	b.level.process(b, 0.01)
	await get_tree().process_frame
	check("actual practice predicate consumes the marker after movement", b.level.st == b.level.ROAD and not is_instance_valid(b.level.drill_marker) and b.mission.has_event("road_step_practiced"))
	b.level.on_mission_action(b, "provoke", b.level.wu)
	b.level.menshen.position = Vector2(1600, 640)
	b.level.wu.position = Vector2(1680, 640)
	b.level._begin_special(b)
	b.level._duel_tick(b, 0.4)
	check("real heavy windup has partial native tell and untimed pose", b.level.special_kind == "heavy" and b.level.fist_windup > 0.0 and b.level.fist_marker.progress > 0.0 and b.level.fist_marker.progress < 1.0 and b.level.menshen.get_meta("story_pose") == "windup" and b.level.menshen._story_pose_t == 0.0)
	b = await _roundtrip(b, "heavy_windup")
	if not is_instance_valid(b): finish(); return
	b.level.wu.position = b.level.fist_at + Vector2(0, 130)
	b.level._duel_tick(b, b.level.fist_windup + 0.01)
	await get_tree().process_frame
	check("actual missed heavy creates a finite unbraced opening", b.level.exposed_left > 0.0 and b.level.opening_serial == b.level.special_index and not b.level.menshen._damage_reduction_sources.has(b.level.BRACE_SOURCE))
	b.level.wu.position = b.level.menshen.position + Vector2(60, 0)
	await _cast_fixture(b, 1)
	b.level.wu.position += Vector2(0, 32)
	check("real W attribution plus explicit fixture movement awaits E", b.level.step_serial == b.level.opening_serial and b.level.wu.position.distance_to(b.level.step_origin) >= 24.0 and b.level.counter_hits == 0 and not b.mission.has_event("mengzhou_signature"))
	b = await _roundtrip(b, "moved_w_before_e")
	if not is_instance_valid(b): finish(); return
	var before_hp: float = b.level.menshen.hp
	await _cast_fixture(b, 2)
	check("restored W opening gives signature only after actual E damage", b.level.menshen.hp < before_hp and b.level.counter_hits == 1 and b.mission.has_event("mengzhou_signature") and b.level.step_serial == -1)
	b = await _roundtrip(b, "verified_counter")
	if not is_instance_valid(b): finish(); return
	var counter_count: int = b.level.counter_hits
	for frame in range(3): await get_tree().process_frame
	check("restore does not replay the drained deferred hit verifier", b.level.counter_hits == counter_count)
	b.level._duel_tick(b, b.level.exposed_left + 0.01)
	check("actual opening expiry clears both serials and restores guard", b.level.opening_serial == -1 and b.level.step_serial == -1 and b.level.exposed_left == 0.0 and b.level.menshen._damage_reduction_sources.has(b.level.BRACE_SOURCE))
	# Keep all captive structures at authored positions. Place the duel pair so
	# the production charge sweep really records the existing sign as a target.
	b.level.menshen.position = b.level.sign.position - Vector2(90, 0)
	b.level.wu.position = b.level.sign.position + Vector2(40, 0)
	b.level._begin_special(b)
	b.level._duel_tick(b, 0.3)
	check("second real special is a partial rush windup", b.level.special_index == 2 and b.level.special_kind == "rush" and b.level.fist_windup > 0.0 and b.level.fist_marker.kind == "rush" and b.level.menshen.get_meta("story_pose") == "rush_windup")
	b = await _roundtrip(b, "rush_windup")
	if not is_instance_valid(b): finish(); return
	b.level.wu.position += Vector2(0, 130)
	b.level._duel_tick(b, b.level.fist_windup + 0.01)
	b.level.menshen._do_charge_step(0.08)
	check("real charge is in flight with its completed tell and captive hit reference", b.level.charge_running and b.level.menshen._charge_dash > 0.0 and b.level.fist_marker.progress == 1.0 and b.level.menshen._charge_hit.has(b.level.sign) and not b.level.menshen._charge_hit.has(b.level.wu) and b.level.sign.hp > 0.0)
	b = await _roundtrip(b, "charge_hit_sign")
	if not is_instance_valid(b): finish(); return
	check("restored charge hit points to the restored sign object", b.level.menshen._charge_hit.count(b.level.sign) == 1)
	for frame in range(60):
		if b.level.menshen._charge_dash > 0.0: b.level.menshen._do_charge_step(1.0 / 60.0)
	b.level._duel_tick(b, 0.01)
	await get_tree().process_frame
	check("actual charge completion keeps sign hit history and opens missed-hero window", not b.level.charge_running and b.level.rush_dodges == 1 and b.level.exposed_left > 0.0 and b.level.menshen._charge_hit.count(b.level.sign) == 1 and not is_instance_valid(b.level.fist_marker))
	b.level.menshen.resolve_story("subdued")
	await get_tree().process_frame
	check("actual nonlethal resolution retains living active Menshen", b.level.st == b.level.RETURN_SHOP and b.level.menshen.story_outcome == "subdued" and b.level.menshen.hp > 0.0 and not b.level.menshen._dying and b.units.has(b.level.menshen) and b.level.menshen.get_parent() == b.units_root and not b.level.victory and not b.mission.has_event("terms"))
	b = await _roundtrip(b, "subdued_alive")
	if not is_instance_valid(b): finish(); return
	# Explicit presentation fixture: the real grid pass performs off-screen
	# visibility culling. Never assign Unit.visible or fabricate a dead outcome.
	b._lite_fx = true
	b.center_camera_cell(Vector2i(0, 0))
	b.camera.force_update_scroll()
	b._grid_build()
	check("real visibility budget can hide a living subdued actor", not b.level.menshen.visible and b.level.menshen.hp > 0.0 and b.units.has(b.level.menshen))
	b = await _roundtrip(b, "subdued_offscreen")
	if not is_instance_valid(b): finish(); return
	check("restored culled subdued actor retains its actual hidden presentation", not b.level.menshen.visible and b.level.menshen.story_outcome == "subdued")
	b.level.on_mission_action(b, "restore_shop", b.level.wu)
	check("wrong takeover actor cannot finish the chapter", not b.level.victory and b.phase == B.Phase.FIGHT)
	b.level.on_mission_action(b, "terms", b.level.wu)
	check("real terms callback leaves a pending shop takeover", b.mission.has_event("terms") and not b.mission.has_event("restore_shop") and not b.level.victory and b.phase == B.Phase.FIGHT)
	b = await _roundtrip(b, "terms_before_shop")
	if not is_instance_valid(b): finish(); return
	await _discard(b)
	# Essential hero death is terminal, not a supported recoverable living graph.
	for role in ["wu", "shi"]:
		b = await _launch()
		if not is_instance_valid(b): finish(); return
		b.level.get(role).take_damage(100000.0, null, true)
		check(role + " actual death ends the chapter without victory", b.phase == B.Phase.END and not b.level.victory and b.level.get(role)._dying)
		var request: Dictionary = b._save_barrier.request_capture()
		check(role + " real capture gate refuses the terminal phase", not request.get("ok", true) and request.get("code") == "CLASSIC_FIGHT_REQUIRED")
		var denied: Dictionary = Session.new(trusted, runtime, "user://level7_component_dead_" + role + "/v1").save_held(b)
		check(role + " terminal death cannot create a complete continuation slot", not denied.get("ok", true) and not Store.new("user://level7_component_dead_" + role + "/v1").read_slot().ok)
		observations.append({"death_fixture": role, "save_result": denied})
		await _discard(b)
	finish()

func _cast_fixture(b: Node, slot: int) -> void:
	var actor: Variant = b.level.wu
	actor._stun_t = 0.0; actor._cast_t = 0.0
	actor.ability_slots[slot]["cd_t"] = 0.0
	b._do_ability(actor, slot, actor.position)
	await get_tree().process_frame

func _discard(b: Node) -> void:
	if is_instance_valid(b): b.queue_free(); await get_tree().process_frame
	if restored_session != null: restored_session.dispose(); restored_session = null


func _launch() -> Node:
	get_tree().paused = false
	var campaign := get_node("/root/Campaign")
	for key in Profiles.KUAI_FLAGS: campaign.set(key, Profiles.KUAI_FLAGS[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	var b: Node = get_tree().current_scene
	if not check("actual Kuaihuolin scene launched", b != null and b.get_script() == B and b.level.get_script() == Kuai): return null
	b.hud._intro_root.hide(); b.hud.intro_done.emit()
	if b.phase == B.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	b._official_context = Profiles.KUAI_CONTEXT.duplicate(true)
	b._save_barrier.configure(b, b._run_clock, Profiles.KUAI_CONTEXT)
	get_tree().paused = true
	return b

func _on_held(_value: Dictionary) -> void: held = true
func _on_rejected(value: String) -> void: rejected = value

func _graph() -> RefCounted:
	return UnitGraph.new(UnitState, Identity, Codec, U, Inventory, B, M, Profiles.KUAI_CONTEXT)

func _state(b: Node) -> Dictionary:
	var ids := {}
	for u in b.units_root.get_children(): ids[u] = str(u.entity_id)
	var graph: Dictionary = _graph().capture(b, ids, trusted.content_version, null, {"mission_token": "mission:level7:core", "deferred_drained": true})
	if not check("component complete Unit graph captured", graph.get("ok", false)): print(graph); return {"ok": false}
	# Graph.capture already validates every Unit record and the Level record.
	# Their payloads are complete encoded wire records. Encoding the entire graph
	# again would incorrectly apply one component's Codec budget to all Units.
	var records := {"graph": graph.value.duplicate(true), "level": graph.level_record.duplicate(true)}
	graph.identity.dispose()
	var extra := {"tells": _tell_snapshot(b), "gold": b.gold, "wood": b.wood, "faction_res": b.faction_res.duplicate(true), "kills": b.kills, "next_tick": b._run_clock._next_tick, "selection": b.selection.map(func(u): return str(u.entity_id)), "mission": [b.mission.stage_id, b.mission.events.duplicate(true), b.mission.active_action_id, b.mission._progress, b.mission._retry, b.mission._generation]}
	var packed: Dictionary = codec.encode(extra)
	if not check("component extra state encodes without unsupported values", packed.ok):
		print("LEVEL7_COMPONENT_STATE_CODEC_FAILED section=extra ", packed)
		return packed
	records["extra"] = packed.value
	return {"ok": true, "value": records}

func _roundtrip(b: Node, label: String) -> Node:
	print("LEVEL7_COMPONENT_ROUNDTRIP ", label)
	var slot_root := "user://level7_component_" + label + "/v1"
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
	for candidate in b.mission._buttons.get_children(): source_buttons.append(candidate.get_meta("campaign_presentation_v1", {}).duplicate(true))
	var scenery: Dictionary = Scenery.new(trusted.content_version, Profiles.KUAI_CONTEXT).capture(b.map)
	if not check(label + " scenery captured", scenery.ok): print(scenery); return null
	_semantic_audit(b, label + " source")
	var saved: Dictionary = Session.new(trusted, runtime, slot_root).save_held(b)
	if not check(label + " actual Session save", saved.ok): print("SAVE ", saved); return null
	var read: Dictionary = Store.new(slot_root).read_slot()
	if not check(label + " closed slot readable", read.ok): return null
	check(label + " slot exact official context", read.document.context == Profiles.KUAI_CONTEXT and read.document.world.profile.id == Profiles.KUAI_ID)
	await _negative_graph(read.document.world, label, b)
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
	if not check(label + " full graph level resources queues and mission equal while paused", get_tree().paused and after.ok and before == after) and after.ok:
		for section in before.value:
			if before.value[section] != after.value.get(section):
				print("LEVEL7_COMPONENT_STATE_MISMATCH fixture=", label, " section=", section)
				if section == "graph":
					var old_records: Array = before.value.graph.records
					var new_records: Array = after.value.graph.records
					print("LEVEL7_COMPONENT_GRAPH_COUNTS ", old_records.size(), " -> ", new_records.size())
					for index in range(mini(old_records.size(), new_records.size())):
						if old_records[index] != new_records[index]: print("LEVEL7_COMPONENT_UNIT_MISMATCH ", before.value.graph.root_order[index])
				else: print("LEVEL7_COMPONENT_RECORD_MISMATCH before=", before.value[section], " after=", after.value.get(section))
	var after_scenery: Dictionary = Scenery.new(trusted.content_version, Profiles.KUAI_CONTEXT).capture(restored.map)
	check(label + " native town scenery equal", after_scenery.ok and after_scenery.value == scenery.value)
	if after_scenery.ok: _semantic_audit(restored, label + " restored")
	check(label + " slot not rewritten on read", Store.new(slot_root).read_slot().file_sha256 == read.file_sha256)
	var restored_buttons: Array = []
	for candidate in restored.mission._buttons.get_children(): restored_buttons.append(candidate.get_meta("campaign_presentation_v1", {}))
	check(label + " all fixed presentation descriptors match source", restored_buttons == source_buttons)
	_fixed_selection(restored, label)
	observations.append({"fixture": label, "slot_sha256": read.file_sha256, "root_entities": restored.units_root.get_child_count(), "active_entities": restored.units.size(), "stage": restored.level.st, "drunk": restored.level.drunk, "counter_hits": restored.level.counter_hits})
	return restored


func _fixed_selection(b: Node, label: String) -> void:
	var found: Array = []
	for button in b.mission._buttons.get_children():
		var descriptor: Dictionary = button.get_meta("campaign_presentation_v1", {})
		if descriptor.get("kind") != "level": continue
		var key: String = descriptor.get("button_id", "")
		if not check(label + " only installed fixed selection callback", key in ["forest_wu", "forest_shi"]): continue
		found.append(key)
		button.pressed.emit()
		var expected: Variant = b.level.wu if key == "forest_wu" else b.level.shi
		check(label + " fixed selection resolves the current live actor " + key, b.selection == [expected] and expected.get_parent() == b.units_root)
	found.sort()
	check(label + " exactly two installed actor selectors", found == ["forest_shi", "forest_wu"])

func _semantic_audit(b: Node, label: String) -> void:
	var l: Variant = b.level
	var roles: Array = [l.wu, l.shi]
	for row in l.taverns: roles.append(row.u)
	roles.append(l.menshen); roles.append(l.sign)
	check(label + " exact fixed eight-entity active graph", roles.size() == 8 and b.units.size() == 8 and b.units_root.get_child_count() == 8 and roles.all(func(u): return is_instance_valid(u) and u.get_parent() == b.units_root and b.units.has(u) and u.hp > 0.0 and not u._dying))
	check(label + " four tavern flags match the cumulative drink state", l.taverns.size() == 4 and l.taverns.filter(func(row): return row.drunk).size() == l.drunk and l.wu._base_atk == 26.0 + 5.0 * l.drunk)
	check(label + " authored captive buildings have no invented footprint", (l.taverns.map(func(row): return row.u) + [l.sign]).all(func(u): return u.is_building and u.is_captive and not u.has_meta("fcell") and not u.has_meta("fhalf") and not u.has_meta("footprint_blocked")))
	check(label + " four installed fist abilities retain exact rank", l.wu.ability_slots.map(func(slot): return [slot.id, slot.rank]) == [["mengzhou_punch", 2], ["mengzhou_step", 2], ["mengzhou_kick", 2], ["mengzhou_breath", 2]])
	var tells: Dictionary = TellState.tokens(l, b.fx_root)
	check(label + " external tells belong to the actual restored FX root", tells.get("ok", false))
	if tells.ok:
		for field in ["fist_marker", "drill_marker"]:
			var marker: Variant = l.get(field)
			if not is_instance_valid(marker): continue
			var token: String = "level7:fist" if field == "fist_marker" else "level7:drill"
			check(label + " external token points to the same installed tell " + field, tells.tokens.get(token) == marker and marker.get_script() == Kuai.DuelTell and marker.get_parent() == b.fx_root)
	if l.st == l.RETURN_SHOP:
		check(label + " subdued Menshen remains alive and active", l.menshen.story_outcome == "subdued" and l.menshen.hp > 0.0 and b.units.has(l.menshen) and not l.charge_running and not is_instance_valid(l.fist_marker) and not l.victory)

func _tell_snapshot(b: Node) -> Dictionary:
	var result := {}
	for field in ["fist_marker", "drill_marker"]:
		var node: Variant = b.level.get(field)
		result[field] = null
		if is_instance_valid(node):
			result[field] = {"kind": node.kind, "progress": node.progress, "extent": node.extent, "position": node.position, "basis_x": node.transform.x, "basis_y": node.transform.y, "z_index": node.z_index, "z_as_relative": node.z_as_relative, "visible": node.visible, "metadata": TellState.metadata(node)}
	return result

func _reject_graph(world: Dictionary, label: String, external: Dictionary) -> void:
	var result: Dictionary = _graph().validate(world.sections.units, trusted.content_version, world.sections.level, world.profile.mission_token, external)
	check(label, not result.get("ok", true) and not String(result.get("code", "")).is_empty())
	observations.append({"negative": label, "result": result})

func _negative_graph(world: Dictionary, fixture: String, b: Node) -> void:
	var registry: Dictionary = TellState.tokens(b.level, b.fx_root)
	if not check(fixture + " valid external registry before negative fixtures", registry.get("ok", false)): return
	var baseline: Dictionary = _graph().validate(world.sections.units, trusted.content_version, world.sections.level, world.profile.mission_token, registry.tokens)
	if not check(fixture + " actual saved graph validates before mutation", baseline.get("ok", false)): print(baseline); return
	var decoded: Dictionary = codec.decode(world.sections.level.payload)
	if not check(fixture + " Level payload decodes for exact negative mutations", decoded.ok): return
	var bad: Dictionary = world.duplicate(true)
	bad["sections"]["units"]["schema"] = "level6_unit_graph_v1"
	_reject_graph(bad, fixture + " foreign chapter graph rejected", registry.tokens)
	var mutations: Array = []
	var value: Dictionary = decoded.value.duplicate(true)
	value["references"]["wu"] = value.references.shi
	mutations.append({"label": "fixed hero roles aliased", "value": value})
	value = decoded.value.duplicate(true)
	value["values"]["drunk"] = (int(value.values.drunk) + 1) % 5
	mutations.append({"label": "drink count diverges from tavern flags", "value": value})
	value = decoded.value.duplicate(true)
	value["references"]["taverns"][0]["u"] = value.references.taverns[1].u
	mutations.append({"label": "two taverns alias the same entity", "value": value})
	value = decoded.value.duplicate(true)
	value["values"]["victory"] = true
	mutations.append({"label": "terminal victory inserted into continuation", "value": value})
	if fixture == "moved_w_before_e":
		value = decoded.value.duplicate(true)
		value["values"]["step_serial"] = value.values.special_index + 1
		mutations.append({"label": "future W serial", "value": value})
	for field in ["fist_marker", "drill_marker"]:
		if decoded.value.external[field] == null: continue
		value = decoded.value.duplicate(true)
		value["external"][field] = "level7:foreign_tell"
		mutations.append({"label": "unknown external token " + field, "value": value})
		var missing: Dictionary = registry.tokens.duplicate()
		missing.erase(decoded.value.external[field])
		_reject_graph(world, fixture + " missing external object " + field, missing)
	for mutation in mutations:
		var encoded: Dictionary = codec.encode(mutation.value)
		if not check(fixture + " negative payload encodes " + mutation.label, encoded.ok): print(encoded); continue
		bad = world.duplicate(true)
		bad["sections"]["level"]["payload"] = encoded.value
		_reject_graph(bad, fixture + " " + mutation.label + " rejected", registry.tokens)
	bad = world.duplicate(true)
	bad["sections"]["units"]["active_order"].erase(decoded.value.references.menshen)
	_reject_graph(bad, fixture + " living Menshen missing from active graph rejected", registry.tokens)
	var unit_id: String = decoded.value.references.wu
	var index: int = world.sections.units.root_order.find(unit_id)
	var row: Dictionary = codec.decode(world.sections.units.records[index].payload)
	if check(fixture + " Wu payload decodes for illegal death record", row.ok):
		var dead: Dictionary = row.value.duplicate(true)
		dead["values"]["hp"] = 0.0
		dead["values"]["_dying"] = true
		var packed: Dictionary = codec.encode(dead)
		if check(fixture + " illegal death record encodes", packed.ok):
			bad = world.duplicate(true)
			bad["sections"]["units"]["records"][index]["payload"] = packed.value
			_reject_graph(bad, fixture + " dead essential hero cannot masquerade as a living continuation", registry.tokens)
	if fixture in ["road", "charge_hit_sign", "subdued_alive"]:
		var changed_id: String = decoded.value.references.sign if fixture == "road" else decoded.value.references.menshen
		var changed_index: int = world.sections.units.root_order.find(changed_id)
		var changed: Dictionary = codec.decode(world.sections.units.records[changed_index].payload)
		if check(fixture + " chapter-specific invalid Unit payload decodes", changed.ok):
			var label: String = "captive building cannot gain an invented footprint"
			if fixture == "road": changed.value["metadata"]["fcell"] = {"kind": "value", "value": Vector2i(54, 18)}
			elif fixture == "charge_hit_sign":
				label = "charge cannot register its own caster as a hit target"
				changed.value["references"]["_charge_hit"] = [{"state": "entity", "id": changed_id}]
			else:
				label = "subdued Menshen cannot change to an unrelated departure outcome"
				changed.value["values"]["story_outcome"] = "retreated"
			var encoded: Dictionary = codec.encode(changed.value)
			if check(fixture + " chapter-specific invalid Unit payload encodes", encoded.ok):
				bad = world.duplicate(true)
				bad["sections"]["units"]["records"][changed_index]["payload"] = encoded.value
				_reject_graph(bad, fixture + " " + label, registry.tokens)
	if fixture in ["road", "drill_tell", "heavy_windup"]: await _negative_live_tells(b, fixture)

func _negative_live_tells(b: Node, fixture: String) -> void:
	# Fault-only presentation fixtures restore the exact original references and
	# drain only their queued frees. No fabricated tell reaches a saved document.
	var orphan: Node2D = Kuai.DuelTell.new()
	b.fx_root.add_child(orphan)
	check(fixture + " unregistered live tell rejected", not TellState.tokens(b.level, b.fx_root).get("ok", true))
	orphan.queue_free(); await get_tree().process_frame
	var old: Variant = b.level.fist_marker
	var wrong := Node2D.new()
	b.fx_root.add_child(wrong); b.level.fist_marker = wrong
	check(fixture + " wrong script external object rejected", not TellState.tokens(b.level, b.fx_root).get("ok", true))
	b.level.fist_marker = old; wrong.queue_free(); await get_tree().process_frame
	if is_instance_valid(old):
		var previous: Variant = b.level.drill_marker
		b.level.drill_marker = old
		check(fixture + " aliased external tell references rejected", not TellState.tokens(b.level, b.fx_root).get("ok", true))
		b.level.drill_marker = previous
	check(fixture + " live tell registry restored exactly after faults", TellState.tokens(b.level, b.fx_root).get("ok", false))


func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row): return row.passed)
	var report := {"mode": "level7_component", "chapter": "level7", "passed": passed, "checks": checks, "pid": OS.get_process_id(), "process_nonce": OS.get_environment("LSH_LEVEL7_NONCE"), "fixture": true, "natural_route": false, "observations": observations, "real_steam": false}
	if report_path != "":
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
		else: passed = false
	else: passed = false
	print("LEVEL7_COMPONENT_COMPLETE ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
