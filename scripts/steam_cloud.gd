extends Node
## Account-scoped, read-before-write Steam Remote Storage synchronization.
## fileWrite acknowledges the Steam client's local cache, not a server upload.

signal changed

const CLOUD_FILE := "liangshan_profile_v1.json"
const MIRROR_PATH := "user://steam_cloud_profile.json" # Legacy: retained, never overwritten/deleted.
const OWNER_PATH := "user://steam_cloud_owner.cfg"
const SCHEMA := 1
const MAX_PROFILE_BYTES := 1048576

var status := "云存档未连接"
var cloud_ready := false
var dirty := false
var last_sync_at := 0
var _owner := ""
var _busy := false
var _applying := false
var _pulled := false
var _retry_after := 0.0
var _tick := 0.0
var _pending_upload := false
var _revision := 0
var _baseline: Dictionary = {}
var _settings_dirty := false
var _language_dirty := false
var _initial_settings := ""
var _initial_language := ""
var _transition_failed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initial_settings = Settings.cloud_text()
	_initial_language = Localize.cloud_text()
	SteamService.initialized.connect(_attach)
	if SteamService.available:
		_attach()


func _attach() -> void:
	# Tests call the internal seam explicitly with a fake. Ordinary/editor/QA
	# startup must never claim ownership or touch cloud/profile files.
	if not OS.has_feature("steam") or SteamRunPolicy.test_environment():
		return
	_attach_account()


func _process(delta: float) -> void:
	if not cloud_ready:
		return
	_tick += delta
	_retry_after = maxf(0.0, _retry_after - delta)
	if _tick < 5.0 or _busy or _retry_after > 0.0:
		return
	_tick = 0.0
	if not _account_matches():
		_pulled = false
		return
	if not _pulled:
		_pull_or_seed()
	elif dirty or _pending_upload:
		_flush()


func _attach_account() -> void:
	if _busy or _transition_failed or not SteamService.available or not SteamService.ensure_account():
		return
	var target: String = SteamService.account
	if not _valid_owner(target):
		return
	if cloud_ready and _owner == target:
		# Never reload a stale mirror over edits made while disconnected.
		_pulled = false
		_retry_after = 0.0
		_pull_or_seed()
		return
	_busy = true
	var binding := _read_binding()
	var legacy := _read_profile_file(MIRROR_PATH)
	if not binding.ok or not legacy.ok:
		_stop_local()
		return
	var local_owner: String = binding.owner
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null:
		_stop_local()
		return
	var campaign_owner: String = campaign.cloud_owner
	var raw_legacy_owner: Variant = legacy.payload.get("owner", "")
	if not raw_legacy_owner is String:
		_stop_local()
		return
	var legacy_owner: String = raw_legacy_owner
	if local_owner == "":
		local_owner = campaign_owner if campaign_owner != "" else legacy_owner
		if local_owner == "":
			var migration := _legacy_import_owner()
			if not migration.ok:
				_stop_local()
				return
			local_owner = migration.owner
		# Missing binding is not permission to claim an already-used profile
		# directory. An orphaned scoped mirror is ownership evidence to inspect.
		if local_owner == "" and _has_scoped_mirror():
			_stop_local()
			return
	if (local_owner != "" and not _valid_owner(local_owner)) or (campaign_owner != "" and campaign_owner != local_owner):
		# A torn/ambiguous ownership transition needs recovery, never relabeling.
		_stop_local()
		return
	var stored := _load_mirror(target)
	if not stored.ok:
		_stop_local()
		return
	# Before switching, retain the complete current profile under its old owner.
	if local_owner != "" and local_owner != target:
		var previous := _load_mirror(local_owner)
		if not previous.ok:
			_stop_local()
			return
		var saved := _build_payload(local_owner)
		if not previous.payload.is_empty():
			saved.campaign = _merged_campaign(previous.payload.campaign, saved.campaign)
		if legacy_owner == local_owner:
			if not _validate_payload(legacy.payload, local_owner):
				_stop_local()
				return
			saved.campaign = _merged_campaign(legacy.payload.campaign, saved.campaign)
		if not _store_mirror(saved, true, true, true):
			_stop_local()
			return
	var local: Dictionary = stored.payload
	var same_local := local_owner == "" or local_owner == target
	if not legacy.payload.is_empty() and (legacy_owner == target or (legacy_owner == "" and local_owner == "")):
		var adopted: Dictionary = legacy.payload.duplicate(true)
		adopted.owner = target # One-time adoption of unowned LOCAL legacy data only.
		if not _validate_payload(adopted, target):
			_stop_local()
			return
		if local.is_empty():
			local = adopted
		else:
			local.campaign = _merged_campaign(adopted.campaign, local.campaign)
	# Disarm the old session before assigning a different owner. Any failed
	# transition remains inert, so later dirty callbacks cannot relabel A as B.
	cloud_ready = false
	_pulled = false
	_owner = target
	_baseline = local.duplicate(true)
	_settings_dirty = bool(local.get("_settings_dirty", false))
	_language_dirty = bool(local.get("_language_dirty", false))
	if same_local:
		var current := _build_payload()
		if not local.is_empty():
			current.campaign = _merged_campaign(local.campaign, current.campaign)
			if not FileAccess.file_exists("user://settings.cfg") and current.settings_text == _initial_settings:
				current.settings_text = local.settings_text
			if not FileAccess.file_exists("user://language.cfg") and current.language_text == _initial_language:
				current.language_text = local.language_text
			_settings_dirty = _settings_dirty or current.settings_text != local.settings_text
			_language_dirty = _language_dirty or current.language_text != local.language_text
		else:
			_settings_dirty = current.settings_text != _initial_settings or FileAccess.file_exists("user://settings.cfg")
			_language_dirty = current.language_text != _initial_language or FileAccess.file_exists("user://language.cfg")
		local = current
	elif local.is_empty():
		local = _default_payload(target)
	# Persist the recoverable scoped copy BEFORE changing shared files/binding.
	if not _validate_payload(local, target) or not _store_mirror(local, true, _settings_dirty, _language_dirty):
		_stop_local()
		return
	# A durable transition marker makes crashes/partial shared-file writes fail
	# closed on the next boot. Both scoped profiles remain available to recover.
	_transition_failed = true
	if not _write_binding(local_owner if local_owner != "" else target, target) or not _apply_profile(local) or not _write_binding(target):
		_stop_local()
		return
	_transition_failed = false
	_baseline = _build_payload()
	cloud_ready = true
	dirty = true
	_pending_upload = true
	_pulled = false
	_retry_after = 0.0
	_busy = false
	_pull_or_seed()


