extends SceneTree
## Native PRIVATE user directory only. Fake confirmation authority is defined
## exclusively here; production has no available write confirmation provider.
const Queue = preload("res://scripts/steam_persistent_outbox.gd")
const State = preload("res://scripts/steam_persistent_outbox_state.gd")
const Ledger = preload("res://scripts/steam_run_ledger.gd")
const Catalog = preload("res://scripts/steam_achievement_catalog.gd")
const OWNER := "76561198000000001"
const OTHER := "76561198000000002"
const DEFENSE := {"mode": "defense", "level_id": "", "waves": 30}

class FaultPoint:
	static func hit(name: String) -> void:
		if OS.get_environment("OUTBOX_STOP") != name: return
		var file := FileAccess.open("res://checkpoint.json", FileAccess.WRITE)
		if file == null: return
		file.store_string(JSON.stringify({"name": name, "pid": OS.get_process_id()}))
		file.flush(); file.close()
		while true: OS.delay_msec(20)

class FaultStore extends "res://scripts/steam_persistent_outbox_store.gd":
	func _checkpoint(name: String) -> void: FaultPoint.hit(name)

class VerifiedFakeQueue extends "res://scripts/steam_persistent_outbox.gd":
	var authority_root := ""
	func _persist(next: Dictionary) -> Dictionary:
		# Independent pre-write witness: the parent validates its transition against
		# the seeded document and fixed checkpoint oracle BEFORE launching recovery.
		var file := FileAccess.open("res://transaction_plan.json", FileAccess.WRITE)
		if file == null: return _bad("FIXTURE_PLAN_WRITE")
		file.store_string(JSON.stringify({"pid": OS.get_process_id(), "previous": _document, "next": next}))
		file.flush(); file.close()
		return super._persist(next)
	func _new_store(account: String, root_path: String) -> RefCounted:
		return FaultStore.new(account, root_path)
	func _checkpoint(name: String) -> void: FaultPoint.hit(name)
	func confirmation_capability() -> Dictionary:
		return {"ok": true, "authority": "private-fixture-signed-write", "production_blocked": true, "synthetic": true}
	func _verify_server_write_proof(proof: Dictionary, _intent: Dictionary) -> Dictionary:
		if proof.authority != "private-fixture-signed-write": return _bad("UNTRUSTED_AUTHORITY")
		var path := authority_root.path_join(proof.intent + ".json")
		if not FileAccess.file_exists(path): return _bad("NO_SERVER_EVIDENCE")
		var raw := FileAccess.get_file_as_string(path)
		if raw != JSON.stringify(proof): return _bad("SERVER_EVIDENCE_MISMATCH")
		var unsigned := proof.duplicate(true)
		unsigned.erase("evidence")
		if proof.evidence != ("test-only-private-authority-key:" + JSON.stringify(unsigned)).sha256_text(): return _bad("BAD_SERVER_SIGNATURE")
		return {"ok": true, "synthetic": true}

var checks: Array = []
var details := {}
var queue: RefCounted
var ledger: RefCounted
var case_root := ""

func check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})

func initial_stats(kills := 0) -> Dictionary:
	return {"TOTAL_KILLS": kills, "TOTAL_WINS": 0, "DEFENSE_WINS": 0, "AI_WINS": 0}

func initial_unlocks() -> Dictionary:
	var value := {}
	for entry in Catalog.entries(): value[entry.id] = false
	return value

func enqueue_latest() -> Dictionary:
	var captured: Dictionary = ledger.capture()
	if not captured.ok: return captured
	return queue.enqueue_receipt(captured.record, captured.file_sha256)

func first_run() -> String:
	return ledger.capture().record.runs.keys()[0]

