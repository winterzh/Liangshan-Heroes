extends "res://scripts/run_snapshot_store.gd"
## Candidate controlled replacement. Never rename over an existing Windows file:
## Godot's different-name rename deletes that destination before MoveFileW.
## Keep the original in our owned stage until CFG and applied journal read back.
## Normal process interruption is the target; power-loss atomicity is not claimed.
const Values := preload("res://scripts/run_campaign_cfg_values.gd")
const CFG_PATH := "user://campaign.cfg"
const STAGES := "user://campaign_cfg_candidates/v1"
const CFG_SCHEMA := "campaign_cfg_transaction_v1"
const CFG_LIMIT := 2 * 1024 * 1024
const RECORD_FIELDS := ["schema", "generation", "state", "transaction", "original_sha256",
	"candidate_sha256", "semantics_sha256", "original_owner", "target_owner", "content_version",
	"engine_sha256", "operation", "run_token", "intent_sha256"]
const REQUEST_FIELDS := ["target_owner", "content_version", "engine_sha256", "operation", "run_token", "intent_sha256"]
var _active: Dictionary = {}
var _pending_record: Dictionary = {}
var _frozen_cfg: ConfigFile
var _recovery_scope: Dictionary = {}

func _init() -> void:
	super("1", "user://campaign_cfg_transactions/v1")

func _magic() -> String:
	return "LH_CAMPAIGN_CFG_TRANSACTION"

func _byte_limit() -> int:
	return 65536

static func _fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return value.has_all(names)

static func _hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for byte in value.to_utf8_buffer():
		if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102): return false
	return true

func _request(value: Variant) -> bool:
	if not _fields(value, REQUEST_FIELDS): return false
	for key in value:
		if typeof(value[key]) != TYPE_STRING: return false
	if value.operation not in ["progress", "prefs", "cloud"] or not _hash(value.engine_sha256) \
		or value.content_version.is_empty() or value.content_version.length() > 256 \
		or (not value.target_owner.is_empty() and not _valid_owner(value.target_owner)): return false
	if value.operation == "progress": return _valid_token(value.run_token) and _hash(value.intent_sha256)
	return value.run_token.is_empty() and value.intent_sha256.is_empty()

func _validate_document(value: Variant) -> Dictionary:
	if not _fields(value, RECORD_FIELDS): return bad("CFG_TRANSACTION_FIELDS")
	for key in value:
		if key != "generation" and typeof(value[key]) != TYPE_STRING: return bad("CFG_TRANSACTION_TYPES")
	if typeof(value.generation) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.generation)) \
		or value.generation != floor(float(value.generation)) or value.generation < 1 or value.generation > 2147483647:
		return bad("CFG_TRANSACTION_GENERATION")
	if value.schema != CFG_SCHEMA or value.state not in ["prepared", "applied"] \
		or not _valid_token(value.transaction) or not _hash(value.original_sha256) \
		or not _hash(value.candidate_sha256) or not _hash(value.semantics_sha256) \
		or (not value.original_owner.is_empty() and not _valid_owner(value.original_owner)):
		return bad("CFG_TRANSACTION_IDENTITY")
	var request: Dictionary = {}
	for key in REQUEST_FIELDS: request[key] = value[key]
	if not _request(request): return bad("CFG_TRANSACTION_SCOPE")
	var record: Dictionary = value.duplicate(true)
	record.generation = int(value.generation)
	return {"ok":true, "document":record, "revision":record.generation}

func _chain() -> Dictionary:
	var head: Dictionary = super._chain()
	if not head.ok or head.revision == 0: return head
	if head.document.state == "applied":
		if head.revision < 2: return bad("CFG_APPLIED_PREDECESSOR_REQUIRED")
		var previous: Dictionary = _verified("record_%010d.json" % (int(head.revision) - 1))
		if not previous.ok or previous.document.state != "prepared": return bad("CFG_APPLIED_PREDECESSOR_REQUIRED")
		for key in RECORD_FIELDS:
			if key not in ["generation", "state"] and previous.document[key] != head.document[key]: return bad("CFG_APPLIED_PROPOSAL_CHANGED")
	return head

