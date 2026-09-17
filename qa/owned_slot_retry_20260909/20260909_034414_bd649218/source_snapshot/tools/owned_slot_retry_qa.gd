extends SceneTree
## Isolated disk-transaction QA. No real Steam, gameplay, or production document
## fixtures are created. The Slot API and shared envelope/chain remain real.
const Session = preload("res://scripts/run_world_session.gd")
var checks: Array = []
var fixture_root := "user://owned_slot_retry_qa"

class FaultSlot:
	extends "res://scripts/run_slot_store.gd"
	var fault := ""
	func _init(path: String) -> void:
		super(path)
	func _validate_document(value: Variant) -> Dictionary:
		if typeof(value) != TYPE_DICTIONARY or value.size() != 2 or not value.has_all(["generation", "value"]) or typeof(value.value) != TYPE_STRING: return bad("QA_DOCUMENT")
		if typeof(value.generation) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.generation)) or value.generation < 1 or value.generation > 2147483647 or floor(float(value.generation)) != float(value.generation): return bad("QA_GENERATION")
		var document: Dictionary = value.duplicate(true)
		document.generation = int(value.generation)
		return {"ok": true, "document": document, "revision": document.generation}
	func _write_new(path: String, raw: String, partial_checkpoint := false) -> Dictionary:
		if partial_checkpoint and fault == "pending_open":
			fault = ""
			return bad("WRITE_OPEN")
		if partial_checkpoint and fault == "pending_corrupt":
			fault = ""
			var half := raw.substr(0, floori(float(raw.length()) * 0.5))
			var written := super(path, half, false)
			return bad("WRITE_INCOMPLETE") if written.ok else written
		var result := super(path, raw, partial_checkpoint)
		if result.ok and ((partial_checkpoint and fault == "pending_readback") or (path.ends_with("writing/owner.json") and fault == "owner_readback")):
			fault = ""
			return bad("CLOSED_READBACK")
		return result
	func release() -> Dictionary:
		if fault == "release_once":
			fault = ""
			return bad("LOCK_RELEASE")
		if fault == "release_missing_owner":
			fault = ""
			if DirAccess.remove_absolute(directory.path_join("writing/owner.json")) != OK: return bad("QA_REMOVE_OWNER")
			return bad("LOCK_RELEASE")
		return super()

func _initialize() -> void:
	if not _private_profile():
		print("OWNED_SLOT_RETRY_PRIVATE_PROFILE_REQUIRED")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(fixture_root)):
		print("OWNED_SLOT_RETRY_FRESH_PROFILE_REQUIRED")
		quit(2)
		return
	_run.call_deferred()

func _private_profile() -> bool:
	if not OS.has_feature("editor") or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("LSH_OWNED_SLOT_RETRY_QA") != "1": return false
	var profile := OS.get_environment("LSH_OWNED_SLOT_RETRY_PROFILE").replace("\\", "/").trim_suffix("/")
	if not profile.is_absolute_path() or profile.is_empty() or profile.simplify_path() != profile: return false
	for name in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		if OS.get_environment(name).replace("\\", "/").trim_suffix("/") != profile.path_join(name.to_lower()): return false
	return OS.get_user_data_dir().replace("\\", "/").begins_with(profile.path_join("appdata") + "/")

func check(name: String, passed: bool) -> bool:
	checks.append({"name": name, "passed": passed})
	if not passed: print("FAIL " + name)
	return passed

func _seed(label: String) -> FaultSlot:
	var store := FaultSlot.new(fixture_root.path_join(label))
	var result: Dictionary = store.write_slot({"generation": 0, "value": "first"})
	if not check(label + " seed", result.ok and result.get("generation") == 1): return null
	return store

func _pending(label: String, fault: String) -> FaultSlot:
	var store := _seed(label)
	if store == null: return null
	store.fault = fault
	var result: Dictionary = store.write_slot({"generation": 0, "value": "second"})
	if not check(label + " retains failed transaction", not result.ok and result.get("pending_save", false) and store.has_pending_write()): return null
	return store

func _snapshot(directory: String, relative := "") -> Dictionary:
	var values := {}
	var folder := DirAccess.open(directory)
	if folder == null: return {"missing": true}
	for name in folder.get_files(): values[relative + name] = FileAccess.get_sha256(directory.path_join(name))
	for name in folder.get_directories():
		values[relative + name + "/"] = "directory"
		values.merge(_snapshot(directory.path_join(name), relative + name + "/"))
	return values

