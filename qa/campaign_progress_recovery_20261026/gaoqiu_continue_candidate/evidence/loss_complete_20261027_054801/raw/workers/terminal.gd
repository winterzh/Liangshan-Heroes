extends "base.gd"
## Natural defeat requires its own strict terminal protocol, never victory fallback.
const GOALS := ["gao_lure", "gao_fire", "gao_land", "gao_capture"]
var loss_baseline: Dictionary = {}

func campaign_memory() -> Dictionary:
	var campaign: Node = get_node("/root/Campaign")
	return {"records":campaign.records.duplicate(true), "unlocked":campaign.unlocked, "owner":campaign.cloud_owner}

func observe_saved_slot(operation: Dictionary) -> void:
	super.observe_saved_slot(operation)
	loss_baseline = {"cfg":cfg_snapshot(), "campaign_memory":campaign_memory(), "rewards":rewards_snapshot()}
	check(loss_baseline.campaign_memory.records.is_empty() and loss_baseline.campaign_memory.unlocked == 1,
		"saved fresh profile has no campaign completion or fabricated unlocks")

func read_predecessor() -> bool:
	if not super.read_predecessor(): return false
	var exact: Dictionary = Codec.new().decode(prior.get("exact_loss_baseline", {}))
	if not check(exact.ok and typeof(exact.get("value")) == TYPE_DICTIONARY,
		"loss baseline retains exact typed CFG memory and rewards across processes"): return false
	loss_baseline = exact.value
	return check(loss_baseline.has_all(["cfg", "campaign_memory", "rewards"]), "predecessor includes original loss baseline")

func verify_ack(life: Dictionary, cfg: Dictionary, label: String) -> Dictionary:
	var document: Dictionary = life.get("document", {})
	var intent: Dictionary = document.get("intent", {})
	var ack: Dictionary = document.get("progress_receipt", {})
	var scope: Dictionary = {"owner":"", "content_version":trusted.content_version, "engine_sha256":trusted.engine_binary_sha256}
	var bound: bool = document.get("schema") == "local_campaign_continue_lifecycle_v3" and document.get("generation") == 3 \
		and document.get("state") == "terminal" and document.get("progress_state") == "applied" and document.get("victory") == false \
		and document.get("scope") == scope and document.get("context") == Profiles.GAO_CONTEXT \
		and Intent.fields(intent, Intent.FIELDS) and intent.get("schema") == "campaign_progress_intent_v2" \
		and intent.get("token") == life.token and intent.get("context") == Profiles.GAO_CONTEXT \
		and intent.get("profile_id") == Profiles.GAO_ID and intent.get("owner") == "" and intent.get("victory") == false \
		and intent.get("content_version") == trusted.content_version and intent.get("engine_sha256") == trusted.engine_binary_sha256 \
		and intent.get("credit") == {"kind":"uncredited"}
	if not check(bound, label + ": strict current loss lifecycle and Intent scope"): return {}
	var intent_sha: String = JSON.stringify(intent).sha256_text()
	var proof: Dictionary = {"schema":"campaign_uncredited_handoff_v1", "token":life.token,
		"context":Profiles.GAO_CONTEXT.duplicate(true), "intent_sha256":intent_sha}
	var expected: Dictionary = {"schema":"campaign_progress_ack_v2", "code":"CAMPAIGN_PROGRESS_NOT_REQUIRED",
		"persisted":false, "suppressed":false, "file_sha256":"", "steam_handoff":proof}
	if not check(ack == expected, label + ": loss ACK has NOT_REQUIRED, no CFG commit and exact uncredited proof"): return {}
	var inspected: Dictionary = get_node("/root/SteamService").inspect_campaign_handoff(intent)
	check(inspected == {"ok":true, "proof":proof}, label + ": independent actual uncredited handoff inspection")
	check(cfg_snapshot() == cfg, label + ": handoff inspection preserves CFG existence and exact bytes")
	return {"intent_sha256":intent_sha, "ack":ack.duplicate(true), "service_inspection":inspected.duplicate(true)}

