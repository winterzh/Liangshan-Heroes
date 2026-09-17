extends RefCounted
## Typed read-only facade. A requested snapshot identifies its read operation;
## it is NOT an acknowledgement of StoreStats or a local receipt generation.
const Catalog = preload("res://scripts/steam_achievement_catalog.gd")
var native: Object
var _owner := ""
var _pending := ""

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _query(command: String) -> Dictionary:
	if native == null: return _bad("READER_UNAVAILABLE")
	var raw: Variant = native.call("query", command)
	if typeof(raw) != TYPE_STRING: return _bad("BAD_NATIVE_RESPONSE")
	var value: Variant = JSON.parse_string(raw)
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("ok")) != TYPE_BOOL: return _bad("BAD_NATIVE_RESPONSE")
	return value

func attach(owner: String) -> Dictionary:
	if native != null or not ClassDB.class_exists("SteamStatsReader"): return _bad("READER_UNAVAILABLE")
	native = ClassDB.instantiate("SteamStatsReader")
	_owner = owner
	return _identity()

func _identity() -> Dictionary:
	var identity := _query("identity")
	if not identity.ok: return identity
	if identity.get("owner") != _owner or identity.get("app") != Catalog.APP_ID: return _bad("WRONG_IDENTITY")
	return identity

func current_snapshot() -> Dictionary:
	return _snapshot(true, "")

func request() -> Dictionary:
	if not _pending.is_empty(): return _bad("READ_BUSY")
	var identity := _identity()
	if not identity.ok: return identity
	var started := _query("request " + _owner)
	if not started.ok: return started
	var handle: Variant = started.get("handle")
	if typeof(handle) != TYPE_STRING or not _valid_handle(handle): return _bad("BAD_NATIVE_HANDLE")
	_pending = handle
	return {"ok": true, "handle": _pending}

func poll(handle: String) -> Dictionary:
	if handle.is_empty() or handle != _pending: return _bad("UNKNOWN_HANDLE")
	var identity := _identity()
	if not identity.ok: return identity
	var result := _query("poll " + handle)
	if not result.ok:
		_pending = ""
		return result
	if result.get("handle") != handle or typeof(result.get("pending")) != TYPE_BOOL: return _bad("BAD_NATIVE_RESPONSE")
	if result.pending: return result
	_pending = ""
	if result.get("owner") != _owner: return _bad("WRONG_IDENTITY")
	return _snapshot(false, handle)

func _snapshot(current: bool, handle: String) -> Dictionary:
	var identity := _identity()
	if not identity.ok: return identity
	var stats := {}
	var unlocked := {}
	var prefix := "current_" if current else "user_"
	var source := "current_cache" if current else "requested_user_cache"
	for name in Catalog.STATS:
		var row := _query(prefix + "stat " + name)
		if not row.ok: return row
		if row.get("owner") != _owner or row.get("handle") != handle or row.get("source") != source: return _bad("MIXED_SNAPSHOT")
		var value: Variant = row.get("value")
		# JSON numbers are floats; accept only exact, non-negative int32 values.
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return _bad("BAD_STAT")
		if not is_finite(float(value)) or value < 0 or value > 2147483647 or float(int(value)) != float(value): return _bad("BAD_STAT")
		stats[name] = int(value)
	for entry in Catalog.entries():
		var row := _query(prefix + "achievement " + entry.id)
		if not row.ok: return row
		if row.get("owner") != _owner or row.get("handle") != handle or row.get("source") != source: return _bad("MIXED_SNAPSHOT")
		if typeof(row.get("value")) != TYPE_BOOL: return _bad("BAD_ACHIEVEMENT")
		unlocked[entry.id] = row.value
	identity = _identity()
	if not identity.ok: return identity
	return {"ok": true, "owner": _owner, "source": source, "handle": handle, "stats": stats, "unlocked": unlocked}

func _valid_handle(value: String) -> bool:
	if value.length() != 16 or value == "0000000000000000": return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true
