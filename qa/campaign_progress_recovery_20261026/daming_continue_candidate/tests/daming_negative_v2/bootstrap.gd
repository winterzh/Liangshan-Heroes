extends SceneTree
## Admission-only external entry. No old res://tools worker is inherited.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	while Engine.is_in_physics_frame(): await process_frame
	var folder: String = OS.get_environment("DN_WORKERS").replace("\\", "/").simplify_path()
	var request_path: String = OS.get_environment("DN_REQUEST")
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" \
		or not OS.get_environment("CAMPAIGN_QA").is_empty(): quit(2); return
	if not request_path.is_absolute_path() or FileAccess.get_sha256(request_path) != OS.get_environment("DN_REQUEST_SHA256"):
		quit(2); return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path))
	if typeof(value) != TYPE_DICTIONARY or value.get("schema") != "daming_negative_admission_request_v2": quit(2); return
	var bindings: Variant = value.get("worker_bindings")
	if typeof(bindings) != TYPE_DICTIONARY or bindings.size() != 4 \
		or not bindings.has_all(["bootstrap.gd","fixture_reader.gd","admission_worker.gd","case_catalog.gd"]): quit(2); return
	for name: String in bindings:
		if FileAccess.get_sha256(folder.path_join(name)) != bindings[name]: quit(2); return
	var script: Script = load(folder.path_join("admission_worker.gd"))
	if script == null or not script.can_instantiate(): quit(2); return
	root.add_child(script.new())
