extends RefCounted
## Only ordinary economy and command algorithms are reused. No old launcher,
## contract fixtures, speed override, damage, entity placement or forced waves.
var driver: Node
var orders := 0
var buildings_started := 0
var units_queued := 0
var units_queued_by_key: Dictionary = {}
var skill_orders := 0
var build_cells: Array = [Vector2i(24,26),Vector2i(26,40),Vector2i(14,42),Vector2i(10,43),Vector2i(21,40),Vector2i(26,23),Vector2i(9,31),Vector2i(15,24)]

func alive(u: Variant) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""

func _init(host: Node) -> void:
	driver = host

func move(b: Node, units: Array, cell: Vector2i, attack_move := false) -> void:
	if units.is_empty(): return
	b.select_members(units, false)
	b.minimap_order(b.map.cell_to_world(cell), attack_move)
	orders += 1
	driver.record_action("attack_move" if attack_move else "move", units, {"cell":cell})

func target(b: Node, units: Array, enemy: Variant, label := "attack") -> void:
	if units.is_empty() or not alive(enemy): return
	b.select_members(units, false)
	b._issue_order(b.to_screen(enemy.position), false)
	orders += 1
	driver.record_action(label, units, {"target_entity_id":str(enemy.entity_id)})

func garrison(b: Node, units: Array, building: Variant) -> void:
	if units.is_empty() or not alive(building): return
	b.select_members(units, false)
	b.arm_garrison()
	driver.check(b._garrison_armed, "ordinary hero command card arms garrison")
	b._order_garrison_at(b.to_screen(building.position))
	b.cancel_armed()
	orders += 1
	driver.record_action("garrison_command_card", units, {"target_entity_id":str(building.entity_id)})

func _place(b, key: String) -> bool:
	var candidates: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_worker and u._state != 6)
	if candidates.is_empty(): return false
	var d: Dictionary = b._defs[key]
	if not b.can_afford(int(d.get("cost_gold",0)),int(d.get("cost_wood",0))): return false
	var cells: Array = [b.level.YARD_SITE] if key == "shipyard" else build_cells
	for cell in cells:
		var half: int = b.building_footprint_half(key)
		if not b.building_terrain_valid(key,cell) or b._building_overlap(cell,half) or b._resource_overlap(cell,half): continue
		var count: int = b.units.size()
		var before_gold: int = b.gold
		var before_wood: int = b.wood
		b.select_single(candidates[0],false)
		b.arm_build(key)
		b._try_place_building(b.to_screen(b.map.cell_to_world(cell)))
		if b.units.size() > count:
			buildings_started += 1
			driver.check(before_gold - b.gold == int(d.cost_gold) and before_wood - b.wood == int(d.cost_wood), "accepted building command pays exact resources: " + key)
			driver.record_action("build", [candidates[0]], {"key":key, "cell":cell, "gold_spent":before_gold-b.gold, "wood_spent":before_wood-b.wood})
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
			driver.record_action("gather_wood", [worker], {"target_entity_id":str(wood_node.entity_id)})
	for i in range(workers.size()):
		var u = workers[i]
		if u._state != 0: continue
		var node = b.nearest_free_gold(u.position,null,u) if i % 2 == 0 else b.nearest_resource(u.position,"wood")
		if node != null:
			b.select_single(u,false)
			b._issue_order(b.to_screen(node.position),false)
			orders += 1
			driver.record_action("gather", [u], {"target_entity_id":str(node.entity_id)})

func snapshot() -> Dictionary:
	return {"orders":orders, "buildings_started":buildings_started, "units_queued":units_queued,
		"units_queued_by_key":units_queued_by_key.duplicate(true), "skill_orders":skill_orders}

func restore_counters(value: Dictionary) -> void:
	# External observer counters only; production world/state is never assigned.
	orders = int(value.orders); buildings_started = int(value.buildings_started)
	units_queued = int(value.units_queued); units_queued_by_key = value.units_queued_by_key.duplicate(true)
	skill_orders = int(value.skill_orders)

