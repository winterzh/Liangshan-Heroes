extends SceneTree
## External probe: use --script only with a binary whose --help advertises it.
## Actual-app mode is retained for supporting templates. Release templates may
## ignore --script; no report means the probe did not run, never a passing test.
## Explicit fallback: LSH_MAC_TEST_PACKED_HOST=1 and the macOS editor executable
## --main-pack /absolute/Test.app/Contents/Resources/Test.pck --script /absolute/this.gd.
## Host mode also requires LSH_MAC_TEST_PCK and LSH_MAC_TEST_PCK_SHA256. The launcher
## must retain its actual command receipt: Godot can consume --main-pack before
## OS.get_cmdline_args(), so this binding is explicitly launcher-supplied.
## That mode validates packaged resources on a native host, NOT the app executable.
## Required: LSH_MAC_TEST_PROFILE (exact custom profile name or absolute profile path),
## LSH_MAC_TEST_STAMP (visible menu text), LSH_MAC_TEST_QA_OUT (absolute evidence directory).
## No project-global class or autoload names are resolved at compile time.
## The actual packed menu and arena run here. This is a paused short-scene package
## smoke test, not a full match, save/continue test, or physical-input playtest.
## A 55-second watchdog leaves the invoking process runner room for a 60-second limit.

const WATCHDOG_SECONDS := 55.0
var checks: Array = []
var failures: Array = []
var evidence := {}
var screenshots := {}
var completed: Array = []
var output := ""
var expected_profile := ""
var expected_stamp := ""
var started_ms := 0
var finished := false
var graphical := false
var mode := "actual_app_binary"
var main_pack := ""

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	print("[macos-test-package] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _timeout() -> void:
	if finished: return
	check(false, "probe completed before its 55-second watchdog")
	_finish()

func _finish() -> void:
	if finished: return
	finished = true
	var report := {
		"schema": 1, "passed": failures.is_empty(), "checks": checks, "failures": failures,
		"mode": mode, "main_pack": main_pack,
		"completed": completed, "evidence": evidence, "screenshots": screenshots,
		"native_graphics": graphical, "expected_stamp": expected_stamp,
		"profile": OS.get_user_data_dir(), "expected_profile": expected_profile,
		"executable": OS.get_executable_path(), "elapsed_ms": Time.get_ticks_msec() - started_ms,
		"scope": ("Packaged resources on a native editor host, NOT the actual app binary. " if mode == "packed_resources_native_host" else "Actual app binary. ") \
			+ "Menu and paused real arena; production potion effect and consumption; not a full match or save/continue test"
	}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("macos-test-package-result.json"), FileAccess.WRITE)
		if file == null:
			failures.append("could not write JSON report")
			report.passed = false
		else:
			file.store_string(JSON.stringify(report, "\t"))
	print("[macos-test-package-result] ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _execution_mode_checks() -> void:
	var host_opt_in := OS.get_environment("LSH_MAC_TEST_PACKED_HOST")
	check(host_opt_in in ["", "1"], "packed-host mode is only enabled by explicit LSH_MAC_TEST_PACKED_HOST=1")
	if host_opt_in != "1":
		check(OS.has_feature("macos") and not OS.has_feature("editor") \
			and OS.get_executable_path().contains(".app/Contents/MacOS/"), "running the exported macOS app binary, not the editor")
		return
	mode = "packed_resources_native_host"
	check(OS.has_feature("macos") and OS.has_feature("editor"), "packed-resource host is the macOS editor-capable engine")
	var args := OS.get_cmdline_args()
	var packs: Array = []
	var source_path_override := false
	for i in range(args.size()):
		var argument: String = args[i]
		if argument == "--main-pack" and i + 1 < args.size(): packs.append(args[i + 1])
		elif argument.begins_with("--main-pack="): packs.append(argument.trim_prefix("--main-pack="))
		if argument == "--path" or argument.begins_with("--path=") or argument == "--upwards":
			source_path_override = true
	main_pack = OS.get_environment("LSH_MAC_TEST_PCK").simplify_path()
	var expected_sha := OS.get_environment("LSH_MAC_TEST_PCK_SHA256").to_lower()
	var actual_pck := not main_pack.is_empty() and main_pack.is_absolute_path() \
		and main_pack.contains(".app/Contents/Resources/") \
		and main_pack.get_base_dir().ends_with(".app/Contents/Resources") \
		and main_pack.ends_with(".pck") and FileAccess.file_exists(main_pack)
	check(actual_pck, "launcher supplies an absolute PCK path inside the actual app's Resources directory")
	var actual_sha := FileAccess.get_sha256(main_pack) if actual_pck else ""
	check(expected_sha.length() == 64 and expected_sha.is_valid_hex_number(false) and actual_sha == expected_sha,
		"launcher-supplied PCK SHA-256 exactly matches the app's actual PCK bytes")
	var visible_pack_matches := packs.is_empty() or (packs.size() == 1 and String(packs[0]).simplify_path() == main_pack)
	check(visible_pack_matches, "any runtime-visible --main-pack argument agrees with the supplied PCK binding")
	check(not source_path_override, "runtime-visible arguments contain no source-project path or upward search override")
	evidence.pack_binding = {"kind": "launcher_supplied_path_and_sha256", "path": main_pack,
		"expected_sha256": expected_sha, "actual_sha256": actual_sha,
		"runtime_main_pack_argument_visible": not packs.is_empty(), "runtime_visible_main_pack_values": packs,
		"limitation": "Godot may consume --main-pack before script execution. When absent here, the launcher command receipt binds these verified bytes to the mounted pack; this is not runtime argument proof."}
	# Exported PCKs contain project.binary, not an editable project.godot. These
	# reads use res:// (the mounted resource namespace), not the working directory.
	# The external probe is the only intentionally loose source script here.
	var packed_settings := FileAccess.file_exists("res://project.binary")
	var source_project := FileAccess.file_exists("res://project.godot")
	var source_checkout := FileAccess.file_exists("res://AGENTS.md")
	var source_probe := FileAccess.file_exists("res://tools/macos_test_package_probe.gd")
	evidence.resource_origin = {"packed_project_binary": packed_settings,
		"editable_project_visible": source_project, "source_checkout_visible": source_checkout,
		"loose_project_probe_visible": source_probe, "main_pack": main_pack,
		"resource_root": ProjectSettings.globalize_path("res://")}
	check(packed_settings and not source_project and not source_checkout and not source_probe,
		"res:// is the exported binary project, not the editable source checkout")

func _guard() -> bool:
	expected_profile = OS.get_environment("LSH_MAC_TEST_PROFILE").simplify_path().trim_suffix("/")
	expected_stamp = OS.get_environment("LSH_MAC_TEST_STAMP")
	var requested_output := OS.get_environment("LSH_MAC_TEST_QA_OUT").simplify_path()
	var valid_output := not requested_output.is_empty() and requested_output.is_absolute_path()
	if valid_output:
		valid_output = DirAccess.make_dir_recursive_absolute(requested_output) == OK
		if valid_output: output = requested_output
	check(valid_output, "absolute QA output directory is available")
	var actual := OS.get_user_data_dir().simplify_path().trim_suffix("/")
	var profile_name := expected_profile.get_file()
	var valid_name := not expected_profile.is_empty() and profile_name.begins_with("LSH-macos-test-")
	var profile_matches := valid_name and actual.get_file() == profile_name
	if expected_profile.is_absolute_path():
		profile_matches = profile_matches and actual == expected_profile
	else:
		profile_matches = profile_matches and expected_profile == profile_name
	profile_matches = profile_matches \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) == profile_name
	check(profile_matches, "user data directory exactly matches the isolated requested profile")
	check(not expected_stamp.strip_edges().is_empty(), "menu stamp expectation is nonempty")
	_execution_mode_checks()
	check(OS.has_feature("local_rts_test") and not OS.has_feature("steam"), "local test feature exists and Steam feature is absent")
	# These hooks can bypass the menu or start unrelated long-running suites.
	var unsafe_hooks: Array = []
	for key in ["SMOKE_TEST", "SCREENSHOT_DIR", "LEVEL", "SKIRMISH", "SKIRMISH_AI", "SCENARIO", "CUSTOM_DEFENSE", "PERF_BENCH", "INFO_UI_TEST", "INFO_UI_TEST_DIR"]:
		if not OS.get_environment(key).is_empty(): unsafe_hooks.append(key)
	evidence.unrelated_hooks = unsafe_hooks
	check(unsafe_hooks.is_empty(), "unrelated launch and benchmark hooks are absent")
	return failures.is_empty()

