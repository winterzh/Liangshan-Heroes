extends Node
## Native admission/catalog probe only. It never runs or claims a negative row.
const Provider := preload("res://scripts/run_content_identity.gd")
var checks: Array = []
var reader: RefCounted
var request: Dictionary = {}
var admitted: Dictionary = {}
var world_specs: Array = []
var component_specs: Array = []
var capture_cases: Dictionary = {}

func check(ok: bool, label: String) -> bool:
	checks.append({"passed":ok,"label":label})
	return ok

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func run() -> void:
	var profile: String = OS.get_environment("DN_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty()
	if not check(safe, "fresh four-root private environment"): finish(); return
	var request_path: String = OS.get_environment("DN_REQUEST")
	if not check(FileAccess.get_sha256(request_path) == OS.get_environment("DN_REQUEST_SHA256"), "request exact SHA"): finish(); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path))
	if not check(typeof(parsed) == TYPE_DICTIONARY, "request JSON object"): finish(); return
	request = parsed
	if not check(request.get("consumer_process_nonce") == OS.get_environment("DN_PROCESS_NONCE")
		and request.get("consumer_batch_nonce") == OS.get_environment("DN_BATCH_NONCE")
		and not OS.get_environment("DN_PROCESS_NONCE").is_empty(), "actual consumer nonces"): finish(); return
	var startup: Node = get_node("/root/ContinueFlow")
	var gate: Script = load("res://scripts/run_campaign_progress_gate.gd")
	for frame in range(300):
		await get_tree().process_frame
		if startup.phase == startup.Phase.IDLE and startup.last_result.get("startup_checked", false) and gate.background_allowed(): break
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check(startup.phase == startup.Phase.IDLE and startup.last_result.get("startup_checked", false)
		and gate.background_allowed(), "real startup ready before fixture decoding"): finish(); return
	if not check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60
		and get_node("/root/Settings").game_speed == 1.0, "normal unchanged clock"): finish(); return
	var folder: String = OS.get_environment("DN_WORKERS").replace("\\", "/").simplify_path()
	var reader_script: Script = load(folder.path_join("fixture_reader.gd"))
	var catalog: Script = load(folder.path_join("case_catalog.gd"))
	if not check(reader_script != null and catalog != null and reader_script.can_instantiate(), "external reader/catalog load"): finish(); return
	reader = reader_script.new()
	var trusted: Dictionary = Provider.new().resolve_runtime_identity()
	admitted = reader.admit(request, trusted)
	if not check(not admitted.is_empty(), "native raw fixture admitted"): finish(); return
	world_specs = catalog.world_specs()
	component_specs = catalog.component_specs()
	capture_cases = catalog.CAPTURE_CASES.duplicate(true)
	var world_ids := {}; var component_ids := {}
	for row: Dictionary in world_specs: world_ids[row.id] = true
	for row: Dictionary in component_specs: component_ids[row.id] = true
	check(world_specs.size() == 132 and world_ids.size() == 132, "132 exact world specs, no execution")
	check(component_specs.size() == 181 and component_ids.size() == 181, "181 exact component specs, no execution")
	check(capture_cases.size() == 24, "24 exact capture cases, no execution")
	check(reader.unchanged(), "all frozen input bytes unchanged")
	finish()

func finish() -> void:
	var all_checks: Array = checks.duplicate(true)
	if reader != null: all_checks.append_array(reader.checks)
	var passed: bool = not admitted.is_empty() and not all_checks.is_empty() and all_checks.all(func(row): return row.passed)
	var result := {"schema":"daming_negative_admission_report_v2","passed":passed,
		"fixture_admission_passed":passed,"negative_matrix_passed":false,"executed_negative_rows":0,
		"checks":all_checks,"pid":OS.get_process_id(),"first_role":request.get("first_role", ""),
		"batch_nonce":OS.get_environment("DN_BATCH_NONCE"),"process_nonce":OS.get_environment("DN_PROCESS_NONCE"),
		"request_path":OS.get_environment("DN_REQUEST"),"request_sha256":OS.get_environment("DN_REQUEST_SHA256"),
		"actual_user_data_dir":OS.get_user_data_dir(),"profile":OS.get_environment("DN_PROFILE"),
		"identity":Provider.new().resolve_runtime_identity(),
		"planned_world_specs":world_specs,"planned_component_specs":component_specs,"planned_capture_cases":capture_cases,
		"safe_id":admitted.get("safe_id", ""),"other_id":admitted.get("other_id", ""),
		"provenance":reader.provenance if reader != null else [],
		"native_slot_decode_called":reader.slot_decode_called if reader != null else false,
		"native_lifecycle_decode_called":reader.lifecycle_decode_called if reader != null else false,
		"producer_terminal_document_validate_called":reader.terminal_document_validate_called if reader != null else false,
		"core_prepare_called":false,"core_capture_called":false,
		"profile_payload_written":false,"whole_world_payload_in_report":false,
		"source_flow_chain_passed":false,"full_61_qualified":false,"original_19_faults_qualified":false,
		"cold_import_qualified":false,"native_sdk_qualified":false,"native_release_tested":false,
		"public_continue_qualified":false,"human_acceptance":false,"published":false}
	var destination: String = OS.get_environment("DN_REPORT").replace("\\", "/").simplify_path()
	var output: String = OS.get_environment("DN_OUTPUT").replace("\\", "/").simplify_path().trim_suffix("/")
	if destination != output.path_join("report.json") or not output.is_absolute_path() \
		or not DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(destination): passed = false
	else:
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null: passed = false
		else:
			file.store_string(JSON.stringify(result, "\t") + "\n"); file.flush()
			passed = passed and file.get_error() == OK; file.close()
	if get_node_or_null("/root/Sfx") != null: get_node("/root/Sfx").shutdown()
	if get_node_or_null("/root/Music") != null: get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
