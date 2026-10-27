extends Node
## Synthetic data fixture, real installed LC/Coordinator/CFG/ACK APIs.
## No Battle, fake liveness, production override, SDK or live settlement claim.
const Identity = preload("res://scripts/run_content_identity.gd")
const Intent = preload("res://scripts/run_campaign_progress_intent.gd")
const ProgressProjection = preload("res://scripts/run_campaign_progress_projection.gd")
const Lifecycle = preload("res://scripts/run_campaign_local_lifecycle.gd")
const Coordinator = preload("res://scripts/run_campaign_progress_coordinator.gd")
const CFG = preload("res://scripts/run_campaign_cfg_transaction.gd")
const Values = preload("res://scripts/run_campaign_cfg_values.gd")
const CONTEXT := {"mode":"campaign", "level_id":"level8", "waves":0}
const GOALS := ["daming_infiltration", "daming_signal", "daming_response"]
const IDS := ["normal_first_full_seal", "normal_repeat_full", "best_single_run_no_union",
	"invalid_no_unlock", "QA_memory_only", "QA_cloud_bool_compatibility", "bad_existing_cfg_load",
	"existing_vanished_prior", "true_new_missing_cfg", "write_failure", "save_OK_fresh_load_failure",
	"readback_semantic_mismatch", "readback_SHA_changed", "legal_unknown_variant_preservation",
	"unsupported_object_or_script_container", "cycle_or_overdepth", "callback_sees_new_memory",
	"cloud_applying_callback_no_upload_claim", "legacy_real_cloud_apply_failure_boundary"]
const FAULTS := {6:"bad_prior", 7:"prior_vanished", 9:"write_denied", 10:"fresh_load_missing",
	11:"semantic_mismatch", 12:"sha_interval_change", 17:"cloud_callback", 18:"cloud_fresh_load_missing"}
const ZERO := "0000000000000000000000000000000000000000000000000000000000000000"
const CLOUD_OWNER := "123456789"

class LocalCloudCounter extends Node:
	signal observed
	var calls: int = 0
	var snapshots: Array = []
	func mark_dirty() -> void:
		calls += 1
		var current: Node = get_node("/root/Campaign")
		snapshots.append({"records":current.records.duplicate(true), "unlocked":current.unlocked,
			"owner":current.cloud_owner, "cfg_sha256":FileAccess.get_sha256("user://campaign.cfg")})

var index: int = -1
var case_id: String = ""
var output: String = ""
var profile: String = ""
var trusted: Dictionary = {}
var checks: Array = []
var failures: Array = []
var observations: Dictionary = {}
var result: Dictionary = {}
var campaign: Node
var cloud: Node
var counter: LocalCloudCounter
var retained: Array[RefCounted] = []
var last_coordinator: RefCounted
var last_lifecycle: RefCounted
var last_intent: Dictionary = {}
var before_memory: Dictionary = {}
var before_cfg: Dictionary = {}
var case_plan: Dictionary = {}
var healthy: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(value: bool, label: String, detail: Variant = null) -> bool:
	checks.append({"passed":value, "label":label, "detail":detail})
	if not value: failures.append(label)
	healthy = healthy and value
	print("PERSISTENCE19 ", "PASS " if value else "FAIL ", label)
	return value

func scope_fields() -> Dictionary:
	return {"pid":OS.get_process_id(), "index":index, "id":case_id,
		"batch_nonce":OS.get_environment("P19_BATCH_NONCE"), "process_nonce":OS.get_environment("P19_PROCESS_NONCE"),
		"profile":profile, "userdata":ProjectSettings.globalize_path("user://").replace("\\", "/"),
		"content_version":trusted.get("content_version", ""), "engine_sha256":trusted.get("engine_binary_sha256", "")}

func write_json(name: String, value: Dictionary) -> bool:
	var path: String = output.path_join(name)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp"): return false
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.flush()
	var code: Error = file.get_error()
	file.close()
	if code != OK or FileAccess.file_exists(path): return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func nonphysics() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame

func memory() -> Dictionary:
	return {"records":campaign.records.duplicate(true), "unlocked":campaign.unlocked, "owner":campaign.cloud_owner}

