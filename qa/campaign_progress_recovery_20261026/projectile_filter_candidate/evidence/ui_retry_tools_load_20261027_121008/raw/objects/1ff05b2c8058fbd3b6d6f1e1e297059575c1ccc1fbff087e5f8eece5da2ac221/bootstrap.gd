extends SceneTree
## Three exact external source pins; loading does not substitute a production API.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder: String = OS.get_environment("UST_WORKERS").replace("\\","/")
	var pins: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("UST_BINDINGS")))
	var names := ["bootstrap.gd","base.gd","worker.gd"]
	if not folder.is_absolute_path() or typeof(pins) != TYPE_DICTIONARY or pins.size() != names.size() or not pins.has_all(names):
		push_error("UI_STARTUP_RETRY_BINDINGS_INVALID"); quit(2); return
	for name: String in names:
		if FileAccess.get_sha256(folder.path_join(name)) != pins[name]:
			push_error("UI_STARTUP_RETRY_WORKER_HASH:" + name); quit(2); return
	var script: Script = load(folder.path_join("worker.gd"))
	if script == null or not script.can_instantiate():
		push_error("UI_STARTUP_RETRY_WORKER_SCRIPT_INVALID"); quit(2); return
	root.add_child(script.new())