func await_loss_terminal() -> bool:
	var deadline: int = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		if battle.phase == B.Phase.END and not flow.busy() and flow.last_result.get("terminal_completed", false) \
			and flow.last_result.get("campaign_progress_committed", false) and battle.hud._end_root.visible: break
		if flow.last_result.get("terminal_pending", false): break
		await get_tree().process_frame
	observations["terminal_flow"] = flow.last_result.duplicate(true)
	return check(battle.phase == B.Phase.END and not battle.mission.has_event("gao_basic_victory") and not battle.mission.has_event("gao_captured") and not flow.busy() \
		and flow.last_result.get("ok", false) and flow.last_result.get("terminal_completed", false) \
		and flow.last_result.get("campaign_progress_committed", false) and battle.hud._end_root.visible,
		"natural defeat finishes actual asynchronous transaction and visible end HUD")

func verify_loss_terminal(original_receipt: Variant, full_result: Dictionary, prior_metrics: Array) -> bool:
	check(battle._continue_receipt == original_receipt and original_receipt.token == checkpoint.binding.token,
		"natural defeat retains original saved lifecycle object and token")
	var life: Dictionary = life_capture(original_receipt)
	if life.is_empty(): return false
	var chain: Array = []
	for generation: int in range(1, 4):
		var record: Dictionary = original_receipt._verified("record_%010d.json" % generation)
		if not check(record.ok and record.revision == generation and record.document.token == checkpoint.binding.token,
			"loss retains original lifecycle generation %d" % generation): return false
		chain.append(record)
	check(chain[0].file_sha256 == checkpoint.lifecycle.file_sha256 and chain[0].document == checkpoint.lifecycle.document,
		"defeat retains exact active gen1 from actual saved exit")
	check(chain[1].previous == chain[0].file_sha256 and chain[2].previous == chain[1].file_sha256 \
		and chain[1].document.progress_state == "pending" and chain[1].document.progress_receipt.is_empty() \
		and not chain[1].document.victory and not chain[2].document.victory \
		and chain[1].document.intent == chain[2].document.intent, "loss gen1/gen2/gen3 has one unchanged frozen intent")
	if not check(full_result.has_all(["core_cleared", "story_complete", "story_done", "story_total", "done_ids", "contract_version",
		"goals", "core_goal", "missed_ids", "pending_ids"]) and full_result.contract_version == 3 \
		and not full_result.core_cleared and not full_result.story_complete and full_result.story_total == 4 \
		and full_result.goals.size() == 4 and full_result.story_done == full_result.done_ids.size(),
		"actual frozen loss preserves all four contract3 goal details without awarding core or full story"): return false
	var classified: Array = []
	for index: int in range(GOALS.size()):
		var row: Dictionary = full_result.goals[index]
		var actual_ids: Array = []
		if row.state == "done": actual_ids = full_result.done_ids
		elif row.state == "missed": actual_ids = full_result.missed_ids
		elif row.state == "pending": actual_ids = full_result.pending_ids
		check(row.id == GOALS[index] and actual_ids.has(row.id), "loss retains actual state for " + GOALS[index])
		classified.append(row.id)
	check(full_result.done_ids.size() + full_result.missed_ids.size() + full_result.pending_ids.size() == classified.size(),
		"loss goal classifications cover the complete four-goal snapshot")
	for key: String in Intent.RESULT_FIELDS:
		check(life.document.intent.result[key] == full_result[key], "loss durable projection matches actual result " + key)
	var cfg: Dictionary = cfg_snapshot()
	var rewards: Dictionary = rewards_snapshot()
	var memory: Dictionary = campaign_memory()
	check(cfg == loss_baseline.cfg and memory == loss_baseline.campaign_memory and rewards == loss_baseline.rewards,
		"natural loss preserves original CFG bytes or absence and adds no record unlock or reward")
	check(memory.records.is_empty() and memory.unlocked == 1 and memory.owner == "", "fresh loss profile remains uncleared and uncredited")
	var handoff: Dictionary = verify_ack(life, cfg, "natural defeat")
	if handoff.is_empty(): return false
	var slot: Dictionary = Store.new(SLOT).read_slot()
	check(slot.ok and slot.revision == 1 and slot.file_sha256 == checkpoint.file_sha256 \
		and slot.document.binding == checkpoint.binding, "defeat preserves original gen1 active slot unchanged")
	var metrics: Array = battle.mission.stage_metrics.duplicate(true)
	check(battle.mission._metrics_closed and metrics.size() == prior_metrics.size() + 1 \
		and metrics.slice(0, prior_metrics.size()) == prior_metrics and metrics.back().end_reason == "defeat",
		"actual mission metrics close exactly once with defeat")
	terminal_checkpoint = {"lifecycle":life, "cfg":cfg, "handoff_validation":handoff,
		"slot_sha256":slot.get("file_sha256", ""), "slot_binding":slot.get("document", {}).get("binding", {}),
		"campaign_memory":memory, "rewards":rewards, "full_result":full_result.duplicate(true), "journal":chain, "metrics":metrics}
	var rows: Array = battle.mission.report.duplicate(true)
	var end_text: String = battle.hud._end_tally.text
	for frame: int in range(20): await get_tree().process_frame
	check(life_capture(original_receipt) == life and cfg_snapshot() == cfg and rewards_snapshot() == rewards \
		and campaign_memory() == memory and battle.mission.stage_metrics == metrics and battle.mission.report == rows \
		and battle.hud._end_tally.text == end_text, "settled defeat does not repeat progress proof metrics or end report")
	return failures.is_empty()

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
	var exact_baseline: Dictionary = Codec.new().encode(loss_baseline)
	check(exact.ok and exact_opening.ok and exact_terminal.ok and exact_baseline.ok, "reports retain exact typed checkpoints through production Codec")
	var lifecycle: Node = get_node("/root/AppLifecycle")
	var result: Dictionary = {"schema":"campaign_gaoqiu_loss_v1", "mode":mode, "passed":stage_completed and failures.is_empty(),
		"stage_completed":stage_completed, "checks":checks, "failures":failures, "observations":observations, "actions":action_evidence,
		"identity":identity_row(), "pid":OS.get_process_id(), "batch_nonce":OS.get_environment("GLS_NONCE"),
		"process_nonce":OS.get_environment("GLS_PROCESS_NONCE"), "exit_reason":lifecycle.quit_reason(),
		"save_exit_observed":save_exit_owned and save_report_ready and lifecycle.quit_started() and lifecycle.quit_reason() == "continue_saved",
		"profile":OS.get_environment("GLS_PROFILE"), "slot_root":SLOT, "checkpoint":checkpoint, "opening":opening,
		"loss_baseline":loss_baseline, "exact_loss_baseline":exact_baseline.get("value"),
		"terminal_checkpoint":terminal_checkpoint, "exact_checkpoint":exact.get("value"), "exact_opening":exact_opening.get("value"), "exact_terminal":exact_terminal.get("value"),
		"candidate_manifest_sha256":OS.get_environment("GLS_CANDIDATE_SHA256"),
		"sources_sha256":OS.get_environment("GLS_SOURCES_SHA256"),
		"natural_loss_required":true, "full_story_required":false, "no_gameplay_state_injection":true, "simulation_time_scale":Engine.time_scale, "physics_hz":Engine.physics_ticks_per_second,
		"public_continue_qualified":false, "native_sdk_qualified":false, "native_release_tested":false,
		"human_acceptance":false, "victory_chain_qualified":false}
	var file: FileAccess = FileAccess.open(OS.get_environment("GLS_REPORT"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok: get_tree().quit(2); return
	if not exit_process: return
	get_node("/root/Sfx").shutdown(); get_node("/root/Music").shutdown()
	get_tree().quit(0 if result.passed else 1)

