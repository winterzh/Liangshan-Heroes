extends Node
## External UNEXECUTED independent components; actual A source and journal only.
## No Core.prepare/capture, Unit/Battle allocation, ticks or slot/journal writes.
const INPUT_SCHEMA := "daming_campaign_component_inputs_v1"
const REPORT_SCHEMA := "daming_campaign_component_report_v1"
const SLOT_ROOT := "user://continue/v1"
const HANDOFF_A := "user://daming_safe_retreat_v25/handoff_A.json"
const ROUTES := ["source", "json"]
const FIXTURES := ["a_report", "a_handoff", "a_packet", "a_world", "a_slot"]
const SOURCE_PATHS := ["res://scripts/run_battle_world_core.gd","res://scripts/run_level8_unit_contract.gd","res://scripts/run_unit_state.gd","res://scripts/run_unit_graph.gd","res://scripts/run_graph_identity.gd","res://scripts/run_campaign_level_state.gd","res://scripts/run_campaign_mission_state.gd","res://scripts/run_campaign_presentation_state.gd","res://scripts/run_battle_root_state.gd","res://scripts/run_state_value_codec.gd","res://scripts/run_slot_store.gd","res://scripts/run_snapshot_store.gd","res://scripts/run_local_lifecycle.gd","res://scripts/run_cast_flow_state.gd","res://scripts/run_item_cast_flow_state.gd","res://scripts/unit.gd","res://scripts/hero_inventory.gd","res://scripts/run_official_restore_profile.gd","res://scripts/battle.gd","res://scripts/campaign.gd","res://scripts/continue_flow.gd","res://scripts/menu.gd","res://scripts/run_campaign_cfg_transaction.gd","res://scripts/run_campaign_cfg_values.gd","res://scripts/run_campaign_local_lifecycle.gd","res://scripts/run_campaign_progress_coordinator.gd","res://scripts/run_campaign_progress_gate.gd","res://scripts/run_campaign_progress_intent.gd","res://scripts/run_campaign_progress_projection.gd","res://scripts/run_campaign_startup_scan.gd","res://scripts/run_world_session.gd","res://scripts/steam_cloud.gd"]
var Core: Script
var Store: Script
var Codec: Script
var Profiles: Script
var UnitState: Script
var Contract: Script
var Identity: Script
var LevelState: Script
var Lifecycle: Script
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var manifest: Dictionary = {}
var base: Dictionary = {}
var base_raw := ""
var role := ""
var safe_id := ""
var other_id := ""
var gate_id := ""
var nonce := ""
var output := ""
var checks: Array = []
var rows: Array = []
var positives: Array = []
var provenance: Array = []
var evidence: Array = []
var specs: Array = []
var fixture_ready := false
var finished := false
var proof_before := {}
var fingerprint_supported := true
var evidence_serial := 0
var audit_leaf_cache: Dictionary = {}

func _brief(v: Variant) -> Dictionary:
	var out := {"type": type_string(typeof(v))}
	if v is Dictionary:
		for f: String in ["code", "field", "path", "section"]:
			if typeof(v.get(f)) == TYPE_STRING: out[f] = v[f].left(200)
		out["ok"] = v.get("ok", "missing")
	else: out["summary"] = str(v).left(200)
	return out

func check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"label": label, "passed": passed, "detail": null if passed else _brief(detail)})
	if not passed: print("V25_COMPONENT_FAIL ", label, " ", _brief(detail))
	return passed

func _bits(value: float, width := 8) -> String:
	var bytes := PackedByteArray()
	bytes.resize(width)
	if width == 8: bytes.encode_double(0, value)
	else: bytes.encode_float(0, value)
	return bytes.hex_encode()

func _audit_leaf_key(v: Variant) -> String:
	var kind: int = typeof(v)
	if kind == TYPE_FLOAT: return str(kind)+":"+_bits(v)
	if kind in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME]:
		var exact: String = str(v)
		if exact.length()<=256: return str(kind)+":"+exact
	return ""

func _typed(v: Variant) -> Variant:
	# Cache only immutable scalar audit leaves, never input containers or validators.
	var key: String = _audit_leaf_key(v)
	if not key.is_empty() and audit_leaf_cache.has(key): return audit_leaf_cache[key]
	var value: Variant = _typed_uncached(v)
	if not key.is_empty() and audit_leaf_cache.size()<8192: audit_leaf_cache[key]=value
	return value

func _typed_uncached(v: Variant) -> Variant:
	# Audit representation, never a validator. Preserve nonfinite installed
	# sentinels and PackedVector2Array that the general Codec deliberately rejects.
	var out := {"typeof": typeof(v), "type": type_string(typeof(v))}
	if v is Dictionary:
		var entries: Array = []
		for k: Variant in v: entries.append({"key": _typed(k), "value": _typed(v[k])})
		out["entries"] = entries
	elif v is Array or typeof(v) in [TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_BYTE_ARRAY]:
		var items: Array = []
		for item: Variant in v: items.append(_typed(item))
		out["items"] = items
	elif typeof(v) == TYPE_PACKED_FLOAT32_ARRAY:
		var items: Array = []
		for item: float in v: items.append(_bits(item, 4))
		out["ieee_f32_items"] = items
	elif typeof(v) == TYPE_FLOAT: out["ieee_f64"] = _bits(v)
	elif typeof(v) == TYPE_VECTOR2: out["ieee_components"] = [_bits(v.x), _bits(v.y)]
	elif typeof(v) == TYPE_VECTOR2I: out["integer_components"] = [str(v.x), str(v.y)]
	elif typeof(v) == TYPE_RECT2: out["rect_components"] = [_typed(v.position), _typed(v.size)]
	elif typeof(v) == TYPE_RECT2I: out["rect_components"] = [_typed(v.position), _typed(v.size)]
	elif typeof(v) == TYPE_COLOR: out["ieee_f32_components"] = [_bits(v.r, 4), _bits(v.g, 4), _bits(v.b, 4), _bits(v.a, 4)]
	elif typeof(v) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]: out["value"] = str(v) if typeof(v) in [TYPE_INT, TYPE_STRING_NAME] else v
	else:
		var encoded: Dictionary = Codec.new().encode(v)
		out["codec_ok"] = encoded.get("ok", false)
		out["wire"] = encoded.get("value")
		if not encoded.get("ok", false): fingerprint_supported = false
	return out

