extends "res://scripts/run_local_lifecycle.gd"
## Candidate v2 sibling: the existing classic v1 script and bytes remain untouched.
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const CAMPAIGN_SCHEMA := "local_campaign_continue_lifecycle_v2"
const DOCUMENT_FIELDS := ["schema", "generation", "token", "context", "scope", "state", "victory", "progress_state", "intent", "progress_receipt"]
const ACK_FIELDS := ["schema", "code", "persisted", "suppressed", "file_sha256"]
var _expected: Dictionary = {}
var _init_issue := ""
var _frozen_intent: Dictionary = {}
var _progress_recovery: Dictionary = {}
var _progress_acknowledged := false
var _owns_terminal_intent := false

func _init(run_token: Variant, slot_root: String, expected_context: Variant,
		installed_identity: Variant, profile_owner: Variant) -> void:
	super(run_token if typeof(run_token) == TYPE_STRING else "", slot_root)
	if not Intent.hex(run_token, 32): _init_issue = "LOCAL_CAMPAIGN_TOKEN_TYPE"; return
	_expected = Intent.scope(expected_context, installed_identity, profile_owner)
	if not _expected.ok: _init_issue = String(_expected.code)

func expected_context() -> Dictionary:
	return _expected.context.duplicate() if _init_issue.is_empty() else {}

func _guard() -> Dictionary:
	if not _init_issue.is_empty(): return bad(_init_issue)
	return super._guard()

func initialize_directory() -> Dictionary:
	if not _init_issue.is_empty(): return bad(_init_issue)
	return super.initialize_directory()

func matches_scope(context: Variant, identity: Variant, profile_owner: Variant) -> bool:
	if not _init_issue.is_empty(): return false
	var current: Dictionary = Intent.scope(context, identity, profile_owner)
	return current.ok and current == _expected

func _validate_document(value: Variant) -> Dictionary:
	if not _init_issue.is_empty(): return Intent.bad(_init_issue)
	return validate_document_data(value, token, _expected)

static func validate_document_data(value: Variant, expected_token: String, expected: Dictionary) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY and value.get("schema") == SCHEMA:
		return Intent.bad("LEGACY_CAMPAIGN_CONTEXT_UNBOUND")
	if not Intent.fields(value, DOCUMENT_FIELDS): return Intent.bad("LOCAL_CAMPAIGN_FIELDS")
	if typeof(value.schema) != TYPE_STRING or value.schema != CAMPAIGN_SCHEMA or not Intent.hex(value.token, 32) or value.token != expected_token:
		return Intent.bad("LOCAL_CAMPAIGN_IDENTITY")
	var context: Dictionary = Intent.Profiles.normalize_context(value.context)
	if not context.ok or context.context != expected.context: return Intent.bad("LOCAL_CAMPAIGN_CONTEXT")
	if not Intent.fields(value.scope, ["owner", "content_version", "engine_sha256"]): return Intent.bad("LOCAL_CAMPAIGN_SCOPE_FIELDS")
	for key in value.scope:
		if typeof(value.scope[key]) != TYPE_STRING or value.scope[key] != expected.scope[key]: return Intent.bad("LOCAL_CAMPAIGN_SCOPE_CHANGED")
	if typeof(value.state) != TYPE_STRING or typeof(value.progress_state) != TYPE_STRING \
		or typeof(value.victory) != TYPE_BOOL or not Intent.integer(value.generation, 1, 3): return Intent.bad("LOCAL_CAMPAIGN_TYPES")
	var generation := int(value.generation)
	if generation == 1:
		if value.state != "active" or value.progress_state != "none" or value.victory \
			or typeof(value.intent) != TYPE_DICTIONARY or not value.intent.is_empty() \
			or typeof(value.progress_receipt) != TYPE_DICTIONARY or not value.progress_receipt.is_empty(): return Intent.bad("LOCAL_CAMPAIGN_TRANSITION")
	else:
		if value.state != "terminal" or value.progress_state != ("pending" if generation == 2 else "applied"):
			return Intent.bad("LOCAL_CAMPAIGN_TRANSITION")
		var frozen: Dictionary = Intent.validate(value.intent, expected_token, expected)
		if not frozen.ok or frozen.intent.victory != value.victory: return Intent.bad("LOCAL_CAMPAIGN_INTENT_CHANGED")
		if generation == 2:
			if typeof(value.progress_receipt) != TYPE_DICTIONARY or not value.progress_receipt.is_empty(): return Intent.bad("LOCAL_CAMPAIGN_EARLY_ACK")
		else:
			var ack: Dictionary = _validate_ack(value.progress_receipt, value.victory)
			if not ack.ok: return ack
	var out: Dictionary = value.duplicate(true)
	out.generation = generation
	out.context = context.context
	if generation > 1: out.intent = Intent.validate(value.intent, expected_token, expected).intent
	return {"ok":true, "document":out, "revision":generation}

