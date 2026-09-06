extends SceneTree
## Free-play contracts for the first four story chapters. Success still uses the
## production interaction actions and pathing; injected story resolutions/deaths
## are confined to the explicit branch and soft-lock fixtures below.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("[freeplay-early] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _start(level_id: String, smoke: bool):
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == level_id: campaign.current = i
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._smoke = smoke
	b.hud._on_start_pressed()
	Engine.time_scale = 4.0
	return b

func _dispose(b) -> void:
	if is_instance_valid(b): b.queue_free()
	await process_frame
	await process_frame

func _wait_until(predicate: Callable, limit := 6000) -> bool:
	var frames := 0
	while not predicate.call() and frames < limit:
		await process_frame
		frames += 1
	return bool(predicate.call())

func _act(b, action_id: String, limit := 5000) -> bool:
	if not b.mission.actions.has(action_id): return false
	var stage_id: String = b.mission.stage_id
	if not b.mission.request_action(action_id): return false
	var event_id := "action:%s:%s" % [stage_id, action_id]
	var frames := 0
	while b.phase == b.Phase.FIGHT and not b.mission.has_event(event_id) and frames < limit:
		await process_frame
		frames += 1
	return b.mission.has_event(event_id)

func _manual_act(b, actor, action_id: String, limit := 5000) -> bool:
	if not b.mission.actions.has(action_id): return false
	var stage_id: String = b.mission.stage_id
	var destination: Vector2 = b.map.cell_to_world(b.mission.actions[action_id].cell)
	b.select_single(actor, false)
	b._issue_order(b.to_screen(destination), false)
	var event_id := "action:%s:%s" % [stage_id, action_id]
	return await _wait_until(func(): return b.mission.has_event(event_id) or b.phase == b.Phase.END, limit) \
		and b.mission.has_event(event_id)

func _contract_shape(level) -> bool:
	var goals: Array = level.campaign_story_goals()
	return level.campaign_core_goal() != "" and level.story_contract_version() >= 1 and goals.size() >= 3 and goals.size() <= 5 \
		and goals.all(func(goal): return goal.has("id") and goal.has("label") and goal.has("required_events") and goal.has("forbidden_events"))

func _core_only_result(b, expected_missed_goal: String) -> bool:
	var result: Dictionary = b.mission.result_snapshot(true)
	return bool(result.get("core_cleared", false)) and not bool(result.get("story_complete", false)) \
		and Array(result.get("missed_ids", [])).has(expected_missed_goal)

func _selected(case_id: String) -> bool:
	var requested := OS.get_environment("FREEPLAY_EARLY_CASES")
	return requested == "" or case_id in requested.split(",")

func _case_yezhulin() -> void:
	var b = await _start("level6", false)
	var l = b.level
	check(_contract_shape(l), "野猪林登记核心目标与3至5项演义目标")
	l.lu.order_attack(l.escorts[0])
	check(await _wait_until(func(): return b.mission.has_event("yezhulin_early_force") or b.phase == b.Phase.END, 600), "提前攻击真实切入公开救援状态")
	for guard in l.escorts:
		if is_instance_valid(guard) and guard.story_outcome == "": guard.resolve_story("subdued")
	check(b.phase == b.Phase.FIGHT and l.st == l.CARE and not l._escorts_threatening(),
		"提前制服解差不会判败，现场转入自然解缚")
	check(await _wait_until(func(): return l.st == l.ESCAPE or b.phase == b.Phase.END, 1200) \
			and b.mission.has_event("untie") and b.mission.has_event("tend_feet"),
		"现场安全后自动完成解缚与照伤，不再依赖旧任务按钮")
	var lu_after_care: Vector2 = l.lu.position
	var lin_after_care: Vector2 = l.lin_freed.position
	var guards_after_care: Array = l.escorts.map(func(u): return u.position)
	for _i in range(60):
		await process_frame
	check(l.lu.position.distance_to(lu_after_care) < 2.0 and l.lin_freed.position.distance_to(lin_after_care) < 2.0 \
			and l.escorts[0].position.distance_to(guards_after_care[0]) < 2.0 \
			and l.escorts[1].position.distance_to(guards_after_care[1]) < 2.0 \
			and b.mission._buttons.get_child_count() == 1 and b.mission.actions.has("rest_stop"),
		"公开救援后四人原地等玩家命令，查看按钮只负责定位")
	check(await _manual_act(b, l.lin_freed, "rest_stop") and b.mission.actions.has("leave_forest") \
			and await _manual_act(b, l.lin_freed, "leave_forest") \
			and await _wait_until(func(): return b.phase == b.Phase.END, 600),
		"玩家用两次真实路线命令带四人歇脚并结队出林")
	check(b.mission.has_event("yezhulin_victory") and not b.mission.has_event("intercept") \
			and b.mission.has_event("tend_feet") and b.mission.has_event("warn_escorts") \
			and b.mission.has_event("yezhulin_four_left"),
		"自由胜利保留照伤和四人相送，但不伪造暗中拦棍事件")
	check(_core_only_result(b, "hidden_intercept"), "野猪林偏离只丢演义印，核心通关仍结算")
	await _dispose(b)

