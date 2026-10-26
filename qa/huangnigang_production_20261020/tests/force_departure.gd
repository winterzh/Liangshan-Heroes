extends "base.gd"
## Natural combat can lose companions. Surviving original owners and permitted
## relays move all seven carts; a living Star waits away for real early departure.
## No damage, position, task, cargo, score or outcome injection; no new fixtures.
const OWNERS: Array = ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi"]
var battle: Variant = null
var observations: Array = []
var combat: Dictionary = {}
var result: Dictionary = {}
var original_carts: Array = []
var original_load_ids: Array = []
var original_actor_ids: Dictionary = {}
var original_actor_refs: Dictionary = {}
var action_evidence: Array = []
var cart_assignments: Array = []
var witness: Variant = null
var witness_evidence: Dictionary = {}

func remember_actors() -> void:
	for actor in battle.level.actors:
		if is_instance_valid(actor) and not original_actor_ids.has(actor.key):
			original_actor_ids[actor.key] = actor.entity_id
			original_actor_refs[actor.key] = actor

func companion_states() -> Array:
	var states: Array = []
	for key in OWNERS + ["bai_sheng"]:
		# Battle.find_unit deliberately excludes dead actors. Inspect the chapter's
		# actual original references so a still-present corpse is not called freed.
		var matches: Array = battle.level.actors.filter(func(u): return is_instance_valid(u) and u.key == key)
		check(matches.size() <= 1, "%s: at most one valid original companion reference remains" % key)
		var actor: Variant = matches[0] if not matches.is_empty() else null
		var row := {"key": key, "initial_entity_id": original_actor_ids.get(key, -1), "alive": alive(actor)}
		if is_instance_valid(actor):
			check(original_actor_ids.has(key) and actor.entity_id == original_actor_ids[key] \
				and original_actor_refs.get(key) == actor,
				"%s: valid chapter actor is the same original object and entity identity" % key)
			row.merge({"entity_id": actor.entity_id, "hp": actor.hp, "outcome": actor.story_outcome,
				"present_in_chapter": true, "freed": false,
				"state": "alive" if alive(actor) else ("dead" if actor.hp <= 0.0 else "resolved")})
		else:
			var freed: bool = not is_instance_valid(original_actor_refs.get(key))
			check(original_actor_refs.has(key) and freed, "%s: absent original companion reference was actually freed" % key)
			row.merge({"present_in_chapter": false, "freed": freed, "state": "freed" if freed else "missing_from_chapter"})
		states.append(row)
	return states

func observe(label: String) -> void:
	var level: Variant = battle.level
	var physical: int = level.jujube_carts.filter(func(u): return is_instance_valid(u) and u.visible).size() + level.cargo.size()
	for i in range(7):
		if bool(level.cargo_ready.get(i, false)) and battle.units.has(level.bundles[i]): physical += 1
	var cart_events: Array = level._delivered_cart_indices(battle)
	var weighted := 0
	for index in cart_events: weighted += 2 if int(index) < 4 else 1
	check(physical == 7 and level.jujube_carts == original_carts and level.bundles.map(func(u): return u.entity_id) == original_load_ids,
		label + ": seven physical carts, original cart objects and eleven load IDs conserved")
	check(level.delivered == weighted and (level.delivered == 11 or level.st == level.FORCE),
		label + ": actual weighted score and force-stage boundary agree")
	var carrier_ids: Array = []
	var unique_bindings := true
	for index in level.empty_cargo:
		var actor: Variant = level.empty_cargo[index]
		if not alive(actor):
			unique_bindings = false
			continue
		unique_bindings = unique_bindings and not carrier_ids.has(actor.entity_id) \
			and actor.get_meta("pushing_empty_tribute", -1) == index and not actor.has_meta("carrying_tribute")
		carrier_ids.append(actor.entity_id)
	for index in level.cargo:
		var actor: Variant = level.cargo[index]
		if not alive(actor):
			unique_bindings = false
			continue
		unique_bindings = unique_bindings and not carrier_ids.has(actor.entity_id) \
			and actor.get_meta("carrying_tribute", -1) == index and not actor.has_meta("pushing_empty_tribute")
		carrier_ids.append(actor.entity_id)
	check(unique_bindings, label + ": each living carrier is bound to at most one original cart")
	observations.append({"label": label, "seconds": battle.mission.total_game_seconds,
		"physical_carts": physical, "delivered_loads": level.delivered, "cart_events": cart_events.duplicate(),
		"carrier_entity_ids": carrier_ids})

