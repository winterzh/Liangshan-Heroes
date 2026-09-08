extends RefCounted
## Test-only player command policy. No AI-friendly helpers, free units, stat
## setters, wave setters, RNG calls, time scaling, or direct spell resolution.
## Every action below uses the same admission/cost/order path as a player.
const HEROES := ["lin_chong", "hua_rong", "song_jiang", "gongsun_sheng"]
const LEARN := {"lin_chong": [2, 3, 0, 1], "hua_rong": [1, 3, 2, 0],
	"song_jiang": [1, 2, 3, 0], "gongsun_sheng": [3, 0, 2, 1]}
var actions: Array = []
var _macro_at := -100.0
var _micro_at := -100.0
var _orders: Dictionary = {}
var _troop_index := 0

func take_actions() -> Array:
	var out: Array = actions
	actions = []
	return out

func _log(kind: String, detail: Dictionary) -> void:
	actions.append({"kind": kind, "detail": detail})

func _alive(b: Variant, faction: int = 0) -> Array:
	var found: Array = []
	for u: Variant in b.units:
		if is_instance_valid(u) and u.faction == faction and u.hp > 0.0 and u.story_outcome == "" and not u.garrisoned:
			found.append(u)
	return found

func _count(b: Variant, key: String, include_queue := false) -> int:
	var result := 0
	for u: Variant in _alive(b):
		if u.key == key: result += 1
		if include_queue and u.is_building: result += u._train_queue.count(key)
	return result

func _building(b: Variant, key: String) -> Variant:
	for u: Variant in _alive(b):
		if u.key == key and not u.is_constructing: return u
	return null

func _workers(b: Variant) -> Array:
	return _alive(b).filter(func(u: Variant) -> bool: return u.is_worker)

func _builder(b: Variant) -> Variant:
	for u: Variant in _workers(b):
		var mining_gold: bool = is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold"
		if u._state not in [Unit.ST_BUILD, Unit.ST_REPAIR] and u._carry_kind != "gold" and not mining_gold: return u
	return null

func _ready_order(u: Variant, seconds: float, cooldown := 4.0) -> bool:
	return seconds - float(_orders.get(str(u.entity_id), -100.0)) >= cooldown

func _order(b: Variant, u: Variant, point: Vector2, amove: bool, seconds: float, purpose: String) -> void:
	b.select_single(u, false)
	b.minimap_order(point, amove, false)
	_orders[str(u.entity_id)] = seconds
	_log("order", {"unit": str(u.entity_id), "key": u.key, "point": [point.x, point.y], "attack_move": amove, "purpose": purpose})

func _train(b: Variant, producer: Variant, key: String) -> bool:
	if producer == null or not key in b._trainable_keys(producer): return false
	var before := [float(b.gold), float(b.wood)]
	var accepted: bool = b.queue_train(producer, key, false)
	if accepted:
		_log("train", {"producer": str(producer.entity_id), "key": key,
			"before": before, "after": [b.gold, b.wood], "seconds": b.train_time_for(key),
			"definition_cost": [b._defs[key].get("cost_gold", 0), b._defs[key].get("cost_wood", 0)]})
	return accepted

