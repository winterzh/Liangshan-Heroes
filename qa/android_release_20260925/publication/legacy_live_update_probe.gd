extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if OS.get_user_data_dir() != OS.get_environment("LSH_APK_PROFILE") or not OS.get_user_data_dir().get_file().begins_with("LSH-android-test-"):
		push_error("Private APK profile required")
		quit(2)
		return
	var legacy_script = load(OS.get_environment("LSH_LEGACY_UPDATER"))
	var legacy = legacy_script.new()
	root.add_child(legacy)
	legacy.check_now()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and legacy.state not in ["current", "error", "available", "full_update"]:
		await create_timer(0.02).timeout
	var full: Dictionary = legacy.get_full_package()
	var passed: bool = legacy.enabled and legacy.state == "full_update" and legacy.BOOTSTRAP_VERSION == 3 \
		and legacy.PACKAGE_VERSION_NAME == "1.8" and String(full.get("version_name", "")) == "2.0" \
		and full.get("sha256", "") == "78a15c9e1e31b9fbcab2e09ab92f6bbbd6a62a1bcfef7e0896f9c19ab1c249c0"
	print("[legacy-live-update] ", JSON.stringify({"passed": passed, "state": legacy.state,
		"old_package": legacy.PACKAGE_VERSION_NAME, "bootstrap": legacy.BOOTSTRAP_VERSION,
		"full_version": full.get("version_name", ""), "full_url": full.get("url", ""),
		"native_android_test": false, "source": "v1.8:scripts/android_updater.gd, original bytes"}))
	legacy.queue_free()
	await process_frame
	quit(0 if passed else 1)
