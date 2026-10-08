extends SceneTree
## Real isolated CFG replacement component fixture; no natural campaign result.
const Transaction := preload("res://scripts/run_campaign_cfg_transaction.gd")
const Values := preload("res://scripts/run_campaign_cfg_values.gd")
var checks: Array = []
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks.append({"label":label, "ok":condition})
	if not condition: failures.append(label)

func _seed() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "schema", 2)
	cfg.set_value("progress", "owner", "")
	cfg.set_value("progress", "unlocked", 2)
	cfg.set_value("progress", "records", {"unrelated_chapter":{"cleared":false,"sentinel":"preserved"}})
	cfg.set_value("pref", "ai_difficulty", "hard")
	cfg.set_value("pref", "defense_interval", 31.0)
	cfg.set_value("unknown section ] quoted", "key=sentinel", {"name":&"kept", "path":NodePath("relative/sentinel"),
		"vector":Vector3(1.25, -2.0, 0.5), "packed":PackedInt32Array([7, 9]), "negative_zero":-0.0})
	var saved: int = cfg.save("user://campaign.cfg")
	check(saved == OK, "fixture actual ConfigFile.save")
	return saved == OK

func _request() -> Dictionary:
	return {"operation":"prefs", "run_token":"", "intent_sha256":"", "target_owner":"",
		"content_version":OS.get_environment("CFG_TRANSACTION_PROBE_CONTENT"),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path())}

func _project(cfg: ConfigFile) -> void:
	# Synthetic component data, deliberately not a Mission or natural victory.
	var records: Dictionary = cfg.get_value("progress", "records", {})
	records["component_fixture"] = {"counter":7, "ids":["single", "run"]}
	cfg.set_value("progress", "records", records)
	cfg.set_value("progress", "unlocked", 9)

func _verify() -> void:
	var cfg := ConfigFile.new()
	var loaded: int = cfg.load("user://campaign.cfg")
	check(loaded == OK, "fresh independent ConfigFile.load")
	if loaded != OK: return
	check(cfg.get_value("progress", "unlocked", -1) == 9, "component projected field durable")
	var records: Variant = cfg.get_value("progress", "records", {})
	check(typeof(records) == TYPE_DICTIONARY and records.has("unrelated_chapter") \
		and records.unrelated_chapter.sentinel == "preserved", "unrelated record preserved")
	check(typeof(records) == TYPE_DICTIONARY and records.get("component_fixture", {}).get("counter") == 7,
		"component value not added twice")
	check(cfg.get_value("pref", "ai_difficulty", "") == "hard" and cfg.get_value("pref", "defense_interval", 0) == 31.0,
		"existing gameplay preferences preserved")
	var unknown: Variant = cfg.get_value("unknown section ] quoted", "key=sentinel", {})
	check(typeof(unknown) == TYPE_DICTIONARY and unknown.get("name") == &"kept" \
		and unknown.get("path") == NodePath("relative/sentinel") \
		and unknown.get("packed") == PackedInt32Array([7, 9]) \
		and unknown.get("vector") == Vector3(1.25, -2.0, 0.5), "legal unknown Variant section/key preserved")

func _run() -> void:
	# SceneTree deferred initialization can drain during the first physics step.
	# Wait on real process frames; production disk guards remain unchanged.
	while Engine.is_in_physics_frame(): await process_frame
	var profile: String = OS.get_environment("CFG_TRANSACTION_PROBE_PROFILE").replace("\\", "/").trim_suffix("/")
	var output: String = OS.get_environment("CFG_TRANSACTION_PROBE_OUT")
	var mode: String = OS.get_environment("CFG_TRANSACTION_PROBE_MODE")
	if not profile.is_absolute_path() or output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/appdata/"):
		quit(2); return
	for name in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		if OS.get_environment(name).replace("\\", "/").trim_suffix("/") != profile.path_join(name.to_lower()):
			quit(2); return
	check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "normal native clocks")
	var transaction := Transaction.new()
	var response: Dictionary = {}
	if mode in ["normal", "window_after_backup", "window_after_install", "external_CAS"]:
		if not _seed(): _finish(output, mode, response); return
		var before: String = FileAccess.get_sha256("user://campaign.cfg")
		var begun: Dictionary = transaction.begin_write(_request())
		check(begun.ok, "actual transaction acquires owned lock and stable prior CFG")
		if not begun.ok: response = begun.duplicate(true)
		if begun.ok:
			_project(begun.cfg)
			response = transaction.commit_prepared(begun.cfg)
		if mode == "external_CAS":
			check(not response.get("ok", false) and response.get("code") == "CFG_CAS_CHANGED_PRESERVED", "actual external CFG CAS refused")
			var cfg := ConfigFile.new()
			check(cfg.load("user://campaign.cfg") == OK and cfg.get_value("external", "sentinel", "") == "controller_owned_change",
				"controller's real external CFG retained")
			check(FileAccess.get_sha256("user://campaign.cfg") != before, "external mutation actual hash differs")
		else:
			check(response.get("ok", false) and response.get("persisted", false), "actual staged CFG and applied journal verified")
			if response.get("ok", false):
				_verify()
				var unchanged: String = FileAccess.get_sha256("user://campaign.cfg")
				var repeated: Dictionary = transaction.begin_write(_request())
				check(repeated.ok, "new ordinary identical transaction permitted after closure")
				if repeated.ok:
					var saved: Dictionary = transaction.commit_prepared(repeated.cfg)
					check(saved.get("ok", false) and FileAccess.get_sha256("user://campaign.cfg") == unchanged,
						"identical CFG closes without destructive replacement")
	elif mode in ["recover", "recover_CAS_refusal"]:
		var identity := {"content_version":OS.get_environment("CFG_TRANSACTION_PROBE_CONTENT"),
			"engine_binary_sha256":FileAccess.get_sha256(OS.get_executable_path())}
		response = transaction.recover_pending(identity, "")
		if mode == "recover_CAS_refusal":
			check(not response.get("ok", false) and response.get("code") == "CFG_CAS_CHANGED_PRESERVED",
				"independent process does not clobber changed external CFG")
		else:
			check(response.get("ok", false) and response.get("persisted", false), "dead exact writer CFG window independently recovered")
			if response.get("ok", false): _verify()
	else:
		check(false, "known exact probe mode")
	_finish(output, mode, response)

func _finish(output: String, mode: String, response: Dictionary) -> void:
	var report := {"schema":"campaign_cfg_transaction_probe_v1", "pid":OS.get_process_id(),
		"nonce":OS.get_environment("CFG_TRANSACTION_PROBE_NONCE"), "mode":mode,
		"actual_user_dir":OS.get_user_data_dir(), "checks":checks.size(), "check_rows":checks,
		"failures":failures, "response":response, "engine_time_scale":Engine.time_scale,
		"natural_campaign_result_qualified":false, "campaign_gen2_ack_recovery_qualified":false,
		"player_ui_qualified":false, "Steam_reward_qualified":false, "power_loss_atomicity_qualified":false}
	var file := FileAccess.open(output.path_join("probe_report.json"), FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.flush(); file.close()
	print("CAMPAIGN_CFG_COMPONENT_COMPLETE ", checks.size(), " / ", failures.size())
	quit(0 if failures.is_empty() else 1)
