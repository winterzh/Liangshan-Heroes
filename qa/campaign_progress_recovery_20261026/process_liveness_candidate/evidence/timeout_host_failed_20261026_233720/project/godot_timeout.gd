extends SceneTree
## Independent timeout fixture. Never loads a game, Store, or real Win32 query helper.
var checks: Array = []
var observed: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> bool:
	checks.append({"passed":value, "label":label})
	print("PROCESS_TIMEOUT ", "PASS " if value else "FAIL ", label)
	return value

func publish(name: String, value: Dictionary) -> bool:
	var path: String = OS.get_environment("PT_OUTPUT").path_join(name)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".pending"): return false
	var file := FileAccess.open(path + ".pending", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value)); file.flush()
	var good: bool = file.get_error() == OK
	file.close()
	return good and DirAccess.rename_absolute(path + ".pending", path) == OK

func run() -> void:
	var oracle_path: String = OS.get_environment("PT_ORACLE")
	if not check(FileAccess.get_sha256(oracle_path) == OS.get_environment("PT_ORACLE_SHA"), "unchanged v1 oracle source bytes"): finish(); return
	var script: Script = load(oracle_path)
	if not check(script != null and script.can_instantiate(), "unchanged v1 oracle compiles"): finish(); return
	var oracle: RefCounted = script.new()
	var target: int = int(OS.get_environment("PT_TARGET"))
	var helper: String = OS.get_environment("PT_HELPER")
	var digest: String = OS.get_environment("PT_HELPER_SHA")
	var probe_root: String = OS.get_environment("PT_PROBES")
	if not check(target > 0 and target != OS.get_process_id(), "target is an external host-owned process"): finish(); return
	if not check(oracle.configure(helper, digest, probe_root).get("ok", false), "real hanging fixture SHA configures"): finish(); return
	var started: Dictionary = oracle.begin(target)
	observed["started"] = started.duplicate(true)
	if not check(started.pending and started.provider_pid > 0 and started.provider_pid != target, "real distinct owned helper starts"): finish(); return
	if not check(publish("started.json", {"schema":"process_timeout_started_v1", "nonce":OS.get_environment("PT_NONCE"),
		"godot_pid":OS.get_process_id(), "target_pid":target, "provider_pid":started.provider_pid, "oracle":started}), "publish actual provider PID atomically for host handle binding"): finish(); return
	var result: Dictionary = started
	var deadline: int = Time.get_ticks_msec() + 6000
	while result.get("pending", false) and Time.get_ticks_msec() < deadline:
		await process_frame
		result = oracle.poll()
	observed["timeout"] = result.duplicate(true)
	check(result.state == "unknown" and result.code == "PROVIDER_TIMEOUT" and not result.pending, "real v1 deadline returns terminal unknown timeout")
	check(result.observed_ms - result.started_ms >= script.TIMEOUT_MS, "real configured three-second deadline elapsed")
	check(result.provider_pid == started.provider_pid and result.target_pid == target, "timeout retains original helper and target identities")
	check(not result.helper_cleanup_confirmed and result.evidence.get("cleanup_unconfirmed", false), "oracle does not invent post-kill cleanup confirmation")
	check(result.evidence.get("kill_requested_once", false) and result.evidence.get("kill_error", -1) == OK, "one actual owned-helper kill request succeeded")
	for index: int in range(4):
		await process_frame
		check(oracle.poll() == result, "repeated timeout poll is stable and non-consuming %d" % index)
	var refused: Dictionary = oracle.begin(target)
	observed["reentry"] = refused.duplicate(true)
	check(refused.state == "unknown" and refused.code == "PROVIDER_STILL_OWNED" and refused.provider_pid == started.provider_pid \
		and not refused.helper_cleanup_confirmed, "same instance cannot bypass quarantined child by begin")
	var config: Dictionary = oracle.configure(helper, digest, probe_root)
	observed["reconfigure"] = config.duplicate(true)
	check(not config.ok and config.code == "PROVIDER_STILL_OWNED", "same instance cannot bypass quarantine by configure")
	check(oracle.poll() == result, "refused begin and configure preserve original timeout result")
	check(not FileAccess.file_exists(started.probe_directory.path_join("result.json")) \
		and not FileAccess.file_exists(started.probe_directory.path_join("pending.json")), "sleep-only fixture produced no observation report")
	finish()

func finish() -> void:
	var good: bool = not checks.is_empty()
	for row: Dictionary in checks: good = good and row.passed
	var report := {"schema":"process_liveness_godot_timeout_v1", "passed":good, "checks":checks, "observed":observed,
		"pid":OS.get_process_id(), "nonce":OS.get_environment("PT_NONCE"), "fixture_kind":"sleep_only_test_helper",
		"timeout_control_qualified":good, "real_win32_helper_hang_qualified":false, "store_recovery_qualified":false,
		"gameplay_qualified":false, "production_integrated":false}
	var saved: bool = publish("report.json", report)
	quit(0 if good and saved else 1)
