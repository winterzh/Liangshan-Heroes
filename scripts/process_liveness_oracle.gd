extends RefCounted
## Independent candidate. All filesystem activity is confined to the configured private QA root.
## A caller MUST retain this instance across begin/poll/retry until the owned helper is terminal.

const SCHEMA := "windows_process_liveness_v1"
const FIELDS := ["code", "creation_filetime", "handle_opened", "nonce", "provider_pid", "query_utc_filetime", "schema", "state", "target_pid", "wait_result", "win32_error"]
const MAX_REPORT := 4096
const MAX_HELPER := 1048576
const TIMEOUT_MS := 3000
const HELPER_NAME := "ProcessLivenessProbe.exe"

var _helper := ""
var _helper_sha := ""
var _root := ""
var _target := 0
var _expected_creation := ""
var _provider_pid := 0
var _nonce := ""
var _directory := ""
var _started_ms := 0
var _deadline_ms := 0
var _pending := false
var _kill_attempted := false
var _cleanup_confirmed := true
var _result: Dictionary = {}

static func _decimal(value: Variant, maximum: String, allow_zero: bool = false) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty(): return false
	if value == "0": return allow_zero
	if value[0] == "0" or value.length() > maximum.length(): return false
	for character in value:
		if character < "0" or character > "9": return false
	return value.length() < maximum.length() or value <= maximum

static func _hex(value: Variant, length: int) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != length: return false
	for character in value:
		if not ((character >= "0" and character <= "9") or (character >= "a" and character <= "f")): return false
	return true

static func _invalid(code: String) -> Dictionary:
	return {"ok": false, "code": code}

static func validate_report(raw: String, expected_nonce: String, target_pid: int, provider_pid: int) -> Dictionary:
	if raw.is_empty() or raw.length() > MAX_REPORT: return _invalid("REPORT_SIZE")
	for byte in raw.to_utf8_buffer():
		if byte < 32 or byte > 126: return _invalid("REPORT_ENCODING")
	var parser := JSON.new()
	if parser.parse(raw) != OK or typeof(parser.data) != TYPE_DICTIONARY: return _invalid("REPORT_JSON")
	var row: Dictionary = parser.data
	if row.size() != FIELDS.size(): return _invalid("REPORT_FIELDS")
	for key in FIELDS:
		if not row.has(key): return _invalid("REPORT_FIELDS")
	# Reject duplicate keys, ignored text, alternative number types, escapes and noncanonical bytes.
	if JSON.stringify(row) != raw: return _invalid("REPORT_NONCANONICAL")
	for key in FIELDS:
		if key == "handle_opened":
			if typeof(row[key]) != TYPE_BOOL: return _invalid("REPORT_TYPE")
		elif typeof(row[key]) != TYPE_STRING: return _invalid("REPORT_TYPE")
	if row.schema != SCHEMA or not _hex(expected_nonce, 32) or row.nonce != expected_nonce: return _invalid("REPORT_SCOPE")
	if target_pid < 1 or target_pid > 2147483647 or provider_pid < 1 or provider_pid > 2147483647: return _invalid("REPORT_SCOPE")
	if row.target_pid != str(target_pid) or row.provider_pid != str(provider_pid): return _invalid("REPORT_PID")
	if not _decimal(row.query_utc_filetime, "9223372036854775807"): return _invalid("REPORT_TIME")
	if not _decimal(row.win32_error, "4294967295", true): return _invalid("REPORT_ERROR")
	if row.creation_filetime != "" and not _decimal(row.creation_filetime, "18446744073709551615"): return _invalid("REPORT_CREATION")
	if row.wait_result != "not_queried" and not _decimal(row.wait_result, "4294967295", true): return _invalid("REPORT_WAIT")
	if not row.handle_opened and (row.creation_filetime != "" or row.wait_result != "not_queried"): return _invalid("REPORT_HANDLE")
	var valid := false
	match row.code:
		"HANDLE_NONSIGNALED":
			valid = row.state == "alive" and row.handle_opened and row.creation_filetime != "" and row.wait_result == "258" and row.win32_error == "0"
		"HANDLE_SIGNALED":
			valid = row.state == "dead" and row.handle_opened and row.creation_filetime != "" and row.wait_result == "0" and row.win32_error == "0"
		"PID_ABSENT_87":
			valid = row.state == "dead" and not row.handle_opened and row.win32_error == "87"
		"OPEN_FAILED":
			valid = row.state == "unknown" and not row.handle_opened and row.win32_error != "87"
		"TIMES_FAILED", "TIMES_INVALID":
			valid = row.state == "unknown" and row.handle_opened and row.creation_filetime == "" and row.wait_result == "not_queried"
		"WAIT_FAILED":
			valid = row.state == "unknown" and row.handle_opened and row.creation_filetime != "" and row.wait_result == "4294967295"
		"WAIT_UNEXPECTED":
			valid = row.state == "unknown" and row.handle_opened and row.creation_filetime != "" and row.wait_result not in ["0", "258", "4294967295", "not_queried"]
		"QUERY_EXCEPTION":
			valid = row.state == "unknown"
		"CLOSE_FAILED":
			valid = row.state == "unknown" and row.handle_opened
	if not valid: return _invalid("REPORT_STATE_CONTRADICTION")
	return {"ok": true, "code": "OK", "record": row.duplicate(true)}

