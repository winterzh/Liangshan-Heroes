extends SceneTree
## Render the existing native gate drawing, then verify its UI-only asset route.
const ICON := "res://assets/ui/stockade_gate_20260926.png"
var output := ""
var checks: Array = []

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})

func _run() -> void:
	output = OS.get_environment("STOCKADE_ICON_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("ART_QA_PROFILE").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = Vector2(256, 355)
	holder.scale = Vector2.ONE * 2.4
	viewport.add_child(holder)
	var world := Node2D.new()
	holder.add_child(world)
	var map = load("res://scripts/game_map.gd").new()
	world.transform = map.ISO
	map.init_map(64, 64, "liangshan", 0)
	map.set_meta("liangshan_rts_court", true)
	var entrance = load("res://scripts/liangshan_entrance.gd").new()
	entrance.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(entrance)
	entrance.setup(map)
	check(entrance._gate_parts.size() == 3, "same three production gate parts")
	check(not entrance.gate_orientation_summary().main_uses_fixed_bitmap, "native RTS renderer, no campaign bitmap")
	var gate_group := Node2D.new()
	gate_group.position = -map.cell_to_world(entrance._gate_cell)
	world.add_child(gate_group)
	for part in entrance._gate_parts:
		part.reparent(gate_group, false)
	entrance.free()
	await process_frame
	await RenderingServer.frame_post_draw
	var generated := viewport.get_texture().get_image()
	check(generated.save_png(output.path_join("stockade_gate.png")) == OK, "save native rendered PNG")
	var bounds := generated.get_used_rect()
	check(bounds.size.x > 300 and bounds.size.y > 300, "gate fills icon")
	check(bounds.position.x > 4 and bounds.position.y > 4 and bounds.end.x < 508 and bounds.end.y < 508, "no clipped gate edges")
	check(generated.get_pixel(0, 0).a == 0.0, "real transparent corner")
	if OS.get_environment("STOCKADE_ICON_GENERATE") != "1":
		var art = root.get_node("Art")
		var defs = load("res://scripts/defs.gd")
		for key in defs.UNITS:
			check(art.ui_portrait_texture(key) != null, "all-definition UI icon present " + key)
		var tex: Texture2D = art.ui_portrait_texture("stockade_gate")
		check(tex != null and tex.resource_path == ICON, "UI uses dedicated gate icon")
		check(art.avatar_texture("stockade_gate") == tex, "avatar route shares same gate icon")
		check(art.building_texture("stockade_gate") == null and art.unit_texture("stockade_gate") == null, "world gate remains native drawing without duplicate sprite")
		var installed := Image.load_from_file(ICON)
		check(installed.get_size() == Vector2i(512, 512), "installed source size")
		check(installed.get_data() == generated.get_data(), "installed pixels reproduce from production gate drawing")
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		var canvas := Control.new()
		root.add_child(canvas)
		var bg := ColorRect.new()
		bg.color = Color("25271e")
		bg.size = Vector2(1280, 720)
		canvas.add_child(bg)
		var x := 24
		for side in [512, 256, 96, 64, 32]:
			var box := TextureRect.new()
			box.texture = tex
			box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.position = Vector2(x, 60)
			box.size = Vector2(side, side)
			canvas.add_child(box)
			x += side + 24
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("icon_sizes.png")) == OK, "capture icon sizes")
		canvas.queue_free()
		await process_frame
		var campaign = root.get_node("Campaign")
		for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]: campaign.set(mode, false)
		campaign.skirmish = true
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
		battle.fog = false
		if battle._fog_layer != null: battle._fog_layer.hide()
		battle.camera.position_smoothing_enabled = false
		var gate_count := 0
		for gate in battle.units:
			if not gate.has_meta("liangshan_gate_id"): continue
			gate_count += 1
			var gate_id := String(gate.get_meta("liangshan_gate_id"))
			check(bool(gate.get_meta("scene_visual_only", false)), gate_id + " real gate uses native scene visual")
			battle.center_camera_cell(battle.map.world_to_cell(gate.position))
			battle._set_selection([gate])
			battle.hud._refresh_panel()
			check(battle.hud._port_tex.visible and battle.hud._port_tex.texture == tex, gate_id + " actual bottom-left HUD shows gate icon")
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("gate_hud_" + gate_id + ".png")) == OK, "capture actual " + gate_id + " gate HUD")
		check(gate_count == 2, "both deployed RTS gates reviewed")
		battle.queue_free()
	viewport.queue_free()
	map.free()
	await process_frame
	var passed := checks.all(func(row): return row.passed)
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify({"passed": passed, "checks": checks, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "scope": "Native production gate renderer, reproducible alpha PNG, UI-only route, both actual deployed RTS gate HUDs. No navigation or gameplay change."}, "\t") + "\n")
	quit(0 if passed else 1)
