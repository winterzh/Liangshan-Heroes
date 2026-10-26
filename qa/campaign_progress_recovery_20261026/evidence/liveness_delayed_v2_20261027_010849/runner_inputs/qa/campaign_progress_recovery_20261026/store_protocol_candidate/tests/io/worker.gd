extends Node
## Candidate-only native files through the actual Store/Ledger APIs. Synthetic account
## and outcome fixtures qualify local transactions only, never SDK/gameplay.
const Ledger := preload("res://scripts/steam_run_ledger.gd")
const Store := preload("res://scripts/steam_receipt_store.gd")
const Receipt := preload("res://scripts/steam_run_receipt.gd")
const Catalog := preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const ROOT_PATH := "user://steam_receipts/v1"
const CONTEXT := {"mode":"campaign", "level_id":"level4", "waves":0}
var mode := ""
var output := ""
var nonce := ""
var profile := ""
var identity: Dictionary = {}
var checks: Array = []
var evidence: Dictionary = {}
var gate_index := 0

func _ready() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks.append({"label":label, "passed":condition})
	print("STORE_PROTOCOL_IO ", "PASS " if condition else "FAIL ", label)
	return condition

func write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "\t")); file.flush(); file.close()
	return true

func blank() -> Dictionary:
	var stats := {}; var unlocked := {}
	for key in Catalog.STATS: stats[key] = 0
	for row in Catalog.entries(): unlocked[row.id] = false
	return {"stats":stats, "unlocked":unlocked}

func descriptor(captured: Dictionary, token: String) -> Dictionary:
	return {"schema":"campaign_steam_handoff_v1", "owner":OWNER, "token":token,
		"context":CONTEXT.duplicate(), "intent_sha256":"a".repeat(64),
		"correction_epoch":captured.record.correction_epoch, "basis_generation":captured.record.generation,
		"basis_sha256":captured.file_sha256, "basis_credited_kills":5, "final_credited_kills":8,
		"victory":true, "result":{"core_cleared":true, "story_complete":true, "story_done":4,
			"story_total":4, "done_ids":["lhm_training","lhm_hooks","lhm_han","lhm_hu"], "contract_version":2}}

func gate(kind: String, directory: String) -> bool:
	var index := gate_index; gate_index += 1
	var request := {"schema":"handoff_io_gate_v1", "index":index, "kind":kind, "mode":mode,
		"nonce":nonce, "pid":OS.get_process_id(), "owner":OWNER, "directory":directory}
	if not check(write_json(output.path_join("request_%02d.json" % index), request), "write controller request"): return false
	var path := output.path_join("ack_%02d.json" % index)
	var deadline := Time.get_ticks_msec() + 45000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not check(FileAccess.file_exists(path), "bounded controller handshake"): return false
	var ack: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(ack) == TYPE_DICTIONARY and ack.get("nonce") == nonce \
		and ack.get("pid") == OS.get_process_id() and ack.get("index") == index, "controller handshake identity"): return false
	# Existing debugger protocol needs ordinary main-loop polling before the API.
	await get_tree().create_timer(0.2).timeout
	return true

