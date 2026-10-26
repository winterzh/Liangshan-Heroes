extends SceneTree
## External QA, loaded only after the real package's autoloads are ready.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path := OS.get_environment("CH_WORKER").replace("\\", "/").simplify_path()
	var allowed := OS.get_environment("CH_WORKER_ROOT").replace("\\", "/").simplify_path()
	var manifest_path := OS.get_environment("CH_QA_BINDINGS")
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty() or not allowed.is_absolute_path() or path.get_base_dir() != allowed:
		push_error("CH_PRIVATE_WORKER_SCOPE"); quit(2); return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if manifest.size() != 3 or not manifest.has_all(["base.gd", "live.gd", "reject_terminal.gd"]):
		push_error("CH_REQUIRED_QA_INPUTS"); quit(2); return
	for relative in manifest:
		if relative not in ["base.gd", "live.gd", "reject_terminal.gd"]:
			push_error("CH_UNKNOWN_QA_INPUT"); quit(2); return
		if FileAccess.get_sha256(allowed.path_join(relative)) != manifest[relative]:
			push_error("CH_QA_INPUT_CHANGED"); quit(2); return
	if not manifest.has(path.get_file()):
		push_error("CH_UNBOUND_WORKER"); quit(2); return
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		push_error("CH_WORKER_LOAD"); quit(2); return
	var worker: Variant = script.new()
	if not worker is Node:
		push_error("CH_REAL_TREE_NODE_REQUIRED"); quit(2); return
	root.add_child(worker)