static func _validate_ack(value: Variant, victory: bool) -> Dictionary:
	if not Intent.fields(value, ACK_FIELDS) or typeof(value.schema) != TYPE_STRING \
		or value.schema != "campaign_progress_ack_v1" or typeof(value.code) != TYPE_STRING \
		or typeof(value.persisted) != TYPE_BOOL or typeof(value.suppressed) != TYPE_BOOL or typeof(value.file_sha256) != TYPE_STRING:
		return Intent.bad("LOCAL_CAMPAIGN_ACK_FIELDS")
	if value.suppressed: return Intent.bad("LOCAL_CAMPAIGN_QA_IS_NOT_DURABLE")
	if victory:
		if value.code != "CAMPAIGN_CFG_READBACK_VERIFIED" or not value.persisted or not Intent.hex(value.file_sha256, 64):
			return Intent.bad("LOCAL_CAMPAIGN_CFG_NOT_VERIFIED")
	elif value.code != "CAMPAIGN_PROGRESS_NOT_REQUIRED" or value.persisted or not value.file_sha256.is_empty():
		return Intent.bad("LOCAL_CAMPAIGN_LOSS_ACK")
	return {"ok":true, "ack":value.duplicate()}

func _chain() -> Dictionary:
	if not _init_issue.is_empty(): return bad(_init_issue)
	var head: Dictionary = super._chain()
	if not head.ok or head.revision == 0: return head
	# At most three records exist; MAX_RETAINED=4 cannot justify a lost genesis.
	var previous: Dictionary = {}
	for revision in range(1, int(head.revision) + 1):
		var row: Dictionary = _verified("record_%010d.json" % revision)
		if not row.ok: return row
		if revision == 3 and (row.document.intent != previous.document.intent or row.document.victory != previous.document.victory):
			return bad("LOCAL_CAMPAIGN_FROZEN_INTENT_CHANGED")
		previous = row
	return head

func _prune() -> Dictionary:
	# The v2 model needs all three fixed generations. Base classic retains two.
	# Never delete genesis or its frozen predecessor; the strict chain caps at 3.
	var checked: Dictionary = _chain()
	return {"ok":true} if checked.ok else checked

func _head() -> Dictionary:
	# Parent retries only the original owned write. Keep a separate settlement
	# capability: its generic terminal flag also becomes true for an ack retry.
	var retrying_ack: bool = not _pending.is_empty() and _pending.proposal.record.generation == 3
	var head: Dictionary = super._head()
	if head.ok and head.revision == 3 and retrying_ack: _progress_acknowledged = true
	return head

