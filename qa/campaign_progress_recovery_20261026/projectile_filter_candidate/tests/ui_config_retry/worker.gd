extends "base.gd"
## B1 only: actual settings save/retry, then independent settings/journal readback.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	mode = OS.get_environment("UCR_MODE")
	output = OS.get_environment("UCR_OUTPUT")
	flow = get_node("/root/ContinueFlow")
	run.call_deferred()

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check("strict isolated B1 source scope",mode in MODES and profile_valid()): finish("scope_refused"); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("actual installed identity and engine",trusted.get("ok",false) and trusted.get("source_mode",false) and trusted.get("content_version") == OS.get_environment("UCR_CONTENT") and trusted.get("engine_binary_sha256") == OS.get_environment("UCR_ENGINE")): finish("identity_refused"); return
	if not check("actual GL and normal 1x 60Hz",DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60 and Settings.game_speed == 1.0): finish("runtime_refused"); return
	AudioServer.set_bus_mute(0,true)
	Localize.set_language("zh_CN",false)
	var deadline: int = Time.get_ticks_msec() + 90000
	while not flow.can_launch() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not check("ordinary startup completed without recovery or SDK",flow.can_launch() and flow.last_result.get("startup_checked",false) and flow.last_result.get("progress_recovered",-1) == 0 and flow._startup_cfg == null and flow._startup_coordinator == null and not SteamService.available and Campaign.cloud_owner.is_empty()): finish("startup_refused"); return
	observations["startup_result"] = flow.last_result.duplicate(true)
	menu = MenuScene.instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	flow.operation_finished.connect(on_operation)
	if not check("only original normal menu exists",no_world() and not get_tree().paused and Campaign._cfg_writer == null and not Campaign.persistence_busy()): finish("menu_refused"); return
	if mode == "save_retry": await save_retry_run()
	else: await readback_run()

func panel() -> Variant:
	var found: Variant = null
	for node: Node in menu.get_children():
		if node.get_script() == PanelScript:
			if found != null: return null
			found = node
	return found