func fake_send(targets: Dictionary) -> Dictionary:
	var loaded: Dictionary = queue._store.open_head()
	check("SDK marker fully read after unlock", loaded.ok and loaded.file_sha256 == targets.marker_sha256)
	var found := false
	if loaded.ok:
		for intent in loaded.document.intents:
			if intent.id == targets.intent:
				found = intent.state == "uncertain" and intent.targets_sha256 == targets.targets_sha256 and intent.stats == targets.stats and intent.unlocked == targets.unlocked
	check("SDK exact intent persisted before mutation", found)
	if not found: return {}
	var proof := {"version": 1, "app": Queue.APP, "owner": OWNER, "intent": targets.intent, "generation": targets.generation, "targets_sha256": targets.targets_sha256, "authority": "private-fixture-signed-write"}
	proof["evidence"] = ("test-only-private-authority-key:" + JSON.stringify(proof)).sha256_text()
	var confirmed_by_fake_server := OS.get_environment("OUTBOX_MODE") != "result8"
	if confirmed_by_fake_server:
		var proof_file := FileAccess.open(queue.authority_root.path_join(targets.intent + ".json"), FileAccess.WRITE)
		if proof_file == null: check("fake authority writes", false); return {}
		proof_file.store_string(JSON.stringify(proof)); proof_file.flush(); proof_file.close()
	var trace := case_root.path_join("sdk.jsonl")
	var file := FileAccess.open(trace, FileAccess.READ_WRITE if FileAccess.file_exists(trace) else FileAccess.WRITE)
	if file == null: check("fake SDK trace writes", false); return {}
	file.seek_end()
	var marker_path: String = queue._store.directory.path_join("record_%010d.json" % int(loaded.revision))
	var marker_raw := FileAccess.get_file_as_string(marker_path)
	file.store_line(JSON.stringify({"pid": OS.get_process_id(), "targets": targets, "proof": proof, "confirmation_issued": confirmed_by_fake_server, "marker_raw": marker_raw}))
	file.flush(); file.close()
	return proof

func staged_send() -> Dictionary:
	var staged: Dictionary = queue.stage_next()
	check("intent stage persists", staged.ok)
	if not staged.ok: return {}
	FaultPoint.hit("before_sdk")
	var targets: Dictionary = queue.take_sdk_targets(OWNER, staged.intent)
	check("owned targets issued", targets.ok)
	if not targets.ok: return {}
	check("targets cannot issue twice", not queue.take_sdk_targets(OWNER, staged.intent).ok)
	var proof := fake_send(targets)
	FaultPoint.hit("after_sdk")
	return proof

func _init() -> void:
	var mode := OS.get_environment("OUTBOX_MODE")
	var name := OS.get_environment("OUTBOX_CASE")
	if not name.is_valid_identifier(): quit(2); return
	var private_profile_ok := OS.get_user_data_dir().replace("\\", "/") == OS.get_environment("OUTBOX_EXPECTED_PROFILE")
	check("private user profile", private_profile_ok)
	if not private_profile_ok:
		print("PRIVATE_PROFILE_REQUIRED")
		quit(2); return # Before every mkdir/store/open or report write.
	case_root = "user://outbox_qa/" + name
	queue = VerifiedFakeQueue.new()
	queue.authority_root = case_root.path_join("fake_authority")
	DirAccess.make_dir_recursive_absolute(queue.authority_root)
	ledger = Ledger.new()
	if mode != "recover":
		check("live ledger opens", ledger.open(OWNER, initial_stats(), initial_unlocks(), case_root.path_join("ledger")).ok)
	var opened: Dictionary = queue.open(OWNER, case_root.path_join("queue"))
	if mode == "recover" and OS.get_environment("OUTBOX_EXPECT_BLOCKED") == "1":
		check("half pending remains blocked with exact cause", not opened.ok and opened.code == "ENVELOPE_JSON")
		var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("OUTBOX_RECOVERY_EXPECTATION")))
		var normalized := State.validate(expected.document, OWNER)
		var committed: Dictionary = queue._store._chain()
		check("half pending preserves exact prior complete document", committed.ok and normalized.ok and committed.document == normalized.document)
		details.opened = opened
		details.before = committed.document if committed.ok else {}
		finish(mode); return
	check("queue opens", opened.ok)
	if not opened.ok: details.opened = opened; finish(mode); return
	if mode in ["seed", "contract"]:
		var begun: Dictionary = ledger.begin_run(DEFENSE)
		check("first trusted run durable", begun.ok)
		check("first progress durable", ledger.progress(begun.token, DEFENSE, 20).ok)
		check("first intent durable", enqueue_latest().ok)
		if mode == "contract": contract()
	elif mode == "enqueue":
		check("next local progress survives queue crash", ledger.progress(first_run(), DEFENSE, 21).ok)
		details.enqueued = enqueue_latest()
		check("next intent persists", details.enqueued.ok)
	elif mode == "stage":
		details.proof = staged_send()
	elif mode in ["confirm", "result8"]:
		var stop := OS.get_environment("OUTBOX_STOP")
		OS.set_environment("OUTBOX_STOP", "")
		var proof := staged_send()
		OS.set_environment("OUTBOX_STOP", stop)
		FaultPoint.hit("before_notification")
		var result: Dictionary = queue.confirm_intent(proof) if mode == "confirm" else queue.observe_store_notification(Queue.APP, OWNER, 8)
		check("notification persistence", result.ok)
	elif mode == "recover": recover_case()
	else: check("known fixture mode", false)
	finish(mode)

