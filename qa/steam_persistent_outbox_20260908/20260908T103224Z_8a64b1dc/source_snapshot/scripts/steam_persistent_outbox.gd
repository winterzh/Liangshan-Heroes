extends RefCounted
## Persistent account intent queue. This class NEVER calls a Steam write API.
## Production confirmation capability is deliberately BLOCKED: a successful
## UserStatsStored_t, matching values or RequestUserStats handle proves no batch.
## Trusted future integrations may override the two protected capability methods
## only after proving exact server write identity; QA overrides live in tools/.
const State = preload("res://scripts/steam_persistent_outbox_state.gd")
const Receipt = preload("res://scripts/steam_run_receipt.gd")
const Store = preload("res://scripts/steam_persistent_outbox_store.gd")
const APP := 5088120
const PROOF_FIELDS := ["version", "app", "owner", "intent", "generation", "targets_sha256", "authority", "evidence"]
var _store: RefCounted
var _owner := ""
var _head: Dictionary = {}
var _document: Dictionary = {}
var _busy := false
var _fault := false
var _opened := false
var _rejection_notice := false
var _owned_intent := ""
var _issued := false

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _new_store(account: String, root_path: String) -> RefCounted:
	return Store.new(account, root_path)

func _checkpoint(_name: String) -> void:
	pass # Fixed no-op seam; native tests override without callback pumping.

func confirmation_capability() -> Dictionary:
	return {"ok": false, "code": "WRITE_CONFIRMATION_UNPROVEN", "production_blocked": true,
		"required": ["server_confirmation_bound_to_exact_write_intent", "app_and_owner", "generation_and_targets_sha256", "verifiable_evidence_independent_of_requested_user_cache"]}

func _verify_server_write_proof(_proof: Dictionary, _intent: Dictionary) -> Dictionary:
	return _bad("WRITE_CONFIRMATION_UNPROVEN")

func open(account: String, root_path := "user://steam_outbox/v1") -> Dictionary:
	if _store != null or _opened: return _bad("ALREADY_OPEN")
	_owner = account
	_store = _new_store(account, root_path)
	var initialized: Dictionary = _store.initialize_directory()
	if not initialized.ok: return initialized
	_head = _store.open_head()
	if not _head.ok and _head.code == "RECOVERY_REQUIRED":
		var plan: Dictionary = _store.inspect_recovery()
		if not plan.ok: return plan
		_head = _store.recover(plan)
	if not _head.ok: return _head
	if int(_head.revision) == 0:
		var initial := {"version": State.VERSION, "owner": account, "revision": 1, "correction_required": false, "intents": []}
		var saved := _persist(initial)
		if not saved.ok: return saved
	else:
		_document = _head.document.duplicate(true)
	_rejection_notice = _document.correction_required
	_opened = true
	return {"ok": true, "code": "OPENED", "confirmation": confirmation_capability(), "pending": _pending_count()}

func _fresh() -> bool:
	if not _opened or _busy or _fault: return false
	var current: Dictionary = _store.open_head()
	if not current.ok or current.revision != _head.revision or current.file_sha256 != _head.file_sha256:
		_fault = true
		return false
	return true

func _persist(next: Dictionary) -> Dictionary:
	if _busy or _fault: return _bad("BUSY_OR_FAULT")
	var checked := State.validate(next, _owner)
	if not checked.ok: return checked
	if int(checked.revision) != int(_head.revision) + 1: return _bad("REVISION_SEQUENCE")
	_busy = true
	var locked: Dictionary = _store.acquire()
	if not locked.ok: _busy = false; _fault = true; return locked
	if locked.revision != _head.revision or locked.file_sha256 != _head.file_sha256:
		_store.release()
		_busy = false
		_fault = true
		return _bad("HOST_CAS_CHANGED")
	var proposal := {"record": checked.document, "sha256": JSON.stringify(checked.document).sha256_text()}
	_checkpoint("prepared")
	var saved: Dictionary = _store.commit_locked(_head.revision, _head.file_sha256, proposal)
	if not saved.ok: _busy = false; _fault = true; return saved
	_checkpoint("disk_before_memory")
	_document = saved.document.duplicate(true)
	_head = saved
	_checkpoint("memory_before_unlock")
	var released: Dictionary = _store.release()
	_busy = false
	if not released.ok: _fault = true; return released
	return {"ok": true, "code": "PERSISTED", "revision": _head.revision}

