extends Node
## One upload at a time; keep the created id before starting an update.
signal changed
var items: Array[Dictionary] = []
var status := "请从 Steam 版游戏打开创意工坊"
var busy := false
var _pending := {}
var _handle := 0
var _elapsed := 0.0
var _progress_tick := 0.0
var _connected := false
var _requested := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SteamService.initialized.connect(_connect_native)
	if SteamService.available: _connect_native()

func _connect_native() -> void:
	if _connected: return
	var api: Object = SteamService.native
	api.connect("item_created", _created)
	api.connect("item_updated", _updated)
	api.connect("item_installed", _installed)
	api.connect("item_downloaded", _downloaded)
	_connected = true
	status = "Steam 工坊已连接"
	refresh()

func _process(delta: float) -> void:
	if not busy: return
	_elapsed += delta
	_progress_tick += delta
	if _progress_tick < 1: return
	_progress_tick = 0
	if not SteamService.available or SteamService.account != _pending.get("owner", ""):
		status = "账号已变化，上传结果待确认，请重启后查看作品页"
	elif _handle != 0:
		var p: Dictionary = SteamService.native.call("getItemUpdateProgress", _handle)
		status = "正在上传：%d / %d KB" % [int(p.get("processed", 0)) / 1024, int(p.get("total", 0)) / 1024]
	elif _elapsed > 60:
		status = "Steam 创建作品尚未返回，请等待；不会重复创建"
	changed.emit()

func refresh() -> void:
	items.clear()
	if not SteamService.ensure_account():
		status = "Steam 未连接，无法读取订阅"
		changed.emit()
		return
	for id in SteamService.native.call("getSubscribedItems"):
		var flags := int(SteamService.native.call("getItemState", id))
		var row := {"id":str(id), "title":"作品 " + str(id), "ok":false, "error":"等待下载"}
		if flags & 4 and not (flags & (8 | 16 | 32)):
			var info: Dictionary = SteamService.native.call("getItemInstallInfo", id)
			if bool(info.get("ret", false)):
				row.merge(WorkshopContent.read_package(String(info.folder)), true)
		elif not _requested.has(id):
			if bool(SteamService.native.call("downloadItem", id, false)):
				_requested[id] = true
			else:
				row.error = "下载未启动，请联网后刷新"
		else:
			row.error = "正在下载或更新"
		items.append(row)
	changed.emit()

func play(id: String) -> void:
	# Re-read after checking subscription/update state. The running battle only sees a copy.
	refresh()
	for item in items:
		if item.id != id or not bool(item.get("ok", false)): continue
		Campaign.scenario = item.kind == "scenario"
		Campaign.custom_defense = item.kind == "custom_defense"
		Campaign.scenario_data = WorkshopContent.runtime_payload(item.data) if Campaign.scenario else {}
		Campaign.custom_config = WorkshopContent.runtime_payload(item.data) if Campaign.custom_defense else {}
		Campaign.skirmish = false
		Campaign.skirmish_ai = false
		Campaign.arena = false
		Campaign.ai_friendly = false
		Campaign.defense_random = false
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return

func unsubscribe(id: String) -> void:
	if SteamService.ensure_account() and id.is_valid_int():
		SteamService.native.call("unsubscribeItem", int(id))
		status = "已请求取消订阅，请稍后刷新"
		changed.emit()

