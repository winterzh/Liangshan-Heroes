extends "res://tools/zhujiazhuang_feedback_qa.gd"
## Recovery hint QA: initial ordinary troops attack the southern camp at 1x and
## must actually be lost to enemies before GUI/paid production/ordinary movement.
## Frozen loss/boundary fixtures are a separate case, never a fallback for combat.
## Not a complete campaign route, a performance test, or first-player evidence.
## Run with an actual renderer and an isolated user-data directory.
## Optional ZHU_RECOVERY_OUT; default output stays in ignored .godot storage.

const RECOVERY_SCRIPT := "res://scripts/zhujiazhuang_recovery_hint.gd"
const RECOVERY_NODE := "ZhujiazhuangRecoveryHint"
const RECOVERY_SEED := 5088120
const TROOP_KEYS := ["liang_dao", "liang_qiang", "liang_gong", "liang_ma"]
var recovery_output := "res://.godot/zhujiazhuang_recovery_qa"
var recovery_script: Script
var recovery_samples: Array = []
var recovery_states: Array = []
var recovery_rng: Array = []
var live_replenishment: Dictionary = {}
var natural_trace: Array = []
var run_seed := RECOVERY_SEED
var qa_started_ms := 0
var reporting := false

func _start(mode := "", index := 2):
	var campaign = root.get_node("Campaign")
	campaign.current = index
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(key, false)
	if mode != "": campaign.set(mode, true)
	campaign.enemy_mult = 1.0
	campaign.hero_mult = 1.0
	campaign.hero_mult_touched = false
	root.get_node("Settings").auto_micro_level = 0
	root.get_node("Localize").set_language("zh_CN", false)
	Engine.time_scale = 1.0
	seed(run_seed)
	var b = load("res://scenes/main.tscn").instantiate()
	var identity_provider: Script = load("res://scripts/run_content_identity.gd")
	var identity: Dictionary = identity_provider.new().resolve_runtime_identity()
	var configured: Dictionary = b.configure_new_gameplay_rng(identity, run_seed)
	check(configured.get("ok") == true, "production RNG fixed before scene attachment")
	if configured.get("ok") != true:
		b.free()
		return null
	var initial: Dictionary = b.capture_gameplay_rng()
	var codec: Script = load("res://scripts/run_state_value_codec.gd")
	var decoded: Dictionary = codec.new().decode(initial.get("record"))
	check(initial.get("ok") == true and decoded.get("ok") == true
		and decoded.get("value", {}).get("seed") == run_seed
		and decoded.get("value", {}).get("calls") == 0, "initial production RNG seed and zero draws verified")
	recovery_rng.append({"configured": configured, "initial": initial})
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	return b

func _fixture():
	var b = await _start()
	if b == null: return null
	await physics_frame
	await physics_frame
	await process_frame
	_freeze(b)
	check(b.phase == b.Phase.FIGHT and b.fog and b.level.elapsed > 0.0
		and b.is_visible_world(b.level.hall.position), "normal fog/camp visibility settled before explicit fixture freeze")
	await _refresh_recovery(b)
	return b

func _recovery_hint(b):
	return b.hud.get_node_or_null(RECOVERY_NODE)

func _refresh_recovery(b) -> void:
	recovery_script.refresh(b)
	b.hud.set_top(b.level.top_status(b))
	b.hud.refresh_command()
	await _layout(b)

func _expect_state(b, expected: String, label: String) -> void:
	var hint = _recovery_hint(b)
	check(hint != null, label + " recovery UI exists")
	if hint == null: return
	check(hint.state_key == expected, label + " state=" + expected + " (actual=" + String(hint.state_key) + ")")
	check(hint.visible == (expected != "hidden"), label + " visibility matches derived state")
	if expected != "hidden": check(not String(hint.message.text).strip_edges().is_empty(), label + " has actionable message")
	recovery_states.append({"label": label, "expected": expected, "actual": hint.state_key,
		"visible": hint.visible, "message": hint.message.text, "game_seconds": b.level.elapsed,
		"locale": root.get_node("Localize").locale})

func _ordinary_army(b) -> Array:
	return b.units.filter(func(u): return alive(u) and u.faction == 0 and u.key in TROOP_KEYS
		and not u.is_hero and not u.is_worker and not u.is_captive and not u.is_noncombat)

