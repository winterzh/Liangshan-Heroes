extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, name: String) -> void:
	print("[freeplay-core] ", "PASS " if ok else "FAIL ", name)
	if not ok:
		failures.append(name)

func _save_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _adjacent_manual_checks(b, Mission, actor, companion) -> void:
	# Explicit frozen interaction fixture: only positions and click receipts are
	# supplied. Production action selection/consumption still handles every case.
	var original_actor: Vector2 = actor.position
	var original_companion: Vector2 = companion.position
	var cell := Vector2i(-1, -1)
	for y in range(1, b.map.h - 1):
		for x in range(1, b.map.w - 3):
			if range(4).all(func(i): return b.map.is_open_cell(Vector2i(x + i, y))):
				cell = Vector2i(x, y); break
		if cell.x >= 0: break
	if cell.x < 0:
		check(false, "adjacent action fixture has a connected open strip"); return
	var destination: Vector2 = b.map.cell_to_world(cell)
	var neighbour: Vector2 = b.map.cell_to_world(cell + Vector2i(1, 0))
	var fixture = Mission.new(b)
	fixture.begin("adjacent", "相邻事项凭证", "原始点击先确定目标，再检查人物是否到场")
	fixture.add_action("intended", "指定事项", cell, [actor.key, companion.key], 0.2, 48.0)
	fixture.add_action("neighbour", "途经事项", cell + Vector2i(1, 0), [actor.key, companion.key], 0.2, 48.0)
	actor.order_stop(); companion.order_stop()
	actor.position = destination + Vector2(64.0, 0.0)
	actor.stamp_mission_order_intent(destination, 101)
	var planned: Dictionary = fixture.prepare_manual_move([actor], destination)
	check(planned.get("actor") == actor and planned.get("target") == destination,
		"manual movement keeps the exact clicked destination despite a nearer actor-side marker")
	check(not fixture._try_manual_action() and fixture.active_action_id == "" and actor.mission_order_token == 101,
		"a neighbouring marker in reach cannot claim a click whose intended marker is still out of reach")
	actor.position = destination
	check(fixture._try_manual_action() and fixture.active_action_id == "intended" and fixture._actor == actor \
		and actor.mission_order_token == 0 and not fixture.actions.neighbour.done,
		"reaching the intended marker claims that action and consumes its original receipt")
	fixture.begin("independent", "独立事项凭证", "远处人物不得阻挡另一个已到场人物")
	fixture.add_action("intended", "远处指定事项", cell, [actor.key, companion.key], 0.2, 48.0)
	fixture.add_action("neighbour", "独立指定事项", cell + Vector2i(1, 0), [actor.key, companion.key], 0.2, 48.0)
	actor.position = destination + Vector2(64.0, 0.0)
	companion.position = neighbour
	actor.stamp_mission_order_intent(destination, 201)
	companion.stamp_mission_order_intent(neighbour + Vector2(0.0, 8.0), 202)
	check(fixture._try_manual_action() and fixture.active_action_id == "neighbour" and fixture._actor == companion \
		and actor.mission_order_token == 201 and companion.mission_order_token == 0,
		"one travelling unit does not block a reachable unit with an independent click receipt")
	fixture.begin("blocked", "禁止串接邻项", "指定事项受阻时保留原始指向")
	fixture.add_action("intended", "被阻止事项", cell, [actor.key], 0.2, 48.0)
	fixture.add_action("neighbour", "可用邻项", cell + Vector2i(1, 0), [actor.key], 0.2, 48.0)
	fixture.block_action("intended", "显式边界夹具")
	actor.position = neighbour
	actor.stamp_mission_order_intent(destination, 301)
	check(fixture.prepare_manual_move([actor], destination).is_empty() and not fixture._try_manual_action() \
		and actor.mission_order_token == 301 and fixture.active_action_id == "",
		"a blocked clicked action never falls back to its available neighbour")
	fixture.actions.intended.erase("blocked_reason")
	fixture.actions.intended.actors = [companion.key]
	check(fixture.prepare_manual_move([actor], destination).is_empty() and not fixture._try_manual_action() \
		and actor.mission_order_token == 301 and fixture.active_action_id == "",
		"an actor ineligible for the clicked action never claims an eligible neighbouring action")
	actor.order_stop(); companion.order_stop()
	actor.position = original_actor; companion.position = original_companion

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	var campaign = root.get_node("Campaign")
	var save_existed := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_before := _save_bytes(campaign.SAVE_PATH)
	var records_before: Dictionary = campaign.records.duplicate(true)
	var unlocked_before: int = campaign.unlocked

	# Old campaign.cfg files have no records key. The normalizer must treat that
	# as an empty, valid migration and ignore unknown/malformed level ids.
	check(campaign._normalized_records(null).is_empty(), "legacy save without records migrates to empty records")
	var normalized: Dictionary = campaign._normalized_records({
		"level1":{"cleared":true,"story_complete":false,"best_done":2,"story_total":4,"best_goal_ids":["a","b"]},
		"level99":{"cleared":true},
		"level2":"bad",
	})
	check(normalized.has("level1") and not normalized.has("level99") and normalized.level2 == campaign._empty_record(),
		"migration keeps known ids and safely defaults malformed records")

	# Best progress is one run, not a union across runs. Later worse results do
	# not erase the best run or an already earned non-numeric story seal.
	campaign.records = {}
	var partial := {"core_cleared":true,"story_complete":false,"story_done":2,"story_total":4,
		"done_ids":["a","b"],"contract_version":1}
	var saved: Dictionary = campaign.record_level_result("level1", partial)
	check(saved.accepted and saved.cleared and saved.best_done == 2 and saved.best_goal_ids == ["a","b"] and not saved.new_story_seal,
		"base clear records one partial run without a story seal")
	var worse := {"core_cleared":true,"story_complete":false,"story_done":1,"story_total":4,
		"done_ids":["c"],"contract_version":1}
	campaign.record_level_result("level1", worse)
	var after_worse: Dictionary = campaign.level_record("level1")
	check(after_worse.best_done == 2 and after_worse.best_goal_ids == ["a","b"],
		"worse replay neither regresses nor unions best story goals")
	var full := {"core_cleared":true,"story_complete":true,"story_done":4,"story_total":4,
		"done_ids":["a","b","c","d"],"contract_version":1}
	var first_full: Dictionary = campaign.record_level_result("level1", full)
	var repeat_full: Dictionary = campaign.record_level_result("level1", full)
	campaign.record_level_result("level1", worse)
	var after_full: Dictionary = campaign.level_record("level1")
	check(first_full.new_story_seal and not repeat_full.new_story_seal and after_full.story_complete and after_full.best_done == 4,
		"story seal is exact-once and later partial clears cannot remove it")
	check(not campaign.record_level_result("level99", full).accepted,
		"unknown level id cannot enter persistent records")

	# Instantiate one real campaign battle so the public mission controller is
	# exercised with actual Unit, GameMap and HUD objects.
	campaign.current = 4
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	b.set_process(false)

	var Mission = load("res://scripts/campaign_mission.gd")
	var mission = Mission.new(b)
	mission.configure_campaign("守住核心据点", [
		{"id":"sequence","label":"依次完成两件原著事件","required_events":["step_a","step_b"],"forbidden_events":[]},
		{"id":"mercy","label":"留人性命","required_events":["spared"],"forbidden_events":["killed"]},
		{"id":"late_forbidden","label":"功成后仍守原著","required_events":["early_ok"],"forbidden_events":["late_break"]},
		{"id":"explicit","label":"显式完成项","required_events":[],"forbidden_events":[]},
	], 3)
	mission.begin("qa_story", "双层结算", "演义目标不阻断基础战斗")
	mission.mark("step_a", "完成第一步")
	mission.mark("early_ok", "先完成演义条件")
	check(mission.story_goals.late_forbidden.state == mission.STORY_PENDING,
		"required events remain candidates until victory settlement")
	mission.mark("late_break", "随后偏离原著")
	mission.mark("killed", "偏离原著，但战斗继续")
	var report_count_after_miss: int = mission.report.size()
	check(b.phase == b.Phase.FIGHT and mission.story_goals.mercy.state == mission.STORY_MISSED \
		and mission._story_miss_notified and not String(mission.story_goals.mercy.reason).contains("killed") \
		and String(mission.story_goals.mercy.reason).contains("留人性命"),
		"forbidden event misses story goal without ending battle or leaking an internal event id")
	check(not mission.miss_story_goal("mercy", "重复偏离") and mission.report.size() == report_count_after_miss,
		"repeated miss is idempotent and does not duplicate report rows")
	mission.begin("qa_story_2", "跨幕继续", "目标状态应保留")
	mission.mark("step_b", "完成第二步")
	check(mission.story_contract_version == 3 and mission.story_goals.sequence.state == mission.STORY_PENDING \
		and mission.story_goals.mercy.state == mission.STORY_MISSED \
		and mission.story_goals.late_forbidden.state == mission.STORY_MISSED,
		"candidate progress and forbidden failures survive begin transition")
	check(mission.complete_story_goal("explicit", "现场选择完成") and not mission.complete_story_goal("explicit"),
		"explicit completion resolves exactly once")
	var settlement: Dictionary = mission.result_snapshot(true)
	var settlement_again: Dictionary = mission.result_snapshot(false)
	check(settlement.core_cleared and not settlement.story_complete and settlement.story_done == 2 and settlement.story_total == 4,
		"base victory and story completion are independent results")
	check(settlement.done_ids.has("sequence") and settlement.missed_ids.has("late_forbidden"),
		"late forbidden event defeats an earlier candidate and prevents a false full seal")
	check(settlement_again == settlement and not mission.complete_story_goal("mercy"),
		"settlement snapshot freezes same-run state against repeat resolution")

	# A normal RTS command can claim an action zone. Merely placing an actor in
	# the zone with no manual-order stamp must not trigger scripted movement.
	var manual_mission = Mission.new(b)
	manual_mission.configure_campaign("手动区域", [
		{"id":"canon","label":"完成现场事件","required_events":["canon_event"],"forbidden_events":[]},
	], 1)
	manual_mission.begin("manual", "手动交互", "走进区域停留")
	var actor = b.find_unit("song_jiang")
	var companion = b.find_unit("wu_yong")
	var actor_cell: Vector2i = b.map.world_to_cell(actor.position)
	var action_destination: Vector2 = b.map.cell_to_world(actor_cell)
	companion.order_stop()
	companion.position = actor.position
	actor.manual_order_t = 0.0
	actor.manual_order_active = false
	# Insert an overlapping action first. Selection must follow the player's click
	# target, not Dictionary insertion order.
	manual_mission.add_action("earlier_nearby", "较早登记的相邻事项", actor_cell + Vector2i(1, 0), [actor.key], 0.2, 96.0)
	manual_mission.add_action("manual_zone", "现场办理", actor_cell, [actor.key], 0.2, 48.0)
	# S/H/P and attack orders carry only the generic anti-AI stamp.
	actor.manual_order_active = true
	manual_mission.tick(0.05)
	var generic_stamp_rejected: bool = manual_mission.active_action_id == ""
	# Passing through the zone on the way elsewhere has a move receipt, but its
	# original click point does not match this action.
	actor.manual_order_t = 0.0
	actor.manual_order_active = false
	actor.mission_order_active = true
	# The actor is physically in reach, but a click 120px beside the marker is an
	# ordinary move and must not be captured even when a crowded stage uses reach=160.
	actor.mission_order_target = action_destination + Vector2(120.0, 0.0)
	actor.mission_order_token = 11
	manual_mission.tick(0.05)
	var crossing_rejected: bool = manual_mission.active_action_id == ""
	# A stop command must consume even an exact old mission target.
	actor.mission_order_active = true
	actor.mission_order_target = action_destination
	actor.mission_order_token = 12
	actor.order_stop()
	manual_mission.tick(0.05)
	check(generic_stamp_rejected and crossing_rejected and manual_mission.active_action_id == "" \
		and not manual_mission.actions.earlier_nearby.done and not manual_mission.actions.manual_zone.done \
		and actor.mission_order_target == Vector2.INF and actor.mission_order_token == 0,
		"script placement, generic S/H/P/attack stamps, path crossing and stopped orders cannot auto-trigger an action zone")
	# Both units share one group-order token. The exact manual-zone click must beat
	# the earlier overlapping action, then consume the companion's copy as well.
	actor.mission_order_active = true
	actor.mission_order_target = action_destination
	actor.mission_order_token = 21
	companion.mission_order_active = true
	companion.mission_order_target = action_destination
	companion.mission_order_token = 21
	actor._done_order()
	companion._done_order()
	manual_mission.tick(0.05)
	check(manual_mission.active_action_id == "manual_zone" and manual_mission._actor == actor \
		and not manual_mission.actions.earlier_nearby.done,
		"the closest clicked marker wins over insertion order and starts the intended action-zone interaction")
	manual_mission.tick(0.25)
	manual_mission.add_action("manual_follow", "相邻后续", actor_cell, [companion.key], 0.2, 48.0)
	manual_mission.tick(0.05)
	check(manual_mission.actions.manual_zone.done and manual_mission.active_action_id == "" \
		and not manual_mission.actions.earlier_nearby.done and not manual_mission.actions.manual_follow.done \
		and actor.manual_order_t <= 0.0 \
		and not actor.manual_order_active and actor.mission_order_arrival_t <= 0.0 \
		and actor.mission_order_target == Vector2.INF and companion.mission_order_target == Vector2.INF \
		and actor.mission_order_token == 0 and companion.mission_order_token == 0,
		"manual zone commits atomically and consumes the whole group token before adjacent follow-ups")
	_adjacent_manual_checks(b, Mission, actor, companion)

	# A task-button route must not leave a fake manual stamp behind. Some stages
	# add an optional early-exit action on the same marker after the first action;
	# it should wait for another player order instead of consuming itself.
	var button_mission = Mission.new(b)
	button_mission.configure_campaign("按钮派遣", [], 1)
	button_mission.begin("button", "按钮派遣隔离", "完成第一项后等待玩家决定")
	button_mission.add_action("first", "第一项", actor_cell, [actor.key], 0.1, 48.0)
	var accepted: bool = button_mission.request_action("first")
	# Exercise the real non-targeted skill entry, not a direct controller call.
	# A valid skill order must cancel the field task before its windup begins.
	var original_battle_mission = b.mission
	b.mission = button_mission
	actor.ability_slots[0]["rank"] = maxi(1, int(actor.ability_slots[0].get("rank", 0)))
	actor.ability_slots[0]["cd_t"] = 0.0
	actor._stun_t = 0.0
	actor._silence_t = 0.0
	b.cast_ability(actor, 0)
	var skill_started: bool = actor._cast_t > 0.0
	b.mission = original_battle_mission
	b.cancel_pending_cast(actor)
	actor.cancel_cast_windup()
	check(accepted and button_mission.active_action_id == "" and not button_mission.actions.first.done \
		and skill_started and not bool(actor.get_meta(button_mission.AUTO_DISPATCH_META, false)),
		"a real valid skill order cancels a task-button route without falsely completing it or swallowing the windup")
	button_mission.request_action("first")
	button_mission.tick(0.15)
	button_mission.add_action("optional_exit", "提前撤离", actor_cell, [actor.key], 0.1, 48.0)
	button_mission.tick(0.05)
	check(button_mission.actions.first.done and button_mission.active_action_id == "" \
		and not button_mission.actions.optional_exit.done and actor.manual_order_t <= 0.0 \
		and actor.mission_order_arrival_t <= 0.0 and actor.mission_order_target == Vector2.INF \
		and not bool(actor.get_meta(button_mission.AUTO_DISPATCH_META, false)),
		"task-button dispatch cannot auto-trigger a following optional action")
	actor.stamp_mission_order_intent(action_destination, 31)
	button_mission.tick(0.05)
	check(button_mission.active_action_id == "optional_exit",
		"a new matching ground-click receipt can still claim the following optional action")
	manual_mission.mark("canon_event", "原著事件完成")
	var full_story_result: Dictionary = manual_mission.result_snapshot(true)
	check(full_story_result.story_complete and full_story_result.story_done == 1,
		"all goals in one victorious run earn the non-numeric story seal result")

	# QA must not touch the user's existing campaign.cfg even after record and
	# preference save paths were exercised repeatedly.
	campaign.save_prefs()
	var save_exists_after := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_after := _save_bytes(campaign.SAVE_PATH)
	check(save_existed == save_exists_after and save_before == save_after,
		"CAMPAIGN_QA leaves campaign.cfg existence and bytes unchanged")

	campaign.records = records_before
	campaign.unlocked = unlocked_before
	b.queue_free()
	await process_frame
	await process_frame
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	print("[freeplay-core-result] ", JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