func verify_handoff(ledger: RefCounted, handoff: Dictionary, before: Dictionary) -> bool:
	var durable: Dictionary = ledger.capture()
	if not check(durable.ok, "ledger durable capture after handoff"): return false
	var independent := Store.new(OWNER, ROOT_PATH)
	var head: Dictionary = independent.open_head()
	if not check(head.ok, "independent native Store reads closed head"): return false
	check(head.document == durable.record and head.file_sha256 == durable.file_sha256, "model matches independent on-disk document and SHA")
	check(durable.record.generation == before.record.generation + 1, "one handoff adds exactly one generation")
	check(durable.record.stats.TOTAL_KILLS == 8 and durable.record.stats.TOTAL_WINS == 1, "one final kill delta and one win persisted")
	check(durable.record.unlocked.ACH_CLEAR_LEVEL_4 and durable.record.unlocked.ACH_STORY_LEVEL_4, "clear and full-story fixture awards are persisted")
	check(durable.record.runs[handoff.token].terminal_reason == "settled" \
		and durable.record.runs[handoff.token].credited_kills == 8, "terminal source and final kills persisted")
	var normalized: Dictionary = Receipt.new().normalize_campaign_handoff(handoff)
	if not check(normalized.ok, "frozen descriptor still has strict canonical shape"): return false
	var proof: Dictionary = ledger.campaign_handoff_proof(handoff)
	var expected := {"schema":"campaign_steam_handoff_proof_v1", "owner":OWNER, "token":handoff.token,
		"context":CONTEXT.duplicate(), "intent_sha256":handoff.intent_sha256,
		"descriptor_sha256":JSON.stringify(normalized.handoff).sha256_text(), "correction_epoch":0,
		"ledger_document_generation":durable.record.generation, "ledger_file_sha256":head.file_sha256}
	check(proof == {"ok":true, "code":"CAMPAIGN_HANDOFF_READBACK_VERIFIED", "proof":expected}, "exact nine-field disk proof and fixed outer envelope")
	var inventory: Dictionary = independent.inventory()
	var duplicate: Dictionary = ledger.apply_campaign_handoff(handoff)
	check(duplicate == proof and ledger.capture() == durable and independent.inventory() == inventory, "duplicate handoff is exact proof with no file or counter mutation")
	var conflict: Dictionary = handoff.duplicate(true); conflict.intent_sha256 = "c".repeat(64)
	check(not ledger.apply_campaign_handoff(conflict).ok and independent.inventory() == inventory, "different intent cannot use terminal shortcut")
	evidence["proof"] = proof; evidence["durable"] = durable; evidence["inventory"] = inventory
	return true

func normal_or_fault() -> void:
	var ledger := Ledger.new(); var targets := blank()
	var opened: Dictionary = ledger.open(OWNER, targets.stats, targets.unlocked, ROOT_PATH)
	evidence["opened"] = opened.duplicate(true)
	evidence["open_physics_frame"] = Engine.is_in_physics_frame()
	if not check(opened.ok, "open new synthetic ledger at fixed production root: " + String(opened.get("code", "OK"))): return
	var begun: Dictionary = ledger.begin_run(CONTEXT)
	if not check(begun.ok, "ordinary ledger begin creates synthetic local token"): return
	if not check(ledger.progress(begun.token, CONTEXT, 5).ok, "ordinary progress persists five eligible fixture kills"): return
	var before: Dictionary = ledger.capture()
	var handoff := descriptor(before, begun.token)
	var prepared := {"schema":"handoff_io_prepared_v1", "nonce":nonce, "pid":OS.get_process_id(), "mode":mode,
		"owner":OWNER, "synthetic_account_and_token":true, "directory":ledger._store.directory,
		"handoff":handoff, "before":before, "identity":identity, "profile":profile}
	if not check(write_json(output.path_join("prepared.json"), prepared), "persist pre-fault descriptor and basis outside ledger"): return
	evidence["prepared"] = prepared
	if mode != "normal":
		if not await gate(mode, ledger._store.directory): return
	var applied: Dictionary = ledger.apply_campaign_handoff(handoff)
	evidence["applied"] = applied.duplicate(true)
	evidence["pending_after_apply"] = ledger.pending_status()
	evidence["inventory_after_apply"] = ledger._store.inventory()
	if mode.begins_with("crash_"):
		check(false, "external controller must terminate original PID at selected native boundary"); return
	if mode in ["write_retry", "rename_writing_retry", "rename_owner_retry", "cleanup_delete_retry", "marker_delete_retry"]:
		var expected_code := "WRITE_OPEN" if mode == "write_retry" else ("RENAME" if mode in ["rename_writing_retry", "rename_owner_retry"] else "LOCK_RELEASE")
		if not check(not applied.ok and applied.get("code") == expected_code, "real native file operation fails at requested boundary"): return
		var pending: Dictionary = ledger.pending_status()
		var proposal: Dictionary = ledger._pending.proposal.duplicate(true)
		var retained_store: RefCounted = ledger._store
		var expected_revision: int = ledger._pending.expected_revision
		var expected_sha256: String = ledger._pending.expected_sha256
		evidence["failure"] = applied; evidence["pending"] = pending; evidence["original_proposal"] = proposal
		check(pending.pending and pending.kind == "handoff" and pending.handoff == handoff \
			and pending.owned_lock and not pending.unsafe, "same ledger retains exact handoff and owned retry")
		if mode != "write_retry":
			if not verify_release_failure(ledger._store): return
		var changed: Dictionary = handoff.duplicate(true); changed.intent_sha256 = "c".repeat(64)
		check(not ledger.retry_campaign_handoff(changed).ok and ledger._pending.proposal == proposal \
			and ledger._pending.expected_revision == expected_revision and ledger._pending.expected_sha256 == expected_sha256,
			"foreign retry cannot replace original proposal or CAS")
		if not await gate("release_fault", ledger._store.directory): return
		check(ledger._store == retained_store and ledger._pending.proposal == proposal \
			and ledger._pending.expected_revision == expected_revision and ledger._pending.expected_sha256 == expected_sha256,
			"native handle repair retains same Store object, original proposal and original CAS")
		applied = ledger.retry_campaign_handoff(handoff)
		evidence["retried"] = applied.duplicate(true)
		check(not ledger.pending_status().get("pending",true), "owned retry completes and clears pending")
		if applied.ok:
			check(ledger.capture().record == proposal.record, "disk commits original retained proposal exactly")
	if not check(applied.ok, "campaign handoff returns verified durable proof: " + String(applied.get("code", "OK"))): return
	verify_handoff(ledger, handoff, before)