func file_state(path: String) -> Dictionary:
	var exists: bool = FileAccess.file_exists(path)
	if not exists: return {"exists":false, "sha256":"", "bytes":0}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return {"exists":true, "readable":false, "sha256":"", "bytes":-1}
	var size: int = file.get_length()
	file.close()
	return {"exists":true, "readable":true, "sha256":FileAccess.get_sha256(path), "bytes":size}

func inventory_tree(path: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(path): return {"ok":true, "exists":false, "files":{}, "directories":[]}
	var files: Dictionary = {}
	var directories: Array = []
	var queue: Array[String] = [""]
	while not queue.is_empty():
		var relative: String = queue.pop_front()
		var directory: DirAccess = DirAccess.open(path.path_join(relative))
		if directory == null: return {"ok":false, "code":"P19_INVENTORY_OPEN"}
		var names: PackedStringArray = directory.get_files()
		for name: String in names:
			if directory.is_link(name): return {"ok":false, "code":"P19_INVENTORY_LINK"}
			var leaf: String = relative.path_join(name) if not relative.is_empty() else name
			files[leaf] = file_state(path.path_join(leaf))
		for name: String in directory.get_directories():
			if directory.is_link(name): return {"ok":false, "code":"P19_INVENTORY_LINK"}
			var child: String = relative.path_join(name) if not relative.is_empty() else name
			directories.append(child); queue.append(child)
	directories.sort()
	return {"ok":true, "exists":true, "files":files, "directories":directories}

func business() -> Dictionary:
	return {"campaign_cfg":file_state("user://campaign.cfg"),
		"cfg_journal":inventory_tree("user://campaign_cfg_transactions/v1"),
		"cfg_candidates":inventory_tree("user://campaign_cfg_candidates/v1"),
		"continue":inventory_tree("user://continue/v1"),
		"settings":file_state("user://settings.cfg"), "language":file_state("user://language.cfg")}

func gate() -> bool:
	var request: Dictionary = scope_fields()
	request.erase("content_version")
	request.erase("engine_sha256")
	request.merge({"schema":"persistence19_gate_v1", "fault":FAULTS.get(index, ""),
		"phase":"before_operation", "output":output,
		"cfg_path":ProjectSettings.globalize_path("user://campaign.cfg").replace("\\", "/"),
		"cfg_source_sha256":before_cfg.sha256, "cfg_expected_unlock":4 if index == 18 else 9})
	if not check(write_json("gate_request.json", request), "exclusive complete gate request published"): return false
	var deadline: int = Time.get_ticks_msec() + 60000
	var path: String = output.path_join("gate_ack.json")
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	var ack: Dictionary = read_json(path)
	var fields: Array = ["schema", "pid", "index", "id", "batch_nonce", "process_nonce"]
	var exact: bool = ack.size() == fields.size() and ack.has_all(fields)
	if exact:
		exact = typeof(ack.schema) == TYPE_STRING and ack.schema == "persistence19_gate_ack_v1" \
			and typeof(ack.id) == TYPE_STRING and ack.id == case_id \
			and typeof(ack.batch_nonce) == TYPE_STRING and ack.batch_nonce == request.batch_nonce \
			and typeof(ack.process_nonce) == TYPE_STRING and ack.process_nonce == request.process_nonce \
			and Intent.integer(ack.pid, OS.get_process_id(), OS.get_process_id()) and Intent.integer(ack.index, index, index)
	if not check(exact, "exact closed host ACK bound to actual pid/case/nonces"): return false
	# Socket-send completion is not debugger command consumption. Ordinary clock.
	await get_tree().create_timer(0.25, true).timeout
	await nonphysics()
	return check(Engine.time_scale == 1.0, "normal 1x clock before synchronous production operation")

func _seed_private_campaign_fixture(extra: Dictionary = {}) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "schema", 2)
	cfg.set_value("progress", "unlocked", 1)
	cfg.set_value("progress", "records", {})
	cfg.set_value("progress", "owner", "")
	cfg.set_value("future]section", "sentinel", 11)
	for key in extra: cfg.set_value("future]section", key, extra[key])
	if not check(cfg.save("user://campaign.cfg") == OK, "real private synthetic seed ConfigFile.save"): return false
	campaign._load()
	return check(campaign.unlocked == 1 and campaign.records.is_empty() and campaign.cloud_owner.is_empty(), "actual Campaign._load reads fixture baseline")

