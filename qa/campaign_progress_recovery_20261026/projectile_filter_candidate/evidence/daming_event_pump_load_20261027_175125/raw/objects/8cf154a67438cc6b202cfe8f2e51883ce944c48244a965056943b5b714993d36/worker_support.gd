extends RefCounted
## Shared native admission/report boundary. No saved packet is manufactured here.
const Provider := preload("res://scripts/run_content_identity.gd")
const Factory := preload("res://scripts/run_level8_world_factory.gd")
const Reader := preload("fixture_reader.gd")
var runner: Node
var reader: RefCounted
var request: Dictionary = {}
var admitted: Dictionary = {}
var trusted: Dictionary = {}
var runtime: Dictionary = {}
var checks: Array = []
var family := ""
var finished := false
var window_event_frames := 0

func check(ok: bool, label: String) -> bool:
	checks.append({"passed":ok,"label":label})
	return ok

func begin(node: Node, expected_family: String) -> Dictionary:
	runner = node
	family = expected_family
	reader = Reader.new()
	var profile: String = reader.path(OS.get_environment("DN_PROFILE"))
	var safe: bool = not profile.is_empty() and reader.no_links(profile) and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and reader.path(OS.get_environment(key)).to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and reader.path(OS.get_user_data_dir()).to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("LSH_CONTINUE_FLOW_QA").is_empty()
	if not check(safe, "fresh four-root isolated environment; no QA gameplay gate"): return {}
	var path: String = reader.path(OS.get_environment("DN_REQUEST"))
	if not check(reader.no_links(path) and FileAccess.get_sha256(path) == OS.get_environment("DN_REQUEST_SHA256"), "exact native request SHA"): return {}
	request = reader.parse(FileAccess.get_file_as_string(path), "native request")
	if request.is_empty(): return {}
	if not check(request.get("scope") == "negative_matrix_52" and request.get("family") == family
		and family in ["world","component","capture"] and OS.get_environment("DN_FAMILY") == family
		and request.get("case", "") == OS.get_environment("DN_CASE")
		and request.get("consumer_process_nonce") == OS.get_environment("DN_PROCESS_NONCE")
		and request.get("consumer_batch_nonce") == OS.get_environment("DN_BATCH_NONCE")
		and request.get("consumer_profile") == OS.get_environment("DN_PROFILE")
		and not OS.get_environment("DN_PROCESS_NONCE").is_empty(), "actual consumer role/family/case/nonces/profile"): return {}
	if not check(reader.path(ProjectSettings.globalize_path("res://")) == reader.path(OS.get_environment("DN_PROJECT"))
		and request.get("project") == OS.get_environment("DN_PROJECT"), "actual frozen project path"): return {}
	var folder: String = reader.path(OS.get_environment("DN_WORKERS"))
	var worker_bindings: Variant = request.get("worker_bindings")
	if not check(typeof(worker_bindings) == TYPE_DICTIONARY and not worker_bindings.is_empty(), "worker binding map"): return {}
	for name: Variant in worker_bindings:
		if not check(typeof(name) == TYPE_STRING and name.get_file() == name and name.ends_with(".gd")
			and FileAccess.get_sha256(folder.path_join(name)) == worker_bindings[name], "exact worker bytes " + str(name)): return {}
	var evidence: String = reader.path(OS.get_environment("DN_EVIDENCE"))
	var output: String = reader.path(OS.get_environment("DN_OUTPUT"))
	if not check(reader.no_links(output) and DirAccess.dir_exists_absolute(output)
		and evidence == output.path_join("evidence") and not DirAccess.dir_exists_absolute(evidence)
		and DirAccess.make_dir_absolute(evidence) == OK, "exclusive evidence directory"): return {}
	var startup: Node = runner.get_node("/root/ContinueFlow")
	var gate: Script = load("res://scripts/run_campaign_progress_gate.gd")
	for frame in range(600):
		await runner.get_tree().process_frame
		if startup.phase == startup.Phase.IDLE and startup.last_result.get("startup_checked", false) and gate.background_allowed(): break
	while Engine.is_in_physics_frame(): await runner.get_tree().process_frame
	if not check(startup.phase == startup.Phase.IDLE and startup.last_result.get("startup_checked", false)
		and gate.background_allowed(), "normal startup finished before native fixture admission"): return {}
	if not check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60
		and runner.get_node("/root/Settings").game_speed == 1.0, "unchanged 1x/60Hz clock"): return {}
	trusted = Provider.new().resolve_runtime_identity()
	print("DN_TIMING ", Time.get_ticks_msec(), " ", family, " reader admission begin")
	admitted = reader.admit(request, trusted)
	print("DN_TIMING ", Time.get_ticks_msec(), " ", family, " reader admission end")
	if not check(not admitted.is_empty(), "original closed A native Slot/LC admitted"): return {}
	if not check(profile_unchanged(), "private slot/journal exact after ordinary startup"): return {}
	var sources: Variant = request.get("source_pins")
	if not check(typeof(sources) == TYPE_DICTIONARY and not sources.is_empty(), "installed component source bindings"): return {}
	for source: Variant in sources:
		if not check(typeof(source) == TYPE_STRING and source.begins_with("res://scripts/") and source.ends_with(".gd")
			and not ".." in source and FileAccess.get_sha256(source) == sources[source], "actual installed source " + str(source)): return {}
	print("DN_TIMING ", Time.get_ticks_msec(), " ", family, " runtime begin")
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	print("DN_TIMING ", Time.get_ticks_msec(), " ", family, " runtime end")
	if not check(pack.get("ok", false), "fixed trusted Level8 runtime"): return {}
	runtime = pack.runtime
	return admitted

