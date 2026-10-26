extends "base.gd"
## Independent OS process, same private profile and original terminalized slot.
func _run() -> void:
	check(OS.get_environment("CH_MODE") == "reject_terminal", "independent terminal rejection worker mode")
	if not identity(OS.get_environment("CH_SOURCE_MODE") != "0"): report(); return
	var previous: String = OS.get_environment("CH_PREVIOUS")
	check(FileAccess.get_sha256(previous) == OS.get_environment("CH_PREVIOUS_SHA256"), "exact natural-terminal predecessor report bytes")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(previous))
	check(typeof(parsed) == TYPE_DICTIONARY, "predecessor is an actual report object")
	if typeof(parsed) != TYPE_DICTIONARY: report(); return
	var prior: Dictionary = parsed
	check(prior.get("schema") == "campaign_huang_terminal_v1" and prior.get("passed", false)
		and prior.get("mode") == "natural_terminal" and prior.get("batch_nonce") == OS.get_environment("CH_NONCE")
		and prior.get("profile") == OS.get_environment("CH_PROFILE") and prior.get("slot_root") == SLOT,
		"successful predecessor has the same batch profile and fixed slot")
	check(int(prior.get("pid", 0)) > 0 and int(prior.get("pid", 0)) != OS.get_process_id(), "consumer is an independent real process")
	check(prior.get("trusted_identity", {}).get("content_version") == trusted.content_version
		and prior.get("trusted_identity", {}).get("engine_binary_sha256") == trusted.engine_binary_sha256
		and prior.get("trusted_identity", {}).get("source_mode") == trusted.source_mode, "consumer executes exact predecessor content and engine mode")
	var exact: Dictionary = Codec.new().decode(prior.get("exact_terminal", {}))
	check(exact.ok and typeof(exact.get("value")) == TYPE_DICTIONARY, "terminal checkpoint retains exact typed production data")
	if not failures.is_empty(): report(); return
	var expected: Dictionary = exact.value
	var startup_ok: bool = await wait_startup()
	if not startup_ok: report(); return
	check(int(startup_observation.get("progress_recovered", -1)) == 0 and not startup_observation.get("settlement_authorized", true),
		"restart does not replay or authorize settlement for an applied terminal")
	var campaign: Node = root.get_node("Campaign")
	var catalog: Dictionary = load("res://scripts/run_campaign_startup_scan.gd").scan(trusted, campaign.cloud_owner)
	check(catalog.ok and catalog.pending.is_empty() and catalog.active.is_empty() and catalog.historical.size() == 1
		and catalog.historical[0].token == expected.lifecycle.token and catalog.historical[0].model == Lifecycle.CAMPAIGN_SCHEMA
		and catalog.historical[0].get("already_applied", false), "real startup catalog classifies the same gen3 token as applied history")
	var receipt: Variant = Lifecycle.new(expected.lifecycle.token, SLOT, Profiles.HG_CONTEXT, trusted, campaign.cloud_owner)
	var life_before: Dictionary = lifecycle_row(receipt)
	var cfg_before: Dictionary = cfg_snapshot()
	var rewards_before: Dictionary = rewards_snapshot()
	var handoff_before: Dictionary = verify_terminal_ack(life_before, cfg_before, "independent restart gen3")
	check(not handoff_before.is_empty() and handoff_before == expected.get("handoff_validation", {}),
		"restart independently inspects the exact predecessor ACK and uncredited handoff proof")
	check(life_before == expected.lifecycle and cfg_before == expected.cfg and rewards_before == expected.rewards,
		"restart preserves lifecycle CFG and native reward state exactly")
	check(campaign.records == expected.campaign_memory.records and campaign.unlocked == expected.campaign_memory.unlocked
		and campaign.cloud_owner == expected.campaign_memory.owner, "restart loads the same full records and unlock count without growth")
	var store := Store.new(SLOT)
	var slot_before: Dictionary = store.read_slot()
	check(slot_before.ok and slot_before.file_sha256 == expected.slot_sha256 and slot_before.document.binding == expected.slot_binding,
		"original active slot survives terminal without replacement")
	if not failures.is_empty(): report(); return
	get_tree().paused = true
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	await get_tree().process_frame
	var runtime: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(runtime.ok, "installed Huangnigang runtime prepares without starting battle")
	if not runtime.ok: report(); return
	owned_session = Session.new(trusted, runtime.runtime, SLOT)
	var refused: Dictionary = owned_session.prepare_restore(menu)
	check(not refused.get("ok", false) and refused.get("code") == "LOCAL_RUN_TERMINAL",
		"actual Session refuses old active slot whose original token completed")
	check(current_scene == menu and owned_session._core._battle == null,
		"terminal refusal precedes world preparation and leaves menu intact")
	owned_session.dispose(); owned_session = null
	for frame in range(10): await get_tree().process_frame
	var slot_after: Dictionary = store.read_slot()
	check(slot_after.ok and slot_after.file_sha256 == slot_before.file_sha256 and slot_after.document == slot_before.document,
		"rejected restore does not rewrite or migrate the old slot")
	var life_after: Dictionary = lifecycle_row(receipt)
	var cfg_after: Dictionary = cfg_snapshot()
	check(life_after == life_before and cfg_after == cfg_before and rewards_snapshot() == rewards_before,
		"rejected restore preserves lifecycle inventory CFG and reward state")
	var handoff_after: Dictionary = verify_terminal_ack(life_after, cfg_after, "after rejected restore gen3")
	check(not handoff_after.is_empty() and handoff_after == handoff_before,
		"terminal refusal preserves independently re-inspected ACK and uncredited handoff proof")
	check(campaign.records == expected.campaign_memory.records and campaign.unlocked == expected.campaign_memory.unlocked,
		"terminal rejection adds no record progress or unlock reward")
	check(not root.get_node("ContinueFlow").last_result.get("terminal_completed", false)
		and not root.get_node("ContinueFlow").last_result.get("settlement_authorized", false), "independent rejection exposes no live terminal completion")
	terminal_checkpoint = expected.duplicate(true)
	var identity_ok: bool = identity(OS.get_environment("CH_SOURCE_MODE") != "0")
	report({"scope":"Same-profile actual startup and Session terminal refusal without a new world or reward",
		"prepare_restore_result":refused, "startup_catalog":catalog, "same_profile_terminal_rejection_verified":failures.is_empty(),
		"slot_or_profile_copied":false, "direct_terminal_callback_used":false, "identity_gate_passed":identity_ok})