func contract() -> void:
	var baseline: Dictionary = queue.capture()
	var production := Queue.new()
	check("production queue opens same durable account", production.open(OWNER, case_root.path_join("queue")).ok)
	check("production writes explicitly blocked", production.stage_next().code == "WRITE_CONFIRMATION_UNPROVEN")
	check("production confirmation explicitly blocked", production.confirm_intent({"result": 1}).code == "WRITE_CONFIRMATION_UNPROVEN")
	check("read operation handles never acknowledge writes", production.observe_read_snapshot({"owner": OWNER, "handle": "ffffffffffffffff", "source": "requested_user_cache", "stats": initial_stats(20)}).code == "READ_IS_NOT_WRITE_CONFIRMATION")
	check("success notification not proof", production.observe_store_notification(Queue.APP, OWNER, 1).code == "NOT_A_WRITE_CONFIRMATION")
	check("unsupported authority leaves durable bytes unchanged", production.capture().file_sha256 == baseline.file_sha256)
	check("same generation deduplicates", enqueue_latest().code == "ALREADY_QUEUED")
	var a := staged_send()
	check("new local progress while A waits", ledger.progress(first_run(), DEFENSE, 21).ok and enqueue_latest().ok)
	var waiting: Dictionary = queue.capture()
	check("two generations retained", waiting.document.intents.size() == 2 and waiting.pending == 2)
	check("timeout keeps all bytes", queue.observe_timeout().ok and queue.capture().file_sha256 == waiting.file_sha256)
	check("late success cannot acknowledge A or B", queue.observe_store_notification(Queue.APP, OWNER, 1).ok and queue.capture().file_sha256 == waiting.file_sha256)
	check("second dispatch waits for actual proof", queue.stage_next().code == "OUTSTANDING_UNCONFIRMED")
	check("A signed fixture proof retires A only", queue.confirm_intent(a).ok and queue.capture().pending == 1)
	var b := staged_send()
	var b_waiting: Dictionary = queue.capture()
	check("A late proof cannot clear B", queue.confirm_intent(a).code == "ALREADY_CONFIRMED" and queue.capture().file_sha256 == b_waiting.file_sha256)
	var forged: Dictionary = a.duplicate(true)
	for key in ["intent", "generation", "targets_sha256"]: forged[key] = b[key]
	check("A proof cannot be rebound to B", not queue.confirm_intent(forged).ok and queue.capture().file_sha256 == b_waiting.file_sha256)
	check("B independent proof confirmed", queue.confirm_intent(b).ok and queue.capture().pending == 0)
	var b_reloaded: Dictionary = JSON.parse_string(JSON.stringify(b))
	check("JSON float proof canonicalizes to prior confirmation", queue.confirm_intent(b_reloaded).code == "ALREADY_CONFIRMED")
	for field in ["version", "app", "generation"]:
		var fractional: Dictionary = b_reloaded.duplicate(true)
		fractional[field] = float(fractional[field]) + 0.5
		check("fractional proof field rejected " + field, not queue.confirm_intent(fractional).ok)
	var second: Dictionary = ledger.begin_run(DEFENSE)
	check("second run continuous in same process", second.ok and ledger.progress(second.token, DEFENSE, 7).ok and ledger.settle(second.token, DEFENSE, true, {}).ok)
	check("second run result queued", enqueue_latest().ok)
	var c := staged_send()
	check("third independent batch same process confirmed", queue.confirm_intent(c).ok and queue.capture().pending == 0)
	var source_for_regression: Dictionary = ledger.capture()
	for regression in ["stat", "achievement"]:
		var guarded := Queue.new()
		check("regression queue opens " + regression, guarded.open(OWNER, case_root.path_join("regression_" + regression)).ok)
		check("regression baseline queued " + regression, guarded.enqueue_receipt(source_for_regression.record, source_for_regression.file_sha256).ok)
		var lowered: Dictionary = source_for_regression.record.duplicate(true)
		lowered.generation += 1
		if regression == "stat": lowered.stats.TOTAL_KILLS -= 1
		else: lowered.unlocked.ACH_DEFENSE_30 = false
		var old_intents: Array = guarded.capture().document.intents
		var rejected_lower: Dictionary = guarded.enqueue_receipt(lowered, "f".repeat(64))
		check("newer generation cannot lower " + regression, not rejected_lower.ok and rejected_lower.code == "NONMONOTONIC_REQUIRES_CORRECTION" and rejected_lower.barrier_persisted)
		check("regression retains original intent " + regression, guarded.capture().document.correction_required and guarded.capture().document.intents == old_intents)
	var wrong: Dictionary = c.duplicate(true)
	wrong.owner = OTHER
	check("other account proof rejected", not queue.confirm_intent(wrong).ok)
	var separate := Queue.new()
	check("account directories isolated", separate.open(OTHER, case_root.path_join("queue")).ok and separate.capture().document.intents.is_empty())
	var third: Dictionary = ledger.begin_run(DEFENSE)
	check("next pending run queued", third.ok and ledger.progress(third.token, DEFENSE, 1).ok and enqueue_latest().ok)
	var rejected := staged_send()
	var before8: Dictionary = queue.capture().document
	check("result8 persists blocking flag", queue.observe_store_notification(Queue.APP, OWNER, 8).ok)
	check("result8 retains exact old intent targets", queue.capture().document.intents == before8.intents)
	check("result8 blocks even a formerly valid proof", not queue.confirm_intent(rejected).ok)
	check("result8 prevents subsequent writes", queue.stage_next().code == "CORRECTION_UNRESOLVED")
	check("ledger independently invalidates", ledger.invalidate(OWNER).ok)
	var read_generation: int = ledger.capture().record.generation
	check("ledger exact correction remains 7", ledger.correct(OWNER, initial_stats(7), initial_unlocks(), read_generation).ok)
	var before_lower: Array = queue.capture().document.intents
	check("lower correction cannot automatically replace pending intents", enqueue_latest().code == "NONMONOTONIC_REQUIRES_CORRECTION" and ledger.capture().record.stats.TOTAL_KILLS == 7)
	check("old rejected targets never overwrite correction", queue.capture().document.intents == before_lower and queue.capture().document.intents[-1].state == "uncertain")
	var healthy: Dictionary = queue.capture().document
	for field in ["owner", "revision", "intents"]:
		var invalid := healthy.duplicate(true)
		invalid.erase(field)
		check("missing schema field " + field, not State.validate(invalid, OWNER).ok)
	var malformed := healthy.duplicate(true)
	malformed.intents[0].stats.TOTAL_KILLS = true
	check("bool counters rejected", not State.validate(malformed, OWNER).ok)
	for later_state in ["confirmed", "uncertain"]:
		var impossible: Dictionary = healthy.duplicate(true)
		impossible.intents.resize(2)
		impossible.intents[0].state = "queued"
		impossible.intents[0].confirmation_sha256 = ""
		impossible.intents[1].state = later_state
		impossible.intents[1].confirmation_sha256 = "a".repeat(64) if later_state == "confirmed" else ""
		check("schema rejects queued before " + later_state, State.validate(impossible, OWNER).code == "INTENT_STATE_ORDER")
	for regression in ["stat", "achievement"]:
		var lowered: Dictionary = healthy.duplicate(true)
		lowered.intents.resize(2)
		if regression == "stat": lowered.intents[1].stats.TOTAL_KILLS = lowered.intents[0].stats.TOTAL_KILLS - 1
		else:
			lowered.intents[0].unlocked.ACH_DEFENSE_30 = true
			lowered.intents[0].targets_sha256 = State.target_digest(lowered.intents[0].stats, lowered.intents[0].unlocked)
			lowered.intents[1].unlocked.ACH_DEFENSE_30 = false
		lowered.intents[1].targets_sha256 = State.target_digest(lowered.intents[1].stats, lowered.intents[1].unlocked)
		check("schema rejects read-side target regression " + regression, not State.validate(lowered, OWNER).ok)
	check("wrong owner cannot enqueue", not queue.enqueue_receipt(separate.capture().document, "0".repeat(64)).ok)
	# A stale owner cannot append after another queue advanced the CAS head.
	check("stale queue notices CAS advancement", not production.capture().ok)

