extends SceneTree
## Real production Battle/HUD + codex, frozen campaign with private profile.
const CA = preload("res://scripts/campaign_art.gd")
const NEW_HEROES := ["wu_yong", "hua_rong", "yang_zhi", "li_kui", "lu_junyi", "guan_sheng", "qin_ming", "hu_yanzhuo"]
var checks: Array = []
var output := ""

func _init() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok: print("FAIL: ", label)

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func run() -> void:
	output = OS.get_environment("HERO_PORTRAITS_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("ART_QA_PROFILE").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var art = root.get_node("Art")
	var heroes: Array = NEW_HEROES.duplicate()
	var manifest_path := OS.get_environment("HERO_PORTRAITS_MANIFEST")
	if not manifest_path.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		for key in manifest.portraits:
			if not key in heroes: heroes.append(key)
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(mode, false)
	campaign.current = 0
	root.get_node("Settings").auto_micro_level = 0
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	b.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	b.phase = b.Phase.FIGHT
	b.hud._intro_root.hide()
	b.hud.hide_deploy()
	b.level.on_start(b)
	check(b.units.size() > 10, "real Huangnigang battle loaded")
	var codex = load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	await process_frame
	var portraits := {}
	for key in heroes:
		codex._select(key)
		var tex: Texture2D = art.ui_portrait_texture(key)
		check(tex != null and codex._port.frames.size() == 1 and codex._port.frames[0] == tex, key + " real codex uses common portrait")
		if tex != null: portraits[key] = FileAccess.get_sha256(tex.resource_path)
	var distinct: Array = []
	for value in portraits.values():
		if not value in distinct: distinct.append(value)
	check(distinct.size() == heroes.size(), "all reviewed heroes have distinct source images")
	codex.queue_free()
	await process_frame
	var pairs := CA.PORTRAIT_OWNERS.duplicate()
	pairs.merge(CA.PROGRAMMATIC_BOUND_VARIANTS)
	for variant in CA.ANIMATED_VARIANTS:
		check(variant.begins_with("town_") or pairs.has(variant), "named campaign variant has identity owner: " + variant)
	for variant in pairs:
		var key: String = pairs[variant]
		var expected: Texture2D = art.portrait_texture(key)
		check(expected != null and art.ui_portrait_texture(key, variant) == expected, key + "/" + variant + " canonical identity")
		var wrong := "hua_rong" if key != "hua_rong" else "wu_yong"
		check(art.ui_portrait_texture(wrong, variant) == null, variant + " rejects wrong person")
		if not b._defs.has(key):
			check(false, "campaign has definition " + key)
			continue
		var unit = b.spawn_at(key, 0, Vector2i(20, 20))
		if unit == null:
			check(false, "spawn UI fixture " + key)
			continue
		unit.art_variant = variant
		b._set_selection([unit])
		b.hud._refresh_panel()
		check(b.hud._port_tex.visible and b.hud._port_tex.texture == expected, "real bottom-left HUD " + variant)
		unit.art_variant = "hn_wu_yong" if key != "wu_yong" else "li_kui_jiangzhou"
		b.hud._refresh_panel()
		check(not b.hud._port_tex.visible, "real HUD hides wrong identity " + variant)
		unit.art_variant = variant
		b.hud._refresh_panel()
		if variant in ["hn_wu_yong", "li_kui_jiangzhou", "lin_chong_prisoner", "daming_bound_lu_junyi", "bound_qin_ming"]:
			await snap("hud_" + variant)
		b._set_selection([])
		unit.queue_free()
		await process_frame
	for key in heroes:
		var unit = b.spawn_at(key, 0, Vector2i(20, 20))
		b._set_selection([unit])
		b.hud._refresh_panel()
		check(b.hud._port_tex.visible and b.hud._port_tex.texture == art.portrait_texture(key), "real standard HUD " + key)
		await snap("hud_" + key)
		b._set_selection([])
		unit.queue_free()
		await process_frame
	check(art.ui_portrait_texture("lin_chong_bound", "lin_chong_bound") == art.portrait_texture("lin_chong"), "captive key retains Lin Chong identity")
	check(art.ui_portrait_texture("scaffold", "jiangzhou_scaffold") == art.avatar_texture("scaffold", "jiangzhou_scaffold"), "scaffold icon retained")
	check(art.ui_portrait_texture("hall") == art.avatar_texture("hall"), "building icon retained")
	for variant in ["town_vendor", "town_porter", "town_woman", "town_elder"]:
		check(art.ui_portrait_texture("villager", variant) == art.avatar_texture("villager", variant), "town identity retained " + variant)
	for pair in [["wu_yong", "hn_wu_yong"], ["li_kui", "li_kui_jiangzhou"], ["lu_junyi", "daming_bound_lu_junyi"]]:
		var raw: Texture2D = art.avatar_texture(pair[0], pair[1])
		check(raw != null and raw.resource_path == CA.still_path(pair[1]), "campaign source preview retained " + pair[1])
		var frames: Array = art.unit_anim_frames(pair[0], "idle", "se", pair[1])
		check(not frames.is_empty(), "campaign world idle retained " + pair[1])
	b.queue_free()
	await process_frame
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(output.path_join("ui_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Frozen production Battle/HUD UI fixtures and actual codex; named variant ownership, distinct portrait bytes, retained town/object/source-preview/world-idle routes. No combat, mobile or release acceptance."}, "\t") + "\n")
	file.close()
	quit(0 if passed else 1)