func _next() -> Dictionary:
	var next := _document.duplicate(true)
	next.revision = int(_document.revision) + 1
	return next

func _pending_count() -> int:
	var count := 0
	for intent in _document.get("intents", []):
		if intent.state != "confirmed": count += 1
	return count

func capture() -> Dictionary:
	if not _fresh(): return _bad("NOT_READY")
	return {"ok": true, "document": _document.duplicate(true), "file_sha256": _head.file_sha256, "pending": _pending_count(), "confirmation": confirmation_capability()}

func enqueue_receipt(record: Variant, ledger_file_sha256: String) -> Dictionary:
	if not _fresh(): return _bad("NOT_READY")
	if not State.hex(ledger_file_sha256, 64): return _bad("LEDGER_DIGEST")
	var receipt := Receipt.new()
	var valid: Dictionary = receipt.open_record(record, _owner)
	if not valid.ok: return valid
	var source: Dictionary = receipt.capture()
	if source.requires_correction:
		var sealed := _mark_correction()
		return {"ok": false, "code": "RECEIPT_CORRECTION_REQUIRED", "barrier_persisted": sealed.ok}
	var digest: String = JSON.stringify(source).sha256_text()
	for intent in _document.intents:
		if int(intent.generation) == int(source.generation):
			if intent.receipt_sha256 != digest or intent.ledger_sha256 != ledger_file_sha256: return _bad("GENERATION_CONFLICT")
			return {"ok": true, "code": "ALREADY_QUEUED", "intent": intent.id, "changed": false}
	if not _document.intents.is_empty() and int(source.generation) < int(_document.intents[-1].generation): return _bad("SOURCE_REGRESSED")
	if not _document.intents.is_empty():
		var previous: Dictionary = _document.intents[-1]
		var regressed := false
		for name in previous.stats:
			if int(source.stats[name]) < int(previous.stats[name]): regressed = true
		for id in previous.unlocked:
			if previous.unlocked[id] and not source.unlocked[id]: regressed = true
		if regressed:
			var sealed := _mark_correction()
			return {"ok": false, "code": "NONMONOTONIC_REQUIRES_CORRECTION", "barrier_persisted": sealed.ok}
	# Finite first implementation: enqueue at reviewed publication/checkpoint
	# boundaries, not once per kill/frame/second. Capacity never discards intentions;
	# controlled compaction and unbounded continuous play are not implemented here.
	if _document.intents.size() >= State.MAX_INTENTS: return _bad("INTENT_CAPACITY")
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	var next := _next()
	next.intents.append({"id": id, "generation": source.generation, "receipt_sha256": digest, "ledger_sha256": ledger_file_sha256,
		"targets_sha256": State.target_digest(source.stats, source.unlocked), "stats": source.stats.duplicate(true), "unlocked": source.unlocked.duplicate(true), "state": "queued", "confirmation_sha256": ""})
	var saved := _persist(next)
	if saved.ok: saved["intent"] = id
	return saved

func stage_next() -> Dictionary:
	if not _fresh(): return _bad("NOT_READY")
	if _rejection_notice or _document.correction_required: return _bad("CORRECTION_UNRESOLVED")
	var capability := confirmation_capability()
	if not capability.ok: return capability
	var selected := -1
	for index in range(_document.intents.size()):
		if _document.intents[index].state == "uncertain": return _bad("OUTSTANDING_UNCONFIRMED")
		if selected < 0 and _document.intents[index].state == "queued": selected = index
	if selected < 0: return _bad("QUEUE_EMPTY")
	var next := _next()
	next.intents[selected].state = "uncertain"
	var saved := _persist(next)
	if not saved.ok: return saved
	_owned_intent = _document.intents[selected].id
	_issued = false
	return {"ok": true, "intent": _owned_intent, "revision": _head.revision}

func take_sdk_targets(live_account: String, intent_id: String) -> Dictionary:
	if live_account != _owner: return _bad("OWNER")
	if not _fresh(): return _bad("NOT_READY")
	if _rejection_notice or _document.correction_required: return _bad("CORRECTION_UNRESOLVED")
	var capability := confirmation_capability()
	if not capability.ok: return capability
	if _issued or _owned_intent.is_empty() or _owned_intent != intent_id: return _bad("NO_OWNED_UNISSUED_INTENT")
	for intent in _document.intents:
		if intent.id != intent_id: continue
		if intent.state != "uncertain": return _bad("INTENT_NOT_UNCERTAIN")
		_issued = true
		return {"ok": true, "app": APP, "owner": _owner, "intent": intent.id, "generation": intent.generation, "targets_sha256": intent.targets_sha256, "stats": intent.stats.duplicate(true), "unlocked": intent.unlocked.duplicate(true), "marker_sha256": _head.file_sha256}
	return _bad("UNKNOWN_INTENT")