func _head() -> Dictionary:
	if not _pending_record.is_empty():
		var retried: Dictionary = retry_owned_commit(_pending_record.revision, _pending_record.sha, _pending_record.proposal)
		if not retried.ok: return retried
		_pending_record.clear()
	var head: Dictionary = open_head()
	if not head.ok and head.code == "RECOVERY_REQUIRED":
		var plan: Dictionary = inspect_recovery()
		if not plan.ok: return plan
		var current: Dictionary = _chain()
		if not current.ok: return current
		if current.revision > 0 and current.document.state == "prepared" and not _scope_matches(current.document):
			return bad("CFG_RECOVERY_SCOPE_CHANGED")
		if plan.inventory.has("receipt.pending"):
			var pending: Dictionary = _verified("receipt.pending")
			if not pending.ok: return pending
			if not _scope_matches(pending.document): return bad("CFG_RECOVERY_SCOPE_CHANGED")
		head = recover(plan)
	return head

func _scope_matches(record: Dictionary) -> bool:
	if not _request(_recovery_scope): return false
	for key in REQUEST_FIELDS:
		if record[key] != _recovery_scope[key]: return false
	return true

func _no_links(path: String) -> bool:
	var boundary: String = ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	var current: String = path.replace("\\", "/").simplify_path()
	if current != boundary and not current.begins_with(boundary + "/"): return false
	while current != current.get_base_dir():
		var folder := DirAccess.open(current.get_base_dir())
		if folder == null or folder.is_link(current.get_file()): return false
		current = current.get_base_dir()
	return true

func _cfg_sha(path: String) -> Dictionary:
	if not _no_links(path) or DirAccess.dir_exists_absolute(path): return bad("CFG_PATH_OR_LINK")
	if not FileAccess.file_exists(path): return {"ok":true, "sha256":ZERO}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return bad("CFG_READ_OPEN")
	var size: int = file.get_length()
	file.close()
	if size < 0 or size > CFG_LIMIT: return bad("CFG_SIZE")
	var digest: String = FileAccess.get_sha256(path)
	return {"ok":true, "sha256":digest} if _hash(digest) else bad("CFG_HASH")

func _stable_cfg(path: String, expected_sha: String) -> Dictionary:
	var before: Dictionary = _cfg_sha(path)
	if not before.ok or before.sha256 != expected_sha or expected_sha == ZERO: return bad("CFG_READBACK_SHA")
	var cfg := ConfigFile.new()
	var loaded: int = cfg.load(path)
	if loaded != OK: return {"ok":false, "code":"CFG_READBACK_LOAD", "native_error":loaded}
	var semantics: Dictionary = Values.semantics(cfg)
	var after: Dictionary = _cfg_sha(path)
	if not semantics.ok or not after.ok or after.sha256 != before.sha256: return bad("CFG_READBACK_CHANGED")
	return {"ok":true, "cfg":cfg, "semantics":semantics.sections,
		"semantics_sha256":JSON.stringify(semantics.sections).sha256_text(), "file_sha256":after.sha256}

func busy() -> bool:
	return not _active.is_empty() or not _pending_record.is_empty() or _locked or _lock_created

