extends "res://tools/gao_capture_test.gd"
## Isolated boundary regressions. Uses real Unit timers, mission dispatch,
## chapter landing/death callbacks and menu button callbacks. No full-play claim.

func _freeze(b) -> void:
	Engine.time_scale = 1.0
	b.set_process(false)
	b.set_physics_process(false)
	for unit in b.units: unit.set_physics_process(false)

func _arrive(unit, destination: Vector2, token: int) -> void:
	unit.order_stop()
	unit.position = destination
	unit.passive = true
	unit.set_stance(unit.STANCE_PASSIVE)
	unit.stamp_mission_order_intent(destination, token)

func _pair(ctx: Dictionary, label: String) -> void:
	ctx.mission.begin(label, label, "Explicit independent player arrival fixture")
	ctx.mission.add_action("first", "First", ctx.cell, [ctx.a.key], 1.0, 48.0)
	ctx.mission.add_action("second", "Second", ctx.other, [ctx.z.key], 1.0, 48.0)
	_arrive(ctx.a, ctx.b.map.cell_to_world(ctx.cell), 9001)
	ctx.mission.tick(1.0 / 60.0)
	_arrive(ctx.z, ctx.b.map.cell_to_world(ctx.other), 9002)

func _pulse(ctx: Dictionary, seconds: float) -> void:
	for _frame in range(ceili(seconds * 60.0)):
		ctx.a._physics_process(1.0 / 60.0)
		ctx.z._physics_process(1.0 / 60.0)
		ctx.mission.tick(1.0 / 60.0)

func _waiting_combat_enabled(ctx: Dictionary, managed: bool) -> void:
	ctx.z.passive = false
	ctx.z.set_stance(ctx.z.STANCE_AGGRO)
	ctx.z.auto_micro = managed
	ctx.z.manual_order_active = false
	ctx.z.manual_order_t = 0.0
	ctx.z._acq_t = 0.0
	ctx.z.skill_points = 0
	# Only the spell-ready boundary is held fixed: real automatic target selection,
	# public orders, Unit timers/movement and mission qualification remain enabled.
	for slot in ctx.z.ability_slots: slot["cd_t"] = 100.0

func _waiting_ai_pulse(ctx: Dictionary, seconds: float) -> void:
	for _frame in range(ceili(seconds * 60.0)):
		ctx.b._grid_build()
		ctx.b._auto_micro_pass()
		# Match production Battle ordering: AI runs before mission qualification;
		# its child Units tick afterwards, with the actual arrival timer ticking.
		ctx.mission.tick(1.0 / 60.0)
		ctx.a._physics_process(1.0 / 60.0)
		ctx.z._physics_process(1.0 / 60.0)
		ctx.b._ai_tick_frame += 1

func _waiting_enemy_pulse(ctx: Dictionary, enemy, seconds: float) -> bool:
	var hit := false
	for _frame in range(ceili(seconds * 60.0)):
		var before_hp: float = ctx.z.hp
		ctx.b._grid_build()
		ctx.b._auto_micro_pass()
		ctx.mission.tick(1.0 / 60.0)
		enemy._physics_process(1.0 / 60.0)
		for fx in ctx.b.fx_root.get_children():
			var script = fx.get_script()
			if script != null and script.resource_path == "res://scripts/projectile.gd" and not fx.is_queued_for_deletion():
				fx._physics_process(1.0 / 60.0)
		ctx.a._physics_process(1.0 / 60.0)
		ctx.z._physics_process(1.0 / 60.0)
		if ctx.z.hp < before_hp: hit = true
		ctx.b._ai_tick_frame += 1
	return hit