func save_retry_run() -> void:
	var before: Dictionary = disk_row()
	var prefs_before: Dictionary = prefs_row()
	observations["initial_disk"] = before.duplicate(true)
	observations["initial_prefs"] = prefs_before.duplicate(true)
	if not check("fresh profile has no CFG settings journal or candidate parent",not before.cfg.exists and not before.settings.exists and before.journal_inventory.kind == "absent" and before.candidate_inventory.kind == "absent"): finish("not_fresh"); return
	if not check("actual default settings differ from chosen UI values",Settings.formation_mode == "loose" and Campaign.ai_difficulty == "normal"): finish("not_default"); return
	if not press(text_button(menu,Localize.text("🛠  更多"),true),"actual main menu More"): finish("more_button"); return
	await get_tree().process_frame
	if not press(text_button(menu,Localize.text("⚙  设置")),"actual More settings"): finish("settings_button"); return
	await get_tree().process_frame
	var settings_panel: Variant = panel()
	if not check("actual reusable SettingsPanel was created",is_instance_valid(settings_panel) and settings_panel.get_script() == PanelScript): finish("panel_missing"); return
	var formation: Variant = text_button(settings_panel,Localize.text("方阵"))
	var difficulty: Variant = text_button(settings_panel,Localize.text("困难"))
	if not check("actual formation and difficulty controls found",is_instance_valid(formation) and is_instance_valid(difficulty)): finish("controls_missing"); return
	if not await show_control(formation) or not press(formation,"normal formation box choice"): finish("formation_button"); return
	if not check("original formation callback changed observable Settings",Settings.formation_mode == "box" and formation.button_pressed): finish("formation_callback"); return
	if not await show_control(difficulty) or not press(difficulty,"normal difficulty hard choice"): finish("difficulty_button"); return
	if not check("original difficulty callback changed observable Campaign",Campaign.ai_difficulty == "hard" and difficulty.button_pressed): finish("difficulty_callback"); return
	var chosen: Dictionary = prefs_row()
	var expected_campaign: Dictionary = prefs_before.campaign.duplicate(true)
	expected_campaign.ai_difficulty = "hard"
	check("only chosen campaign preference changed and no progress reward grew",chosen.campaign == expected_campaign and chosen.unlocked == prefs_before.unlocked and chosen.records == prefs_before.records and chosen.cloud_owner == prefs_before.cloud_owner)
	check("settings controls have not yet written either configuration",disk_row() == before)
	observations["chosen_prefs"] = chosen.duplicate(true)
	if not passed(): finish("control_scope"); return
	var stage_parent: String = ProjectSettings.globalize_path(CANDIDATE_PARENT)
	var cfg_path: String = ProjectSettings.globalize_path(ConfigTransaction.CFG_PATH)
	var journal_directory: String = ConfigTransaction.new().directory
	var detail := {"stage_parent":stage_parent,"cfg_path":cfg_path,"journal_directory":journal_directory,"expected_code":"CFG_STAGE_PARENT","initial_cfg":before.cfg,"initial_settings":before.settings}
	if not await gate("arm_stage_parent",detail): finish("arm_gate"); return
	if not check("host created only a regular parent blocker before save",FileAccess.file_exists(stage_parent) and not DirAccess.dir_exists_absolute(stage_parent) and file_row(cfg_path) == before.cfg and file_row(ProjectSettings.globalize_path(Settings.PATH)) == before.settings): finish("blocker_missing"); return
	var back: Variant = text_button(settings_panel,Localize.text("←  返回（保存）"))
	if not check("actual return save control found",is_instance_valid(back)): finish("save_button_missing"); return
	if not await show_control(back): finish("save_button_clipped"); return
	var original_result: Dictionary = flow.last_result
	if not press(back,"actual settings Return Save"): finish("save_button"); return
	check("Settings saves synchronously before Campaign deferred write",file_row(ProjectSettings.globalize_path(Settings.PATH)).exists and file_row(cfg_path) == before.cfg and Campaign._prefs_deferred and Campaign._prefs_requested.get("ai_difficulty") == "hard")
	if not await wait_changed_result(original_result) or not failure_valid(): finish("first_stage_failure"); return
	if not check("first failure emitted once after actual SettingsPanel closed",operations.size() == 1 and operations[0].result.get("code") == "CFG_STAGE_PARENT" and panel() == null): finish("first_failure_signal"); return
	var settings_cfg := ConfigFile.new()
	check("settings file legitimately contains UI chosen formation despite CFG failure",settings_cfg.load(Settings.PATH) == OK and settings_cfg.get_value("game","formation","") == "box" and file_row(cfg_path) == before.cfg and prefs_row() == chosen)
	retain_writer()
	check("frozen proposal contains exactly the preferences edited through the UI",retained_cfg.get_sections().size() == 1 and retained_cfg.has_section("pref") and retained_cfg.get_section_keys("pref").size() == chosen.campaign.size())
	for key: String in chosen.campaign:
		check("frozen UI preference retains exact value " + key,retained_cfg.has_section_key("pref",key) and exact(retained_cfg.get_value("pref",key)) == exact(chosen.campaign[key]))
	var frozen_semantics: Dictionary = Values.semantics(retained_cfg)
	check("frozen proposal semantics and retry prefs bind the edited UI values",frozen_semantics.get("ok",false) and JSON.stringify(frozen_semantics.get("sections",{})).sha256_text() == retained_writer._active.semantics_sha256 and exact(Campaign._prefs_failed) == exact(chosen.campaign))
	observations["first_failure"] = retained_pending.duplicate(true)
	if not same_writer(): finish("retained_initial"); return
	original_result = flow.last_result
	if not press(flow.find_child("RetryCampaignConfig",true,false),"actual RetryCampaignConfig while parent still blocked"): finish("blocked_retry_button"); return
	if not await wait_changed_result(original_result) or not failure_valid() or not same_writer(): finish("blocked_retry"); return
	observations["blocked_retry"] = pending_observation()
	check("blocked retry uses actual result replacement without duplicate operation signal",operations.size() == 1 and not get_tree().process_frame.is_connected(Callable(flow,"_retry_config_write")) and observations.blocked_retry == observations.first_failure)
	if not passed(): finish("blocked_retry_observation"); return
	var transaction: String = retained_writer._active.transaction
	if not await gate("release_stage_parent",{"stage_parent":stage_parent,"cfg_path":cfg_path,"journal_directory":journal_directory,"expected_code":"CFG_STAGE_PARENT"}): finish("release_gate"); return
	if not check("host released own blocker without installing a candidate or CFG",not FileAccess.file_exists(stage_parent) and not DirAccess.dir_exists_absolute(stage_parent) and file_row(cfg_path) == before.cfg): finish("release_scope"); return
	if not same_writer(false): finish("released_writer"); return
	original_result = flow.last_result
	if not press(flow.find_child("RetryCampaignConfig",true,false),"actual RetryCampaignConfig after owned blocker removed"): finish("success_retry_button"); return
	if not await wait_changed_result(original_result): finish("success_retry_timeout"); return
	observations["final_write_result"] = flow.last_result.duplicate(true)
	check("actual one retained preference transaction completed",flow.last_result.get("ok",false) and flow.last_result.get("code") == "CAMPAIGN_CFG_READBACK_VERIFIED" and flow.last_result.get("persisted",false) and not flow.last_result.get("suppressed",true) and flow.last_result.get("transaction") == transaction and flow.last_result.get("owned_stage_cleanup",{}).get("ok",false))
	check("real retry releases same writer and closes original error overlay",Campaign._cfg_writer == null and not Campaign.persistence_busy() and Campaign._cfg_writer_scope.is_empty() and Campaign._prefs_failed.is_empty() and Campaign._prefs_failed_scope.is_empty() and Campaign._prefs_requested.is_empty() and retained_writer._active.is_empty() and retained_writer._frozen_cfg == null and not retained_writer.busy() and flow.phase == flow.Phase.IDLE and flow._overlay == null and not get_tree().paused and operations.size() == 2 and no_world())
	if not passed(): finish("success_result"); return
	save_checkpoint()
	if not passed(): finish("completed_checkpoint"); return
	var applied: Dictionary = checkpoint.journal.applied.document
	check("actual installed CFG is exact candidate from the retained transaction",checkpoint.journal.transaction == transaction and checkpoint.disk.cfg.sha256 == applied.candidate_sha256 and checkpoint.disk.cfg.sha256 == flow.last_result.file_sha256 and checkpoint.prefs == chosen and checkpoint.disk.settings == observations.first_failure.disk.settings)
	var cfg := ConfigFile.new()
	check("real CFG readback contains original UI preference",cfg.load(ConfigTransaction.CFG_PATH) == OK and cfg.get_value("pref","ai_difficulty","") == "hard")
	var stable: Variant = checkpoint.exact_disk
	for index in range(60): await get_tree().process_frame
	check("success settles without duplicate preference commit",exact(disk_row()) == stable and exact(prefs_row()) == checkpoint.exact_prefs and operations.size() == 2 and Campaign._cfg_writer == null and not Campaign._prefs_deferred)
	finish()

