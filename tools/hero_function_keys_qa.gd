extends SceneTree
## Real production input/settings/HUD regression. Run only in a frozen project
## prepared by run_rts_refinement_qa.py --prepare-only, with its private profile.
## No global-class/autoload compile dependency; no player data or live game writes.
const HERO_KEYS := ["song_jiang", "lin_chong", "li_kui", "gongsun_sheng",
	"hua_rong", "wu_song", "lu_junyi", "lu_zhishen"]
var checks: Array = []
var failures: Array = []
var samples: Array = []
var completed: Array[String] = []
var _finished := false
var _battle = null


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[hero-function-keys] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func _private_ok() -> bool:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var expected := OS.get_environment("LSH_RTS_QA_PROJECT").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("LSH_RTS_QA_PROFILE").simplify_path().trim_suffix("/")
	var output := OS.get_environment("LSH_RTS_QA_OUT").simplify_path().trim_suffix("/")
	return expected.is_absolute_path() and profile.is_absolute_path() and output.is_absolute_path() \
		and project == expected and not output.begins_with(project + "/") and output != project \
		and OS.get_user_data_dir().simplify_path().trim_suffix("/") == profile \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-") \
		and FileAccess.file_exists("res://override.cfg") \
		and not FileAccess.file_exists("res://.git") and not DirAccess.dir_exists_absolute(project.path_join(".git")) \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"


