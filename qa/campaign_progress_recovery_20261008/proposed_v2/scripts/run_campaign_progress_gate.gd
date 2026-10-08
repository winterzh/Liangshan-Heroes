extends RefCounted
## Shared process gate. A retained recovery transaction is never silently dropped.
const COORDINATOR_PATH := "res://scripts/run_campaign_progress_coordinator.gd"
static var _startup_checked := false
static var _pending: Dictionary = {}
static var _holder: WeakRef

static func _bad(code: String) -> Dictionary:
	return {"ok":false, "code":code}

static func _actual_holder(value: Variant) -> bool:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value) or not value is RefCounted: return false
	var script: Resource = ResourceLoader.load(COORDINATOR_PATH, "Script", ResourceLoader.CACHE_MODE_REUSE)
	return script != null and value.get_script() == script

static func _scope(value: Variant) -> bool:
	var names := ["token", "intent_sha256", "owner", "content_version", "engine_sha256"]
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size() or not value.has_all(names): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in names or typeof(value[key]) != TYPE_STRING: return false
	if value.token.length() != 32 or value.intent_sha256.length() != 64 or value.engine_sha256.length() != 64 \
		or value.content_version.is_empty() or value.content_version.length() > 256: return false
	for field in ["token", "intent_sha256", "engine_sha256"]:
		for byte in value[field].to_utf8_buffer():
			if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102): return false
	return value.owner.is_empty() or (value.owner.length() <= 20 and value.owner.is_valid_int() \
		and not value.owner.begins_with("0") and not value.owner.begins_with("+") \
		and not value.owner.begins_with("-") and value.owner.to_int() > 0)

static func status() -> Dictionary:
	return {"startup_checked":_startup_checked, "progress_pending":not _pending.is_empty(),
		"background_writes_allowed":_startup_checked and _pending.is_empty()}

static func background_allowed() -> bool:
	return _startup_checked and _pending.is_empty()

static func enter(holder: Variant, scope: Variant, startup_recovery: bool = false) -> Dictionary:
	if not _actual_holder(holder) or not _scope(scope): return _bad("CAMPAIGN_PROGRESS_GATE_SOURCE")
	if not _startup_checked and not startup_recovery: return _bad("CAMPAIGN_STARTUP_RECOVERY_REQUIRED")
	if not _pending.is_empty():
		if _holder == null or _holder.get_ref() != holder or _pending != scope: return _bad("CAMPAIGN_PROGRESS_PENDING")
		return {"ok":true, "owned_retry":true}
	_pending = scope.duplicate(true)
	_holder = weakref(holder)
	return {"ok":true, "owned_retry":false}

static func allows(holder: Variant, scope: Variant) -> bool:
	return _actual_holder(holder) and _scope(scope) and _holder != null \
		and _holder.get_ref() == holder and _pending == scope

static func leave(holder: Variant, scope: Variant) -> Dictionary:
	if not allows(holder, scope): return _bad("CAMPAIGN_PROGRESS_GATE_CHANGED")
	_pending.clear(); _holder = null
	return {"ok":true}

static func startup_complete(holder: Variant) -> Dictionary:
	if not _actual_holder(holder) or not _pending.is_empty(): return _bad("CAMPAIGN_STARTUP_PENDING")
	_startup_checked = true
	return {"ok":true}
