extends "base.gd"
## Strict current offline Level5 terminal contract; no legacy protocol fallback.
const GOALS := ["gao_lure", "gao_fire", "gao_land", "gao_capture"]

func cfg_snapshot() -> Dictionary:
	var path: String = get_node("/root/Campaign").SAVE_PATH
	if not FileAccess.file_exists(path): return {"exists":false, "path":path, "sha256":"", "sections":{}}
	var before: String = FileAccess.get_sha256(path)
	var cfg := ConfigFile.new()
	check(cfg.load(path) == OK, "actual campaign CFG independently loads")
	var sections: Dictionary = {}
	for name: String in cfg.get_sections():
		var values: Dictionary = {}
		for key: String in cfg.get_section_keys(name): values[key] = cfg.get_value(name, key)
		sections[name] = values
	check(FileAccess.get_sha256(path) == before, "CFG read preserves exact bytes")
	return {"exists":true, "path":path, "sha256":before, "sections":sections}

func rewards_snapshot() -> Dictionary:
	var service: Node = get_node("/root/SteamService")
	check(not service.available and not service.stats_ready and service._active_run == 0
		and service._run_counter == 0 and service._local_runs == null, "Steam-disabled service has no credited run or native ledger")
	return {"stats":service.state.stats.duplicate(true), "unlocked":service.state.unlocked.duplicate(true),
		"settled":service.state.settled.duplicate(true), "active_run":service._active_run, "run_counter":service._run_counter}

func life_capture(receipt: Variant) -> Dictionary:
	check(receipt != null and receipt.get_script() == Lifecycle, "actual campaign lifecycle script retained")
	if receipt == null or receipt.get_script() != Lifecycle: return {}
	var head: Dictionary = receipt.open_head()
	check(head.ok, "actual lifecycle chain reads")
	if not head.ok: return {}
	var owner: String = get_node("/root/Campaign").cloud_owner
	var scope: Dictionary = {"owner":owner, "content_version":trusted.content_version, "engine_sha256":trusted.engine_binary_sha256}
	check(owner.is_empty() and head.document.schema == Lifecycle.CAMPAIGN_SCHEMA
		and head.document.context == Profiles.GAO_CONTEXT and head.document.scope == scope
		and receipt.matches_scope(Profiles.GAO_CONTEXT, trusted, owner), "Level5 lifecycle binds actual context owner content and engine")
	var inventory: Dictionary = receipt.inventory()
	check(inventory.ok, "lifecycle inventory reads without recovery or writes")
	return {"directory":receipt.directory, "token":receipt.token, "file_sha256":head.file_sha256,
		"generation":int(head.revision), "document":head.document.duplicate(true), "inventory":inventory.get("items", {}).duplicate(true)}

func verify_ack(life: Dictionary, cfg: Dictionary, label: String) -> Dictionary:
	var document: Dictionary = life.get("document", {})
	var intent: Dictionary = document.get("intent", {})
	var ack: Dictionary = document.get("progress_receipt", {})
	var expected_scope: Dictionary = {"owner":"", "content_version":trusted.content_version, "engine_sha256":trusted.engine_binary_sha256}
	var bound: bool = document.get("schema") == "local_campaign_continue_lifecycle_v3" and document.get("generation") == 3 \
		and document.get("state") == "terminal" and document.get("progress_state") == "applied" and document.get("victory") == true \
		and document.get("scope") == expected_scope and document.get("context") == Profiles.GAO_CONTEXT \
		and Intent.fields(intent, Intent.FIELDS) and intent.get("schema") == "campaign_progress_intent_v2" \
		and intent.get("token") == life.token and intent.get("context") == Profiles.GAO_CONTEXT \
		and intent.get("profile_id") == Profiles.GAO_ID and intent.get("owner") == "" and intent.get("victory") == true \
		and intent.get("content_version") == trusted.content_version and intent.get("engine_sha256") == trusted.engine_binary_sha256 \
		and intent.get("credit") == {"kind":"uncredited"}
	if not check(bound, label + ": exact LCv3/Intentv2 offline Level5 scope and credit"): return {}
	if not check(cfg.get("exists", false) and Intent.hex(cfg.get("sha256"), 64), label + ": real durable CFG exists"): return {}
	var intent_sha: String = JSON.stringify(intent).sha256_text()
	var proof: Dictionary = {"schema":"campaign_uncredited_handoff_v1", "token":life.token,
		"context":Profiles.GAO_CONTEXT.duplicate(true), "intent_sha256":intent_sha}
	var expected: Dictionary = {"schema":"campaign_progress_ack_v2", "code":"CAMPAIGN_CFG_READBACK_VERIFIED",
		"persisted":true, "suppressed":false, "file_sha256":cfg.sha256, "steam_handoff":proof}
	if not check(ack == expected, label + ": exact ACKv2 binds CFG and same-token uncredited proof"): return {}
	var inspected: Dictionary = get_node("/root/SteamService").inspect_campaign_handoff(intent)
	check(inspected == {"ok":true, "proof":proof}, label + ": independent service handoff inspection")
	check(FileAccess.get_sha256(cfg.path) == cfg.sha256, label + ": inspection preserves CFG bytes")
	return {"intent_sha256":intent_sha, "ack":ack.duplicate(true), "service_inspection":inspected.duplicate(true)}

