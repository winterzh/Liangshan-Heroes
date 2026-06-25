extends Node
## 全局设置（Autoload: Settings）。音频/游戏速度/画面/镜头/显示等偏好，
## 持久化到 user://settings.cfg。须排在 Sfx/Music 之前加载——开机先建好音频总线。

const PATH := "user://settings.cfg"

# —— 音频（0..1 线性音量）——
var bgm := 0.8
var sfx := 0.9
var muted := false
# —— 游戏 ——
var game_speed := 1.0       # 战斗节奏倍率：0.5 慢 / 1.0 正常 / 1.5 快
var atmosphere := true      # 氛围后期（暗角/暖色调）
var auto_micro_level := 2   # 英雄托管档位：0 无托管(去掉T/触屏按钮、全部取消) / 1 弱托管(只守附近~15格) / 2 强托管(全图) / 3 全托管(彻底挂机，仅驻守战AI友好模式下可用)
# —— 镜头 ——
var edge_scroll := true     # 屏幕边缘滚屏
var cam_speed := 1.0        # 镜头平移速度倍率
var zoom_sens := 1.0        # 缩放灵敏度
# —— 显示 ——
var show_damage := true      # 伤害飘字
var show_healthbars := true  # 血条常显
var show_cooldown := true    # 技能冷却倒计时数字


func _ready() -> void:
	_load()
	var am := OS.get_environment("AUTO_MICRO")   # 测试钩子：强制托管档位（0/1/2/3）
	if am != "":
		auto_micro_level = clampi(int(am), 0, 3)
	apply_audio()


## 应用音量：音乐/音效各自播放器的音量乘子 + Master 静音。
## 不再运行时建子总线（部分安卓音频驱动在战斗音乐+密集音效同时走自建总线时会崩溃）。
func apply_audio() -> void:
	Music.set_user_vol(bgm)
	Sfx.user_vol = sfx
	AudioServer.set_bus_mute(0, muted)   # Master 静音 = 全静音


func set_bgm(v: float) -> void:
	bgm = v
	apply_audio()


func set_sfx(v: float) -> void:
	sfx = v
	apply_audio()


func set_muted(on: bool) -> void:
	muted = on
	apply_audio()


func save() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "bgm", bgm)
	c.set_value("audio", "sfx", sfx)
	c.set_value("audio", "muted", muted)
	c.set_value("game", "speed", game_speed)
	c.set_value("game", "atmosphere", atmosphere)
	c.set_value("game", "auto_micro", auto_micro_level)
	c.set_value("cam", "edge", edge_scroll)
	c.set_value("cam", "speed", cam_speed)
	c.set_value("cam", "zoom", zoom_sens)
	c.set_value("show", "damage", show_damage)
	c.set_value("show", "hpbar", show_healthbars)
	c.set_value("show", "cooldown", show_cooldown)
	c.save(PATH)


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	bgm = float(c.get_value("audio", "bgm", bgm))
	sfx = float(c.get_value("audio", "sfx", sfx))
	muted = bool(c.get_value("audio", "muted", muted))
	game_speed = float(c.get_value("game", "speed", game_speed))
	if game_speed < 1.0:
		game_speed = 1.0   # 旧档「慢=0.8」迁移到新档位最低速 1.0（新：慢1.0/中1.2/快1.5）
	atmosphere = bool(c.get_value("game", "atmosphere", atmosphere))
	auto_micro_level = int(c.get_value("game", "auto_micro", auto_micro_level))
	edge_scroll = bool(c.get_value("cam", "edge", edge_scroll))
	cam_speed = float(c.get_value("cam", "speed", cam_speed))
	zoom_sens = float(c.get_value("cam", "zoom", zoom_sens))
	show_damage = bool(c.get_value("show", "damage", show_damage))
	show_healthbars = bool(c.get_value("show", "hpbar", show_healthbars))
	show_cooldown = bool(c.get_value("show", "cooldown", show_cooldown))
