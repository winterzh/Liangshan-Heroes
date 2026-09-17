extends SceneTree
## Agent observational playtest: real fog, 1x pace, screenshots + HUD/message log.
## RTS_PLAY_PLAN=plan_mine|plan_cut|plan_inside
## Not a fun acceptance; evidence for readability / plan feedback.

const OUT := "res://qa/zhujiazhuang_playtest_20260914"
var plan := "plan_cut"
var shots := 0
var log_lines := []

func _initialize() -> void: _run.call_deferred()

func _log(line: String) -> void:
	log_lines.append(line)
	print("[play] ", line)

func _capture(b, name: String, title: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUT)
	var err = picture.save_png(OUT+"/"+name+".png")
	shots += 1
	_log("SHOT %s (%s) err=%s size=%s" % [name, title, err, picture.get_size()])

func _mission_text(b) -> String:
	if b.mission == null:
		return ""
	var t = b.mission.get("status_text")
	if t == null:
		t = b.mission.get("_status")
	return str(t)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var p = OS.get_environment("RTS_PLAY_PLAN")
	if p in ["plan_mine","plan_cut","plan_inside"]:
		plan = p
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	root.size = Vector2i(1280,720)
	var c = root.get_node("Campaign")
	c.current = 2
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]:
		c.set(key,false)
	root.get_node("Settings").auto_micro_level = 0
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	Engine.time_scale = 1.0
	b.center_camera_cell(b.level.CAMP)
	await create_timer(3.0).timeout
	DirAccess.make_dir_recursive_absolute(OUT)
	var l = b.level
	_log("OPEN plan="+plan+" gold="+str(b.gold)+" wood="+str(b.wood)+" pop="+str(b.used_pop())+"/"+str(b.pop_cap))
	_log("HUD mission actions="+str(b.mission.actions.keys()))
	_log("HUD intro hint="+str(b.hud.get("info_label") if b.hud else "n/a"))
	await _capture(b, plan+"_01_opening_camp", "开局前营+任务栏")
	# Recon first: what the player is told to do
	if b.mission.actions.has("zhu_rts_recon"):
		b.select_single(l.song,false)
		b.minimap_order(b.map.cell_to_world(b.mission.actions["zhu_rts_recon"].cell),false)
		_log("ORDER recon by Song Jiang")
	await create_timer(8.0).timeout
	b.center_camera_cell(Vector2i(42,22))
	await _capture(b, plan+"_02_after_recon_area", "探路区域（迷雾开启）")
	_log("t=%d sent_sun=%s stage=%s" % [int(l.elapsed), l.sent_sun, l.stage])
	# Plan-specific early goals
	if plan == "plan_mine":
		var army = b.units.filter(func(u): return u.faction==0 and not u.is_worker and not u.is_building and not u.is_hero)
		b.select_members(army,false)
		b.minimap_order(b.map.cell_to_world(l.EXPANSION),true)
		_log("ORDER take north mine")
		var guard = 0
		while l.elapsed < 120.0 and not l.expansion_secured and guard < 40:
			await create_timer(2.0).timeout
			guard += 1
		b.center_camera_cell(l.EXPANSION)
		await _capture(b, plan+"_03_north_mine", "北矿争夺")
		_log("t=%d expansion_secured=%s" % [int(l.elapsed), l.expansion_secured])
	elif plan == "plan_cut":
		var army = b.units.filter(func(u): return u.faction==0 and not u.is_worker and not u.is_building and not u.is_hero)
		b.select_members(army,false)
		b.minimap_order(b.map.cell_to_world(l.OUTPOST),true)
		_log("ORDER cut south outpost")
		var guard = 0
		while l.elapsed < 180.0 and not l.supply_cut and guard < 70:
			await create_timer(2.0).timeout
			guard += 1
		b.center_camera_cell(l.OUTPOST)
		await _capture(b, plan+"_03_outpost", "南营断援")
		_log("t=%d supply_cut=%s raids=%d" % [int(l.elapsed), l.supply_cut, l.raids_sent])
	else:
		var guard = 0
		while l.elapsed < 60.0 and not l.sent_sun and guard < 20:
			await create_timer(2.0).timeout
			guard += 1
		if alive(l.sun) and b.mission.actions.has("zhu_rts_inside"):
			b.select_single(l.sun,false)
			b.minimap_order(b.map.cell_to_world(b.mission.actions["zhu_rts_inside"].cell),false)
			_log("ORDER Sun Li to inside contact")
		guard = 0
		while l.elapsed < 100.0 and not l.inside_open and guard < 30:
			await create_timer(2.0).timeout
			guard += 1
		b.center_camera_cell(Vector2i(25,18))
		await _capture(b, plan+"_03_side_gate", "偏门接应")
		_log("t=%d inside_open=%s sent_sun=%s" % [int(l.elapsed), l.inside_open, l.sent_sun])
	# Mid: first raid / pressure
	var wait = 0
	while l.elapsed < 200.0 and l.raids_sent < 1 and wait < 40:
		await create_timer(2.0).timeout
		wait += 1
	b.center_camera_cell(b.level.CAMP)
	await _capture(b, plan+"_04_mid_camp", "中盘前营（是否来袭）")
	_log("t=%d raids=%d camp_hp=%s pop=%s/%s gold=%s wood=%s" % [int(l.elapsed), l.raids_sent,
		l.hall.hp if alive(l.hall) else -1, b.used_pop(), b.pop_cap, b.gold, b.wood])
	# Keep playing simply toward gate for a while
	var army = b.units.filter(func(u): return u.faction==0 and not u.is_worker and not u.is_building and not u.is_hero and u.key not in ["song_jiang","sun_li"])
	if army.size() >= 8:
		if plan == "plan_inside" and l.inside_open:
			b.select_members(army,false)
			b.minimap_order(b.map.cell_to_world(Vector2i(22,18)),true)
		else:
			if alive(l.gate) and l.gate.visible:
				b.select_members(army,false)
				b._issue_order(b.to_screen(l.gate.position),false)
			else:
				b.select_members(army,false)
				b.minimap_order(b.map.cell_to_world(Vector2i(25,28)),true)
		_log("ORDER assault "+plan)
	var step = 0
	while l.elapsed < 360.0 and b.phase != b.Phase.END and step < 40:
		await create_timer(4.0).timeout
		step += 1
		army = b.units.filter(func(u): return u.faction==0 and not u.is_worker and not u.is_building and not u.is_hero and u.key not in ["song_jiang","sun_li"])
		if step % 5 == 0:
			_log("t=%d stage_army=%d gate=%s manor=%s inside=%s cut=%s north=%s" % [int(l.elapsed), army.size(),
				alive(l.gate), l.manor_fallen, l.inside_open, l.supply_cut, l.expansion_secured])
	b.center_camera_cell(Vector2i(20,25))
	await _capture(b, plan+"_05_late_gate_area", "后期正门/偏门一带")
	_log("END t=%d phase=%s victory=%s manor=%s inside=%s cut=%s north=%s raids=%d" % [
		int(l.elapsed), b.phase, b.mission.has_event("zhu_victory") if b.mission else false,
		l.manor_fallen, l.inside_open, l.supply_cut, l.expansion_secured, l.raids_sent])
	var f = FileAccess.open(OUT+"/"+plan+"_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines)+"\n")
	f.close()
	b.queue_free()
	await process_frame
	quit()

func alive(u) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""