func _case_kuaihuolin() -> void:
	var b = await _start("level7", false)
	var l = b.level
	check(_contract_shape(l), "快活林登记核心目标与3至5项演义目标")
	l.wu.order_attack(l.menshen)
	check(await _wait_until(func(): return l.st == l.SHOWDOWN or b.phase == b.Phase.END, 600), "武松可不饮酒直接挑战蒋门神")
	if b.phase == b.Phase.FIGHT and l.menshen.story_outcome == "": l.menshen.resolve_story("subdued")
	check(await _wait_until(func(): return l.st == l.RETURN_SHOP or b.phase == b.Phase.END, 120), "提前挑战仍以非致死制服进入接店阶段")
	check(b.mission.actions.has("restore_shop") and await _act(b, "restore_shop"), "施恩可跳过退店条件直接接管酒店")
	check(b.phase == b.Phase.END and b.mission.has_event("restore_shop") and l.menshen.story_outcome == "subdued", "直接挑战完成核心目标，蒋门神保持制服状态")
	check(l.drunk == 0 and not b.mission.has_event("provoke") and not b.mission.has_event("terms"), "自由通关未伪造无三不过望与原著退店事件")
	check(_core_only_result(b, "three_bowls"), "快活林偏离只丢演义印，核心通关仍结算")
	await _dispose(b)

func _case_jiangzhou_softlock() -> void:
	var b = await _start("level2", true)
	var l = b.level
	check(_contract_shape(l), "江州登记核心目标与3至5项演义目标")
	check(await _wait_until(func(): return l.rescued_song and l.rescued_dai and l.st == l.RETREAT, 12000), "原主链真实救出宋江、戴宗后进入撤退")
	b._smoke = false
	for enemy in b.units.duplicate():
		if is_instance_valid(enemy) and enemy.faction == 1 and enemy.story_outcome == "": enemy.resolve_story("retreated")
	for doomed in l.rescuing_army.duplicate():
		if is_instance_valid(doomed): doomed.take_damage(100000.0, null, true, true)
	await process_frame
	check(b.phase == b.Phase.FIGHT and l._living_rescuers() == 0 and not l._living(b.find_unit("li_kui")) and not l._living(b.find_unit("yan_shun")), "二人获救后即使其他救援者全部失去，仍可自行撤到码头")
	var dock: Vector2 = b.map.cell_to_world(l.DOCK_C)
	l.song_freed.order_move(dock)
	l.dai_freed.order_move(dock + Vector2(20, 0))
	check(await _wait_until(func(): return l.st == l.EMBARK or b.phase == b.Phase.END, 5000), "两位获救者可自行走到码头触发直接登船")
	check(b.mission.has_event("jiangzhou_direct_dock") and not b.mission.actions.has("rearguard_li") and not b.mission.actions.has("rearguard_yan"), "无人可选时不再生成固定断后软锁")
	check(await _act(b, "board_song") and await _act(b, "board_dai"), "宋江、戴宗分别以真实登船动作脱险")
	check(await _wait_until(func(): return b.phase == b.Phase.END, 300), "两名核心人物登船后立即完成营救")
	check(b.mission.has_event("all_embarked") and not b.mission.has_event("jiangzhou_named_survive"), "核心胜利不会伪造全员脱险演义目标")
	check(_core_only_result(b, "named_survive"), "江州其他伤亡只丢演义印，二人登船仍结算")
	await _dispose(b)

	b = await _start("level2", false)
	l = b.level
	var early_actor = b.find_unit("hua_rong")
	var executioners: Array = b.units.filter(func(u): return is_instance_valid(u) and u.key == "guan_zhanzi")
	for executioner in executioners:
		executioner.take_damage(100000.0, early_actor, true, true)
	check(await _wait_until(func(): return l.st == l.RESCUE or b.phase == b.Phase.END, 120), "非李逵提前击倒刽子手也真实转入刑台救人")
	check(b.phase == b.Phase.FIGHT and b.mission.has_event("jiangzhou_other_first") and b.mission.actions.has("free_song") and b.mission.actions.has("free_dai"), "提前动手只失李逵排头演义目标，不会停在潜入阶段")
	await _dispose(b)

