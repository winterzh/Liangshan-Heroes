extends "base.gd"
## Prepared-journal interruption, original startup retry, independent no-replay readback.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	mode = OS.get_environment("UST_MODE")
	output = OS.get_environment("UST_OUTPUT")
	flow = get_node("/root/ContinueFlow")
	flow.operation_finished.connect(on_operation)
	run.call_deferred()

func scope_row(schema: String) -> Dictionary:
	return {"schema":schema,"mode":mode,"pid":OS.get_process_id(),"batch_nonce":OS.get_environment("UST_BATCH_NONCE"),"process_nonce":OS.get_environment("UST_PROCESS_NONCE"),"profile":OS.get_environment("UST_PROFILE"),"identity":identity_row(),"candidate_manifest_sha256":OS.get_environment("UST_MANIFEST"),"sources_sha256":OS.get_environment("UST_SOURCES_SHA256")}

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check("strict isolated B2 source scope",mode in MODES and profile_valid()): finish("scope_refused"); return
	trusted = Provider.new().resolve_runtime_identity()
	if not check("actual fixed installed source and engine",trusted.get("ok",false) and trusted.get("source_mode",false) and trusted.get("content_version") == OS.get_environment("UST_CONTENT") and trusted.get("engine_binary_sha256") == OS.get_environment("UST_ENGINE")): finish("identity_refused"); return
	if not check("actual GL and normal 1x 60Hz",DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60 and Settings.game_speed == 1.0 and not SteamService.available): finish("runtime_refused"); return
	AudioServer.set_bus_mute(0,true)
	Localize.set_language("zh_CN",false)
	var deadline: int = Time.get_ticks_msec() + 90000
	while flow.phase not in [flow.Phase.IDLE,flow.Phase.ERROR] and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not check("original startup reached an observable outcome",flow.phase in [flow.Phase.IDLE,flow.Phase.ERROR]): finish("startup_timeout"); return
	observations["startup_result"] = flow.last_result.duplicate(true)
	menu = MenuScene.instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	if not check("normal menu exists without a Battle or SDK",no_world() and not SteamService.available and Campaign.cloud_owner.is_empty()): finish("menu_refused"); return
	if mode == "startup_retry": await startup_retry_run()
	else:
		if not check("ordinary startup succeeded without pending CFG",flow.can_launch() and flow.last_result.get("startup_checked",false) and flow.last_result.get("progress_recovered",-1) == 0 and flow._startup_cfg == null and flow._startup_coordinator == null and not get_tree().paused and not Campaign.persistence_busy()): finish("startup_refused"); return
		if mode == "prepare_crash": await producer_run()
		else: await readback_run()

func panel() -> Variant:
	var found: Variant = null
	for node: Node in menu.get_children():
		if node.get_script() == PanelScript:
			if found != null: return null
			found = node
	return found

func producer_observation(submitted: bool) -> Dictionary:
	var value: Dictionary = scope_row("ui_startup_producer_observation_v1")
	value.merge({"submitted":submitted,"precondition_checks_passed":passed(),"stage_completed":false,"controlled_crash_completed":false,"checks":checks.duplicate(true),"actions":actions.duplicate(true),"initial_disk":observations.initial_disk,"chosen_prefs":observations.chosen_prefs,"exact_chosen_prefs":exact(observations.chosen_prefs),"disk_now":disk_row(),"prefs_deferred":Campaign._prefs_deferred,"prefs_requested":Campaign._prefs_requested.duplicate(true),"desktop_os_input":false,"runtime_qualified":false,"producer_normal_exit_qualified":false})
	return value

