extends Node
## Exercise the unpatched v27b Campaign methods and actual private ConfigFile APIs.
## These are component cases, not natural battles, player UI or crash recovery.

class LocalCloudCounter extends Node:
	signal observed
	var calls := 0
	var snapshots: Array = []
	func mark_dirty() -> void:
		calls += 1
		var campaign = get_node("/root/Campaign")
		snapshots.append({"records":campaign.records.duplicate(true), "unlocked":campaign.unlocked})

const IDS := ["normal_first_full_seal", "normal_repeat_full", "best_single_run_no_union",
	"invalid_no_unlock", "QA_memory_only", "QA_cloud_bool_compatibility", "bad_existing_cfg_load",
	"existing_vanished_prior", "true_new_missing_cfg", "write_failure", "save_OK_fresh_load_failure",
	"readback_semantic_mismatch", "readback_SHA_changed", "legal_unknown_variant_preservation",
	"unsupported_object_or_script_container", "cycle_or_overdepth", "callback_sees_new_memory",
	"cloud_applying_callback_no_upload_claim", "legacy_real_cloud_apply_failure_boundary"]
var campaign
var real_cloud
var counter: LocalCloudCounter
var output := ""
var nonce := ""
var cases: Array = []
var current: Dictionary = {}
var checks := 0
var failures: Array = []
var full_bytes := PackedByteArray()

func _ready() -> void:
	_run.call_deferred()

func _assert(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append({"case":current.get("id", "profile_guard"), "check":label})

func _json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("FAULT_MATRIX_REPORT_WRITE_FAILED")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()

func _bytes(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(value)
		file.close()
	_assert(file != null, "private fixture write")

func _memory() -> Dictionary:
	return {"records":campaign.records.duplicate(true), "unlocked":campaign.unlocked, "owner":campaign.cloud_owner}

func _full() -> Dictionary:
	return {"core_cleared":true, "story_complete":true, "story_done":3, "story_total":3,
		"done_ids":["a", "b", "c"], "contract_version":2}

func _partial(ids: Array) -> Dictionary:
	return {"core_cleared":true, "story_complete":false, "story_done":ids.size(), "story_total":3,
		"done_ids":ids, "contract_version":2}

func _seed(extra: Dictionary = {}) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "schema", 2)
	cfg.set_value("progress", "unlocked", 1)
	cfg.set_value("progress", "records", {})
	cfg.set_value("future]section", "sentinel", 11)
	for key in extra:
		cfg.set_value("future]section", key, extra[key])
	_assert(cfg.save(campaign.SAVE_PATH) == OK, "actual seed ConfigFile.save")

func _cloud(use_real: bool) -> void:
	if counter != null and counter.is_inside_tree():
		remove_child_counter()
	if real_cloud.is_inside_tree():
		get_tree().root.remove_child(real_cloud)
	if use_real:
		get_tree().root.add_child(real_cloud)
		real_cloud.set_process(false)
		real_cloud._applying = true
		real_cloud.dirty = false
		real_cloud._pending_upload = false
	else:
		counter = LocalCloudCounter.new()
		counter.name = "SteamCloud"
		get_tree().root.add_child(counter)

func remove_child_counter() -> void:
	get_tree().root.remove_child(counter)
	counter.free()
	counter = null

func _begin(id: String, fault := "", preserve_full := false, use_real := false, qa := false) -> void:
	current = {"id":id, "fault":fault, "failures_before":failures.size(), "checks_before":checks}
	print("CAMPAIGN_FAULT_CASE_BEGIN ", id)
	OS.set_environment("CAMPAIGN_QA", "1" if qa else "0")
	_cloud(use_real)
	if FileAccess.file_exists(campaign.SAVE_PATH):
		_assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.SAVE_PATH)) == OK, "owned cfg fixture reset")
	campaign.records = {}
	campaign.unlocked = 1
	campaign.cloud_owner = ""
	campaign._last_save_receipt = {}
	if preserve_full:
		_bytes(campaign.SAVE_PATH, full_bytes)
		campaign._load()
	elif id != "true_new_missing_cfg" and id != "normal_first_full_seal":
		_seed()
	current.before_memory = _memory()
	current.before_sha256 = FileAccess.get_sha256(campaign.SAVE_PATH) if FileAccess.file_exists(campaign.SAVE_PATH) else ""
	# The controller installs a source-pinned breakpoint while this real process
	# awaits a private acknowledgement. No Campaign return values are replaced.
	_json(output.path_join("request_%02d.json" % cases.size()), {"id":id, "fault":fault,
		"index":cases.size(), "nonce":nonce, "pid":OS.get_process_id(), "ready":true})
	var until := Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(output.path_join("ack_%02d.json" % cases.size())):
		if Time.get_ticks_msec() >= until:
			push_error("OWNED_FAULT_CONTROLLER_ACK_TIMEOUT")
			get_tree().quit(2)
			return
		await get_tree().process_frame
	var ack: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("ack_%02d.json" % cases.size())))
	_assert(ack is Dictionary and ack.get("nonce") == nonce and ack.get("id") == id, "controller acknowledgement identity")
	# Socket send completion is not engine command consumption. Leave the actual
	# main loop enough wall time to poll the queued debugger breakpoint before
	# entering the targeted production method; normal Engine time_scale stays 1.
	await get_tree().create_timer(0.25, true).timeout