func mark_dirty() -> void:
	if _applying:
		return
	_revision += 1
	dirty = true
	_pending_upload = true
	# Before attach keep the change in runtime/normal local files. After attach
	# keep it in the bound account's mirror even with Steam unavailable.
	if cloud_ready and not _busy:
		_remember_local()


func profile_bytes() -> PackedByteArray:
	return JSON.stringify(_build_payload(), "\t").to_utf8_buffer()


func _build_payload(owner: String = "") -> Dictionary:
	return {"schema": SCHEMA, "owner": _owner if owner == "" else owner, "updated_at": int(Time.get_unix_time_from_system()),
		"campaign": _local_campaign(), "settings_text": Settings.cloud_text(), "language_text": Localize.cloud_text()}


func _default_payload(owner: String) -> Dictionary:
	return {"schema": SCHEMA, "owner": owner, "updated_at": 0,
		"campaign": {"schema": 2, "unlocked": 1, "records": {}},
		"settings_text": Settings.default_cloud_text(), "language_text": Localize.default_cloud_text()}


func _capture_local() -> Dictionary:
	var payload := _build_payload()
	if not _baseline.is_empty():
		payload.campaign = _merged_campaign(_baseline.campaign, payload.campaign)
		_settings_dirty = _settings_dirty or payload.settings_text != _baseline.settings_text
		_language_dirty = _language_dirty or payload.language_text != _baseline.language_text
	return payload


func _remember_local() -> bool:
	var campaign := get_node_or_null("/root/Campaign")
	if not cloud_ready or _transition_failed or campaign == null or campaign.cloud_owner != _owner:
		return false
	return _store_mirror(_capture_local(), true, _settings_dirty, _language_dirty)


func _pull_or_seed() -> void:
	if _busy or not cloud_ready or not _account_matches():
		return
	_busy = true
	_pulled = false
	var cloud := _cloud_read(SteamService.native)
	if not cloud.ok or not _account_matches():
		_remember_local()
		_fail("云存档暂不可用，稍后重试")
		return
	var remote: Dictionary = cloud.payload
	if not remote.is_empty() and not _validate_payload(remote, _owner):
		_remember_local()
		_fail("云存档暂不可用，稍后重试")
		return
	var payload := _capture_local()
	if not remote.is_empty():
		payload.campaign = _merged_campaign(payload.campaign, remote.campaign)
		if not _settings_dirty:
			payload.settings_text = remote.settings_text
		if not _language_dirty:
			payload.language_text = remote.language_text
	if not _validate_payload(payload, _owner) or not _store_mirror(payload, true, _settings_dirty, _language_dirty):
		_fail("云存档上传失败，将重试")
		return
	if not _apply_profile(payload):
		_fail("云存档上传失败，将重试")
		return
	_pulled = true
	# Serialize normalized, migrated runtime settings, not the untrusted input.
	payload = _build_payload()
	# Downloaded settings are the new comparison baseline even if the upload
	# fails; otherwise the next pull would mistake our own apply for local edits.
	_baseline = payload.duplicate(true)
	_send_payload(payload)