func _barracks(b):
	for u in b.units:
		if alive(u) and u.faction == 0 and u.key == "barracks": return u
	return null

func _recovery_authority(b) -> Dictionary:
	var result := _authority(b)
	var production: Array = []
	for u in b.units:
		if not is_instance_valid(u): continue
		production.append([u.get_instance_id(), u._train_queue.duplicate(true), u._train_t,
			u._research_key, u._research_t, u.rally, u.has_rally, u.garrisoned,
			u.is_constructing, u.build_progress, u.is_captive, u.is_noncombat, u.story_outcome])
	result["production"] = production
	result["selection"] = b.selection.map(func(u): return u.get_instance_id())
	result["population"] = [b.pop_cap, b.used_pop(), b._queued_pop()]
	result["factions"] = b.faction_res.duplicate(true)
	result["phase"] = b.phase
	return result

func _command_control(node: Node, kind: String, key := "") -> Control:
	for property in node.get_property_list():
		if property.name != "spec": continue
		var spec: Variant = node.get("spec")
		if spec is Dictionary and spec.get("kind") == kind and (key == "" or spec.get("key") == key):
			return node as Control
	for child in node.get_children():
		var found := _command_control(child, kind, key)
		if found != null: return found
	return null

func _control_click(control: Control, label: String) -> void:
	check(control != null, label + " actual control exists")
	if control == null: return
	for i in range(3): await process_frame
	check(control.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect()),
		label + " actual control is visible inside viewport")
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _screenshot_recovery(b, label: String, scope: String) -> void:
	var hint = _recovery_hint(b)
	check(hint != null, label + " hint exists for screenshot")
	if hint == null: return
	if b.is_physics_processing():
		for i in range(9): await process_frame
	else:
		await _layout(b)
	if hint.visible:
		var rect: Rect2 = hint.get_global_rect()
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(rect), label + " hint stays inside 1280x720")
		check(rect.end.y <= b.hud._bottom_panel.get_global_rect().position.y,
			label + " hint does not overlap bottom command area")
		for control in [hint.message, hint.barracks_button, hint.camp_button]:
			if control.visible:
				check(rect.grow(1.0).encloses(control.get_global_rect()), label + " child fits panel: " + control.name)
		check(hint.message.size.y + 1.0 >= hint.message.get_minimum_size().y, label + " message has required vertical layout space")
	await RenderingServer.frame_post_draw
	var path := recovery_output.path_join(label + ".png")
	var error := root.get_texture().get_image().save_png(path)
	check(error == OK, label + " renderer PNG saved")
	recovery_samples.append({"name": label, "file": path, "sha256": FileAccess.get_sha256(path) if error == OK else "",
		"locale": root.get_node("Localize").locale, "size": str(root.size), "state": hint.state_key,
		"message": hint.message.text, "scope": scope, "visual_inspection": "pending"})

func _recreate_hint(b, expected: String) -> void:
	var hint = _recovery_hint(b)
	if hint == null:
		check(false, "UI recreation requires an existing hint")
		return
	var previous_id: int = hint.get_instance_id()
	var before := _recovery_authority(b)
	b.hud.remove_child(hint)
	hint.queue_free()
	await process_frame
	await _refresh_recovery(b)
	hint = _recovery_hint(b)
	check(hint != null and hint.get_instance_id() != previous_id, "destroyed hint is recreated from current battle")
	_expect_state(b, expected, "UI recreation " + expected)
	check(_recovery_authority(b) == before, "UI recreation preserves gameplay authority: " + expected)

func _locator_controls(b) -> void:
	var hint = _recovery_hint(b)
	var bar = _barracks(b)
	if hint == null or bar == null:
		check(false, "locator fixture requires hint and barracks")
		return
	b.select_single(b.level.song, false)
	b.center_camera_cell(b.level.CAMP)
	var before := _recovery_authority(b)
	var camera_before: Vector2 = b.camera.position
	await _control_click(hint.barracks_button, "recovery barracks locator")
	check(b.camera.position.distance_to(b.to_screen(bar.position)) < 1.0
		and b.camera.position.distance_to(camera_before) > 1.0, "barracks locator only moves to actual barracks")
	check(_recovery_authority(b) == before, "barracks locator preserves selection/orders/resources/queues/tasks")
	before = _recovery_authority(b)
	camera_before = b.camera.position
	await _control_click(hint.camp_button, "recovery camp locator")
	check(b.camera.position.distance_to(b.to_screen(b.level.hall.position)) < 1.0
		and b.camera.position.distance_to(camera_before) > 1.0, "camp locator only moves to actual camp")
	check(_recovery_authority(b) == before, "camp locator preserves selection/orders/resources/queues/tasks")