func publish(kind: String, source: Dictionary, description: String, visibility: int, preview: Image) -> void:
	if busy: return
	if not SteamService.ensure_account():
		status = "请先连接 Steam"
		changed.emit()
		return
	var payload: Dictionary = WorkshopContent.encode_payload(source)
	payload.erase("_workshop_source_id")
	var check := WorkshopContent.new()
	if not check.validate(kind, payload):
		status = check.error
		changed.emit()
		return
	if description.to_utf8_buffer().size() > 7000 or visibility not in [0, 1, 2] or preview == null or preview.is_empty():
		status = "说明过长、可见性无效或缺少封面"
		changed.emit()
		return
	if not source.has("_workshop_source_id"):
		source._workshop_source_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var local_path := ScenarioStore.save(source) if kind == "scenario" else CustomConfig.save(source)
	if local_path.is_empty():
		status = "本地作品保存失败，未开始上传"
		changed.emit()
		return
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	var folder := "user://workshop_uploads/" + token
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		status = "无法创建上传目录"
		changed.emit()
		return
	var image := preview.duplicate() as Image
	image.resize(512, 288, Image.INTERPOLATE_LANCZOS)
	var jpg := image.save_jpg_to_buffer(0.8)
	if jpg.size() > WorkshopContent.MAX_PREVIEW_BYTES or not _write(folder.path_join("preview.jpg"), jpg) or not _write(folder.path_join("manifest.json"), JSON.stringify({"format_version":1, "kind":kind}).to_utf8_buffer()) or not _write(folder.path_join("content.json"), JSON.stringify(payload).to_utf8_buffer()):
		status = "作品包写入失败，未开始上传"
		changed.emit()
		return
	_pending = {"owner":SteamService.account, "source":String(source._workshop_source_id), "folder":ProjectSettings.globalize_path(folder), "title":String(payload.get("title", payload.get("name", ""))), "description":description, "visibility":visibility, "kind":kind, "id":0}
	var links := ConfigFile.new()
	links.load("user://workshop_publications.cfg")
	_pending.id = int(String(links.get_value(_pending.owner, _pending.source, "0")))
	busy = true
	_elapsed = 0
	_handle = 0
	status = "正在准备工坊作品"
	if int(_pending.id) == 0:
		SteamService.native.call("createItem", SteamAchievementCatalog.APP_ID, 0)
	else:
		_submit()
	changed.emit()

func _created(result: int, id: int, accept_tos: bool) -> void:
	if not _owns_pending() or int(_pending.id) != 0: return
	if result != 1:
		_finish("创建失败（Steam %d），可重试" % result)
		return
	_pending.id = id
	var links := ConfigFile.new()
	links.load("user://workshop_publications.cfg")
	links.set_value(_pending.owner, _pending.source, str(id))
	if links.save("user://workshop_publications.cfg") != OK:
		# Keep busy: a retry must not create a duplicate after an unrecorded CreateItem.
		status = "作品已创建，但本地关联保存失败；请记录作品 ID %d 后重启" % id
		changed.emit()
		return
	if accept_tos: open_item(str(id))
	_submit()

func _submit() -> void:
	var api: Object = SteamService.native
	_handle = int(api.call("startItemUpdate", SteamAchievementCatalog.APP_ID, int(_pending.id)))
	if _handle == 0 or _handle == -1:
		_finish("无法开始作品更新，可重试")
		return
	for call_spec in [["setItemTitle", _pending.title], ["setItemDescription", _pending.description], ["setItemVisibility", _pending.visibility], ["setItemContent", _pending.folder], ["setItemPreview", String(_pending.folder).path_join("preview.jpg")], ["setItemTags", PackedStringArray(["Map" if _pending.kind == "scenario" else "Defense"])]]:
		if not bool(api.call(call_spec[0], _handle, call_spec[1])):
			_finish("Steam 拒绝作品信息：" + String(call_spec[0]))
			return
	api.call("submitItemUpdate", _handle, "Updated from Liangshan Heroes editor")
	status = "正在上传；Steam 提交后无法取消"
	changed.emit()

func _updated(result: int, accept_tos: bool, id: int) -> void:
	if not _owns_pending() or int(_pending.id) != id: return
	_finish(("已上传，请在 Steam 接受工坊协议后查看可见性" if accept_tos else "作品已上传，已打开作品页面") if result == 1 else "上传失败（Steam %d）；重试会更新同一作品" % result)
	if result == 1: open_item(str(id))

func _owns_pending() -> bool:
	return busy and SteamService.ensure_account() and SteamService.account == _pending.get("owner", "")

func _finish(message: String) -> void:
	busy = false
	_handle = 0
	status = message
	changed.emit()

func _installed(app_id: int, _id: int) -> void:
	if app_id == SteamAchievementCatalog.APP_ID: refresh()

func _downloaded(result: int, id: int, app_id: int) -> void:
	if app_id != SteamAchievementCatalog.APP_ID: return
	_requested.erase(id)
	if result == 1: refresh()
	else:
		status = "下载失败（Steam %d），请联网后刷新" % result
		changed.emit()

func open_item(id: String) -> void:
	if id.is_valid_int(): SteamService.open_page("https://steamcommunity.com/sharedfiles/filedetails/?id=" + id)

func _write(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	return file.get_error() == OK
