extends Node
## Windows Steam adapter. No static Steam class reference in portable game code.

signal changed
signal initialized

const LocalRunSession = preload("res://scripts/steam_local_run_session.gd")
const StatsReader = preload("res://scripts/steam_stats_reader.gd")
var _local_runs: RefCounted
var _publisher_enabled := false
var _local_tick := 0.0
var _stats_reader: RefCounted
var _correction_required := false
var _campaign_startup_ready := false
var _campaign_reference_scan := false
var _campaign_references: Array = []
var _campaign_startup_completion := false
var _persistent_ready := false
var _adoption: Dictionary = {}
var _startup_merge: Dictionary = {}
var _correction_request: Dictionary = {}
var _campaign_handoff_intent: Dictionary = {}
const RECEIPT_ROOT := "user://steam_receipts/v1"

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
	if _correction_required:
		_local_tick += delta
		if _local_tick >= 1.0:
			_local_tick = 0.0
			_drive_correction()
		return
	if _local_runs != null:
		_local_tick += delta
		if _local_tick >= 1.0:
			_local_tick = 0.0
			if _persistent_ready and ensure_account() and stats_ready and _local_runs.has_pending(): _checkpoint_persistent_run()
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
	# Lifecycle scanning precedes account-ledger creation, migration and writes.
	# ContinueFlow calls prepare/complete_campaign_startup after its real scan.
	if _campaign_startup_ready:
		var completed: Dictionary = complete_campaign_startup()
		if not completed.ok:
			status = "本机战斗记录暂不可用，请保留存档并重新启动游戏"
			changed.emit()
			return
	changed.emit()

func begin_run(context: Dictionary) -> int:
	_active_run = 0
	_run_kill_highwater = 0
	_context = context.duplicate(true)
	state.settled.clear()
	if not _campaign_startup_ready or not _campaign_background_allowed() or not ensure_account() or not stats_ready or context.get("mode", "custom") == "custom" or SteamRunPolicy.test_environment():
		return 0
	# Credit eligibility is frozen at launch. A later cloud-owner bind cannot
	# retroactively credit a campaign that began without the matching profile.
	if context.get("mode") == "campaign" and (Campaign.cloud_owner.is_empty() or Campaign.cloud_owner != account): return 0
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
	if not _campaign_startup_ready or not _campaign_background_allowed(): return
	if _local_runs != null and not _publisher_enabled: return
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
	if not _campaign_startup_ready or not _campaign_background_allowed(): return
	if _local_runs != null and not _publisher_enabled: return
	if _correction_required or not ensure_account() or not stats_ready or not _dirty or _store_busy or _retry_after > 0:
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
			_correction_required = true
			_publisher_enabled = false
			stats_ready = false; _active_run = 0
			if _correction_request.is_empty(): _correction_request = {"owner":account, "phase":"invalidate", "last_error":{}}
			# Keep the request even if another proposal currently owns the ledger.
			# Deferred work is outside physics and must finish that exact write first.
			call_deferred("_drive_correction")
			status = "Steam 统计发生校正，本局停止计入，请重启后检查"
			changed.emit()
		elif _publisher_enabled:
			# Neither a late success nor a failure may acknowledge a run generation.
			# Repeated absolute SetStat targets are idempotent on this account.
			_dirty = true
			status = "本局已保存到本机，Steam 统计将自动重试同步"
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
	if not _campaign_startup_completion: return
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
		var source_owner: Variant = source.get_value("progress", "owner", "")
		if typeof(source_owner) != TYPE_STRING or source_owner != campaign.cloud_owner \
			or (not source_owner.is_empty() and source_owner != account): return
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
	if _correction_required: _drive_correction()
	elif _local_runs != null and _local_runs.has_pending(): _checkpoint_persistent_run()
	flush()
	if native != null:
		native.call("steamShutdown")

