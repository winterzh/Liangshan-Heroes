extends SceneTree
## Manual-order contract for the four later campaign chapters.
##
## This fixture never calls CampaignMission.request_action().  Every branch is
## entered through the production selection/right-click path:
## Battle._set_selection -> Battle._issue_order -> Unit.order_move/order_attack.
## Once a real attack has acquired and damaged its target, a labelled boundary
## settlement resolves the remaining finite force so the four chapters stay a
## short deterministic regression rather than an automated pacing claim.

const OUT_DIR := "res://qa/campaign_manual_play_20260901/late"
const FACTION_LIANG := 0
const FACTION_GUAN := 1

var failures: Array[String] = []
var checks := 0
var evidence: Array[Dictionary] = []
var player_move_orders := 0
var player_attack_orders := 0
var boundary_resolutions := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("[manual-late] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func _story_state(b, goal_id: String) -> String:
	if not b.mission.story_goals.has(goal_id):
		return "missing"
	return String(b.mission.story_goals[goal_id].state)


func _start(level_id: String):
	seed(5088120)
	var campaign = root.get_node("Campaign")
	campaign.current = campaign.index_for_id(level_id)
	campaign.arena = false
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.scenario = false
	campaign.custom_defense = false
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	Engine.time_scale = 8.0
	return b


func _dispose(b) -> void:
	if current_scene == b:
		current_scene = null
	b.queue_free()
	await process_frame
	await process_frame


func _living_player_units(b, include_captives := false) -> Array:
	return b.units.filter(func(u):
		return is_instance_valid(u) and u.faction == FACTION_LIANG and u.hp > 0.0 \
			and u.story_outcome == "" and not u.is_building and not u.garrisoned \
			and (include_captives or not u.is_captive))


func _player_move(b, actors: Array, cell: Vector2i) -> bool:
	var valid: Array = actors.filter(func(u):
		return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "" \
			and not u.is_building and not u.garrisoned and not u.is_captive)
	if valid.is_empty():
		return false
	b._set_selection(valid)
	var destination: Vector2 = b.map.cell_to_world(cell)
	b._issue_order(b.to_screen(destination))
	player_move_orders += 1
	var shared_token: int = int(valid[0].mission_order_token)
	return valid.all(func(u):
		return u.manual_order_t > 0.0 and u.manual_order_active \
			and (u.mission_order_active or u.mission_order_arrival_t > 0.0) \
			and shared_token > 0 and u.mission_order_token == shared_token \
			and u.mission_order_target.distance_to(destination) <= 0.1 \
			and u._target == null \
			and not bool(u.get_meta(b.mission.AUTO_DISPATCH_META, false)))


func _player_attack(b, actors: Array, target) -> bool:
	if not is_instance_valid(target) or target.hp <= 0.0 or target.story_outcome != "":
		return false
	var valid: Array = actors.filter(func(u):
		return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "" \
			and not u.is_building and not u.garrisoned and not u.is_captive)
	if valid.is_empty():
		return false
	b._set_selection(valid)
	b._issue_order(b.to_screen(target.position))
	player_attack_orders += 1
	return valid.all(func(u):
		return u.manual_order_t > 0.0 and u.manual_order_active \
			and u._target == target and not u.mission_order_active \
			and u.mission_order_arrival_t <= 0.0 and u.mission_order_target == Vector2.INF \
			and u.mission_order_token == 0 \
			and not bool(u.get_meta(b.mission.AUTO_DISPATCH_META, false)))


func _wait_for(predicate: Callable, limit := 1800, freeze_new_enemies := false) -> bool:
	var frames := 0
	while not predicate.call() and frames < limit:
		if freeze_new_enemies and is_instance_valid(current_scene):
			for u in current_scene.units:
				if is_instance_valid(u) and u.faction == FACTION_GUAN:
					u.set_physics_process(false)
		await process_frame
		frames += 1
	return bool(predicate.call())


func _wait_damaged(target, limit := 1800) -> bool:
	if not is_instance_valid(target):
		return false
	var initial_hp: float = target.hp
	return await _wait_for(func():
		return not is_instance_valid(target) or target.story_outcome != "" or target.hp < initial_hp, limit)


func _resolve_effective(arr: Array, outcome := "subdued") -> int:
	var count := 0
	for u in arr:
		if is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "":
			u.resolve_story(outcome)
			count += 1
	boundary_resolutions += count
	return count


func _freeze_enemies(b) -> void:
	for u in b.units:
		if is_instance_valid(u) and u.faction == FACTION_GUAN:
			u.set_physics_process(false)


func _zhujiazhuang_manual() -> void:
	var b = await _start("level3")
	var l = b.level
	l._third_day(b) # Bounded cross-day entry; all branch play below is manual.
	await process_frame
	var allies := _living_player_units(b)
	# Put Sun Li directly on his authored admission marker, then issue an attack
	# with no intervening frame. The attack must win over the nearby task action.
	l.sun.position = b.map.cell_to_world(Vector2i(24, 28))
	var ordered := _player_attack(b, allies, l.gate)
	_check(ordered, "Zhujiazhuang gate order is stamped as a real player attack")
	_check(await _wait_for(func(): return l.free_third_assault, 900),
		"attacking the manor gate enters the free third assault without a task button")
	_check(_story_state(b, "zhu_inside") == "missed" and b.phase == b.Phase.FIGHT,
		"direct manor assault forfeits only the inside-agent story goal")
	_check(not b.mission.has_event("zhu_sun_entered") and not b.mission.has_event("action:zhu_infiltrate:zhu_enter_manor"),
		"gate attack is not misread as Sun Li's authored admission action")
	var gate_damaged := await _wait_damaged(l.gate, 1500)
	_check(gate_damaged, "the selected force really damages the unshielded manor gate")
	if is_instance_valid(l.gate) and l.gate.story_outcome == "":
		l.gate.resolve_story("subdued") # Boundary settlement after real contact.
		boundary_resolutions += 1
	await process_frame
	_freeze_enemies(b)
	var rescuer = l.song
	# (15,32) is inside the prison trigger but clear of the captive/guard click
	# radii.  This proves a move order rather than accidentally right-clicking a
	# projected unit next to the cart.
	_check(_player_move(b, [rescuer], l.PRISON_CELL + Vector2i(4, -1)),
		"a real player move sends a surviving fighter through the breached gate to the prison")
	_check(await _wait_for(func(): return b.mission.has_event("zhu_prisoners_freed"), 1800),
		"arrival at the prison frees all seven captives without a task button")
	var prisoner_event_count := 1 if b.mission.events.has("zhu_prisoners_freed") else 0
	l._third_free_tick(b)
	l._third_free_tick(b)
	_check(prisoner_event_count == 1 and b.mission.events.has("zhu_prisoners_freed") and l.prisoners.size() == 7,
		"repeated prison-zone processing cannot duplicate captives or settlement")
	var live_commanders: Array = ["zhu_long", "zhu_hu", "zhu_biao", "luan_tingyu"].map(func(key): return b.find_unit(key)).filter(func(u):
		return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "")
	var commander = live_commanders[0] if not live_commanders.is_empty() else null
	allies = _living_player_units(b)
	_check(_player_attack(b, allies, commander),
		"the player can issue a second real attack order against the manor commanders")
	_check(await _wait_damaged(commander, 1800), "the commander attack reaches real combat contact")
	for key in ["zhu_long", "zhu_hu", "zhu_biao", "luan_tingyu"]:
		var foe = b.find_unit(key)
		if is_instance_valid(foe) and foe.story_outcome == "":
			foe.take_damage(1000000.0, rescuer)
			boundary_resolutions += 1
	_check(await _wait_for(func(): return b.phase == b.Phase.END, 300),
		"manual gate and prison route has no soft lock and reaches core victory")
	var result: Dictionary = b.mission.result_snapshot(true)
	_check(b.phase == b.Phase.END and bool(result.get("core_cleared", false)) and not bool(result.get("story_complete", true)),
		"Zhujiazhuang records base clear and an incomplete story run separately")
	evidence.append({"level":"level3", "events":b.mission.events.keys(), "result":result,
		"manual_route":"attack gate -> move through breach -> free prison -> attack commanders"})
	await _dispose(b)


func _lianhuanma_manual() -> void:
	var b = await _start("level4")
	var l = b.level
	_check(_player_move(b, [l.xu], Vector2i(12, 47)),
		"Lianhuanma skip-training marker accepts a real player move")
	_check(await _wait_for(func(): return l.stage == "prepare", 1800),
		"manual skip-training order redeploys the battle without a task button")
	_check(l.training_skipped and _story_state(b, "lhm_training") == "missed",
		"skipping training loses only the training story goal")
	_check(not l.free_battle and not b.mission.has_event("action:lhm_prepare:lhm_direct_battle"),
		"the consumed skip-training command does not also trigger the next-stage direct battle")
	var actor = _living_player_units(b).filter(func(u): return u.key == "lin_chong")[0]
	_check(_player_move(b, [actor], Vector2i(40, 34)),
		"a real player advance reaches the direct-battle route")
	_check(await _wait_for(func(): return l.free_battle and l.riders.size() == 12, 1800),
		"advancing beyond the prepared line starts both finite cavalry waves without a task button")
	var rider = l.riders[0]
	var fighters: Array = _living_player_units(b).filter(func(u): return u.key not in ["song_jiang", "wu_yong"])
	_check(_player_attack(b, fighters, rider),
		"the selected force receives a real focus-attack order against an intact linked rider")
	_check(await _wait_damaged(rider, 1200),
		"direct assault damages a high-reduction rider instead of being rejected by script")
	for mounted in l.riders:
		if is_instance_valid(mounted) and mounted.hp > 0.0 and mounted.story_outcome == "":
			mounted.take_damage(1000000.0, actor)
			boundary_resolutions += 1
	if is_instance_valid(l.han) and l.han.story_outcome == "":
		l.han.resolve_story("captured")
		boundary_resolutions += 1
	_check(await _wait_for(func(): return b.phase == b.Phase.END, 600),
		"finite direct battle settles the core after all twelve riders and Han Tao are resolved")
	var result: Dictionary = b.mission.result_snapshot(true)
	_check(bool(result.get("core_cleared", false)) and _story_state(b, "lhm_hooks") == "missed",
		"direct victory is a base clear and does not falsely award the all-hooks story goal")
	_check(b.mission.has_event("lhm_hu_fled") and b.mission.has_event("lhm_han_captured"),
		"Huyan flight and Han capture remain separate outcomes on the free route")
	evidence.append({"level":"level4", "events":b.mission.events.keys(), "result":result,
		"manual_route":"move to skip training -> advance past line -> focus intact rider"})
	await _dispose(b)


func _daming_manual() -> void:
	var b = await _start("level8")
	var l = b.level
	_check(_player_move(b, [l.strategist], Vector2i(26, 48)),
		"Daming strategist receives a real player order at the public-assault rally")
	_check(await _wait_for(func(): return l.open_assault and l.stage == "gate", 300),
		"manual rally order starts public assault without a task button")
	_check(_story_state(b, "daming_infiltration") == "missed" and _story_state(b, "daming_signal") == "missed",
		"public assault forfeits infiltration and fire-signal goals only")
	_check(not l.gate_open and not b.mission.has_event("action:daming_gate:daming_open_gate"),
		"the consumed public-assault order does not also open the next-stage gate")
	var responders: Array = l.outside_army.filter(func(u): return is_instance_valid(u) and u.key in l.ESCORT_KEYS)
	_check(_player_attack(b, responders, l.gate),
		"released outside troops can receive a real focus-attack order on the south gate")
	_check(await _wait_damaged(l.gate, 1200), "the public assault really damages the south gate")
	if is_instance_valid(l.gate) and l.gate.story_outcome == "":
		l.gate.resolve_story("subdued")
		boundary_resolutions += 1
	_check(await _wait_for(func(): return l.gate_open and l.stage == "rescue", 300),
		"breaking the gate opens a navigable rescue route with no task-button dependency")
	var live_guards: Array = l.guards.filter(func(u): return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "")
	if not live_guards.is_empty():
		_check(_player_attack(b, responders, live_guards[0]),
			"the player can issue real attack orders to clear the jail approach")
		_check(await _wait_damaged(live_guards[0], 900), "the jail-approach attack reaches real combat contact")
	else:
		_check(false, "the player can issue real attack orders to clear the jail approach")
		_check(false, "the jail-approach attack reaches real combat contact")
	_resolve_effective(l.guards)
	_freeze_enemies(b)
	var rescuer = responders[0]
	_check(_player_move(b, [rescuer], l.PRISON_CHECK),
		"a real move sends the rescuer through the open south gate to the prison door")
	_check(await _wait_for(func(): return l.prison_door_open, 2400),
		"arrival opens the prison approach without a scripted task dispatch")
	_check(_player_move(b, [rescuer], l.JAIL_ACTION),
		"the same selected rescuer receives a second real move into the jail")
	_check(await _wait_for(func(): return l.rescued and l.prison_breached, 900),
		"arrival releases Lu Junyi and Shi Xiu without a task button")
	var release_key_count := int(b.mission.events.has("daming_prisoners_freed"))
	l._open_assault_tick(b)
	l._open_assault_tick(b)
	_check(release_key_count == 1 and l.rescued and is_instance_valid(l.lu) and is_instance_valid(l.shi),
		"repeated jail-zone processing cannot release or spawn the prisoners twice")
	_check(_player_move(b, [l.lu, l.shi], l.EXIT_CELL),
		"both rescued prisoners accept a real grouped move toward the city exit")
	_check(await _wait_for(func():
		return b.mission.has_event("daming_lu_safe") and b.mission.has_event("daming_shi_safe"), 3000, true),
		"both prisoners physically reach the exit and remain alive")
	_check(await _wait_for(func(): return b.phase == b.Phase.END, 300),
		"manual public assault, jail breach, and exit route reaches core victory without a soft lock")
	var result: Dictionary = b.mission.result_snapshot(true)
	_check(bool(result.get("core_cleared", false)) and not bool(result.get("story_complete", true)),
		"Daming records the manual public assault as base clear with missed story goals")
	evidence.append({"level":"level8", "events":b.mission.events.keys(), "result":result,
		"manual_route":"rally public assault -> attack gate/guards -> move into jail -> grouped prisoner exit"})
	await _dispose(b)


func _finale_manual() -> void:
	var b = await _start("level5")
	var l = b.level
	var first_target = l.enemy_fleet[-1]
	_check(_player_attack(b, l.fleet, first_target),
		"finale fleet receives a real player focus-attack order before the lure")
	_check(await _wait_damaged(first_target, 1800), "first-invasion ships make real combat contact")
	_check(await _wait_for(func(): return l.first_direct and l.lure_route == "direct", 300),
		"early naval contact switches to the direct first battle without a task button")
	_check(_story_state(b, "gao_lure") == "missed", "direct first battle forfeits only the lure story goal")
	_resolve_effective(l.enemy_fleet)
	_check(await _wait_for(func(): return l.stage == "fire_prepare", 600),
		"surviving Liangshan ships carry the core into the second invasion")
	_check(not l.fire_direct and not b.mission.has_event("action:fire_prepare:fire_direct"),
		"the first direct order is consumed and cannot auto-trigger second-invasion direct combat")
	var fire_target = l.enemy_fleet[-1]
	_check(_player_attack(b, l.fleet, fire_target),
		"second-invasion ships accept a real direct attack order instead of forcing the fire ritual")
	_check(await _wait_damaged(fire_target, 1800), "second-invasion direct order damages the linked official fleet")
	_check(await _wait_for(func(): return l.stage == "fire_direct", 300),
		"breaking the linked fleet before ignition opens direct naval combat without a task button")
	_check(_story_state(b, "gao_fire") == "missed", "direct second battle forfeits only the fire story goal")
	_resolve_effective(l.enemy_fleet)
	_check(await _wait_for(func(): return l.stage == "land_ambush", 600),
		"direct second naval victory still opens the real land-defense section")
	var lin = b.find_unit("lin_chong")
	_check(_player_move(b, [lin], Vector2i(23, 22)),
		"the player can move a land unit to the mountain-road defense marker")
	_check(await _wait_for(func(): return l.land_started and not l.land_enemies.is_empty(), 1800),
		"manual land movement starts the finite shore battle without a task button")
	var land_target = l.land_enemies[0]
	var land_force: Array = _living_player_units(b).filter(func(u): return u.movement_profile == "land")
	_check(_player_attack(b, land_force, land_target),
		"land defenders receive a real focus-attack order against the advancing army")
	_check(await _wait_damaged(land_target, 1200), "the land order reaches real combat contact")
	_resolve_effective(l.land_enemies)
	_check(await _wait_for(func(): return l.stage == "final_fleet", 600),
		"shore victory reaches the third invasion with the core still playable")
	_check(not l.lure_started and not l.final_direct and not b.mission.has_event("action:final_fleet:sortie"),
		"earlier land movement cannot leak into the fresh third-invasion water actions")
	var escort = l.enemy_fleet[-1]
	var sortie_ship = b.find_unit("ruan_xiaoqi_boat")
	# The sortie action occupies (41,35). An immediate focus attack from that
	# exact point must remain combat intent and must not be swallowed by Mission.tick.
	sortie_ship.position = b.map.cell_to_world(Vector2i(41, 35))
	_check(_player_attack(b, l.fleet, escort),
		"third-invasion ships receive a real direct attack order before the sortie")
	_check(await _wait_damaged(escort, 1800), "third-invasion direct attack reaches an escort")
	_check(await _wait_for(func(): return l.final_direct, 300),
		"early third-invasion contact starts the direct flagship battle without a task button")
	_check(not b.mission.has_event("action:final_fleet:sortie"),
		"manual attack on the fleet is not misread as the authored sortie action")
	_check(_player_attack(b, l.fleet, l.flagship),
		"the selected fleet can explicitly focus Gao Qiu's flagship")
	_check(await _wait_damaged(l.flagship, 2400), "the direct fleet really damages Gao Qiu's flagship")
	if is_instance_valid(l.flagship) and l.flagship.story_outcome == "":
		l.flagship.resolve_story("subdued")
		boundary_resolutions += 1
	_check(await _wait_for(func(): return b.phase == b.Phase.END, 300),
		"repelling the flagship grants core victory without a capture-route soft lock")
	var result: Dictionary = b.mission.result_snapshot(true)
	_check(bool(result.get("core_cleared", false)) and _story_state(b, "gao_capture") == "missed",
		"finale direct victory is a base clear and does not falsely claim Gao Qiu's capture")
	var final_event_count := int(b.mission.events.has("flagship_repelled")) + int(b.mission.events.has("flagship_sunk_direct"))
	l.process(b, 0.1)
	l.process(b, 0.1)
	_check(final_event_count == 1 and l.final_direct_victory,
		"repeated finale processing cannot settle the flagship or campaign twice")
	evidence.append({"level":"level5", "events":b.mission.events.keys(), "result":result,
		"manual_route":"attack before lure -> attack before fire -> move land defense -> attack before sortie -> focus flagship"})
	await _dispose(b)


func _write_report(save_unchanged: bool) -> void:
	var absolute := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	var result := {
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"levels": ["level3", "level4", "level8", "level5"],
		"player_move_orders": player_move_orders,
		"player_attack_orders": player_attack_orders,
		"request_action_calls_from_test": 0,
		"boundary_resolutions_after_real_contact": boundary_resolutions,
		"campaign_save_unchanged": save_unchanged,
		"evidence": evidence,
		"scope": "Production select/right-click orders and real frame progression prove free-route entry, combat contact, core settlement, missed story goals, repeat guards and no soft lock. Cross-day entry and post-contact finite-force settlement are labelled test boundaries; this is not human-play, pacing, visual or performance acceptance."
	}
	var file := FileAccess.open(OUT_DIR + "/manual_orders_late.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ") + "\n")


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)
	var campaign = root.get_node("Campaign")
	var save_existed := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_before := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_existed else PackedByteArray()
	await _zhujiazhuang_manual()
	await _lianhuanma_manual()
	await _daming_manual()
	await _finale_manual()
	var save_exists_now := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_after := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	var save_unchanged := save_existed == save_exists_now and save_before == save_after
	_check(save_unchanged, "CAMPAIGN_QA manual-order fixture performs zero campaign-save writes")
	_check(player_move_orders >= 7 and player_attack_orders >= 9,
		"all four chapters exercise multiple real move and attack commands")
	Engine.time_scale = 1.0
	_write_report(save_unchanged)
	print("[manual-late-result] ", JSON.stringify({"passed":failures.is_empty(), "checks":checks,
		"failures":failures, "move_orders":player_move_orders, "attack_orders":player_attack_orders,
		"request_action_calls":0, "save_unchanged":save_unchanged}))
	quit(0 if failures.is_empty() else 1)