func recover_case() -> void:
	var before: Dictionary = queue.capture()
	details.before = before.document
	var expectation_path := OS.get_environment("OUTBOX_RECOVERY_EXPECTATION")
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(expectation_path))
	var normalized := State.validate(expected.document, OWNER) if typeof(expected) == TYPE_DICTIONARY and expected.has("document") else {"ok": false}
	var exact: bool = normalized.ok and before.document == normalized.document
	check("checkpoint exact complete durable document before proof or notification", exact)
	check("checkpoint exact first opened disk head revision", exact and int(queue._head.revision) == int(expected.document.revision))
	if not exact: details.expected = expected; return # Never re-confirm a rolled-back committed state.
	check("at least original intent retained", before.document.intents.size() >= 1)
	check("success after restart cannot retire intent", queue.observe_store_notification(Queue.APP, OWNER, 1).ok and queue.capture().file_sha256 == before.file_sha256)
	check("timeout after restart leaves bytes", queue.observe_timeout().ok and queue.capture().file_sha256 == before.file_sha256)
	for intent in before.document.intents:
		check("restart cannot replay SDK targets " + intent.id, not queue.take_sdk_targets(OWNER, intent.id).ok)
	if before.document.correction_required:
		check("result8 still blocks after restart", queue.stage_next().code == "CORRECTION_UNRESOLVED")
	else:
		for intent in before.document.intents:
			if intent.state != "uncertain": continue
			check("uncertain batch prevents next send", queue.stage_next().code == "OUTSTANDING_UNCONFIRMED")
			var proof_path: String = queue.authority_root.path_join(intent.id + ".json")
			if FileAccess.file_exists(proof_path):
				var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(proof_path))
				check("restart can verify existing independent server proof", queue.confirm_intent(proof).ok)
	details.after = queue.capture().document

func finish(mode: String) -> void:
	var failed := 0
	for row in checks:
		if not row.passed: failed += 1
	var report := {"suite": "steam-persistent-outbox", "mode": mode, "pid": OS.get_process_id(), "profile": OS.get_user_data_dir(), "passed": failed == 0, "failed": failed, "checks": checks, "details": details, "real_sdk": false, "production_confirmation_blocked": true}
	var file := FileAccess.open(OS.get_environment("OUTBOX_REPORT"), FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(report, "\t")); file.flush(); file.close()
	print("[steam persistent outbox QA] ", JSON.stringify(report))
	quit(0 if failed == 0 else 1)