func begin_write(request: Variant) -> Dictionary:
	if Engine.is_in_physics_frame(): return bad("CFG_PHYSICS_WRITE")
	if OS.get_environment("CAMPAIGN_QA") == "1": return bad("CFG_QA_NOT_DURABLE")
	if not _request(request): return bad("CFG_REQUEST_SCOPE")
	if busy(): return bad("CFG_OWNED_OPERATION_PENDING")
	var ready: Dictionary = initialize_directory()
	if not ready.ok: return ready
	_recovery_scope = request.duplicate()
	var head: Dictionary = _head()
	if not head.ok: return head
	if head.revision > 0 and head.document.state == "prepared": return bad("CFG_PENDING_RECOVERY_REQUIRED")
	var locked: Dictionary = acquire()
	if not locked.ok: return locked
	var prior: Dictionary = _cfg_sha(ProjectSettings.globalize_path(CFG_PATH))
	if not prior.ok: return _release_refusal(prior)
	var cfg := ConfigFile.new()
	if prior.sha256 != ZERO:
		var read: Dictionary = _stable_cfg(ProjectSettings.globalize_path(CFG_PATH), prior.sha256)
		if not read.ok: return _release_refusal(read)
		cfg = read.cfg
	var prior_owner: Variant = cfg.get_value("progress", "owner", "")
	if typeof(prior_owner) != TYPE_STRING or (not prior_owner.is_empty() and not _valid_owner(prior_owner)):
		return _release_refusal(bad("CFG_EXISTING_OWNER_INVALID"))
	if request.operation != "cloud" and prior_owner != request.target_owner:
		return _release_refusal(bad("CFG_PROFILE_OWNER_CHANGED"))
	_active = {"request":request.duplicate(), "original_sha256":prior.sha256, "original_owner":prior_owner,
		"transaction":Crypto.new().generate_random_bytes(16).hex_encode(), "stage":"building"}
	return {"ok":true, "cfg":cfg, "original_sha256":prior.sha256}

func _release_refusal(reason: Dictionary) -> Dictionary:
	var released: Dictionary = release()
	if released.ok:
		_active.clear(); _frozen_cfg = null
	return reason if released.ok else {"ok":false, "code":released.code, "original_error":reason.code, "owned_pending":true}

func _existing_parents_safe(path: String) -> bool:
	var boundary: String = ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	var normalized: String = path.replace("\\", "/").simplify_path()
	if not normalized.begins_with(boundary + "/") or not _no_links(boundary): return false
	var current: String = boundary
	for leaf in normalized.trim_prefix(boundary + "/").split("/"):
		if leaf in ["", ".", ".."]: return false
		var parent := DirAccess.open(current)
		if parent == null: return false
		if parent.is_link(leaf) or FileAccess.file_exists(current.path_join(leaf)): return false
		current = current.path_join(leaf)
		if not DirAccess.dir_exists_absolute(current): return true
	return true

func _stage_dir(record: Dictionary) -> String:
	return ProjectSettings.globalize_path(STAGES).path_join(record.transaction)

func commit_prepared(cfg: ConfigFile) -> Dictionary:
	if Engine.is_in_physics_frame(): return bad("CFG_PHYSICS_WRITE")
	if _active.is_empty() or _active.stage != "building": return bad("CFG_PREPARATION_REQUIRED")
	var owned: Dictionary = _owned_retry_guard()
	if not owned.ok: return owned
	var expected: Dictionary = Values.semantics(cfg)
	if not expected.ok: return _release_refusal(expected)
	var target_owner: Variant = cfg.get_value("progress", "owner", "")
	if typeof(target_owner) != TYPE_STRING or target_owner != _active.request.target_owner: return bad("CFG_CANDIDATE_OWNER_CHANGED")
	var estimated_bytes: int = cfg.encode_to_text().to_utf8_buffer().size()
	if estimated_bytes < 1 or estimated_bytes > CFG_LIMIT: return bad("CFG_CANDIDATE_SIZE")
	# Full encode_to_text does not escape ']' section names in the Windows tag.
	# Freeze supported data into an unshared ConfigFile; real save escapes them.
	_frozen_cfg = ConfigFile.new()
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			var value: Variant = cfg.get_value(section, key)
			if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY]: value = value.duplicate(true)
			elif typeof(value) in [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
				TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]:
				value = value.duplicate()
			_frozen_cfg.set_value(section, key, value)
	_active.semantics_sha256 = JSON.stringify(expected.sections).sha256_text()
	_active.stage = "staging"
	return retry_write()

func _commit_record(head: Dictionary, record: Dictionary) -> Dictionary:
	var proposal := {"record":record.duplicate(true), "sha256":JSON.stringify(record).sha256_text()}
	_pending_record = {"revision":head.revision, "sha":head.file_sha256, "proposal":proposal}
	var result: Dictionary = commit_locked(head.revision, head.file_sha256, proposal)
	if result.ok: _pending_record.clear()
	return result