func readback_run() -> void:
	var path: String = OS.get_environment("UCR_PREVIOUS")
	if not check("previous original report SHA",FileAccess.get_sha256(path) == OS.get_environment("UCR_PREVIOUS_SHA")): finish("previous_hash"); return
	var value: Variant = read_json(path)
	if not check("successful independent original predecessor",typeof(value) == TYPE_DICTIONARY and value.get("schema") == "ui_config_retry_two_process_v1" and value.get("mode") == "save_retry" and value.get("passed",false) and value.get("stage_completed",false) and value.get("pid") != OS.get_process_id() and value.get("profile") == OS.get_environment("UCR_PROFILE") and value.get("batch_nonce") == OS.get_environment("UCR_BATCH_NONCE") and value.get("process_nonce") != OS.get_environment("UCR_PROCESS_NONCE") and value.get("identity") == identity_row() and value.get("candidate_manifest_sha256") == OS.get_environment("UCR_MANIFEST") and value.get("sources_sha256") == OS.get_environment("UCR_SOURCES_SHA256")): finish("previous_scope"); return
	previous = value
	save_checkpoint()
	if not passed(): finish("readback_checkpoint"); return
	check("actual independent startup loaded UI preferences",Settings.formation_mode == "box" and Campaign.ai_difficulty == "hard" and checkpoint.exact_prefs == previous.checkpoint.exact_prefs)
	check("startup retained exact original CFG settings and journal bytes",checkpoint.exact_disk == previous.checkpoint.exact_disk and checkpoint.exact_journal == previous.checkpoint.exact_journal)
	check("startup needed no pending transaction recovery or reward replay",flow._startup_cfg == null and flow._startup_index == 0 and flow._startup_items.is_empty() and flow._startup_coordinator == null and Campaign._cfg_writer == null and not Campaign._prefs_deferred and Campaign._prefs_requested.is_empty() and operations.is_empty() and no_world())
	var status: Dictionary = ConfigTransaction.new().pending_status()
	check("native CFG journal is already applied without pending work",status.get("ok",false) and not status.get("pending",true),status)
	for index in range(60): await get_tree().process_frame
	check("readback process does not generate another commit or recovery",exact(disk_row()) == checkpoint.exact_disk and exact(prefs_row()) == checkpoint.exact_prefs and exact(journal_row()) == checkpoint.exact_journal and operations.is_empty() and Campaign._cfg_writer == null and not Campaign._prefs_deferred and not Campaign.persistence_busy() and flow.phase == flow.Phase.IDLE)
	finish()