func pending_cart_action(verb: String, index: int) -> String:
	var prefix := "force_%s_%d_" % [verb, index]
	var found: Array = []
	for key in battle.mission.actions:
		if String(key).begins_with(prefix) and not battle.mission.actions[key].done:
			found.append(String(key))
	check(found.size() == 1, prefix + ": exactly one actual uncompleted registered action")
	return found[0] if found.size() == 1 else ""

func select_carrier(index: int, action_id: String, allow_witness: bool) -> Variant:
	var allowed: Array = battle.mission.actions[action_id].actors
	var candidates: Array = []
	for key in allowed:
		var actor: Variant = battle.find_unit(key)
		if alive(actor) and actor.key in OWNERS and (allow_witness or actor != witness) \
			and not actor.has_meta("carrying_tribute") and not actor.has_meta("pushing_empty_tribute"):
			candidates.append(actor)
	var owner: Variant = battle.find_unit(OWNERS[index])
	var actor: Variant = owner if alive(owner) and candidates.has(owner) else null
	if not alive(owner) and not candidates.is_empty(): actor = candidates[0]
	check(alive(actor), action_id + ": living original owner or permitted empty-handed survivor can take the cart")
	if not alive(actor): return null
	check(not alive(owner) or actor == owner, action_id + ": a surviving original owner keeps responsibility for their cart")
	cart_assignments.append({"cart_index": index, "original_owner": OWNERS[index], "original_owner_alive": alive(owner),
		"carrier": actor.key, "carrier_entity_id": actor.entity_id, "allowed_actors": allowed.duplicate(),
		"take_action": action_id, "relay_after_owner_death": not alive(owner), "seconds": battle.mission.total_game_seconds})
	return actor

func perform_cart_action(verb: String, index: int, actor: Variant) -> bool:
	var action_id := pending_cart_action(verb, index)
	if action_id.is_empty(): return false
	var level: Variant = battle.level
	var allowed: Array = battle.mission.actions[action_id].actors.duplicate()
	check(alive(actor) and allowed.has(actor.key), action_id + ": actual living carrier is permitted by the registered action")
	if not failures.is_empty(): return false
	var before_score: int = level.delivered
	var before_carts: Array = level._delivered_cart_indices(battle).duplicate()
	var origin: Vector2 = actor.position
	var actor_key: String = actor.key
	var actor_id: int = actor.entity_id
	var completion_event := "action:%s:%s" % [battle.mission.stage_id, action_id]
	_action(battle, actor, action_id)
	var reached := await wait_until(func(): return battle.mission.has_event(completion_event) or battle.phase == battle.Phase.END, 110.0)
	var completed: bool = reached and battle.mission.has_event(completion_event) and alive(actor)
	if verb == "take":
		completed = completed and level.empty_cargo.get(index) == actor and actor.get_meta("pushing_empty_tribute", -1) == index \
			and not actor.has_meta("carrying_tribute") and not level.cargo.has(index) and not bool(level.cargo_ready.get(index, false)) \
			and original_carts[index].visible and level.delivered == before_score and level._delivered_cart_indices(battle) == before_carts
	elif verb == "load":
		completed = completed and level.cargo.get(index) == actor and actor.get_meta("carrying_tribute", -1) == index \
			and not level.empty_cargo.has(index) and not actor.has_meta("pushing_empty_tribute") and bool(level.cargo_ready.get(index, false)) \
			and not original_carts[index].visible and level.delivered == before_score and level._delivered_cart_indices(battle) == before_carts
		var load_indices: Array = [index, index + 7] if index < 4 else [index]
		for load_index in load_indices:
			completed = completed and not level.bundles[load_index].visible and not battle.units.has(level.bundles[load_index])
	elif verb == "deliver":
		# Final delivery begins withdrawal and clears the old action dictionary.
		# The durable event and installed cart state, not old action.done, prove it.
		completed = completed and battle.mission.has_event("force_delivered_%d" % index) \
			and not before_carts.has(index) and level._delivered_cart_indices(battle).has(index) \
			and level._delivered_cart_indices(battle).size() == before_carts.size() + 1 \
			and level.delivered == before_score + (2 if index < 4 else 1) \
			and not level.cargo.has(index) and not level.empty_cargo.has(index) \
			and not actor.has_meta("carrying_tribute") and not actor.has_meta("pushing_empty_tribute") \
			and battle.units.has(level.bundles[index]) and level.bundles[index].visible \
			and level.bundles[index].faction == actor.FACTION_LIANG
		if index < 4:
			completed = completed and not battle.units.has(level.bundles[index + 7]) and not level.bundles[index + 7].visible
	check(completed, action_id + ": real timed marker action, original cart state, weighted score and carrier binding agree")
	var destination: Array = [actor.position.x, actor.position.y] if is_instance_valid(actor) else []
	action_evidence.append({"action_id": action_id, "completion_event": completion_event, "event_present": battle.mission.has_event(completion_event),
		"verb": verb, "cart_index": index, "carrier": actor_key, "carrier_entity_id": actor_id,
		"allowed_actors": allowed, "from": [origin.x, origin.y], "to": destination,
		"delivered_before": before_score, "delivered_after": level.delivered, "seconds": battle.mission.total_game_seconds,
		"actual_cart_state_confirmed": completed})
	observe(action_id)
	return failures.is_empty()

