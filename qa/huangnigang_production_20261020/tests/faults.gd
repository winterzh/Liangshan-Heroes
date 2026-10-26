extends "base.gd"
## Fault injection is ONLY real lethal damage to two carriers, after loading a
## naturally reached checkpoint. All relay movement uses actual player orders.
var samples: Array = []
var battle: Variant = null
var original_ids: Array = []

func conservation(label: String) -> void:
	var level: Variant = battle.level
	var physical: int = level.jujube_carts.filter(func(u): return is_instance_valid(u) and u.visible).size() + level.cargo.size()
	for i in range(7):
		if bool(level.cargo_ready.get(i, false)) and battle.units.has(level.bundles[i]): physical += 1
	var cart_events: Array = level._delivered_cart_indices(battle)
	var weighted := 0
	for index in cart_events: weighted += 2 if int(index) < 4 else 1
	check(physical == 7 and level.bundles.map(func(u): return str(u.entity_id)) == original_ids, label + ": seven physical carts and eleven original IDs conserved")
	check(level.delivered == weighted and (level.delivered == 11 or level.st == level.CARRY), label + ": weighted score and partial stage consistent")
	samples.append({"label": label, "physical_carts": physical, "delivered_loads": level.delivered, "delivered_carts": cart_events.duplicate(), "seconds": battle.mission.total_game_seconds})

func perform(action_id: String, actor_key: String) -> bool:
	var actor: Variant = battle.find_unit(actor_key)
	check(alive(actor) and battle.mission.actions.has(action_id), action_id + ": actual living actor and registered action")
	if not failures.is_empty(): return false
	var origin: Vector2 = actor.position
	var level: Variant = battle.level
	var delivered_before: int = level.delivered
	var completion_event := "action:%s:%s" % [battle.mission.stage_id, action_id]
	_action(battle, actor, action_id)
	# The last delivery starts withdrawal and clears the old action dictionary.
	# Mission commits its durable action event before the real level callback.
	var ok := await wait_until(func(): return battle.mission.has_event(completion_event) or battle.phase == battle.Phase.END, 110.0)
	var completed: bool = battle.mission.has_event(completion_event)
	if action_id.begins_with("force_deliver_"):
		var index := int(action_id.split("_")[2])
		var weight := 2 if index < 4 else 1
		completed = completed and battle.mission.has_event("force_delivered_%d" % index) \
			and level._delivered_cart_indices(battle).has(index) and level.delivered == delivered_before + weight \
			and not level.cargo.has(index) and not actor.has_meta("carrying_tribute") \
			and battle.units.has(level.bundles[index]) and level.bundles[index].visible \
			and level.bundles[index].faction == actor.FACTION_LIANG
	else:
		completed = completed and battle.mission.actions.has(action_id) and battle.mission.actions[action_id].done
	check(ok and completed, action_id + ": durable completion event and actual cart state confirm player marker order")
	if not ok: print("RELAY_TIMEOUT ", action_id, " cell=", battle.map.world_to_cell(actor.position), " origin=", origin, " actions=", battle.mission.actions.keys())
	conservation(action_id)
	return failures.is_empty()

func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): report(); return
	battle = await restore_checkpoint()
	if battle == null: report(); return
	var level: Variant = battle.level
	original_ids = level.bundles.map(func(u): return str(u.entity_id))
	root.get_node("Settings").game_speed = 1.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	battle.select_members(level.cargo.values(), false)
	battle._order_stop(); orders += 1
	var double_carrier: Variant = battle.find_unit("wu_yong")
	var single_carrier: Variant = battle.find_unit("ruan_xiaoqi")
	double_carrier.take_damage(double_carrier.max_hp * 1000.0, null, false, true)
	single_carrier.take_damage(single_carrier.max_hp * 1000.0, null, false, true)
	await get_tree().process_frame
	check(not level.cargo.has(1) and not level.cargo.has(6) and battle.units.has(level.bundles[1]) and battle.units.has(level.bundles[6]), "native death callbacks drop both original carts")
	check(not battle.units.has(level.bundles[8]) and not level.bundles[8].visible, "double-load drop keeps secondary load packed inside same cart")
	check(level.force_attempts.get(1, 0) == 1 and level.force_attempts.get(6, 0) == 1, "each dropped cart registers exactly one relay attempt")
	conservation("two_real_damage_drops")
	if not failures.is_empty(): finish(); return
	battle.select_single(battle.find_unit("bai_sheng"), false)
	check(not battle.mission.request_action("force_take_6_1") and not level.cargo.has(6), "wine seller cannot take a dropped seventh cart")
	battle.select_single(battle.find_unit("chao_gai"), false)
	check(not battle.mission.request_action("force_take_6_1") and level.cargo.get(0) == battle.find_unit("chao_gai"), "already loaded Star cannot carry two carts")
	if not await checkpoint_save(battle, "two_dropped_carts_real_damage"): finish(); return
	if not await perform("force_deliver_0_0", "chao_gai"): finish(); return
	check(level.delivered == 2 and level.st == level.CARRY, "first double cart credits exactly two and does not finish")
	if not await perform("force_take_6_1", "chao_gai") or not await perform("force_deliver_6_1", "chao_gai"): finish(); return
	check(level.delivered == 3 and level.st == level.CARRY and level._delivered_cart_indices(battle).size() == 2, "old three-load threshold cannot finish seven-cart chapter")
	battle.select_single(battle.find_unit("chao_gai"), false)
	check(not battle.mission.request_action("force_deliver_6_1") and level.delivered == 3, "repeated completed relay cannot duplicate score")
	if not await perform("force_take_1_1", "chao_gai") or not await perform("force_deliver_1_1", "chao_gai"): finish(); return
	check(level.delivered == 5 and not battle.units.has(level.bundles[8]), "double-cart relay credits exactly two and keeps secondary packed")
	var owners: Array = ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi"]
	for i in range(2, 6):
		if not await perform("force_deliver_%d_0" % i, owners[i]): finish(); return
	check(level.delivered == 11 and level._delivered_cart_indices(battle).size() == 7 and level.st == level.WITHDRAW, "all seven distinct delivered carts and eleven loads unlock regroup")
	finish()

func finish() -> void:
	report({"scope": "Isolated explicit carrier-death failure branch, real drop callbacks and real player relay movement",
		"producer_pid": producer_report.pid, "samples": samples, "checkpoint": checkpoint,
		"fault_injection": ["native lethal damage to Wu Yong and Ruan Xiaoqi after naturally saved load state"],
		"coordinates_or_cargo_or_score_injected": false, "eight_survivor_story_claimed": false, "full_campaign_continue_accepted": false})