func pump_paused_window() -> bool:
	# Whole rows remain synchronous. Yield only after their validation/disposal;
	# no live World is installed by either matrix and the SceneTree stays paused.
	if not check(runner.get_tree().paused and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60,
		"paused window pump begins with unchanged 1x/60Hz clock"): return false
	var before_frame: int = Engine.get_process_frames()
	await runner.get_tree().process_frame
	if not check(runner.get_tree().paused and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60
		and Engine.get_process_frames() > before_frame, "window frame advanced while gameplay remains paused at 1x/60Hz"): return false
	window_event_frames += 1
	return true

func profile_unchanged() -> bool:
	return not admitted.is_empty() and reader.inventory_matches(ProjectSettings.globalize_path("user://continue/v1"), admitted.descriptor.frozen_inventory, admitted.packet.binding.token)

func finish(payload: Dictionary, passed: bool) -> void:
	if finished: return
	finished = true
	check(reader != null and reader.unchanged(), "all original pinned fixture bytes unchanged at finish")
	check(profile_unchanged(), "whole private slot/journal bytes and directories unchanged at finish")
	if passed and family in ["world", "component"]:
		check(window_event_frames == (266 if family == "world" else 364), "each complete positive route and original negative row yielded exactly once while paused")
	var all_checks: Array = checks.duplicate(true)
	if reader != null: all_checks.append_array(reader.checks)
	all_checks.append_array(payload.get("checks", []))
	passed = passed and not admitted.is_empty() and not all_checks.is_empty() and all_checks.all(func(row): return row is Dictionary and row.get("passed") == true)
	var result: Dictionary = payload.duplicate(true)
	result.merge({"schema":"daming_negative_stage_report_v2","passed":passed,"checks":all_checks,
		"paused_window_event_frames":window_event_frames,
		"family":family,"case":request.get("case", ""),"first_role":request.get("first_role", ""),
		"pid":OS.get_process_id(),"profile":OS.get_environment("DN_PROFILE"),"actual_user_data_dir":OS.get_user_data_dir(),
		"batch_nonce":OS.get_environment("DN_BATCH_NONCE"),"process_nonce":OS.get_environment("DN_PROCESS_NONCE"),
		"request_path":OS.get_environment("DN_REQUEST"),"request_sha256":OS.get_environment("DN_REQUEST_SHA256"),
		"identity":trusted,"source_pins":request.get("source_pins", {}),"worker_bindings":request.get("worker_bindings", {}),
		"fixture_provenance":reader.provenance if reader != null else [],
		"fixture_admission_passed":not admitted.is_empty(),"native_slot_decode_called":reader.slot_decode_called if reader != null else false,
		"native_lifecycle_decode_called":reader.lifecycle_decode_called if reader != null else false,
		"producer_terminal_document_validate_called":reader.terminal_document_validate_called if reader != null else false,
		"source_flow_chain_passed":false,"full_61_qualified":false,"original_19_faults_qualified":false,
		"cold_import_qualified":false,"native_sdk_qualified":false,"public_continue_qualified":false,
		"native_release_tested":false,"human_acceptance":false,"published":false}, true)
	var destination: String = reader.path(OS.get_environment("DN_REPORT"))
	var output: String = reader.path(OS.get_environment("DN_OUTPUT"))
	if destination != output.path_join("report.json") or not reader.no_links(output) or not DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(destination): passed = false
	else:
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null: passed = false
		else:
			file.store_string(JSON.stringify(result, "\t") + "\n"); file.flush()
			passed = passed and file.get_error() == OK; file.close()
	if runner.get_node_or_null("/root/Sfx") != null: runner.get_node("/root/Sfx").shutdown()
	if runner.get_node_or_null("/root/Music") != null: runner.get_node("/root/Music").shutdown()
	runner.get_tree().quit(0 if passed else 1)
