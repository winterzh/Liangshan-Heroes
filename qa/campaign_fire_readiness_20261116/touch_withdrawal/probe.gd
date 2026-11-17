extends "res://tools/zhujiazhuang_rts_test.gd"
## Bounded fixtures in the real naval chapter. Fire and withdrawal use normal task input.

const READY := {"zh_CN":"可以举火","zh_TW":"可以舉火","en":"Ready to ignite","ja":"点火できます"}
const TAP := {"zh_CN":"轻点","zh_TW":"輕點","en":"tap","ja":"タップ"}

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	var facts := {}
	var b = await _start("",4)
	b.set_process(false)
	b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	var l = b.level
	var fire = l.fireboat
	var two = b.find_unit("ruan_xiaoer_boat")
	var five = b.find_unit("ruan_xiaowu_boat")
	var liu = b.find_unit("liu_tang")
	l.on_mission_action(b,"gao_wind",b.find_unit("gongsun_sheng"))
	l.on_mission_action(b,"gao_prepare",liu)
	check(b.hud.touch_ui and l.fire_prepared and b.mission.actions.has("gao_fire_1"),
		"the actual prep callback creates the touch ignition flag")
	if not failures.is_empty():
		_finish(facts)
		return
	var marker: Vector2 = b.map.cell_to_world(l.FIRE_POINTS[1])
	check("先护送" in l.unit_tactical_hint(b,fire),"the inspector first tells the player to approach a fire flag")
	fire.position = marker
	two.position = marker + Vector2(96,0)
	five.position = marker + Vector2(-256,0)
	for u in b.units:
		if u.faction == 1: u.position = Vector2(10000,10000)
	var enemy = l.water_groups[1][0]
	enemy.position = marker + Vector2(l.FIRE_ZONE_RADIUS,0)
	b.fog = true
	b._sight_now.fill(0)
	b._reveal_t.fill(0)
	var hint: String = l.unit_tactical_hint(b,fire)
	check("可见连船0" in hint and "等第二批" in hint,"unseen linked ships do not make the inspector say ready")
	facts["unseen"]=hint
	var enemy_cell: Vector2i = b.map.world_to_cell(enemy.position)
	b._sight_now[enemy_cell.y*b.map.w+enemy_cell.x] = 1
	hint = l.unit_tactical_hint(b,fire)
	check("到位1/2" in hint and "等两艘" in hint,"a visible target and only one escort show the missing escort")
	facts["one_escort"]=hint
	five.position = marker + Vector2(-96,0)
	var loc = root.get_node("Localize")
	facts["ready"] = {}
	for locale: String in READY:
		loc.set_language(locale,false)
		hint = l.unit_tactical_hint(b,fire)
		check(READY[locale] in hint and TAP[locale] in hint and not l.fire_lit,
			"both escorts plus a visible target show tap-ready advice without igniting / "+locale)
		facts.ready[locale]=hint
	loc.set_language("zh_CN",false)
	b.hud.set_touch_ui(false)
	check("右键" in l.unit_tactical_hint(b,fire),"ignition advice follows a desktop input layout")
	b.hud.set_touch_ui(true)

	b.fog = false
	b._grid_build()
	b.center_camera_cell(l.FIRE_POINTS[1])
	b.select_single(fire,false)
	b._tap_command(b.to_screen(marker),false)
	var fire_token: int = fire.mission_order_token
	b.mission.tick(1.6)
	check(fire_token > 0 and l.fire_lit and l.liu_carrier == two,
		"the real touch task transfers Liu to the original escort after ignition")
	if not failures.is_empty():
		_finish(facts)
		return
	var safe: Vector2 = b.map.cell_to_world(l.FIRE_SAFE)
	two.position = safe+Vector2(32,0)
	five.position = safe+Vector2(96,0)
	enemy.position = Vector2(10000,10000)
	b._grid_build()
	b.center_camera_cell(l.FIRE_SAFE)
	check("安全区2/2" in l.unit_tactical_hint(b,two) and "轻点" in l.unit_tactical_hint(b,two),
		"withdrawal advice shows how both safe escorts submit the task")
	facts["withdraw_hint"]=l.unit_tactical_hint(b,two)

	b.select_members([two,five],false)
	b._tap_command(b.to_screen(two.position),false)
	check(b.selection == [two] and two.mission_order_token == 0,
		"tapping an escort outside the flag ring still selects the ship alone")
	two.position = safe
	b._grid_build()
	b.select_members([two,five],false)
	check(b._friendly_at(b.to_screen(safe)) == two,"the withdrawal flag is actually underneath an escort")
	b._tap_command(b.to_screen(safe),false)
	var group_token: int = two.mission_order_token
	check(group_token > 0 and group_token == five.mission_order_token and b.selection == [two,five],
		"one tap on the overlapping flag orders both selected escorts")
	b.mission.tick(1.1)
	check(b.mission.has_event("fire_escort_safe") and l.liu_carrier == two,
		"the normal command commits the real fire withdrawal and preserves Liu's carrier")
	facts["withdraw_completed"]=b.mission.has_event("fire_escort_safe")
	facts["group_token"]=group_token
	l.port_sealed = true
	l._update_withdrawal_briefing(b)
	check("轻点" in b.mission.objective and "凿船接俘" in b.mission.objective,
		"the sealed harbor lists touch capture and still allows basic victory")
	facts["capture_objective"]=b.mission.objective
	await RenderingServer.frame_post_draw
	var previous: WeakRef = weakref(b)
	b.hud.to_menu.emit()
	await scene_changed
	await RenderingServer.frame_post_draw
	await process_frame
	check(previous.get_ref() == null and current_scene.scene_file_path == "res://scenes/menu.tscn",
		"the normal return releases the battle before exiting the probe")
	_finish(facts)

func _finish(facts: Dictionary) -> void:
	print("GAO_TOUCH_WITHDRAWAL_RESULT ",JSON.stringify({"passed":failures.is_empty(),
		"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("gao_touch_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
