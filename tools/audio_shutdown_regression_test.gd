extends SceneTree
## Product audio lifecycle regression. AUDIO_EXIT_CASE selects one isolated process:
## fast, menu, battle, android, window, sfx, transition.

const CASES := ["fast", "menu", "battle", "android", "window", "sfx", "transition"]

var _case := ""


class NotificationProbe:
	extends Node
	func send_go_back(target: Node) -> void:
		target.call("_notification", NOTIFICATION_WM_GO_BACK_REQUEST)

	func send_close(target: Node) -> void:
		target.call("_notification", NOTIFICATION_WM_CLOSE_REQUEST)


func _initialize() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	_case = OS.get_environment("AUDIO_EXIT_CASE")
	_run.call_deferred()


func _valid_player(player) -> bool:
	return player is AudioStreamPlayer and is_instance_valid(player)


func _music_ready(music) -> bool:
	var calm = music.get("_p_calm")
	var battle = music.get("_p_battle")
	return _valid_player(calm) and _valid_player(battle) \
		and calm.stream != null and battle.stream != null \
		and calm.playing and battle.playing


func _dispatch_result(expected_reason: String, extra := {}) -> void:
	var app = root.get_node_or_null("AppLifecycle")
	var music = root.get_node_or_null("Music")
	var sfx = root.get_node_or_null("Sfx")
	var result := {
		"case": _case,
		"expected_reason": expected_reason,
		"quit_started": app != null and app.quit_started(),
		"actual_reason": app.quit_reason() if app != null else "missing",
		"music_shutdown": music != null and bool(music.get("_shutting_down")),
		"sfx_shutdown": sfx != null and bool(sfx.get("_shutting_down")),
	}
	result.merge(extra, true)
	result["passed"] = bool(result.quit_started) \
		and String(result.actual_reason) == expected_reason \
		and bool(result.music_shutdown) and bool(result.sfx_shutdown) \
		and bool(result.get("precondition", true))
	print("[audio-exit-case] ", JSON.stringify(result))
	if not bool(result.passed):
		push_error("audio exit route failed: " + JSON.stringify(result))


func _run_transition() -> void:
	var music = root.get_node("Music")
	var sfx = root.get_node("Sfx")
	var checks := {}
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	checks["menu_calm"] = music.mood() == "calm"
	checks["music_players_started"] = _music_ready(music)
	current_scene = null
	menu.queue_free()
	await process_frame
	await process_frame

	var campaign = root.get_node("Campaign")
	campaign.current = 5
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle._on_start_battle()
	battle.phase = battle.Phase.FIGHT
	for _frame in range(4):
		await process_frame
	checks["battle_mood"] = music.mood() == "battle"
	checks["battle_music_streams_live"] = _music_ready(music)
	current_scene = null
	battle.queue_free()
	await process_frame
	await process_frame

	menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	checks["return_menu_calm"] = music.mood() == "calm"
	sfx.play("alert", 0.0, 0.0, 0)
	checks["sfx_live"] = (sfx.get("_players") as Array).any(func(player):
		return _valid_player(player) and player.stream != null and player.playing)
	var passed := checks.values().all(func(value): return bool(value))
	print("[audio-transition-result] ", JSON.stringify({"passed": passed, "checks": checks}))
	if not passed:
		push_error("menu/battle audio transition failed: " + JSON.stringify(checks))
	root.get_node("AppLifecycle").request_quit("qa_transition")
	_dispatch_result("qa_transition", {"precondition": passed})


func _run() -> void:
	if _case not in CASES:
		push_error("AUDIO_EXIT_CASE must be one of: " + ", ".join(CASES))
		quit(2)
		return
	var app = root.get_node_or_null("AppLifecycle")
	var music = root.get_node_or_null("Music")
	var sfx = root.get_node_or_null("Sfx")
	if app == null or music == null or sfx == null:
		push_error("required product autoload missing")
		quit(3)
		return
	match _case:
		"fast":
			var thread = music.get("_thr")
			var ready: bool = _music_ready(music) and thread is Thread and thread.is_started()
			app.request_quit("qa_fast")
			app.request_quit("qa_duplicate_must_not_replace")
			var duplicate_rejected: bool = app.quit_reason() == "qa_fast"
			_dispatch_result("qa_fast", {"precondition": ready and duplicate_rejected,
				"background_thread_was_started": ready, "duplicate_rejected": duplicate_rejected})
		"menu":
			var menu = load("res://scenes/menu.tscn").instantiate()
			root.add_child(menu)
			current_scene = menu
			await process_frame
			var ready: bool = music.mood() == "calm" and _music_ready(music)
			var probe := NotificationProbe.new()
			probe.send_go_back(menu)
			probe.free()
			_dispatch_result("menu_back", {"precondition": ready})
		"battle":
			root.get_node("Campaign").current = 5
			var battle = load("res://scenes/main.tscn").instantiate()
			root.add_child(battle)
			current_scene = battle
			await process_frame
			var ready: bool = battle.hud != null and _music_ready(music)
			battle.hud.quit_game.emit()
			_dispatch_result("battle_quit", {"precondition": ready})
		"android":
			var ready: bool = _music_ready(music)
			root.get_node("AndroidUpdater").quit_for_restart()
			_dispatch_result("android_update_restart", {"precondition": ready})
		"window":
			var ready: bool = not auto_accept_quit and _music_ready(music)
			var probe := NotificationProbe.new()
			probe.send_close(app)
			probe.free()
			_dispatch_result("window_close", {"precondition": ready, "auto_accept_quit": auto_accept_quit})
		"sfx":
			sfx.play("alert", 0.0, 0.0, 0)
			var live: bool = (sfx.get("_players") as Array).any(func(player):
				return _valid_player(player) and player.stream != null and player.playing)
			app.request_quit("qa_sfx_live")
			_dispatch_result("qa_sfx_live", {"precondition": live, "sfx_was_live": live})
		"transition":
			await _run_transition()
