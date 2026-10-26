extends SceneTree
## Normal autoload startup; the diagnostic operates on a same-byte private copy.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder: String = OS.get_environment("CT_WORKERS").replace("\\", "/")
	var path: String = folder.path_join("driver.gd")
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" \
		or FileAccess.get_sha256(path) != OS.get_environment("CT_WORKER_SHA256"):
		push_error("CLASSIC_TIMING_WORKER_SCOPE"); quit(2); return
	var script: Script = load(path)
	if script == null or not script.can_instantiate(): quit(2); return
	root.add_child(script.new())
