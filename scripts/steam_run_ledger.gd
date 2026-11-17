extends RefCounted
## Local receipt transaction owner. Internal integration API, not an SDK adapter.
## Caller supplies live account/trusted mode, never an owner or path from a slot.
const Receipt = preload("res://scripts/steam_run_receipt.gd")
const Store = preload("res://scripts/steam_receipt_store.gd")
var _store: RefCounted
var _model: RefCounted
var _head: Dictionary = {}
var _owner := ""
var _busy := false
var _fault := false
var _opened := false
var _pending: Dictionary = {}
var _open_scope: Dictionary = {}

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func open(account: String, initial_stats: Dictionary = {}, initial_unlocked: Dictionary = {}, root_path := "user://steam_receipts/v1", require_existing := false) -> Dictionary:
	if _opened or _store != null or not _open_scope.is_empty(): return _bad("ALREADY_OPEN")
	if Engine.is_in_physics_frame(): return _bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	_open_scope = {"account":account, "initial_stats":initial_stats.duplicate(true),
		"initial_unlocked":initial_unlocked.duplicate(true), "root_path":root_path, "require_existing":require_existing}
	_owner = account
	_store = Store.new(account, root_path)
	_open_scope["directory"] = _store.directory
	return retry_open()

func retry_open() -> Dictionary:
	if Engine.is_in_physics_frame(): return _bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	if _open_scope.is_empty() or _store == null or _owner != _open_scope.account \
		or _store.owner != _owner or _store.directory != _open_scope.directory: return _bad("OPEN_SCOPE_REQUIRED")
	if _busy or _fault: return _bad("BUSY_OR_FAULT")
	if _opened:
		if not _pending.is_empty(): return _bad("OPEN_COMPLETE_OTHER_WRITE_PENDING")
		return {"ok":true, "code":"ALREADY_OPENED", "generation":_model.capture().generation,
			"version":_model.capture().version, "upgrade_required":_model.capture().version != Receipt.VERSION}
	if not _pending.is_empty():
		if not _pending.creating: return _bad("OPEN_PENDING_KIND_CHANGED")
		return retry_pending()
	if _open_scope.require_existing and not DirAccess.dir_exists_absolute(_store.directory): return _bad("CAMPAIGN_LEDGER_MISSING")
	var directory: Dictionary = _store.initialize_directory()
	if not directory.ok: return directory
	_head = _store.open_head()
	if not _head.ok and _head.code == "RECOVERY_REQUIRED":
		var plan: Dictionary = _store.inspect_recovery()
		if not plan.ok: return plan
		_head = _store.recover(plan)
	if not _head.ok: return _head
	if int(_head.revision) == 0 and _open_scope.require_existing: return _bad("CAMPAIGN_LEDGER_MISSING")
	if _model == null: _model = Receipt.new()
	elif not _model.capture().is_empty(): return _bad("OPEN_MODEL_ALREADY_PREPARED")
	if int(_head.revision) > 0:
		var restored: Dictionary = _model.open_record(_head.document, _owner)
		if not restored.ok: return restored
		_opened = true
		return {"ok": true, "code": "OPENED", "generation": _model.capture().generation,
			"version": _model.capture().version, "upgrade_required": _model.capture().version != Receipt.VERSION}
	var seeded: Dictionary = _model.create(_owner, _open_scope.initial_stats, _open_scope.initial_unlocked)
	if not seeded.ok: return seeded
	var initial: Dictionary = _model.capture()
	var persisted := _persist({"ok": true, "changed": true, "record": initial, "sha256": JSON.stringify(initial).sha256_text()}, true)
	if persisted.ok: _opened = true
	return persisted

func _persist(proposal: Dictionary, creating := false, kind := "other", handoff: Dictionary = {}, success_fields: Dictionary = {}) -> Dictionary:
	if _busy or _fault or not _pending.is_empty(): return _bad("BUSY_OR_FAULT")
	if not proposal.ok: return proposal
	if not proposal.get("changed", false): return proposal
	_pending = {"kind":kind, "handoff":handoff.duplicate(true), "phase":"acquire", "creating":creating,
		"expected_revision":int(_head.revision), "expected_sha256":_head.file_sha256,
		"proposal":{"record":proposal.record.duplicate(true), "sha256":proposal.sha256},
		"commit_attempted":false, "model_committed":false, "written":{}, "unsafe":false,
		"error":{}, "success_fields":success_fields.duplicate(true)}
	return _drive_pending()

