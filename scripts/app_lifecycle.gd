extends Node
## 全局退出协调器：所有正常退出都先释放程序合成音频，再等待三个主循环帧。
## _exit_tree 仍由 Music/Sfx 自己兜底，用于系统强制终止等无法等待的路径。

const AUDIO_RELEASE_FRAMES := 3

var _quit_started := false
var _quit_reason := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 桌面窗口关闭也必须经过 request_quit，不能让 SceneTree 自动抢先退出。
	get_tree().auto_accept_quit = false


func request_quit(reason := "app") -> void:
	if _quit_started:
		return
	_quit_started = true
	_quit_reason = reason
	var steam := get_node_or_null("/root/SteamService")
	if steam != null:
		steam.flush()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null and sfx.has_method("shutdown"):
		sfx.shutdown()
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("shutdown"):
		music.shutdown()
	for _frame in range(AUDIO_RELEASE_FRAMES):
		await get_tree().process_frame
	get_tree().quit()


func quit_started() -> bool:
	return _quit_started


func quit_reason() -> String:
	return _quit_reason


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit("window_close")
