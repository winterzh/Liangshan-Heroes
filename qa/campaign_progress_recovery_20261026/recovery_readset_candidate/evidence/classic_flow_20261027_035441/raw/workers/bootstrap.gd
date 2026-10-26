extends SceneTree
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder: String = OS.get_environment("SC_WORKERS").replace("\\", "/")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SC_BINDINGS")))
	var names := ["driver.gd", "classic_base.gd", "policy.gd", "inflight.gd"]
	if not folder.is_absolute_path() or typeof(manifest) != TYPE_DICTIONARY \
		or manifest.size() != names.size() or not manifest.has_all(names): quit(2); return
	for name: String in names:
		if FileAccess.get_sha256(folder.path_join(name)) != manifest[name]: quit(2); return
	var script: Script = load(folder.path_join("driver.gd"))
	if script == null or not script.can_instantiate(): quit(2); return
	root.add_child(script.new())