func _fingerprint(v: Variant) -> String:
	return JSON.stringify(_typed(v)).sha256_text()

func _write_new(name: String, value: Variant) -> bool:
	evidence_serial += 1
	var path: String = output.path_join(str(evidence_serial).pad_zeros(4) + ".json")
	if not check("fresh component evidence " + name, not FileAccess.file_exists(path)): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check("component evidence writable " + name, file != null): return false
	file.store_string(JSON.stringify(value) + "\n"); file.close()
	evidence.append({"label": name, "path": path, "sha256": FileAccess.get_sha256(path)})
	return true

func _read_pinned(row: Variant, label: String) -> String:
	if not check(label + " exact path SHA", row is Dictionary and row.has_all(["path", "sha256"]) and typeof(row.path) == TYPE_STRING and row.path.is_absolute_path() and typeof(row.sha256) == TYPE_STRING and row.sha256.length() == 64 and row.sha256.is_valid_hex_number()): return ""
	if not check(label + " original frozen SHA", FileAccess.file_exists(row.path) and FileAccess.get_sha256(row.path) == row.sha256): return ""
	var file := FileAccess.open(row.path, FileAccess.READ)
	if not check(label + " readable", file != null): return ""
	var bytes: PackedByteArray = file.get_buffer(file.get_length()); file.close()
	var raw := bytes.get_string_from_utf8()
	if not check(label + " complete original UTF8", not bytes.is_empty() and raw.to_utf8_buffer() == bytes): return ""
	provenance.append({"label": label, "path": row.path, "sha256": row.sha256, "bytes": bytes.size()})
	return raw

func _parse(raw: String, label: String) -> Dictionary:
	var parser := JSON.new()
	if not check(label + " JSON Dictionary", parser.parse(raw) == OK and parser.data is Dictionary): return {}
	return parser.data

func _scan(path: String, relative := "") -> Dictionary:
	var out := {}; var dir := DirAccess.open(path)
	if dir == null: return {"__ERROR_OPEN__": path}
	dir.list_dir_begin(); var name := dir.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			if dir.is_link(name): dir.list_dir_end(); return {"__ERROR_LINK__": name}
			var child: String = path.path_join(name)
			var rel: String = name if relative.is_empty() else relative.path_join(name)
			if dir.current_is_dir(): out.merge(_scan(child, rel))
			else: out[rel] = FileAccess.get_sha256(child)
		name = dir.get_next()
	dir.list_dir_end(); return out

func _sha_map_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for k: Variant in a:
		if not b.has(k) or typeof(a[k]) != TYPE_STRING or typeof(b[k]) != TYPE_STRING or a[k] != b[k]: return false
	return true

