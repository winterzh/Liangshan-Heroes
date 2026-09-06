extends SceneTree
## Real campaign actions/movement; extra visibility refreshes probe the carried object lifecycle.
## carrier_death injects one lethal hit only to verify that the exact carried load
## drops for a survivor relay. The relay and the core victory use public task actions.
var results: Array = []
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _start():
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]: campaign.set(mode, false)
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

func _contains_in_buckets(b, bundle) -> bool:
	for grid in [b._grid, b._mob_grid, b._body_grid_liang, b._body_grid_guan]:
		for bucket in grid.values():
			if bucket.has(bundle): return true
	return false

func _ground_count(b) -> int:
	return b.units.filter(func(u): return is_instance_valid(u) and u.key == "treasure_cart").size()

func _owned_count(b) -> int:
	return b.units_root.get_children().filter(func(u): return is_instance_valid(u) and u.get("key") == "treasure_cart").size()

func _hidden_contract(b, bundle, carrier) -> bool:
	return is_instance_valid(bundle) and bundle.get_parent() == b.units_root and not bundle.visible \
		and bundle.process_mode == Node.PROCESS_MODE_DISABLED and not b.units.has(bundle) \
		and not b.selection.has(bundle) and b._inspect_unit != bundle and not bundle.selected \
		and not _contains_in_buckets(b, bundle) and not b.units_near(bundle.position, 100.0).has(bundle) \
		and b._enemy_at(b.to_screen(bundle.position)) != bundle and not bool(bundle.get_meta("footprint_blocked", false)) \
		and bundle.hp > 0.0 and bundle.story_outcome == "" and carrier.has_meta("carrying_tribute")

func _drive_force_actions(b) -> void:
	if b.level.st != b.level.FORCE or b.mission.active_action_id != "": return
	for prefix in ["force_deliver_", "force_take_"]:
		for action_id in b.mission.actions.keys():
			if String(action_id).begins_with(prefix) and b.mission.request_action(String(action_id)):
				return

