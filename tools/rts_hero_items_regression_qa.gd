extends SceneTree
## Private, paused production Battle. Potion healing/consumption/death/recruitment
## run unmodified production code; only cooldown/approach items are test data.
const DT := 1.0 / 60.0
var checks: Array = []
var failures: Array = []
var completed: Array[String] = []
var samples: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[hero-items] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _private_ok() -> bool:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var expected := OS.get_environment("LSH_RTS_QA_PROJECT").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("LSH_RTS_QA_PROFILE").simplify_path().trim_suffix("/")
	return not expected.is_empty() and not profile.is_empty() and project == expected \
		and OS.get_user_data_dir().simplify_path().trim_suffix("/") == profile \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-") \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"

func _make_battle():
	var campaign = root.get_node("Campaign")
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(key, false)
	campaign.skirmish_ai = true
	campaign.ai_difficulty = "normal"
	campaign.victory_mode = "conquest"
	root.get_node("Settings").auto_micro_level = 0
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	if not b.has_method("gameplay_rng_fault"):
		check(false, "production Battle parses and attaches")
		return null
	b.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	b.phase = b.Phase.FIGHT
	b.hud._intro_root.hide()
	b.level.on_start(b)
	check(b.units.size() > 10 and b.gameplay_rng_fault().is_empty(), "nonempty real skirmish scene starts with valid RNG")
	return b

func _count(hero, item_id := "health_potion") -> int:
	if hero.inventory == null: return 0
	var count := 0
	for item in hero.inventory.slots:
		if String(item.get("id", "")) == item_id: count += int(item.get("count", 0))
	return count

func _slot(hero, item_id := "health_potion") -> int:
	for i in range(hero.inventory.SLOT_COUNT):
		if String(hero.inventory.slot_item(i).get("id", "")) == item_id: return i
	return -1

func _spawn(b, key: String, faction := 0):
	return b.spawn_at(key, faction, b.map.nearest_open(b.level.HALL + Vector2i(8, 8)))

func _click_item(b, hero, slot: int) -> void:
	b._set_selection([hero])
	b.hud.refresh_inventory()
	var grid = b.hud._inventory_popup_grid if b.hud.touch_ui else b.hud._inventory_grid
	var button = grid.get_child(slot)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(12, 12)
	click.pressed = true
	button._gui_input(click)
	click.pressed = false
	button._gui_input(click)
	button._gui_input(click) # A duplicate release must not execute a second use.

func _birth_cases(b) -> void:
	var initial_roster: Array = b._hero_roster_keys.duplicate()
	var tested := 0
	var all_ok := true
	for key in b._defs:
		if not bool(b._defs[key].get("hero", false)) or bool(b._defs[key].get("building", false)): continue
		var u = _spawn(b, key)
		all_ok = all_ok and is_instance_valid(u) and _count(u) == 1
		tested += 1
		if is_instance_valid(u):
			b.units.erase(u)
			u.queue_free() # Dispose fixture spawns, not a death/revival under test.
	b._hero_roster_keys.assign(initial_roster)
	check(tested >= 20 and all_ok, "all available friendly hero definitions spawn with exactly one potion")
	var soldier = _spawn(b, "liang_dao")
	check(not soldier.is_hero and _count(soldier) == 0, "ordinary soldier receives no potion")
	var ally = _spawn(b, "lin_chong")
	var enemy = _spawn(b, "lin_chong", 1)
	var saved: Dictionary = ally.inventory.snapshot()
	b.hero_item_progress[ally.key] = saved.duplicate(true)
	var enemy_again = _spawn(b, "lin_chong", 1)
	check(_count(enemy) == 0 and _count(enemy_again) == 0 and b.hero_item_progress.has(ally.key) \
		and ally.inventory.snapshot() == saved, "enemy hero never receives or consumes the player's retired inventory")
	b.hero_item_progress.erase(ally.key)
	samples.append({"kind": "birth definitions", "hero_definitions": tested})
	completed.append("birth")

