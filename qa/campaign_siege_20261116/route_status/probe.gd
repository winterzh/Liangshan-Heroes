extends "res://tools/zhujiazhuang_rts_test.gd"
## Focused runtime fixtures. Enemy buildings take controlled lethal damage.

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b = await _start()
	b.set_process(false)
	b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	var l = b.level
	var localize = root.get_node("Localize")
	l._refresh_stage(b)
	check(l.stage=="scout","opening does not disclose an unbroken approach")
	var side = l.side_gate
	side.take_damage(100000.0,l.song,false,true)
	await process_frame
	l._refresh_stage(b)
	check(not is_instance_valid(side) and b.mission.has_event("zhu_side_breached")
		and l.stage=="siege" and "偏门已可通行" in b.mission.objective
		and not l.supply_cut and not l.main_breached and not l.inside_open,
		"destroyed side gate still advances the objective after its node is released")
	var guard_orders = l.gate_defenders.map(func(u): return [u.entity_id,u._order_serial])
	var main = l.gate
	main.take_damage(100000.0,l.song,false,true)
	await process_frame
	l._refresh_stage(b)
	check(l.main_breached and "正门和偏门都已通行" in b.mission.objective,
		"opening both gates exposes both approaches")
	check(l.gate_defenders.map(func(u): return [u.entity_id,u._order_serial])==guard_orders,
		"opening the second gate preserves the first gate guard commitment")

	l.train_clock=0.0
	l._enemy_economy(b,0.0)
	check(l.ai_trained==1 and l.reserve.size()==1,"an existing paid outpost reinforcement enters the reserve")
	var raider = l.reserve[0]
	l.reserve.erase(raider)
	l.raiders.append(raider)
	l.raid_state="attack"
	l.raid_strength=3
	l.raids_sent=1
	var post = l.outpost
	post.take_damage(100000.0,l.song,false,true)
	await process_frame
	b._sight_now.fill(0)
	b._reveal_t.fill(0)
	var hidden: String = l.top_status(b)
	check(l.supply_cut and alive(raider) and raider in b.units and "庄内仍可补兵" in hidden and not "出击" in hidden,
		"cutting the outpost preserves a raider without disclosing its hidden attack state")
	var cell: Vector2i = b.map.world_to_cell(raider.position)
	b._sight_now[cell.y*b.map.w+cell.x]=1
	check("残部仍在出击" in l.top_status(b),"visible active raid is still reported after cutting supply")
	l.raid_state="retreat"
	var before_id: int = raider.entity_id
	var phrases := {"zh_CN":"残部正在退守","zh_TW":"殘部正在退守",
		"en":"Raiders falling back","ja":"残存部隊が後退中"}
	var hints := {}
	for locale in phrases:
		localize.set_language(locale,false)
		hints[locale]=l.top_status(b)
		check(phrases[locale] in hints[locale],"visible retreat remains readable in "+locale)
	localize.set_language("zh_CN",false)
	var gold: float = b.faction_gold(1)
	var wood: float = b.faction_wood(1)
	var paid_before := [l.ai_spent_gold,l.ai_spent_wood]
	l.train_clock=0.0
	l._enemy_economy(b,0.0)
	var debit := [l.ai_spent_gold-paid_before[0],l.ai_spent_wood-paid_before[1]]
	check(l.ai_trained==2 and l.reserve.is_empty() and alive(raider) and raider.entity_id==before_id
		and b.map.world_to_cell(l.trained[-1].position)==Vector2i(14,23)
		and [int(gold-b.faction_gold(1)),int(wood-b.faction_wood(1))]==debit
		and debit[0]+debit[1]>0,"after the cut a normally paid defender starts inside the manor")
	l._reset_raid()
	l.raid_clock=0.0
	l.raid_think=0.0
	l._raids(b,1.0)
	check(l.raids_sent==1,"the destroyed outpost cannot launch another raid")
	var manor = l.enemy_base
	manor.take_damage(100000.0,l.song,false,true)
	await process_frame
	l.train_clock=0.0
	l._enemy_economy(b,0.0)
	l._refresh_stage(b)
	check(l.manor_fallen and l.ai_trained==2 and "大营停止补兵" in l.top_status(b)
		and b.mission.stage_title=="营救 · 前往牢院",
		"destroying the manor ends production and moves the objective to rescue")
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"side_gate_node_released":not is_instance_valid(side),"first_commitment":guard_orders,
		"hidden_raid_status":hidden,"visible_retreat_localizations":hints,"paid_manor_defender":debit,
		"raid_count":l.raids_sent,"training_count":l.ai_trained,
		"scope":"controlled real chapter scene; release of destroyed gates, fog, actual paid spawn, and transition text"}
	await _dispose(b)
	var cut_only := await _cut_only()
	report.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cut_only":cut_only},true)
	print("ZHU_ROUTE_STATUS_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _cut_only() -> Dictionary:
	var b = await _start()
	b.set_process(false)
	b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	var l = b.level
	l.outpost.take_damage(100000.0,l.song,false,true)
	await process_frame
	l._refresh_stage(b)
	var available: String = b.mission.objective
	check(l.supply_cut and not l.main_breached and not l.inside_open and alive(l.sun)
		and "庄内大营仍可补兵" in available and "接应孙立" in available,
		"cut-only route offers a living contact or a frontal attack")
	var sun = l.sun
	sun.take_damage(100000.0,l.resource_guards[0],false,true)
	await process_frame
	l._refresh_stage(b)
	var unavailable: String = b.mission.objective
	check(not l._alive(sun) and "内应路线关闭" in unavailable and "攻破庄门" in unavailable,
		"the optional approach disappears when the named contact is actually lost")
	await _dispose(b)
	return {"with_contact":available,"after_contact_lost":unavailable}