func await_terminal() -> bool:
	var terminal_flow: Node = get_node("/root/ContinueFlow")
	var deadline: int = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		if battle.phase == B.Phase.END and not terminal_flow.busy() and terminal_flow.last_result.get("terminal_completed", false) \
			and terminal_flow.last_result.get("campaign_progress_committed", false) and battle.hud._end_root.visible: break
		if terminal_flow.last_result.get("terminal_pending", false): break
		await get_tree().process_frame
	observations["terminal_flow"] = terminal_flow.last_result.duplicate(true)
	return check(battle.phase == B.Phase.END and (battle.mission.has_event("gao_basic_victory") or battle.mission.has_event("gao_captured")) and not terminal_flow.busy() \
		and terminal_flow.last_result.get("ok", false) and terminal_flow.last_result.get("terminal_completed", false) \
		and terminal_flow.last_result.get("campaign_progress_committed", false) and battle.hud._end_root.visible,
		"natural victory completes asynchronous transaction and visible end HUD")

func verify_terminal(original_receipt: Variant, full_result: Dictionary, prior_metrics: Array) -> bool:
	check(battle._continue_receipt == original_receipt and original_receipt.token == checkpoint.binding.token,
		"natural terminal retains saved lifecycle object and token")
	var life: Dictionary = life_capture(original_receipt)
	if life.is_empty(): return false
	check(life.generation == 3 and life.document.victory and life.document.progress_state == "applied", "natural lifecycle applied gen3")
	var chain: Array = []
	for generation: int in range(1, 4):
		var record: Dictionary = original_receipt._verified("record_%010d.json" % generation)
		if not check(record.ok and record.revision == generation and record.document.token == checkpoint.binding.token,
			"same-token original lifecycle generation %d" % generation): return false
		chain.append(record)
	check(chain[0].file_sha256 == checkpoint.lifecycle.file_sha256 and chain[0].document == checkpoint.lifecycle.document,
		"terminal retains exact active gen1 previously saved in both processes")
	check(chain[1].previous == chain[0].file_sha256 and chain[2].previous == chain[1].file_sha256 \
		and chain[1].document.progress_state == "pending" and chain[1].document.progress_receipt.is_empty() \
		and chain[1].document.intent == chain[2].document.intent, "gen1/gen2/CFG/handoff/gen3 retains one frozen intent")
	var intent: Dictionary = life.document.intent
	for key: String in Intent.RESULT_FIELDS:
		check(intent.result[key] == full_result[key], "durable projection retains real result " + key)
	if not check(full_result.has_all(["core_cleared", "story_complete", "story_done", "story_total", "done_ids", "contract_version",
		"goals", "core_goal", "missed_ids", "pending_ids"]) and full_result.contract_version == 3 and full_result.core_cleared
		and full_result.story_total == 4 and full_result.goals.size() == 4 and full_result.story_done == full_result.done_ids.size()
		and full_result.story_complete == (full_result.story_done == 4) and full_result.pending_ids.is_empty(),
		"full natural Level5 core victory retains all contract3 goal details and final classifications"): return false
	var classified: Array = []
	for index: int in range(GOALS.size()):
		var row: Dictionary = full_result.goals[index]
		var ids: Array = full_result.done_ids if row.state == "done" else full_result.missed_ids if row.state == "missed" else []
		check(row.id == GOALS[index] and ids.has(row.id) and not classified.has(row.id), "actual optional-goal terminal state: " + GOALS[index])
		classified.append(row.id)
	check(full_result.done_ids.size() + full_result.missed_ids.size() == 4,
		"core win neither requires nor fabricates optional capture or four-goal completion")

	var cfg: Dictionary = cfg_snapshot()
	var handoff: Dictionary = verify_ack(life, cfg, "natural terminal")
	if handoff.is_empty(): return false
	var reader := ConfigFile.new()
	check(reader.load(cfg.path) == OK and Intent.cfg_dominates(reader, intent), "actual CFG contains natural Level5 outcome")
	var progress: Dictionary = cfg.sections.get("progress", {})
	var record: Dictionary = progress.get("records", {}).get("level5", {})
	check(progress.get("schema") == 2 and progress.get("owner") == "" and progress.get("unlocked") == 6
		and record.get("cleared", false) and record.get("story_complete") == full_result.story_complete
		and record.get("best_done") == full_result.story_done and record.get("story_total") == 4
		and record.get("best_goal_ids") == full_result.done_ids and record.get("contract_version") == 3
		and progress.get("records", {}).size() == 1, "fresh CFG records exact Level5 core outcome and actual optional goals, unlocking six")
	var campaign: Node = get_node("/root/Campaign")
	check(campaign.records == progress.get("records") and campaign.unlocked == 6 and campaign.cloud_owner == "",
		"campaign memory agrees with actual durable CFG")
	check(rewards_snapshot() == opening.baseline.rewards, "offline core victory grants no native credited Steam reward")
	var metrics: Array = battle.mission.stage_metrics.duplicate(true)
	check(battle.mission._metrics_closed and metrics.size() == prior_metrics.size() + 1
		and metrics.slice(0, prior_metrics.size()) == prior_metrics and metrics.back().end_reason == "victory",
		"actual mission metrics close exactly once through original victory")

	var slot: Dictionary = Store.new(SLOT).read_slot()
	check(slot.ok and slot.file_sha256 == checkpoint.file_sha256 and slot.revision == 2 \
		and slot.document.binding == checkpoint.binding, "terminal preserves last original active slot and binding")
	terminal_checkpoint = {"lifecycle":life, "cfg":cfg, "handoff_validation":handoff,
		"slot_sha256":slot.get("file_sha256", ""), "slot_binding":slot.get("document", {}).get("binding", {}),
		"campaign_memory":{"records":campaign.records.duplicate(true), "unlocked":campaign.unlocked, "owner":campaign.cloud_owner},
		"rewards":rewards_snapshot(), "full_result":full_result.duplicate(true), "journal":chain, "metrics":metrics}
	var metric_rows: Array = battle.mission.report.duplicate(true)
	var before_end: String = battle.hud._end_tally.text
	for frame: int in range(20): await get_tree().process_frame
	check(life_capture(original_receipt) == life and cfg_snapshot() == cfg and rewards_snapshot() == terminal_checkpoint.rewards \
		and battle.mission.report == metric_rows and battle.mission.stage_metrics == metrics and battle.hud._end_tally.text == before_end,
		"settled scene does not repeat CFG handoff rewards metrics or end report")
	return failures.is_empty()

