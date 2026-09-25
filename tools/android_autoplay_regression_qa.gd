extends SceneTree
## Real Battle/HUD regression, never run against a checkout or player profile.
## Button signals test production callbacks, not Android's physical input stack.
const HERO_KEYS := ["song_jiang", "hua_rong", "lin_chong", "gongsun_sheng", "li_kui", "wu_song"]
var checks: Array = []
var failures: Array = []
var samples: Array = []
var completed: Array[String] = []
var battle = null
var heroes: Array = []
var soldier = null
var finished := false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[android-autoplay] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _private_ok() -> bool:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var expected := OS.get_environment("LSH_RTS_QA_PROJECT").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("LSH_RTS_QA_PROFILE").simplify_path().trim_suffix("/")
	var output := OS.get_environment("LSH_RTS_QA_OUT").simplify_path().trim_suffix("/")
	return expected.is_absolute_path() and profile.is_absolute_path() and output.is_absolute_path() \
		and project == expected and output != project and not output.begins_with(project + "/") \
		and OS.get_user_data_dir().simplify_path().trim_suffix("/") == profile \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-rts-") \
		and FileAccess.file_exists("res://override.cfg") \
		and not FileAccess.file_exists("res://.git") and not DirAccess.dir_exists_absolute(project.path_join(".git")) \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"

func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children(): _freeze(child)

