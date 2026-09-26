extends SceneTree
## Only texture regions change: source images and world sprites remain untouched.
var checks: Array = []
var output := ""
var art

func _init() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok: print("FAIL: ", label)

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func box(parent: Control, tex: Texture2D, pos: Vector2, side: int) -> void:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.position = pos
	rect.size = Vector2(side, side)
	parent.add_child(rect)

func run() -> void:
	output = OS.get_environment("PORTRAIT_REGIONS_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("ART_QA_PROFILE").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	art = root.get_node("Art")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/contracts/portrait_regions_20260926/manifest.json"))
	for row in manifest.sources:
		check(FileAccess.get_sha256("res://" + row.path) == row.sha256, "unchanged original " + row.path)
	var ids: Array = []
	for key in manifest.portraits:
		var row: Dictionary = manifest.portraits[key]
		var tex: Texture2D = art.portrait_texture(key)
		var r: Array = row.region
		var region := Rect2(r[0], r[1], r[2], r[3])
		check(tex is AtlasTexture, key + " region texture")
		if not tex is AtlasTexture: continue
		check(tex.atlas.resource_path == "res://" + row.source and tex.region == region, key + " exact authored source/region")
		check(Rect2(Vector2.ZERO, tex.atlas.get_size()).encloses(region) and region.size.x > 0 and region.size.y > 0, key + " valid bounds")
		check(tex.filter_clip, key + " edge filtering clipped")
		check(art.ui_portrait_texture(key) == tex and art.portrait_texture(key) == tex, key + " shared cached HUD/codex portrait")
		var id: String = row.source + str(region)
		check(not id in ids, key + " distinct panel identity")
		ids.append(id)
	for key in art.STANDALONE_PORTRAITS:
		check(art.portrait_texture(key).resource_path == art.STANDALONE_PORTRAITS[key], key + " standalone priority")
	var defs = load("res://scripts/defs.gd")
	for key in defs.UNITS:
		check(art.ui_portrait_texture(key) != null, key + " UI icon available")
	var keys: Array = manifest.portraits.keys()
	for page in range(ceili(keys.size() / 6.0)):
		var canvas := Control.new()
		canvas.theme = UITheme.shared()
		root.add_child(canvas)
		var bg := ColorRect.new()
		bg.color = Color("25271e")
		bg.size = Vector2(1280, 900)
		canvas.add_child(bg)
		for i in range(6):
			if page * 6 + i >= keys.size(): break
			var key: String = keys[page * 6 + i]
			var row: Dictionary = manifest.portraits[key]
			var origin := Vector2((i % 3) * 426, (i / 3) * 450)
			var title := Label.new()
			title.text = str(defs.UNITS[key].name) + " / " + key + "\n旧裁切                 修正裁切"
			title.position = origin + Vector2(10, 8)
			title.add_theme_font_size_override("font_size", 16)
			canvas.add_child(title)
			var old := AtlasTexture.new()
			old.atlas = load("res://" + row.source)
			var r: Array = row.legacy_region
			old.region = Rect2(r[0], r[1], r[2], r[3])
			old.filter_clip = true
			box(canvas, old, origin + Vector2(8, 62), 200)
			box(canvas, art.portrait_texture(key), origin + Vector2(218, 62), 200)
			box(canvas, art.ui_portrait_texture(key), origin + Vector2(218, 282), 64)
			box(canvas, art.ui_portrait_texture(key), origin + Vector2(304, 282), 32)
		await snap("regions_" + str(page + 1))
		canvas.queue_free()
		await process_frame
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var codex = load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	await process_frame
	for key in keys:
		codex._select(key)
		check(codex._port.frames.size() == 1 and codex._port.frames[0] == art.portrait_texture(key), key + " actual codex")
		if key in ["li_ying", "wei_dingguo", "xue_yong"]: await snap("codex_" + key)
	codex.queue_free()
	await process_frame
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(mode, false)
	campaign.current = 0
	root.get_node("Settings").auto_micro_level = 0
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	battle.phase = battle.Phase.FIGHT
	battle.hud._intro_root.hide()
	battle.hud.hide_deploy()
	battle.level.on_start(battle)
	for key in keys:
		var unit = battle.spawn_at(key, 0, Vector2i(20, 20))
		check(unit != null, key + " HUD fixture")
		if unit == null: continue
		battle._set_selection([unit])
		battle.hud._refresh_panel()
		check(battle.hud._port_tex.visible and battle.hud._port_tex.texture == art.portrait_texture(key), key + " actual bottom-left HUD")
		if key in ["li_ying", "wei_dingguo", "xue_yong"]: await snap("hud_" + key)
		battle._set_selection([])
		unit.queue_free()
		await process_frame
	battle.queue_free()
	await process_frame
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "81 authored regions, unchanged atlas bytes, actual codex/HUD, source identity and 32/64/200px comparison galleries. Visual review separate; no claim of new faces, model alignment, combat or mobile acceptance."}, "\t") + "\n")
	file.close()
	quit(0 if passed else 1)
