extends SceneTree
## Headless story/position contracts. Success paths use only task requests and real movement.
## Exposure, timeout and deliberate violence are free-play deviations: they must remain
## winnable through the public force route, but they cannot earn the original-story seal.
const DEFAULT_CASES := ["victory", "identity_recovery", "exposure_failure", "attention_recovery", "handoff_recovery", "attention_timeout", "rest_timeout", "early_violence", "replay"]
const FREE_ROUTE_CASES := ["exposure_failure", "rest_timeout", "early_violence"]
const OBSERVED := ["yang_inquired", "merchant_identity_confirmed", "bai_arrived", "bring_wine", "taste_wine", "distract_yang", "drug_scoop", "reclaim_scoop", "drugged", "suspicion_raised", "suspicion_recovered", "missed_attention", "exposed", "escaped"]
var results: Array = []
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _start():
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == "level1": campaign.current = i
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b._smoke = true
	Engine.time_scale = 4.0
	return b

func _actor_cells(b) -> Dictionary:
	var snapshot := {}
	for key in ["yang_zhi", "liu_tang", "wu_yong", "bai_sheng", "gongsun_sheng"]:
		var u = b.find_unit(key)
		if is_instance_valid(u): snapshot[key] = {"position": [u.position.x, u.position.y], "cell": str(b.map.world_to_cell(u.position))}
	return snapshot

func _event_contract(b, event_id: String) -> bool:
	var l = b.level
	match event_id:
		"yang_inquired": return l._at(b, l.yang, l.INSPECT, 56.0) and b.find_unit("bai_sheng") == null
		# Yang is ordered back to the convoy in this callback and can move one physics step before this observer.
		"merchant_identity_confirmed": return l._at(b, b.find_unit("liu_tang"), l.ANSWER, 40.1) and l._at(b, l.yang, l.INSPECT, 64.0) and l._identity_ready(b)
		"bai_arrived": return b.mission.has_event("merchant_identity_confirmed") and is_instance_valid(b.find_unit("bai_sheng"))
		"bring_wine": return l._at(b, b.find_unit("bai_sheng"), Vector2i(23, 24), 40.1) and not l.sale_drugged
		"taste_wine": return l._at(b, b.find_unit("liu_tang"), l.GOOD_WINE, 40.1) and l.clean_trial and not l.sale_drugged
		"distract_yang": return l._attention_valid(b) and l.clean_trial and l.attention_left > 0.0
		"drug_scoop": return l._at(b, b.find_unit("wu_yong"), l.SALE_WINE, 40.1) and l._attention_valid(b) and l.scoop_prepared and not l.sale_drugged
		"reclaim_scoop": return l._at(b, b.find_unit("bai_sheng"), l.SALE_WINE, 40.1) and l._at(b, b.find_unit("wu_yong"), l.SALE_WINE, 70.0) and l._attention_valid(b) and l.sale_drugged
		"drugged":
			if l.convoy.size() != 15 or b.kills != 0: return false
			for u in l.convoy:
				if not is_instance_valid(u) or u.hp <= 0.0 or u.story_outcome != "unconscious": return false
			return true
	return true

