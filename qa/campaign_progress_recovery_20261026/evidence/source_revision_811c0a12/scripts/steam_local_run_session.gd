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
var _campaign_handoff: Dictionary = {}
var _operation: Dictionary = {}
var _checkpoint: Dictionary = {}
var _open_scope: Dictionary = {}
var _invalidation_requested := false
var _invalidation_durable := false
var _last_terminal: Dictionary = {}

func bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

static func validate_binding(value: Variant) -> Dictionary:
	var model := Receipt.new()
	if typeof(value) != TYPE_DICTIONARY or value.size() != BINDING_KEYS.size() or not value.has_all(BINDING_KEYS): return {"ok": false, "code": "STEAM_BINDING_FIELDS"}
	if value.kind != "steam" or not model._owner(value.owner) or not model._token(value.token): return {"ok": false, "code": "STEAM_BINDING_IDENTITY"}
	if not model._number(value.credited_kills) or not model._number(value.generation): return {"ok": false, "code": "STEAM_BINDING_COUNTER"}
	if not model._sha(value.receipt_sha256): return {"ok": false, "code": "STEAM_BINDING_HASH"}
	var normalized: Dictionary = value.duplicate(true)
	normalized.credited_kills = int(value.credited_kills); normalized.generation = int(value.generation)
	return {"ok": true, "binding": normalized}

func open(account: String, stats: Dictionary, unlocked: Dictionary, root_path: String, require_existing := false) -> Dictionary:
	if Engine.is_in_physics_frame(): return bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	var scope := {"owner":account, "stats":stats.duplicate(true), "unlocked":unlocked.duplicate(true), "root":root_path, "require_existing":require_existing}
	if _ledger == null:
		_owner = account; _ledger = Ledger.new(); _open_scope = scope
		_operation = {"kind":"open", "scope":scope.duplicate(true)}
		var opened: Dictionary = _ledger.open(account, stats, unlocked, root_path, require_existing)
		if opened.ok: _operation.clear()
		return opened
	if scope != _open_scope or _operation.get("kind") != "open": return bad("LOCAL_OPEN_SCOPE_CHANGED")
	return _drive_operation()

func _operate(kind: String, scope: Dictionary) -> Dictionary:
	if _ledger == null or Engine.is_in_physics_frame(): return bad("LOCAL_RECEIPT_UNAVAILABLE")
	var request := {"kind":kind, "scope":scope.duplicate(true)}
	if _operation.is_empty(): _operation = request
	elif _operation != request: return bad("LOCAL_OPERATION_SCOPE_CHANGED")
	return _drive_operation()

func _drive_operation() -> Dictionary:
	if _operation.is_empty(): return bad("LOCAL_OPERATION_REQUIRED")
	var status: Dictionary = _ledger.pending_status()
	if not status.ok: return status
	var result: Dictionary
	var scope: Dictionary = _operation.scope
	if status.get("pending", false):
		result = _ledger.retry_pending()
	else:
		match _operation.kind:
			"open": result = _ledger.retry_open()
			"upgrade": result = _ledger.upgrade()
			"begin": result = _ledger.begin_run(scope.context)
			"progress": result = _ledger.progress(scope.token, scope.context, scope.kills)
			"settle": result = _ledger.settle(scope.token, scope.context, scope.victory, scope.result)
			"invalidate": result = _ledger.invalidate(_owner)
			"correct": result = _ledger.correct(_owner, scope.stats, scope.unlocked, scope.generation)
			"merge": result = _ledger.merge_remote_floor(_owner, scope.stats, scope.unlocked, scope.generation)
			_: return bad("LOCAL_OPERATION_UNKNOWN")
	if result.ok: _operation.clear()
	return result

func capture() -> Dictionary:
	if _fault or _ledger == null or not _operation.is_empty(): return bad("LOCAL_RECEIPT_FAULT_OR_PENDING")
	return _ledger.capture()

func begin(context: Dictionary) -> Dictionary:
	if _invalidation_requested: return bad("LOCAL_CORRECTION_REQUIRED")
	if _operation.get("kind") != "begin":
		var ready := checkpoint()
		if not ready.ok: return ready
	var begun: Dictionary = _operate("begin", {"context":context})
	if not begun.ok: return begun
	_token = begun.token; _context = context.duplicate(true)
	_pending_kills = 0; _terminal.clear(); _last_terminal.clear(); _settled = false; _dirty = false
	return begun