func _platform_checks() -> bool:
	var updater = root.get_node_or_null("AndroidUpdater")
	check(is_instance_valid(updater), "packed AndroidUpdater autoload exists")
	if is_instance_valid(updater):
		check(updater.get("enabled") == false and updater.get("_request") == null,
			"content updater is disabled and never created its HTTP request")
		check(updater.get("_run_identity_complete") == true,
			"disabled updater completed its content identity bootstrap")
	var steam = root.get_node_or_null("SteamService")
	check(is_instance_valid(steam), "packed SteamService autoload exists")
	if is_instance_valid(steam):
		check(steam.get("available") == false and steam.get("native") == null,
			"Steam service has no live native connection")
	return failures.is_empty()

func _find_stamp(node: Node, matches: Array) -> void:
	if node is Label and node.text.contains(expected_stamp) and node.is_visible_in_tree():
		matches.append({"path": str(node.get_path()), "text": node.text,
			"rect": str(node.get_global_rect()), "inside_viewport": node.get_global_rect().intersects(root.get_visible_rect())})
	for child in node.get_children(): _find_stamp(child, matches)

func _screenshot(name: String) -> void:
	if not graphical:
		screenshots[name] = {"saved": false, "reason": "headless: no native image was captured"}
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var valid := frame != null and not frame.is_empty() and frame.get_width() > 0 and frame.get_height() > 0
	var path := output.path_join(name + ".png")
	var saved := valid and frame.save_png(path) == OK
	screenshots[name] = {"saved": saved, "path": path,
		"width": frame.get_width() if valid else 0, "height": frame.get_height() if valid else 0}
	check(saved, "native viewport screenshot saved: " + name)

