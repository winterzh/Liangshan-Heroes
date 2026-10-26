extends SceneTree
## External worker: production autoloads must exist before loading Battle dependencies.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder := OS.get_environment("LR_WORKERS").replace("\\", "/").simplify_path()
	var worker := folder.path_join("training.gd")
	if OS.get_environment("STEAM_DISABLED") != "1" or not folder.is_absolute_path() \
			or FileAccess.get_sha256(worker) != OS.get_environment("LR_WORKER_SHA256"):
		push_error("LIAN_WORKER_BINDING"); quit(2); return
	var script: Script = load(worker)
	if script == null or not script.can_instantiate():
		push_error("LIAN_WORKER_LOAD"); quit(2); return
	root.add_child(script.new())
