extends "res://scripts/run_snapshot_store.gd"
## Candidate only: normal release uses unique cleanup paths. Legacy fixed
## writing/recovering recovery remains the unchanged base implementation.
const Receipt = preload("res://scripts/steam_run_receipt.gd")
const CLEANUP_PREFIX := "cleanup_v1_"
const RELEASE_PREFIX := "release_v1_"
var _protocol_owned: Dictionary = {}
var _stale_abort: Dictionary = {}

func _magic() -> String:
	return "LH_STEAM_RUN_SNAPSHOTS"

func _validate_document(value: Variant) -> Dictionary:
	var model := Receipt.new()
	var opened: Dictionary = model.open_record(value, owner)
	if not opened.ok: return opened
	return {"ok":true, "document":model.capture(), "revision":int(model.capture().generation) + 1}

func _busy_release() -> Dictionary:
	return {"ok":false, "code":"WRITER_BUSY", "retryable":true, "unsafe":false,
		"restart_required":false, "owned_pending":_locked or _lock_created}

func _decimal(value: String, zero := false, limit := 2147483647) -> bool:
	return value.is_valid_int() and str(int(value)) == value and int(value) >= (0 if zero else 1) and int(value) <= limit

func _digest(value: String) -> bool:
	if value.length() != 64: return false
	for byte in value.to_utf8_buffer():
		if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102): return false
	return true

func _owner_file(path: String) -> Dictionary:
	var read: Dictionary = _read(path)
	if not read.ok: return read
	var value: Variant = JSON.parse_string(read.raw)
	if typeof(value) != TYPE_DICTIONARY or value.size() != 4 or not value.has_all(["version","owner","pid","token"]): return bad("LOCK_METADATA")
	for key in value:
		if typeof(key) != TYPE_STRING or typeof(value[key]) != TYPE_STRING: return bad("LOCK_METADATA")
	if value.version != "1" or value.owner != owner or not _decimal(value.pid, false, 4294967295) \
		or not _valid_token(value.token) or JSON.stringify(value) != read.raw: return bad("LOCK_METADATA")
	return {"ok":true, "raw":read.raw, "file_sha256":read.file_sha256, "metadata":value}

func _cleanup_name(pid: int, nonce: String) -> String:
	return CLEANUP_PREFIX + str(pid) + "_" + nonce

func _cleanup_fields(name: String) -> Dictionary:
	var parts := name.split("_")
	if parts.size() != 4 or parts[0] != "cleanup" or parts[1] != "v1" \
		or not _decimal(parts[2], false, 4294967295) or not _valid_token(parts[3]): return bad("CLEANUP_NAME")
	return {"ok":true, "name":name, "claim_pid":int(parts[2]), "claim_nonce":parts[3]}

func _release_name(claim_pid: int, claim_nonce: String, cleanup_pid: int, cleanup_nonce: String, revision: int, sha: String) -> String:
	return RELEASE_PREFIX + str(claim_pid) + "_" + claim_nonce + "_" + str(cleanup_pid) + "_" + cleanup_nonce + "_" + str(revision) + "_" + sha + ".json"

func _release_fields(name: String) -> Dictionary:
	if not name.ends_with(".json"): return bad("RELEASE_MARKER_NAME")
	var parts := name.trim_suffix(".json").split("_")
	if parts.size() != 8 or parts[0] != "release" or parts[1] != "v1" \
		or not _decimal(parts[2], false, 4294967295) or not _valid_token(parts[3]) \
		or not _decimal(parts[4], false, 4294967295) or not _valid_token(parts[5]) \
		or not _decimal(parts[6], true) or not _digest(parts[7]): return bad("RELEASE_MARKER_NAME")
	return {"ok":true, "name":name, "claim_pid":int(parts[2]), "claim_nonce":parts[3],
		"cleanup_pid":int(parts[4]), "cleanup_nonce":parts[5], "cleanup":_cleanup_name(int(parts[4]),parts[5]),
		"head_revision":int(parts[6]), "head_sha256":parts[7]}

