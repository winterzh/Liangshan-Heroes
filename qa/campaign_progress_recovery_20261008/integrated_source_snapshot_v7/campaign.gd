extends Node
## 战役进度管理（Autoload "Campaign"）：关卡注册表、当前关、解锁进度、存档。

const VERSION := "2.0"   # 完整包版本；仅 Android 启用应用内内容更新。

const LEVELS := [
	{"id": "level1", "title": "智取生辰纲", "sub": "三人酒计·分队夺纲", "script": "res://scripts/levels/level1_huangnigang_short.gd"},
	{"id": "level2", "title": "江州劫法场", "sub": "有限补给·分路劫救", "script": "res://scripts/levels/level2_jiangzhou_rts.gd"},
	{"id": "level3", "title": "三打祝家庄", "sub": "扎营扩军·断援攻城", "script": "res://scripts/levels/level3_zhujiazhuang_rts.gd"},
	{"id": "level4", "title": "大破连环马", "sub": "扎营练枪·断粮破骑", "script": "res://scripts/levels/level4_lianhuanma_rts.gd"},
	{"id": "level5", "title": "三败高太尉", "sub": "经营水寨·水陆协同", "script": "res://scripts/levels/level5_gao_rts.gd"},
	{"id": "level6", "title": "大闹野猪林", "sub": "花和尚禅杖·救林冲", "script": "res://scripts/levels/level6_yezhulin.gd"},
	{"id": "level7", "title": "醉打蒋门神", "sub": "择酒练步·诱招反击", "script": "res://scripts/levels/level7_kuaihuolin_short.gd"},
	{"id": "level8", "title": "智取大名府", "sub": "城外经营·翠云楼火号", "script": "res://scripts/levels/level8_daming_rts.gd"},
]

const STORY_ORDER := ["level6", "level1", "level7", "level2", "level3", "level4", "level8", "level5"]

const SAVE_PATH := "user://campaign.cfg"
const SAVE_SCHEMA := 2

const SKIRMISH_SCRIPT := "res://scripts/levels/skirmish.gd"
const SKIRMISH_AI_SCRIPT := "res://scripts/levels/skirmish_ai.gd"
const CUSTOM_DEFENSE_SCRIPT := "res://scripts/levels/custom_defense.gd"
const SCENARIO_SCRIPT := "res://scripts/levels/scenario.gd"
const ARENA_SCRIPT := "res://scripts/levels/arena.gd"

var _cfg_writer: RefCounted
var _cfg_writer_scope: Dictionary = {}
var _cfg_writer_error: Dictionary = {}
var _prefs_requested: Dictionary = {}
var _prefs_deferred := false
var _prefs_failed: Dictionary = {}
var _prefs_failed_scope: Dictionary = {}
var current := 0
var unlocked := 1
var records: Dictionary = {} # stable level id -> best base clear / same-run original-story result
var cloud_owner := "" # Owner of the shared local progress; never relabel another account's progress.
var skirmish := false       # 启动自由「遭遇战」模式而非战役关卡
var skirmish_ai := false    # 启动「AI 对战」1v1 模式
var arena := false          # 启动「竞技场」沙盒模式：自由点将+刷敌
var custom_defense := false # 启动「自定义据守」模式（用 custom_config）
var custom_config := {}     # 自定义据守的配置（编辑器产出 / 存档读入）
var scenario := false       # 启动「数据驱动自定义关卡」（用 scenario_data，见 scenario.gd）
var scenario_data := {}     # 自定义关卡的 JSON 字典（编辑器试玩 / 分享码 / SCENARIO 环境变量）
var ai_difficulty := "normal"   # AI 对战难度：easy / normal / hard
var victory_mode := "conquest"  # 1v1 胜利条件：conquest 征服 / regicide 斩首 / koth 占山为王
var defense_waves := 30         # 驻守战波数：20 速战 / 30 经典 / 60 史诗
var defense_hero_cap := 4       # 驻守战英雄上限（60 关放宽到 6 员）
# 自定义随机波次：任意波数 + 每波固定间隔秒数；每波随机敌军(数量随波次增长)、受敌方倍率影响
var defense_random := false     # 是否走「随机波次」模式（与三档预设互斥，按下随机开战时置真）
var defense_rand_waves := 30    # 随机模式波数(1~999)
var defense_interval := 25.0    # 每波之前的间隔秒数(1~600)
var ai_friendly := false        # 驻守战「AI友好模式」：全自动（全员托管 + 自动镜头）。与倍率无关、独立开关。
var ai_friendly_mult := 3.0     # 旧字段·保留兼容（敌方数量倍率现走 enemy_mult）
# 「改变倍率」：独立于 AI友好。开后 敌方倍率(放大敌人) + 英雄倍率(放大你方英雄) 生效。
var scale_on := false           # 是否改变倍率
var enemy_mult := 2.0           # 敌方倍率(1~5)：小兵 数量×e、血×(1+(e-1)/3)、攻×(1+(e-1)/4)；大将只乘血/攻
var hero_mult := 2.0            # 英雄倍率(1~3)：你方英雄 范围/CD/伤害/血量按 n 放大；默认=敌方倍率(封顶3)
var hero_mult_touched := false  # 玩家是否手动改过英雄倍率（改过后不再自动跟随敌方倍率）


