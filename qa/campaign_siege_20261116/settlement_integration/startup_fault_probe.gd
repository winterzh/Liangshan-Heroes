extends SceneTree
## Controlled startup fault in an isolated Windows profile.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var area := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not area.contains("/zhu-fault-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(area + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	var cfg = load("res://scripts/run_campaign_cfg_transaction.gd").new()
	var blocker: String = cfg.directory.path_join("qa_blocker")
	DirAccess.make_dir_recursive_absolute(blocker.get_base_dir())
	var file := FileAccess.open(blocker,FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string("isolated startup recovery fixture")
	file.close()
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 65000
	while flow.phase == flow.Phase.RESTORING and Time.get_ticks_msec() < deadline:
		await process_frame
	var fault: bool = flow.phase == flow.Phase.ERROR and flow.last_result.get("startup_pending",false)
	var expected := {"zh_CN":"战役进度暂时无法确认","zh_TW":"暫時無法確認戰役進度",
		"en":"Campaign progress could not be verified","ja":"戦役の進行状況を確認できませんでした"}
	var status: Label = flow._overlay.find_child("Status",true,false) if fault else null
	var localized := {}
	for locale in expected:
		root.get_node("Localize").set_language(locale,false)
		localized[locale] = status != null and expected[locale] in status.text
	var quit_button: Button = flow._overlay.find_child("LeaveCampaignStartup",true,false) if fault else null
	if quit_button != null and quit_button.is_visible_in_tree(): quit_button.pressed.emit()
	var leaving: bool = root.get_node("AppLifecycle").quit_started()
	var intact: bool = FileAccess.get_file_as_string(blocker) == "isolated startup recovery fixture"
	var passed: bool = fault and localized.values().all(func(value): return value) and leaving and intact
	print("ZHU_INTEGRATION_RESULT ",JSON.stringify({"stage":"fault","pid":OS.get_process_id(),
		"passed":passed,"code":flow.last_result.get("code",""),"languages":localized,"quit_started":leaving,"fault_preserved":intact}))
	if not leaving: quit.call_deferred(1)
