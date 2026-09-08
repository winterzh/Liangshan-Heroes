extends "res://scripts/run_snapshot_store.gd"
## Independent local-only run identity. No Steam owner, stats or achievements.
## Commit the active receipt before the slot and the terminal receipt before
## exposing settlement. A retained transaction retries only its original lock.
const SCHEMA := "local_continue_lifecycle_v1"
const CONTEXT := {"mode": "defense", "level_id": "", "waves": 30}
var token := ""
var _binding: Dictionary = {}
var _pending: Dictionary = {}
var _creating := false

func _init(run_token: String, slot_root := "user://continue/v1") -> void:
	token = run_token
	super("1", slot_root.path_join("local_runs").path_join(run_token) if _valid_token(run_token) else "")

func _magic() -> String:
	return "LH_LOCAL_CONTINUE_LIFECYCLE"

func _byte_limit() -> int:
	return 65536

static func validate_binding(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or value.size() != 3 or not value.has_all(["kind", "token", "receipt_sha256"]): return {"ok": false, "code": "LOCAL_BINDING_FIELDS"}
	if value.kind != "uncredited" or typeof(value.token) != TYPE_STRING or value.token.length() != 32 or not value.token.is_valid_hex_number() or value.token != value.token.to_lower(): return {"ok": false, "code": "LOCAL_BINDING_TOKEN"}
	if typeof(value.receipt_sha256) != TYPE_STRING or value.receipt_sha256.length() != 64 or not value.receipt_sha256.is_valid_hex_number() or value.receipt_sha256 != value.receipt_sha256.to_lower(): return {"ok": false, "code": "LOCAL_BINDING_HASH"}
	return {"ok": true, "binding": value.duplicate(true)}

func _validate_document(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or value.size() != 6 or not value.has_all(["schema", "generation", "token", "context", "state", "victory"]): return bad("LOCAL_LIFECYCLE_FIELDS")
	if value.schema != SCHEMA or value.token != token or value.context != CONTEXT: return bad("LOCAL_LIFECYCLE_IDENTITY")
	if typeof(value.victory) != TYPE_BOOL or typeof(value.generation) not in [TYPE_INT, TYPE_FLOAT]: return bad("LOCAL_LIFECYCLE_TYPES")
	if not ((value.generation == 1 and value.state == "active" and not value.victory) or (value.generation == 2 and value.state == "terminal")): return bad("LOCAL_LIFECYCLE_TRANSITION")
	var normalized: Dictionary = value.duplicate(true)
	normalized.generation = int(value.generation)
	normalized.context = CONTEXT.duplicate()
	return {"ok": true, "document": normalized, "revision": normalized.generation}

func _head() -> Dictionary:
	if not _pending.is_empty():
		var retried := retry_owned_commit(_pending.revision, _pending.sha, _pending.proposal)
		if not retried.ok: return retried
		_pending.clear()
	var head := open_head()
	if not head.ok and head.code == "RECOVERY_REQUIRED":
		var plan := inspect_recovery()
		if not plan.ok: return plan
		head = recover(plan)
	return head

func _commit(head: Dictionary, document: Dictionary) -> Dictionary:
	if Engine.is_in_physics_frame(): return bad("LOCAL_LIFECYCLE_PHYSICS_WRITE")
	var proposal := {"record": document.duplicate(true), "sha256": JSON.stringify(document).sha256_text()}
	_pending = {"revision": head.revision, "sha": head.file_sha256, "proposal": proposal}
	var locked := acquire()
	if not locked.ok:
		if not _locked and not _lock_created: _pending.clear()
		return locked
	if locked.revision != head.revision or locked.file_sha256 != head.file_sha256:
		var unlocked := release()
		if unlocked.ok: _pending.clear()
		return bad("LOCAL_LIFECYCLE_CHANGED")
	var committed := commit_locked(head.revision, head.file_sha256, proposal)
	if not committed.ok: return committed
	var released := release()
	if not released.ok: return released
	_pending.clear()
	return committed

func begin() -> Dictionary:
	if Engine.is_in_physics_frame(): return bad("LOCAL_LIFECYCLE_PHYSICS_WRITE")
	if not _binding.is_empty(): return binding()
	var ready := initialize_directory()
	if not ready.ok: return ready
	var head := _head()
	if not head.ok: return head
	if head.revision != 0 and not _creating: return bad("LOCAL_TOKEN_EXISTS")
	if head.revision == 0:
		_creating = true
		head = _commit(head, {"schema": SCHEMA, "generation": 1, "token": token, "context": CONTEXT.duplicate(), "state": "active", "victory": false})
		if not head.ok: return head
	if head.document.state == "terminal": return bad("LOCAL_RUN_TERMINAL")
	_binding = {"kind": "uncredited", "token": token, "receipt_sha256": head.file_sha256}
	return {"ok": true, "binding": _binding.duplicate(true)}

func prepare_resume(value: Variant) -> Dictionary:
	var checked := validate_binding(value)
	if not checked.ok: return checked
	if checked.binding.token != token: return bad("LOCAL_BINDING_TOKEN")
	var head := _head()
	if not head.ok: return head
	if head.revision == 0: return bad("LOCAL_LIFECYCLE_MISSING")
	if head.document.state == "terminal": return bad("LOCAL_RUN_TERMINAL")
	if head.revision != 1 or head.file_sha256 != checked.binding.receipt_sha256: return bad("LOCAL_LIFECYCLE_CHANGED")
	_binding = checked.binding.duplicate(true)
	return {"ok": true}

func binding() -> Dictionary:
	if _binding.is_empty(): return begin()
	var checked := prepare_resume(_binding)
	if not checked.ok: return checked
	return {"ok": true, "binding": _binding.duplicate(true)}

func terminal(victory: bool) -> Dictionary:
	if Engine.is_in_physics_frame(): return bad("LOCAL_LIFECYCLE_PHYSICS_WRITE")
	# A failed first save may have retained an unfinished active receipt.
	if _binding.is_empty():
		var begun := begin()
		if not begun.ok: return begun
	var head := _head()
	if not head.ok: return head
	if head.revision == 2:
		return {"ok": true, "already_terminal": true} if head.document.victory == victory else bad("LOCAL_TERMINAL_CHANGED")
	if head.revision != 1 or head.file_sha256 != _binding.receipt_sha256: return bad("LOCAL_LIFECYCLE_CHANGED")
	var ended: Dictionary = head.document.duplicate(true)
	ended.generation = 2; ended.state = "terminal"; ended.victory = victory
	var written := _commit(head, ended)
	return written if not written.ok else {"ok": true, "already_terminal": false}
