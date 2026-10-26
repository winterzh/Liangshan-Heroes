extends Node
## Synthetic naming/layout checks; no native Store transaction or SDK calls.
func _ready() -> void:
	run.call_deferred()

func run() -> void:
	# Await an idle frame before identity/native filesystem APIs or model setup.
	while Engine.is_in_physics_frame():
		await get_tree().process_frame
	var profile: String = OS.get_environment("SPM_PROFILE").replace("\\", "/").simplify_path()
	var safe: bool = profile.is_absolute_path() and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("SPM_MODE") == "protocol_model"
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	safe = safe and project.to_lower() == OS.get_environment("SPM_PROJECT").replace("\\", "/").trim_suffix("/").to_lower()
	if not safe:
		get_tree().quit(2)
		return
	var identity_script: Script = load("res://scripts/run_content_identity.gd")
	if identity_script == null or not identity_script.can_instantiate():
		push_error("PROTOCOL_IDENTITY_SCRIPT_INVALID")
		get_tree().quit(2)
		return
	var identity: Dictionary = identity_script.new().resolve_runtime_identity()
	if not identity.get("ok", false) or not identity.get("source_mode", false):
		get_tree().quit(2)
		return
	var path: String = OS.get_environment("SPM_WORKERS").replace("\\", "/").path_join("protocol_model.gd")
	if FileAccess.get_sha256(path) != OS.get_environment("SPM_MODEL_SHA256"):
		get_tree().quit(2)
		return
	var model_script: Script = load(path)
	if model_script == null or not model_script.can_instantiate():
		push_error("PROTOCOL_MODEL_SCRIPT_INVALID")
		get_tree().quit(2)
		return
	var model: RefCounted = model_script.new()
	var result: Dictionary = model.run_all()
	result.mode = "protocol_model"
	result.batch_nonce = OS.get_environment("SPM_NONCE")
	result.profile = OS.get_environment("SPM_PROFILE")
	result.pid = OS.get_process_id()
	result.model_sha256 = FileAccess.get_sha256(path)
	result.worker_sha256 = FileAccess.get_sha256(OS.get_environment("SPM_WORKERS").path_join("protocol_worker.gd"))
	result.candidate_manifest_sha256 = OS.get_environment("SPM_CANDIDATE_MANIFEST_SHA256")
	result.identity = {"content_version":identity.content_version, "engine_sha256":identity.engine_binary_sha256, "source_mode":true}
	result.failures = []
	for row: Dictionary in result.checks:
		print("PROTOCOL_MODEL ", "PASS " if row.passed else "FAIL ", row.label)
		if not row.passed:
			result.failures.append(row.label)
	result.passed = result.passed and result.failures.is_empty() and not result.checks.is_empty()
	result.synthetic_account_and_token = true
	var report: FileAccess = FileAccess.open(OS.get_environment("SPM_REPORT"), FileAccess.WRITE)
	if report == null:
		get_tree().quit(2)
		return
	report.store_string(JSON.stringify(result, "\t"))
	report.close()
	get_tree().quit(0 if result.passed else 1)