func _layout() -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	var folder := DirAccess.open(directory)
	if folder == null: return bad("READ_OPEN")
	var records: Array[String] = []
	var markers: Array = []
	var locks: Dictionary = {}
	var items: Dictionary = {}
	var pending := false
	var file_names := folder.get_files()
	file_names.sort()
	for name: String in file_names:
		if (name.begins_with("record_") and name.ends_with(".json") and name.length() == 22) or name == "receipt.pending":
			var read: Dictionary = _read(directory.path_join(name))
			if not read.ok: return read
			items[name] = read.file_sha256
			if name == "receipt.pending": pending = true
			else: records.append(name)
		elif name.begins_with(RELEASE_PREFIX):
			var marker: Dictionary = _release_fields(name)
			if not marker.ok: return marker
			var original: Dictionary = _owner_file(directory.path_join(name))
			if not original.ok: return original
			marker["raw"] = original.raw; marker["metadata"] = original.metadata
			marker["file_sha256"] = original.file_sha256
			markers.append(marker); items[name] = original.file_sha256
		else: return bad("UNKNOWN_FILE")
	var names := folder.get_directories()
	names.sort()
	var has_protocol_barrier: bool = not markers.is_empty()
	for name: String in names:
		if name.begins_with(CLEANUP_PREFIX): has_protocol_barrier = true
	for name: String in names:
		var row := {"name":name, "kind":"legacy", "claim_pid":0, "claim_nonce":"", "has_owner":false, "raw":"", "metadata":{}}
		if name.begins_with(CLEANUP_PREFIX):
			var claim: Dictionary = _cleanup_fields(name)
			if not claim.ok: return claim
			row.kind = "cleanup"; row.claim_pid = claim.claim_pid; row.claim_nonce = claim.claim_nonce
		elif name not in ["writing","recovering"]: return bad("UNKNOWN_DIRECTORY")
		var child := DirAccess.open(directory.path_join(name))
		if child == null or not child.get_directories().is_empty(): return bad("LOCK_SHAPE")
		items[name + "/"] = "directory"
		for leaf: String in child.get_files():
			if leaf != "owner.json" or child.is_link(leaf): return bad("LOCK_SHAPE")
			row.has_owner = true
			if row.kind == "legacy":
				# Preserve the base inventory's legacy metadata reading domain.
				# A delayed writer behind our barrier is never a cleanup target.
				var read: Dictionary = _read(directory.path_join(name).path_join(leaf))
				if not read.ok: return _busy_release() if name == "writing" and has_protocol_barrier else read
				row.raw = read.raw
				items[name + "/" + leaf] = read.file_sha256
			else:
				var original: Dictionary = _owner_file(directory.path_join(name).path_join(leaf))
				if not original.ok: return original
				row.raw = original.raw; row.metadata = original.metadata
				items[name + "/" + leaf] = original.file_sha256
		locks[name] = row
	# Files and directories are separate native enumerations. A cleanup->marker
	# transition between them must not masquerade as an idle journal.
	var files_after := folder.get_files()
	var directories_after := folder.get_directories()
	files_after.sort(); directories_after.sort()
	if files_after != file_names or directories_after != names: return _busy_release()
	return {"ok":true, "records":records, "markers":markers, "locks":locks, "items":items,
		"pending":pending, "barrier":has_protocol_barrier}

func _protocol_state(layout: Dictionary) -> Dictionary:
	if not layout.barrier: return {"ok":true, "kind":"legacy"}
	if layout.locks.has("recovering"): return bad("RECOVERY_WRITER_OR_RESIDUE")
	var cleanup: Array = []
	for row: Dictionary in layout.locks.values():
		if row.kind == "cleanup": cleanup.append(row)
	if layout.markers.size() > 1 or cleanup.size() > 1 or layout.pending: return bad("PROTOCOL_LAYOUT_CHANGED")
	if layout.markers.size() == 1:
		var marker: Dictionary = layout.markers[0]
		if not cleanup.is_empty() and (cleanup[0].name != marker.cleanup or cleanup[0].has_owner): return bad("RELEASE_LAYOUT_CHANGED")
		return {"ok":true, "kind":"release", "marker":marker}
	if cleanup.size() != 1 or not cleanup[0].has_owner: return bad("UNKNOWN_OR_MISSING_LOCK")
	return {"ok":true, "kind":"cleanup", "lock":cleanup[0]}

