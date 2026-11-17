extends SceneTree
## Explicit terminal fault fixture, based on the installed Zhu goal contract.

var failures := []
var facts := {}
var checks := 0
var mode: String
var flow: Node
var campaign: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("[settlement] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
	return ok

func _run() -> void:
	mode = OS.get_environment("ZHU_SETTLEMENT_STAGE")
	var profile := OS.get_environment("APPDATA").replace("\\","/").to_lower()
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/zhu-settlement-") \
			or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	flow = root.get_node("ContinueFlow")
	campaign = root.get_node("Campaign")
	await process_frame
	for tick in range(300):
		if not flow.busy() or flow.phase == flow.Phase.ERROR: break
		await process_frame
	if not check(flow.last_result.get("ok",false) and flow.last_result.get("startup_checked",false),
			"installed startup completes"):
		facts["error"] = String(flow.last_result.get("code",""))
		_finish()
		return
	var trusted: Dictionary = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	facts["identity"] = trusted.get("content_version","")
	if mode == "produce":
		await _produce(trusted)
	else:
		_readback(trusted)
	_finish()

func _produce(trusted: Dictionary) -> void:
	if not check(campaign.level_record("level3").best_done == 0, "fixture starts without Zhu progression"): return
	campaign.current = 2
	var battle = load("res://scenes/main.tscn").instantiate()
	var configured: Dictionary = battle.configure_new_gameplay_rng(trusted,5088120)
	if not check(configured.get("ok",false), "battle configured with installed identity"):
		battle.free()
		return
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle._on_start_battle()
	if not check(battle.phase == battle.Phase.FIGHT and battle._official_context.level_id == "level3",
			"fixture uses a real official Zhu battle"):
		return
	var cfg = load("res://scripts/run_campaign_cfg_transaction.gd").new()
	var blocker: String = cfg.directory.path_join("qa_blocker")
	if not check(DirAccess.make_dir_recursive_absolute(blocker.get_base_dir()) == OK,
			"private journal directory prepared"): return
	var file := FileAccess.open(blocker,FileAccess.WRITE)
	if not check(file != null,"obstruction created in empty private profile"): return
	file.store_string("controlled-qa-cfg-obstruction")
	file.close()
	for event in ["zhu_hu_captured","zhu_gate_opened","zhu_seven_safe"]:
		battle.mission.mark(event,"")
	var reported: Array[Dictionary] = []
	flow.operation_finished.connect(func(value: Dictionary): reported.append(value),CONNECT_ONE_SHOT)
	battle.win("QA controlled Zhu victory fixture.")
	for tick in range(300):
		if not reported.is_empty(): break
		await process_frame
	if not check(not reported.is_empty(),"terminal coordinator reported the write failure"): return
	var result := reported[0]
	facts["error"] = String(result.get("code",""))
	check(not result.get("ok",false) and result.get("code") == "UNKNOWN_FILE"
		and result.get("terminal_pending",false) and paused,
		"obstructed progress holds actual terminal completion")
	check(campaign.level_record("level3").best_done == 0,"progress has not been awarded before process termination")
	var scanner: Script = load("res://scripts/run_campaign_startup_scan.gd")
	var catalog: Dictionary = scanner.scan(trusted,campaign.cloud_owner)
	check(catalog.get("ok",false) and catalog.pending.size() == 1
		and catalog.pending[0].intent.result.story_done == 3,"one durable pending victory record exists")
	facts["pending"] = catalog.get("pending",[]).size()

func _readback(trusted: Dictionary) -> void:
	var expected := 1 if mode == "recover" else 0
	check(flow.last_result.get("progress_recovered",-1) == expected
		and flow.last_result.get("settlement_authorized",true) == false,
		"ordinary startup recovery count and settlement policy match")
	var record: Dictionary = campaign.level_record("level3")
	check(record.cleared and record.story_complete and record.best_done == 3 and campaign.unlocked == 4,
		"disk-backed Zhu progression and all three goals are loaded")
	var scanner: Script = load("res://scripts/run_campaign_startup_scan.gd")
	var catalog: Dictionary = scanner.scan(trusted,campaign.cloud_owner)
	check(catalog.get("ok",false) and catalog.pending.is_empty() and catalog.historical.size() == 1
		and catalog.historical[0].get("already_applied",false),"single applied record with no replay pending")
	facts["recovered"] = flow.last_result.get("progress_recovered",-1)
	facts["progress_sha256"] = FileAccess.get_sha256("user://campaign.cfg")
	facts["goals"] = record.best_goal_ids
	facts["unlocked"] = campaign.unlocked
	if catalog.get("ok",false) and catalog.historical.size() == 1:
		facts["receipt_sha256"] = JSON.stringify(catalog.historical[0].progress_receipt).sha256_text()

func _finish() -> void:
	print("ZHU_SETTLEMENT_RESULT ",JSON.stringify({"mode":mode,"checks":checks,"failures":failures,"facts":facts,"pid":OS.get_process_id()}))
	if mode == "produce" and failures.is_empty():
		return # Host terminates this exact held process.
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)
