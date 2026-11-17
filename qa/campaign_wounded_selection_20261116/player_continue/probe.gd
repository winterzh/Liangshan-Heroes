extends "res://qa/campaign_wounded_selection_20261116/menu_resume/probe.gd"
## Runs the established assault through player admission and settlement.

func _run() -> void:
	stage = OS.get_environment("DAMING_MENU_STAGE")
	var profile := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/daming-player-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.game_speed = 1.0
	flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.last_result.get("startup_checked",false) and flow.can_launch(),"current startup completes")
	if not failures.is_empty():
		facts["startup"] = flow.last_result
		_finish()
		return
	facts["identity"] = flow._startup_identity.get("content_version","")
	flow.set_script(load("res://qa/campaign_siege_20261116/player_continue/platform_entry.gd"))
	check(not flow._private_qa_enabled(),"player admission is active in the isolated profile")
	route = "assault"
	facts["route"] = route
	build_cells = DAMING_BUILD_CELLS.duplicate()
	match stage:
		"save": await _save()
		"resume": await _resume()
		"reject": await _reject_old_slot()
		_:
			check(false,"known stage")
			_finish()

func _reject_old_slot() -> void:
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	flow.operation_finished.connect(_rejected,CONNECT_ONE_SHOT)
	if not _clicked(menu,"ContinueBattle"):
		_finish()

func _rejected(result: Dictionary) -> void:
	facts["terminal_code"] = result.get("code","")
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	var campaign = root.get_node("Campaign")
	check(not result.ok and facts.terminal_code == "LOCAL_RUN_TERMINAL","player menu rejects the settled slot")
	check(slot.get("ok",false) and slot.file_sha256 == previous.sha and campaign.level_record("level8").cleared,
		"settled campaign progress and original slot bytes are preserved")
	facts["progress_sha"] = FileAccess.get_sha256("user://campaign.cfg")
	_clicked(flow._overlay,"CloseError")
	_finish()

func _finish() -> void:
	Engine.time_scale = 1
	if stage == "resume" and failures.is_empty():
		var deadline := Time.get_ticks_msec() + 60000
		while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
			await process_frame
		var record: Dictionary = root.get_node("Campaign").level_record("level8")
		check(flow.last_result.get("terminal_completed",false) and record.cleared,
			"natural victory is committed by the campaign settlement coordinator")
		facts["progress_sha"] = FileAccess.get_sha256("user://campaign.cfg")
	print("DAMING_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		if stage != "save":
			root.get_node("AppLifecycle").request_quit("daming_player_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