func _lock_for_resume() -> Dictionary:
	if _locked or _lock_created:
		var owned: Dictionary = _owned_retry_guard()
		if not owned.ok: return owned
		_locked = true
		return _chain()
	return acquire()

func retry_write() -> Dictionary:
	if Engine.is_in_physics_frame(): return bad("CFG_PHYSICS_WRITE")
	if OS.get_environment("CAMPAIGN_QA") == "1": return bad("CFG_QA_NOT_DURABLE")
	if _active.is_empty() or _active.stage == "building": return bad("CFG_FROZEN_PROPOSAL_REQUIRED")
	var head: Dictionary = _head() if not _pending_record.is_empty() else _chain()
	if not head.ok: return head
	var locked: Dictionary = _lock_for_resume()
	if not locked.ok: return locked
	if _active.stage == "staging":
		var parent: String = ProjectSettings.globalize_path(STAGES)
		if not _existing_parents_safe(parent) or DirAccess.make_dir_recursive_absolute(parent) != OK \
			or not _no_links(parent): return bad("CFG_STAGE_PARENT")
		var directory_path: String = parent.path_join(_active.transaction)
		if not _active.has("stage_created"):
			if DirAccess.make_dir_absolute(directory_path) != OK: return bad("CFG_STAGE_EXISTS_OR_CREATE_FAILED")
			_active.stage_created = true
		if not _no_links(directory_path): return bad("CFG_STAGE_LINK")
		var candidate: String = directory_path.path_join("candidate.cfg")
		if not _active.has("candidate_sha256"):
			if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate): return bad("CFG_UNCONFIRMED_STAGE_PRESERVED")
			if _frozen_cfg == null: return bad("CFG_FROZEN_SOURCE_REQUIRED")
			var check: Dictionary = Values.semantics(_frozen_cfg)
			if not check.ok or JSON.stringify(check.sections).sha256_text() != _active.semantics_sha256: return bad("CFG_FROZEN_SEMANTICS")
			var saved: int = _frozen_cfg.save(candidate)
			if saved != OK: return {"ok":false, "code":"CFG_STAGE_WRITE", "native_error":saved, "owned_pending":true}
			var digest: Dictionary = _cfg_sha(candidate)
			if not digest.ok: return digest
			_active.candidate_sha256 = digest.sha256
		var read: Dictionary = _stable_cfg(candidate, _active.candidate_sha256)
		if not read.ok or read.semantics_sha256 != _active.semantics_sha256: return bad("CFG_STAGE_READBACK")
		var prepared: Dictionary = _active.request.duplicate()
		prepared.merge({"schema":CFG_SCHEMA, "generation":int(locked.revision) + 1, "state":"prepared",
			"transaction":_active.transaction, "original_sha256":_active.original_sha256,
			"original_owner":_active.original_owner, "candidate_sha256":_active.candidate_sha256,
			"semantics_sha256":_active.semantics_sha256})
		var written: Dictionary = _commit_record(locked, prepared)
		if not written.ok:
			_active.stage = "prepared_commit_pending"
			return written
		_active.stage = "replacing"
		_active.record = prepared
		locked = written
	elif _active.stage == "prepared_commit_pending":
		if locked.revision < 1 or locked.document.state != "prepared" or locked.document.transaction != _active.transaction:
			return bad("CFG_PREPARED_RETRY_CHANGED")
		_active.record = locked.document.duplicate(true)
		_active.stage = "replacing"
	if _active.stage == "replacing":
		if locked.revision < 1 or locked.document != _active.record: return bad("CFG_PREPARED_HEAD_CHANGED")
		var replaced: Dictionary = _replace_and_verify(_active.record)
		if not replaced.ok: return replaced
		var applied: Dictionary = _active.record.duplicate(true)
		applied.generation = int(locked.revision) + 1
		applied.state = "applied"
		var written: Dictionary = _commit_record(locked, applied)
		if not written.ok:
			_active.stage = "applied_commit_pending"
			return written
		_active.stage = "releasing"
		_active.record = applied
	elif _active.stage == "applied_commit_pending":
		if locked.revision < 1 or locked.document.state != "applied" or locked.document.transaction != _active.transaction:
			return bad("CFG_APPLIED_RETRY_CHANGED")
		_active.record = locked.document.duplicate(true)
		_active.stage = "releasing"
	if _active.stage != "releasing": return bad("CFG_TRANSACTION_STAGE")
	var final: Dictionary = _stable_cfg(ProjectSettings.globalize_path(CFG_PATH), _active.record.candidate_sha256)
	if not final.ok or final.semantics_sha256 != _active.record.semantics_sha256: return bad("CFG_FINAL_CHANGED")
	var released: Dictionary = release()
	if not released.ok: return released
	var receipt := {"ok":true, "code":"CAMPAIGN_CFG_READBACK_VERIFIED", "persisted":true, "suppressed":false,
		"file_sha256":final.file_sha256, "transaction":_active.transaction, "normal_process_readback":true,
		"power_loss_atomicity_qualified":false, "external_uncooperative_writer_atomic_CAS":false}
	receipt.owned_stage_cleanup = _cleanup_completed_stage(_active.record)
	_active.clear(); _frozen_cfg = null
	return receipt

