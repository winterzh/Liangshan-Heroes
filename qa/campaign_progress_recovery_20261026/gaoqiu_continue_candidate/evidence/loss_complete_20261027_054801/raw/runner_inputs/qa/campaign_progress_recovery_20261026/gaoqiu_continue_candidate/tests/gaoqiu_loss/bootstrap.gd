extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	while Engine.is_in_physics_frame(): await process_frame
	var folder: String = OS.get_environment("GLS_WORKERS").replace("\\", "/").simplify_path()
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): quit(2); return
	var binding_path: String = OS.get_environment("GLS_BINDINGS")
	if FileAccess.get_sha256(binding_path) != OS.get_environment("GLS_BINDINGS_SHA256"): quit(2); return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(binding_path))
	if typeof(value) != TYPE_DICTIONARY or value.size() != 4 or not value.has_all(["base.gd", "terminal.gd", "driver.gd", "bootstrap.gd"]): quit(2); return
	for name: String in value:
		if FileAccess.get_sha256(folder.path_join(name)) != value[name]: quit(2); return
	var script: Script = load(folder.path_join("driver.gd"))
	if script == null or not script.can_instantiate():
		push_error("GAO_LOSS_WORKER_SCRIPT_INVALID")
		quit(2)
		return
	root.add_child(script.new())
