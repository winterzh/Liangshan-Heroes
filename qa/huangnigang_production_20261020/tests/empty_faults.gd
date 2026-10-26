extends "base.gd"
## Explicit carrier-death fault only. Original cart, movement, death callback,
## takeover and loading are actual production operations; no teleport/state edit.
var battle: Variant = null
var observations: Array = []
var original_load_ids: Array = []
var original_carts: Array = []
var takeover_labels: Array = []

func check_takeover_label(action_id: String) -> void:
	if not battle.mission.actions.has(action_id): return
	var action: Dictionary = battle.mission.actions[action_id]
	var localize: Variant = root.get_node("Localize")
	var initial_locale: String = localize.locale
	var recorded_label: String = action.label
	var marker: Variant = action.marker
	var button: Variant = action.button
	var template := "%s · 第%d车（%d担）%s"
	var initial_expected: String = localize.text(template) % [localize.text("幸存七星"), 7, 1, localize.text("取车")]
	check(recorded_label == initial_expected and not action.done and is_instance_valid(marker) and marker.label == recorded_label and is_instance_valid(button),
		"actual death registers surviving-Stars label on new empty-cart action and original marker")
	if not is_instance_valid(marker) or not is_instance_valid(button): return
	for locale: String in ["zh_CN", "zh_TW", "en", "ja"]:
		localize.set_language(locale, false)
		var expected: String = localize.text(template) % [localize.text("幸存七星"), 7, 1, localize.text("取车")]
		var button_template: String = "无法办理 · %s" if action.has("blocked_reason") else "查看 · %s"
		var expected_button: String = localize.text(button_template) % expected
		var actual_label: String = localize.text(recorded_label)
		var actual_marker: String = localize.text(String(marker.label))
		check(actual_label == expected and actual_marker == expected and button.text == expected_button,
			"actual surviving-Stars action, marker and button translate together in " + locale)
		takeover_labels.append({"language": locale, "expected": expected, "action": actual_label,
			"marker": actual_marker, "button": button.text})
	localize.set_language(initial_locale, false)

func observe(label: String) -> void:
	var level: Variant = battle.level
	var physical: int = level.jujube_carts.filter(func(u): return is_instance_valid(u) and u.visible).size() + level.cargo.size()
	for i in range(7):
		if bool(level.cargo_ready.get(i, false)) and battle.units.has(level.bundles[i]): physical += 1
	check(physical == 7 and level.bundles.map(func(u): return u.entity_id) == original_load_ids and level.jujube_carts == original_carts, label + ": seven physical carts, original cart objects and original load IDs conserved")
	var delivered_carts: Array = level._delivered_cart_indices(battle)
	var expected_score := 0
	for index in delivered_carts: expected_score += 2 if int(index) < 4 else 1
	check(level.delivered == expected_score and level.st == level.CARRY, label + ": actual partial score stays in transport stage")
	observations.append({"label": label, "seconds": battle.mission.total_game_seconds, "delivered_loads": level.delivered,
		"empty_indices": level.empty_cargo.keys(), "loaded_indices": level.cargo.keys(), "delivered_carts": delivered_carts,
		"seventh_cart_position": [level.jujube_carts[6].position.x, level.jujube_carts[6].position.y]})

func perform(action_id: String, actor_key: String) -> bool:
	var actor: Variant = battle.find_unit(actor_key)
	check(alive(actor) and battle.mission.actions.has(action_id), action_id + ": actual living actor and registered action")
	if not failures.is_empty(): return false
	_action(battle, actor, action_id)
	var completed := await wait_until(func(): return (battle.mission.actions.has(action_id) and battle.mission.actions[action_id].done) or battle.phase == battle.Phase.END, 110.0)
	check(completed and battle.mission.actions.has(action_id) and battle.mission.actions[action_id].done and battle.phase == battle.Phase.FIGHT, action_id + ": actual player marker order completes")
	if not completed: print("EMPTY_RELAY_TIMEOUT ", action_id, " actor_cell=", battle.map.world_to_cell(actor.position), " empty=", battle.level.empty_cargo.keys(), " cargo=", battle.level.cargo.keys())
	observe(action_id)
	return failures.is_empty()

