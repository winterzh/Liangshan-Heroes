extends "res://tools/daming_campaign_durable_cross_process_v1.gd"
## External, unexecuted live capture suite. Exactly one case per new process/profile.
## Inherit only the complete Session/install/world/packet/binding audits. Override
## all entry, driver, report and HELD methods; the old _hold is never invoked.
const CAPTURE_SCHEMA := "daming_campaign_capture_report_v1"
const CAPTURE_REVISION := "campaign_v2_r1"
const LIVE_CAST_FIELDS := ["_walk_casts", "_pending_casts", "_channels", "_pending_item_casts", "_walk_item_casts"]
const CAPTURE_INPUT_SCHEMA := "daming_campaign_capture_inputs_v1"
const CAPTURE_CASES := {
	"safe_queue_nonempty": "LEVEL8_SAFE_RETREAT_QUEUE",
	"safe_stop__chase_intent": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__group_cap": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__has_home": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__home": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"safe_stop__hua_lock_shots": "LEVEL8_SAFE_RETREAT_STOP_ANCHOR",
	"other_hp_zero": "LEVEL8_LIFETIME", "other_dying_true": "LEVEL8_LIFETIME",
	"other_role_null": "LEVEL8_SAFE_REQUIRED_ACTOR_MISSING",
	"other_alive_missing_active": "LEVEL8_ACTIVE_MEMBERSHIP",
	"other_outcome_captured": "LEVEL8_UNSUPPORTED_STORY_OUTCOME",
	"root_safe_selection": "LEVEL8_SAFE_SELECTED_ROOT",
	"root_safe__ability_caster": "LEVEL8_SAFE_ARMED_CASTER",
	"root_safe__item_caster": "LEVEL8_SAFE_ARMED_CASTER",
	"safe_event_missing": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"other_safe_event_without_retreat": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"safe_actor_outcome_empty": "LEVEL8_SAFE_EVENT_OUTCOME_PAIR",
	"freed_event_missing": "LEVEL8_SAFE_RESCUE_EVENT_PAIR",
	"rescue_done_false": "LEVEL8_SAFE_RESCUE_EVENT_PAIR",
	"safe_caster__walk_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__pending_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__channels": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__pending_item_casts": "LEVEL8_SAFE_CAST_INTENT",
	"safe_caster__walk_item_casts": "LEVEL8_SAFE_CAST_INTENT"
}
const IDENTITY_FIELDS := ["_entities", "_known_ids", "_object_ids", "_retired_ids", "_retired_sources", "_decoded_ids", "_decoded_sources", "_issued_id_tokens", "_issued_source_tokens", "_next_id_token", "_next_source_token", "_tombstones", "_expired", "_released"]
var capture_case := ""
var capture_manifest: Dictionary = {}
var capture_packet: Dictionary = {}
var capture_provenance: Array = []
var capture_adapter: RefCounted
var mutation: Dictionary = {}
var live_row: Dictionary = {}
var row_completed := false
var actual_negative_capture_called := false
var owned_installed_battle: Node
var evidence_serial := 0

func _brief(value: Variant) -> Dictionary:
	var out := {"type": type_string(typeof(value))}
	if value is Dictionary:
		for field: String in ["code", "path", "field", "section"]:
			if typeof(value.get(field)) == TYPE_STRING: out[field] = value[field].left(200)
		out["summary"] = "fields=" + str(value.size()) + "; ok=" + str(value.get("ok", "missing"))
	else: out["summary"] = str(value).left(200)
	return out

func check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"label": label, "passed": passed, "detail": null if passed else _brief(detail)})
	if not passed: print("V25_CAPTURE_FAIL ", label, " ", _brief(detail))
	return passed

func _clone(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

func _bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8); bytes.encode_double(0, value)
	return bytes.hex_encode()

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
	return is_same(a, b) if typeof(a) == TYPE_OBJECT else a == b

func _live_view(value: Variant) -> Variant:
	if typeof(value) == TYPE_OBJECT:
		return {"type": "Object", "valid": is_instance_valid(value), "object_id": str(value.get_instance_id()) if is_instance_valid(value) else "expired"}
	if typeof(value) == TYPE_FLOAT: return {"type": "Float", "ieee_f64": _bits(value)}
	if value is Dictionary:
		var entries: Array = []
		for key: Variant in value: entries.append({"key": _live_view(key), "value": _live_view(value[key])})
		return {"type": "Dictionary", "entries": entries}
	if value is Array:
		var items: Array = []
		for item: Variant in value: items.append(_live_view(item))
		return {"type": "Array", "items": items}
	var encoded: Dictionary = Codec.new().encode(value)
	return {"type": type_string(typeof(value)), "codec": encoded.get("value"), "codec_ok": encoded.get("ok", false)}

