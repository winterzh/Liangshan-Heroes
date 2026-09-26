extends SceneTree
## Run against frozen production inputs and a private user profile.
const DEFAULT_MANIFEST := "res://tools/contracts/hero_portraits_aligned_20260926/manifest.json"
var checks: Array = []
var output := ""

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func run() -> void:
	output = OS.get_environment("HERO_PORTRAITS_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("ART_QA_PROFILE").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var manifest_path := OS.get_environment("HERO_PORTRAITS_MANIFEST")
	if manifest_path.is_empty(): manifest_path = DEFAULT_MANIFEST
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var art = root.get_node("Art")
	var codex = load("res://scenes/codex.tscn").instantiate()
	root.add_child(codex)
	await process_frame
	for key in manifest.portraits:
		var row: Dictionary = manifest.portraits[key]
		var path: String = "res://" + row.path
		var texture: Texture2D = art.portrait_texture(key)
		check(FileAccess.get_sha256(path) == row.sha256, key + " original source bytes")
		check(texture != null and texture.resource_path == path, key + " standalone portrait route")
		if texture != null:
			check(texture.get_width() == row.width and texture.get_height() == row.height, key + " imported dimensions")
		var avatar: Texture2D = art.ui_portrait_texture(key)
		check(avatar != null and avatar.resource_path == path, key + " HUD avatar route")
		codex._select(key)
		await process_frame
		check(codex._port.frames.size() == 1 and codex._port.frames[0].resource_path == path, key + " real codex portrait")
		await snap(key + "_codex")
	check(art.portrait_texture("chao_gai").resource_path == "res://assets/characters/art_full_20260916/chao_gai_portrait_20260916.png", "existing Chao Gai route retained")
	check(art.portrait_texture("lin_chong").resource_path == "res://assets/characters/codex_portraits_20260913/lin_chong.png", "existing Lin Chong route retained")
	codex.queue_free()
	await process_frame
	var canvas := Control.new()
	canvas.theme = UITheme.shared()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("25271e")
	bg.size = Vector2(1280, 720)
	canvas.add_child(bg)
	var index := 0
	var column_width: float = 1280.0 / manifest.portraits.size()
	for key in manifest.portraits:
		var row: Dictionary = manifest.portraits[key]
		var label := Label.new()
		label.text = row.name + "\n" + key
		label.add_theme_font_size_override("font_size", 16)
		label.position = Vector2(index * column_width + 16, 12)
		canvas.add_child(label)
		var y := 70
		for side in [mini(256, int(column_width) - 32), 96, 64, 32]:
			var box := TextureRect.new()
			box.texture = art.ui_portrait_texture(key)
			box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.size = Vector2(side, side)
			box.position = Vector2(index * column_width + 16, y)
			canvas.add_child(box)
			var size_label := Label.new()
			size_label.text = str(side) + " px"
			size_label.position = Vector2(index * column_width + 16, y + side + 2)
			canvas.add_child(size_label)
			y += side + 42
		index += 1
	await snap("portrait_sizes")
	canvas.queue_free()
	await process_frame
	if manifest.has("model_alignment"):
		await model_alignment(manifest.model_alignment, art)
	var passed := checks.all(func(row): return row.passed)
	var report := {"passed": passed, "checks": checks, "scope": "Original PNG identity, production Art/HUD routes, actual codex and size previews; optional model reference bytes, actual sprite paths and honest directional coverage. Visual similarity is reviewed separately; no combat or release acceptance."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	quit(0 if passed else 1)

func model_alignment(rows: Dictionary, art) -> void:
	var samples: Array = []
	for key in rows:
		var row: Dictionary = rows[key]
		for source in row.sources + row.get("world_files", []):
			check(FileAccess.get_sha256("res://" + source.path) == source.sha256, key + " model source bytes " + source.path)
		var canvas := Control.new()
		canvas.theme = UITheme.shared()
		root.add_child(canvas)
		var bg := ColorRect.new()
		bg.color = Color("25271e")
		bg.size = Vector2(1280, 720)
		canvas.add_child(bg)
		var title := Label.new()
		title.text = row.name + " / " + key + " · 头像与实际造型对照"
		title.position = Vector2(24, 24)
		canvas.add_child(title)
		var portrait := TextureRect.new()
		portrait.texture = art.ui_portrait_texture(key)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(24, 112)
		portrait.size = Vector2(320, 320)
		canvas.add_child(portrait)
		var index := 0
		for direction in ["se", "sw", "ne", "nw"]:
			var frames: Array = art.unit_anim_frames(key, row.state, direction)
			var exact: bool = art.unit_anim_uses_directional_source(key, row.state, direction)
			check(not frames.is_empty(), key + " model available " + direction)
			check(exact == row.directional, key + " honest directional coverage " + direction)
			if not frames.is_empty():
				var box := TextureRect.new()
				box.texture = frames[0]
				box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				box.position = Vector2(370 + index * 224, 150)
				box.size = Vector2(220, 220)
				canvas.add_child(box)
				var frame: Texture2D = frames[0]
				var source_path: String = frame.atlas.resource_path if frame is AtlasTexture else frame.resource_path
				check(row.sources.any(func(source): return "res://" + source.path == source_path), key + " actual source matches approved reference " + direction)
				samples.append({"key": key, "state": row.state, "direction": direction, "independent_direction": exact, "source": source_path, "portrait": portrait.texture.resource_path})
			var label := Label.new()
			label.text = direction.to_upper() + " · " + ("独立四向" if exact else "旧图回退")
			label.position = Vector2(380 + index * 224, 392)
			canvas.add_child(label)
			index += 1
		var notes := Label.new()
		notes.text = row.review + "\n" + row.limit
		notes.position = Vector2(24, 476)
		notes.size = Vector2(1210, 200)
		notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		canvas.add_child(notes)
		await snap(key + "_model_alignment")
		canvas.queue_free()
		await process_frame
	var file := FileAccess.open(output.path_join("model_alignment.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "\t") + "\n")
	file.close()
