extends RefCounted
## Bounded read-only catalog. Never recover a journal, build a world or settle.
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const SLOT_ROOT := "user://continue/v1"
const RUNS_ROOT := SLOT_ROOT + "/local_runs"
const MAX_RUNS := 256

class Reader extends "res://scripts/run_snapshot_store.gd":
	const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
	const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
	const Classic := preload("res://scripts/run_local_lifecycle.gd")
	var token := ""
	var model := ""
	var expected: Dictionary = {}

	func _init(run_token: String) -> void:
		token = run_token
		super("1", "user://continue/v1/local_runs/" + run_token)

	func _magic() -> String:
		return "LH_LOCAL_CONTINUE_LIFECYCLE"

	func _byte_limit() -> int:
		return 65536

	func _validate_document(value: Variant) -> Dictionary:
		if typeof(value) != TYPE_DICTIONARY or typeof(value.get("schema")) != TYPE_STRING:
			return bad("STARTUP_LOCAL_SCHEMA_REQUIRED")
		if not model.is_empty() and model != value.schema: return bad("STARTUP_LOCAL_MODEL_CHANGED")
		model = value.schema
		if model == Classic.SCHEMA:
			# Original strict classic validator, no begin/head/recovery or directory I/O.
			return Classic.new(token, "user://continue/v1")._validate_document(value)
		if model != Lifecycle.CAMPAIGN_SCHEMA: return bad("STARTUP_LOCAL_SCHEMA_UNSUPPORTED")
		var context: Dictionary = Intent.Profiles.normalize_context(value.get("context"))
		var scope: Variant = value.get("scope")
		if not context.ok or not Intent.Profiles.is_official_campaign_profile(context.profile_id) \
			or not Intent.fields(scope, ["owner", "content_version", "engine_sha256"]):
			return bad("STARTUP_LOCAL_SCOPE_FIELDS")
		if not Intent.valid_owner(scope.owner) or not Intent.hex(scope.engine_sha256, 64) \
			or typeof(scope.content_version) != TYPE_STRING or scope.content_version.is_empty() \
			or scope.content_version.length() > 256: return bad("STARTUP_LOCAL_SCOPE_TYPES")
		var historical := {"ok":true, "context":context.context, "profile_id":context.profile_id,
			"scope":scope.duplicate(true)}
		if not expected.is_empty() and expected != historical: return bad("STARTUP_LOCAL_SCOPE_CHANGED")
		expected = historical
		# Historical scope validates data only. It never grants a write capability.
		return Lifecycle.validate_document_data(value, token, expected)

	func _chain() -> Dictionary:
		var head: Dictionary = super._chain()
		if not head.ok or head.revision == 0 or model != Lifecycle.CAMPAIGN_SCHEMA: return head
		var previous: Dictionary = {}
		for revision in range(1, int(head.revision) + 1):
			var item: Dictionary = _verified("record_%010d.json" % revision)
			if not item.ok: return item
			if revision == 3 and (item.document.intent != previous.document.intent or item.document.victory != previous.document.victory):
				return bad("STARTUP_LOCAL_INTENT_CHANGED")
			previous = item
		return head

	func inspect_only() -> Dictionary:
		var before: Dictionary = inventory()
		if not before.ok: return before
		var head: Dictionary = _chain()
		if not head.ok: return head
		var selected: Dictionary = head
		var recovery_required: bool = before.items.has("writing/") or before.items.has("receipt.pending") or before.items.has("recovering/")
		if recovery_required:
			# Inspects the actual PID and full pending chain, without calling recover.
			var plan: Dictionary = inspect_recovery()
			if not plan.ok: return plan
			if before.items.has("receipt.pending"):
				selected = _verified("receipt.pending")
				if not selected.ok: return selected
				if selected.revision == 3 and (head.revision != 2 or selected.document.intent != head.document.intent \
					or selected.document.victory != head.document.victory): return bad("STARTUP_LOCAL_PENDING_INTENT_CHANGED")
		var after: Dictionary = inventory()
		if not after.ok or after.items != before.items: return bad("STARTUP_LOCAL_FILES_CHANGED")
		if selected.revision == 0: return bad("STARTUP_LOCAL_EMPTY_JOURNAL")
		return {"ok":true, "token":token, "model":model, "document":selected.document.duplicate(true),
			"head_revision":head.revision, "head_sha256":head.file_sha256,
			"recovery_required":recovery_required, "inventory":after.items.duplicate(true),
			"historical_expected":expected.duplicate(true)}

