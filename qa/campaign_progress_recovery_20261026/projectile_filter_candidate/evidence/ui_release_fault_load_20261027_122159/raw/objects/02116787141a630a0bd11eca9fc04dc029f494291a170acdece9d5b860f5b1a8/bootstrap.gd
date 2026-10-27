extends SceneTree
## Load-only pin checks precede the independent fault-model worker.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder: String = OS.get_environment("URF_WORKERS").replace("\\", "/")
	var bindings: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("URF_BINDINGS")))
	var names: Array = ["bootstrap.gd","base.gd","worker.gd"]
	if not folder.is_absolute_path() or typeof(bindings) != TYPE_DICTIONARY or bindings.size() != names.size() or not bindings.has_all(names):
		push_error("UI_RELEASE_FAULT_BINDINGS_INVALID"); quit(2); return
	for name: String in names:
		if FileAccess.get_sha256(folder.path_join(name)) != bindings[name]:
			push_error("UI_RELEASE_FAULT_WORKER_HASH:" + name); quit(2); return
	var script: Script = load(folder.path_join("worker.gd"))
	if script == null or not script.can_instantiate():
		push_error("UI_RELEASE_FAULT_WORKER_SCRIPT_INVALID"); quit(2); return
	root.add_child(script.new())
