extends "res://tools/zhujiazhuang_rts_test.gd"
## One actual chapter with a loaded cart, controlled obstacle and fatal damage.

func _edge_site(b,actor) -> Dictionary:
	var wheel = load("res://scripts/tribute_cart_wheel_visual.gd")
	for x in range(10,43):
		for y in range(10,28):
			var cell := Vector2i(x,y)
			if not b.map.is_open_cell(cell,"land"): continue
			var center: Vector2 = b.map.cell_to_world(cell)
			for shift in [Vector2(15,0),Vector2(-15,0),Vector2(0,15),Vector2(0,-15)]:
				var from: Vector2 = center+shift
				var contact: Vector2 = b.map.unproject(b.map.project(from)+wheel.ground_contact(actor,actor.radius*3.7*actor.visual_scale))
				var block: Vector2i = b.map.world_to_cell(contact)
				var direction := block-cell
				if absi(direction.x)+absi(direction.y)!=1: continue
				var opposite: Vector2i = block+direction
				if not b.map.is_open_cell(block,"land") or not b.map.is_open_cell(opposite,"land"): continue
				if not b.map._segment_open(from,contact,"land"): continue
				if from.distance_to(b.map.cell_to_world(opposite))>=75.0: continue
				if b.units.any(func(u): return is_instance_valid(u) and u.position.distance_to(from)<95.0): continue
				return {"origin":from,"blocked":block,"opposite":opposite,"contact":contact}
	return {}

func _commit_action(b,l,actor,key: String) -> void:
	var action: Dictionary = b.mission.actions[key]
	actor.position=b.map.cell_to_world(action.cell)
	action.done=true
	l.on_mission_action(b,key,actor)