func reject_terminal() -> void:
	var expected: Dictionary = terminal_checkpoint.duplicate(true)
	check(int(startup_observation.get("progress_recovered", -1)) == 0 and not startup_observation.get("settlement_authorized", true),
		"independent startup does not replay or authorize applied settlement")
	var campaign: Node = get_node("/root/Campaign")
	var catalog: Dictionary = Startup.scan(trusted, campaign.cloud_owner)
	if not check(catalog.ok and catalog.pending.is_empty() and catalog.active.is_empty() and catalog.historical.size() == 1 \
		and catalog.historical[0].token == expected.lifecycle.token and catalog.historical[0].model == Lifecycle.CAMPAIGN_SCHEMA \
		and catalog.historical[0].get("already_applied", false), "startup classifies original gen3 as applied history"): return
	var receipt: Variant = Lifecycle.new(expected.lifecycle.token, SLOT, Profiles.GAO_CONTEXT, trusted, campaign.cloud_owner)
	var before: Dictionary = life_capture(receipt)
	var cfg: Dictionary = cfg_snapshot()
	var rewards: Dictionary = rewards_snapshot()
	var handoff: Dictionary = verify_ack(before, cfg, "independent restart")
	check(before == expected.lifecycle and cfg == expected.cfg and rewards == expected.rewards \
		and handoff == expected.handoff_validation, "independent process preserves exact lifecycle CFG reward and proof")
	check(campaign.records == expected.campaign_memory.records and campaign.unlocked == expected.campaign_memory.unlocked \
		and campaign.cloud_owner == expected.campaign_memory.owner, "restart loads exact records and unlock count without growth")
	var store := Store.new(SLOT)
	var slot: Dictionary = store.read_slot()
	check(slot.ok and slot.file_sha256 == expected.slot_sha256 and slot.document.binding == expected.slot_binding,
		"same physical original active slot remains present")
	if not failures.is_empty(): return
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child(menu); get_tree().current_scene = menu
	await get_tree().process_frame
	flow_received = false
	var entry: Variant = menu.find_child("ContinueBattle", true, false)
	if not await reveal_button(entry) or not press_button(entry, "continue ended Level5 from actual menu"): return
	if not await wait_flow(): return
	var refused: Dictionary = flow_result.duplicate(true)
	check(not refused.get("ok", false) and refused.get("code") == "LOCAL_RUN_TERMINAL", "actual menu ContinueFlow rejects terminal token before installing old slot")
	check(get_tree().current_scene == menu and flow.phase == flow.Phase.ERROR
		and get_tree().root.get_children().all(func(node): return node.get_script() != B), "terminal refusal leaves real menu, error overlay and no reconstructed Battle")
	observations["terminal_refusal"] = refused.duplicate(true)
	await get_tree().process_frame
	if not press_button(flow.find_child("CloseError", true, false), "dismiss actual terminal refusal"): return
	check(not flow.busy() and get_tree().current_scene == menu, "visible return button closes refusal to the same menu")
	for frame: int in range(10): await get_tree().process_frame
	var after: Dictionary = store.read_slot()
	check(after.ok and after.document == slot.document and after.file_sha256 == slot.file_sha256,
		"rejection does not rewrite migrate or delete original slot")
	check(life_capture(receipt) == before and cfg_snapshot() == cfg and rewards_snapshot() == rewards \
		and verify_ack(life_capture(receipt), cfg_snapshot(), "after rejection") == handoff,
		"rejection preserves lifecycle CFG rewards and independently inspected proof")
	check(not flow.last_result.get("terminal_completed", false) and not flow.last_result.get("settlement_authorized", false),
		"restart rejection has no live completion or reward authorization")
	stage_completed = failures.is_empty()

