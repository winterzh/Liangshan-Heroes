extends SceneTree
## Instantiate only the level data object; never deploy/start a battle or open a save.
func _initialize() -> void:
	var driver_path := OS.get_environment("LT_STRATEGY_SOURCE")
	if driver_path.is_empty() or OS.get_environment("STEAM_DISABLED") != "1":
		push_error("STRATEGY_PRIVATE_PREFLIGHT_REQUIRED"); quit(2); return
	var level_script: Script = load("res://scripts/levels/level4_lianhuanma_rts.gd")
	var level: RefCounted = level_script.new()
	var names: Dictionary = level_script.get_script_constant_map()
	for item in level.get_property_list(): names[item.name] = true
	for item in level.get_method_list(): names[item.name] = true
	var expression := RegEx.new()
	expression.compile("\\blevel\\.([A-Za-z_][A-Za-z_0-9]*)")
	var referenced: Dictionary = {}
	for item in expression.search_all(FileAccess.get_file_as_string(driver_path)):
		var member := item.get_string(1)
		if not names.has(member):
			push_error("STRATEGY_UNKNOWN_LEVEL_MEMBER: " + member); quit(2); return
		referenced[member] = true
	var driver: Script = load(driver_path)
	if driver == null or not driver.can_instantiate():
		push_error("STRATEGY_DRIVER_PARSE_FAILED"); quit(2); return
	print("STRATEGY_CONTRACT PASS members=", referenced.size(), " no_battle_deployed=true no_save_opened=true")
	quit(0)
