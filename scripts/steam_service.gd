extends Node
## Windows Steam adapter. No static Steam class reference in portable game code.

signal changed
signal initialized

const LocalRunSession = preload("res://scripts/steam_local_run_session.gd")
const StatsReader = preload("res://scripts/steam_stats_reader.gd")
var _local_runs: RefCounted
var _stats_reader: RefCounted
var _correction_required := false

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
var _run_kill_highwater := 0
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
	if _local_runs != null:
		_tick += delta
		if _tick >= 1.0:
			_tick = 0.0
			if ensure_account() and stats_ready and _local_runs.has_pending(): _checkpoint_persistent_run()
		return
	if _correction_required:
		ensure_account()
		return
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
		if not stats_ready and not _correction_required:
			_read_initial_state()
		elif _dirty and _retry_after <= 0:
			_sync_state()
			flush()

func _read_initial_state() -> void:
	if _correction_required or not ensure_account(): return
	stats_ready = false
	if _stats_reader == null:
		var reader := StatsReader.new()
		var attached: Dictionary = reader.attach(account)
		if attached.ok: _stats_reader = reader
	var snapshot: Dictionary = {"ok": false}
	if _stats_reader != null: snapshot = _stats_reader.current_snapshot()
	if not snapshot.get("ok", false) or snapshot.get("owner") != account or not ensure_account():
		status = "Steam 统计配置尚未就绪，当前不计入"
		changed.emit()
		return
	# Native getter success is mandatory for every stat and achievement. A write
	# probe cannot distinguish a failed getter from the legitimate value zero.
	var values: Dictionary = snapshot.stats
	var initial: Dictionary = snapshot.unlocked
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
	_run_kill_highwater = 0
	_context = context.duplicate(true)
	state.settled.clear()
	if not ensure_account() or not stats_ready or context.get("mode", "custom") == "custom" or SteamRunPolicy.test_environment():
		return 0
	if _local_runs != null: return _begin_persistent_run(context)
	_run_counter += 1
	_active_run = _run_counter
	return _active_run

func record_kill(run_id: int, total_valid_kills: Variant) -> void:
	if run_id == 0 or run_id != _active_run or not ensure_account() or not stats_ready or state.settled.has(run_id):
		return
	# A restored world can be behind the service's history. Replaying its old
	# deaths must not increase statistics again. Never infer a per-event delta.
	if typeof(total_valid_kills) != TYPE_INT or total_valid_kills < 0 or total_valid_kills > 2147483647:
		return
	if _local_runs != null:
		var observed: Dictionary = _local_runs.observe(total_valid_kills)
		if observed.ok: _run_kill_highwater = maxi(_run_kill_highwater, total_valid_kills)
		return
	if total_valid_kills <= _run_kill_highwater: return
	var newly_credited: int = total_valid_kills - _run_kill_highwater
	_run_kill_highwater = total_valid_kills
	state.stats.TOTAL_KILLS = mini(2147483647, int(state.stats.get("TOTAL_KILLS", 0)) + newly_credited)
	state.evaluate()
	_sync_state()

func settle(run_id: int, victory: bool, result: Dictionary) -> void:
	if run_id == 0 or run_id != _active_run or not ensure_account() or not stats_ready:
		return
	if _local_runs != null:
		var queued: Dictionary = _local_runs.queue_terminal(victory, result)
		if queued.ok and queued.get("changed", false): call_deferred("_checkpoint_persistent_run")
		return
	if state.settle(run_id, _context, victory, result):
		_sync_state()
		flush()
		changed.emit()

func _sync_state() -> void:
	if _local_runs != null: return # Durable local mode awaits the continuous SDK publisher.
	if not ensure_account() or not stats_ready or _correction_required: return
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
	if _local_runs != null: return
	if not ensure_account() or not stats_ready or not _dirty or _store_busy or _retry_after > 0:
		return
	_store_revision = _revision
	_store_busy = bool(native.call("storeStats"))
	_store_age = 0
	_retry_after = 60

