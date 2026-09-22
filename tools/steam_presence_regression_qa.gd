extends SceneTree
## Production Presence/Battle/levels and repository fake. Private frozen project
## only; no native Steam SDK, player profile, network or Steamworks publication.
var checks: Array = []
var failures: Array = []
var presence
var service
var native
var battle


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[steam-presence] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


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
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1" \
		and not Engine.has_singleton("Steam")


func _bind_fake() -> void:
	# The actual production startup remains disabled in QA. Inject only the
	# documented in-memory fake after verifying the private/no-SDK boundary.
	service.native = native
	service.account = str(native.owner)
	service.available = true
	presence._bound_account = service.account
	presence._native = native
	presence.presence_ready = true


func _run() -> void:
	if not _private_ok():
		print("PRIVATE_STEAM_PRESENCE_QA_REQUIRED")
		quit(2)
		return
	service = root.get_node("SteamService")
	presence = root.get_node("SteamPresence")
	service.set_process(false)
	presence.set_process(false)
	check(service.native == null and not service.available and not presence.presence_ready,
		"ordinary private launch creates production autoloads without Steam activity")
	var campaign = root.get_node("Campaign")
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on", "defense_random"]:
		campaign.set(key, false)
	campaign.skirmish = true
	campaign.defense_waves = 30
	battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var defense = battle.level
	check(battle.gameplay_rng_fault().is_empty() and is_instance_valid(defense.hall),
		"actual defense Battle initializes without presence-triggered RNG faults")
	# Exercise the formerly crashing ordinary campaign path while Steam is off.
	battle.level = load(campaign.LEVELS[0].script).new()
	battle._update_steam_presence()
	check(service.native == null and presence._last_key.is_empty(),
		"ordinary non-Steam campaign presence event does not call SDK or read absent _wave")
	native = load("res://tools/steam_fake_api.gd").new()
	_bind_fake()
	var detached_battle = load("res://scripts/battle.gd").new()
	detached_battle._update_steam_presence()
	detached_battle._on_cloud_settings_applied()
	check(native.presence_writes == 0, "detached/deferred Battle presence safely ignores missing scene tree")
	detached_battle.free()
	presence.set_presence({"mode": "menu"})
	check(native.rich_presence.get("steam_display") == "#Status" and native.rich_presence.get("status_en") == "Main menu",
		"menu is published through the real repository fake")
	var writes: int = native.presence_writes
	presence.set_presence({"mode": "menu"})
	check(native.presence_writes == writes, "identical successful context is deduplicated")
	var localize = root.get_node("Localize")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(localize.CATALOG_PATH))
	battle._official_context = {"mode": "custom", "level_id": ""}
	for entry in campaign.LEVELS:
		battle.level = load(entry.script).new()
		battle._update_steam_presence()
		check(native.rich_presence.get("mode") == "campaign" and native.rich_presence.get("level") == entry.id \
			and not native.rich_presence.has("wave"), "campaign mode/zero-wave independent of achievement eligibility: " + entry.id)
		for locale in ["zh_CN", "zh_TW", "en", "ja"]:
			var expected_title: String = entry.title if locale == "zh_CN" else catalog[entry.title][locale]
			check(String(native.rich_presence.get("status_" + locale, "")).contains(expected_title),
				"localized campaign title " + entry.id + " " + locale)
	for locale in ["en", "ja", "zh_TW", "zh_CN"]:
		localize.set_language(locale, false)
		check(native.rich_presence.get("status") == native.rich_presence.get("status_" + locale),
			"language signal refreshes current status without new gameplay event: " + locale)
	for mode in ["scenario", "custom_defense", "arena", "ai", "defense"]:
		var paths := {"scenario": campaign.SCENARIO_SCRIPT, "custom_defense": campaign.CUSTOM_DEFENSE_SCRIPT,
			"arena": campaign.ARENA_SCRIPT, "ai": campaign.SKIRMISH_AI_SCRIPT, "defense": campaign.SKIRMISH_SCRIPT}
		battle.level = load(paths[mode]).new()
		battle._update_steam_presence()
		check(native.rich_presence.get("mode") == mode and native.rich_presence.get("status_en") != "Liangshan Heroes",
			"actual loaded mode is reachable despite custom achievement context: " + mode)
	# The real skirmish process emits the event; this test does not manually call
	# _update_steam_presence between the two waves or replace its spawn function.
	battle.level = defense
	battle._update_steam_presence()
	defense._started = true
	defense._wave_t = 0.0
	defense.process(battle, 0.01)
	check(defense._wave == 1 and native.rich_presence.get("wave") == "1" \
		and native.rich_presence.get("wave_total") == "30", "first actual wave emits and refreshes presence")
	defense._wave_t = 0.0
	defense.process(battle, 0.01)
	check(defense._wave == 2 and native.rich_presence.get("wave") == "2" \
		and String(native.rich_presence.get("status_en", "")).contains("2/30"), "second actual wave refreshes without pause/menu event")
	battle._update_steam_presence(true)
	check(native.rich_presence.get("paused") == "1" and String(native.rich_presence.get("status_en", "")).begins_with("Paused"), "pause publishes paused state")
	battle._update_steam_presence(false)
	check(native.rich_presence.get("paused") == "0", "resume clears paused state")
	var settings = root.get_node("Settings")
	var saved_settings: String = settings.cloud_text()
	var saved_phase: int = battle.phase
	var saved_speed: float = Engine.time_scale
	for fixture in [[battle.Phase.DEPLOY, false, true], [battle.Phase.FIGHT, false, true],
		[battle.Phase.INTRO, false, false], [battle.Phase.END, false, false],
		[battle.Phase.FIGHT, true, false], [battle.Phase.DEPLOY, true, false]]:
		battle.phase = fixture[0]
		paused = fixture[1]
		Engine.time_scale = 1.0
		var applied: bool = settings.apply_cloud_text("[game]\nspeed=1.2\n")
		check(applied and is_equal_approx(Engine.time_scale, 1.2 if fixture[2] else 1.0),
			"late cloud speed respects Battle phase=%d paused=%s" % [fixture[0], fixture[1]])
	paused = false
	battle.phase = saved_phase
	settings.apply_cloud_text(saved_settings)
	Engine.time_scale = saved_speed
	campaign.defense_random = true
	campaign.defense_rand_waves = 57
	var random_defense = load(campaign.SKIRMISH_SCRIPT).new()
	battle.level = random_defense
	battle._update_steam_presence()
	check(native.rich_presence.get("mode") == "defense" and random_defense._wavelist_cache.is_empty() \
		and random_defense.presence_wave_total() == 57, "random defense display remains distinct without constructing RNG waves")
	native.presence_write_ok = false
	presence.set_presence({"mode": "arena"})
	check(presence._last_key.is_empty() and presence._retry_pending and native.rich_presence.is_empty(),
		"failed native write clears partial keys and does not cache fingerprint")
	writes = native.presence_writes
	native.presence_write_ok = true
	presence._process(6.0)
	check(native.presence_writes > writes and not presence._retry_pending and native.rich_presence.get("mode") == "arena",
		"failed identical context retries without another gameplay event")
	native.presence_fail_key = "steam_display"
	writes = native.presence_writes
	presence.set_presence({"mode": "scenario"})
	check(native.presence_writes > writes + 1 and native.rich_presence.is_empty() \
		and presence._last_key.is_empty() and presence._retry_pending,
		"failure on final steam_display clears partial keys without caching success")
	native.presence_fail_key = ""
	presence._process(6.0)
	check(native.rich_presence.get("steam_display") == "#Status" and native.rich_presence.get("mode") == "scenario",
		"final-key failure retries the complete latest context")
	presence.clear_presence()
	check(native.rich_presence.is_empty() and presence._last_key.is_empty() and presence._context.is_empty(),
		"clear removes native keys, cached context and fingerprint")
	writes = native.presence_writes
	localize.set_language("ja", false)
	presence._process(6.0)
	check(native.presence_writes == writes, "language/timer after clear cannot resurrect stale state")
	presence.set_presence({"mode": "defense", "wave": 2, "wave_total": 30})
	native.owner += 1
	presence._process(1.0)
	check(not presence.presence_ready and presence._bound_account.is_empty() and presence._context.is_empty() \
		and native.rich_presence.is_empty(), "account change clears native presence and all account-bound state")
	writes = native.presence_writes
	presence.set_presence({"mode": "arena"})
	check(native.presence_writes == writes, "account mismatch does not publish into new account")
	_bind_fake()
	presence.set_presence({"mode": "menu"})
	service.available = false
	service.changed.emit()
	check(not presence.presence_ready and native.rich_presence.is_empty(), "disconnect notification clears stale presence immediately")
	var token_path := "res://tools/contracts/steam/rich_presence.vdf"
	var tokens := FileAccess.get_file_as_string(token_path) if FileAccess.file_exists(token_path) else ""
	for pair in [["english", "status_en"], ["schinese", "status_zh_CN"], ["tchinese", "status_zh_TW"], ["japanese", "status_ja"]]:
		check(tokens.contains('"' + pair[0] + '"') and tokens.contains('"#Status" "%' + pair[1] + '%"'),
			"source-controlled required Steamworks token mapping: " + pair[0])
	battle.level = defense
	battle.free()
	service.native = null
	service.available = false
	_finish()


func _finish() -> void:
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"project": ProjectSettings.globalize_path("res://"), "profile": OS.get_user_data_dir(),
		"scope": "Actual production Presence/Battle/levels with repository fake; real wave events; no native SDK, real profile or Steamworks publication"}
	var file := FileAccess.open(OS.get_environment("LSH_RTS_QA_OUT").path_join("steam-presence-result.json"), FileAccess.WRITE)
	if file == null:
		check(false, "write private presence report")
		report.passed = false
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("[steam-presence-result] " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
