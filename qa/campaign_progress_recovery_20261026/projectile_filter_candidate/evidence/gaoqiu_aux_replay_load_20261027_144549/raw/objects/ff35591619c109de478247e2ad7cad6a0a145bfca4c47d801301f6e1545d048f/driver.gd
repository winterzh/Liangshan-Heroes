extends "base.gd"

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	mode = OS.get_environment("GT_MODE")
	var profile: String = OS.get_environment("GT_PROFILE").replace("\\", "/").simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var safe: bool = profile.is_absolute_path() and mode in MODES and OS.get_environment("STEAM_DISABLED") == "1" \
		and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("LSH_CONTINUE_FLOW_QA") == "1" \
		and OS.get_environment("LSH_CONTINUE_FLOW_PROFILE").replace("\\", "/").simplify_path() == profile \
		and Intent.hex(OS.get_environment("GT_PROCESS_NONCE"), 32)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		safe = safe and OS.get_environment(key).replace("\\", "/").simplify_path().to_lower() == profile.path_join(key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(profile.path_join("appdata").to_lower() + "/") \
		and project.to_lower() == OS.get_environment("GT_PROJECT").replace("\\", "/").to_lower()
	if not safe: push_error("GAO_PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	check(true, "actual source project and four private environment roots are bound with Steam disabled")
	check(DisplayServer.get_name() != "headless", "actual GL display is active")
	trusted = Provider.new().resolve_runtime_identity()
	if not check(trusted.get("ok", false) and trusted.get("save_eligible", false) and trusted.get("source_mode", false), "actual source runtime identity"): finish(); return
	check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3" and Intent.CONTRACTS.level5.version == 3,
		"installed Gao uses lifecycle v3 and actual Level5 contract3")
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check(pack.get("ok", false) and not pack.get("deploy_or_start_called", true), "fixed installed Level5 factory audits private definitions without deployment"): finish(); return
	runtime = pack.runtime
	if not await wait_for_startup(): finish(); return
	flow = get_node("/root/ContinueFlow")
	if not check(flow.is_enabled() and flow._private_qa_enabled(), "actual isolated private Flow UI is enabled without public campaign release"): finish(); return
	flow.operation_finished.connect(on_flow_operation)
	get_node("/root/Localize").set_language("zh_CN", false)
	var settings: Node = get_node("/root/Settings")
	settings.game_speed = 1.0
	settings.auto_micro_level = 0
	settings.edge_scroll = false
	if mode == "save_queue":
		await first_process()
	elif read_predecessor() and await restore_same_slot():
		if mode == "resume_complete_save":
			await complete_training()
		else:
			check(checkpoint.generation == 2 and producer._train_queue.is_empty() and producer._train_t == 0.0
				and new_ids() == [training.new_unit_id], "third independent Continue keeps exactly one already completed paid ship")
			check(battle.population_summary().active == training.before.population.active + 3
				and battle.population_summary().queued == 0, "third process retains exactly one completed three-population boat")
			check(progress_snapshot() == progress_before, "third process still has no campaign result or CFG growth")
			check(battle._continue_receipt.open_head().document.state == "active", "third process remains an active campaign without terminal settlement")
			stage_completed = failures.is_empty()
	if save_exit_owned: return
	finish()

func finish(exit_process := true) -> void:
	var end_identity: Dictionary = Provider.new().resolve_runtime_identity()
	check(end_identity.get("save_eligible", false) and end_identity.get("source_mode", false)
		and end_identity.get("content_version") == trusted.get("content_version")
		and end_identity.get("engine_binary_sha256") == trusted.get("engine_binary_sha256"), "final executed source and engine identity unchanged")
	check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "normal clock remains 1x and 60Hz")
	var exact: Dictionary = Codec.new().encode(checkpoint)
	var exact_training: Dictionary = Codec.new().encode(training)
	check(exact.ok and exact_training.ok, "production Codec retains exact typed checkpoints and training evidence")
	var lifecycle: Node = get_node("/root/AppLifecycle")
	var result: Dictionary = {"schema":"campaign_gaoqiu_training_v1", "mode":mode, "passed":stage_completed and failures.is_empty(),
		"stage_completed":stage_completed, "checks":checks, "failures":failures, "observations":observations, "actions":action_evidence,
		"identity":identity_row(), "pid":OS.get_process_id(), "batch_nonce":OS.get_environment("GT_NONCE"),
		"process_nonce":OS.get_environment("GT_PROCESS_NONCE"), "exit_reason":lifecycle.quit_reason(),
		"save_exit_observed":save_exit_owned and save_report_ready and lifecycle.quit_started() and lifecycle.quit_reason() == "continue_saved",
		"profile":OS.get_environment("GT_PROFILE"), "slot_root":SLOT, "checkpoint":checkpoint, "training":training,
		"exact_checkpoint":exact.get("value"), "exact_training":exact_training.get("value"),
		"candidate_manifest_sha256":OS.get_environment("GT_CANDIDATE_SHA256"), "ordinary_queue_commands_this_process":commands,
		"full_story_required":false, "active_period_only":true, "no_gameplay_state_injection":true,
		"simulation_time_scale":Engine.time_scale, "physics_hz":Engine.physics_ticks_per_second,
		"public_continue_qualified":false, "native_sdk_qualified":false, "native_release_tested":false,
		"human_acceptance":false, "terminal_qualified":false, "rewards_qualified":false, "victory_chain_qualified":false, "defeat_chain_qualified":false}
	var file: FileAccess = FileAccess.open(OS.get_environment("GT_REPORT"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok: get_tree().quit(2); return
	if not exit_process: return
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if result.passed else 1)
