extends SceneTree
## Protocol qualification only: real ConfigFile before/after the owned debugger pause.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := OS.get_environment("CAMPAIGN_FAULT_PROBE_OUT")
	var expected := OS.get_environment("CAMPAIGN_FAULT_PROBE_PROFILE")
	if output.is_empty() or expected.is_empty() or not OS.get_user_data_dir().begins_with(expected):
		push_error("PRIVATE_FAULT_PROBE_PROFILE_REQUIRED")
		quit(2)
		return
	var path := "user://debug_probe.cfg"
	var config := ConfigFile.new()
	config.set_value("proof", "value", 11)
	var saved := config.save(path)
	var before := FileAccess.get_sha256(path)
	# The external controller's breakpoint targets the exact following native read.
	var independent := ConfigFile.new()
	var loaded := independent.load(path)
	var report := {
		"schema": "campaign_fault_debug_probe_v1",
		"pid": OS.get_process_id(), "nonce": OS.get_environment("CAMPAIGN_FAULT_PROBE_NONCE"),
		"save_error": saved, "load_error": loaded, "before_sha256": before,
		"after_sha256": FileAccess.get_sha256(path),
		"value": independent.get_value("proof", "value", -1),
		"actual_user_dir": OS.get_user_data_dir(),
		"production_campaign_called": false, "fault_matrix_qualified": false,
	}
	var file := FileAccess.open(output.path_join("probe_report.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("CAMPAIGN_FAULT_DEBUG_PROBE_COMPLETE ", JSON.stringify(report))
	quit(0)