func _potion_count(hero) -> int:
	if hero.inventory == null: return 0
	var count := 0
	for item in hero.inventory.slots:
		if String(item.get("id", "")) == "health_potion": count += int(item.get("count", 0))
	return count

func _run() -> void:
	create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_timeout)
	graphical = DisplayServer.get_name() != "headless"
	if not _guard() or not _platform_checks():
		_finish()
		return
	AudioServer.set_bus_mute(0, true)
	var campaign = root.get_node_or_null("Campaign")
	var settings = root.get_node_or_null("Settings")
	check(is_instance_valid(campaign) and is_instance_valid(settings), "packed Campaign and Settings autoloads exist")
	if not is_instance_valid(campaign) or not is_instance_valid(settings):
		_finish()
		return
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(key, false)
	settings.set("auto_micro_level", 0)
	settings.set("edge_scroll", false)
	var menu_scene = load("res://scenes/menu.tscn")
	check(menu_scene is PackedScene, "actual packed menu scene loads")
	if not menu_scene is PackedScene:
		_finish()
		return
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var matches: Array = []
	_find_stamp(menu, matches)
	evidence.menu_stamp_labels = matches
	check(not matches.is_empty(), "actual menu contains the requested visible test stamp")
	check(not matches.is_empty() and bool(matches[0].inside_viewport), "test stamp intersects the native menu viewport")
	await _screenshot("macos-test-menu")
	completed.append("menu")
	current_scene = null
	menu.queue_free()
	await process_frame
	campaign.set("arena", true)
	var battle_scene = load("res://scenes/main.tscn")
	check(battle_scene is PackedScene, "actual packed battle scene loads")
	if not battle_scene is PackedScene:
		_finish()
		return
	var battle = battle_scene.instantiate()
	# Disable before readiness: production deploy still runs, but neither Battle
	# nor inheriting units advance a gameplay/AI tick while this fixture awaits UI.
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(battle)
	current_scene = battle
	var ready: bool = battle.has_method("gameplay_rng_fault") and is_instance_valid(battle.get("hud")) \
		and is_instance_valid(battle.get("level"))
	check(ready, "real arena battle attaches and initializes its HUD and level")
	if not ready:
		_finish()
		return
	check(battle.level.id() == "arena" and battle.units.size() >= 8 \
		and String(battle.gameplay_rng_fault()).is_empty(), "arena deploy is nonempty and has no gameplay RNG fault")
	battle.hud._intro_root.hide()
	battle.phase = battle.Phase.DEPLOY
	battle._on_start_battle()
	var hero = battle.spawn_at("lin_chong", 0, Vector2i(18, 25))
	check(is_instance_valid(hero) and hero.inventory != null, "real friendly Lin Chong spawns with an inventory")
	if not is_instance_valid(hero) or hero.inventory == null:
		_finish()
		return
	for unit in battle.units:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.auto_micro = false
	battle.select_single(hero, false)
	check(battle.active_unit() == hero and _potion_count(hero) == 1, "selected newly born Lin Chong has exactly one health potion")
	var slot := -1
	for i in range(hero.inventory.slots.size()):
		if String(hero.inventory.slot_item(i).get("id", "")) == "health_potion": slot = i; break
	check(slot >= 0, "birth potion occupies a real inventory slot")
	if slot < 0:
		_finish()
		return
	hero.hp = 1.0 # Only damage setup is a fixture; healing below is production cast_item.
	var maximum: float = hero.max_hp
	var before: float = hero.hp
	battle.cast_item(hero, slot)
	var expected := minf(maximum, before + 200.0 + maximum * 0.2)
	check(is_equal_approx(float(hero.hp), expected), "production cast_item heals 200 plus 20 percent of current maximum HP")
	check(_potion_count(hero) == 0, "one production item use consumes exactly the one birth potion")
	var after: float = hero.hp
	battle.cast_item(hero, slot)
	check(_potion_count(hero) == 0 and is_equal_approx(float(hero.hp), after), "reusing the now-empty slot produces no extra heal or consumption")
	evidence.potion = {"hero": hero.key, "max_hp": maximum, "before_hp": before,
		"expected_hp": expected, "after_hp": after, "count_before": 1, "count_after": _potion_count(hero)}
	battle.hud.refresh_inventory()
	battle.hud._inventory_popup_open = true
	battle.hud._layout_inventory()
	battle._grid_build()
	battle.camera.position = battle.to_screen(hero.position)
	battle.camera.clamp_to_limits()
	battle.camera.force_update_scroll()
	battle._refresh_run_capture_presentation()
	await _screenshot("macos-test-arena")
	check(battle.process_mode == Node.PROCESS_MODE_DISABLED and String(battle.gameplay_rng_fault()).is_empty(),
		"arena remains paused with no gameplay RNG fault after the item effect")
	completed.append("arena_potion")
	_platform_checks()
	check(completed.size() == 2 and checks.size() >= 20, "both real-scene suites completed with nonempty evidence")
	current_scene = null
	battle.queue_free()
	await process_frame
	_finish()