func result_data(ids: Array, victory: bool = true) -> Dictionary:
	return {"core_cleared":victory, "story_complete":victory and ids.size() == GOALS.size(),
		"story_done":ids.size(), "story_total":GOALS.size(), "done_ids":ids.duplicate(), "contract_version":2}

func make_intent(ids: Array) -> Dictionary:
	var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var expected: Dictionary = Intent.scope(CONTEXT, trusted, campaign.cloud_owner)
	if not check(expected.ok, "actual trusted Daming scope"): return {}
	var raw: Dictionary = {"schema":Intent.SCHEMA, "token":token, "context":CONTEXT.duplicate(),
		"profile_id":expected.profile_id, "owner":campaign.cloud_owner,
		"content_version":trusted.content_version, "engine_sha256":trusted.engine_binary_sha256,
		"victory":true, "result":result_data(ids), "credit":{"kind":"uncredited"}}
	var checked: Dictionary = Intent.validate(raw, token, expected)
	if not check(checked.ok, "strict synthetic Intent v2 with actual IDs and uncredited scope"): return {}
	return checked.intent

func run_recovery(ids: Array, inspect_projection: bool = true) -> Dictionary:
	var intent: Dictionary = make_intent(ids)
	if intent.is_empty(): return {"ok":false, "code":"P19_FIXTURE_INTENT"}
	last_intent = intent.duplicate(true)
	if inspect_projection:
		var probe := ConfigFile.new()
		if FileAccess.file_exists("user://campaign.cfg"):
			if not check(probe.load("user://campaign.cfg") == OK, "independent prior projection probe loads original CFG"): return {"ok":false, "code":"P19_PRIOR_PROBE"}
		var predicted: Dictionary = ProgressProjection.project(intent, intent.token, Intent.scope(CONTEXT, trusted, campaign.cloud_owner), probe)
		if not check(predicted.ok, "pure expected projection validates without committing"): return predicted
		observations.get_or_add("projections", []).append({"token":intent.token, "new_story_seal":predicted.new_story_seal,
			"record":predicted.record.duplicate(true), "unlocked":predicted.unlocked})
	var created: RefCounted = Lifecycle.new(intent.token, "user://continue/v1", CONTEXT, trusted, campaign.cloud_owner)
	retained.append(created)
	var begun: Dictionary = created.begin()
	if not check(begun.ok, "actual LC3 begin writes gen1"): return begun
	var ended: Dictionary = created.terminal_with_intent(true, intent)
	if not check(ended.ok and ended.local_terminal_committed, "actual LC3 terminal writes strict gen2 intent"): return ended
	var cold: RefCounted = Lifecycle.new(intent.token, "user://continue/v1", CONTEXT, trusted, campaign.cloud_owner)
	var coordinator: RefCounted = Coordinator.new(campaign, trusted)
	retained.append(cold); retained.append(coordinator)
	last_lifecycle = cold; last_coordinator = coordinator
	var applied: Dictionary = coordinator.begin_recovery(cold)
	observations.get_or_add("transactions", []).append({"token":intent.token, "intent":intent.duplicate(true), "result":applied.duplicate(true)})
	if applied.ok:
		check(applied.get("progress_recovery_only", false) and not applied.get("settlement_authorized", true)
			and applied.get("campaign_progress_committed", false), "real recovery commits without live settlement capability")
		var head: Dictionary = cold.open_head()
		if not check(head.ok and head.revision == 3, "real local acknowledgement reaches gen3"): return {"ok":false, "code":"P19_ACK_HEAD"}
		var ack: Dictionary = head.document.progress_receipt
		var proof: Dictionary = Intent.validate_handoff_proof(ack.steam_handoff, intent)
		check(ack.schema == "campaign_progress_ack_v2" and ack.persisted and not ack.suppressed
			and ack.file_sha256 == FileAccess.get_sha256("user://campaign.cfg") and proof.ok,
			"actual ACK2 CFG SHA and strict uncredited handoff proof")
		check(head.document.intent == intent and coordinator._intent == intent, "original frozen intent survives complete transaction unchanged")
		observations.get_or_add("acknowledgements", []).append({"token":intent.token, "local_file_sha256":head.file_sha256,
			"ack":ack.duplicate(true), "scope":head.document.scope.duplicate(true)})
	return applied

