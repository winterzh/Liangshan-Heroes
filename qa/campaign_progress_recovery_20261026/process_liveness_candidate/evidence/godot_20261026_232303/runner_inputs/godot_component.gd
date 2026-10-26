extends SceneTree
## Component evidence only; this minimal project never loads a Store or game.
var checks: Array = []
var queries: Array = []
var oracle_script: Script

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> bool:
	checks.append({"passed": value, "label": label})
	print("PROCESS_COMPONENT ", "PASS " if value else "FAIL ", label)
	return value

func query(oracle: RefCounted, target: int, expected: String, creation := "") -> Dictionary:
	var result: Dictionary = oracle.begin(target, creation)
	if not check(result.get("pending", false) and result.target_pid == target, "query starts its own helper for " + expected): return result
	var provider: int = result.provider_pid
	var refused: Dictionary = oracle.begin(target)
	check(refused.code == "PROVIDER_STILL_OWNED" and refused.provider_pid == provider, "repeated begin preserves original owned helper")
	var deadline: int = Time.get_ticks_msec() + 4500
	while result.get("pending", false) and Time.get_ticks_msec() < deadline:
		await process_frame
		result = oracle.poll()
	check(not result.get("pending", true) and result.get("helper_cleanup_confirmed", false), "normal helper terminal is confirmed")
	check(result.get("state") == expected, "actual query yields " + expected)
	check(result.get("target_pid") == target and result.get("provider_pid") == provider, "result retains target and actual child PID")
	check(oracle.poll() == result, "terminal poll is non-consuming and stable")
	queries.append(result.duplicate(true))
	return result

func run() -> void:
	var oracle_path: String = OS.get_environment("PL_ORACLE")
	var model_path: String = OS.get_environment("PL_MODEL")
	if not check(FileAccess.get_sha256(oracle_path) == OS.get_environment("PL_ORACLE_SHA") \
		and FileAccess.get_sha256(model_path) == OS.get_environment("PL_MODEL_SHA"), "copied candidate and model source hashes match"): finish({}); return
	oracle_script = load(oracle_path)
	var model: Script = load(model_path)
	if not check(oracle_script != null and oracle_script.can_instantiate() and model != null and model.can_instantiate(), "candidate and model compile"): finish({}); return
	var model_report: Dictionary = model.new().run(oracle_script)
	check(model_report.get("ok", false) and model_report.checks.size() == 22, "all 22 strict report model cases pass")
	var fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PL_FIXTURES")))
	if not check(typeof(fixtures) == TYPE_DICTIONARY and fixtures.nonce == OS.get_environment("PL_NONCE"), "host fixture nonce matches"): finish(model_report); return
	var oracle: RefCounted = oracle_script.new()
	if not check(oracle.configure(OS.get_environment("PL_HELPER"), OS.get_environment("PL_HELPER_SHA"), OS.get_environment("PL_PROBES")).get("ok", false), "exact compiled helper configures"): finish(model_report); return
	for target: Dictionary in fixtures.targets:
		var result: Dictionary = await query(oracle, int(target.pid), str(target.expected))
		check(result.get("code") == target.code, "actual native result code: " + str(target.label))
		if result.get("evidence", {}).get("handle_opened", false):
			check(result.evidence.creation_filetime == target.creation_filetime, "held target creation FILETIME matches host")
	var live: Dictionary = fixtures.targets[0]
	var mismatch: Dictionary = await query(oracle, int(live.pid), "unknown", str(int(live.creation_filetime) + 1))
	check(mismatch.get("code") == "PID_IDENTITY_MISMATCH", "different creation identity never becomes dead")
	for invalid: Variant in [0, -1, 1.5, "12", 2147483648]:
		var result: Dictionary = oracle.begin(invalid)
		check(result.state == "unknown" and result.code == "INVALID_PID" and not result.pending and result.provider_pid == 0, "invalid PID starts no helper: " + str(invalid))
	var unconfigured: RefCounted = oracle_script.new()
	var refused: Dictionary = unconfigured.configure(OS.get_environment("PL_HELPER"), "0".repeat(64), OS.get_environment("PL_PROBES"))
	check(not refused.ok and refused.code == "HELPER_SHA", "unmatched helper bytes are refused")
	var unknown: Dictionary = unconfigured.begin(int(live.pid))
	check(unknown.state == "unknown" and unknown.code == "HELPER_SHA" and unknown.provider_pid == 0, "unconfigured helper cannot produce a death decision")
	finish(model_report)

func finish(model_report: Dictionary) -> void:
	var good := not checks.is_empty()
	for row: Dictionary in checks: good = good and row.passed
	var report := {"schema": "process_liveness_godot_component_v1", "passed": good, "checks": checks,
		"model": model_report, "queries": queries, "pid": OS.get_process_id(), "nonce": OS.get_environment("PL_NONCE"),
		"engine": Engine.get_version_info(), "store_recovery_qualified": false, "gameplay_qualified": false,
		"timeout_path_qualified": false, "production_integrated": false}
	var file := FileAccess.open(OS.get_environment("PL_REPORT"), FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(report, "\t")); file.flush(); file.close()
	quit(0 if good else 1)