func economy(b: Node) -> void:
	_mine_idle_workers(b)
	var own: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_building)
	var reserve_gold := 0
	var reserve_wood := 0
	if not own.any(func(u): return u.is_constructing):
		var wanted := ""
		if not own.any(func(u): return u.key == "shipyard"): wanted = "shipyard"
		elif b.pop_cap - b.used_pop() - b._queued_pop() < 6 and b.pop_cap < 84: wanted = "house"
		elif own.filter(func(u): return u.key == "barracks").size() < 2: wanted = "barracks"
		if wanted != "" and not _place(b, wanted):
			reserve_gold = int(b._defs[wanted].cost_gold); reserve_wood = int(b._defs[wanted].cost_wood)
	var ships: int = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key in b.level.SHIP_KEYS and u.key != "zhang_shun_boat").size()
	var troops: int = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key in ["liang_gong", "liang_qiang", "liang_dao"]).size()
	var workers: int = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.is_worker).size()
	for building: Variant in own:
		if building.is_constructing or not building._train_queue.is_empty(): continue
		var key := ""
		if building.key == "shipyard" and ships < 11:
			key = "liangshan_warship"
			move(b, [building], Vector2i(35,50)) # Ordinary building rally command.
		elif building.key == "hall" and workers < 9: key = "lou_luo"
		elif building.key == "barracks" and troops < 18 and (ships >= 6 or troops < 9 or b.gold > 150):
			key = ["liang_qiang", "liang_gong", "liang_dao"][units_queued % 3]
		if key == "": continue
		var definition: Dictionary = b._defs[key]
		if b.gold < int(definition.cost_gold) + reserve_gold or b.wood < int(definition.cost_wood) + reserve_wood: continue
		var before_gold: int = b.gold
		var before_wood: int = b.wood
		var before_pop: Dictionary = b.population_summary()
		if b.queue_train(building, key, false):
			var after_pop: Dictionary = b.population_summary()
			driver.check(before_gold-b.gold == int(definition.cost_gold) and before_wood-b.wood == int(definition.cost_wood), "ordinary recruitment pays exact cost: " + key)
			driver.check(after_pop.active == before_pop.active and after_pop.queued-before_pop.queued == int(definition.get("pop", 1))
				and building._train_queue == [key] and building._train_t == b.train_time_for(key), "accepted queue reserves real population and full normal timer: " + key)
			driver.record_action("train", [building], {"key":key, "gold_spent":before_gold-b.gold, "wood_spent":before_wood-b.wood,
				"queue":building._train_queue.duplicate(), "remaining":building._train_t, "population_before":before_pop, "population_after":after_pop})
			units_queued += 1; units_queued_by_key[key] = int(units_queued_by_key.get(key,0)) + 1
	for hero: Variant in b.units:
		if alive(hero) and hero.faction == 0 and hero.is_hero:
			for slot: int in range(4):
				if hero.can_learn(slot): hero.learn(slot); driver.record_action("learn", [hero], {"slot":slot})

func skills(b: Node, army: Array) -> void:
	for hero: Variant in army:
		if not hero.is_hero or hero._cast_t > 0: continue
		var foes: Array = b.units.filter(func(u): return alive(u) and u.faction == 1 and not u.is_building and b.is_visible_world(u.position) and dispatched(b.level,u) and u.position.distance_to(hero.position) < 240)
		if foes.is_empty(): continue
		for slot: int in [1,0,3]:
			if slot >= hero.slot_count() or not hero.slot_ready(slot): continue
			b.select_members([hero],false); b._cast_ability_slot(slot)
			if b._ability_armed != "": b._cast_armed_at(b.to_screen(foes[0].position))
			skill_orders += 1
			driver.record_action("skill_command", [hero], {"slot":slot, "target_entity_id":str(foes[0].entity_id)})
			break

func dispatched(level: Variant, unit: Variant) -> bool:
	# Keep this route's original 140/330/540 schedule observable. Ordinary
	# enemies/support remain live; no flags, timers or orders are assigned.
	if unit == level.flagship and not level.waves[2].sent: return false
	for index: int in range(3):
		if not level.waves[index].sent and (level.land_groups[index].has(unit) or level.water_groups[index].has(unit)): return false
	return true

func attack(b: Node, army: Array, enemy: Variant, cell: Vector2i) -> void:
	if army.is_empty(): return
	if alive(enemy) and b.is_visible_world(enemy.position): target(b, army, enemy)
	else: move(b, army, cell, true)