func retained_cfg(writer: RefCounted) -> Dictionary:
	if writer == null: return {}
	var value: Dictionary = {"busy":writer.busy(), "active":writer._active.duplicate(true),
		"pending_record":writer._pending_record.duplicate(true), "inventory":writer.inventory()}
	if not writer._active.is_empty():
		var path: String = writer._stage_dir(writer._active).path_join("candidate.cfg")
		value.candidate_path = path; value.candidate = file_state(path)
		if FileAccess.file_exists(path):
			var candidate := ConfigFile.new()
			var loaded: int = candidate.load(path)
			value.candidate_load_error = loaded
			if loaded == OK:
				var semantic: Dictionary = Values.semantics(candidate)
				value.candidate_semantics_ok = semantic.ok
				if semantic.ok: value.candidate_semantics_sha256 = JSON.stringify(semantic.sections).sha256_text()
		if writer._frozen_cfg != null:
			var frozen: Dictionary = Values.semantics(writer._frozen_cfg)
			value.frozen_semantics_ok = frozen.ok
			if frozen.ok: value.frozen_semantics_sha256 = JSON.stringify(frozen.sections).sha256_text()
	return value

func normal_cases() -> void:
	if index == 2:
		for ids: Array in [[GOALS[0]], [GOALS[1], GOALS[2]], [GOALS[0], GOALS[2]], [GOALS[0]]]:
			result = run_recovery(ids)
			if not check(result.ok, "each actual single-run component transaction completes"): return
		check(campaign.records.level8.best_goal_ids == [GOALS[1], GOALS[2]] and not campaign.has_story_seal("level8"),
			"actual CFG/Campaign keep best single run, no union or tie replacement")
	else:
		result = run_recovery(GOALS)
		if not check(result.ok, "actual full component transaction completes"): return
		check(campaign.unlocked == 9 and campaign.has_story_seal("level8"), "actual published memory has full seal and unlock9")
		var disk := ConfigFile.new()
		check(disk.load("user://campaign.cfg") == OK and disk.get_value("progress", "unlocked", 0) == 9
			and disk.get_value("progress", "records", {}).get("level8", {}).get("story_complete", false), "independent real CFG load confirms seal and unlock9")
		if index in [0, 1]:
			check(observations.projections[0].new_story_seal == (index == 0), "first vs distinct-token repeat projected seal is exact")
		if index == 16:
			check(counter.calls == 1 and counter.snapshots[0].records == campaign.records and counter.snapshots[0].unlocked == 9
				and counter.snapshots[0].cfg_sha256 == FileAccess.get_sha256("user://campaign.cfg"), "one actual commit callback sees newly published memory and disk")
		if index == 17:
			check(cloud._applying and not cloud.dirty and not cloud._pending_upload and cloud._revision == observations.cloud_before.revision,
				"real applying SteamCloud suppresses dirty/upload; host must separately prove mark_dirty call stack")

func invalid_case() -> void:
	var states: Dictionary = business()
	var custom: Dictionary = Intent.scope({"mode":"custom", "level_id":"level8", "waves":0}, trusted, "")
	var unknown: Dictionary = Intent.scope({"mode":"campaign", "level_id":"unknown", "waves":0}, trusted, "")
	var wrong: Dictionary = Intent.validate_result(result_data([], false), CONTEXT, true)
	result = {"custom":custom, "unknown":unknown, "core_mismatch":wrong}
	check(not custom.ok and custom.code == "OFFICIAL_CONTEXT_NOT_SUPPORTED", "current custom context exact refusal")
	check(not unknown.ok and unknown.code == "OFFICIAL_CONTEXT_NOT_SUPPORTED", "current unknown chapter exact refusal")
	check(not wrong.ok and wrong.code == "CAMPAIGN_INTENT_OUTCOME_MISMATCH", "current victory/core mismatch exact refusal")
	check(memory() == before_memory and business() == states, "three current validation refusals change no memory or named business file")