## 敌方倍率改动 → 英雄倍率默认跟随(=敌方，封顶3)，直到玩家手动改过英雄倍率才脱钩。
func set_enemy_mult(v: float) -> void:
	enemy_mult = clampf(v, 1.0, 5.0)
	if not hero_mult_touched:
		hero_mult = clampf(enemy_mult, 1.0, 3.0)


func set_hero_mult(v: float) -> void:
	hero_mult = clampf(v, 1.0, 3.0)
	hero_mult_touched = true


func _ready() -> void:
	_load()
	if OS.get_environment("SKIRMISH") == "1":
		skirmish = true
	if OS.get_environment("SKIRMISH_AI") == "1":
		skirmish_ai = true
	if OS.get_environment("ARENA") == "1":
		arena = true
	var ad := OS.get_environment("AI_DIFF")
	if ad != "":
		ai_difficulty = ad
	var vm := OS.get_environment("VICTORY")
	if vm != "":
		victory_mode = vm
	var dw := OS.get_environment("DEF_WAVES")
	if dw != "":
		defense_waves = int(dw)
	var dh := OS.get_environment("DEF_HEROES")
	if dh != "":
		defense_hero_cap = int(dh)
	# 随机波次：DEF_RANDOM=1 启用，波数复用 DEF_WAVES，间隔用 DEF_INTERVAL
	if OS.get_environment("DEF_RANDOM") == "1":
		defense_random = true
		defense_rand_waves = clampi(int(defense_waves), 1, 999)
	var di := OS.get_environment("DEF_INTERVAL")
	if di != "":
		defense_interval = clampf(float(di), 1.0, 600.0)
	if OS.get_environment("AI_FRIENDLY") == "1":
		ai_friendly = true
	var afm := OS.get_environment("AI_FRIENDLY_MULT")
	if afm != "":
		ai_friendly_mult = maxf(1.1, float(afm))
	if OS.get_environment("SCALE_ON") == "1":
		scale_on = true
	var em := OS.get_environment("ENEMY_MULT")
	if em != "":
		set_enemy_mult(float(em)); scale_on = true
	var hm := OS.get_environment("HERO_MULT")
	if hm != "":
		set_hero_mult(float(hm)); scale_on = true
	var lv := OS.get_environment("LEVEL")
	if lv != "":
		current = clampi(int(lv) - 1, 0, LEVELS.size() - 1)
		unlocked = LEVELS.size()  # 测试模式解锁全部
	# headless 测试：CUSTOM_DEFENSE=<json路径> 加载该配置进自定义据守
	var cd := OS.get_environment("CUSTOM_DEFENSE")
	if cd != "" and FileAccess.file_exists(cd):
		var txt := FileAccess.get_file_as_string(cd)
		var data: Variant = JSON.parse_string(txt)
		if data is Dictionary:
			custom_config = data
			custom_defense = true
	# headless / 试玩：SCENARIO=<json路径> 加载数据驱动自定义关卡
	var sc := OS.get_environment("SCENARIO")
	if sc != "" and FileAccess.file_exists(sc):
		var stxt := FileAccess.get_file_as_string(sc)
		var sdata: Variant = JSON.parse_string(stxt)
		if sdata is Dictionary:
			scenario_data = sdata
			scenario = true