func _waiting_ai_checks(ctx: Dictionary) -> void:
	var settings = root.get_node("Settings")
	var previous_level: int = settings.auto_micro_level
	var previous_fog: bool = ctx.b.fog
	var previous_slots: Array = ctx.z.ability_slots.duplicate(true)
	var previous_points: int = ctx.z.skill_points
	settings.auto_micro_level = 2
	ctx.b.fog = false
	# Freeze only the durable opponent, not the waiting hero's natural state machine.
	var enemy = ctx.b.spawn_at("guan_gong", 1, ctx.b.map.nearest_open(ctx.other + Vector2i(2, 0)))
	enemy.set_physics_process(false)
	enemy.max_hp = 1000000.0
	enemy.hp = enemy.max_hp
	var destination: Vector2 = ctx.b.map.cell_to_world(ctx.other)

	_pair(ctx, "wait_against_idle_acquisition")
	_waiting_combat_enabled(ctx, false)
	ctx.z.set_stance(ctx.z.STANCE_DEFEND)
	ctx.z._home = destination + Vector2(128, 0)
	_waiting_ai_pulse(ctx, 0.6)
	check(ctx.z._target == null and ctx.z.position.distance_to(destination) < 0.01 \
		and ctx.z.mission_order_token == 9002 and ctx.z.mission_order_arrival_t > 0.0,
		"valid waiting receipt survives natural idle acquisition and defensive return-to-home")
	_waiting_ai_pulse(ctx, 1.7)
	check(ctx.mission.actions.second.done,
		"unmanaged waiting hero completes the second task despite a visible nearby enemy")

	_pair(ctx, "wait_against_auto_micro")
	_waiting_combat_enabled(ctx, true)
	ctx.b._ai_tick_frame = ctx.z.ai_tick_phase
	_waiting_ai_pulse(ctx, 0.6)
	check(ctx.z._target == null and ctx.z.position.distance_to(destination) < 0.01 \
		and ctx.z.mission_order_token == 9002 and ctx.z.mission_order_arrival_t > 0.0,
		"real eligible auto-micro passes cannot overwrite a valid waiting task")
	_waiting_ai_pulse(ctx, 1.7)
	check(ctx.mission.actions.second.done and ctx.z.mission_order_token == 0,
		"managed second task completes and consumes its finite waiting receipt")
	ctx.z.order_stop()
	ctx.b._grid_build()
	ctx.b._ai_tick_frame = ctx.z.ai_tick_phase
	ctx.b._auto_micro_pass()
	check(ctx.z._target != null,
		"actual auto-micro target acquisition resumes after task completion")

	_pair(ctx, "wait_cancelled_by_block")
	_waiting_combat_enabled(ctx, true)
	ctx.mission.block_action("second", "Fixture: task cancelled")
	ctx.b._grid_build()
	ctx.b._ai_tick_frame = ctx.z.ai_tick_phase
	ctx.b._auto_micro_pass()
	check(ctx.z.mission_order_token == 0 and ctx.z._target != null,
		"task cancellation removes waiting protection and real auto-micro resumes")

	_pair(ctx, "wait_actor_ineligible")
	_waiting_combat_enabled(ctx, false)
	ctx.z.is_summon = true
	ctx.mission.tick(1.0 / 60.0)
	ctx.z.is_summon = false
	ctx.b._grid_build()
	ctx.z._physics_process(1.0 / 60.0)
	check(ctx.z.mission_order_token == 0 and ctx.z._target != null,
		"an invalidated actor loses the receipt and ordinary idle acquisition resumes")

	_pair(ctx, "ordinary_arrival_keeps_combat_response")
	_arrive(ctx.z, destination + Vector2(0, 128), 9212)
	_waiting_combat_enabled(ctx, false)
	ctx.b._grid_build()
	ctx.z._physics_process(1.0 / 60.0)
	check(ctx.z.mission_order_arrival_t > 0.0 and ctx.z._target != null,
		"ordinary non-task arrivals still acquire enemies immediately, without a new 0.35s combat delay")
	ctx.z.order_stop()
	ctx.z.stamp_mission_order_intent(ctx.z.position, 9213)
	var previous_mission = ctx.b.mission
	ctx.b.mission = null
	_waiting_combat_enabled(ctx, true)
	ctx.b._ai_tick_frame = ctx.z.ai_tick_phase
	ctx.b._auto_micro_pass()
	check(ctx.z._target != null,
		"arrival tokens outside campaign missions never delay real auto-micro acquisition")
	ctx.b.mission = previous_mission

	_pair(ctx, "wait_under_real_enemy_fire")
	ctx.mission.actions.first.duration = 4.0
	_waiting_combat_enabled(ctx, true)
	enemy.position = ctx.b.map.cell_to_world(ctx.b.map.nearest_open(ctx.other + Vector2i(4, 0)))
	enemy.order_attack(ctx.z, false, true)
	var hit_waiter := _waiting_enemy_pulse(ctx, enemy, 1.5)
	check(hit_waiter and ctx.z._target == null and ctx.z.position.distance_to(destination) < 0.01 \
		and ctx.z.mission_order_token == 9002,
		"real enemy bow attacks deal damage without replacing a valid waiting player's task")
	ctx.mission.block_action("second", "Fixture: cancel waiting under fire")
	ctx.z.auto_micro = false
	ctx.z.passive = true
	ctx.z._acq_t = 99.0 # Isolate damage retaliation from ordinary idle acquisition.
	var hit_after_cancel := _waiting_enemy_pulse(ctx, enemy, 1.5)
	check(hit_after_cancel and ctx.z._target == enemy and ctx.z.mission_order_token == 0,
		"subsequent real enemy hits restore automatic retaliation after waiting is cancelled")
	enemy.order_stop()
	for fx in ctx.b.fx_root.get_children():
		var script = fx.get_script()
		if script != null and script.resource_path == "res://scripts/projectile.gd": fx.queue_free()

	_pair(ctx, "wait_replaced_by_player_stop")
	_waiting_combat_enabled(ctx, false)
	ctx.b._stamp_manual([ctx.z])
	ctx.z.order_stop()
	ctx.z.take_damage(1.0, enemy)
	check(ctx.z._target == enemy and ctx.z.mission_order_token == 0,
		"new explicit player stop cancels waiting and keeps its normal damage-retaliation behavior")
	_pair(ctx, "wait_leaves_task_area")
	_waiting_combat_enabled(ctx, false)
	ctx.z.position += Vector2(0, 100)
	ctx.mission.tick(1.0 / 60.0)
	ctx.z.take_damage(1.0, enemy)
	check(ctx.z._target == enemy and ctx.z.mission_order_token == 0,
		"leaving task range releases waiting protection and damage retaliation resumes")
	_pair(ctx, "wait_forced_control")
	_waiting_combat_enabled(ctx, false)
	ctx.z.apply_taunt(enemy, 1.0)
	check(ctx.z._target == enemy and ctx.z._chase_intent == ctx.z.CHASE_FORCED and ctx.z.mission_order_token == 0,
		"real taunt still overrides and cancels a waiting task; waiting grants no control immunity")
	ctx.z._taunt_t = 0.0
	ctx.z._taunt_src = null

	ctx.z.order_stop()
	ctx.z.auto_micro = false
	ctx.z.ability_slots = previous_slots
	ctx.z.skill_points = previous_points
	ctx.b.units.erase(enemy)
	enemy.free()
	ctx.b._grid_build()
	settings.auto_micro_level = previous_level
	ctx.b.fog = previous_fog

