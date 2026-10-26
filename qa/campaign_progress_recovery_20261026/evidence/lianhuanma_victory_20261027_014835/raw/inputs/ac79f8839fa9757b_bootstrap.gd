extends SceneTree
## External fixture only. Root's approved runner must bind the frozen project,
## candidate scripts, this file, worker, engine, profile and terminal receipt.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder: String = OS.get_environment("CB_WORKERS").replace("\\", "/").simplify_path()
	var path: String = folder.path_join("binding_disk.gd")
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" \
		or not OS.get_environment("CAMPAIGN_QA").is_empty() \
		or FileAccess.get_sha256(path) != OS.get_environment("CB_WORKER_SHA256"):
		push_error("CONTINUE_BINDING_WORKER_SCOPE"); quit(2); return
	var script: Script = load(path)
	if script == null or not script.can_instantiate(): quit(2); return
	root.add_child(script.new())