func observe(total: Variant) -> Dictionary:
	if _fault or _invalidation_requested or not _campaign_handoff.is_empty() or _token.is_empty() or _settled or not _terminal.is_empty(): return bad("LOCAL_RUN_CLOSED")
	if typeof(total) != TYPE_INT or total < 0 or total > 2147483647: return bad("KILLS")
	if total > _pending_kills: _pending_kills = total; _dirty = true
	return {"ok": true}

func queue_terminal(victory: bool, result: Dictionary) -> Dictionary:
	if _fault or _invalidation_requested or not _campaign_handoff.is_empty() or _token.is_empty(): return bad("LOCAL_RUN_CLOSED")
	var request := {"victory":victory, "result":result.duplicate(true)}
	if _settled: return {"ok":true, "changed":false} if _last_terminal == request else bad("LOCAL_TERMINAL_CHANGED")
	if not _terminal.is_empty(): return {"ok":true, "changed":false} if _terminal == request else bad("LOCAL_TERMINAL_CHANGED")
	_terminal = {"victory": victory, "result": result.duplicate(true)}
	_dirty = true
	return {"ok": true, "changed": true}

func checkpoint() -> Dictionary:
	if not _campaign_handoff.is_empty(): return bad("CAMPAIGN_HANDOFF_PENDING")
	if _fault or _invalidation_requested or _ledger == null: return bad("LOCAL_RECEIPT_FAULT")
	if Engine.is_in_physics_frame(): return bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	if _dirty and not _token.is_empty() and not _settled:
		if _checkpoint.is_empty(): _checkpoint = {"phase":"progress", "kills":_pending_kills, "terminal":_terminal.duplicate(true)}
		if _checkpoint.phase == "progress":
			var progress: Dictionary = _operate("progress", {"token":_token, "context":_context, "kills":_checkpoint.kills})
			if not progress.ok: return progress
			_checkpoint.phase = "settle"
		if not _checkpoint.terminal.is_empty():
			var ended: Dictionary = _operate("settle", {"token":_token, "context":_context, "victory":_checkpoint.terminal.victory, "result":_checkpoint.terminal.result})
			if not ended.ok: return ended
			_settled = true; _last_terminal = _checkpoint.terminal.duplicate(true); _terminal.clear()
		_dirty = not _settled and (_pending_kills > _checkpoint.kills or not _terminal.is_empty())
		_checkpoint.clear()
	return capture()

func has_pending() -> bool:
	return not _fault and (_dirty or not _checkpoint.is_empty()) and not _invalidation_requested

func binding(total: int, trusted_context: Dictionary) -> Dictionary:
	if trusted_context != _context: return bad("CONTEXT_MISMATCH")
	var observed := observe(total)
	if not observed.ok: return observed
	var durable := checkpoint()
	if not durable.ok: return durable
	# A failed earlier checkpoint may have frozen an older high-water. Complete
	# that exact proposal first, then persist the newly observed total separately.
	if _dirty:
		durable = checkpoint()
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
	_pending_kills = plan.credited_kills; _terminal.clear(); _last_terminal.clear(); _settled = false; _dirty = false

func invalidate() -> Dictionary:
	if _ledger == null: return bad("LOCAL_RECEIPT_FAULT")
	_invalidation_requested = true
	if Engine.is_in_physics_frame(): return bad("RECEIPT_PHYSICS_WRITE_REFUSED")
	if _invalidation_durable: return {"ok":true, "code":"LOCAL_INVALIDATION_DURABLE"}
	# Finish only the retained proposal before creating the epoch+1 proposal.
	# The service gate is already closed, so this cannot authorize ACK/publishing.
	if not _operation.is_empty() and _operation.kind != "invalidate":
		var completed: Dictionary = _drive_operation()
		if not completed.ok: return completed
	var pending: Dictionary = _ledger.pending_status()
	if not pending.ok: return pending
	if pending.get("pending", false) and _operation.is_empty():
		var retried: Dictionary = _ledger.retry_pending()
		if not retried.ok: return retried
	if _operation.is_empty():
		var current: Dictionary = _ledger.capture()
		if not current.ok: return current
		if current.record.version != Receipt.VERSION:
			var upgraded: Dictionary = _operate("upgrade", {})
			if not upgraded.ok: return upgraded
	var invalidated: Dictionary = _operate("invalidate", {})
	if not invalidated.ok: return invalidated
	var durable: Dictionary = _ledger.capture()
	if not durable.ok: return durable
	if not durable.record.requires_correction: return bad("LOCAL_INVALIDATION_READBACK_REQUIRED")
	_invalidation_durable = true
	_dirty = false; _checkpoint.clear(); _terminal.clear()
	return {"ok":true, "code":"LOCAL_INVALIDATION_DURABLE", "record":durable.record, "file_sha256":durable.file_sha256}


