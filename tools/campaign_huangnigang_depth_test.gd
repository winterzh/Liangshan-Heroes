extends SceneTree
## Huangnigang HN-3 fixture. Success cases use normal task requests and movement only.
## Direct callbacks are restricted to rejection edges. One lethal hit verifies that a
## carried original load drops in place and can be relayed without failing the chapter.
const OUTPUT_DIR := "res://qa/campaign_gameplay_depth_20260901/huangnigang"
var results: Array = []
var failures: Array[String] = []
var case_checks: Array = []

func _initialize() -> void: _run.call_deferred()

func _check(condition: bool, label: String) -> bool:
	case_checks.append({"label": label, "passed": condition})
	if not condition: push_warning("[hn-depth-check] " + label)
	return condition

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

func _prepare_cargo_choice(b) -> bool:
	var frames := 0
	while b.phase == b.Phase.FIGHT and not b.mission.has_event("drugged") and frames < 12000:
		await process_frame
		frames += 1
		# Pause the known-route driver before sell_wine commits so the player-facing
		# choice remains untouched. The preceding story chain is still entirely real.
		if b.mission.active_action_id == "sell_wine" and b.mission._progress >= 0.5:
			b._smoke = false
	return b.phase == b.Phase.FIGHT and b.mission.has_event("drugged") \
		and b.mission.stage_id == "carry_plan" and b.level.st == b.level.CARRY

func _complete_action(b, action_id: String, limit := 5000) -> bool:
	if not b.mission.actions.has(action_id): return false
	var stage_at_request: String = b.mission.stage_id
	if not b.mission.request_action(action_id): return false
	var event_id := "action:%s:%s" % [stage_at_request, action_id]
	var frames := 0
	while b.phase == b.Phase.FIGHT and not b.mission.has_event(event_id) and frames < limit:
		await process_frame
		frames += 1
	return b.mission.has_event(event_id)

func _wait_existing_action(b, stage_id: String, action_id: String, limit := 5000) -> bool:
	var event_id := "action:%s:%s" % [stage_id, action_id]
	var frames := 0
	while b.phase == b.Phase.FIGHT and not b.mission.has_event(event_id) and frames < limit:
		await process_frame
		frames += 1
	return b.mission.has_event(event_id)

func _wait_end(b, limit := 5000) -> bool:
	var frames := 0
	while b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	return b.phase == b.Phase.END

func _order_survivors_to_exit(b) -> bool:
	var living: Array = b.level.actors.filter(func(u):
		return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "")
	# Two small control groups avoid the three friendly loads already parked on the
	# exact gate cell and keep every formation slot inside the exit radius.
	var groups := [living.slice(0, 4), living.slice(4)]
	for i in range(groups.size()):
		b._set_selection(groups[i])
		b._issue_order(b.to_screen(b.map.cell_to_world(b.level.GATE_W + Vector2i(-1, -1 + i * 2))))
	return await _wait_end(b)

func _withdraw_with_player_order(b) -> bool:
	if not await _complete_action(b, "withdraw"):
		return false
	return await _order_survivors_to_exit(b)

func _ground_count(b) -> int:
	return b.units.filter(func(u): return is_instance_valid(u) and u.key == "treasure_cart").size()

func _owned_count(b) -> int:
	return b.units_root.get_children().filter(func(u): return is_instance_valid(u) and u.get("key") == "treasure_cart").size()

func _carrying_count(b) -> int:
	var count := 0
	for key in b.level.CARRIERS:
		var u = b.find_unit(key)
		if is_instance_valid(u) and u.has_meta("carrying_tribute"): count += 1
	return count

func _convoy_safe(b) -> bool:
	return b.level.convoy.size() == 15 and b.kills == 0 and b.level.convoy.all(func(u):
		return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "unconscious")

func _final_cargo_unique(b) -> bool:
	var l = b.level
	if l.delivered != 3 or _ground_count(b) != 3 or _owned_count(b) != 3: return false
	var ids: Array = []
	for i in range(3):
		var bundle = l.bundles[i]
		if not is_instance_valid(bundle) or not bundle.visible or bundle.process_mode == Node.PROCESS_MODE_DISABLED: return false
		if b.units.count(bundle) != 1 or b.map.world_to_cell(bundle.position) != l.GATE_W + Vector2i(0, i - 1): return false
		ids.append(bundle.get_instance_id())
	return ids.duplicate().size() == 3 and ids[0] != ids[1] and ids[0] != ids[2] and ids[1] != ids[2]