func cloud_snapshot() -> Dictionary:
	return {"applying":cloud._applying, "dirty":cloud.dirty, "pending_upload":cloud._pending_upload,
		"revision":cloud._revision, "shared_pending":cloud.shared_profile_pending(),
		"pending_phase":cloud._pending_shared_phase, "pending_kind":cloud._pending_shared_kind,
		"pending_payload_sha256":JSON.stringify(cloud._pending_shared_profile).sha256_text(),
		"pending_source_sha256":JSON.stringify(cloud._pending_shared_source_profile).sha256_text()}

func cloud_payload() -> Dictionary:
	var payload: Dictionary = cloud._default_payload(CLOUD_OWNER)
	payload.campaign = {"schema":2, "unlocked":4, "records":{"level6":{"cleared":true}}}
	return payload

func qa_case() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	if index == 4:
		result = campaign.record_level_result("level8", result_data(GOALS))
		check(result.get("accepted", false) and result.get("new_story_seal", false) and campaign._save(), "current QA bool and memory-only full seal compatibility")
		check(campaign.has_story_seal("level8"), "QA memory updated through actual legacy API")
	else:
		var payload: Dictionary = cloud_payload()
		var applied: bool = cloud._apply_profile(payload)
		result = {"ok":applied, "returned_type":"bool"}
		check(applied and campaign.cloud_owner == CLOUD_OWNER and campaign.unlocked == 4 and campaign.records.has("level6"), "actual Cloud QA bool replaces compatible campaign memory")
	OS.set_environment("CAMPAIGN_QA", "")
	check(file_state("user://campaign.cfg") == before_cfg, "QA preserves original actual CFG bytes")
	var after: Dictionary = business()
	check(after.cfg_journal == observations.before_business.cfg_journal and after.cfg_candidates == observations.before_business.cfg_candidates,
		"QA creates no CFG transaction or candidate")
	check(not cloud.dirty and not cloud._pending_upload, "QA makes no cloud dirty/upload claim")

func fault_cases() -> void:
	result = run_recovery(GOALS, false)
	if index == 8:
		if not check(result.ok, "genuine missing CFG accepted by actual recovery transaction"): return
		check(not before_cfg.exists and FileAccess.file_exists("user://campaign.cfg") and campaign.unlocked == 9,
			"actual ZERO prior creates durable CFG without prior load-error fiction")
		check(not last_coordinator._cfg.busy(), "new file transaction releases owned writer")
		return
	var expected_code: String = "CFG_READBACK_LOAD" if index in [6, 7] else ("CFG_STAGE_WRITE" if index == 9 else "CFG_STAGE_READBACK")
	if not check(not result.ok and result.get("code", "") == expected_code, "exact current production fault result", result): return
	check(memory() == before_memory, "actual failed transaction keeps prior Campaign memory")
	check(last_coordinator._intent == last_intent and last_coordinator._stage == "progress", "failure retains the original coordinator intent and stage")
	var head: Dictionary = last_lifecycle.open_head()
	check(head.ok and head.revision == 2 and head.document.intent == last_intent and head.document.progress_state == "pending",
		"failed CFG never grants gen3 acknowledgement or changes original terminal intent")
	var state: Dictionary = retained_cfg(last_coordinator._cfg)
	observations.retained_cfg = state
	if index in [6, 7, 9]: check(int(result.get("native_error", OK)) != OK, "actual native ConfigFile error is nonzero")
	check(cloud._revision == observations.cloud_before.revision and cloud.dirty == observations.cloud_before.dirty
		and cloud._pending_upload == observations.cloud_before.pending_upload, "failed progress never requests a local cloud callback")
	if index == 7:
		check(not FileAccess.file_exists("user://campaign.cfg"), "vanished original was not silently recreated")
	else:
		check(file_state("user://campaign.cfg") == before_cfg, "failure preserves exact original CFG bytes")
	if index >= 9:
		check(state.busy and state.active.request.run_token == last_intent.token
			and state.active.request.intent_sha256 == JSON.stringify(last_intent).sha256_text(), "retained writer remains bound to exact original token/intent")
	if index == 9: check(result.get("owned_pending", false), "native save rejection reports owned pending")
	if index in [11, 12]:
		if not check(state.get("candidate_load_error", -1) == OK and state.get("candidate_semantics_ok", false)
			and state.get("frozen_semantics_ok", false), "actual retained candidate/frozen semantics are readable"): return
		if index == 11:
			check(state.candidate.sha256 == state.active.candidate_sha256
				and state.candidate_semantics_sha256 != state.frozen_semantics_sha256, "semantic fault has stable modified bytes but differs from frozen expected data")
		else:
			observations.readback_semantics_equal_frozen = state.candidate_semantics_sha256 == state.frozen_semantics_sha256
			check(state.candidate.sha256 != state.active.candidate_sha256
				and observations.readback_semantics_equal_frozen, "oplock fault changes actual bytes only, not frozen ConfigFile semantics")

