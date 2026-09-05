extends SceneTree
## RTS_TEST_ROUTE=contracts|direct|inside. Routes use production orders, costs,
## construction and live enemy combat; boundary fixtures are labelled separately.
var failures: Array[String] = []
var checks := 0
var orders := 0
var buildings_started := 0
var units_queued := 0
var units_queued_by_key := {}
var route := "contracts"
var out_dir := "res://qa/zhujiazhuang_rts_20260905"
var build_cells := [Vector2i(49,36),Vector2i(50,41),Vector2i(60,29),Vector2i(48,45),Vector2i(55,13),Vector2i(60,14),Vector2i(47,14)]
var play_metrics := {}

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("[rts] ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func alive(u) -> bool: return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""
func _start(mode := "", index := 2):
	var c = root.get_node("Campaign")
	c.current = index
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: c.set(key,false)
	if mode != "": c.set(mode,true)
	root.get_node("Settings").auto_micro_level = 0
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	return b
func _dispose(b) -> void:
	b.queue_free()
	await process_frame
	await process_frame
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
func _click(b, units: Array, cell: Vector2i, amove := false) -> void:
	b.select_members(units,false)
	b.minimap_order(b.map.cell_to_world(cell),amove)
	orders += 1
func _action(b, unit, action_id: String) -> void:
	if not alive(unit) or not b.mission.actions.has(action_id): return
	if b.mission.actions[action_id].done or b.mission.active_action_id == action_id: return
	_click(b,[unit],b.mission.actions[action_id].cell)
func _place(b, key: String) -> bool:
	var candidates: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_worker and u._state != 6)
	if candidates.is_empty(): return false
	var d: Dictionary = b._defs[key]
	if not b.can_afford(int(d.get("cost_gold",0)),int(d.get("cost_wood",0))): return false
	for cell in build_cells:
		var half: int = b.building_footprint_half(key)
		if not b.map.area_buildable(cell,half) or b._building_overlap(cell,half) or b._resource_overlap(cell,half): continue
		var count: int = b.units.size()
		b.select_single(candidates[0],false)
		b.arm_build(key)
		b._try_place_building(b.to_screen(b.map.cell_to_world(cell)))
		if b.units.size() > count:
			buildings_started += 1
			return true
	return false
func _mine_idle_workers(b) -> void:
	var workers: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_worker)
	var gold_workers: Array = workers.filter(func(u): return is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold" and u._state != 6) # ST_BUILD; avoid preloading Unit before autoloads.
	if b.wood < 100 and b.gold > 250 and gold_workers.size() > 1:
		var worker = gold_workers.back()
		var wood_node = b.nearest_resource(worker.position,"wood")
		if wood_node != null:
			b.select_single(worker,false)
			b._issue_order(b.to_screen(wood_node.position),false)
			orders += 1
	for i in range(workers.size()):
		var u = workers[i]
		if u._state != 0: continue
		var node = b.nearest_free_gold(u.position,null,u) if i % 2 == 0 else b.nearest_resource(u.position,"wood")
		if node != null:
			b.select_single(u,false)
			b._issue_order(b.to_screen(node.position),false)
			orders += 1
func _economy(b) -> void:
	_mine_idle_workers(b)
	var own: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_building)
	var pending: Array = own.filter(func(u): return u.is_constructing)
	if pending.is_empty():
		if b.pop_cap - b.used_pop() - b._queued_pop() < 6 and b.pop_cap < 70: _place(b,"house")
		elif not own.any(func(u): return u.key == "siege_workshop"): _place(b,"siege_workshop")
		elif own.filter(func(u): return u.key == "barracks").size() < 2: _place(b,"barracks")
	own.sort_custom(func(a,z): return a.key == "siege_workshop" and z.key != "siege_workshop")
	var siege_count: int = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key in ["siege_ram","siege_cata"]).size()
	var field_count: int = b.units.filter(func(u): return alive(u) and u.faction == 0 and not u.is_worker and not u.is_building and not u.is_noncombat and u.key not in ["song_jiang","sun_li"]).size()
	for building in own:
		if building.is_constructing or not building._train_queue.is_empty(): continue
		var key := ""
		if building.key == "hall" and b.find_unit("hua_rong") == null: key = "hua_rong"
		elif building.key == "barracks":
			if field_count < 12 or siege_count >= 2 or b.wood > 115:
				key = ["liang_qiang","liang_gong","liang_dao","liang_gong"][units_queued % 4]
		elif building.key == "siege_workshop":
			var siege: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key in ["siege_ram","siege_cata"])
			if siege.size() < 3: key = "siege_ram" if siege.size() < 2 else "siege_cata"
		if key != "" and b.queue_train(building,key,false):
			units_queued += 1
			units_queued_by_key[key] = int(units_queued_by_key.get(key,0)) + 1
	for hero in b.units:
		if not alive(hero) or hero.faction != 0 or not hero.is_hero: continue
		for i in range(4):
			if hero.can_learn(i): hero.learn(i)

