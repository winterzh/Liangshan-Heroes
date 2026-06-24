extends Node
## 全屏支持（Autoload "Screen"，全局常驻）：F11 或 Alt+Enter 在「窗口 ⇄ 全屏」之间切换。
## 任何场景（主菜单/战斗/结算）都可用；记住上次的选择，下次启动沿用。

const SAVE_PATH := "user://screen.cfg"


var orient := "auto"   # 手机横屏方向：auto 重力感应(双横屏自动转) / normal 正向 / flip 反向


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时也能切全屏
	var cfg := ConfigFile.new()
	var loaded := cfg.load(SAVE_PATH) == OK
	# 移动端：恢复并应用上次的横屏方向偏好（窗口模式由系统接管）
	if OS.has_feature("mobile"):
		orient = String(cfg.get_value("display", "orient", "auto")) if loaded else "auto"
		_apply_orient()
		return
	if OS.has_feature("web"):
		return
	# 桌面：恢复上次的全屏偏好
	if loaded and bool(cfg.get_value("display", "fullscreen", false)):
		set_fullscreen(true)


## 设置横屏方向并持久化（移动端）。auto=重力感应双横屏 / normal=正向 / flip=反向。
func set_orientation(o: String) -> void:
	orient = o
	_apply_orient()
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # 先读，保留 fullscreen 等其它键
	cfg.set_value("display", "orient", o)
	cfg.save(SAVE_PATH)


func _apply_orient() -> void:
	var d := DisplayServer.SCREEN_SENSOR_LANDSCAPE
	match orient:
		"normal": d = DisplayServer.SCREEN_LANDSCAPE
		"flip": d = DisplayServer.SCREEN_REVERSE_LANDSCAPE
		_: d = DisplayServer.SCREEN_SENSOR_LANDSCAPE
	DisplayServer.screen_set_orientation(d)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())


func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", on)
	cfg.save(SAVE_PATH)
