extends Node
## External, unexecuted fixed DTO negative suite. Actual A source files are mandatory.
## Source and actual JSON-reader routes both reach an independent Core.prepare.
## No capture/live-object negative is implemented, and no saved data is written.
const INPUT_SCHEMA := "daming_safe_retreat_negative_inputs_v25"
const REPORT_SCHEMA := "daming_safe_retreat_negative_world_report_v25"
const ROLES := ["lu", "shi"]
const FIXTURES := ["a_report", "a_handoff", "a_packet", "a_world", "a_slot"]
const RECORD_TEXT := {"units": ["schema", "content_version"], "level": ["schema", "level_id", "content_version", "mission_token"], "root": ["schema", "content_version"], "mission": ["schema"], "presentation": ["schema"]}
const CONTEXT_TEXT := ["level_id", "content_version", "mission_token", "presentation_token"]
const CASTERS := {"_walk_casts": "c", "_pending_casts": "caster", "_channels": "caster", "_walk_item_casts": "c", "_pending_item_casts": "caster"}
var Core: Script
var Store: Script
var Codec: Script
var Factory: Script
var Profiles: Script
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var checks: Array = []
var rows: Array = []
var positives: Array = []
var provenance: Array = []
var specs: Array = []
var manifest: Dictionary = {}
var base: Dictionary = {}
var base_envelope: Dictionary = {}
var safe_id := ""
var other_id := ""
var role := ""
var nonce := ""
var output := ""
var fixture_ready := false
var finished := false

func _brief(value: Variant) -> Dictionary:
	var result := {"type": type_string(typeof(value))}
	if value is Dictionary:
		for key: String in ["code", "field", "path", "section"]:
			if typeof(value.get(key)) == TYPE_STRING: result[key] = value[key].left(200)
		result["summary"] = "fields=" + str(value.size()) + "; ok=" + str(value.get("ok", "missing"))
	else: result["summary"] = str(value).left(200)
	return result

func check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"label": label, "passed": passed, "detail": null if passed else _brief(detail)})
	if not passed: print("V25_NEGATIVE_FAIL ", label, " ", _brief(detail))
	return passed

func _bits(value: float) -> String:
	var raw := PackedByteArray()
	raw.resize(8); raw.encode_double(0, value)
	return raw.hex_encode()

