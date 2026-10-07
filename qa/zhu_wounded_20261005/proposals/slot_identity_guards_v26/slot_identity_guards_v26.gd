extends Node
## Pure Slot outer identity validation. No Battle/Unit factory, Session install,
## lifecycle terminal call, gameplay tick, disk slot write or current-classic claim.
const ZERO := "0000000000000000000000000000000000000000000000000000000000000000"
const MATRIX_SHA256 := "b785db62a288071d52d78e2b6694c2de735ec3969faa616a994cff27bdd9d5b6"
const SOURCE_PIN_SHA256 := "384b839f768d64fc739ffd4848ff611bd344764cd27fd92b9e68251c3e3fb622"
const ORIGINAL_PAYLOAD_SHA256 := "975438e07af96fbded5d705c1807941bffae8cc344207eb2a224b73569e0cb96"
const DECIMAL_PAYLOAD_SHA256 := "17194c35b47442232df9e1f8a1c46bb1b0302eca738dcc1c22907d3a7f12077b"
const SOURCE_FILES := [{"path":"res://scripts/run_slot_store.gd","sha256":"908f8591f012752b192278362b48a83f212a7e596727214b5b0734dce23bdbde"},{"path":"res://scripts/run_snapshot_store.gd","sha256":"581e638b8f0ce7cb24d5533b03ee94b99732c5cffcbf373b1a5a69a1618d8251"},{"path":"res://scripts/run_official_restore_profile.gd","sha256":"a1791e5eb3bb7b8dffa1bdd6a2ccee274a672ae77d44b9740bf16a8c0843a42c"},{"path":"res://scripts/steam_local_run_session.gd","sha256":"b102aed1246e467ab416019cbbb72f6452fa4ffcc18012cf7f7114f013232039"},{"path":"res://scripts/run_local_lifecycle.gd","sha256":"e68cb817a6dcc4cc1df91caf29c07c4c4c6cfdca378f6c05335636e6a6617e00"},{"path":"res://scripts/run_scenery_json_boundary.gd","sha256":"476ee2ee83a513d29a0db04b5dc08eb5a3dcd6895a036697ed368b28c5d5c6ea"},{"path":"res://scripts/run_state_value_codec.gd","sha256":"c8c4a58d1e68e22abb9f8b1abcb1a9cc1dbaa486e51ea5174dd16984aaa35d15"},{"path":"res://scripts/run_battle_world_core.gd","sha256":"621426f2714207dd69fb66981dbf73f34b9b9a1637cd890b23fb53d4a39fd571"},{"path":"res://tools/owned_slot_retry_qa.gd","sha256":"424987ebca5d8204c1b410c5ef12ecc5d460f6ca6bbb5c479ac0de59bf988a5c"},{"path":"res://scripts/run_content_identity.gd","sha256":"1ea430ae4dec555f18e7fd11382b24dae38ee51ae30b60096909af992019a063"}]
const EXPECT_CASES := 134
const ROUTES := ["source", "json"]
var Store: Script
var Boundary: Script
var checks: Array = []
var case_rows: Array = []
var positives: Array = []
var provenance: Array = []
var source_rows: Array = []
var manifest: Dictionary = {}
var matrix: Dictionary = {}
var report_path := ""
var manifest_path := ""
var nonce := ""
var identity: Dictionary = {}
var json_base: Dictionary = {}
var native_source_base: Dictionary = {}
var store: RefCounted
var original_payload := ""
var decimal_payload := ""
var finished := false
var matrix_completed := false

func check(label: String, passed: bool, code: String = "", path: String = "") -> bool:
	checks.append({"label": label, "passed": passed, "code": code.left(160), "path": path.left(240)})
	if not passed: print("SLOT_IDENTITY_FAIL ", label, " code=", code.left(160), " path=", path.left(240))
	return passed

