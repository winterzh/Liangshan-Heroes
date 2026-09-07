extends RefCounted
## Serialized host transaction boundary. No filesystem or SDK calls.
## Every prepared document must be closed, read back and durably accepted by the
## host before commit(). The outbox precedes even the FIRST SetStat/SetAchievement:
## Steam may upload its local cache when the application exits.
## HOST REQUIREMENT: prepare -> synchronous closed-file readback -> commit is one
## non-yielding critical section. Never await, pump SDK callbacks, run arbitrary
## validation callbacks or reenter from another writer within that section.
## Rejecting commit cannot undo a document the host already wrote to disk.
## A reopened uncertain outbox never authorizes replay. Its old runs are closed
## before a genuinely authoritative server read can reconcile the document.
const VERSION := 1
const MAX_REVISION := 2147483647
const DOCUMENT_FIELDS := ["version", "owner", "revision", "receipt", "outbound"]
const OUTBOUND_FIELDS := ["state", "token", "generation", "stats", "unlocked"]
var _receipt_script: Script
var _owner := ""
var _document: Dictionary = {}
var _pending: Dictionary = {}
var _pending_sha := ""
var _pending_operation := ""
var _owned_token := ""
var _issued := false
var _notice := false
var _read_token := ""
var _read_revision := -1
var _used_read_tokens: Dictionary = {}

func _init(receipt_script: Script) -> void:
	_receipt_script = receipt_script

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in keys: return false
	return true

func _integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT and value >= 0 and value <= MAX_REVISION) or (typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value <= MAX_REVISION and value == floor(value))

