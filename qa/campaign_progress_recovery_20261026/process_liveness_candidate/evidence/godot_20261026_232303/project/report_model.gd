extends RefCounted
## Synthetic report validation only. No process/Store/SDK qualification; not yet run in Godot.

func run(oracle: Script) -> Dictionary:
	var nonce := "0123456789abcdef0123456789abcdef"
	var valid := {"code": "HANDLE_NONSIGNALED", "creation_filetime": "134000000000000000", "handle_opened": true,
		"nonce": nonce, "provider_pid": "1234", "query_utc_filetime": "134000000000000100", "schema": "windows_process_liveness_v1",
		"state": "alive", "target_pid": "5678", "wait_result": "258", "win32_error": "0"}
	var checks: Array = []
	_check(checks, "synthetic live handle", oracle.validate_report(JSON.stringify(valid), nonce, 5678, 1234).ok)
	var dead: Dictionary = valid.duplicate(true)
	dead.merge({"state": "dead", "code": "HANDLE_SIGNALED", "wait_result": "0"}, true)
	_check(checks, "synthetic signaled handle", oracle.validate_report(JSON.stringify(dead), nonce, 5678, 1234).ok)
	var absent: Dictionary = valid.duplicate(true)
	absent.merge({"state": "dead", "code": "PID_ABSENT_87", "handle_opened": false, "creation_filetime": "", "wait_result": "not_queried", "win32_error": "87"}, true)
	_check(checks, "synthetic absent nonzero PID", oracle.validate_report(JSON.stringify(absent), nonce, 5678, 1234).ok)
	var denied: Dictionary = absent.duplicate(true)
	denied.merge({"state": "unknown", "code": "OPEN_FAILED", "win32_error": "5"}, true)
	_check(checks, "synthetic access denied is unknown", oracle.validate_report(JSON.stringify(denied), nonce, 5678, 1234).ok)
	var mutations: Array = [
		["extra field", "extra", true], ["fractional PID", "target_pid", 5678.5], ["numeric PID", "target_pid", 5678],
		["other PID", "target_pid", "5679"], ["other child", "provider_pid", "1235"], ["wrong nonce", "nonce", "f".repeat(32)],
		["unknown schema", "schema", "future"], ["false death", "state", "dead"], ["missing creation", "creation_filetime", ""],
		["leading zero time", "creation_filetime", "0134"], ["overflow time", "creation_filetime", "18446744073709551616"],
		["fake wait", "wait_result", "0"], ["unexpected error", "win32_error", "5"], ["missing handle", "handle_opened", false]]
	for mutation in mutations:
		var changed: Dictionary = valid.duplicate(true)
		changed[mutation[1]] = mutation[2]
		_check(checks, "reject " + str(mutation[0]), not oracle.validate_report(JSON.stringify(changed), nonce, 5678, 1234).ok)
	_check(checks, "reject idle PID", not oracle.validate_report(JSON.stringify(absent), nonce, 0, 1234).ok)
	_check(checks, "reject trailing whitespace", not oracle.validate_report(JSON.stringify(valid) + "\n", nonce, 5678, 1234).ok)
	_check(checks, "reject duplicate keys", not oracle.validate_report(JSON.stringify(valid).trim_suffix("}") + ",\"state\":\"alive\"}", nonce, 5678, 1234).ok)
	_check(checks, "reject oversized", not oracle.validate_report("x".repeat(4097), nonce, 5678, 1234).ok)
	var good := true
	for item in checks: good = good and item.passed
	return {"schema": "process_liveness_report_model_v1", "ok": good, "checks": checks, "synthetic_only": true,
		"native_process_qualified": false, "store_recovery_qualified": false, "sdk_qualified": false}

func _check(checks: Array, name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})