func record_items(inventory: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for key: String in inventory:
		if key.begins_with("record_") and key.ends_with(".json"): records[key] = inventory[key]
	return records

func protocol_owner_sha(plan: Dictionary) -> String:
	var source: Dictionary = plan.source
	var key: String = source.name + "/owner.json" if plan.kind == "cleanup" else source.name
	return String(plan.inventory.get(key, ""))

func verify_release_failure(store: RefCounted) -> bool:
	var inv: Dictionary = store.inventory()
	if not check(inv.ok, "failed release leaves an enumerable native inventory"): return false
	var cleanup: Array[String] = []; var markers: Array[String] = []
	for key: String in inv.items:
		if key.begins_with("cleanup_v1_") and key.ends_with("/"): cleanup.append(key)
		if key.begins_with("release_v1_"): markers.append(key)
	evidence["release_failure_inventory"] = inv
	if mode == "rename_writing_retry":
		return check(inv.items.has("writing/") and inv.items.has("writing/owner.json") \
			and cleanup.is_empty() and markers.is_empty(), "rejected writing rename preserves original fixed owner directory")
	if not check(not inv.items.has("writing/") and not inv.items.has("recovering/") \
		and not inv.items.has("receipt.pending"), "unique release failure has no fixed lock or pending journal"): return false
	if mode == "rename_owner_retry":
		return check(cleanup.size() == 1 and markers.is_empty() and inv.items.has(cleanup[0] + "owner.json"),
			"rejected owner rename preserves owner bytes inside the unique cleanup")
	if not check(markers.size() == 1, "delete refusal preserves exactly one release marker"): return false
	if mode == "cleanup_delete_retry":
		return check(cleanup.size() == 1 and not inv.items.has(cleanup[0] + "owner.json"),
			"rejected cleanup deletion preserves empty unique directory and marker")
	return check(cleanup.is_empty(), "rejected marker deletion preserves marker after unique directory removal")

func legacy_upgrade() -> void:
	var targets := blank(); var model := Receipt.new()
	if not check(model.create(OWNER, targets.stats, targets.unlocked).ok, "construct explicit synthetic legacy fixture"): return
	var legacy: Dictionary = model.capture(); legacy.version = 2; legacy.erase("correction_epoch")
	var strict := Receipt.new()
	if not check(strict.open_record(legacy, OWNER).ok and strict.capture() == legacy, "legacy fixture passes unchanged strict v2 reader"): return
	var store := Store.new(OWNER, ROOT_PATH)
	if not check(store.initialize_directory().ok, "initialize native legacy account directory"): return
	var empty: Dictionary = store.acquire()
	if not check(empty.ok and empty.revision == 0, "acquire empty legacy journal"): return
	var seed: Dictionary = store.commit_locked(0, empty.file_sha256, {"record":legacy, "sha256":JSON.stringify(legacy).sha256_text()})
	if not check(seed.ok and store.release().ok, "write canonical v2 envelope with actual Store API"): return
	var original: Dictionary = store.inventory()
	var ledger := Ledger.new()
	var opened: Dictionary = ledger.open(OWNER, {}, {}, ROOT_PATH, true)
	if not check(opened.ok and opened.get("upgrade_required",false), "ledger identifies existing v2 without implicit upgrade"): return
	check(ledger.capture().record == legacy and store.inventory() == original, "opening v2 preserves original native chain")
	check(ledger.begin_run(CONTEXT).get("code") == "RECEIPT_UPGRADE_REQUIRED" and store.inventory() == original, "v2 write refuses before explicit upgrade")
	if not check(ledger.upgrade().ok, "explicit upgrade commits through native ledger transaction"): return
	var current: Dictionary = ledger.capture()
	var head: Dictionary = store.open_head()
	check(current.record.version == 3 and current.record.generation == legacy.generation + 1 \
		and current.record.stats == legacy.stats and current.record.unlocked == legacy.unlocked, "upgrade adds one generation and preserves targets")
	check(head.previous == seed.file_sha256 and FileAccess.get_sha256(store.directory.path_join("record_0000000001.json")) == seed.file_sha256, "v3 links to original v2 file SHA and original bytes remain")
	var upgraded_inventory: Dictionary = store.inventory()
	check(ledger.upgrade().ok and store.inventory() == upgraded_inventory, "repeat upgrade is native-file no-op")
	evidence = {"legacy":legacy, "seed":seed, "original_inventory":original, "upgraded":current, "inventory":upgraded_inventory}

func recover_crash() -> void:
	var path := OS.get_environment("SP_PREVIOUS")
	if not check(FileAccess.get_sha256(path) == OS.get_environment("SP_PREVIOUS_SHA256"), "predecessor evidence pin"): return
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(previous) == TYPE_DICTIONARY and previous.get("schema") == "handoff_io_prepared_v1" \
		and previous.get("nonce") == nonce and previous.get("profile") == profile \
		and previous.get("identity") == identity and previous.get("owner") == OWNER \
		and int(previous.get("pid",0)) > 0 and int(previous.get("pid",0)) != OS.get_process_id() \
		and not OS.is_process_running(int(previous.get("pid",0))), "same profile and identity with predecessor PID terminal"): return
	var origin_writer_pid: int = int(previous.get("origin_writer_pid", previous.pid))
	var origin_mode: String = String(previous.get("origin_mode", previous.mode))
	if not check(origin_writer_pid > 0 and origin_writer_pid != OS.get_process_id() \
		and not OS.is_process_running(origin_writer_pid), "original writer PID is also terminal"): return
	var store := Store.new(OWNER, ROOT_PATH)
	if not check(store.directory == previous.directory, "recovery uses original account directory"): return
	var inventory: Dictionary = store.inventory()
	if not check(inventory.ok, "recovery reads actual residue inventory"): return
	var plan: Dictionary = store.inspect_recovery()
	evidence = {"previous":previous, "before_inventory":inventory, "recovery_plan":plan,
		"origin_writer_pid":origin_writer_pid, "origin_mode":origin_mode}
	var is_unique: bool = origin_mode in ["crash_cleanup", "crash_marker", "crash_cleanup_removed"]
	if is_unique:
		if not check(plan.ok and plan.get("protocol") == "steam_unique_release_v1" \
			and plan.get("action") == "finish_unique_release" and not plan.get("owned",true),
			"dead unique release exposes its exact unowned protocol recovery plan"): return
		var expected_kind := "cleanup" if origin_mode == "crash_cleanup" else "release"
		if not check(plan.kind == expected_kind and plan.dead_pid == origin_writer_pid \
			and int(plan.source.metadata.pid) == origin_writer_pid and plan.source.claim_pid == int(previous.pid),
			"unique source binds original owner PID and most recent dead claimant PID"): return
		if not check(plan.inventory == inventory.items and not plan.inventory.has("receipt.pending") \
			and not plan.inventory.has("writing/") and not plan.inventory.has("recovering/"),
			"unique recovery inventory is exact and excludes fixed locks and pending"): return
		if plan.kind == "cleanup":
			if not check(plan.inventory.has(plan.source.name + "/") and plan.inventory.has(plan.source.name + "/owner.json"),
				"cleanup-claimed crash retains its unique directory and original owner file"): return
		else:
			if not check(plan.inventory.has(plan.source.cleanup + "/") == (origin_mode == "crash_marker") \
				and not plan.inventory.has(plan.source.cleanup + "/owner.json"),
				"marker crash layout matches whether its bound cleanup directory has already been removed"): return
		var owner_path: String = store.directory.path_join(plan.source.name)
		if plan.kind == "cleanup": owner_path = owner_path.path_join("owner.json")
		if not check(FileAccess.get_file_as_string(owner_path) == plan.source.raw \
			and FileAccess.get_sha256(owner_path) == protocol_owner_sha(plan) \
			and plan.source.raw.sha256_text() == protocol_owner_sha(plan),
			"original owner bytes and file SHA agree with independently read source"): return
		if previous.mode == "recover_claim_crash":
			if not check(previous.has_all(["claim_plan","origin_owner_raw","origin_owner_sha256","origin_record_inventory","predecessor_pid"]),
				"dead recovery claimant persisted its predecessor and original source evidence"): return
			var earlier: Dictionary = previous.claim_plan
			if not check(int(previous.predecessor_pid) == origin_writer_pid \
				and plan.source.name != earlier.source.name and plan.source.claim_nonce != earlier.source.claim_nonce \
				and plan.kind == earlier.kind and plan.source.raw == previous.origin_owner_raw \
				and protocol_owner_sha(plan) == previous.origin_owner_sha256 \
				and plan.source.metadata == earlier.source.metadata,
				"third process sees a fresh claimed nonce and unchanged original owner identity and bytes"): return
			if not check(record_items(plan.inventory) == previous.origin_record_inventory \
				and plan.head_revision == earlier.head_revision and plan.head_sha256 == earlier.head_sha256,
				"recovery claimant death preserves every record SHA and exact head"): return
			if plan.kind == "release":
				if not check(plan.source.cleanup == earlier.source.cleanup \
					and plan.source.cleanup_pid == earlier.source.cleanup_pid and plan.source.cleanup_nonce == earlier.source.cleanup_nonce,
					"marker re-claim retains its original cleanup binding"): return
	if mode == "recover_claim_crash":
		if not check(is_unique and previous.mode in ["crash_cleanup","crash_marker"], "bounded second claimant stage starts at a supported unique source"): return
		var prepared: Dictionary = previous.duplicate(true)
		prepared["pid"] = OS.get_process_id(); prepared["mode"] = mode
		prepared["origin_writer_pid"] = origin_writer_pid; prepared["origin_mode"] = origin_mode
		prepared["predecessor_pid"] = int(previous.pid); prepared["claim_plan"] = plan.duplicate(true)
		prepared["origin_owner_raw"] = plan.source.raw
		prepared["origin_owner_sha256"] = protocol_owner_sha(plan)
		prepared["origin_record_inventory"] = record_items(plan.inventory)
		if not check(write_json(output.path_join("prepared.json"), prepared), "persist claimant lineage and original owner and record evidence before claim"): return
		evidence["prepared"] = prepared
		if not await gate("recover_claim_crash", store.directory): return
		var recovered: Dictionary = store.recover(plan)
		evidence["unexpected_recovered"] = recovered
		check(false, "external controller must terminate second PID at unique_release_recovery_claimed")
		return
	var ledger := Ledger.new()
	var opened: Dictionary = ledger.open(OWNER, {}, {}, ROOT_PATH, true)
	evidence["opened"] = opened
	if origin_mode == "crash_half":
		check(not plan.ok and plan.get("code") == "ENVELOPE_JSON" and not opened.ok and opened.get("code") == "ENVELOPE_JSON", "half-pending native crash residue fails closed with precise reason")
		check(store.inventory() == inventory and not ledger.campaign_handoff_proof(previous.handoff).ok, "blocked recovery preserves residue and grants no proof")
		evidence["expected_blocked_diagnostic"] = true
		return
	if origin_mode == "crash_marker_removed":
		if not check(not plan.ok and plan.get("code") == "UNKNOWN_OR_MISSING_LOCK" \
			and record_items(inventory.items) == inventory.items and opened.ok,
			"marker-removed crash is a clean journal that opens without a recovery plan"): return
	else:
		if not check(plan.ok and plan.dead_pid == origin_writer_pid and opened.ok, "real dead-PID recovery succeeds"): return
		var action := "finish_unique_release" if is_unique else ("forward_pending" if origin_mode == "crash_pending" else "release_committed_lock")
		check(plan.action == action, "native recovery chooses expected action")
	if is_unique or origin_mode == "crash_marker_removed":
		var after_inventory: Dictionary = store.inventory()
		if not check(after_inventory.ok and after_inventory.items == record_items(inventory.items),
			"unique completion removes only protocol residue and preserves every committed record SHA"): return
		var clean_head: Dictionary = store.open_head()
		if not check(clean_head.ok, "completed release permits an independent clean head read"): return
		if is_unique:
			if not check(clean_head.revision == plan.head_revision and clean_head.file_sha256 == plan.head_sha256,
				"unique completion does not advance or rewrite the committed head"): return
	verify_handoff(ledger, previous.handoff, previous.before)