func _natural_snapshot(b, label: String) -> void:
	var troops: Array = []
	for u in b.units:
		if not alive(u) or u.faction != 0 or u.key not in TROOP_KEYS: continue
		troops.append({"id": u.entity_id, "key": u.key, "hp": u.hp,
			"position": str(u.position), "state": u._state})
	natural_trace.append({"label": label, "game_seconds": b.level.elapsed,
		"phase": b.phase, "gold": b.gold, "wood": b.wood, "troops": troops,
		"camp_hp": b.level.hall.hp if alive(b.level.hall) else 0.0,
		"song_hp": b.level.song.hp if alive(b.level.song) else 0.0})

func _world_left_click(b, world_screen: Vector2, label: String) -> void:
	var point: Vector2 = b.get_global_transform_with_canvas() * world_screen
	check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point), label + " lies in visible viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _live_production_and_movement() -> void:
	# This case starts independently and never freezes, damages, funds, teleports,
	# spawns units, changes enemy AI, or edits timers to obtain a desired outcome.
	var b = await _start()
	if b == null: return
	await create_timer(0.75).timeout
	check(b.fog and Engine.time_scale == 1.0 and b.phase == b.Phase.FIGHT,
		"natural recovery begins in normal fog, FIGHT and 1x simulation")
	_expect_state(b, "hidden", "natural opening army present")
	var troops := _ordinary_army(b)
	check(troops.size() == 4, "natural attack starts with exactly four original ordinary troops")
	if troops.size() != 4:
		await _dispose(b)
		return
	var heroes: Array = [b.level.song, b.find_unit("lin_chong")]
	var hero_positions: Array = heroes.map(func(u): return u.position if alive(u) else Vector2.INF)
	var hero_health: Array = heroes.map(func(u): return u.hp if alive(u) else 0.0)
	var hero_enemy_target_seen := false
	var initial_ids: Array = troops.map(func(u): return u.entity_id)
	var attack_start: float = b.level.elapsed
	var attack_wall: int = Time.get_ticks_msec()
	live_replenishment = {"initial_condition": "unmodified opening four troops ordered to attack-move southern enemy camp",
		"initial_troop_ids": initial_ids, "natural_loss_passed": false, "arrived": false,
		"hero_orders": "no hero orders or ability casts; remain at original camp",
		"mutation_boundary": "no freeze, take_damage, injected funds, spawn, teleport, AI/timer edits in this case"}
	b.select_members(troops, false)
	b.minimap_order(b.map.cell_to_world(b.level.OUTPOST), true)
	_natural_snapshot(b, "attack_south_ordered")
	var next_trace: float = b.level.elapsed + 5.0
	# Independent game and wall limits: a stalled or ineffective attack fails;
	# it is never replaced by the explicitly frozen death case below.
	while not _ordinary_army(b).is_empty() and b.phase == b.Phase.FIGHT \
			and b.level.elapsed - attack_start < 240.0 \
			and Time.get_ticks_msec() - attack_wall < 300000:
		await create_timer(0.25).timeout
		for hero in heroes:
			if alive(hero) and is_instance_valid(hero._target) and hero._target.faction == 1:
				hero_enemy_target_seen = true
		if b.level.elapsed >= next_trace:
			_natural_snapshot(b, "natural_attack_progress")
			next_trace = b.level.elapsed + 5.0
	var lost_naturally := _ordinary_army(b).is_empty() and b.phase == b.Phase.FIGHT
	check(lost_naturally, "four starting soldiers are naturally lost to southern enemy camp within 240 game seconds")
	check(heroes.all(func(u): return alive(u)) and alive(b.level.hall),
		"heroes and camp remain alive after natural setback")
	var heroes_stayed := true
	for i in range(heroes.size()):
		if not alive(heroes[i]) or heroes[i].position.distance_to(hero_positions[i]) > 96.0 \
				or heroes[i].hp < float(hero_health[i]) - 0.01:
			heroes_stayed = false
	check(heroes_stayed and not hero_enemy_target_seen, "heroes remain out of the sampled southern engagement")
	live_replenishment["natural_loss_passed"] = lost_naturally
	live_replenishment["loss_game_seconds"] = b.level.elapsed - attack_start
	live_replenishment["loss_wall_seconds"] = float(Time.get_ticks_msec() - attack_wall) / 1000.0
	live_replenishment["heroes_stayed_at_camp"] = heroes_stayed
	live_replenishment["hero_enemy_target_seen"] = hero_enemy_target_seen
	_natural_snapshot(b, "natural_setback_result")
	if not lost_naturally:
		await _screenshot_recovery(b, "natural_loss_not_reached", "natural attack did not reach required setback; retained failure, no fixture substitution")
		await _dispose(b)
		return
	var camera_before: Vector2 = b.camera.position
	await create_timer(0.65).timeout
	_expect_state(b, "ready", "normal level process shows recovery after natural losses")
	check(b.camera.position == camera_before, "natural recovery hint does not take camera control")
	var hint = _recovery_hint(b)
	var bar = _barracks(b)
	if hint == null or bar == null:
		check(false, "natural recovery requires real hint and surviving barracks")
		await _dispose(b)
		return
	await _screenshot_recovery(b, "natural_setback_ready", "unfrozen natural combat losses; continuing real simulation")
	var selection_before: Array = b.selection.duplicate()
	await _control_click(hint.camp_button, "natural recovery camp locator")
	check(b.selection == selection_before, "natural camp locator preserves current selection")
	check(b.camera.position.distance_to(b.to_screen(b.level.hall.position)) < 1.0,
		"natural camp locator reaches surviving camp")
	await _control_click(hint.barracks_button, "natural recovery barracks locator")
	check(b.selection == selection_before, "natural barracks locator does not select or order units")
	check(b.camera.position.distance_to(b.to_screen(bar.position)) < 1.0,
		"natural barracks locator reaches surviving barracks")
	# Actually click the displayed building after using the hint's camera button.
	var hit_point: Vector2 = b.to_screen(bar.position) + Vector2(0, -20)
	check(b._player_building_at(hit_point) == bar, "visible building click resolves to the intended barracks")
	await _world_left_click(b, hit_point, "actual barracks selection")
	check(b.selection == [bar], "separate world GUI click selects the barracks")
	b.hud.refresh_command()
	for i in range(5): await process_frame
	var cost: Dictionary = b._defs["liang_qiang"]
	var train_card := _command_control(b.hud._skill_bar, "train", "liang_qiang")
	check(train_card != null, "natural recovery real spear training card exists")
	if train_card == null:
		await _dispose(b)
		return
	for i in range(3): await process_frame
	check(train_card.is_visible_in_tree()
		and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(train_card.get_global_rect()),
		"natural training card is visible before actual GUI payment")
	var train_point := train_card.get_global_rect().get_center()
	var train_motion := InputEventMouseMotion.new()
	train_motion.position = train_point
	root.push_input(train_motion)
	# No await or manual simulation tick between these observations and both
	# real GUI events. Workers continue normally before/after this single frame.
	# This needs no optional Battle observer or unpublished gameplay changes.
	var gold_before: int = b.gold
	var wood_before: int = b.wood
	var queue_before: Array = bar._train_queue.duplicate()
	var payment_frame: int = Engine.get_physics_frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = train_point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	var gold_after: int = b.gold
	var wood_after: int = b.wood
	var queue_after: Array = bar._train_queue.duplicate()
	check(queue_before.is_empty() and queue_after == ["liang_qiang"],
		"actual same-frame GUI press/release queues exactly one ordinary soldier")
	check(gold_after == gold_before - int(cost.cost_gold)
		and wood_after == wood_before - int(cost.cost_wood)
		and Engine.get_physics_frames() == payment_frame,
		"same-frame GUI payment debits exact production cost with no intervening worker tick")
	live_replenishment["payment"] = {"gold_before": gold_before, "wood_before": wood_before,
		"gold_after": gold_after, "wood_after": wood_after, "queue_before": queue_before,
		"queue_after": queue_after, "physics_frame": payment_frame,
		"method": "real GUI press/release in one frame; no await, freeze, resource hook or injection"}
	if bar._train_queue != ["liang_qiang"]:
		await _screenshot_recovery(b, "natural_training_failed", "real GUI training failed; no forced queue insertion")
		await _dispose(b)
		return
	var train_seconds: float = b.train_time_for("liang_qiang")
	var start_game: float = b.level.elapsed
	var start_wall: int = Time.get_ticks_msec()
	check(bar._train_t > 0.0 and bar._train_t <= train_seconds,
		"natural training timer uses unmodified runtime duration")
	await create_timer(0.65).timeout
	_expect_state(b, "training", "normal level refresh notices paid reinforcement queue")
	await _screenshot_recovery(b, "natural_training", "unfrozen actual paid GUI order and ordinary production timer")
	while _ordinary_army(b).is_empty() and b.phase == b.Phase.FIGHT \
			and Time.get_ticks_msec() - start_wall < int((train_seconds + 25.0) * 1000.0):
		await create_timer(0.25).timeout
	var army := _ordinary_army(b)
	check(army.size() == 1 and bar._train_queue.is_empty(), "normal 1x running simulation produces one troop")
	check(b.level.elapsed - start_game >= train_seconds - 0.5 and Engine.time_scale == 1.0,
		"live production consumes the ordinary game duration at 1x")
	live_replenishment.merge({"train_seconds": train_seconds,
		"production_game_seconds": b.level.elapsed - start_game,
		"production_wall_seconds": float(Time.get_ticks_msec() - start_wall) / 1000.0,
		"gold_paid": int(cost.cost_gold), "wood_paid": int(cost.cost_wood), "produced_count": army.size()})
	if army.size() == 1:
		var troop = army[0]
		await create_timer(0.65).timeout
		_expect_state(b, "hidden", "normal level refresh sees replenished army")
		var before_position: Vector2 = troop.position
		var before_serial: int = troop._order_serial
		var target_cell: Vector2i = b.level.CAMP + Vector2i(-7, 4)
		var target: Vector2 = b.map.cell_to_world(target_cell)
		check(not b.map.find_path(troop.position, target).is_empty(), "safe gathering point outside camp has a normal path")
		b.select_single(troop, false)
		b._issue_order(b.to_screen(target), false)
		check(troop._order_serial > before_serial, "separate ordinary player move order starts gathering")
		var move_start: int = Time.get_ticks_msec()
		while alive(troop) and troop.position.distance_to(target) > 56.0 and b.phase == b.Phase.FIGHT \
				and Time.get_ticks_msec() - move_start < 30000:
			await create_timer(0.25).timeout
		var arrived: bool = alive(troop) and troop.position.distance_to(target) <= 56.0
		check(arrived and troop.position.distance_to(before_position) > 100.0,
			"new paid troop really walks to safe gathering point without teleportation")
		live_replenishment["move_target_cell"] = str(target_cell)
		live_replenishment["move_start"] = str(before_position)
		live_replenishment["move_end"] = str(troop.position) if is_instance_valid(troop) else "freed"
		live_replenishment["arrived"] = arrived
		check(b.phase == b.Phase.FIGHT and alive(b.level.song) and alive(b.level.hall), "live recovery preserves continuing campaign")
		_expect_state(b, "hidden", "army remains available after gathering")
		b.center_camera_cell(target_cell)
		await _screenshot_recovery(b, "live_replenished_and_moved", "natural setback, paid production and movement; simulation remains running")
	_natural_snapshot(b, "natural_recovery_result")
	await _dispose(b)

