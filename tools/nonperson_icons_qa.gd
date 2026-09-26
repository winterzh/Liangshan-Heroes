extends SceneTree
## Compare the complete UI/world routing table with a frozen pre-change run.
const CA := preload("res://scripts/campaign_art.gd")
const CHANGED := ["market", "scaffold", "zhu_gate"]
const OBJECT_PAIRS := {
	"jiangzhou_scaffold": "scaffold", "bailong_temple": "tavern",
	"roadside_tavern": "tavern", "heyang_tavern": "signboard",
	"zhu_gate_native_20260906": "zhu_gate", "daming_south_gate": "zhu_gate",
}
var checks: Array = []
var output := ""

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})

func signature(tex: Texture2D) -> Dictionary:
	if tex == null: return {}
	if tex is AtlasTexture:
		return {"atlas": signature(tex.atlas), "region": [tex.region.position.x, tex.region.position.y, tex.region.size.x, tex.region.size.y], "filter_clip": tex.filter_clip}
	return {"path": tex.resource_path, "sha256": FileAccess.get_sha256(tex.resource_path), "width": tex.get_width(), "height": tex.get_height()}

func routes(art) -> Dictionary:
	var result := {}
	for key in load("res://scripts/defs.gd").UNITS:
		result[key] = {
			"ui": signature(art.ui_portrait_texture(key)), "avatar": signature(art.avatar_texture(key)),
			"portrait": signature(art.portrait_texture(key)), "building": signature(art.building_texture(key)),
			"unit": signature(art.unit_texture(key)), "terrain": signature(art.terrain_texture(key)),
		}
	var pairs := CA.PORTRAIT_OWNERS.duplicate()
	pairs.merge(CA.PROGRAMMATIC_BOUND_VARIANTS)
	pairs.merge(OBJECT_PAIRS)
	for variant in pairs:
		var key: String = pairs[variant]
		result[key + "/" + variant] = {
			"ui": signature(art.ui_portrait_texture(key, variant)),
			"avatar": signature(art.avatar_texture(key, variant)),
			"unit": signature(art.unit_texture(key, variant)),
		}
	return result

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func expected_icon(art, key: String) -> Texture2D:
	return art.building_texture(key) if key == "market" else art.terrain_texture(key)

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

func select_and_capture(b, unit, expected: Texture2D, name: String) -> void:
	b.center_camera_cell(b.map.world_to_cell(unit.position))
	# Simulation is paused: revealing the map overlay alone leaves the enemy's
	# cached fog flag unchanged. Explicitly reveal the selected visual fixture.
	unit.fog_visible = true
	unit.show()
	unit.queue_redraw()
	b._set_selection([unit])
	b.hud._refresh_panel()
	check(b.hud._port_tex.visible and b.hud._port_tex.texture == expected, name + " real HUD uses expected texture")
	await snap(name)

func _run() -> void:
	output = OS.get_environment("NONPERSON_ICONS_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("ART_QA_PROFILE").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var art = root.get_node("Art")
	# JSON reads numbers back as floats. Compare both sides after the same
	# serialization, including sorted dictionary keys, instead of Variant types.
	var current: Dictionary = JSON.parse_string(JSON.stringify(routes(art)))
	FileAccess.open(output.path_join("routes.json"), FileAccess.WRITE).store_string(JSON.stringify(current, "\t") + "\n")
	if OS.get_environment("NONPERSON_ICONS_BASELINE") == "1":
		for key in CHANGED:
			check(current[key].ui == current.hall.ui, key + " reproduces old hall icon")
	else:
		var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NONPERSON_ICONS_BEFORE")))
		check(before.size() == current.size() and current.keys().all(func(key): return before.has(key)), "same definitions and variant identities")
		for key in current:
			for route in current[key]:
				var change: bool = key in CHANGED and route in ["ui", "avatar"]
				check((before[key][route] != current[key][route]) if change else (before[key][route] == current[key][route]), key + " " + route + (" corrected" if change else " unchanged"))
		for key in load("res://scripts/defs.gd").UNITS:
			check(art.ui_portrait_texture(key) != null, key + " UI available")
		for key in CHANGED:
			check(art.ui_portrait_texture(key) == expected_icon(art, key), key + " UI uses existing world source")
			check(not art.ART_ALIAS.has(key), key + " no stale hall alias")
		check(art.ui_portrait_texture("market", "jiangzhou_scaffold") == null, "generic variant still rejects wrong object")
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		var canvas := Control.new()
		canvas.theme = UITheme.shared()
		root.add_child(canvas)
		var bg := ColorRect.new()
		bg.size = Vector2(1280, 720)
		bg.color = Color("25271e")
		canvas.add_child(bg)
		for i in CHANGED.size():
			var key: String = CHANGED[i]
			var title := Label.new()
			title.position = Vector2(24 + i * 416, 15)
			title.text = key + "   旧 / 新 / 64 / 32"
			canvas.add_child(title)
			var specs := [[art.avatar_texture("hall"), 150, 24, 65], [expected_icon(art, key), 220, 180, 65], [expected_icon(art, key), 64, 30, 320], [expected_icon(art, key), 32, 135, 320], [expected_icon(art, key), 300, 70, 390]]
			for spec in specs:
				var box := TextureRect.new()
				box.texture = spec[0]
				box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				box.position = Vector2(i * 416 + spec[2], spec[3])
				box.size = Vector2(spec[1], spec[1])
				canvas.add_child(box)
		await snap("base_icon_comparison")
		canvas.queue_free()
		await process_frame
		var codex = load("res://scenes/codex.tscn").instantiate()
		root.add_child(codex)
		await process_frame
		for key in CHANGED:
			codex._select(key)
			check(codex._port.frames.size() == 1 and codex._port.frames[0] == expected_icon(art, key), key + " real codex uses same source")
			await snap("codex_" + key)
		codex.queue_free()
		await process_frame
		var b = await battle_fixture(0, true)
		for key in CHANGED:
			var unit = b.spawn_at(key, 0, Vector2i(28, 28))
			check(unit != null, key + " controlled base-key fixture exists")
			if unit == null: continue
			await select_and_capture(b, unit, expected_icon(art, key), "base_hud_" + key)
			b._set_selection([])
			b.units.erase(unit)
			unit.queue_free()
			await process_frame
		b.queue_free()
		await process_frame
		# Current campaign entry points, with their actual spawned variants.
		for spec in [[1, ["jiangzhou_scaffold", "bailong_temple"]], [2, ["zhu_gate_native_20260906"]], [6, ["roadside_tavern", "heyang_tavern"]], [7, ["daming_south_gate"]]]:
			b = await battle_fixture(spec[0], false)
			for variant in spec[1]:
				var found := 0
				for unit in b.units:
					if unit.art_variant != variant: continue
					found += 1
					var expected: Texture2D = art.avatar_texture(OBJECT_PAIRS[variant], variant)
					check(expected != null, variant + " dedicated icon exists")
					var actual: Dictionary = JSON.parse_string(JSON.stringify(signature(expected)))
					check(actual == before[OBJECT_PAIRS[variant] + "/" + variant].ui, variant + " actual campaign retains dedicated icon")
					if found == 1: await select_and_capture(b, unit, expected, "campaign_hud_" + variant)
				check(found > 0, variant + " present in active campaign entry")
			b.queue_free()
			await process_frame
	var passed := checks.all(func(row): return row.passed)
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Three base UI aliases; complete base and named variant route comparison; controlled base fixtures plus actual campaign objects. World/scoped visual routes not modified; no animation, gameplay, mobile or release acceptance."}, "\t") + "\n")
	quit(0 if passed else 1)
