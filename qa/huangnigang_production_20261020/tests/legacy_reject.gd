extends "base.gd"
## Reject genuine old three-target files without conversion or identity rewrites.
func inventory() -> Dictionary:
	var directory := OS.get_user_data_dir().path_join("hg_legacy3")
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	if not directory.replace("\\", "/").to_lower().begins_with(profile.to_lower() + "/"): return {}
	var result: Dictionary = {}
	var pending: Array[String] = [""]
	while not pending.is_empty():
		var relative: String = pending.pop_back()
		var opened := DirAccess.open(directory.path_join(relative))
		if opened == null: return {}
		for name in opened.get_directories():
			if opened.is_link(name): return {}
			pending.append(relative.path_join(name))
		for name in opened.get_files():
			if opened.is_link(name) or name.get_extension() != "json": return {}
			var item := relative.path_join(name)
			result[item] = FileAccess.get_sha256(directory.path_join(item))
	return result

func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): report(); return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HG_LEGACY_EXPECTED")))
	check(expected.get("passed", false) and expected.get("profile", "") == "campaign_level1_v1" and expected.get("load_ids", []).size() == 3,
		"fixture was genuinely saved by real original three-target world")
	var before := inventory()
	var expected_files: Dictionary = {}
	for item in expected.get("copied_fixture_files", []): expected_files[item.path] = item.sha256
	check(before.size() == 2 and before == expected_files, "all genuine legacy slot and lifecycle bytes match original producer")
	if not failures.is_empty(): report(); return
	var pack: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(pack.get("ok", false), "current production runtime prepares normally")
	if not failures.is_empty(): report(); return
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	await get_tree().process_frame
	get_tree().paused = true
	var session: Variant = load("res://scripts/run_world_session.gd").new(trusted, pack.runtime, "user://hg_legacy3/v1")
	var prepared: Dictionary = session.prepare_restore(menu)
	check(not prepared.get("ok", true), "actual current Session refuses genuine incompatible old three-target world")
	session.dispose()
	await get_tree().process_frame
	var after := inventory()
	check(after == before, "all genuine old slot and lifecycle paths and hashes unchanged after refusal")
	check(current_scene == menu and is_instance_valid(menu), "rejection leaves actual menu installed")
	report({"scope": "Genuine old three-target save refused and preserved; content/engine/profile may all differ",
		"actual_prepare_result": prepared, "legacy_files_before": before, "legacy_files_after": after,
		"migration_implemented": false, "isolated_schema_only_test": false, "ordinary_player_continue_entry_tested": false})