func _boundary_states_and_languages() -> void:
	var b = await _fixture()
	if b == null: return
	_expect_state(b, "hidden", "frozen opening boundary")
	await _recreate_hint(b, "hidden")
	var troops := _ordinary_army(b)
	if troops.size() != 4:
		check(false, "boundary fixture needs four opening troops")
		await _dispose(b)
		return
	for i in range(3): troops[i].take_damage(troops[i].max_hp * 20.0, null, false, true)
	troops[3].garrisoned = true # Explicit classification fixture, not a played garrison route.
	await _refresh_recovery(b)
	_expect_state(b, "hidden", "one garrisoned ordinary soldier still counts as alive")
	troops[3].garrisoned = false
	troops[3].take_damage(troops[3].max_hp * 20.0, null, false, true)
	check(_ordinary_army(b).is_empty() and alive(b.level.song) and alive(b.find_unit("lin_chong"))
		and alive(b.level.hall) and b.phase == b.Phase.FIGHT,
		"frozen four-soldier take_damage fixture preserves heroes/camp/FIGHT")
	var siege = b.spawn_at("siege_ram", 0, Vector2i(58, 30)) # Boundary-only entity; never part of live production case.
	_freeze(b)
	await _refresh_recovery(b)
	check(alive(siege), "siege classification fixture created through production spawn API")
	_expect_state(b, "ready", "heroes/workers/captives/siege do not mask missing ordinary troops")
	await _recreate_hint(b, "ready")
	await _locator_controls(b)
	var bar = _barracks(b)
	if bar == null:
		check(false, "boundary fixture barracks missing")
		await _dispose(b)
		return
	var saved_gold: int = b.gold
	var saved_wood: int = b.wood
	var saved_pop: int = b.pop_cap
	b.select_single(bar, false)
	await _refresh_recovery(b)
	var cost: Dictionary = b._defs["liang_qiang"]
	await _control_click(_command_control(b.hud._skill_bar, "train", "liang_qiang"), "frozen real paid training card")
	check(bar._train_queue == ["liang_qiang"] and b.gold == saved_gold - int(cost.cost_gold)
		and b.wood == saved_wood - int(cost.cost_wood), "frozen GUI training spends normal resources")
	await _refresh_recovery(b)
	_expect_state(b, "training", "frozen paid queue boundary")
	await _recreate_hint(b, "training")
	bar.production_blocked = true # Explicit blocked-exit UI boundary; not a natural obstruction.
	await _refresh_recovery(b)
	_expect_state(b, "blocked", "frozen blocked production exit boundary")
	bar.production_blocked = false
	await _control_click(_command_control(b.hud._queue_bar, "cancel_train", "liang_qiang"), "frozen actual queue cancel card")
	check(bar._train_queue.is_empty() and b.gold == saved_gold and b.wood == saved_wood,
		"actual GUI cancellation refunds exact cost and clears ordinary queue")
	await _refresh_recovery(b)
	_expect_state(b, "ready", "queue canceled while ordinary army absent")
	var localized_messages: Dictionary = {}
	for locale in ["zh_CN", "zh_TW", "en", "ja"]:
		root.get_node("Localize").set_language(locale, false)
		await _refresh_recovery(b)
		_expect_state(b, "ready", "ready locale " + locale)
		var hint = _recovery_hint(b)
		if hint != null: localized_messages[locale] = hint.message.text
		await _screenshot_recovery(b, "boundary_ready_" + locale, "frozen classification/layout fixture; normal fog; visual inspection pending")
	check(localized_messages.size() == 4 and localized_messages.get("en") != localized_messages.get("zh_CN")
		and localized_messages.get("ja") != localized_messages.get("zh_CN"), "English and Japanese messages translate instead of falling back to Chinese")
	root.get_node("Localize").set_language("zh_CN", false)
	# The mutations below are explicit isolated boundary fixtures only. Resource
	# reductions and exact restoration never enter the live replenishment case.
	b.gold = 0
	b.wood = 0
	await _refresh_recovery(b)
	_expect_state(b, "resources", "zero resources boundary")
	await _recreate_hint(b, "resources")
	await _screenshot_recovery(b, "boundary_resources_zh_CN", "frozen zero-resource fixture")
	b.gold = saved_gold
	b.wood = saved_wood
	b.pop_cap = b.used_pop()
	await _refresh_recovery(b)
	_expect_state(b, "population", "no free population boundary")
	b.pop_cap = saved_pop
	bar._research_key = "tech_armor"
	bar._research_t = 60.0
	await _refresh_recovery(b)
	_expect_state(b, "researching", "busy research boundary")
	bar._research_key = ""
	bar._research_t = 0.0
	bar.is_constructing = true
	await _refresh_recovery(b)
	_expect_state(b, "constructing", "barracks construction boundary")
	bar.is_constructing = false
	await _refresh_recovery(b)
	_expect_state(b, "ready", "all temporary boundary restrictions removed")
	bar.take_damage(bar.max_hp * 20.0, null, false, true)
	await _refresh_recovery(b)
	_expect_state(b, "no_barracks", "real barracks death boundary")
	check(b.phase == b.Phase.FIGHT, "barracks loss does not itself end the campaign")
	await _recreate_hint(b, "no_barracks")
	var hint = _recovery_hint(b)
	if hint != null:
		check(not hint.barracks_button.visible or hint.barracks_button.disabled,
			"missing barracks has no actionable locator to a destroyed target")
	await _screenshot_recovery(b, "boundary_no_barracks_zh_CN", "frozen real barracks death fixture")
	for worker in b.level.workers:
		if alive(worker): worker.take_damage(worker.max_hp * 20.0, null, false, true)
	await _refresh_recovery(b)
	_expect_state(b, "no_workers", "frozen loss of workers with camp and heroes surviving")
	check(alive(b.level.hall) and alive(b.level.song) and b.phase == b.Phase.FIGHT,
		"missing workforce does not falsely claim terminal defeat")
	await _screenshot_recovery(b, "boundary_no_workers_zh_CN", "frozen worker-death fixture; no natural worker-loss claim")
	b.level.hall.take_damage(b.level.hall.max_hp * 20.0, null, false, true)
	# END stops the level process; require the hint's own process to hide it.
	for i in range(9): await process_frame
	check(b.phase == b.Phase.END, "real camp death enters ordinary terminal phase")
	_expect_state(b, "hidden", "terminal battle hides recovery hint")
	await _recreate_hint(b, "hidden")
	await _screenshot_recovery(b, "boundary_terminal_zh_CN", "frozen camp-death/terminal UI fixture")
	await _dispose(b)