func _drive_force_actions(b) -> void:
	var l = b.level
	if l.st != l.FORCE or b.mission.active_action_id != "": return
	# Let the real battle settle first. All convoy units use a nonlethal story outcome,
	# so this does not inject a victory or resolve an opponent from the fixture.
	if l.convoy.any(func(guard): return is_instance_valid(guard) and guard.hp > 0.0 and guard.story_outcome == ""):
		return
	# Prefer putting down a carried load before assigning another. Action ids carry an
	# attempt suffix because a fallen carrier may drop the same original load for relay.
	for prefix in ["force_deliver_", "force_take_"]:
		for action_id in b.mission.actions.keys():
			if String(action_id).begins_with(prefix) and b.mission.request_action(String(action_id)):
				return

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	var requested := OS.get_environment("HN_QA_CASES")
	var cases: Array = Array(requested.split(",")) if requested != "" else DEFAULT_CASES
	for case_name in cases:
		if not case_name in DEFAULT_CASES:
			push_error("Unknown HN_QA_CASES: " + String(case_name))
			quit(2)
			return
		await _case(String(case_name))
	var output := ProjectSettings.globalize_path("res://qa/campaign_huangnigang")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("tactics_v1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "cases": results, "timing_note": "mission_game_seconds is FIGHT simulation time from CampaignMission. wall_seconds includes stage pauses, excludes intro. Fixed-fps60, time_scale4, automatic known-route driving; not human pacing or performance evidence."}, "\t"))
	file.close()
	Engine.time_scale = 1.0
	print("[hn-summary] ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "evidence": output.path_join("tactics_v1.json")}))
	quit(0 if failures.is_empty() else 1)

func _case(case_name: String) -> void:
	var b = await _start()
	var l = b.level
	var start_fresh: bool = l.st == l.PREPARE and l.exposure == 0.0 and not l.drug_done and not l.sale_drugged and not l.suspicion_seen and l.actors.size() == 7 and l.convoy.is_empty() and l.bundles.size() == 3 and b.find_unit("bai_sheng") == null and b.mission.events.is_empty()
	var bad_order_rejected: bool = not b.mission.request_action("sell_wine") and not b.mission.request_action("drug_scoop") and not b.mission.request_action("reclaim_scoop") and not b.mission.request_action("bring_wine")
	var invariants := start_fresh and bad_order_rejected
	var events := {}
	var event_trace: Array = []
	var injected := false
	var case_step := 0
	var recovery_checked := false
	var rejected_reply := false
	var clocks_preserved := true
	var remote_recovery_safe := true
	var remote_return_frames := 0
	var previous_exposure := 0.0
	var reset_rest := -1.0
	var frames := 0
	var max_exposure := 0.0
	while b.phase != b.Phase.END and b.mission.total_game_seconds < 260.0 and frames < 30000:
		await process_frame
		frames += 1
		max_exposure = maxf(max_exposure, l.exposure)
		if b.mission.active_action_id.begins_with("return_") and is_instance_valid(b.mission._actor) and b.mission._actor.position.distance_to(b.map.cell_to_world(l.SHADE)) > 146.0:
			remote_return_frames += 1
			remote_recovery_safe = remote_recovery_safe and not l._identity_ready(b) and l.exposure + 0.001 >= previous_exposure
		previous_exposure = l.exposure
		if not b.mission.has_event("merchant_identity_confirmed") and not l.force_started:
			invariants = invariants and b.find_unit("bai_sheng") == null and l.actors.size() == 7
		invariants = invariants and l.bundles.size() == 3 and l.convoy.size() in [0, 15]
		for event_id in OBSERVED:
			if b.mission.has_event(event_id) and not events.has(event_id):
				events[event_id] = true
				var contract: bool = _event_contract(b, event_id)
				invariants = invariants and contract
				event_trace.append({"event": event_id, "game_seconds": b.mission.total_game_seconds, "contract": contract, "wine_step": l.wine_step, "exposure": l.exposure, "actors": _actor_cells(b)})
		match case_name:
			"identity_recovery", "exposure_failure":
				if case_step == 0 and l.st == l.INQUIRY:
					b._smoke = false
					b.find_unit("liu_tang").order_move(b.map.cell_to_world(l.ANSWER))
					case_step = 1
				if case_step == 1 and l._at(b, b.find_unit("liu_tang"), l.ANSWER, 35.0) and b.mission.has_event("yang_inquired"):
					b.find_unit("gongsun_sheng").order_move(b.map.cell_to_world(l.INSPECT + Vector2i(1, 0)))
					injected = true
					case_step = 2
				if case_name == "identity_recovery":
					if case_step == 2 and l.exposure >= 8.0:
						invariants = invariants and not l._identity_ready(b)
						b.mission.request_action("answer_yang")
						case_step = 3
					if case_step == 3 and b.mission.has_event("action:inquiry:answer_yang") and b.mission.active_action_id == "":
						rejected_reply = not b.mission.has_event("merchant_identity_confirmed") and not b.mission.actions["answer_yang"].done
						invariants = invariants and b.mission.request_action("return_gongsun_sheng")
						case_step = 4
					if case_step == 4 and b.mission.has_event("cover_restored_gongsun_sheng"):
						recovery_checked = l._at(b, b.find_unit("gongsun_sheng"), l._cover_cell("gongsun_sheng"), 40.1)
						b._smoke = true
						case_step = 5
			"attention_recovery", "attention_timeout":
				if not injected and l.wine_step == "scoop" and b.mission.active_action_id == "":
					b._smoke = false
					injected = true
					reset_rest = l.rest_t
					if case_name == "attention_recovery": b.find_unit("liu_tang").order_move(b.map.cell_to_world(l.GOOD_WINE))
				if injected and not recovery_checked and b.mission.has_event("missed_attention"):
					recovery_checked = l.wine_step == "trial" and not l.sale_drugged and not l.scoop_prepared and not l.clean_trial
					clocks_preserved = l.rest_t >= reset_rest
					b._smoke = true
			"handoff_recovery":
				if case_step == 0 and l.wine_step == "reclaim" and b.mission.active_action_id == "":
					b._smoke = false
					b.find_unit("wu_yong").order_move(b.map.cell_to_world(Vector2i(20, 24)))
					injected = true
					reset_rest = l.rest_t
					case_step = 1
				if case_step == 1 and not l._at(b, b.find_unit("wu_yong"), l.SALE_WINE, 85.0):
					invariants = invariants and b.mission.request_action("reclaim_scoop")
					case_step = 2
				if case_step == 2 and b.mission.has_event("missed_attention"):
					recovery_checked = not b.mission.has_event("reclaim_scoop") and not l.sale_drugged and l.wine_step == "trial"
					clocks_preserved = l.rest_t >= reset_rest
					b._smoke = true
					case_step = 3
			"rest_timeout":
				if not injected and l.st == l.WINE:
					b._smoke = false
					injected = true
			"early_violence":
				if not injected and is_instance_valid(l.yang):
					b.find_unit("liu_tang").order_attack(l.yang, false, true)
					injected = true
		if case_name in FREE_ROUTE_CASES and l.st == l.FORCE:
			b._smoke = true
			_drive_force_actions(b)
		if frames % 1800 == 0: print("[hn-progress] ", case_name, " stage=", b.mission.stage_id, " action=", b.mission.active_action_id, " game=", b.mission.total_game_seconds, " suspicion=", l.exposure)
	var won: bool = b.phase == b.Phase.END and b.mission.has_event("escaped")
	var story_result: Dictionary = b.mission.result_snapshot(true) if b.phase == b.Phase.END else {}
	var passed: bool = invariants and won and clocks_preserved
	if case_name in FREE_ROUTE_CASES:
		passed = passed and injected and l.force_started and b.mission.has_event("huangnigang_force") \
			and not l.drug_done and l.delivered == 3 and b.kills == 0 \
			and bool(story_result.get("core_cleared", false)) and not bool(story_result.get("story_complete", true)) \
			and story_result.get("missed_ids", []).has("wine_scheme")
	else:
		passed = passed and bool(story_result.get("core_cleared", false)) and bool(story_result.get("story_complete", false))
	if case_name == "exposure_failure": passed = passed and b.mission.has_event("exposed") and l.actors.size() == 8
	if case_name == "early_violence": passed = passed and b.mission.has_event("huangnigang_convoy_hurt")
	if case_name == "identity_recovery": passed = passed and recovery_checked and rejected_reply and b.mission.has_event("suspicion_recovered") and remote_recovery_safe and remote_return_frames > 0
	if case_name in ["attention_recovery", "attention_timeout", "handoff_recovery"]: passed = passed and recovery_checked and b.mission.has_event("missed_attention")
	var repeated_safe := true
	if won and not case_name in FREE_ROUTE_CASES:
		var actual_events: Array = b.mission.events.keys()
		var last_index := -1
		for event_id in ["yang_inquired", "merchant_identity_confirmed", "bai_arrived", "bring_wine", "taste_wine", "distract_yang", "drug_scoop", "reclaim_scoop", "drugged", "escaped"]:
			var event_index: int = actual_events.find(event_id)
			passed = passed and event_index > last_index
			last_index = event_index
		var before_report: int = b.mission.report.size()
		var before_units: int = b.units.size()
		l.on_mission_action(b, "sell_wine", b.find_unit("bai_sheng"))
		l.on_mission_action(b, "reclaim_scoop", b.find_unit("bai_sheng"))
		repeated_safe = not b.mission.request_action("sell_wine") and b.mission.report.size() == before_report and b.units.size() == before_units and l.delivered == 3
		for guard in l.convoy:
			guard.take_damage(100000.0, null, true, true)
			repeated_safe = repeated_safe and guard.hp > 0.0 and guard.story_outcome == "unconscious"
		passed = passed and repeated_safe and b.kills == 0 and l.actors.size() == 8
	var result := {"case": case_name, "passed": passed, "invariants": invariants, "fresh": start_fresh, "bad_order_rejected": bad_order_rejected, "recovery_checked": recovery_checked, "rejected_reply": rejected_reply, "remote_recovery_safe": remote_recovery_safe, "remote_return_frames": remote_return_frames, "repeated_safe": repeated_safe, "max_exposure": max_exposure, "mission_game_seconds": b.mission.total_game_seconds, "stage_metrics": b.mission.stage_metrics.duplicate(true), "event_trace": event_trace, "events": b.mission.events.keys(), "frames": frames, "free_route": case_name in FREE_ROUTE_CASES, "story_result": story_result}
	results.append(result)
	print("[hn-result] ", JSON.stringify(result))
	if not passed:
		failures.append(case_name)
		print("[hn-failure-state] ", JSON.stringify({"stage": b.mission.stage_id, "action": b.mission.active_action_id, "wine_step": l.wine_step, "positions": _actor_cells(b)}))
	b.queue_free()
	await process_frame
	await process_frame