func unsupported_cases() -> void:
	var unsafe: Array = []
	var local_counter := LocalCloudCounter.new()
	var cycle: Array = []
	if index == 14:
		var scripted: Array[LocalCloudCounter] = []
		var objects: Array[Node] = []
		var object_map: Dictionary[String, Node] = {}
		unsafe = [RefCounted.new(), RID(), Callable(local_counter, "mark_dirty"), local_counter.observed, scripted, objects, object_map]
	else:
		cycle.append(cycle)
		var deep: Variant = 1
		for _depth: int in range(129): deep = [deep]
		unsafe = [cycle, deep]
	var outcomes: Array = []
	for value: Variant in unsafe:
		var writer: RefCounted = CFG.new()
		retained.append(writer)
		var request: Dictionary = {"operation":"prefs", "run_token":"", "intent_sha256":"", "target_owner":"",
			"content_version":trusted.content_version, "engine_sha256":trusted.engine_binary_sha256}
		var begun: Dictionary = writer.begin_write(request)
		if not check(begun.ok, "actual CFG acquires safe prior before unsupported input"): break
		var cfg: ConfigFile = begun.cfg
		cfg.set_value("unsafe", "value", value)
		var refused: Dictionary = writer.commit_prepared(cfg)
		outcomes.append(refused.duplicate(true))
		if not check(not refused.ok and refused.code == "CAMPAIGN_CFG_UNSUPPORTED_VALUE" and not writer.busy(),
			"actual unsupported input refused before encoding and releases own writer"): break
		check(file_state("user://campaign.cfg") == before_cfg and memory() == before_memory, "unsupported refusal preserves original disk/memory")
	if index == 15:
		check(cycle.size() == 1 and is_same(cycle[0], cycle), "self-cycle alias input unchanged after refusal")
		cycle.clear()
	check(outcomes.size() == (7 if index == 14 else 2), "every original unsupported/depth input reached actual refusal")
	check(not DirAccess.dir_exists_absolute("user://campaign_cfg_candidates/v1"), "preencoder refusals never create candidate stage tree")
	result = {"outcomes":outcomes}
	local_counter.free()

func cloud_failure() -> void:
	var payload: Dictionary = cloud_payload()
	observations.cloud_payload_sha256 = JSON.stringify(payload).sha256_text()
	var applied: bool = cloud._apply_profile(payload)
	observations.cloud_apply_return = applied
	result = campaign._cfg_writer_error.duplicate(true)
	if not check(not applied and result.get("code", "") == "CFG_STAGE_READBACK", "actual Cloud returns false on precise current candidate readback failure"): return
	check(memory() == before_memory and file_state("user://campaign.cfg") == before_cfg,
		"current atomic Campaign boundary preserves prior memory and actual CFG")
	if not check(campaign.persistence_busy() and cloud.shared_profile_pending() and campaign._cfg_writer != null,
		"actual Cloud/CFG retain pending transaction after failed write"): return
	observations.retained_cfg = retained_cfg(campaign._cfg_writer)
	check(campaign._cfg_writer_scope.operation == "cloud" and campaign._cfg_writer_scope.target_owner == CLOUD_OWNER
		and campaign._cfg_writer_original_owner == before_memory.owner, "retained Cloud operation preserves original and target owner scope")
	check(not cloud.dirty and not cloud._pending_upload, "failed real Cloud apply makes no local dirty/upload success claim")
	observations.old_failed_memory_replacement_expected = false
	observations.current_atomic_memory_boundary = true
	observations.settings_language_after = {"settings":file_state("user://settings.cfg"), "language":file_state("user://language.cfg")}

