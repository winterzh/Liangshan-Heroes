extends Node
## Two real Ledgers. Only the external debugger pauses the actual acquire call.
## Process liveness is proved by the controller, never by Godot's foreign-PID API.
const Ledger := preload("res://scripts/steam_run_ledger.gd")
const Receipt := preload("res://scripts/steam_run_receipt.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Catalog := preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const ROOT_PATH := "user://steam_receipts/v1"
const CONTEXT := {"mode":"campaign", "level_id":"level4", "waves":0}
var mode := ""
var expected := ""
var output := ""
var nonce := ""
var profile := ""
var identity: Dictionary = {}
var checks: Array = []
var evidence: Dictionary = {}
var gate_index := 0
var completed := false

func _ready() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks.append({"label":label,"passed":condition})
	print("LIVE_OWNER ", "PASS " if condition else "FAIL ", label)
	return condition

func write_json(path: String, value: Dictionary) -> bool:
	if FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value,"\t")); file.flush()
	var okay: bool = file.get_error() == OK
	file.close()
	return okay

func gate(kind: String, directory: String) -> bool:
	var index := gate_index; gate_index += 1
	var request := {"schema":"live_owner_gate_v1","index":index,"kind":kind,"mode":mode,
		"case":"live_owner","nonce":nonce,"pid":OS.get_process_id(),"owner":OWNER,"directory":directory}
	if not check(write_json(output.path_join("request_%02d.json" % index),request),"publish gate " + kind): return false
	var path: String = output.path_join("ack_%02d.json" % index)
	var deadline: int = Time.get_ticks_msec() + 120000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not check(FileAccess.file_exists(path),"bounded gate " + kind): return false
	var ack: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(ack) == TYPE_DICTIONARY and ack.get("nonce") == nonce \
		and ack.get("pid") == OS.get_process_id() and ack.get("index") == index,"exact gate acknowledgement " + kind): return false
	await get_tree().create_timer(0.2).timeout
	return true

func blank() -> Dictionary:
	var stats := {}; var unlocked := {}
	for key in Catalog.STATS: stats[key] = 0
	for row in Catalog.entries(): unlocked[row.id] = false
	return {"stats":stats,"unlocked":unlocked}

func descriptor(before: Dictionary, token: String) -> Dictionary:
	return {"schema":"campaign_steam_handoff_v1","owner":OWNER,"token":token,
		"context":CONTEXT.duplicate(),"intent_sha256":"a".repeat(64),
		"correction_epoch":before.record.correction_epoch,"basis_generation":before.record.generation,
		"basis_sha256":before.file_sha256,"basis_credited_kills":5,"final_credited_kills":8,
		"victory":true,"result":{"core_cleared":true,"story_complete":true,"story_done":4,
			"story_total":4,"done_ids":["lhm_training","lhm_hooks","lhm_han","lhm_hu"],"contract_version":2}}

func scope(ledger: RefCounted) -> Dictionary:
	return {"expected_revision":ledger._pending.expected_revision,"expected_sha256":ledger._pending.expected_sha256,
		"proposal":ledger._pending.proposal.duplicate(true)}

func only_records(items: Dictionary) -> bool:
	for key: String in items:
		if not key.begins_with("record_") or not key.ends_with(".json"): return false
	return not items.is_empty()

func verify_fixed(ledger: RefCounted, before: Dictionary, handoff: Dictionary) -> bool:
	var durable: Dictionary = ledger.capture()
	if not check(durable.ok and durable.record.generation == before.record.generation + 1 \
		and durable.record.stats.TOTAL_KILLS == 8 and durable.record.stats.TOTAL_WINS == 1,
		"one original proposal persists one final kill delta and one win"): return false
	check(durable.record.unlocked.ACH_CLEAR_LEVEL_4 and durable.record.unlocked.ACH_STORY_LEVEL_4 \
		and durable.record.runs[handoff.token].terminal_reason == "settled", "fixture terminal awards and reason are durable")
	var normalized: Dictionary = Receipt.new().normalize_campaign_handoff(handoff)
	if not check(normalized.ok,"original handoff descriptor stays canonical"): return false
	var proof: Dictionary = ledger.campaign_handoff_proof(handoff)
	var wanted := {"schema":"campaign_steam_handoff_proof_v1","owner":OWNER,"token":handoff.token,
		"context":CONTEXT.duplicate(),"intent_sha256":handoff.intent_sha256,
		"descriptor_sha256":JSON.stringify(normalized.handoff).sha256_text(),"correction_epoch":before.record.correction_epoch,
		"ledger_document_generation":durable.record.generation,"ledger_file_sha256":durable.file_sha256}
	if not check(proof == {"ok":true,"code":"CAMPAIGN_HANDOFF_READBACK_VERIFIED","proof":wanted},"exact nine-field durable proof"): return false
	var inv: Dictionary = ledger._store.inventory()
	if not check(inv.ok and only_records(inv.items),"A release leaves only canonical records"): return false
	check(ledger.apply_campaign_handoff(handoff) == proof and ledger.capture() == durable \
		and ledger._store.inventory() == inv,"same handoff repeats proof without another reward or file mutation")
	evidence["durable"] = durable; evidence["proof"] = proof
	return true