func pending_status() -> Dictionary:
	if _pending.is_empty(): return {"ok":true, "pending":false, "kind":""}
	return {"ok":true, "pending":true, "kind":_pending.kind, "phase":_pending.phase,
		"owned_lock":_store._locked or _store._lock_created, "model_committed":_pending.model_committed,
		"expected_revision":_pending.expected_revision, "expected_sha256":_pending.expected_sha256,
		"handoff":_pending.handoff.duplicate(true), "unsafe":_pending.unsafe,
		"error":_pending.error.duplicate(true)}

func _retain_failure(reason: Dictionary) -> Dictionary:
	_busy = false
	var result: Dictionary = reason.duplicate(true)
	var transient: bool = String(reason.get("code", "")) in ["WRITER_BUSY", "READ_OPEN", "READ_INCOMPLETE", "WRITE_OPEN", "CLOSED_READBACK", "RENAME", "FINAL_READBACK", "PRUNE_FAILED", "PRUNE_READBACK", "LOCK_RELEASE"]
	result["retryable"] = bool(reason.get("retryable", transient))
	result["unsafe"] = bool(reason.get("unsafe", not result.retryable))
	result["restart_required"] = bool(reason.get("restart_required", result.unsafe))
	result["pending_save"] = true
	result["pending_kind"] = _pending.kind
	_pending.error = result.duplicate(true)
	_pending.unsafe = result.unsafe
	return result

func _drive_pending() -> Dictionary:
	if Engine.is_in_physics_frame(): return _bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	if _pending.is_empty() or _busy or _fault: return _bad("NO_RETRYABLE_PENDING")
	if _pending.unsafe and _pending.phase != "abort_release": return _pending.error.duplicate(true)
	_busy = true
	if _pending.phase == "acquire":
		var lock: Dictionary = _store.acquire()
		if not lock.ok:
			if _store._locked or _store._lock_created: _pending.phase = "commit"
			return _retain_failure(lock)
		if int(lock.revision) != _pending.expected_revision or lock.file_sha256 != _pending.expected_sha256:
			_pending.phase = "abort_release"
		else:
			_pending.phase = "commit"
	if _pending.phase == "abort_release":
		# Release only this acquired lock. Never rebase its frozen proposal onto
		# an externally changed head, even when no bytes were written yet.
		var released: Dictionary = _store.release()
		if not released.ok: return _retain_failure(released)
		_pending.clear(); _busy = false; _fault = true
		return {"ok":false, "code":"HOST_CAS_CHANGED", "unsafe":true, "restart_required":true}
	if _pending.phase == "commit":
		var written: Dictionary
		if not _pending.commit_attempted and _store._locked:
			_pending.commit_attempted = true
			written = _store.commit_locked(_pending.expected_revision, _pending.expected_sha256, _pending.proposal)
		else:
			_pending.commit_attempted = true
			written = _store.retry_owned_commit(_pending.expected_revision, _pending.expected_sha256, _pending.proposal)
		if not written.ok: return _retain_failure(written)
		_pending.written = written
		_pending.phase = "model"
	if _pending.phase == "model":
		if not _pending.creating and not _pending.model_committed:
			var committed: Dictionary = _model.commit(_pending.written.document, _pending.proposal.sha256)
			if not committed.ok: return _retain_failure(committed)
		_pending.model_committed = true
		_head = _pending.written
		_pending.phase = "release" if (_store._locked or _store._lock_created) else "readback"
	if _pending.phase == "release":
		var released: Dictionary = _store.release()
		if not released.ok: return _retain_failure(released)
		_pending.phase = "readback"
	if _pending.phase == "readback":
		var actual: Dictionary = _store.open_head()
		if not actual.ok: return _retain_failure(actual)
		if actual.revision != _head.revision or actual.file_sha256 != _head.file_sha256 \
			or actual.document != _model.capture(): return _retain_failure(_bad("HOST_FINAL_HEAD_CHANGED"))
		var fields: Dictionary = _pending.success_fields.duplicate(true)
		var creating: bool = _pending.creating
		_pending.clear(); _busy = false
		if creating: _opened = true
		var result := {"ok":true, "code":"COMMITTED", "changed":true, "generation":_model.capture().generation,
			"version":_model.capture().version, "upgrade_required":false}
		result.merge(fields)
		return result
	return _retain_failure(_bad("UNKNOWN_PENDING_PHASE"))

func retry_pending() -> Dictionary:
	if _pending.is_empty(): return _bad("NO_PENDING_WRITE")
	var kind: String = _pending.kind
	var handoff: Dictionary = _pending.handoff.duplicate(true)
	var retried: Dictionary = _drive_pending()
	if not retried.ok: return retried
	return campaign_handoff_proof(handoff) if kind == "handoff" else retried

func _ready_for_event() -> bool:
	if not _opened or _busy or _fault or not _pending.is_empty(): return false
	var current: Dictionary = _store.open_head()
	if not current.ok or current.revision != _head.revision or current.file_sha256 != _head.file_sha256:
		_fault = true
		return false
	return true

