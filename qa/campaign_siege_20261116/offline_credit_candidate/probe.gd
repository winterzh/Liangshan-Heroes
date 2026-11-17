extends "res://tools/zhujiazhuang_rts_test.gd"
## Windows offscreen fixture using a fake SDK and one private local profile.

const OWNER := "55555"
const HANDOFF := "user://zhu_credit_qa_handoff.json"
var stage := ""
var facts := {}
var steam: Node
var flow: Node
var campaign: Node
var sdk: RefCounted

func _run() -> void:
	stage = OS.get_environment("ZHU_CREDIT_STAGE")
	var appdata := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not appdata.contains("/zhu-credit-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(appdata + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	steam = root.get_node("SteamService")
	flow = root.get_node("ContinueFlow")
	campaign = root.get_node("Campaign")
	root.get_node("Settings").edge_scroll = false
	if stage == "save":
		var cfg := ConfigFile.new()
		cfg.set_value("progress","schema",1)
		cfg.set_value("progress","owner",OWNER)
		cfg.set_value("progress","unlocked",3)
		cfg.set_value("progress","records",{})
		check(cfg.save("user://campaign.cfg") == OK,"fixture initializes fresh owner profile")
		campaign._load()
	if stage in ["save","settle"]:
		_attach_sdk(true)
		steam._read_initial_state()
	var deadline := Time.get_ticks_msec() + 55000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.last_result.get("startup_checked",false) and flow.can_launch(),"normal startup admits the profile")
	if not failures.is_empty():
		facts["startup_result"] = flow.last_result
		_finish()
		return
	facts["startup_recovered"] = flow.last_result.get("progress_recovered",-1)
	flow.set_script(load("res://qa/campaign_siege_20261116/player_continue/platform_entry.gd"))
	if stage == "save":
		await _save_credit()
	elif stage == "settle":
		await _settle_credit()
	elif stage == "offline":
		await _offline_then_attach()
	else:
		check(false,"known stage")
		_finish()

func _attach_sdk(ready: bool) -> void:
	sdk = load("res://tools/steam_fake_api.gd").new()
	sdk.owner = int(OWNER)
	sdk.read_ok = ready
	steam.set_process(false)
	steam.native = sdk
	steam.account = OWNER
	steam.available = true
	steam._stats_reader = sdk

func _menu_button(owner: Node, name: String) -> bool:
	var button := owner.find_child(name,true,false) as Button
	var ready := button != null and button.is_visible_in_tree() and not button.disabled
	check(ready,"visible " + name)
	if ready: button.pressed.emit()
	return ready

func _mount_menu():
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	return menu

func _save_credit() -> void:
	var b = await _start()
	b._steam_run_id = steam._begin_persistent_run(b._official_context)
	check(b._steam_run_id > 0 and steam._publisher_enabled,"fake SDK starts an official creditable run")
	if not failures.is_empty():
		_finish()
		return
	await physics_frame
	await process_frame
	b._open_pause()
	flow.operation_finished.connect(_checked_save,CONNECT_ONE_SHOT)
	if not _menu_button(b.hud,"SaveAndExit"): _finish()

func _checked_save(result: Dictionary) -> void:
	facts["save"] = result.get("code","")
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(result.ok and slot.ok and slot.document.binding.kind == "steam","pause menu writes a Steam-bound campaign slot")
	if slot.ok:
		var file := FileAccess.open(HANDOFF,FileAccess.WRITE)
		check(file != null,"hold the original slot digest for restart")
		if file != null:
			file.store_string(JSON.stringify({"slot_sha":slot.file_sha256}))
			file.close()
	_finish()

func _settle_credit() -> void:
	var menu = await _mount_menu()
	flow.operation_finished.connect(_restored_credit,CONNECT_ONE_SHOT)
	if not _menu_button(menu,"ContinueBattle"): _finish()

func _restored_credit(result: Dictionary) -> void:
	facts["restore"] = result.get("code","")
	check(result.ok and result.get("steam_credit",false),"new process continues the Steam-bound player slot")
	if not failures.is_empty():
		_finish()
		return
	var b = current_scene
	check(b._steam_run_id == steam._active_run and b._steam_run_id > 0,"restored world is bound to the installed run handle")
	steam._publisher_enabled = false # Keep the earned result on disk until the next process connects.
	for event in ["zhu_hu_captured","zhu_gate_opened","zhu_seven_safe"]:
		b.mission.mark(event,"")
	flow.operation_finished.connect(_settled_credit,CONNECT_ONE_SHOT)
	b.win("Controlled campaign credit fixture.")

func _settled_credit(result: Dictionary) -> void:
	facts["terminal"] = result.get("code","")
	var record: Dictionary = campaign.level_record("level3")
	var ledger: Dictionary = steam._local_runs.capture()
	check(result.ok and result.get("terminal_completed",false) and record.story_complete and campaign.unlocked == 4,
		"settlement completes local progression and unlocks the next chapter")
	check(ledger.ok and ledger.record.stats.TOTAL_WINS == 1 and ledger.record.unlocked.get("ACH_STORY_LEVEL_3",false),
		"durable ledger has one win and the chapter achievement")
	check(sdk.stat_writes == 0 and sdk.achievement_writes == 0,"fixture leaves Steam dispatch pending")
	facts["local_wins"] = ledger.get("record",{}).get("stats",{}).get("TOTAL_WINS",-1)
	_finish()

func _offline_then_attach() -> void:
	check(not steam.available and not steam._publisher_enabled,"historical credit admits offline play without a publisher")
	check(facts.startup_recovered == 0 and campaign.level_record("level3").story_complete and campaign.unlocked == 4,
		"offline restart retains the existing local victory")
	var progress_before := FileAccess.get_sha256("user://campaign.cfg")
	_attach_sdk(false)
	steam._read_initial_state()
	check(not steam.stats_ready and not steam._publisher_enabled and sdk.stat_writes == 0,
		"unready same-account SDK cannot publish")
	sdk.read_ok = true
	steam._read_initial_state()
	check(steam.stats_ready and steam._publisher_enabled and sdk.stats.TOTAL_WINS == 1 \
			and sdk.achievements.get("ACH_STORY_LEVEL_3",false),"ready same account sends the earned absolute totals")
	var calls: Array = [sdk.stat_writes,sdk.achievement_writes]
	steam.refresh_campaign_targets()
	check([sdk.stat_writes,sdk.achievement_writes] == calls and sdk.stats.TOTAL_WINS == 1,
		"the next refresh does not increment or resend the award")
	check(FileAccess.get_sha256("user://campaign.cfg") == progress_before,"deferred publishing leaves the campaign progress bytes intact")
	facts["sdk_wins"] = sdk.stats.TOTAL_WINS
	facts["sdk_awards"] = sdk.achievement_writes
	var menu = await _mount_menu()
	flow.operation_finished.connect(_refused_old_slot,CONNECT_ONE_SHOT)
	if not _menu_button(menu,"ContinueBattle"): _finish()

func _refused_old_slot(result: Dictionary) -> void:
	facts["old_slot"] = result.get("code","")
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	check(not result.ok and "TERMINAL" in facts.old_slot and slot.ok and slot.file_sha256 == previous.slot_sha,
		"the old terminal slot is refused and its bytes are preserved")
	_menu_button(flow._overlay,"CloseError")
	_finish()

func _finish() -> void:
	print("ZHU_CREDIT_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		if stage != "save": root.get_node("AppLifecycle").request_quit("zhu_credit_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
