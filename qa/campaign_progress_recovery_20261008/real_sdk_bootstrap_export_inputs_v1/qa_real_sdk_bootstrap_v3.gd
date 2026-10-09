extends Node
## Normal exported scene only. No SDK substitution or policy bypass.
## Autoloads run normally and may synchronize the real account before this node.
const Provider := preload("res://scripts/run_content_identity.gd")
const APP_ID := 5088120
const SCHEMA := "campaign_real_sdk_bootstrap_v3"
var checks: Array[String] = []
var failures: Array[String] = []
var descriptor: Dictionary = {}
var descriptor_sha := ""
var identity: Dictionary = {}
var owner := ""
var started := 0
var private_profile_verified := false
var report_path := ""
var windows_environment: Dictionary = {}
var initial_snapshot: Dictionary = {}
var final_snapshot: Dictionary = {}

func _hex_nonce(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 32: return false
	for ch in value.to_utf8_buffer():
		if not (ch >= 48 and ch <= 57) and not (ch >= 97 and ch <= 102): return false
	return true

func _check(ok: bool, label: String) -> bool:
	checks.append(label)
	if not ok: failures.append(label)
	return ok

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started = Time.get_ticks_msec()
	call_deferred("_observe")

func _observe() -> void:
	var path := OS.get_environment("LSH_REAL_SDK_DESCRIPTOR")
	descriptor_sha = OS.get_environment("LSH_REAL_SDK_DESCRIPTOR_SHA256")
	if not _check(path.is_absolute_path() and descriptor_sha.length() == 64
		and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == descriptor_sha,
		"exact external descriptor bytes"): _finish(); return
	var file := FileAccess.open(path, FileAccess.READ)
	if not _check(file != null and file.get_length() <= 1048576,"bounded descriptor readable"): _finish(); return
	var raw := file.get_buffer(file.get_length())
	file.close()
	var hash := HashingContext.new()
	if not _check(hash.start(HashingContext.HASH_SHA256) == OK and hash.update(raw) == OK
		and hash.finish().hex_encode() == descriptor_sha,"descriptor original read buffer SHA"): _finish(); return
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not _check(decoded is Dictionary and FileAccess.get_sha256(path) == descriptor_sha,
		"descriptor dictionary and bytes stable"): _finish(); return
	descriptor = decoded
	if not _check(descriptor.get("schema") == "campaign_real_sdk_bootstrap_descriptor_v2"
		and descriptor.get("case") == "bootstrap_only"
		and descriptor.get("normal_startup_account_side_effects_acknowledged") == true,
		"specific bootstrap descriptor acknowledges normal account synchronization"): _finish(); return
	if not _check(_hex_nonce(descriptor.get("nonce"))
		and typeof(descriptor.get("private_user_directory")) == TYPE_STRING
		and OS.get_user_data_dir().simplify_path() == descriptor.private_user_directory.simplify_path(),
		"exact fresh private user directory and nonce"): _finish(); return
	var declared_roots: Variant = descriptor.get("private_windows_roots")
	var roots_ok: bool = declared_roots is Dictionary and declared_roots.size() == 4
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		windows_environment[key] = OS.get_environment(key)
		roots_ok = roots_ok and declared_roots is Dictionary and declared_roots.has(key) \
			and typeof(declared_roots.get(key)) == TYPE_STRING and not declared_roots.get(key).is_empty() \
			and windows_environment[key] == declared_roots.get(key)
	roots_ok = roots_ok and OS.get_environment("SCREENSHOT_DIR").is_empty()
	if not _check(roots_ok,"actual four private Windows environment roots equal original descriptor"): _finish(); return
	private_profile_verified = true
	report_path = "user://real_sdk_bootstrap_" + descriptor.nonce + ".json"
	if not _check(not FileAccess.file_exists(report_path) and not DirAccess.dir_exists_absolute(report_path),
		"nonce-specific report path initially absent"): get_tree().quit(2); return
	if not _check(OS.has_feature("steam") and not OS.has_feature("editor")
		and DisplayServer.get_name() != "headless" and not SteamRunPolicy.test_environment()
		and not ("--script" in OS.get_cmdline_args()) and not ("-s" in OS.get_cmdline_args()),
		"normal exported steam feature and production launch policy"): _finish(); return
	if not _check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60,
		"normal clock and physics rate"): _finish(); return
	if not _check(typeof(descriptor.get("executable")) == TYPE_STRING
		and OS.get_executable_path().simplify_path() == descriptor.executable.simplify_path()
		and FileAccess.get_sha256(OS.get_executable_path()) == descriptor.get("executable_sha256"),
		"actual exported executable path and SHA"): _finish(); return
	identity = Provider.new().resolve_runtime_identity()
	if not _check(identity.get("ok",false) and identity == descriptor.get("installed_identity"),
		"actual native complete installed identity equals frozen descriptor"): _finish(); return
	var steam: Node = get_node("/root/SteamService")
	while not steam.stats_ready and Time.get_ticks_msec()-started < 45000:
		await get_tree().process_frame
	if not _check(Engine.has_singleton("Steam") and steam.available and steam.native != null
		and steam.native == Engine.get_singleton("Steam") and steam.ensure_account(),
		"actual Engine Steam singleton and production account guard"): _finish(); return
	owner = str(steam.native.call("getSteamID"))
	if not _check(owner != "0" and owner == steam.account
		and owner == descriptor.get("expected_account")
		and int(steam.native.call("getAppID")) == APP_ID,
		"actual SDK AppID and exact authorized account"): _finish(); return
	if not _check(steam.stats_ready and not steam._correction_required and steam._stats_reader != null,
		"production native stats reader ready without correction"): _finish(); return
	var first: Dictionary = steam._stats_reader.current_snapshot()
	if not _check(first.get("ok",false) and first.get("owner") == owner,
		"original native stats snapshot owns actual account"): _finish(); return
	initial_snapshot = first.duplicate(true)
	for frame in range(180): await get_tree().process_frame
	if not _check(steam.native == Engine.get_singleton("Steam") and steam.ensure_account()
		and str(steam.native.call("getSteamID")) == owner and steam.stats_ready
		and Provider.new().resolve_runtime_identity() == identity,
		"same real account singleton and installed identity after ordinary frames"): _finish(); return
	final_snapshot = steam._stats_reader.current_snapshot()
	if not _check(final_snapshot.get("ok",false) and final_snapshot.get("owner") == owner,
		"final original native stats snapshot owns same account"): _finish(); return
	_finish()