func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): report(); return
	battle = await restore_checkpoint("empty")
	if battle == null: report(); return
	var level: Variant = battle.level
	original_load_ids = level.bundles.map(func(u): return u.entity_id)
	original_carts = level.jujube_carts.duplicate()
	var actor: Variant = level.empty_cargo[6]
	var original_cart: Variant = level.jujube_carts[6]
	var start_actor: Vector2 = actor.position
	var start_cart: Vector2 = original_cart.position
	root.get_node("Settings").game_speed = 1.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	_action(battle, actor, "force_load_6_0")
	check(await wait_until(func(): return (actor.position.distance_to(start_actor) > 12.0 and original_cart.position.distance_to(start_cart) > 6.0) or level.cargo.has(6), 6.0), "seventh empty cart and owner genuinely continue moving after restart")
	check(level.empty_cargo.get(6) == actor and level.cargo.is_empty() and level.cargo_ready.is_empty(), "fault occurs while original seventh cart is still empty and moving")
	if not failures.is_empty(): finish(); return
	var drop_position: Vector2 = original_cart.position
	actor.take_damage(actor.max_hp * 1000.0, null, false, true)
	await get_tree().process_frame
	check(not level.empty_cargo.has(6) and level.empty_cargo.size() == 6 and not level.cargo.has(6), "real death callback removes only seventh empty-carrier binding")
	check(original_cart == level.jujube_carts[6] and original_cart.visible and original_cart.position.distance_to(drop_position) < 0.01, "same seventh original cart stays exactly where its owner fell")
	check(level.force_attempts.get(6, 0) == 1 and battle.mission.actions.has("force_take_6_1") and not battle.mission.actions.has("force_load_6_0"), "empty-cart death retires stale load command and registers one relay attempt")
	check_takeover_label("force_take_6_1")
	await _wait(0.75)
	check(original_cart.position.distance_to(drop_position) < 0.01, "abandoned original empty cart remains stationary across live ticks")
	check(level.bundles.all(func(u): return battle.units.has(u) and u.visible) and level.delivered == 0, "empty-cart drop leaves all eleven actual loads untouched")
	observe("empty_carrier_death")
	if not failures.is_empty(): finish(); return
	battle.select_single(battle.find_unit("bai_sheng"), false)
	check(not battle.mission.request_action("force_take_6_1"), "wine seller cannot take abandoned empty cart")
	battle.select_single(battle.find_unit("chao_gai"), false)
	check(not battle.mission.request_action("force_take_6_1"), "Star already pushing his own empty cart cannot take a second cart")
	if not await checkpoint_save(battle, "empty_cart_owner_lost"): finish(); return
	# Free one living Star through genuine loading and delivery of his own cart.
	if not await perform("force_load_0_0", "chao_gai") or not await perform("force_deliver_0_0", "chao_gai"): finish(); return
	check(level.delivered == 2 and not battle.find_unit("chao_gai").has_meta("pushing_empty_tribute") and not battle.find_unit("chao_gai").has_meta("carrying_tribute"), "Chao genuinely delivers his own two loads before becoming relay carrier")
	check(battle.mission.actions["force_take_6_1"].actors.has("chao_gai"), "finished Star becomes eligible to take fallen owner's empty cart")
	if not await perform("force_take_6_1", "chao_gai"): finish(); return
	var relay: Variant = battle.find_unit("chao_gai")
	check(level.empty_cargo.get(6) == relay and relay.get_meta("pushing_empty_tribute", -1) == 6 and original_cart == level.jujube_carts[6], "living Star takes the same abandoned empty-cart node")
	battle.select_single(relay, false)
	check(not battle.mission.request_action("force_take_6_1") and not battle.mission.request_action("force_load_6_0"), "completed takeover and dead owner's stale loading command are rejected")
	if not await perform("force_load_6_1", "chao_gai"): finish(); return
	check(level.cargo.get(6) == relay and not level.empty_cargo.has(6) and relay.get_meta("carrying_tribute", -1) == 6 and not relay.has_meta("pushing_empty_tribute"), "relay walks original empty cart to cargo and actually loads it")
	check(level.delivered == 2 and level.cargo_ready.get(6, false) and original_cart == level.jujube_carts[6] and not original_cart.visible and not battle.units.has(level.bundles[6]), "relay loading preserves original cart and seventh load while adding no delivery credit")
	if failures.is_empty(): await checkpoint_save(battle, "empty_cart_relay_loaded")
	finish()

func finish() -> void:
	report({"scope": "Explicit death of moving original empty-cart owner; stationary original prop; living Star frees own cart, walks back, takes over and loads",
		"producer_pid": producer_report.pid, "observations": observations, "checkpoint": checkpoint, "takeover_labels": takeover_labels,
		"fault_injection": ["native lethal damage to Ruan Xiaoqi while genuinely pushing original seventh empty cart"],
		"coordinates_or_cargo_or_score_injected": false, "eight_survivor_story_claimed": false, "full_campaign_continue_accepted": false})