func _write_new_json(path: String, value: Variant) -> bool:
	# Inherited complete packet audit is called before AND after the mutation.
	# Give each raw artifact a fresh path; never overwrite an earlier audit.
	evidence_serial += 1
	var fresh: String = path.get_base_dir().path_join(str(evidence_serial).pad_zeros(4) + "_" + path.get_file())
	if not check("new evidence path unused " + fresh.get_file(), not FileAccess.file_exists(fresh)): return false
	var file := FileAccess.open(fresh, FileAccess.WRITE)
	if not check("complete raw evidence writable " + fresh.get_file(), file != null): return false
	file.store_string(JSON.stringify(value, "\t") + "\n"); file.close()
	evidence.append({"path": fresh, "sha256": FileAccess.get_sha256(fresh)})
	return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = OS.get_environment("DAMING_CAPTURE_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	output = OS.get_environment("DAMING_CAPTURE_OUT").replace("\\", "/").simplify_path().trim_suffix("/")
	nonce = OS.get_environment("DAMING_CAPTURE_NONCE")
	capture_case = OS.get_environment("DAMING_CAPTURE_CASE")
	mode = CASES[1] # Only inherited complete restore/audits run; no B gameplay driver.
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().trim_suffix("/").to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	if not safe: print("V25_CAPTURE PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	if not check("one implemented live row and fresh nonce", CAPTURE_CASES.has(capture_case) and not nonce.is_empty()): finish(); return
	if not check("fresh external evidence directory", output.is_absolute_path() and not DirAccess.dir_exists_absolute(output) and not output.to_lower().begins_with(project.to_lower() + "/")): finish(); return
	if not check("evidence directory created", DirAccess.make_dir_recursive_absolute(output) == OK): finish(); return
	run.call_deferred()

func _load_fixed_scripts() -> void:
	B = load("res://scripts/battle.gd")
	Daming = load("res://scripts/levels/level8_daming_rts.gd")
	Profiles = load("res://scripts/run_official_restore_profile.gd")
	Factory = load("res://scripts/run_level8_world_factory.gd")
	Provider = load("res://scripts/run_content_identity.gd")
	Session = load("res://scripts/run_world_session.gd")
	Store = load("res://scripts/run_slot_store.gd")
	Core = load("res://scripts/run_battle_world_core.gd")
	Codec = load("res://scripts/run_state_value_codec.gd")
	# The parent's natural route module and gameplay drivers are never loaded/called.

func _read_pinned(row: Variant, label: String) -> String:
	if not check(label + " explicit path/SHA", row is Dictionary and row.has_all(["path", "sha256"]) and typeof(row.path) == TYPE_STRING and row.path.is_absolute_path() and typeof(row.sha256) == TYPE_STRING and row.sha256.length() == 64 and row.sha256.is_valid_hex_number()): return ""
	if not check(label + " exact SHA", FileAccess.file_exists(row.path) and FileAccess.get_sha256(row.path) == row.sha256): return ""
	var file := FileAccess.open(row.path, FileAccess.READ)
	if not check(label + " readable", file != null): return ""
	var bytes: PackedByteArray = file.get_buffer(file.get_length()); file.close()
	var text := bytes.get_string_from_utf8()
	if not check(label + " full UTF8", not bytes.is_empty() and text.to_utf8_buffer() == bytes): return ""
	capture_provenance.append({"label": label, "path": row.path, "sha256": row.sha256, "bytes": bytes.size()})
	return text

func _parse(raw: String, label: String) -> Dictionary:
	var parser := JSON.new()
	if not check(label + " JSON Dictionary", parser.parse(raw) == OK and parser.data is Dictionary): return {}
	return parser.data

func _scan(path: String, relative := "") -> Dictionary:
	var files := {}
	var dir := DirAccess.open(path)
	if dir == null: return {"__ERROR_OPEN__": path}
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			if dir.is_link(name): dir.list_dir_end(); return {"__ERROR_LINK__": name}
			var child: String = path.path_join(name)
			var rel: String = name if relative.is_empty() else relative.path_join(name)
			if dir.current_is_dir(): files.merge(_scan(child, rel))
			else: files[rel] = FileAccess.get_sha256(child)
		name = dir.get_next()
	dir.list_dir_end()
	return files

func _profile_check() -> bool:
	if not check("actual A slot/local journal manifest nonempty", capture_manifest.get("profile_files") is Array and not capture_manifest.profile_files.is_empty()): return false
	var expected := {}
	var scope: String = ProjectSettings.globalize_path(SLOT_ROOT).replace("\\", "/").simplify_path().trim_suffix("/")
	for row: Variant in capture_manifest.profile_files:
		if not check("fixed relative slot-scope path", row is Dictionary and row.has_all(["path", "sha256", "relative"]) and typeof(row.relative) == TYPE_STRING and not row.relative.is_empty() and not row.relative.is_absolute_path() and row.relative.replace("\\", "/").simplify_path() == row.relative and not row.relative.begins_with("../") and not expected.has(row.relative)): return false
		if _read_pinned(row, "actual A slot/journal " + row.relative).is_empty(): return false
		expected[row.relative] = row.sha256
		if not check("owned private profile copy exact " + row.relative, FileAccess.get_sha256(scope.path_join(row.relative)) == row.sha256): return false
	if not check("complete slot/local journal file keyset+SHA exact", _exact(_scan(scope), expected)): return false
	return check("owned real A handoff exact raw bytes", FileAccess.get_sha256(HANDOFF_A) == capture_manifest.a_handoff.sha256)

func run() -> void:
	var path := OS.get_environment("DAMING_CAPTURE_MANIFEST")
	if not check("V25_CAPTURE_PREFLIGHT_ACTUAL_A_REQUIRED", path.is_absolute_path() and FileAccess.file_exists(path)): finish(); return
	capture_manifest = _parse(_read_pinned({"path": path, "sha256": OS.get_environment("DAMING_CAPTURE_MANIFEST_SHA256")}, "capture manifest"), "capture manifest")
	var names := ["a_report", "a_handoff", "a_packet", "a_world", "a_slot"]
	if not check("full actual A input schema", typeof(capture_manifest.get("schema")) == TYPE_STRING and capture_manifest.schema == CAPTURE_INPUT_SCHEMA and capture_manifest.has_all(names + ["first_role", "content_version", "engine_sha256", "profile_files"]) and typeof(capture_manifest.first_role) == TYPE_STRING and capture_manifest.first_role in ["lu", "shi"] and typeof(capture_manifest.content_version) == TYPE_STRING and not capture_manifest.content_version.is_empty() and typeof(capture_manifest.engine_sha256) == TYPE_STRING and capture_manifest.engine_sha256.length() == 64 and capture_manifest.engine_sha256.is_valid_hex_number()): finish(); return
	first_role = capture_manifest.first_role
	var raw := {}
	for name: String in names:
		raw[name] = _read_pinned(capture_manifest[name], name)
		if raw[name].is_empty(): finish(); return
	_load_fixed_scripts()
	var startup_flow: Node = get_node("/root/ContinueFlow")
	var gate: Script = load("res://scripts/run_campaign_progress_gate.gd")
	for frame in range(180): await get_tree().process_frame
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check("production startup checked before any matrix factory or world", startup_flow.phase == startup_flow.Phase.IDLE and startup_flow.last_result.get("startup_checked",false) and gate.background_allowed(), startup_flow.last_result.duplicate(true)): finish(); return
	if not check("normal installed clock configuration", Engine.physics_ticks_per_second == 60 and is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(get_node("/root/Settings").game_speed, 1.0)): finish(); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("actual source/engine match A and producer", trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("content_version") == capture_manifest.content_version and trusted.get("engine_binary_sha256") == capture_manifest.engine_sha256 and trusted.get("content_version") == OS.get_environment("DAMING_CAPTURE_EXPECT_CONTENT") and capture_manifest.engine_sha256 == OS.get_environment("DAMING_CAPTURE_EXPECT_ENGINE") and capture_manifest.engine_sha256 == FileAccess.get_sha256(OS.get_executable_path()), trusted): finish(); return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("installed fixed runtime available", pack.get("ok", false), pack): finish(); return
	runtime = pack.runtime
	capture_adapter = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT)
	if not check("actual V25 pair method installed", capture_adapter.has_method("_validate_daming_safe_pair")): finish(); return
	var source_report := _parse(raw.a_report, "actual A report")
	var source_handoff := _parse(raw.a_handoff, "actual A handoff")
	var packet_json := _parse(raw.a_packet, "actual A packet")
	var world_json := _parse(raw.a_world, "actual A world")
	if not check("A actual native success", source_report.get("schema") == "daming_campaign_durable_cross_process_report_v1" and source_report.get("case") == "A_single_save" and source_report.get("first_role") == first_role and source_report.get("passed") == true and source_report.get("single_safe_disk_case_qualified") == true and source_report.get("checks") is Array and not source_report.checks.is_empty() and source_report.checks.all(func(r): return r is Dictionary and r.get("passed") == true)): finish(); return
	if not check("A source identity and independent PID/nonce", source_report.get("trusted") is Dictionary and source_report.trusted.get("content_version") == trusted.content_version and source_report.trusted.get("engine_binary_sha256") == capture_manifest.engine_sha256 and typeof(source_report.get("pid")) in [TYPE_INT, TYPE_FLOAT] and int(source_report.pid) > 0 and int(source_report.pid) != OS.get_process_id() and typeof(source_report.get("nonce")) == TYPE_STRING and not source_report.nonce.is_empty() and source_report.nonce != nonce): finish(); return
	if not check("A report binds exact packet and world SHA", source_report.get("evidence") is Array and source_report.evidence.any(func(r): return r is Dictionary and r.get("sha256") == capture_manifest.a_packet.sha256) and source_report.evidence.any(func(r): return r is Dictionary and r.get("sha256") == capture_manifest.a_world.sha256)): finish(); return
	if not check("A handoff exact process/role/identity/slot/packet", source_handoff.get("schema") == "daming_safe_retreat_cross_process_handoff_v25" and source_handoff.get("mode") == "A_single_save" and source_handoff.get("first_role") == first_role and source_handoff.get("pid") == source_report.pid and source_handoff.get("nonce") == source_report.nonce and source_handoff.get("generation") == 1 and source_handoff.get("file_sha256") == capture_manifest.a_slot.sha256 and source_handoff.get("content_version") == trusted.content_version and source_handoff.get("engine_sha256") == capture_manifest.engine_sha256 and source_handoff.get("packet") == packet_json and packet_json.get("world") == world_json): finish(); return
	if not _profile_check(): finish(); return
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot()
	if not check("actual private closed gen1 slot canonical SHA/packet", slot.get("ok", false) and slot.revision == 1 and slot.file_sha256 == capture_manifest.a_slot.sha256 and JSON.parse_string(JSON.stringify(slot.document)) == packet_json and slot.document.context == Profiles.DAMING_CONTEXT and slot.document.resume_paused, slot): finish(); return
	capture_packet = slot.document.duplicate(true)
	battle = await _restore()
	if not is_instance_valid(battle): finish(); return
	if not _exercise(): finish(); return
	for row: Dictionary in capture_provenance:
		if not check("all real source bytes unchanged " + row.label, FileAccess.get_sha256(row.path) == row.sha256): finish(); return
	if not _profile_check(): finish(); return
	row_completed = true
	finish()

func _restore() -> Node:
	handoff = _read_json(HANDOFF_A if mode == CASES[1] else HANDOFF_B)
	if not check("complete prior process handoff", handoff.has_all(["schema", "mode", "pid", "nonce", "first_role", "content_version", "engine_sha256", "file_sha256", "generation", "packet", "state", "source_timing", "ancestor_pids", "ancestor_nonces"])): return null
	var expected_mode: String = CASES[0] if mode == CASES[1] else CASES[1]
	if not check("correct preceding genuinely distinct process", handoff.schema == "daming_safe_retreat_cross_process_handoff_v25" and handoff.mode == expected_mode and handoff.first_role == first_role and int(handoff.pid) != OS.get_process_id() and handoff.nonce != nonce and not handoff.ancestor_pids.has(OS.get_process_id()) and not handoff.ancestor_nonces.has(nonce)): return null
	if not check("same frozen source and actual engine across processes", handoff.content_version == trusted.content_version and handoff.engine_sha256 == trusted.engine_binary_sha256): return null
	var slot: Dictionary = Store.new(SLOT_ROOT).read_slot(true)
	if not check("prior disk bytes and generation verified", slot.get("ok", false) and slot.file_sha256 == handoff.file_sha256 and slot.revision == int(handoff.generation), slot.get("code", "")): return null
	# The actual Store hash above proves disk bytes. Normalize only this external
	# handoff comparison through JSON; it gives both sides identical number types.
	# All strict component comparisons below use the Store-validated packet.
	if not check("handoff retains the full committed packet", JSON.parse_string(JSON.stringify(slot.document)) == handoff.packet): return null
	if not _write_new_json(output.path_join("input_packet.json"), slot.document): return null
	if not _write_new_json(output.path_join("input_world.json"), slot.document.world): return null
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	restore_session = Session.new(trusted, runtime, SLOT_ROOT)
	var prepare_before: int = Time.get_ticks_msec()
	var prepared: Dictionary = restore_session.prepare_restore(menu)
	var prepare_after: int = Time.get_ticks_msec()
	if not check("actual Session prepare_restore succeeds", prepared.get("ok", false), prepared): return null
	if not check("old menu retained and new entire Battle detached inert", get_tree().current_scene == menu and not prepared.battle.is_inside_tree() and prepared.battle.process_mode == Node.PROCESS_MODE_DISABLED): return null
	# Stage separately only to observe the real Session mount bounds and rebased
	# pointer stamps. commit_restore_async then owns native layout/final activation.
	var mount_before: int = Time.get_ticks_msec()
	var staged: Dictionary = restore_session.stage_mount()
	var mount_after: int = Time.get_ticks_msec()
	if not check("actual Session paused stage_mount succeeds", staged.get("ok", false), staged): return null
	var mounted_input_stamps := {}
	for field: String in ["_last_group_time", "_press_ms", "_last_tap_ms"]: mounted_input_stamps[field] = staged.battle.get(field)
	var before_commit_physics: int = Engine.get_physics_frames()
	var installed: Dictionary = await restore_session.commit_restore_async(120)
	var after_commit_physics: int = Engine.get_physics_frames()
	if not check("actual Session commit_restore_async succeeds", installed.get("ok", false), installed): return null
	var b: Node = installed.battle
	# Record only the actual successful Session handoff, before any later audit.
	owned_installed_battle = b
	retained_identity = installed.identity
	var activation_physics: int = b._run_clock._engine_anchor
	if not check("complete installed paused Battle and local resume", get_tree().current_scene == b and b.get_parent() == get_tree().root and get_tree().paused and _healthy(b) and not installed.steam_credit and installed.generation == slot.revision and installed.paused == slot.document.resume_paused and activation_physics >= before_commit_physics and activation_physics <= after_commit_physics): return null
	if not await _hold(b, "restored complete world"): return null
	if not _verify_packet_install(b, slot.document): return null
	var fresh_before: int = Time.get_ticks_msec()
	var fresh_process: int = Engine.get_process_frames()
	var fresh_stage_started: int = b.mission._stage_started_ms
	var capture: Dictionary = Core.new(trusted, runtime, {}, null, Profiles.DAMING_CONTEXT).capture(b, retained_identity)
	var fresh_after: int = Time.get_ticks_msec()
	if not check("fresh full Core capture at real restored HELD", capture.get("ok", false), capture): return null
	if not _write_new_json(output.path_join("restored_world.json"), capture.record): return null
	var times := {"prepare_before": prepare_before, "prepare_after": prepare_after, "mount_before": mount_before, "mount_after": mount_after, "mounted_input_stamps": mounted_input_stamps, "activation_physics": activation_physics, "held_physics": held_physics, "fresh_before": fresh_before, "fresh_after": fresh_after, "fresh_process": fresh_process, "fresh_stage_started": fresh_stage_started}
	if not _compare_complete_world(slot.document.world, capture.record, times): return null
	if not _audit_bindings(b): return null
	observations.append({"restored": _retreat_state(b), "clock_audit": times})
	return b

func _retreat_state(b: Node) -> Dictionary:
	return {"phase": b.phase, "lu_id": str(b.level.lu.entity_id), "shi_id": str(b.level.shi.entity_id), "lu_outcome": b.level.lu.story_outcome, "shi_outcome": b.level.shi.story_outcome, "events": b.mission.events.duplicate(true), "mission_elapsed": b.mission.elapsed, "level_elapsed": b.level.elapsed, "next_tick": str(b._run_clock._next_tick)}

func _node_ids(node: Node) -> Array:
	var result: Array = [str(node.get_instance_id())]
	for child: Node in node.get_children(true): result.append_array(_node_ids(child))
	return result

func _identity_snapshot() -> Dictionary:
	var result := {}
	for name: String in IDENTITY_FIELDS: result[name] = _clone(retained_identity.get(name))
	return result

func _live_cast_entry(safe: Node, field: String) -> Dictionary:
	# These are native Object references and native Vector2 values, never saved DTO tags.
	# No command, allocator, cooldown, Unit setter or gameplay consumer is called.
	var serial: int = safe._order_serial if field in ["_walk_casts", "_walk_item_casts"] else safe._cast_serial
	if field != "_channels" and not check("actual original cast/order serial acceptable", serial >= (-1 if field in ["_walk_casts", "_walk_item_casts"] else 0)): return {}
	var uid := 0
	if field in ["_pending_item_casts", "_walk_item_casts"]:
		# Battle's allocator issues monotonically from 1 and never reuses a UID.
		# Original ItemFlow explicitly accepts a consumed/transferred retired alias.
		# Use an already-issued alias below the actual unchanged counter, never allocate.
		if not check("actual issued item alias exists without changing allocator", typeof(battle.get("next_item_uid")) == TYPE_INT and battle.next_item_uid > 1 and battle.next_item_uid <= Core.ItemCasts.MAX_UID): return {}
		uid = battle.next_item_uid - 1
	match field:
		"_walk_casts": return {"c": safe, "slot": 0, "tgt": null, "point": safe.position, "serial": serial, "t": 0.4, "age": 0.0}
		"_pending_casts": return {"caster": safe, "slot": 0, "lp": safe.position, "tgt": null, "serial": serial}
		"_channels": return {"caster": safe, "center": safe.position, "eff": {"kind": "channel", "dur": 3.0, "tick": 0.5}, "sc": 1.0, "rank": 1, "r": 110.0, "tick": 0.5, "tick_t": 0.0, "ad": {}}
		"_pending_item_casts": return {"caster": safe, "slot": 0, "uid": uid, "point": safe.position, "target": null, "serial": serial}
		"_walk_item_casts": return {"c": safe, "uid": uid, "tgt": null, "point": safe.position, "serial": serial, "t": 0.4, "age": 0.0}
	return {}

func _capture_cast_component(field: String) -> Dictionary:
	var ids := {}
	for unit: Node in battle.units_root.get_children(true): ids[unit] = str(unit.entity_id)
	var module: RefCounted = Core.ItemCasts.new(Codec, B, Core.U) if field in ["_pending_item_casts", "_walk_item_casts"] else Core.Casts.new(Codec, B, Core.U)
	return module.capture(battle, trusted.content_version, ids)

func _capture_guard_layer(refusal: Dictionary) -> String:
	if refusal.get("code") == "LEVEL8_SAFE_CAST_INTENT": return "level8_safe_pair"
	if typeof(refusal.get("section")) == TYPE_STRING: return "Core.capture section " + refusal.section
	return "Core.capture earlier validator or unknown layer"

func _make_mutation() -> Dictionary:
	var safe: Node = battle.level.get(first_role)
	var other: Node = battle.level.get("shi" if first_role == "lu" else "lu")
	if not check("real single-safe actors and events before negative", is_instance_valid(safe) and is_instance_valid(other) and safe.get_script() == Core.U and other.get_script() == Core.U and safe != other and safe.story_outcome == "retreated" and other.story_outcome == "" and safe.hp > 0.0 and other.hp > 0.0 and not other._dying and battle.units.has(safe) and battle.units.has(other) and safe.get_parent() == battle.units_root and other.get_parent() == battle.units_root and battle.mission.has_event("daming_" + first_role + "_safe") and not battle.mission.has_event("daming_" + ("shi" if first_role == "lu" else "lu") + "_safe")): return {}
	var target: Object = safe
	var field := ""
	var temporary: Variant = null
	if capture_case.begins_with("safe_caster_"):
		target = battle; field = capture_case.trim_prefix("safe_caster_")
		if not check("one actual existing cast array", field in LIVE_CAST_FIELDS and typeof(battle.get(field)) == TYPE_ARRAY): return {}
		var entry: Dictionary = _live_cast_entry(safe, field)
		if entry.is_empty(): return {}
		temporary = _clone(battle.get(field)); temporary.append(entry)
	elif capture_case == "safe_queue_nonempty": field = "_queue"; temporary = [{"kind": "move", "pos": safe.position, "group_cap": 0.0}]
	elif capture_case.begins_with("safe_stop_"):
		field = capture_case.trim_prefix("safe_stop_")
		match field:
			"_chase_intent", "_hua_lock_shots": temporary = 1
			"_group_cap": temporary = 1.0
			"_has_home": temporary = false
			"_home": temporary = safe.position + Vector2(1.0, 0.0)
	elif capture_case == "other_hp_zero": target = other; field = "hp"; temporary = 0.0
	elif capture_case == "other_dying_true": target = other; field = "_dying"; temporary = true
	elif capture_case == "other_role_null": target = battle.level; field = "shi" if first_role == "lu" else "lu"
	elif capture_case == "other_alive_missing_active": target = battle; field = "units"; temporary = battle.units.duplicate(); temporary.erase(other)
	elif capture_case == "other_outcome_captured": target = other; field = "story_outcome"; temporary = "captured"
	elif capture_case == "root_safe_selection": target = battle; field = "selection"; temporary = battle.selection.duplicate(); temporary.append(safe)
	elif capture_case.begins_with("root_safe_"): target = battle; field = capture_case.trim_prefix("root_safe_"); temporary = safe
	elif capture_case == "safe_actor_outcome_empty": field = "story_outcome"; temporary = ""
	elif capture_case in ["safe_event_missing", "other_safe_event_without_retreat", "freed_event_missing"]:
		target = battle.mission; field = "events"; temporary = battle.mission.events.duplicate(true)
		if capture_case == "safe_event_missing": temporary.erase("daming_" + first_role + "_safe")
		elif capture_case == "freed_event_missing": temporary.erase("daming_prisoners_freed")
		else: temporary["daming_" + ("shi" if first_role == "lu" else "lu") + "_safe"] = true
	elif capture_case == "rescue_done_false":
		target = battle.mission; field = "actions"; temporary = battle.mission.actions.duplicate(true)
		if not check("actual rescue action exists and completed", temporary.has("daming_rescue") and temporary.daming_rescue.done): return {}
		temporary.daming_rescue.done = false
	if not check("one exact actual object property selected", not field.is_empty() and is_instance_valid(target) and not _exact(target.get(field), temporary)): return {}
	return {"target": target, "field": field, "original": target.get(field), "original_snapshot": _clone(target.get(field)), "temporary": temporary, "object_id": str(target.get_instance_id())}

func _compare_held(before: Dictionary, after: Dictionary, bounds: Dictionary) -> bool:
	var left: Dictionary = before.duplicate(true)
	var right: Dictionary = after.duplicate(true)
	if not check("post-restore complete envelope and section keysets exact", _same_keys(left, right) and _exact(left.profile, right.profile) and _same_keys(left.sections, right.sections) and left.sections.size() == Core.CAMPAIGN_SECTIONS.size() and left.sections.has_all(Core.CAMPAIGN_SECTIONS)): return false
	for name: String in ["root", "mission"]:
		var opened_before: Dictionary = Codec.new().decode(left.sections[name].payload)
		var opened_after: Dictionary = Codec.new().decode(right.sections[name].payload)
		if not check("complete comparison payload decode " + name, opened_before.get("ok", false) and opened_after.get("ok", false)): return false
		var a: Dictionary = opened_before.value
		var b: Dictionary = opened_after.value
		if name == "mission":
			if not check("only actual wall age advance inside real capture bounds", battle.mission._stage_started_ms == bounds.stage_started and a.values.stage_age_ms >= bounds.before_min - bounds.stage_started and a.values.stage_age_ms <= bounds.before_max - bounds.stage_started and b.values.stage_age_ms >= bounds.after_min - bounds.stage_started and b.values.stage_age_ms <= bounds.after_max - bounds.stage_started): return false
			b.values.stage_age_ms = a.values.stage_age_ms
		else:
			if not check("HELD root physics/process/logical/cache clocks exact", _exact(a.simulation, b.simulation) and _exact(a.clock_values, b.clock_values) and a.clocks.physics == b.clocks.physics and a.clocks.process == b.clocks.process and a.clocks.process == bounds.process and a.clocks.msec >= bounds.before_min and a.clocks.msec <= bounds.before_max and b.clocks.msec >= bounds.after_min and b.clocks.msec <= bounds.after_max): return false
			b.clocks.msec = a.clocks.msec
		if not check("all decoded fields exact after only audited wall time leaf " + name, _exact(a, b)): return false
		# Retain entire wrappers. Only payload values whose one wall leaf was
		# independently bounded above can now compare using the original codec.
		right.sections[name].payload = left.sections[name].payload.duplicate(true)
	return check("every full world field/type/IEEE restored exactly", _exact(left, right))

func _exercise() -> bool:
	var before_min := Time.get_ticks_msec()
	var baseline: Dictionary = capture_adapter.capture(battle, retained_identity)
	var before_max := Time.get_ticks_msec()
	if not check("before-mutation actual whole source capture", baseline.get("ok", false) and baseline.get("identity") == retained_identity, baseline): return false
	if not _write_new_json(output.path_join("before_world.json"), baseline.record): return false
	var nodes_before := _node_ids(battle)
	var identity_before := _identity_snapshot()
	var canvas_before := get_tree().root.canvas_transform
	var physics_before := Engine.get_physics_frames()
	var process_before := Engine.get_process_frames()
	var next_tick: int = battle._run_clock._next_tick
	var stage_started: int = battle.mission._stage_started_ms
	mutation = _make_mutation()
	if mutation.is_empty(): return false
	var target: Object = mutation.target
	target.set(mutation.field, mutation.temporary)
	var applied := _exact(target.get(mutation.field), mutation.temporary)
	var cast_case: bool = capture_case.begins_with("safe_caster_")
	var cast_component: Dictionary = _capture_cast_component(mutation.field) if cast_case else {}
	actual_negative_capture_called = true
	var refusal: Dictionary = capture_adapter.capture(battle, retained_identity)
	var temporary_unchanged := _exact(target.get(mutation.field), mutation.temporary)
	# Synchronous single-field undo: no await, signal, tick, protection or broad reset.
	target.set(mutation.field, mutation.original)
	var restored_typed := _exact(target.get(mutation.field), mutation.original_snapshot) and _exact(mutation.original, mutation.original_snapshot)
	var after_min := Time.get_ticks_msec()
	var restored: Dictionary = capture_adapter.capture(battle, retained_identity)
	var after_max := Time.get_ticks_msec()
	var exact_code: bool = refusal.get("ok") == false and refusal.get("code") == CAPTURE_CASES[capture_case]
	if cast_case: exact_code = exact_code and cast_component.get("ok", false) and refusal.get("section") == mutation.field
	var identity_ok: bool = is_instance_valid(retained_identity) and _exact(identity_before, _identity_snapshot()) and restored.get("identity") == retained_identity
	var held_ok: bool = get_tree().paused and battle._save_barrier.state == battle._save_barrier.State.HELD and battle._save_barrier.health().ok and battle._run_clock._next_tick == next_tick and Engine.get_physics_frames() == physics_before and Engine.get_process_frames() == process_before and get_tree().current_scene == battle and _exact(canvas_before, get_tree().root.canvas_transform) and _exact(nodes_before, _node_ids(battle))
	live_row = {"case": capture_case, "first_role": first_role, "expected_code": CAPTURE_CASES[capture_case], "actual_code": refusal.get("code", ""), "actual_Core_capture_called": actual_negative_capture_called, "DTO_substitution": false, "single_live_field_applied": applied, "temporary_field_unchanged_by_capture": temporary_unchanged, "original_field_type_ieee_restored": restored_typed, "retained_identity_same_live_unchanged": identity_ok, "source_held_no_ticks_no_nodes_added": held_ok, "original_target_object_id": mutation.object_id, "field": mutation.field, "original_typed_view": _live_view(mutation.original_snapshot), "temporary_typed_view": _live_view(mutation.temporary), "refusal_summary": _brief(refusal), "passed": false}
	live_row["cast_component_capture_called"] = cast_case
	live_row["cast_component_capture_accepted"] = cast_component.get("ok", false) if cast_case else false
	live_row["cast_component_actual_code"] = cast_component.get("code", "") if cast_case else "not_run_original_19_case"
	live_row["expected_guard_layer"] = "level8_safe_pair" if cast_case else "original_fixed_capture_guard"
	live_row["actual_guard_layer"] = _capture_guard_layer(refusal)
	live_row["actual_section"] = refusal.get("section", "")
	live_row["actual_field"] = refusal.get("field", "")
	live_row["expected_pair_array"] = mutation.field if cast_case else ""
	live_row["actual_pair_array"] = refusal.get("section", "") if refusal.get("code") == "LEVEL8_SAFE_CAST_INTENT" else ""
	live_row["direct_safe_cast_pair_coverage"] = cast_case and exact_code
	if cast_case:
		live_row["actual_caster_object_id"] = str(battle.level.get(first_role).get_instance_id())
		live_row["actual_item_counter_unchanged"] = battle.next_item_uid
		if not _write_new_json(output.path_join("cast_component_capture.json"), cast_component): return false
	if not check("actual live capture exact controlled refusal", applied and temporary_unchanged and exact_code, refusal): return false
	if not check("original typed property and caller-owned identity restored", restored_typed and identity_ok): return false
	if not check("source remains exact HELD with no ticks/nodes/scene change", held_ok): return false
	if not check("after-undo complete actual capture succeeds", restored.get("ok", false), restored): return false
	if not _write_new_json(output.path_join("after_world.json"), restored.record): return false
	if not _compare_held(baseline.record, restored.record, {"before_min": before_min, "before_max": before_max, "after_min": after_min, "after_max": after_max, "stage_started": stage_started, "process": process_before}): return false
	if not _verify_packet_install(battle, capture_packet) or not _audit_bindings(battle): return false
	live_row.passed = true
	return _write_new_json(output.path_join("live_mutation_audit.json"), live_row)

func finish() -> void:
	if finished: return
	finished = true
	if not mutation.is_empty() and is_instance_valid(mutation.get("target")):
		mutation.target.set(mutation.field, mutation.original)
	var passed: bool = row_completed and live_row.get("passed", false) and not checks.is_empty() and checks.all(func(r): return r.passed)
	var report := {"schema": CAPTURE_SCHEMA, "passed": passed, "row_completed": row_completed, "case": capture_case, "first_role": first_role, "pid": OS.get_process_id(), "nonce": nonce, "actual_user_data_dir": OS.get_user_data_dir(), "private_profile": profile, "content_version": trusted.get("content_version", ""), "engine_sha256": FileAccess.get_sha256(OS.get_executable_path()), "checks": checks, "observations": observations, "evidence": evidence, "provenance": capture_provenance, "executed_live_row": live_row, "actual_Core_capture_called": actual_negative_capture_called, "actual_live_object_capture": actual_negative_capture_called, "whole_live_capture_matrix_qualified": false, "overall_v25_qualified": false, "separate_component_harness_implemented": false, "native_log_zero_ERROR_verified": false, "implemented_cases": CAPTURE_CASES.keys(), "harness_revision": CAPTURE_REVISION, "planned_cases": 24, "planned_roles": ["lu", "shi"], "live_cast_cases_implemented": 5, "not_run_scope": ["all 24-by-two-role native matrix aggregation not executed", "record schema/identity types are DTO-only; no user-settable live identity leaf", "full role/case/process matrix aggregation requires producer", "natural terminal/reward/tick regressions"], "source_row_isolation": "one case per fresh independent process/profile; complete actual A Session installed", "successful_handoff_owned_world_tracked": is_instance_valid(owned_installed_battle), "hold_helper_source": "v24s 76ed6f114de755b398112778ddabf5af820a30237b75070a5a2aaaea188b87db", "hold_helper_native_qualified_at_preparation": false, "base_harness_sha256": FileAccess.get_sha256("res://tools/daming_safe_retreat_cross_process_v25.gd"), "harness_sha256": FileAccess.get_sha256(get_script().resource_path), "disk_slot_writes": 0, "gameplay_ticks_injected": 0, "grid_clears": 0, "runtime_patches": 0}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output.path_join("report.json")):
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
		else: passed = false
	else: passed = false
	# Session.handoff_world gives caller ownership. Installed Session.dispose does
	# not release it. Free source once, then retained identity once, after evidence.
	if is_instance_valid(owned_installed_battle):
		owned_installed_battle.queue_free()
		await get_tree().process_frame
	owned_installed_battle = null
	battle = null
	if retained_identity != null: retained_identity.dispose(); retained_identity = null
	if capture_adapter != null: capture_adapter.dispose(); capture_adapter = null
	if restore_session != null: restore_session.dispose(); restore_session = null
	print("DAMING_SAFE_CAPTURE_V25_COMPLETE ", capture_case, " ", passed)
	if get_node_or_null("/root/Sfx") != null: get_node("/root/Sfx").shutdown()
	if get_node_or_null("/root/Music") != null: get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)

