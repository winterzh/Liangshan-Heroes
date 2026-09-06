extends SceneTree
## Store footage: native scenes, normal orders/production, unchanged combat rules.
## Run against the verified release EXE with --main-pack; isolated APPDATA.
const SOURCE_SHA := "443e75e887afd76f9569cae17b0527a72408aedc"
const FPS := 30
var shot := "zhu"
var output_dir := ""
var b
var frames := 0
var rows: Array = []
var _camera_target := Vector2.ZERO

func _init() -> void:
	# MovieWriter snapshots the window-override settings before SceneTree.initialize.
	# The script constructor changes only capture resolution, never game rules.
	ProjectSettings.set_setting("display/window/size/window_width_override",1920)
	ProjectSettings.set_setting("display/window/size/window_height_override",1080)

func _initialize() -> void:
	_run.call_deferred()

func _live(u) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""

func _army(water := false) -> Array:
	return b.units.filter(func(u): return _live(u) and u.faction == 0 and not u.is_building and not u.is_worker and not u.is_noncombat and ((u.movement_profile == "water") == water))

func _log(action: String, details: Variant = {}) -> void:
	var row := {"frame":frames,"seconds":float(frames)/FPS,"action":action,"details":details}
	rows.append(row)
	print("STORE_FOOTAGE ",JSON.stringify(row))

func _order_army(cell: Vector2i, water := false) -> void:
	var army := _army(water)
	b._set_selection(army)
	for u in army:
		u.order_amove(b.map.cell_to_world(cell))
	_log("normal_attack_move",{"cell":[cell.x,cell.y],"units":army.map(func(u):return u.key)})

func _train(key: String) -> void:
	var barracks = b.units.filter(func(u):return _live(u) and u.faction == 0 and u.key == "barracks")
	if barracks.is_empty(): return
	var ok: bool = b.queue_train(barracks[0],key,false)
	_log("normal_paid_training",{"unit":key,"accepted":ok,"gold":b.gold,"wood":b.wood})

func _learn(key: String, slot: int) -> void:
	var hero = b.find_unit(key)
	if not _live(hero): return
	b.learn_slot(hero,slot)
	_log("normal_learn_skill",{"hero":key,"slot":slot,"rank":hero.ability_slots[slot].rank})

func _cast(key: String, slot: int, at_enemy := false) -> void:
	var hero = b.find_unit(key)
	if not _live(hero) or not hero.slot_ready(slot): return
	b._set_selection([hero])
	b.cast_ability(hero,slot,false)
	var target_position: Vector2 = hero.position
	if at_enemy:
		var enemies = b.units.filter(func(u):return _live(u) and u.faction == 1 and not u.is_building and not u.is_resource and b.is_visible_world(u.position))
		if not enemies.is_empty():
			var enemy = enemies[0]
			for u in enemies:
				if hero.position.distance_to(u.position)<hero.position.distance_to(enemy.position): enemy = u
			target_position = enemy.position
	if b._ability_caster == hero: b._cast_armed_at(b.to_screen(target_position))
	_log("normal_skill_command",{"hero":key,"slot":slot,"enemy_target":at_enemy})

func _build_house(cell: Vector2i) -> void:
	var workers = b.units.filter(func(u):return _live(u) and u.faction == 0 and u.is_worker)
	if workers.is_empty(): return
	b._set_selection([workers[workers.size()-1]])
	b.arm_build("house")
	b._try_place_building(b.to_screen(b.map.cell_to_world(cell)))
	_log("normal_build_house",{"cell":[cell.x,cell.y],"gold":b.gold,"wood":b.wood})

func _camera_cell(cell: Vector2i, zoom_value: float) -> void:
	_camera_target = b.to_screen(b.map.cell_to_world(cell)) + Vector2(-120,60)
	b.camera.zoom = Vector2.ONE * zoom_value

func _camera_army(water := false, zoom_value := 1.20) -> void:
	var army := _army(water)
	if army.is_empty(): return
	if not water:
		var heroes := army.filter(func(u):return u.key in ["song_jiang","lin_chong"])
		if not heroes.is_empty(): army = heroes
	var center := Vector2.ZERO
	for u in army: center += u.position
	center /= army.size()
	_camera_target = b.to_screen(center) + Vector2(-140,60)
	b.camera.zoom = Vector2.ONE * zoom_value

