extends SceneTree
## External QA only. Production autoload startup remains enabled.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder: String = OS.get_environment("RS_WORKERS").replace("\\", "/")
	var driver: String = folder.path_join("driver.gd")
	var fixtures: String = folder.path_join("fixtures.gd")
	if not folder.is_absolute_path() or OS.get_environment("STEAM_DISABLED") != "1" \
		or not OS.get_environment("CAMPAIGN_QA").is_empty() \
		or FileAccess.get_sha256(driver) != OS.get_environment("RS_DRIVER_SHA256") \
		or FileAccess.get_sha256(fixtures) != OS.get_environment("RS_FIXTURES_SHA256"):
		push_error("READSET_WORKER_SCOPE")
		quit(2)
		return
	var script: Script = load(driver)
	if script == null or not script.can_instantiate():
		quit(2)
		return
	root.add_child(script.new())
