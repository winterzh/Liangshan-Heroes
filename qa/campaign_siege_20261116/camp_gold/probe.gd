extends "res://tools/zhujiazhuang_rts_test.gd"
## Real mission callback and gather input, with controlled mine eligibility.

func _set_sight(b, mine, shown: bool) -> void:
	var cell: Vector2i = b.map.world_to_cell(mine.position)
	var index: int = cell.y * b.map.w + cell.x
	b._sight_now[index] = 1 if shown else 0
	b._reveal_t[index] = 0.0
	mine.fog_visible = shown

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	var b = await _start()
	await physics_frame
	await process_frame
	b.set_process(false)
	b.set_physics_process(false)
	var level = b.level
	var button: Button
	for child in b.mission._buttons.get_children():
		var descriptor: Dictionary = child.get_meta("campaign_presentation_v1",{})
		if descriptor.get("button_id") == "zhu_find_camp_gold":
			button = child
	check(is_instance_valid(button), "the normal mission registers the official gold locator")
	if button == null:
		await _dispose(b)
		quit(1)
		return

	b.center_camera_cell(level.CAMP)
	button.pressed.emit()
	check("此矿约剩" in b.mission._status.text, "opening camp has a visible mine through the normal mission button")
	var mines: Array = b.units.filter(func(u):
		return u.key == "gold_mine" and b.map.world_to_cell(u.position) in level.CAMP_GOLD_CELLS)
	for u in b.units:
		u.set_physics_process(false)
	check(mines.size() == 3, "locator uses the three authored camp mines")
	var occupied = mines[0]
	var open = mines[1]
	var hidden = mines[2]
	occupied.res_left = 600
	open.res_left = 350
	hidden.res_left = 900
	_set_sight(b,occupied,true)
	_set_sight(b,open,true)
	_set_sight(b,hidden,false)
	for worker in level.workers:
		worker.order_gather(occupied)
	var worker = level.workers[0]
	b.select_members([worker],false)
	var serial: int = worker._order_serial
	var gold: int = b.gold
	b.center_camera_cell(b.map.world_to_cell(open.position))
	var expected: Vector2 = b.camera.position
	b.center_camera_cell(level.CAMP)
	button.pressed.emit()
	check(b.camera.position == expected and "350金，0名工人" in b.mission._status.text,
		"the unassigned visible mine wins over the richer occupied and hidden mines")
	check(b.selection == [worker] and worker._order_serial == serial
		and worker._gather_node == occupied and b.gold == gold,
		"viewing preserves selection, gather order and gold")
	var localization = root.get_node("Localize")
	var status_key := "此矿约剩%d金，%d名工人采运。选工人右键金矿可采集。"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/zhujiazhuang_camp_gold.json"))
	for locale: String in localization.LOCALES:
		localization.set_language(locale,false)
		var label: String = "查看 · 前营金矿" if locale == "zh_CN" else catalog["查看 · 前营金矿"][locale]
		var status: String = status_key if locale == "zh_CN" else catalog[status_key][locale]
		check(button.text == label and b.mission._status.text == status % [350,0], "button and current feedback in " + locale)
	localization.set_language("zh_CN",false)
	b._grid_build()
	b._issue_order(b.to_screen(open.position),false)
	check(worker._gather_node == open and worker._order_serial > serial, "a separate right-click orders the worker to mine")

	open.res_left = 0
	var block: Vector2i = b.map.world_to_cell(occupied.position)
	b.map.block_footprint(block,0,true)
	await physics_frame
	button.pressed.emit()
	check("前营暂无可见的可采金矿" in b.mission._status.text,
		"depleted, obstructed and hidden mines trigger the northern mines or market alternative")
	b.map.block_footprint(block,0,false)
	level.main_breached = true
	level._refresh_stage(b)
	check("缺金可查看前营金矿" in b.mission.objective, "an open main gate points players to the gold option")
	level.supply_cut = true
	level._refresh_stage(b)
	check("缺金可查看前营金矿" not in b.mission.objective, "the siege objective advances after cutting reinforcements")
	print("ZHU_CAMP_GOLD_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"visible_unassigned_gold":350}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
