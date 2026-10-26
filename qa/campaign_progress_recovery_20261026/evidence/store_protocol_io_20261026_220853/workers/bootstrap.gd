extends SceneTree
## External bootstrap only; the frozen project and its scripts stay untouched.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder := OS.get_environment("SP_WORKERS").replace("\\", "/").simplify_path()
	var worker := folder.path_join("worker.gd")
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty() \
		or not folder.is_absolute_path() or FileAccess.get_sha256(worker) != OS.get_environment("SP_WORKER_SHA256"):
		push_error("HANDOFF_SP_WORKER_BINDING"); quit(2); return
	var script: Script = load(worker)
	if script == null or not script.can_instantiate(): quit(2); return
	root.add_child(script.new())
