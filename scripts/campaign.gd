extends Node
## 战役进度管理（Autoload "Campaign"）：关卡注册表、当前关、解锁进度、存档。

const VERSION := "1.8"   # 完整包版本；三端内容更新状态由 AndroidUpdater 统一显示

const LEVELS := [
	{"id": "level1", "title": "智取生辰纲", "sub": "黄泥冈·七星聚义", "script": "res://scripts/levels/level1_huangnigang.gd"},
	{"id": "level2", "title": "江州劫法场", "sub": "浔阳江畔·限时劫法场", "script": "res://scripts/levels/level2_jiangzhou.gd"},
	{"id": "level3", "title": "三打祝家庄", "sub": "独龙冈·盘陀路", "script": "res://scripts/levels/level3_zhujiazhuang.gd"},
	{"id": "level4", "title": "大破连环马", "sub": "钩镰枪法·专砍马腿", "script": "res://scripts/levels/level4_lianhuanma.gd"},
	{"id": "level5", "title": "三败高太尉", "sub": "三败高太尉·终战", "script": "res://scripts/levels/level5_liangshan.gd"},
	{"id": "level6", "title": "大闹野猪林", "sub": "花和尚禅杖·救林冲", "script": "res://scripts/levels/level6_yezhulin.gd"},
	{"id": "level7", "title": "醉打蒋门神", "sub": "快活林·无三不过望", "script": "res://scripts/levels/level7_kuaihuolin.gd"},
	{"id": "level8", "title": "智取大名府", "sub": "元宵灯市·开门劫牢", "script": "res://scripts/levels/level8_dongchangfu.gd"},
]

const STORY_ORDER := ["level6", "level1", "level7", "level2", "level3", "level4", "level8", "level5"]

const SAVE_PATH := "user://campaign.cfg"
const SAVE_SCHEMA := 2

const SKIRMISH_SCRIPT := "res://scripts/levels/skirmish.gd"
const SKIRMISH_AI_SCRIPT := "res://scripts/levels/skirmish_ai.gd"
const CUSTOM_DEFENSE_SCRIPT := "res://scripts/levels/custom_defense.gd"
const SCENARIO_SCRIPT := "res://scripts/levels/scenario.gd"
const ARENA_SCRIPT := "res://scripts/levels/arena.gd"

var current := 0
var unlocked := 1
var records: Dictionary = {} # stable level id -> best base clear / same-run original-story result
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


func on_level_won(result: Dictionary = {}) -> Dictionary:
	unlocked = maxi(unlocked, current + 2)
	var level_id := String(LEVELS[current].id) if current >= 0 and current < LEVELS.size() else ""
	if result.is_empty():
		result = {"core_cleared":true,"story_complete":false,"story_done":0,"story_total":0,
			"done_ids":[],"contract_version":1}
	return record_level_result(level_id, result)


func record_level_result(level_id: String, result: Dictionary) -> Dictionary:
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
	_save()


func _save() -> void:
	if OS.get_environment("CAMPAIGN_QA") == "1":
		return
	var cfg := ConfigFile.new()
	# Preserve unknown sections/keys from prior or newer builds instead of
	# reconstructing campaign.cfg and silently discarding them.
	cfg.load(SAVE_PATH)
	cfg.set_value("progress", "schema", SAVE_SCHEMA)
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "records", records)
	cfg.set_value("pref", "ai_difficulty", ai_difficulty)
	cfg.set_value("pref", "victory_mode", victory_mode)
	cfg.set_value("pref", "scale_on", scale_on)
	cfg.set_value("pref", "enemy_mult", enemy_mult)
	cfg.set_value("pref", "hero_mult", hero_mult)
	cfg.set_value("pref", "hero_mult_touched", hero_mult_touched)
	cfg.set_value("pref", "defense_rand_waves", defense_rand_waves)
	cfg.set_value("pref", "defense_interval", defense_interval)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
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