func _potion_cases(b, hero) -> void:
	var campaign = root.get_node("Campaign")
	# Enable the actual supported scale mode gate; no hand-edited max_hp fixture.
	campaign.skirmish = true
	campaign.scale_on = true
	for scale in [1.0, 3.0]:
		campaign.hero_mult = scale
		hero._recompute_hero_stats()
		b.hud.set_touch_ui(scale > 1.0)
		hero.inventory.add_item("health_potion", 3)
		hero.hp = 1.0
		var before_hp: float = hero.hp
		var maximum: float = hero.max_hp
		var count := _count(hero)
		_click_item(b, hero, _slot(hero))
		var expected := minf(maximum, before_hp + 200.0 + maximum * 0.2)
		check(is_equal_approx(hero.hp, expected), "real potion heals 200 + 20%% current maximum at hero scale %s" % scale)
		check(_count(hero) == count - 1, "one item click consumes exactly one potion at scale %s" % scale)
		samples.append({"kind": "potion heal", "scale": scale, "max_hp": maximum, "before": before_hp, "after": hero.hp})
		hero.hp = maximum - 1.0
		count = _count(hero)
		_click_item(b, hero, _slot(hero))
		check(is_equal_approx(hero.hp, maximum) and _count(hero) == count - 1, "near-full potion clips healing at max_hp (%s)" % scale)
		count = _count(hero)
		_click_item(b, hero, _slot(hero))
		check(_count(hero) == count and is_equal_approx(hero.hp, maximum), "full-health click consumes nothing (%s)" % scale)
	campaign.scale_on = false
	campaign.skirmish = false
	hero._recompute_hero_stats()
	b.hud.set_touch_ui(false)
	completed.append("potion")

func _revive(b, hero):
	var key: String = hero.key
	hero.take_damage(hero.max_hp * 100.0, null, false, true)
	check(hero.hp == 0.0 and not b.units.has(hero) and b.hero_item_progress.has(key), "real lethal damage retires the hero inventory")
	b.gold = 10000
	b.wood = 10000
	b.pop_cap = 999
	var hall = b.level.hall
	check(b.queue_train(hall, key, false), "dead hero enters the real paid revival queue")
	for frame in range(int(ceil(b.train_time_for(key) / DT)) + 2): hall._physics_process(DT)
	var revived = null
	for u in b.units:
		if u.key == key and u.faction == 0 and u.hp > 0.0: revived = u; break
	check(is_instance_valid(revived) and revived != hero, "building ticks finish a real hero revival")
	return revived

func _revival_cases(b, hero):
	while _count(hero) > 0: hero.inventory.consume_one(_slot(hero))
	b._items["qa_token"] = {"name": "QA token", "max_stack": 1, "stats": {"hp": 10.0}}
	hero.inventory.add_item("qa_token")
	var token_uid: int = hero.inventory.slot_item(_slot(hero, "qa_token")).uid
	hero = _revive(b, hero)
	check(_count(hero) == 1 and hero.inventory.find_uid(token_uid) >= 0, "revival restores old items then replenishes one missing potion")
	hero.inventory.add_item("health_potion", 2)
	var potion_uid: int = hero.inventory.slot_item(_slot(hero)).uid
	hero = _revive(b, hero)
	check(_count(hero) == 3 and hero.inventory.find_uid(potion_uid) >= 0, "revival preserves existing potion stack without accumulating a free bottle")
	while _count(hero) > 0: hero.inventory.consume_one(_slot(hero))
	while hero.inventory.first_empty_slot() >= 0: hero.inventory.add_item("qa_token")
	var full: Array = hero.inventory.slots.duplicate(true)
	hero = _revive(b, hero)
	check(hero.inventory.slots == full and _count(hero) == 0, "full restored inventory is never overwritten to grant a potion")
	completed.append("revival")
	return hero