func transport_cart(index: int, allow_witness := false) -> bool:
	var action_id := pending_cart_action("take", index)
	if action_id.is_empty(): return false
	var actor: Variant = select_carrier(index, action_id, allow_witness)
	if not failures.is_empty() or not alive(actor): return false
	var cart_start: Vector2 = original_carts[index].position
	if not await perform_cart_action("take", index, actor): return false
	if not await perform_cart_action("load", index, actor): return false
	check(original_carts[index].position.distance_to(cart_start) > 5,
		"cart %d: the original empty cart physically travels to its original cargo before loading" % index)
	if not failures.is_empty(): return false
	return await perform_cart_action("deliver", index, actor)

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").game_speed = 1.0
	Engine.time_scale = 1.0
	var size_parts: PackedStringArray = OS.get_environment("HNS_SIZE").split("x")
	root.size = Vector2i(int(size_parts[0]), int(size_parts[1])) if size_parts.size() == 2 else Vector2i(1280, 720)
	var language := OS.get_environment("LSH_LANGUAGE")
	root.get_node("Localize").set_language("zh_CN" if language.is_empty() else language, false)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): finish(); return
	battle = await _start("", 0)
	var level: Variant = battle.level
	original_carts = level.jujube_carts.duplicate()
	original_load_ids = level.bundles.map(func(u): return u.entity_id)
	remember_actors()
	var carriers: Array = OWNERS.map(func(key): return battle.find_unit(key))
	check(level.st == level.MARCH and not level.force_started and level.jujube_carts.size() == 7 and level.bundles.size() == 11 and carriers.all(func(u): return alive(u)),
		"fresh actual chapter starts with seven merchants, seven original carts and eleven loads")
	if not failures.is_empty(): finish(); return
	var rally := Vector2i(27, 17)
	_click(battle, carriers, rally)
	check(await wait_until(func(): return carriers.all(func(u): return alive(u) and u.position.distance_to(battle.map.cell_to_world(rally)) <= 110), 18.0) and not level.force_started,
		"seven merchants genuinely gather before attacking the entering convoy")
	if not failures.is_empty(): finish(); return
	combat["strategy"] = "gather_seven_then_attack_entering_column"
	combat["guards_entered_at_attack"] = level.convoy.size()
	battle.center_camera_cell(level.TOP)
	battle.select_members(carriers, false)
	battle._issue_order(battle.to_screen(level.yang.position), false); orders += 1
	check(await wait_until(func(): return level.force_started or battle.phase == battle.Phase.END, 35.0) and level.force_started,
		"real player attack starts force route without calling its transition directly")
	if not failures.is_empty(): finish(); return
	remember_actors()
	check(original_actor_ids.size() == 8 and (OWNERS + ["bai_sheng"]).all(func(key): return original_actor_ids.has(key)),
		"all eight original companion identities are recorded before combat casualties")
	if not failures.is_empty(): finish(); return
	var elapsed := 0.0
	while battle.phase == battle.Phase.FIGHT and (level.convoy.size() < 15 or level.convoy.any(func(u): return alive(u))) and elapsed < 100.0:
		var guards: Array = level.convoy.filter(func(u): return alive(u))
		var fighters: Array = level.actors.filter(func(u): return alive(u))
		if not guards.is_empty() and not fighters.is_empty():
			battle.select_members(fighters, false)
			battle._issue_order(battle.to_screen(guards[0].position), false); orders += 1
		await _wait(2.0); elapsed += 2.0
	combat["actors"] = companion_states()
	combat["survivors"] = combat.actors.filter(func(row): return row.alive).map(func(row): return row.key)
	combat["casualties"] = combat.actors.filter(func(row): return not row.alive).map(func(row): return row.key)
	combat["convoy"] = level.convoy.map(func(u): return {"key": u.key, "hp": u.hp, "outcome": u.story_outcome} if is_instance_valid(u) else {"freed": true})
	check(battle.phase == battle.Phase.FIGHT and level.convoy.size() == 15 and level.convoy.all(func(u): return is_instance_valid(u) and u.hp > 0 and u.story_outcome == "subdued") and battle.kills == 0,
		"real combat subdues all fifteen convoy members without killing them")
	var living_stars: Array = carriers.filter(func(u): return alive(u))
	check(level.actors.size() == 8 and living_stars.size() >= 2 and not level.drug_done \
		and battle.mission.has_event("huangnigang_force") and not battle.mission.has_event("drugged"),
		"real force route preserves at least two surviving Stars for transport and a distant witness without inventing wine success")
	if not failures.is_empty(): finish(); return
	if not combat.casualties.is_empty():
		check(battle.mission.has_event("huangnigang_actor_lost"), "actual combat casualties have the production companion-loss event")
	observe("natural_combat_finished")
	if not failures.is_empty(): finish(); return
	# Complete the witness's own cart first. Moving this living Star away before
	# the other six deliveries prevents an accidental all-survivors-at-exit win.
	witness = living_stars[0]
	var witness_index: int = OWNERS.find(witness.key)
	if not await transport_cart(witness_index, true): finish(); return
	_click(battle, [witness], level.BAI_STATION)
	check(await wait_until(func(): return alive(witness) and witness.position.distance_to(battle.map.cell_to_world(level.BAI_STATION)) <= 56, 40.0),
		"surviving witness walks from their completed delivery to the distant post on a real player order")
	if not failures.is_empty(): finish(); return
	battle.select_single(witness, false)
	battle._order_hold_position(); orders += 1
	check(witness.position.distance_to(battle.map.cell_to_world(level.GATE_W)) > 150 \
		and not witness.has_meta("carrying_tribute") and not witness.has_meta("pushing_empty_tribute"),
		"living witness holds away from the exit with their original cart delivered and both hands free")
	witness_evidence = {"key": witness.key, "entity_id": witness.entity_id, "own_cart_index": witness_index,
		"own_cart_delivered": level._delivered_cart_indices(battle).has(witness_index),
		"hold_position_ordered": true, "waiting_cell": [level.BAI_STATION.x, level.BAI_STATION.y],
		"exit_distance_after_hold": witness.position.distance_to(battle.map.cell_to_world(level.GATE_W))}
	if not failures.is_empty(): finish(); return
	# Living original owners finish their own carts before an empty-handed Star
	# returns for a dead owner's cart. Every selection comes from live action actors.
	var remaining: Array = []
	for index in range(7):
		if index != witness_index and alive(battle.find_unit(OWNERS[index])): remaining.append(index)
	for index in range(7):
		if index != witness_index and not alive(battle.find_unit(OWNERS[index])): remaining.append(index)
	for index in remaining:
		if not await transport_cart(index): finish(); return
	check(level.delivered == 11 and level._delivered_cart_indices(battle).size() == 7 and level.st == level.WITHDRAW,
		"surviving original owners and permitted relays deliver all seven distinct carts and exactly eleven loads before withdrawal")
	var relays: Array = cart_assignments.filter(func(row): return row.relay_after_owner_death)
	var dead_owner_count: int = OWNERS.filter(func(key): return combat.casualties.has(key)).size()
	check(cart_assignments.size() == 7 and relays.size() == dead_owner_count \
		and relays.all(func(row): return row.carrier != witness.key and row.carrier != row.original_owner and row.allowed_actors.has(row.carrier)),
		"each naturally lost original owner has exactly one actual permitted survivor relay, never using the distant witness")
	check(action_evidence.size() == 21 and action_evidence.all(func(row): return row.actual_cart_state_confirmed),
		"all seven original carts have real take, load and deliver action evidence")
	observe("force_delivered")
	if not failures.is_empty(): finish(); return
	var departing: Array = level.actors.filter(func(u): return alive(u) and u != witness)
	_click(battle, departing, level.GATE_W + Vector2i(-2, 0))
	check(await wait_until(func(): return departing.all(func(u): return alive(u) and u.position.distance_to(battle.map.cell_to_world(level.GATE_W)) <= 140), 40.0),
		"all surviving companions other than the held witness genuinely gather at the west exit")
	await _wait(1.0)
	var witness_distance: float = witness.position.distance_to(battle.map.cell_to_world(level.GATE_W))
	check(alive(witness) and witness_distance > 150 and not level.victory and not level.depart_requested and battle.phase == battle.Phase.FIGHT,
		"living witness remains outside exit radius and eleven delivered loads do not auto-win")
	check(battle.mission.actions.has("withdraw_now") and not battle.mission.actions["withdraw_now"].done,
		"actual early-departure action remains available and uncompleted")
	observations.append({"label": "before_player_early_departure", "witness_key": witness.key, "witness_exit_distance": witness_distance,
		"living_companions": level.actors.filter(func(u): return alive(u)).size()})
	if not failures.is_empty(): finish(); return
	var departing_stars: Array = departing.filter(func(u): return u.key in OWNERS)
	check(not departing_stars.is_empty(), "a different surviving Star is present to issue actual early withdrawal")
	if not failures.is_empty(): finish(); return
	var departure_actor: Variant = departing_stars[0]
	_action(battle, departure_actor, "withdraw_now")
	check(await wait_until(func(): return level.victory or battle.phase == battle.Phase.END, 15.0) and level.victory and level.depart_requested and battle.mission.has_event("action:withdraw:withdraw_now"),
		"real withdraw marker order and timed action explicitly trigger early victory")
	check(alive(witness) and witness.position.distance_to(battle.map.cell_to_world(level.GATE_W)) > 150 and not battle.mission.has_event("huangnigang_all_safe") and not battle.mission.has_event("drugged"),
		"early departure grants neither absent all-safe event nor absent wine event")
	witness_evidence["departure_actor"] = departure_actor.key
	witness_evidence["exit_distance_at_victory"] = witness.position.distance_to(battle.map.cell_to_world(level.GATE_W))
	witness_evidence["alive_at_victory"] = alive(witness)
	witness_evidence["actual_withdraw_event"] = battle.mission.has_event("action:withdraw:withdraw_now")
	result = battle.mission.result_snapshot(level.victory)
	check(result.core_cleared and not result.story_complete and result.done_ids.is_empty() and ["merchant_cover", "wine_scheme", "no_bloodshed", "all_safe"].all(func(goal): return result.missed_ids.has(goal)),
		"actual settled result records core victory and all four explicitly missed story goals")
	check(identity(OS.get_environment("HG_SOURCE_MODE") != "0"), "same real runtime identity remains bound through natural force and early departure")
	finish()