func _case_huangnigang_force() -> void:
	var b = await _start("level1", true)
	var l = b.level
	check(_contract_shape(l), "黄泥冈登记核心目标与3至5项演义目标")
	check(await _wait_until(func(): return is_instance_valid(l.yang), 5000), "押送队按原流程实际上冈")
	b._smoke = false
	var attacker = b.find_unit("liu_tang")
	attacker.order_attack(l.yang)
	check(await _wait_until(func(): return l.st == l.FORCE or b.phase == b.Phase.END, 600), "主动动武真实切换强夺路线")
	var hostile: bool = l.convoy.any(func(guard): return is_instance_valid(guard) and guard.story_outcome == "" and not guard.passive and guard.stance == 0)
	check(b.phase == b.Phase.FIGHT and hostile and b.mission.has_event("huangnigang_force"), "身份败露后押送队实际敌对，不是只删除失败")
	for guard in l.convoy:
		if is_instance_valid(guard) and guard.story_outcome == "": guard.resolve_story("subdued")
	var original_bundle_id: int = l.bundles[0].get_instance_id()
	check(await _act(b, "force_take_0_0"), "任一幸存好汉可真实挑起第一担")
	var first_carrier: Object = l.cargo.get(0)
	check(is_instance_valid(first_carrier) and first_carrier.has_meta("carrying_tribute") and not b.units.has(l.bundles[0]), "拾取使用同一纲担对象并从世界查询隐藏")
	first_carrier.take_damage(100000.0, null, true, true)
	await process_frame
	await process_frame
	check(is_instance_valid(l.bundles[0]) and l.bundles[0].get_instance_id() == original_bundle_id and b.units.has(l.bundles[0]) and l.bundles[0].visible, "固定搬运者死亡时原纲担真实落地")
	check(b.mission.actions.has("force_take_0_1"), "落担后自动开放另一名好汉接力，不永久丢任务")
	for i in range(3):
		var attempt: int = int(l.force_attempts.get(i, 0))
		check(await _act(b, "force_take_%d_%d" % [i, attempt]), "强夺路线接手第%d担" % (i + 1))
		check(await _act(b, "force_deliver_%d_%d" % [i, attempt]), "强夺路线送出第%d担" % (i + 1))
	check(l.delivered == 3 and l.st == l.WITHDRAW, "三担均可由动态搬运者送出并进入撤离")
	check(await _wait_until(func(): return b.phase == b.Phase.END, 5000), "强夺路线至少一名幸存者出冈后完成核心胜利")
	check(b.mission.has_event("escaped") and b.mission.has_event("huangnigang_convoy_hurt") and not b.mission.has_event("drugged"), "强夺胜利不伪造原著无伤酒计")
	check(_core_only_result(b, "wine_scheme"), "黄泥冈强夺只丢演义印，三担出冈仍结算")
	await _dispose(b)

func _case_core_failures() -> void:
	var b = await _start("level6", false)
	b.level.lin_freed.take_damage(100000.0, null, true, true)
	check(await _wait_until(func(): return b.phase == b.Phase.END, 30) and not b.mission.has_event("yezhulin_victory"), "野猪林林冲遇害时核心目标仍判败")
	await _dispose(b)

	b = await _start("level7", false)
	b.level.shi.take_damage(100000.0, null, true, true)
	check(await _wait_until(func(): return b.phase == b.Phase.END, 30) and not b.mission.has_event("restore_shop"), "快活林施恩遇害时核心目标仍判败")
	await _dispose(b)

	b = await _start("level2", true)
	check(await _wait_until(func(): return b.level.rescued_song and is_instance_valid(b.level.song_freed), 12000), "江州核心失败夹具先通过真实任务救出宋江")
	if is_instance_valid(b.level.song_freed):
		b.level.song_freed.take_damage(100000.0, null, true, true)
	check(await _wait_until(func(): return b.phase == b.Phase.END, 30) and not b.mission.has_event("all_embarked"), "江州宋江获救后遇害时核心目标仍判败")
	await _dispose(b)

	b = await _start("level1", false)
	b.level.bundles[0].take_damage(100000.0, null, true, true)
	check(await _wait_until(func(): return b.phase == b.Phase.END, 30) and not b.mission.has_event("escaped"), "黄泥冈纲担被毁时核心目标仍判败")
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	if _selected("yezhulin"): await _case_yezhulin()
	if _selected("kuaihuolin"): await _case_kuaihuolin()
	if _selected("jiangzhou"): await _case_jiangzhou_softlock()
	if _selected("huangnigang"): await _case_huangnigang_force()
	if _selected("core_failures"): await _case_core_failures()
	Engine.time_scale = 1.0
	print("[freeplay-early-summary] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
