extends "res://qa/campaign_escort_arrival_20261116/menu_resume/probe.gd"
## Force the rescue through ordinary combat, then save during Lin's untying.

func _checkpoint(b) -> Dictionary:
	var l = b.level
	var events: Array = b.mission.events.keys()
	events.sort()
	var actors: Array = []
	for u in [l.lu,l.lin_bound] + l.escorts:
		actors.append({"id":u.entity_id,"name":u.key,"hp":u.hp,"position":[u.position.x,u.position.y],
			"outcome":u.story_outcome,"faction":u.faction,"serial":u._order_serial})
	return {"clock":b.mission.total_game_seconds,"care_elapsed":l.care_t,"actors":actors,
		"mission_stage":b.mission.stage_id,"events":events}

func _expected_stage(b) -> bool:
	var l = b.level
	return l.st == l.CARE and is_instance_valid(l.lin_bound) and not is_instance_valid(l.lin_freed) \
		and l.escorts.all(func(u): return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "subdued") \
		and l._lu_near_patient() and l.care_t > 0 and l.care_t < l.UNTIE_TIME

func _attack_guard(b, guard) -> void:
	b.select_single(b.level.lu,false)
	b._issue_order(b.to_screen(guard.position),false)
	orders += 1

func _save() -> void:
	var b = await _start("",5)
	var l = b.level
	Engine.time_scale = 4
	_attack_guard(b,l.escorts[0])
	var opened := await _until(func(): return l.st == l.CARE or b.phase == b.Phase.END,15)
	check(opened and l.st == l.CARE and b.mission.has_event("yezhulin_early_force"),
		"attacking the guards triggers early rescue")
	if not failures.is_empty():
		_finish()
		return
	var elapsed := 0.0
	while l.st == l.CARE and l._escorts_threatening() and elapsed < 32:
		var hostile: Array = l.escorts.filter(func(u): return alive(u) and u.faction == 1)
		if l.lu._target not in hostile:
			_attack_guard(b,hostile[0])
		await _wait(0.1)
		elapsed += 0.1
	if not l._escorts_threatening() and not l._lu_near_patient():
		_click(b,[l.lu],b.map.world_to_cell(l.lin_bound.position)+Vector2i(0,-1))
	await _until(func(): return l.care_t >= 0.4 or not is_instance_valid(l.lin_bound) or b.phase == b.Phase.END,18)
	check(_expected_stage(b) and not b.mission.has_event("untie"),
		"two original guards are subdued and Lin is still bound during actual care")
	if not failures.is_empty():
		_finish()
		return
	_pause_and_save(b)

func _play_restored(b) -> void:
	var l = b.level
	var original_guard_ids: Array = l.escorts.map(func(u): return u.entity_id)
	var expected_lin_id: int = l.lin_bound.entity_id + 1
	Engine.time_scale = 4
	b._close_pause()
	var freed := await _until(func(): return l.st == l.ESCAPE or b.phase == b.Phase.END,10)
	check(freed and l.st == l.ESCAPE and l.treated and l.lin_freed.entity_id == expected_lin_id
		and b.mission.has_event("untie") and b.mission.has_event("tend_feet") and orders == 0,
		"untying and tending finish after resume without a new command")
	check(l.escorts.map(func(u): return u.entity_id) == original_guard_ids and l.escorts.all(func(u):
		return alive(u) and u.faction == 0 and u.is_noncombat),"both original guards join the escort after care")
	facts["care_without_new_order"] = orders == 0 and l.treated
	facts["care_finished_seconds"] = b.mission.total_game_seconds
	if failures.is_empty():
		check(await _action_done(b,l.lin_freed,"leave_forest",90),"one new order leads all four directly out of the forest")
		await _until(func(): return b.phase == b.Phase.END,8)
		var result: Dictionary = b.mission.result_snapshot(l.victory)
		check(l.victory and l._full_group_near(b.map.cell_to_world(l.EXIT_W),l.EXIT_R)
			and b.mission.has_event("yezhulin_early_force") and not b.mission.has_event("intercept")
			and not l.rest_reached and result.story_done == 0,
			"direct exit wins with all four survivors and no invented optional credit")
		facts["story_done"] = result.story_done
		facts["finish_seconds"] = b.mission.total_game_seconds
	_finish()
