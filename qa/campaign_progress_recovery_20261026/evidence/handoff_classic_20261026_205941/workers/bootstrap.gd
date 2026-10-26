extends SceneTree
## External observer; production autoloads and runtime identity remain untouched.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder := OS.get_environment("CC_WORKERS").replace("\\", "/").simplify_path()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CC_BINDINGS")))
	var names := ["driver.gd", "policy.gd", "inflight.gd"]
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" \
		or not OS.get_environment("CAMPAIGN_QA").is_empty() or typeof(parsed) != TYPE_DICTIONARY \
		or parsed.size() != names.size() or not parsed.has_all(names):
		push_error("CLASSIC_EXTERNAL_SCOPE_REQUIRED"); quit(2); return
	for name in names:
		if FileAccess.get_sha256(folder.path_join(name)) != parsed[name]:
			push_error("CLASSIC_WORKER_SHA_CHANGED:" + name); quit(2); return
	var script: Script = load(folder.path_join("driver.gd"))
	if script == null or not script.can_instantiate():
		push_error("CLASSIC_WORKER_LOAD_FAILED"); quit(2); return
	var worker: Variant = script.new()
	if not worker is Node:
		push_error("CLASSIC_REAL_NODE_REQUIRED"); quit(2); return
	root.add_child(worker)
