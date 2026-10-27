extends SceneTree
func _initialize() -> void:
	check.call_deferred()
func check() -> void:
	for name: String in ["bootstrap.gd","fixture_reader.gd","case_catalog.gd","worker_support.gd","world_worker.gd","component_worker.gd","capture_base.gd","capture_worker.gd"]:
		var script: Script = load(OS.get_environment("DAMING_NEGATIVE_PARSE_WORKERS").path_join(name))
		if script == null or not script.can_instantiate():
			push_error("DAMING_NEGATIVE_PARSER_INVALID: " + name)
			quit(2)
			return
	print("DAMING_NEGATIVE_WORKERS_COMPILED_WITHOUT_INSTANTIATION")
	quit(0)