func _on_stored(game_id: int, result: int) -> void:
	if game_id != SteamAchievementCatalog.APP_ID or not ensure_account():
		return
	if _local_runs != null:
		if result == 8:
			_local_runs.invalidate(); stats_ready = false; _active_run = 0
			status = "Steam 统计发生校正，本局停止计入，请重启后检查"
			changed.emit()
		return # Uncorrelated callbacks cannot acknowledge local receipt generations.
	if _correction_required: return
	if result == 1:
		# StoreStats and IndicateAchievementProgress share this notification, which
		# has no request ID. It must never release a newer in-flight request or
		# acknowledge any revision. Keep periodic, rate-limited absolute retries.
		if not _dirty: return
		status = "Steam 保存尚未确认，将重试"
	elif result == 8:
		# Steam rejected stale/invalid parameters and refreshed its cached values.
		# Retain local state, stop writes and require a fresh process to read the
		# correction. A late success must not re-enable this process.
		_correction_required = true
		stats_ready = false
		_active_run = 0
		status = "Steam 统计发生校正，本局停止计入，请重启后检查"
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
	if _local_runs != null and _local_runs.has_pending(): _checkpoint_persistent_run()
	flush()
	if native != null:
		native.call("steamShutdown")

func _local_bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _open_persistent_runs(root_path := "user://steam_receipts/v1") -> Dictionary:
	# Internal activation seam. The normal startup does not enable this until
	# the persistent outbox/SDK publisher is ready. Never inject paths from slots.
	if _local_runs != null or _active_run != 0 or _dirty or _store_busy or _store_revision >= 0 or _correction_required: return _local_bad("PERSISTENT_ADOPTION_BUSY")
	if not ensure_account() or not stats_ready: return _local_bad("STEAM_NOT_READY")
	var local := LocalRunSession.new()
	var opened: Dictionary = local.open(account, state.stats, state.unlocked, root_path)
	if not opened.ok: return opened
	var captured: Dictionary = local.capture()
	if not captured.ok or captured.record.requires_correction: return _local_bad("LOCAL_RECEIPT_UNAVAILABLE")
	_local_runs = local
	state.seed(captured.record.stats, captured.record.unlocked)
	status = "本局进度保存在本机，Steam 同步尚未接通"
	return {"ok": true}

func _begin_persistent_run(context: Dictionary) -> int:
	# Called only after begin_run's production eligibility gate; native QA
	# invokes this seam with a fake SDK because test_environment remains closed.
	if _local_runs == null or not ensure_account() or not stats_ready or _run_counter >= 2147483647: return 0
	var begun: Dictionary = _local_runs.begin(context)
	if not begun.ok: return 0
	_run_counter += 1; _active_run = _run_counter
	_context = context.duplicate(true); _run_kill_highwater = 0
	state.settled.clear()
	return _active_run

func _checkpoint_persistent_run() -> Dictionary:
	if _local_runs == null or not ensure_account() or not stats_ready: return _local_bad("STEAM_NOT_READY")
	var captured: Dictionary = _local_runs.checkpoint()
	if not captured.ok:
		status = "本局进度未能保存，请保留当前战斗并检查存储"
		changed.emit()
		return captured
	state.seed(captured.record.stats, captured.record.unlocked)
	if _local_runs._settled: state.settled[_active_run] = true
	changed.emit()
	return captured

func _persistent_binding(run_id: int, context: Dictionary, total: int) -> Dictionary:
	if _local_runs == null or run_id == 0 or run_id != _active_run or context != _context or not ensure_account() or not stats_ready: return _local_bad("PERSISTENT_STEAM_BINDING_REQUIRED")
	var bound: Dictionary = _local_runs.binding(total, context)
	if not bound.ok: return bound
	var durable: Dictionary = _local_runs.capture()
	if not durable.ok: return durable
	state.seed(durable.record.stats, durable.record.unlocked)
	return bound

func _prepare_persistent_resume(binding: Dictionary, context: Dictionary, total: int) -> Dictionary:
	if _local_runs == null or _active_run != 0 or _run_counter >= 2147483647 or not ensure_account() or not stats_ready: return _local_bad("PERSISTENT_STEAM_BINDING_REQUIRED")
	var prepared: Dictionary = _local_runs.prepare_resume(binding, context, total)
	if not prepared.ok: return prepared
	prepared.handle = _run_counter + 1
	return prepared

func _install_persistent_resume(prepared: Dictionary) -> void:
	# No IO, signals, SDK calls or awaits between the Session's final receipt
	# revalidation and this assignment. It cannot retire or acknowledge a receipt.
	_local_runs.install_prepared(prepared)
	_run_counter = prepared.handle; _active_run = prepared.handle
	_context = prepared.context.duplicate(true); _run_kill_highwater = prepared.credited_kills
	state.seed(prepared.record.stats, prepared.record.unlocked)
