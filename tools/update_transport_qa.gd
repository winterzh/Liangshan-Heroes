extends SceneTree
## Run only inside the private project made by run_update_transport_qa.py.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var mode := OS.get_environment("UPDATE_QA_MODE")
	var report := {"mode": mode, "user_dir": OS.get_user_data_dir(), "passed": false}
	if not OS.get_user_data_dir().contains("LSH-update-qa-"):
		push_error("Private update QA profile required")
		quit(2)
		return
	var updater = root.get_node("AndroidUpdater")
	var test_version := OS.get_environment("UPDATE_QA_CONTENT_VERSION")
	if mode == "pack":
		var packer := PCKPacker.new()
		var ok := packer.pck_start(OS.get_environment("UPDATE_QA_PACK")) == OK
		ok = ok and packer.add_file("res://update_qa_marker.txt", OS.get_environment("UPDATE_QA_MARKER")) == OK
		report.passed = ok and packer.flush() == OK
	elif mode == "windows":
		# An old downloaded cache must remain untouched and unmounted.
		var directory := "user://content_updates/windows"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var file := FileAccess.open(directory + "/state.json", FileAccess.WRITE)
		file.store_string("windows-cache-sentinel")
		file.close()
		var old_cache := FileAccess.get_sha256(directory + "/state.json")
		var second = updater.get_script().new()
		report.passed = not updater.enabled and updater._request == null and updater._update_dir == "" \
			and not second.enabled and second._update_dir == "" \
			and FileAccess.get_sha256(directory + "/state.json") == old_cache \
			and updater.run_content_mount_identity().complete
		second.free()
	elif mode == "mount":
		report.passed = updater.enabled and updater.active_content_version == test_version \
			and FileAccess.get_file_as_string("res://update_qa_marker.txt") == "isolated-patch-loaded" \
			and updater.run_content_mount_identity().patch_sha256 != ""
	elif mode == "reject_cached":
		report.passed = updater.active_content_version == updater.BASE_CONTENT_VERSION \
			and not FileAccess.file_exists("res://update_qa_marker.txt")
	else:
		var timeout := Time.get_ticks_msec() + 25000
		updater.check_now()
		var terminal := ["ready", "current", "error", "full_update"]
		if mode == "inspect_live": terminal.append("available")
		while Time.get_ticks_msec() < timeout and updater.state not in terminal:
			if updater.state == "available" and mode != "inspect_live": updater.begin_download()
			await create_timer(0.02).timeout
		var expected := OS.get_environment("UPDATE_QA_EXPECT")
		report.passed = updater.enabled and updater.state in expected.split(",")
		if expected == "ready":
			report.passed = report.passed and FileAccess.file_exists(updater._state_path) \
				and FileAccess.get_sha256(updater._patch_path(test_version)) == updater.available_manifest.patch.sha256
		report["status_text"] = updater.status_text
	report["enabled"] = updater.enabled
	report["state"] = updater.state
	report["version"] = updater.active_content_version
	var output := FileAccess.open(OS.get_environment("UPDATE_QA_REPORT"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("[update-transport] ", JSON.stringify(report))
	quit(0 if report.passed else 1)