func begin_run(trusted_context: Dictionary) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	var saved := _persist(_model.prepare_begin(token, trusted_context), false, "other", {}, {"token":token})
	if saved.ok: saved.token = token
	return saved

func progress(token: String, trusted_context: Dictionary, total_valid_kills: Variant) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	return _persist(_model.prepare_progress(token, trusted_context, total_valid_kills))

func settle(token: String, trusted_context: Dictionary, victory: bool, result: Dictionary) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	return _persist(_model.prepare_settle(token, trusted_context, victory, result))

func can_resume(token: String, live_account: String, trusted_context: Dictionary) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	return _model.can_resume(token, live_account, trusted_context)

func capture() -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	return {"ok": true, "record": _model.capture(), "file_sha256": _head.file_sha256}

func invalidate(live_account: String) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	return _persist(_model.prepare_server_invalidation(live_account))

func correct(live_account: String, stats: Dictionary, unlocked: Dictionary, read_generation: Variant) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	return _persist(_model.prepare_server_correction(live_account, stats, unlocked, read_generation))

func merge_remote_floor(live_account: String, stats: Dictionary, unlocked: Dictionary, generation: int) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	return _persist(_model.prepare_remote_floor(live_account, stats, unlocked, generation))

func upgrade() -> Dictionary:
	if Engine.is_in_physics_frame(): return _bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	if not _pending.is_empty():
		return retry_pending() if _pending.kind == "upgrade" else _bad("ANOTHER_WRITE_PENDING")
	if not _ready_for_event(): return _bad("NOT_READY")
	var result: Dictionary = _persist(_model.prepare_upgrade(), false, "upgrade")
	if result.ok:
		result["version"] = _model.capture().version
		result["upgrade_required"] = false
	return result

func _handoff_basis(handoff: Dictionary) -> Dictionary:
	var record: Dictionary = _model.capture()
	if record.owner != handoff.owner: return _bad("OWNER")
	if record.generation < handoff.basis_generation: return _bad("HANDOFF_RECEIPT_ROLLBACK")
	if record.generation == handoff.basis_generation and _head.file_sha256 != handoff.basis_sha256:
		return _bad("HANDOFF_BASIS_SHA_CHANGED")
	return {"ok":true}

func apply_campaign_handoff(value: Variant) -> Dictionary:
	if Engine.is_in_physics_frame(): return _bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	if _model == null: return _bad("NOT_READY")
	var checked: Dictionary = _model.normalize_campaign_handoff(value)
	if not checked.ok: return checked
	var handoff: Dictionary = checked.handoff
	if not _pending.is_empty():
		if _pending.kind != "handoff" or _pending.handoff != handoff: return _bad("ANOTHER_HANDOFF_OR_WRITE_PENDING")
		return retry_campaign_handoff()
	if not _ready_for_event(): return _bad("NOT_READY")
	var basis: Dictionary = _handoff_basis(handoff)
	if not basis.ok: return basis
	var saved: Dictionary = _persist(_model.prepare_campaign_handoff(handoff), false, "handoff", handoff)
	if not saved.ok: return saved
	return campaign_handoff_proof(handoff)

func retry_campaign_handoff(value: Variant = null) -> Dictionary:
	if _pending.is_empty() or _pending.kind != "handoff": return _bad("NO_HANDOFF_PENDING")
	if value != null:
		var checked: Dictionary = _model.normalize_campaign_handoff(value)
		if not checked.ok: return checked
		if checked.handoff != _pending.handoff: return _bad("ANOTHER_HANDOFF_OR_WRITE_PENDING")
	return retry_pending()

func campaign_handoff_proof(value: Variant) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	var checked: Dictionary = _model.campaign_handoff_proof(value)
	if not checked.ok: return checked
	var handoff: Dictionary = checked.handoff
	var basis: Dictionary = _handoff_basis(handoff)
	if not basis.ok: return basis
	# _ready_for_event independently read and checked the current durable head.
	# Proof fields are a strict data schema, not a UI or SDK acknowledgement.
	var proof := {"schema":"campaign_steam_handoff_proof_v1", "owner":handoff.owner,
		"token":handoff.token, "context":handoff.context.duplicate(true), "intent_sha256":handoff.intent_sha256,
		"descriptor_sha256":checked.descriptor_sha256, "correction_epoch":handoff.correction_epoch,
		"ledger_document_generation":int(_model.capture().generation), "ledger_file_sha256":_head.file_sha256}
	return {"ok":true, "code":"CAMPAIGN_HANDOFF_READBACK_VERIFIED", "proof":proof}
