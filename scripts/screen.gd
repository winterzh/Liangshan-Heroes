extends Node
## 全屏支持（Autoload "Screen"，全局常驻）：F11 或 Alt+Enter 在「窗口 ⇄ 全屏」之间切换。
## 任何场景（主菜单/战斗/结算）都可用；记住上次的选择，下次启动沿用。

const SAVE_PATH := "user://screen.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时也能切全屏
	# 移动端/网页端窗口模式由系统接管，不在此处理
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return
	# 恢复上次的全屏偏好
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK and bool(cfg.get_value("display", "fullscreen", false)):
		set_fullscreen(true)


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