func guard(b: Node, units: Array, cell: Vector2i) -> void:
	# A-move can autonomously acquire predeployed unsent groups. Use ordinary
	# movement to the inner camp/harbour, then the real H command; no chase.
	var center: Vector2 = b.map.cell_to_world(cell)
	var moving: Array = units.filter(func(u): return u.position.distance_to(center) > 90.0)
	if not moving.is_empty(): move(b, moving, cell, false)
	var holding: Array = units.filter(func(u): return u.position.distance_to(center) <= 90.0 and not u._hold_order_active)
	if not holding.is_empty():
		b.select_members(holding, false)
		b._order_hold_position()
		orders += 1
		driver.record_action("hold_position", holding, {"cell":cell, "all_waves_sent":b.level.waves.all(func(row): return row.sent)})

func command_stance(b: Node, units: Array, wanted: int, reason: String) -> bool:
	var changing: Array = units.filter(func(u): return u.stance != wanted or u._hold_order_active)
	if changing.is_empty(): return true
	b.select_members(changing, false)
	var cycles := 0
	for attempt: int in range(4):
		if changing.all(func(u): return u.stance == wanted and not u._hold_order_active): break
		b._cycle_stance()
		cycles += 1
		orders += 1
	driver.record_action("stance_command", changing, {"cycles":cycles, "wanted":wanted, "reason":reason})
	return driver.check(changing.all(func(u): return u.stance == wanted and not u._hold_order_active),
		"ordinary stance command reaches requested mode without residual H: " + reason)

func focus_dispatched(b: Node, units: Array, groups: Array, anchor: Vector2i) -> bool:
	# PASSIVE is selected through the real G command. Explicit A+unit attacks
	# still chase that target, but do not acquire a different unit after it dies.
	if units.is_empty(): return false
	var candidates: Array = []
	for index: int in range(3):
		if not b.level.waves[index].sent: continue
		for enemy: Variant in groups[index]:
			if alive(enemy) and b.is_visible_world(enemy.position) and b._enemy_at(b.to_screen(enemy.position)) == enemy:
				candidates.append(enemy)
	if candidates.is_empty(): return false
	var center: Vector2 = b.map.cell_to_world(anchor)
	candidates.sort_custom(func(a,z): return a.position.distance_squared_to(center) < z.position.distance_squared_to(center))
	var enemy: Variant = candidates[0]
	if not command_stance(b, units, 3, "passive_dispatched_attack"): return true # STANCE_PASSIVE
	var attackers: Array = units.filter(func(u): return u._target != enemy or u._chase_intent != 2 or u._state != 3) # CHASE_EXPLICIT / ST_CHASE
	if attackers.is_empty(): return true
	var point: Vector2 = b.to_screen(enemy.position)
	if not driver.check(b._enemy_at(point) == enemy and dispatched(b.level, enemy),
		"visible dispatched original unit is exact click target; never fall back to A-ground"): return true
	b.select_members(attackers, false)
	b._order_amove_at(point, false) # Production A+unit branch calls order_attack(..., explicit=true).
	orders += 1
	driver.record_action("explicit_dispatched_wave_attack", attackers, {"target_entity_id":str(enemy.entity_id),
		"target_position":[enemy.position.x,enemy.position.y], "target_hp":enemy.hp, "stance":3})
	driver.check(attackers.all(func(u): return u.stance == 3 and u._target == enemy and u._chase_intent == 2 and u._state == 3 and not u._resume_amove and not u._hold_order_active),
		"real target command retains passive stance and exact explicit chase without attack-move")
	return true

