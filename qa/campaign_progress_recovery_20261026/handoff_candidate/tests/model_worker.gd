extends Node
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var profile := OS.get_environment("MR_PROFILE").replace("\\","/").simplify_path()
	var safe := profile.is_absolute_path() and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty()
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and OS.get_environment(key).replace("\\","/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	var project := ProjectSettings.globalize_path("res://").replace("\\","/").trim_suffix("/")
	safe = safe and project.to_lower() == OS.get_environment("MR_PROJECT").replace("\\","/").to_lower()
	if not safe: get_tree().quit(2); return
	var identity: Dictionary = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if not identity.get("ok",false) or not identity.get("source_mode",false): get_tree().quit(2); return
	var path := OS.get_environment("MR_WORKERS").replace("\\","/").path_join("receipt_model.gd")
	var model_script: Script = load(path)
	if model_script == null or not model_script.can_instantiate():
		push_error("HANDOFF_MODEL_SCRIPT_INVALID")
		get_tree().quit(2)
		return
	var model: RefCounted = model_script.new()
	var result: Dictionary = model.run_all()
	result.mode = OS.get_environment("MR_MODE")
	result.batch_nonce = OS.get_environment("MR_NONCE")
	result.profile = OS.get_environment("MR_PROFILE")
	result.pid = OS.get_process_id()
	result.identity = {"content_version":identity.content_version,"engine_sha256":identity.engine_binary_sha256,"source_mode":true}
	result.failures = []
	for row in result.checks:
		print("HANDOFF_MODEL ","PASS " if row.passed else "FAIL ",row.label)
		if not row.passed: result.failures.append(row.label)
	result.passed = result.failures.is_empty()
	result.synthetic_account_and_token = true
	var report := FileAccess.open(OS.get_environment("MR_REPORT"),FileAccess.WRITE)
	if report == null: get_tree().quit(2); return
	report.store_string(JSON.stringify(result,"\t")); report.close()
	get_tree().quit(0 if result.passed else 1)
