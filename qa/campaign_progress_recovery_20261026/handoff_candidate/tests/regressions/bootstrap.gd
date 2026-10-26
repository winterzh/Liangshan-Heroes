extends SceneTree
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder := OS.get_environment("RG_WORKERS").replace("\\","/").simplify_path()
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty():
		push_error("REGRESSION_PRIVATE_SCOPE_REQUIRED"); quit(2); return
	for item in [["worker.gd","RG_WORKER_SHA256"],["receipt_case.gd","RG_RECEIPT_SHA256"],["session_case.gd","RG_SESSION_SHA256"]]:
		if FileAccess.get_sha256(folder.path_join(item[0])) != OS.get_environment(item[1]):
			push_error("REGRESSION_WORKER_SHA_CHANGED"); quit(2); return
	var script: Script = load(folder.path_join("worker.gd"))
	if script == null or not script.can_instantiate():
		push_error("REGRESSION_WORKER_LOAD"); quit(2); return
	root.add_child(script.new())