func _flush() -> void:
	if _busy or not cloud_ready or _retry_after > 0.0:
		return
	if not _pulled:
		_pull_or_seed()
		return
	if not _account_matches():
		_pulled = false
		_remember_local()
		return
	_busy = true
	_send_payload(_capture_local())


func _send_payload(payload: Dictionary) -> void:
	dirty = true
	_pending_upload = true
	if not _validate_payload(payload, _owner) or not _store_mirror(payload, true, _settings_dirty, _language_dirty):
		_fail("云存档上传失败，将重试")
		return
	var revision := _revision
	if not _account_matches() or not _cloud_write(SteamService.native, payload) or not _account_matches():
		_pulled = false
		_fail("云存档上传失败，将重试")
		return
	_baseline = payload.duplicate(true)
	last_sync_at = int(payload.updated_at)
	_settings_dirty = false
	_language_dirty = false
	if revision != _revision:
		# A signal/callback changed runtime during the synchronous native call.
		_remember_local()
		_fail("云存档上传失败，将重试")
		return
	if not _store_mirror(payload, false, false, false):
		_fail("云存档上传失败，将重试")
		return
	dirty = false
	_pending_upload = false
	_retry_after = 0.0
	_finish("云存档已提交 Steam")


func _fail(message: String) -> void:
	dirty = true
	_pending_upload = true
	_pulled = false
	_retry_after = 30.0
	_finish(message)


func _stop_local() -> void:
	cloud_ready = false
	_pulled = false
	_transition_failed = true
	_fail("本机云存档需要检查，已停止同步")


func _finish(message: String) -> void:
	status = Localize.text(message)
	changed.emit() # Keep the reentrancy guard until listeners return.
	_busy = false


func apply_payload(payload: Dictionary, from_cloud: bool) -> Dictionary:
	# Applying never acknowledges a pending upload; only fileWrite can do that.
	if not _validate_payload(payload, _owner):
		return {"ok": false, "code": "PROFILE_INVALID"}
	if from_cloud and not _apply_profile(payload):
		return {"ok": false, "code": "LOCAL_WRITE_FAILED"}
	if not _store_mirror(payload, true, _settings_dirty, _language_dirty):
		return {"ok": false, "code": "LOCAL_WRITE_FAILED"}
	return {"ok": true}


func _apply_profile(payload: Dictionary) -> bool:
	if not _validate_payload(payload, _owner):
		return false
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null:
		return false
	_applying = true
	var ok := Settings.apply_cloud_text(payload.settings_text) and Localize.apply_cloud_text(payload.language_text)
	if ok:
		ok = _write_text("user://settings.cfg", Settings.cloud_text()) and _write_text("user://language.cfg", Localize.cloud_text())
	if ok:
		ok = campaign.apply_cloud_progress(payload.campaign, _owner)
	_applying = false
	return ok


func _validate_payload(payload: Dictionary, owner: String) -> bool:
	var raw_owner: Variant = payload.get("owner")
	if not _valid_owner(owner) or not raw_owner is String or raw_owner != owner or not _whole(payload.get("schema"), SCHEMA, SCHEMA):
		return false
	if not _whole(payload.get("updated_at", 0), 0, 9007199254740991):
		return false
	for key in ["_local_dirty", "_settings_dirty", "_language_dirty"]:
		if payload.has(key) and typeof(payload[key]) != TYPE_BOOL:
			return false
	var progress: Variant = payload.get("campaign")
	if not progress is Dictionary or not _whole(progress.get("schema"), 2, 2) or not _whole(progress.get("unlocked"), 1, 9):
		return false
	var records: Variant = progress.get("records")
	if not records is Dictionary or records.size() > 8:
		return false
	for level_id in records:
		if not level_id is String or level_id not in ["level1", "level2", "level3", "level4", "level5", "level6", "level7", "level8"]:
			return false
		var record: Variant = records[level_id]
		if not record is Dictionary:
			return false
		for key in ["cleared", "story_complete"]:
			if typeof(record.get(key, false)) != TYPE_BOOL:
				return false
		for key in ["best_done", "story_total", "contract_version"]:
			if not _whole(record.get(key, 1 if key == "contract_version" else 0), 0, 100000):
				return false
		if record.has("best_total") and not _whole(record.best_total, 0, 100000):
			return false
		var ids: Variant = record.get("best_goal_ids", [])
		if not ids is Array or ids.size() > 256:
			return false
		for id in ids:
			if not id is String or id.length() > 256:
				return false
	var settings: Variant = payload.get("settings_text")
	var language: Variant = payload.get("language_text")
	return settings is String and language is String and Settings.validate_cloud_text(settings) and Localize.validate_cloud_text(language)


