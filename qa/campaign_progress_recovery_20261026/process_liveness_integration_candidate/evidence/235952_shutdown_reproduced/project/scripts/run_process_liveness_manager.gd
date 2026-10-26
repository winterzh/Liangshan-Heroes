extends RefCounted
## Process-owned, synchronous recovery bridge. No SceneTree pumping or callbacks.
## Candidate only: metadata retains the oracle even after every temporary Store is freed.

const Oracle = preload("res://scripts/process_liveness_oracle.gd")
const SCRIPT_PATH := "res://scripts/run_process_liveness_manager.gd"
const META_KEY := &"_lh_process_liveness_manager_v2"
const SCHEMA := "process_liveness_manager_v2"
const HELPER_PATH := "res://addons/process_liveness/windows/ProcessLivenessProbe.exe"
const HELPER_SHA := "012354b1cf0376712f97e19362d91b2ef7f51775c6797c862c513df1e2f1936c"
const PRIVATE_ROOT := "user://process_liveness/v2"
const BUDGET_MS := 3000
const POLL_MS := 5

var _schema := SCHEMA
var _process_pid := OS.get_process_id()
var _configuration := {"helper_path": HELPER_PATH, "helper_sha256": HELPER_SHA, "private_root": PRIVATE_ROOT, "budget_ms": BUDGET_MS}
var _oracle: RefCounted
var _quarantine: Dictionary = {}
var _scopes: Dictionary = {}
var _serial := 0
var _in_query := false

static func _bad(code: String, restart := false, detail: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "retryable": not restart, "unsafe": false,
		"restart_required": restart, "liveness_detail": detail.duplicate(true)}

static func _instance() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return _bad("PROCESS_LIVENESS_THREAD")
	var script: Script = load(SCRIPT_PATH)
	if script == null or not script.can_instantiate(): return _bad("PROCESS_LIVENESS_MANAGER_SCRIPT", true)
	var manager: Variant
	if Engine.has_meta(META_KEY):
		manager = Engine.get_meta(META_KEY)
		if not manager is RefCounted or not is_instance_valid(manager) or manager.get_script() != script:
			return _bad("PROCESS_LIVENESS_MANAGER_IDENTITY", true)
		if manager._schema != SCHEMA or manager._process_pid != OS.get_process_id() or manager._configuration != {
			"helper_path": HELPER_PATH, "helper_sha256": HELPER_SHA, "private_root": PRIVATE_ROOT, "budget_ms": BUDGET_MS}:
			return _bad("PROCESS_LIVENESS_MANAGER_CONFIG", true)
	else:
		manager = script.new()
		Engine.set_meta(META_KEY, manager)
	return {"ok": true, "manager": manager}

static func open_scope(binding: String) -> Dictionary:
	var found := _instance()
	if not found.ok: return found
	return found.manager._open_scope(binding)

static func close_scope(scope_id: int) -> Dictionary:
	var found := _instance()
	if not found.ok: return found
	return found.manager._close_scope(scope_id)

static func query_dead(scope_id: int, pid: int, binding_sha256: String, phase: String) -> Dictionary:
	var found := _instance()
	if not found.ok: return found
	return found.manager._query_dead(scope_id, pid, binding_sha256, phase)

static func check_budget(scope_id: int) -> Dictionary:
	var found := _instance()
	if not found.ok: return found
	return found.manager._check_budget(scope_id)

static func status() -> Dictionary:
	var found := _instance()
	if not found.ok: return found
	return {"ok": true, "schema": SCHEMA, "process_pid": found.manager._process_pid,
		"scope_count": found.manager._scopes.size(), "in_query": found.manager._in_query,
		"quarantined": not found.manager._quarantine.is_empty(), "quarantine": found.manager._quarantine.duplicate(true)}

func _open_scope(binding: String) -> Dictionary:
	if _in_query: return _bad("PROCESS_LIVENESS_REENTRANT")
	if binding.is_empty(): return _bad("PROCESS_LIVENESS_SCOPE")
	_serial += 1
	var deadline := Time.get_ticks_msec() + BUDGET_MS
	_scopes[_serial] = {"binding": binding, "deadline_ms": deadline, "results": {}}
	return {"ok": true, "scope_id": _serial, "deadline_ms": deadline}

func _close_scope(scope_id: int) -> Dictionary:
	if _in_query: return _bad("PROCESS_LIVENESS_REENTRANT")
	if not _scopes.has(scope_id): return _bad("PROCESS_LIVENESS_SCOPE")
	_scopes.erase(scope_id)
	# Never erase/reset the oracle or quarantine while forgetting a temporary Store.
	return {"ok": true}