func _contracts(b) -> void:
	var l = b.level
	check(b.economy and b.fog and b.current_age == 3,"campaign uses economy, fog and available siege age")
	check(b.used_pop() == 16 and b.pop_cap == 20,"opening population excludes seven captives")
	check(b._defs.hall.produces == ["lou_luo","song_jiang","lin_chong","hua_rong"],"chapter hero recruitment is bounded")
	for key in ["liang_qiang","liang_gong","liang_ma","siege_ram","siege_cata","arrow_tower"]:
		check(b._defs[key] == Defs.UNITS[key],"shared definition unchanged: "+key)
	check(b.map.find_path(b.map.cell_to_world(Vector2i(25,28)),b.map.cell_to_world(Vector2i(16,28))).is_empty(),"both gates block actual navigation without boundary bypass")
	for cell in [Vector2i(42,22),l.EXPANSION,l.OUTPOST,l.INNER_CONTACT]:
		check(not b.map.find_path(l.song.position,b.map.cell_to_world(cell)).is_empty(),"army route reachable: "+str(cell))
	var gold_before: int = b.gold
	var wood_before: int = b.wood
	await _wait(20.0)
	check(b.gold > gold_before,"workers collect and unload real resources")
	check(b.wood > wood_before,"workers chop solid tree tiles and return actual wood")
	check(b.faction_gold(1) > 180.0,"enemy workers fund independent economy")
	check(_place(b,"house"),"place house through player build command")
	for i in range(30):
		if b.pop_cap == 30: break
		await _wait(2.0)
	check(b.pop_cap == 30,"worker construction finishes and adds population")
	var bar = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key == "barracks")[0]
	var g: int = b.gold
	var w: int = b.wood
	check(b.queue_train(bar,"liang_qiang",false) and b.gold == g-24 and b.wood == w-14,"production debits shared troop cost")
	await _wait(20.0)
	check(bar._train_queue.is_empty() and b.used_pop() == 17,"normal training finishes without instant-spawn fixture")
	var unit_ids: Array = b.units.map(func(u): return u.get_instance_id())
	var actions: Array = b.mission.actions.keys()
	b.mission.set_title("验证：不重部署")
	check(unit_ids == b.units.map(func(u): return u.get_instance_id()) and actions == b.mission.actions.keys(),"heading update preserves army, camp and actions")
	# Boundary fixtures below intentionally alter pools/outcomes; not gameplay evidence.
	b.faction_res[1] = {"gold":0.0,"wood":0.0}
	l.train_clock = 0.0
	var trained_before: int = l.ai_trained
	l._enemy_economy(b,0.01)
	check(l.ai_trained == trained_before,"enemy cannot train without resources")
	b.faction_res[1] = {"gold":500.0,"wood":500.0}
	l.train_clock = 0.0
	l._enemy_economy(b,0.01)
	check(l.ai_trained == trained_before+1 and l.ai_spent_gold > 0,"enemy training spends finite faction funds")
	var raids_before: int = l.raids_sent
	l.outpost.take_damage(100000.0)
	await process_frame
	l.raid_clock = 0.0
	l._raids(b,1.0)
	check(l.supply_cut and l.raids_sent == raids_before,"destroyed outpost stops future raids")
	l.gate.take_damage(100000.0)
	await process_frame
	check(not b.map.find_path(b.map.cell_to_world(Vector2i(25,28)),b.map.cell_to_world(Vector2i(16,28))).is_empty(),"gate destruction releases crossing")
	check(not l._finish_ready() and not b.mission.actions.has("zhu_rts_finish"),"victory requires manor and actual rescue/return")
	l.hall.take_damage(100000.0)
	await process_frame
	check(b.phase == b.Phase.END and not b.mission.has_event("zhu_victory"),"camp loss terminates with defeat")

