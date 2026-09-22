extends Node
## Steam Cloud 战役进度与个人设置同步。只同步已稳定进度，不含战斗中途续玩档。

signal changed

const CLOUD_FILE := "liangshan_profile_v1.json"
const MIRROR_PATH := "user://steam_cloud_profile.json"
const SCHEMA := 1

var status := "云存档未连接"
var ready := false
var dirty := false
var last_sync_at := 0
var _owner := ""
var _busy := false
var _retry_after := 0.0
var _tick := 0.0
var _pending_upload := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SteamService.initialized.connect(_attach)
	if SteamService.available:
		_attach()

func _process(delta: float) -> void:
	if not ready:
		return
	_tick += delta
	_retry_after = maxf(0.0, _retry_after - delta)
	if _tick < 5.0:
		return
	_tick = 0.0
	if not SteamService.ensure_account():
		return
	if _pending_upload and not _busy and _retry_after <= 0.0:
		_flush()
	elif dirty and not _busy and _retry_after <= 0.0:
		_flush()

func _attach() -> void:
	if SteamRunPolicy.test_environment() or not SteamService.available or not SteamService.ensure_account():
		return
	_owner = SteamService.account
	ready = true
	status = Localize.text("正在检查云存档")
	changed.emit()
	_pull_or_seed()

func mark_dirty() -> void:
	if not ready or not SteamService.ensure_account() or SteamService.account != _owner:
		return
	dirty = true
	_pending_upload = true

func profile_bytes() -> PackedByteArray:
	return JSON.stringify(_build_payload(), "\t").to_utf8_buffer()

func apply_payload(payload: Dictionary, from_cloud: bool) -> Dictionary:
	if int(payload.get("schema", 0)) != SCHEMA:
		return {"ok": false, "code": "SCHEMA_MISMATCH"}
	var owner := String(payload.get("owner", ""))
	if owner != "" and owner != _owner:
		return {"ok": false, "code": "OWNER_MISMATCH"}
	var campaign: Dictionary = payload.get("campaign", {})
	var settings_text := String(payload.get("settings_text", ""))
	var language_text := String(payload.get("language_text", ""))
	if from_cloud:
		_apply_campaign(campaign)
		_apply_text_file("user://settings.cfg", settings_text)
		_apply_text_file("user://language.cfg", language_text)
	_write_mirror(payload)
	last_sync_at = int(payload.get("updated_at", 0))
	dirty = false
	_pending_upload = false
	status = Localize.text("云存档已同步")
	changed.emit()
	return {"ok": true}

func _build_payload() -> Dictionary:
	var campaign := get_node_or_null("/root/Campaign")
	var progress := {}
	if campaign != null:
		progress = {
			"schema": campaign.SAVE_SCHEMA,
			"unlocked": int(campaign.unlocked),
			"records": campaign.records.duplicate(true),
		}
	return {
		"schema": SCHEMA,
		"owner": _owner,
		"updated_at": int(Time.get_unix_time_from_system()),
		"campaign": progress,
		"settings_text": _read_text("user://settings.cfg"),
		"language_text": _read_text("user://language.cfg"),
	}

func _pull_or_seed() -> void:
	if _busy:
		return
	_busy = true
	var native: Object = SteamService.native
	if native == null:
		_busy = false
		return
	var cloud: Dictionary = _cloud_read(native)
	if not cloud.get("ok", false):
		_busy = false
		_retry_after = 30.0
		status = Localize.text("云存档暂不可用，稍后重试")
		changed.emit()
		return
	var remote: Variant = cloud.get("payload", {})
	if not remote is Dictionary:
		remote = {}
	var local := _read_mirror()
	if remote.is_empty() and local.is_empty():
		var first_payload := _build_payload()
		_write_mirror(first_payload)
		if _cloud_write(native, first_payload):
			last_sync_at = int(first_payload.get("updated_at", 0))
			status = Localize.text("已上传本机战役进度到云存档")
		else:
			dirty = true
			_pending_upload = true
			status = Localize.text("云存档上传失败，将重试")
		changed.emit()
		_busy = false
		return
	if remote.is_empty() and not local.is_empty():
		var restored: Dictionary = local.duplicate(true)
		restored["owner"] = _owner
		restored["updated_at"] = int(Time.get_unix_time_from_system())
		restored["campaign"] = _merged_campaign(local.get("campaign", {}), _local_campaign())
		apply_payload(restored, true)
		if not _cloud_write(native, restored):
			dirty = true
			_pending_upload = true
			status = Localize.text("旧进度恢复上传失败，将重试")
			changed.emit()
		else:
			status = Localize.text("已将本机旧进度恢复到云存档")
			changed.emit()
		_busy = false
		return
	if not remote.is_empty() and local.is_empty():
		apply_payload(remote, true)
		_busy = false
		return
	var merged: Dictionary = remote.duplicate(true)
	merged["campaign"] = _merged_campaign(local.get("campaign", {}), remote.get("campaign", {}))
	if int(local.get("updated_at", 0)) > int(remote.get("updated_at", 0)):
		merged["settings_text"] = String(local.get("settings_text", remote.get("settings_text", "")))
		merged["language_text"] = String(local.get("language_text", remote.get("language_text", "")))
	else:
		merged["settings_text"] = String(remote.get("settings_text", local.get("settings_text", "")))
		merged["language_text"] = String(remote.get("language_text", local.get("language_text", "")))
	merged["owner"] = _owner
	merged["updated_at"] = int(Time.get_unix_time_from_system())
	apply_payload(merged, true)
	if _cloud_write(native, merged):
		status = Localize.text("云存档已合并同步")
	else:
		dirty = true
		_pending_upload = true
		status = Localize.text("云存档合并上传失败，将重试")
	changed.emit()
	_busy = false

