extends SceneTree
## Actual Unit/Map/Battle objects; Battle never enters the tree or runs _ready.
## Root runner supplies RUN_RESTORE_QA_MANIFEST and owns process/source protections.
## No independent runner, persistent player file, or whole-Battle resume claim.
const VERSION := "defense_identity_bridge_v2"
var checks: Array = []
var owned: Array = []
var contexts: Array = []
var failures: Array = []
var manifest: Dictionary = {}
var report_path: String = ""
var manifest_ready: bool = false
var signal_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool) -> bool:
	checks.append({"label": label, "passed": passed})
	if not passed: failures.append(label)
	return passed

func _ok(label: String, result: Dictionary) -> bool:
	checks.append({"label": label, "passed": result.get("ok") == true,
		"code": result.get("code", ""), "field": result.get("field", "")})
	if result.get("ok") != true:
		failures.append(label)
		return false
	return true

func _on_signal(_sender: Variant) -> void:
	signal_count += 1

func _source_guard(label: String) -> void:
	for path in manifest.source_sha256:
		_check(label + " " + String(path), FileAccess.get_sha256(String(path)) == manifest.source_sha256[path])

func _finish(aborted: bool = false) -> void:
	for context: Variant in contexts: context.dispose()
	for object: Variant in owned:
		if is_instance_valid(object): object.free()
	paused = false
	if manifest_ready: _source_guard("source after")
	var report: Dictionary = {"suite": "defense-identity-bridge", "run_id": manifest.get("run_id", ""),
		"complete": not aborted, "passed": failures.is_empty() and not aborted,
		"checks": checks, "check_count": checks.size(), "failures": failures, "failed_count": failures.size(),
		"process_id": OS.get_process_id(), "actual_user_dir": OS.get_user_data_dir(),
		"source_sha256": manifest.get("source_sha256", {}), "battle_resume_tested": false,
		"scope": "Real off-tree Battle/Unit graph and standard Skirmish v2 JSON roundtrip; stable/native collision, allocator boundary, post-restore final cleanup consumption. No Battle._ready, full campaign, disk slot, activation, or cross-process gameplay restore."}
	if not report_path.is_empty():
		var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("[defense identity bridge QA] ", JSON.stringify(report))
	quit(0 if report.passed else 1)

func _shell(battle_script: Script, map_script: Script) -> Variant:
	var battle: Variant = battle_script.new()
	owned.append(battle)
	battle.world = Node2D.new()
	battle.map = map_script.new()
	battle.units_root = Node2D.new()
	battle.add_child(battle.world)
	battle.world.add_child(battle.map)
	battle.world.add_child(battle.units_root)
	battle.gold = 137
	battle.wood = 59
	return battle

func _unit(unit_script: Script, battle: Variant, name_text: String) -> Variant:
	var unit: Variant = unit_script.new()
	unit.name = name_text
	unit.key = name_text.to_lower()
	unit.display_name = name_text
	unit.visible = false
	unit.battle = battle
	unit.map = battle.map
	unit.set_physics_process(true)
	battle.units_root.add_child(unit)
	return unit