func begin() -> Dictionary:
	if not _init_issue.is_empty(): return bad(_init_issue)
	if Engine.is_in_physics_frame(): return bad("LOCAL_LIFECYCLE_PHYSICS_WRITE")
	if not _binding.is_empty(): return binding()
	var ready: Dictionary = initialize_directory()
	if not ready.ok: return ready
	var head: Dictionary = _head()
	if not head.ok: return head
	if head.revision != 0 and not _creating: return bad("LOCAL_TOKEN_EXISTS")
	if head.revision == 0:
		_creating = true
		head = _commit(head, {"schema":CAMPAIGN_SCHEMA, "generation":1, "token":token,
			"context":_expected.context.duplicate(), "scope":_expected.scope.duplicate(), "state":"active",
			"victory":false, "progress_state":"none", "intent":{}, "progress_receipt":{}})
		if not head.ok:
			if not _locked and not _lock_created: _creating = false
			return head
	if head.document.state == "terminal": return bad("LOCAL_RUN_TERMINAL")
	_binding = {"kind":"uncredited", "token":token, "receipt_sha256":head.file_sha256}
	return {"ok":true, "binding":_binding.duplicate()}

func terminal(_victory: bool) -> Dictionary:
	# Exact parent signature; campaign callers must provide a frozen intent.
	return bad("LOCAL_CAMPAIGN_FROZEN_INTENT_REQUIRED")

func terminal_with_intent(victory: bool, frozen: Variant) -> Dictionary:
	if not _init_issue.is_empty(): return bad(_init_issue)
	if Engine.is_in_physics_frame(): return bad("LOCAL_LIFECYCLE_PHYSICS_WRITE")
	var checked: Dictionary = Intent.validate(frozen, token, _expected)
	if not checked.ok or checked.intent.victory != victory: return bad("LOCAL_CAMPAIGN_FROZEN_INTENT_REQUIRED")
	if not _frozen_intent.is_empty() and _frozen_intent != checked.intent: return bad("LOCAL_TERMINAL_CHANGED")
	_frozen_intent = checked.intent.duplicate(true)
	if _binding.is_empty():
		var begun: Dictionary = begin()
		if not begun.ok: return begun
	var head: Dictionary = _head()
	if not head.ok: return head
	if head.revision >= 2:
		if not _owns_terminal_intent: return bad("LOCAL_RUN_TERMINAL")
		if head.document.intent != _frozen_intent or head.document.victory != victory: return bad("LOCAL_TERMINAL_CHANGED")
		return {"ok":true, "already_terminal":true, "local_terminal_committed":true,
			"campaign_progress_committed":head.revision == 3}
	if head.revision != 1 or head.file_sha256 != _binding.receipt_sha256: return bad("LOCAL_LIFECYCLE_CHANGED")
	var ended: Dictionary = head.document.duplicate(true)
	ended.generation = 2; ended.state = "terminal"; ended.victory = victory
	ended.progress_state = "pending"; ended.intent = _frozen_intent.duplicate(true)
	var written: Dictionary = _commit(head, ended)
	# An attempted lock held by another object cannot grant settlement capability.
	# Only this committed write or this exact retained lock may own terminal retry.
	if written.ok or _locked or _lock_created: _owns_terminal_intent = true
	if not written.ok: return written
	_committed_terminal = true
	return {"ok":true, "already_terminal":false, "local_terminal_committed":true, "campaign_progress_committed":false}

func prepare_progress_recovery() -> Dictionary:
	if not _init_issue.is_empty(): return bad(_init_issue)
	if Engine.is_in_physics_frame(): return bad("LOCAL_LIFECYCLE_PHYSICS_WRITE")
	var head: Dictionary = _head()
	if not head.ok: return head
	if head.revision == 3:
		# Historical CFG hash is a receipt, never a perpetual check on later prefs.
		return {"ok":true, "already_applied":true, "progress_replay_needed":false}
	if head.revision != 2: return bad("LOCAL_CAMPAIGN_PROGRESS_NOT_PENDING")
	_progress_recovery = {"head_sha256":head.file_sha256, "intent":head.document.intent.duplicate(true)}
	return {"ok":true, "already_applied":false, "progress_replay_needed":true,
		"intent":_progress_recovery.intent.duplicate(true), "settlement_authorized":false}

