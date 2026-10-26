extends "res://scripts/run_snapshot_store.gd"
## Steam receipt specialization. File layout/envelope remain version 1.
## The model reads v2 unchanged; only an explicit ledger transaction writes v3.
const Receipt = preload("res://scripts/steam_run_receipt.gd")
var _owned_release := OwnedRelease.new()

func _magic() -> String:
	return "LH_STEAM_RUN_SNAPSHOTS"

func _validate_document(value: Variant) -> Dictionary:
	var model := Receipt.new()
	var opened: Dictionary = model.open_record(value, owner)
	if not opened.ok: return opened
	return {"ok": true, "document": model.capture(), "revision": int(model.capture().generation) + 1}

func release() -> Dictionary:
	return _owned_release.release_store(self)

func _owned_retry_guard() -> Dictionary:
	return _owned_release.guard_removed(self) if _owned_release.pending() else super._owned_retry_guard()

class OwnedRelease extends RefCounted:
	# Retain removal of this exact owner file if the now-empty directory removal
	# fails. This never deletes pending/data files or adopts another writer's lock.
	var _removed := false
	var _holder: WeakRef
	var _directory := ""
	var _raw := ""
	var _head: Dictionary = {}

	func pending() -> bool:
		return _removed

	func _bad(code: String) -> Dictionary:
		return {"ok":false, "code":code, "owned_pending":true}

	func guard_removed(store: RefCounted) -> Dictionary:
		if not _removed or _holder == null or _holder.get_ref() != store or store.directory != _directory \
			or store._lock_raw != _raw or not store._lock_created: return _bad("OWNED_RELEASE_SCOPE_CHANGED")
		var guard: Dictionary = store._guard()
		if not guard.ok: return guard
		var folder := DirAccess.open(_directory.path_join("writing"))
		if folder == null or not folder.get_files().is_empty() or not folder.get_directories().is_empty():
			return _bad("OWNED_RELEASE_DIRECTORY_CHANGED")
		var head: Dictionary = store._chain()
		if not head.ok or head.revision != _head.revision or head.file_sha256 != _head.file_sha256:
			return _bad("OWNED_RELEASE_HEAD_CHANGED")
		return {"ok":true}

	func release_store(store: RefCounted) -> Dictionary:
		if not _removed:
			var owned: Dictionary = store._owned_retry_guard()
			if not owned.ok: return owned
			var head: Dictionary = store._chain()
			if not head.ok: return head
			_holder = weakref(store); _directory = store.directory; _raw = store._lock_raw
			_head = {"revision":head.revision, "file_sha256":head.file_sha256}
			if DirAccess.remove_absolute(_directory.path_join("writing/owner.json")) != OK:
				return _bad("LOCK_RELEASE")
			_removed = true
		var safe: Dictionary = guard_removed(store)
		if not safe.ok: return safe
		if DirAccess.remove_absolute(_directory.path_join("writing")) != OK: return _bad("LOCK_RELEASE")
		store._locked = false; store._lock_created = false
		_removed = false; _head.clear(); _holder = null; _directory = ""; _raw = ""
		return {"ok":true}
