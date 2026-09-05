extends "res://tools/zhujiazhuang_rts_test.gd"
## Isolated guard fixtures plus live two-hero rush probes; no forced balance win/loss.
func _guard_probe(key: String) -> void:
	var b = await _start()
	Engine.time_scale = 4.0
	var enemy = b.units.filter(func(u): return alive(u) and u.faction == 1 and u.key == key)[0]
	var hero = b.level.song
	for u in b.units:
		if u != enemy and u != hero:
			u.set_physics_process(false)
			u.faction = 1 # Isolate the duel: no other player targets can pull the defender away.
	var home: Vector2 = enemy.position
	hero.position = home + Vector2(0,120) # Clear of the south outpost's building footprint.
	hero.set_stance(3) # Passive target fixture; defender receives no attack order or damage.
	hero.order_stop()
	hero.max_hp = 2000.0
	hero.hp = 2000.0 # Durable observation target only; live hero rushes never change health.
	var start_hp: float = hero.hp
	await _wait(8.0)
	check(enemy.position.distance_to(home) > 35.0, key+" proactively closes distance without being attacked")
	check(hero.hp < start_hp, key+" actually hits the passive intruder")
	hero.position = home + Vector2(600,0)
	await _wait(14.0)
	check(enemy.position.distance_to(home) < 40.0, key+" returns to its post after the intruder leaves")
	print("[guard-probe] key=",key," stance=",enemy.stance," hp_lost=",start_hp-hero.hp," home_distance=",enemy.position.distance_to(home)," state=",enemy._state," anchor=",enemy._home," path=",enemy._path.size()," pos=",enemy.position)
	hero.position = home + Vector2(0,120)
	var reentry_hp: float = hero.hp
	await _wait(8.0)
	check(hero.hp < reentry_hp,key+" re-engages the same intruder after returning")
	await _dispose(b)

func _order_contracts() -> void:
	var b = await _start()
	var enemy = b.level.hu
	var hero = b.level.song
	hero.position = enemy.position + Vector2(0,100)
	hero.set_stance(3)
	b._enemy_ability_pass()
	var serial: int = enemy._cast_serial
	check(b.is_cast_pending(enemy,-1),"enemy hero starts a real pending spell")
	enemy._cast_t = 0.0 # Reproduce the exact frame between windup ending and settlement.
	b._enemy_ability_pass()
	check(enemy._cast_serial == serial,"AI cannot replace a completed windup before its spell settles")
	var hp_before: float = hero.hp
	b._tick_pending_casts()
	check(hero.hp < hp_before and enemy.ability_slots[0].cd_t > 0.0,"pending enemy spell deals damage once and starts cooldown")
	var lin = b.find_unit("lin_chong")
	lin.position = b.map.cell_to_world(Vector2i(47,34))
	lin.set_stance(1)
	lin.order_stop()
	check(lin._home == lin.position,"explicit Stop establishes a new defensive post")
	lin.order_hold_position()
	check(lin.stance == 2 and lin._hold_order_active,"player Hold Position retains its stationary semantics")
	lin.order_move(b.map.cell_to_world(Vector2i(48,34)))
	check(lin.stance == 1 and not lin._hold_order_active,"player move cancels temporary hold and restores defensive stance")
	await _dispose(b)

func _hero_probe() -> void:
	var b = await _start()
	Engine.time_scale = 4.0
	var l = b.level
	var heroes: Array = [l.song,b.find_unit("lin_chong")]
	var target_stage := "outpost" if route == "hero_inside" else "gate"
	while l.elapsed < 480.0 and b.phase != b.Phase.END and alive(heroes[1]):
		await _wait(2.0)
		for h in heroes:
			if alive(h):
				for i in range(4):
					if h.can_learn(i): h.learn(i)
		if target_stage == "outpost":
			_click(b,heroes,l.OUTPOST,true)
			if l.supply_cut: target_stage = "gate"
		elif target_stage == "gate":
			if route == "hero_inside":
				_click(b,heroes,Vector2i(25,18),true)
				_action(b,l.sun,"zhu_rts_inside")
				if l.inside_open: target_stage = "manor"
			elif alive(l.gate) and l.gate.visible:
				b.select_members(heroes,false)
				b._issue_order(b.to_screen(l.gate.position),false)
			else: _click(b,heroes,Vector2i(23,28),true)
			if l.main_breached: target_stage = "manor"
		elif target_stage == "manor":
			_click(b,heroes,Vector2i(10,26),true)
			if l.manor_fallen: break
	check(not l.manor_fallen, route+" does not destroy the manor without recruiting/building")
	check(not alive(l.song) or not alive(heroes[1]) or b.phase == b.Phase.END,route+" is stopped by actual combat rather than only the time limit")
	play_metrics = {"game_seconds":l.elapsed,"stage":target_stage,"song_hp":l.song.hp if is_instance_valid(l.song) else 0.0,"lin_hp":heroes[1].hp if is_instance_valid(heroes[1]) else 0.0,
		"main_breached":l.main_breached,"inside_open":l.inside_open,"manor_fallen":l.manor_fallen,
		"buildings_started":0,"units_queued":0,"enemy_trained":l.ai_trained,"raids_sent":l.raids_sent,
		"scope":"Two heroes receive attack orders and normal skill learning; no spell-use/kiting optimization. Opening four troops stay at camp. Not proof against every expert strategy."}
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	out_dir = "res://qa/zhujiazhuang_rts_feedback_20260905"
	route = OS.get_environment("RTS_FEEDBACK_TEST")
	if route == "": route = "guards"
	if route == "guards":
		for key in ["zhu_keke","hu_sanniang","zhu_hu"]: await _guard_probe(key)
		await _order_contracts()
		check(checks == 18,"all eighteen guard/order cases reached their assertions")
	else: await _hero_probe()
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var report := {"route":route,"checks":checks,"passed":failures.is_empty(),"failures":failures,"metrics":play_metrics}
	var suffix := OS.get_environment("RTS_FEEDBACK_SUFFIX")
	var f = FileAccess.open(out_dir+"/"+route+suffix+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")+"\n")
	f.close()
	print("[rts-feedback] ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