func _finish() -> void:
	if not private_profile_verified: get_tree().quit(2); return
	var report := {"schema":SCHEMA,"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"pid":OS.get_process_id(),"nonce":descriptor.get("nonce",""),"descriptor_sha256":descriptor_sha,
		"account":owner,"app_id":APP_ID,"identity":identity,"user_directory":OS.get_user_data_dir(),
		"windows_environment":windows_environment.duplicate(true),
		"initial_native_stats":initial_snapshot,"final_native_stats":final_snapshot,
		"executable":OS.get_executable_path(),"executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"elapsed_ms":Time.get_ticks_msec()-started,"time_scale":Engine.time_scale,
		"physics_ticks":Engine.physics_ticks_per_second,"native_bootstrap_observed":failures.is_empty(),
		"successful_cloud_retry_qualified":false,"same_profile_restart_qualified":false,
		"SDK_reward_once_qualified":false,"original19_qualified":false,"overall_goal_qualified":false}
	# Host must hold the unique empty private profile throughout the owned process.
	# This check is defense in depth, not an atomic exclusive-open or host lease.
	if FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path):
		get_tree().quit(2); return
	var report_text: String = JSON.stringify(report,"\t") + "\n"
	var expected: PackedByteArray = report_text.to_utf8_buffer()
	var output := FileAccess.open(report_path,FileAccess.WRITE)
	if output == null: get_tree().quit(2); return
	output.store_buffer(expected)
	output.flush()
	var write_error: int = output.get_error()
	output.close()
	if write_error != OK: get_tree().quit(2); return
	var closed := FileAccess.open(report_path,FileAccess.READ)
	if closed == null: get_tree().quit(2); return
	var actual: PackedByteArray = closed.get_buffer(closed.get_length())
	closed.close()
	if actual != expected or FileAccess.get_sha256(report_path) != report_text.sha256_text():
		get_tree().quit(2); return
	print("REAL_SDK_BOOTSTRAP_COMPLETE ",OS.get_process_id()," ",descriptor.get("nonce","")," ",checks.size()," ",failures.is_empty())
	get_tree().quit(0 if failures.is_empty() else 1)
