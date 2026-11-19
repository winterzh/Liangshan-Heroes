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
	var localize := root.get_node("Localize")
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
	check("持续4秒" in level.unit_tactical_hint(battle, level.gate),
		"visible gate displays how to trigger the diversion before it starts")
	var health: float = troop.hp + support.hp
	await _wait(5.2)
	check(level.defense_state == "feint" and battle.mission.has_event(level.FEINT_HAPPENED)
		and troop.hp + support.hp < health, "two units hold under real fire and draw the defenders")
	check(bodies[0].position.distance_to(posts[0]) > 32.0 and bodies[1].position.distance_to(posts[1]) > 32.0
		and bodies[2].position.distance_to(posts[2]) < 32.0, "two original guards physically move while the third keeps his post")
	check(level.unit_tactical_hint(battle, level.gate) == localize.text("正门佯攻生效 · 部分守军已被引向正门"),
		"visible gate displays active diversion after guards take the order")
	_click(battle, [troop, support], Vector2i(38, 27))
	for step in range(45):
		if level.defense_state == "returning":
			break
		await _wait(0.25)
	check(level.defense_state == "returning" and level._has_feint_guards(battle.mission),
		"the released guards return before the diversion becomes available again")
	battle._reveal_fog_at(level.gate.position, 32.0, 1.0)
	check(level.unit_tactical_hint(battle, level.gate) == localize.text("佯攻已解除 · 守军正返回原岗位"),
		"inspecting the revealed gate shows the guards are returning")
	await _wait(10.0)
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
	await _wait(5.0)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	const ACTIVE := "正门佯攻生效 · 部分守军已被引向正门"
	const OBJECTIVE := "部分守军已被引向正门。保持正门压力，让孙立到偏门接应；还需破营、救出时迁。"
	for language in ["zh_CN", "zh_TW", "en", "ja"]:
		localize.set_language(language, false)
		await process_frame
		var expected_gate := ACTIVE if language == "zh_CN" else String(catalog[ACTIVE][language])
		var expected_objective := OBJECTIVE if language == "zh_CN" else String(catalog[OBJECTIVE][language])
		check(level.unit_tactical_hint(battle, level.gate) == expected_gate
			and battle.mission._objective.text == expected_objective, "gate and active route objective in " + language)
	localize.set_language("zh_CN", false)
	_action(battle, level.sun, "zhu_rts_inside")
	await _wait(6.0)
	check(level.defense_state == "feint" and level.inside_open
		and battle.mission.has_event(level.FEINT_AT_SIDE), "Sun Li opens the side gate without retargeting the distracted guards")
	check(level.campaign_debrief(battle.mission).back().source.begins_with("重玩建议 · 本局佯攻接应成功"),
		"debrief suggests a frontal attack after a successful diversion")
	check(battle.mission.objective.begins_with("偏门已可通行"),
		"opening the side gate restores the rescue objective")
	await _dispose(battle)
	battle = await _start()
	level = battle.level
	level._introduce_sun(battle)
	battle.find_unit("lin_chong").position = battle.map.cell_to_world(Vector2i(23, 28))
	level.song.position = battle.map.cell_to_world(Vector2i(23, 27))
	level.sun.position = battle.map.cell_to_world(level.INNER_CONTACT)
	await _wait(5.0)
	check(level.defense_state == "feint", "third battle draws the original guards")
	for index in range(level.gate_defenders.size()):
		if battle.mission.has_event(level.FEINT_SHIFTS[index]):
			level.gate_defenders[index].take_damage(100000.0, level.song, false, true)
	await _wait(0.7)
	check(not level._has_feint_guards(battle.mission) and battle.mission.objective != OBJECTIVE,
		"no active diversion guidance after all redirected guards die")
	_action(battle, level.sun, "zhu_rts_inside")
	await _wait(6.0)
	check(level.inside_open and not battle.mission.has_event(level.FEINT_AT_SIDE),
		"Sun Li can still open the gate without a false active-diversion record")
	Engine.time_scale = 1.0
	print("ZHU_FEINT_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)
