extends "res://tools/zhujiazhuang_rts_test.gd"
## State-boundary checks for the reporting guard. Battle movement and timers
## run normally after the fixture places the first prisoner at the rescue step.

func _run() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/jiangzhou-report-") \
			or not OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	var flow := root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while not flow.can_launch():
		if flow.phase == flow.Phase.ERROR or Time.get_ticks_msec() >= deadline:
			push_error("Jiangzhou probe startup: " + str(flow.last_result))
			quit(2)
			return
		await process_frame
	await _check_delivered()
	await _check_intercepted()
	await _check_closed()
	await _check_original()
	print("JIANG_REPORT_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)


func _reach_rescue(battle) -> void:
	Engine.time_scale = 4.0
	var level = battle.level
	level._uprising(battle, level.named_units.li_kui)
	for executioner in level.executioners:
		executioner.take_damage(10000, null, false, true)
	var deadline: float = level.elapsed + 2.0
	while not level.execution_halted and level.elapsed < deadline:
		await process_frame
	check(level.execution_halted, "execution stopped in the fixture")
	level.on_mission_action(battle, "free_song", level.named_units.li_kui)
	# The fixture starts before the real advance has cleared the scaffold.
	# Give the rescued prisoner a safe position while the guard makes his run.
	if alive(level.song_freed):
		level.song_freed.position = battle.map.cell_to_world(level.WEST_CAMP + Vector2i(2, 2))


func _check_delivered() -> void:
	var battle = await _start("", 1)
	var level = battle.level
	var courier = level._report_guard()
	var position: Vector2 = courier.position
	await _reach_rescue(battle)
	check(battle.mission.has_event(level.REPORT_SENT) and courier._path.size() > 0,
		"first unbinding sends the existing guard on a real path")
	var start: float = level.elapsed
	while battle.phase == battle.Phase.FIGHT and not battle.mission.has_event(level.REPORT_DELIVERED) and level.elapsed - start < level.PURSUIT_WARNING:
		await process_frame
	check(battle.mission.has_event(level.REPORT_DELIVERED) and courier.position.distance_to(position) > 100.0,
		"guard physically reaches the north watch")
	check(not level.pursuit_sent and not level._report_open(battle.mission),
		"arrival closes the chance without releasing the reserve early")
	while battle.phase == battle.Phase.FIGHT and not level.pursuit_sent and level.elapsed - start < level.PURSUIT_WARNING + 1.0:
		await process_frame
	check(level.pursuit_sent and absf(level.elapsed - start - level.PURSUIT_WARNING) < 0.5,
		"ignoring the guard preserves the original 20-second pursuit")
	check(level.pursuit.size() == 6 and level.campaign_debrief(battle.mission).back().source == "北哨报信 · 官差已抵达",
		"reserve count and debrief reflect the event")
	await _dispose(battle)


func _check_intercepted() -> void:
	var battle = await _start("", 1)
	var level = battle.level
	await _reach_rescue(battle)
	var courier = level._report_guard()
	var before: float = level.pursuit_left
	courier.take_damage(10000, level.named_units.hua_rong, false, true)
	check(battle.mission.has_event(level.REPORT_CUT) and is_equal_approx(level.pursuit_left, before + 12.0),
		"interception adds exactly 12 seconds")
	level.on_unit_died(battle, courier)
	level.on_mission_action(battle, "free_dai", level.named_units.li_kui)
	if alive(level.dai_freed):
		level.dai_freed.position = battle.map.cell_to_world(level.WEST_CAMP + Vector2i(3, 2))
	check(is_equal_approx(level.pursuit_left, before + 12.0), "repeat death and second rescue cannot add or reset time")
	var start: float = level.elapsed
	while battle.phase == battle.Phase.FIGHT and not level.pursuit_sent and level.elapsed - start < before + 13.0:
		await process_frame
	check(level.pursuit_sent and absf(level.elapsed - start - before - 12.0) < 0.5,
		"same reserve launches only when the extended timer expires")
	check(level.campaign_debrief(battle.mission).back().source == "北哨报信 · 已拦截，推迟追兵12秒",
		"interception appears in the battle report")
	await _dispose(battle)


func _check_closed() -> void:
	var battle = await _start("", 1)
	var level = battle.level
	await _reach_rescue(battle)
	var courier = level._report_guard()
	# Standstill exercises the timeout without depending on pathfinder stalls.
	courier.order_stop()
	var start: float = level.elapsed
	while battle.phase == battle.Phase.FIGHT and not level.pursuit_sent and level.elapsed - start < level.PURSUIT_WARNING + 1.0:
		await process_frame
	check(level.pursuit_sent and battle.mission.has_event(level.REPORT_CLOSED)
		and not battle.mission.has_event(level.REPORT_CUT), "a blocked path cannot defer the pursuit")
	await _dispose(battle)


func _check_original() -> void:
	var battle = await _start("", 1)
	var level = battle.level
	battle.mission.events.erase(level.REPORT_RULE)
	await _reach_rescue(battle)
	check(level.first_rescued and is_equal_approx(level.pursuit_left, 20.0)
		and not battle.mission.has_event(level.REPORT_SENT), "a restored old mission without the feature event keeps its original rule")
	var boatman = level.named_units.zhang_shun
	var reference: WeakRef = weakref(boatman)
	boatman.take_damage(10000, null, false, true)
	var deadline: float = level.elapsed + 4.0
	while battle.phase == battle.Phase.FIGHT and reference.get_ref() != null and level.elapsed < deadline:
		await process_frame
	check(reference.get_ref() == null and level._bailong_party()[2] == null,
		"an absent boatman becomes a vacant rendezvous slot")
	await _dispose(battle)