func _run() -> void:
	var path: String = OS.get_environment("RUN_RESTORE_QA_MANIFEST")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else null
	if typeof(data) != TYPE_DICTIONARY:
		_check("host manifest present", false)
		_finish(true)
		return
	manifest = data
	for key: String in ["run_id", "private_user", "report"]:
		if typeof(manifest.get(key)) != TYPE_STRING or manifest[key].is_empty():
			_check("host manifest " + key, false)
			_finish(true)
			return
	if typeof(manifest.get("source_sha256")) != TYPE_DICTIONARY or manifest.source_sha256.is_empty():
		_check("host source manifest", false)
		_finish(true)
		return
	for source_path in manifest.source_sha256:
		if typeof(source_path) != TYPE_STRING or typeof(manifest.source_sha256[source_path]) != TYPE_STRING:
			_check("host source entry", false)
			_finish(true)
			return
	report_path = manifest.report
	if not report_path.is_absolute_path() or FileAccess.file_exists(report_path):
		_check("new absolute report path", false)
		report_path = ""
		_finish(true)
		return
	manifest_ready = true
	_check("actual private user directory", OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower() == manifest.private_user.replace("\\", "/").simplify_path().to_lower())
	_source_guard("source before")
	if not failures.is_empty():
		_finish(true)
		return
	# All game classes load after Autoload initialization; no entry preloads.
	var us: Script = load("res://scripts/unit.gd")
	var bs: Script = load("res://scripts/battle.gd")
	var ms: Script = load("res://scripts/game_map.gd")
	var ls: Script = load("res://scripts/levels/skirmish.gd")
	var cs: Script = load("res://scripts/run_state_value_codec.gd")
	var gs: Script = load("res://scripts/run_unit_graph.gd")
	var ss: Script = load("res://scripts/run_unit_state.gd")
	var ns: Script = load("res://scripts/run_graph_identity.gd")
	var inv: Script = load("res://scripts/hero_inventory.gd")
	var ds: Script = load("res://scripts/run_defense_level_state.gd")
	var codec: Variant = cs.new()
	var graph: Variant = gs.new(ss, ns, cs, us, inv, bs, ms)
	var defense: Variant = ds.new(cs, ls, us)
	var source: Variant = _shell(bs, ms)
	var target: Variant = _shell(bs, ms)
	for battle: Variant in [source, target]:
		battle.map.init_map(60, 60, "marsh", ms.T.GRASS)
		battle.map.bake()
		battle.fog = false
		battle.ai_friendly = false
		if not _ok("fixed private gameplay seed", battle.configure_new_gameplay_rng({}, 5088120)):
			_finish(true)
			return
	var hall: Variant = _unit(us, source, "Hall")
	var foe: Variant = _unit(us, source, "Foe")
	var mine: Variant = _unit(us, source, "Mine")
	hall.key = "hall"
	hall.is_building = true
	hall.position = Vector2(600, 960)
	hall.entity_id = 41
	foe.key = "guan_dao"
	foe.faction = 1
	foe.position = Vector2(664, 896)
	# Deliberate collision: this stable key equals ANOTHER live Unit's ObjectID.
	foe.entity_id = hall.get_instance_id()
	mine.entity_id = 9007199254740993
	mine.is_resource = true
	mine.res_kind = "gold"
	mine.position = Vector2(500, 900)
	foe._lin_spear_target_id = hall.get_instance_id()
	source.next_entity_id = 9007199254740994
	source.units.assign([mine, foe, hall])
	var retired: Variant = _unit(us, source, "Retired")
	retired.entity_id = 9007199254740992
	retired.position = Vector2(200, 300)
	source.units.append(retired)
	source.units.erase(retired)
	retired.free()
	_check("historical sample Unit really retired before capture", not is_instance_valid(retired) and source.units_root.get_child_count() == 3)
	var ids: Dictionary = {mine: str(mine.entity_id), foe: str(foe.entity_id), hall: str(hall.entity_id)}
	_check("fixture stable/native collision is genuine", foe.entity_id == hall.get_instance_id() and foe.entity_id != foe.get_instance_id() and foe.entity_id > 41 and foe.entity_id < 9007199254740992)
	var level: Variant = ls.new()
	level.hall = hall
	level._started = true
	level._wave = 30
	level._wave_spawned = true
	level._wave_t = -0.25
	level._wavelist_cache = ls.WAVES.duplicate(true)
	level._final_cleanup_last_alive = 1
	level._final_cleanup_last_hp = foe.hp
	level._final_cleanup_quiet = 6.0
	level._final_cleanup_tick = 0.0
	# Already-active correction must continue after restore. No HUD setup needed.
	level._final_cleanup_active = true
	level._final_cleanup_positions = {foe.entity_id: Vector2(600, 896), 9007199254740992: Vector2(200, 300)}
	level.bind_gameplay_rng_owner(source)
	source.level = level
	var gc: Dictionary = graph.capture(source, ids, VERSION)
	if not _ok("capture actual stable Unit graph", gc):
		_finish(true)
		return
	contexts.append(gc.identity)
	var lc: Dictionary = defense.capture(level, VERSION, ids, source.next_entity_id)
	if not _ok("capture defense v2 using stable keys", lc):
		_finish(true)
		return
	var initial_payload: Dictionary = codec.decode(lc.record.payload)
	_check("collision remains literal stable decimal rather than native entity token", initial_payload.ok and initial_payload.value.cleanup_positions[0].target == str(foe.entity_id) and typeof(initial_payload.value.cleanup_positions[0].target) == TYPE_STRING)
	var bundle: Variant = JSON.parse_string(JSON.stringify({"graph": gc.value, "level": lc.record}))
	var gv: Dictionary = graph.validate(bundle.graph, VERSION)
	if not _ok("validate graph after real JSON stringify/parse", gv):
		_finish(true)
		return
	_check("next allocator and high stable identity preserve exact integers", gv.next_entity_id == 9007199254740994 and bundle.graph.next_entity_id == "9007199254740994" and gv.known_ids.has("9007199254740993"))
	if not _ok("validate matching defense using graph-validated allocator", defense.validate(bundle.level, VERSION, gv.known_ids, gv.next_entity_id)):
		_finish(true)
		return
	# Unknown live registry identities must reject; historical position samples
	# below next are intentionally allowed because Units can die between samples.
	var bad_known: Dictionary = gv.known_ids.duplicate()
	bad_known[str(gv.next_entity_id)] = true
	_check("unknown current registry ID at next rejects", defense.validate(bundle.level, VERSION, bad_known, gv.next_entity_id).get("code") == "ENTITY_COUNTER_BOUND")
	for value: Variant in [str(gv.next_entity_id), "9223372036854775807", "9223372036854775808", "0", "01", "-1", 3, 3.0, {"kind": "entity", "id": "41"}]:
		var bad: Dictionary = _position_record(codec, bundle.level, value)
		_check("invalid or unallocated stable position key rejects " + str(value), defense.validate(bad, VERSION, gv.known_ids, gv.next_entity_id).get("ok") == false)
	var dup: Dictionary = _position_record(codec, bundle.level, str(foe.entity_id), true)
	_check("duplicate stable sample rejects", defense.validate(dup, VERSION, gv.known_ids, gv.next_entity_id).get("code") == "DUPLICATE_POSITION_ID")
	var old_schema: Dictionary = bundle.level.duplicate(true)
	old_schema.schema = "standard_defense_level_v1"
	_check("old native-token schema refuses silent migration", defense.validate(old_schema, VERSION, gv.known_ids, gv.next_entity_id).get("code") == "SCHEMA")
	var saved_positions: Dictionary = level._final_cleanup_positions.duplicate()
	level._final_cleanup_positions = {source.next_entity_id: Vector2.ZERO}
	_check("live capture rejects a never-allocated stable key", defense.capture(level, VERSION, ids, source.next_entity_id).get("code") == "POSITION_COUNTER_BOUND")
	level._final_cleanup_positions = saved_positions
	var bad_ids: Dictionary = ids.duplicate()
	bad_ids[foe] = str(foe.get_instance_id())
	_check("native ObjectID supplied as Unit registry identity rejects", defense.capture(level, VERSION, bad_ids, source.next_entity_id).get("code") == "REGISTRY_ENTITY_FIELD")
	var prepared: Dictionary = graph.prepare(bundle.graph, VERSION, target, target.map)
	if not _ok("prepare detached real Unit graph", prepared):
		_finish(true)
		return
	contexts.append(prepared.identity)
	owned.append_array(prepared.units_in_root_order)
	var lr: Dictionary = defense.restore(bundle.level, VERSION, prepared.id_to_unit, gv.next_entity_id)
	if not _ok("restore standard level with stable identity graph", lr):
		_finish(true)
		return
	_check("restore creates no allocator or deployment side effects", target.next_entity_id == 1 and target.units.is_empty() and target.units_root.get_child_count() == 0 and not lr.deploy_or_start_called)
	_check("historical high stable key survives without native tombstone", lr.level._final_cleanup_positions.has(9007199254740992) and lr.level._final_cleanup_positions == saved_positions)
	var new_hall: Variant = prepared.id_to_unit["41"]
	var new_foe: Variant = prepared.id_to_unit[str(foe.entity_id)]
	_check("collision does not select the other live unit", lr.level.hall == new_hall and lr.level._final_cleanup_positions.has(new_foe.entity_id) and new_hall.get_instance_id() != hall.get_instance_id() and new_foe.entity_id != new_hall.entity_id)
	_check("real native target domain still remaps to new ObjectID", new_foe._lin_spear_target_id == new_hall.get_instance_id() and new_foe._lin_spear_target_id != new_hall.entity_id)
	# Outer commit demonstration only: allocator before any later spawn, all
	# nodes attached off-tree, native tombstones released after both graph binds.
	target.next_entity_id = prepared.pending_battle_fields.next_entity_id
	for unit: Variant in prepared.units_in_root_order:
		target.units_root.add_child(unit)
	target.units.assign(prepared.active_units)
	target.level = lr.level
	target.level.bind_gameplay_rng_owner(target)
	prepared.identity.release_tombstones()
	var again: Dictionary = defense.capture(target.level, VERSION, prepared.object_to_id, target.next_entity_id)
	_check("defense JSON recapture exactly equals source", again.get("ok") == true and JSON.stringify(again.record) == JSON.stringify(bundle.level))
	var first_root: Array = target.units_root.get_children()
	for battle: Variant in [source, target]:
		battle.level.process(battle, 0.1)
	_check("restored stable position is consumed as movement progress", source.level._final_cleanup_quiet == 0.0 and target.level._final_cleanup_quiet == 0.0)
	_check("historical sample expires through real next sample", not target.level._final_cleanup_positions.has(9007199254740992) and target.level._final_cleanup_positions == source.level._final_cleanup_positions)
	_check("real active cleanup reapplies identical attack-move", new_foe._state == us.ST_AMOVE and foe._state == us.ST_AMOVE and new_foe._amove_dest == new_hall.position and new_foe._path == foe._path and new_foe.get_meta("final_cleanup_stall") == foe.get_meta("final_cleanup_stall"))
	for step in range(3):
		for battle: Variant in [source, target]:
			battle.level.process(battle, 2.0)
		_check("continued quiet sample matches source " + str(step), target.level._final_cleanup_quiet == 2.0 * float(step + 1) and source.level._final_cleanup_quiet == target.level._final_cleanup_quiet and target.level._final_cleanup_positions == source.level._final_cleanup_positions)
	_check("consumer preserves allocator and root order", target.next_entity_id == gv.next_entity_id and target.units_root.get_children() == first_root)
	_check("seed remains fixed and cleanup draws no gameplay randomness", source._gameplay_rng._calls == 0 and target._gameplay_rng._calls == 0 and source._gameplay_rng._rng.state == target._gameplay_rng._rng.state)
	# A second full graph/level JSON boundary after actual consumers ran.
	var after_graph: Dictionary = graph.capture(target, prepared.object_to_id, VERSION, prepared.identity)
	var after_level: Dictionary = defense.capture(target.level, VERSION, prepared.object_to_id, target.next_entity_id)
	if not _ok("capture graph after cleanup consumers", after_graph) or not _ok("capture level after cleanup consumers", after_level):
		_finish(true)
		return
	var second_wire: Variant = JSON.parse_string(JSON.stringify({"graph": after_graph.value, "level": after_level.record}))
	var second_gv: Dictionary = graph.validate(second_wire.graph, VERSION)
	if not _ok("second graph wire validates", second_gv):
		_finish(true)
		return
	_check("second level wire validates against same allocator", defense.validate(second_wire.level, VERSION, second_gv.known_ids, second_gv.next_entity_id).get("ok") == true)
	# Actual allocator consumer, after installation, must issue exactly next.
	target._defs = {"bridge_new": {"building": true, "hp": 100, "name": "Bridge allocator fixture"}}
	var spawned: Variant = target.spawn_unit("bridge_new", 0, Vector2(400, 400))
	_check("actual post-restore spawn consumes exact next once", spawned != null and spawned.entity_id == 9007199254740994 and target.next_entity_id == 9007199254740995 and target.units.size() == 4)
	_check("Battle ready and full gameplay never started", not source.is_inside_tree() and not target.is_inside_tree() and source.gold == 137 and target.gold == 137 and source.gameplay_rng_fault().is_empty() and target.gameplay_rng_fault().is_empty())
	_finish()

func _position_record(codec: Variant, record: Dictionary, key: Variant, duplicate: bool = false) -> Dictionary:
	var out: Dictionary = record.duplicate(true)
	var decoded: Dictionary = codec.decode(out.payload)
	if duplicate:
		decoded.value.cleanup_positions.append(decoded.value.cleanup_positions[0].duplicate(true))
	else:
		decoded.value.cleanup_positions[0].target = key
	var encoded: Dictionary = codec.encode(decoded.value)
	out.payload = encoded.value
	return out
