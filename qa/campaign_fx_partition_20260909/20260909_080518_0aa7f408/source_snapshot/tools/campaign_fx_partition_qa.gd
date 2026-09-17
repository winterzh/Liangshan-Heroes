extends Node
## Real Battle/Level3/Mission/Presentation and ordinary Unit graph components.
## No Level deploy/on_start, whole-world continuation, clock arm, or Steam call.
const Visual := preload("res://scripts/run_visual_graph.gd")
const PP := preload("res://scripts/run_campaign_presentation_state.gd")
const MS := preload("res://scripts/run_campaign_mission_state.gd")
const Mission := preload("res://scripts/campaign_mission.gd")
const B := preload("res://scripts/battle.gd")
const U := preload("res://scripts/unit.gd")
const M := preload("res://scripts/game_map.gd")
const Zhu := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const Classic := preload("res://scripts/levels/skirmish.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Graph := preload("res://scripts/run_unit_graph.gd")
const UnitState := preload("res://scripts/run_unit_state.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const RNG := preload("res://scripts/run_gameplay_rng.gd")
const CONTENT := "fixture:campaign_fx_partition:v1"
const CONTEXT := {"level_id": "level3", "content_version": CONTENT, "mission_token": "mission:fx:1", "presentation_token": "presentation:fx:1"}
const NOW := 100000
var codec := Codec.new()
var checks: Array = []
var owners: Array = []
var restorations: Array = []

class QuietHUD extends HUD:
	func _ready() -> void: pass
	func update_selection_panel(_selection: Array) -> void: pass
	func refresh_command() -> void: pass
	func show_message(_text: String, _duration := 3.5, _quiet_in_full_auto := false) -> void: pass
	func campaign_objective_position() -> Vector2: return Vector2(84, 78)

func _ready() -> void:
	var profile := OS.get_environment("LSH_CAMPAIGN_FX_PARTITION_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("CAMPAIGN_FX_PARTITION_QA PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: print("PARTITION_CHECK_FAILED ", label)

func result_check(label: String, result: Dictionary) -> bool:
	check(label, result.get("ok", false))
	if not result.get("ok", false): print("PARTITION_RESULT ", label, " ", result)
	return result.get("ok", false)

func gate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED; node.set_block_signals(true)
	for child: Node in node.get_children(true): gate(child)

func graph() -> RefCounted:
	# Ordinary soldiers use the existing classic Unit subset, independently of
	# the Level3-specific marker contract. No claim of chapter role restoration.
	return Graph.new(UnitState, Identity, Codec, U, Inventory, B, M)

func shell() -> B:
	var owner := B.new(); owner.process_mode = Node.PROCESS_MODE_DISABLED; owner.set_block_signals(true)
	owner.world = Node2D.new(); owner.add_child(owner.world)
	owner.map = M.new(); owner.world.add_child(owner.map)
	owner.map.init_map(64, 56, "village", M.T.GRASS); owner.map.bake()
	owner.units_root = Node2D.new(); owner.world.add_child(owner.units_root)
	owner.fx_root = Node2D.new(); owner.world.add_child(owner.fx_root)
	owner.hud = QuietHUD.new(); owner.hud.battle = owner; owner.add_child(owner.hud)
	owner.level = Zhu.new(); owner._defs = Defs.UNITS.duplicate(true)
	owner.phase = B.Phase.FIGHT; owner.fog = false
	owner.set_meta("_run_core_prepared", true); owner._cursor_resources_released = true
	var engine_hash := OS.get_environment("LSH_CAMPAIGN_FX_PARTITION_ENGINE_SHA256")
	var rng := RNG.new(CONTENT)
	if result_check("private RNG seed accepted", rng.start(731, engine_hash)):
		result_check("Battle uses restored RNG with no clock", owner.configure_restored_gameplay_rng({"ok": true, "save_eligible": true, "content_version": CONTENT, "engine_binary_sha256": engine_hash}, rng.capture().record))
	gate(owner); owners.append(owner)
	return owner

func ids(owner: B) -> Dictionary:
	var result := {}
	for unit: Node in owner.units_root.get_children(true): result[str(unit.entity_id)] = unit
	return result

func inverse(registry: Dictionary) -> Dictionary:
	var result := {}
	for id: String in registry: result[registry[id]] = id
	return result

func label_fx(name_text: String, amount: int, position: Vector2) -> Node2D:
	var fx := B.FloatLabel.new(); fx.name = name_text; fx.amount = amount; fx.t = 0.19
	fx.position = position; fx.crit = amount > 20
	return fx

func make_source() -> B:
	var owner := shell()
	var soldier: Unit = owner.spawn_at("liang_dao", 0, Vector2i(4, 5))
	check("actual ordinary Unit spawned without chapter deployment", is_instance_valid(soldier) and owner.units.size() == 1)
	gate(soldier)
	var mission := Mission.new(owner); owner.mission = mission
	mission.configure_campaign(owner.level.campaign_core_goal(), owner.level.campaign_story_goals(), 2)
	mission.begin("zhu_rts", "第一打 · 扎营探路", "北取资源，南拔外营。")
	mission._stage_started_ms = NOW - 2500; mission.enable_scrolling()
	owner.fx_root.add_child(label_fx("BeforeMarker", 17, Vector2(130, 140)))
	mission.add_action("zhu_rts_inside", "接应内应，打开偏门", Vector2i(25, 18), ["sun_li"], 5.0, 64.0)
	var nested := Node2D.new(); nested.name = "NestedContainer"; nested.position = Vector2(12, 15)
	owner.fx_root.add_child(nested); nested.add_child(label_fx("NestedDamage", 43, Vector2(180, 200)))
	mission.add_action("zhu_rts_rescue", "救出被囚好汉", Vector2i(15, 35), ["song_jiang"], 3.0, 64.0)
	var bolt := B.BoltFx.new(); bolt.name = "AfterMarker"; bolt.chain_from = soldier
	bolt.position = Vector2(210, 220); bolt._t = 0.37; bolt._trail = [Vector2(200, 210), Vector2(205, 215)]
	owner.fx_root.add_child(bolt)
	var marker: Node2D = mission._markers[0]
	marker.number = 17; marker.show_caption = true; marker.rotation = 0.21; marker.scale = Vector2(1.1, 0.9)
	marker.modulate = Color(0.7, 0.8, 0.9, 0.6); marker.z_index = 3451
	marker.process_priority = 13; marker.process_physics_priority = -4; marker.set_process(true)
	mission._markers[1].visible = false; mission.actions.zhu_rts_rescue.button.disabled = true
	mission.add_map_locator("前营", Zhu.CAMP)
	add_child(owner)
	return owner

func configured(owner: B, bundle: Dictionary, registry: Dictionary) -> RefCounted:
	var visual := Visual.new(Codec, B, U, owner)
	result_check("fixed Presentation and Mission records configure partition", visual.configure_presentation(bundle.presentation, bundle.mission, CONTEXT, registry, int(bundle.units.next_entity_id)))
	return visual

func capture_source(owner: B) -> Dictionary:
	var registry := ids(owner)
	check("real CanvasLayer HUD owns the source Mission panel", owner.hud is CanvasLayer and owner.mission._panel.get_parent() == owner.hud)
	var pp: Dictionary = PP.new().capture(owner.mission, CONTEXT)
	if not result_check("real mounted Presentation captured", pp): return {}
	var ms: Dictionary = MS.new().capture(owner.mission, CONTEXT, registry, owner.next_entity_id, pp.external_to_token, NOW, {"deferred_drained": true, "presentation_captured": true})
	if not result_check("real Mission captured with exact external map", ms): return {}
	var units: Dictionary = graph().capture(owner, inverse(registry), CONTENT)
	if not result_check("ordinary actual Unit graph captured", units): return {}
	result_check("ordinary Unit records independently validated", graph().validate(units.value, CONTENT))
	units.identity.dispose()
	var bundle := {"presentation": pp.record, "mission": ms.record, "units": units.value}
	var visual := configured(owner, bundle, registry)
	var captured: Dictionary = visual.capture(owner.fx_root, CONTENT, inverse(registry))
	if not result_check("mixed Visual and external marker graph captured", captured): return {}
	bundle.visual = captured.value
	var rows: Array = codec.decode(bundle.visual.records).value
	check("mixed graph contains nested container and three ordinary effects", rows.size() == 7 and captured.count == 7)
	var markers := 0
	for row: Dictionary in rows:
		if row.kind == Visual.EXTERNAL_MARKER:
			markers += 1
			check("external row contains only identity order and token " + row.token, row.size() == 5 and not row.has("node") and not row.has("values") and not row.has("references"))
	check("both real markers represented exactly once", markers == 2)
	check("classic default refuses Mission markers", not Visual.new(Codec, B, U, owner).capture(owner.fx_root, CONTENT, inverse(registry)).ok)
	return bundle

func capture_negatives(owner: B, bundle: Dictionary) -> void:
	var registry := ids(owner); var visual := configured(owner, bundle, registry)
	var marker: Node2D = owner.mission._markers[0]
	var original_level: Variant = owner.level; owner.level = Classic.new()
	check("changed actual Level script refuses capture", not visual.capture(owner.fx_root, CONTENT, inverse(registry)).ok)
	owner.level = original_level
	var number: int = marker.number; marker.number += 1
	check("changed live marker data refuses stale pair", not visual.capture(owner.fx_root, CONTENT, inverse(registry)).ok)
	marker.number = number
	owner.mission._stage_commands += 1
	check("changed live Mission data refuses stale component pair", not visual.capture(owner.fx_root, CONTENT, inverse(registry)).ok)
	owner.mission._stage_commands -= 1
	var nested: Node = owner.fx_root.get_node("NestedContainer")
	var original_transform := marker.transform
	marker.reparent(nested)
	check("nested marker parent refuses capture", not visual.capture(owner.fx_root, CONTENT, inverse(registry)).ok)
	marker.reparent(owner.fx_root); owner.fx_root.move_child(marker, 1); marker.transform = original_transform
	var alien := Mission.MissionMarker.new(); owner.fx_root.add_child(alien)
	check("unregistered real marker refuses capture", not visual.capture(owner.fx_root, CONTENT, inverse(registry)).ok)
	owner.fx_root.remove_child(alien); alien.free()
	var old: Variant = owner.mission._markers[1]; owner.mission._markers[1] = marker
	check("aliased Mission marker refuses capture", not visual.capture(owner.fx_root, CONTENT, inverse(registry)).ok)
	owner.mission._markers[1] = old
	check("restored source fields capture successfully", visual.capture(owner.fx_root, CONTENT, inverse(registry)).ok)

func record_negatives(bundle: Dictionary) -> void:
	var known := {}
	var registry := {}
	for id: String in bundle.units.root_order:
		known[id] = true
		var unit := U.new(); unit.entity_id = int(id); gate(unit); registry[id] = unit
	var rows: Array = codec.decode(bundle.visual.records).value
	var first := -1; var second := -1; var nested := ""
	for index: int in rows.size():
		if rows[index].kind == Visual.EXTERNAL_MARKER:
			if first < 0: first = index
			else: second = index
		if rows[index].kind == "container" and rows[index].parent != "": nested = rows[index].id
	var cases: Array = []
	for value: Variant in ["marker:999", "node:_status", 1, [], {}, null]:
		var changed := rows.duplicate(true); changed[first].token = value
		cases.append({"label": "bad external token " + str(value), "rows": changed})
	var alias := rows.duplicate(true); alias[second].token = alias[first].token; cases.append({"label": "alias external token", "rows": alias})
	var parent := rows.duplicate(true); parent[first].parent = nested; cases.append({"label": "external parent container", "rows": parent})
	var order := rows.duplicate(true); order[first].index += 1; cases.append({"label": "external sibling gap", "rows": order})
	var duplicate_state := rows.duplicate(true); duplicate_state[first].values = {}; cases.append({"label": "duplicated marker state", "rows": duplicate_state})
	var missing := rows.duplicate(true); missing.remove_at(second); cases.append({"label": "missing external marker", "rows": missing})
	for item: Dictionary in cases:
		var wire: Dictionary = bundle.visual.duplicate(true); wire.records = codec.encode(item.rows).value
		var visual := configured(null, bundle, known)
		check(item.label + " validates as rejection", not visual.validate(wire, CONTENT, known).ok)
		check(item.label + " allocates no FX", not visual.prepare(wire, CONTENT, registry).ok and visual._nodes.is_empty())
		visual.dispose()
	var tampered: Dictionary = bundle.presentation.duplicate(true)
	var raw: Dictionary = codec.decode(tampered.payload).value
	raw.markers[0].descriptor.action_id = "unknown_action"; tampered.payload = codec.encode(raw).value
	var other := Visual.new(Codec, B, U)
	check("valid marker shape with wrong action refuses configure", not other.configure_presentation(tampered, bundle.mission, CONTEXT, known, int(bundle.units.next_entity_id)).ok)
	var empty_root := Node2D.new()
	check("failed configure cannot fall through to classic", not other.capture(empty_root, CONTENT, {}).ok)
	empty_root.free()
	var classic := Visual.new(Codec, B, U)
	check("campaign schema requires configured fixed partition", not classic.validate(bundle.visual, CONTENT, known).ok)
	var plain := Node2D.new(); plain.add_child(label_fx("ClassicDamage", 12, Vector2(30, 40)))
	var captured: Dictionary = classic.capture(plain, CONTENT, {})
	check("classic default still captures ordinary effects", captured.ok and captured.value.schema == Visual.SCHEMA)
	plain.free()
	for field: String in CONTEXT:
		var context := CONTEXT.duplicate(true); context[field] = "unknown"
		check("changed context refuses configuration " + field, not Visual.new(Codec, B, U).configure_presentation(bundle.presentation, bundle.mission, context, known, int(bundle.units.next_entity_id)).ok)
	for unit: Node in registry.values(): unit.free()

func prepare_pair(bundle: Dictionary, mission_override: Variant = null) -> Dictionary:
	var owner := shell()
	var units: Dictionary = graph().prepare(bundle.units, CONTENT, owner, owner.map)
	if not result_check("actual Unit graph prepares private fresh objects", units): return {}
	for unit: Node in units.units_in_root_order: owner.units_root.add_child(unit)
	owner.units.assign(units.active_units); owner.next_entity_id = units.pending_battle_fields.next_entity_id
	units.identity.release_tombstones()
	var visual := configured(owner, bundle, units.id_to_unit)
	var prepared: Dictionary = visual.prepare(bundle.visual, CONTENT, units.id_to_unit)
	if not result_check("Visual prepares only owned effects", prepared): units.identity.dispose(); return {}
	owner.fx_root.free(); owner.fx_root = prepared.root; owner.world.add_child(owner.fx_root)
	check("Visual allocation excludes both markers", prepared.created_count == 5 and prepared.external_count == 2 and owner.fx_root.get_child_count() == 3)
	var pp := PP.new()
	var presentation: Dictionary = pp.prepare(owner, bundle.presentation, bundle.mission if mission_override == null else mission_override, CONTEXT, units.id_to_unit, owner.next_entity_id, 1000)
	if not result_check("real Presentation prepares Mission and both markers", presentation): visual.dispose(); units.identity.dispose(); return {}
	var result := {"owner": owner, "visual": visual, "pp": pp, "units": units}
	restorations.append(result)
	return result

func failed_binding_cleanup(bundle: Dictionary) -> void:
	var old_keys: Array = Localize._bindings.keys()
	var old_connections: int = Localize.language_changed.get_connections().size()
	var pair := prepare_pair(bundle)
	if pair.is_empty(): return
	var markers: Array = pair.pp.mission._markers.duplicate()
	markers[0].number += 1
	check("cleanup fixture refuses changed marker before bind", not pair.visual.bind_presentation(pair.pp).ok)
	var bound_keys: Array = Localize._bindings.keys()
	pair.visual.dispose()
	check("failed Visual disposal preserves PP-owned marker objects", markers.all(func(node: Node) -> bool: return is_instance_valid(node) and node.get_parent() == null))
	check("failed Visual disposal leaves PP bindings for PP cleanup", Localize._bindings.keys() == bound_keys)
	pair.pp.dispose()
	check("Presentation disposal releases only new binding keys", Localize._bindings.keys() == old_keys)
	check("Presentation disposal releases only new language connection", Localize.language_changed.get_connections().size() == old_connections)
	var different: Dictionary = bundle.mission.duplicate(true)
	var raw: Dictionary = codec.decode(different.payload).value
	raw.values._stage_commands += 1; different.payload = codec.encode(raw).value
	var known := {}
	for id: String in bundle.units.root_order: known[id] = true
	result_check("different Mission B remains independently valid", MS.new().validate(different, CONTEXT, known, int(bundle.units.next_entity_id), PP.new().validate(bundle.presentation, CONTEXT).tokens))
	var other := prepare_pair(bundle, different)
	if not other.is_empty():
		check("Mission A configuration refuses valid Mission B adapter", not other.visual.bind_presentation(other.pp).ok)
		check("pairing rejection does not silently rewrite Mission B", other.pp.mission._stage_commands == raw.values._stage_commands)

func restore_case(bundle: Dictionary, label: String, mutation := "") -> void:
	var pair := prepare_pair(bundle)
	if pair.is_empty(): return
	var pp: Variant = pair.pp; var visual: Variant = pair.visual; var owner: B = pair.owner
	var marker: Node2D = pp.mission._markers[0]
	if mutation == "wrong_adapter":
		check(label + " rejects unrelated Presentation instance", not visual.bind_presentation(PP.new()).ok)
	if mutation == "bind_changed":
		marker.number += 1
		check(label + " rejects changed marker before bind", not visual.bind_presentation(pp).ok)
		marker.number -= 1
	if mutation == "bind_extra":
		var extra := Node2D.new(); owner.fx_root.add_child(extra)
		check(label + " rejects unknown root child before bind", not visual.bind_presentation(pp).ok)
		owner.fx_root.remove_child(extra); extra.free()
	if not result_check(label + " exact Presentation binds full mixed order", visual.bind_presentation(pp)): return
	check(label + " owns only five nodes", visual._nodes.size() == 5 and visual._external_nodes.size() == 2)
	check(label + " marker identities come from PP", visual._external_nodes.values().has(marker) and not visual._nodes.values().has(marker))
	check(label + " full root mix preserved", owner.fx_root.get_child(0).name == "BeforeMarker" and owner.fx_root.get_child(1) == marker and owner.fx_root.get_child(2).name == "NestedContainer" and owner.fx_root.get_child(3) == pp.mission._markers[1] and owner.fx_root.get_child(4).name == "AfterMarker")
	add_child(owner)
	check(label + " mounted shell never starts gameplay", owner.gameplay_rng_fault().is_empty() and owner._run_clock == null and owner._save_barrier == null and owner.units.size() == 1)
	check(label + " activation refuses unfinished layout", not visual.activate().ok)
	var layout := false
	for frame: int in 12:
		await get_tree().process_frame
		var finished: Dictionary = pp.finish_layout()
		if finished.ok: layout = true; break
		if finished.code != "PRESENTATION_LAYOUT_PENDING": print("PARTITION_LAYOUT ", finished); break
	check(label + " real mounted multi-frame layout finishes", layout)
	if not layout: return
	if mutation == "order":
		owner.fx_root.move_child(marker, 4)
		check(label + " activation rejects changed mixed order", not visual.activate().ok)
		owner.fx_root.move_child(marker, 1)
	if mutation == "parent":
		var original_transform := marker.transform
		marker.reparent(owner.fx_root.get_node("NestedContainer"))
		check(label + " activation rejects marker parent change", not visual.activate().ok)
		marker.reparent(owner.fx_root); owner.fx_root.move_child(marker, 1); marker.transform = original_transform
	if mutation == "state":
		marker.visible = not marker.visible
		check(label + " activation rejects changed marker visibility", not visual.activate().ok)
		marker.visible = not marker.visible
	if mutation == "metadata":
		marker.set_meta("qa_unknown", true)
		check(label + " activation rejects unknown marker metadata", not visual.activate().ok)
		marker.remove_meta("qa_unknown")
	if mutation == "alias":
		var previous: Variant = pp.token_to_external["marker:0"]; pp.token_to_external["marker:0"] = pp.token_to_external["marker:1"]
		check(label + " activation rejects token object alias", not visual.activate().ok)
		pp.token_to_external["marker:0"] = previous
	if mutation == "token_missing":
		var previous: Variant = pp.token_to_external["marker:0"]; pp.token_to_external.erase("marker:0")
		check(label + " activation rejects missing external token without native error", not visual.activate().ok)
		pp.token_to_external["marker:0"] = previous
	if mutation == "ungated":
		marker.set_block_signals(false)
		check(label + " activation rejects prematurely unblocked marker", not visual.activate().ok)
		marker.set_block_signals(true)
	if mutation == "extra":
		var extra := Node2D.new(); owner.fx_root.add_child(extra); gate(extra)
		check(label + " activation rejects an unknown added child", not visual.activate().ok)
		owner.fx_root.remove_child(extra); extra.free()
	if mutation == "plan":
		pp.activation_plan[marker].priority += 1
		check(label + " activation rejects changed marker activation plan", not visual.activate().ok)
		pp.activation_plan[marker].priority -= 1
	if mutation == "mission":
		pp.mission._stage_commands += 1
		check(label + " activation rejects changed stable Mission fields", not visual.activate().ok)
		pp.mission._stage_commands -= 1
	if mutation == "clock":
		pp.mission._stage_started_ms += 1
		check(label + " activation rejects changed rebased clock anchor", not visual.activate().ok)
		pp.mission._stage_started_ms -= 1
	if mutation == "unknown_cleanup":
		var extra := Node2D.new(); owner.fx_root.get_node("NestedContainer").add_child(extra); gate(extra)
		check(label + " activation rejects unknown nested child", not visual.activate().ok)
		pp.dispose(); visual.dispose(); owner.free()
		check(label + " failed private tree cleanup frees unknown nested child", not is_instance_valid(extra))
		return
	if not result_check(label + " Visual activation audits all external markers", visual.activate()): return
	check(label + " Visual leaves marker gated", marker.process_mode == Node.PROCESS_MODE_DISABLED and marker.is_blocking_signals())
	check(label + " real Bolt binds restored Unit not source", owner.fx_root.get_node("AfterMarker").chain_from == pair.units.id_to_unit["1"])
	check(label + " nested FloatLabel state preserved", owner.fx_root.get_node("NestedContainer/NestedDamage").amount == 43 and is_equal_approx(owner.fx_root.get_node("NestedContainer/NestedDamage").t, 0.19))
	check(label + " marker number transform and hidden second marker preserved", marker.number == 17 and is_equal_approx(marker.rotation, 0.21) and not pp.mission._markers[1].visible)
	result_check(label + " Presentation alone activates marker flags", pp.activate())
	check(label + " marker inherited mode and signals restored", marker.process_mode == Node.PROCESS_MODE_INHERIT and not marker.is_blocking_signals())
	check(label + " marker nondefault processing flags restored by PP", marker.process_priority == 13 and marker.process_physics_priority == -4 and marker.is_processing())
	check(label + " restored real action button invokes new Mission", pp.mission.actions.zhu_rts_inside.button.pressed.get_connections()[0].callable.get_object() == pp.mission)
	var nested: Node = owner.fx_root.get_node("NestedContainer/NestedDamage")
	nested._process(0.01)
	check(label + " restored actual FloatLabel continues elapsed time", is_equal_approx(nested.t, 0.20))
	var bolt: Node = owner.fx_root.get_node("AfterMarker"); bolt._process(0.01)
	check(label + " restored actual Bolt continues trail against fresh Unit", bolt._trail.size() == 3 and bolt.chain_from == pair.units.id_to_unit["1"] and is_equal_approx(bolt._t, 0.38))
	check(label + " second Visual activation refuses", not visual.activate().ok)

func cleanup() -> void:
	for row: Dictionary in restorations:
		row.pp.dispose(); row.visual.dispose(); row.units.identity.dispose()
	for owner: B in owners:
		if not is_instance_valid(owner): continue
		if is_instance_valid(owner.mission):
			var temporary := PP.new(); temporary.mission = owner.mission; temporary._owner = owner; temporary.dispose()
		owner.free()

func run() -> void:
	get_tree().paused = true
	var phase := OS.get_environment("LSH_CAMPAIGN_FX_PARTITION_PHASE")
	var snapshot_path := OS.get_environment("LSH_CAMPAIGN_FX_PARTITION_SNAPSHOT")
	var bundle: Dictionary = {}
	if phase == "component":
		var source := make_source()
		for frame: int in 4: await get_tree().process_frame
		bundle = capture_source(source)
		if not bundle.is_empty():
			capture_negatives(source, bundle); record_negatives(bundle)
			failed_binding_cleanup(bundle)
			bundle.synthetic_fixture = true; bundle.producer_pid = OS.get_process_id()
			var file := FileAccess.open(snapshot_path, FileAccess.WRITE)
			check("synthetic producer snapshot opened", file != null)
			if file != null: file.store_string(JSON.stringify(bundle)); file.close()
	elif phase == "restart":
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
		check("fresh process loads producer synthetic fixture", typeof(data) == TYPE_DICTIONARY and data.get("synthetic_fixture") == true)
		if typeof(data) == TYPE_DICTIONARY: bundle = data
	else: check("known component phase", false)
	if not bundle.is_empty():
		await restore_case(bundle, phase + " roundtrip")
		if phase == "component":
			for mutation: String in ["wrong_adapter", "bind_changed", "bind_extra", "order", "parent", "state", "metadata", "alias", "token_missing", "ungated", "extra", "plan", "mission", "clock", "unknown_cleanup"]:
				await restore_case(bundle, mutation, mutation)
	cleanup()
	await get_tree().process_frame
	var passed := not checks.is_empty() and checks.all(func(row: Dictionary) -> bool: return row.passed)
	var report := {"phase": phase, "pid": OS.get_process_id(), "passed": passed, "checks": checks,
		"component_only": true, "full_world": false, "real_steam": false, "normal_gameplay": false,
		"snapshot_sha256": FileAccess.get_sha256(snapshot_path), "snapshot_producer_pid": int(bundle.get("producer_pid", 0))}
	var file := FileAccess.open(OS.get_environment("LSH_CAMPAIGN_FX_PARTITION_REPORT"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("CAMPAIGN_FX_PARTITION_QA ", phase, " checks=", checks.size(), " passed=", passed)
	get_tree().quit(0 if passed and file != null else 1)