func producer_run() -> void:
	var before: Dictionary = disk_row()
	var initial: Dictionary = prefs_row()
	observations["initial_disk"] = before.duplicate(true)
	observations["initial_prefs"] = initial.duplicate(true)
	if not check("new producer profile contains no prior CFG or journal",not before.cfg.exists and not before.settings.exists and before.journal_inventory.kind == "absent" and before.candidate_inventory.kind == "absent"): finish("producer_not_fresh"); return
	if not check("actual initial preference controls start at defaults",Settings.formation_mode == "loose" and Campaign.ai_difficulty == "normal"): finish("producer_defaults"); return
	if not press(text_button(menu,Localize.text("🛠  更多"),true),"actual menu More"): finish("more_button"); return
	await get_tree().process_frame
	if not press(text_button(menu,Localize.text("⚙  设置")),"actual More settings"): finish("settings_button"); return
	await get_tree().process_frame
	var settings_panel: Variant = panel()
	if not check("original SettingsPanel exists",is_instance_valid(settings_panel) and settings_panel.get_script() == PanelScript): finish("panel_missing"); return
	var formation: Variant = text_button(settings_panel,Localize.text("方阵"))
	var difficulty: Variant = text_button(settings_panel,Localize.text("困难"))
	if not check("original settings choice controls exist",is_instance_valid(formation) and is_instance_valid(difficulty)): finish("controls_missing"); return
	if not await show_control(formation) or not press(formation,"original box formation callback"): finish("formation_button"); return
	if not await show_control(difficulty) or not press(difficulty,"original hard difficulty callback"): finish("difficulty_button"); return
	var chosen: Dictionary = prefs_row()
	var expected: Dictionary = initial.campaign.duplicate(true)
	expected.ai_difficulty = "hard"
	check("real UI changed only intended preferences without progress",Settings.formation_mode == "box" and formation.button_pressed and difficulty.button_pressed and chosen.campaign == expected and chosen.unlocked == initial.unlocked and chosen.records == initial.records and chosen.cloud_owner == initial.cloud_owner)
	check("UI editing has not yet saved either file",disk_row() == before)
	observations["chosen_prefs"] = chosen.duplicate(true)
	if not passed(): finish("producer_ui_scope"); return
	if not check("publish real UI producer preconditions",publish("producer_ready.json",producer_observation(false))): finish("producer_ready"); return
	if not await gate("prepared_armed",{"stage_parent":ProjectSettings.globalize_path(CANDIDATE_PARENT),"cfg_path":ProjectSettings.globalize_path(ConfigTransaction.CFG_PATH),"journal_directory":ConfigTransaction.new().directory,"producer_ready_sha256":FileAccess.get_sha256(output.path_join("producer_ready.json"))}): finish("producer_arm"); return
	var back: Variant = text_button(settings_panel,Localize.text("←  返回（保存）"))
	if not check("real return-save control found",is_instance_valid(back)) or not await show_control(back): finish("back_missing"); return
	if not press(back,"actual settings Return Save before planned interruption"): finish("back_button"); return
	# Same callback stack: Campaign's deferred writer cannot have run yet.
	check("actual Settings save precedes requested deferred CFG write",Campaign._prefs_deferred and Campaign._prefs_requested.get("ai_difficulty") == "hard" and file_row(ProjectSettings.globalize_path(Settings.PATH)).exists and file_row(ProjectSettings.globalize_path(ConfigTransaction.CFG_PATH)) == before.cfg)
	if not check("publish exact submission before production deferred callback",publish("producer_submitted.json",producer_observation(true))): finish("producer_submitted"); return
	var deadline: int = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if flow.phase == flow.Phase.ERROR or FileAccess.file_exists(ConfigTransaction.CFG_PATH): finish("expected_controlled_stop_not_observed"); return
	finish("producer_not_terminated_at_original_checkpoint")

func load_prepared_fixture() -> bool:
	var path: String = OS.get_environment("UST_PREVIOUS")
	if not check("actual terminated producer fixture exact SHA",FileAccess.get_sha256(path) == OS.get_environment("UST_PREVIOUS_SHA")): return false
	var value: Variant = read_json(path)
	if not check("fixture binds real controlled producer termination",typeof(value) == TYPE_DICTIONARY and value.get("schema") == "ui_startup_prepared_fixture_v1" and value.get("mode") == "prepare_crash" and value.get("actual_process_terminated",false) and value.get("planned_termination",false) and value.get("pid") != OS.get_process_id() and value.get("process_nonce") != OS.get_environment("UST_PROCESS_NONCE") and value.get("batch_nonce") == OS.get_environment("UST_BATCH_NONCE") and value.get("profile") == OS.get_environment("UST_PROFILE") and value.get("identity") == identity_row() and value.get("candidate_manifest_sha256") == OS.get_environment("UST_MANIFEST") and value.get("sources_sha256") == OS.get_environment("UST_SOURCES_SHA256") and typeof(value.get("checkpoint")) == TYPE_DICTIONARY): return false
	prepared_fixture = value
	return true

func startup_failure_valid() -> bool:
	return check("original startup surfaced real install rename failure",flow.phase == flow.Phase.ERROR and flow.last_result.get("code") == "CFG_INSTALL_RENAME" and not flow.last_result.get("ok",true) and flow.last_result.get("startup_pending",false) and flow._startup_cfg != null and flow._startup_cfg.get_script() == ConfigTransaction and flow._startup_cfg.busy() and flow._startup_cfg._active.get("stage") == "replacing" and flow._startup_cfg._frozen_cfg == null and not flow._startup_scanned and flow._startup_index == 0 and flow._startup_coordinator == null and flow._startup_lifecycle == null and Campaign._cfg_writer == null and not get_tree().paused and no_world() and flow.find_child("RetryCampaignStartup",true,false) != null,flow.last_result)