func wave_survivors(b: Node) -> Array:
	# Bounded read-only diagnosis: at most the 32 original land/water members.
	var rows: Array = []
	for lane: int in range(2):
		var profile: String = "land" if lane == 0 else "water"
		var groups: Array = b.level.land_groups if lane == 0 else b.level.water_groups
		var anchor: Vector2 = b.map.cell_to_world(Vector2i(25,33) if lane == 0 else Vector2i(39,47))
		var friendly: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and not u.is_worker and not u.is_building and not u.garrisoned and not u.is_noncombat and u.movement_profile == profile)
		for index: int in range(3):
			for enemy: Variant in groups[index]:
				if not alive(enemy): continue
				var nearest: Variant = null
				var distance := -1.0
				for own: Variant in friendly:
					var current: float = own.position.distance_to(enemy.position)
					if nearest == null or current < distance: nearest = own; distance = current
				rows.append({"wave":index, "sent":b.level.waves[index].sent, "lane":profile,
					"entity_id":str(enemy.entity_id), "key":enemy.key, "hp":enemy.hp,
					"position":[enemy.position.x,enemy.position.y], "state":enemy._state, "stance":enemy.stance,
					"target_entity_id":str(enemy._target.entity_id) if is_instance_valid(enemy._target) else "",
					"attack_range":enemy.atk_range, "distance_to_guard":enemy.position.distance_to(anchor),
					"nearest_friendly_id":str(nearest.entity_id) if nearest != null else "", "nearest_friendly_distance":distance,
					"nearest_friendly_reach":nearest.atk_range+nearest.radius+enemy.radius if nearest != null else -1.0,
					"visible":b.is_visible_world(enemy.position)})
	return rows

func fight(b: Node) -> void:
	var level: Variant = b.level
	var army: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u != level.song and u != level.embarked_liu and not u.garrisoned and not u.is_worker and not u.is_building and not u.is_noncombat and u.movement_profile == "land" and b.mission._actor != u)
	var fleet: Array = b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key in level.SHIP_KEYS and u.key != "zhang_shun_boat" and not u.garrisoned and b.mission._actor != u)
	if not level.waves[2].sent:
		# The chosen timed-defence route keeps every original dispatch observable.
		# Enemy guard AI, paid reinforcements and all wave clocks remain live.
		if not focus_dispatched(b, army, level.land_groups, Vector2i(25,33)):
			guard(b, army, Vector2i(25,33))
		if not driver.failures.is_empty(): return
		if not focus_dispatched(b, fleet, level.water_groups, Vector2i(39,47)):
			guard(b, fleet, Vector2i(39,47))
		return
	# H and the previous explicit-wave orders can retain PASSIVE. Restore the
	# original assault mode through ordinary G before post-third A-ground orders.
	if not command_stance(b, army + fleet, 0, "all_dispatched_assault"): return # STANCE_AGGRO
	var land_foes: Array = b.units.filter(func(u): return alive(u) and u.faction == 1 and not u.is_building and u.movement_profile == "land" and dispatched(level,u))
	land_foes.sort_custom(func(a,z): return a.position.distance_squared_to(level.hall.position) < z.position.distance_squared_to(level.hall.position))
	var land_target: Variant = null
	var land_cell := Vector2i(29,32)
	if not land_foes.is_empty() and (army.size() >= 12 or land_foes[0].position.distance_to(level.hall.position) < 520):
		land_target = land_foes[0]; land_cell = b.map.world_to_cell(land_target.position)
	elif level.waves[2].sent and army.size() >= 12 and alive(level.posts[0]): land_target = level.posts[0]; land_cell = level.LAND_POST
	attack(b,army,land_target,land_cell)
	skills(b,army)
	var sea_front: Vector2 = b.map.cell_to_world(level.SEA_FRONT)
	var naval_foes: Array = b.units.filter(func(u): return alive(u) and u.faction == 1 and u.movement_profile == "water" and dispatched(level,u))
	naval_foes.sort_custom(func(a,z): return a.position.distance_squared_to(sea_front) < z.position.distance_squared_to(sea_front))
	var sea_target: Variant = null
	var sea_cell := Vector2i(39,45)
	if not naval_foes.is_empty() and (fleet.size() >= 6 or naval_foes[0].position.distance_to(sea_front) < 360):
		sea_target = naval_foes[0]; sea_cell = b.map.world_to_cell(sea_target.position)
	if level.waves[2].sent and fleet.size() >= 6 and alive(level.posts[1]) and (naval_foes.is_empty() or naval_foes[0].position.distance_to(sea_front) > 440):
		sea_target = level.posts[1]; sea_cell = level.SEA_POST
	attack(b,fleet,sea_target,sea_cell)