func finish() -> void:
	var events: Array = battle.mission.events.keys() if is_instance_valid(battle) else []
	var casualties: Array = combat.get("casualties", [])
	var completed_relays: Array = []
	for assignment in cart_assignments:
		if not assignment.relay_after_owner_death: continue
		var complete: bool = ["take", "load", "deliver"].all(func(verb):
			return action_evidence.any(func(row): return row.verb == verb and row.cart_index == assignment.cart_index \
				and row.carrier_entity_id == assignment.carrier_entity_id and row.actual_cart_state_confirmed))
		if complete: completed_relays.append(assignment.cart_index)
	report({"scope": "Natural force combat with recorded companion outcomes, surviving-owner and permitted transport, then real early departure while a living Star waits away",
		"original_actor_ids": original_actor_ids, "combat": combat, "observations": observations, "result": result, "events": events,
		"cart_assignments": cart_assignments, "action_evidence": action_evidence, "witness": witness_evidence,
		"natural_combat_casualties": casualties, "natural_combat_casualty_count": casualties.size(),
		"completed_relay_cart_indices": completed_relays, "completed_relay_cart_count": completed_relays.size(),
		"natural_death_relay_covered": failures.is_empty() and not casualties.is_empty() and not completed_relays.is_empty(),
		"eight_survivor_story_claimed": false,
		"fault_injection": [], "coordinates_or_cargo_or_score_or_damage_injected": false,
		"full_campaign_continue_accepted": false})