func _outcome(out: Dictionary, code: String, applied: bool, persisted: bool, suppressed := false) -> void:
	_assert(out.accepted == true, "valid result accepted separately from persistence")
	_assert(out.memory_applied == applied and out.persisted == persisted and out.suppressed == suppressed, "memory/disk/suppression outcome")
	_assert(out.save_receipt.code == code, "exact actual save receipt code")
	_assert(out.save_receipt.cloud_upload_verified == false and out.save_receipt.crash_recovery_qualified == false, "qualification boundary")
	if not applied:
		_assert(_memory() == current.before_memory, "failure keeps prior live campaign memory")
		_assert(not out.new_story_seal and not out.durable_new_story_seal, "failure grants no story seal")
		_assert(counter.calls == 0, "failure does not request local cloud callback")
	current.outcome = out.duplicate(true)

func _end() -> void:
	current.after_memory = _memory()
	current.after_sha256 = FileAccess.get_sha256(campaign.SAVE_PATH) if FileAccess.file_exists(campaign.SAVE_PATH) else ""
	current.checks = checks - current.checks_before
	current.last_save_receipt = campaign._last_save_receipt.duplicate(true)
	current.local_counter_calls = counter.calls if counter != null else null
	current.actual_cloud_dirty = real_cloud.dirty if real_cloud.is_inside_tree() else null
	current.actual_cloud_pending_upload = real_cloud._pending_upload if real_cloud.is_inside_tree() else null
	if FileAccess.file_exists(campaign.SAVE_PATH):
		_bytes(output.path_join("private_case_%02d.cfg" % cases.size()), FileAccess.get_file_as_bytes(campaign.SAVE_PATH))
	current.complete = failures.size() == current.failures_before
	cases.append(current.duplicate(true))
	_json(output.path_join("case_%02d.json" % (cases.size() - 1)), current)
	print("CAMPAIGN_FAULT_CASE_END ", current.id)

