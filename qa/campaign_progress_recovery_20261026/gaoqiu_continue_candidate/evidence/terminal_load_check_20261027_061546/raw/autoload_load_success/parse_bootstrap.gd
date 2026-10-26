extends SceneTree
func _initialize() -> void:
	check.call_deferred()
func check() -> void:
	for name: String in ["driver.gd","bootstrap.gd"]:
		var script: Script = load(OS.get_environment("GAO_PARSE_WORKERS").path_join(name))
		if script == null or not script.can_instantiate():
			push_error("GAO_PARSER_INVALID: " + name)
			quit(2)
			return
	print("GAO_WORKERS_COMPILED_WITHOUT_INSTANTIATION")
	quit(0)
