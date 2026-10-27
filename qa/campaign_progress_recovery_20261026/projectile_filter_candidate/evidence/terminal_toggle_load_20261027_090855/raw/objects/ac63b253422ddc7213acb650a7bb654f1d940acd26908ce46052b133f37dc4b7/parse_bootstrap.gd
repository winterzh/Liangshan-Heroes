extends SceneTree
func _initialize() -> void:
	check.call_deferred()
func check() -> void:
	for name: String in ["bootstrap.gd","base.gd","terminal.gd","driver.gd","policy.gd"]:
		var script: Script = load(OS.get_environment("GAO_TOGGLE_PARSE_WORKERS").path_join(name))
		if script == null or not script.can_instantiate():
			push_error("GAO_TOGGLE_PARSER_INVALID: " + name)
			quit(2)
			return
	print("GAO_TOGGLE_WORKERS_COMPILED_WITHOUT_INSTANTIATION")
	quit(0)