func _construct(b: Variant, key: String, near_cell: Vector2i, seconds: float) -> bool:
	var worker: Variant = _builder(b)
	if worker == null or not b._defs.has(key):
		_log("build_unavailable", {"key": key, "reason": "no_available_worker" if worker == null else "unknown_definition"})
		return false
	var definition: Dictionary = b._defs[key]
	if int(definition.get("min_age", 1)) > int(b.current_age) or not b.can_afford(int(definition.get("cost_gold", 0)), int(definition.get("cost_wood", 0))):
		_log("build_unavailable", {"key": key, "reason": "age_or_resources", "age": b.current_age, "required_age": definition.get("min_age", 1), "resources": [b.gold, b.wood], "cost": [definition.get("cost_gold", 0), definition.get("cost_wood", 0)]})
		return false
	var half: int = b.building_footprint_half(key)
	var candidates: Array = []
	var rejected := {"hidden": 0, "terrain": 0, "building_overlap": 0, "resource_overlap": 0, "unreachable": 0}
	# Search only the established, currently visible economic courtyard. The
	# normal placement function remains responsible for all placement checks.
	for y in range(23, 42):
		for x in range(6, 30):
			var cell := Vector2i(x, y)
			var point: Vector2 = b.map.cell_to_world(cell)
			if not b.is_visible_world(point): rejected.hidden += 1; continue
			if not b.building_terrain_valid(key, cell): rejected.terrain += 1; continue
			if b._building_overlap(cell, half): rejected.building_overlap += 1; continue
			if b._resource_overlap(cell, half): rejected.resource_overlap += 1; continue
			if b.map.find_path(worker.position, point).is_empty(): rejected.unreachable += 1; continue
			candidates.append({"cell": cell, "distance": cell.distance_squared_to(near_cell)})
	if candidates.is_empty():
		_log("build_unavailable", {"key": key, "reason": "no_legal_visible_site", "worker": str(worker.entity_id), "worker_position": [worker.position.x, worker.position.y], "rejected": rejected})
		return false
	candidates.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
		if a.distance == c.distance: return a.cell.y * 60 + a.cell.x < c.cell.y * 60 + c.cell.x
		return a.distance < c.distance)
	var chosen: Vector2i = candidates[0].cell
	var before := [float(b.gold), float(b.wood)]
	var allocator: int = b.next_entity_id
	b.select_single(worker, false)
	b.arm_build(key)
	b._try_place_building(b.to_screen(b.map.cell_to_world(chosen)))
	var created: bool = b.units.any(func(u: Variant) -> bool: return is_instance_valid(u) and u.entity_id == allocator and u.key == key and u.faction == 0 and u.is_constructing)
	if not created:
		_log("build_unavailable", {"key": key, "reason": "normal_placement_rejected", "worker": str(worker.entity_id), "cell": [chosen.x, chosen.y], "armed_after": b._build_armed, "before": before, "after": [b.gold, b.wood], "allocator_before": str(allocator), "allocator_after": str(b.next_entity_id)})
		b.cancel_armed()
		return false
	_orders[str(worker.entity_id)] = seconds
	_log("build", {"worker": str(worker.entity_id), "site": str(allocator), "key": key, "cell": [chosen.x, chosen.y],
		"before": before, "after": [b.gold, b.wood],
		"definition_cost": [definition.get("cost_gold", 0), definition.get("cost_wood", 0)], "visible_candidates": candidates.size(), "rejected": rejected})
	return true

func initial_orders(b: Variant, seconds: float) -> void:
	_construct(b, "depot", Vector2i(7, 32), seconds)
	_train(b, b.level.hall, HEROES[0])
	for u: Variant in _alive(b):
		if not u.is_building and not u.is_worker and not u.is_resource:
			_order(b, u, b.map.cell_to_world(Vector2i(26, 33)), true, seconds, "initial_defense")

func tick(b: Variant, seconds: float) -> void:
	if b.phase != 2 or b.get_tree().paused or b._run_capture_input_closed(): return
	if seconds - _macro_at >= 2.0:
		_macro_at = seconds
		_macro(b, seconds)
	if seconds - _micro_at >= 0.5:
		_micro_at = seconds
		_micro(b, seconds)

func _resume_unstaffed_construction(b: Variant, workers: Array, seconds: float) -> bool:
	for site: Variant in _alive(b):
		if not site.is_building or site.is_resource or not site.is_constructing: continue
		var staffed: bool = workers.any(func(u: Variant) -> bool: return u._state == Unit.ST_BUILD and u._build_site == site)
		if staffed: continue
		var worker: Variant = _builder(b)
		if worker == null: return false
		var progress_before: float = site.build_progress
		# Actual worker right-click resumes the existing paid site. The normal
		# input handler resolves its hit target and owns every order/state change.
		_order(b, worker, site.position, false, seconds, "resume_construction")
		var accepted: bool = worker._state == Unit.ST_BUILD and worker._build_site == site
		_log("resume_construction", {"worker": str(worker.entity_id), "site": str(site.entity_id),
			"key": site.key, "accepted": accepted, "progress_before": progress_before,
			"progress_after_command": site.build_progress, "worker_state_after": worker._state,
			"actual_site": str(worker._build_site.entity_id) if is_instance_valid(worker._build_site) else ""})
		# One continuation attempt per macro step; do not immediately give this
		# same worker a new construction order and abandon the rescued site again.
		return true
	return false

