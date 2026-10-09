extends SceneTree
## Actual fresh startup and normal preferences only. No battle/world fixture.
const Gate := preload("res://scripts/run_campaign_progress_gate.gd")
var checks: Array = []
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String, detail: Variant = null) -> void:
	checks.append({"label":label,"ok":value,"detail":detail})
	if not value: failures.append(label)

func _run() -> void:
	var output := OS.get_environment("CAMPAIGN_INTEGRATION_REPORT")
	var nonce := OS.get_environment("CAMPAIGN_INTEGRATION_NONCE")
	if output.is_empty() or nonce.length() != 32: quit(2); return
	var opened: int = change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	check(opened == OK,"actual configured menu opened")
	for frame in range(180): await process_frame
	while Engine.is_in_physics_frame(): await process_frame
	var flow: Node = root.get_node("ContinueFlow")
	var campaign: Node = root.get_node("Campaign")
	var steam: Node = root.get_node("SteamService")
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn","actual menu retained")
	check(flow.phase == flow.Phase.IDLE and flow.last_result.get("startup_checked",false),"fresh startup actually acknowledged",flow.last_result.duplicate(true))
	check(Gate.status().startup_checked and Gate.background_allowed(),"startup gate opens after actual scan",Gate.status())
	check(not campaign.persistence_busy(),"no retained configuration operation")
	check(not FileAccess.file_exists(campaign.SAVE_PATH),"fresh profile begins without campaign CFG")
	check(not DirAccess.dir_exists_absolute("user://continue/v1/local_runs"),"fresh startup creates no local run journals")
	check(not steam.available and steam._active_run == 0,"Steam-disabled service has no active run")
	check(OS.get_user_data_dir().replace("\\","/").begins_with(OS.get_environment("APPDATA").replace("\\","/")+"/"),"actual user data stays inside private APPDATA")
	check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60,"ordinary simulation clock")
	if failures.is_empty():
		campaign.ai_difficulty = "hard"
		campaign.victory_mode = "regicide"
		campaign.save_prefs()
		for frame in range(60): await process_frame
		while Engine.is_in_physics_frame(): await process_frame
		var cfg := ConfigFile.new()
		var loaded: int = cfg.load(campaign.SAVE_PATH)
		check(loaded == OK,"normal deferred save_prefs writes actual CFG",loaded)
		if loaded == OK:
			check(cfg.get_value("pref","ai_difficulty","") == "hard" and cfg.get_value("pref","victory_mode","") == "regicide","fresh ConfigFile load reads requested preferences")
		check(not campaign.persistence_busy() and Gate.background_allowed(),"preferences release owned operation and preserve startup gate")
		check(flow.phase == flow.Phase.IDLE,"normal preference persistence needs no failure overlay",flow.last_result.duplicate(true))
		var before: String = FileAccess.get_sha256(campaign.SAVE_PATH)
		campaign.save_prefs()
		for frame in range(60): await process_frame
		check(not before.is_empty() and FileAccess.get_sha256(campaign.SAVE_PATH) == before and not campaign.persistence_busy(),"same preference resave keeps actual file hash")
		check(not DirAccess.dir_exists_absolute("user://continue/v1/local_runs"),"preference writes create no campaign/Steam run identity")
	var report := {"schema":"campaign_integration_startup_probe_v1","passed":failures.is_empty(),
		"checks":checks,"failures":failures,"pid":OS.get_process_id(),"nonce":nonce,
		"user_directory":OS.get_user_data_dir(),"startup_last_result":flow.last_result.duplicate(true),
		"scope":"Actual fresh startup and ordinary preference persistence only.",
		"gen2_cfg_ack_recovery_qualified":false,"player_recovery_UI_qualified":false,"Steam_rewards_qualified":false}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("CAMPAIGN_INTEGRATION_STARTUP_PROBE ",report.passed," ",checks.size())
	quit(0 if report.passed else 1)