func inventory() -> Dictionary:
	var layout: Dictionary = _layout()
	return {"ok":true, "items":layout.items} if layout.ok else layout

func _chain() -> Dictionary:
	# Preserve canonical chain checks; ignore only strictly recognized markers.
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	var names: Array[String] = layout.records
	if names.size() > MAX_RETAINED: return bad("JOURNAL_LIMIT")
	names.sort()
	var current := {"ok":true, "revision":0, "file_sha256":ZERO, "document":{}}
	for name: String in names:
		var next: Dictionary = _verified(name)
		if not next.ok: return next
		if name != "record_%010d.json" % next.revision: return bad("RECORD_NAME")
		if int(current.revision) == 0:
			if next.revision == 1 and next.previous != ZERO: return bad("GENESIS_HASH")
			if next.revision != 1 and names.size() < 2: return bad("MISSING_PREDECESSOR")
		elif next.revision != current.revision + 1 or next.previous != current.file_sha256: return bad("CHAIN_BROKEN")
		current = next
	return current

func open_head() -> Dictionary:
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	if not layout.locks.is_empty() or layout.barrier or layout.pending: return bad("RECOVERY_REQUIRED")
	return _chain()

func acquire() -> Dictionary:
	if _locked or _lock_created or not _protocol_owned.is_empty(): return bad("REENTRANT_LOCK")
	var opened: Dictionary = open_head()
	if not opened.ok: return opened
	if DirAccess.make_dir_absolute(directory.path_join("writing")) != OK: return bad("WRITER_BUSY")
	_lock_created = true
	_lock_raw = JSON.stringify({"version":"1", "owner":owner, "pid":str(OS.get_process_id()), "token":Crypto.new().generate_random_bytes(16).hex_encode()})
	var written: Dictionary = _write_new(directory.path_join("writing/owner.json"), _lock_raw)
	if not written.ok: return written
	_locked = true
	_checkpoint("lock_acquired")
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	if layout.barrier or layout.locks.has("recovering"): return _busy_release()
	# Ledger compares this fresh head against its original CAS before writing.
	return _chain()

func _owns(kind: String, name: String, raw: String) -> bool:
	return not _protocol_owned.is_empty() and _protocol_owned.kind == kind and _protocol_owned.name == name \
		and _protocol_owned.raw == raw and _protocol_owned.directory == directory \
		and _protocol_owned.claim_pid == OS.get_process_id() and _lock_raw == raw and _lock_created

func _remember(kind: String, name: String, raw: String, extra: Dictionary = {}) -> void:
	_protocol_owned = {"kind":kind, "name":name, "raw":raw, "directory":directory, "claim_pid":OS.get_process_id()}
	_protocol_owned.merge(extra, true)
	_lock_raw = raw; _locked = true; _lock_created = true

func _owned_retry_guard() -> Dictionary:
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	if not layout.barrier: return super._owned_retry_guard()
	if _protocol_owned.is_empty(): return _busy_release()
	var state: Dictionary = _protocol_state(layout)
	if not state.ok: return state
	if state.kind == "cleanup":
		var lock: Dictionary = state.lock
		return {"ok":true} if _owns("cleanup",lock.name,lock.raw) and lock.claim_pid == OS.get_process_id() else bad("OWNED_CLEANUP_SCOPE_CHANGED")
	var marker: Dictionary = state.marker
	if not _owns("release",marker.name,marker.raw) or marker.claim_pid != OS.get_process_id() \
		or marker.cleanup != _protocol_owned.cleanup or marker.head_revision != _protocol_owned.head_revision \
		or marker.head_sha256 != _protocol_owned.head_sha256: return bad("OWNED_RELEASE_SCOPE_CHANGED")
	var head: Dictionary = _chain()
	if not head.ok: return head
	return {"ok":true} if head.revision == marker.head_revision and head.file_sha256 == marker.head_sha256 else bad("OWNED_RELEASE_HEAD_CHANGED")