func finish(exit_process := true) -> void:
	var end_identity: Dictionary = Provider.new().resolve_runtime_identity()
	check(end_identity.get("save_eligible", false) and end_identity.get("source_mode", false) \
		and end_identity.get("content_version") == trusted.get("content_version") \
		and end_identity.get("engine_binary_sha256") == trusted.get("engine_binary_sha256"), "final executed source and engine identity unchanged")
	check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "normal clock remains 1x and 60Hz")
	var exact: Dictionary = Codec.new().encode(checkpoint)
	var exact_opening: Dictionary = Codec.new().encode(opening)
	var exact_terminal: Dictionary = Codec.new().encode(terminal_checkpoint)
	check(exact.ok and exact_opening.ok and exact_terminal.ok, "reports retain exact typed checkpoints through production Codec")
	var lifecycle: Node = get_node("/root/AppLifecycle")
	var result: Dictionary = {"schema":"campaign_gaoqiu_terminal_v1", "mode":mode, "passed":stage_completed and failures.is_empty(),
		"stage_completed":stage_completed, "checks":checks, "failures":failures, "observations":observations, "actions":action_evidence,
		"identity":identity_row(), "pid":OS.get_process_id(), "batch_nonce":OS.get_environment("GVT_NONCE"),
		"process_nonce":OS.get_environment("GVT_PROCESS_NONCE"), "exit_reason":lifecycle.quit_reason(),
		"save_exit_observed":save_exit_owned and save_report_ready and lifecycle.quit_started() and lifecycle.quit_reason() == "continue_saved",
		"profile":OS.get_environment("GVT_PROFILE"), "slot_root":SLOT, "checkpoint":checkpoint, "opening":opening,
		"terminal_checkpoint":terminal_checkpoint, "exact_checkpoint":exact.get("value"), "exact_opening":exact_opening.get("value"), "exact_terminal":exact_terminal.get("value"),
		"candidate_manifest_sha256":OS.get_environment("GVT_CANDIDATE_SHA256"),
		"sources_sha256":OS.get_environment("GVT_SOURCES_SHA256"),
		"natural_core_victory_required":true, "full_story_required":false, "no_gameplay_state_injection":true, "simulation_time_scale":Engine.time_scale, "physics_hz":Engine.physics_ticks_per_second,
		"public_continue_qualified":false, "native_sdk_qualified":false, "native_release_tested":false,
		"human_acceptance":false, "defeat_chain_qualified":false}
	var file: FileAccess = FileAccess.open(OS.get_environment("GVT_REPORT"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok: get_tree().quit(2); return
	if not exit_process: return
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if result.passed else 1)


func observe_saved_slot(operation: Dictionary) -> void:
	super.observe_saved_slot(operation)
	check(cfg_snapshot() == opening.baseline.cfg and rewards_snapshot() == opening.baseline.rewards
		and get_node("/root/Campaign").records.is_empty() and get_node("/root/Campaign").unlocked == 1,
		"both active saves precede progress settlement and preserve original CFG and rewards")