static func _file_digest(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var size := file.get_length()
	if size < 1 or size > MAX_HELPER:
		file.close(); return ""
	var bytes := file.get_buffer(size)
	var complete := bytes.size() == size and file.get_error() == OK and file.get_length() == size
	file.close()
	if not complete: return ""
	var digest := HashingContext.new()
	if digest.start(HashingContext.HASH_SHA256) != OK or digest.update(bytes) != OK: return ""
	return digest.finish().hex_encode()

static func guard_native_path(path: String, directory_leaf: bool) -> bool:
	# Godot Windows is_link tests all FILE_ATTRIBUTE_REPARSE_POINT, including junctions.
	# Reject unsupported path forms instead of normalizing away an unsafe parent.
	if OS.get_name() != "Windows": return false
	var clean := path.replace("\\", "/")
	if clean.length() < 3 or clean.substr(1, 2) != ":/" or clean.substr(0, 1).to_upper() < "A" or clean.substr(0, 1).to_upper() > "Z": return false
	if clean != clean.simplify_path() or ":" in clean.substr(3): return false
	var current := clean.substr(0, 3)
	if not DirAccess.dir_exists_absolute(current): return false
	var parts := clean.substr(3).split("/", false)
	for index in range(parts.size()):
		var parent := DirAccess.open(current)
		if parent == null or parent.is_link(parts[index]): return false
		current = current.path_join(parts[index])
		if index == parts.size() - 1 and not directory_leaf:
			if not FileAccess.file_exists(current): return false
		elif not DirAccess.dir_exists_absolute(current): return false
	return directory_leaf or not parts.is_empty()

func configure(helper_path: String, expected_sha256: String, private_root: String) -> Dictionary:
	if _pending or not _cleanup_confirmed: return _invalid("PROVIDER_STILL_OWNED")
	if OS.get_name() != "Windows": return _invalid("UNSUPPORTED_PLATFORM")
	if not helper_path.is_absolute_path() or helper_path.get_file() != HELPER_NAME or not _hex(expected_sha256, 64): return _invalid("HELPER_CONFIG")
	if not private_root.is_absolute_path() or private_root.begins_with("res:") or private_root.begins_with("user:"): return _invalid("PRIVATE_ROOT")
	if not guard_native_path(helper_path, false) or not guard_native_path(private_root, true): return _invalid("PATH_REPARSE_OR_MISSING")
	if _file_digest(helper_path) != expected_sha256: return _invalid("HELPER_SHA")
	if not DirAccess.dir_exists_absolute(private_root): return _invalid("PRIVATE_ROOT_MISSING")
	_helper = helper_path
	_helper_sha = expected_sha256
	_root = private_root.trim_suffix("/").trim_suffix("\\")
	return {"ok": true, "code": "CONFIGURED"}

func _envelope(state: String, code: String, evidence: Dictionary = {}) -> Dictionary:
	return {"state": state, "code": code, "target_pid": _target, "provider_pid": _provider_pid,
		"pending": _pending, "helper_cleanup_confirmed": _cleanup_confirmed,
		"started_ms": _started_ms, "observed_ms": Time.get_ticks_msec(), "helper_sha256": _helper_sha,
		"probe_directory": _directory, "evidence": evidence.duplicate(true)}

func _finish(state: String, code: String, evidence: Dictionary = {}) -> Dictionary:
	_pending = false
	_result = _envelope(state, code, evidence)
	return _result.duplicate(true)

func begin(target_pid: Variant, expected_creation_filetime: String = "", scope_deadline_ms: int = 0) -> Dictionary:
	# Repeated begin does not replace or forget a live child/proposal. Call poll on the same instance.
	if _pending or not _cleanup_confirmed:
		return _envelope("unknown", "PROVIDER_STILL_OWNED", {"requested_pid": str(target_pid)})
	_target = 0
	_provider_pid = 0
	_directory = ""
	_nonce = ""
	_result = {}
	_started_ms = Time.get_ticks_msec()
	_deadline_ms = _started_ms + TIMEOUT_MS
	if scope_deadline_ms > 0: _deadline_ms = mini(_deadline_ms, scope_deadline_ms)
	if _started_ms >= _deadline_ms: return _finish("unknown", "PROVIDER_SCOPE_TIMEOUT")
	if typeof(target_pid) != TYPE_INT or target_pid < 1 or target_pid > 2147483647: return _finish("unknown", "INVALID_PID")
	_target = target_pid
	if expected_creation_filetime != "" and not _decimal(expected_creation_filetime, "18446744073709551615"): return _finish("unknown", "INVALID_CREATION")
	_expected_creation = expected_creation_filetime
	if OS.get_name() != "Windows": return _finish("unknown", "UNSUPPORTED_PLATFORM")
	if not guard_native_path(_helper, false) or not guard_native_path(_root, true): return _finish("unknown", "PATH_REPARSE_OR_MISSING")
	if _helper.is_empty() or _file_digest(_helper) != _helper_sha: return _finish("unknown", "HELPER_SHA")
	var random := Crypto.new().generate_random_bytes(16)
	if random.size() != 16: return _finish("unknown", "NONCE_UNAVAILABLE")
	_nonce = random.hex_encode()
	_directory = _root.path_join(_nonce)
	# mkdir is exclusive: any existing directory/file collision fails without changing its contents.
	if DirAccess.make_dir_absolute(_directory) != OK: return _finish("unknown", "PROBE_DIRECTORY_COLLISION")
	if not guard_native_path(_directory, true) or not guard_native_path(_helper, false): return _finish("unknown", "PATH_REPARSE_OR_MISSING")
	if Time.get_ticks_msec() >= _deadline_ms: return _finish("unknown", "PROVIDER_SCOPE_TIMEOUT")
	_kill_attempted = false
	_provider_pid = OS.create_process(_helper, PackedStringArray([str(_target), _nonce, _directory.replace("/", "\\")]), false)
	if _provider_pid <= 0: return _finish("unknown", "PROVIDER_START_FAILED")
	_cleanup_confirmed = false
	_pending = true
	return _envelope("unknown", "PENDING")

func poll() -> Dictionary:
	if not _pending:
		if not _result.is_empty(): return _result.duplicate(true)
		return _envelope("unknown", "NO_QUERY")
	# This PID came from this very OS.create_process call, unlike an external lock owner PID.
	var exit_code := OS.get_process_exit_code(_provider_pid)
	if Time.get_ticks_msec() >= _deadline_ms: return cancel("PROVIDER_SCOPE_TIMEOUT")
	if exit_code >= 0:
		_cleanup_confirmed = true
		if exit_code != 0: return _finish("unknown", "PROVIDER_EXIT", {"exit_code": exit_code})
		if not guard_native_path(_helper, false) or not guard_native_path(_directory, true): return _finish("unknown", "PATH_REPARSE_OR_MISSING")
		if _file_digest(_helper) != _helper_sha: return _finish("unknown", "HELPER_CHANGED")
		var final_path := _directory.path_join("result.json")
		if not guard_native_path(final_path, false): return _finish("unknown", "REPORT_REPARSE_OR_MISSING")
		if FileAccess.file_exists(_directory.path_join("pending.json")): return _finish("unknown", "PROVIDER_PENDING_FILE")
		var file := FileAccess.open(final_path, FileAccess.READ)
		if file == null: return _finish("unknown", "REPORT_MISSING")
		var size := file.get_length()
		if size < 1 or size > MAX_REPORT:
			file.close(); return _finish("unknown", "REPORT_SIZE")
		var bytes := file.get_buffer(size)
		var complete := bytes.size() == size and file.get_error() == OK and file.get_length() == size
		file.close()
		if not complete: return _finish("unknown", "REPORT_READ")
		for byte in bytes:
			if byte < 32 or byte > 126: return _finish("unknown", "REPORT_ENCODING")
		var validated := validate_report(bytes.get_string_from_ascii(), _nonce, _target, _provider_pid)
		if not validated.ok: return _finish("unknown", validated.code)
		if Time.get_ticks_msec() >= _deadline_ms: return _finish("unknown", "PROVIDER_SCOPE_TIMEOUT")
		var row: Dictionary = validated.record
		if _expected_creation != "" and row.handle_opened and row.creation_filetime != _expected_creation:
			return _finish("unknown", "PID_IDENTITY_MISMATCH", row)
		return _finish(row.state, row.code, row)
	return _envelope("unknown", "PENDING")

func cancel(reason: String = "PROVIDER_CANCELLED") -> Dictionary:
	if not _pending:
		if not _result.is_empty(): return _result.duplicate(true)
		return _envelope("unknown", "NO_QUERY")
	var exit_code := OS.get_process_exit_code(_provider_pid)
	if exit_code >= 0:
		_cleanup_confirmed = true
		return _finish("unknown", reason, {"exit_code": exit_code})
	# kill removes the owned map entry, even if it fails. Exactly one attempt, no raw-PID retry.
	if not _kill_attempted:
		_kill_attempted = true
		var kill_error := OS.kill(_provider_pid)
		return _finish("unknown", reason, {"kill_requested_once": true, "kill_error": kill_error, "cleanup_unconfirmed": true})
	return _finish("unknown", reason, {"cleanup_unconfirmed": true})