func _local_bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _drive_correction() -> Dictionary:
	if not _correction_required or _correction_request.is_empty(): return _local_bad("CORRECTION_REQUEST_REQUIRED")
	if Engine.is_in_physics_frame() or not ensure_account() or _correction_request.owner != account or _local_runs == null:
		return _local_bad("CORRECTION_ACCOUNT_UNAVAILABLE")
	var result: Dictionary
	if _correction_request.phase == "invalidate":
		result = _local_runs.invalidate()
		if not result.ok:
			_correction_request.last_error = result.duplicate(true)
			return result
		_correction_request.phase = "read"
	if _correction_request.phase == "read":
		if _stats_reader == null: return _local_bad("CORRECTION_READ_REQUIRED")
		var fresh: Dictionary = _stats_reader.current_snapshot()
		if not fresh.get("ok",false) or fresh.get("owner") != account or not ensure_account(): return _local_bad("CORRECTION_READ_REQUIRED")
		var durable: Dictionary = _local_runs.capture()
		if not durable.ok: return durable
		if not durable.record.requires_correction: return _local_bad("DURABLE_INVALIDATION_REQUIRED")
		_correction_request["snapshot"] = fresh.duplicate(true)
		_correction_request["generation"] = int(durable.record.generation)
		_correction_request.phase = "correct"
	if _correction_request.phase == "correct":
		var fresh: Dictionary = _correction_request.snapshot
		result = _local_runs.correct(fresh.stats, fresh.unlocked, _correction_request.generation)
		if not result.ok:
			_correction_request.last_error = result.duplicate(true)
			return result
		_correction_request.phase = "done"
	# This process remains closed after authoritative correction. Existing live
	# intents keep their old epoch; neither a late callback nor this read reopens it.
	return {"ok":true, "code":"CORRECTION_DURABLE_RESTART_REQUIRED", "publisher_enabled":false}

func _open_persistent_runs(root_path := RECEIPT_ROOT, require_existing := false) -> Dictionary:
	if root_path != RECEIPT_ROOT: return _local_bad("PERSISTENT_PRODUCTION_ROOT_REQUIRED")
	if _correction_required or not ensure_account() or not stats_ready: return _local_bad("STEAM_NOT_READY")
	if not _campaign_reference_scan: return _local_bad("CAMPAIGN_REFERENCE_SCAN_REQUIRED")
	if _persistent_ready:
		return {"ok":true} if _local_runs != null and _local_runs._owner == account else _local_bad("PERSISTENT_OWNER_CHANGED")
	if _adoption.is_empty():
		if _local_runs != null or _active_run != 0 or _dirty or _store_busy or _store_revision >= 0: return _local_bad("PERSISTENT_ADOPTION_BUSY")
		if require_existing:
			var reader := LocalRunSession.Ledger.Store.new(account, root_path)
			if reader.directory.is_empty() or not DirAccess.dir_exists_absolute(reader.directory): return _local_bad("CAMPAIGN_LEDGER_MISSING")
			var prior: Dictionary = reader.open_head()
			if prior.ok and prior.revision == 0: return _local_bad("CAMPAIGN_LEDGER_MISSING")
			if not prior.ok and prior.code != "RECOVERY_REQUIRED": return prior
		_adoption = {"owner":account, "root":root_path, "require_existing":require_existing,
			"phase":"open", "stats":state.stats.duplicate(true), "unlocked":state.unlocked.duplicate(true)}
		# Retain the one writer before the first call that can acquire its lock.
		_local_runs = LocalRunSession.new()
	if _adoption.owner != account or _adoption.root != root_path or _adoption.require_existing != require_existing:
		return _local_bad("PERSISTENT_ADOPTION_SCOPE_CHANGED")
	if _adoption.phase == "open":
		var opened: Dictionary = _local_runs.open(account, _adoption.stats, _adoption.unlocked, root_path, require_existing)
		if not opened.ok: return opened
		_adoption.phase = "upgrade" if opened.get("upgrade_required",false) else "capture"
	if _adoption.phase == "upgrade":
		var upgraded: Dictionary = _local_runs.upgrade()
		if not upgraded.ok: return upgraded
		_adoption.phase = "capture"
	if _adoption.phase == "capture":
		var captured: Dictionary = _local_runs.capture()
		if not captured.ok: return captured
		_adoption["generation"] = int(captured.record.generation)
		_adoption.phase = "correction_read" if captured.record.requires_correction else "merge"
	if _adoption.phase == "correction_read":
		if _stats_reader == null: return _local_bad("CORRECTION_READ_REQUIRED")
		var fresh: Dictionary = _stats_reader.current_snapshot()
		if not fresh.get("ok",false) or fresh.get("owner") != account or not ensure_account(): return _local_bad("CORRECTION_READ_REQUIRED")
		_adoption["snapshot"] = fresh.duplicate(true)
		_adoption.phase = "correct"
	if _adoption.phase == "correct":
		var fresh: Dictionary = _adoption.snapshot
		var corrected: Dictionary = _local_runs.correct(fresh.stats, fresh.unlocked, _adoption.generation)
		if not corrected.ok: return corrected
		# Never max-merge stale pre-correction targets back into authoritative data.
		_adoption.stats = fresh.stats.duplicate(true); _adoption.unlocked = fresh.unlocked.duplicate(true)
		_sent_stats = fresh.stats.duplicate(true); _sent_achievements = fresh.unlocked.duplicate(true)
		_adoption.phase = "corrected_capture"
	if _adoption.phase == "corrected_capture":
		var captured: Dictionary = _local_runs.capture()
		if not captured.ok: return captured
		_adoption.generation = int(captured.record.generation)
		_adoption.phase = "merge"
	if _adoption.phase == "merge":
		var merged: Dictionary = _local_runs.merge_remote_floor(_adoption.stats, _adoption.unlocked, _adoption.generation)
		if not merged.ok: return merged
		_adoption.phase = "readback"
	var final: Dictionary = _local_runs.capture()
	if not final.ok: return final
	if final.record.owner != account or final.record.requires_correction: return _local_bad("PERSISTENT_ADOPTION_READBACK")
	state.seed(final.record.stats, final.record.unlocked)
	_persistent_ready = true
	_adoption.clear()
	status = "本局进度保存在本机，Steam 同步尚未接通"
	return {"ok":true}