func _transfer_and_cd_cases(b, donor, receiver) -> void:
	b._items["qa_shared"] = {"name": "QA shared cooldown", "max_stack": 1,
		"active": {"target": "self", "cooldown": 10.0, "cast_time": 0.0, "consume": false,
			"effect": {"target": "self", "heal": 1.0}}}
	# The donor's full restored bag is intentionally preserved by the previous case.
	while not donor.inventory.slots[0].is_empty(): donor.inventory.consume_one(0)
	while not donor.inventory.slots[1].is_empty(): donor.inventory.consume_one(1)
	donor.inventory.put_item(0, "qa_shared")
	donor.inventory.put_item(1, "qa_shared")
	b.cast_item(donor, 0)
	check(donor.inventory.cooldown_left("qa_shared") == 10.0 and not donor.inventory.ready(1), "real active-item use keeps same-name shared cooldown")
	donor.position = b.map.cell_to_world(b.map.nearest_open(b.level.HALL + Vector2i(8, 8)))
	receiver.position = donor.position + Vector2(201, 0)
	var uid: int = donor.inventory.slot_item(0).uid
	check(not b.transfer_hero_item(donor, 0, receiver) and donor.inventory.find_uid(uid) == 0, "item transfer beyond 200 is rejected without losing the item")
	receiver.position = donor.position + Vector2(200, 0)
	check(b.transfer_hero_item(donor, 0, receiver) and donor.inventory.find_uid(uid) == -1 \
		and receiver.inventory.find_uid(uid) >= 0, "item transfer at exactly 200 succeeds and preserves identity")
	check(receiver.inventory.cooldown_left("qa_shared") == 10.0 and not receiver.inventory.ready(receiver.inventory.find_uid(uid)), "transferred item retains shared cooldown")
	completed.append("transfer")

func _aim_and_roster_cases(b, hero, other) -> void:
	b.fog = false # Expose a genuine nearby threat; the cancel control must really cast Q.
	hero.position = other.position + Vector2(50, 0)
	hero.hp = hero.max_hp * 0.25
	b._grid_build()
	for slot in hero.ability_slots:
		slot.rank = maxi(1, int(slot.rank))
		slot.cd_t = 0.0
	hero.skill_points = 0
	hero.auto_micro = true
	root.get_node("Settings").auto_micro_level = 2
	b._set_selection([hero])
	b._command_hotkey(1) # Hua Rong W, the actual hotkey dispatch and targeted skill.
	check(b._ability_armed == "hua_rain" and b.hero_command_state(hero, 1).state == "aiming", "manual W enters the real armed/aiming state")
	var serial: int = hero._cast_serial
	# Expire the general grace period deliberately; armed state must remain its own gate.
	hero.manual_order_t = 0.0
	hero.manual_order_active = false
	for i in range(64):
		b._ai_tick_frame = i
		b._auto_micro_pass()
	check(b._ability_armed == "hua_rain" and hero._cast_serial == serial and not b.is_cast_pending(hero, 0), "AI never takes Q or replaces W after the manual grace timer expires")
	b.cancel_armed()
	check(not b.is_manual_aiming(hero), "explicit cancel releases armed protection")
	b._ai_tick_frame = hero.ai_tick_phase
	b._auto_micro_pass()
	check(b.is_cast_pending(hero, 0) or float(hero.ability_slots[0].cd_t) > 0.0,
		"positive control: after cancel the same AI pass really casts Q against the nearby threat")
	hero.order_stop()
	b.cancel_pending_cast(hero)
	b._command_hotkey(1)
	b._set_selection([other])
	check(b._ability_armed == "" and b._ability_caster == null, "switching active hero clears the old aimed ability")
	# Lin Chong Q is aimed; W is self-targeted. Only a ready replacement owns
	# the cursor, and W must settle through its actual production guard effect.
	other.order_stop()
	for slot in other.ability_slots:
		slot.rank = maxi(1, int(slot.rank))
		slot.cd_t = 0.0
	other.skill_points = 0
	b._command_hotkey(0)
	check(b._ability_armed == "lin_thrust" and b.is_manual_aiming(other), "Lin Q hotkey enters aimed state before replacement")
	other.ability_slots[1].cd_t = 10.0
	b._command_hotkey(1)
	check(b._ability_armed == "lin_thrust" and not b.is_cast_pending(other, 1), "blocked W keeps the existing Q aim instead of cancelling it")
	other.ability_slots[1].cd_t = 0.0
	b._command_hotkey(1)
	check(b._ability_armed.is_empty() and b._item_armed.is_empty() and not b.is_manual_aiming(other) \
		and b.is_cast_pending(other, 1), "ready W hotkey clears old Q aim before starting the real windup")
	for frame in range(60):
		other._phys_body(DT)
		b._tick_pending_casts()
	check(other._lin_guard_t > 0.0 and float(other.ability_slots[1].cd_t) > 0.0 \
		and not b.is_manual_aiming(other), "W settles its real guard effect without retaining stale manual aim")
	var slots: Array = b.hero_roster_slots()
	var hero_index := -1
	var other_index := -1
	for i in range(slots.size()):
		if slots[i].key == hero.key: hero_index = i
		if slots[i].key == other.key: other_index = i
	hero.take_damage(hero.max_hp * 100.0, null, false, true)
	var after: Array = b.hero_roster_slots()
	check(hero_index >= 0 and other_index >= 0 and after.size() == slots.size() \
		and after[hero_index].dead and after[other_index].hero == other \
		and after[other_index].hotkey == slots[other_index].hotkey, "death leaves the fixed hero shortcut slot empty instead of shifting survivors")
	b._set_selection([other])
	b._select_hero_by_index(hero_index)
	check(b.active_unit() == other, "dead hero shortcut does not select a replacement hero")
	completed.append("aim_roster")

