extends Node
## Native two-process ordering fixture. A uses Ledger; B uses Store + Receipt.
## The controller pauses unmodified source statements through the debugger.
const Ledger := preload("res://scripts/steam_run_ledger.gd")
const Store := preload("res://scripts/steam_receipt_store.gd")
const Receipt := preload("res://scripts/steam_run_receipt.gd")
const Catalog := preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const ROOT_PATH := "user://steam_receipts/v1"
const CONTEXT := {"mode":"campaign", "level_id":"level4", "waves":0}
var mode := ""
var case_name := ""
var expected := "fixed"
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
	checks.append({"label":label,"passed":condition})
	print("DELAYED_IO ", "PASS " if condition else "FAIL ", label)
	return condition

func write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "\t")); file.flush()
	var okay: bool = file.get_error() == OK
	file.close()
	return okay

func gate(kind: String, directory: String) -> bool:
	var index := gate_index; gate_index += 1
	var request := {"schema":"handoff_delayed_gate_v1","index":index,"kind":kind,"mode":mode,
		"case":case_name,"nonce":nonce,"pid":OS.get_process_id(),"owner":OWNER,"directory":directory}
	if not check(write_json(output.path_join("request_%02d.json" % index),request),"write controller gate " + kind): return false
	var path: String = output.path_join("ack_%02d.json" % index)
	var deadline: int = Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not check(FileAccess.file_exists(path),"bounded controller gate " + kind): return false
	var ack: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(ack) == TYPE_DICTIONARY and ack.get("nonce") == nonce \
		and ack.get("pid") == OS.get_process_id() and ack.get("index") == index,"controller gate identity " + kind): return false
	await get_tree().create_timer(0.2).timeout
	return true

func blank() -> Dictionary:
	var stats := {}; var unlocked := {}
	for key in Catalog.STATS: stats[key] = 0
	for row in Catalog.entries(): unlocked[row.id] = false
	return {"stats":stats,"unlocked":unlocked}

func descriptor(captured: Dictionary, token: String) -> Dictionary:
	return {"schema":"campaign_steam_handoff_v1","owner":OWNER,"token":token,
		"context":CONTEXT.duplicate(),"intent_sha256":"a".repeat(64),
		"correction_epoch":captured.record.correction_epoch,"basis_generation":captured.record.generation,
		"basis_sha256":captured.file_sha256,"basis_credited_kills":5,"final_credited_kills":8,
		"victory":true,"result":{"core_cleared":true,"story_complete":true,"story_done":4,
			"story_total":4,"done_ids":["lhm_training","lhm_hooks","lhm_han","lhm_hu"],"contract_version":2}}

