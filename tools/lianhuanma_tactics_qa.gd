extends "res://tools/zhujiazhuang_rts_test.gd"
## Frozen real-world predicate and HUD fixtures; never counted as a playthrough.

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.get_node("Settings").edge_scroll = false
	var folder := "res://.godot/hook-tactics"
	DirAccess.make_dir_recursive_absolute(folder)
	var b = await _start("", 3)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	b.fog = false
	b._fog_layer.hide()
	var level = b.level
	var rider = level.riders[0]
	var hooks: Array = b.units.filter(func(u): return u.key == "gou_lian" and u.faction == 0)
	for u in b.units:
		if u.key in level.HOOK_KEYS: u.position = b.map.cell_to_world(level.CAMP)
	var ids: Array = level.riders.map(func(u): return u.entity_id)
	rider.position = b.map.cell_to_world(Vector2i(34,29))
	for i in range(2):
		hooks[i].position = rider.position + Vector2(24 + i * 24,0)
		hooks[i]._target = rider
	check(not level.hook_conditions(b,rider).ready, "unimpeded road rider does not break")
	rider.temp_speed = 0.8
	check(not level.hook_conditions(b,rider).ready, "20 percent slow is below existing break requirement")
	rider.temp_speed = 0.79
	check(level.hook_conditions(b,rider).ready, "strong slow and a supported melee target meet existing rule")
	hooks[1]._stun_t = 1.0
	check(not level.hook_conditions(b,rider).ready, "stunned partner cannot satisfy cooperation")
	hooks[1]._stun_t = 0.0
	hooks[1].garrisoned = true
	check(not level.hook_conditions(b,rider).ready, "garrisoned partner cannot satisfy cooperation")
	hooks[1].garrisoned = false
	rider.temp_speed = 1.0
	rider.position = b.map.cell_to_world(level.LANES[0])
	level.riders[1].position = rider.position + Vector2(130,0)
	for i in range(2):
		hooks[i].position = rider.position + Vector2(24 + i * 24,0)
		hooks[i]._target = null
	check(not level.hook_conditions(b,rider).ready, "nearby partners still need a melee attack target")
	rider.apply_damage_reduction(0.5,1.25,level.LINK_SOURCE)
	var serials: Array = hooks.map(func(u): return u._order_serial)
	var count_before: int = level.broken_count
	var hint: String = level.unit_tactical_hint(b,rider)
	check("50%" in hint and "2/2" in hint and level.broken_count == count_before and hooks.map(func(u): return u._order_serial) == serials, "inspection reads actual protection and partners without changing combat or orders")
	b.fog = true
	var cell: Vector2i = b.map.world_to_cell(rider.position)
	b._sight_now[cell.y * b.map.w + cell.x] = 0
	b._reveal_t[cell.y * b.map.w + cell.x] = 0
	check("暂无视野" in level.unit_tactical_hint(b,rider), "hidden inspected rider reveals no tactical condition")
	b.fog = false
	hooks[0]._target = rider
	level._rider_tick(b)
	level._rider_tick(b)
	check(bool(rider.get_meta("formation_broken")) and not rider._damage_reduction_sources.has(level.LINK_SOURCE) and level.broken_count == count_before + 1 and level.riders.map(func(u): return u.entity_id) == ids, "production tick breaks once, removes link protection and preserves twelve identities")
	var state = load("res://scripts/run_campaign_level_state.gd").new()
	check(state.audit_declarations("level4").ok, "derived feedback adds no unclassified saved fields")
	# Display fixture: restore an unbroken, hindered target with partners nearby
	# but no current attack. No victory or route outcome is derived from this.
	rider.set_meta("formation_broken", false)
	rider.set_meta("wave_state", "waiting")
	rider.apply_damage_reduction(0.5,1.25,level.LINK_SOURCE)
	for u in hooks: u._target = null
	var texts: Array = []
	for language in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(language,false)
		await _capture(b, rider, language + "_rider", folder, texts)
	root.get_node("Localize").set_language("en",false)
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	level.xu._target = null
	await _capture(b, level.xu, "en_narrow_xu", folder, texts)
	await _dispose(b)
	FileAccess.open(folder + "/report.json", FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(), "checks":checks, "failures":failures, "texts":texts, "scope":"frozen predicate/HUD fixtures; not gameplay or whole-world restore"}, "\t"))
	quit(0 if failures.is_empty() else 1)

func _capture(b, target, name: String, folder: String, texts: Array) -> void:
	target.fog_visible = true
	target.show()
	if target.faction == 0: b.select_single(target,false)
	else: b._set_inspect(target)
	b.hud.update_selection_panel(b.selection)
	b.hud._refresh_panel()
	b.camera.zoom = Vector2.ONE
	b.center_camera_cell(b.map.world_to_cell(target.position))
	b.camera.force_update_scroll()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var label: Label = b.hud._info_stats
	var bounds: Rect2 = label.get_global_rect()
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(bounds) and b.hud._info_box.get_global_rect().encloses(bounds) and label.get_minimum_size().y <= label.size.y + 1, name + " tactical text fits rendered panel")
	check(root.get_texture().get_image().save_png(folder + "/" + name + ".png") == OK, name + " actual renderer capture")
	texts.append({"name":name,"text":label.text,"rect":str(bounds)})