func _flush() -> void:
	if not SteamService.ensure_account() or SteamService.account != _owner:
		return
	var native: Object = SteamService.native
	if native == null:
		return
	_busy = true
	var payload := _build_payload()
	payload["campaign"] = _merged_campaign(_read_mirror().get("campaign", {}), payload.get("campaign", {}))
	_write_mirror(payload)
	if _cloud_write(native, payload):
		last_sync_at = int(payload.get("updated_at", 0))
		dirty = false
		_pending_upload = false
		status = Localize.text("云存档已同步")
	else:
		_retry_after = 30.0
		status = Localize.text("云存档上传失败，将重试")
	changed.emit()
	_busy = false

func _merged_campaign(a: Dictionary, b: Dictionary) -> Dictionary:
	var unlocked := maxi(int(a.get("unlocked", 1)), int(b.get("unlocked", 1)))
	var records := {}
	for source in [a.get("records", {}), b.get("records", {})]:
		if not source is Dictionary:
			continue
		for level_id in source:
			var incoming := _normalize_record(source[level_id])
			if records.has(level_id):
				records[level_id] = _better_record(records[level_id], incoming)
			else:
				records[level_id] = incoming
	return {"schema": 2, "unlocked": unlocked, "records": records}

func _better_record(left: Dictionary, right: Dictionary) -> Dictionary:
	var out := left.duplicate(true)
	out["cleared"] = bool(left.get("cleared", false)) or bool(right.get("cleared", false))
	out["story_complete"] = bool(left.get("story_complete", false)) or bool(right.get("story_complete", false))
	out["contract_version"] = maxi(int(left.get("contract_version", 1)), int(right.get("contract_version", 1)))
	var left_done := int(left.get("best_done", 0))
	var right_done := int(right.get("best_done", 0))
	# Keep one best single-run goal set. Never union goals across runs.
	if right_done > left_done or (int(left.get("story_total", 0)) == 0 and int(right.get("story_total", 0)) > 0) \
			or (bool(right.get("story_complete", false)) and not bool(left.get("story_complete", false)) and right_done >= left_done):
		out["best_done"] = right_done
		out["story_total"] = int(right.get("story_total", 0))
		var ids: Array = []
		for item in right.get("best_goal_ids", []):
			var goal_id := String(item).strip_edges()
			if goal_id != "" and not ids.has(goal_id):
				ids.append(goal_id)
		out["best_goal_ids"] = ids
	return out

func _normalize_record(raw_value: Variant) -> Dictionary:
	var out := {"cleared": false, "story_complete": false, "best_done": 0, "story_total": 0,
		"best_goal_ids": [], "contract_version": 1}
	if not raw_value is Dictionary:
		return out
	var raw: Dictionary = raw_value
	out["cleared"] = bool(raw.get("cleared", false))
	out["story_complete"] = bool(raw.get("story_complete", false))
	out["best_done"] = maxi(0, int(raw.get("best_done", 0)))
	out["story_total"] = maxi(int(out["best_done"]), int(raw.get("story_total", 0)))
	var ids: Array = []
	for item in raw.get("best_goal_ids", []):
		var goal_id := String(item).strip_edges()
		if goal_id != "" and not ids.has(goal_id):
			ids.append(goal_id)
	out["best_goal_ids"] = ids
	out["contract_version"] = maxi(1, int(raw.get("contract_version", 1)))
	return out

func _local_campaign() -> Dictionary:
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null:
		return {}
	return {"schema": campaign.SAVE_SCHEMA, "unlocked": int(campaign.unlocked), "records": campaign.records.duplicate(true)}

func _apply_campaign(campaign: Dictionary) -> void:
	var node := get_node_or_null("/root/Campaign")
	if node == null or not campaign is Dictionary:
		return
	var merged := _merged_campaign(_local_campaign(), campaign)
	node.unlocked = maxi(1, int(merged.get("unlocked", 1)))
	node.records = merged.get("records", {})
	node._save()

func _apply_text_file(path: String, text_value: String) -> void:
	if text_value.strip_edges() == "":
		return
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(text_value)
	out.close()

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

func _write_mirror(payload: Dictionary) -> void:
	var out := FileAccess.open(MIRROR_PATH, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(JSON.stringify(payload, "\t"))
	out.close()

func _read_mirror() -> Dictionary:
	if not FileAccess.file_exists(MIRROR_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MIRROR_PATH))
	return parsed if parsed is Dictionary else {}

func _exit_tree() -> void:
	if ready and dirty and not _busy and SteamService.ensure_account() and SteamService.account == _owner:
		_flush()

func _cloud_read(native: Object) -> Dictionary:
	if not bool(native.call("fileExists", CLOUD_FILE)):
		return {"ok": true, "payload": {}}
	var result: Variant = native.call("fileRead", CLOUD_FILE, 0)
	if not result is Dictionary or not bool(result.get("ret", false)):
		return {"ok": false, "code": "FILE_READ_FAILED"}
	var content: Variant = result.get("content", result.get("buffer", PackedByteArray()))
	var bytes: PackedByteArray
	if content is PackedByteArray:
		bytes = content
	elif content is String:
		bytes = String(content).to_utf8_buffer()
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "code": "CLOUD_PAYLOAD_INVALID"}
	return {"ok": true, "payload": parsed}

func _cloud_write(native: Object, payload: Dictionary) -> bool:
	var bytes := JSON.stringify(payload, "\t").to_utf8_buffer()
	if bool(native.call("fileWrite", CLOUD_FILE, bytes)):
		return true
	return bool(native.call("fileWriteAsync", CLOUD_FILE, bytes))