func _task_checks() -> void:
	var b = await _start("", 2)
	_freeze(b)
	var mission = load("res://scripts/campaign_mission.gd").new(b)
	b.mission = mission
	var cell: Vector2i = b.map.nearest_open(Vector2i(52, 44))
	var other: Vector2i = b.map.nearest_open(cell + Vector2i(4, 0))
	var ctx := {"b": b, "mission": mission, "a": b.find_unit("song_jiang"),
		"z": b.find_unit("lin_chong"), "cell": cell, "other": other}
	_pair(ctx, "overlapping_arrival")
	_pulse(ctx, 2.2)
	check(mission.actions.first.done and mission.actions.second.done,
		"independent overlapping arrivals both complete without another click")

	_pair(ctx, "player_stop")
	_pulse(ctx, 0.1)
	b._stamp_manual([ctx.z])
	ctx.z.order_stop()
	_pulse(ctx, 2.2)
	check(not mission.actions.second.done and ctx.z.mission_order_token == 0,
		"player stop cancels a waiting arrival")

	_pair(ctx, "player_move")
	_pulse(ctx, 0.1)
	b._stamp_manual([ctx.z])
	ctx.z.order_move(ctx.z.position + Vector2(64, 0))
	_pulse(ctx, 2.2)
	check(not mission.actions.second.done and ctx.z.mission_order_token == 0,
		"new movement replaces a waiting task instead of reviving it later")

	_pair(ctx, "leave_range")
	ctx.z.position += Vector2(100, 0)
	mission.tick(1.0 / 60.0)
	ctx.z.position = b.map.cell_to_world(other)
	_pulse(ctx, 2.2)
	check(not mission.actions.second.done and ctx.z.mission_order_token == 0,
		"leaving task range cancels the waiting receipt even if later moved back")

	_pair(ctx, "blocked_waiter")
	mission.block_action("second", "Review boundary")
	mission.actions.second.erase("blocked_reason")
	_pulse(ctx, 2.2)
	check(not mission.actions.second.done and ctx.z.mission_order_token == 0,
		"blocking a task consumes its waiting receipt; reopening needs a new order")

	_pair(ctx, "old_stage")
	mission.begin("new_stage", "New stage", "Old arrivals cannot trigger new tasks")
	mission.add_action("followup", "Follow-up", other, [ctx.z.key], 0.2, 48.0)
	_pulse(ctx, 0.8)
	check(not mission.actions.followup.done and ctx.z.mission_order_token == 0,
		"stage transition consumes old arrivals before adding a colocated follow-up")

	mission.begin("duplicate_target", "Duplicate target", "One completed marker cannot redirect an old click")
	mission.add_action("first", "First", cell, [ctx.a.key, ctx.z.key], 1.0, 48.0)
	mission.add_action("neighbour", "Neighbour", cell + Vector2i(1, 0), [ctx.z.key], 0.2, 48.0)
	_arrive(ctx.a, b.map.cell_to_world(cell), 9101)
	mission.tick(1.0 / 60.0)
	_arrive(ctx.z, b.map.cell_to_world(cell), 9102)
	_pulse(ctx, 2.2)
	check(mission.actions.first.done and not mission.actions.neighbour.done and ctx.z.mission_order_token == 0,
		"duplicate independent click on a finished task never transfers to its neighbour")

	_pair(ctx, "non_task_click")
	_arrive(ctx.z, b.map.cell_to_world(other + Vector2i(0, 4)), 9202)
	_pulse(ctx, 0.5)
	check(ctx.z.mission_order_token == 0,
		"ordinary non-task arrivals retain their short expiry while another task runs")
	_waiting_ai_checks(ctx)
	_pair(ctx, "terminal_cleanup")
	mission.finish_metrics(false)
	check(ctx.z.mission_order_token == 0,
		"settlement clears waiting player task receipts")
	var declaration_audit: Dictionary = load("res://scripts/run_campaign_mission_state.gd").new().audit_declarations()
	check(declaration_audit.ok, "mission restore field audit remains complete")
	await _dispose(b)