func recovery_observation() -> Dictionary:
	var writer: RefCounted = flow._startup_cfg
	var head: Dictionary = writer._chain()
	var record: Dictionary = writer._active.record
	var candidate: String = writer._stage_dir(record).path_join("candidate.cfg")
	var stable: Dictionary = writer._stable_cfg(candidate,record.candidate_sha256)
	var owner_path: String = writer.directory.path_join("writing/owner.json")
	return {"writer_instance_id":str(writer.get_instance_id()),"transaction":record.transaction,"stage":writer._active.stage,"directory":writer.directory,"owner_path":owner_path,"owner_raw":writer._lock_raw,"owner_sha256":FileAccess.get_sha256(owner_path),"locked":writer._locked,"lock_created":writer._lock_created,"head_ok":head.get("ok",false),"head_revision":head.get("revision",-1),"head_sha256":head.get("file_sha256",""),"prepared_path":writer.directory.path_join("record_0000000001.json"),"candidate_path":candidate,"candidate_sha256":FileAccess.get_sha256(candidate),"candidate_read_ok":stable.get("ok",false),"semantics_sha256":stable.get("semantics_sha256",""),"exact_candidate_semantics":exact(stable.get("semantics",{})),"exact_active":exact(writer._active),"exact_current_record":exact(record),"exact_recovery_scope":exact(writer._recovery_scope),"exact_flow_scope":exact(flow._startup_cfg_scope),"frozen_config_absent":writer._frozen_cfg == null,"pending_record_empty":writer._pending_record.is_empty(),"inventory":writer.inventory(),"disk":disk_row(),"flow_phase":int(flow.phase),"tree_paused":get_tree().paused,"startup_scanned":flow._startup_scanned,"startup_index":flow._startup_index,"coordinator_absent":flow._startup_coordinator == null,"lifecycle_absent":flow._startup_lifecycle == null,"campaign_writer_absent":Campaign._cfg_writer == null,"exact_preferences":exact(prefs_row())}

func retain_recovery() -> void:
	retained_writer = flow._startup_cfg
	retained_active = retained_writer._active
	retained_record = retained_writer._active.record
	retained_scope = retained_writer._recovery_scope
	retained_flow_scope = flow._startup_cfg_scope
	retained_pending = recovery_observation()

func same_recovery() -> bool:
	if not check("same original startup CFG active record and recovery scopes",flow._startup_cfg == retained_writer and is_same(retained_active,retained_writer._active) and is_same(retained_record,retained_writer._active.record) and is_same(retained_scope,retained_writer._recovery_scope) and is_same(retained_flow_scope,flow._startup_cfg_scope)): return false
	var current: Dictionary = recovery_observation()
	return check("retry preserves original closed record candidate semantics CAS and new owner",current == retained_pending and current.locked and current.lock_created and current.head_ok and current.head_revision == 1 and current.head_sha256 == prepared_fixture.checkpoint.prepared_sha256 and current.candidate_read_ok and current.candidate_sha256 == prepared_fixture.checkpoint.candidate_sha256 and current.semantics_sha256 == retained_record.semantics_sha256 and current.pending_record_empty and current.frozen_config_absent and current.coordinator_absent and current.lifecycle_absent and not current.tree_paused)

