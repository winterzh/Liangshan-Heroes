extends SceneTree
## Run only inside the private project made by run_update_transport_qa.py.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var mode := OS.get_environment("UPDATE_QA_MODE")
	var report := {"mode": mode, "user_dir": OS.get_user_data_dir(), "passed": false}
	var expected_profile := OS.get_environment("UPDATE_QA_PROFILE")
	var expected_project := OS.get_environment("UPDATE_QA_PROJECT")
	if OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1" \
		or not expected_profile.begins_with("LSH-update-qa-") or OS.get_user_data_dir().get_file() != expected_profile \
		or not expected_project.is_absolute_path() or ProjectSettings.globalize_path("res://").trim_suffix("/") != expected_project \
		or not FileAccess.file_exists("res://override.cfg") or DirAccess.dir_exists_absolute(expected_project.path_join(".git")) \
		or OS.get_environment("UPDATE_QA_REPORT").get_base_dir() != OS.get_environment("UPDATE_QA_OUT"):
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
	elif mode == "disabled":
		# Re-create the bootstrap with old desktop and Android caches present.
		# A platform override must not even remove download/state temporary files.
		var cache_hashes := {}
		for directory in ["user://content_updates/windows", "user://content_updates/macos", "user://android_updates"]:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
			for filename in ["state.json", "state.json.tmp", "download.pck.tmp"]:
				var path: String = directory.path_join(filename)
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_string("disabled-cache-sentinel")
				file.close()
				cache_hashes[path] = FileAccess.get_sha256(path)
		var second = updater.get_script().new()
		root.add_child(second)
		second.check_now()
		second.begin_download()
		await process_frame
		report.passed = not updater.enabled and updater._request == null and updater._update_dir == "" \
			and not second.enabled and second._request == null and second._update_dir == "" and second._phase == "" \
			and updater.run_content_mount_identity().complete and second.run_content_mount_identity().patch_sha256 == ""
		for path in cache_hashes:
			report.passed = report.passed and FileAccess.get_sha256(path) == cache_hashes[path]
		# Remove only this private fixture's sentinels before the next Android run.
		# Invalid JSON here would otherwise pollute the unrelated live/patch tests.
		for path in cache_hashes:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		# Explicit policy table covers exported runtimes unavailable on this host.
		for target in ["android", "windows", "macos", ""]:
			for private_test in [false, true]:
				report.passed = report.passed and not updater._platform_updates_allowed(false, false, private_test, target)
		report.passed = report.passed and updater._platform_updates_allowed(true, false, false, "android") \
			and not updater._platform_updates_allowed(false, true, false, "android") \
			and updater._platform_updates_allowed(false, true, true, "android")
		report["cache_files_unchanged"] = cache_hashes.size()
		second.free()
	elif mode == "mount":
		report.passed = updater.enabled and updater.active_content_version == test_version \
			and FileAccess.get_file_as_string("res://update_qa_marker.txt") == "isolated-patch-loaded" \
			and updater.run_content_mount_identity().patch_sha256 != ""
	elif mode == "reject_cached":
		report.passed = updater.enabled and updater.active_content_version == updater.BASE_CONTENT_VERSION \
			and not FileAccess.file_exists("res://update_qa_marker.txt") and updater.run_content_mount_identity().patch_sha256 == ""
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
		var expected_full := OS.get_environment("UPDATE_QA_FULL_VERSION")
		if expected_full != "":
			report["full_version"] = updater._full_package_version(updater.get_full_package(), "")
			report.passed = report.passed and updater.state == "full_update" and report.full_version == expected_full \
				and not FileAccess.file_exists("res://update_qa_marker.txt")
		report["status_text"] = updater.status_text
	report["enabled"] = updater.enabled
	report["state"] = updater.state
	report["version"] = updater.active_content_version
	report["package_version"] = updater.PACKAGE_VERSION_NAME
	report["package_code"] = updater.PACKAGE_VERSION_CODE
	report["bootstrap"] = updater.BOOTSTRAP_VERSION
	var output := FileAccess.open(OS.get_environment("UPDATE_QA_REPORT"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("[update-transport] ", JSON.stringify(report))
	quit(0 if report.passed else 1)