func _press(b, key: int, modifier := "", is_echo := false, is_pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = is_pressed
	event.echo = is_echo
	event.ctrl_pressed = modifier == "ctrl"
	event.meta_pressed = modifier == "meta"
	event.shift_pressed = modifier == "shift"
	event.alt_pressed = modifier == "alt"
	b._unhandled_input(event)


func _single(b, hero) -> bool:
	return b.selection.size() == 1 and b.selection[0] == hero and b.active_unit() == hero


func _settings_cases() -> void:
	var settings = root.get_node("Settings")
	settings.reset_keybinds()
	check(not settings.keybinds.has("select_army") and settings.key_for("select_army") == KEY_NONE,
		"default/reset has no select-army keyboard action")
	for key in range(KEY_F1, KEY_F8 + 1):
		var original: int = settings.key_for("stop")
		check(not settings.can_bind_key(key) and not settings.rebind_key("stop", key) \
			and settings.key_for("stop") == original,
			"F%d cannot be rebound over its fixed hero slot" % (key - KEY_F1 + 1))
	check(not settings.rebind_key("select_army", KEY_L), "removed select-army action cannot be rebound")
	var cfg := ConfigFile.new()
	cfg.set_value("keys", "select_army", KEY_F2)
	cfg.set_value("keys", "stop", KEY_F2)
	cfg.set_value("keys", "hold", KEY_F5)
	cfg.set_value("keys", "amove", KEY_L)
	cfg.set_value("audio", "bgm", 0.37)
	var wrote := cfg.save("user://settings.cfg") == OK
	check(wrote, "legacy-settings fixture written only in verified private profile")
	if not wrote:
		return
	settings._load()
	check(not settings.keybinds.has("select_army") and settings.key_for("select_army") == KEY_NONE,
		"real Settings._load ignores legacy F2 select-army entry")
	check(settings.key_for("stop") == KEY_S and settings.key_for("hold") == KEY_H,
		"real Settings._load restores defaults for legacy command bindings on F2/F5")
	check(settings.key_for("amove") == KEY_L and is_equal_approx(float(settings.bgm), 0.37),
		"migration retains an unrelated valid custom key and audio setting")
	# A once-valid exchange chain can collide when the F2 command returns to Q.
	# The production migration must repair that chain, not leave Q ambiguous.
	cfg = ConfigFile.new()
	cfg.set_value("keys", "select_army", KEY_SPACE)
	cfg.set_value("keys", "command_0", KEY_F2)
	cfg.set_value("keys", "alert", KEY_Q)
	cfg.set_value("keys", "stop", KEY_J)
	check(cfg.save("user://settings.cfg") == OK, "write private legacy exchange-chain fixture")
	settings._load()
	check(settings.key_for("command_0") == KEY_Q and settings.key_for("alert") == KEY_SPACE,
		"legacy F2 to Q exchange chain restores Q skill and Space alert without collision")
	check(settings.key_for("stop") == KEY_J and not settings.keybinds.has("select_army"),
		"exchange-chain migration preserves unrelated J stop and removes old army action")
	var seen_keys: Array = []
	var unique := true
	for action in settings.keybinds:
		var key: int = settings.key_for(action)
		unique = unique and key not in seen_keys and settings.can_bind_key(key)
		seen_keys.append(key)
	check(unique and seen_keys.size() >= 20, "every migrated command remains reachable on a unique allowed key")
	settings.reset_keybinds()
	check(settings.key_for("amove") == KEY_A and settings.key_for("stop") == KEY_S \
		and settings.key_for("hold") == KEY_H and not settings.keybinds.has("select_army"),
		"reset after legacy migration restores standard commands without F2 all-army")
	samples.append({"kind": "legacy_settings", "private_path": ProjectSettings.globalize_path("user://settings.cfg"),
		"ignored_action": "select_army", "restored_actions": ["stop", "hold"], "preserved_custom_amove": "L"})
	completed.append("settings_migration")


func _make_battle():
	var campaign = root.get_node("Campaign")
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(key, false)
	campaign.skirmish_ai = true
	campaign.ai_difficulty = "normal"
	campaign.victory_mode = "conquest"
	root.get_node("Settings").auto_micro_level = 0
	var b = load("res://scenes/main.tscn").instantiate()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(b)
	current_scene = b
	if not b.has_method("gameplay_rng_fault"):
		check(false, "production Battle parses and attaches")
		return null
	await process_frame
	b.phase = b.Phase.FIGHT
	b.hud._intro_root.hide()
	b.level.on_start(b)
	b.hud.set_touch_ui(false)
	check(b.units.size() > 10 and b.gameplay_rng_fault().is_empty(),
		"real paused skirmish scene starts with nonempty units and valid RNG")
	# Controlled roster fixture only: preserve real world/economy/soldier units,
	# remove any startup heroes without simulating a death for this setup step.
	b._set_selection([])
	for unit in b.liang_heroes():
		b.units.erase(unit)
		unit.queue_free()
	b._hero_roster_keys.clear()
	b.hero_progress.clear()
	return b


func _spawn_hero(b, index: int):
	return b.spawn_at(HERO_KEYS[index], 0, b.map.nearest_open(b.level.HALL + Vector2i(8 + index, 8)))


func _input_cases(b) -> Array:
	var heroes: Array = [_spawn_hero(b, 0), _spawn_hero(b, 1)]
	check(is_instance_valid(heroes[0]) and is_instance_valid(heroes[1]), "first two real hero fixtures exist")
	b._set_selection([heroes[0]])
	_press(b, KEY_F8)
	check(_single(b, heroes[0]) and b.hero_roster_slots().size() == 2,
		"F8 with an empty eighth roster slot does not select another unit")
	for i in range(2, HERO_KEYS.size()):
		heroes.append(_spawn_hero(b, i))
	var valid := heroes.size() == 8
	for hero in heroes:
		valid = valid and is_instance_valid(hero) and hero.is_hero and hero.hp > 0.0
	check(valid and b.hero_roster_slots().size() == 8, "fixture has eight distinct alive heroes in fixed slots")
	if not valid:
		return []
	var soldier = b.spawn_at("liang_dao", 0, b.map.nearest_open(b.level.HALL + Vector2i(7, 8)))
	for i in range(8):
		b._set_selection([heroes[0], heroes[7], soldier])
		_press(b, KEY_F1 + i)
		check(_single(b, heroes[i]), "real F%d input exclusively selects hero slot %d (%s)" % [i + 1, i + 1, HERO_KEYS[i]])
		samples.append({"kind": "hero_key", "key": "F%d" % (i + 1), "slot": i, "hero": HERO_KEYS[i],
			"selected_count": b.selection.size(), "active_key": b.active_unit().key if b.active_unit() != null else ""})
	b.select_all_army()
	check(b.selection.size() >= 9 and b.selection.has(soldier), "on-screen all-army action remains functional")
	_press(b, KEY_F2)
	check(_single(b, heroes[1]) and not b.selection.has(soldier), "F2 replaces all-army selection with only second hero")
	var settings = root.get_node("Settings")
	settings.keybinds["command_0"] = KEY_F2 # Defensive runtime-corruption fixture, not normal settings flow.
	b._set_selection([heroes[0]])
	_press(b, KEY_F2)
	check(_single(b, heroes[1]) and b._ability_armed.is_empty(),
		"reserved F2 hero input wins even if an abnormal runtime dictionary binds a skill to F2")
	settings.reset_keybinds()
	b._set_selection([heroes[7]])
	_press(b, KEY_F2, "", true)
	check(_single(b, heroes[7]), "echoed F2 event does not change selection")
	_press(b, KEY_F2, "", false, false)
	check(_single(b, heroes[7]), "F2 release does not change selection")
	completed.append("keyboard_mapping")
	return heroes


func _hud_cases(b, heroes: Array, after_death := false) -> void:
	# Desktop legitimately has no touch skill rail until the real mode-switch
	# entry creates it. Validate the PC avatars first, then enter touch mode.
	b.hud.set_touch_ui(false)
	b.hud._refresh_hero_bar()
	var slots: Array = b.hero_roster_slots()
	var expected_size := 8
	var suffix := " after death" if after_death else ""
	var desktop_ready: bool = slots.size() == expected_size and is_instance_valid(b.hud._hero_bar) \
		and b.hud._hero_bar.get_child_count() == expected_size and b.hud._hero_bar.visible
	check(desktop_ready, "desktop HUD and roster expose eight avatar slots" + suffix)
	if not desktop_ready:
		return
	for i in range(expected_size):
		var cap := "F%d" % (i + 1)
		var chip = b.hud._hero_bar.get_child(i)
		var expected_hero = slots[i].get("hero") if after_death else heroes[i]
		check(slots[i].hotkey == cap and chip.roster_hotkey == cap \
			and chip.roster_key == HERO_KEYS[i] and chip.hero == expected_hero,
			"actual desktop avatar %s keycap and hero match the keyboard target%s" % [cap, suffix])
	b.hud.set_touch_ui(true)
	b.hud._refresh_skill_rail()
	var touch_ready: bool = b.hud.touch_ui and is_instance_valid(b.hud._skill_rail) \
		and b.hud._skill_rail.get_child_count() == expected_size
	check(touch_ready, "real touch-mode entry creates an eight-hero skill rail" + suffix)
	if not touch_ready:
		b.hud.set_touch_ui(false)
		return
	for i in range(expected_size):
		var cap := "F%d" % (i + 1)
		var row = b.hud._skill_rail.get_child(i)
		var rail_chip = row.get_child(0) if row.get_child_count() > 0 else null
		var expected_hero = slots[i].get("hero") if after_death else heroes[i]
		check(is_instance_valid(rail_chip) and rail_chip.roster_hotkey == cap \
			and rail_chip.roster_key == HERO_KEYS[i] and rail_chip.hero == expected_hero,
			"touch avatar retains the same %s roster mapping with keyboard hints hidden%s" % [cap, suffix])
	b.hud.set_touch_ui(false)
	completed.append("hud_after_death" if after_death else "hud_mapping")


func _modifier_cases(b, heroes: Array) -> void:
	b._set_selection([heroes[7]])
	for modifier in ["ctrl", "meta"]:
		for i in range(4):
			b.camera.position = b.to_screen(heroes[i].position)
			b.camera.clamp_to_limits()
			var center: Vector2 = b.camera.view_center()
			_press(b, KEY_F1 + i, modifier)
			check(b._camera_locs.has(i + 1) and Vector2(b._camera_locs[i + 1]).is_equal_approx(center) \
				and _single(b, heroes[7]), "%s+F%d saves actual view center without selecting a hero" % [modifier, i + 1])
	for i in range(4):
		var saved: Vector2 = b._camera_locs[i + 1]
		b.camera.position = saved + Vector2(120, 80)
		_press(b, KEY_F1 + i, "shift")
		check(b.camera.position.is_equal_approx(saved) and _single(b, heroes[7]),
			"Shift+F%d recalls its camera location without selecting a hero" % (i + 1))
	# Undefined modifier combinations deliberately keep prior behavior; this
	# regression only promises the established camera shortcuts above.
	completed.append("camera_modifiers")


func _death_cases(b, heroes: Array) -> void:
	var second_key: String = heroes[1].key
	heroes[1].take_damage(heroes[1].max_hp * 100.0, null, false, true)
	var slots: Array = b.hero_roster_slots()
	check(slots.size() == 8 and slots[1].key == second_key and slots[1].dead \
		and slots[2].hero == heroes[2] and slots[7].hero == heroes[7],
		"real second-hero death retains its F2 slot and all later indices")
	b._set_selection([heroes[0]])
	_press(b, KEY_F2)
	check(_single(b, heroes[0]), "F2 on dead second hero neither selects all army nor shifts to third hero")
	for i in range(2, 8):
		_press(b, KEY_F1 + i)
		check(_single(b, heroes[i]), "F%d keeps its original hero after F2 hero dies" % (i + 1))
	_hud_cases(b, heroes, true)
	completed.append("death_stability")


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "samples": samples,
		"completed": completed, "profile": OS.get_user_data_dir(),
		"project": ProjectSettings.globalize_path("res://"),
		"scope": "Paused real skirmish; real Battle._unhandled_input, Settings._load/reset/rebind, hero death and HUD keycap nodes"}
	var out := OS.get_environment("LSH_RTS_QA_OUT")
	var file := FileAccess.open(out.path_join("hero-function-keys-result.json"), FileAccess.WRITE)
	if file == null:
		check(false, "write private hero-function-keys result")
		report.passed = false
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("[hero-function-keys-result] " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	if not _private_ok():
		push_error("PRIVATE_HERO_FUNCTION_KEYS_QA_REQUIRED")
		quit(2)
		return
	create_timer(50.0).timeout.connect(func():
		if not _finished:
			check(false, "regression completed before watchdog timeout")
			_finish())
	AudioServer.set_bus_mute(0, true)
	_settings_cases()
	_battle = await _make_battle()
	if _battle == null:
		_finish()
		return
	var heroes := _input_cases(_battle)
	if heroes.size() == 8:
		_hud_cases(_battle, heroes)
		_modifier_cases(_battle, heroes)
		_death_cases(_battle, heroes)
	check(completed.size() == 6 and checks.size() >= 75 and samples.size() == 9 \
		and _battle.gameplay_rng_fault().is_empty(), "six complete suites with nonempty evidence and no gameplay RNG fault")
	current_scene = null
	_battle.queue_free()
	await process_frame
	await process_frame
	_finish()