func verify_prepared_and_candidate() -> bool:
	var expected: Dictionary = prepared_fixture.checkpoint
	var writer: RefCounted = flow._startup_cfg
	var original: Dictionary = writer._verified("record_0000000001.json")
	if not check("actual original prepared1 is unchanged and not a rev0 fixture",original.get("ok",false) and original.revision == 1 and original.document.state == "prepared" and original.file_sha256 == expected.get("prepared_sha256") and original.previous == ZERO): return false
	var record: Dictionary = original.document
	var candidate: String = writer._stage_dir(record).path_join("candidate.cfg")
	check("candidate and CFG paths come from actual prepared transaction",writer.directory == expected.journal_directory and writer.directory.path_join("record_0000000001.json") == expected.prepared_path and candidate == expected.candidate_path and record.candidate_sha256 == expected.candidate_sha256 and same_file_row(file_row(ProjectSettings.globalize_path(ConfigTransaction.CFG_PATH)),expected.cfg) and same_file_row(file_row(ProjectSettings.globalize_path(Settings.PATH)),expected.settings))
	check("actual prepared scope matches this installed uncredited preference transaction",record.schema == ConfigTransaction.CFG_SCHEMA and record.operation == "prefs" and record.run_token.is_empty() and record.intent_sha256.is_empty() and record.original_sha256 == ZERO and record.original_owner.is_empty() and record.target_owner.is_empty() and record.content_version == trusted.content_version and record.engine_sha256 == trusted.engine_binary_sha256)
	var stable: Dictionary = writer._stable_cfg(candidate,expected.candidate_sha256)
	if not check("real candidate remains readable while installation alone is denied",stable.get("ok",false) and stable.get("semantics_sha256") == record.semantics_sha256): return false
	var decoded: Dictionary = Codec.new().decode(expected.exact_chosen_prefs)
	if not check("producer typed preference payload is valid",decoded.get("ok",false) and typeof(decoded.get("value")) == TYPE_DICTIONARY): return false
	var chosen: Dictionary = decoded.value
	if not check("producer typed UI preference observation decodes",chosen.has("campaign") and chosen.get("settings_formation") == "box" and chosen.campaign.get("ai_difficulty") == "hard"): return false
	for key: String in chosen.campaign:
		check("actual candidate preserves producer UI preference " + key,stable.cfg.has_section_key("pref",key) and exact(stable.cfg.get_value("pref",key)) == exact(chosen.campaign[key]))
	var old_owner: Variant = JSON.parse_string(expected.owner_raw)
	var current_owner: Variant = JSON.parse_string(writer._lock_raw)
	check("real recovery replaced only terminated producer owner with current child",typeof(old_owner) == TYPE_DICTIONARY and typeof(current_owner) == TYPE_DICTIONARY and old_owner.get("pid") == str(int(prepared_fixture.pid)) and current_owner.get("pid") == str(OS.get_process_id()) and old_owner.get("token") != current_owner.get("token") and writer._lock_raw != expected.owner_raw and expected.owner_raw.sha256_text() == expected.owner_sha256 and writer.directory.path_join("writing/owner.json") == expected.owner_path)
	check("startup refusal has not installed prefs or replayed game progression",Settings.formation_mode == "box" and Campaign.ai_difficulty == "normal" and Campaign.unlocked == chosen.unlocked and exact(Campaign.records) == exact(chosen.records) and Campaign.cloud_owner == chosen.cloud_owner)
	return passed()