func _whole(value: Variant, low: int, high: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high


func _valid_owner(owner: String) -> bool:
	return owner.length() <= 20 and owner.is_valid_int() and not owner.begins_with("+") and not owner.begins_with("-") and owner.to_int() > 0


func _account_matches() -> bool:
	var campaign := get_node_or_null("/root/Campaign")
	return campaign != null and campaign.cloud_owner == _owner and SteamService.available and SteamService.account == _owner and SteamService.ensure_account()


func _local_campaign() -> Dictionary:
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null:
		return {}
	return {"schema": campaign.SAVE_SCHEMA, "unlocked": int(campaign.unlocked), "records": campaign.records.duplicate(true)}


func _merged_campaign(a: Dictionary, b: Dictionary) -> Dictionary:
	var records := {}
	for source in [a.get("records", {}), b.get("records", {})]:
		if not source is Dictionary:
			continue
		for level_id in source:
			var incoming := _normalize_record(source[level_id])
			records[level_id] = _better_record(records[level_id], incoming) if records.has(level_id) else incoming
	return {"schema": 2, "unlocked": maxi(int(a.get("unlocked", 1)), int(b.get("unlocked", 1))), "records": records}


func _better_record(left: Dictionary, right: Dictionary) -> Dictionary:
	var out := left.duplicate(true)
	out.cleared = bool(left.cleared) or bool(right.cleared)
	out.story_complete = bool(left.story_complete) or bool(right.story_complete)
	out.contract_version = maxi(int(left.contract_version), int(right.contract_version))
	# Keep an exact goal set from ONE run; never manufacture a union of runs.
	if int(right.best_done) > int(left.best_done) or (int(left.story_total) == 0 and int(right.story_total) > 0) or (bool(right.story_complete) and not bool(left.story_complete)):
		out.best_done = right.best_done
		out.story_total = right.story_total
		out.best_goal_ids = right.best_goal_ids.duplicate()
	return out


func _normalize_record(raw_value: Variant) -> Dictionary:
	var out := {"cleared": false, "story_complete": false, "best_done": 0, "story_total": 0, "best_goal_ids": [], "contract_version": 1}
	if not raw_value is Dictionary:
		return out
	var raw: Dictionary = raw_value
	out.cleared = bool(raw.get("cleared", false))
	out.story_complete = bool(raw.get("story_complete", false))
	out.best_done = maxi(0, int(raw.get("best_done", 0)))
	out.story_total = maxi(int(out.best_done), int(raw.get("story_total", raw.get("best_total", 0))))
	var ids: Variant = raw.get("best_goal_ids", [])
	if ids is Array:
		for item in ids:
			if item is String and item.strip_edges() != "" and not out.best_goal_ids.has(item.strip_edges()):
				out.best_goal_ids.append(item.strip_edges())
	out.contract_version = maxi(1, int(raw.get("contract_version", 1)))
	return out


func _mirror_path(owner: String) -> String:
	return "user://steam_cloud_profile_%s.json" % owner


func _read_profile_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "payload": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_PROFILE_BYTES:
		return {"ok": false, "payload": {}}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary or parser.data.is_empty():
		return {"ok": false, "payload": {}}
	return {"ok": true, "payload": parser.data}


func _load_mirror(owner: String) -> Dictionary:
	var result := _read_profile_file(_mirror_path(owner))
	if result.ok and not result.payload.is_empty() and not _validate_payload(result.payload, owner):
		result.ok = false
	return result


func _read_mirror() -> Dictionary:
	var result := _load_mirror(_owner)
	return result.payload if result.ok else {}


func _store_mirror(payload: Dictionary, pending: bool, settings_changed: bool, language_changed: bool) -> bool:
	var raw_owner: Variant = payload.get("owner")
	if not raw_owner is String:
		return false
	var owner: String = raw_owner
	if not _validate_payload(payload, owner):
		return false
	var saved := payload.duplicate(true)
	saved["_local_dirty"] = pending
	saved["_settings_dirty"] = settings_changed
	saved["_language_dirty"] = language_changed
	var text_value := JSON.stringify(saved, "\t")
	return text_value.to_utf8_buffer().size() <= MAX_PROFILE_BYTES and _write_text(_mirror_path(owner), text_value)


func _read_binding() -> Dictionary:
	if not FileAccess.file_exists(OWNER_PATH):
		return {"ok": true, "owner": ""}
	var cfg := ConfigFile.new()
	if cfg.load(OWNER_PATH) != OK:
		return {"ok": false, "owner": ""}
	var pending: Variant = cfg.get_value("profile", "pending_owner", "")
	if not pending is String or pending != "":
		return {"ok": false, "owner": ""}
	var owner: Variant = cfg.get_value("profile", "owner", null)
	return {"ok": owner is String and _valid_owner(owner), "owner": owner if owner is String else ""}


func _legacy_import_owner() -> Dictionary:
	var path := "user://steam_legacy_import.cfg"
	if not FileAccess.file_exists(path):
		return {"ok": true, "owner": ""}
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {"ok": false, "owner": ""}
	var owner: Variant = cfg.get_value("migration", "owner", null)
	return {"ok": owner is String and _valid_owner(owner), "owner": owner if owner is String else ""}


func _has_scoped_mirror() -> bool:
	var directory := DirAccess.open("user://")
	if directory == null:
		return true
	for name in directory.get_files():
		if name.begins_with("steam_cloud_profile_") and name.ends_with(".json"):
			return true
	return false


func _write_binding(owner: String, pending_owner := "") -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "owner", owner)
	if pending_owner != "":
		cfg.set_value("profile", "pending_owner", pending_owner)
	return _write_text(OWNER_PATH, cfg.encode_to_text())


