extends Node
## Isolated component QA, not full Battle/mission/Steam acceptance.
const State := preload("res://scripts/run_campaign_level_state.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const U := preload("res://scripts/unit.gd")
var checks: Array = []
var state := State.new()
var codec := Codec.new()
var owned: Array = []
const BOUNDARY := {"mission_token": "mission:fixture:1", "deferred_drained": true}
func _ready() -> void: call_deferred("run")
func check(label: String, condition: bool) -> void:
	checks.append({"label": label, "passed": condition})
	if not condition: push_error(label)
func unit(id: int) -> Variant:
	var u := U.new(); u.entity_id = id; u.process_mode = Node.PROCESS_MODE_DISABLED; u.set_block_signals(true); owned.append(u); return u
func external(field: String) -> Node:
	var node: Node = Button.new() if field in ["depart_button", "end_button"] else Node2D.new()
	node.process_mode = Node.PROCESS_MODE_DISABLED; node.set_block_signals(true)
	owned.append(node); return node
func wire_change(record: Dictionary, section: String, field: String, value: Variant) -> Dictionary:
	var result := record.duplicate(true)
	var payload: Dictionary = codec.decode(result.payload).value
	payload[section][field] = value
	result.payload = codec.encode(payload).value
	return result
func run() -> void:
	for level_id: String in State.SCRIPTS: test_level(level_id)
	for node: Node in owned: node.free()
	var passed := true
	for row: Dictionary in checks: passed = passed and row.passed
	passed = passed and checks.size() >= 96
	var report := {"passed": passed, "component_only": true, "checks": checks}
	var path := OS.get_environment("LSH_CAMPAIGN_STATE_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null: get_tree().quit(2); return
		file.store_string(JSON.stringify(report, "  ")); file.close()
	print("CAMPAIGN_LEVEL_STATE_QA ", JSON.stringify(report))
	get_tree().quit(0 if passed else 1)
func test_level(level_id: String) -> void:
	var level: Variant = State.SCRIPTS[level_id].new()
	var u: Variant = unit(1); var v: Variant = unit(2)
	var ids := {"1": u, "2": v}
	var refs := {}; var inverse := {}
	var names: Dictionary = state._names(level_id)
	for field: String in names:
		match names[field]:
			"unit": level.set(field, u)
			"units":
				var rows: Variant = level.get(field)
				rows.assign([u, null, v]); level.set(field, rows)
			"groups": level.set(field, [[u, null], [v], [u, v]])
			"named_units": level.set(field, {"chao_gai": u, "li_kui": v})
			"index_unit": level.set(field, {0: u, 2: v})
			"taverns": level.set(field, [{"u": u, "drunk": true}, {"u": v, "drunk": false}])
			"external", "externals":
				var node := external(field)
				var token := level_id + ":" + field
				refs[node] = token; inverse[token] = node
				level.set(field, [node, null] if names[field] == "externals" else node)
			"float": level.set(field, 1.25)
	if level_id == "level1":
		level.cargo_assignments = {0: "liu_tang", 2: "wu_yong"}
		level.cargo_ready = {0: true}; level.force_attempts = {2: 3}
		level.distraction_serial = 72; level.team_t = 1.5; level.delivered = 1
	if level_id == "level3": level.sent_sun = true; level.prisoners_freed = true; level.raids_sent = 2
	if level_id == "level4": level.waves[0].sent = true; level.waves[1].time += 45.0; level.broken_count = 3; level.lhm_killed = 2
	if level_id == "level5": level.fire_prepared = true; level.fire_lit = true; level.recovered = true
	if level_id == "level6": level.escort_orders = {1: 44, 2: 72}
	if level_id == "level7": level.charge_running = true; level.opening_serial = 8; level.step_serial = 8
	if level_id == "level8": level.signaled = true; level.signal_left = 31.25
	# Fixed production layouts are authored explicitly, independently of State's
	# validation table; remaining dynamic pools deliberately exercise empty/varied
	# sizes and the same nullable alias registry.
	var fixed: Dictionary = {
		"level1": {"bundles": 3}, "level2": {"caches": 2, "executioners": 2},
		"level3": {"prisoners": 7}, "level4": {"posts": 2, "riders": 12},
		"level5": {"posts": 2, "water_groups": [3, 5, 6], "land_groups": [4, 6, 8]},
		"level6": {"escorts": 2}, "level7": {"taverns": 4}, "level8": {"posts": 2}}
	for field: String in fixed[level_id]:
		var shape: Variant = fixed[level_id][field]
		var rows: Array = []
		if typeof(shape) == TYPE_INT:
			for i in range(shape):
				var entry: Variant = [u, v][i % 2] if field == "bundles" else [u, v, null][i % 3]
				rows.append({"u": entry, "drunk": i % 2 == 0} if field == "taverns" else entry)
		else:
			for count: int in shape:
				var group: Array = []
				for i in range(count): group.append([u, null, v][i % 3])
				rows.append(group)
		var typed: Variant = level.get(field)
		typed.assign(rows); level.set(field, typed)
	check(level_id + " inherited declarations fully classified", state.audit_declarations(level_id).ok)
	check(level_id + " explicit external boundary required", not state.capture(level, level_id, "fixture:v1", ids, 3, refs, {}).ok)
	var captured := state.capture(level, level_id, "fixture:v1", ids, 3, refs, BOUNDARY)
	check(level_id + " actual production class captures", captured.ok)
	if not captured.ok:
		print(level_id, " capture error ", captured); return
	var record: Dictionary = JSON.parse_string(JSON.stringify(captured.record))
	for field: String in fixed[level_id]:
		var empty := wire_change(record, "references", field, [])
		check(level_id + " empty fixed " + field + " rejected by validate", not state.validate(empty, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
		check(level_id + " empty fixed " + field + " rejected by restore", not state.restore(empty, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
		var payload: Dictionary = codec.decode(record.payload).value
		var longer: Array = payload.references[field].duplicate(true)
		longer.append(longer[0])
		check(level_id + " oversized fixed " + field + " rejected", not state.validate(wire_change(record, "references", field, longer), level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
		var current: Variant = level.get(field)
		var held: Array = current.duplicate()
		current.clear(); level.set(field, current)
		check(level_id + " capture rejects missing fixed " + field, not state.capture(level, level_id, "fixture:v1", ids, 3, refs, BOUNDARY).ok)
		current.assign(held); level.set(field, current)
	if level_id == "level5":
		for field: String in ["water_groups", "land_groups"]:
			var payload: Dictionary = codec.decode(record.payload).value
			var groups: Array = payload.references[field].duplicate(true)
			groups[1] = []
			check("gao empty inner " + field + " rejected", not state.validate(wire_change(record, "references", field, groups), level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	if level_id in ["level4", "level8"]:
		var payload: Dictionary = codec.decode(record.payload).value
		payload.references.escorts = []
		var dynamic_record := record.duplicate(true); dynamic_record.payload = codec.encode(payload).value
		check(level_id + " empty dynamic escorts legal", state.restore(dynamic_record, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	if level_id == "level1":
		check("missing tribute bundle is not a resumable empty slot", not state.validate(wire_change(record, "references", "bundles", ["1", null, "2"]), level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	var restored := state.restore(record, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token)
	check(level_id + " JSON roundtrip restores without deploy", restored.ok and not restored.get("deploy_or_start_called", true) and not restored.get("complete_world", true))
	if restored.ok:
		var recaptured := state.capture(restored.level, level_id, "fixture:v1", ids, 3, refs, BOUNDARY)
		check(level_id + " exact values aliases order and external identity", recaptured.ok and recaptured.record == captured.record)
		check(level_id + " new private RefCounted instance", restored.level != level and restored.level.get_script() == State.SCRIPTS[level_id])
	check(level_id + " wrong content rejected", not state.restore(record, level_id, "other", ids, 3, inverse, BOUNDARY.mission_token).ok)
	check(level_id + " wrong mission rejected", not state.restore(record, level_id, "fixture:v1", ids, 3, inverse, "other").ok)
	u.process_mode = Node.PROCESS_MODE_INHERIT
	check(level_id + " active Unit binding rejected", not state.restore(record, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.set_block_signals(false)
	check(level_id + " signal-enabled Unit binding rejected", not state.restore(record, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	u.set_block_signals(true)
	check(level_id + " unrelated production class rejected", not state.capture(level, "level8" if level_id != "level8" else "level3", "fixture:v1", ids, 3, refs, BOUNDARY).ok)
	check(level_id + " missing referenced Unit rejected", not state.restore(record, level_id, "fixture:v1", {"1": u}, 3, inverse, BOUNDARY.mission_token).ok)
	check(level_id + " allocator bound checked", not state.restore(record, level_id, "fixture:v1", ids, 2, inverse, BOUNDARY.mission_token).ok)
	var extra := wire_change(record, "values", "unreviewed_field", 1)
	check(level_id + " unknown saved field rejected", not state.validate(extra, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	for field: String in names:
		if names[field] == "float":
			var wrong := wire_change(record, "values", field, "1.25")
			check(level_id + " strict timer type rejected", not state.validate(wrong, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
			break
	if not refs.is_empty():
		check(level_id + " live external cannot silently disappear", not state.capture(level, level_id, "fixture:v1", ids, 3, {}, BOUNDARY).ok)
		check(level_id + " missing restored external rejected", not state.restore(record, level_id, "fixture:v1", ids, 3, {}, BOUNDARY.mission_token).ok)
		var aliased := refs.duplicate()
		var extra_node := external("extra")
		aliased[extra_node] = refs.values()[0]
		check(level_id + " duplicate external token rejected", not state.capture(level, level_id, "fixture:v1", ids, 3, aliased, BOUNDARY).ok)
		var existing: Node = inverse.values()[0]
		existing.process_mode = Node.PROCESS_MODE_INHERIT
		check(level_id + " active external binding rejected", not state.restore(record, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
		existing.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(existing)
		check(level_id + " mounted external binding rejected", not state.restore(record, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
		remove_child(existing)
	if level_id in ["level1", "level6", "level7"]:
		var bad_stage := wire_change(record, "values", "st", 999)
		check(level_id + " unknown stage rejected", not state.validate(bad_stage, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	if level_id in ["level4", "level5"]:
		var bad_wave := wire_change(record, "values", "waves", [{"time": 1.0, "sent": true, "warned": false}])
		check(level_id + " incomplete wave list rejected", not state.validate(bad_wave, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	if level_id == "level6":
		check("forest INF sentinel exact", restored.ok and restored.level.escort_player_target == Vector2.INF)
		var wrong := wire_change(record, "values", "escort_orders", {3: 1})
		check("historical escort order must precede allocator", not state.validate(wrong, level_id, "fixture:v1", ids, 3, inverse, BOUNDARY.mission_token).ok)
	if level_id == "level7":
		var pending := BOUNDARY.duplicate(); pending.deferred_drained = false
		check("duel deferred hit confirmation must drain", not state.capture(level, level_id, "fixture:v1", ids, 3, refs, pending).ok)
	if names.has("victory"):
		level.victory = true
		check(level_id + " terminal level rejected", not state.capture(level, level_id, "fixture:v1", ids, 3, refs, BOUNDARY).ok)
