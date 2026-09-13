extends Node
## Explicit component fixtures. Positioning, callback and death advancement below
## are fault/stage setup; they are not evidence of the natural player route.
const B := preload("res://scripts/battle.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Jiang := preload("res://scripts/levels/level2_jiangzhou_rts.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Factory := preload("res://scripts/run_level2_world_factory.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Session := preload("res://scripts/run_world_session.gd")
const Store := preload("res://scripts/run_slot_store.gd")
const UnitGraph := preload("res://scripts/run_unit_graph.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const Scenery := preload("res://scripts/run_scenery_state.gd")
const MapState := preload("res://scripts/run_map_state.gd")
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
		print("LEVEL2_COMPONENT PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	report_path = OS.get_environment("LSH_LEVEL2_STATE")
	if report_path.is_empty(): report_path = OS.get_environment("LSH_LEVEL3_RESTORE_REPORT")
	run.call_deferred()

func run() -> void:
	trusted = Provider.new().resolve_runtime_identity()
	if not check("trusted content identity", trusted.get("save_eligible", false)): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("installed Jiangzhou runtime", pack.get("ok", false) and Profiles._installed(Profiles.JIANG_ID)): finish(); return
	runtime = pack.runtime
	check("runtime does not deploy or change art", not pack.deploy_or_start_called and not pack.global_art_changed)
	check("uninstalled chapter still rejected", not Profiles.select_context({"mode": "campaign", "level_id": "level4", "waves": 0}, trusted).ok)
	var b: Node = await _launch()
	if not is_instance_valid(b): finish(); return
	var initial_gold: float = b.gold
	var initial_wood: float = b.wood
	for camp in b.level.camps:
		b.select_members([camp], false)
		b.minimap_order(b.map.cell_to_world(Vector2i(22, 28)), false)
		check("actual camp accepts paid reinforcement", b.queue_train(camp, "liang_qiang", false))
	check("actual training consumes shared gold and wood", b.gold < initial_gold and b.wood < initial_wood and b.level.camps.all(func(u): return u._train_queue == ["liang_qiang"] and u._train_t > 0))
	b = await _roundtrip(b, "paid_queue")
	if not is_instance_valid(b): finish(); return
	# Explicit skill fixture: learn each installed Q, then invoke the real
	# ability resolver, which supplies source attribution and normal cooldowns.
	for key in ["yan_shun", "zhang_heng"]:
		var actor: Variant = b.level.named_units[key]
		b.learn_slot(actor, 0)
		if not check(key + " installed Q can be cast", actor.slot_ready(0)): finish(); return
		b._do_ability(actor, 0, actor.position)
	check("actual Yan Q creates attributed tiger summon", b.units.any(func(u): return u.key == "tiger_summon" and u.is_summon and u.stat_owner_key == "yan_shun" and u.stat_ability_id == "yan_shun_q"))
	check("actual Zhang Heng Q creates attributed nonhero copy", b.units.any(func(u): return u.key == "zhang_heng" and u.is_summon and not u.is_hero and u.stat_owner_key == "zhang_heng" and u.stat_ability_id == "zhang_heng_q"))
	b = await _roundtrip(b, "real_summons")
	if not is_instance_valid(b): finish(); return
	# Explicit stage fixture: seat the two named signal actors and invoke the
	# authored mission callbacks. Resource and recruitment callbacks remain real.
	var l: Variant = b.level
	l.named_units.li_kui.position = b.map.cell_to_world(Vector2i(22, 25))
	l.named_units.yan_shun.position = b.map.cell_to_world(Vector2i(27, 29))
	l.on_mission_action(b, "west_street", l.named_units.li_kui)
	l.on_mission_action(b, "south_lane", l.named_units.yan_shun)
	l.on_mission_action(b, "first_axes", l.named_units.li_kui)
	var enemy_gold: float = b.faction_gold(1)
	l.process(b, 32.1)
	check("fixture calls real uprising and finite paid enemy producer", l.alarm and b.mission.has_event("jiangzhou_li_first") and l.enemy_produced == 1 and l.reinforcements.size() == 1 and b.faction_gold(1) < enemy_gold and l.enemy_spent_gold > 0)
	# Explicit fixture clears the actual cache guards, then the authored action
	# credits its one-time supplies and updates its visible claim label.
	for unit in b.units.duplicate():
		if l.active(unit) and unit.faction == 1 and not unit.is_building and unit.position.distance_to(l.caches[0].position) < 170:
			unit.take_damage(10000.0, null, false, true)
	l.on_mission_action(b, "cache_0", l.named_units.chao_gai)
	check("actual cache callback records one-time supplies", l.cache_taken == [true, false] and b.mission.has_event("cache_0"))
	b = await _roundtrip(b, "alarm_production")
	if not is_instance_valid(b): finish(); return
	l = b.level
	# Explicit lethal fixture uses Unit.take_damage and the actual chapter death
	# callbacks. Keep executioners in their death-strip window for this save.
	for unit in l.executioners: unit.take_damage(10000.0, null, false, true)
	l.process(b, 0.0)
	check("real executioner deaths halt the deadline", l.execution_halted and l.executioners.all(func(u): return u._dying and not b.units.has(u) and u.get_parent() == b.units_root))
	var song_bound_id := str(l.song_bound.entity_id)
	l.on_mission_action(b, "free_song", l.named_units.chao_gai)
	await get_tree().process_frame
	check("first real prisoner replacement preserves the second captive", not is_instance_valid(l.song_bound) and is_instance_valid(l.song_freed) and is_instance_valid(l.dai_bound) and not is_instance_valid(l.dai_freed) and str(l.song_freed.entity_id) != song_bound_id and not b.units_root.get_children().any(func(u): return str(u.entity_id) == song_bound_id) and l.first_rescued and not l.pursuit_sent)
	b = await _roundtrip(b, "song_freed")
	if not is_instance_valid(b): finish(); return
	l = b.level
	var dai_bound_id := str(l.dai_bound.entity_id)
	l.on_mission_action(b, "free_dai", l.named_units.chao_gai)
	await get_tree().process_frame
	check("second real replacement has its own new identity", not is_instance_valid(l.dai_bound) and is_instance_valid(l.dai_freed) and str(l.dai_freed.entity_id) != dai_bound_id and not b.units_root.get_children().any(func(u): return str(u.entity_id) == dai_bound_id))
	check("rescued pair is unarmed and has authored appearance", [l.song_freed, l.dai_freed].all(func(u): return u.is_noncombat and not u.is_hero and u.atk == 0 and u.art_variant == u.key + "_rescued"))
	# Advance only existing death callbacks while paused, then release the actual
	# north reserve using the chapter timer. No extra reserve is fabricated.
	for unit in l.executioners: unit._physics_process(U.DEATH_DUR + 0.1)
	await get_tree().process_frame
	l.process(b, 20.1)
	check("real pursuit release and expired executioner slots", l.pursuit_sent and b.mission.has_event("jiangzhou_rear_pursuit") and l.executioners.all(func(u): return not is_instance_valid(u)) and l.pursuit.all(func(u): return not u.passive))
	b = await _roundtrip(b, "both_freed")
	if not is_instance_valid(b): finish(); return
	l = b.level
	# Component-only geometry setup exercises live meeting/boarding callbacks.
	for actor in [l.song_freed, l.dai_freed, l.named_units.zhang_shun, l.named_units.zhang_heng]:
		actor.order_stop(); actor.position = b.map.cell_to_world(l.BAILONG)
	l.process(b, 0.3)
	check("actual meeting predicate earns Bailong event", l.meeting and b.mission.has_event("bailong"))
	l.song_freed.position = b.map.cell_to_world(l.DOCK)
	l.on_mission_action(b, "board_song", l.song_freed)
	check("one boarded passenger stays in root and Battle units while hidden", l.song_freed.story_outcome == "embarked" and l.song_freed.get_parent() == b.units_root and b.units.has(l.song_freed) and not l.song_freed.visible and l.dai_freed.story_outcome == "" and not is_instance_valid(l.depart_button))
	b = await _roundtrip(b, "one_embarked")
	if not is_instance_valid(b): finish(); return
	l = b.level
	l.dai_freed.position = b.map.cell_to_world(l.DOCK + Vector2i(2, 0))
	l.on_mission_action(b, "board_dai", l.dai_freed)
	l.process(b, 0.3)
	check("both real boarding callbacks create fixed departure button", l.dai_freed.story_outcome == "embarked" and is_instance_valid(l.depart_button) and l.depart_button.get_meta("campaign_presentation_v1", {}).get("button_id") == "jiang_depart")
	b = await _roundtrip(b, "departure_ready")
	if not is_instance_valid(b): finish(); return
	l = b.level
	var pursuer: Variant = l.pursuit[0]
	pursuer.take_damage(10000.0, null, false, true)
	check("real mobile death retains a dying reserve role", pursuer._dying and not b.units.has(pursuer) and pursuer.get_parent() == b.units_root)
	b = await _roundtrip(b, "dying_pursuer")
	if not is_instance_valid(b): finish(); return
	l = b.level
	l.pursuit[0]._physics_process(U.DEATH_DUR + 0.1)
	# Buildings use immediate queue_free, not the mobile death-strip lifetime.
	l.post.take_damage(10000.0, null, false, true)
	await get_tree().process_frame
	check("actual callbacks expire reserve and destroyed post references", not is_instance_valid(l.pursuit[0]) and not is_instance_valid(l.post) and b.mission.has_event("jiangzhou_post_destroyed"))
	var produced: int = l.enemy_produced
	l.process(b, 40.0)
	check("dead producer cannot spend or spawn", l.enemy_produced == produced)
	b = await _roundtrip(b, "expired_pursuer_post")
	if is_instance_valid(b): b.queue_free(); await get_tree().process_frame
	finish()

func _launch() -> Node:
	var campaign := get_node("/root/Campaign")
	for key in Profiles.JIANG_FLAGS: campaign.set(key, Profiles.JIANG_FLAGS[key])
	campaign.ai_friendly = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	menu._launch()
	for frame in range(180):
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.get_script() == B: break
	var b: Node = get_tree().current_scene
	if not check("actual Jiangzhou scene launched", b != null and b.get_script() == B and b.level.get_script() == Jiang): return null
	b.hud._intro_root.hide(); b.hud.intro_done.emit()
	if b.phase == B.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await get_tree().physics_frame
	await get_tree().process_frame
	b._official_context = Profiles.JIANG_CONTEXT.duplicate(true)
	b._save_barrier.configure(b, b._run_clock, Profiles.JIANG_CONTEXT)
	get_tree().paused = true
	return b

func _on_held(_value: Dictionary) -> void: held = true
func _on_rejected(value: String) -> void: rejected = value

func _graph() -> RefCounted:
	return UnitGraph.new(UnitState, Identity, Codec, U, Inventory, B, M, Profiles.JIANG_CONTEXT)

func _state(b: Node) -> Dictionary:
	var ids := {}
	for u in b.units_root.get_children(): ids[u] = str(u.entity_id)
	var graph: Dictionary = _graph().capture(b, ids, trusted.content_version, null, {"mission_token": "mission:level2:core", "deferred_drained": true})
	if not check("component complete Unit graph captured", graph.get("ok", false)): print(graph); return {"ok": false}
	# Graph.capture already validates every Unit record and the Level record.
	# Their payloads are complete encoded wire records. Encoding the entire graph
	# again would incorrectly apply one component's Codec budget to all Units.
	var records := {"graph": graph.value.duplicate(true), "level": graph.level_record.duplicate(true)}
	graph.identity.dispose()
	var extra := {"gold": b.gold, "wood": b.wood, "faction_res": b.faction_res.duplicate(true), "kills": b.kills, "next_tick": b._run_clock._next_tick, "selection": b.selection.map(func(u): return str(u.entity_id)), "mission": [b.mission.stage_id, b.mission.events.duplicate(true), b.mission.active_action_id, b.mission._progress, b.mission._retry, b.mission._generation]}
	var packed: Dictionary = codec.encode(extra)
	if not check("component extra state encodes without unsupported values", packed.ok):
		print("LEVEL2_COMPONENT_STATE_CODEC_FAILED section=extra ", packed)
		return packed
	records["extra"] = packed.value
	return {"ok": true, "value": records}

func _roundtrip(b: Node, label: String) -> Node:
	print("LEVEL2_COMPONENT_ROUNDTRIP ", label)
	var slot_root := "user://level2_component_" + label + "/v1"
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
	var scenery: Dictionary = Scenery.new(trusted.content_version, Profiles.JIANG_CONTEXT).capture(b.map)
	if not check(label + " scenery captured", scenery.ok): print(scenery); return null
	_scenery_audit(b, scenery.value, label + " source")
	var saved: Dictionary = Session.new(trusted, runtime, slot_root).save_held(b)
	if not check(label + " actual Session save", saved.ok): print("SAVE ", saved); return null
	var read: Dictionary = Store.new(slot_root).read_slot()
	if not check(label + " closed slot readable", read.ok): return null
	check(label + " slot exact official context", read.document.context == Profiles.JIANG_CONTEXT and read.document.world.profile.id == Profiles.JIANG_ID)
	if label == "paid_queue": _negative_map(read.document.world.sections.map)
	_negative_graph(read.document.world, label, b.level)
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
				print("LEVEL2_COMPONENT_STATE_MISMATCH fixture=", label, " section=", section)
				if section == "graph":
					var old_records: Array = before.value.graph.records
					var new_records: Array = after.value.graph.records
					print("LEVEL2_COMPONENT_GRAPH_COUNTS ", old_records.size(), " -> ", new_records.size())
					for index in range(mini(old_records.size(), new_records.size())):
						if old_records[index] != new_records[index]: print("LEVEL2_COMPONENT_UNIT_MISMATCH ", before.value.graph.root_order[index])
				else: print("LEVEL2_COMPONENT_RECORD_MISMATCH before=", before.value[section], " after=", after.value.get(section))
	var after_scenery: Dictionary = Scenery.new(trusted.content_version, Profiles.JIANG_CONTEXT).capture(restored.map)
	check(label + " native town scenery equal", after_scenery.ok and after_scenery.value == scenery.value)
	if after_scenery.ok: _scenery_audit(restored, after_scenery.value, label + " restored")
	check(label + " slot not rewritten on read", Store.new(slot_root).read_slot().file_sha256 == read.file_sha256)
	var restored_buttons: Array = []
	for candidate in restored.mission._buttons.get_children(): restored_buttons.append(candidate.get_meta("campaign_presentation_v1", {}))
	check(label + " all fixed presentation descriptors match source", restored_buttons == source_buttons)
	if label in ["departure_ready", "dying_pursuer", "expired_pursuer_post"]:
		check(label + " departure external binds actual installed button", is_instance_valid(restored.level.depart_button) and restored.level.depart_button.get_parent() == restored.mission._buttons and restored.level.depart_button.get_meta("campaign_presentation_v1", {}).get("button_id") == "jiang_depart")
	observations.append({"fixture": label, "slot_sha256": read.file_sha256, "root_entities": restored.units_root.get_child_count(), "active_entities": restored.units.size(), "enemy_produced": restored.level.enemy_produced})
	return restored

func _scenery_audit(b: Node, snapshot: Dictionary, label: String) -> void:
	check(label + " exact authored town map", b.map.w == 60 and b.map.h == 58 and b.map.theme == "town" and not b.map.has_meta("campaign_wall_segments") and snapshot.schema == "level2_scenery_state_v1")
	var crowd: Array = []; var signs: Array = []
	var all_decoded := true
	for encoded in snapshot.nodes:
		var row: Dictionary = codec.decode(encoded)
		if not row.ok: all_decoded = false; continue
		if row.value.kind == "story_crowd": crowd.append({"variant": row.value.fixed.variant, "facing": row.value.fixed._direction_override, "texture": row.value.textures._idle_texture})
		if row.value.kind == "story_sign": signs.append(row.value.fixed.label)
	check(label + " scenery nodes decode", all_decoded)
	check(label + " all eight authored crowd appearances retained", crowd.size() == 8 and crowd.all(func(row): return typeof(row.variant) == TYPE_INT and row.facing in ["se", "sw", "ne", "nw"] and row.texture.get("kind") != "none"))
	var expected := ["西街接应营", "江边接应营", "巡防营", "西巷", "南巷"]
	signs.sort(); expected.sort()
	check(label + " five authored town signs retained", signs == expected)
	observations.append({"display": label, "crowd": crowd, "signs": signs})

func _reject_graph(world: Dictionary, label: String, level: Variant) -> void:
	var external := {}
	if is_instance_valid(level.depart_button): external["level2:depart"] = level.depart_button
	var result: Dictionary = _graph().validate(world.sections.units, trusted.content_version, world.sections.level, world.profile.mission_token, external)
	check(label, not result.get("ok", true) and not String(result.get("code", "")).is_empty())

func _negative_map(snapshot: Dictionary) -> void:
	var adapter := MapState.new(trusted.content_version, Profiles.JIANG_CONTEXT)
	var source: Dictionary = adapter.validate(snapshot)
	if not check("actual saved Jiangzhou MapState validates before mutation", source.get("ok", false)): print("LEVEL2_COMPONENT_MAP_BASELINE ", source); return
	var decoded: Dictionary = codec.decode(snapshot.sections.header)
	if not check("saved MapState header decodes for decor negatives", decoded.ok): print(decoded); return
	var decor: Array = decoded.value.decor
	var crowd_indexes: Array = []; var ordinary_index := -1
	for index in range(decor.size()):
		if decor[index][0] == "crowd": crowd_indexes.append(index)
		elif ordinary_index == -1: ordinary_index = index
	if not check("negative fixture locates eight actual crowd markers and ordinary decor", crowd_indexes.size() == 8 and ordinary_index >= 0): return
	var crowd_index: int = crowd_indexes[0]
	var original: Array = decor[crowd_index]
	if not check("authored crowd marker keeps float zero and integer coordinate variant", original.size() == 4 and typeof(original[2]) == TYPE_FLOAT and original[2] == 0.0 and typeof(original[3]) == TYPE_INT and original[3] == original[1].x + original[1].y): return
	var mutations := [
		[crowd_index, 2, 1.0, "crowd positive size rejected", "DECOR_CROWD"],
		[crowd_index, 3, original[3] + 1, "crowd shifted variant rejected", "DECOR_CROWD"],
		[ordinary_index, 2, 0.0, "ordinary decor zero size rejected", "DECOR_VALUE"]]
	for mutation in mutations:
		var header: Dictionary = decoded.value.duplicate(true)
		header["decor"][mutation[0]][mutation[1]] = mutation[2]
		var encoded: Dictionary = codec.encode(header)
		if not check("MapState negative header encodes " + mutation[3], encoded.ok): print("LEVEL2_COMPONENT_MAP_CODEC_FAILED ", encoded); continue
		var bad: Dictionary = snapshot.duplicate(true)
		bad["sections"]["header"] = encoded.value
		var result: Dictionary = adapter.validate(bad)
		check(mutation[3], not result.get("ok", true) and result.get("code") == mutation[4] and result.get("path") == "$/header/decor/" + str(mutation[0]))
		observations.append({"map_negative": mutation[3], "result": result})

func _negative_graph(world: Dictionary, fixture: String, level: Variant) -> void:
	var decoded: Dictionary = codec.decode(world.sections.level.payload)
	if not check(fixture + " negative Level payload decodes", decoded.ok): return
	var refs: Dictionary = decoded.value.references
	var bad: Dictionary = world.duplicate(true)
	bad["sections"]["units"]["schema"] = "level6_unit_graph_v1"
	_reject_graph(bad, fixture + " foreign chapter graph rejected", level)
	var mutations: Array = []
	for pair in [["song_bound", "song_freed"], ["dai_bound", "dai_freed"]]:
		var value: Dictionary = decoded.value.duplicate(true)
		var field: String = pair[0] if value.references[pair[0]] != null else pair[1]
		value["references"][field] = null
		mutations.append({"label": "required prisoner missing " + field, "value": value})
	var swapped: Dictionary = decoded.value.duplicate(true)
	swapped["references"]["named_units"]["chao_gai"] = refs.named_units.li_kui
	mutations.append({"label": "named identities aliased", "value": swapped})
	var wrong_cache: Dictionary = decoded.value.duplicate(true)
	wrong_cache["values"]["cache_taken"] = [false]
	mutations.append({"label": "cache cardinality changed", "value": wrong_cache})
	if fixture == "alarm_production":
		var wrong_claim: Dictionary = decoded.value.duplicate(true)
		wrong_claim["values"]["cache_taken"] = [false, false]
		mutations.append({"label": "claimed cache display and flag diverge", "value": wrong_claim})
		var swapped_reserve: Dictionary = decoded.value.duplicate(true)
		var first: Variant = swapped_reserve.references.pursuit[0]
		swapped_reserve["references"]["pursuit"][0] = swapped_reserve.references.pursuit[5]
		swapped_reserve["references"]["pursuit"][5] = first
		mutations.append({"label": "initial pursuit roles swapped", "value": swapped_reserve})
		var wrong_produced: Dictionary = decoded.value.duplicate(true)
		wrong_produced["values"]["enemy_produced"] = 9
		mutations.append({"label": "finite producer count overflow", "value": wrong_produced})
		var wrong_spent: Dictionary = decoded.value.duplicate(true)
		wrong_spent["values"]["enemy_spent_gold"] = -1
		mutations.append({"label": "negative producer spending", "value": wrong_spent})
	for mutation in mutations:
		var encoded: Dictionary = codec.encode(mutation.value)
		if not check(fixture + " bad payload encoded " + mutation.label, encoded.ok):
			print("LEVEL2_COMPONENT_NEGATIVE_CODEC_FAILED fixture=", fixture, " mutation=", mutation.label, " ", encoded)
			continue
		bad = world.duplicate(true); bad["sections"]["level"]["payload"] = encoded.value
		_reject_graph(bad, fixture + " " + mutation.label + " rejected", level)
	var prisoner: String = refs.song_bound if refs.song_bound != null else refs.song_freed
	bad = world.duplicate(true)
	if bad.sections.units.active_order.has(prisoner): bad.sections.units.active_order.erase(prisoner)
	else: bad.sections.units.active_order.append(prisoner)
	_reject_graph(bad, fixture + " prisoner active membership mismatch rejected", level)
	if refs.song_freed != null:
		var index: int = world.sections.units.root_order.find(refs.song_freed)
		var unit_decoded: Dictionary = codec.decode(world.sections.units.records[index].payload)
		if check(fixture + " freed actor payload decodes", unit_decoded.ok):
			var value: Dictionary = unit_decoded.value.duplicate(true)
			value["values"]["atk"] = 99.0
			var encoded: Dictionary = codec.encode(value)
			if check(fixture + " armed prisoner payload encodes", encoded.ok):
				bad = world.duplicate(true); bad["sections"]["units"]["records"][index]["payload"] = encoded.value
				_reject_graph(bad, fixture + " rescued prisoner cannot gain combat stats", level)
			else: print("LEVEL2_COMPONENT_NEGATIVE_CODEC_FAILED fixture=", fixture, " mutation=armed_prisoner ", encoded)

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row): return row.passed)
	var report := {"mode": "level2_component", "chapter": "level2", "passed": passed, "checks": checks, "pid": OS.get_process_id(), "process_nonce": OS.get_environment("LSH_LEVEL2_NONCE"), "fixture": true, "natural_route": false, "observations": observations, "real_steam": false}
	if report_path != "":
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
		else: passed = false
	else: passed = false
	print("LEVEL2_COMPONENT_COMPLETE ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