func implemented(i: int) -> bool:
	return i >= 0 and i < LEVELS.size() and ResourceLoader.exists(LEVELS[i]["script"])


func is_unlocked(i: int) -> bool:
	# 全部关卡从一开始即可选择（不再按通关进度逐关解锁）
	return implemented(i)


func make_level() -> LevelBase:
	if scenario and not scenario_data.is_empty() and ResourceLoader.exists(SCENARIO_SCRIPT):
		var s = load(SCENARIO_SCRIPT).new()
		s.data = scenario_data
		return s
	if custom_defense and not custom_config.is_empty() and ResourceLoader.exists(CUSTOM_DEFENSE_SCRIPT):
		return load(CUSTOM_DEFENSE_SCRIPT).new()
	if arena and ResourceLoader.exists(ARENA_SCRIPT):
		return load(ARENA_SCRIPT).new()
	if skirmish_ai and ResourceLoader.exists(SKIRMISH_AI_SCRIPT):
		return load(SKIRMISH_AI_SCRIPT).new()
	if skirmish and ResourceLoader.exists(SKIRMISH_SCRIPT):
		return load(SKIRMISH_SCRIPT).new()
	var path: String = LEVELS[current]["script"]
	if not ResourceLoader.exists(path):
		path = "res://scripts/levels/level5_liangshan.gd"
	return load(path).new()


func has_next() -> bool:
	return next_index() >= 0 and implemented(next_index())


