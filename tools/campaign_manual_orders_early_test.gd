extends SceneTree
## Player-order contract for the first four campaign chapters. Every mission
## interaction in this suite begins with Battle.select_single + Battle._issue_order,
## the same route used by a right click in the running game. It deliberately does
## not call CampaignMission.request_action or press a task button.

var failures: Array[String] = []
var checks := 0
var move_orders := 0
var attack_orders := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("[manual-early] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func _start(level_id: String):
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == level_id:
			campaign.current = i
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._smoke = false
	b.hud._on_start_pressed()
	Engine.time_scale = 6.0
	return b


func _dispose(b) -> void:
	if is_instance_valid(b):
		b.queue_free()
	await process_frame
	await process_frame


func _wait_until(predicate: Callable, limit := 6000) -> bool:
	var frames := 0
	while not predicate.call() and frames < limit:
		await process_frame
		frames += 1
	return bool(predicate.call())


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _manual_right_click(b, actor, logic_position: Vector2) -> bool:
	if not is_instance_valid(actor) or actor.hp <= 0.0 or actor.story_outcome != "":
		return false
	b.select_single(actor, false)
	b._issue_order(b.to_screen(logic_position), false)
	if actor._state == 0:
		print("[manual-early-debug] issued-idle actor=", actor.key, " pos=", actor.position,
			" requested=", logic_position, " selected=", b.selection.has(actor), " target=", actor._target,
			" path=", actor._path.size(), " manual_t=", actor.manual_order_t,
			" manual_active=", actor.manual_order_active, " mission_active=", actor.mission_order_active,
			" mission_arrival=", actor.mission_order_arrival_t, " mission_target=", actor.mission_order_target,
			" mission_token=", actor.mission_order_token)
	return actor.manual_order_t > 0.0 and actor.manual_order_active


func _manual_move_action(b, actor, action_id: String, limit := 5000) -> bool:
	if not b.mission.actions.has(action_id):
		return false
	var stage_id: String = b.mission.stage_id
	var action: Dictionary = b.mission.actions[action_id]
	var destination: Vector2 = b.map.cell_to_world(action.cell)
	move_orders += 1
	if not _manual_right_click(b, actor, destination):
		return false
	if not (actor.mission_order_active or actor.mission_order_arrival_t > 0.0) \
			or actor.mission_order_token <= 0 \
			or actor.mission_order_target.distance_to(destination) > 0.1:
		return false
	var event_id := "action:%s:%s" % [stage_id, action_id]
	var arrived: bool = await _wait_until(func(): return b.mission.has_event(event_id) or b.phase == b.Phase.END, limit)
	if not arrived or not b.mission.has_event(event_id):
		print("[manual-early-debug] action=", action_id, " actor=", actor.key, " pos=", actor.position,
			" dest=", destination, " distance=", actor.position.distance_to(destination), " state=", actor._state,
			" cell=", action.cell, " open=", b.map.is_open_cell(action.cell, actor.movement_profile),
			" nearest_open=", b.map.nearest_open(action.cell, actor.movement_profile),
			" segment_open=", b.map._segment_open(actor.position, destination, actor.movement_profile),
			" path=", actor._path.size(), " path_i=", actor._path_i, " manual_t=", actor.manual_order_t,
			" manual_active=", actor.manual_order_active, " mission_active=", actor.mission_order_active,
			" mission_arrival=", actor.mission_order_arrival_t, " mission_target=", actor.mission_order_target,
			" mission_token=", actor.mission_order_token,
			" active_action=", b.mission.active_action_id,
			" phase=", b.phase, " end_title=", b.hud._end_title.text, " end_sub=", b.hud._end_sub.text)
	return arrived and b.mission.has_event(event_id)


func _manual_move_to(b, actor, destination: Vector2, predicate: Callable, limit := 5000) -> bool:
	move_orders += 1
	if not _manual_right_click(b, actor, destination):
		return false
	if not (actor.mission_order_active or actor.mission_order_arrival_t > 0.0) \
			or actor.mission_order_token <= 0 \
			or actor.mission_order_target.distance_to(destination) > 0.1:
		return false
	return await _wait_until(predicate, limit)


func _manual_attack(b, actor, target) -> bool:
	if not is_instance_valid(target):
		return false
	attack_orders += 1
	if not _manual_right_click(b, actor, target.position):
		return false
	return actor._target == target


func _core_only(b, missed_goal: String) -> bool:
	var result: Dictionary = b.mission.result_snapshot(true)
	return bool(result.get("core_cleared", false)) and not bool(result.get("story_complete", false)) \
		and Array(result.get("missed_ids", [])).has(missed_goal)


func _selected(case_id: String) -> bool:
	var requested := OS.get_environment("MANUAL_EARLY_CASES")
	return requested == "" or case_id in requested.split(",")


func _retire_hostiles(b) -> void:
	for u in b.units.duplicate():
		if is_instance_valid(u) and u.faction == 1 and u.story_outcome == "":
			u.resolve_story("retreated")


func _case_yezhulin() -> void:
	var b = await _start("level6")
	var l = b.level
	check(await _manual_attack(b, l.lu, l.escorts[0]), "野猪林：右键敌人实际下达鲁智深提前攻击令")
	check(await _wait_until(func(): return b.mission.has_event("yezhulin_early_force") and l.st == l.CARE, 300), "野猪林：提前接战由单位目标检测切入公开救援")
	for guard in l.escorts:
		if is_instance_valid(guard) and guard.story_outcome == "":
			guard.resolve_story("subdued")
	check(await _wait_until(func(): return l.st == l.ESCAPE, 1200) \
			and b.mission.has_event("untie") and b.mission.has_event("tend_feet"),
		"野猪林：现场安全后解缚照伤剧情自然继续")
	check(b.mission._buttons.get_child_count() == 1 and b.mission.actions.has("rest_stop") \
			and not b.mission.actions.has("leave_forest"),
		"野猪林：公开救援后只开放四人歇脚的查看按钮")
	var lu_stays: Vector2 = l.lu.position
	var lin_stays: Vector2 = l.lin_freed.position
	var guard_stays: Array = l.escorts.map(func(u): return u.position)
	await _wait_frames(90)
	check(l.lu.position.distance_to(lu_stays) < 2.0 and l.lin_freed.position.distance_to(lin_stays) < 2.0 \
			and l.escorts[0].position.distance_to(guard_stays[0]) < 2.0 \
			and l.escorts[1].position.distance_to(guard_stays[1]) < 2.0,
		"野猪林：玩家不下令时相送四人都不会被系统接管")
	check(await _manual_move_action(b, l.lin_freed, "rest_stop") \
			and b.mission.actions.has("leave_forest"),
		"野猪林：玩家只点林冲下令，四人先结队到林边歇脚")
	check(await _manual_move_action(b, l.lin_freed, "leave_forest"),
		"野猪林：玩家第二次下令，四人结队出林")
	check(await _wait_until(func(): return b.phase == b.Phase.END, 600), "野猪林：四人真实抵达林口后完成核心通关")
	check(_core_only(b, "hidden_intercept") and b.mission.has_event("tend_feet"), "野猪林：提前接战只丢失对应的暗护演义目标")
	var victory_events: int = b.mission.events.keys().filter(func(key): return String(key) == "yezhulin_victory").size()
	await _wait_frames(12)
	check(victory_events == 1, "野猪林：核心胜利事件只结算一次")
	await _dispose(b)


func _case_huangnigang() -> void:
	var b = await _start("level1")
	var l = b.level
	var wu = b.find_unit("wu_yong")
	var wu_before: Vector2 = wu.position
	var scout_button: Button = b.mission.actions["scout_shade"].button
	scout_button.emit_signal("pressed")
	await _wait_frames(12)
	check(scout_button.text.begins_with("查看 · ") and b.mission.active_action_id == "" \
			and wu.position.distance_to(wu_before) < 1.0 and not wu.has_meta(b.mission.AUTO_DISPATCH_META),
		"黄泥岗：任务按钮只定位现场，不替吴用下令")
	check(await _manual_move_action(b, wu, "scout_shade"), "黄泥冈：吴用手动察看松阴")
	check(await _manual_move_action(b, b.find_unit("chao_gai"), "place_dates"), "黄泥冈：晁盖手动到位安置枣车")
	check(await _wait_until(func(): return is_instance_valid(l.yang), 5000), "黄泥冈：两个手动准备动作后押送队实际上冈")
	var attacker = b.find_unit("liu_tang")
	check(await _manual_attack(b, attacker, l.yang), "黄泥冈：右键杨志实际下达提前动武令")
	check(await _wait_until(func(): return l.st == l.FORCE and b.mission.has_event("huangnigang_force"), 300), "黄泥冈：提前攻击实际切换强夺路线")
	for guard in l.convoy:
		if is_instance_valid(guard) and guard.story_outcome == "":
			guard.resolve_story("subdued")
	var carriers := [b.find_unit("chao_gai"), b.find_unit("liu_tang"), b.find_unit("wu_yong")]
	for i in range(3):
		var take_id := "force_take_%d_%d" % [i, int(l.force_attempts.get(i, 0))]
		check(await _manual_move_action(b, carriers[i], take_id), "黄泥冈：手动走到第%d担旁接手纲担" % (i + 1))
		await _wait_frames(3)
		var unintended_pickup := false
		var carrier_still_eligible := false
		for other in range(i + 1, 3):
			unintended_pickup = unintended_pickup or l.cargo.has(other)
		for pending_id in b.mission.actions:
			if String(pending_id).begins_with("force_take_") and not bool(b.mission.actions[pending_id].done):
				carrier_still_eligible = carrier_still_eligible or Array(b.mission.actions[pending_id].actors).has(carriers[i].key)
		check(not unintended_pickup and not carrier_still_eligible and b.mission.active_action_id == "", "黄泥冈：一次接担命令不会连触相邻纲担")
		var deliver_id := "force_deliver_%d_%d" % [i, int(l.force_attempts.get(i, 0))]
		var delivered_ok: bool = await _manual_move_action(b, carriers[i], deliver_id)
		var eligible_after_delivery := true
		for pending_id in b.mission.actions:
			if String(pending_id).begins_with("force_take_") and not bool(b.mission.actions[pending_id].done):
				eligible_after_delivery = eligible_after_delivery and Array(b.mission.actions[pending_id].actors).has(carriers[i].key)
		check(delivered_ok and eligible_after_delivery, "黄泥冈：搬运者手动送出第%d担并恢复接力资格" % (i + 1))
	check(await _wait_until(func(): return b.phase == b.Phase.END, 5000), "黄泥冈：三担均由玩家手动搬运后完成自由核心通关")
	check(l.delivered == 3 and _core_only(b, "wine_scheme") and not b.mission.has_event("drugged"), "黄泥冈：强夺通关不伪造原著酒计奖励")
	var delivered_events: int = b.mission.events.keys().filter(func(key): return String(key).begins_with("force_delivered_")).size()
	check(delivered_events == 3, "黄泥冈：三担送达各结算一次且无重复触发")
	await _dispose(b)


func _case_kuaihuolin() -> void:
	var b = await _start("level7")
	var l = b.level
	check(await _manual_attack(b, l.wu, l.menshen), "快活林：右键蒋门神实际下达直接挑战令")
	check(await _wait_until(func(): return l.st == l.SHOWDOWN and b.mission.has_event("kuaihuolin_early_showdown"), 300), "快活林：未饮酒的提前接战进入拳脚对决")
	l.menshen.resolve_story("subdued")
	check(await _wait_until(func(): return l.st == l.RETURN_SHOP, 120), "快活林：非致死制服后开放还店阶段")
	await _wait_frames(36)
	check(not b.mission.has_event("terms") and b.mission.active_action_id != "terms", "快活林：攻击命令不会自动串成原著退店条件")
	check(await _manual_move_action(b, l.shi, "restore_shop"), "快活林：玩家另选施恩手动接管酒店")
	check(b.phase == b.Phase.END and _core_only(b, "three_bowls"), "快活林：直接挑战可通关且只丢相应演义奖励")
	check(l.menshen.story_outcome == "subdued" and not b.mission.has_event("terms"), "快活林：蒋门神保持制服，未伪造玩家未执行的谈条件事件")
	await _dispose(b)


func _case_jiangzhou() -> void:
	var b = await _start("level2")
	var l = b.level
	var attacker = b.find_unit("hua_rong")
	var executioners: Array = b.units.filter(func(u): return is_instance_valid(u) and u.key == "guan_zhanzi" and u.story_outcome == "")
	check(executioners.size() == 2 and await _manual_attack(b, attacker, executioners[0]), "江州：非李逵右键刽子手实际下达提前攻击令")
	check(await _wait_until(func(): return l.st == l.BREAK_EXEC and b.mission.has_event("jiangzhou_other_first"), 300), "江州：任意好汉提前接战均能发动劫法场")
	for executioner in executioners:
		if is_instance_valid(executioner) and executioner.story_outcome == "":
			executioner.take_damage(100000.0, attacker, true, true)
	check(await _wait_until(func(): return l.st == l.RESCUE and b.mission.actions.has("free_song"), 300), "江州：打断行刑后开放两名囚犯的现场解缚")
	_retire_hostiles(b)
	# The physical rescue reaches overlap, but the 24px marker hit areas do not.
	# First click their midpoint, then Dai's later marker, to prove both boundaries.
	var chao = b.find_unit("chao_gai")
	var near_stage_safe: Vector2 = b.map.cell_to_world(l.SCAFFOLD + Vector2i(-2, 3))
	var near_stage_arrived: bool = await _manual_move_to(b, chao, near_stage_safe,
		func(): return chao.position.distance_to(near_stage_safe) < 72.0, 3000)
	var marker_midpoint: Vector2 = b.map.cell_to_world(l.SCAFFOLD + Vector2i(0, 1))
	move_orders += 1
	var midpoint_ordered: bool = _manual_right_click(b, chao, marker_midpoint) \
		and chao.mission_order_token > 0 and chao.mission_order_target.distance_to(marker_midpoint) <= 0.1
	await _wait_frames(45)
	var midpoint_rejected: bool = not l.rescued_song and not l.rescued_dai \
		and not b.mission.has_event("free_song") and not b.mission.has_event("free_dai")
	check(near_stage_arrived and midpoint_ordered and midpoint_rejected and await _manual_move_action(b, chao, "free_dai"),
		"江州：点两标记中点只移动，精确点后登记的戴宗标记才救下戴宗")
	await _wait_frames(30)
	check(not l.rescued_song and not b.mission.has_event("free_song") and b.mission.active_action_id != "free_song", "江州：点戴宗不会按登记顺序误救宋江，也不会串触相邻任务")
	var yan = b.find_unit("yan_shun")
	check(await _manual_move_action(b, yan, "free_song"), "江州：玩家另选燕顺手动救下宋江")
	check(await _wait_until(func(): return l.st == l.RETREAT and l.rescued_song and l.rescued_dai, 300), "江州：两次独立手动解缚后进入自由撤退")
	_retire_hostiles(b)
	var dock: Vector2 = b.map.cell_to_world(l.DOCK_C)
	var song_order_ok = await _manual_move_to(b, l.song_freed, dock, func(): return l.song_freed.position.distance_to(dock) < l.DOCK_R or l.st == l.EMBARK, 6000)
	var dai_order_ok = await _manual_move_to(b, l.dai_freed, dock + Vector2(24, 0), func(): return l.st == l.EMBARK, 6000)
	check(song_order_ok and dai_order_ok and b.mission.has_event("jiangzhou_direct_dock"), "江州：宋江戴宗可由玩家直接下令去码头，无需选择剧情巷道")
	check(not b.mission.has_event("route_west") and not b.mission.has_event("route_south") and not b.mission.has_event("bailong"), "江州：直奔码头不会伪造选路和白龙庙事件")
	if not b.mission.has_event("board_song"):
		check(await _manual_move_action(b, l.song_freed, "board_song"), "江州：宋江手动进入登船区域")
	else:
		check(true, "江州：宋江此前的手动码头命令延续到登船区域")
	if not b.mission.has_event("board_dai"):
		check(await _manual_move_action(b, l.dai_freed, "board_dai"), "江州：戴宗手动进入登船区域")
	else:
		check(true, "江州：戴宗此前的手动码头命令延续到登船区域")
	check(await _wait_until(func(): return b.phase == b.Phase.END, 500), "江州：宋江戴宗登船后不依赖断后按钮即可完成核心通关")
	check(_core_only(b, "li_kui_first") and b.mission.has_event("all_embarked"), "江州：自由救援通关并正确失去李逵排头演义目标")
	var embark_events: int = b.mission.events.keys().filter(func(key): return String(key) in ["board_song", "board_dai", "all_embarked"]).size()
	check(embark_events == 3, "江州：二人登船与胜利事件均只结算一次")
	await _dispose(b)


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	if _selected("yezhulin"): await _case_yezhulin()
	if _selected("huangnigang"): await _case_huangnigang()
	if _selected("kuaihuolin"): await _case_kuaihuolin()
	if _selected("jiangzhou"): await _case_jiangzhou()
	Engine.time_scale = 1.0
	if OS.get_environment("MANUAL_EARLY_CASES") == "":
		check(move_orders >= 17 and attack_orders == 4, "测试本身实际发出足量右键移动/攻击命令")
	print("[manual-early-summary] ", JSON.stringify({
		"passed": failures.is_empty(),
		"checks": checks,
		"move_orders": move_orders,
		"attack_orders": attack_orders,
		"failures": failures,
	}))
	quit(0 if failures.is_empty() else 1)