func records(items: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in items:
		if key.begins_with("record_") and key.ends_with(".json"): result[key] = items[key]
	return result

func head_bytes(store: RefCounted, head: Dictionary) -> String:
	return FileAccess.get_file_as_string(store.directory.path_join("record_%010d.json" % int(head.revision)))

func pending_scope(ledger: RefCounted) -> Dictionary:
	return {"expected_revision":ledger._pending.expected_revision,"expected_sha256":ledger._pending.expected_sha256,
		"proposal":ledger._pending.proposal.duplicate(true)}

func observed_a(ledger: RefCounted, result: Dictionary, frozen: Dictionary) -> Dictionary:
	return {"schema":"handoff_delayed_a_observation_v1","mode":mode,"case":case_name,"expected":expected,
		"pid":OS.get_process_id(),"nonce":nonce,"profile":profile,"identity":identity,
		"result":result.duplicate(true),"pending":ledger.pending_status(),"scope":pending_scope(ledger),
		"frozen_scope":frozen,"commit_attempted":ledger._pending.commit_attempted,
		"store_instance_id":ledger._store.get_instance_id(),"owner_raw":ledger._store._lock_raw,
		"inventory":ledger._store.inventory(),"chain":ledger._store._chain()}

func preserved_rewards(head: Dictionary, token: String, original: Dictionary) -> bool:
	return check(head.document.stats == original.stats and head.document.unlocked == original.unlocked \
		and head.document.stats.TOTAL_KILLS == 5 and head.document.stats.TOTAL_WINS == 0 \
		and head.document.runs[token] == original.runs[token] and not head.document.runs[token].terminal,
		"A original handoff remains unapplied: original rewards and active run are unchanged")

func writer_a() -> void:
	var ledger := Ledger.new(); var targets := blank()
	var opened: Dictionary = ledger.open(OWNER,targets.stats,targets.unlocked,ROOT_PATH)
	if not check(opened.ok,"A opens a new real Ledger in the shared private profile"): return
	var begun: Dictionary = ledger.begin_run(CONTEXT)
	if not check(begun.ok,"A begins its real locally generated run"): return
	if not check(ledger.progress(begun.token,CONTEXT,5).ok,"A persists five credited fixture kills"): return
	var before: Dictionary = ledger.capture()
	if not check(before.ok,"A captures the original durable handoff basis"): return
	var handoff: Dictionary = descriptor(before,begun.token)
	# A separate model prepares an observation only; the real Ledger prepares its own proposal.
	var observer := Receipt.new()
	if not check(observer.open_record(before.record,OWNER).ok,"observer opens the original typed receipt"): return
	var proposal: Dictionary = observer.prepare_campaign_handoff(handoff)
	if not check(proposal.ok and proposal.changed,"observer derives the frozen handoff proposal without writing"): return
	var frozen := {"expected_revision":int(ledger._head.revision),"expected_sha256":before.file_sha256,
		"proposal":{"record":proposal.record.duplicate(true),"sha256":proposal.sha256}}
	var retained_store: RefCounted = ledger._store
	var prepared := {"schema":"handoff_delayed_prepared_v1","pid":OS.get_process_id(),"mode":mode,
		"case":case_name,"expected":expected,"nonce":nonce,"profile":profile,"identity":identity,
		"owner":OWNER,"directory":ledger._store.directory,"handoff":handoff,"before":before,
		"frozen_scope":frozen,"store_instance_id":retained_store.get_instance_id(),"synthetic_account_and_token":true}
	if not check(write_json(output.path_join("prepared.json"),prepared),"A saves original basis and proposal before apply"): return
	evidence["prepared"] = prepared
	if not await gate("a_apply",ledger._store.directory): return
	var applied: Dictionary = ledger.apply_campaign_handoff(handoff)
	if not check(not applied.ok and applied.get("code") == "WRITER_BUSY" \
		and applied.get("retryable",false) and not applied.get("unsafe",true),"delayed A acquire is blocked by the real B release barrier"): return
	if not check(ledger._store == retained_store and pending_scope(ledger) == frozen \
		and ledger._pending.phase == "commit" and not ledger._pending.commit_attempted \
		and ledger._store._locked and ledger._store._lock_created,"blocked acquire retains exact Store, proposal and CAS before first commit attempt"): return
	var blocked: Dictionary = observed_a(ledger,applied,frozen)
	if not check(blocked.inventory.ok and blocked.inventory.items.has("writing/owner.json") \
		and not blocked.inventory.items.has("receipt.pending") \
		and FileAccess.get_file_as_string(ledger._store.directory.path_join("writing/owner.json")) == ledger._store._lock_raw,
		"A barrier stop preserves its actual owner file and creates no pending journal"): return
	var b_head: Dictionary = blocked.chain
	if not check(b_head.ok and b_head.revision == frozen.expected_revision + 1 \
		and b_head.previous == before.file_sha256,"B has committed exactly one newer head while A retains its old CAS"): return
	if not preserved_rewards(b_head,begun.token,before.record): return
	var b_raw: String = head_bytes(ledger._store,b_head)
	if not check(b_raw.sha256_text() == b_head.file_sha256,"A independently reads exact B committed envelope bytes"): return
	var owner_raw: String = ledger._store._lock_raw
	blocked["b_record_raw"] = b_raw
	if not check(write_json(output.path_join("a_blocked.json"),blocked),"A saves real blocked-acquire evidence"): return
	evidence["blocked"] = blocked
	if not await gate("a_retry",ledger._store.directory): return
	if case_name == "retry_under_barrier":
		var barrier_retry: Dictionary = ledger.retry_campaign_handoff(handoff)
		if not check(not barrier_retry.ok and barrier_retry.get("code") == "WRITER_BUSY" \
			and barrier_retry.get("retryable",false) and not barrier_retry.get("unsafe",true),"first A retry while B is paused remains retryable WRITER_BUSY"): return
		if not check(ledger._store == retained_store and pending_scope(ledger) == frozen \
			and ledger._pending.commit_attempted and ledger._store._lock_raw == owner_raw,
			"barrier retry keeps original owner, Store, proposal and CAS and records the commit attempt"): return
		var retry_observation: Dictionary = observed_a(ledger,barrier_retry,frozen)
		if not check(retry_observation.chain == b_head and head_bytes(ledger._store,b_head) == b_raw \
			and retry_observation.inventory.ok and not retry_observation.inventory.items.has("receipt.pending") \
			and FileAccess.get_file_as_string(ledger._store.directory.path_join("writing/owner.json")) == owner_raw,
			"retry under barrier writes no journal or reward change"): return
		if not check(write_json(output.path_join("barrier_retry.json"),retry_observation),"A saves barrier retry evidence"): return
		evidence["barrier_retry"] = retry_observation
		if not await gate("a_final_retry",ledger._store.directory): return
	var retried: Dictionary = ledger.retry_campaign_handoff(handoff)
	var final_observation: Dictionary = observed_a(ledger,retried,frozen)
	evidence["final"] = final_observation
	if not check(ledger._store == retained_store and pending_scope(ledger) == frozen,"final retry retains the original Store and frozen proposal/CAS"): return
	if expected == "defects":
		if not check(case_name == "first_after_clear" and not retried.ok and retried.get("code") == "CAS_CHANGED" \
			and retried.get("unsafe",false) and retried.get("restart_required",false),"known old first-retry CAS_CHANGED defect is reproduced"): return
		if not check(ledger._store._locked and ledger._store._lock_created \
			and final_observation.inventory.items.has("writing/owner.json") \
			and FileAccess.get_file_as_string(ledger._store.directory.path_join("writing/owner.json")) == owner_raw,
			"known defect leaves the original live A writing owner lock in place"): return
		final_observation["known_defect_reproduced"] = true
	else:
		if not check(not retried.ok and retried.get("code") == "OWNED_HEAD_CHANGED" \
			and retried.get("own_stale_lock_released",false) and retried.get("unsafe",false) \
			and retried.get("restart_required",false),"stale A retry explicitly releases its own lock before requiring restart"): return
		if not check(not ledger._store._locked and not ledger._store._lock_created \
			and final_observation.inventory.ok and final_observation.inventory.items == records(final_observation.inventory.items),
			"stale abort removes writing, cleanup and marker residue"): return
		var independent := Store.new(OWNER,ROOT_PATH)
		var clean: Dictionary = independent.open_head()
		if not check(clean == b_head and head_bytes(independent,clean) == b_raw,"independent clean Store head remains exactly B committed bytes"): return
		var restarted := Ledger.new()
		var restarted_open: Dictionary = restarted.open(OWNER,{}, {},ROOT_PATH,true)
		if not check(restarted_open.ok,"a new real Ledger opens after A releases its stale lock"): return
		var restarted_capture: Dictionary = restarted.capture()
		if not check(restarted_capture.ok and restarted_capture.record == b_head.document \
			and restarted_capture.file_sha256 == b_head.file_sha256 and head_bytes(independent,clean) == b_raw,
			"new Ledger reads B exact durable record without applying A old proposal"): return
		if not preserved_rewards(clean,begun.token,before.record): return
		final_observation["restarted_open"] = restarted_open
		final_observation["restarted_capture"] = restarted_capture
	if not check(final_observation.chain == b_head and head_bytes(ledger._store,b_head) == b_raw,
		"final A result preserves every byte of B committed head"): return
	if not check(write_json(output.path_join("a_result.json"),final_observation),"A saves final ordering result"): return
	if not await gate("a_verified",ledger._store.directory): return

func writer_b() -> void:
	var path: String = OS.get_environment("DA_PREVIOUS")
	if not check(FileAccess.get_sha256(path) == OS.get_environment("DA_PREVIOUS_SHA256"),"B verifies original A prepared evidence pin"): return
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(typeof(previous) == TYPE_DICTIONARY and previous.get("schema") == "handoff_delayed_prepared_v1" \
		and previous.get("nonce") == nonce and previous.get("profile") == profile and previous.get("identity") == identity \
		and previous.get("case") == case_name and previous.get("expected") == expected and previous.get("owner") == OWNER \
		and int(previous.get("pid",0)) > 0 and int(previous.pid) != OS.get_process_id() \
		and OS.is_process_running(int(previous.pid)),"B shares the exact private profile and identity with live A"): return
	var store := Store.new(OWNER,ROOT_PATH)
	if not check(store.directory == previous.directory,"B uses A original account directory"): return
	var original: Dictionary = store.open_head()
	if not check(original.ok and original.file_sha256 == previous.before.file_sha256 \
		and original.revision == int(previous.frozen_scope.expected_revision),"B reads the original A basis before claiming its own lock"): return
	var model := Receipt.new()
	if not check(model.open_record(original.document,OWNER).ok,"B opens the real Receipt model from the native head"): return
	if not await gate("b_begin",store.directory): return
	var acquired: Dictionary = store.acquire()
	if not check(acquired.ok and acquired == original,"B acquires the original head through the real Store"): return
	var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var proposal: Dictionary = model.prepare_begin(token,CONTEXT)
	if not check(proposal.ok and proposal.changed,"B prepares an ordinary new Receipt run with a real random token"): return
	var committed: Dictionary = store.commit_locked(original.revision,original.file_sha256,{"record":proposal.record,"sha256":proposal.sha256})
	if not check(committed.ok and model.commit(committed.document,proposal.sha256).ok,"B commits the exact ordinary begin proposal with native Store and Receipt"): return
	var released: Dictionary = store.release()
	if not check(released.ok,"B finishes its unique release while delayed A retains fixed writing"): return
	var chain: Dictionary = store._chain()
	var inv: Dictionary = store.inventory()
	if not check(chain == committed and inv.ok and inv.items.has("writing/owner.json"),"B committed record survives while A live writing is kept distinct"): return
	var owner_path: String = store.directory.path_join("writing/owner.json")
	var owner_raw: String = FileAccess.get_file_as_string(owner_path)
	var owner: Variant = JSON.parse_string(owner_raw)
	if not check(typeof(owner) == TYPE_DICTIONARY and int(owner.get("pid",0)) == int(previous.pid) \
		and owner.get("owner") == OWNER,"B release preserved A actual owner identity"): return
	var raw: String = head_bytes(store,committed)
	if not check(raw.sha256_text() == committed.file_sha256,"B retains its exact committed envelope bytes"): return
	var receipt := {"schema":"handoff_delayed_b_committed_v1","mode":mode,"case":case_name,"expected":expected,
		"pid":OS.get_process_id(),"nonce":nonce,"profile":profile,"identity":identity,"owner":OWNER,
		"directory":store.directory,"committed_head":committed,"record":model.capture(),"proposal":proposal,
		"token":token,"record_raw":raw,"writing_owner_raw":owner_raw,"writing_owner_sha256":FileAccess.get_sha256(owner_path),
		"inventory":inv,"a_pid":int(previous.pid),"fixture_api":"Store+Receipt; B does not claim Ledger.begin success"}
	if not check(write_json(output.path_join("b_committed.json"),receipt),"B persists its native transaction evidence before waiting for A"): return
	evidence["committed"] = receipt
	if not await gate("b_done",store.directory): return
	var independent := Store.new(OWNER,ROOT_PATH)
	var final: Dictionary = independent.open_head()
	var final_inventory: Dictionary = independent.inventory()
	if expected == "defects":
		check(not final.ok and final.get("code") == "RECOVERY_REQUIRED" and OS.is_process_running(int(previous.pid)) \
			and final_inventory.ok and final_inventory.items.has("writing/owner.json") \
			and FileAccess.get_file_as_string(owner_path) == owner_raw,
			"B confirms known defect retains live A lock and cannot be called clean recovery")
		check(independent._chain() == committed and head_bytes(independent,committed) == raw,"known defect preserves B record despite retaining A lock")
	else:
		check(final == committed and final_inventory.ok and final_inventory.items == records(inv.items) \
			and head_bytes(independent,committed) == raw,"B independently verifies A cleanup leaves exactly its original committed records")
	evidence["final_head"] = final; evidence["final_inventory"] = final_inventory

func run() -> void:
	mode = OS.get_environment("DA_MODE"); case_name = OS.get_environment("DA_CASE")
	expected = OS.get_environment("DA_EXPECT")
	if expected.is_empty(): expected = "fixed"
	output = OS.get_environment("DA_OUTPUT"); nonce = OS.get_environment("DA_NONCE"); profile = OS.get_environment("DA_PROFILE")
	var normalized: String = profile.replace("\\","/").simplify_path()
	var safe: bool = normalized.is_absolute_path() and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and nonce.length() == 32
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		safe = safe and OS.get_environment(key).replace("\\","/").simplify_path().to_lower() == normalized.path_join(key.to_lower()).to_lower()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\","/").trim_suffix("/")
	safe = safe and project.to_lower() == OS.get_environment("DA_PROJECT").replace("\\","/").trim_suffix("/").to_lower()
	safe = safe and ProjectSettings.globalize_path("user://").replace("\\","/").to_lower().begins_with(normalized.to_lower() + "/")
	if not check(safe,"private shared profile, fixed source project and disabled SDK"): finish(); return
	if not check(mode in ["A","B"] and case_name in ["first_after_clear","retry_under_barrier"] \
		and expected in ["fixed","defects"] and (expected != "defects" or case_name == "first_after_clear"),"known bounded mode, ordering and expectation"): finish(); return
	var resolved: Dictionary = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	if not check(resolved.get("ok",false) and resolved.get("source_mode",false),"actual installed candidate source identity"): finish(); return
	identity = {"content_version":resolved.content_version,"engine_sha256":resolved.engine_binary_sha256,"source_mode":true}
	for frame in range(4):
		if not Engine.is_in_physics_frame(): break
		await get_tree().process_frame
	if not check(not Engine.is_in_physics_frame(),"native transactions run outside physics frame"): finish(); return
	if mode == "A": await writer_a()
	else: await writer_b()
	finish()

func finish() -> void:
	var failures: Array = []
	for row in checks:
		if not row.passed: failures.append(row.label)
	var passed: bool = failures.is_empty()
	var report := {"schema":"handoff_delayed_io_v1","mode":mode,"case":case_name,"expected":expected,"passed":passed,
		"slice_passed":passed and expected == "fixed","diagnostic_only":expected == "defects","production_qualified":false,
		"checks":checks,"failures":failures,"evidence":evidence,"identity":identity,"pid":OS.get_process_id(),
		"nonce":nonce,"profile":profile,"actual_user_dir":OS.get_user_data_dir(),"owner":OWNER,"production_root":ROOT_PATH,
		"synthetic_account_and_token":true,"sdk_or_real_account_qualified":false,"gameplay_or_power_loss_qualified":false,
		"fixture_api":"Ledger A; Store+Receipt B","workers":OS.get_environment("DA_WORKERS")}
	var saved: bool = write_json(output.path_join("report.json"),report)
	get_tree().quit(0 if saved and passed else 1)