func _record_case(name: String, b, extra := {}) -> void:
	var passed: bool = case_checks.all(func(item): return bool(item.passed))
	var record := {"case": name, "passed": passed, "checks": case_checks.duplicate(true),
		"mission_game_seconds": b.mission.total_game_seconds if is_instance_valid(b) else -1.0,
		"stage_metrics": b.mission.stage_metrics.duplicate(true) if is_instance_valid(b) else []}
	for key in extra: record[key] = extra[key]
	results.append(record)
	if not passed: failures.append(name)
	print("[hn-depth-result] ", JSON.stringify(record))

func _close(b) -> void:
	if is_instance_valid(b): b.queue_free()
	await process_frame
	await process_frame

func _case_grouped() -> void:
	case_checks = []
	var b = await _start()
	var l = b.level
	_check(await _prepare_cargo_choice(b), "grouped reaches the real post-drug choice")
	_check(b.mission.actions.has("cargo_group_plan") and b.mission.actions.has("cargo_serial_plan"), "both carrying plans are visible")
	_check(await _complete_action(b, "cargo_group_plan"), "group plan is chosen through its real action")
	_check(l.cargo_plan == "grouped" and l.cargo_assignments.size() == 3 and l.cargo_ready.is_empty(), "group plan assigns three named carriers before readiness")
	var route_cells_open := true
	for i in range(3):
		route_cells_open = route_cells_open and b.map.is_open_cell(l.CARGO_STAGE_CELLS[i]) \
			and b.map.is_open_cell(Vector2i(24 + i, 20)) and b.map.is_open_cell(l.GATE_W + Vector2i(0, i - 1))
	_check(route_cells_open, "three staging, pickup and exit cells are land-open")
	for order_index in [2, 0, 1]:
		_check(await _complete_action(b, "stage_%d" % order_index), "group carrier %d reaches assigned staging cell" % (order_index + 1))
		var carrier = b.find_unit(l.CARRIERS[order_index])
		_check(l._at(b, carrier, l.CARGO_STAGE_CELLS[order_index], 40.1), "carrier %d is physically at staging cell" % (order_index + 1))
		if l.cargo_ready.size() < 3:
			_check(not b.mission.actions.has("take_0") and not b.mission.actions.has("take_1") and not b.mission.actions.has("take_2"), "loads stay locked until all grouped carriers are ready")
	_check(b.mission.has_event("cargo_group_ready") and l.cargo_ready.size() == 3, "group readiness settles once")
	_check([0, 1, 2].all(func(i): return b.mission.actions.has("take_%d" % i)), "all three pickup choices open together")
	for i in [2, 0, 1]: _check(await _complete_action(b, "take_%d" % i), "group pickup %d uses original action id" % (i + 1))
	_check(_carrying_count(b) == 3 and _ground_count(b) == 0 and _owned_count(b) == 3, "group plan can marshal all three exact loads before delivery")
	_check(l.cargo_objective_cache.contains("刘唐·北沿 挑运中") and l.cargo_objective_cache.contains("阮小五·中道 挑运中") and l.cargo_objective_cache.contains("阮小七·南沿 挑运中"), "task objective names each carrier, route and live state")
	for i in [1, 2, 0]: _check(await _complete_action(b, "deliver_%d" % i), "group delivery %d reaches its exit lane" % (i + 1))
	_check(await _withdraw_with_player_order(b), "grouped route reaches normal withdrawal victory after a real group move")
	_check(b.mission.has_event("escaped") and _convoy_safe(b), "grouped ending preserves the unconscious convoy")
	_check(_final_cargo_unique(b), "grouped ending restores exactly three original loads once")
	_record_case("grouped_preposition", b, {"plan": l.cargo_plan})
	await _close(b)

func _case_serial() -> void:
	case_checks = []
	var b = await _start()
	var l = b.level
	_check(await _prepare_cargo_choice(b), "serial reaches the real post-drug choice")
	_check(await _complete_action(b, "cargo_serial_plan"), "serial plan is chosen by Liu Tang reaching load one")
	_check(l.cargo_plan == "serial" and l.cargo_assignments.size() == 1 and l.cargo_ready.has(0), "serial begins with only the first carrier assigned")
	var max_carrying := 0
	for i in range(3):
		if i > 0:
			_check(l.cargo_assignments.size() == i + 1 and b.mission.actions.has("stage_%d" % i) and not b.mission.actions.has("take_%d" % i), "serial assigns carrier %d only after prior delivery" % (i + 1))
			_check(await _complete_action(b, "stage_%d" % i), "serial carrier %d reaches the next load" % (i + 1))
		_check(await _complete_action(b, "take_%d" % i), "serial pickup %d uses original action id" % (i + 1))
		max_carrying = maxi(max_carrying, _carrying_count(b))
		_check(await _complete_action(b, "deliver_%d" % i), "serial delivery %d completes before next dispatch" % (i + 1))
		max_carrying = maxi(max_carrying, _carrying_count(b))
	_check(max_carrying == 1, "serial plan never requires more than one simultaneous carrier")
	_check(await _withdraw_with_player_order(b), "serial route reaches normal withdrawal victory after a real group move")
	_check(b.mission.has_event("escaped") and _convoy_safe(b), "serial ending preserves the unconscious convoy")
	_check(_final_cargo_unique(b), "serial ending restores exactly three original loads once")
	_record_case("serial_dispatch", b, {"plan": l.cargo_plan, "max_simultaneous_carriers": max_carrying})
	await _close(b)