func _cleanup_completed_stage(record: Dictionary) -> Dictionary:
	# Only the successful operation's own files, with exact hashes, can be removed.
	# Failed/unknown stages are retained. No recursive deletion and no target CFG.
	var stage: String = _stage_dir(record)
	if not _no_links(stage): return bad("CFG_COMPLETED_STAGE_LINK")
	for name in ["previous.cfg", "candidate.cfg"]:
		var path: String = stage.path_join(name)
		var digest: Dictionary = _cfg_sha(path)
		if not digest.ok: return digest
		if digest.sha256 == ZERO: continue
		var expected: String = record.original_sha256 if name == "previous.cfg" else record.candidate_sha256
		if digest.sha256 != expected: return bad("CFG_COMPLETED_STAGE_CHANGED")
		if DirAccess.remove_absolute(path) != OK: return bad("CFG_COMPLETED_STAGE_REMOVE")
	var folder := DirAccess.open(stage)
	if folder == null or not folder.get_files().is_empty() or not folder.get_directories().is_empty(): return bad("CFG_COMPLETED_STAGE_RESIDUE")
	return {"ok":true} if DirAccess.remove_absolute(stage) == OK else bad("CFG_COMPLETED_STAGE_FINISH")

func _replace_and_verify(record: Dictionary) -> Dictionary:
	var owned: Dictionary = _owned_retry_guard()
	if not owned.ok: return owned
	var target: String = ProjectSettings.globalize_path(CFG_PATH)
	var stage: String = _stage_dir(record)
	var candidate: String = stage.path_join("candidate.cfg")
	var backup: String = stage.path_join("previous.cfg")
	if not _no_links(stage): return bad("CFG_STAGE_LINK")
	var current: Dictionary = _cfg_sha(target)
	var previous: Dictionary = _cfg_sha(backup)
	if not current.ok or not previous.ok: return bad("CFG_REPLACEMENT_PATH")
	if current.sha256 != record.candidate_sha256:
		var staged: Dictionary = _stable_cfg(candidate, record.candidate_sha256)
		if not staged.ok or staged.semantics_sha256 != record.semantics_sha256: return bad("CFG_CANDIDATE_CHANGED")
		if current.sha256 == record.original_sha256 and record.original_sha256 != ZERO and previous.sha256 == ZERO:
			_checkpoint("cfg_before_backup")
			# Re-read after the last observable stop; a changed original remains at
			# its public CFG path, rather than first being moved to a backup.
			current = _cfg_sha(target)
			previous = _cfg_sha(backup)
			if not current.ok or not previous.ok or current.sha256 != record.original_sha256 or previous.sha256 != ZERO:
				return bad("CFG_CAS_CHANGED_PRESERVED")
			# Never overwrite a destination, including an unknown backup.
			if FileAccess.file_exists(backup) or DirAccess.rename_absolute(target, backup) != OK: return bad("CFG_BACKUP_RENAME")
			_checkpoint("cfg_after_backup")
			previous = _cfg_sha(backup)
			current = _cfg_sha(target)
		if not current.ok or not previous.ok or current.sha256 != ZERO or previous.sha256 != record.original_sha256:
			return bad("CFG_CAS_CHANGED_PRESERVED")
		owned = _owned_retry_guard()
		if not owned.ok: return owned
		_checkpoint("cfg_before_install")
		if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target) \
			or DirAccess.rename_absolute(candidate, target) != OK: return bad("CFG_INSTALL_RENAME")
		_checkpoint("cfg_after_install")
	elif previous.sha256 != record.original_sha256 \
		and not (record.original_sha256 == record.candidate_sha256 and previous.sha256 == ZERO):
		return bad("CFG_BACKUP_CHANGED")
	var verified: Dictionary = _stable_cfg(target, record.candidate_sha256)
	if not verified.ok or verified.semantics_sha256 != record.semantics_sha256: return bad("CFG_INSTALLED_READBACK")
	return verified

