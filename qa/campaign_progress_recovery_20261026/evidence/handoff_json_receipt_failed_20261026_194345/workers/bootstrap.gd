extends SceneTree
func _initialize() -> void:
	start.call_deferred()
func start() -> void:
	var folder := OS.get_environment("MR_WORKERS").replace("\\","/").simplify_path()
	if OS.get_environment("STEAM_DISABLED") != "1" or not folder.is_absolute_path(): quit(2); return
	for item in [["model_worker.gd","MR_WORKER_SHA256"],["receipt_model.gd","MR_MODEL_SHA256"]]:
		if FileAccess.get_sha256(folder.path_join(item[0])) != OS.get_environment(item[1]): quit(2); return
	var script: Script = load(folder.path_join("model_worker.gd"))
	if script == null or not script.can_instantiate(): quit(2); return
	root.add_child(script.new())