func _begin_persistent_run(context: Dictionary) -> int:
	# Called only after begin_run's production eligibility gate; native QA
	# invokes this seam with a fake SDK because test_environment remains closed.
	if _local_runs == null or not _persistent_ready or _correction_required or not ensure_account() or not stats_ready or _run_counter >= 2147483647: return 0
	var begun: Dictionary = _local_runs.begin(context)
	if not begun.ok: return 0
	_run_counter += 1; _active_run = _run_counter
	_context = context.duplicate(true); _run_kill_highwater = 0
	state.settled.clear()
	return _active_run

func _checkpoint_persistent_run() -> Dictionary:
	if _local_runs == null or not _persistent_ready or _correction_required or not ensure_account() or not stats_ready: return _local_bad("STEAM_NOT_READY")
	var captured: Dictionary = _local_runs.checkpoint()
	if not captured.ok:
		status = "本局进度未能保存，请保留当前战斗并检查存储"
		changed.emit()
		return captured
	state.seed(captured.record.stats, captured.record.unlocked)
	if _local_runs._settled: state.settled[_active_run] = true
	if _publisher_enabled:
		_sync_state()
		flush()
	changed.emit()
	return captured

func _persistent_binding(run_id: int, context: Dictionary, total: int) -> Dictionary:
	if _local_runs == null or not _persistent_ready or _correction_required or run_id == 0 or run_id != _active_run or context != _context or not ensure_account() or not stats_ready: return _local_bad("PERSISTENT_STEAM_BINDING_REQUIRED")
	var bound: Dictionary = _local_runs.binding(total, context)
	if not bound.ok: return bound
	var durable: Dictionary = _local_runs.capture()
	if not durable.ok: return durable
	state.seed(durable.record.stats, durable.record.unlocked)
	return bound

func _prepare_persistent_resume(binding: Dictionary, context: Dictionary, total: int) -> Dictionary:
	if _local_runs == null or not _persistent_ready or _correction_required or _active_run != 0 or _run_counter >= 2147483647 or not ensure_account() or not stats_ready: return _local_bad("PERSISTENT_STEAM_BINDING_REQUIRED")
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

