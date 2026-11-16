extends "res://tools/gao_rts_play.gd"
## Controlled branch: withdrawal completes before the occupied escort sinks.

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b = await _start("",4)
	b.set_process(false)
	b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	var l = b.level
	var two = b.find_unit("ruan_xiaoer_boat")
	var five = b.find_unit("ruan_xiaowu_boat")
	var enemy = l.water_groups[1][0]
	l.on_mission_action(b,"gao_wind",b.find_unit("gongsun_sheng"))
	l.on_mission_action(b,"gao_prepare",b.find_unit("liu_tang"))
	var fire_point: Vector2 = b.map.cell_to_world(l.FIRE_POINTS[1])
	l.fireboat.position = fire_point
	two.position = fire_point + Vector2(100,0)
	five.position = fire_point + Vector2(0,100)
	enemy.position = fire_point + Vector2(0,-100)
	l.on_mission_action(b,"gao_fire_1",l.fireboat)
	check(l.liu_carrier==two and two.get_meta("carried_story_person","")=="刘唐","the surviving commander is aboard the original escort")
	var safe: Vector2 = b.map.cell_to_world(l.FIRE_SAFE)
	two.position = safe
	five.position = safe + Vector2(0,110)
	for u in b.units:
		if u.faction == 1:
			u.position = Vector2(10000,10000)
	l.on_mission_action(b,"gao_fire_withdraw",two)
	var fire_goal: Dictionary = b.mission.story_goals.gao_fire
	check(fire_goal.required_events.all(b.mission.has_event) and fire_goal.state=="pending",
		"withdrawal satisfies every required event before settlement and carrier loss")
	two.take_damage(100000.0,enemy,false,true)
	check(b.mission.has_event("liu_tang_lost") and l.liu_carrier==null and l.embarked_liu==null
		and not two.has_meta("carried_story_person") and b.count_alive(0,"liu_tang")==0,
		"the real death callback clears the passenger reservation and the ship metadata immediately")
	check(fire_goal.state=="pending" and not b.mission.actions.gao_liu_return.get("blocked_reason","").is_empty(),
		"loss keeps the withdrawal eligible for credit and blocks the original return action")
	var localize = root.get_node("Localize")
	var phrases := {"zh_CN":"已完成的火攻演义保留","zh_TW":"已完成的火攻演義保留",
		"en":"completed fire attack objective still counts","ja":"達成した火攻めの演義目標は有効"}
	var hints := {}
	for locale in phrases:
		localize.set_language(locale,false)
		hints[locale] = l.unit_tactical_hint(b,five)
		check(phrases[locale] in hints[locale],"surviving escort gives the credited loss advice in "+locale)
	localize.set_language("zh_CN",false)
	check(b.queue_train(l.hall,"liu_tang",false)
		and b._train_block_reason(l.hall,"liu_tang")=="hero_exists",
		"normal hall queue accepts a paid replacement and reserves his unique slot")
	var settlement: Dictionary = b.mission.result_snapshot(true)
	check("gao_fire" in settlement.done_ids and "gao_fire" not in settlement.missed_ids,
		"victory settlement keeps the fire credit after the original carrier is lost")
	var summary := {"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"fire_goal":b.mission.story_goals.gao_fire.state,"hints":hints,
		"scope":"controlled completed-withdrawal branch with a lethal damage fixture and the actual battle death callback"}
	print("GAO_SAFE_ESCORT_LOSS_RESULT ",JSON.stringify(summary))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