func writer_a() -> void:
	var ledger := Ledger.new(); var targets := blank()
	if not check(ledger.open(OWNER,targets.stats,targets.unlocked,ROOT_PATH).ok,"A opens actual new Ledger"): return
	var begun: Dictionary = ledger.begin_run(CONTEXT)
	if not check(begun.ok and ledger.progress(begun.token,CONTEXT,5).ok,"A ordinary begin and progress persist five kills"): return
	var before: Dictionary = ledger.capture()
	if not check(before.ok,"A reads exact durable basis"): return
	var handoff: Dictionary = descriptor(before,begun.token)
	var observer := Receipt.new()
	if not check(observer.open_record(before.record,OWNER).ok,"read-only observer opens typed basis"): return
	var proposal: Dictionary = observer.prepare_campaign_handoff(handoff)
	if not check(proposal.ok and proposal.changed,"observer derives expected proposal without writing"): return
	var frozen := {"expected_revision":int(ledger._head.revision),"expected_sha256":before.file_sha256,
		"proposal":{"record":proposal.record.duplicate(true),"sha256":proposal.sha256}}
	var exact: Dictionary = Codec.new().encode({"before":before,"handoff":handoff,"frozen_scope":frozen})
	if not check(exact.ok,"predecessor keeps exact Variant types through Codec"): return
	var retained_store: RefCounted = ledger._store
	var prepared := {"schema":"live_owner_prepared_v1","mode":mode,"expected":expected,"pid":OS.get_process_id(),
		"nonce":nonce,"profile":profile,"identity":identity,"owner":OWNER,"directory":retained_store.directory,
		"store_instance_id":retained_store.get_instance_id(),"exact_fixture":exact.value,"before":before,"handoff":handoff}
	if not check(write_json(output.path_join("prepared.json"),prepared),"A writes immutable prepared evidence"): return
	if not await gate("a_apply",retained_store.directory): return
	# The controller pauses inside the unmodified Store.acquire at lock_acquired.
	var applied: Dictionary = ledger.apply_campaign_handoff(handoff)
	evidence["applied"] = applied; evidence["pending"] = ledger.pending_status()
	if expected == "defects":
		if not check(not applied.ok and applied.get("code") == "LOCK_CHANGED" and applied.get("unsafe",false) \
			and applied.get("restart_required",false),"actual live-lock deletion makes A LOCK_CHANGED and unsafe"): return
		if not check(ledger._store == retained_store and not ledger._pending.is_empty() and scope(ledger) == frozen \
			and ledger._pending.phase == "commit" and ledger._pending.commit_attempted and not ledger._pending.model_committed,
			"failed A retains original Store and uncommitted proposal/CAS"): return
		var inv: Dictionary = retained_store.inventory(); var head: Dictionary = retained_store._chain()
		if not check(inv.ok and only_records(inv.items) and head.ok and head.document == before.record \
			and head.file_sha256 == before.file_sha256,"deleted live lock leaves original records and no A reward"): return
		check(ledger.retry_campaign_handoff(handoff) == applied and scope(ledger) == frozen \
			and retained_store.inventory() == inv,"unsafe retry preserves original unsubmitted scope and disk")
		evidence["scope"] = scope(ledger); evidence["head"] = head
	else:
		if not check(applied.ok and ledger._store == retained_store,"A continues original transaction after B refuses recovery"): return
		if not verify_fixed(ledger,before,handoff): return
	if not check(write_json(output.path_join("a_result.json"),{"schema":"live_owner_a_result_v1","result":applied,
		"pid":OS.get_process_id(),"nonce":nonce,"expected":expected,"evidence":evidence}),"A publishes outcome evidence"): return
	if not await gate("a_verified",retained_store.directory): return
	completed = true