func commit_locked(expected_revision: int, expected_sha: String, proposal: Dictionary) -> Dictionary:
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	if layout.barrier: return _busy_release()
	return super.commit_locked(expected_revision, expected_sha, proposal)

func retry_owned_commit(expected_revision: int, expected_sha: String, proposal: Dictionary) -> Dictionary:
	var scope := {"expected_revision":expected_revision,"expected_sha":expected_sha,"proposal":proposal.duplicate(true)}
	if not _stale_abort.is_empty():
		if scope != _stale_abort: return _owned_retry_error("STALE_ABORT_SCOPE_CHANGED",true)
		return _continue_stale_abort()
	var inspected: Dictionary = inspect_owned_commit(expected_revision, expected_sha, proposal)
	if not inspected.ok:
		# After a delayed acquire, never reprepare the proposal against a new
		# head. Release our own live stale lock and require a fresh session.
		if inspected.code == "OWNED_HEAD_CHANGED" and _protocol_owned.is_empty():
			_stale_abort = scope
			return _continue_stale_abort()
		return inspected
	return super.retry_owned_commit(expected_revision, expected_sha, proposal)

func _continue_stale_abort() -> Dictionary:
	# The original CAS/proposal stays frozen across a failed cleanup release.
	# Only after its release completes may this become a restart-required error.
	var released: Dictionary = release()
	if not released.ok: return released
	_stale_abort.clear()
	var stopped: Dictionary = _owned_retry_error("OWNED_HEAD_CHANGED",true)
	stopped["own_stale_lock_released"] = true
	return stopped

func _finish_release() -> Dictionary:
	var guard: Dictionary = _owned_retry_guard()
	if not guard.ok: return guard
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	var state: Dictionary = _protocol_state(layout)
	if not state.ok or state.kind != "release": return bad("OWNED_RELEASE_REQUIRED")
	var marker: Dictionary = state.marker
	if layout.locks.has(marker.cleanup):
		# This fresh-nonce path is never the reusable writing/recovering name.
		if DirAccess.remove_absolute(directory.path_join(marker.cleanup)) != OK: return bad("LOCK_RELEASE")
	_checkpoint("release_directory_removed")
	guard = _owned_retry_guard()
	if not guard.ok: return guard
	if DirAccess.remove_absolute(directory.path_join(marker.name)) != OK: return bad("LOCK_RELEASE")
	_locked = false; _lock_created = false; _lock_raw = ""; _protocol_owned.clear()
	_checkpoint("release_marker_removed")
	return {"ok":true}

func release() -> Dictionary:
	var guard: Dictionary = _owned_retry_guard()
	if not guard.ok: return guard
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	if layout.pending: return bad("RELEASE_WITH_PENDING")
	if not layout.barrier:
		# Only this live writer may move fixed writing. Dead fixed-writing
		# recovery is not claimed by this rename; it remains the base path.
		var initial_nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
		var cleanup: String = _cleanup_name(OS.get_process_id(),initial_nonce)
		if FileAccess.file_exists(directory.path_join(cleanup)) or DirAccess.dir_exists_absolute(directory.path_join(cleanup)): return bad("TARGET_EXISTS")
		if DirAccess.rename_absolute(directory.path_join("writing"),directory.path_join(cleanup)) != OK: return bad("RENAME")
		_remember("cleanup",cleanup,_lock_raw)
		_checkpoint("release_directory_claimed")
		layout = _layout()
		if not layout.ok: return layout
	var state: Dictionary = _protocol_state(layout)
	if not state.ok: return state
	if state.kind == "release": return _finish_release()
	if state.kind != "cleanup": return bad("OWNED_CLEANUP_REQUIRED")
	guard = _owned_retry_guard()
	if not guard.ok: return guard
	var lock: Dictionary = state.lock
	var head: Dictionary = _chain()
	if not head.ok: return head
	var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var name: String = _release_name(OS.get_process_id(),nonce,lock.claim_pid,lock.claim_nonce,head.revision,head.file_sha256)
	if FileAccess.file_exists(directory.path_join(name)) or DirAccess.dir_exists_absolute(directory.path_join(name)): return bad("TARGET_EXISTS")
	if DirAccess.rename_absolute(directory.path_join(lock.name).path_join("owner.json"),directory.path_join(name)) != OK: return bad("RENAME")
	_remember("release",name,lock.raw,{"cleanup":lock.name,"head_revision":head.revision,"head_sha256":head.file_sha256})
	_checkpoint("release_marker_published")
	return _finish_release()