func _play(b) -> void:
	var l = b.level
	var entrance_towers: Array = b.units.filter(func(u): return alive(u) and u.faction == 1 and u.key == "arrow_tower")
	var target_stage := "north"
	var mobilized := false
	var rescuer = null
	var entered_with_main_intact := false
	var clock := 0.0
	var next_print := 0.0
	while l.elapsed < 1600.0 and b.phase != b.Phase.END:
		await _wait(2.0)
		clock = l.elapsed
		_economy(b)
		var army: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and not u.is_worker and not u.is_building and not u.is_captive and not u.is_noncombat and u.key not in ["song_jiang","sun_li"])
		if l.inside_open and not l.main_breached and army.any(func(u): return b.map.world_to_cell(u.position).x < 19):
			entered_with_main_intact = true
		if clock >= next_print:
			next_print = clock+60.0
			print("[rts-play] t=",int(clock)," stage=",target_stage," army=",army.size()," g=",b.gold," w=",b.wood," pop=",b.used_pop(),"/",b.pop_cap," buildings=",buildings_started," gate_hp=",l.gate.hp if alive(l.gate) else 0)
		if army.size() >= 14: mobilized = true
		if not mobilized or army.size() < 6:
			_click(b,army,Vector2i(50,32),true)
			continue
		if target_stage == "north":
			_click(b,army,l.EXPANSION,true)
			if l.expansion_secured: target_stage = "outpost"
		elif target_stage == "outpost":
			_click(b,army,l.OUTPOST,true)
			if l.supply_cut: target_stage = "gate"
		elif target_stage == "gate":
			if route == "inside":
				_click(b,army,Vector2i(25,18),true)
				_action(b,l.sun,"zhu_rts_inside")
				if l.inside_open: target_stage = "tower"
			else:
				if alive(l.gate) and l.gate.visible:
					b.select_members(army,false)
					b._issue_order(b.to_screen(l.gate.position),false)
					orders += 1
				else: _click(b,army,Vector2i(25,28),true)
				if l.main_breached: target_stage = "tower"
		elif target_stage == "tower":
			# Player strategy: clear the entrance's real tower before attacking the
			# manor, rather than walking the entire army past a live fortification.
			var tower_cells: Array = [Vector2i(17,20),Vector2i(17,30)] if route == "inside" else [Vector2i(17,30)]
			var towers: Array = []
			var tower_cell: Vector2i = tower_cells[0]
			for candidate_cell in tower_cells:
				towers = b.units.filter(func(u): return alive(u) and u.faction == 1 and u.key == "arrow_tower" and b.map.world_to_cell(u.position) == candidate_cell)
				if not towers.is_empty():
					tower_cell = candidate_cell
					break
			if towers.is_empty(): target_stage = "manor"
			elif towers[0].visible:
				b.select_members(army,false)
				b._issue_order(b.to_screen(towers[0].position),false)
				orders += 1
			else: _click(b,army,tower_cell,true)
		elif target_stage == "manor":
			if alive(l.enemy_base) and l.enemy_base.visible:
				b.select_members(army,false)
				b._issue_order(b.to_screen(l.enemy_base.position),false)
				orders += 1
			else: _click(b,army,Vector2i(10,26),true)
			if l.manor_fallen: target_stage = "rescue"
		elif target_stage == "rescue":
			if not alive(rescuer):
				var rescuers: Array = army.filter(func(u): return u.key in l.FIELD_ACTORS)
				if rescuers.is_empty(): continue
				rescuer = rescuers[0] # Siege engines cannot perform the prisoner interaction.
			_click(b,army.filter(func(u): return u != rescuer),Vector2i(14,31),true)
			_action(b,rescuer,"zhu_rts_rescue")
			if l.prisoners_freed: target_stage = "return"
		elif target_stage == "return":
			_click(b,army,Vector2i(23,28),true)
			_click(b,l.prisoners.filter(func(u): return alive(u)),l.CAMP+Vector2i(-4,0))
			if l._finish_ready(): _action(b,l.song,"zhu_rts_finish")
	check(b.mission.has_event("zhu_victory") and b.phase == b.Phase.END,route+" route wins through live economy/combat and explicit return")
	check(buildings_started >= 2 and units_queued >= 6,"route uses construction and normal troop production")
	check(l.expansion_secured and l.supply_cut,"route takes expansion and cuts reinforcement source")
	var towers_destroyed: int = entrance_towers.filter(func(u): return not alive(u)).size()
	check(towers_destroyed > 0 and units_queued_by_key.get("siege_cata",0) > 0,"route recruits siege and clears a defended entrance tower")
	if route == "direct": check(l.main_breached and not l.inside_open,"direct route needs no inside agent")
	else: check(l.inside_open and entered_with_main_intact,"inside route enters manor while main gate remains intact")
	play_metrics = {"game_seconds":l.elapsed,"stage":target_stage,"orders":orders,"buildings_started":buildings_started,"units_queued":units_queued,"units_queued_by_key":units_queued_by_key,"towers_destroyed":towers_destroyed,"ai_trained":l.ai_trained,"raids_sent":l.raids_sent,"entered_with_main_intact":entered_with_main_intact,"events":b.mission.events.keys(),"result":b.mission.result_snapshot(b.mission.has_event("zhu_victory"))}

