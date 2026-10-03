extends "res://tools/scoped_object_icons_qa.gd"
## Real defense scenes: static visual ownership, scope guards and HUD.

func _run() -> void:
	output = OS.get_environment("SCOPED_OBJECT_ICONS_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("ART_QA_PROFILE").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var art = root.get_node("Art")
	var expected := EA.object("level5", "zhongyi_hall")
	check(expected != null, "accepted hall bitmap exists")
	for custom in [false, true]:
		var b = await defense_fixture(custom)
		var hall = b.level.hall
		var mode := "custom_defense" if custom else "skirmish"
		check(hall != null and hall.key == "hall", mode + " real gameplay hall")
		check(hall._active_campaign_level_id() == mode, mode + " gameplay identity unchanged")
		check(b.map.get_meta("liangshan_hall_cell") == b.map.world_to_cell(hall.position), mode + " scenery anchor matches gameplay owner")
		var matches := 0
		for sprite in b.map.sample_scenery._sprites:
			if sprite.get_meta("campaign_environment_route", "") == "zhongyi_hall":
				matches += 1
				check(sprite.position == hall.position, mode + " actual static sprite at hall")
				check(sprite.tex == expected, mode + " actual static sprite uses accepted source")
		check(matches == 1, mode + " exactly one static hall")
		check(hall._campaign_environment_texture(false) == expected, mode + " unit resolves scenery source and suppresses legacy body")
		var saved := metadata(hall).duplicate(true)
		var health: float = hall.hp
		var gameplay_position: Vector2 = hall.position
		await inspect(b, hall, expected, mode + "_hall_aligned")
		check(hall.hp == health and hall.position == gameplay_position, mode + " UI does not alter health or placement")
		# Explicit scenery reuse is limited to this exact static hall owner.
		for field in ["campaign_environment_route", "campaign_environment_state", "campaign_environment_text_surface_id"]:
			hall.set_meta(field, "invalid_qa_value")
			check(hall.ui_portrait_texture() == art.ui_portrait_texture("hall"), mode + " rejects invalid " + field)
			for key in saved: hall.set_meta(key, saved[key])
		hall.set_meta("campaign_environment_static_visual", false)
		check(hall._campaign_environment_art_level_id() == mode, mode + " ordinary dynamic building cannot reuse scenery scope")
		for key in saved: hall.set_meta(key, saved[key])
		hall.position += Vector2(64, 0)
		check(hall._campaign_environment_art_level_id() == mode, mode + " unrelated hall at another position cannot reuse scope")
		hall.position = gameplay_position
		hall.key = "market"
		check(hall._campaign_environment_art_level_id() == mode, mode + " unrelated building cannot reuse scope")
		hall.key = "hall"
		var art_id = b.map.get_meta("liangshan_art_level_id")
		b.map.set_meta("liangshan_art_level_id", "level7")
		check(hall._campaign_environment_art_level_id() == mode, mode + " wrong scenery art level rejected")
		b.map.set_meta("liangshan_art_level_id", art_id)
		var scenery = b.map.sample_scenery
		b.map.sample_scenery = null
		check(hall._campaign_environment_art_level_id() == mode, mode + " no static scenery retains ordinary body")
		b.map.sample_scenery = scenery
		check(metadata(hall) == saved, mode + " all metadata restored after guard checks")
		b.queue_free()
		await process_frame
	var b = await battle_fixture(4, false)
	for unit in b.units:
		if unit.get_meta("campaign_environment_route", "") == "zhongyi_hall":
			check(unit._active_campaign_level_id() == "level5", "campaign level identity unchanged")
			await inspect(b, unit, expected, "level5_hall_unchanged")
	b.queue_free()
	await process_frame
	var passed := checks.all(func(row): return row.passed)
	FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify({"passed": passed, "checks": checks, "instances": scoped_rows, "scope": "Real classic/custom defense and campaign hall placement, static ownership, narrow art scope and HUD. No performance or complete combat acceptance."}, "\t") + "\n")
	quit(0 if passed else 1)

func defense_fixture(custom: bool):
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "ai_friendly", "scale_on"]:
		campaign.set(mode, false)
	campaign.skirmish = true
	campaign.custom_defense = custom
	campaign.custom_config = {}
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
