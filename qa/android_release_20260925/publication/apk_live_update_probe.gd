extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if OS.get_user_data_dir() != OS.get_environment("LSH_APK_PROFILE") or not OS.get_user_data_dir().get_file().begins_with("LSH-android-test-"):
		push_error("Private APK profile required")
		quit(2)
		return
	var updater = root.get_node("AndroidUpdater")
	updater.check_now()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and updater.state not in ["current", "error", "available", "full_update"]:
		await create_timer(0.02).timeout
	var manifest: Dictionary = updater.available_manifest
	var passed: bool = updater.enabled and updater.state == "current" and updater.BASE_CONTENT_VERSION == "2.0" \
		and String(manifest.get("content_version", "")) == "2.0" and int(manifest.get("min_bootstrap", 0)) == 4 \
		and manifest.get("patch", "missing") == null and int(manifest.get("full_apk", {}).get("version_code", 0)) == 16 \
		and manifest.get("full_apk", {}).get("sha256", "") == "78a15c9e1e31b9fbcab2e09ab92f6bbbd6a62a1bcfef7e0896f9c19ab1c249c0" \
		and updater.run_content_mount_identity().patch_sha256 == ""
	print("[apk-live-update] ", JSON.stringify({"passed": passed, "state": updater.state,
		"base": updater.BASE_CONTENT_VERSION, "platform": updater.platform_id,
		"content_version": manifest.get("content_version", ""), "min_bootstrap": manifest.get("min_bootstrap", 0),
		"private_user_dir": OS.get_user_data_dir(), "native_android_test": false}))
	quit(0 if passed else 1)
