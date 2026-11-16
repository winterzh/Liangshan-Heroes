extends SceneTree

const Menu = "res://scenes/menu.tscn"
const Identity = "res://scripts/run_content_identity.gd"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var paths := OS.get_cmdline_user_args()
	if not paths.is_empty():
		var probe: RefCounted = load(Identity).new()
		var started := Time.get_ticks_usec()
		var sha: String = probe._hash_scan_file(paths[0])
		var elapsed := (Time.get_ticks_usec() - started) / 1000.0
		if sha != paths[1]:
			_fail("chunked hash did not match the published file")
			return
		print("ENTRY_ASYNC_PACKAGE_HASH " + JSON.stringify({"sha256": sha, "elapsed_ms": elapsed}))
	change_scene_to_file(Menu)
	await scene_changed
	await RenderingServer.frame_post_draw
	var menu := current_scene
	var arena: Button
	for candidate in menu.find_children("*", "Button", true, false):
		if "竞技场" in (candidate as Button).text:
			arena = candidate
			break
	if arena == null:
		_fail("arena button missing")
		return
	var old_fps := Engine.max_fps
	var click := Time.get_ticks_usec()
	arena.pressed.emit()
	await RenderingServer.frame_post_draw
	var provider: RefCounted = menu._entry_scan
	if provider == null or not provider.runtime_identity_scan_pending() or menu.get_node_or_null("BattleLoading") == null:
		_fail("no loading frame while arena scan was active")
		return
	print("ENTRY_ASYNC_ARENA_LOADING " + JSON.stringify({"feedback_ms": (Time.get_ticks_usec() - click) / 1000.0}))
	menu.tree_exited.connect(_exited.bind(provider, old_fps), CONNECT_ONE_SHOT)
	root.get_node("AppLifecycle").request_quit("entry_cancel_probe")

func _exited(provider: RefCounted, old_fps: int) -> void:
	if provider.runtime_identity_scan_pending() or Engine.max_fps != old_fps:
		_fail("scan or frame limit survived menu exit")
		return
	print("ENTRY_ASYNC_ARENA_QUIT_OK")

func _fail(message: String) -> void:
	printerr("ENTRY_ASYNC_ERROR " + message)
	quit(1)