func inspect_recovery() -> Dictionary:
	var layout: Dictionary = _layout()
	if not layout.ok: return layout
	if not layout.barrier: return super.inspect_recovery()
	var state: Dictionary = _protocol_state(layout)
	if not state.ok: return state
	var head: Dictionary = _chain()
	if not head.ok: return head
	var source: Dictionary = state.marker if state.kind == "release" else state.lock
	var owned: bool = _owns(state.kind,source.name,source.raw)
	if not owned and (OS.is_process_running(source.claim_pid) or OS.is_process_running(int(source.metadata.pid))): return bad("WRITER_ALIVE")
	if state.kind == "release" and (head.revision != source.head_revision or head.file_sha256 != source.head_sha256): return bad("RELEASE_HEAD_CHANGED")
	if owned:
		var guard: Dictionary = _owned_retry_guard()
		if not guard.ok: return guard
	return {"ok":true,"protocol":"steam_unique_release_v1","kind":state.kind,"owned":owned,"source":source,
		"inventory":layout.items,"head_revision":head.revision,"head_sha256":head.file_sha256,
		"action":"finish_unique_release","dead_pid":int(source.metadata.pid)}

func _renamed_inventory(items: Dictionary, old_name: String, new_name: String, is_directory: bool) -> Dictionary:
	var expected: Dictionary = {}
	for key: String in items:
		var renamed: String = key
		if (is_directory and key.begins_with(old_name + "/")) or (not is_directory and key == old_name): renamed = new_name + key.substr(old_name.length())
		expected[renamed] = items[key]
	return expected

func recover(plan: Dictionary) -> Dictionary:
	var fresh: Dictionary = inspect_recovery()
	if not fresh.ok: return fresh
	if fresh != plan: return bad("RECOVERY_PLAN_CHANGED")
	if plan.get("protocol") != "steam_unique_release_v1":
		# Preserve the existing complete-pending/dead-writing recovery range,
		# including its known bare recovering / owner-removal failure windows.
		return super.recover(plan)
	if not plan.owned:
		var source: Dictionary = plan.source
		var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
		var name: String
		var extra: Dictionary = {}
		if plan.kind == "cleanup": name = _cleanup_name(OS.get_process_id(),nonce)
		else:
			name = _release_name(OS.get_process_id(),nonce,source.cleanup_pid,source.cleanup_nonce,source.head_revision,source.head_sha256)
			extra = {"cleanup":source.cleanup,"head_revision":source.head_revision,"head_sha256":source.head_sha256}
		if FileAccess.file_exists(directory.path_join(name)) or DirAccess.dir_exists_absolute(directory.path_join(name)): return bad("RECOVERY_CLAIM_COLLISION")
		# Only a non-reused fresh-nonce source is claimed, never fixed writing.
		if DirAccess.rename_absolute(directory.path_join(source.name),directory.path_join(name)) != OK: return bad("RECOVERY_BUSY")
		_remember(plan.kind,name,source.raw,extra)
		var actual: Dictionary = inventory()
		if not actual.ok: return actual
		if actual.items != _renamed_inventory(plan.inventory,source.name,name,plan.kind == "cleanup"): return bad("RECOVERY_CAS_CHANGED")
		var head: Dictionary = _chain()
		if not head.ok: return head
		if head.revision != plan.head_revision or head.file_sha256 != plan.head_sha256: return bad("RECOVERY_CAS_CHANGED")
	_checkpoint("unique_release_recovery_claimed")
	var released: Dictionary = release()
	return open_head() if released.ok else released
