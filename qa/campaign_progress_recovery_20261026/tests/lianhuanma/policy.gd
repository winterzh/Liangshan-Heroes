extends RefCounted
## Only ordinary economy and command algorithms are reused. No old launcher,
## contract fixtures, speed override, damage, entity placement or forced waves.
var driver: Node
var orders := 0
var buildings_started := 0
var units_queued := 0
var units_queued_by_key: Dictionary = {}
var skill_orders := 0
var build_cells: Array = [Vector2i(5,28),Vector2i(5,35),Vector2i(12,36),Vector2i(17,36),Vector2i(12,23),Vector2i(16,24),Vector2i(9,43),Vector2i(20,34)]

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
	for cell in build_cells:
		var half: int = b.building_footprint_half(key)
		if not b.map.area_buildable(cell,half) or b._building_overlap(cell,half) or b._resource_overlap(cell,half): continue
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
func _economy_lhm(b) -> void:
	_mine_idle_workers(b)
	var own: Array=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_building)
	var reserve_gold := 0
	if not own.any(func(u): return u.is_constructing):
		var building_key := ""
		if b.pop_cap-b.used_pop()-b._queued_pop()<8 and b.pop_cap<84: building_key="house"
		elif own.filter(func(u): return u.key=="barracks").size()<2: building_key="barracks"
		elif not own.any(func(u): return u.key=="siege_workshop"): building_key="siege_workshop"
		if building_key!="" and not _place(b,building_key): reserve_gold=int(b._defs[building_key].cost_gold)
	var worker_count: int=b.units.filter(func(u): return alive(u) and u.faction==0 and u.is_worker).size()
	for building in own:
		if building.is_constructing or not building._train_queue.is_empty(): continue
		var key := ""
		if building.key=="barracks": key=["gou_lian","liang_gong","liang_qiang","gou_lian","liang_dao"][units_queued%5]
		elif building.key=="siege_workshop" and b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="siege_ram").size()<2: key="siege_ram"
		elif building.key=="hall" and worker_count<10: key="lou_luo"
		var before_gold: int = b.gold
		var before_wood: int = b.wood
		if key!="" and b.gold>=int(b._defs[key].cost_gold)+reserve_gold and b.queue_train(building,key,false):
			driver.check(before_gold-b.gold == int(b._defs[key].cost_gold) and before_wood-b.wood == int(b._defs[key].cost_wood), "ordinary economy recruitment pays exact cost: " + key)
			driver.record_action("train", [building], {"key":key, "gold_spent":before_gold-b.gold, "wood_spent":before_wood-b.wood})
			units_queued+=1
			units_queued_by_key[key]=int(units_queued_by_key.get(key,0))+1
	for hero in b.units:
		if alive(hero) and hero.faction==0 and hero.is_hero:
			for slot in range(4):
				if hero.can_learn(slot):
					hero.learn(slot)
					driver.record_action("learn", [hero], {"slot":slot})
func _skills_lhm(b,army: Array) -> void:
	for hero in army:
		if not hero.is_hero or hero._cast_t>0: continue
		var foes: Array=b.units.filter(func(u): return alive(u) and u.faction==1 and u.fog_visible and not u.is_building and hero.position.distance_to(u.position)<250)
		if foes.is_empty(): continue
		foes.sort_custom(func(a,z): return hero.position.distance_to(a.position)<hero.position.distance_to(z.position))
		for slot in [1,0,3]:
			if slot>=hero.slot_count() or not hero.slot_ready(slot): continue
			b.select_members([hero],false)
			b._cast_ability_slot(slot)
			if b._ability_armed!="": b._cast_armed_at(b.to_screen(foes[0].position))
			skill_orders+=1
			driver.record_action("skill_command", [hero], {"slot":slot, "target_entity_id":str(foes[0].entity_id)})
			break
