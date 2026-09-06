extends SceneTree
## 按稳定关卡ID配置的部署态捕获。旧环境契约仅供定位地形回归，不代表新任务验收。
const CENTERS := {"level1":Vector2i(24,20),"level2":Vector2i(28,26),"level3":Vector2i(34,28),"level4":Vector2i(20,40),"level5":Vector2i(23,38),"level6":Vector2i(39,20),"level7":Vector2i(32,19),"level8":Vector2i(36,25)}
const DETAILS := {"level1":Vector2i(22,20),"level2":Vector2i(27,23),"level3":Vector2i(19,28),"level4":Vector2i(20,40),"level5":Vector2i(17,38),"level6":Vector2i(27,20),"level7":Vector2i(35,19),"level8":Vector2i(35,16)}
const ROUTES := {
"level1":[[Vector2i(46,20),Vector2i(24,20)],[Vector2i(24,20),Vector2i(2,20)]],
"level2":[[Vector2i(8,30),Vector2i(28,24)],[Vector2i(24,40),Vector2i(28,24)],[Vector2i(28,24),Vector2i(10,50)]],
"level3":[[Vector2i(58,28),Vector2i(24,28)],[Vector2i(42,22),Vector2i(40,14)]],
"level4":[[Vector2i(57,24),Vector2i(31,30)],[Vector2i(14,42),Vector2i(24,40)]],
"level5":[[Vector2i(16,49),Vector2i(16,34)],[Vector2i(18,6),Vector2i(23,22)]],
"level6":[[Vector2i(45,16),Vector2i(30,16)],[Vector2i(29,20),Vector2i(3,20)]],
"level7":[[Vector2i(6,19),Vector2i(16,17)],[Vector2i(16,17),Vector2i(25,20)],[Vector2i(25,20),Vector2i(34,16)],[Vector2i(34,16),Vector2i(43,19)]],
"level8":[[Vector2i(43,34),Vector2i(35,16)],[Vector2i(19,19),Vector2i(30,36)]]}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := OS.get_environment("CAMPAIGN_CAPTURE_DIR")
	if out.is_empty():
		quit(2)
		return
	var campaign := root.get_node("Campaign")
	for key in ["skirmish","skirmish_ai","arena","custom_defense","scenario","ai_friendly","scale_on"]:
		campaign.set(key,false)
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").game_speed = 1.0
	root.get_node("Settings").atmosphere = true
	AudioServer.set_bus_mute(0,true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var levels := OS.get_environment("CAMPAIGN_LEVELS")
	var all_passed := true
	for number in range(1,9):
		if not levels.is_empty() and not str(number) in levels.split(","):
			continue
		var folder := out.path_join("level%d"%number)
		DirAccess.make_dir_recursive_absolute(folder)
		campaign.current = number-1
		seed(5088120+number)
		var b = load("res://scenes/main.tscn").instantiate()
		root.add_child(b)
		current_scene = b
		await process_frame
		b.hud._intro_root.hide()
		b._on_intro_done()
		b.set_process(false)
		b.camera.set_process(false)
		for u in b.units:
			u.set_physics_process(false)
		b._grid_build()
		var snapshot := _snapshot(b,number)
		_save(folder.path_join("state.json"),snapshot)
		for view in [{"name":"overview","cell":CENTERS[b.level.id()],"zoom":0.70},
			{"name":"detail","cell":DETAILS[b.level.id()],"zoom":1.15}]:
			b.camera.position = b.to_screen(b.map.cell_to_world(view.cell))
			b.camera.zoom = Vector2.ONE*float(view.zoom)
			b.camera.force_update_scroll()
			await create_timer(2.1).timeout
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(folder.path_join(view.name+".png"))!=OK:
				quit(3)
				return
		if OS.get_environment("CAMPAIGN_VERIFY")=="1":
			all_passed = await _verify(b,number,folder) and all_passed
		print("[campaign_capture] level=",number," units=",snapshot.units.size()," saved")
		b.queue_free()
		await process_frame
		await process_frame
	quit(0 if all_passed else 5)

func _save(path: String,data: Variant) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()

func _snapshot(b,number: int) -> Dictionary:
	var result := {"grid":Array(b.map.grid),"w":b.map.w,"h":b.map.h,"solids":[],"weights":[],"units":[],"routes":[],"decor":b.map.decor}
	for y in range(b.map.h):
		for x in range(b.map.w):
			var c := Vector2i(x,y)
			result.solids.append(b.map.astar.is_point_solid(c))
			result.weights.append([b.map.astar.get_point_weight_scale(c),b.map.astar_guan.get_point_weight_scale(c)])
	for u in b.units:
		result.units.append({"key":u.key,"position":[u.position.x,u.position.y],"hp":u.hp,"faction":u.faction})
	for route in ROUTES[b.level.id()]:
		for team in range(2):
			var nav: AStarGrid2D = b.map.astar if team==0 else b.map.astar_guan
			var a: Vector2i = b.map.nearest_open(route[0])
			var z: Vector2i = b.map.nearest_open(route[1])
			result.routes.append({"from":str(a),"to":str(z),"faction":team,"path":Array(nav.get_id_path(a,z))})
	return result

func _verify(b,number: int,folder: String) -> bool:
	var result := {"routes_reachable":true,"roundtrip_error":0.0,"minimum_derivative":1.0,"walk":false,"select":false,"sample_loaded":b.map.sample_scenery!=null}
	for route in _snapshot(b,number).routes:
		result.routes_reachable = result.routes_reachable and not route.path.is_empty()
	for y in range(b.map.h*2):
		for x in range(b.map.w*2):
			var p := Vector2(x,y)*16.0+Vector2(3.2,5.6)
			var s: Vector2 = b.to_screen(p)
			result.roundtrip_error = maxf(result.roundtrip_error,p.distance_to(b.to_logic(s)))
			result.minimum_derivative = minf(result.minimum_derivative,b.to_screen(p+Vector2.ONE).y-s.y)
	var a: Vector2i = b.map.nearest_open(ROUTES[b.level.id()][0][0])
	var z: Vector2i = b.map.nearest_open(ROUTES[b.level.id()][0][1])
	var path: Array[Vector2i] = b.map.astar.get_id_path(a,z)
	if not path.is_empty():
		# 导航探针隔离静止兵团的相互挤压；建筑阻挡仍完整保留。
		var original_units: Array = b.units.duplicate()
		b.units = b.units.filter(func(u): return u.is_building)
		b._grid_build()
		var probe = b.spawn_at("liang_dao",0,a)
		probe.set_physics_process(false)
		b._set_selection([probe])
		var goal: Vector2 = b.map.cell_to_world(path[mini(path.size()-1,8)])
		probe.order_move(goal)
		probe.passive = true
		probe.set_physics_process(true)
		var start := Time.get_ticks_msec()
		var blocked := false
		while probe.position.distance_to(goal)>6 and Time.get_ticks_msec()-start<16000:
			await physics_frame
			b._grid_build()
			blocked = blocked or b.map.astar.is_point_solid(b.map.world_to_cell(probe.position))
		probe.set_physics_process(false)
		await process_frame
		result.walk = probe.position.distance_to(goal)<=6 and not blocked
		result.walk_distance_remaining = probe.position.distance_to(goal)
		result.walk_hit_solid = blocked
		result.select = b._friendly_at(b.to_screen(probe.position))==probe
		b.camera.position = b.to_screen(probe.position)
		b.camera.zoom = Vector2.ONE*1.3
		b.camera.force_update_scroll()
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("walk.png"))
		b.units = original_units
		b.units.append(probe)
		b._grid_build()
	result.props_blocked = true
	var config = load("res://scripts/campaign_environment.gd")
	for house in config.houses("level%d"%number):
		for dy in range(-1,2):
			for dx in range(-1,2):
				var cell: Vector2i = house[0]+Vector2i(dx,dy)
				result.props_blocked = result.props_blocked and b.map.astar.is_point_solid(cell) and b.map.astar_guan.is_point_solid(cell)
	result.water_level = true
	for y in range(b.map.h):
		for x in range(b.map.w):
			if b.map.t_at(x,y)==0:
				result.water_level = result.water_level and absf(b.map.height_at(b.map.cell_to_world(Vector2i(x,y))))<0.001
	result.boats_in_water = true
	for d in b.map.decor:
		if d[0]=="boat": result.boats_in_water = result.boats_in_water and b.map.t_at(d[1].x,d[1].y)==0
	result.stealth_retained = true
	if number in [1,6]:
		b._stealth_pass()
		var found := 0
		for u in b.units:
			if u.faction==0 and not u.is_building and b.map.t_world(u.position)==3:
				found+=1
				result.stealth_retained = result.stealth_retained and u.hidden_in_reeds
		result.stealth_retained = result.stealth_retained and found>0
	result.courtyards_flat = true
	if number in [2,3,7,8]:
		for house in config.houses("level%d"%number):
			for dy in range(-1,2):
				for dx in range(-1,2):
					result.courtyards_flat = result.courtyards_flat and absf(b.map.height_at(b.map.cell_to_world(house[0]+Vector2i(dx,dy))))<0.001
	# 帧率用不保存截图的稳定时间窗，不能从截图瞬时FPS推断性能。
	b.camera.position = b.to_screen(b.map.cell_to_world(CENTERS[b.level.id()]))
	b.camera.zoom = Vector2.ONE*0.7
	b.camera.force_update_scroll()
	await create_timer(1.5).timeout
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec()-start<2000000:
		await process_frame
		frames+=1
	result.static_fps = frames/(float(Time.get_ticks_usec()-start)/1000000.0)
	if number==7:
		result.taverns = await _check_taverns(b)
	result.passed = result.routes_reachable and result.roundtrip_error<0.01 and result.minimum_derivative>0.1 and result.walk and result.select and result.sample_loaded and result.props_blocked and result.water_level and result.boats_in_water and result.stealth_retained and result.courtyards_flat
	if number==7: result.passed = result.passed and result.taverns.passed
	_save(folder.path_join("checks.json"),result)
	print("[campaign_verify] ",number," ",JSON.stringify(result))
	return result.passed