func _mode_regression() -> void:
	for mode in ["skirmish","skirmish_ai"]:
		var b = await _start(mode)
		Engine.time_scale = 4.0
		var gold_start: int = b.gold
		var wood_start: int = b.wood
		await _wait(30.0)
		check(b.gold > gold_start and b.wood > wood_start,mode+" actual mining/chopping/unloading survives mode switch")
		check(b._defs.hall.produces == Defs.UNITS.hall.produces and bool(b._defs.shi_qian.get("hero_trainable",false)),mode+" has original roster and no captive overrides")
		await _dispose(b)
	for index in [0,1,3,4,5,6,7]:
		var b = await _start("",index)
		check(b.level.id() == "level%d"%(index+1) and b.economy == (index in [3,4,7]) and b.units.size() > 0,"other chapter startup and expected economy: level%d"%(index+1))
		await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	if OS.get_environment("RTS_TEST_ROUTE") != "": route = OS.get_environment("RTS_TEST_ROUTE")
	if OS.get_environment("RTS_TEST_OUT") != "": out_dir = OS.get_environment("RTS_TEST_OUT")
	var b = await _start()
	Engine.time_scale = 4.0
	if route == "contracts": await _contracts(b)
	else: await _play(b)
	await _dispose(b)
	if route == "contracts": await _mode_regression()
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var report := {"route":route,"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":play_metrics,"scope":"boundary contracts" if route == "contracts" else "automated live gameplay; not human fun acceptance"}
	var f = FileAccess.open(out_dir+"/"+route+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")+"\n")
	f.close()
	print("[rts-result] ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
