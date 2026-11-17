extends SceneTree
## One rendered random-defense entry with a completed menu scan.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	if change_scene_to_file("res://scenes/menu.tscn") != OK:
		_finish({"passed":false,"error":"menu"})
		return
	await scene_changed
	var menu := current_scene
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 35000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	var trusted: Dictionary = flow.take_startup_entry_identity()
	if not flow.can_launch() or not trusted.get("ok",false) or trusted.get("source_mode",true):
		_finish({"passed":false,"error":"startup identity"})
		return
	var defense := _find_button(menu,"驻守战")
	if defense == null:
		_finish({"passed":false,"error":"defense selection"})
		return
	defense.pressed.emit()
	await RenderingServer.frame_post_draw
	var random := _find_button(menu,"随机波次 · 开战")
	if random == null:
		_finish({"passed":false,"error":"random selection"})
		return
	var edited := 0
	for node in menu.find_children("*","SpinBox",true,false):
		var box := node as SpinBox
		if not box.is_visible_in_tree(): continue
		if box.max_value == 999.0:
			box.value = 17
			edited += 1
		elif box.max_value == 600.0:
			box.value = 41
			edited += 1
	if edited != 2:
		_finish({"passed":false,"error":"random preferences","edited":edited})
		return
	menu._begin_battle_scan(true)
	while menu._entry_scan.runtime_identity_scan_pending():
		await process_frame
	await RenderingServer.frame_post_draw
	var clicked := Time.get_ticks_usec()
	random.pressed.emit()
	var loading_shown := menu.get_node_or_null("BattleLoading") != null
	await RenderingServer.frame_post_draw
	var redraw := Time.get_ticks_usec() - clicked
	deadline = Time.get_ticks_msec() + 20000
	while (current_scene == null or (is_instance_valid(menu) and current_scene == menu)) and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
	var b = current_scene
	var first_battle_us := Time.get_ticks_usec() - clicked
	var active: bool = is_instance_valid(b) and b.scene_file_path == "res://scenes/main.tscn" \
		and b.gameplay_rng_fault().is_empty() and b._gameplay_content_identity == trusted
	var campaign = root.get_node("Campaign")
	var settings := ConfigFile.new()
	var prefs_ok := settings.load("user://campaign.cfg") == OK and int(settings.get_value("pref","defense_rand_waves",0)) == 17 \
		and is_equal_approx(float(settings.get_value("pref","defense_interval",0)),41.0)
	var mode_ok: bool = campaign.defense_random and campaign.defense_waves == 17 and is_equal_approx(campaign.defense_interval,41.0)
	_finish({"passed":active and prefs_ok and mode_ok and loading_shown,"loading_shown":loading_shown,"battle_ready":active,"click_to_loading_us":redraw,
		"click_to_battle_us":first_battle_us,"pref_file_persisted":prefs_ok,"random_mode_configured":mode_ok,
		"candidate_content_sha256":trusted.source_sha256,"engine_sha256":trusted.engine_binary_sha256})

func _find_button(scope: Node, text: String) -> Button:
	for candidate in scope.find_children("*","Button",true,false):
		var button := candidate as Button
		if button.is_visible_in_tree() and not button.disabled and button.text.contains(text): return button
	return null

func _finish(result: Dictionary) -> void:
	print("RANDOM_DEFENSE_PACK_RESULT ",JSON.stringify(result))
	if result.passed:
		root.get_node("AppLifecycle").request_quit("random_prefs_pack_probe")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
