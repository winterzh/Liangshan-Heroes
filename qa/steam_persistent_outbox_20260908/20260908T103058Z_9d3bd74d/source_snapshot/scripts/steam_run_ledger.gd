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

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func open(account: String, initial_stats: Dictionary = {}, initial_unlocked: Dictionary = {}, root_path := "user://steam_receipts/v1") -> Dictionary:
	if _opened or _store != null: return _bad("ALREADY_OPEN")
	_owner = account
	_store = Store.new(account, root_path)
	var directory: Dictionary = _store.initialize_directory()
	if not directory.ok: return directory
	_head = _store.open_head()
	if not _head.ok and _head.code == "RECOVERY_REQUIRED":
		var plan: Dictionary = _store.inspect_recovery()
		if not plan.ok: return plan
		_head = _store.recover(plan)
	if not _head.ok: return _head
	_model = Receipt.new()
	if int(_head.revision) > 0:
		var restored: Dictionary = _model.open_record(_head.document, account)
		if not restored.ok: return restored
		_opened = true
		return {"ok": true, "code": "OPENED", "generation": _model.capture().generation}
	var seeded: Dictionary = _model.create(account, initial_stats, initial_unlocked)
	if not seeded.ok: return seeded
	var initial: Dictionary = _model.capture()
	var persisted := _persist({"ok": true, "changed": true, "record": initial, "sha256": JSON.stringify(initial).sha256_text()}, true)
	if persisted.ok: _opened = true
	return persisted

func _persist(proposal: Dictionary, creating := false) -> Dictionary:
	if _busy or _fault: return _bad("BUSY_OR_FAULT")
	if not proposal.ok: return proposal
	if not proposal.get("changed", false): return proposal
	_busy = true
	var lock: Dictionary = _store.acquire()
	if not lock.ok:
		_busy = false
		_fault = true
		return lock
	if lock.revision != _head.revision or lock.file_sha256 != _head.file_sha256:
		_store.release()
		_fault = true
		_busy = false
		return _bad("HOST_CAS_CHANGED")
	var written: Dictionary = _store.commit_locked(_head.revision, _head.file_sha256, proposal)
	if not written.ok:
		_fault = true
		_busy = false
		return written # Preserve writer/residue; no success targets can escape.
	if not creating:
		var committed: Dictionary = _model.commit(written.document, proposal.sha256)
		if not committed.ok:
			_fault = true
			_busy = false
			return committed
	_head = written
	var released: Dictionary = _store.release()
	_busy = false
	if not released.ok:
		_fault = true
		return released
	return {"ok": true, "code": "COMMITTED", "changed": true, "generation": _model.capture().generation}

func _ready_for_event() -> bool:
	if not _opened or _busy or _fault: return false
	var current: Dictionary = _store.open_head()
	if not current.ok or current.revision != _head.revision or current.file_sha256 != _head.file_sha256:
		_fault = true
		return false
	return true

func begin_run(trusted_context: Dictionary) -> Dictionary:
	if not _ready_for_event(): return _bad("NOT_READY")
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	var saved := _persist(_model.prepare_begin(token, trusted_context))
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
