extends SceneTree
## External, model-only bootstrap. Never mounted into the frozen project.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	while Engine.is_in_physics_frame():
		await process_frame
	var folder: String = OS.get_environment("SPM_WORKERS").replace("\\", "/").simplify_path()
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty() \
		or not folder.is_absolute_path() or OS.get_environment("SPM_MODE") != "protocol_model":
		quit(2)
		return
	for item: Array in [["protocol_worker.gd", "SPM_WORKER_SHA256"], ["protocol_model.gd", "SPM_MODEL_SHA256"]]:
		if FileAccess.get_sha256(folder.path_join(item[0])) != OS.get_environment(item[1]):
			quit(2)
			return
	var worker_script: Script = load(folder.path_join("protocol_worker.gd"))
	if worker_script == null or not worker_script.can_instantiate():
		push_error("PROTOCOL_WORKER_SCRIPT_INVALID")
		quit(2)
		return
	root.add_child(worker_script.new())