static func _bad(code: String) -> Dictionary:
	return {"ok":false, "code":code, "startup_checked":false}

static func _existing_path_safe(path: String) -> bool:
	var boundary: String = ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	var current: String = path.replace("\\", "/").simplify_path()
	if current != boundary and not current.begins_with(boundary + "/"): return false
	while current != current.get_base_dir():
		var parent := DirAccess.open(current.get_base_dir())
		if parent != null and parent.is_link(current.get_file()): return false
		if FileAccess.file_exists(current): return false
		current = current.get_base_dir()
	return true

static func _tokens(path: String) -> Dictionary:
	if not _existing_path_safe(path): return _bad("STARTUP_RUNS_PATH_OR_LINK")
	if not DirAccess.dir_exists_absolute(path): return {"ok":true, "tokens":[]}
	var folder := DirAccess.open(path)
	if folder == null or folder.list_dir_begin() != OK: return _bad("STARTUP_RUNS_OPEN")
	folder.include_hidden = true
	folder.include_navigational = false
	var tokens: Array[String] = []
	var name: String = folder.get_next()
	while not name.is_empty():
		if tokens.size() >= MAX_RUNS or not Intent.hex(name, 32) or not folder.current_is_dir() or folder.is_link(name):
			folder.list_dir_end()
			return _bad("STARTUP_RUNS_INVENTORY")
		tokens.append(name)
		name = folder.get_next()
	folder.list_dir_end()
	tokens.sort()
	return {"ok":true, "tokens":tokens}

static func scan(identity: Dictionary, profile_owner: String) -> Dictionary:
	if not Intent.Profiles.trusted_identity(identity) or not Intent.valid_owner(profile_owner):
		return _bad("STARTUP_ACTUAL_IDENTITY_REQUIRED")
	var path: String = ProjectSettings.globalize_path(RUNS_ROOT)
	var names: Dictionary = _tokens(path)
	if not names.ok: return names
	var pending: Array = []
	var historical: Array = []
	var active: Array = []
	for token: String in names.tokens:
		var reader := Reader.new(token)
		var observed: Dictionary = reader.inspect_only()
		if not observed.ok: return observed
		if observed.model != Lifecycle.CAMPAIGN_SCHEMA:
			historical.append({"token":token, "model":observed.model, "classic_unchanged":true})
			continue
		var document: Dictionary = observed.document
		if document.generation == 3 and not observed.recovery_required:
			historical.append({"token":token, "model":observed.model, "already_applied":true})
			continue
		if document.generation == 1:
			active.append({"token":token, "model":observed.model})
			continue
		# Uncommitted pending ACKs, dead terminal locks and gen2 require current
		# source/owner before any journal or CFG recovery. Never fabricate identity.
		var current: Dictionary = Intent.scope(document.context, identity, profile_owner)
		if not current.ok or current.scope != document.scope: return _bad("STARTUP_PENDING_SCOPE_CHANGED")
		pending.append({"token":token, "context":document.context.duplicate(true),
			"intent":document.intent.duplicate(true), "inventory":observed.inventory,
			"head_revision":observed.head_revision, "head_sha256":observed.head_sha256})
	var again: Dictionary = _tokens(path)
	if not again.ok or again.tokens != names.tokens: return _bad("STARTUP_RUNS_CHANGED")
	return {"ok":true, "pending":pending, "historical":historical, "active":active,
		"read_only":true, "settlement_authorized":false}
