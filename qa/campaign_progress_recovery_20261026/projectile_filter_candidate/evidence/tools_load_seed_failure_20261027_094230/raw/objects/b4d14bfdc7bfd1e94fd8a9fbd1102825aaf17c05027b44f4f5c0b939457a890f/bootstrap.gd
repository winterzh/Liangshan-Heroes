extends SceneTree
## External synthetic component only; ordinary autoload startup remains enabled.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder: String = OS.get_environment("P19_WORKERS").replace("\\", "/").simplify_path()
	var path: String = folder.path_join("worker.gd")
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" \
		or not OS.get_environment("CAMPAIGN_QA").is_empty() \
		or not OS.get_environment("LSH_CONTINUE_FLOW_QA").is_empty() \
		or OS.get_environment("P19_WORKER_SHA256").length() != 64 \
		or FileAccess.get_sha256(path) != OS.get_environment("P19_WORKER_SHA256") \
		or OS.get_environment("P19_PLAN_SHA256").length() != 64 \
		or FileAccess.get_sha256(folder.path_join("cases.json")) != OS.get_environment("P19_PLAN_SHA256"):
		push_error("PERSISTENCE19_BOOTSTRAP_SCOPE"); quit(2); return
	var worker: Script = load(path)
	if worker == null or not worker.can_instantiate(): quit(2); return
	root.add_child(worker.new())