func _land_fixture(b) -> void:
	_freeze(b)
	var l = b.level
	var zhang = b.find_unit("zhang_shun_boat")
	# Declared precondition: sealing and pickup completed; the real boat reached dock.
	l.port_sealed = true
	l.recovered = true
	l.carrier = zhang
	zhang.position = b.map.cell_to_world(l.LANDING_WATER)
	zhang.set_meta("carried_story_person", "高俅")
	b.mission.mark("port_sealed", "Fixture: port sealed")
	b.mission.mark("flagship_scuttled", "Fixture: pickup complete")
	l.on_mission_action(b, "gao_land", zhang)
	check(l.landed and alive(l.prisoner) and not zhang.has_meta("carried_story_person"),
		"real landing creates a live land prisoner and empties the cargo boat")

func _capture_checks() -> void:
	var b = await _fixture()
	_land_fixture(b)
	var l = b.level
	b.find_unit("zhang_shun_boat").take_damage(10000, null, false, true)
	b.find_unit("ruan_xiaoer_boat").take_damage(10000, null, false, true)
	b.find_unit("ruan_xiaowu_boat").take_damage(10000, null, false, true)
	check(alive(l.prisoner) and not l.capture_lost and not b.mission.has_event("gao_escaped"),
		"post-landing empty transport and completed sealing ships may sink without losing Gao")
	# Explicit final escort-position boundary; production process decides the outcome.
	l.prisoner.position = b.map.cell_to_world(l.HALL + Vector2i(0, 4))
	b.find_unit("wu_yong").position = l.prisoner.position + Vector2(32, 0)
	l.strategy_t = 0.0
	l.process(b, 0.25)
	var result: Dictionary = b.mission.result_snapshot(true)
	check(b.phase == b.Phase.END and "gao_capture" in result.done_ids,
		"live prisoner reaching the hall still earns capture credit after empty-boat loss")
	await _dispose(b)

	b = await _fixture()
	_land_fixture(b)
	l = b.level
	l.prisoner.take_damage(10000, null, false, true)
	check(l.capture_lost and b.mission.has_event("gao_escaped") and not b.mission.has_event("gao_captured"),
		"actual land prisoner death still fails the capture route")
	await _dispose(b)

	b = await _fixture()
	_freeze(b)
	b.find_unit("zhang_shun_boat").take_damage(10000, null, false, true)
	check(b.level.capture_lost, "transport loss before prisoner landing still fails capture")
	await _dispose(b)

	b = await _fixture()
	_freeze(b)
	b.find_unit("ruan_xiaoer_boat").take_damage(10000, null, false, true)
	b.find_unit("ruan_xiaowu_boat").take_damage(10000, null, false, true)
	check(b.level.capture_lost, "losing both sealing ships before sealing still fails capture")
	await _dispose(b)

func _menu_checks() -> void:
	var campaign = root.get_node("Campaign")
	var menu = load("res://scripts/menu.gd").new()
	root.add_child(menu)
	var card = menu._make_card(0)
	menu.add_child(card)
	var box = card.get_child(0)
	var launch_button = box.get_child(box.get_child_count() - 1)
	var flow = root.get_node("ContinueFlow")
	var old_phase = flow.phase
	# Only defer scene switching; the actual story button sets the production flags.
	flow.phase = flow.Phase.CONFIRM
	for flag in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly"]:
		campaign.set(flag, true)
	launch_button.pressed.emit()
	check(campaign.current == 0 and not campaign.arena and not campaign.skirmish and not campaign.skirmish_ai \
		and not campaign.scenario and not campaign.custom_defense and not campaign.ai_friendly \
		and campaign.make_level().id() == "level1", "story card clears arena and other previous modes before launch")
	flow.phase = old_phase
	menu.queue_free()
	await process_frame

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	await _task_checks()
	await _capture_checks()
	await _menu_checks()
	print("[campaign-controls-regression] checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