func _adopt_publisher() -> Dictionary:
	if not _campaign_startup_completion: return _local_bad("CAMPAIGN_STARTUP_REQUIRED")
	# Read/merge before gameplay begins; never retire local targets on an SDK
	# callback. Across restarts, publish absolute maxima, not replayed deltas.
	var adopted := _open_persistent_runs()
	if not adopted.ok: return adopted
	_publisher_enabled = true
	status = "战斗记录已保存到本机，Steam 统计自动同步"
	return adopted


func _campaign_intent() -> Script:
	return load("res://scripts/run_campaign_progress_intent.gd")

func _campaign_gate() -> Script:
	return load("res://scripts/run_campaign_progress_gate.gd")

func _campaign_background_allowed() -> bool:
	return _campaign_gate().background_allowed()

func _campaign_battle_source(battle: Variant) -> bool:
	var source: Resource = ResourceLoader.load("res://scripts/battle.gd", "Script", ResourceLoader.CACHE_MODE_REUSE)
	return typeof(battle) == TYPE_OBJECT and is_instance_valid(battle) and battle is Node \
		and get_tree().current_scene == battle and battle.get_script() == source and battle.phase == 3 \
		and battle._official_context.get("mode") == "campaign"

func capture_campaign_credit(battle: Node, token: String) -> Dictionary:
	if not _campaign_battle_source(battle) or Engine.is_in_physics_frame(): return _local_bad("CAMPAIGN_CREDIT_SOURCE_REQUIRED")
	if battle._steam_run_id == 0:
		var offline := {"kind":"uncredited"}
		var verified: Dictionary = verify_campaign_live_credit(battle,token,offline)
		return {"ok":true,"credit":offline} if verified.ok else verified
	if Campaign.cloud_owner.is_empty() or Campaign.cloud_owner != account: return _local_bad("CAMPAIGN_CREDIT_OWNER_UNBOUND")
	var bound: Dictionary = _persistent_binding(battle._steam_run_id,battle._official_context,battle._steam_valid_kills)
	if not bound.ok: return bound
	var durable: Dictionary = _local_runs.capture()
	if not durable.ok: return durable
	if durable.record.version != 3 or durable.record.requires_correction: return _local_bad("CAMPAIGN_CREDIT_CORRECTION_OR_UPGRADE")
	var credit := {"kind":"steam","binding":bound.binding.duplicate(true),"correction_epoch":durable.record.correction_epoch}
	var verified: Dictionary = verify_campaign_live_credit(battle,token,credit)
	return {"ok":true,"credit":credit} if verified.ok else verified

func verify_campaign_live_credit(battle: Node, token: String, credit: Dictionary) -> Dictionary:
	if not _campaign_battle_source(battle): return _local_bad("CAMPAIGN_CREDIT_SOURCE_REQUIRED")
	var checked: Dictionary = _campaign_intent().validate_credit(credit,token,Campaign.cloud_owner)
	if not checked.ok: return checked
	if credit.kind == "uncredited":
		if battle._steam_run_id != 0 or _active_run != 0: return _local_bad("CAMPAIGN_CREDIT_LINEAGE_CONFLICT")
		if _local_runs != null:
			var existing: Dictionary = _local_runs.capture()
			if not existing.ok: return existing
			if existing.record.runs.has(token): return _local_bad("CAMPAIGN_CREDIT_LINEAGE_CONFLICT")
		return {"ok":true}
	if _correction_required or not ensure_account() or not stats_ready or _local_runs == null \
		or _local_runs.get_script() != LocalRunSession or _local_runs._owner != account \
		or Campaign.cloud_owner != account or battle._steam_run_id == 0 or battle._steam_run_id != _active_run \
		or _context != battle._official_context or _local_runs._token != token: return _local_bad("CAMPAIGN_CREDIT_SOURCE_CHANGED")
	var pending: Dictionary = _local_runs._ledger.pending_status()
	if not pending.ok: return pending
	if pending.get("pending",false) and pending.get("kind") == "handoff":
		return _local_runs.verify_reserved_credit(credit, token, battle._official_context, battle._steam_valid_kills)
	var durable: Dictionary = _local_runs.capture()
	if not durable.ok: return durable
	var record: Dictionary = durable.record
	if record.version != 3 or record.requires_correction or record.correction_epoch != credit.correction_epoch \
		or not record.runs.has(token) or record.generation < credit.binding.generation \
		or (record.generation == credit.binding.generation and durable.file_sha256 != credit.binding.receipt_sha256):
		return _local_bad("CAMPAIGN_CREDIT_RECEIPT_CHANGED")
	var run: Dictionary = record.runs[token]
	if run.context != battle._official_context or run.credited_kills != credit.binding.credited_kills \
		or battle._steam_valid_kills > credit.binding.credited_kills: return _local_bad("CAMPAIGN_CREDIT_HIGHWATER_CHANGED")
	return {"ok":true}

