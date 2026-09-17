extends SceneTree
## External editor host loads the actual candidate PCK. Frozen state fixtures;
## button signals test packed bindings, not physical mouse input or natural loss.
var checks: Array = []
var failures: Array = []
var languages: Array = []
var profile_proof: Dictionary = {}

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[recovery-pack] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _profile_guard() -> bool:
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	var environment := {}
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual := OS.get_environment(key).replace("\\", "/").simplify_path()
		environment[key] = actual
		safe = safe and actual.to_lower() == (profile + "/" + String(key).to_lower()).to_lower()
	var user_path := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	safe = safe and user_path.to_lower().begins_with((profile + "/appdata/").to_lower())
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	safe = safe and OS.get_environment("PCK_ART_REPORT").is_absolute_path() and OS.get_environment("PCK_ART_PACK").is_absolute_path() and OS.get_environment("PCK_ART_PACK_SHA").length() == 64
	profile_proof = {"passed": safe, "profile": profile, "environment": environment, "user_data_dir": user_path}
	return safe

func _authority(b) -> Dictionary:
	var units: Array = []
	for u in b.units:
		if is_instance_valid(u): units.append([u.get_instance_id(), u.position, u.hp, u._order_serial, u._queue.duplicate(true), u._train_queue.duplicate(true)])
	return {"gold": b.gold, "wood": b.wood, "units": units, "selection": b.selection.duplicate(), "task": b.mission.active_action_id, "events": b.mission.events.duplicate(true)}

func _run() -> void:
	if not _profile_guard():
		quit(2)
		return
	await process_frame
	Engine.time_scale = 1.0
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var campaign = root.get_node("Campaign")
	campaign.current = 2
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]: campaign.set(key, false)
	root.get_node("Settings").auto_micro_level = 0
	var localize = root.get_node("Localize")
	localize.set_language("zh_CN", false)
	var b = ResourceLoader.load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	await create_timer(0.75).timeout
	check(b.phase == b.Phase.FIGHT and b.level.id() == "level3" and b.fog, "packed chapter3 starts in FIGHT with normal fog")
	var hint = b.hud.get_node_or_null("ZhujiazhuangRecoveryHint")
	check(hint != null, "packed level hook creates recovery panel without test refresh")
	if hint != null:
		check(not hint.visible and hint.state_key == "hidden", "opening ordinary soldiers keep hint hidden")
		b.set_physics_process(false)
		b.set_process(false)
		var soldiers: Array = []
		var bar
		for u in b.units:
			if not is_instance_valid(u): continue
			u.set_physics_process(false)
			if u.faction == 0 and u.key == "barracks": bar = u
			if u.faction == 0 and u.key in hint.SOLDIERS and not u.is_hero and u.hp > 0:
				soldiers.append([u, u.hp])
				u.hp = 0 # Explicit frozen loss fixture; never claimed as combat.
		check(soldiers.size() == 4 and b.level.song.hp > 0, "fixture excludes living hero and changes four ordinary soldiers")
		hint.update_state()
		check(hint.visible and hint.state_key == "ready", "packed loss fixture displays actionable ready hint")
		check(not b.qa_resource_observer.is_valid(), "production resource observer remains a no-op")
		var original_wallet := Vector2i(b.gold, b.wood)
		check(b.spend(3, 2), "production spend succeeds with normal funds")
		b.refund(3, 2)
		check(Vector2i(b.gold, b.wood) == original_wallet, "production refund restores exactly the spent resources")
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
		var key: String = hint.MESSAGES.ready
		for locale in ["zh_CN", "zh_TW", "en", "ja"]:
			localize.set_language(locale, false)
			for i in range(3): await process_frame
			var expected: String = key if locale == "zh_CN" else catalog[key][locale]
			check(hint.message.text == expected, "packed ready translation matches shipped catalog: " + locale)
			var barracks_text: String = "查看 · 兵营" if locale == "zh_CN" else catalog["查看 · 兵营"][locale]
			var camp_text: String = "查看 · 前营" if locale == "zh_CN" else catalog["查看 · 前营"][locale]
			check(hint.barracks_button.text == barracks_text and hint.camp_button.text == camp_text, "packed locator translations match catalog: " + locale)
			check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(hint.get_global_rect()), "headless layout keeps panel inside viewport: " + locale)
			languages.append({"locale": locale, "text": hint.message.text, "barracks": hint.barracks_button.text, "camp": hint.camp_button.text})
		var before := _authority(b)
		hint.barracks_button.pressed.emit()
		check(bar != null and b.camera.position.distance_to(b.to_screen(bar.position)) < 1.0, "packed barracks signal resolves actual barracks")
		check(_authority(b) == before, "packed barracks signal preserves authority")
		hint.camp_button.pressed.emit()
		check(b.camera.position.distance_to(b.to_screen(b.level.hall.position)) < 1.0, "packed camp signal resolves actual camp")
		check(_authority(b) == before, "packed camp signal preserves authority")
		check(b.queue_train(bar, "liang_qiang", false), "packed normal production API accepts paid spear recruit")
		hint.update_state()
		check(hint.state_key == "training", "packed queue changes hint to training")
		b.cancel_train(bar, 0)
		hint.update_state()
		check(hint.state_key == "ready" and Vector2i(b.gold, b.wood) == original_wallet, "packed cancel refunds and restores ready hint")
		for soldier in soldiers: soldier[0].hp = soldier[1]
		hint.update_state()
		check(not hint.visible, "restored ordinary soldier state hides packed hint")
		for soldier in soldiers: soldier[0].hp = 0
		hint.update_state()
		b.phase = b.Phase.END
		await process_frame
		await process_frame
		check(not hint.visible, "packed END hides recovery panel without level processing")
	b.queue_free()
	await process_frame
	await process_frame
	for name in ["Sfx", "Music"]:
		var singleton = root.get_node_or_null(name)
		if singleton != null and singleton.has_method("shutdown"): singleton.shutdown()
	var report := {"schema": "recovery_pck_probe_v1", "complete": true, "passed": failures.is_empty(), "checks": checks, "failures": failures, "languages": languages, "private_profile": profile_proof, "pid": OS.get_process_id(), "pack": OS.get_environment("PCK_ART_PACK"), "pack_sha256": OS.get_environment("PCK_ART_PACK_SHA"), "scope": "Editor host mounts actual exported PCK; frozen state fixtures, production APIs and button signals. No screenshots, OS mouse, natural combat, human playtest or live Steam."}
	var output := FileAccess.open(OS.get_environment("PCK_ART_REPORT"), FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	quit(0 if failures.is_empty() else 1)
