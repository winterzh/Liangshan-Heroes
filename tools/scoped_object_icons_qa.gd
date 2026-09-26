extends SceneTree
const CA := preload("res://scripts/campaign_art.gd")
const EA := preload("res://scripts/campaign_environment_art.gd")
const BEFORE := "res://qa/nonperson_icons_20260927/final/routes.json"
const OBJECT_PAIRS := {"jiangzhou_scaffold": "scaffold", "bailong_temple": "tavern", "roadside_tavern": "tavern", "heyang_tavern": "signboard", "zhu_gate_native_20260906": "zhu_gate", "daming_south_gate": "zhu_gate"}
var checks: Array = []
var output := ""
var scoped_rows: Array = []

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok: print("FAIL: ", label)

func signature(tex: Texture2D) -> Dictionary:
	if tex == null: return {}
	if tex is AtlasTexture:
		return {"atlas": signature(tex.atlas), "region": [tex.region.position.x, tex.region.position.y, tex.region.size.x, tex.region.size.y], "filter_clip": tex.filter_clip}
	return {"path": tex.resource_path, "sha256": FileAccess.get_sha256(tex.resource_path), "width": tex.get_width(), "height": tex.get_height()}

func normalized(value):
	return JSON.parse_string(JSON.stringify(value))

func metadata(unit) -> Dictionary:
	var result := {}
	for key in unit.get_meta_list(): result[key] = unit.get_meta(key)
	return result

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func battle_fixture(index: int, skirmish: bool):
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]: campaign.set(mode, false)
	campaign.skirmish = skirmish
	campaign.current = index
	root.get_node("Settings").auto_micro_level = 0
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	b.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	b.phase = b.Phase.FIGHT
	b.hud._intro_root.hide()
	b.hud.hide_deploy()
	b.fog = false
	if b._fog_layer != null: b._fog_layer.hide()
	b.camera.position_smoothing_enabled = false
	return b

func inspect(b, unit, expected: Texture2D, name: String) -> void:
	var old_metadata := metadata(unit).duplicate(true)
	check(unit.ui_portrait_texture() == expected, name + " instance icon matches scoped live source")
	check(metadata(unit) == old_metadata, name + " UI lookup has no metadata side effects")
	b.center_camera_cell(b.map.world_to_cell(unit.position))
	unit.fog_visible = true
	unit.show()
	unit.queue_redraw()
	b._set_selection([unit])
	b.hud._refresh_panel()
	check(b.hud._port_tex.visible and b.hud._port_tex.texture == expected, name + " actual HUD panel uses scoped source")
	await snap(name)
	check(b.hud._sel_grid.get_child_count() == 1, name + " actual selection chip present")
	scoped_rows.append({"name": name, "key": unit.key, "variant": unit.art_variant, "level": unit._active_campaign_level_id(), "route": unit.get_meta("campaign_environment_route", ""), "icon": signature(expected)})