func run() -> void:
	mode = OS.get_environment("SP_MODE"); output = OS.get_environment("SP_OUTPUT"); nonce = OS.get_environment("SP_NONCE")
	profile = OS.get_environment("SP_PROFILE")
	var normalized := profile.replace("\\", "/").simplify_path()
	var safe := normalized.is_absolute_path() and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and nonce.length() == 32
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == normalized.path_join(key.to_lower()).to_lower()
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	safe = safe and project.to_lower() == OS.get_environment("SP_PROJECT").replace("\\", "/").to_lower()
	safe = safe and ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower().begins_with(normalized.to_lower() + "/")
	if not check(safe, "private profile, fixed source project, SDK disabled"): finish(); return
	var resolved: Dictionary = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if not check(resolved.get("ok",false) and resolved.get("source_mode",false), "actual installed candidate source identity"): finish(); return
	identity = {"content_version":resolved.content_version, "engine_sha256":resolved.engine_binary_sha256, "source_mode":true}
	# A deferred _ready callback can still be in the initial physics phase.
	# Real persistence APIs require an ordinary process frame, as production does.
	for frame in range(4):
		if not Engine.is_in_physics_frame(): break
		await get_tree().process_frame
	if not check(not Engine.is_in_physics_frame(), "native transactions run outside the physics frame"): finish(); return
	if mode == "legacy_upgrade": legacy_upgrade()
	elif mode in ["recover","recover_claim_crash"]: await recover_crash()
	elif mode in ["normal","write_retry","rename_writing_retry","rename_owner_retry","cleanup_delete_retry","marker_delete_retry", \
		"crash_half","crash_pending","crash_record","crash_cleanup","crash_marker","crash_cleanup_removed","crash_marker_removed"]:
		await normal_or_fault()
	else: check(false, "known IO mode")
	finish()

func finish() -> void:
	var failures: Array = []
	for row in checks:
		if not row.passed: failures.append(row.label)
	var report := {"schema":"campaign_handoff_native_io_v1", "mode":mode, "passed":failures.is_empty(),
		"checks":checks, "failures":failures, "evidence":evidence, "identity":identity,
		"pid":OS.get_process_id(), "nonce":nonce, "profile":profile, "actual_user_dir":OS.get_user_data_dir(),
		"synthetic_account_and_token":true, "owner":OWNER, "sdk_or_real_account_qualified":false,
		"gameplay_or_power_loss_qualified":false, "production_root":ROOT_PATH}
	var saved := write_json(output.path_join("report.json"), report)
	get_tree().quit(0 if saved and failures.is_empty() else 1)
