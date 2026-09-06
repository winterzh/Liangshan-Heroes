extends SceneTree
## End-to-end action-driver tests. Uses request_action, actual paths and actual combat.
## EARLY_QA_FAILURES=1 exercises both free-play deviations and true loss paths.
## Deviating from the novel may forfeit the optional story seal, but must not
## turn an otherwise achievable tactical objective into an automatic defeat.
const CASES := {"level6": "yezhulin_victory", "level1": "escaped", "level7": "restore_shop", "level2": "all_embarked"}
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _start(key: String):
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == key:
			campaign.current = i
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._smoke = true
	b.hud._on_start_pressed()
	Engine.time_scale = 4.0
	return b

func _dispose(b) -> void:
	b.queue_free()
	await process_frame
	await process_frame

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	var requested := OS.get_environment("EARLY_QA_LEVELS")
	for key in CASES:
		if requested != "" and not key in requested.split(","):
			continue
		var b = await _start(key)
		var frames := 0
		var seconds := 0.0
		var recovery_started := false
		while b.phase != b.Phase.END and frames < 21000 and seconds < 240.0:
			await process_frame
			frames += 1
			seconds += b.get_process_delta_time()
			if key == "level1" and OS.get_environment("EARLY_QA_RECOVERY") == "1":
				if not recovery_started and b.mission.has_event("distract_yang") and not b.mission.has_event("drug_scoop") and b.mission.active_action_id == "":
					b._smoke = false
					recovery_started = true
				if recovery_started and b.mission.has_event("missed_attention"):
					b._smoke = true
			if frames % 900 == 0:
				print("[early-progress] ", key, " stage=", b.mission.stage_id, " action=", b.mission.active_action_id, " elapsed=", seconds, " events=", b.mission.events.keys())
		var passed: bool = b.phase == b.Phase.END and b.mission.has_event(CASES[key])
		var kills_before: int = b.kills
		if key == "level1":
			for guard in b.level.convoy:
				if is_instance_valid(guard) and guard.story_outcome == "unconscious":
					guard.take_damage(100000.0, null, true, true)
				passed = passed and is_instance_valid(guard) and guard.hp > 0.0 and guard.story_outcome == "unconscious"
			passed = passed and b.kills == 0
			if OS.get_environment("EARLY_QA_RECOVERY") == "1":
				passed = passed and recovery_started and b.mission.has_event("missed_attention")
		elif key == "level6":
			passed = passed and b.kills == 0 and b.find_unit("lu_qian") == null
		elif key == "level7":
			if b.level.menshen.story_outcome == "subdued":
				b.level.menshen.take_damage(100000.0, null, true, true)
			passed = passed and b.level.menshen.story_outcome == "subdued" and b.level.menshen.hp > 0.0 and b.find_unit("zhang_tuanlian") == null
			passed = passed and b.level.wu.art_variant == "wu_song_mengzhou"
			passed = passed and b._defs["wu_song"]["abilities"][0] == "mengzhou_punch"
		elif key == "level2":
			for rescued in [b.level.song_freed, b.level.dai_freed]:
				if is_instance_valid(rescued) and rescued.story_outcome == "embarked":
					rescued.take_damage(100000.0, null, true, true)
			passed = passed and b.level.song_freed.story_outcome == "embarked" and b.level.dai_freed.story_outcome == "embarked"
		var story_result: Dictionary = b.mission.result_snapshot(true)
		passed = passed and bool(story_result.get("story_complete", false))
		passed = passed and b.kills == kills_before
		print("[early-result] ", JSON.stringify({"level": key, "passed": passed, "frames": frames, "simulation_seconds": seconds, "mission_game_seconds": b.mission.total_game_seconds, "stage_metrics": b.mission.stage_metrics, "events": b.mission.events.keys(), "story_result": story_result}))
		if not passed:
			failures.append(key)
			var snapshot := []
			for u in b.units:
				if is_instance_valid(u):
					snapshot.append({"key": u.key, "hp": u.hp, "cell": str(b.map.world_to_cell(u.position)), "outcome": u.story_outcome, "path": [u._path_i, u._path.size()]})
			print("[early-snapshot] ", JSON.stringify(snapshot))
		await _dispose(b)
	if OS.get_environment("EARLY_QA_FAILURES") == "1":
		await _negative_paths()
	Engine.time_scale = 1.0
	print("[early-summary] ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _negative_paths() -> void:
	var specs := [
		{"level": "level1", "case": "early_violence", "expect_core": true, "deviation_event": "huangnigang_force", "missed_goal": "merchant_cover"},
		{"level": "level2", "case": "song_killed", "expect_core": false},
		{"level": "level2", "case": "dai_killed", "expect_core": false},
		{"level": "level6", "case": "missed_intercept", "expect_core": false},
		{"level": "level7", "case": "early_duel", "expect_core": true, "deviation_event": "kuaihuolin_early_showdown", "missed_goal": "drunken_provocation"},
	]
	for spec in specs:
		var key: String = spec.level
		var b = await _start(key)
		var frames := 0
		var triggered := false
		var route_prepared := false
		while b.phase != b.Phase.END and frames < 14000:
			await process_frame
			frames += 1
			if not triggered and spec.case == "early_violence" and is_instance_valid(b.level.yang):
				b.level.yang.take_damage(5.0, b.find_unit("liu_tang"), false, true)
				triggered = true
			elif not triggered and spec.case == "song_killed" and b.level.rescued_song:
				b.level.song_freed.take_damage(100000.0, null, true, true)
				triggered = true
			elif not triggered and spec.case == "dai_killed" and b.level.rescued_dai:
				b.level.dai_freed.take_damage(100000.0, null, true, true)
				triggered = true
			elif not triggered and spec.case == "missed_intercept" and b.mission.stage_id == "intercept":
				b._smoke = false
				triggered = true
			elif not triggered and spec.case == "early_duel":
				b.level.menshen.take_damage(5.0, b.level.wu, false, true)
				triggered = true
			if spec.case == "early_violence" and not route_prepared and b.mission.has_event("huangnigang_force"):
				# This is a branch/settlement contract, not an encounter-balance test.
				# Remove the hostile screen after it has been proved active so the test
				# can deterministically exercise all three carry interactions and exit.
				b._smoke = false
				for guard in b.level.convoy:
					if is_instance_valid(guard) and guard.story_outcome == "":
						guard.resolve_story("subdued")
				route_prepared = true
			# The normal story smoke route has no reason to know the dynamically named
			# force-cargo actions. Drive those actions here so this test proves the
			# exposed Huangnigang route remains winnable instead of merely entering it.
			if spec.case == "early_violence" and b.mission.active_action_id == "":
				# Deliver before taking another bundle. Otherwise request_action() may
				# repeatedly choose the same first eligible hero, who correctly refuses
				# a second load while still carrying the first.
				for action_id in b.mission.actions:
					if String(action_id).begins_with("force_deliver_") and b.mission.request_action(action_id):
						break
				if b.mission.active_action_id == "":
					for action_id in b.mission.actions:
						if String(action_id).begins_with("force_take_") and b.mission.request_action(action_id):
							break
		# If a fixture times out before settlement, never manufacture a successful
		# snapshot by passing the expected answer into result_snapshot().
		var completed_core_event: bool = b.mission.has_event(CASES[key])
		var result: Dictionary = b.mission.result_snapshot(b.phase == b.Phase.END and completed_core_event)
		var expect_core: bool = bool(spec.expect_core)
		var passed: bool = triggered and b.phase == b.Phase.END
		if expect_core:
			var deviation_event := String(spec.deviation_event)
			var missed_goal := String(spec.missed_goal)
			passed = passed and bool(result.get("core_cleared", false))
			passed = passed and b.mission.has_event(CASES[key]) and b.mission.has_event(deviation_event)
			passed = passed and not bool(result.get("story_complete", true))
			passed = passed and missed_goal in result.get("missed_ids", [])
		else:
			passed = passed and not bool(result.get("core_cleared", true))
			passed = passed and not b.mission.has_event(CASES[key])
		print("[early-negative] ", JSON.stringify({"level": key, "case": spec.case, "passed": passed, "triggered": triggered, "expect_core": expect_core, "phase": b.phase, "stage": b.mission.stage_id, "active_action": b.mission.active_action_id, "core_event": completed_core_event, "events": b.mission.events.keys(), "result": result}))
		if not passed:
			failures.append(key + "_" + String(spec.case))
		await _dispose(b)