func finish() -> void:
	OS.set_environment("CAMPAIGN_QA", "")
	if campaign != null:
		observations.after_memory = memory()
		observations.after_cfg = file_state("user://campaign.cfg")
		observations.after_business = business()
	if cloud != null: observations.cloud_after = cloud_snapshot()
	if counter != null:
		observations.counter = {"calls":counter.calls, "snapshots":counter.snapshots.duplicate(true)}
		get_tree().root.remove_child(counter); counter.free(); counter = null
		get_tree().root.add_child(cloud)
	if output.is_absolute_path():
		var report: Dictionary = scope_fields()
		report.merge({"schema":"persistence19_component_v2", "case":case_id, "passed":healthy, "checks":checks,
			"failures":failures, "result":result, "observations":observations, "identity":trusted,
			"old_expected":case_plan.get("old_expected", {}), "oracle_version":case_plan.get("oracle_version", ""),
			"synthetic_component":true, "host_fault_proof_required":FAULTS.has(index),
			"native_qualified":false, "all_19_qualified":false, "full_61_qualified":false,
			"public_continue_qualified":false, "natural_battle_qualified":false, "reward_once_qualified":false,
			"native_sdk_qualified":false, "cloud_upload_qualified":false, "live_settlement_qualified":false,
			"native_release_tested":false, "human_acceptance":false, "published":false,
			"production_method_overrides":0, "engine_time_scale":Engine.time_scale})
		if not write_json("report.json", report): push_error("PERSISTENCE19_REPORT_WRITE_FAILED"); get_tree().quit(2); return
	get_tree().quit(0 if healthy else 1)