func _check_recovery_guidance(b,l,relay,take_id: String) -> Dictionary:
	l._sync_controls(b)
	var empty_id := "force_take_%d_0" % l.Transport.OWNERS.find(relay.key)
	var empty_action: Dictionary = b.mission.actions[empty_id]
	relay.position = b.map.cell_to_world(empty_action.cell)
	b.select_single(relay,false)
	check(b.mission.actions[take_id].cell != empty_action.cell and l._selected_transport_action(b) == take_id,
		"an eligible empty-handed survivor locates a dropped loaded cart ahead of the nearer empty cart")
	var eligible: Array = b.mission.actions[take_id].actors.duplicate()
	b.mission.update_action_actors(take_id,[l.NO_FORCE_CARRIER])
	check(l._selected_transport_action(b) == empty_id,
		"an ineligible survivor falls back to the normal empty-cart marker")
	b.mission.update_action_actors(take_id,eligible)
	var next: Button = null
	for button in b.mission._buttons.get_children():
		if button.get_meta(b.mission.PRESENTATION_META,{}).get("button_id","") == "hg_transport_next":
			next = button
			break
	check(next != null,"the next-step locator is available after a cart falls")
	if next == null: return {}
	var localize = root.get_node("Localize")
	var serial: int = relay._order_serial
	var position: Vector2 = relay.position
	next.pressed.emit()
	check(b.selection == [relay] and relay.position == position and relay._order_serial == serial
		and String(b.mission._status.text).contains(localize.text(b.mission.actions[take_id].label)),
		"the actual button names the loaded cart without issuing orders or changing selection")
	var expected := {"zh_CN":"待接重车1辆","zh_TW":"待接重車1輛",
		"en":"Loaded carts to recover: 1","ja":"引き継ぎ待ちの積載車1台"}
	var guidance := {}
	for locale: String in expected:
		localize.set_language(locale,false)
		var status: String = l.top_status(b)
		check(status.ends_with(expected[locale]),"one waiting loaded cart is shown in " + locale)
		guidance[locale] = {"status":status,"tooltip":next.tooltip_text}
	check(guidance.values().map(func(row): return row.tooltip).all(
		func(line): return not String(line).is_empty()) and guidance.en.tooltip != guidance.zh_CN.tooltip
		and guidance.ja.tooltip != guidance.zh_CN.tooltip and guidance.zh_TW.tooltip != guidance.zh_CN.tooltip,
		"the player-facing locator tooltip is present in all four languages")
	localize.set_language("zh_CN",false)
	return guidance

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var b=await _start("",0)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	var l=b.level
	l._begin_force_route(b,"夹具：验证载重货车接力。",false)
	for u in b.units:
		u.set_physics_process(false)
		if u.faction==1: u.position=Vector2(-10000,-10000)
	var index: int = l.Transport.cart_for_load(0)
	var carrier=b.find_unit(l.Transport.owner(index))
	var cart=l.bundles[index]
	var cart_id: int=cart.entity_id
	_commit_action(b,l,carrier,"force_take_%d_0"%index)
	check(l.empty_cargo.get(index)==carrier,"the real initial take action assigns the empty cart")
	var load_id := "force_load_%d_0"%index
	check(l._transport_action_for(b,carrier) == load_id,
		"the next step for an empty-cart pusher remains the loading marker")
	carrier.position=b.map.cell_to_world(b.mission.actions[load_id].cell)
	l.jujube_carts[index].position=l._empty_cart_anchor(carrier)
	_commit_action(b,l,carrier,load_id)
	check(l.cargo.get(index)==carrier and l.cargo_ready.get(index,false) and not b.units.has(cart),
		"the real loading action carries the original loaded cart")
	carrier.animation_direction="se"
	carrier._tribute_wheel_angle=1.25
	var site:=_edge_site(b,carrier)
	check(not site.is_empty(),"find a real open lane beside a controlled obstruction")
	if site.is_empty():
		await _dispose(b)
		quit(1)
		return
	carrier.position=site.origin
	b.map.block_footprint(site.blocked,0,true)
	var killer=l.convoy[0]
	carrier.take_damage(100000.0,killer,false,true)
	var take_id := "force_take_%d_1"%index
	var expected: Vector2=b.map.limit_displacement(site.origin,site.contact,"land")
	check(b.units.has(cart) and not l.cargo.has(index) and cart.entity_id==cart_id and cart.position==expected
		and b.map._segment_open(site.origin,cart.position,"land") and is_equal_approx(cart._tribute_wheel_angle,1.25),
		"fatal damage leaves the same loaded cart and wheel on the carrier's side")
	check(not b.mission.actions.has("force_deliver_%d_0"%index) and b.mission.actions.has(take_id)
		and int(l.force_attempts[index])==1,"the death retires delivery and exposes one new relay task")
	var relay=b.find_unit("wu_yong") if carrier.key!="wu_yong" else b.find_unit("liu_tang")
	var guidance := _check_recovery_guidance(b,l,relay,take_id)
	var take: Dictionary = b.mission.actions[take_id]
	var marker: Vector2i=take.cell
	var marker_position: Vector2=b.map.cell_to_world(marker)
	check(b.map._segment_open(cart.position,marker_position,"land")
		and marker_position.distance_to(cart.position)+float(take.reach)+2.0<=l.LOADED_RELAY_REACH,
		"the relay flag stands on reachable ground and its arrival circle fits the interaction distance")
	var across: Vector2=b.map.cell_to_world(site.opposite)
	check(not b.map._segment_open(across,cart.position,"land") and across.distance_to(cart.position)<=l.LOADED_RELAY_REACH,
		"the opponent side lies within range but a blocked tile separates it from the cart")
	take.cell=site.opposite
	var objective: String=b.mission.objective
	_commit_action(b,l,relay,take_id)
	check(not take.done and not l.cargo.has(index) and b.units.has(cart)
		and b.mission.objective==objective and "同一侧" in b.mission._status.text,
		"an old flag across a barrier cannot pick up the cart through the wall")
	take.cell=marker
	relay.position=marker_position
	b._grid_build()
	b.select_members([relay],false)
	b._issue_order(b.to_screen(marker_position),false)
	b.mission.tick(1.0)
	check(l.cargo.get(index)==relay and not b.units.has(cart) and cart.entity_id==cart_id
		and is_equal_approx(relay._tribute_wheel_angle,1.25),
		"a real right-click near the cart transfers it to the survivor with its wheel phase")
	check(not l.top_status(b).contains("待接重车")
		and l._selected_transport_action(b) == "force_deliver_%d_1" % index,
		"the recovery count clears and the next step points to delivery after the handoff")
	var deliver_id := "force_deliver_%d_1"%index
	_commit_action(b,l,relay,deliver_id)
	var delivered: int=l.delivered
	l.on_mission_action(b,deliver_id,relay)
	check(l.delivered==l.Transport.weight(index) and l.delivered==delivered and b.units.has(cart)
		and l._delivered_cart_indices(b)==[index] and cart.entity_id==cart_id,
		"the same loaded cart reaches the exit and a duplicate delivery changes no cargo count")
	check(load("res://scripts/run_campaign_level_state.gd").new().audit_declarations("level1").ok,
		"the relay introduces no unmatched level state")
	print("HG_LOADED_RELAY_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"cart_id":cart_id,"cart_index":index,"delivered_loads":delivered,
		"drop_position":[expected.x,expected.y],"blocked_cell":[site.blocked.x,site.blocked.y],
		"guidance":guidance,
		"scope":"controlled loaded-carrier death, obstacle and real manual relay input"}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