func _check_budget(scope_id: int) -> Dictionary:
	if not _scopes.has(scope_id): return _bad("PROCESS_LIVENESS_SCOPE")
	if Time.get_ticks_msec() >= int(_scopes[scope_id].deadline_ms): return _bad("PROCESS_LIVENESS_TIMEOUT")
	return {"ok": true}

func _prepare_provider() -> Dictionary:
	if OS.get_name() != "Windows": return _bad("PROCESS_LIVENESS_UNSUPPORTED")
	var helper := ProjectSettings.globalize_path(HELPER_PATH).replace("\\", "/")
	var boundary := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	if not Oracle.guard_native_path(helper, false) or not Oracle.guard_native_path(boundary, true):
		return _bad("PROCESS_LIVENESS_PATH")
	# Only the fixed private root is created. Every existing ancestor is checked before and after.
	var current := boundary
	for leaf in ["process_liveness", "v2"]:
		if not Oracle.guard_native_path(current, true): return _bad("PROCESS_LIVENESS_PATH")
		var next: String = current.path_join(leaf)
		if not DirAccess.dir_exists_absolute(next):
			if FileAccess.file_exists(next) or DirAccess.make_dir_absolute(next) != OK: return _bad("PROCESS_LIVENESS_PRIVATE_DIRECTORY")
		if not Oracle.guard_native_path(next, true): return _bad("PROCESS_LIVENESS_PATH")
		current = next
	if current != ProjectSettings.globalize_path(PRIVATE_ROOT).replace("\\", "/"): return _bad("PROCESS_LIVENESS_PRIVATE_SCOPE")
	if _oracle == null: _oracle = Oracle.new()
	var configured: Dictionary = _oracle.configure(helper, HELPER_SHA, current)
	if not configured.ok: return _bad("PROCESS_LIVENESS_PROVIDER_CONFIG", false, configured)
	return {"ok": true}

func _query_dead(scope_id: int, pid: int, binding_sha256: String, phase: String) -> Dictionary:
	if _in_query: return _bad("PROCESS_LIVENESS_REENTRANT")
	if not _quarantine.is_empty(): return _bad("PROCESS_LIVENESS_QUARANTINED", true, _quarantine)
	var budget := _check_budget(scope_id)
	if not budget.ok: return budget
	if pid < 1 or pid > 2147483647 or not Oracle._hex(binding_sha256, 64) or phase not in ["inspect", "claim"]:
		return _bad("PROCESS_LIVENESS_QUERY_SCOPE")
	var scope: Dictionary = _scopes[scope_id]
	var key := phase + ":" + binding_sha256 + ":" + str(pid)
	# Results are immutable/non-consuming within this logical operation only.
	if scope.results.has(key): return scope.results[key].duplicate(true)
	_in_query = true
	var result := _drive_query(scope_id, pid)
	_in_query = false
	scope.results[key] = result.duplicate(true)
	return result

func _drive_query(scope_id: int, pid: int) -> Dictionary:
	var prepared := _prepare_provider()
	if not prepared.ok: return prepared
	var budget := _check_budget(scope_id)
	if not budget.ok: return budget
	var deadline: int = _scopes[scope_id].deadline_ms
	var observed: Dictionary = _oracle.begin(pid, "", deadline)
	while true:
		if Time.get_ticks_msec() >= deadline:
			if observed.get("pending", false): observed = _oracle.cancel("PROVIDER_SCOPE_TIMEOUT")
			_retain_quarantine(observed)
			return _bad("PROCESS_LIVENESS_TIMEOUT", not _quarantine.is_empty(), observed)
		if not observed.get("pending", false): break
		observed = _oracle.poll()
		# No event loop, SceneTree, deferred callbacks, or caller code is pumped while waiting.
		if observed.get("pending", false):
			var remaining := deadline - Time.get_ticks_msec()
			if remaining > 0: OS.delay_msec(mini(POLL_MS, remaining))
	_retain_quarantine(observed)
	if not _quarantine.is_empty(): return _bad("PROCESS_LIVENESS_QUARANTINED", true, observed)
	if Time.get_ticks_msec() >= deadline: return _bad("PROCESS_LIVENESS_TIMEOUT", false, observed)
	match observed.get("state", "unknown"):
		"dead": return {"ok": true, "code": "PROCESS_CONFIRMED_DEAD", "pid": pid, "observation": observed.duplicate(true)}
		"alive": return _bad("WRITER_ALIVE", false, observed)
	return _bad("PROCESS_LIVENESS_UNKNOWN", false, observed)

func _retain_quarantine(observed: Dictionary) -> void:
	if not bool(observed.get("helper_cleanup_confirmed", true)):
		_quarantine = observed.duplicate(true)