func on_level_won(result: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if OS.get_environment("CAMPAIGN_QA") != "1":
		return {"accepted":false, "persisted":false, "new_story_seal":false, "code":"CAMPAIGN_COORDINATOR_REQUIRED"}
	if context.get("mode", "custom") != "campaign":
		return {"accepted":false,"new_story_seal":false}
	var level_id := String(context.get("level_id", ""))
	var index := index_for_id(level_id)
	if index < 0:
		return {"accepted":false,"new_story_seal":false}
	unlocked = maxi(unlocked, index + 2)
	if result.is_empty():
		result = {"core_cleared":true,"story_complete":false,"story_done":0,"story_total":0,
			"done_ids":[],"contract_version":1}
	return record_level_result(level_id, result)


func record_level_result(level_id: String, result: Dictionary) -> Dictionary:
	if OS.get_environment("CAMPAIGN_QA") != "1":
		return {"accepted":false, "persisted":false, "new_story_seal":false, "code":"CAMPAIGN_COORDINATOR_REQUIRED"}
	if index_for_id(level_id) < 0 or not bool(result.get("core_cleared", false)):
		return {"accepted":false,"new_story_seal":false}
	var old: Dictionary = _normalize_record(records.get(level_id, {}))
	var record := old.duplicate(true)
	var was_story_complete := bool(old.story_complete)
	var run_total := maxi(0, int(result.get("story_total", 0)))
	var run_done := clampi(int(result.get("story_done", 0)), 0, run_total)
	var run_complete := bool(result.get("story_complete", false)) and run_total > 0 and run_done == run_total
	var run_ids := _string_ids(result.get("done_ids", []))
	record.cleared = true
	record.story_complete = was_story_complete or run_complete
	record.contract_version = maxi(int(old.contract_version), maxi(1, int(result.get("contract_version", 1))))
	# Keep the exact goal set from one best run. Never union separate runs: doing so
	# could fabricate an original-story completion that never happened in one battle.
	if run_done > int(old.best_done) or (int(old.story_total) == 0 and run_total > 0) or (run_complete and not was_story_complete):
		record.best_done = run_done
		record.story_total = run_total
		record.best_goal_ids = run_ids
	records[level_id] = _normalize_record(record)
	_save()
	var response: Dictionary = records[level_id].duplicate(true)
	response.accepted = true
	response.new_story_seal = run_complete and not was_story_complete
	return response


func level_record(level_id: String) -> Dictionary:
	return _normalize_record(records.get(level_id, {})).duplicate(true)


func has_story_seal(level_id: String) -> bool:
	return bool(level_record(level_id).story_complete)


func _empty_record() -> Dictionary:
	return {"cleared":false,"story_complete":false,"best_done":0,"story_total":0,
		"best_goal_ids":[],"contract_version":1}


func _normalize_record(raw_value: Variant) -> Dictionary:
	var out := _empty_record()
	if not raw_value is Dictionary:
		return out
	var raw: Dictionary = raw_value
	out.cleared = bool(raw.get("cleared", false))
	out.story_complete = bool(raw.get("story_complete", false))
	out.best_done = maxi(0, int(raw.get("best_done", 0)))
	out.story_total = maxi(out.best_done, int(raw.get("story_total", raw.get("best_total", 0))))
	out.best_goal_ids = _string_ids(raw.get("best_goal_ids", []))
	out.contract_version = maxi(1, int(raw.get("contract_version", 1)))
	return out


func _string_ids(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item in value:
			var goal_id := String(item).strip_edges()
			if goal_id != "" and not out.has(goal_id): out.append(goal_id)
	return out


func _normalized_records(raw_value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw_value is Dictionary:
		return out
	var raw: Dictionary = raw_value
	for info in LEVELS:
		var level_id := String(info.id)
		if raw.has(level_id):
			out[level_id] = _normalize_record(raw[level_id])
	return out


func save_prefs() -> void:
	if OS.get_environment("CAMPAIGN_QA") == "1": return
	_prefs_requested.clear()
	for key in ["ai_difficulty", "victory_mode", "scale_on", "enemy_mult", "hero_mult", "hero_mult_touched", "defense_rand_waves", "defense_interval"]:
		_prefs_requested[key] = get(key)
	if not _prefs_deferred:
		_prefs_deferred = true
		get_tree().process_frame.connect(_save_prefs_deferred, CONNECT_ONE_SHOT)

func _save_prefs_deferred() -> void:
	if Engine.is_in_physics_frame():
		get_tree().process_frame.connect(_save_prefs_deferred, CONNECT_ONE_SHOT)
		return
	_prefs_deferred = false
	if _prefs_requested.is_empty(): return
	if not _progress_gate().background_allowed() or persistence_busy(): return
	var frozen: Dictionary = _prefs_requested.duplicate(true)
	_prefs_requested.clear()
	var saved: Dictionary = _write_values("prefs", frozen, cloud_owner)
	if not saved.ok:
		_prefs_failed = frozen.duplicate(true)
		var flow := get_node_or_null("/root/ContinueFlow")
		if flow != null: flow.note_config_failure(saved)


func _progress_gate() -> Script:
	return ResourceLoader.load("res://scripts/run_campaign_progress_gate.gd", "Script", ResourceLoader.CACHE_MODE_REUSE)

func persistence_busy() -> bool:
	return not _prefs_failed.is_empty() or (_cfg_writer != null and _cfg_writer.busy())

func _identity() -> Dictionary:
	return ResourceLoader.load("res://scripts/run_content_identity.gd", "Script", ResourceLoader.CACHE_MODE_REUSE).new().resolve_runtime_identity()

func _save() -> bool:
	if OS.get_environment("CAMPAIGN_QA") == "1": return true
	return _write_values("prefs", {}, cloud_owner).get("ok", false)

func _write_values(operation: String, progress: Dictionary, owner: String) -> Dictionary:
	if not _progress_gate().background_allowed(): return {"ok":false, "code":"CAMPAIGN_PROGRESS_PENDING"}
	if _cfg_writer != null and _cfg_writer.busy(): return {"ok":false, "code":"CAMPAIGN_CFG_OWNED_PENDING"}
	var identity: Dictionary = _identity()
	if not identity.ok: return identity
	_cfg_writer = ResourceLoader.load("res://scripts/run_campaign_cfg_transaction.gd", "Script", ResourceLoader.CACHE_MODE_REUSE).new()
	_cfg_writer_scope = {"operation":operation, "run_token":"", "intent_sha256":"", "target_owner":owner,
		"content_version":identity.content_version, "engine_sha256":identity.engine_binary_sha256}
	var begun: Dictionary = _cfg_writer.begin_write(_cfg_writer_scope)
	if not begun.ok: return _retain_writer_error(begun)
	var cfg: ConfigFile = begun.cfg
	if operation == "cloud":
		cfg.set_value("progress", "schema", SAVE_SCHEMA)
		cfg.set_value("progress", "unlocked", int(progress.unlocked))
		cfg.set_value("progress", "records", progress.records.duplicate(true))
		cfg.set_value("progress", "owner", owner)
	else:
		for key in ["ai_difficulty", "victory_mode", "scale_on", "enemy_mult", "hero_mult", "hero_mult_touched", "defense_rand_waves", "defense_interval"]:
			cfg.set_value("pref", key, progress.get(key, get(key)))
	var saved: Dictionary = _cfg_writer.commit_prepared(cfg)
	if not saved.ok: return _retain_writer_error(saved)
	return _writer_complete(saved)

func _retain_writer_error(error: Dictionary) -> Dictionary:
	_cfg_writer_error = error.duplicate(true)
	if _cfg_writer_scope.get("operation") == "prefs": _prefs_failed_scope = _cfg_writer_scope.duplicate(true)
	if _cfg_writer != null and not _cfg_writer.busy():
		_cfg_writer = null
		_cfg_writer_scope.clear()
	return error

func _writer_complete(receipt: Dictionary) -> Dictionary:
	var operation: String = _cfg_writer_scope.operation
	_cfg_writer = null
	_cfg_writer_scope.clear()
	_cfg_writer_error.clear()
	if operation == "prefs":
		_prefs_failed.clear()
		_prefs_failed_scope.clear()
	if operation == "cloud": _load()
	var cloud := get_node_or_null("/root/SteamCloud")
	if cloud != null: cloud.mark_dirty()
	if not _prefs_requested.is_empty() and not _prefs_deferred:
		_prefs_deferred = true
		get_tree().process_frame.connect(_save_prefs_deferred, CONNECT_ONE_SHOT)
	return receipt

func retry_persistence() -> Dictionary:
	if not _progress_gate().background_allowed(): return {"ok":false, "code":"CAMPAIGN_CFG_RETRY_NOT_ALLOWED"}
	var identity: Dictionary = _identity()
	if _cfg_writer == null:
		if _prefs_failed.is_empty() or _prefs_failed_scope.is_empty() or not identity.ok \
			or identity.content_version != _prefs_failed_scope.content_version or identity.engine_binary_sha256 != _prefs_failed_scope.engine_sha256 \
			or cloud_owner != _prefs_failed_scope.target_owner: return {"ok":false, "code":"CAMPAIGN_PREFS_RETRY_SCOPE_CHANGED"}
		if not cloud_owner.is_empty() and SteamService.available and SteamService.account != cloud_owner:
			return {"ok":false, "code":"CAMPAIGN_CFG_ACCOUNT_SCOPE_CHANGED"}
		return _write_values("prefs", _prefs_failed.duplicate(true), cloud_owner)
	if not identity.ok or identity.content_version != _cfg_writer_scope.content_version or identity.engine_binary_sha256 != _cfg_writer_scope.engine_sha256:
		return {"ok":false, "code":"CAMPAIGN_CFG_INSTALLED_SCOPE_CHANGED"}
	if _cfg_writer.preparation_pending():
		var aborted: Dictionary = _cfg_writer.abort_unprepared()
		if not aborted.ok: return _retain_writer_error(aborted)
		_cfg_writer = null
		_cfg_writer_scope.clear()
		return {"ok":false, "code":"CAMPAIGN_CFG_PREPARATION_RELEASED"}
	if cloud_owner != _cfg_writer_scope.target_owner or (not cloud_owner.is_empty() and SteamService.available and SteamService.account != cloud_owner):
		return {"ok":false, "code":"CAMPAIGN_CFG_ACCOUNT_SCOPE_CHANGED"}
	var saved: Dictionary = _cfg_writer.retry_write()
	return _writer_complete(saved) if saved.ok else _retain_writer_error(saved)

func apply_cloud_progress(progress: Dictionary, owner: String) -> bool:
	if OS.get_environment("CAMPAIGN_QA") == "1":
		unlocked = maxi(1, int(progress.get("unlocked", 1)))
		records = _normalized_records(progress.get("records", {}))
		cloud_owner = owner
		return true
	var cloud := get_node_or_null("/root/SteamCloud")
	var script: Resource = ResourceLoader.load("res://scripts/steam_cloud.gd", "Script", ResourceLoader.CACHE_MODE_REUSE)
	if cloud == null or cloud.get_script() != script or not cloud._applying or cloud._owner != owner: return false
	var payload: Dictionary = cloud._build_payload(owner)
	payload.campaign = progress.duplicate(true)
	if not cloud._validate_payload(payload, owner): return false
	return _write_values("cloud", progress, owner).get("ok", false)

func progress_committed(coordinator: RefCounted) -> void:
	var script: Resource = ResourceLoader.load("res://scripts/run_campaign_progress_coordinator.gd", "Script", ResourceLoader.CACHE_MODE_REUSE)
	if not is_instance_valid(coordinator) or coordinator.get_script() != script: return
	var committed: Dictionary = coordinator.committed_owner()
	if not committed.ok or committed.owner != cloud_owner: return
	var cloud := get_node_or_null("/root/SteamCloud")
	if cloud != null: cloud.mark_dirty()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved_owner: Variant = cfg.get_value("progress", "owner", "")
		cloud_owner = saved_owner if saved_owner is String else "INVALID_OWNER"
		unlocked = maxi(1, int(cfg.get_value("progress", "unlocked", 1)))
		records = _normalized_records(cfg.get_value("progress", "records", {}))
		ai_difficulty = String(cfg.get_value("pref", "ai_difficulty", ai_difficulty))
		victory_mode = String(cfg.get_value("pref", "victory_mode", victory_mode))
		scale_on = bool(cfg.get_value("pref", "scale_on", scale_on))
		enemy_mult = clampf(float(cfg.get_value("pref", "enemy_mult", enemy_mult)), 1.0, 5.0)
		hero_mult = clampf(float(cfg.get_value("pref", "hero_mult", hero_mult)), 1.0, 3.0)
		hero_mult_touched = bool(cfg.get_value("pref", "hero_mult_touched", hero_mult_touched))
		defense_rand_waves = clampi(int(cfg.get_value("pref", "defense_rand_waves", defense_rand_waves)), 1, 999)
		defense_interval = clampf(float(cfg.get_value("pref", "defense_interval", defense_interval)), 1.0, 600.0)


func index_for_id(level_id: String) -> int:
	for i in range(LEVELS.size()):
		if LEVELS[i].id == level_id:
			return i
	return -1

func story_indices() -> Array:
	var out: Array = []
	for level_id in STORY_ORDER:
		out.append(index_for_id(level_id))
	return out

func story_number(index: int) -> int:
	return STORY_ORDER.find(LEVELS[index].id) + 1

func next_index() -> int:
	var order := story_number(current)
	return index_for_id(STORY_ORDER[order]) if order < STORY_ORDER.size() else -1