func _write_recovery_report() -> void:
	if reporting: return
	reporting = true
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"samples": recovery_samples, "states": recovery_states, "rng": recovery_rng,
		"live_replenishment": live_replenishment, "natural_trace": natural_trace,
		"seed": run_seed, "profile": OS.get_environment("ZHU_RECOVERY_PROFILE"),
		"source_manifest": OS.get_environment("ZHU_RECOVERY_SOURCE_MANIFEST"),
		"wall_seconds": float(Time.get_ticks_msec() - qa_started_ms) / 1000.0,
		"scope": "independent natural 1x southern-camp setback, GUI locators/selection, paid production and real movement; separate frozen classification/loss/boundary fixtures",
		"not_proven": ["first-player understanding", "complete campaign victory", "cross-process save restoration", "performance", "human visual approval"]}
	var file := FileAccess.open(recovery_output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not create recovery QA report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[zhu-recovery] ", checks, " checks; failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _recovery_deadline() -> void:
	if reporting: return
	check(false, "total recovery QA wall-clock deadline reached at 590 seconds")
	if current_scene != null and is_instance_valid(current_scene):
		_natural_snapshot(current_scene, "wall_deadline")
	_write_recovery_report()

func _run() -> void:
	qa_started_ms = Time.get_ticks_msec()
	create_timer(590.0, true, false, true).timeout.connect(_recovery_deadline)
	if not OS.get_environment("ZHU_RECOVERY_OUT").is_empty(): recovery_output = OS.get_environment("ZHU_RECOVERY_OUT")
	var seed_text := OS.get_environment("ZHU_RECOVERY_SEED")
	if seed_text.is_valid_int(): run_seed = seed_text.to_int()
	DirAccess.make_dir_recursive_absolute(recovery_output)
	if DisplayServer.get_name() == "headless":
		check(false, "actual renderer required for recovery GUI QA")
		_write_recovery_report()
		return
	if not ResourceLoader.exists(RECOVERY_SCRIPT):
		check(false, "recovery production script must exist before QA runs")
		_write_recovery_report()
		return
	recovery_script = load(RECOVERY_SCRIPT)
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	root.get_node("Settings").edge_scroll = false
	root.get_node("Localize").set_language("zh_CN", false)
	Engine.max_fps = 60
	Engine.time_scale = 1.0
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	# Derived hint recreation is not an entire-world save/load test. This narrow
	# audit only guards against introducing unregistered authoritative Level fields.
	var level_state: Script = load("res://scripts/run_campaign_level_state.gd")
	var declarations: Dictionary = level_state.new().audit_declarations("level3")
	check(declarations.get("ok") == true, "level3 authoritative save declarations remain registered")
	await _live_production_and_movement()
	await _boundary_states_and_languages()
	_write_recovery_report()
