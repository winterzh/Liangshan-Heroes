extends Node
## Exact Battle/Map/Unit/Level3 scripts; only HUD rendering is replaced locally.
## A detached component graph is not an installed/resumed campaign world.
const Graph := preload("res://scripts/run_unit_graph.gd")
const State := preload("res://scripts/run_unit_state.gd")
const Identity := preload("res://scripts/run_graph_identity.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const U := preload("res://scripts/unit.gd")
const B := preload("res://scripts/battle.gd")
const M := preload("res://scripts/game_map.gd")
const Inventory := preload("res://scripts/hero_inventory.gd")
const Zhu := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const Classic := preload("res://scripts/levels/skirmish.gd")
const LevelState := preload("res://scripts/run_campaign_level_state.gd")
const Mission := preload("res://scripts/campaign_mission.gd")
const Factory := preload("res://scripts/run_level3_world_factory.gd")
const CONTENT := "fixture:level3_unit_graph:v1"
const TRUSTED := {"ok": true, "save_eligible": true, "content_version": CONTENT,
	"engine_binary_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
const TOKEN := "mission:level3:unit_graph_qa"
const BOUNDARY := {"mission_token": TOKEN, "deferred_drained": true}
var codec := Codec.new()
var graph := Graph.new(State, Identity, Codec, U, Inventory, B, M, Graph.ZHU_CONTEXT)
var checks: Array = []
var owners: Array = []
var snapshots: Array = []

class QuietHUD extends HUD:
	var seen_messages: Array = []
	func _ready() -> void: pass
	func update_selection_panel(_sel: Array) -> void: pass
	func refresh_command() -> void: pass
	func show_message(text: String, _dur := 3.5, _quiet_in_full_auto := false) -> void:
		seen_messages.append(text)

func _ready() -> void:
	var profile := OS.get_environment("LSH_LEVEL3_UNIT_GRAPH_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("LEVEL3_UNIT_GRAPH_QA PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: push_error(label)

func make_graph(context: Dictionary) -> RefCounted:
	return Graph.new(State, Identity, Codec, U, Inventory, B, M, context)

func shell() -> B:
	var owner := B.new()
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	owner.world = Node2D.new(); owner.add_child(owner.world)
	owner.map = M.new(); owner.world.add_child(owner.map)
	owner.map.init_map(64, 56, "village", M.T.GRASS)
	Zhu.new().paint_map(owner.map); owner.map.bake()
	owner.units_root = Node2D.new(); owner.world.add_child(owner.units_root)
	owner.fx_root = Node2D.new(); owner.world.add_child(owner.fx_root)
	owner.hud = QuietHUD.new(); owner.add_child(owner.hud); owner.hud.battle = owner
	owner.phase = B.Phase.FIGHT; owner.economy = true; owner.fog = false
	owner.gold = 300; owner.wood = 200; owner.current_age = 3; owner.pop_cap = 20
	owner._official_context = Graph.ZHU_CONTEXT.duplicate()
	var runtime: Dictionary = Factory.prepare_runtime(TRUSTED)
	check("installed Level3 definitions prepared without deployment", runtime.ok and not runtime.get("deploy_or_start_called", true))
	if runtime.ok:
		owner._defs = runtime.runtime.defs; owner._abilities = runtime.runtime.abilities; owner._items = runtime.runtime.items
	owner.level = Zhu.new()
	check("private actual Battle RNG initialized", owner.configure_new_gameplay_rng(TRUSTED, 731).ok)
	owners.append(owner)
	return owner

func source_fixture() -> B:
	var owner := shell()
	owner.mission = Mission.new(owner)
	owner.mission.configure_campaign(owner.level.campaign_core_goal(), owner.level.campaign_story_goals(), owner.level.story_contract_version())
	# Only normal source construction deploys. prepare/restore below never does.
	owner.level.deploy(owner); owner.level.on_start(owner)
	check("normal Level3 deployment produced seven prisoners", owner.level.prisoners.size() == 7 and owner.units.size() > 40)
	check("normal source has no RNG failure", owner.gameplay_rng_fault().is_empty())
	return owner

func object_registry(owner: B) -> Dictionary:
	var result := {}
	for unit: Node in owner.units_root.get_children(true): result[unit] = str(unit.entity_id)
	return result

func snapshot_case(label: String, owner: B) -> Dictionary:
	var result: Dictionary = graph.capture(owner, object_registry(owner), CONTENT, null, BOUNDARY)
	check(label + " actual Graph.capture", result.ok)
	if not result.ok: print(label, " ", result); return {}
	result.identity.dispose()
	var saved := {"name": label, "graph": result.value, "level": result.level_record}
	snapshots.append(saved)
	roundtrip(saved, label)
	return saved

func without_activation(wire: Dictionary) -> Dictionary:
	var copy := wire.duplicate(true)
	for record: Dictionary in copy.records:
		var payload: Dictionary = codec.decode(record.payload).value
		payload.node.activation = {} # prepare intentionally keeps every Unit gated.
		record.payload = codec.encode(payload).value
	return copy

func roundtrip(saved: Dictionary, label: String) -> void:
	var indexed: Dictionary = graph.validate_index(saved.graph, CONTENT)
	check(label + " structural index before role decoding", indexed.ok and indexed.get("index_only", false))
	var checked: Dictionary = graph.validate(saved.graph, CONTENT, saved.level, TOKEN)
	check(label + " all roles and Unit records validated", checked.ok)
	if not checked.ok: print(label, " ", checked); return
	var destination := shell()
	var before: int = destination.units_root.get_child_count(true)
	var prepared: Dictionary = graph.prepare(saved.graph, CONTENT, destination, destination.map, saved.level, TOKEN)
	check(label + " actual Graph.prepare", prepared.ok)
	if not prepared.ok: print(label, " ", prepared); return
	check(label + " prepare leaves destination and allocator untouched", destination.units_root.get_child_count(true) == before and destination.units.is_empty() and destination.next_entity_id == 1)
	var detached := true
	var ordered: Array = []
	for unit: Node in prepared.units_in_root_order:
		detached = detached and not unit.is_inside_tree() and unit.get_parent() == null and unit.is_blocking_signals() and unit.process_mode == Node.PROCESS_MODE_DISABLED
		ordered.append(str(unit.entity_id))
	check(label + " every allocated Unit detached disabled blocked", detached)
	check(label + " root order preserved", ordered == saved.graph.root_order)
	ordered.clear()
	for unit: Node in prepared.active_units: ordered.append(str(unit.entity_id))
	check(label + " active order preserved separately", ordered == saved.graph.active_order)
	var level: Dictionary = LevelState.new().restore(saved.level, "level3", CONTENT, prepared.id_to_unit, prepared.pending_battle_fields.next_entity_id, {}, TOKEN)
	check(label + " Level references bind to prepared Units without deployment", level.ok and not level.get("deploy_or_start_called", true))
	if not level.ok:
		prepared.identity.dispose()
		for unit: Node in prepared.units_in_root_order: unit.free()
		return
	destination.level = level.level
	# Test-only ownership installation; no root clock, HUD or world activation.
	for unit: Node in prepared.units_in_root_order: destination.units_root.add_child(unit)
	destination.units.assign(prepared.active_units)
	destination.next_entity_id = prepared.pending_battle_fields.next_entity_id
	prepared.identity.release_tombstones()
	var recaptured: Dictionary = graph.capture(destination, prepared.object_to_id, CONTENT, prepared.identity, BOUNDARY)
	check(label + " privately bound graph can be captured again", recaptured.ok)
	if recaptured.ok:
		check(label + " all Unit data and identities roundtrip except intentional activation gate", without_activation(recaptured.value) == without_activation(saved.graph))
		check(label + " exact Level record roundtrip", recaptured.level_record == saved.level)
	else: print(label, " recapture ", recaptured)
	check(label + " preparation replays no mission rewards or spawn", destination.hud.seen_messages.is_empty() and destination.mission == null and destination.units_root.get_child_count(true) == saved.graph.root_order.size() and destination.kills == 0)
	prepared.identity.dispose()

func changed_unit(saved: Dictionary, id: String, section: String, field: String, value: Variant) -> Dictionary:
	var result: Dictionary = saved.duplicate(true)
	for record: Dictionary in result.graph.records:
		if record.entity_id != id: continue
		var payload: Dictionary = codec.decode(record.payload).value
		payload[section][field] = {"kind": "value", "value": value} if section == "metadata" else value; record.payload = codec.encode(payload).value
	return result

func changed_level(saved: Dictionary, field: String, value: Variant) -> Dictionary:
	var result: Dictionary = saved.duplicate(true)
	var payload: Dictionary = codec.decode(result.level.payload).value
	payload.references[field] = value; result.level.payload = codec.encode(payload).value
	return result

func reject_saved(label: String, saved: Dictionary) -> void:
	var destination := shell()
	var checked: Dictionary = graph.validate(saved.graph, CONTENT, saved.level, TOKEN)
	var prepared: Dictionary = graph.prepare(saved.graph, CONTENT, destination, destination.map, saved.level, TOKEN)
	check(label + " validate rejects", not checked.ok)
	check(label + " prepare rejects before any Unit allocation", not prepared.ok and prepared.get("created_count", -1) == 0 and prepared.get("freed_count", -1) == 0)
	check(label + " destination remains empty", destination.units.is_empty() and destination.units_root.get_child_count(true) == 0 and destination.next_entity_id == 1)
	if prepared.ok:
		prepared.identity.dispose()
		for unit: Node in prepared.units_in_root_order: unit.free()

func negatives(base: Dictionary, captured: Dictionary, retired: Dictionary, dead: Dictionary, owner: B) -> void:
	var hu_id := str(owner.level.hu.entity_id)
	var side_id := str(owner.level.side_gate.entity_id)
	var captive_id := str(owner.level.prisoners[0].entity_id)
	var dead_id := str(owner.level.prisoners[1].entity_id)
	var plain_id := str(owner.level.song.entity_id)
	var refs: Dictionary = codec.decode(base.level.payload).value.references
	reject_saved("unknown role id", changed_level(base, "hu", "999999"))
	reject_saved("duplicate role id", changed_level(base, "side_gate", refs.gate))
	reject_saved("wrong real hero used as Hu", changed_level(base, "hu", plain_id))
	var swapped: Array = refs.prisoners.duplicate(); var first: Variant = swapped[0]; swapped[0] = swapped[1]; swapped[1] = first
	reject_saved("prisoner slot identity swapped", changed_level(base, "prisoners", swapped))
	reject_saved("prisoner dimension shortened", changed_level(base, "prisoners", refs.prisoners.slice(0, 6)))
	reject_saved("Hu missing from Level record", changed_level(base, "hu", null))
	reject_saved("neutral faction ordinary hero", changed_unit(base, plain_id, "values", "faction", 2))
	reject_saved("unregistered captured hero", changed_unit(base, plain_id, "values", "story_outcome", "captured"))
	reject_saved("captive gained worker identity", changed_unit(base, captive_id, "values", "is_worker", true))
	reject_saved("Hu gained summon identity", changed_unit(base, hu_id, "values", "is_summon", true))
	reject_saved("captive wrong faction", changed_unit(base, captive_id, "values", "faction", 0))
	reject_saved("captive garrisoned", changed_unit(base, captive_id, "values", "garrisoned", true))
	reject_saved("Hu wrongly marked as captive", changed_unit(captured, hu_id, "values", "is_captive", true))
	reject_saved("captured Hu has pending damage", changed_unit(captured, hu_id, "values", "_pending_done", false))
	reject_saved("captured Hu retained own attack target", changed_unit(captured, hu_id, "references", "_target", {"state": "entity", "id": plain_id}))
	reject_saved("retired gate became visible", changed_unit(retired, side_id, "node", "visible", true))
	reject_saved("retired gate blocks navigation", changed_unit(retired, side_id, "metadata", "footprint_blocked", true))
	var removed: Dictionary = captured.duplicate(true); removed.graph.active_order.erase(hu_id)
	reject_saved("captured Hu removed from active registry", removed)
	removed = retired.duplicate(true); removed.graph.active_order.erase(side_id)
	reject_saved("retired side gate removed from active registry", removed)
	removed = dead.duplicate(true); removed.graph.active_order.append(dead_id)
	reject_saved("dead captive wrongly active", removed)
	removed = base.duplicate(true); removed.graph.records[0].schema = State.SCHEMA
	reject_saved("mixed classic Unit schema", removed)
	for invalid: Variant in [1, [], {}]:
		removed = base.duplicate(true); removed.graph.records[0].entity_id = invalid
		reject_saved("bad Unit entity id Variant " + str(typeof(invalid)), removed)
	removed = base.duplicate(true); removed.level.mission_token = "mission:wrong"
	reject_saved("wrong Mission token", removed)
	check("classic reader refuses chapter graph", not make_graph(Graph.CLASSIC_CONTEXT).validate(base.graph, CONTENT).ok)
	for context: Dictionary in [{"mode": "campaign", "level_id": "level2", "waves": 0}, {"mode": "scenario", "level_id": "level3", "waves": 0}, {"mode": "campaign", "level_id": "level3", "waves": 30}, {"mode": "campaign", "level_id": "level3", "waves": 0, "roles": {}}]:
		check("unknown official context refused " + str(context), not make_graph(context).validate(base.graph, CONTENT, base.level, TOKEN).ok)
	check("canonical JSON numeric context accepted", make_graph({"mode": "campaign", "level_id": "level3", "waves": 0.0}).validate(base.graph, CONTENT, base.level, TOKEN).ok)
	var wrong_script := Graph.new(State, Identity, Codec, Classic, Inventory, B, M, Graph.ZHU_CONTEXT)
	check("chapter refuses injected replacement Unit script", not wrong_script.validate(base.graph, CONTENT, base.level, TOKEN).ok)
	var active: Array = owner.units.duplicate()
	owner.units.erase(owner.level.hu)
	check("capture rejects inconsistent live active membership", not graph.capture(owner, object_registry(owner), CONTENT, null, BOUNDARY).ok)
	owner.units.assign(active)
	check("capture rejects malformed boundary before Variant comparison", not graph.capture(owner, object_registry(owner), CONTENT, null, {"mission_token": TOKEN, "deferred_drained": []}).ok)
	var saved_level: Variant = owner.level; owner.level = Classic.new()
	check("capture rejects non-installed Level3 source", not graph.capture(owner, object_registry(owner), CONTENT, null, BOUNDARY).ok)
	owner.level = saved_level

func classic_control() -> void:
	var owner := shell()
	owner.level = Classic.new()
	var unit: U = owner.spawn_at("liang_dao", 0, Vector2i(50, 25))
	var classic: Variant = make_graph(Graph.CLASSIC_CONTEXT)
	var captured: Dictionary = classic.capture(owner, object_registry(owner), CONTENT)
	check("default classic capture/schema unchanged", captured.ok and captured.get("value", {}).get("schema") == Graph.SCHEMA)
	if not captured.ok: print(captured); return
	check("default classic validate unchanged", classic.validate(captured.value, CONTENT).ok)
	var destination := shell()
	var restored: Dictionary = classic.prepare(captured.value, CONTENT, destination, destination.map)
	check("default classic prepare unchanged", restored.ok)
	if restored.ok:
		restored.identity.dispose()
		for node: Node in restored.units_in_root_order: node.free()
	unit.is_captive = true
	check("default classic still rejects chapter captive state", not classic.capture(owner, object_registry(owner), CONTENT).ok)
	captured.identity.dispose()

func clean_owner(owner: B) -> void:
	if owner.mission != null and Localize.language_changed.is_connected(owner.mission._on_language_changed):
		Localize.language_changed.disconnect(owner.mission._on_language_changed)
	unbind_branch(owner)
	owner.mission = null
	owner.free()

func unbind_branch(node: Node) -> void:
	Localize.unbind(node)
	for child: Node in node.get_children(true): unbind_branch(child)

func run() -> void:
	var phase := OS.get_environment("LSH_LEVEL3_UNIT_GRAPH_PHASE")
	if phase == "restart":
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LSH_LEVEL3_UNIT_GRAPH_SNAPSHOT")))
		check("restart reads synthetic saved graph collection", typeof(data) == TYPE_DICTIONARY and data.get("synthetic_fixture") == true and data.get("snapshots", []).size() >= 7)
		if typeof(data) == TYPE_DICTIONARY:
			var producer: Variant = data.get("producer_pid")
			check("restart fixture was produced by a different native process", typeof(producer) in [TYPE_INT, TYPE_FLOAT] and producer > 0 and int(producer) != OS.get_process_id())
			for saved: Dictionary in data.get("snapshots", []): roundtrip(saved, "restart " + String(saved.name))
	else:
		classic_control()
		var owner := source_fixture()
		var base := snapshot_case("deployed", owner)
		if base.is_empty(): finish(phase); return
		var enemy: U = owner.level.hu
		var captive: U = owner.level.prisoners[0]
		captive.take_damage(3.0, enemy, false, true)
		check("real enemy damage clears captive passive without freeing", captive.is_captive and not captive.passive and captive.stance == U.STANCE_PASSIVE and captive.hp > 0.0)
		var wounded := snapshot_case("wounded_captive", owner)
		enemy.hp = 0.5
		snapshot_case("fractional_hp_hu", owner)
		# Create real queued/taunt state while Hu is still an unresolved target.
		# Resolution stops immediate attackers, but this mover's queued order stays.
		var other: U = owner.level.song
		other.apply_taunt(enemy, 2.0)
		other.order_move(owner.map.cell_to_world(Vector2i(49, 24)))
		other.order_attack(enemy, true, true)
		other._chase_last_id = enemy.get_instance_id()
		var kills: int = owner.kills
		enemy.take_damage(100.0, owner.level.song, false, true)
		check("real lethal Hu capture stays active hostile noncaptive", enemy.story_outcome == "captured" and enemy.hp >= 1.0 and enemy.faction == 1 and not enemy.is_captive and owner.units.has(enemy))
		check("capture produces Mission event without kill", owner.mission.events.has("zhu_hu_captured") and owner.kills == kills)
		check("real resolution preserves another mover's queued and taunt references", other._queue.size() == 1 and other._queue[0].target == enemy and other._taunt_src == enemy and other._target == null)
		enemy.visible = false # Fog/culling permits invisible captured Hu.
		var captured := snapshot_case("captured_hu_delayed_refs", owner)
		var prisoner: U = owner.level.prisoners[1]
		var attacker: U = owner.level.resource_guards[0]
		prisoner.take_damage(prisoner.hp + 1.0, attacker, false, true)
		check("real captive death stays root but leaves active", prisoner.hp == 0.0 and prisoner._dying and prisoner.is_captive and not prisoner.passive and not owner.units.has(prisoner) and prisoner.get_parent() == owner.units_root)
		var dead := snapshot_case("dead_nonessential_captive", owner)
		owner.level.on_mission_action(owner, "zhu_rts_rescue", owner.level.song)
		check("real rescue skips dead captive and frees survivors", owner.level.prisoners_freed and prisoner.is_captive and prisoner.faction == 2 and not captive.is_captive and not captive.is_hero and captive.faction == 0)
		captive.order_move(owner.map.cell_to_world(Vector2i(49, 24)))
		check("freed evacuee accepts a real move command", not captive.passive and captive.has_target() == false and captive._state != U.ST_IDLE)
		snapshot_case("rescued_moving_with_dead_captive", owner)
		captive.position = owner.level.hall.position
		captive.order_garrison(owner.level.hall); captive._do_garrison(0.0)
		check("freed evacuee can enter a real garrison and stays active", captive.garrisoned and not captive.visible and captive.garrison_holder == owner.level.hall and owner.level.hall.passengers.has(captive) and owner.units.has(captive))
		snapshot_case("rescued_garrisoned", owner)
		owner.level.sun = owner.spawn_at("sun_li", 0, Vector2i(25, 18)); owner.level.sent_sun = true
		owner.level.on_mission_action(owner, "zhu_rts_inside", owner.level.sun)
		check("real inside action retires gate without removing active Unit", owner.level.inside_open and owner.level.side_gate.story_outcome == "retreated" and not owner.level.side_gate.visible and owner.units.has(owner.level.side_gate) and not owner.level.side_gate.get_meta("footprint_blocked"))
		var retired := snapshot_case("retired_side_gate", owner)
		if not wounded.is_empty() and not captured.is_empty() and not dead.is_empty() and not retired.is_empty(): negatives(base, captured, retired, dead, owner)
		var gate: U = owner.level.gate
		gate.take_damage(gate.hp + 1.0, null, false, true)
		check("real destroyed gate queues deletion and records breach", gate.is_queued_for_deletion() and owner.level.main_breached)
		check("capture refuses undrained queued gate", not graph.capture(owner, object_registry(owner), CONTENT, null, BOUNDARY).ok)
		await get_tree().process_frame
		await get_tree().process_frame
		check("queued gate actually deleted before new capture", not is_instance_valid(gate))
		snapshot_case("destroyed_main_gate_null_reference", owner)
		var file := FileAccess.open(OS.get_environment("LSH_LEVEL3_UNIT_GRAPH_SNAPSHOT"), FileAccess.WRITE)
		check("synthetic cross-process fixture can be written", file != null)
		if file != null:
			file.store_string(JSON.stringify({"synthetic_fixture": true, "component_only": true, "producer_pid": OS.get_process_id(), "snapshots": snapshots})); file.close()
	finish(phase)

func finish(phase: String) -> void:
	for owner: B in owners: clean_owner(owner)
	owners.clear()
	var passed := true
	for row: Dictionary in checks: passed = passed and row.passed
	var snapshot_path := OS.get_environment("LSH_LEVEL3_UNIT_GRAPH_SNAPSHOT")
	var snapshot_sha := ""
	var snapshot_producer_pid := 0
	if FileAccess.file_exists(snapshot_path):
		snapshot_sha = FileAccess.get_sha256(snapshot_path)
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
		if typeof(saved) == TYPE_DICTIONARY and typeof(saved.get("producer_pid")) in [TYPE_INT, TYPE_FLOAT]:
			snapshot_producer_pid = int(saved.producer_pid)
	var report := {"passed": passed, "phase": phase, "checks": checks, "component_only": true, "full_world": false, "real_steam": false,
		"pid": OS.get_process_id(), "snapshot_sha256": snapshot_sha, "snapshot_producer_pid": snapshot_producer_pid}
	var file := FileAccess.open(OS.get_environment("LSH_LEVEL3_UNIT_GRAPH_REPORT"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("LEVEL3_UNIT_GRAPH_QA ", phase, " checks=", checks.size(), " passed=", passed)
	get_tree().quit(0 if passed and file != null else 1)