func _macro(b: Variant, seconds: float) -> void:
	var workers: Array = _workers(b)
	var continued_construction: bool = _resume_unstaffed_construction(b, workers, seconds)
	var mining := 0
	for u: Variant in workers:
		if u._gather_node != null and is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold" and u._state in [Unit.ST_GATHER, Unit.ST_RETURN, Unit.ST_MOVE]: mining += 1
	for u: Variant in workers:
		if u._state in [Unit.ST_BUILD, Unit.ST_REPAIR] or not _ready_order(u, seconds, 8.0): continue
		if u._state == Unit.ST_IDLE or (mining < 2 and workers.size() >= 6 and u._carry_kind == "wood"):
			var kind := "gold" if mining < 2 else "wood"
			var resource: Variant = b.nearest_resource(u.position, kind)
			if resource != null:
				_order(b, u, resource.position, false, seconds, "gather_" + kind)
				if kind == "gold": mining += 1
	# At most one worker repairs the threatened hall/gate each macro step; fees
	# and repair progress are entirely Unit/Battle production behavior.
	var repair: Variant = null
	for u: Variant in _alive(b):
		if not u.is_building or u.is_resource or u.is_constructing or u.hp >= u.max_hp * 0.75: continue
		if u.key not in ["hall", "stockade_gate", "arrow_tower", "thunder_tower", "altar_tower"]: continue
		if repair == null or u.key == "hall" or u.hp / u.max_hp < repair.hp / repair.max_hp: repair = u
	if repair != null and b.gold >= 10 and b.wood >= 10:
		var staffed: bool = workers.any(func(u: Variant) -> bool: return u._state == Unit.ST_REPAIR and u._build_site == repair)
		var fixer: Variant = _builder(b)
		if not staffed and fixer != null:
			b.select_single(fixer, false)
			b._order_repair_at(b.to_screen(repair.position), false)
			_orders[str(fixer.entity_id)] = seconds
			_log("repair", {"worker": str(fixer.entity_id), "building": str(repair.entity_id), "key": repair.key})
	if _building(b, "market") != null and b.wood >= 300 and b.gold < 260:
		var before := [float(b.gold), float(b.wood)]
		b.do_trade("wood")
		_log("trade", {"give": "wood", "before": before, "after": [b.gold, b.wood]})
	var hall: Variant = b.level.hall
	var present_heroes := 0
	for key: String in HEROES: present_heroes += _count(b, key, true)
	if hall._train_queue.size() < 2:
		if workers.size() < 4 or (present_heroes >= 2 and workers.size() + _queued(b, "lou_luo") < 8 and hall._train_queue.is_empty()):
			_train(b, hall, "lou_luo")
		for key: String in HEROES:
			if _count(b, key, true) == 0:
				_train(b, hall, key)
				break
	if continued_construction:
		pass
	elif _count(b, "depot") == 0:
		_construct(b, "depot", Vector2i(7, 32), seconds)
	elif b.used_pop() + b._queued_pop() + 5 > b.pop_cap and b.pop_cap < 90 and not _constructing(b, "house"):
		_construct(b, "house", Vector2i(13, 38), seconds)
	elif _count(b, "market") == 0 and b.wood >= 150:
		_construct(b, "market", Vector2i(14, 33), seconds)
	elif _count(b, "depot") < 2 and b.wood >= 130:
		_construct(b, "depot", Vector2i(12, 27), seconds)
	elif present_heroes >= 2 and b.gold >= 230 and _count(b, "barracks") < 2:
		_construct(b, "barracks", Vector2i(24, 35), seconds)
	elif present_heroes >= 3 and b.gold >= 190:
		var towers := _count(b, "arrow_tower") + _count(b, "thunder_tower") + _count(b, "altar_tower")
		if towers < 8:
			var key: String = ["arrow_tower", "thunder_tower", "altar_tower"][towers % 3]
			_construct(b, key, Vector2i(27, 32) if towers % 2 == 0 else Vector2i(18, 40), seconds)
	if present_heroes >= 4 and b.gold >= 200:
		for producer: Variant in _alive(b):
			if producer.key != "barracks" or producer.is_constructing or not producer._train_queue.is_empty(): continue
			var troop: String = ["liang_qiang", "liang_gong", "liang_dao"][_troop_index % 3]
			if _train(b, producer, troop): _troop_index += 1
	# Only click a research entry actually supplied by the normal production UI.
	if present_heroes >= 4 and b.gold >= 350 and b.wood >= 200:
		for producer: Variant in _alive(b):
			if not producer.is_building or producer.is_constructing or not producer._train_queue.is_empty(): continue
			for row: Dictionary in b.research_menu(producer):
				var key: String = row.get("key", "")
				if key.is_empty() or not b._research_block_reason(producer, key).is_empty(): continue
				var before := [float(b.gold), float(b.wood)]
				if b.queue_research(producer, key, false):
					_log("research", {"producer": str(producer.entity_id), "key": key, "before": before, "after": [b.gold, b.wood]})
					return