func ack_progress(value: Variant) -> Dictionary:
	if not _init_issue.is_empty(): return bad(_init_issue)
	if Engine.is_in_physics_frame(): return bad("LOCAL_LIFECYCLE_PHYSICS_WRITE")
	var head: Dictionary = _head()
	if not head.ok: return head
	if head.revision == 3:
		if not _progress_acknowledged: return bad("LOCAL_CAMPAIGN_ALREADY_APPLIED")
		var repeated: Dictionary = _validate_ack(value, head.document.victory)
		if not repeated.ok or repeated.ack != head.document.progress_receipt: return bad("LOCAL_CAMPAIGN_ACK_CHANGED")
		return {"ok":true, "already_applied":true, "settlement_authorized":_owns_terminal_intent}
	if head.revision != 2: return bad("LOCAL_CAMPAIGN_PROGRESS_NOT_PENDING")
	if not _owns_terminal_intent:
		if _progress_recovery.is_empty() or _progress_recovery.head_sha256 != head.file_sha256 \
			or _progress_recovery.intent != head.document.intent: return bad("LOCAL_CAMPAIGN_RECOVERY_PLAN_REQUIRED")
	elif _frozen_intent != head.document.intent: return bad("LOCAL_TERMINAL_CHANGED")
	var ack: Dictionary = _validate_ack(value, head.document.victory)
	if not ack.ok: return ack
	if head.document.victory:
		var path: String = Intent.Profiles.CampaignScript.SAVE_PATH
		if not FileAccess.file_exists(path): return bad("LOCAL_CAMPAIGN_CFG_ACK_READBACK_FAILED")
		var before: String = FileAccess.get_sha256(path)
		var cfg := ConfigFile.new()
		if before != ack.ack.file_sha256 or cfg.load(path) != OK \
			or not Intent.cfg_dominates(cfg, head.document.intent) \
			or FileAccess.get_sha256(path) != before: return bad("LOCAL_CAMPAIGN_CFG_ACK_READBACK_FAILED")
	var applied: Dictionary = head.document.duplicate(true)
	applied.generation = 3; applied.progress_state = "applied"; applied.progress_receipt = ack.ack
	var written: Dictionary = _commit(head, applied)
	if not written.ok: return written
	_progress_acknowledged = true
	_progress_recovery.clear()
	return {"ok":true, "already_applied":false, "local_terminal_committed":true,
		"campaign_progress_committed":true, "settlement_authorized":_owns_terminal_intent}

func inspect_campaign_marker() -> Dictionary:
	# A credited slot must be refused before Core allocation after local terminal,
	# including a crash after campaign ACK but before the independent Steam ledger.
	# A legacy credited active slot with no side journal may still resume normally.
	if not _init_issue.is_empty() or directory.is_empty(): return bad("LOCAL_CAMPAIGN_SCOPE_CHANGED")
	var path: String = directory
	while path != path.get_base_dir():
		var parent := DirAccess.open(path.get_base_dir())
		if FileAccess.file_exists(path) or (parent != null and parent.is_link(path.get_file())):
			return bad("LOCAL_CAMPAIGN_MARKER_PATH")
		path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory): return {"ok":true, "absent":true, "read_only":true}
	var before: Dictionary = inventory()
	if not before.ok: return before
	var head: Dictionary = _chain()
	if not head.ok: return head
	if head.revision >= 2: return bad("LOCAL_RUN_TERMINAL")
	if before.items.has("receipt.pending"):
		var pending: Dictionary = _verified("receipt.pending")
		if not pending.ok or pending.revision != head.revision+1 or pending.previous != head.file_sha256:
			return bad("LOCAL_CAMPAIGN_PENDING_CHAIN")
		if pending.revision >= 2: return bad("LOCAL_RUN_TERMINAL")
	if before.items.has("writing/") or before.items.has("recovering/") or before.items.has("receipt.pending"):
		return bad("RECOVERY_REQUIRED")
	var after: Dictionary = inventory()
	if not after.ok or before.items != after.items: return bad("LOCAL_CAMPAIGN_MARKER_CHANGED")
	return {"ok":true, "absent":false, "read_only":true}
