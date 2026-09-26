extends SceneTree
## Run against frozen production inputs and a private user profile.
const MANIFEST := "res://tools/contracts/hero_portraits_20260926/manifest.json"
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
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
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
		var avatar: Texture2D = art.avatar_texture(key)
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
	for key in manifest.portraits:
		var row: Dictionary = manifest.portraits[key]
		var label := Label.new()
		label.text = row.name + " / " + key
		label.position = Vector2(index * 320 + 24, 12)
		canvas.add_child(label)
		var y := 48
		for side in [256, 96, 64, 32]:
			var box := TextureRect.new()
			box.texture = art.avatar_texture(key)
			box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.size = Vector2(side, side)
			box.position = Vector2(index * 320 + 24, y)
			canvas.add_child(box)
			var size_label := Label.new()
			size_label.text = str(side) + " px"
			size_label.position = Vector2(index * 320 + 24, y + side + 2)
			canvas.add_child(size_label)
			y += side + 42
		index += 1
	await snap("portrait_sizes")
	canvas.queue_free()
	await process_frame
	var passed := checks.all(func(row): return row.passed)
	var report := {"passed": passed, "checks": checks, "scope": "Original PNG identity, production Art/HUD routes, actual codex and 256/96/64/32px engine rendering; no animation, combat or release acceptance."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	quit(0 if passed else 1)