func _checked_campaign_intent(value: Variant) -> Dictionary:
	# Historical validation proves data shape only, never current replay authority.
	# The Coordinator checks installed identity before acquiring its write gate.
	var intent: Script = _campaign_intent()
	if typeof(value) != TYPE_DICTIONARY: return _local_bad("CAMPAIGN_INTENT_REQUIRED")
	var context: Dictionary = intent.Profiles.normalize_context(value.get("context"))
	if not context.ok: return context
	var expected := {"ok":true,"context":context.context,"profile_id":context.profile_id,
		"scope":{"owner":value.get("owner"),"content_version":value.get("content_version"),"engine_sha256":value.get("engine_sha256")}}
	return intent.validate(value,String(value.get("token","")),expected)

func commit_campaign_handoff(value: Dictionary) -> Dictionary:
	var checked: Dictionary = _checked_campaign_intent(value)
	if not checked.ok: return checked
	var intent: Dictionary = checked.intent
	if Engine.is_in_physics_frame() or not _campaign_gate().matches_pending_intent(intent): return _local_bad("CAMPAIGN_HANDOFF_GATE_REQUIRED")
	if intent.credit.kind == "uncredited": return {"ok":true,"proof":_campaign_intent().uncredited_proof(intent)}
	if _correction_required or not ensure_account() or not stats_ready or not _persistent_ready or _local_runs == null \
		or _local_runs.get_script() != LocalRunSession or _local_runs._owner != account \
		or intent.owner != account or Campaign.cloud_owner != account: return _local_bad("CAMPAIGN_HANDOFF_ACCOUNT_UNAVAILABLE")
	if _campaign_handoff_intent.is_empty(): _campaign_handoff_intent = intent.duplicate(true)
	elif _campaign_handoff_intent != intent: return _local_bad("CAMPAIGN_HANDOFF_INTENT_CHANGED")
	var applied: Dictionary = _local_runs.apply_campaign_handoff(_campaign_intent().handoff_descriptor(intent))
	if not applied.ok: return applied
	var captured: Dictionary = _local_runs.capture()
	if not captured.ok: return captured
	state.seed(captured.record.stats,captured.record.unlocked)
	if _local_runs._settled and _local_runs._token == intent.token: state.settled[_active_run] = true
	_dirty = true
	_campaign_handoff_intent.clear()
	return applied

func retry_campaign_handoff() -> Dictionary:
	if _campaign_handoff_intent.is_empty(): return _local_bad("CAMPAIGN_HANDOFF_RETRY_REQUIRED")
	return commit_campaign_handoff(_campaign_handoff_intent)

func inspect_campaign_handoff(value: Dictionary) -> Dictionary:
	var checked: Dictionary = _checked_campaign_intent(value)
	if not checked.ok: return checked
	var intent: Dictionary = checked.intent
	if intent.credit.kind == "uncredited": return {"ok":true,"proof":_campaign_intent().uncredited_proof(intent)}
	if _correction_required or not ensure_account() or not stats_ready or not _persistent_ready or _local_runs == null \
		or _local_runs.get_script() != LocalRunSession or _local_runs._owner != account \
		or intent.owner != account or Campaign.cloud_owner != account: return _local_bad("CAMPAIGN_HANDOFF_ACCOUNT_UNAVAILABLE")
	return _local_runs.campaign_handoff_proof(_campaign_intent().handoff_descriptor(intent))

