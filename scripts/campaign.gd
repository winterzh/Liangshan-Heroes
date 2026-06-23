extends Node
## 战役进度管理（Autoload "Campaign"）：关卡注册表、当前关、解锁进度、存档。

const LEVELS := [
	{"id": "level1", "title": "智取生辰纲", "sub": "黄泥冈·七星聚义", "script": "res://scripts/levels/level1_huangnigang.gd"},
	{"id": "level2", "title": "江州劫法场", "sub": "浔阳江畔·限时劫法场", "script": "res://scripts/levels/level2_jiangzhou.gd"},
	{"id": "level3", "title": "三打祝家庄", "sub": "独龙冈·盘陀路", "script": "res://scripts/levels/level3_zhujiazhuang.gd"},
	{"id": "level4", "title": "大破连环马", "sub": "钩镰枪法·专砍马腿", "script": "res://scripts/levels/level4_lianhuanma.gd"},
	{"id": "level5", "title": "梁山泊保卫战", "sub": "三败高太尉·终战", "script": "res://scripts/levels/level5_liangshan.gd"},
	{"id": "level6", "title": "大闹野猪林", "sub": "花和尚禅杖·救林冲", "script": "res://scripts/levels/level6_yezhulin.gd"},
	{"id": "level7", "title": "醉打蒋门神", "sub": "快活林·无三不过望", "script": "res://scripts/levels/level7_kuaihuolin.gd"},
	{"id": "level8", "title": "东昌府·飞石", "sub": "没羽箭张清·水擒招安", "script": "res://scripts/levels/level8_dongchangfu.gd"},
]

const SAVE_PATH := "user://campaign.cfg"

const SKIRMISH_SCRIPT := "res://scripts/levels/skirmish.gd"
const SKIRMISH_AI_SCRIPT := "res://scripts/levels/skirmish_ai.gd"
const CUSTOM_DEFENSE_SCRIPT := "res://scripts/levels/custom_defense.gd"
const SCENARIO_SCRIPT := "res://scripts/levels/scenario.gd"

var current := 0
var unlocked := 1
var skirmish := false       # 启动自由「遭遇战」模式而非战役关卡
var skirmish_ai := false    # 启动「AI 对战」1v1 模式
var custom_defense := false # 启动「自定义据守」模式（用 custom_config）
var custom_config := {}     # 自定义据守的配置（编辑器产出 / 存档读入）
var scenario := false       # 启动「数据驱动自定义关卡」（用 scenario_data，见 scenario.gd）
var scenario_data := {}     # 自定义关卡的 JSON 字典（编辑器试玩 / 分享码 / SCENARIO 环境变量）
var ai_difficulty := "normal"   # AI 对战难度：easy / normal / hard
var victory_mode := "conquest"  # 1v1 胜利条件：conquest 征服 / regicide 斩首 / koth 占山为王
var defense_waves := 30         # 驻守战波数：20 速战 / 30 经典 / 60 史诗
var defense_hero_cap := 4       # 驻守战英雄上限（60 关放宽到 6 员）
var ai_friendly := false        # 驻守战「AI友好模式」：敌方小兵×3(英雄不×3) + 全员托管时自动镜头巡战场


func _ready() -> void:
	_load()
	if OS.get_environment("SKIRMISH") == "1":
		skirmish = true
	if OS.get_environment("SKIRMISH_AI") == "1":
		skirmish_ai = true
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
	if OS.get_environment("AI_FRIENDLY") == "1":
		ai_friendly = true
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
	if skirmish_ai and ResourceLoader.exists(SKIRMISH_AI_SCRIPT):
		return load(SKIRMISH_AI_SCRIPT).new()
	if skirmish and ResourceLoader.exists(SKIRMISH_SCRIPT):
		return load(SKIRMISH_SCRIPT).new()
	var path: String = LEVELS[current]["script"]
	if not ResourceLoader.exists(path):
		path = "res://scripts/levels/level5_liangshan.gd"
	return load(path).new()


func has_next() -> bool:
	return current + 1 < LEVELS.size() and implemented(current + 1)


func on_level_won() -> void:
	unlocked = maxi(unlocked, current + 2)
	_save()


func save_prefs() -> void:
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("pref", "ai_difficulty", ai_difficulty)
	cfg.set_value("pref", "victory_mode", victory_mode)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlocked = maxi(1, int(cfg.get_value("progress", "unlocked", 1)))
		ai_difficulty = String(cfg.get_value("pref", "ai_difficulty", ai_difficulty))
		victory_mode = String(cfg.get_value("pref", "victory_mode", victory_mode))