func _write_text(path: String, value: String) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(temporary, path) == OK


func _cloud_enabled(native: Object) -> bool:
	if native == null:
		return false
	for method in ["isCloudEnabledForAccount", "isCloudEnabledForApp", "fileExists", "getFileSize", "fileRead", "fileWrite"]:
		if not native.has_method(method):
			return false
	return native.call("isCloudEnabledForAccount") == true and native.call("isCloudEnabledForApp") == true


func _cloud_read(native: Object) -> Dictionary:
	if not _cloud_enabled(native):
		return {"ok": false, "code": "CLOUD_DISABLED"}
	var exists: Variant = native.call("fileExists", CLOUD_FILE)
	if typeof(exists) != TYPE_BOOL:
		return {"ok": false, "code": "FILE_READ_FAILED"}
	if not exists:
		return {"ok": true, "payload": {}}
	var size: Variant = native.call("getFileSize", CLOUD_FILE)
	if typeof(size) != TYPE_INT or size <= 0 or size > MAX_PROFILE_BYTES:
		return {"ok": false, "code": "FILE_SIZE_INVALID"}
	# GodotSteam 4.22.1: ret is the byte count; buf has allocated length even
	# after a short read. Check BOTH, never reinterpret ret as a success bool.
	var result: Variant = native.call("fileRead", CLOUD_FILE, size)
	if not result is Dictionary or typeof(result.get("ret")) != TYPE_INT or result.ret != size:
		return {"ok": false, "code": "FILE_READ_FAILED"}
	var bytes: Variant = result.get("buf")
	if not bytes is PackedByteArray or bytes.size() != size:
		return {"ok": false, "code": "FILE_READ_FAILED"}
	var text_value: String = bytes.get_string_from_utf8()
	var parser := JSON.new()
	if text_value.to_utf8_buffer() != bytes or parser.parse(text_value) != OK or not parser.data is Dictionary or parser.data.is_empty():
		return {"ok": false, "code": "CLOUD_PAYLOAD_INVALID"}
	return {"ok": true, "payload": parser.data}


func _cloud_write(native: Object, payload: Dictionary) -> bool:
	if not _cloud_enabled(native) or not _validate_payload(payload, _owner):
		return false
	var clean := payload.duplicate(true)
	for key in ["_local_dirty", "_settings_dirty", "_language_dirty"]:
		clean.erase(key)
	var bytes := JSON.stringify(clean, "\t").to_utf8_buffer()
	if bytes.size() > MAX_PROFILE_BYTES:
		return false
	# fileWriteAsync is void and needs a completion callback; do not fall back.
	var result: Variant = native.call("fileWrite", CLOUD_FILE, bytes)
	return typeof(result) == TYPE_BOOL and result


func _exit_tree() -> void:
	if not cloud_ready or _busy:
		return
	if dirty or _pending_upload:
		_remember_local()
		if _account_matches():
			_flush()