func pending_status() -> Dictionary:
	# Pure metadata read. Startup validates the corresponding local run intent
	# BEFORE calling recovery, even when a dead lock has a closed pending record.
	if not DirAccess.dir_exists_absolute(directory): return {"ok":true, "pending":false}
	var inv: Dictionary = inventory()
	if not inv.ok: return inv
	var head: Dictionary = _chain()
	if not head.ok: return head
	if inv.items.has("receipt.pending"):
		var pending: Dictionary = _verified("receipt.pending")
		if not pending.ok: return pending
		if pending.revision != head.revision + 1 or pending.previous != head.file_sha256: return bad("CFG_PENDING_CHAIN")
		head = pending
	if head.revision == 0: return {"ok":true, "pending":false}
	return {"ok":true, "pending":head.document.state == "prepared" or inv.items.has("writing/"),
		"document":head.document.duplicate(true), "file_sha256":head.file_sha256}

func recover_pending(identity: Dictionary, profile_owner: String, expected_progress: Dictionary = {}) -> Dictionary:
	# Startup must call this before Campaign._load or any prefs/cloud writer.
	# It validates fixed metadata only; no Battle, Mission, callback or reward.
	if Engine.is_in_physics_frame() or busy(): return bad("CFG_RECOVERY_CONTEXT")
	if typeof(identity.get("content_version")) != TYPE_STRING or typeof(identity.get("engine_binary_sha256")) != TYPE_STRING:
		return bad("CFG_RECOVERY_SCOPE_TYPES")
	var status: Dictionary = pending_status()
	if not status.ok: return status
	if status.get("pending", false):
		var pending: Dictionary = status.document
		if pending.content_version != identity.content_version or pending.engine_sha256 != identity.engine_binary_sha256 \
			or pending.target_owner != profile_owner: return bad("CFG_RECOVERY_SCOPE_CHANGED")
		if pending.operation == "progress" and (not _fields(expected_progress, ["run_token", "intent_sha256"]) \
			or expected_progress.run_token != pending.run_token or expected_progress.intent_sha256 != pending.intent_sha256):
			return bad("CFG_RECOVERY_FROZEN_INTENT_REQUIRED")
		_recovery_scope = {}
		for key in REQUEST_FIELDS: _recovery_scope[key] = pending[key]
	var ready: Dictionary = initialize_directory()
	if not ready.ok: return ready
	var head: Dictionary = _head()
	if not head.ok: return head
	if head.revision == 0 or head.document.state == "applied": return {"ok":true, "pending":false}
	var record: Dictionary = head.document
	if typeof(identity.get("content_version")) != TYPE_STRING or typeof(identity.get("engine_binary_sha256")) != TYPE_STRING \
		or record.content_version != identity.content_version or record.engine_sha256 != identity.engine_binary_sha256 \
		or record.target_owner != profile_owner: return bad("CFG_RECOVERY_SCOPE_CHANGED")
	_active = {"stage":"replacing", "transaction":record.transaction, "record":record.duplicate(true)}
	return retry_write()
