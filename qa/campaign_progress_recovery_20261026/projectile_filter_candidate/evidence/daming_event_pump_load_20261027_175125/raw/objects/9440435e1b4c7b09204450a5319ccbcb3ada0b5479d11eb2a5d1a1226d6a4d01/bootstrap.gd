extends SceneTree
const NAMES := ["bootstrap.gd","fixture_reader.gd","case_catalog.gd","worker_support.gd","world_worker.gd","component_worker.gd","capture_base.gd","capture_worker.gd"]
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	while Engine.is_in_physics_frame(): await process_frame
	var folder: String = OS.get_environment("DN_WORKERS").replace("\\", "/").simplify_path()
	var path: String = OS.get_environment("DN_REQUEST")
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): quit(2); return
	if not path.is_absolute_path() or FileAccess.get_sha256(path) != OS.get_environment("DN_REQUEST_SHA256"): quit(2); return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(value) != TYPE_DICTIONARY or value.get("schema") != "daming_negative_admission_request_v2" or value.get("scope") != "negative_matrix_52": quit(2); return
	var bindings: Variant = value.get("worker_bindings")
	if typeof(bindings) != TYPE_DICTIONARY or bindings.size() != NAMES.size() or not bindings.has_all(NAMES): quit(2); return
	for name: String in NAMES:
		if FileAccess.get_sha256(folder.path_join(name)) != bindings[name]: quit(2); return
	var family: String = OS.get_environment("DN_FAMILY")
	if not family in ["world","component","capture"] or value.get("family") != family: quit(2); return
	var script: Script = load(folder.path_join(family + "_worker.gd"))
	if script == null or not script.can_instantiate(): push_error("DAMING_NEGATIVE_WORKER_SCRIPT_INVALID"); quit(2); return
	root.add_child(script.new())