func _hold_owned_links(barrier: Node, signal_name: String, callback: Callable) -> Array:
	var found: Array = []
	for link: Dictionary in barrier.get_signal_connection_list(signal_name):
		if link.callable == callback: found.append(link)
	return found

func _hold_other_links(barrier: Node, signal_name: String, callback: Callable) -> Array:
	var found: Array = []
	for link: Dictionary in barrier.get_signal_connection_list(signal_name):
		if link.callable != callback: found.append({"callable": link.callable, "flags": link.flags})
	return found

func _hold_link_summary(links: Array) -> Dictionary:
	var flags: Array = []
	var targets: Array = []
	var methods: Array = []
	var bound_counts: Array = []
	var unbound_counts: Array = []
	for link: Dictionary in links:
		var callback: Callable = link.callable
		flags.append(int(link.flags))
		targets.append(callback.get_object_id())
		methods.append(String(callback.get_method()))
		bound_counts.append(callback.get_bound_arguments().size())
		unbound_counts.append(callback.get_unbound_arguments_count())
	return {"own_count": links.size(), "flags": flags, "targets": targets, "methods": methods, "bound_counts": bound_counts, "unbound_counts": unbound_counts}

func _hold_cleanup(barrier: Node, label: String, stage: String) -> bool:
	var results: Dictionary = {}
	var clean := true
	for name: String in ["capture_ready", "capture_rejected"]:
		var callback: Callable = Callable(self, "_on_held" if name == "capture_ready" else "_on_rejected")
		var own_before: Array = _hold_owned_links(barrier, name, callback)
		var other_before: Array = _hold_other_links(barrier, name, callback)
		# Only this exact unbound callable is removed; other targets/methods/binds
		# remain registered even when they listen to the same barrier signal.
		if barrier.is_connected(name, callback): barrier.disconnect(name, callback)
		var own_after: Array = _hold_owned_links(barrier, name, callback)
		var other_after: Array = _hold_other_links(barrier, name, callback)
		var untouched: bool = other_before == other_after
		var summary: Dictionary = _hold_link_summary(own_before)
		summary["own_after"] = own_after.size()
		summary["flags_after"] = _hold_link_summary(own_after).flags
		summary["other_before"] = other_before.size()
		summary["other_after"] = other_after.size()
		summary["other_unchanged"] = untouched
		results[name] = summary
		clean = check(label + " " + stage + " " + name + " only own listeners cleared", own_after.is_empty() and untouched, summary) and clean
	observations.append({"hold_connection_audit": {"label": label, "stage": stage, "signals": results}})
	return check(label + " " + stage + " both own barrier listeners cleared", clean, results)

