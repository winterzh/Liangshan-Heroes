extends Node
## 全局设置（Autoload: Settings）。音频/游戏速度/画面/镜头/显示等偏好，
## 持久化到 user://settings.cfg。须排在 Sfx/Music 之前加载——开机先建好音频总线。

const PATH := "user://settings.cfg"
signal keybinds_changed
const DEFAULT_KEYBINDS := {
	"amove": KEY_A, "stop": KEY_S, "hold": KEY_H, "patrol": KEY_P,
	"stance": KEY_G, "auto": KEY_T,
	"command_0": KEY_Q, "command_1": KEY_W, "command_2": KEY_E, "command_3": KEY_R,
	"item_0": KEY_Z, "item_1": KEY_X, "item_2": KEY_C,
	"item_3": KEY_V, "item_4": KEY_B, "item_5": KEY_N,
	"alert": KEY_SPACE, "select_army": KEY_F2, "subgroup": KEY_TAB,
	"idle_worker": KEY_PERIOD, "demolish": KEY_DELETE,
}

# —— 音频（0..1 线性音量）——
var bgm := 0.8
var sfx := 0.9
var muted := false
# —— 游戏 ——
var game_speed := 1.0       # 战斗节奏倍率：0.5 慢 / 1.0 正常 / 1.5 快
var atmosphere := true      # 氛围后期（暗角/暖色调）
var auto_micro_level := 2   # 英雄托管档位：0 无托管(去掉T/触屏按钮、全部取消) / 1 弱托管(只守附近~15格) / 2 强托管(全图) / 3 全托管(彻底挂机，仅驻守战AI友好模式下可用)
var formation_mode := "loose" # 群体行军：loose 保持相对站位 / box 方阵 / line 横列
var keybinds: Dictionary = DEFAULT_KEYBINDS.duplicate()
# —— 镜头 ——
var edge_scroll := true     # 屏幕边缘滚屏
var cam_speed := 1.0        # 镜头平移速度倍率
var zoom_sens := 1.0        # 缩放灵敏度
# —— 显示 ——
var show_damage := true      # 伤害飘字
var show_healthbars := true  # 血条常显
var show_cooldown := true    # 技能冷却倒计时数字
var show_command_queue := true # 选中单位的当前路径/Shift队列
var show_target_lines := true  # 选中单位攻击目标线
var show_range_rings := true   # 活动单位/建筑的攻击范围圈


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
	c.set_value("game", "formation", formation_mode)
	for action in DEFAULT_KEYBINDS:
		c.set_value("keys", action, int(keybinds.get(action, DEFAULT_KEYBINDS[action])))
	c.set_value("cam", "edge", edge_scroll)
	c.set_value("cam", "speed", cam_speed)
	c.set_value("cam", "zoom", zoom_sens)
	c.set_value("show", "damage", show_damage)
	c.set_value("show", "hpbar", show_healthbars)
	c.set_value("show", "cooldown", show_cooldown)
	c.set_value("show", "command_queue", show_command_queue)
	c.set_value("show", "target_lines", show_target_lines)
	c.set_value("show", "range_rings", show_range_rings)
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
	formation_mode = String(c.get_value("game", "formation", formation_mode))
	if formation_mode not in ["loose", "box", "line"]:
		formation_mode = "loose"
	for action in DEFAULT_KEYBINDS:
		var key := int(c.get_value("keys", action, DEFAULT_KEYBINDS[action]))
		keybinds[action] = key if can_bind_key(key) else DEFAULT_KEYBINDS[action]
	edge_scroll = bool(c.get_value("cam", "edge", edge_scroll))
	cam_speed = float(c.get_value("cam", "speed", cam_speed))
	zoom_sens = float(c.get_value("cam", "zoom", zoom_sens))
	show_damage = bool(c.get_value("show", "damage", show_damage))
	show_healthbars = bool(c.get_value("show", "hpbar", show_healthbars))
	show_cooldown = bool(c.get_value("show", "cooldown", show_cooldown))
	show_command_queue = bool(c.get_value("show", "command_queue", show_command_queue))
	show_target_lines = bool(c.get_value("show", "target_lines", show_target_lines))
	show_range_rings = bool(c.get_value("show", "range_rings", show_range_rings))


func key_for(action: String) -> int:
	return int(keybinds.get(action, DEFAULT_KEYBINDS.get(action, KEY_NONE)))


func key_matches(event: InputEventKey, action: String) -> bool:
	return event.keycode == key_for(action)


func key_label(action: String) -> String:
	return OS.get_keycode_string(key_for(action))


func command_key_labels() -> Array:
	return [key_label("command_0"), key_label("command_1"), key_label("command_2"), key_label("command_3")]


func item_key_labels() -> Array:
	return [key_label("item_0"), key_label("item_1"), key_label("item_2"),
		key_label("item_3"), key_label("item_4"), key_label("item_5")]


func item_slot_for_event(event: InputEventKey) -> int:
	for i in range(6):
		if key_matches(event, "item_%d" % i):
			return i
	return -1


func can_bind_key(key: int) -> bool:
	if key == KEY_NONE or key == KEY_ESCAPE or key in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
		return false
	if (key >= KEY_0 and key <= KEY_9) or (key >= KEY_KP_0 and key <= KEY_KP_9):
		return false   # 数字键固定留给编队
	if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_EQUAL, KEY_MINUS, KEY_KP_ADD, KEY_KP_SUBTRACT]:
		return false   # 镜头移动/缩放保留键
	if key >= KEY_F1 and key <= KEY_F8 and key != KEY_F2:
		return false   # F1/F3-F8 固定留给英雄与镜头位置
	return true


## 绑定到已占用按键时交换两项，保证所有核心命令始终可达。
func rebind_key(action: String, key: int) -> bool:
	if not DEFAULT_KEYBINDS.has(action) or not can_bind_key(key):
		return false
	var old := key_for(action)
	for other in DEFAULT_KEYBINDS:
		if other != action and key_for(other) == key:
			keybinds[other] = old
			break
	keybinds[action] = key
	keybinds_changed.emit()
	return true


func reset_keybinds() -> void:
	keybinds = DEFAULT_KEYBINDS.duplicate()
	keybinds_changed.emit()