func _setup() -> void:
	shot = OS.get_environment("STORE_SHOT")
	if shot.is_empty(): shot = "zhu"
	output_dir = OS.get_environment("STORE_VIDEO_OUT").replace("\\","/")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1280,720)
	root.mode = Window.MODE_WINDOWED
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var settings = root.get_node("Settings")
	settings.game_speed = 1.0
	settings.edge_scroll = false
	settings.atmosphere = true
	settings.auto_micro_level = 0
	settings.show_range_rings = false
	settings.show_target_lines = false
	settings.show_command_queue = false
	settings.bgm = 0.8
	settings.sfx = 0.8
	settings.muted = false
	settings.apply_audio()
	var campaign = root.get_node("Campaign")
	for flag in ["skirmish","skirmish_ai","arena","custom_defense","scenario","ai_friendly","scale_on"]: campaign.set(flag,false)
	campaign.current = 4 if shot == "naval" else 0 if shot == "caravan" else 2
	if shot == "defense":
		campaign.skirmish = true
		campaign.defense_waves = 30
		campaign.defense_random = false
		campaign.ai_friendly = true
	seed(50881207)
	b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	if b.hud._intro_root != null: b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	if b.hud._fps_label != null: b.hud._fps_label.hide()
	b.camera.position_smoothing_enabled = false
	b.camera._user_input_t = 9999.0
	if shot == "defense": _camera_cell(Vector2i(20,34),0.9)
	elif shot == "naval": _camera_cell(Vector2i(35,47),1.10)
	elif shot == "caravan": _camera_cell(b.level.camera_start_cell(),1.10)
	else: _camera_cell(Vector2i(52,31),1.08)
	b.camera.position = _camera_target
	b.camera.force_update_scroll()
	_log("scene_start",{"level":b.level.id(),"source_sha":SOURCE_SHA,"pack":OS.get_environment("STORE_MOUNTED_PACK"),"pack_sha256":FileAccess.get_sha256(OS.get_environment("STORE_MOUNTED_PACK")),"viewport":[1920,1080],"game_speed":1.0,"mode":"standard_30_wave_full_auto" if shot == "defense" else "standard_campaign"})

func _run() -> void:
	await _setup()
	var duration := 75 if shot == "zhu" else 65 if shot == "naval" else 12 if shot == "caravan" else 205
	var override_duration := OS.get_environment("STORE_DURATION")
	if not override_duration.is_empty(): duration = int(override_duration)
	for frame in range(duration*FPS):
		frames = frame
		var second := frame/FPS
		if frame%FPS == 0:
			if shot == "zhu":
				match second:
					2: _build_house(Vector2i(51,37))
					3: _train("liang_qiang"); _train("liang_gong"); _train("liang_qiang"); _learn("song_jiang",1); _learn("lin_chong",0)
					24: _order_army(Vector2i(42,22))
					36: _order_army(Vector2i(36,17))
					43: _cast("song_jiang",1); _cast("lin_chong",0,true)
					60: _order_army(Vector2i(34,16))
				if second < 24: _camera_cell(Vector2i(52,31),1.1)
				else: _camera_army(false,1.22)
			elif shot == "naval":
				match second:
					2: _order_army(Vector2i(39,39),true)
					18: _order_army(Vector2i(42,29),true)
					40: _order_army(Vector2i(34,26),false)
				if second < 42: _camera_army(true,1.05)
				else: _camera_army(false,1.12)
			elif shot == "caravan":
				_camera_cell(b.level.camera_start_cell(),1.10)
			else:
				if second < 100: _camera_cell(Vector2i(19,32),0.90)
				elif second < 140: _camera_cell(Vector2i(22,24),1.06)
				else:
					var enemies = b.units.filter(func(u):return _live(u) and u.faction == 1 and not u.is_building and b.is_visible_world(u.position))
					if not enemies.is_empty():
						var focus = enemies[0]
						for u in enemies:
							if u.position.distance_to(b.level.hall.position) < focus.position.distance_to(b.level.hall.position): focus = u
						_camera_target = b.to_screen(focus.position)+Vector2(-120,60)
						b.camera.zoom = Vector2.ONE*1.10
					else: _camera_cell(Vector2i(22,31),0.96)
			if second%5 == 0:
				_log("state",{"level":b.level.id(),"phase":b.phase,"friendly":b.players_alive(),"enemy":b.enemies_alive(),"gold":b.gold,"wood":b.wood,"army_hp":_army().map(func(u):return {"key":u.key,"hp":u.hp,"cell":str(b.map.world_to_cell(u.position))})})
		b.camera._user_input_t = 9999.0
		b.camera.position = b.camera.position.lerp(_camera_target,0.045)
		b.camera.force_update_scroll()
		await process_frame
		if frame%150 == 149:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_dir.path_join("%s_%03d.png"%[shot,(frame+1)/FPS]))
	var file := FileAccess.open(output_dir.path_join(shot+"_capture_log.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"source_sha":SOURCE_SHA,"shot":shot,"fps":FPS,"frames":frames+1,"orders":rows,"scope":"Normal campaign/standard 30-wave defense scenes; normal paid training, building and attack-move orders; no spawn, stat, health, resource, fog or mission-progress overrides. Intro dismissal and camera positioning are presentation actions. In-game audio only."},"  ")+"\n")
	file.close()
	root.get_node("AppLifecycle").request_quit("store_footage_complete")
