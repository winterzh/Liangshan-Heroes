extends "res://tools/zhujiazhuang_rts_test.gd"
## Place the pressure squad near the chosen entrance. Guard movement, damage,
## withdrawal, and the gate transition then use the actual battle rules.

func _run() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/zhu-feint-") \
			or not OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	var flow := root.get_node("ContinueFlow")
	var startup_deadline := Time.get_ticks_msec() + 60000
	while not flow.can_launch():
		if flow.phase == flow.Phase.ERROR or Time.get_ticks_msec() >= startup_deadline:
			push_error(str(flow.last_result))
			quit(2)
			return
		await process_frame
	var battle = await _start()
	Engine.time_scale = 3.0
	var level = battle.level
	var troop = battle.find_unit("lin_chong")
	var support = level.song
	var bodies: Array = level.gate_defenders.duplicate()
	var posts: Array = bodies.map(func(unit): return unit.position)
	if troop == null or support == null or bodies.size() != 3:
		push_error("missing authored pressure squad or guard posts")
		quit(2)
		return
	troop.position = battle.map.cell_to_world(Vector2i(23, 28))
	await _wait(4.4)
	check(level.defense_state == "watch" and not battle.mission.has_event(level.FEINT_HAPPENED),
		"a single forward unit does not draw the gate guard")
	support.position = battle.map.cell_to_world(Vector2i(23, 27))
	var health: float = troop.hp + support.hp
	await _wait(5.2)
	check(level.defense_state == "feint" and battle.mission.has_event(level.FEINT_HAPPENED)
		and troop.hp + support.hp < health, "two units hold under real fire and draw the defenders")
	check(bodies[0].position.distance_to(posts[0]) > 32.0 and bodies[1].position.distance_to(posts[1]) > 32.0
		and bodies[2].position.distance_to(posts[2]) < 32.0, "two original guards physically move while the third keeps his post")
	_click(battle, [troop, support], Vector2i(38, 27))
	await _wait(14.0)
	check(level.defense_state == "watch" and bodies[0].position.distance_to(posts[0]) <= 32.0
		and bodies[1].position.distance_to(posts[1]) <= 32.0, "withdrawal releases both guards back to their own posts")
	check(level.gate_defenders == bodies, "withdrawal preserves the original guard slots")
	await _dispose(battle)
	battle = await _start()
	Engine.time_scale = 3.0
	level = battle.level
	troop = battle.find_unit("lin_chong")
	support = level.song
	level._introduce_sun(battle)
	troop.position = battle.map.cell_to_world(Vector2i(23, 28))
	support.position = battle.map.cell_to_world(Vector2i(23, 27))
	level.sun.position = battle.map.cell_to_world(level.INNER_CONTACT)
	_action(battle, level.sun, "zhu_rts_inside")
	await _wait(6.0)
	check(level.defense_state == "feint" and level.inside_open
		and battle.mission.has_event(level.FEINT_AT_SIDE), "Sun Li opens the side gate without retargeting the distracted guards")
	check(level.campaign_debrief(battle.mission).back().source.begins_with("重玩建议 · 本局佯攻接应成功"),
		"debrief suggests a frontal attack after a successful diversion")
	Engine.time_scale = 1.0
	print("ZHU_FEINT_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)