func _case_rejections() -> void:
	case_checks = []
	var b = await _start()
	var l = b.level
	_check(await _prepare_cargo_choice(b), "rejection case reaches the real post-drug choice")
	_check(not l._assign_cargo(1, "liu_tang") and l.cargo_assignments.is_empty(), "duplicate carrier cannot be assigned to the wrong load")
	var plan_report: int = b.mission.report.size()
	l.on_mission_action(b, "cargo_group_plan", b.find_unit("wu_yong"))
	_check(l.cargo_plan == "" and b.mission.report.size() == plan_report, "wrong actor cannot commit a carrying plan callback")
	_check(await _complete_action(b, "cargo_group_plan"), "valid grouped plan still works after rejection")
	var stage_report: int = b.mission.report.size()
	l.on_mission_action(b, "stage_0", b.find_unit("ruan_xiaowu"))
	_check(not l.cargo_ready.has(0) and b.mission.report.size() == stage_report, "wrong carrier cannot take another carrier's staging assignment")
	_check(await _complete_action(b, "stage_0"), "correct staging remains available")
	stage_report = b.mission.report.size()
	l.on_mission_action(b, "stage_0", b.find_unit("liu_tang"))
	_check(l.cargo_ready.size() == 1 and b.mission.report.size() == stage_report, "duplicate staging callback settles only once")
	_check(await _complete_action(b, "stage_1") and await _complete_action(b, "stage_2"), "remaining valid staging actions complete")
	var wrong_pick_report: int = b.mission.report.size()
	l.on_mission_action(b, "take_0", b.find_unit("ruan_xiaowu"))
	_check(not l.cargo.has(0) and b.mission.report.size() == wrong_pick_report and _ground_count(b) == 3, "wrong carrier cannot pick another assigned load")
	_check(await _complete_action(b, "take_0"), "correct carrier can still pick after wrong attempt")
	var units_after_pick: int = b.units.size()
	var reports_after_pick: int = b.mission.report.size()
	l.on_mission_action(b, "take_0", b.find_unit("liu_tang"))
	_check(b.units.size() == units_after_pick and b.mission.report.size() == reports_after_pick and _ground_count(b) == 2, "duplicate pickup cannot hide or create another load")
	_check(not b.mission.request_action("cargo_serial_plan"), "the other plan cannot be selected after commitment")
	_check(await _complete_action(b, "take_1") and await _complete_action(b, "take_2"), "valid pickups remain recoverable")
	for i in [0, 1, 2]: _check(await _complete_action(b, "deliver_%d" % i), "recovery delivery %d completes" % (i + 1))
	_check(await _withdraw_with_player_order(b), "rejected inputs do not soft-lock the valid chain")
	_check(_final_cargo_unique(b) and _convoy_safe(b), "rejection recovery keeps final cargo and convoy contracts")
	_record_case("wrong_and_duplicate_rejected", b, {"boundary_fixture": "Direct callbacks are used only to prove rejection; all successful actions and movement use request_action."})
	await _close(b)