func _hold(b: Node, label: String) -> bool:
	var barrier: Node = b._save_barrier
	if not _hold_cleanup(barrier, label, "before_connect"): return false
	held = false
	rejected = ""
	held_physics = -1
	var ready_error: int = barrier.capture_ready.connect(_on_held, CONNECT_ONE_SHOT)
	var rejected_error: int = barrier.capture_rejected.connect(_on_rejected, CONNECT_ONE_SHOT)
	var ready_links: Array = _hold_owned_links(barrier, "capture_ready", Callable(self, "_on_held"))
	var rejected_links: Array = _hold_owned_links(barrier, "capture_rejected", Callable(self, "_on_rejected"))
	var ready_summary: Dictionary = _hold_link_summary(ready_links)
	var rejected_summary: Dictionary = _hold_link_summary(rejected_links)
	var exact: bool = ready_error == OK and rejected_error == OK and ready_links.size() == 1 and rejected_links.size() == 1
	exact = exact and ready_summary.flags == [CONNECT_ONE_SHOT] and rejected_summary.flags == [CONNECT_ONE_SHOT]
	exact = exact and ready_summary.targets == [get_instance_id()] and rejected_summary.targets == [get_instance_id()]
	exact = exact and ready_summary.methods == ["_on_held"] and rejected_summary.methods == ["_on_rejected"]
	exact = exact and ready_summary.bound_counts == [0] and rejected_summary.bound_counts == [0] and ready_summary.unbound_counts == [0] and rejected_summary.unbound_counts == [0]
	observations.append({"hold_connection_audit": {"label": label, "stage": "installed", "signals": {"capture_ready": ready_summary, "capture_rejected": rejected_summary}, "ready_error": ready_error, "rejected_error": rejected_error}})
	if not check(label + " exact two owned one-shot barrier listeners", exact, {"ready": ready_summary, "rejected": rejected_summary, "ready_error": ready_error, "rejected_error": rejected_error}):
		_hold_cleanup(barrier, label, "connect_failure")
		return false
	var requested: Dictionary = b._save_barrier.request_capture()
	if not check(label + " actual barrier request", requested.get("ok", false), requested):
		_hold_cleanup(barrier, label, "request_refused")
		return false
	var deadline: int = Time.get_ticks_msec() + 15000
	for frame in range(180):
		await get_tree().process_frame
		if held or not rejected.is_empty() or Time.get_ticks_msec() >= deadline: break
	var ready: bool = check(label + " real healthy HELD", held and rejected.is_empty() and b._save_barrier.state == b._save_barrier.State.HELD and b._save_barrier.health().ok, {"rejected": rejected, "health": b._save_barrier.health(), "held_physics": held_physics})
	var cleaned: bool = _hold_cleanup(barrier, label, "after_wait")
	return ready and cleaned