func observe_store_notification(app: int, live_account: String, result: int) -> Dictionary:
	if app != APP or live_account != _owner: return _bad("NOTIFICATION_IDENTITY")
	if result == 8:
		_rejection_notice = true # Immediate live barrier even if persistence fails.
		return _mark_correction()
	if not _fresh(): return _bad("NOT_READY")
	return {"ok": true, "code": "NOT_A_WRITE_CONFIRMATION", "changed": false}

func _mark_correction() -> Dictionary:
	_rejection_notice = true
	if not _fresh(): return _bad("NOT_READY")
	if _document.correction_required: return {"ok": true, "code": "CORRECTION_UNRESOLVED", "changed": false}
	var next := _next()
	next.correction_required = true
	# Keep every intent and its original frozen values. Never overwrite the local
	# ledger or a newly corrected server snapshot with a rejected old absolute value.
	return _persist(next)

func observe_read_snapshot(snapshot: Variant) -> Dictionary:
	if not _fresh(): return _bad("NOT_READY")
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.get("owner") != _owner: return _bad("READ_IDENTITY")
	return {"ok": false, "code": "READ_IS_NOT_WRITE_CONFIRMATION", "changed": false}

func observe_timeout() -> Dictionary:
	if not _fresh(): return _bad("NOT_READY")
	return {"ok": true, "code": "UNCONFIRMED_INTENTS_RETAINED", "changed": false, "pending": _pending_count()}

func confirm_intent(proof: Variant) -> Dictionary:
	if not _fresh(): return _bad("NOT_READY")
	if _rejection_notice or _document.correction_required: return _bad("CORRECTION_UNRESOLVED")
	var capability := confirmation_capability()
	if not capability.ok: return capability
	if not State.keys(proof, PROOF_FIELDS): return _bad("PROOF_FIELDS")
	if not State.number(proof.version) or int(proof.version) != 1 or not State.number(proof.app) or int(proof.app) != APP or proof.owner != _owner: return _bad("PROOF_IDENTITY")
	if not State.hex(proof.intent, 32) or not State.number(proof.generation) or not State.hex(proof.targets_sha256, 64): return _bad("PROOF_BINDING")
	if typeof(proof.authority) != TYPE_STRING or proof.authority.is_empty() or proof.authority.length() > 128 or typeof(proof.evidence) != TYPE_STRING or proof.evidence.is_empty() or proof.evidence.length() > 4096: return _bad("PROOF_EVIDENCE")
	# Native JSON numbers become floats. Normalize only fields already proven
	# exact integers before signature validation/idempotence hashing across restarts.
	proof = proof.duplicate(true)
	for field in ["version", "app", "generation"]: proof[field] = int(proof[field])
	var selected := -1
	for index in range(_document.intents.size()):
		if _document.intents[index].id == proof.intent: selected = index; break
	if selected < 0: return _bad("UNKNOWN_INTENT")
	var intent: Dictionary = _document.intents[selected]
	if int(proof.generation) != int(intent.generation) or proof.targets_sha256 != intent.targets_sha256: return _bad("PROOF_BINDING")
	var digest: String = JSON.stringify(proof).sha256_text()
	if intent.state == "confirmed":
		return {"ok": true, "code": "ALREADY_CONFIRMED", "changed": false} if intent.confirmation_sha256 == digest else _bad("CONFLICTING_CONFIRMATION")
	if intent.state != "uncertain": return _bad("INTENT_NOT_UNCERTAIN")
	# A trusted future verifier must be synchronous, local and non-reentrant. Read
	# handles/result 1/matching values are intentionally absent from this interface.
	_busy = true
	var verified := _verify_server_write_proof(proof.duplicate(true), intent.duplicate(true))
	_busy = false
	if _fault or _rejection_notice: return _bad("VERIFICATION_SUPERSEDED")
	if not verified.ok: return verified
	var next := _next()
	next.intents[selected].state = "confirmed"
	next.intents[selected].confirmation_sha256 = digest
	var saved := _persist(next)
	if saved.ok and _owned_intent == intent.id: _owned_intent = ""; _issued = false
	return saved
