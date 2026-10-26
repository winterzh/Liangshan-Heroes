extends Node
const Provider := preload("res://scripts/run_content_identity.gd")
const ReceiptCase := preload("receipt_case.gd")
const SessionCase := preload("session_case.gd")
var checks: Array = []
var results: Dictionary = {}
var trusted: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks.append({"label":label, "passed":value})
	return value

func run() -> void:
	var profile := OS.get_environment("RG_PROFILE").replace("\\","/").simplify_path()
	var safe: bool = profile.is_absolute_path() and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("RG_EXPECT") in ["defects","fixed"]
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and OS.get_environment(key).replace("\\","/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/")
	safe = safe and ProjectSettings.globalize_path("res://").replace("\\","/").trim_suffix("/").to_lower() == OS.get_environment("RG_PROJECT").replace("\\","/").trim_suffix("/").to_lower()
	if not check(safe, "four isolated profile roots and expected mode"): finish(); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok",false) and trusted.get("save_eligible",false) and trusted.get("source_mode",false), "actual source candidate identity"): finish(); return
	for frame in range(4):
		if not Engine.is_in_physics_frame(): break
		await get_tree().process_frame
	if not check(not Engine.is_in_physics_frame(), "Session operations execute outside physics"): finish(); return
	results["correction_remote_floor"] = ReceiptCase.run_case()
	results["session_retained_checkpoint"] = SessionCase.run_case()
	for name in results:
		var row: Dictionary = results[name]
		check(row.get("setup_ok",false), name + " setup and declared transitions")
		if OS.get_environment("RG_EXPECT") == "defects":
			check(row.get("bug_reproduced",false) and not row.get("fixed_behavior_ok",true), name + " existing defect reproduced")
		else:
			check(not row.get("bug_reproduced",true) and row.get("fixed_behavior_ok",false), name + " fixed behavior verified")
	var after: Dictionary = Provider.new().resolve_runtime_identity()
	check(after == trusted, "same actual source and engine after pure/synthetic cases")
	finish()

func finish() -> void:
	var passed: bool = not checks.is_empty() and checks.all(func(row): return row.passed)
	var fixed: bool = passed and OS.get_environment("RG_EXPECT") == "fixed"
	var report := {"schema":"handoff_known_regressions_v1", "mode":"model_regressions", "passed":passed,
		"expected":OS.get_environment("RG_EXPECT"), "candidate_regressions_passed":fixed,
		"defect_reproduction_complete":passed and not fixed, "batch_nonce":OS.get_environment("RG_NONCE"),
		"pid":OS.get_process_id(), "profile":OS.get_environment("RG_PROFILE"), "trusted_identity":trusted,
		"checks":checks, "failures":checks.filter(func(row): return not row.passed), "cases":results,
		"acceptance_scope":"real Receipt reducer plus real LocalSession with synthetic in-memory Ledger",
		"filesystem_or_sdk_exercised":false, "original_release_gui_tested":false, "human_acceptance":false,
		"performance_acceptance":false, "published":false, "candidate_runtime_qualified":false}
	var file := FileAccess.open(OS.get_environment("RG_REPORT"),FileAccess.WRITE)
	if file == null: push_error("REGRESSION_REPORT_WRITE"); get_tree().quit(2); return
	file.store_string(JSON.stringify(report,"\t")); file.flush(); file.close()
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	print("HANDOFF_REGRESSIONS ",OS.get_environment("RG_EXPECT")," ",passed)
	get_tree().quit(0 if passed else 1)