func _finish_same(store: FaultSlot, label: String, target_sha: String) -> void:
	var result: Dictionary = store.retry_pending_write()
	if not check(label + " completes original generation", result.ok and result.get("generation") == 2 and result.get("file_sha256") == target_sha): return
	check(label + " clears only completed attempt", not store.has_pending_write())
	check(label + " releases owned lock", not DirAccess.dir_exists_absolute(store.directory.path_join("writing")))
	check(label + " second retry does not create generation", store.retry_pending_write().code == "NO_PENDING_SLOT_WRITE" and store.read_slot().revision == 2)
	var next: Dictionary = store.write_slot({"generation": 0, "value": "third"})
	check(label + " later save works in same process", next.ok and next.get("generation") == 3)

func _release_failure() -> void:
	var store := _pending("release", "release_once")
	if store == null: return
	var status: Dictionary = store.pending_write_status()
	check("release retryable with committed action", status.ok and status.get("action") == "finish_committed" and status.retryable and not status.unsafe and not status.restart_required)
	var head: Dictionary = store._chain()
	check("release error already has target on disk", head.ok and head.get("revision") == 2)
	var other := FaultSlot.new(fixture_root.path_join("release"))
	check("ordinary recovery refuses live writer", other.inspect_recovery().code == "WRITER_ALIVE")
	_finish_same(store, "release", head.file_sha256)

func _pending_failure() -> void:
	var store := _pending("pending", "pending_readback")
	if store == null: return
	var pending: Dictionary = store._verified("receipt.pending")
	check("pending readback error preserves old head", store._chain().revision == 1 and pending.ok and pending.get("revision") == 2)
	var status: Dictionary = store.pending_write_status()
	check("pending retry uses validated forward action", status.ok and status.get("action") == "forward_pending" and status.retryable)
	_finish_same(store, "pending", pending.file_sha256)

func _prewrite_failure(label: String, fault: String) -> void:
	var store := _pending(label, fault)
	if store == null: return
	var status: Dictionary = store.pending_write_status()
	check(label + " missing pending retries frozen proposal", status.ok and status.get("action") == "retry_commit" and store._chain().revision == 1)
	var intent: Dictionary = store._pending_write
	var plan: Dictionary = store.inspect_owned_commit(intent.revision, intent.file_sha256, intent.proposal)
	if not check(label + " proposal verified", plan.ok): return
	_finish_same(store, label, plan.target.file_sha256)

func _bad_token() -> void:
	var store := _pending("token", "release_once")
	if store == null: return
	var before := _snapshot(store.directory)
	var original: String = store._lock_raw
	var wrong: Dictionary = JSON.parse_string(original)
	wrong.token = "11111111111111111111111111111111" if wrong.token != "11111111111111111111111111111111" else "22222222222222222222222222222222"
	store._lock_raw = JSON.stringify(wrong)
	var rejected: Dictionary = store.retry_pending_write()
	check("wrong token refused with unsafe flags", not rejected.ok and rejected.code == "OWNED_LOCK_CHANGED" and rejected.unsafe and rejected.restart_required and not rejected.retryable)
	check("wrong token does not touch files", _snapshot(store.directory) == before)
	store._lock_raw = original
	_finish_same(store, "token restored", store._chain().file_sha256)

func _other_owner() -> void:
	var store := _pending("owner", "release_once")
	if store == null: return
	var before := _snapshot(store.directory)
	store.owner = "2"
	var rejected: Dictionary = store.retry_pending_write()
	check("different owner refused", not rejected.ok and rejected.code == "OWNED_LOCK_IDENTITY" and rejected.unsafe)
	check("different owner does not touch files", _snapshot(store.directory) == before)
	store.owner = "1"
	var other := FaultSlot.new(fixture_root.path_join("owner"))
	var intent: Dictionary = store._pending_write
	var stolen: Dictionary = other.retry_owned_commit(intent.revision, intent.file_sha256, intent.proposal)
	check("new object cannot adopt same PID proposal", not stolen.ok and stolen.code == "OWNED_LOCK_REQUIRED" and _snapshot(store.directory) == before)
	_finish_same(store, "owner restored", store._chain().file_sha256)