func _check_taverns(b) -> Dictionary:
	# 使用原武松和原process饮酒判定；每家从主道附近步行至可达门前。
	# 分段定位起点以控制测试时间，不冒称全路线连续真人游玩。
	var level = b.level
	var wu = level.wu
	var old_position: Vector2 = wu.position
	var results := []
	for tavern in level.taverns:
		var c: Vector2i = b.map.world_to_cell(tavern.u.position)
		var direction := 1.0 if c.y<19 else -1.0
		wu.position = b.map.cell_to_world(Vector2i(c.x,19))
		var goal: Vector2 = tavern.u.position+Vector2(0,direction*52)
		wu.order_move(goal)
		wu.passive=true
		wu.set_physics_process(true)
		var start := Time.get_ticks_msec()
		var solid := false
		while not tavern.drunk and Time.get_ticks_msec()-start<12000:
			await physics_frame
			b._grid_build()
			level.process(b,0.0166667)
			solid = solid or b.map.astar.is_point_solid(b.map.world_to_cell(wu.position))
		wu.set_physics_process(false)
		results.append({"cell":str(c),"triggered":tavern.drunk,"hit_solid":solid,"distance":wu.position.distance_to(tavern.u.position)})
	wu.position=old_position
	wu.order_stop()
	b._grid_build()
	return {"passed":level.drunk==4 and results.all(func(r):return r.triggered and not r.hit_solid),"drunk":level.drunk,"approaches":results}
