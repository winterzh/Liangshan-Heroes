extends SceneTree
## Run only with unchanged, extracted APK resources and a unique private profile.
var checks: Array = []
var details := {}

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})

func _finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row): return bool(row.passed))
	print("[android-hot-candidate] ", JSON.stringify({"passed": passed, "checks": checks, "details": details, "native_android_tested": false}))
	quit(0 if passed else 3)

func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children(): _freeze(child)

func _has_text(node: Node, needle: String) -> bool:
	if node is Label and needle in node.text: return true
	for child in node.get_children():
		if _has_text(child, needle): return true
	return false

func _run() -> void:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var profile := OS.get_user_data_dir().simplify_path().trim_suffix("/")
	if project != OS.get_environment("LSH_HOT_PROJECT").simplify_path().trim_suffix("/") \
		or profile != OS.get_environment("LSH_HOT_PROFILE").simplify_path().trim_suffix("/") \
		or not profile.get_file().begins_with("LSH-hot-candidate-") or not FileAccess.file_exists("res://override.cfg") \
		or FileAccess.file_exists("res://.git") or DirAccess.dir_exists_absolute(project.path_join(".git")) \
		or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		_check(false, "private APK project/profile required"); _finish(); return
	var version := OS.get_environment("LSH_HOT_VERSION")
	var updater = root.get_node("AndroidUpdater")
	_check(updater.enabled and updater.platform_id == "android" and updater.architecture == "arm64", "actual APK updater enabled in private Android simulation")
	_check(updater.BASE_CONTENT_VERSION == "2.0" and updater.PACKAGE_VERSION_NAME == "2.0" \
		and updater.PACKAGE_VERSION_CODE == 16 and updater.BOOTSTRAP_VERSION == 4, "original APK version and bootstrap preserved")
	_check(not root.get_node("SteamService").available and not root.get_node("ContinueFlow").is_enabled(), "Steam and desktop continuation remain disabled")
	if OS.get_environment("LSH_HOT_MODE") == "download":
		_check(updater.active_content_version == "2.0" and updater.run_content_mount_identity().patch_sha256 == "", "download begins without an installed patch")
		updater.check_now()
		var deadline := Time.get_ticks_msec() + 40000
		while Time.get_ticks_msec() < deadline and updater.state not in ["available", "error", "current", "full_update"]: await create_timer(0.02).timeout
		_check(updater.state == "available" and updater.available_manifest.get("content_version", "") == version, "HTTP candidate offered as compatible content patch")
		if updater.state == "available":
			updater.begin_download()
			deadline = Time.get_ticks_msec() + 150000
			while Time.get_ticks_msec() < deadline and updater.state not in ["ready", "error"]: await create_timer(0.02).timeout
		_check(updater.state == "ready" and updater.active_content_version == "2.0", "real HTTP download verified and persisted; old process remains original version")
		details["download_state"] = updater.state
		_finish(); return
	var identity: Dictionary = updater.run_content_mount_identity()
	_check(identity.get("complete", false) and identity.get("patch_sha256", "") == OS.get_environment("LSH_HOT_PATCH_SHA") \
		and updater.active_content_version == version, "fresh process naturally mounts exact signed candidate SHA and version")
	var cached: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://android_updates/state.json"))
	_check(cached is Dictionary and String(cached.get("manifest", "")).sha256_text() == OS.get_environment("LSH_HOT_MANIFEST_SHA"), "installed signed manifest bytes equal verified candidate")
	if not bool(checks[-2].passed): _finish(); return
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	for frame in range(4): await process_frame
	_check(_has_text(menu, version), "actual menu displays patched content version")
	_check(root.get_node("Localize").text("已退出全托管，经济与镜头改为手动") == "Full automation off. Economy and camera are now manual.", "patched localization is active")
	menu.free()
	var helper = load("res://scripts/static_scenery_draw_batch.gd")
	_check(helper != null and helper.new().has_method("summary"), "new static batching script loads from patch")
	var campaign = root.get_node("Campaign")
	for key in ["skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]: campaign.set(key, false)
	campaign.skirmish = true; campaign.current = 0; campaign.defense_waves = 60
	campaign.defense_hero_cap = 6; campaign.defense_random = false
	root.get_node("Settings").auto_micro_level = 0
	root.size = Vector2i(1280, 853)
	var battle = load("res://scenes/main.tscn").instantiate()
	_check(battle.has_method("set_heroes_managed"), "actual Battle loads new shared management API")
	if not battle.has_method("set_heroes_managed"): battle.free(); _finish(); return
	var provider = load("res://scripts/run_content_identity.gd").new()
	var seeded: Dictionary = battle.configure_new_gameplay_rng(provider.resolve_runtime_identity(), 5088120)
	_check(seeded.get("ok", false), "patched Battle accepts isolated content-bound RNG")
	if not seeded.get("ok", false): battle.free(); _finish(); return
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(battle); current_scene = battle
	battle.hud._intro_root.hide(); battle._on_intro_done(); battle.hud.set_touch_ui(true)
	var keys := ["song_jiang", "hua_rong", "lin_chong", "gongsun_sheng", "li_kui", "wu_song"]
	for i in keys.size(): battle.spawn_at(keys[i], 0, battle.map.nearest_open(Vector2i(25 + i % 3, 33 + i / 3)))
	battle.hud._process(0.3); _freeze(battle)
	for frame in range(5): await process_frame
	var hud = battle.hud
	var rail: Rect2 = hud._skill_rail.get_global_rect()
	var fps: Rect2 = hud._fps_label.get_global_rect()
	var safe: Vector4 = hud._logical_safe_insets()
	var vp: Vector2 = hud.get_viewport().get_visible_rect().size
	_check(battle.gameplay_rng_fault().is_empty() and battle.liang_heroes().size() == 6 \
		and hud._skill_rail.get_child_count() == 6, "actual six-hero defense fixture initialized")
	_check(hud._fps_label.is_visible_in_tree() and hud._fps_label.text.begins_with("FPS ") \
		and fps.has_area() and not fps.intersects(rail), "FPS remains visible and separate from six-hero rail")
	_check(rail.has_area() and rail.size.x <= (vp.x - safe.x - safe.z) * 0.25 + 1.0, "tablet rail fits quarter of safe screen width")
	root.get_node("Settings").auto_micro_level = 3; battle.ai_friendly = true
	var heroes: Array = battle.liang_heroes()
	for hero in heroes: hero.auto_micro = true
	var cancelled: Dictionary = battle.set_heroes_managed(heroes, false)
	battle._auto_micro_pass()
	_check(cancelled.get("exited_full_auto", false) and root.get_node("Settings").auto_micro_level == 2 \
		and heroes.all(func(hero): return not hero.auto_micro), "cancel management stays off after actual AI pass")
	details = {"content_version": updater.active_content_version, "mount_identity": identity,
		"fps_rect": str(fps), "rail_rect": str(rail), "viewport": str(vp), "user_dir": profile}
	battle.free(); await process_frame
	_finish()