func _profile_proof() -> bool:
	if not check("actual A full slot/journal source set exists", manifest.get("profile_files") is Array and not manifest.profile_files.is_empty()): return false
	var expected := {}; var scope: String = ProjectSettings.globalize_path(SLOT_ROOT).replace("\\", "/").simplify_path().trim_suffix("/")
	for row: Variant in manifest.profile_files:
		if not check("exact nonalias relative profile file", row is Dictionary and row.has_all(["path", "sha256", "relative"]) and typeof(row.relative) == TYPE_STRING and not row.relative.is_empty() and not row.relative.is_absolute_path() and row.relative.replace("\\", "/").simplify_path() == row.relative and not row.relative.begins_with("../") and not expected.has(row.relative)): return false
		if _read_pinned(row, "original A journal/slot " + row.relative).is_empty(): return false
		expected[row.relative] = row.sha256
		if not check("owned A profile exact bytes " + row.relative, FileAccess.get_sha256(scope.path_join(row.relative)) == row.sha256): return false
	if not check("complete owned A journal/slot keyset SHA", _sha_map_equal(_scan(scope), expected)): return false
	return check("owned raw A handoff bytes", FileAccess.get_sha256(HANDOFF_A) == manifest.a_handoff.sha256)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("DAMING_COMPONENT_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	output = OS.get_environment("DAMING_COMPONENT_OUT").replace("\\", "/").simplify_path().trim_suffix("/")
	nonce = OS.get_environment("DAMING_COMPONENT_NONCE")
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for f: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(f).replace("\\", "/").simplify_path().trim_suffix("/").to_lower() == profile.path_join(f.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with(profile.path_join("appdata").to_lower() + "/") and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty()
	if not safe: print("V25_COMPONENT PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	if not check("fresh external component output and nonce", not nonce.is_empty() and output.is_absolute_path() and not DirAccess.dir_exists_absolute(output) and not output.to_lower().begins_with(project.to_lower() + "/") and output.to_lower() != project.to_lower()): finish(); return
	if not check("new component output created", DirAccess.make_dir_recursive_absolute(output) == OK): finish(); return
	run.call_deferred()

func _load() -> void:
	Core = load("res://scripts/run_battle_world_core.gd"); Store = load("res://scripts/run_slot_store.gd")
	Codec = load("res://scripts/run_state_value_codec.gd"); Profiles = load("res://scripts/run_official_restore_profile.gd")
	UnitState = load("res://scripts/run_unit_state.gd"); Contract = load("res://scripts/run_level8_unit_contract.gd")
	Identity = load("res://scripts/run_graph_identity.gd"); LevelState = load("res://scripts/run_campaign_level_state.gd")
	Lifecycle = load("res://scripts/run_campaign_local_lifecycle.gd")

func run() -> void:
	var path: String = OS.get_environment("DAMING_COMPONENT_MANIFEST")
	if not check("V25_COMPONENT_PREFLIGHT_ACTUAL_A_REQUIRED", path.is_absolute_path() and FileAccess.file_exists(path)): finish(); return
	_load()
	var startup_flow: Node = get_node("/root/ContinueFlow")
	var gate: Script = load("res://scripts/run_campaign_progress_gate.gd")
	for frame in range(180): await get_tree().process_frame
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check("production startup checked before any matrix factory or world", startup_flow.phase == startup_flow.Phase.IDLE and startup_flow.last_result.get("startup_checked",false) and gate.background_allowed(), startup_flow.last_result.duplicate(true)): finish(); return
	manifest = _parse(_read_pinned({"path": path, "sha256": OS.get_environment("DAMING_COMPONENT_MANIFEST_SHA256")}, "component manifest"), "component manifest")
	if not check("component exact actual A manifest", manifest.get("schema") == INPUT_SCHEMA and manifest.has_all(FIXTURES + ["first_role", "content_version", "engine_sha256", "profile_files", "source_pins"]) and typeof(manifest.first_role) == TYPE_STRING and manifest.first_role in ["lu", "shi"] and typeof(manifest.content_version) == TYPE_STRING and not manifest.content_version.is_empty() and typeof(manifest.engine_sha256) == TYPE_STRING and manifest.engine_sha256.length() == 64 and manifest.engine_sha256.is_valid_hex_number()): finish(); return
	role = manifest.first_role
	if not check("exact fixed installed component source pin keyset", manifest.source_pins is Dictionary and manifest.source_pins.size() == SOURCE_PATHS.size() and manifest.source_pins.has_all(SOURCE_PATHS)): finish(); return
	for src: String in SOURCE_PATHS:
		if not check("actual installed component source " + src, typeof(manifest.source_pins[src]) == TYPE_STRING and manifest.source_pins[src].length() == 64 and FileAccess.get_sha256(src) == manifest.source_pins[src]): finish(); return
	var raw := {}
	for f: String in FIXTURES:
		raw[f] = _read_pinned(manifest[f], f)
		if raw[f].is_empty(): finish(); return
	base_raw = raw.a_slot
	trusted = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if not check("actual A and component source engine content identity", trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("content_version") == manifest.content_version and trusted.get("engine_binary_sha256") == manifest.engine_sha256 and trusted.get("content_version") == OS.get_environment("DAMING_COMPONENT_EXPECT_CONTENT") and manifest.engine_sha256 == FileAccess.get_sha256(OS.get_executable_path()) and manifest.engine_sha256 == OS.get_environment("DAMING_COMPONENT_EXPECT_ENGINE"), trusted): finish(); return
	var pack: Dictionary = load("res://scripts/run_level8_world_factory.gd").prepare_runtime(trusted)
	if not check("original installed read-only definitions available", pack.get("ok", false), pack): finish(); return
	runtime = pack.runtime
	var probe: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var contract_probe: RefCounted = Contract.new()
	var installed: bool = probe.has_method("_validate_daming_safe_pair") and contract_probe.has_method("_safe_retreat_values") and _zero(probe)
	probe.dispose()
	if not check("actual new pair and safe Unit component APIs installed", installed): finish(); return
	var a_report := _parse(raw.a_report, "actual A report"); var handoff := _parse(raw.a_handoff, "actual A handoff")
	var packet := _parse(raw.a_packet, "actual A packet"); var world := _parse(raw.a_world, "actual A world")
	if not check("actual A successful single-safe source", a_report.get("schema") == "daming_campaign_durable_cross_process_report_v1" and a_report.get("case") == "A_single_save" and a_report.get("first_role") == role and a_report.get("passed") == true and a_report.get("single_safe_disk_case_qualified") == true and a_report.get("checks") is Array and not a_report.checks.is_empty() and a_report.checks.all(func(r): return r is Dictionary and r.get("passed") == true)): finish(); return
	if not check("source actual PID nonce content engine", a_report.get("trusted") is Dictionary and a_report.trusted.get("content_version") == manifest.content_version and a_report.trusted.get("engine_binary_sha256") == manifest.engine_sha256 and typeof(a_report.get("pid")) in [TYPE_INT, TYPE_FLOAT] and int(a_report.pid) > 0 and int(a_report.pid) != OS.get_process_id() and typeof(a_report.get("nonce")) == TYPE_STRING and not a_report.nonce.is_empty() and a_report.nonce != nonce): finish(); return
	if not check("A report authentic full packet/world hashes", a_report.get("evidence") is Array and a_report.evidence.any(func(r): return r is Dictionary and r.get("sha256") == manifest.a_packet.sha256) and a_report.evidence.any(func(r): return r is Dictionary and r.get("sha256") == manifest.a_world.sha256)): finish(); return
	if not check("A five original files consistent", handoff.get("schema") == "daming_safe_retreat_cross_process_handoff_v25" and handoff.get("mode") == "A_single_save" and handoff.get("pid") == a_report.pid and handoff.get("nonce") == a_report.nonce and handoff.get("first_role") == role and handoff.get("generation") == 1 and handoff.get("file_sha256") == manifest.a_slot.sha256 and handoff.get("content_version") == manifest.content_version and handoff.get("engine_sha256") == manifest.engine_sha256 and handoff.get("packet") == packet and packet.get("world") == world): finish(); return
	var opened: Dictionary = Store.new(SLOT_ROOT)._decode(base_raw)
	if not check("actual canonical A slot full typed packet", opened.get("ok", false) and opened.get("revision") == 1 and opened.get("file_sha256") == manifest.a_slot.sha256 and JSON.parse_string(JSON.stringify(opened.document)) == packet, opened): finish(); return
	base = opened.document
	if not _profile_proof(): finish(); return
	var owned: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("owned actual A slot full head unchanged", owned.get("ok", false) and owned.file_sha256 == manifest.a_slot.sha256 and owned.revision == 1 and _fingerprint(owned.document) == _fingerprint(base), owned): finish(); return
	if not check("original local-only binding fixed", base.binding is Dictionary and Lifecycle.validate_binding(base.binding).get("ok", false)): finish(); return
	var journal: RefCounted = Lifecycle.new(base.binding.token, SLOT_ROOT, base.context, trusted, get_node("/root/Campaign").cloud_owner)
	if not check("matrix lifecycle exact actual context identity owner", journal.matches_scope(base.context,trusted,get_node("/root/Campaign").cloud_owner)): finish(); return
	var head: Dictionary = journal.open_head() # pure read: never begin/_head/recover/write
	if not check("actual original journal durable active receipt", head.get("ok", false) and head.revision == 1 and head.file_sha256 == base.binding.receipt_sha256 and head.document.state == "active" and head.document.victory == false and head.document.schema == Lifecycle.CAMPAIGN_SCHEMA and head.document.context == base.context and head.document.progress_state == "none", head): finish(); return
	proof_before = _scan(ProjectSettings.globalize_path(SLOT_ROOT))
	get_tree().paused = true
	for route: String in ROUTES:
		if not _positive(route): finish(); return
	fixture_ready = true
	_build_specs()
	if not check("exact separate component planned cases", specs.size() == 181): finish(); return
	for spec: Dictionary in specs:
		for route: String in ROUTES:
			if not _negative(spec, route): finish(); return
	for row: Dictionary in provenance:
		if not check("all actual A frozen source bytes unchanged " + row.label, FileAccess.get_sha256(row.path) == row.sha256): finish(); return
	if not _profile_proof() or not check("original journal entire subtree unchanged", _sha_map_equal(proof_before, _scan(ProjectSettings.globalize_path(SLOT_ROOT)))): finish(); return
	finish()

func _route_packet(route: String) -> Dictionary:
	var store: RefCounted = Store.new(SLOT_ROOT)
	return store._validate_document(base.duplicate(true)) if route == "source" else store._decode(base_raw)

func _data(packet: Dictionary, section: String) -> Dictionary:
	var opened: Dictionary = Codec.new().decode(packet.world.sections[section].payload)
	if not check("original complete component payload " + section, opened.get("ok", false) and opened.value is Dictionary, opened): return {}
	return opened.value

func _put(sections: Dictionary, section: String, data: Dictionary) -> bool:
	var encoded: Dictionary = Codec.new().encode(data)
	if not check("full owned component recode " + section, encoded.get("ok", false), encoded): return false
	sections[section].payload = encoded.value; return true

func _context(packet: Dictionary) -> Dictionary:
	var c: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var graph: RefCounted = c._graph()
	var indexed: Dictionary = graph.validate_index(packet.world.sections.units, trusted.content_version)
	if not check("actual complete graph original identity index", indexed.get("ok", false), indexed): c.dispose(); return {}
	var level: Dictionary = LevelState.new().validate(packet.world.sections.level, "level8", trusted.content_version, indexed.known_ids, indexed.next_entity_id, {}, packet.world.profile.mission_token)
	if not check("actual complete original fixed Level roles", level.get("ok", false), level): c.dispose(); return {}
	var roles := {"values": level.value.values, "references": level.value.references, "external": level.value.external}
	var contract: RefCounted = Contract.new()
	var configured: Dictionary = contract.configure(roles)
	if not check("actual Level8Contract configured from accepted Level", configured.get("ok", false), configured): c.dispose(); return {}
	var identity: RefCounted = Identity.new(Core.U)
	var declared: Dictionary = identity.declare_entities(indexed.known_ids)
	if not check("abstract original known identities declared no Unit", declared.get("ok", false), declared): identity.dispose(); c.dispose(); return {}
	var unit: RefCounted = UnitState.new(Codec, Core.U, Core.Inventory, Profiles.DAMING_CONTEXT, roles)
	var states := {}; var records := {}
	for record: Dictionary in packet.world.sections.units.records:
		var accepted: Dictionary = unit.validate(record, trusted.content_version, indexed.known_ids, identity.validate_identity)
		if not check("original full Unit model validated " + record.entity_id, accepted.get("ok", false), accepted): identity.dispose(); c.dispose(); return {}
		states[record.entity_id] = accepted; records[record.entity_id] = record
	var active: Array = packet.world.sections.units.active_order
	var member: Dictionary = unit.validate_level8_membership(states, active)
	if not check("original complete Unit membership component accepts", member.get("ok", false), member): identity.dispose(); c.dispose(); return {}
	c.dispose()
	return {"unit": unit, "contract": contract, "identity": identity, "known": indexed.known_ids, "states": states, "records": records, "roles": roles, "active": active.duplicate()}

func _close(ctx: Dictionary) -> void:
	if not ctx.is_empty() and ctx.get("identity") != null: ctx.identity.dispose()

func _zero(c: RefCounted) -> bool:
	return c._battle == null and c._identity == null and c._unit_plan.is_empty()

func _positive(route: String) -> bool:
	var opened: Dictionary = _route_packet(route)
	if not check("actual A unmodified Store route " + route, opened.get("ok", false), opened): return false
	var before := _fingerprint(opened.document)
	var ctx := _context(opened.document)
	if ctx.is_empty(): return false
	var refs: Dictionary = ctx.roles.references
	if not check("actual source safe other gate IDs typed", typeof(refs[role]) == TYPE_STRING and typeof(refs["shi" if role == "lu" else "lu"]) == TYPE_STRING and typeof(refs.gate) == TYPE_STRING): _close(ctx); return false
	safe_id = refs[role]; other_id = refs["shi" if role == "lu" else "lu"]; gate_id = refs.gate
	var safe: Dictionary = ctx.states[safe_id]; var other: Dictionary = ctx.states[other_id]; var gate: Dictionary = ctx.states[gate_id]
	var mission: Dictionary = _data(opened.document, "mission")
	if not check("actual natural A source contains safe and live rescued other", safe.values.story_outcome == "retreated" and other.values.story_outcome == "" and not other.values.is_captive and other.values.faction == 0 and mission.events.has("daming_" + role + "_safe") and not mission.events.has("daming_" + ("shi" if role == "lu" else "lu") + "_safe")): _close(ctx); return false
	if not check("V25_COMPONENT_SOURCE_OLD_RETIRED_GATE_REQUIRED", gate.values.story_outcome == "retreated" and gate.values.key == "zhu_gate" and ctx.roles.values.gate_open): _close(ctx); return false
	for entry: Dictionary in [{"id": "actual_safe_unit", "entity_id": safe_id}, {"id": "actual_other_rescued_unretreated_unit", "entity_id": other_id}, {"id": "actual_old_retired_gate", "entity_id": gate_id}]:
		var state: Dictionary = ctx.states[entry.entity_id]
		var values_ok: Dictionary = ctx.contract.values(state.values)
		var parts_ok: Dictionary = ctx.contract.parts(state.values, state.references, state.metadata, state.node)
		if not check("original independent direct Contract positive " + entry.id + "/" + route, values_ok.get("ok", false) and parts_ok.get("ok", false)): _close(ctx); return false
		positives.append({"id": entry.id, "route": route, "entity_id": entry.entity_id, "actual_original_unit_record": true, "full_UnitState_validate": true, "direct_Contract_values": true, "direct_Contract_parts": true, "passed": true})
	var c: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var nodes_before: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var zero_before := _zero(c)
	var pair: Dictionary = c._validate_daming_safe_pair(opened.document.world.sections, opened.document.world.profile.mission_token, opened.document.world.profile.presentation_token)
	var no_nodes: bool = Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == nodes_before
	var good: bool = pair.get("ok", false) and pair.get("safe_count") == 1 and zero_before and _zero(c) and no_nodes and before == _fingerprint(opened.document)
	positives.append({"id": "actual_original_single_safe_pair", "route": route, "actual_Core_fixed_pair_called": true, "safe_count": pair.get("safe_count"), "no_world_before_and_after": zero_before and _zero(c), "native_node_count_unchanged": no_nodes, "input_type_ieee_unchanged": before == _fingerprint(opened.document), "passed": good})
	c.dispose(); _close(ctx)
	return check("original actual pure fixedpair no Unit/Battle " + route, good, pair)

func _add(id: String, module: String, kind: String, code: String, extra: Dictionary = {}) -> void:
	var spec := {"id": id, "module": module, "kind": kind, "expected_code": code}
	spec.merge(extra); specs.append(spec)

func _build_specs() -> void:
	for field: String in ["_chase_intent", "_group_cap", "_has_home", "_home", "_hua_lock_shots"]:
		for module: String in ["unit_full", "contract_values"]:
			_add(module + "_safe_stop_" + field, module, "stop", "LEVEL8_SAFE_RETREAT_STOP_ANCHOR", {"field": field, "subject": "safe"})
	for module: String in ["unit_full", "contract_parts"]:
		_add(module + "_safe_queue_nonempty", module, "queue", "LEVEL8_SAFE_RETREAT_QUEUE", {"subject": "safe"})
	var identities := {"is_captive": "RESCUED_IDENTITY", "is_hero": "RESCUED_IDENTITY", "faction": "RESCUED_IDENTITY", "base_speed": "RESCUED_IDENTITY", "art_variant": "RESCUED_IDENTITY", "is_noncombat": "PRISONER_IDENTITY", "atk": "PRISONER_IDENTITY", "ability": "PRISONER_IDENTITY", "key": "ROLE_KEY"}
	for field: String in identities:
		for module: String in ["unit_full", "contract_values"]:
			_add(module + "_rescued_identity_" + field, module, "rescued_identity", "LEVEL8_" + identities[field], {"field": field, "subject": "other"})
	for field: String in ["hp", "_dying"]:
		for module: String in ["unit_full", "contract_values"]:
			_add(module + "_other_lifetime_" + field, module, "lifetime", "LEVEL8_LIFETIME", {"field": field, "subject": "other"})
	for module: String in ["unit_full", "contract_values"]:
		_add(module + "_other_captured_outcome", module, "outcome", "LEVEL8_UNSUPPORTED_STORY_OUTCOME", {"subject": "other"})
	for kind: String in ["active_drop", "state_drop"]:
		for module: String in ["unit_membership", "contract_membership"]:
			_add(module + "_other_" + kind, module, kind, "LEVEL8_ACTIVE_MEMBERSHIP" if kind == "active_drop" else "LEVEL8_ROLE_NOT_IN_GRAPH", {"subject": "other"})
	var labels := ["nil", "bool", "int", "float", "array", "dictionary"]
	var unit_text := {"schema": "SCHEMA", "content_version": "CONTENT_VERSION", "entity_id": "SUBJECT_ID"}
	for field: String in unit_text:
		for label: String in labels:
			_add("unit_full_identity_" + field + "_" + label, "unit_full", "unit_identity", unit_text[field], {"field": field, "type_case": label, "subject": "safe"})
	var pair_rows := [
		["other_role_null", "other_null", "LEVEL8_SAFE_REQUIRED_ACTOR_MISSING"],
		["other_dead_complete_lifetime", "other_dead", "LEVEL8_SAFE_REQUIRED_ACTOR_LIFETIME"],
		["safe_event_missing", "safe_event_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR"],
		["safe_actor_outcome_empty", "safe_outcome_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR"],
		["other_safe_event_without_retreat", "other_event_add", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR"],
		["root_safe_selection", "root_selection", "LEVEL8_SAFE_SELECTED_ROOT"],
		["freed_event_missing", "freed_remove", "LEVEL8_SAFE_RESCUE_EVENT_PAIR"],
		["rescue_done_false", "rescue_done", "LEVEL8_SAFE_RESCUE_EVENT_PAIR"]]
	for entry: Array in pair_rows: _add("pair_" + entry[0], "pair", entry[1], entry[2])
	for field: String in ["_ability_caster", "_item_caster"]:
		_add("pair_root_safe_" + field, "pair", "root_caster", "LEVEL8_SAFE_ARMED_CASTER", {"field": field})
	for kind: String in ["_walk_casts", "_pending_casts", "_channels", "_walk_item_casts", "_pending_item_casts"]:
		_add("pair_safe_caster_" + kind, "pair", "cast", "LEVEL8_SAFE_CAST_INTENT", {"array": kind})
	var records := {"units": ["schema", "content_version"], "level": ["schema", "level_id", "content_version", "mission_token"], "root": ["schema", "content_version"], "mission": ["schema"], "presentation": ["schema"]}
	for section: String in records:
		for field: String in records[section]:
			for label: String in labels:
				_add("pair_identity_" + section + "_" + field + "_" + label, "pair", "pair_identity", "LEVEL8_SAFE_IDENTITY_TEXT_TYPE", {"section": section, "path": [field], "type_case": label})
	for section: String in ["mission", "presentation"]:
		for field: String in ["level_id", "content_version", "mission_token", "presentation_token"]:
			for label: String in labels:
				_add("pair_identity_" + section + "_context_" + field + "_" + label, "pair", "pair_identity", "LEVEL8_SAFE_CONTEXT_TEXT_TYPE", {"section": section, "path": ["context", field], "type_case": label})

func _invalid(label: String) -> Variant:
	match label:
		"nil": return null
		"bool": return true
		"int": return 1
		"float": return 1.0
		"array": return []
		"dictionary": return {}
	return null

func _mutate_unit_data(data: Dictionary, spec: Dictionary) -> void:
	var v: Dictionary = data.values
	if spec.kind == "stop":
		match spec.field:
			"_chase_intent", "_hua_lock_shots": v[spec.field] = 1
			"_group_cap": v[spec.field] = 1.0
			"_has_home": v[spec.field] = false
			"_home": v[spec.field] = v.position + Vector2(1.0, 0.0)
	elif spec.kind == "queue": data.references["_queue"] = [{"kind": "move", "pos": v.position, "group_cap": 0.0}]
	elif spec.kind == "lifetime": v[spec.field] = 0.0 if spec.field == "hp" else true
	elif spec.kind == "outcome": v.story_outcome = "captured"
	elif spec.kind == "rescued_identity":
		match spec.field:
			"is_captive", "is_hero": v[spec.field] = true
			"faction": v.faction = 2
			"base_speed": v.base_speed = 0.0
			"art_variant": v.art_variant = "daming_bound_" + v.key
			"is_noncombat": v.is_noncombat = false
			"atk": v.atk = 1.0
			"ability": v.ability = "component_unallowed_ability"
			"key": v.key = "lou_luo"

func _unit_record(sections: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in sections.units.records:
		if row.entity_id == id: return row
	return {}

func _encode_component_wire(wire: Dictionary, membership: bool) -> Dictionary:
	if not membership: return Codec.new().encode(wire)
	# Production Unit payloads are encoded one record at a time. Keep that exact
	# per-value limit for the complete membership transport, including every key.
	var entries: Array = []
	for key: Variant in wire:
		var encoded_key: Dictionary = Codec.new().encode(key)
		if not encoded_key.get("ok", false): return encoded_key
		if key == "states":
			if typeof(wire[key]) != TYPE_DICTIONARY: return {"ok":false,"code":"COMPONENT_MEMBERSHIP_STATES_TYPE"}
			var rows: Array = []
			for id: Variant in wire[key]:
				var encoded_id: Dictionary = Codec.new().encode(id)
				if not encoded_id.get("ok", false): return encoded_id
				var encoded_state: Dictionary = Codec.new().encode(wire[key][id])
				if not encoded_state.get("ok", false): return encoded_state
				rows.append({"id":encoded_id.value,"state":encoded_state.value})
			entries.append({"key":encoded_key.value,"kind":"states","rows":rows})
		else:
			var encoded_value: Dictionary = Codec.new().encode(wire[key])
			if not encoded_value.get("ok", false): return encoded_value
			entries.append({"key":encoded_key.value,"kind":"value","value":encoded_value.value})
	var value := {"schema":"complete_membership_component_wire_v1","entries":entries}
	if JSON.stringify(value).to_utf8_buffer().size() > Store.new(SLOT_ROOT)._byte_limit():
		return {"ok":false,"code":"COMPONENT_MEMBERSHIP_TRANSPORT_BYTES"}
	return {"ok":true,"value":value}

func _decode_component_wire(tagged: Variant, membership: bool) -> Dictionary:
	if not membership: return Codec.new().decode(tagged)
	if typeof(tagged) != TYPE_DICTIONARY or tagged.size() != 2 or not tagged.has_all(["schema","entries"]) \
		or tagged.schema != "complete_membership_component_wire_v1" or typeof(tagged.entries) != TYPE_ARRAY:
		return {"ok":false,"code":"COMPONENT_MEMBERSHIP_TRANSPORT_FIELDS"}
	if JSON.stringify(tagged).to_utf8_buffer().size() > Store.new(SLOT_ROOT)._byte_limit():
		return {"ok":false,"code":"COMPONENT_MEMBERSHIP_TRANSPORT_BYTES"}
	var result: Dictionary = {}
	for entry: Variant in tagged.entries:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 3 or not entry.has_all(["key","kind"]) \
			or typeof(entry.kind) != TYPE_STRING or entry.kind not in ["states","value"]:
			return {"ok":false,"code":"COMPONENT_MEMBERSHIP_ENTRY_FIELDS"}
		var decoded_key: Dictionary = Codec.new().decode(entry.key)
		if not decoded_key.get("ok", false): return decoded_key
		var key: Variant = decoded_key.value
		if result.has(key): return {"ok":false,"code":"COMPONENT_MEMBERSHIP_DUPLICATE_KEY"}
		if entry.kind == "states":
			if key != "states" or not entry.has("rows") or typeof(entry.rows) != TYPE_ARRAY:
				return {"ok":false,"code":"COMPONENT_MEMBERSHIP_STATES_FIELDS"}
			var states: Dictionary = {}
			for row: Variant in entry.rows:
				if typeof(row) != TYPE_DICTIONARY or row.size() != 2 or not row.has_all(["id","state"]):
					return {"ok":false,"code":"COMPONENT_MEMBERSHIP_ROW_FIELDS"}
				var decoded_id: Dictionary = Codec.new().decode(row.id)
				if not decoded_id.get("ok", false): return decoded_id
				var decoded_state: Dictionary = Codec.new().decode(row.state)
				if not decoded_state.get("ok", false): return decoded_state
				if states.has(decoded_id.value): return {"ok":false,"code":"COMPONENT_MEMBERSHIP_DUPLICATE_ID"}
				states[decoded_id.value] = decoded_state.value
			result[key] = states
		else:
			if key == "states" or not entry.has("value"): return {"ok":false,"code":"COMPONENT_MEMBERSHIP_VALUE_FIELDS"}
			var decoded_value: Dictionary = Codec.new().decode(entry.value)
			if not decoded_value.get("ok", false): return decoded_value
			result[key] = decoded_value.value
	return {"ok":true,"value":result}

func _component_json(input: Dictionary, ctx: Dictionary, route: String, subject: String, membership := false) -> Dictionary:
	if route == "source": return {"ok": true, "value": input}
	var unit: RefCounted = ctx.unit
	var wire: Dictionary = input.duplicate(true)
	if membership:
		for id: String in wire.states:
			wire.states[id].values = unit._to_wire(wire.states[id].values)
			wire.states[id].metadata = Codec.new().decode(ctx.records[id].payload).value.metadata
	else:
		wire.values = unit._to_wire(wire.values)
		wire.metadata = Codec.new().decode(ctx.records[subject].payload).value.metadata
	var encoded: Dictionary = _encode_component_wire(wire, membership)
	if not encoded.get("ok", false): return encoded
	var parser := JSON.new()
	if parser.parse(JSON.stringify(encoded.value)) != OK: return {"ok": false, "code": "COMPONENT_JSON"}
	var decoded: Dictionary = _decode_component_wire(parser.data, membership)
	if not decoded.get("ok", false): return decoded
	var result: Dictionary = decoded.value
	if membership:
		for id: String in result.states:
			var native: Dictionary = unit._from_wire(result.states[id].values)
			if not native.get("ok", false): return native
			result.states[id].values = native.values
			var meta: Dictionary = unit._check_metadata(result.states[id].metadata, ctx.known)
			if not meta.get("ok", false): return meta
			result.states[id].metadata = meta.value
	else:
		var native: Dictionary = unit._from_wire(result.values)
		if not native.get("ok", false): return native
		result.values = native.values
		var meta: Dictionary = unit._check_metadata(result.metadata, ctx.known)
		if not meta.get("ok", false): return meta
		result.metadata = meta.value
	return {"ok": true, "value": result}

func _mutate_pair(sections: Dictionary, spec: Dictionary, packet: Dictionary) -> bool:
	if spec.kind == "pair_identity":
		if spec.path.size() == 1: sections[spec.section][spec.path[0]] = _invalid(spec.type_case)
		else: sections[spec.section][spec.path[0]][spec.path[1]] = _invalid(spec.type_case)
		return true
	if spec.kind in ["other_dead", "safe_outcome_remove"]:
		var rec: Dictionary = _unit_record(sections, other_id if spec.kind == "other_dead" else safe_id)
		if not check("actual original pair Unit source record exists", not rec.is_empty()): return false
		var body: Dictionary = Codec.new().decode(rec.payload).value
		if spec.kind == "other_dead": body.values.hp = 0.0; body.values._dying = true; sections.units.active_order.erase(other_id)
		else: body.values.story_outcome = ""
		var encoded: Dictionary = Codec.new().encode(body)
		if not check("original complete pair Unit recode", encoded.get("ok", false)): return false
		rec.payload = encoded.value; return true
	if spec.kind == "other_null":
		var body: Dictionary = _data(packet, "level"); body.references["shi" if role == "lu" else "lu"] = null
		return _put(sections, "level", body)
	if spec.kind in ["safe_event_remove", "other_event_add", "freed_remove", "rescue_done"]:
		var body: Dictionary = _data(packet, "mission")
		if spec.kind == "safe_event_remove": body.events.erase("daming_" + role + "_safe")
		elif spec.kind == "other_event_add": body.events.append("daming_" + ("shi" if role == "lu" else "lu") + "_safe")
		elif spec.kind == "freed_remove": body.events.erase("daming_prisoners_freed")
		else:
			var found := false
			for action: Dictionary in body.actions:
				if action.id == "daming_rescue": action.done = false; found = true
			if not check("actual original rescue source case exists", found): return false
		return _put(sections, "mission", body)
	if spec.kind in ["root_selection", "root_caster"]:
		var body: Dictionary = _data(packet, "root"); var tag := {"state": "entity", "id": safe_id}
		if spec.kind == "root_selection": body.selection.append(tag)
		else: body.references[spec.field] = tag
		return _put(sections, "root", body)
	if spec.kind == "cast":
		var section: String = "item_casts" if spec.array in ["_walk_item_casts", "_pending_item_casts"] else "casts"
		var body: Dictionary = _data(packet, section)
		if not check("actual original fixed cast source field", body.has(spec.array) and body[spec.array] is Array): return false
		var pos: Vector2 = Codec.new().decode(_unit_record(sections, safe_id).payload).value.values.position
		var tag := {"state": "entity", "id": safe_id}; var none := {"state": "none"}; var entry := {}
		match spec.array:
			"_walk_casts": entry = {"c": tag, "slot": 0, "tgt": none, "point": {"mode": "point", "value": pos}, "serial": 0, "t": 0.0, "age": 0.0}
			"_pending_casts": entry = {"caster": tag, "slot": 0, "lp": pos, "tgt": none, "serial": 0}
			"_channels": entry = {"caster": tag, "center": pos, "eff": {"kind": "channel"}, "sc": 1.0, "rank": 1, "r": 1.0, "tick": 1.0, "tick_t": 0.0, "ad": {}}
			"_walk_item_casts": entry = {"c": tag, "uid": 1, "tgt": none, "point": {"mode": "point", "value": pos}, "serial": 0, "t": 0.0, "age": 0.0}
			"_pending_item_casts": entry = {"caster": tag, "slot": 0, "uid": 1, "point": pos, "target": none, "serial": 0}
		body[spec.array].append(entry); return _put(sections, section, body)
	return check("known independent pair mutation", false, spec)

func _negative(spec: Dictionary, route: String) -> bool:
	var base_before := _fingerprint(base)
	var opened: Dictionary = _route_packet(route)
	if not check("original actual A component reader " + spec.id + "/" + route, opened.get("ok", false), opened): return false
	var packet: Dictionary = opened.document
	var packet_before := _fingerprint(packet)
	var ctx := _context(packet)
	if ctx.is_empty(): return false
	var subject: String = safe_id if spec.get("subject", "safe") == "safe" else other_id
	var input: Variant = null
	if spec.module == "unit_full":
		input = ctx.records[subject].duplicate(true)
		if spec.kind == "unit_identity": input[spec.field] = _invalid(spec.type_case)
		else:
			var data: Dictionary = Codec.new().decode(input.payload).value
			_mutate_unit_data(data, spec)
			var encoded: Dictionary = Codec.new().encode(data)
			if not check("complete independent Unit wire recoded", encoded.get("ok", false), encoded): _close(ctx); return false
			input.payload = encoded.value
		# Primitive record identity uses actual JSON parsing (Int becomes Float);
		# do not cast the resulting identity or pretend it crossed Slot canonical IO.
		if route == "json": input = JSON.parse_string(JSON.stringify(input))
	elif spec.module in ["contract_values", "contract_parts"]:
		input = {"values": ctx.states[subject].values.duplicate(true), "references": ctx.states[subject].references.duplicate(true), "metadata": ctx.states[subject].metadata.duplicate(true), "node": ctx.states[subject].node.duplicate(true)}
		_mutate_unit_data(input, spec)
		var decoded: Dictionary = _component_json(input, ctx, route, subject)
		if not check("direct Contract full installed wire JSON route", decoded.get("ok", false), decoded): _close(ctx); return false
		input = decoded.value
	elif spec.module in ["unit_membership", "contract_membership"]:
		input = {"states": ctx.states.duplicate(true), "active": ctx.active.duplicate()}
		if spec.kind == "active_drop": input.active.erase(other_id)
		else: input.states.erase(other_id)
		var decoded: Dictionary = _component_json(input, ctx, route, subject, true)
		if not check("membership full installed wire JSON route", decoded.get("ok", false), decoded): _close(ctx); return false
		input = decoded.value
	else:
		input = packet.world.sections.duplicate(true)
		if not _mutate_pair(input, spec, packet): _close(ctx); return false
		if route == "json": input = JSON.parse_string(JSON.stringify(input))
	var input_before := _fingerprint(input)
	if not check("every complete input audit type supported " + spec.id + "/" + route, fingerprint_supported): _close(ctx); return false
	if not _write_new(spec.id + "_" + route + "_input", {"input": _typed(input), "type_ieee_sha256": input_before}): _close(ctx); return false
	var nodes_before: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var result := {}; var pair_core: RefCounted = null
	var core_before: Variant = null; var core_after: Variant = null
	var call := ""
	match spec.module:
		"unit_full": call = "UnitState.validate"; result = ctx.unit.validate(input, trusted.content_version, ctx.known, ctx.identity.validate_identity)
		"contract_values": call = "Level8Contract.values"; result = ctx.contract.values(input.values)
		"contract_parts": call = "Level8Contract.parts"; result = ctx.contract.parts(input.values, input.references, input.metadata, input.node)
		"unit_membership": call = "UnitState.validate_level8_membership"; result = ctx.unit.validate_level8_membership(input.states, input.active)
		"contract_membership": call = "Level8Contract.membership"; result = ctx.contract.membership(input.states, input.active)
		"pair":
			call = "Core._validate_daming_safe_pair"
			pair_core = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
			core_before = _zero(pair_core)
			result = pair_core._validate_daming_safe_pair(input, packet.world.profile.mission_token, packet.world.profile.presentation_token)
			core_after = _zero(pair_core)
	var after := _fingerprint(input)
	var input_unchanged: bool = input_before == after
	var original_unchanged: bool = packet_before == _fingerprint(packet) and base_before == _fingerprint(base)
	var no_nodes: bool = Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == nodes_before
	var no_world: bool = spec.module != "pair" or (core_before == true and core_after == true)
	var passed: bool = result.get("ok") == false and result.get("code") == spec.expected_code and input_unchanged and original_unchanged and no_nodes and no_world and fingerprint_supported
	var row := {"id": spec.id, "route": route, "module": spec.module, "actual_call": call, "expected_code": spec.expected_code, "actual_code": result.get("code", ""), "expected_guard_layer": spec.module, "actual_component_call_executed": true, "full_original_UnitState_model_kept": spec.module in ["unit_full", "unit_membership"], "source_case_original_A": true, "input_type_ieee_sha256_before": input_before, "input_type_ieee_sha256_after": after, "input_type_ieee_unchanged": input_unchanged, "original_A_type_ieee_unchanged": original_unchanged, "native_node_count_before": nodes_before, "native_node_count_after": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "native_node_count_unchanged": no_nodes, "core_constructor_called": spec.module == "pair", "core_prepare_called": false, "core_capture_called": false, "core_zero_before": core_before, "core_zero_after": core_after, "direct_pair_branch_called": spec.module == "pair", "result_summary": _brief(result), "passed": passed}
	rows.append(row)
	if pair_core != null: pair_core.dispose()
	_close(ctx)
	if not _write_new(spec.id + "_" + route + "_result", row): return false
	return check("independent component refusal immutable no allocation " + spec.id + "/" + route, passed, result)

func finish() -> void:
	if finished: return
	finished = true
	var expected := {}; var actual := {}; var duplicate := false
	for spec: Dictionary in specs:
		for route: String in ROUTES: expected[spec.id + "/" + route] = true
	for row: Dictionary in rows:
		var key: String = row.id + "/" + row.route
		if actual.has(key): duplicate = true
		actual[key] = true
	var complete: bool = fixture_ready and specs.size() == 181 and not duplicate and actual.size() == expected.size() and expected.keys().all(func(k): return actual.has(k)) and rows.all(func(r): return r.passed) and positives.size() == 8 and positives.all(func(r): return r.passed)
	var passed: bool = complete and not checks.is_empty() and checks.all(func(r): return r.passed)
	var sources := {}
	for path: String in SOURCE_PATHS: sources[path] = FileAccess.get_sha256(path)
	var report := {"schema": REPORT_SCHEMA, "passed": passed, "pure_matrix_passed": passed, "component_matrix_complete": complete, "fixture_ready": fixture_ready, "first_role": role, "pid": OS.get_process_id(), "nonce": nonce, "actual_user_data_dir": OS.get_user_data_dir(), "content_version": trusted.get("content_version", ""), "engine_sha256": FileAccess.get_sha256(OS.get_executable_path()), "harness_sha256": FileAccess.get_sha256(get_script().resource_path), "source_pins": sources, "planned_specs": specs, "expected_case_count": 181, "expected_row_count": 362, "executed_rows": rows, "positives": positives, "checks": checks, "provenance": provenance, "evidence": evidence, "independent_component_calls_implemented": true, "whole_world_DTO_prepare_substitution": false, "actual_Core_prepare_calls": 0, "actual_Core_capture_calls": 0, "disk_slot_writes": 0, "local_journal_writes": 0, "gameplay_ticks_injected": 0, "cached_grids_cleared": 0, "whole_v25_qualified": false, "overall_v25_qualified": false, "future_producer_integration_qualified": false, "native_zero_ERROR_log_verified": false, "actual_two_unretreated_whole_fixture_qualified": false, "not_run_scope": ["Actual two-unretreated whole-world positive fixture absent; original A other Unit positive is narrower and never fabricated", "Actual live five cast-array negatives remain separate not_implemented", "38 live capture rows and full A/B/C/D natural terminal/reward qualification not_run", "Successor parser/native/error-log and independent producer aggregate not_run"], "scope": "Actual original single-safe A closed slot plus full original local journal; independent full UnitState and direct Level8Contract calls, separate real pure Core fixedpair. Component source/JSON boundaries do not claim mutated whole Slot canonical coverage."}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output):
		var path: String = output.path_join("report.json")
		if not FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
			else: passed = false
		else: passed = false
	else: passed = false
	print("DAMING_SAFE_COMPONENT_V25_COMPLETE ", passed, " rows=", rows.size())
	if get_node_or_null("/root/Sfx") != null: get_node("/root/Sfx").shutdown()
	if get_node_or_null("/root/Music") != null: get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