func _case_interruption_death_restart() -> void:
	case_checks = []
	var b = await _start()
	var l = b.level
	_check(await _prepare_cargo_choice(b), "interruption case reaches the real post-drug choice")
	_check(await _complete_action(b, "cargo_group_plan"), "interruption case selects grouped plan normally")
	for i in range(3): _check(await _complete_action(b, "stage_%d" % i), "interruption setup stages carrier %d" % (i + 1))
	_check(await _complete_action(b, "take_0"), "first load is picked normally")
	var interruptions_before: int = b.mission._stage_interruptions
	var deliver_started: bool = b.mission.request_action("deliver_0")
	for frame in range(8): await process_frame
	var switched_to_second: bool = b.mission.active_action_id == "deliver_0" and b.mission.request_action("take_1")
	_check(deliver_started and switched_to_second, "another valid group task interrupts an in-flight delivery")
	_check(b.mission._stage_interruptions == interruptions_before + 1 and l.cargo.has(0) and not b.mission.has_event("deliver_0") and not b.units.has(l.bundles[0]), "interruption retains exactly one hidden carried load")
	_check(await _wait_existing_action(b, "carry_group", "take_1"), "second pickup completes after the deliberate task switch")
	_check(await _complete_action(b, "deliver_0"), "interrupted delivery can be requested again and completed once")
	var doomed = b.find_unit("ruan_xiaowu")
	_check(doomed.has_meta("carrying_tribute") and l.cargo[1] == doomed, "death fixture targets a carrier who is holding the second load")
	var original_load = l.bundles[1]
	var original_load_id: int = original_load.get_instance_id()
	var drop_origin: Vector2i = b.map.world_to_cell(doomed.position)
	doomed.take_damage(1000000.0, null, false, true)
	await process_frame
	await process_frame
	_check(b.phase == b.Phase.FIGHT and l.st == l.FORCE and b.mission.has_event("huangnigang_force") \
		and not b.mission.has_event("escaped") and not b.mission.has_event("deliver_1"),
		"carrier death changes to the free force route instead of ending the chapter")
	_check(b.mission.has_event("force_drop_1_1") and is_instance_valid(original_load) \
		and original_load.get_instance_id() == original_load_id and b.units.count(original_load) == 1 \
		and original_load.visible and _owned_count(b) == 3 and _ground_count(b) == 3 \
		and b.map.world_to_cell(original_load.position).distance_to(drop_origin) <= 2.0,
		"the same original second load drops once near its fallen carrier")
	_check(b.mission.actions.has("force_take_1_1"), "the dropped load immediately exposes a survivor relay task")
	_check(await _complete_action(b, "force_take_1_1"), "another surviving hero picks up the dropped original load")
	var relay = l.cargo.get(1)
	_check(is_instance_valid(relay) and relay != doomed and relay.hp > 0.0 \
		and relay.get_meta("carrying_tribute", -1) == 1 and not b.units.has(original_load) \
		and original_load.get_instance_id() == original_load_id and _owned_count(b) == 3,
		"relay carries that exact hidden scene-owned load without cloning it")
	_check(await _complete_action(b, "force_deliver_1_1") and b.mission.has_event("force_delivered_1"),
		"relay delivers the dropped second load once")
	_check(await _complete_action(b, "force_take_2_0") and await _complete_action(b, "force_deliver_2_0"),
		"survivors can finish the remaining load through the same free route")
	_check(await _wait_end(b) and b.mission.has_event("escaped"),
		"three delivered loads and one surviving hero still complete the core chapter")
	var result: Dictionary = b.mission.result_snapshot(true)
	_check(bool(result.get("core_cleared", false)) and not bool(result.get("story_complete", true)) \
		and result.get("missed_ids", []).has("all_safe"),
		"the forced relay keeps the core victory but forfeits the original-story seal")
	_check(_final_cargo_unique(b) and original_load.get_instance_id() == original_load_id,
		"the ending restores exactly the three original loads after relay")
	var death_metrics: Array = b.mission.stage_metrics.duplicate(true)
	_record_case("interruption_and_carrier_death_relay", b, {
		"damage_fixture": "One lethal hit is injected only to verify same-load drop and survivor relay; it is not a scripted victory.",
		"closed_stage_metrics": death_metrics,
		"story_result": result,
	})
	await _close(b)

	case_checks = []
	var restarted = await _start()
	var rl = restarted.level
	var fresh: bool = rl.st == rl.PREPARE and rl.cargo_plan == "" and rl.cargo_assignments.is_empty() and rl.cargo_ready.is_empty() \
		and rl.cargo.is_empty() and rl.delivered == 0 and restarted.mission.events.is_empty() \
		and _owned_count(restarted) == 3 and _ground_count(restarted) == 3 \
		and rl.bundles.all(func(bundle): return bundle.visible and bundle.process_mode != Node.PROCESS_MODE_DISABLED and not bundle.has_meta("tribute_process_mode"))
	_check(fresh, "restarted chapter clears plan, assignments, readiness, carried state and events")
	_record_case("restart_reset", restarted, {"restart_fixture": "Fresh main scene after the interrupted/death case; no campaign progress is written."})
	await _close(restarted)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	await _case_grouped()
	await _case_serial()
	await _case_rejections()
	await _case_interruption_death_restart()
	if results.size() != 5: failures.append("incomplete_expected_5")
	var output := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output)
	var payload := {"passed": failures.is_empty(), "failures": failures, "cases": results,
		"timing_note": "mission_game_seconds is fixed-fps60 FIGHT simulation time at time_scale4. Setup follows the production known route, then tasks use real request_action movement. It is not human pacing, performance, or a 15-25 minute acceptance result.",
		"success_injection": false, "representative_loads": 3}
	var file := FileAccess.open(output.path_join("depth_v1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	Engine.time_scale = 1.0
	print("[hn-depth-summary] ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "cases": results.size(), "evidence": output.path_join("depth_v1.json")}))
	quit(0 if failures.is_empty() else 1)
