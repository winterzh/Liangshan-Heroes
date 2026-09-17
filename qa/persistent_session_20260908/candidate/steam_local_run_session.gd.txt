extends RefCounted
## Local receipt side of the unified session. SDK publishing is a separate gate.
## observe/queue_terminal are memory-only; checkpoint runs outside physics.
const Ledger = preload("res://scripts/steam_run_ledger.gd")
const Receipt = preload("res://scripts/steam_run_receipt.gd")
const BINDING_KEYS := ["kind", "owner", "token", "credited_kills", "generation", "receipt_sha256"]
var _ledger: RefCounted
var _owner := ""
var _token := ""
var _context := {}
var _pending_kills := 0
var _terminal := {}
var _settled := false
var _fault := false
var _dirty := false

func bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

static func validate_binding(value: Variant) -> Dictionary:
	var model := Receipt.new()
	if typeof(value) != TYPE_DICTIONARY or value.size() != BINDING_KEYS.size() or not value.has_all(BINDING_KEYS): return {"ok": false, "code": "STEAM_BINDING_FIELDS"}
	if value.kind != "steam" or not model._owner(value.owner) or not model._token(value.token): return {"ok": false, "code": "STEAM_BINDING_IDENTITY"}
	if not model._number(value.credited_kills) or not model._number(value.generation): return {"ok": false, "code": "STEAM_BINDING_COUNTER"}
	if typeof(value.receipt_sha256) != TYPE_STRING or value.receipt_sha256.length() != 64 or not value.receipt_sha256.is_valid_hex_number(): return {"ok": false, "code": "STEAM_BINDING_HASH"}
	var normalized: Dictionary = value.duplicate(true)
	normalized.credited_kills = int(value.credited_kills); normalized.generation = int(value.generation)
	return {"ok": true, "binding": normalized}

func open(account: String, stats: Dictionary, unlocked: Dictionary, root_path: String) -> Dictionary:
	if _ledger != null: return bad("ALREADY_OPEN")
	if Engine.is_in_physics_frame(): return bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	_owner = account; _ledger = Ledger.new()
	return _ledger.open(account, stats, unlocked, root_path)

func capture() -> Dictionary:
	if _fault or _ledger == null: return bad("LOCAL_RECEIPT_FAULT")
	return _ledger.capture()

func begin(context: Dictionary) -> Dictionary:
	var ready := checkpoint()
	if not ready.ok: return ready
	var begun: Dictionary = _ledger.begin_run(context)
	if not begun.ok: _fault = true; return begun
	_token = begun.token; _context = context.duplicate(true)
	_pending_kills = 0; _terminal.clear(); _settled = false; _dirty = false
	return begun

func observe(total: Variant) -> Dictionary:
	if _fault or _token.is_empty() or _settled or not _terminal.is_empty(): return bad("LOCAL_RUN_CLOSED")
	if typeof(total) != TYPE_INT or total < 0 or total > 2147483647: return bad("KILLS")
	if total > _pending_kills: _pending_kills = total; _dirty = true
	return {"ok": true}

func queue_terminal(victory: bool, result: Dictionary) -> Dictionary:
	if _fault or _token.is_empty(): return bad("LOCAL_RUN_CLOSED")
	if _settled or not _terminal.is_empty(): return {"ok": true, "changed": false}
	_terminal = {"victory": victory, "result": result.duplicate(true)}
	_dirty = true
	return {"ok": true, "changed": true}

func checkpoint() -> Dictionary:
	if _fault or _ledger == null: return bad("LOCAL_RECEIPT_FAULT")
	if Engine.is_in_physics_frame(): return bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	if _dirty and not _token.is_empty() and not _settled:
		var progress: Dictionary = _ledger.progress(_token, _context, _pending_kills)
		if not progress.ok: _fault = true; return progress
		if not _terminal.is_empty():
			var ended: Dictionary = _ledger.settle(_token, _context, _terminal.victory, _terminal.result)
			if not ended.ok: _fault = true; return ended
			_settled = true; _terminal.clear()
		_dirty = false
	return capture()

func has_pending() -> bool:
	return _dirty and not _fault

func binding(total: int, trusted_context: Dictionary) -> Dictionary:
	if trusted_context != _context: return bad("CONTEXT_MISMATCH")
	var observed := observe(total)
	if not observed.ok: return observed
	var durable := checkpoint()
	if not durable.ok: return durable
	var resumable: Dictionary = _ledger.can_resume(_token, _owner, trusted_context)
	if not resumable.ok: return resumable
	return {"ok": true, "binding": {"kind": "steam", "owner": _owner, "token": _token, "credited_kills": resumable.credited_kills, "generation": durable.record.generation, "receipt_sha256": durable.file_sha256}}

func prepare_resume(value: Variant, context: Dictionary, total: int) -> Dictionary:
	var checked := validate_binding(value)
	if not checked.ok: return checked
	var saved: Dictionary = checked.binding
	if saved.owner != _owner: return bad("OWNER")
	if total < 0 or total > saved.credited_kills: return bad("WORLD_AHEAD_OF_SAVED_RECEIPT")
	var durable := capture()
	if not durable.ok: return durable
	if durable.record.generation < saved.generation or (durable.record.generation == saved.generation and durable.file_sha256 != saved.receipt_sha256): return bad("RECEIPT_ROLLBACK")
	var resumable: Dictionary = _ledger.can_resume(saved.token, _owner, context)
	if not resumable.ok: return resumable
	if resumable.credited_kills < saved.credited_kills: return bad("RUN_HIGHWATER_ROLLBACK")
	return {"ok": true, "token": saved.token, "owner": _owner, "context": context.duplicate(true), "credited_kills": resumable.credited_kills, "record": durable.record, "receipt_sha256": durable.file_sha256}

func install_prepared(plan: Dictionary) -> void:
	# Only the trusted service's same-frame commit calls this, after revalidation.
	_token = plan.token; _context = plan.context.duplicate(true)
	_pending_kills = plan.credited_kills; _terminal.clear(); _settled = false; _dirty = false

func invalidate() -> Dictionary:
	if _ledger == null: return bad("LOCAL_RECEIPT_FAULT")
	_fault = true
	return _ledger.invalidate(_owner)