func run() -> void:
	output = OS.get_environment("P19_OUTPUT").replace("\\", "/").simplify_path()
	profile = OS.get_environment("P19_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	case_id = OS.get_environment("P19_CASE")
	var raw_index: String = OS.get_environment("P19_INDEX")
	index = raw_index.to_int() if raw_index.is_valid_int() else -1
	if not check(index >= 0 and index < IDS.size() and IDS[index] == case_id and output.is_absolute_path()
		and profile.is_absolute_path() and OS.get_environment("P19_BATCH_NONCE").length() == 32
		and OS.get_environment("P19_PROCESS_NONCE").length() == 32, "exact case and private process scope"): finish(); return
	var plan_path: String = OS.get_environment("P19_WORKERS").replace("\\", "/").path_join("cases.json")
	var plan: Dictionary = read_json(plan_path)
	if not check(FileAccess.get_sha256(plan_path) == OS.get_environment("P19_PLAN_SHA256")
		and plan.get("schema", "") == "persistence19_b22_adaptation_plan_v1" and plan.get("worker_implemented", false)
		and typeof(plan.get("cases")) == TYPE_ARRAY and plan.cases.size() == IDS.size(), "pinned current-protocol case mapping loaded"): finish(); return
	case_plan = plan.cases[index]
	if not check(case_plan.get("id", "") == case_id and case_plan.get("oracle_version", "") == "b22_synthetic_component_v2",
		"exact original case with explicit current oracle version"): finish(); return
	var userdata: String = ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	if not check(userdata.begins_with(profile + "/"), "actual userdata lies beneath assigned private profile"): finish(); return
	for variable: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		if not check(OS.get_environment(variable).replace("\\", "/").simplify_path().begins_with(profile + "/"), "private environment " + variable): finish(); return
	campaign = get_node("/root/Campaign"); cloud = get_node("/root/SteamCloud")
	var flow: Node = get_node("/root/ContinueFlow")
	var deadline: int = Time.get_ticks_msec() + 30000
	while not flow.can_launch() and Time.get_ticks_msec() < deadline:
		if flow.phase == flow.Phase.ERROR: break
		await get_tree().process_frame
	if not check(flow.can_launch() and flow.last_result.get("startup_checked", false), "ordinary autoload startup completed"): finish(); return
	await nonphysics()
	trusted = Identity.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("source_mode", false)
		and trusted.content_version == OS.get_environment("P19_CONTENT")
		and trusted.engine_binary_sha256 == OS.get_environment("P19_ENGINE"), "actual b22 source and engine identity"): finish(); return
	if not check(Engine.time_scale == 1.0 and OS.get_environment("STEAM_DISABLED") == "1"
		and OS.get_environment("CAMPAIGN_QA").is_empty(), "normal clock/offline initial non-QA runtime"): finish(); return
	if index == 1:
		var prior_path: String = OS.get_environment("P19_PREVIOUS")
		var prior: Dictionary = read_json(prior_path)
		if not check(FileAccess.get_sha256(prior_path) == OS.get_environment("P19_PREVIOUS_SHA")
			and prior.get("schema", "") == "persistence19_component_v2" and prior.get("passed", false)
			and prior.get("id", "") == IDS[0] and prior.get("profile", "") == profile
			and prior.get("batch_nonce", "") == OS.get_environment("P19_BATCH_NONCE")
			and prior.get("content_version", "") == trusted.content_version
			and prior.observations.after_cfg.sha256 == FileAccess.get_sha256("user://campaign.cfg"),
			"repeat uses exact preceding first-full process/report/closed CFG"): finish(); return
	else:
		if not check(not FileAccess.file_exists("user://campaign.cfg")
			and not DirAccess.dir_exists_absolute("user://campaign_cfg_transactions/v1")
			and not DirAccess.dir_exists_absolute("user://continue/v1"), "case begins in a fresh actual business profile"): finish(); return
		if index not in [0, 8, 13]:
			if not _seed_private_campaign_fixture(): finish(); return
	if index == 13:
		var typed_array: Array[String] = ["known", "future"]
		var typed_dict: Dictionary[String, Vector2] = {"position":Vector2(2.25, -3.5)}
		if not _seed_private_campaign_fixture({"vector":Vector2(1.25, -2.5), "transform":Transform3D.IDENTITY, "projection":Projection.IDENTITY,
			"bytes":PackedByteArray([1,128,255]), "integers":PackedInt64Array([9223372036854775807]),
			"vectors":PackedVector4Array([Vector4(1,2,3,4)]), "colors":PackedColorArray([Color(0.1,0.2,0.3)]),
			"typed_array":typed_array, "typed_dict":typed_dict, "string_name":&"future_name", "node_path":NodePath("root/child"),
			"nan":NAN, "inf":INF, "negative_zero":-0.0}): finish(); return
		var original := ConfigFile.new()
		if not check(original.load("user://campaign.cfg") == OK, "actual legal-variant seed load"): finish(); return
		observations.unknown_semantics_before = Values.semantics(original)
	if index == 6:
		var file: FileAccess = FileAccess.open("user://campaign.cfg", FileAccess.WRITE)
		if not check(file != null, "owned malformed fixture opens"): finish(); return
		file.store_string("[broken")
		file.flush()
		var write_error: Error = file.get_error()
		file.close()
		if not check(write_error == OK, "actual malformed CFG closed before gate"): finish(); return
	if index in [5, 17, 18]:
		cloud.set_process(false); cloud.dirty = false; cloud._pending_upload = false
		if index in [5, 18]: cloud._owner = CLOUD_OWNER
		if index == 17: cloud._applying = true
	if index == 16:
		get_tree().root.remove_child(cloud)
		counter = LocalCloudCounter.new(); counter.name = "SteamCloud"; get_tree().root.add_child(counter)
	before_memory = memory(); before_cfg = file_state("user://campaign.cfg")
	observations.before_memory = before_memory.duplicate(true); observations.before_cfg = before_cfg.duplicate(true)
	observations.before_business = business(); observations.cloud_before = cloud_snapshot()
	if not await gate(): finish(); return
	if index in [0, 1, 2, 16, 17]: normal_cases()
	elif index == 3: invalid_case()
	elif index in [4, 5]: qa_case()
	elif index in [6, 7, 8, 9, 10, 11, 12]: fault_cases()
	elif index == 13:
		result = run_recovery(GOALS)
		if check(result.ok, "actual supported-Variant transaction commits"):
			var fresh := ConfigFile.new()
			if check(fresh.load("user://campaign.cfg") == OK, "fresh actual persisted legal-Variant load"):
				var semantics: Dictionary = Values.semantics(fresh)
				check(semantics.ok and semantics.sections["future]section"] == observations.unknown_semantics_before.sections["future]section"],
					"every unknown key retains actual per-value ConfigFile semantics")
	elif index in [14, 15]: unsupported_cases()
	else: cloud_failure()
	finish()