func _token(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 32: return false
	for c in value.to_utf8_buffer():
		if not (c >= 48 and c <= 57) and not (c >= 97 and c <= 102): return false
	return true

func _checked(value: Variant) -> Dictionary:
	if not _keys(value, DOCUMENT_FIELDS): return _bad("DOCUMENT_FIELDS")
	if not _integer(value.version) or int(value.version) != VERSION: return _bad("DOCUMENT_VERSION")
	if typeof(value.owner) != TYPE_STRING or value.owner != _owner: return _bad("OWNER")
	if not _integer(value.revision) or int(value.revision) < 1: return _bad("DOCUMENT_REVISION")
	var receipt: Variant = _receipt_script.new()
	var opened: Dictionary = receipt.open_record(value.receipt, _owner)
	if not opened.ok: return opened
	var normalized: Dictionary = value.duplicate(true)
	normalized.version = VERSION
	normalized.revision = int(value.revision)
	normalized.receipt = receipt.capture()
	if not _keys(value.outbound, ["state"]) or value.outbound.state != "none":
		if not _keys(value.outbound, OUTBOUND_FIELDS) or value.outbound.state != "uncertain" or not _token(value.outbound.token): return _bad("OUTBOUND_FIELDS")
		if not _integer(value.outbound.generation) or int(value.outbound.generation) > int(normalized.receipt.generation): return _bad("OUTBOUND_GENERATION")
		# Reuse the complete receipt target contract without trusting a battle slot.
		var targets: Dictionary = normalized.receipt.duplicate(true)
		targets.stats = value.outbound.stats
		targets.unlocked = value.outbound.unlocked
		var target_checker: Variant = _receipt_script.new()
		var target_result: Dictionary = target_checker.open_record(targets, _owner)
		if not target_result.ok: return _bad("OUTBOUND_TARGETS")
		normalized.outbound.generation = int(value.outbound.generation)
		normalized.outbound.stats = target_checker.capture().stats
	return {"ok": true, "value": normalized}

func capture() -> Dictionary:
	return _document.duplicate(true)

func open_document(value: Variant, owner: String) -> Dictionary:
	if not _document.is_empty() or not _pending.is_empty(): return _bad("ALREADY_OPEN")
	_owner = owner
	var checked := _checked(value)
	if not checked.ok: return checked
	_document = checked.value
	_notice = _document.receipt.requires_correction or _document.outbound.state == "uncertain"
	return {"ok": true, "code": "RECOVERY_REQUIRED" if _notice else "OPENED"}

func _prepare(next: Dictionary, operation: String) -> Dictionary:
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	var revision: int = int(_document.get("revision", 0))
	if revision == MAX_REVISION: return _bad("REVISION_EXHAUSTED")
	next["revision"] = revision + 1
	var checked := _checked(next)
	if not checked.ok: return checked
	_pending = checked.value
	_pending_sha = JSON.stringify(_pending).sha256_text()
	_pending_operation = operation
	return {"ok": true, "code": "PREPARED", "changed": true, "document": _pending.duplicate(true), "sha256": _pending_sha}

func prepare_create(owner: String, stats: Dictionary, unlocked: Dictionary) -> Dictionary:
	if not _document.is_empty() or not _pending.is_empty(): return _bad("ALREADY_OPEN")
	_owner = owner
	var receipt: Variant = _receipt_script.new()
	var created: Dictionary = receipt.create(owner, stats, unlocked)
	if not created.ok: return created
	return _prepare({"version": VERSION, "owner": owner, "receipt": receipt.capture(), "outbound": {"state": "none"}}, "create")

func commit(closed_readback: Variant, digest: String) -> Dictionary:
	if _pending.is_empty() or digest != _pending_sha: return _bad("NO_MATCHING_PREPARATION")
	if _notice and _pending_operation in ["dispatch", "acknowledge"]: return _bad("INVALIDATION_SUPERSEDED_PREPARATION")
	var checked := _checked(closed_readback)
	if not checked.ok: return checked
	if JSON.stringify(checked.value).sha256_text() != _pending_sha: return _bad("PREPARATION_CHANGED")
	_document = checked.value
	if _pending_operation == "dispatch":
		_owned_token = _document.outbound.token
		_issued = false
	elif _pending_operation in ["acknowledge", "invalidate", "correct"]:
		_owned_token = ""
		_issued = false
		_notice = _document.receipt.requires_correction
	_read_token = ""
	_read_revision = -1
	_pending.clear()
	_pending_sha = ""
	_pending_operation = ""
	return {"ok": true, "code": "COMMITTED"}

func abandon() -> void:
	_pending.clear()
	_pending_sha = ""
	_pending_operation = ""
	# An observed invalidation remains a live-session barrier after disk failure.

func _model() -> Variant:
	var receipt: Variant = _receipt_script.new()
	var result: Dictionary = receipt.open_record(_document.receipt, _owner)
	assert(result.ok)
	return receipt

func _wrap_prepared(receipt: Variant, proposal: Dictionary, operation: String, clear_outbound := false) -> Dictionary:
	if not proposal.ok: return proposal
	if proposal.get("changed", false):
		var committed: Dictionary = receipt.commit(proposal.record, proposal.sha256)
		if not committed.ok: return committed
	var next := capture()
	next.receipt = receipt.capture()
	if clear_outbound: next.outbound = {"state": "none"}
	if next == _document: return {"ok": true, "code": "UNCHANGED", "changed": false}
	return _prepare(next, operation)

func prepare_run_event(method: String, arguments: Array) -> Dictionary:
	if _document.is_empty(): return _bad("NOT_OPEN")
	if _notice: return _bad("SERVER_RECOVERY_REQUIRED")
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	if method not in ["prepare_begin", "prepare_progress", "prepare_settle"]: return _bad("RUN_METHOD")
	var counts := {"prepare_begin": 2, "prepare_progress": 3, "prepare_settle": 4}
	if arguments.size() != counts[method]: return _bad("RUN_ARGUMENTS")
	if typeof(arguments[1]) != TYPE_DICTIONARY: return _bad("RUN_ARGUMENTS")
	if method == "prepare_settle" and (typeof(arguments[2]) != TYPE_BOOL or typeof(arguments[3]) != TYPE_DICTIONARY): return _bad("RUN_ARGUMENTS")
	var receipt: Variant = _model()
	var proposed: Dictionary = receipt.callv(method, arguments)
	return _wrap_prepared(receipt, proposed, "run_event")

func prepare_dispatch(token: String) -> Dictionary:
	if _document.is_empty(): return _bad("NOT_OPEN")
	if _notice or _document.receipt.requires_correction: return _bad("SERVER_RECOVERY_REQUIRED")
	if _document.outbound.state != "none": return _bad("OUTBOUND_UNRESOLVED")
	if not _token(token): return _bad("DISPATCH_TOKEN")
	var receipt: Variant = _model()
	var targets: Dictionary = receipt.publish_targets(_owner)
	if not targets.ok: return targets
	var next := capture()
	next.outbound = {"state": "uncertain", "token": token, "generation": targets.generation, "stats": targets.stats, "unlocked": targets.unlocked}
	return _prepare(next, "dispatch")

func take_sdk_targets(owner: String, token: String) -> Dictionary:
	if owner != _owner or _document.is_empty(): return _bad("OWNER")
	if _notice or _document.receipt.requires_correction: return _bad("SERVER_RECOVERY_REQUIRED")
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	if token != _owned_token or _document.outbound.state != "uncertain" or token != _document.outbound.token or _issued: return _bad("NO_OWNED_UNISSUED_DISPATCH")
	_issued = true
	return {"ok": true, "owner": _owner, "token": token, "targets": _document.outbound.duplicate(true)}

func prepare_stored(owner: String, token: String, result: int) -> Dictionary:
	if owner != _owner or _document.is_empty(): return _bad("OWNER")
	if token != _owned_token or token.is_empty() or not _issued: return _bad("UNOWNED_CALLBACK")
	if result == 8:
		_notice = true
		return prepare_recovery_invalidation(owner)
	if _notice: return _bad("SERVER_RECOVERY_REQUIRED")
	if result != 1: return _bad("OUTBOUND_UNRESOLVED")
	var next := capture()
	next.outbound = {"state": "none"}
	return _prepare(next, "acknowledge")

func prepare_recovery_invalidation(owner: String) -> Dictionary:
	if owner != _owner or _document.is_empty(): return _bad("OWNER")
	if not _notice and _document.outbound.state != "uncertain": return _bad("NO_RECOVERY_REQUIRED")
	_notice = true
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	var receipt: Variant = _model()
	return _wrap_prepared(receipt, receipt.prepare_server_invalidation(owner), "invalidate", true)

func prepare_external_invalidation(owner: String) -> Dictionary:
	## Only the live host calls this after a same-app result 8 which cannot be
	## attributed to its sole outstanding attempt. Never continue old publication.
	if owner != _owner or _document.is_empty(): return _bad("OWNER")
	_notice = true
	return prepare_recovery_invalidation(owner)

func begin_authoritative_read(owner: String, request_token: String) -> Dictionary:
	if owner != _owner or _document.is_empty(): return _bad("OWNER")
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	if not _document.receipt.requires_correction or _document.outbound.state != "none": return _bad("DURABLE_INVALIDATION_REQUIRED")
	if not _token(request_token) or not _read_token.is_empty() or _used_read_tokens.has(request_token): return _bad("READ_REQUEST")
	if _used_read_tokens.size() >= 4096: return _bad("READ_LIMIT")
	_used_read_tokens[request_token] = true
	_read_token = request_token
	_read_revision = _document.revision
	return {"ok": true, "owner": owner, "request_token": request_token, "revision": _read_revision}

func cancel_authoritative_read(owner: String, request_token: String) -> Dictionary:
	if owner != _owner or _document.is_empty(): return _bad("OWNER")
	if request_token.is_empty() or request_token != _read_token: return _bad("STALE_REMOTE_READ")
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	_read_token = ""
	_read_revision = -1
	return {"ok": true, "code": "READ_CANCELLED"}

func prepare_authoritative_correction(owner: String, request_token: String, stats: Dictionary, unlocked: Dictionary) -> Dictionary:
	if owner != _owner or _document.is_empty(): return _bad("OWNER")
	if request_token.is_empty() or request_token != _read_token or _read_revision != _document.revision: return _bad("STALE_REMOTE_READ")
	if not _pending.is_empty(): return _bad("PERSISTENCE_PENDING")
	var receipt: Variant = _model()
	return _wrap_prepared(receipt, receipt.prepare_server_correction(owner, stats, unlocked, _document.receipt.generation), "correct")