func writer_b() -> void:
	var previous := OS.get_environment("LO_PREVIOUS")
	if not check(FileAccess.get_sha256(previous) == OS.get_environment("LO_PREVIOUS_SHA256"),"B reads pinned A prepared bytes"): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(previous))
	if not check(typeof(value) == TYPE_DICTIONARY and value.get("schema") == "live_owner_prepared_v1" \
		and value.get("mode") == "A" and value.get("expected") == expected and value.get("nonce") == nonce \
		and value.get("profile") == profile and value.get("identity") == identity and value.get("owner") == OWNER \
		and int(value.get("pid",0)) > 0 and int(value.pid) != OS.get_process_id(),"B predecessor scope and typed-free identity match"): return
	var decoded: Dictionary = Codec.new().decode(value.get("exact_fixture",{}))
	if not check(decoded.ok and typeof(decoded.get("value")) == TYPE_DICTIONARY,"B decodes original typed fixture"): return
	var fixture: Dictionary = decoded.value
	var before: Dictionary = fixture.before; var handoff: Dictionary = fixture.handoff
	# B never asks OS.is_process_running about A. Its liveness comes from the host.
	if not await gate("b_open",value.directory): return
	var ledger := Ledger.new()
	var opened: Dictionary = ledger.open(OWNER,{}, {},ROOT_PATH,true)
	var retained_store: RefCounted = ledger._store
	var observations: Array = [opened.duplicate(true)]
	var deadline: int = Time.get_ticks_msec() + 15000
	while expected == "fixed" and opened.get("code") == "LIVENESS_PENDING" and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
		opened = ledger.retry_open()
		observations.append(opened.duplicate(true))
		if not check(ledger._store == retained_store,"liveness polling retains B original Store"): return
	evidence["open_observations"] = observations
	evidence["opened"] = opened; evidence["inventory_after_open"] = retained_store.inventory()
	evidence["previous_pid"] = int(value.pid)
	if not check(write_json(output.path_join("b_observed.json"),{"schema":"live_owner_b_observed_v1","pid":OS.get_process_id(),
		"nonce":nonce,"expected":expected,"result":opened,"inventory":evidence.inventory_after_open}),"B records actual automatic open/recovery result"): return
	if expected == "defects":
		if not check(opened.ok,"baseline B really opens by wrongly recovering A live lock"): return
		var captured: Dictionary = ledger.capture()
		if not check(captured.ok and captured.record == before.record and captured.file_sha256 == before.file_sha256,
			"B recovery does not invent A handoff reward"): return
	else:
		if not check(not opened.ok and opened.get("code") == "WRITER_ALIVE",
			"B explicitly refuses confirmed live writer; UNKNOWN or PENDING is not a pass"): return
	if not await gate("b_observed",retained_store.directory): return
	if expected == "fixed":
		if not check(ledger.retry_open().ok and ledger._store == retained_store,"B same Ledger/Store opens after A naturally finishes"): return
		if not verify_fixed(ledger,before,handoff): return
	else:
		var final: Dictionary = ledger.capture()
		if not check(final.ok and final.record == before.record and final.file_sha256 == before.file_sha256,
			"B independently confirms A unsafe failure leaves original durable bytes"): return
	completed = true

func run() -> void:
	mode = OS.get_environment("LO_MODE"); expected = OS.get_environment("LO_EXPECT")
	output = OS.get_environment("LO_OUTPUT"); nonce = OS.get_environment("LO_NONCE"); profile = OS.get_environment("LO_PROFILE")
	var normalized: String = profile.replace("\\","/").simplify_path()
	var safe: bool = normalized.is_absolute_path() and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and nonce.length() == 32 and nonce.is_valid_hex_number()
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and OS.get_environment(key).replace("\\","/").simplify_path().to_lower() == normalized.path_join(key.to_lower()).to_lower()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\","/").trim_suffix("/")
	safe = safe and project.to_lower() == OS.get_environment("LO_PROJECT").replace("\\","/").trim_suffix("/").to_lower()
	safe = safe and ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(normalized.path_join("appdata").to_lower() + "/")
	if not check(safe and mode in ["A","B"] and expected in ["defects","fixed"],"fixed source and four private profile roots"): finish(); return
	var resolved: Dictionary = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if not check(resolved.get("ok",false) and resolved.get("source_mode",false),"actual source identity resolved"): finish(); return
	identity = {"content_version":resolved.content_version,"engine_sha256":resolved.engine_binary_sha256,"source_mode":true}
	for frame in range(4):
		if not Engine.is_in_physics_frame(): break
		await get_tree().process_frame
	if not check(not Engine.is_in_physics_frame(),"start transactions outside physics frame"): finish(); return
	if mode == "A": await writer_a()
	else: await writer_b()
	finish()

func finish() -> void:
	var failures: Array = []
	for row in checks:
		if not row.passed: failures.append(row.label)
	var passed: bool = completed and failures.is_empty()
	var report := {"schema":"live_owner_worker_v1","mode":mode,"expected":expected,"passed":passed,
		"stage_completed":completed,"checks":checks,"failures":failures,"evidence":evidence,"identity":identity,
		"nonce":nonce,"pid":OS.get_process_id(),"profile":profile,"owner":OWNER,"production_root":ROOT_PATH,
		"actual_user_dir":OS.get_user_data_dir(),"workers":OS.get_environment("LO_WORKERS"),
		"diagnostic_only":expected == "defects","slice_passed":passed and expected == "fixed","production_qualified":false,
		"synthetic_account_and_token":true,"sdk_or_real_account_qualified":false,"fixture_api":"real Ledger A and B"}
	var saved: bool = write_json(output.path_join("report.json"),report)
	get_tree().quit(0 if saved and passed else 1)