func _approach_cancel_cases(b, caster) -> void:
	b.fog = false
	b.cancel_armed()
	caster.order_stop()
	for slot in caster.ability_slots:
		slot.rank = maxi(1, int(slot.rank))
		slot.cd_t = 0.0
	b._items["qa_approach"] = {"name": "QA approach", "max_stack": 1,
		"active": {"target": "unit", "range": 100.0, "cooldown": 10.0, "cast_time": 0.1,
			"consume": false, "effect": {"target": "unit", "heal": 1.0}}}
	var start: Vector2 = caster.position
	var retreat := start - Vector2(40, 0)
	for mode in ["ability", "item"]:
		var reasons := ["target death", "timeout", "new order"]
		if mode == "item": reasons.append_array(["freed target", "lost item", "item cooldown", "nonfinite point"])
		for reason in reasons:
			caster.order_stop()
			caster.position = start
			caster.ability_slots[0].cd_t = 0.0
			caster.inventory.cooldowns.erase("qa_approach")
			if _slot(caster, "qa_approach") < 0: caster.inventory.add_item("qa_approach")
			var item_slot := _slot(caster, "qa_approach")
			var target = _spawn(b, "liang_dao", 1)
			target.position = start + Vector2(450, 0)
			var target_hp: float = target.hp
			if mode == "ability": b._queue_walk_cast(caster, 0, target)
			else: b._queue_walk_item(caster, item_slot, target, Vector2.INF)
			var serial: int = caster._order_serial
			caster.order_move(retreat, true, 24.0)
			caster.order_move(start - Vector2(80, 0), true, 18.0)
			var intents: Array = b._walk_casts if mode == "ability" else b._walk_item_casts
			var replacement_path := PackedVector2Array()
			match reason:
				"target death": target.take_damage(target.max_hp * 100.0, null, false, true)
				"freed target":
					b.units.erase(target)
					target.free()
				"timeout": intents[0].age = 15.0
				"lost item": caster.inventory.consume_one(item_slot)
				"item cooldown": caster.inventory.start_cooldown(item_slot)
				"nonfinite point":
					intents[0].tgt = null
					intents[0].point = Vector2.INF
				"new order":
					caster.order_move(start + Vector2(0, 120), false, 27.0)
					caster.order_move(retreat, true)
					replacement_path = caster._path.duplicate()
					target.take_damage(target.max_hp * 100.0, null, false, true)
					intents[0].age = 16.0
			if mode == "ability": b._walk_cast_pass(DT)
			else: b._walk_item_cast_pass(DT)
			var empty: bool = b._walk_casts.is_empty() if mode == "ability" else b._walk_item_casts.is_empty()
			if reason == "new order":
				check(empty and caster._home == start + Vector2(0, 120) and caster._path == replacement_path \
					and caster._queue.size() == 1 and caster._group_cap == 27.0 and caster._order_serial != serial,
					"real scene %s stale dead-target intent never interferes with a newer move" % mode)
			else:
				check(empty and caster._state == caster.ST_MOVE and caster._home == retreat \
					and caster._queue.size() == 1 and caster._group_cap == 24.0 and caster._order_serial == serial \
					and caster.position == start and not b.is_cast_pending(caster, 0) \
					and not b.is_item_cast_pending(caster, item_slot),
					"real scene %s %s immediately starts queued withdrawal" % [mode, reason])
			if is_instance_valid(target) and target.hp > 0.0:
				check(target.hp == target_hp, "cancelled %s %s does not apply an effect" % [mode, reason])
				b.units.erase(target)
				target.queue_free()
	caster.order_stop()
	caster.position = start
	caster.inventory.cooldowns.erase("qa_approach")
	completed.append("approach_cancel")