func _corrupt_pending() -> void:
	var store := _pending("corrupt", "pending_corrupt")
	if store == null: return
	var before := _snapshot(store.directory)
	var status: Dictionary = store.pending_write_status()
	check("corrupt pending refuses automatic repair", not status.ok and status.unsafe and status.restart_required and not status.retryable)
	var rejected: Dictionary = store.retry_pending_write()
	check("corrupt pending retained byte for byte", not rejected.ok and rejected.unsafe and _snapshot(store.directory) == before and FileAccess.file_exists(store.directory.path_join("receipt.pending")))
	check("corrupt pending does not advance old head", store._chain().revision == 1)

func _changed_pending() -> void:
	var store := _pending("changed", "pending_readback")
	if store == null: return
	var path: String = store.directory.path_join("receipt.pending")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var document: Dictionary = JSON.parse_string(envelope.payload)
	document.value = "different valid proposal"
	document.generation = int(document.generation)
	envelope.payload = JSON.stringify(document)
	envelope.payload_bytes = str(envelope.payload.to_utf8_buffer().size())
	envelope.payload_sha256 = envelope.payload.sha256_text()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope)); file.flush(); file.close()
	check("changed pending remains structurally valid", store._verified("receipt.pending").ok)
	var before := _snapshot(store.directory)
	var rejected: Dictionary = store.retry_pending_write()
	check("different valid pending cannot replace original intent", not rejected.ok and rejected.code == "OWNED_PENDING_CHANGED" and rejected.unsafe and _snapshot(store.directory) == before)

func _lost_owner() -> void:
	var store := _pending("missing_owner", "release_missing_owner")
	if store == null: return
	var before := _snapshot(store.directory)
	var rejected: Dictionary = store.retry_pending_write()
	check("partial release without token stays unsafe", not rejected.ok and rejected.code == "OWNED_LOCK_MISSING" and rejected.unsafe and rejected.restart_required)
	check("partial release does not guess directory ownership", _snapshot(store.directory) == before)

func _session_retention() -> void:
	var store := _pending("session", "release_once")
	if store == null: return
	var session := Session.new({}, {}, fixture_root.path_join("unused_session"))
	session._store = store
	session._phase = "save_pending"
	var before := _snapshot(store.directory)
	check("session exposes pending disk transaction", session.has_pending_save() and session.pending_save_status().retryable)
	var refused: Dictionary = session.dispose()
	check("session refuses disposal while token is needed", not refused.ok and refused.code == "PENDING_SAVE_RETAIN_SESSION" and session.has_pending_save())
	var invalid_source: Dictionary = session.retry_pending_save(null)
	check("session will not save and quit an unrelated source", not invalid_source.ok and invalid_source.code == "PENDING_SAVE_SOURCE_CHANGED" and _snapshot(store.directory) == before)
	check("original store still completes after disposal refusal", store.retry_pending_write().ok)
	check("session disposal allowed after transaction completes", session.dispose().ok)

func _run() -> void:
	_release_failure()
	_pending_failure()
	_prewrite_failure("prewrite", "pending_open")
	_prewrite_failure("owner_readback", "owner_readback")
	_bad_token()
	_other_owner()
	_corrupt_pending()
	_changed_pending()
	_lost_owner()
	_session_retention()
	var passed := not checks.is_empty() and checks.all(func(row): return row.passed)
	var report := {"passed": passed, "checks": checks, "real_steam": false, "production_slot_document": false, "full_world_flow": false, "source_sha256": {}}
	for source_path in ["res://scripts/run_snapshot_store.gd", "res://scripts/run_slot_store.gd", "res://scripts/run_world_session.gd", "res://tools/owned_slot_retry_qa.gd"]: report.source_sha256[source_path] = FileAccess.get_sha256(source_path)
	var report_path := fixture_root.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null: print("OWNED_SLOT_RETRY_REPORT_FAILED"); quit(1); return
	file.store_string(JSON.stringify(report)); file.flush(); file.close()
	print("OWNED_SLOT_RETRY_QA " + str(checks.size()) + " " + str(passed) + " " + ProjectSettings.globalize_path(report_path))
	for name in ["Sfx", "Music"]:
		var node := root.get_node_or_null(name)
		if node != null and node.has_method("shutdown"): node.shutdown()
	for _frame in range(3): await process_frame
	quit(0 if passed else 1)