func _exact(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _exact(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not _exact(a[i], b[i]): return false
		return true
	if typeof(a) == TYPE_FLOAT: return _bits(a) == _bits(b)
	return a == b

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile := OS.get_environment("DAMING_NEGATIVE_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	output = OS.get_environment("DAMING_NEGATIVE_REPORT").replace("\\", "/").simplify_path()
	nonce = OS.get_environment("DAMING_NEGATIVE_NONCE")
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for name: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(name).replace("\\", "/").simplify_path().trim_suffix("/").to_lower() == profile.path_join(name.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	if not safe:
		print("V25_NEGATIVE PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	if not check("fresh external report and nonce", not nonce.is_empty() and output.is_absolute_path() and DirAccess.dir_exists_absolute(output.get_base_dir()) and not FileAccess.file_exists(output) and not output.to_lower().begins_with(project.to_lower() + "/")): finish(); return
	run.call_deferred()

func _read_pinned(row: Variant, label: String) -> String:
	if not check(label + " explicit pinned file", row is Dictionary and row.has_all(["path", "sha256"]) and typeof(row.path) == TYPE_STRING and row.path.is_absolute_path() and typeof(row.sha256) == TYPE_STRING and row.sha256.length() == 64): return ""
	if not check(label + " real source file exists with exact SHA", FileAccess.file_exists(row.path) and FileAccess.get_sha256(row.path) == row.sha256): return ""
	var file := FileAccess.open(row.path, FileAccess.READ)
	if not check(label + " readable", file != null): return ""
	var raw: String = file.get_as_text(); file.close()
	provenance.append({"label": label, "path": row.path, "sha256": row.sha256, "utf8_bytes": raw.to_utf8_buffer().size()})
	return raw

func _parse(raw: String, label: String) -> Dictionary:
	var parser := JSON.new()
	if not check(label + " JSON syntax", parser.parse(raw) == OK): return {}
	if not check(label + " Dictionary", parser.data is Dictionary): return {}
	return parser.data

func run() -> void:
	var input := OS.get_environment("DAMING_NEGATIVE_MANIFEST").replace("\\", "/").simplify_path()
	if not check("V25_NEGATIVE_PREFLIGHT_FIXTURE_MISSING", input.is_absolute_path() and FileAccess.file_exists(input)): finish(); return
	manifest = _parse(_read_pinned({"path": input, "sha256": OS.get_environment("DAMING_NEGATIVE_MANIFEST_SHA256")}, "input manifest"), "input manifest")
	if not check("fixed complete A input manifest", typeof(manifest.get("schema")) == TYPE_STRING and manifest.get("schema") == INPUT_SCHEMA and manifest.has_all(FIXTURES + ["first_role", "content_version", "engine_sha256"]) and typeof(manifest.first_role) == TYPE_STRING and manifest.first_role in ROLES and typeof(manifest.content_version) == TYPE_STRING and typeof(manifest.engine_sha256) == TYPE_STRING): finish(); return
	role = manifest.first_role
	var raw := {}
	for name: String in FIXTURES:
		raw[name] = _read_pinned(manifest[name], name)
		if raw[name].is_empty(): finish(); return
	Core = load("res://scripts/run_battle_world_core.gd")
	Store = load("res://scripts/run_slot_store.gd")
	Codec = load("res://scripts/run_state_value_codec.gd")
	Factory = load("res://scripts/run_level8_world_factory.gd")
	Profiles = load("res://scripts/run_official_restore_profile.gd")
	trusted = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if not check("actual source and engine match source A and producer", trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("content_version") == manifest.content_version and trusted.get("engine_binary_sha256") == manifest.engine_sha256 and trusted.get("content_version") == OS.get_environment("DAMING_NEGATIVE_EXPECT_CONTENT") and FileAccess.get_sha256(OS.get_executable_path()) == manifest.engine_sha256 and manifest.engine_sha256 == OS.get_environment("DAMING_NEGATIVE_EXPECT_ENGINE"), trusted): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("fixed installed read-only Daming runtime", pack.get("ok", false), pack): finish(); return
	runtime = pack.runtime
	var probe: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var candidate_ok: bool = probe.has_method("_validate_daming_safe_pair") and probe._battle == null and probe._identity == null and probe._unit_plan.is_empty()
	probe.dispose()
	if not check("v25 Core pairing implementation actually installed", candidate_ok): finish(); return
	var report: Dictionary = _parse(raw.a_report, "actual A report")
	var handoff: Dictionary = _parse(raw.a_handoff, "actual A handoff")
	var packet: Dictionary = _parse(raw.a_packet, "actual saved packet")
	var world: Dictionary = _parse(raw.a_world, "actual saved world")
	base_envelope = _parse(raw.a_slot, "actual raw slot envelope")
	if not check("actual A native success evidence declared", report.get("schema") == "daming_safe_retreat_cross_process_report_v25" and report.get("case") == "A_single_save" and report.get("passed") == true and report.get("single_safe_disk_case_qualified") == true and report.get("first_role") == role and report.get("checks") is Array and not report.checks.is_empty() and report.checks.all(func(r): return r is Dictionary and r.get("passed") == true)): finish(); return
	if not check("actual A report frozen version/engine and distinct source process", report.get("trusted") is Dictionary and report.trusted.get("content_version") == trusted.content_version and report.trusted.get("engine_binary_sha256") == manifest.engine_sha256 and typeof(report.get("pid")) in [TYPE_INT, TYPE_FLOAT] and int(report.pid) > 0 and int(report.pid) != OS.get_process_id() and typeof(report.get("nonce")) == TYPE_STRING and not report.nonce.is_empty() and report.nonce != nonce): finish(); return
	if not check("actual A packet/world SHA recorded in native report", report.get("evidence") is Array and report.evidence.any(func(r): return r is Dictionary and r.get("sha256") == manifest.a_packet.sha256) and report.evidence.any(func(r): return r is Dictionary and r.get("sha256") == manifest.a_world.sha256)): finish(); return
	if not check("actual A handoff source/slot/role/pid/nonce agree", handoff.get("schema") == "daming_safe_retreat_cross_process_handoff_v25" and handoff.get("mode") == "A_single_save" and handoff.get("first_role") == role and handoff.get("pid") == report.pid and handoff.get("nonce") == report.nonce and handoff.get("generation") == 1 and handoff.get("file_sha256") == manifest.a_slot.sha256 and handoff.get("content_version") == trusted.content_version and handoff.get("engine_sha256") == manifest.engine_sha256 and handoff.get("packet") == packet and packet.get("world") == world): finish(); return
	var slot: RefCounted = Store.new("user://v25_negative_data_only_no_disk")
	var decoded: Dictionary = slot._decode(raw.a_slot)
	if not check("actual raw closed slot canonical chain model decode", decoded.get("ok", false) and decoded.get("revision") == 1 and decoded.get("file_sha256") == manifest.a_slot.sha256, decoded): finish(); return
	base = decoded.document
	if not check("source A typed packet is exact declared JSON snapshot", JSON.parse_string(JSON.stringify(base)) == packet and base.context == Profiles.DAMING_CONTEXT and base.world.content_version == trusted.content_version): finish(); return
	var native_base: Dictionary = slot._validate_document(base)
	if not check("actual A recovered native source document strictly valid", native_base.get("ok", false) and _exact(base, native_base.document), native_base): finish(); return
	# First validate the complete actual positive through Core. Only its accepted
	# Level/Graph may supply typed role IDs; no malformed fixture is cast to String.
	get_tree().paused = true
	if not _positive("source") or not _positive("json"): finish(); return
	var levels: Dictionary = _body(base, "level")
	var mission: Dictionary = _body(base, "mission")
	if levels.is_empty() or mission.is_empty(): finish(); return
	var first_ref: Variant = levels.references[role]
	var second_ref: Variant = levels.references["shi" if role == "lu" else "lu"]
	if not check("actual A required role IDs explicitly typed", typeof(first_ref) == TYPE_STRING and typeof(second_ref) == TYPE_STRING and not first_ref.is_empty() and not second_ref.is_empty()): finish(); return
	safe_id = first_ref; other_id = second_ref
	var safe: Dictionary = _unit(base, safe_id)
	var other: Dictionary = _unit(base, other_id)
	if not check("actual single-safe actor/event fixture", typeof(safe_id) == TYPE_STRING and typeof(other_id) == TYPE_STRING and safe_id != other_id and safe.get("values", {}).get("story_outcome") == "retreated" and other.get("values", {}).get("story_outcome") == "" and mission.events.has("daming_" + role + "_safe") and not mission.events.has("daming_" + ("shi" if role == "lu" else "lu") + "_safe")): finish(); return
	fixture_ready = true
	_build_specs()
	for spec: Dictionary in specs:
		for route_name: String in ["source", "json"]:
			if not _negative(spec, route_name): finish(); return
	for row: Dictionary in provenance:
		if not check("all actual source input bytes unchanged " + row.label, FileAccess.get_sha256(row.path) == row.sha256): finish(); return
	finish()

func _body(packet: Dictionary, section: String) -> Dictionary:
	var result: Dictionary = Codec.new().decode(packet.world.sections[section].payload)
	if not check("fixed payload decode " + section, result.ok and result.value is Dictionary, result): return {}
	return result.value

func _set_body(packet: Dictionary, section: String, value: Dictionary) -> bool:
	var result: Dictionary = Codec.new().encode(value)
	if not check("fixed payload encode " + section, result.ok, result): return false
	packet.world.sections[section]["payload"] = result.value
	return true

func _unit_index(packet: Dictionary, id: String) -> int:
	for i: int in range(packet.world.sections.units.records.size()):
		if packet.world.sections.units.records[i].entity_id == id: return i
	return -1

func _unit(packet: Dictionary, id: String) -> Dictionary:
	var index := _unit_index(packet, id)
	if not check("fixed original actor record present " + id, index >= 0): return {}
	var result: Dictionary = Codec.new().decode(packet.world.sections.units.records[index].payload)
	if not check("fixed original actor Codec payload complete " + id, result.ok and result.value is Dictionary and result.value.has_all(["values", "references", "ids", "pools", "inventory", "metadata", "node"]), result): return {}
	return result.value

func _set_unit(packet: Dictionary, id: String, data: Dictionary) -> bool:
	var index := _unit_index(packet, id)
	var result: Dictionary = Codec.new().encode(data)
	if not check("fixed actor DTO recode preserves envelope " + id, index >= 0 and result.ok, result): return false
	packet.world.sections.units.records[index]["payload"] = result.value
	return true

func _read_route(packet: Dictionary, route_name: String) -> Dictionary:
	var store: RefCounted = Store.new("user://v25_negative_data_only_no_disk")
	if route_name == "source": return store._validate_document(packet)
	var payload := JSON.stringify(packet)
	var envelope: Dictionary = base_envelope.duplicate(true)
	envelope["payload"] = payload
	envelope["payload_bytes"] = str(payload.to_utf8_buffer().size())
	envelope["payload_sha256"] = payload.sha256_text()
	# Original real envelope identity/revision/previous hash; a model negative,
	# never a new disk record. Actual Base._decode invokes the JSON Slot hook.
	return store._decode(JSON.stringify(envelope))

func _zero(core: RefCounted) -> bool:
	return core._battle == null and core._identity == null and core._unit_plan.is_empty()

func _positive(route_name: String) -> bool:
	var original: Dictionary = base.duplicate(true)
	var opened: Dictionary = _read_route(base, route_name)
	if not check("unmodified actual A " + route_name + " Slot route accepted", opened.get("ok", false) and _exact(base, original), opened): return false
	var before: Dictionary = opened.document.duplicate(true)
	var core: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	if not check("positive independent Core initially empty " + route_name, _zero(core)): core.dispose(); return false
	var prepared: Dictionary = core.prepare(opened.document.world)
	var accepted: bool = prepared.get("ok", false) and is_instance_valid(core._battle) and not core._battle.is_inside_tree() and core._battle.process_mode == Node.PROCESS_MODE_DISABLED and _exact(before, opened.document) and _exact(base, original)
	positives.append({"route": route_name, "actual_A_unmodified": true, "prepared": prepared.get("ok", false), "detached_inert": is_instance_valid(core._battle) and not core._battle.is_inside_tree(), "input_exact": _exact(before, opened.document) and _exact(base, original)})
	core.dispose()
	var disposed_zero := _zero(core)
	positives[-1]["disposed_zero"] = disposed_zero
	return check("actual A full-world positive prepare/dispose " + route_name, accepted and disposed_zero, prepared)

func _add(id: String, kind: String, expected: String, args: Dictionary = {}, layer: String = "paired") -> void:
	var spec := {"id": id, "kind": kind, "expected_code": expected, "expected_guard_layer": layer, "direct_pair_branch_coverage": layer == "paired" or layer == "pair_identity_type"}
	for key: String in args: spec[key] = args[key]
	specs.append(spec)

func _build_specs() -> void:
	_add("safe_queue_nonempty", "queue", "UNIT_LEVEL8_SAFE_RETREAT_QUEUE", {}, "full_unit_contract")
	for field: String in ["_chase_intent", "_group_cap", "_has_home", "_home", "_hua_lock_shots"]:
		_add("safe_stop_" + field, "stop", "UNIT_LEVEL8_SAFE_RETREAT_STOP_ANCHOR", {"field": field}, "full_unit_contract")
	_add("other_role_null", "other_null", "LEVEL8_SAFE_REQUIRED_ACTOR_MISSING")
	_add("other_dead_complete_lifetime", "other_dead", "LEVEL8_SAFE_REQUIRED_ACTOR_LIFETIME")
	_add("other_alive_missing_active", "other_active_drop", "LEVEL8_ACTIVE_MEMBERSHIP", {}, "full_graph_membership")
	_add("other_missing_root_record", "other_root_drop", "UNBOUND_UNIT", {}, "full_level_registry")
	_add("other_captured_outcome", "other_outcome", "UNIT_LEVEL8_UNSUPPORTED_STORY_OUTCOME", {}, "full_unit_contract")
	_add("safe_event_missing", "safe_event_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR")
	_add("safe_actor_outcome_empty", "safe_outcome_remove", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR")
	_add("other_safe_event_without_retreat", "other_event_add", "LEVEL8_SAFE_EVENT_OUTCOME_PAIR")
	_add("root_safe_selection", "root_selection", "LEVEL8_SAFE_SELECTED_ROOT")
	for field: String in ["_ability_caster", "_item_caster"]:
		_add("root_safe_" + field, "root_caster", "LEVEL8_SAFE_ARMED_CASTER", {"field": field})
	for kind: String in CASTERS:
		_add("safe_caster_" + kind, "cast", "LEVEL8_SAFE_CAST_INTENT", {"array": kind})
	_add("freed_event_missing", "freed_remove", "LEVEL8_SAFE_RESCUE_EVENT_PAIR")
	_add("rescue_done_false", "rescue_done", "LEVEL8_SAFE_RESCUE_EVENT_PAIR")
	var values: Array = [null, true, 1, 1.0, [], {}]
	var labels := ["nil", "bool", "int", "float", "array", "dictionary"]
	for section: String in RECORD_TEXT:
		for field: String in RECORD_TEXT[section]:
			for i: int in range(values.size()):
				_add("identity_" + section + "_" + field + "_" + labels[i], "identity", "LEVEL8_SAFE_IDENTITY_TEXT_TYPE", {"section": section, "path": [field], "value": values[i]}, "pair_identity_type")
	for section: String in ["mission", "presentation"]:
		for field: String in CONTEXT_TEXT:
			for i: int in range(values.size()):
				_add("identity_" + section + "_context_" + field + "_" + labels[i], "identity", "LEVEL8_SAFE_CONTEXT_TEXT_TYPE", {"section": section, "path": ["context", field], "value": values[i]}, "pair_identity_type")

func _mutate(packet: Dictionary, spec: Dictionary) -> bool:
	var kind: String = spec.kind
	if kind in ["queue", "stop", "safe_outcome_remove", "other_dead", "other_outcome"]:
		var id: String = other_id if kind in ["other_dead", "other_outcome"] else safe_id
		var data: Dictionary = _unit(packet, id)
		if data.is_empty(): return false
		if kind == "queue": data.references["_queue"] = [{"kind": "move", "pos": data.values.position, "group_cap": 0.0}]
		elif kind == "stop":
			match spec.field:
				"_chase_intent", "_hua_lock_shots": data.values[spec.field] = 1
				"_group_cap": data.values[spec.field] = 1.0
				"_has_home": data.values[spec.field] = false
				"_home": data.values[spec.field] = data.values.position + Vector2(1.0, 0.0)
		elif kind == "safe_outcome_remove": data.values["story_outcome"] = ""
		elif kind == "other_outcome": data.values["story_outcome"] = "captured"
		else:
			# Coupled original lifetime/membership stays consistent, reaching pair.
			data.values["hp"] = 0.0; data.values["_dying"] = true
			packet.world.sections.units.active_order.erase(other_id)
		return _set_unit(packet, id, data)
	if kind == "other_null":
		var levels: Dictionary = _body(packet, "level")
		levels.references["shi" if role == "lu" else "lu"] = null
		return _set_body(packet, "level", levels)
	if kind == "other_active_drop": packet.world.sections.units.active_order.erase(other_id); return true
	if kind == "other_root_drop":
		var index := _unit_index(packet, other_id)
		packet.world.sections.units.records.remove_at(index)
		packet.world.sections.units.root_order.erase(other_id)
		packet.world.sections.units.active_order.erase(other_id)
		# Never erase any cached grid/reference to manufacture a later rejection.
		return true
	if kind in ["safe_event_remove", "other_event_add", "freed_remove", "rescue_done"]:
		var mission: Dictionary = _body(packet, "mission")
		if kind == "safe_event_remove": mission.events.erase("daming_" + role + "_safe")
		elif kind == "other_event_add": mission.events.append("daming_" + ("shi" if role == "lu" else "lu") + "_safe")
		elif kind == "freed_remove": mission.events.erase("daming_prisoners_freed")
		else:
			var found := false
			for action: Dictionary in mission.actions:
				if action.id == "daming_rescue": action["done"] = false; found = true
			if not check("actual rescue action row found", found): return false
		return _set_body(packet, "mission", mission)
	if kind in ["root_selection", "root_caster"]:
		var root: Dictionary = _body(packet, "root")
		var tag := {"state": "entity", "id": safe_id}
		if kind == "root_selection": root.selection.append(tag)
		else: root.references[spec.field] = tag
		return _set_body(packet, "root", root)
	if kind == "cast":
		var section: String = "item_casts" if spec.array in ["_pending_item_casts", "_walk_item_casts"] else "casts"
		var data: Dictionary = _body(packet, section)
		var unit: Dictionary = _unit(packet, safe_id)
		var pos: Vector2 = unit.values.position
		var tag := {"state": "entity", "id": safe_id}
		var none := {"state": "none"}
		var entry := {}
		match spec.array:
			"_walk_casts": entry = {"c": tag, "slot": 0, "tgt": none, "point": {"mode": "point", "value": pos}, "serial": 0, "t": 0.0, "age": 0.0}
			"_pending_casts": entry = {"caster": tag, "slot": 0, "lp": pos, "tgt": none, "serial": 0}
			"_channels": entry = {"caster": tag, "center": pos, "eff": {"kind": "channel"}, "sc": 1.0, "rank": 1, "r": 1.0, "tick": 1.0, "tick_t": 0.0, "ad": {}}
			"_walk_item_casts": entry = {"c": tag, "uid": 1, "tgt": none, "point": {"mode": "point", "value": pos}, "serial": 0, "t": 0.0, "age": 0.0}
			"_pending_item_casts": entry = {"caster": tag, "slot": 0, "uid": 1, "point": pos, "target": none, "serial": 0}
		if not check("actual fixed cast array field exists", data.has(spec.array) and data[spec.array] is Array): return false
		data[spec.array].append(entry)
		return _set_body(packet, section, data)
	if kind == "identity":
		var record: Dictionary = packet.world.sections[spec.section]
		if spec.path.size() == 1: record[spec.path[0]] = spec.value
		else: record[spec.path[0]][spec.path[1]] = spec.value
		return true
	return check("known immutable fixed negative mutation", false, spec.kind)

func _canonical_json_int(spec: Dictionary, packet: Dictionary, before: Dictionary, base_before: Dictionary, fingerprint: String, opened: Dictionary) -> bool:
	# Actual JSON envelope route remains mandatory. Bare integer identity leaves
	# parse as Float; the unchanged Base exact canonical guard rejects before Core.
	var payload: String = JSON.stringify(packet)
	var parsed: Variant = JSON.parse_string(payload)
	if not check("canonical route actual JSON Dictionary " + spec.id, parsed is Dictionary): return false
	var parsed_before: Dictionary = parsed.duplicate(true)
	var hook: Dictionary = Store.new("user://v25_negative_data_only_no_disk")._validate_json_document(parsed)
	if not check("canonical route Slot document hook valid before exact-byte refusal " + spec.id, hook.get("ok", false), hook): return false
	var expected_normalized: Dictionary = packet.duplicate(true)
	var expected_record: Dictionary = expected_normalized.world.sections[spec.section]
	if spec.path.size() == 1: expected_record[spec.path[0]] = float(spec.value)
	else: expected_record[spec.path[0]][spec.path[1]] = float(spec.value)
	var record: Dictionary = hook.document.world.sections[spec.section]
	var leaf: Variant = record[spec.path[0]] if spec.path.size() == 1 else record[spec.path[0]][spec.path[1]]
	var normalized: String = JSON.stringify(hook.document)
	var core: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var initially_empty := _zero(core)
	# No Core.prepare call here. The observed refusal is the actual Store._decode
	# result already obtained by _read_route; this independent Core stays empty.
	var refused: bool = opened.get("ok") == false and opened.get("code") == "NONCANONICAL_RECORD"
	var one_leaf: bool = typeof(leaf) == TYPE_FLOAT and is_finite(leaf) and leaf == float(spec.value) and _exact(expected_normalized, hook.document) and normalized != payload
	var immutable: bool = _exact(packet, before) and _exact(base, base_before) and _exact(parsed, parsed_before) and JSON.stringify(packet).sha256_text() == fingerprint
	var no_allocation := _zero(core)
	var passed: bool = refused and one_leaf and immutable and initially_empty and no_allocation
	rows.append({"case": spec.id, "route": "json", "passed": passed, "expected_code": "NONCANONICAL_RECORD", "actual_code": opened.get("code", ""), "expected_guard_layer": "slot_exact_canonical", "direct_pair_branch_coverage": false,
		"core_prepare_called": false, "initially_empty": initially_empty, "zero_world_before_dispose": no_allocation, "core_battle_null": core._battle == null, "core_identity_null": core._identity == null, "core_unit_plan_empty": core._unit_plan.is_empty(),
		"source_input_type_ieee_exact": immutable, "mutated_packet_sha256": fingerprint, "typed_document_sha256": normalized.sha256_text(), "cached_grids_preserved": true, "actual_store_envelope_decode_called": true, "json_source_scalar_type": "int", "json_decoded_scalar_type": type_string(typeof(leaf)), "json_int_to_float_one_leaf_exact": one_leaf, "core_expected_if_reached": spec.expected_code,
		"detail": null if passed else _brief(opened)})
	core.dispose()
	return check("actual Slot canonical rejection/no Core.prepare/input immutable " + spec.id + "/json", passed, opened)


func _negative(spec: Dictionary, route_name: String) -> bool:
	var base_before: Dictionary = base.duplicate(true)
	var packet: Dictionary = base.duplicate(true)
	if not _mutate(packet, spec): return false
	var root_base: Dictionary = _body(base, "root")
	var root_mutated: Dictionary = _body(packet, "root")
	if not check("cached grids preserved by mutation " + spec.id, _exact(root_base.grids, root_mutated.grids) and _exact(root_base.identities, root_mutated.identities) and _exact(root_base.blockers, root_mutated.blockers)): return false
	var mutated_before: Dictionary = packet.duplicate(true)
	var fingerprint: String = JSON.stringify(packet).sha256_text()
	var opened: Dictionary = _read_route(packet, route_name)
	if route_name == "json" and spec.kind == "identity" and typeof(spec.value) == TYPE_INT:
		return _canonical_json_int(spec, packet, mutated_before, base_before, fingerprint, opened)
	if not check("negative valid Slot front schema reaches Core " + spec.id + "/" + route_name, opened.get("ok", false) and _exact(packet, mutated_before), opened): return false
	var typed_before: Dictionary = opened.document.duplicate(true)
	var core: RefCounted = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	var initially_empty := _zero(core)
	var prepared: Dictionary = core.prepare(opened.document.world)
	# Observe failure before cleanup; disposal alone could hide allocation.
	var no_allocation := _zero(core)
	var immutable := _exact(packet, mutated_before) and _exact(opened.document, typed_before) and _exact(base, base_before) and JSON.stringify(packet).sha256_text() == fingerprint
	var passed: bool = initially_empty and not prepared.get("ok", false) and prepared.get("code") == spec.expected_code and no_allocation and immutable
	rows.append({"case": spec.id, "route": route_name, "passed": passed, "expected_code": spec.expected_code, "actual_code": prepared.get("code", ""), "expected_guard_layer": spec.expected_guard_layer, "direct_pair_branch_coverage": spec.direct_pair_branch_coverage,
		"actual_store_envelope_decode_called": route_name == "json", "core_prepare_called": true, "initially_empty": initially_empty, "zero_world_before_dispose": no_allocation, "core_battle_null": core._battle == null, "core_identity_null": core._identity == null, "core_unit_plan_empty": core._unit_plan.is_empty(),
		"source_input_type_ieee_exact": immutable, "mutated_packet_sha256": fingerprint, "typed_document_sha256": JSON.stringify(typed_before).sha256_text(), "cached_grids_preserved": true, "detail": null if passed else _brief(prepared)})
	core.dispose()
	return check("exact rejection/no world allocation/input immutable " + spec.id + "/" + route_name, passed, prepared)

func finish() -> void:
	if finished: return
	finished = true
	var matrix_complete: bool = fixture_ready and positives.size() == 2 and not specs.is_empty() and rows.size() == specs.size() * 2 and rows.all(func(r): return r.passed)
	var passed: bool = matrix_complete and not checks.is_empty() and checks.all(func(r): return r.passed)
	var names: Array = specs.map(func(s): return s.id)
	var source_pins: Array = []
	for path: String in ["res://scripts/run_battle_world_core.gd", "res://scripts/run_level8_unit_contract.gd", "res://scripts/run_slot_store.gd", "res://scripts/run_snapshot_store.gd", "res://scripts/run_unit_graph.gd", "res://scripts/run_unit_state.gd", "res://scripts/run_graph_identity.gd", "res://scripts/run_battle_root_state.gd", "res://scripts/run_campaign_level_state.gd", "res://scripts/run_campaign_mission_state.gd", "res://scripts/run_campaign_presentation_state.gd", "res://scripts/run_cast_flow_state.gd", "res://scripts/run_item_cast_flow_state.gd", "res://scripts/run_state_value_codec.gd"]:
		source_pins.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var report := {"schema": REPORT_SCHEMA, "passed": passed, "pure_matrix_passed": passed, "fixture_ready": fixture_ready, "matrix_complete": matrix_complete, "planned_cases": names, "executed_rows": rows, "checks": checks, "positives": positives, "provenance": provenance,
		"source_files": source_pins, "harness_sha256": FileAccess.get_sha256(get_script().resource_path), "pid": OS.get_process_id(), "nonce": nonce, "first_role": role, "actual_user_data_dir": OS.get_user_data_dir(), "content_version": trusted.get("content_version", ""), "engine_sha256": FileAccess.get_sha256(OS.get_executable_path()),
		"whole_world_dto_negative_only": true, "store_routes": ["native_source_document", "actual_JSON_envelope_decode_hook"], "live_object_capture_negative_implemented": false, "live_object_capture_negative_qualified": false, "separate_component_harness_implemented": false, "overall_v25_qualified": false,
		"disk_slot_writes": 0, "direct_gameplay_calls": 0, "cached_grids_cleared": 0, "future_producer_integration_qualified": false,
		"not_implemented": ["live object capture negatives", "separate Unit/Pair component harness", "two-safe full coherent DTO and terminal/result branches beyond this fixed matrix", "all other packet/payload leaf types outside fixed five-record identity leaves"],
		"scope": "Actual qualified A raw source pinned; source/JSON Store hooks then independent complete Core.prepare. Exact fixed DTO failures and pre-dispose no-world states. No live capture negative, activation, ticks, save IO or feature qualification."}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output.get_base_dir()) and not FileAccess.file_exists(output):
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
		else: passed = false
	else: passed = false
	print("DAMING_SAFE_NEGATIVE_WORLD_V25_COMPLETE ", passed, " executed_rows=", rows.size())
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
