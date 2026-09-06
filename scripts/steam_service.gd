extends Node
## Windows Steam adapter. No static Steam class reference in portable game code.

signal changed
signal initialized

var native: Object
var available := false
var stats_ready := false
var status := "普通启动：Steam 成就不计入"
var account := ""
var state := SteamAchievementState.new()
var _sent_stats := {}
var _sent_achievements := {}
var _dirty := false
var _revision := 0
var _store_revision := -1
var _store_busy := false
var _store_age := 0.0
var _tick := 0.0
var _retry_after := 0.0
var _run_counter := 0
var _active_run := 0
var _context := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("steam") or SteamRunPolicy.test_environment():
		return
	if not Engine.has_singleton("Steam"):
		status = "Steam 组件未加载，请检查 Steam 版安装文件"
		return
	native = Engine.get_singleton("Steam")
	var result: Dictionary = native.call("steamInitEx", SteamAchievementCatalog.APP_ID, false)
	if int(result.get("status", -1)) != 0:
		status = "Steam 未连接：请运行 Steam 客户端后重新启动游戏"
		native = null
		return
	if int(native.call("getAppID")) != SteamAchievementCatalog.APP_ID:
		status = "Steam 应用不匹配，功能已停用"
		native.call("steamShutdown")
		native = null
		return
	account = str(native.call("getSteamID"))
	available = account != "0"
	native.connect("user_stats_stored", _on_stored)
	status = "Steam 已连接，正在读取成就"
	initialized.emit()
	_read_initial_state()

func _process(delta: float) -> void:
	if not available:
		return
	native.call("run_callbacks")
	_tick += delta
	_retry_after = maxf(0, _retry_after - delta)
	if _store_busy:
		_store_age += delta
		if _store_age > 30:
			_store_busy = false
			_retry_after = 60
			status = "Steam 保存尚未确认，将重试"
			changed.emit()
	if _tick >= 10:
		_tick = 0
		if str(native.call("getSteamID")) != account:
			available = false
			stats_ready = false
			_active_run = 0
			status = "Steam 账号已变化，请重启游戏后继续计入成就"
			changed.emit()
			return
		if not stats_ready:
			_read_initial_state()
		elif _dirty and _retry_after <= 0:
			_sync_state()
			flush()

func _read_initial_state() -> void:
	var initial := {}
	for e in SteamAchievementCatalog.entries():
		var r: Dictionary = native.call("getAchievement", e.id)
		if not bool(r.get("ret", false)):
			status = "Steam 成就配置尚未就绪，当前不计入"
			changed.emit()
			return
		initial[e.id] = bool(r.get("achieved", false))
	var values := {}
	for name in SteamAchievementCatalog.STATS:
		var value := int(native.call("getStatInt", name))
		if value < 0 or not bool(native.call("setStatInt", name, value)):
			status = "Steam 统计配置尚未就绪，当前不计入"
			changed.emit()
			return
		values[name] = value
	state.seed(values, initial)
	_sent_stats = values.duplicate()
	_sent_achievements = initial.duplicate()
	stats_ready = true
	status = "Steam 成就已就绪（官方玩法计入；工坊与自定义不计入）"
	_import_legacy()
	state.evaluate()
	_sync_state()
	flush()
	changed.emit()

func begin_run(context: Dictionary) -> int:
	_active_run = 0
	_context = context.duplicate(true)
	state.settled.clear()
	if not ensure_account() or not stats_ready or context.get("mode", "custom") == "custom" or SteamRunPolicy.test_environment():
		return 0
	_run_counter += 1
	_active_run = _run_counter
	return _active_run

func record_kill(run_id: int) -> void:
	if run_id == 0 or run_id != _active_run or not ensure_account() or not stats_ready or state.settled.has(run_id):
		return
	state.add_kill()
	_sync_state()

func settle(run_id: int, victory: bool, result: Dictionary) -> void:
	if run_id == 0 or run_id != _active_run or not ensure_account() or not stats_ready:
		return
	if state.settle(run_id, _context, victory, result):
		_sync_state()
		flush()
		changed.emit()

func _sync_state() -> void:
	if not ensure_account(): return
	var new_unlock := false
	for name in state.stats:
		if state.stats[name] == _sent_stats.get(name):
			continue
		_dirty = true
		if bool(native.call("setStatInt", name, int(state.stats[name]))):
			_sent_stats[name] = state.stats[name]
			_revision += 1
	for id in state.unlocked:
		if not state.unlocked[id] or bool(_sent_achievements.get(id, false)):
			continue
		_dirty = true
		if bool(native.call("setAchievement", id)):
			_sent_achievements[id] = true
			_revision += 1
			new_unlock = true
	if new_unlock:
		flush()
		changed.emit()

func flush() -> void:
	if not ensure_account() or not stats_ready or not _dirty or _store_busy or _retry_after > 0:
		return
	_store_revision = _revision
	_store_busy = bool(native.call("storeStats"))
	_store_age = 0
	_retry_after = 60

func _on_stored(game_id: int, result: int) -> void:
	if game_id != SteamAchievementCatalog.APP_ID or not ensure_account():
		return
	_store_busy = false
	if result == 1:
		_dirty = _revision != _store_revision or state.stats != _sent_stats or state.unlocked != _sent_achievements
		status = "Steam 成就已保存"
	elif result == 8:
		# Steam rejected stale/invalid parameters and refreshed its cached values.
		# Do not replay absolute counters over that authoritative correction.
		stats_ready = false
		_active_run = 0
		_dirty = false
		status = "Steam 校正了统计，正在重新读取；下一局恢复计入"
	else:
		_dirty = true
		_retry_after = 60
		status = "Steam 保存暂未成功，将自动重试"
	changed.emit()

func _import_legacy() -> void:
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null:
		return
	var migration := ConfigFile.new()
	var path := "user://steam_legacy_import.cfg"
	migration.load(path)
	var owner := String(migration.get_value("migration", "owner", ""))
	if owner != "" and owner != account:
		return
	if owner == "":
		var source := ConfigFile.new()
		if source.load(campaign.SAVE_PATH) != OK:
			return
		var contracts := {}
		for entry in campaign.LEVELS:
			var level: RefCounted = load(entry.script).new()
			var ids: Array[String] = []
			for goal in level.campaign_story_goals():
				ids.append(goal.id)
			contracts[entry.id] = {"version":level.story_contract_version(), "ids":ids}
		var verified := SteamAchievementCatalog.verified_legacy_ids(source.get_value("progress", "records", {}), contracts)
		migration.set_value("migration", "owner", account)
		migration.set_value("migration", "achievements", verified)
		if migration.save(path) != OK:
			return
	for id in migration.get_value("migration", "achievements", []):
		state.unlocked[id] = true

func open_page(url: String) -> void:
	if available and bool(native.call("isOverlayEnabled")):
		native.call("activateGameOverlayToWebPage", url)
	else:
		OS.shell_open(url)

func ensure_account() -> bool:
	if not available or native == null: return false
	if str(native.call("getSteamID")) == account: return true
	available = false
	stats_ready = false
	_active_run = 0
	status = "Steam 账号已变化，请重启游戏后继续计入成就"
	changed.emit()
	return false

func _exit_tree() -> void:
	flush()
	if native != null:
		native.call("steamShutdown")