func _queued(b: Variant, key: String) -> int:
	var total := 0
	for u: Variant in _alive(b):
		if u.is_building: total += u._train_queue.count(key)
	return total

func _constructing(b: Variant, key: String) -> bool:
	return _alive(b).any(func(u: Variant) -> bool: return u.key == key and u.is_constructing)

func _visible_enemies(b: Variant) -> Array:
	return _alive(b, 1).filter(func(u: Variant) -> bool: return not u.is_resource and not u.is_captive and b.is_visible_world(u.position))

func _micro(b: Variant, seconds: float) -> void:
	var enemies: Array = _visible_enemies(b)
	var hall: Variant = b.level.hall
	var threat: Variant = null
	for enemy: Variant in enemies:
		if threat == null or enemy.position.distance_squared_to(hall.position) < threat.position.distance_squared_to(hall.position): threat = enemy
	for u: Variant in _alive(b):
		if u.is_building or u.is_worker or u.is_resource or u.is_summon: continue
		if u.is_hero:
			for slot: int in LEARN.get(u.key, [3, 0, 1, 2]):
				if u.can_learn(slot):
					var before: int = u.skill_points
					b.learn_slot(u, slot)
					_log("learn", {"unit": str(u.entity_id), "key": u.key, "slot": slot, "before": before, "after": u.skill_points})
					break
			if b.is_cast_pending(u, -1) or u._cast_t > 0.0: continue
			var has_walk: bool = b._walk_casts.any(func(row: Dictionary) -> bool: return row.get("c") == u)
			if has_walk: continue
			if _cast(b, u, enemies): continue
		if not _ready_order(u, seconds): continue
		if u.is_hero and u.hp < u.max_hp * 0.28:
			_order(b, u, b.map.cell_to_world(Vector2i(15, 32)), false, seconds, "wounded_retreat")
		elif threat != null and (not u.has_target() or u._state == Unit.ST_IDLE):
			_order(b, u, threat.position, true, seconds, "visible_threat")
		elif threat == null and u._state == Unit.ST_IDLE and u.position.distance_to(b.map.cell_to_world(Vector2i(25, 34))) > 170.0:
			_order(b, u, b.map.cell_to_world(Vector2i(25, 34)), true, seconds, "defensive_muster")

func _cast(b: Variant, hero: Variant, enemies: Array) -> bool:
	if enemies.is_empty(): return false
	var nearest: Variant = null
	for enemy: Variant in enemies:
		if nearest == null or hero.position.distance_squared_to(enemy.position) < hero.position.distance_squared_to(nearest.position): nearest = enemy
	for slot: int in LEARN.get(hero.key, [3, 0, 1, 2]):
		# slot_ready already accepts ordinary active skills and hybrid passives.
		if not hero.slot_ready(slot): continue
		var aid: String = hero.ability_slots[slot].id
		var ad: Dictionary = b.ability_def(aid)
		var target: Variant = nearest
		if ad.get("hero_only", false):
			target = null
			for enemy: Variant in enemies:
				if enemy.is_hero: target = enemy; break
		if target == null: continue
		# Retreat/movement abilities need a separately proven policy. Skipping them
		# is a player decision, not a skill/cooldown/definition modification.
		if aid == "hua_blink": continue
		if ad.get("unit_team", "enemy") == "ally": target = hero
		var distance: float = hero.position.distance_to(target.position)
		if not ad.get("targeted", false) and distance > maxf(240.0, float(ad.get("radius", 0.0))): continue
		if ad.get("targeted", false) and distance > minf(600.0, b.ability_cast_range(hero, ad)): continue
		b.select_single(hero, false)
		b.cast_ability(hero, slot)
		if ad.get("targeted", false): b._cast_armed_at(b.to_screen(target.position))
		var accepted: bool = b.is_cast_pending(hero, slot) or b._walk_casts.any(func(row: Dictionary) -> bool: return row.get("c") == hero)
		if not b._ability_armed.is_empty(): b.cancel_armed()
		if accepted:
			_log("cast", {"unit": str(hero.entity_id), "key": hero.key, "slot": slot, "ability": aid, "target": str(target.entity_id)})
			return true
	return false
