extends "res://tools/huangnigang_short_test.gd"
## Lose an already loaded cart to the active convoy using normal player orders.

var facts := {}

func _report() -> void:
	print("HG_NATURAL_RELAY_RESULT ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"orders":orders,"facts":facts}))
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	quit(0 if failures.is_empty() else 1)

func _attack(b,actors: Array,target) -> void:
	b.center_camera_cell(b.map.world_to_cell(target.position))
	b.select_members(actors,false)
	b._issue_order(b.to_screen(target.position),false)
	orders += 1

func _observations(b) -> Dictionary:
	var l = b.level
	return {"time":b.mission.total_game_seconds,"phase":b.phase,"stage":l.st,"delivered":l.delivered,
		"events":b.mission.events.keys(),"actors":l.actors.filter(func(u): return alive(u)).map(
			func(u): return [u.key,u.hp,b.map.world_to_cell(u.position)]),
		"guards":l.convoy.filter(func(u): return alive(u)).map(
			func(u): return [u.key,u.hp,b.map.world_to_cell(u.position)])}

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	var b = await _start("",0)
	Engine.time_scale = 4
	var l = b.level
	var carrier = b.find_unit("wu_yong")
	var lead = b.find_unit("chao_gai")
	var reserve: Array = l.actors.filter(func(u): return u not in [carrier,lead])
	# The reserve waits out of the initial clash while the runner loads his cart.
	_click(b,reserve,Vector2i(14,23))
	await until(func(): return l.convoy.size() >= 12 and l.bundles[1].position.x < b.map.cell_to_world(Vector2i(32,18)).x,36)
	_attack(b,[lead],l.yang)
	check(await until(func(): return l.force_started,4),"an actual attack order breaks the disguise")
	if not failures.is_empty():
		facts["stop"] = _observations(b)
		_report()
		return
	var index: int = l.Transport.OWNERS.find(carrier.key)
	var cart = l.bundles[index]
	var cart_id: int = cart.entity_id
	# Pull the strongest companion southwest to draw the guards off the top road.
	_click(b,[lead],Vector2i(15,16))
	check(await action(b,carrier,"force_take_%d_0" % index,14),"the original owner retrieves his cart")
	check(await action(b,carrier,"force_load_%d_0" % index,20) and l.cargo.get(index) == carrier,
		"the original cart is actually loaded while enemies remain")
	facts["loaded"] = _observations(b)
	if not failures.is_empty():
		_report()
		return
	facts["cart_id"] = cart_id
	var enemies: Array = l.convoy.filter(func(u): return alive(u))
	check(not enemies.is_empty(),"real enemies still remain at loading")
	if not failures.is_empty():
		_report()
		return
	var enemy = enemies[0]
	_click(b,[carrier],b.map.world_to_cell(enemy.position))
	var dropped := await until(func(): return b.mission.has_event("force_drop_%d_1" % index) or b.phase == b.Phase.END,33)
	facts["drop"] = _observations(b)
	check(dropped and b.mission.has_event("force_drop_%d_1" % index) and not alive(carrier)
		and cart.entity_id == cart_id and b.units.has(cart) and l.cargo_ready.get(index,false)
		and l.top_status(b).contains("待接重车1辆"),"enemy combat drops the original loaded cart and shows the recovery count")
	if not failures.is_empty():
		_report()
		return
	await _recover(b,index,cart_id)
	_report()

func _recover(b,index: int,cart_id: int) -> void:
	var l = b.level
	# Focus the pursuers, then give each original cart its own player orders.
	var t := 0.0
	while b.phase == b.Phase.FIGHT and l.convoy.any(func(u): return alive(u)) and t < 92:
		var fighters: Array = l.actors.filter(func(u): return alive(u))
		if fighters.is_empty(): break
		var enemies: Array = l.convoy.filter(func(u): return alive(u))
		_attack(b,fighters,enemies[0])
		await _wait(2)
		t += 2.0
	facts["after_combat"] = _observations(b)
	check(b.phase == b.Phase.FIGHT and l.convoy.size() == 15 and l.convoy.all(func(u): return not alive(u)),
		"the surviving party resolves the live convoy combat")
	if not failures.is_empty(): return

	var successor = b.find_unit(l._transport_candidates(b,index)[0]) if not l._transport_candidates(b,index).is_empty() else null
	check(alive(successor),"a different surviving Star is eligible to recover the loaded cart")
	if not failures.is_empty(): return
	b.select_single(successor,false)
	var take_id := "force_take_%d_1" % index
	check(l._selected_transport_action(b) == take_id,
		"next-step guidance finds the original loaded cart")
	var take: Dictionary = b.mission.actions[take_id]
	var marker: Vector2 = b.map.cell_to_world(take.cell)
	var cart_position: Vector2 = l.bundles[index].position
	var clicked_enemy = b._enemy_at(b.to_screen(marker))
	facts["relay_before"] = {"cart_pos":[cart_position.x,cart_position.y],"marker":[marker.x,marker.y],
		"marker_reach":take.reach,"click_resolves":b.mission._nearest_clicked_action(marker),
		"click_enemy":clicked_enemy.key if is_instance_valid(clicked_enemy) else "",
		"marker_to_cart_open":b.map._segment_open(marker,cart_position,"land")}
	_action(b,successor,take_id)
	facts["relay_command"] = {"token":successor.mission_order_token,"state":successor._state,
		"marker_open":b.map.is_open_world(marker,"land")}
	check(successor.mission_order_token > 0 and successor._target != l.bundles[index],
		"the ordinary right-click claims a manual task instead of attacking the loaded cart")
	if not failures.is_empty(): return
	var took := await until(func(): return l.cargo.get(index) == successor or b.phase == b.Phase.END,25)
	var actor_position: Vector2 = successor.position
	facts["relay_after"] = {"actor_pos":[actor_position.x,actor_position.y],"distance":actor_position.distance_to(marker),
		"actor_to_marker_open":b.map._segment_open(actor_position,marker,"land"),
		"actor_to_cart_open":b.map._segment_open(actor_position,cart_position,"land"),
		"action_active":b.mission.active_action_id,"action_done":take.done,"token":successor.mission_order_token,
		"path_remaining":successor._path.size()-successor._path_i,"status":b.mission._status.text}
	check(took and l.cargo.get(index) == successor
		and not l.top_status(b).contains("待接重车"),"the survivor takes over the already loaded cart")
	if not failures.is_empty(): return
	check(await action(b,successor,"force_deliver_%d_1" % index,80) and l.bundles[index].entity_id == cart_id
		and l.delivered == l.Transport.weight(index),"one new exit order delivers that same cart and loads once")
	facts["relay"] = {"successor":successor.key,"cart":cart_id,"loads":l.delivered,"time":b.mission.total_game_seconds}
	if not failures.is_empty(): return

	for next_index in range(l.Transport.CART_COUNT):
		if next_index == index: continue
		var candidates: Array = l._transport_candidates(b,next_index)
		if candidates.is_empty():
			check(false,"remaining carts must have an available original owner or relay")
			return
		var next_carrier = b.find_unit(candidates[0])
		var suffix := "%d_%d" % [next_index,int(l.force_attempts.get(next_index,0))]
		if not await action(b,next_carrier,"force_take_"+suffix,75) or not await action(b,next_carrier,"force_load_"+suffix,75) \
				or not await action(b,next_carrier,"force_deliver_"+suffix,80):
			check(false,"remaining carts must travel through their own orders")
			return
	check(l.delivered == 11 and l._delivered_cart_indices(b).size() == 7 and l.st == l.WITHDRAW,
		"seven cart identities deliver exactly eleven loads")
	_click(b,l.actors.filter(func(u): return alive(u)),l.GATE_W)
	await until(func(): return b.phase == b.Phase.END,65)
	var result: Dictionary = b.mission.result_snapshot(l.victory)
	facts["result"] = {"core":result.core_cleared,"story":result.story_done,"loads":l.delivered,
		"carts":l._delivered_cart_indices(b),"seconds":b.mission.total_game_seconds}
	check(l.victory and result.core_cleared and not b.mission.has_event("huangnigang_all_safe"),
		"the survivors assemble and win with the casualty reflected in the result")