func _run() -> void:
	output = OS.get_environment("SCOPED_OBJECT_ICONS_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("ART_QA_PROFILE").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var art = root.get_node("Art")
	# Load after autoloads initialize; eagerly referencing the Unit class from a
	# SceneTree command script compiles its Sfx dependency before registration.
	var unit_script = load("res://scripts/unit.gd")
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BEFORE))
	var defs = load("res://scripts/defs.gd")
	for key in defs.UNITS:
		var textures := {"ui": art.ui_portrait_texture(key), "avatar": art.avatar_texture(key), "portrait": art.portrait_texture(key), "building": art.building_texture(key), "unit": art.unit_texture(key), "terrain": art.terrain_texture(key)}
		for route in textures:
			check(normalized(signature(textures[route])) == before[key][route], key + " global " + route + " unchanged")
		var shell = unit_script.new()
		shell.key = key
		shell.is_building = bool(defs.UNITS[key].get("building", false))
		shell.is_hero = bool(defs.UNITS[key].get("hero", false))
		shell.set_meta("campaign_environment_route", "heyang_wine_sign")
		check(shell.ui_portrait_texture() == textures.ui, key + " without active level retains global icon")
		shell.free()
	var pairs := CA.PORTRAIT_OWNERS.duplicate()
	pairs.merge(CA.PROGRAMMATIC_BOUND_VARIANTS)
	pairs.merge(OBJECT_PAIRS)
	for variant in pairs:
		var key: String = pairs[variant]
		var textures := {"ui": art.ui_portrait_texture(key, variant), "avatar": art.avatar_texture(key, variant), "unit": art.unit_texture(key, variant)}
		for route in textures:
			check(normalized(signature(textures[route])) == before[key + "/" + variant][route], variant + " global " + route + " unchanged")
		var shell = unit_script.new()
		shell.key = key
		shell.art_variant = variant
		check(shell.ui_portrait_texture() == textures.ui, variant + " instance retains canonical identity")
		if not CA.portrait_owner(variant).is_empty():
			shell.key = "wu_yong" if key != "wu_yong" else "hua_rong"
			check(shell.ui_portrait_texture() == null, variant + " instance rejects wrong person")
		shell.free()
	var b = await battle_fixture(6, false)
	# These world branches deliberately bypass the generic building renderer.
	for spec in [
		{"key": "lin_chong_bound", "kind": "captive"},
		{"key": "tree", "kind": "resource"},
		{"key": "arrow_tower", "kind": "tower"},
		{"key": "stockade_gate", "kind": "scene"},
	]:
		var shell = unit_script.new()
		shell.key = spec.key
		shell.battle = b
		shell.is_building = true
		shell.set_meta("campaign_environment_route", "heyang_wine_sign")
		match spec.kind:
			"captive":
				shell.is_captive = true
				check(shell.is_bound_person(), "captive guard fixture is a bound person")
			"resource": shell.is_resource = true
			"tower":
				shell.atk = 10.0
				shell.setup_def = {"build_cat": "tower"}
				check(shell._is_tower(), "tower guard fixture uses tower drawing branch")
			"scene": shell.set_meta("scene_visual_only", true)
		check(shell.ui_portrait_texture() == art.ui_portrait_texture(spec.key), spec.kind + " ignores unrelated scoped prop route")
		shell.free()
	var sign = null
	var tavern_count := 0
	for unit in b.units:
		if unit.key == "signboard": sign = unit
		if unit.key == "tavern" and unit.art_variant == "roadside_tavern":
			tavern_count += 1
			var route: String = unit.get_meta("campaign_environment_route", "")
			check(EA.object("level7", route) != null, route + " scoped source exists")
			await inspect(b, unit, unit_script.LIVE_TAVERN_FALLBACK, "level7_" + route)
	check(tavern_count == 4, "all four real roadside taverns checked")
	check(sign != null, "real Heyang sign exists")
	if sign != null:
		var expected := EA.object("level7", "heyang_wine_sign")
		check(expected != null and expected != art.ui_portrait_texture("signboard", "heyang_tavern"), "wooden sign replaces unrelated tavern icon")
		await inspect(b, sign, expected, "level7_heyang_sign")
		# Both accepted text calibration and level scope are required, just as in world drawing.
		var saved := metadata(sign).duplicate(true)
		for field in ["campaign_environment_state", "campaign_environment_route", "campaign_environment_text_surface_id"]:
			sign.set_meta(field, "invalid_qa_value")
			var untouched := metadata(sign).duplicate(true)
			check(sign.ui_portrait_texture() == art.ui_portrait_texture(sign.key, sign.art_variant), field + " invalid value falls back")
			check(metadata(sign) == untouched, field + " failed lookup does not change metadata")
			if saved.has(field): sign.set_meta(field, saved[field])
			else: sign.remove_meta(field)
		sign.set_meta("campaign_environment_route", "zhongyi_hall")
		check(sign.ui_portrait_texture() == art.ui_portrait_texture(sign.key, sign.art_variant), "level5 hall cannot leak into level7")
		for field in saved: sign.set_meta(field, saved[field])
		var hero = b.find_unit("wu_song")
		hero.set_meta("campaign_environment_route", "heyang_wine_sign")
		check(hero.ui_portrait_texture() == art.portrait_texture("wu_song"), "hero with prop metadata still uses own face")
		hero.remove_meta("campaign_environment_route")
		await inspect(b, hero, art.portrait_texture("wu_song"), "level7_wu_song_identity")
	b.queue_free()
	await process_frame
	b = await battle_fixture(4, false)
	var halls := 0
	for unit in b.units:
		if String(unit.get_meta("campaign_environment_route", "")) != "zhongyi_hall": continue
		halls += 1
		await inspect(b, unit, EA.object("level5", "zhongyi_hall"), "level5_zhongyi_hall")
	check(halls == 1, "current level5 hall checked")
	b.queue_free()
	await process_frame
	b = await battle_fixture(0, true)
	var skirmish_halls := 0
	for unit in b.units:
		if unit.key != "hall": continue
		skirmish_halls += 1
		check(unit._active_campaign_level_id() == "skirmish", "RTS has its own level scope")
		await inspect(b, unit, art.ui_portrait_texture("hall", unit.art_variant), "skirmish_hall_scope")
	check(skirmish_halls == 1, "actual RTS hall checked")
	b.queue_free()
	await process_frame
	var passed := checks.all(func(row): return row.passed)
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify({"passed": passed, "checks": checks, "scoped_instances": scoped_rows, "scope": "Global routes unchanged; instance-aware scoped object UI; real level7 taverns/sign and Wu Song, level5 hall and RTS scope guard. Runtime lettering stays in the world renderer; the HUD name identifies the prop."}, "\t") + "\n")
	quit(0 if passed else 1)
