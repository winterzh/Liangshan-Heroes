extends Node
## Data-only native JSON/Scenery validation regression. No Battle creation,
## factory/setup/deploy/tick, scene install, player profile or real slot write.
const CASES := ["gao", "daming", "level1", "level2", "level3", "level4", "level6", "level7", "classic_liangshan"]
const GAO_LISTS := ["trees", "sprites", "guard_posts", "gate_parts", "side_gate_parts", "wall_parts", "dock_parts"]
const DAMING_LISTS := ["walls", "sprites", "trees"]
const ZERO := "0000000000000000000000000000000000000000000000000000000000000000"
var Boundary: Script
var Scenery: Script
var Store: Script
var Codec: Script
var checks: Array = []
var cases: Array = []
var provenance: Array = []
var report_path := ""
var manifest_path := ""
var manifest: Dictionary = {}
var maps: Dictionary = {}
var typed_maps: Dictionary = {}
var nonce := ""
var identity: Dictionary = {}
var finished := false

func check(label: String, passed: bool, detail: Variant = null) -> bool:
	checks.append({"label": label, "passed": passed, "detail": null if passed else detail})
	if not passed: print("OWNERSHIP_JSON_FAIL ", label, " ", detail)
	return passed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile: String = OS.get_environment("OWNERSHIP_JSON_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual: String = OS.get_environment(key).replace("\\", "/").simplify_path().trim_suffix("/")
		safe = safe and actual.to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	if not safe:
		print("OWNERSHIP_JSON PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	report_path = OS.get_environment("OWNERSHIP_JSON_REPORT").replace("\\", "/").simplify_path()
	manifest_path = OS.get_environment("OWNERSHIP_JSON_FIXTURES").replace("\\", "/").simplify_path()
	var root_path: String = ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	if not check("external fresh evidence path", report_path.is_absolute_path() and DirAccess.dir_exists_absolute(report_path.get_base_dir()) and not FileAccess.file_exists(report_path) and not report_path.to_lower().begins_with(root_path.to_lower() + "/")): finish(); return
	if not check("external explicit fixture manifest", manifest_path.is_absolute_path() and FileAccess.file_exists(manifest_path)): finish(); return
	run.call_deferred()

func _raw_fixture(row: Dictionary) -> String:
	if not check("fixture path/SHA declared", row.has_all(["path", "sha256"]) and typeof(row.path) == TYPE_STRING and row.path.is_absolute_path() and typeof(row.sha256) == TYPE_STRING and row.sha256.length() == 64): return ""
	if not check("fixture bytes pinned " + row.path.get_file(), FileAccess.file_exists(row.path) and FileAccess.get_sha256(row.path) == row.sha256): return ""
	var file := FileAccess.open(row.path, FileAccess.READ)
	if not check("fixture readable " + row.path.get_file(), file != null): return ""
	var raw: String = file.get_as_text()
	file.close()
	provenance.append({"path": row.path, "sha256": row.sha256, "utf8_bytes": raw.to_utf8_buffer().size(), "origin": row.get("origin", "raw_payload")})
	return raw

func _float_bits(value: float) -> String:
	var raw := PackedByteArray()
	raw.resize(8)
	raw.encode_double(0, value)
	return raw.hex_encode()

func _exact(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _exact(left[key], right[key]): return false
		return true
	if left is Array:
		if left.size() != right.size(): return false
		for index: int in range(left.size()):
			if not _exact(left[index], right[index]): return false
		return true
	if typeof(left) == TYPE_FLOAT: return _float_bits(left) == _float_bits(right)
	return left == right

func _context(chapter: String) -> Dictionary:
	return {"mode": "defense", "level_id": "", "waves": 30} if chapter == "" else {"mode": "campaign", "level_id": chapter, "waves": 0}

func _scenery_context(chapter: String) -> Dictionary:
	return {} if chapter == "" else _context(chapter)

func _lists(chapter: String) -> Array:
	return GAO_LISTS if chapter == "level5" else DAMING_LISTS if chapter == "level8" else []

func _expected_paths(record: Dictionary, chapter: String) -> Array:
	var paths: Array = []
	var owner: Dictionary = record.sections.display.ownership
	if chapter == "level5": paths.append("ownership/entrance")
	for field: String in _lists(chapter):
		for index: int in range(owner[field].size()): paths.append("ownership/" + field + "/" + str(index))
	return paths

func _other_fields_exact(before: Dictionary, after: Dictionary, chapter: String) -> bool:
	var a: Dictionary = before.duplicate(true)
	var b: Dictionary = after.duplicate(true)
	if chapter in ["level5", "level8"]:
		for field: String in _lists(chapter): a.sections.display.ownership.erase(field); b.sections.display.ownership.erase(field)
		if chapter == "level5": a.sections.display.ownership.erase("entrance"); b.sections.display.ownership.erase("entrance")
	return _exact(a, b)

func _envelope(payload: String) -> String:
	return JSON.stringify({"magic": "LH_CLASSIC_CONTINUE_SLOT", "version": "1", "app": "5088120", "owner": "1", "revision": "1", "previous_sha256": ZERO,
		"payload_bytes": str(payload.to_utf8_buffer().size()), "payload_sha256": payload.sha256_text(), "payload": payload})

func run() -> void:
	Boundary = load("res://scripts/run_scenery_json_boundary.gd")
	Scenery = load("res://scripts/run_scenery_state.gd")
	Store = load("res://scripts/run_slot_store.gd")
	Codec = load("res://scripts/run_state_value_codec.gd")
	var expected_engine: String = OS.get_environment("OWNERSHIP_JSON_ENGINE_SHA256")
	if not check("actual engine binary pinned", expected_engine.length() == 64 and FileAccess.get_sha256(OS.get_executable_path()) == expected_engine): finish(); return
	nonce = OS.get_environment("OWNERSHIP_JSON_NONCE")
	if not check("nonempty producer nonce", not nonce.is_empty()): finish(); return
	var provider: Script = load("res://scripts/run_content_identity.gd")
	identity = provider.new().resolve_runtime_identity()
	if not check("actual current installed content identity pinned", identity.get("ok", false) and identity.get("save_eligible", false) and identity.get("content_version") == OS.get_environment("OWNERSHIP_JSON_EXPECT_CONTENT") and identity.get("engine_binary_sha256") == expected_engine): finish(); return
	var mf := FileAccess.open(manifest_path, FileAccess.READ)
	if not check("manifest readable", mf != null): finish(); return
	var decoded: Variant = JSON.parse_string(mf.get_as_text())
	mf.close()
	if not check("manifest schema and complete matrix", decoded is Dictionary and decoded.get("schema") == "native_ownership_json_boundary_fixtures_v24q" and decoded.has_all(["original_payload", "normalized_payload", "maps"]) and decoded.maps is Array and decoded.maps.size() == CASES.size()): finish(); return
	manifest = decoded
	provenance.append({"path": manifest_path, "sha256": FileAccess.get_sha256(manifest_path), "origin": "explicit complete fixture manifest"})
	for row: Dictionary in manifest.maps:
		if not check("unique expected named case", row.has_all(["case", "chapter", "origin", "path", "sha256"]) and row.case in CASES and not maps.has(row.case)): finish(); return
		var raw: String = _raw_fixture(row)
		if raw.is_empty(): finish(); return
		var fixture: Variant = JSON.parse_string(raw)
		if not check("fixture dictionary " + row.case, fixture is Dictionary): finish(); return
		var map_record: Variant = null
		if row.origin == "world_original":
			if not check("original whole world map exists " + row.case, fixture.has("original") and fixture.original is Dictionary and fixture.original.has("sections") and fixture.original.sections.has("map")): finish(); return
			map_record = fixture.original.sections.map
		elif row.origin == "slot_envelope_map":
			if not check("historical component envelope payload exists", fixture.has("payload") and typeof(fixture.payload) == TYPE_STRING): finish(); return
			var packet: Variant = JSON.parse_string(fixture.payload)
			if not check("historical original map extracted only", packet is Dictionary and packet.has("world") and packet.world.has("sections") and packet.world.sections.has("map")): finish(); return
			map_record = packet.world.sections.map
		else:
			if not check("explicit current standalone map component", row.origin == "map_component" and fixture is Dictionary): finish(); return
			map_record = fixture
		if not check("map component and version declared " + row.case, map_record is Dictionary and map_record.has_all(["schema", "content_version", "sections"]) and typeof(map_record.content_version) == TYPE_STRING): finish(); return
		maps[row.case] = {"map": map_record, "chapter": row.chapter, "origin": row.origin}
	if not check("all exact matrix names present", maps.size() == CASES.size() and maps.has_all(CASES)): finish(); return
	if not _actual_pending_payload(): finish(); return
	for name: String in CASES:
		if not _component(name): finish(); return
	if not _classic_none(): finish(); return
	for name: String in ["gao", "daming"]:
		if not _negative_matrix(name): finish(); return
	if not _other_payload_negative(): finish(); return
	for row: Dictionary in provenance:
		if not check("all original input bytes unchanged " + row.path.get_file(), FileAccess.get_sha256(row.path) == row.sha256): finish(); return
	finish()

func _actual_pending_payload() -> bool:
	var original: String = _raw_fixture(manifest.original_payload)
	var normalized: String = _raw_fixture(manifest.normalized_payload)
	if original.is_empty() or normalized.is_empty(): return false
	var store: RefCounted = Store.new("user://ownership_json_boundary_v24q/no_disk_operation")
	var source_float: Variant = JSON.parse_string(original)
	var source_result: Dictionary = store._validate_document(source_float)
	if not check("native writer directly rejects parsed ownership float", not source_result.ok and source_result.get("code") == "SLOT_MAP_NATIVE_OWNER_INTEGER", source_result): return false
	var opened: Dictionary = store._decode(_envelope(original))
	if not check("real original pending payload envelope decode passes", opened.ok, opened): return false
	if not check("complete decoded record stringify reproduces every original UTF8 byte", JSON.stringify(opened.document).to_utf8_buffer() == original.to_utf8_buffer() and JSON.stringify(opened.document).sha256_text() == manifest.original_payload.sha256): return false
	var source_typed: Dictionary = store._validate_document(opened.document)
	if not check("recovered native typed document remains strictly valid", source_typed.ok, source_typed): return false
	var noncanonical: Dictionary = store._decode(_envelope(normalized))
	if not check("actual decimal .0 payload still NONCANONICAL_RECORD", not noncanonical.ok and noncanonical.get("code") == "NONCANONICAL_RECORD", noncanonical): return false
	var boundaries: Dictionary = Boundary.normalize_json(source_float.world.sections.map, source_float.world.content_version, _context("level8"))
	if not check("actual failed ownership path set has exactly196 typed repairs", boundaries.ok and boundaries.changed_paths.size() == 196, boundaries.get("code", "")): return false
	var expected: Array = _expected_paths(source_float.world.sections.map, "level8")
	var actual: Array = boundaries.changed_paths.duplicate()
	expected.sort(); actual.sort()
	if not check("actual failed ownership all fixed paths covered exactly", actual == expected): return false
	cases.append({"case": "actual_v24p_pending", "original_payload_sha256": original.sha256_text(), "normalized_payload_sha256": normalized.sha256_text(), "original_utf8_bytes": original.to_utf8_buffer().size(), "normalized_utf8_bytes": normalized.to_utf8_buffer().size(), "fixed_paths": actual, "original_envelope_decoded": true, "noncanonical_decimal_envelope_rejected": true, "disk_write_performed": false})
	return true

func _component(name: String) -> bool:
	var row: Dictionary = maps[name]
	var source: Dictionary = row.map
	var immutable: Dictionary = source.duplicate(true)
	var result: Dictionary = Boundary.normalize_json(source, source.content_version, _context(row.chapter))
	if not check("component fixed JSON boundary accepted " + name, result.ok, result): return false
	if not check("component original parsed data untouched " + name, _exact(source, immutable)): return false
	if not check("component all unrelated Codec/material/reed/lighting fields exact " + name, _other_fields_exact(source, result.value, row.chapter)): return false
	var expected_count: int = 262 if name == "gao" else 196 if name == "daming" else 0
	if not check("complete registered repair count " + name, result.changed_paths.size() == expected_count): return false
	if expected_count > 0:
		var expected: Array = _expected_paths(source, row.chapter)
		var actual: Array = result.changed_paths.duplicate()
		expected.sort(); actual.sort()
		if not check("every declared ownership repair path exact " + name, actual == expected): return false
		var rejected_source: Dictionary = Boundary.validate_source(source, source.content_version, _context(row.chapter))
		if not check("native source rejects JSON ownership float " + name, not rejected_source.ok and rejected_source.get("code") == "SLOT_MAP_NATIVE_OWNER_INTEGER", rejected_source): return false
	else:
		if not check("old/standard complete record exact no-op " + name, _exact(source, result.value)): return false
	var validated: Dictionary = Scenery.new(source.content_version, _scenery_context(row.chapter)).validate(result.value.sections.display)
	if not check("original complete Scenery validator accepted restored ints " + name, validated.ok, validated): return false
	var native: Dictionary = Boundary.validate_source(result.value, source.content_version, _context(row.chapter))
	if not check("strict native source restored fixture accepted " + name, native.ok, native): return false
	var repeated: Dictionary = Boundary.normalize_json(result.value, source.content_version, _context(row.chapter))
	if not check("fixed boundary idempotent and no more repairs " + name, repeated.ok and repeated.changed_paths.is_empty() and _exact(result.value, repeated.value)): return false
	typed_maps[name] = result.value
	cases.append({"case": name, "chapter": row.chapter, "origin": row.origin, "fixed_path_count": expected_count, "fixed_paths": result.changed_paths, "pure_component_only": true})
	return true

func _classic_none() -> bool:
	var source: Dictionary = typed_maps.classic_liangshan.duplicate(true)
	source.sections.display = {"schema": "scenery_state_v2", "content_version": source.content_version, "kind": "none"}
	var before: Dictionary = source.duplicate(true)
	var normalized: Dictionary = Boundary.normalize_json(source, source.content_version, _context(""))
	if not check("explicit classic none-display component fixture exact no-op", normalized.ok and normalized.changed_paths.is_empty() and _exact(source, normalized.value) and _exact(source, before), normalized): return false
	var validated: Dictionary = Scenery.new(source.content_version, {}).validate(source.sections.display)
	if not check("original classic none-display validator passes", validated.ok, validated): return false
	var bad: Dictionary = source.duplicate(true)
	bad.sections.display["ownership"] = {"entrance": 1}
	if not _reject(bad, "", "standard none cannot acquire ownership field", source.content_version): return false
	cases.append({"case": "classic_none", "origin": "explicit component DTO derived from pinned classic map wrapper; no original runtime map claim", "pure_component_only": true})
	return true

func _reject(record: Dictionary, chapter: String, label: String, trusted_version: String) -> bool:
	var before: Dictionary = record.duplicate(true)
	var result: Dictionary = Boundary.normalize_json(record, trusted_version, _context(chapter))
	return check("reject " + label, not result.ok and _exact(record, before), result)

func _negative_matrix(name: String) -> bool:
	var chapter: String = maps[name].chapter
	var source: Dictionary = typed_maps[name]
	# Caller identity remains the trusted fixture identity. Malformed leaves must
	# reach validator rejection, never typed String argument conversion errors.
	var trusted_version: String = source.content_version
	var trusted_context: Dictionary = _context(chapter)
	var identity_paths: Array = [["schema"], ["content_version"], ["sections", "display", "schema"],
		["sections", "display", "kind"], ["sections", "display", "content_version"],
		["sections", "display", "context", "mode"], ["sections", "display", "context", "level_id"]]
	var malformed_identity: Array = [null, true, 1, [], {}]
	var malformed_labels: Array = ["null", "bool", "int", "Array", "Dictionary"]
	for path: Array in identity_paths:
		for index: int in range(malformed_identity.size()):
			var malformed: Dictionary = source.duplicate(true)
			var parent: Dictionary = malformed
			for depth: int in range(path.size() - 1): parent = parent[path[depth]]
			parent[path[-1]] = malformed_identity[index]
			var before_identity: Dictionary = malformed.duplicate(true)
			var json_rejection: Dictionary = Boundary.normalize_json(malformed, trusted_version, trusted_context)
			var source_rejection: Dictionary = Boundary.validate_source(malformed, trusted_version, trusted_context)
			var identity_label: String = name + "/" + "/".join(path) + "/" + malformed_labels[index]
			if not check("JSON identity leaf controlled rejection " + identity_label, not json_rejection.ok and typeof(json_rejection.get("code")) == TYPE_STRING and not json_rejection.code.is_empty() and _exact(malformed, before_identity), json_rejection): return false
			if not check("native source identity leaf controlled rejection " + identity_label, not source_rejection.ok and typeof(source_rejection.get("code")) == TYPE_STRING and not source_rejection.code.is_empty() and _exact(malformed, before_identity), source_rejection): return false
	var list_name: String = "sprites"
	var values: Array = [float(source.sections.display.ownership.sprites[0]), 2.5, NAN, INF, -INF, true, "2", null, 0, -1, source.sections.display.nodes.size()]
	var labels := ["integral float native-only refusal", "fractional", "NaN", "Infinity", "negative Infinity", "bool", "string", "null", "zero", "negative", "out of range"]
	for index: int in range(values.size()):
		var bad: Dictionary = source.duplicate(true)
		bad.sections.display.ownership[list_name][0] = values[index]
		var before: Dictionary = bad.duplicate(true)
		var native: Dictionary = Boundary.validate_source(bad, bad.content_version, _context(chapter))
		if not check("source strict index negative " + name + "/" + labels[index], not native.ok and _exact(bad, before), native): return false
		if index == 0:
			var repaired: Dictionary = Boundary.normalize_json(bad, bad.content_version, _context(chapter))
			if not check("JSON integral float valid identity converts only allowed leaf " + name, repaired.ok and repaired.changed_paths == ["ownership/sprites/0"] and _exact(source, repaired.value) and _exact(bad, before), repaired): return false
		else:
			if not _reject(bad, chapter, name + "/" + labels[index], source.content_version): return false
	var bad: Dictionary = source.duplicate(true)
	bad["foreign_map_field"] = true
	if not _reject(bad, chapter, name + "/extra Map envelope field", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections["foreign_section"] = {"t": "int64", "v": "1"}
	if not _reject(bad, chapter, name + "/extra Map section field", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display["foreign_display_field"] = true
	if not _reject(bad, chapter, name + "/extra display field", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.schema = "unknown_scenery_v999"
	if not _reject(bad, chapter, name + "/unknown schema", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.context.level_id = "level5" if chapter == "level8" else "level8"
	if not _reject(bad, chapter, name + "/cross chapter context", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.kind = "campaign_level1"
	if not _reject(bad, chapter, name + "/cross chapter kind", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.context.mode = 1
	if not _reject(bad, chapter, name + "/context mode wrong primitive type", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.ownership["foreign_owner"] = 1
	if not _reject(bad, chapter, name + "/unknown ownership field", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.ownership.erase("trees")
	if not _reject(bad, chapter, name + "/missing ownership field", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.ownership.sprites.append(bad.sections.display.ownership.sprites[0])
	if not _reject(bad, chapter, name + "/duplicate owned member", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.ownership.sprites.pop_back()
	if not _reject(bad, chapter, name + "/missing owned member", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.nodes.append(bad.sections.display.nodes[1].duplicate(true))
	if not _reject(bad, chapter, name + "/unregistered extra node", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.ownership.sprites[0] = 1 # native root/night/entrance is not a sprite.
	if not _reject(bad, chapter, name + "/wrong node kind", source.content_version): return false
	bad = source.duplicate(true)
	var decoded_node: Dictionary = Codec.new().decode(bad.sections.display.nodes[int(bad.sections.display.ownership.sprites[0])])
	if not check("negative fixture original tagged node decodes", decoded_node.ok): return false
	decoded_node.value.parent = -1
	bad.sections.display.nodes[int(bad.sections.display.ownership.sprites[0])] = Codec.new().encode(decoded_node.value).value
	if not _reject(bad, chapter, name + "/wrong encoded parent", source.content_version): return false
	if chapter == "level5":
		bad = source.duplicate(true)
		bad.sections.display.ownership.entrance = float(bad.sections.display.ownership.entrance)
		var native: Dictionary = Boundary.validate_source(bad, bad.content_version, _context(chapter))
		if not check("source Gao scalar entrance float remains rejected", not native.ok): return false
		var fixed: Dictionary = Boundary.normalize_json(bad, bad.content_version, _context(chapter))
		if not check("JSON Gao scalar entrance repairs exactly", fixed.ok and fixed.changed_paths == ["ownership/entrance"] and _exact(fixed.value, source)): return false
	return true

func _other_payload_negative() -> bool:
	var source: Dictionary = typed_maps.daming
	var bad: Dictionary = source.duplicate(true)
	var lights: Dictionary = Codec.new().decode(bad.sections.display.lighting.payload)
	if not check("real lighting negative fixture decoded", lights.ok): return false
	lights.value.energies[0] = 0.0
	bad.sections.display.lighting.payload = Codec.new().encode(lights.value).value
	if not _reject(bad, "level8", "lighting mutation never normalized away", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.material["foreign_uniform"] = {"t": "int64", "v": "1"}
	if not _reject(bad, "level8", "material injection never dropped", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.reed["foreign_reed"] = true
	if not _reject(bad, "level8", "reed injection never dropped", source.content_version): return false
	bad = source.duplicate(true)
	bad.sections.display.ownership.ground_shadows.append({"t": "string", "v": "bad shadow"})
	if not _reject(bad, "level8", "ground-shadow codec mutation never repaired", source.content_version): return false
	for name: String in ["level1", "level2", "level3", "level4", "level6", "level7", "classic_liangshan"]:
		bad = typed_maps[name].duplicate(true)
		bad.sections.display["ownership"] = {"sprites": [2]}
		if not _reject(bad, maps[name].chapter, name + "/ownership injection into no-op schema", typed_maps[name].content_version): return false
	return true

func finish() -> void:
	if finished: return
	finished = true
	var passed: bool = not checks.is_empty() and checks.all(func(row): return row.passed)
	var source_pins: Array = []
	for path: String in ["res://scripts/run_snapshot_store.gd", "res://scripts/run_slot_store.gd", "res://scripts/run_scenery_json_boundary.gd", "res://scripts/run_scenery_state.gd", "res://scripts/run_state_value_codec.gd"]:
		source_pins.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var report := {"schema": "native_ownership_json_boundary_report_v24q", "passed": passed, "checks": checks, "cases": cases, "provenance": provenance, "source_files": source_pins,
		"pid": OS.get_process_id(), "nonce": nonce, "actual_user_data_dir": OS.get_user_data_dir(), "content_version": identity.get("content_version", ""), "engine_sha256": FileAccess.get_sha256(OS.get_executable_path()), "pure_fixed_validator": true,
		"battle_factory_calls": 0, "deploy_or_tick_calls": 0, "disk_slot_writes": 0, "private_runtime_patches": 0,
		"full_world_continuation_qualified": false, "natural_result_qualified": false, "public_campaign_entry_qualified": false,
		"scope": "Actual failed pending-packet canonical/strict-native boundary, eight original map components and explicit standard components, exact repair paths and comprehensive rejection/immutability matrix. No world install or gameplay continuation."}
	if report_path.is_empty() or FileAccess.file_exists(report_path): passed = false
	else:
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null: passed = false
		else: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("NATIVE_OWNERSHIP_JSON_V24Q_COMPLETE ", checks.size(), " ", passed)
	get_node("/root/Sfx").shutdown()
	get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