func startup_retry_run() -> void:
	if not load_prepared_fixture() or not startup_failure_valid() or not verify_prepared_and_candidate(): finish("initial_startup_refusal"); return
	retain_recovery()
	observations["first_failure"] = retained_pending.duplicate(true)
	var initial_operations: int = operations.size()
	observations["initial_operation_count"] = initial_operations
	if not same_recovery(): finish("first_recovery_scope"); return
	var original_result: Dictionary = flow.last_result
	if not press(flow.find_child("RetryCampaignStartup",true,false),"actual startup Retry while candidate handle remains"): finish("blocked_retry_button"); return
	if not await wait_changed_result(original_result) or not startup_failure_valid() or not same_recovery(): finish("blocked_retry"); return
	observations["blocked_retry"] = recovery_observation()
	check("failed original startup Retry emitted exactly one failure",operations.size() == initial_operations + 1 and operations.back().result.get("code") == "CFG_INSTALL_RENAME" and not get_tree().process_frame.is_connected(Callable(flow,"_startup_recover")))
	if not passed(): finish("blocked_retry_signal"); return
	var blocked: Dictionary = scope_row("ui_startup_blocked_observation_v1")
	blocked.merge({"checks":checks.duplicate(true),"actions":actions.duplicate(true),"actual_operations":operations.duplicate(true),"first_failure":observations.first_failure,"blocked_retry":observations.blocked_retry,"prepared_fixture_sha256":OS.get_environment("UST_PREVIOUS_SHA"),"stage_completed":false,"desktop_os_input":false})
	if not check("publish actual two refusal observations before handle release",publish("startup_blocked.json",blocked)): finish("blocked_observation"); return
	var transaction: String = retained_record.transaction
	if not await gate("release_candidate_install",{"candidate_path":retained_pending.candidate_path,"candidate_sha256":retained_pending.candidate_sha256,"journal_directory":retained_writer.directory,"transaction":transaction,"expected_code":"CFG_INSTALL_RENAME"}): finish("release_gate"); return
	if not same_recovery(): finish("released_recovery_scope"); return
	original_result = flow.last_result
	if not press(flow.find_child("RetryCampaignStartup",true,false),"actual startup Retry after owned handle closes"): finish("success_retry_button"); return
	if not await wait_changed_result(original_result): finish("success_retry_timeout"); return
	observations["final_startup_result"] = flow.last_result.duplicate(true)
	check("original startup resumes same transaction without settlement authorization",flow.last_result.get("ok",false) and flow.last_result.get("startup_checked",false) and flow.last_result.get("progress_recovered",-1) == 0 and flow.last_result.get("settlement_authorized",true) == false and flow.phase == flow.Phase.IDLE and flow._startup_cfg == null and flow._startup_cfg_scope.is_empty() and flow._startup_coordinator == null and flow._startup_lifecycle == null and flow._startup_index == 0 and flow._startup_items.is_empty() and flow._startup_scanned and retained_writer._active.is_empty() and retained_writer._frozen_cfg == null and not retained_writer.busy() and operations.size() == initial_operations + 2 and no_world())
	if not passed(): finish("startup_success_result"); return
	save_checkpoint()
	if not passed(): finish("startup_checkpoint"); return
	check("recovered CFG matches original candidate and UI preferences exactly",checkpoint.journal.transaction == transaction and checkpoint.journal.prepared.file_sha256 == prepared_fixture.checkpoint.prepared_sha256 and checkpoint.disk.cfg.sha256 == prepared_fixture.checkpoint.candidate_sha256 and same_file_row(checkpoint.disk.settings,prepared_fixture.checkpoint.settings) and checkpoint.exact_prefs == prepared_fixture.checkpoint.exact_chosen_prefs)
	var stable_disk: Variant = checkpoint.exact_disk
	for index in range(60): await get_tree().process_frame
	check("completed startup does not commit the same settings twice",exact(disk_row()) == stable_disk and exact(prefs_row()) == checkpoint.exact_prefs and exact(journal_row()) == checkpoint.exact_journal and operations.size() == initial_operations + 2 and Campaign._cfg_writer == null and not Campaign._prefs_deferred)
	finish()

func readback_run() -> void:
	var path: String = OS.get_environment("UST_PREVIOUS")
	if not check("completed recovery predecessor exact report SHA",FileAccess.get_sha256(path) == OS.get_environment("UST_PREVIOUS_SHA")): finish("previous_hash"); return
	var value: Variant = read_json(path)
	if not check("independent successful actual startup recovery predecessor",typeof(value) == TYPE_DICTIONARY and value.get("schema") == "ui_startup_retry_three_process_v1" and value.get("mode") == "startup_retry" and value.get("passed",false) and value.get("stage_completed",false) and value.get("pid") != OS.get_process_id() and value.get("profile") == OS.get_environment("UST_PROFILE") and value.get("batch_nonce") == OS.get_environment("UST_BATCH_NONCE") and value.get("process_nonce") != OS.get_environment("UST_PROCESS_NONCE") and value.get("identity") == identity_row() and value.get("candidate_manifest_sha256") == OS.get_environment("UST_MANIFEST") and value.get("sources_sha256") == OS.get_environment("UST_SOURCES_SHA256")): finish("previous_scope"); return
	previous = value
	var initial_operations: int = operations.size()
	save_checkpoint()
	if not passed(): finish("readback_checkpoint"); return
	check("third process reads exact applied original UI preferences",Settings.formation_mode == "box" and Campaign.ai_difficulty == "hard" and checkpoint.exact_prefs == previous.checkpoint.exact_prefs)
	check("third startup did not change original files or transaction",checkpoint.exact_disk == previous.checkpoint.exact_disk and checkpoint.exact_journal == previous.checkpoint.exact_journal and flow._startup_cfg == null and flow._startup_coordinator == null and flow._startup_index == 0 and flow._startup_items.is_empty() and not Campaign._prefs_deferred)
	var status: Dictionary = ConfigTransaction.new().pending_status()
	check("actual journal remains applied with no pending recovery",status.get("ok",false) and not status.get("pending",true),status)
	for index in range(60): await get_tree().process_frame
	check("independent readback has no recovery or preference replay",exact(disk_row()) == checkpoint.exact_disk and exact(prefs_row()) == checkpoint.exact_prefs and exact(journal_row()) == checkpoint.exact_journal and operations.size() == initial_operations and Campaign._cfg_writer == null and not Campaign.persistence_busy())
	observations["initial_operation_count"] = initial_operations
	finish()
