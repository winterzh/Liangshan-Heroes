extends RefCounted
## Shared player-menu and settlement checks for the three short chapters.

static func is_isolated() -> bool:
	var profile := OS.get_environment("APPDATA").replace("\\","/")
	return OS.get_environment("STEAM_DISABLED") == "1" and profile.contains("/short-player-") \
		and OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/")

static func prepare(probe) -> bool:
	AudioServer.set_bus_mute(0,true)
	var settings = probe.root.get_node("Settings")
	settings.edge_scroll = false
	settings.game_speed = 1.0
	var deadline := Time.get_ticks_msec() + 60000
	while probe.flow.busy() and probe.flow.phase != probe.flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await probe.process_frame
	probe.check(probe.flow.last_result.get("startup_checked",false) and probe.flow.can_launch(),"current startup completes")
	if not probe.failures.is_empty():
		probe.facts["startup"] = probe.flow.last_result
		return false
	probe.facts["identity"] = probe.flow._startup_identity.get("content_version","")
	probe.flow.set_script(load("res://qa/campaign_siege_20261116/player_continue/platform_entry.gd"))
	probe.check(not probe.flow._private_qa_enabled(),"player admission is active in the isolated profile")
	return probe.failures.is_empty()

static func reject_settled(probe, chapter: String, handoff: String, expected_goals: int) -> void:
	var menu = load("res://scenes/menu.tscn").instantiate()
	probe.root.add_child(menu)
	probe.current_scene = menu
	await probe.process_frame
	var button := menu.find_child("ContinueBattle",true,false) as Button
	var ready := button != null and button.is_visible_in_tree() and not button.disabled
	probe.check(ready,"visible ContinueBattle button")
	if not ready:
		probe._finish()
		return
	probe.flow.operation_finished.connect(_on_rejected.bind(probe,chapter,handoff,expected_goals),CONNECT_ONE_SHOT)
	button.pressed.emit()

static func _on_rejected(result: Dictionary, probe, chapter: String, handoff: String, expected_goals: int) -> void:
	probe.facts["terminal_code"] = result.get("code","")
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(handoff))
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	var record: Dictionary = probe.root.get_node("Campaign").level_record(chapter)
	probe.check(not result.ok and probe.facts.terminal_code == "LOCAL_RUN_TERMINAL","player menu rejects the settled slot")
	probe.check(slot.get("ok",false) and slot.file_sha256 == previous.sha and _matches(record,expected_goals),
		"settled campaign progress and original slot bytes are preserved")
	probe.facts["progress_sha"] = FileAccess.get_sha256("user://campaign.cfg")
	var close := probe.flow._overlay.find_child("CloseError",true,false) as Button
	var ready := close != null and close.is_visible_in_tree() and not close.disabled
	probe.check(ready,"visible CloseError button")
	if ready: close.pressed.emit()
	probe._finish()

static func _matches(record: Dictionary, expected_goals: int) -> bool:
	return record.cleared and record.best_done == expected_goals and (expected_goals == 0 or record.story_complete)

static func finish(probe, chapter: String, expected_goals: int) -> void:
	Engine.time_scale = 1
	if probe.stage == "resume" and probe.failures.is_empty():
		var deadline := Time.get_ticks_msec() + 60000
		while probe.flow.busy() and probe.flow.phase != probe.flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
			await probe.process_frame
		var record: Dictionary = probe.root.get_node("Campaign").level_record(chapter)
		probe.facts["campaign_record"] = record
		probe.check(probe.flow.last_result.get("terminal_completed",false) and _matches(record,expected_goals),
			"natural victory and the route's story count are committed by the settlement coordinator")
		probe.facts["progress_sha"] = FileAccess.get_sha256("user://campaign.cfg")
	print("SHORT_PLAYER_RESULT ",JSON.stringify({"stage":probe.stage,"chapter":chapter,"pid":OS.get_process_id(),
		"checks":probe.checks,"failures":probe.failures,"facts":probe.facts}))
	if probe.failures.is_empty():
		if probe.stage != "save":
			probe.root.get_node("AppLifecycle").request_quit("short_campaign_player_fixture")
	else:
		probe.root.get_node("Sfx").shutdown()
		probe.root.get_node("Music").shutdown()
		probe.quit.call_deferred(1)