func prepare_campaign_startup(references: Array) -> Dictionary:
	if Engine.is_in_physics_frame(): return _local_bad("CAMPAIGN_STARTUP_PHYSICS_WRITE")
	if _campaign_reference_scan and _campaign_references != references: return _local_bad("CAMPAIGN_STARTUP_REFERENCES_CHANGED")
	var required := false
	for reference in references:
		var checked: Dictionary = _checked_campaign_intent(reference)
		if not checked.ok: return checked
		if checked.intent.credit.kind != "steam": continue
		required = true
		if not ensure_account() or checked.intent.owner != account: return _local_bad("CAMPAIGN_HANDOFF_ACCOUNT_UNAVAILABLE")
	_campaign_references = references.duplicate(true)
	_campaign_reference_scan = true
	if required and not stats_ready: return _local_bad("CAMPAIGN_HANDOFF_STATS_NOT_READY")
	if not _persistent_ready and available and stats_ready:
		var opened: Dictionary = _open_persistent_runs(RECEIPT_ROOT,required)
		if not opened.ok: return opened
	return {"ok":true,"ledger_required":required}

func complete_campaign_startup() -> Dictionary:
	if not _campaign_reference_scan: return _local_bad("CAMPAIGN_REFERENCE_SCAN_REQUIRED")
	if _correction_required: return _local_bad("CORRECTION_RESTART_REQUIRED")
	# Empty/offline startup remains playable. Delayed real SDK readiness retries
	# this same gated adoption; no synthetic account or receipt is introduced.
	if not available or not stats_ready:
		if _campaign_references.any(func(item): return item.credit.kind == "steam"):
			return _local_bad("CAMPAIGN_HANDOFF_ACCOUNT_UNAVAILABLE")
		_campaign_startup_ready = true
		return {"ok":true,"publisher_enabled":false}
	if not ensure_account(): return _local_bad("CAMPAIGN_HANDOFF_ACCOUNT_UNAVAILABLE")
	if not _persistent_ready:
		var prepared: Dictionary = prepare_campaign_startup(_campaign_references)
		if not prepared.ok: return prepared
	if _startup_merge.is_empty():
		var captured: Dictionary = _local_runs.capture()
		if not captured.ok: return captured
		# Correction is authoritative. Historical CFG/migration achievements must
		# not be re-imported over its tombstones on this or a later restart.
		if int(captured.record.correction_epoch) == 0:
			_campaign_startup_completion = true
			_import_legacy()
			_campaign_startup_completion = false
			state.evaluate()
		_startup_merge = {"stats":state.stats.duplicate(true), "unlocked":state.unlocked.duplicate(true), "generation":int(captured.record.generation), "phase":"merge"}
	if _startup_merge.phase == "merge":
		var merged: Dictionary = _local_runs.merge_remote_floor(_startup_merge.stats,_startup_merge.unlocked,_startup_merge.generation)
		if not merged.ok: return merged
		_startup_merge.phase = "readback"
	var current: Dictionary = _local_runs.capture()
	if not current.ok: return current
	if current.record.requires_correction or current.record.owner != account: return _local_bad("CAMPAIGN_STARTUP_RECEIPT_CHANGED")
	state.seed(current.record.stats,current.record.unlocked)
	_startup_merge.clear()
	_campaign_startup_ready = true
	_publisher_enabled = true
	status = "战斗记录已保存到本机，Steam 统计自动同步"
	_sync_state()
	flush()
	return {"ok":true,"publisher_enabled":true}

func refresh_campaign_targets() -> void:
	# The campaign ledger already settled before gen3. This only publishes its
	# absolute targets; it must never queue a second business settlement.
	_sync_state()
	flush()
	changed.emit()