func _run() -> void:
	output = OS.get_environment("CAMPAIGN_FAULT_MATRIX_OUT")
	nonce = OS.get_environment("CAMPAIGN_FAULT_MATRIX_NONCE")
	var profile := OS.get_environment("CAMPAIGN_FAULT_MATRIX_PROFILE")
	if output.is_empty() or nonce.is_empty() or profile.is_empty() or not OS.get_user_data_dir().begins_with(profile):
		push_error("PRIVATE_FAULT_MATRIX_PROFILE_REQUIRED")
		get_tree().quit(2)
		return
	campaign = get_node("/root/Campaign")
	real_cloud = get_node("/root/SteamCloud")
	var out: Dictionary
	await _begin(IDS[0])
	out = campaign.on_level_won(_full(), {"mode":"campaign", "level_id":"level8"})
	_outcome(out, "CAMPAIGN_CFG_READBACK_VERIFIED", true, true)
	_assert(out.new_story_seal and out.durable_new_story_seal and campaign.unlocked == 9, "first full same-run seal and staged unlock")
	full_bytes = FileAccess.get_file_as_bytes(campaign.SAVE_PATH)
	_end()
	await _begin(IDS[1], "", true)
	out = campaign.on_level_won(_full(), {"mode":"campaign", "level_id":"level8"})
	_outcome(out, "CAMPAIGN_CFG_READBACK_VERIFIED", true, true)
	_assert(not out.new_story_seal and not out.durable_new_story_seal, "loaded prior full result gives no duplicate seal")
	_end()
	await _begin(IDS[2])
	for ids in [["a"], ["b", "c"], ["a", "c"], ["d"]]:
		out = campaign.record_level_result("level8", _partial(ids))
		_outcome(out, "CAMPAIGN_CFG_READBACK_VERIFIED", true, true)
	_assert(campaign.records.level8.best_goal_ids == ["b", "c"] and not campaign.has_story_seal("level8"), "one best run, no union or tied replacement")
	_end()
	await _begin(IDS[3])
	for request in [[_full(), {"mode":"custom", "level_id":"level8"}], [_full(), {"mode":"campaign", "level_id":"unknown"}], [{"core_cleared":false}, {"mode":"campaign", "level_id":"level8"}]]:
		out = campaign.on_level_won(request[0], request[1])
		_assert(not out.accepted and not out.memory_applied and not out.persisted and not out.save_receipt.write_attempted, "invalid context/level/core refused before disk")
	_assert(_memory() == current.before_memory and FileAccess.get_sha256(campaign.SAVE_PATH) == current.before_sha256, "invalid result keeps memory and actual file")
	_end()
	await _begin(IDS[4], "", false, false, true)
	out = campaign.record_level_result("level8", _full())
	_outcome(out, "CAMPAIGN_QA_SUPPRESSED", true, false, true)
	_assert(out.new_story_seal and not out.durable_new_story_seal and campaign._save() == true, "legacy QA bool remains successful without durability")
	_assert(FileAccess.get_sha256(campaign.SAVE_PATH) == current.before_sha256 and counter.calls == 0, "QA leaves real file and callback untouched")
	_end()
	await _begin(IDS[5], "", false, true, true)
	var owner := "123456789"
	real_cloud._owner = owner
	var payload: Dictionary = real_cloud._default_payload(owner)
	payload.campaign = {"schema":2, "unlocked":4, "records":{"level6":{"cleared":true}}}
	_assert(real_cloud._apply_profile(payload) == true and campaign.cloud_owner == owner and campaign.unlocked == 4, "actual legacy Cloud apply QA bool and replacement")
	_assert(campaign._last_save_receipt.suppressed and not campaign._last_save_receipt.persisted and not real_cloud.dirty, "actual applying branch makes no upload claim")
	_assert(FileAccess.get_sha256(campaign.SAVE_PATH) == current.before_sha256, "QA Cloud keeps seeded actual cfg")
	_end()
	await _begin(IDS[6])
	_bytes(campaign.SAVE_PATH, "[broken".to_utf8_buffer())
	current.before_sha256 = FileAccess.get_sha256(campaign.SAVE_PATH)
	out = campaign.record_level_result("level8", _full())
	_outcome(out, "CAMPAIGN_CFG_PRIOR_LOAD_FAILED", false, false)
	_assert(not out.save_receipt.write_attempted and FileAccess.get_sha256(campaign.SAVE_PATH) == current.before_sha256, "malformed prior file never overwritten")
	_end()
	for index in [7, 8, 9, 10, 11, 12]:
		var faults := {7:"prior_vanished", 8:"", 9:"write_readonly", 10:"fresh_load_missing", 11:"semantic_mismatch", 12:"sha_interval_change"}
		await _begin(IDS[index], faults[index])
		out = campaign.record_level_result("level8", _full())
		var codes := {7:"CAMPAIGN_CFG_PRIOR_LOAD_FAILED", 8:"CAMPAIGN_CFG_READBACK_VERIFIED", 9:"CAMPAIGN_CFG_WRITE_FAILED", 10:"CAMPAIGN_CFG_READBACK_FAILED", 11:"CAMPAIGN_CFG_READBACK_MISMATCH", 12:"CAMPAIGN_CFG_READBACK_MISMATCH"}
		_outcome(out, codes[index], index == 8, index == 8)
		if index == 7: _assert(not out.save_receipt.write_attempted and not FileAccess.file_exists(campaign.SAVE_PATH), "existed-then-vanished does not rebuild")
		if index == 8: _assert(out.save_receipt.prior_load_error == ERR_FILE_NOT_FOUND, "genuinely new missing file accepted by actual load code")
		if index == 9: _assert(out.save_receipt.write_error != OK and not out.save_receipt.readback_attempted, "actual writer failure blocks fresh readback")
		if index in [10, 11, 12]: _assert(out.save_receipt.write_error == OK and out.save_receipt.readback_failed and out.save_receipt.disk_state_unconfirmed and not out.save_receipt.retry_safe, "saved then unconfirmed disk is not a safe retry")
		_end()
	await _begin(IDS[13])
	var typed_array: Array[String] = ["known", "future"]
	var typed_dict: Dictionary[String, Vector2] = {"position":Vector2(2.25, -3.5)}
	_seed({"vector":Vector2(1.25, -2.5), "transform":Transform3D.IDENTITY, "projection":Projection.IDENTITY,
		"bytes":PackedByteArray([1, 128, 255]), "integers":PackedInt64Array([9223372036854775807]),
		"vectors":PackedVector4Array([Vector4(1, 2, 3, 4)]), "colors":PackedColorArray([Color(0.1, 0.2, 0.3)]),
		"typed_array":typed_array, "typed_dict":typed_dict, "string_name":&"future_name", "node_path":NodePath("root/child"),
		"nan":NAN, "inf":INF, "negative_zero":-0.0})
	var before_cfg := ConfigFile.new()
	_assert(before_cfg.load(campaign.SAVE_PATH) == OK, "actual legal unknown fixture fresh load")
	var before_semantics: Dictionary = campaign._cfg_semantics(before_cfg)
	out = campaign.record_level_result("level8", _full())
	_outcome(out, "CAMPAIGN_CFG_READBACK_VERIFIED", true, true)
	var after_cfg := ConfigFile.new()
	_assert(after_cfg.load(campaign.SAVE_PATH) == OK and campaign._cfg_semantics(after_cfg).sections["future]section"] == before_semantics.sections["future]section"], "all unknown keys preserve actual ConfigFile semantics")
	_end()
	await _begin(IDS[14])
	var scripted: Array[LocalCloudCounter] = []
	var object_array: Array[Node] = []
	var object_dict: Dictionary[String, Node] = {}
	var object := RefCounted.new()
	for value in [object, RID(), Callable(counter, "mark_dirty"), counter.observed, scripted, object_array, object_dict]:
		var receipt: Dictionary = campaign._write_config_receipt(1, {"unsafe":value})
		_assert(receipt.code == "CAMPAIGN_CFG_UNSUPPORTED_VALUE" and not receipt.write_attempted and not receipt.persisted, "real prewrite component rejects identity/container value")
	_assert(FileAccess.get_sha256(campaign.SAVE_PATH) == current.before_sha256 and counter.calls == 0, "unsupported component leaves prior file unchanged")
	_assert(_memory() == current.before_memory, "unsupported component keeps live memory")
	_end()
	await _begin(IDS[15])
	var cycle: Array = []
	cycle.append(cycle)
	var deep: Variant = 1
	for _depth in range(129): deep = [deep]
	for value in [cycle, deep]:
		var receipt: Dictionary = campaign._write_config_receipt(1, {"unsafe":value})
		_assert(receipt.code == "CAMPAIGN_CFG_UNSUPPORTED_VALUE" and not receipt.write_attempted, "cycle/depth refused before encoder")
	_assert(cycle.size() == 1 and is_same(cycle[0], cycle), "component refusal leaves alias cycle input unchanged")
	cycle.clear()
	_assert(FileAccess.get_sha256(campaign.SAVE_PATH) == current.before_sha256, "cycle/depth never writes prior cfg")
	_assert(_memory() == current.before_memory, "cycle/depth component keeps live memory")
	_end()
	await _begin(IDS[16])
	out = campaign.on_level_won(_full(), {"mode":"campaign", "level_id":"level8"})
	_outcome(out, "CAMPAIGN_CFG_READBACK_VERIFIED", true, true)
	_assert(counter.calls == 1 and counter.snapshots[0].records == campaign.records and counter.snapshots[0].unlocked == 9, "actual local callback sees newly published memory")
	_end()
	await _begin(IDS[17], "", false, true)
	out = campaign.record_level_result("level8", _full())
	_assert(out.persisted and out.save_receipt.cloud_dirty_requested and out.save_receipt.cloud_dirty_callback_invoked, "actual SteamCloud.mark_dirty invocation recorded")
	_assert(not real_cloud.dirty and not real_cloud._pending_upload and out.save_receipt.cloud_dirty_observed == null and not out.save_receipt.cloud_upload_verified, "real applying branch suppresses dirty and upload")
	_end()
	await _begin(IDS[18], "fresh_load_missing", false, true)
	real_cloud._owner = owner
	payload = real_cloud._default_payload(owner)
	payload.campaign = {"schema":2, "unlocked":4, "records":{"level6":{"cleared":true}}}
	_assert(real_cloud._apply_profile(payload) == false, "actual legacy Cloud apply reports real readback failure")
	_assert(campaign.cloud_owner == owner and campaign.unlocked == 4 and campaign.records.has("level6"), "existing pre-save cloud memory replacement boundary observed")
	_assert(campaign._last_save_receipt.code == "CAMPAIGN_CFG_READBACK_FAILED" and not campaign._last_save_receipt.persisted, "failed Cloud apply does not claim disk persistence")
	_end()
	_assert(cases.size() == 19, "all original matrix IDs executed")
	var report := {"schema":"campaign_persistence_fault_component_v1", "complete":failures.is_empty(),
		"pid":OS.get_process_id(), "nonce":nonce, "cases":cases, "checks":checks, "failures":failures,
		"actual_user_dir":OS.get_user_data_dir(), "engine_time_scale":Engine.time_scale,
		"campaign_runtime_patches":0, "cfg_return_values_simulated":false,
		"natural_battle_qualified":false, "player_UI_qualified":false, "crash_recovery_qualified":false,
		"reward_once_qualified":false, "cloud_upload_qualified":false}
	_json(output.path_join("report.json"), report)
	print("CAMPAIGN_PERSISTENCE_FAULT_MATRIX_COMPLETE ", JSON.stringify({"cases":cases.size(), "checks":checks, "failures":failures.size()}))
	if real_cloud != null and not real_cloud.is_inside_tree(): real_cloud.free()
	get_tree().quit(0 if failures.is_empty() else 1)