func _touch_and_menu_cases(b) -> void:
	b._touch_mode = true
	b.camera.touch_mode = true
	b.hud.set_touch_ui(true)
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	b._unhandled_input(motion)
	check(b._touch_mode and b.camera.touch_mode, "emulated mouse retains touch control mode")
	motion.device = 0
	b._unhandled_input(motion)
	check(not b._touch_mode and not b.camera.touch_mode, "real mouse exits touch control mode in Battle and camera")
	var hall = b.level.hall
	b.gold = 10000
	b.wood = 10000
	b.pop_cap = 999
	var before: Dictionary = b.population_summary()
	check(b.queue_train(hall, "lou_luo", false), "population fixture creates a genuine paid production queue")
	var pop: Dictionary = b.population_summary()
	b.hud._refresh_resource_values()
	check(pop.active == before.active and pop.queued == before.queued + 1 \
		and b.hud._res_pop.text.contains("+%d" % pop.queued), "population HUD separates alive population from reserved queued population")
	b.cancel_train(hall, 0)
	var bar = _spawn(b, "barracks")
	b.current_age = 1
	var locked := {}
	for entry in b.train_menu(bar):
		if int(entry.get("min_age", 1)) > 1: locked = entry; break
	check(not locked.is_empty() and not locked.affordable and not String(locked.blocked).is_empty(), "production menu exposes an age-locked unit with its reason")
	if not locked.is_empty():
		for next_age in range(2, int(locked.min_age) + 1):
			var key := "tech_age%d" % next_age
			check(b.queue_research(hall, key, false), "menu unlock uses genuine paid research " + key)
			var duration: float = hall._research_t
			for frame in range(int(ceil(duration / DT)) + 2): hall._physics_process(DT)
			check(b.current_age == next_age, "building ticks complete research before unlock " + key)
		var unlocked := false
		for entry in b.train_menu(bar):
			if entry.get("key", "") == locked.key: unlocked = entry.affordable and String(entry.blocked).is_empty()
		check(unlocked, "same production menu entry becomes available at its required age")
	completed.append("touch_menu")

func _run() -> void:
	print("[hero-items] project=", ProjectSettings.globalize_path("res://"), " profile=", OS.get_user_data_dir())
	if not _private_ok():
		push_error("PRIVATE_RTS_HERO_ITEMS_QA_REQUIRED")
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	var b = await _make_battle()
	if b == null: quit(3); return
	_birth_cases(b)
	await process_frame
	var hero = null
	for u in b.units:
		if u.key == "lin_chong" and u.faction == 0: hero = u; break
	check(is_instance_valid(hero), "player test hero exists")
	_potion_cases(b, hero)
	hero = _revival_cases(b, hero)
	var hua = _spawn(b, "hua_rong")
	_transfer_and_cd_cases(b, hero, hua)
	_approach_cancel_cases(b, hero)
	_aim_and_roster_cases(b, hua, hero)
	_touch_and_menu_cases(b)
	check(completed.size() == 7 and checks.size() >= 50 and samples.size() >= 3 \
		and b.gameplay_rng_fault().is_empty(), "all runtime suites completed with nonempty evidence and no RNG fault")
	current_scene = null
	b.queue_free()
	await process_frame
	await process_frame
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "samples": samples,
		"profile": OS.get_user_data_dir(), "scope": "Paused real skirmish scene; real potion effects, revival, input, and approach cancellation; custom cooldown/approach items"}
	var out := OS.get_environment("LSH_RTS_QA_OUT")
	if not out.is_empty():
		var file := FileAccess.open(out.path_join("hero-items-result.json"), FileAccess.WRITE)
		if file == null: check(false, "write hero item report")
		else: file.store_string(JSON.stringify(report, "\t"))
	print("[hero-items-result] " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