func upgrade() -> Dictionary:
	if _ledger == null or not _token.is_empty() or _dirty or _fault: return bad("LOCAL_UPGRADE_BUSY")
	return _operate("upgrade", {})

func correct(stats: Dictionary, unlocked: Dictionary, generation: int) -> Dictionary:
	return _operate("correct", {"stats":stats, "unlocked":unlocked, "generation":generation})

func merge_remote_floor(stats: Dictionary, unlocked: Dictionary, generation: int) -> Dictionary:
	if _invalidation_requested: return bad("LOCAL_CORRECTION_REQUIRED")
	return _operate("merge", {"stats":stats, "unlocked":unlocked, "generation":generation})

func apply_campaign_handoff(descriptor: Dictionary) -> Dictionary:
	# Startup recovery uses the existing account ledger directly. It does not
	# install a Battle or manufacture an active handle/session token.
	if _ledger == null or _invalidation_requested or not _operation.is_empty() or not _checkpoint.is_empty() or Engine.is_in_physics_frame(): return bad("LOCAL_CAMPAIGN_LEDGER_REQUIRED")
	if not _token.is_empty() and _token != descriptor.get("token"): return bad("LOCAL_CAMPAIGN_OTHER_RUN")
	if not _token.is_empty() and (_context != descriptor.get("context") \
		or _pending_kills > descriptor.get("final_credited_kills",-1) or not _terminal.is_empty()):
		return bad("LOCAL_CAMPAIGN_PENDING_CHANGED")
	if _campaign_handoff.is_empty():
		if _fault: return bad("LOCAL_RECEIPT_FAULT")
		_campaign_handoff = descriptor.duplicate(true)
	elif _campaign_handoff != descriptor: return bad("LOCAL_CAMPAIGN_HANDOFF_CHANGED")
	var status: Dictionary = _ledger.pending_status()
	if not status.ok: return status
	var applied: Dictionary
	if status.get("pending",false): applied = _ledger.retry_campaign_handoff()
	else: applied = _ledger.apply_campaign_handoff(descriptor)
	if not applied.ok: return applied
	var confirmed: Dictionary = _ledger.campaign_handoff_proof(descriptor)
	if not confirmed.ok: return confirmed
	if _token == descriptor.token:
		_pending_kills = descriptor.final_credited_kills
		_settled = true
		_dirty = false
		_terminal.clear()
	_campaign_handoff.clear()
	return confirmed

func campaign_handoff_proof(descriptor: Dictionary) -> Dictionary:
	if _ledger == null or _fault or _invalidation_requested or not _operation.is_empty(): return bad("LOCAL_CAMPAIGN_LEDGER_REQUIRED")
	return _ledger.campaign_handoff_proof(descriptor)

func verify_reserved_credit(credit: Dictionary, token: String, context: Dictionary, total: int) -> Dictionary:
	# Source continuity only: never a durable handoff proof. This lets the live
	# Coordinator reach the one retained proposal after a write/release failure.
	if _ledger == null or _fault or _invalidation_requested or _campaign_handoff.is_empty() or not _operation.is_empty():
		return bad("LOCAL_RESERVED_HANDOFF_REQUIRED")
	var pending: Dictionary = _ledger.pending_status()
	if not pending.ok: return pending
	if not pending.get("pending",false) or pending.get("kind") != "handoff" or pending.get("handoff") != _campaign_handoff:
		return bad("LOCAL_RESERVED_HANDOFF_CHANGED")
	if pending.get("unsafe",false): return pending.error.duplicate(true)
	var descriptor: Dictionary = _campaign_handoff
	var binding: Dictionary = credit.binding
	if descriptor.owner != _owner or descriptor.token != token or descriptor.context != context \
		or descriptor.correction_epoch != credit.correction_epoch or descriptor.basis_generation != binding.generation \
		or descriptor.basis_sha256 != binding.receipt_sha256 or descriptor.basis_credited_kills != binding.credited_kills \
		or descriptor.final_credited_kills != binding.credited_kills or total > binding.credited_kills \
		or _token != token or _context != context or _pending_kills > descriptor.final_credited_kills:
		return bad("LOCAL_RESERVED_CREDIT_CHANGED")
	return {"ok":true, "reserved_only":true, "durable_handoff_complete":false}