func _sha(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and value.length() == 64 and value.is_valid_hex_number()

func _normalized_path(value: String) -> String:
	return value.replace("\\", "/").simplify_path().trim_suffix("/")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile: String = _normalized_path(OS.get_environment("SLOT_IDENTITY_PROFILE"))
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual: String = _normalized_path(OS.get_environment(key))
		safe = safe and actual.to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and _normalized_path(OS.get_user_data_dir()).to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	if not safe:
		print("SLOT_IDENTITY PRIVATE_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	report_path = _normalized_path(OS.get_environment("SLOT_IDENTITY_REPORT"))
	manifest_path = _normalized_path(OS.get_environment("SLOT_IDENTITY_FIXTURES"))
	var root_path: String = _normalized_path(ProjectSettings.globalize_path("res://"))
	if not check("fresh external report path", report_path.is_absolute_path() and DirAccess.dir_exists_absolute(report_path.get_base_dir()) and not FileAccess.file_exists(report_path) and not report_path.to_lower().begins_with(root_path.to_lower() + "/")): _finish(); return
	if not check("explicit external fixture manifest", manifest_path.is_absolute_path() and FileAccess.file_exists(manifest_path)): _finish(); return
	_run.call_deferred()

func _read_pinned(row: Variant, label: String, expected_sha: String = "") -> Dictionary:
	if not check(label + " path/SHA fields", typeof(row) == TYPE_DICTIONARY and row.has_all(["path", "sha256"]) and typeof(row.path) == TYPE_STRING and row.path.is_absolute_path() and _sha(row.sha256)): return {"ok": false}
	if not check(label + " expected SHA", expected_sha.is_empty() or row.sha256 == expected_sha): return {"ok": false}
	if not check(label + " exact file SHA", FileAccess.file_exists(row.path) and FileAccess.get_sha256(row.path) == row.sha256, "FIXTURE_SHA", row.path): return {"ok": false}
	var file := FileAccess.open(row.path, FileAccess.READ)
	if not check(label + " readable", file != null): return {"ok": false}
	var raw: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var text: String = raw.get_string_from_utf8()
	if not check(label + " exact nonempty UTF8", not raw.is_empty() and text.to_utf8_buffer() == raw): return {"ok": false}
	provenance.append({"path": row.path, "sha256": row.sha256, "utf8_bytes": raw.size(), "origin": label})
	return {"ok": true, "text": text}

func _parse_dictionary(text: String, label: String) -> Dictionary:
	var parser := JSON.new()
	if not check(label + " valid JSON", parser.parse(text) == OK): return {"ok": false}
	if not check(label + " dictionary", typeof(parser.data) == TYPE_DICTIONARY): return {"ok": false}
	return {"ok": true, "value": parser.data}

func _float_bits(value: float) -> String:
	var raw := PackedByteArray()
	raw.resize(8)
	raw.encode_double(0, value)
	return raw.hex_encode()

func _clone(value: Variant) -> Variant:
	return value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value

func _exact(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _exact(left[key], right[key]): return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size(): return false
		for index: int in range(left.size()):
			if not _exact(left[index], right[index]): return false
		return true
	if typeof(left) == TYPE_FLOAT: return _float_bits(left) == _float_bits(right)
	return left == right

func _feed_text(ctx: HashingContext, text: String) -> void:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	ctx.update((str(bytes.size()) + ":").to_utf8_buffer())
	ctx.update(bytes)

func _feed_value(ctx: HashingContext, value: Variant) -> void:
	_feed_text(ctx, str(typeof(value)))
	if typeof(value) == TYPE_DICTIONARY:
		_feed_text(ctx, str(value.size()))
		# Preserve the actual Dictionary key iteration order as an extra audit.
		for key: Variant in value:
			_feed_value(ctx, key)
			_feed_value(ctx, value[key])
	elif typeof(value) == TYPE_ARRAY:
		_feed_text(ctx, str(value.size()))
		for item: Variant in value: _feed_value(ctx, item)
	elif typeof(value) == TYPE_FLOAT:
		_feed_text(ctx, _float_bits(value))
	elif typeof(value) == TYPE_STRING:
		_feed_text(ctx, value)
	else:
		_feed_text(ctx, str(value))

func _fingerprint(value: Variant) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_feed_value(ctx, value)
	return ctx.finish().hex_encode()

func _envelope(payload: String) -> String:
	return JSON.stringify({"magic": "LH_CLASSIC_CONTINUE_SLOT", "version": "1", "app": "5088120", "owner": "1", "revision": "1", "previous_sha256": ZERO,
		"payload_bytes": str(payload.to_utf8_buffer().size()), "payload_sha256": payload.sha256_text(), "payload": payload})

func _result_code(value: Variant) -> String:
	return value.code if typeof(value) == TYPE_DICTIONARY and typeof(value.get("code")) == TYPE_STRING else "NO_CONTROLLED_CODE"

func _ok(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY and typeof(value.get("ok")) == TYPE_BOOL and value.ok

func _refused(value: Variant, code: String) -> bool:
	return typeof(value) == TYPE_DICTIONARY and typeof(value.get("ok")) == TYPE_BOOL and not value.ok and typeof(value.get("code")) == TYPE_STRING and value.code == code

func _source_pin_gate() -> bool:
	for row: Dictionary in SOURCE_FILES:
		var actual: String = FileAccess.get_sha256(row.path)
		source_rows.append({"path": row.path, "expected_sha256": row.sha256, "sha256": actual})
		if not check("actual frozen source pin " + row.path, actual == row.sha256, "SOURCE_SHA", row.path): return false
	return true

func _run() -> void:
	nonce = OS.get_environment("SLOT_IDENTITY_NONCE")
	var expected_engine: String = OS.get_environment("SLOT_IDENTITY_ENGINE_SHA256")
	if not check("producer nonce nonempty", not nonce.is_empty()): _finish(); return
	if not check("actual engine SHA pinned", _sha(expected_engine) and FileAccess.get_sha256(OS.get_executable_path()) == expected_engine): _finish(); return
	if not _source_pin_gate(): _finish(); return
	Store = load("res://scripts/run_slot_store.gd")
	Boundary = load("res://scripts/run_scenery_json_boundary.gd")
	if not check("fixed installed scripts loaded", Store != null and Boundary != null): _finish(); return
	var provider: Script = load("res://scripts/run_content_identity.gd")
	if not check("fixed identity provider loaded", provider != null): _finish(); return
	identity = provider.new().resolve_runtime_identity()
	if not check("actual frozen installed content identity", _ok(identity) and identity.get("save_eligible", false) and typeof(identity.get("content_version")) == TYPE_STRING and identity.content_version == OS.get_environment("SLOT_IDENTITY_EXPECT_CONTENT") and identity.get("engine_binary_sha256") == expected_engine): _finish(); return
	var fixture_sha: String = OS.get_environment("SLOT_IDENTITY_FIXTURES_SHA256")
	if not check("manifest producer SHA supplied", _sha(fixture_sha)): _finish(); return
	var loaded: Dictionary = _read_pinned({"path": manifest_path, "sha256": fixture_sha}, "producer-bound fixture manifest")
	if not loaded.ok: _finish(); return
	var parsed: Dictionary = _parse_dictionary(loaded.text, "fixture manifest")
	if not parsed.ok: _finish(); return
	manifest = parsed.value
	if not check("fixed fixture manifest schema", typeof(manifest.get("schema")) == TYPE_STRING and manifest.schema == "slot_identity_guard_fixtures_v26" and manifest.has_all(["matrix", "source_pins", "original_payload", "normalized_payload", "classic_current_whole_slot", "original_owned_slot_retry"])): _finish(); return
	var matrix_file: Dictionary = _read_pinned(manifest.matrix, "exact134 original matrix", MATRIX_SHA256)
	var pins_file: Dictionary = _read_pinned(manifest.source_pins, "original source lineage pins", SOURCE_PIN_SHA256)
	if not matrix_file.ok or not pins_file.ok: _finish(); return
	parsed = _parse_dictionary(matrix_file.text, "fixed matrix")
	if not parsed.ok: _finish(); return
	matrix = parsed.value
	if not check("fixed complete134x2 matrix", typeof(matrix.get("schema")) == TYPE_STRING and matrix.schema == "slot_identity_guard_native_matrix_plan_v26" and typeof(matrix.get("cases")) == TYPE_ARRAY and matrix.cases.size() == EXPECT_CASES and matrix.get("negative_case_count") == EXPECT_CASES and matrix.get("route_checks") == EXPECT_CASES * ROUTES.size()): _finish(); return
	var original: Dictionary = _read_pinned(manifest.original_payload, "actual failed pending original JSON", ORIGINAL_PAYLOAD_SHA256)
	var decimal: Dictionary = _read_pinned(manifest.normalized_payload, "actual failed pending decimal JSON", DECIMAL_PAYLOAD_SHA256)
	if not original.ok or not decimal.ok: _finish(); return
	original_payload = original.text
	decimal_payload = decimal.text
	parsed = _parse_dictionary(original_payload, "actual pending document")
	if not parsed.ok: _finish(); return
	json_base = parsed.value
	if not check("actual pending known outer identities", typeof(json_base.get("schema")) == TYPE_STRING and json_base.schema == "official_continue_slot_v1" and typeof(json_base.get("context")) == TYPE_DICTIONARY and _exact(json_base.context, {"level_id": "level8", "mode": "campaign", "waves": 0.0}) and typeof(json_base.get("world")) == TYPE_DICTIONARY and typeof(json_base.world.get("profile")) == TYPE_DICTIONARY and typeof(json_base.world.profile.get("id")) == TYPE_STRING and json_base.world.profile.id == "campaign_level8_v1"): _finish(); return
	store = Store.new("user://slot_identity_guards_v26/no_disk_operation")
	if not check("no disk slot directory before validator", not DirAccess.dir_exists_absolute(store.directory)): _finish(); return
	if not _positive_pending(): _finish(); return
	if not _negative_matrix(): _finish(); return
	if not _positive_float_waves(): _finish(); return
	if not _canonical_controls(): _finish(); return
	for row: Dictionary in provenance:
		if not check("input file bytes still exact " + row.origin, FileAccess.get_sha256(row.path) == row.sha256, "FIXTURE_DRIFT", row.path): _finish(); return
	for row: Dictionary in source_rows:
		if not check("source bytes still exact " + row.path, FileAccess.get_sha256(row.path) == row.expected_sha256, "SOURCE_DRIFT", row.path): _finish(); return
	check("no disk slot directory after validator", not DirAccess.dir_exists_absolute(store.directory))
	matrix_completed = true
	_finish()

func _positive_pending() -> bool:
	var before: Dictionary = json_base.duplicate(true)
	var before_sha: String = _fingerprint(json_base)
	var direct: Variant = store._validate_document(json_base)
	if not check("strict native writer rejects actual JSON ownership floats", _refused(direct, "SLOT_MAP_NATIVE_OWNER_INTEGER"), _result_code(direct)): return false
	if not check("strict native writer input full types/IEEE unchanged", _exact(json_base, before) and _fingerprint(json_base) == before_sha): return false
	var normalized: Variant = store._validate_json_document(json_base)
	if not check("actual pending JSON validator accepts complete packet", _ok(normalized), _result_code(normalized)): return false
	if not check("JSON validator input full types/IEEE unchanged", _exact(json_base, before) and _fingerprint(json_base) == before_sha): return false
	var opened: Variant = store._decode(_envelope(original_payload))
	if not check("actual original pending canonical envelope decode", _ok(opened), _result_code(opened)): return false
	if not check("original pending every UTF8 canonical byte reproduced", JSON.stringify(opened.document).to_utf8_buffer() == original_payload.to_utf8_buffer() and JSON.stringify(opened.document).sha256_text() == ORIGINAL_PAYLOAD_SHA256): return false
	if not check("JSON hook and envelope typed decodedDTO exactly same", _exact(normalized.document, opened.document)): return false
	native_source_base = opened.document.duplicate(true)
	var source_before: Dictionary = native_source_base.duplicate(true)
	var source_sha: String = _fingerprint(native_source_base)
	var checked: Variant = store._validate_document(native_source_base)
	if not check("typed decodedDTO accepted by strict native source validator", _ok(checked) and _exact(checked.document, native_source_base), _result_code(checked)): return false
	if not check("typed decodedDTO input full types/IEEE unchanged", _exact(native_source_base, source_before) and _fingerprint(native_source_base) == source_sha): return false
	var boundary: Variant = Boundary.normalize_json(json_base.world.sections.map, json_base.world.content_version, {"mode": "campaign", "level_id": "level8", "waves": 0})
	if not check("existing fixed map JSON boundary repairs exactly196 ownership fields", _ok(boundary) and boundary.changed_paths.size() == 196, _result_code(boundary)): return false
	if not check("typed decodedDTO map exactly equals fixed boundary output", _exact(native_source_base.world.sections.map, boundary.value) and _exact(json_base, before) and _fingerprint(json_base) == before_sha): return false
	var noncanonical: Variant = store._decode(_envelope(decimal_payload))
	if not check("historical decimal .0 remains NONCANONICAL_RECORD", _refused(noncanonical, "NONCANONICAL_RECORD"), _result_code(noncanonical)): return false
	positives.append({"case": "actual_pending_decodedDTO", "original_payload_sha256": ORIGINAL_PAYLOAD_SHA256, "decimal_payload_sha256": DECIMAL_PAYLOAD_SHA256,
		"origin": "original failed pending JSON decoded through original Slot JSON hook/fixed ownership boundary; not another native World capture",
		"json_input_fingerprint": before_sha, "sourceDTO_fingerprint": source_sha, "canonical_exact": true, "native_source_valid": true, "fixed_ownership_paths": boundary.changed_paths,
		"historical_decimal_NONCANONICAL_RECORD": true, "disk_slot_writes": 0})
	return true

func _replacement(row: Dictionary) -> Dictionary:
	var kind: Variant = row.get("replacement_type")
	if typeof(kind) != TYPE_STRING: return {"ok": false}
	match kind:
		"nil": return {"ok": true, "value": null}
		"bool": return {"ok": true, "value": false}
		"int", "wrong_integer": return {"ok": true, "value": int(row.replacement)}
		"float", "fractional": return {"ok": true, "value": float(row.replacement)}
		"array": return {"ok": true, "value": []}
		"dictionary": return {"ok": true, "value": {}}
		"string": return {"ok": true, "value": row.replacement}
	return {"ok": false}

func _parent(value: Variant, parts: PackedStringArray) -> Dictionary:
	var cursor: Variant = value
	for index: int in range(parts.size() - 1):
		if typeof(cursor) != TYPE_DICTIONARY or not cursor.has(parts[index]): return {"ok": false}
		cursor = cursor[parts[index]]
	if typeof(cursor) != TYPE_DICTIONARY: return {"ok": false}
	return {"ok": true, "value": cursor, "key": parts[parts.size() - 1]}

func _mutate(base: Dictionary, row: Dictionary) -> Dictionary:
	var path: String = row.json_pointer
	var removing: bool = row.get("mutation", "") == "remove_key"
	var replacement: Dictionary = {"ok": true, "value": null} if removing else _replacement(row)
	if not replacement.ok: return {"ok": false}
	if path.is_empty(): return {"ok": not removing, "value": replacement.value, "replacement_actual_type": type_string(typeof(replacement.value))}
	if not path.begins_with("/"): return {"ok": false}
	var parts: PackedStringArray = path.trim_prefix("/").split("/")
	var output: Dictionary = base.duplicate(true)
	var selected: Dictionary = _parent(output, parts)
	if not selected.ok or not selected.value.has(selected.key): return {"ok": false}
	if removing: selected.value.erase(selected.key)
	else: selected.value[selected.key] = replacement.value
	return {"ok": true, "value": output, "replacement_actual_type": "missing" if removing else type_string(typeof(replacement.value))}

func _single_leaf(base: Dictionary, input: Variant, path: String) -> bool:
	if path.is_empty(): return true
	var before: Dictionary = base.duplicate(true)
	var after: Variant = _clone(input)
	var parts: PackedStringArray = path.trim_prefix("/").split("/")
	var left: Dictionary = _parent(before, parts)
	var right: Dictionary = _parent(after, parts)
	if not left.ok or not right.ok: return false
	left.value.erase(left.key)
	right.value.erase(right.key)
	return _exact(before, after)

func _negative_matrix() -> bool:
	var seen: Dictionary = {}
	for row: Variant in matrix.cases:
		if not check("matrix row exact declared identity", typeof(row) == TYPE_DICTIONARY and row.has_all(["id", "json_pointer", "expected_code", "routes", "single_leaf"]) and typeof(row.id) == TYPE_STRING and typeof(row.json_pointer) == TYPE_STRING and typeof(row.expected_code) == TYPE_STRING and typeof(row.routes) == TYPE_ARRAY and row.routes.size() == 2 and typeof(row.single_leaf) == TYPE_BOOL and row.single_leaf and not seen.has(row.id)): return false
		seen[row.id] = true
		for route: String in ROUTES:
			var base: Dictionary = native_source_base if route == "source" else json_base
			var base_before: Dictionary = base.duplicate(true)
			var mutated: Dictionary = _mutate(base, row)
			if not check("one leaf construction " + row.id + "/" + route, mutated.ok and _single_leaf(base, mutated.get("value"), row.json_pointer) and _exact(base, base_before), "MUTATION_CONSTRUCTION", row.json_pointer): return false
			var input: Variant = mutated.value
			var before: Variant = _clone(input)
			var before_sha: String = _fingerprint(input)
			var result: Variant = store._validate_document(input) if route == "source" else store._validate_json_document(input)
			var after_sha: String = _fingerprint(input)
			var unchanged: bool = _exact(input, before) and before_sha == after_sha
			var controlled: bool = _refused(result, row.expected_code)
			check("controlled exact refusal " + row.id + "/" + route, controlled, _result_code(result), row.json_pointer)
			check("full type/IEEE input unchanged " + row.id + "/" + route, unchanged, "INPUT_DRIFT" if not unchanged else "", row.json_pointer)
			case_rows.append({"id": row.id, "path": row.json_pointer, "route": route, "call": "_validate_document" if route == "source" else "_validate_json_document",
				"fixture_origin": "actual pending decodedDTO/direct model call; int test values deliberately constructed by harness, not claimed as JSON.parse integers",
				"replacement_actual_type": mutated.replacement_actual_type, "expected_code": row.expected_code, "code": _result_code(result),
				"controlled_refusal": controlled, "strictly_unchanged": unchanged, "before_type_ieee_sha256": before_sha, "after_type_ieee_sha256": after_sha,
				"slot_source_sha256": SOURCE_FILES[0].sha256, "original_payload_sha256": ORIGINAL_PAYLOAD_SHA256, "native_factory_calls": 0})
	return check("all134 distinct cases executed through both routes", seen.size() == EXPECT_CASES and case_rows.size() == EXPECT_CASES * ROUTES.size())

func _positive_float_waves() -> bool:
	for path: String in ["/context/waves", "/world/profile/context/waves"]:
		for route: String in ROUTES:
			var base: Dictionary = native_source_base if route == "source" else json_base
			var mutated: Dictionary = _mutate(base, {"json_pointer": path, "replacement_type": "float", "replacement": 0.0})
			if not check("float zero waves constructed " + path + "/" + route, mutated.ok): return false
			var input: Variant = mutated.value
			var before: Variant = _clone(input)
			var sha_before: String = _fingerprint(input)
			var result: Variant = store._validate_document(input) if route == "source" else store._validate_json_document(input)
			if not check("original INT/FLOAT zero document acceptance " + path + "/" + route, _ok(result), _result_code(result), path): return false
			if not check("float zero complete input types/IEEE unchanged " + path + "/" + route, _exact(input, before) and _fingerprint(input) == sha_before): return false
			positives.append({"case": "float_zero_wave_document", "path": path, "route": route, "input_fingerprint": sha_before, "passed": true, "canonical_byte_acceptance_claimed": false})
		# Isolate canonical .0 wave change from the already typed decodedDTO.
		var dto: Dictionary = _mutate(native_source_base, {"json_pointer": path, "replacement_type": "float", "replacement": 0.0})
		var refused: Variant = store._decode(_envelope(JSON.stringify(dto.value)))
		if not check("isolated decimal zero wave canonical record remains rejected " + path, _refused(refused, "NONCANONICAL_RECORD"), _result_code(refused), path): return false
	return true

func _canonical_controls() -> bool:
	var envelope: String = _envelope(original_payload)
	var parsed: Dictionary = _parse_dictionary(envelope, "canonical control envelope")
	if not parsed.ok: return false
	var value: Dictionary = parsed.value
	var bad: Dictionary = value.duplicate(true)
	bad.payload_sha256 = ZERO
	var result: Variant = store._decode(JSON.stringify(bad))
	if not check("original payload SHA refusal preserved", _refused(result, "PAYLOAD_HASH"), _result_code(result)): return false
	bad = value.duplicate(true)
	bad.payload_bytes = "1"
	result = store._decode(JSON.stringify(bad))
	if not check("original payload byte count refusal preserved", _refused(result, "PAYLOAD_HASH"), _result_code(result)): return false
	result = store._decode(envelope + "\n")
	if not check("original noncanonical envelope byte refusal preserved", _refused(result, "NONCANONICAL_ENVELOPE"), _result_code(result)): return false
	bad = value.duplicate(true)
	bad.revision = "2"
	result = store._decode(JSON.stringify(bad))
	if not check("original document revision refusal preserved", _refused(result, "DOCUMENT_REVISION"), _result_code(result)): return false
	positives.append({"case": "original_canonical_hash_controls", "passed": true, "disk_slot_writes": 0})
	return true

func _finish() -> void:
	if finished: return
	finished = true
	var pure_passed: bool = matrix_completed and case_rows.size() == EXPECT_CASES * ROUTES.size() and not checks.is_empty()
	for row: Dictionary in checks: pure_passed = pure_passed and row.passed
	var not_run: Array = [
		{"stage": "current_classic_whole_slot_positive_and_identity_matrix", "status": "not_run", "reason": "no qualified current complete classic fixture; campaign DTO/old component is not relabeled"},
		{"stage": "original_owned_slot_retry_complete_suite", "status": "not_run", "reason": "future producer must run original unchanged suite in its independent private profile"},
		{"stage": "producer_native_log_zero_SCRIPT_ERROR", "status": "not_run", "reason": "producer must inspect this actual process complete native log and exit status"}]
	var report := {"schema": "slot_identity_guard_report_v26", "harness_revision": "v26", "passed": false, "pure_matrix_passed": pure_passed, "overall_qualified": false,
		"qualification_complete": false, "missing_required_stages": not_run, "checks": checks, "cases": case_rows, "positive_controls": positives, "provenance": provenance, "source_files": source_rows,
		"pid": OS.get_process_id(), "nonce": nonce, "actual_user_data_dir": OS.get_user_data_dir(), "content_version": identity.get("content_version", ""), "engine_sha256": FileAccess.get_sha256(OS.get_executable_path()),
		"manifest_sha256": FileAccess.get_sha256(manifest_path) if not manifest_path.is_empty() else "", "matrix_sha256": MATRIX_SHA256,
		"harness_sha256": FileAccess.get_sha256("res://tools/slot_identity_guards_v26.gd"), "scene_sha256": FileAccess.get_sha256("res://tools/slot_identity_guards_v26.tscn"),
		"expected_case_count": EXPECT_CASES, "expected_route_count": EXPECT_CASES * ROUTES.size(), "actual_route_count": case_rows.size(),
		"sourceDTO_origin": "actual pending JSON decoded through original Slot JSON/fixed ownership boundary; not a new native capture",
		"data_only": true, "battle_factory_calls": 0, "unit_factory_calls": 0, "deploy_or_tick_calls": 0, "disk_slot_writes": 0, "private_runtime_patches": 0,
		"zero_SCRIPT_ERROR_verified": false, "full_world_continuation_qualified": false, "natural_result_qualified": false, "public_campaign_entry_qualified": false,
		"scope": "134 actual-pending decodedDTO single-leaf source/JSON controlled refusals, complete type/IEEE immutable inputs and original canonical/hash controls. Pure component evidence only."}
	if report_path.is_empty() or FileAccess.file_exists(report_path): pure_passed = false
	else:
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null: pure_passed = false
		else: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("NATIVE_SLOT_IDENTITY_V26_COMPONENT_COMPLETE ", case_rows.size(), " ", pure_passed, " overall_qualified=false")
	if get_node_or_null("/root/Sfx") != null: get_node("/root/Sfx").shutdown()
	if get_node_or_null("/root/Music") != null: get_node("/root/Music").shutdown()
	get_tree().quit(0 if pure_passed else 1)