func _make_battle() -> bool:
	var campaign = root.get_node("Campaign")
	for key in ["skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(key, false)
	campaign.skirmish = true
	campaign.current = 0
	campaign.defense_waves = 30
	campaign.defense_hero_cap = 6
	campaign.defense_random = false
	campaign.enemy_mult = 1.0
	campaign.hero_mult = 1.0
	campaign.hero_mult_touched = false
	var settings = root.get_node("Settings")
	settings.auto_micro_level = 0
	settings.edge_scroll = false
	settings.reset_keybinds()
	root.size = Vector2i(1280, 720)
	battle = load("res://scenes/main.tscn").instantiate()
	if not battle.has_method("set_heroes_managed"):
		check(false, "production Battle exposes shared hero-management transition")
		return false
	var provider: Script = load("res://scripts/run_content_identity.gd")
	var configured: Dictionary = battle.configure_new_gameplay_rng(provider.new().resolve_runtime_identity(), 5088120)
	check(configured.get("ok", false), "fixed fixture seed uses production new-game RNG API")
	if not configured.get("ok", false): return false
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(battle)
	current_scene = battle
	_freeze(battle)
	check(battle.hud != null and battle.gameplay_rng_fault().is_empty(), "real defense Battle/HUD starts without RNG fault")
	if battle.hud == null or not battle.gameplay_rng_fault().is_empty(): return false
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle._on_start_battle()
	battle.hud.set_touch_ui(true)
	for unit in battle.units:
		if unit.key == "liang_dao":
			soldier = unit
			break
	return is_instance_valid(soldier)

func _flags() -> Array:
	return heroes.map(func(hero): return bool(hero.auto_micro))

func _configure(level: int, enabled := false) -> void:
	root.get_node("Settings").auto_micro_level = level
	root.get_node("Campaign").ai_friendly = level == 3
	battle.ai_friendly = level == 3
	battle._autocam_enabled = level == 3
	for hero in heroes:
		hero.auto_micro = enabled
		hero.skill_points = 0
		hero.manual_order_active = true # Bound fixture: AI passes cannot start combat or emit skill messages.
		hero.manual_order_t = 50.0
		hero.clear_mission_order_intent()
	battle.hud._refresh_touch_controls()

func _select(members: Array, active = null) -> void:
	battle._set_selection(members)
	if active != null: battle._active = active
	battle.hud._refresh_touch_controls()

func _advance_ai() -> void:
	for tick in range(40):
		battle._ai_tick_frame += 1
		battle._auto_micro_pass()
		battle.hud._refresh_touch_controls()

func _clear_messages() -> void:
	battle.hud._message_log.clear()
	battle.hud._info_unread = 0
	battle.hud._clear_info_toasts()
	battle.hud._refresh_info_log()
	battle.hud._update_info_toggle()

func _messages() -> Dictionary:
	return {"rows": battle.hud._message_log.duplicate(true), "unread": battle.hud._info_unread}

func _manual(hero) -> Array:
	return [hero.manual_order_active, hero.manual_order_t, hero.mission_order_active,
		hero.mission_order_arrival_t, hero.mission_order_target, hero.mission_order_token, hero.stance]

func _stamp_manual(hero) -> void:
	hero.manual_order_active = true
	hero.manual_order_t = 7.0
	hero.mission_order_active = true
	hero.mission_order_arrival_t = 2.0
	hero.mission_order_target = hero.position + Vector2(80, 30)
	hero.mission_order_token = 83
	hero.stance = hero.STANCE_HOLD

func _natural_rail_sample(expected: int) -> void:
	battle.hud._process(0.25)
	_freeze(battle)
	for frame in range(5): await process_frame
	var audit_script: Script = load("res://tools/rts_touch_layout_qa.gd")
	var result: Dictionary = audit_script.new().audit(battle.hud)
	var observed := 0
	for entry in result.checks:
		if String(entry.name).begins_with("fps_") or entry.name == "rail_quarter_safe_width":
			check(bool(entry.ok), "natural %d-hero rail: %s %s" % [expected, entry.name, entry.detail])
			observed += 1
	check(observed >= 5 and battle.liang_heroes().size() == expected \
		and battle.hud._skill_rail.get_child_count() == expected, "natural %d-hero rail fixture and FPS contract are nonempty" % expected)
	samples.append({"kind": "natural_hero_arrival_fps", "heroes": expected, "geometry": result.geometry})

func _spawn_heroes_and_check_fps() -> void:
	check(battle.liang_heroes().is_empty(), "defense naturally starts before the first hero is trained")
	await _natural_rail_sample(0)
	for index in range(HERO_KEYS.size()):
		var cell: Vector2i = battle.map.nearest_open(Vector2i(22 + index % 3 * 2, 35 + index / 3 * 2))
		var hero = battle.spawn_at(HERO_KEYS[index], 0, cell)
		check(hero != null, "spawn real fixture hero " + HERO_KEYS[index])
		if hero == null: return
		heroes.append(hero)
		if heroes.size() == 1: await _natural_rail_sample(1)
	await _natural_rail_sample(6)
	battle._grid_build()
	completed.append("natural_fps")

func _api_cases() -> void:
	_configure(2)
	var foreign = load("res://scripts/unit.gd").new()
	foreign.is_hero = true
	foreign.faction = 0
	foreign.hp = 100.0
	heroes[4].faction = 1
	var saved_hp: float = heroes[5].hp
	heroes[5].hp = 0.0
	var result: Dictionary = battle.set_heroes_managed([heroes[0], heroes[0], soldier, foreign, heroes[4], heroes[5], null], true)
	check(result.get("changed") == 1 and not result.get("exited_full_auto", true), "shared API deduplicates heroes and rejects enemy/dead/nonhero/foreign/null targets")
	check(heroes[0].auto_micro and not heroes[4].auto_micro and not heroes[5].auto_micro and not foreign.auto_micro,
		"invalid and cross-Battle objects are not modified")
	heroes[4].faction = 0
	heroes[5].hp = saved_hp
	foreign.free()
	_configure(2)
	heroes[0].auto_micro = true
	_stamp_manual(heroes[0])
	_stamp_manual(heroes[1])
	var already_on := _manual(heroes[0])
	result = battle.set_heroes_managed([heroes[0], heroes[1]], true)
	check(result.get("changed") == 1 and _manual(heroes[0]) == already_on, "enabling a mixed group preserves already-managed hero's manual intent and stance")
	check(heroes[1].auto_micro and not heroes[1].manual_order_active and heroes[1].manual_order_t == 0.0 \
		and not heroes[1].mission_order_active, "only newly enabled hero clears manual intent")
	_stamp_manual(heroes[1])
	var newly_on := _manual(heroes[1])
	result = battle.set_heroes_managed([heroes[0], heroes[1]], false)
	check(result.get("changed") == 2 and _manual(heroes[0]) == already_on and _manual(heroes[1]) == newly_on,
		"disabling management preserves both heroes' manual orders")
	var messages := _messages()
	result = battle.set_heroes_managed([heroes[0], heroes[1]], false)
	check(result.get("changed") == 0 and _messages() == messages, "repeating an explicit disable is an idempotent no-op without message growth")
	_configure(3, true)
	result = battle.set_heroes_managed([], false)
	check(result.get("changed") == 0 and not result.get("exited_full_auto", true) \
		and root.get_node("Settings").auto_micro_level == 3, "empty targets do not leave full-auto mode")
	result = battle.set_heroes_managed([soldier, null], false)
	check(result.get("changed") == 0 and root.get_node("Settings").auto_micro_level == 3,
		"nonhero-only targets do not leave full-auto mode")
	completed.append("api")

func _disabled_and_partial_cases() -> void:
	var localize = root.get_node("Localize")
	_configure(0)
	_select([heroes[0]])
	_clear_messages()
	check(not battle.hud._act_auto.visible and not battle.hud._act_allauto.visible, "level zero hides both management buttons")
	var result: Dictionary = battle.set_heroes_managed([heroes[0]], true)
	battle.hud._act_auto.pressed.emit()
	battle.hud._act_allauto.pressed.emit()
	check(result.get("changed") == 0 and not _flags().has(true) and root.get_node("Settings").auto_micro_level == 0,
		"level zero API and hidden-button callbacks cannot enable management")
	check(battle.hud._message_log.is_empty(), "level zero no-op callbacks do not claim successful management")
	heroes[0].auto_micro = true
	_advance_ai()
	check(not heroes[0].auto_micro, "level zero AI pass clears stale per-hero management")
	check(battle.hud._act_auto.get_signal_connection_list("pressed").size() == 1 \
		and battle.hud._act_allauto.get_signal_connection_list("pressed").size() == 1,
		"repeated HUD refresh keeps exactly one gameplay callback per management button")
	for level in [1, 2]:
		_configure(level)
		heroes[1].auto_micro = true
		_select([heroes[0], heroes[1]], heroes[0])
		check(battle.hud._act_auto.visible and battle.hud._act_auto.text == localize.text("🪄托管"), "level %d mixed selection advertises enable" % level)
		battle.hud._act_auto.pressed.emit()
		battle.hud._refresh_touch_controls()
		check(heroes[0].auto_micro and heroes[1].auto_micro and not heroes[2].auto_micro,
			"level %d mixed click enables selected heroes only" % level)
		check(root.get_node("Settings").auto_micro_level == level and battle.hud._act_auto.text == localize.text("🚫取消托管"),
			"level %d stays selected and label follows all-on group" % level)
		_select([heroes[0], heroes[1], soldier], soldier)
		check(battle.hud._act_auto.visible, "level %d hero-management button remains visible when active subgroup is a soldier" % level)
		battle.hud._act_auto.pressed.emit()
		check(not heroes[0].auto_micro and not heroes[1].auto_micro and not soldier.auto_micro,
			"level %d all-on mixed army click disables heroes without managing soldier" % level)
	completed.append("levels_0_1_2")

func _full_auto_cases() -> void:
	var settings = root.get_node("Settings")
	_configure(3, true)
	_select([heroes[0]])
	_clear_messages()
	battle.hud._act_auto.pressed.emit()
	check(settings.auto_micro_level == 2 and not battle._full_auto() and not battle._autocam_enabled,
		"selected cancellation explicitly exits full economy/camera automation to level two")
	check(not heroes[0].auto_micro and _flags().slice(1).all(func(value): return value),
		"selected cancellation preserves all unselected heroes' management flags")
	var messages := _messages()
	_advance_ai()
	check(not heroes[0].auto_micro and _messages() == messages, "forty AI passes cannot reenable selected cancellation or repeat its status messages")
	_configure(3, true)
	_clear_messages()
	battle.hud._act_allauto.pressed.emit()
	check(settings.auto_micro_level == 2 and not _flags().has(true) and not battle._autocam_enabled,
		"all-army cancellation exits full-auto and disables every hero")
	messages = _messages()
	check(not messages.rows.is_empty() and messages.rows.all(func(row): return int(row.count) == 1),
		"one cancellation emits status messages once, without a misleading repeated-count suffix")
	_advance_ai()
	check(not _flags().has(true) and _messages() == messages, "all-army cancellation remains off with stable message/unread counters")
	battle.hud._act_allauto.pressed.emit()
	check(_flags().all(func(value): return value) and settings.auto_micro_level == 2 and not battle._full_auto() \
		and not battle._autocam_enabled, "next enable button enables heroes only; it does not silently restore level-three economy/camera AI")
	for hero in heroes: hero.manual_order_active = true
	messages = _messages()
	_advance_ai()
	check(_messages() == messages and settings.auto_micro_level == 2, "enabled strong management does not independently increment button messages")
	battle.hud._act_allauto.pressed.emit()
	check(not _flags().has(true), "third all-army click cancels normally at level two")
	samples.append({"kind": "full_auto_click_sequence", "final_level": settings.auto_micro_level, "flags": _flags(), "messages": _messages()})
	for hero in heroes: hero.manual_order_active = true
	settings.auto_micro_level = 3
	_advance_ai()
	check(_flags().all(func(value): return value) and battle._full_auto(),
		"explicitly reselecting full-auto in settings still reenables its global policy")
	completed.append("full_auto")

func _keyboard_cases() -> void:
	var settings = root.get_node("Settings")
	_configure(2)
	heroes[1].auto_micro = true
	_select([heroes[0], heroes[1]])
	var event := InputEventKey.new()
	event.keycode = settings.key_for("auto")
	event.physical_keycode = event.keycode
	event.pressed = true
	battle._unhandled_input(event)
	check(heroes[0].auto_micro and heroes[1].auto_micro, "desktop T uses the same enable-mixed-selection rule")
	var messages := _messages()
	event.echo = true
	battle._unhandled_input(event)
	check(heroes[0].auto_micro and heroes[1].auto_micro and _messages() == messages, "keyboard echo cannot retrigger management")
	_configure(3, true)
	event.echo = false
	event.shift_pressed = true
	battle._unhandled_input(event)
	check(settings.auto_micro_level == 2 and not _flags().has(true), "desktop Shift+T exits full-auto through the shared transition")
	completed.append("keyboard")

func _finish() -> void:
	if finished: return
	finished = true
	check(completed.size() == 5 and samples.size() >= 4 and checks.size() >= 45, "all required autoplay/FPS suites completed with nonempty evidence")
	if is_instance_valid(battle):
		check(battle.gameplay_rng_fault().is_empty(), "no gameplay RNG fault after regression cases")
		current_scene = null
		battle.free()
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"samples": samples, "completed": completed, "physical_android_input": false,
		"profile": OS.get_user_data_dir(), "scope": "Production callbacks, API state transitions and natural 0/1/6-hero FPS layout; no device FPS claim"}
	var file := FileAccess.open(OS.get_environment("LSH_RTS_QA_OUT").path_join("android-autoplay-result.json"), FileAccess.WRITE)
	if file == null:
		push_error("ANDROID_AUTOPLAY_REPORT_WRITE_FAILED")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[android-autoplay-result] " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	if not _private_ok():
		push_error("PRIVATE_LSH_RTS_ANDROID_AUTOPLAY_QA_REQUIRED")
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	if not _make_battle():
		check(false, "real fixture creation completed")
		_finish()
		return
	await _spawn_heroes_and_check_fps()
	if heroes.size() == 6:
		_api_cases()
		_disabled_and_partial_cases()
		_full_auto_cases()
		_keyboard_cases()
	_finish()