func _case(case_name: String) -> void:
	var b = await _start()
	var l = b.level
	var original_ids: Array = []
	var references: Array = []
	for bundle in l.bundles:
		original_ids.append(bundle.get_instance_id())
		references.append(weakref(bundle))
	var fresh: bool = l.st == l.PREPARE and l.cargo.is_empty() and l.delivered == 0 and _ground_count(b) == 3 and _owned_count(b) == 3
	for bundle in l.bundles:
		fresh = fresh and bundle.visible and bundle.process_mode != Node.PROCESS_MODE_DISABLED and not bundle.has_meta("tribute_process_mode")
	var checks := fresh
	var picks: Array = []
	var drops: Array = []
	var inspect_set: Array = []
	var refreshes := 0
	var signs_hidden := false
	var delivered_once := true
	var death_injected := false
	var dead_carrier = null
	var death_origin := Vector2i.ZERO
	var death_drop_checked := false
	var relay_checked := false
	var force_deliveries: Array = []
	var stopped_for_restart := false
	var frames := 0
	while b.phase != b.Phase.END and b.mission.total_game_seconds < 250.0 and frames < 20000:
		await process_frame
		frames += 1
		if b.mission.has_event("drugged"):
			signs_hidden = not l.field_signs.is_empty() and l.field_signs.all(func(sign_node): return is_instance_valid(sign_node) and not sign_node.visible)
			checks = checks and signs_hidden
		if case_name == "carrier_death" and death_injected and not death_drop_checked:
			var dropped = l.bundles[0]
			death_drop_checked = b.mission.has_event("force_drop_0_1")
			checks = checks and death_drop_checked and b.phase == b.Phase.FIGHT and l.st == l.FORCE \
				and is_instance_valid(dropped) and dropped.get_instance_id() == original_ids[0] \
				and b.units.count(dropped) == 1 and dropped.visible \
				and b.map.world_to_cell(dropped.position).distance_to(death_origin) <= 2.0 \
				and b.mission.actions.has("force_take_0_1") and not b.mission.has_event("escaped")
		if case_name == "carrier_death" and death_drop_checked and not relay_checked \
				and b.mission.has_event("force_taken_0_1"):
			var relay = l.cargo.get(0)
			relay_checked = is_instance_valid(relay) and relay != dead_carrier and relay.hp > 0.0 \
				and relay.key in l.SEVEN + ["bai_sheng"] and _hidden_contract(b, l.bundles[0], relay)
			checks = checks and relay_checked
		for i in range(3):
			if b.mission.has_event("force_delivered_%d" % i) and not force_deliveries.has(i):
				force_deliveries.append(i)
		for i in range(3):
			var take_id := "take_%d" % i
			var deliver_id := "deliver_%d" % i
			var bundle = l.bundles[i]
			if b.mission.active_action_id == take_id and b.mission._progress >= 0.5 and not inspect_set.has(i):
				# Real inspect UI state must be cleared when its ground object is picked up.
				b._set_inspect(bundle)
				inspect_set.append(i)
			if b.mission.has_event(take_id) and not picks.has(i):
				b._smoke = false
				picks.append(i)
				var carrier = l.cargo[i]
				checks = checks and _hidden_contract(b, bundle, carrier) and _owned_count(b) == 3 and _ground_count(b) == 2
				# This chapter normally has no fog; initialize only the visibility fixture's buffers.
				# Calling both production refresh methods must not reinsert or reveal the carried node.
				if b._vision.is_empty(): b._init_fog()
				for repeat_index in range(12):
					b._grid_build()
					b._fog_pass(0.25)
					checks = checks and _hidden_contract(b, bundle, carrier)
					refreshes += 2
					await process_frame
				checks = checks and not b.mission.request_action(take_id)
				var before_units: int = b.units.size()
				var before_events: int = b.mission.report.size()
				l.on_mission_action(b, take_id, carrier)
				checks = checks and b.units.size() == before_units and b.mission.report.size() == before_events and _hidden_contract(b, bundle, carrier)
				if case_name == "restart_during_carry":
					stopped_for_restart = true
					break
				if case_name == "carrier_death":
					dead_carrier = carrier
					death_origin = b.map.world_to_cell(carrier.position)
					carrier.take_damage(1000000.0, null, false, true)
					death_injected = true
					checks = checks and carrier.hp <= 0.0 and b.phase == b.Phase.FIGHT and not b.mission.has_event("escaped")
					break
				b._smoke = true
			if b.mission.has_event(deliver_id) and not drops.has(i):
				drops.append(i)
				var carrier = l.cargo[i]
				b._grid_build()
				checks = checks and bundle.get_instance_id() == original_ids[i] and bundle.get_parent() == b.units_root \
					and b.units.count(bundle) == 1 and bundle.visible and bundle.process_mode != Node.PROCESS_MODE_DISABLED \
					and not carrier.has_meta("carrying_tribute") and _owned_count(b) == 3 and _ground_count(b) == 3 \
					and b.map.world_to_cell(bundle.position) == l.GATE_W + Vector2i(0, i - 1) and bundle.story_outcome == ""
				var count_before: int = l.delivered
				var before_units: int = b.units.size()
				l.on_mission_action(b, deliver_id, carrier)
				delivered_once = delivered_once and l.delivered == count_before and b.units.size() == before_units and b.units.count(bundle) == 1 and not b.mission.request_action(deliver_id)
		if case_name == "carrier_death" and death_drop_checked:
			b._smoke = true
			_drive_force_actions(b)
		if stopped_for_restart: break
	var won: bool = b.phase == b.Phase.END and b.mission.has_event("escaped")
	var story_result: Dictionary = b.mission.result_snapshot(true) if b.phase == b.Phase.END else {}
	var outcome_ok: bool = won and picks.size() == 3 and drops.size() == 3 and l.delivered == 3
	if case_name == "restart_during_carry": outcome_ok = stopped_for_restart and b.phase == b.Phase.FIGHT and picks == [0] and drops.is_empty()
	if case_name == "carrier_death":
		outcome_ok = death_injected and death_drop_checked and relay_checked and won and picks == [0] \
			and force_deliveries == [0, 1, 2] and l.delivered == 3 \
			and bool(story_result.get("core_cleared", false)) and not bool(story_result.get("story_complete", true)) \
			and story_result.get("missed_ids", []).has("all_safe")
	var convoy_safe: bool = l.convoy.size() == 15 and l.convoy.all(func(u): return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "unconscious") and b.kills == 0
	var record := {"case": case_name, "fresh": fresh, "checks": checks, "outcome_ok": outcome_ok, "convoy_safe": convoy_safe,
		"obsolete_signs_hidden": signs_hidden, "picks": picks, "drops": drops, "inspected_before_pick": inspect_set,
		"production_visibility_refresh_calls": refreshes, "duplicate_safe": delivered_once,
		"mission_game_seconds": b.mission.total_game_seconds, "stage_metrics": b.mission.stage_metrics.duplicate(true),
		"visibility_fixture_note": "Extra grid/fog refresh calls and 12 observation frames per pickup; successful story actions/movement are real, but timing includes these test observation pauses.",
		"damage_fixture": death_injected, "death_drop_checked": death_drop_checked,
		"relay_checked": relay_checked, "force_deliveries": force_deliveries, "story_result": story_result}
	b.queue_free()
	await process_frame
	await process_frame
	var scene_cleanup: bool = references.all(func(reference): return reference.get_ref() == null)
	record["all_original_nodes_freed_with_scene"] = scene_cleanup
	record["passed"] = checks and outcome_ok and convoy_safe and signs_hidden and delivered_once and scene_cleanup and inspect_set.size() == picks.size()
	results.append(record)
	if not record.passed: failures.append(case_name)
	print("[hn-cargo-result] ", JSON.stringify(record))

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	for case_name in ["carry_visibility_delivery", "restart_during_carry", "carrier_death", "replay"]: await _case(case_name)
	if results.size() != 4: failures.append("incomplete_run_expected_4")
	var directory := ProjectSettings.globalize_path("res://qa/campaign_huangnigang")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("cargo_v1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":results,"not_human_or_pacing_evidence":true}, "\t"))
	file.close()
	print("[hn-cargo-summary] ", JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":results.size()}))
	quit(0 if failures.is_empty() else 1)
