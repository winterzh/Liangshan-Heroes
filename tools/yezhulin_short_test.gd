extends "res://tools/zhujiazhuang_rts_test.gd"
## YF_CASE=north|south|late|force|boundaries|all; YF_VISUAL=1 saves live views.
## Live routes use player orders only. Boundary injections are explicitly labelled.
var cases: Array=[]
var visual := false
var folder := "res://.godot/yezhulin_short"
var spacing: Array=[]

func _until(predicate: Callable,seconds: float) -> bool:
	var t := 0.0
	while not predicate.call() and t<seconds:
		await _wait(0.1)
		t+=0.1
	return bool(predicate.call())

func _action_done(b,actor,key: String,seconds := 50.0) -> bool:
	if not alive(actor) or not b.mission.actions.has(key): return false
	var event := "action:%s:%s"%[b.mission.stage_id,key]
	_action(b,actor,key)
	var t := 0.0
	var max_gap := 0.0
	var widest: Array=[]
	var initial_gap := 0.0
	var assembly_time := -1.0
	var path_max_gap := 0.0
	while not b.mission.has_event(event) and b.phase!=b.Phase.END and t<seconds:
		if key in ["rest_stop","leave_forest"]:
			var current_gap := 0.0
			for member in b.level._escort_group():
				var gap: float=member.position.distance_to(actor.position)
				current_gap=maxf(current_gap,gap)
				if gap>max_gap:
					max_gap=gap
					widest=[t,member.key,member.position,actor.position]
			if t==0.0: initial_gap=current_gap
			if assembly_time<0.0 and current_gap<=96: assembly_time=t
			if assembly_time>=0.0: path_max_gap=maxf(path_max_gap,current_gap)
		await _wait(0.1); t+=0.1
	if key in ["rest_stop","leave_forest"]:
		spacing.append({"action":key,"max_gap":max_gap,"initial_gap":initial_gap,"assembly_seconds":assembly_time,"path_max_gap":path_max_gap,"widest":widest})
		print("[yf-spacing] ",key," ",max_gap," ",widest)
		# Rescue preserves actual positions. Allow real walking into formation,
		# then retain the existing tight convoy bound; never teleport the actors.
		check(assembly_time>=0 and assembly_time<=3 and path_max_gap<=96,"escort assembles within 3 seconds and maintains 96-unit spacing during "+key)
	if not b.mission.has_event(event):
		print("[yf-timeout] ",key," ",b.level.st," ",b.mission.active_action_id," group=",b.level._escort_group().map(func(u): return [u.key,b.map.world_to_cell(u.position),u._state,u.mission_order_token,u._path_i,u._path.size()]))
	return b.mission.has_event(event)

func _shot(b,name: String,cell: Vector2i) -> void:
	if not visual: return
	b.camera.zoom=Vector2.ONE
	b.center_camera_cell(cell)
	await process_frame
	await RenderingServer.frame_post_draw
	if b.phase==b.Phase.FIGHT:
		check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"objective panel avoids command cards at "+str(root.size))
		check(b.mission._buttons.get_child(-1).get_global_rect().end.y<=b.mission._scroll.get_global_rect().end.y+1,"last short-chapter control is visible at "+str(root.size))
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"saved live "+name)

func _live(name: String) -> void:
	spacing=[]
	var b=await _start("",5)
	var l=b.level
	check(l.id()=="level6" and not b.economy and not b._smoke,name+" starts the actual short chapter without smoke driver")
	var lu_start: Vector2=l.lu.position
	var serial: int=l.lu._order_serial
	b.mission._buttons.get_child(0).pressed.emit()
	check(b.selection==[l.lu] and l.lu._order_serial==serial and l.lu.position==lu_start,"selection shortcut selects without walking")
	await _shot(b,name+"_start",Vector2i(39,20))
	if name=="late":
		await _until(func(): return l.st==l.RESCUE or b.phase==b.Phase.END,30)
		check(l.st==l.RESCUE and b.phase==b.Phase.FIGHT and l.shadow_route=="lost_trail" and l.exec_timer>20,"falling behind leaves a real final rescue window")
	elif name=="force":
		b.select_single(l.lu,false)
		b._issue_order(b.to_screen(l.escorts[0].position),false)
		orders+=1
		await _until(func(): return l.st==l.CARE or b.phase==b.Phase.END,15)
	else:
		_click(b,[l.lu],Vector2i(34,16 if name=="north" else 25))
		await _until(func(): return l.st==l.RESCUE or b.phase==b.Phase.END,30)
		check(l.st==l.RESCUE and l.shadow_route==("north_pines" if name=="north" else "south_reeds"),name+" follows its route through actual movement")
	if name=="force":
		var t := 0.0
		while l.st==l.CARE and b.phase==b.Phase.FIGHT and t<40:
			var threats: Array=l.escorts.filter(func(u): return alive(u) and u.faction==1)
			if not threats.is_empty():
				if not is_instance_valid(l.lu._target) or l.lu._target not in threats:
					b.select_single(l.lu,false); b._issue_order(b.to_screen(threats[0].position),false); orders+=1
			else:
				var patient=l.lin_freed if is_instance_valid(l.lin_freed) else l.lin_bound
				if patient!=null and l.lu.position.distance_to(patient.position)>80:
					_click(b,[l.lu],b.map.world_to_cell(patient.position)+Vector2i(0,-1))
			await _wait(0.5); t+=0.5
		check(l.st==l.ESCAPE and l.escorts.all(func(u): return alive(u) and u.faction==0),"early force subdues both actual guards, returns to prisoner and frees him locally")
	else:
		check(await _action_done(b,l.lu,"intercept",25),name+" intercepts using an actual right-click action")
		await _until(func(): return l.st==l.ESCAPE or b.phase==b.Phase.END,12)
	check(l.st==l.ESCAPE and l.lin_freed!=null,name+" reaches player-controlled escort")
	if l.st!=l.ESCAPE or l.lin_freed==null:
		cases.append({"route":name,"failed_stage":l.st,"events":b.mission.events.keys()})
		await _dispose(b); return
	check(l.lin_freed.is_noncombat and l.lin_freed.atk==0 and l.lin_freed.aura=="","wounded Lin cannot fight or grant combat auras")
	check(b.mission.actions.has("rest_stop") and b.mission.actions.has("leave_forest"),"rest and direct group exit are available together")
	var group: Array=l._escort_group()
	var positions: Array=group.map(func(u): return u.position)
	await _wait(2)
	check(range(group.size()).all(func(i): return group[i].position.distance_to(positions[i])<3),"rescued party waits without invented movement")
	await _shot(b,name+"_choice",b.map.world_to_cell(l.lin_freed.position))
	if name=="north":
		_click(b,[l.lin_freed],l.REST)
		await _wait(0.8)
		b.select_single(l.lu,false); b._order_stop()
		await _wait(0.2)
		var stopped: Array=group.map(func(u): return u.position)
		await _wait(1)
		check(range(group.size()).all(func(i): return group[i].position.distance_to(stopped[i])<2),"stopping one selected companion stops the whole escort")
	if name in ["north","south"]:
		check(await _action_done(b,l.lin_freed,"rest_stop"),name+" gives one real order for four-person rest")
		check(l.rest_reached and l._full_group_near(b.map.cell_to_world(l.REST),176),"rest counts only when the real party arrives")
		await _shot(b,name+"_rest",l.REST)
	# Early force frees Lin near the eastern entrance, leaving the longest walk.
	# The previous 70-second observation ended shortly before actual completion.
	check(await _action_done(b,l.lin_freed,"leave_forest",90),name+" gives a separate real exit order")
	await _until(func(): return b.phase==b.Phase.END,8)
	check(l.victory and b.mission.has_event("yezhulin_victory"),name+" escorts the living party to victory")
	print("[yf-party] ",name," ",group.map(func(u): return [u.key,b.map.world_to_cell(u.position),u._state,u._order_serial]))
	var result: Dictionary=b.mission.result_snapshot(l.victory)
	if name in ["north","south"]: check(result.story_complete,name+" completes all three optional story goals")
	else: check(not l.rest_reached and not result.story_complete,name+" direct exit does not fabricate rest credit")
	await _shot(b,name+"_result",l.EXIT_W)
	cases.append({"route":name,"orders":orders,"seconds":b.mission.total_game_seconds,"result":result,"events":b.mission.events.keys(),"spacing":spacing.duplicate(true),"hp":group.map(func(u): return [u.key,u.hp])})
	await _dispose(b)

func _boundaries() -> void:
	var b=await _start("",5)
	var l=b.level
	await _until(func(): return b.phase==b.Phase.END,50)
	check(not l.victory and b.mission.has_event("yezhulin_missed_rescue"),"no input eventually fails after the visible rescue deadline")
	var old_id: int=b.get_instance_id()
	var retry=b.hud.find_children("*","Button",true,false).filter(func(node): return node.text=="重打本关")
	check(retry.size()==1,"defeat offers one actual restart button")
	if retry.size()==1:
		retry[0].pressed.emit()
		await _until(func(): return current_scene!=null and current_scene.get_instance_id()!=old_id,5)
		b=current_scene; l=b.level
		check(l.id()=="level6" and not l.victory and not l.tracking_done and not l.rest_reached and l.escort_orders.is_empty(),"actual restart reloads fresh chapter state")
	await _dispose(b)
	b=await _start("",5); l=b.level
	# Explicit position/time fixture: follow recovery and suspicion are separate.
	for u in b.units: u.set_physics_process(false)
	l.lin_freed.position=b.map.cell_to_world(l.WATCH)
	for i in range(l.escorts.size()): l.escorts[i].position=b.map.cell_to_world(l.WATCH+Vector2i(i*2-1,-1))
	l.process(b,0)
	check(l.shadow_route=="lost_trail" and b.phase==b.Phase.FIGHT,"falling behind is an actionable warning, not instant failure")
	l.lu.position=b.map.cell_to_world(l.PINE)+Vector2(0,220)
	l.process(b,0)
	check(l.shadow_route=="south_reeds" and b.mission.has_event("shadow_recovered"),"returning before the pine checkpoint restores a real shadow route")
	l.lu.position=l.escorts[0].position+Vector2(72,0)
	l.process(b,0.9)
	check(l.shadow_cautioned and not l.shadow_warning,"first close approach warns before full exposure")
	l.lu.position=b.map.cell_to_world(l.PINE)+Vector2(0,220)
	l.process(b,1)
	check(not l.shadow_warning and l.shadow_attention==0,"retreat from first warning sheds suspicion")
	await _dispose(b)
	b=await _start("",5); l=b.level
	# Explicit care fixture isolates physical proximity, reposition and death edges.
	for u in b.units: u.set_physics_process(false)
	l._begin_open_rescue(b,"boundary fixture")
	for guard in l.escorts: guard.resolve_story("subdued")
	var prisoner_at: Vector2=l.lin_bound.position
	l.lu.position=prisoner_at+Vector2(200,0)
	l.process(b,5)
	check(l.lin_freed==null,"defeating guards remotely cannot free a distant prisoner")
	l.lu.position=prisoner_at+Vector2(50,0)
	l.process(b,2)
	check(l.lin_freed!=null and l.lin_freed.position.distance_to(prisoner_at)<1,"untying preserves the actual prisoner location")
	var before: Array=([l.lu,l.lin_freed]+l.escorts).map(func(u): return u.position)
	l.process(b,3)
	check(l.st==l.ESCAPE and range(4).all(func(i): return ([l.lu,l.lin_freed]+l.escorts)[i].position==before[i]),"finishing care does not teleport people into formation")
	l.lin_freed.order_move(b.map.cell_to_world(l.EXIT_W))
	l._enforce_post_rescue_escort_control(b)
	check(l.lin_freed._path.is_empty() and b.mission.has_event("post_rescue_auto_move_blocked"),"unrequested script movement is still rejected after the route authorization fix")
	# Retry must not consume rest or healing while one living companion is missing.
	l.lin_freed.position=b.map.cell_to_world(l.REST)
	var hp: float=l.lin_freed.hp
	b.mission.actions.rest_stop.done=true
	l.on_mission_action(b,"rest_stop",l.lin_freed)
	check(not l.rest_reached and not b.mission.actions.rest_stop.done and l.lin_freed.hp==hp,"incomplete rest is retryable and gives no premature healing")
	# Explicit collision-drift fixture: tolerance is only for progress after arrival.
	for u in l._escort_group(): u.position=b.map.cell_to_world(l.REST)
	l.lin_freed.position+=Vector2(55,0)
	_action(b,l.lin_freed,"rest_stop")
	b.mission._try_manual_action()
	check(b.mission.active_action_id=="","settle margin cannot start a task outside its 48-unit arrival range")
	l.lin_freed.position=b.map.cell_to_world(l.REST)+Vector2(47,0)
	b.mission._try_manual_action()
	l.lin_freed.position+=Vector2(8,0)
	b.mission.tick(0.1)
	check(b.mission.active_action_id=="rest_stop" and b.mission._progress>0,"small companion collision drift preserves an already-started escort action")
	b.select_single(l.lin_freed,false)
	b._order_stop()
	check(b.mission.active_action_id=="" and not l.rest_reached,"actual player stop still cancels an action within the settle margin")
	# A genuinely dead guard is a missed optional, not an impossible four-person core.
	l.escorts[0].defeat_outcome=""
	l.escorts[0].take_damage(10000,null,false,true)
	for u in l._escort_group(): u.position=b.map.cell_to_world(l.EXIT_W)
	l.on_mission_action(b,"leave_forest",l.lin_freed)
	l.process(b,0)
	check(l.victory and not b.mission.result_snapshot(true).story_complete,"survivors can leave without pretending a dead guard survived")
	await _dispose(b)
	b=await _start("",5); l=b.level
	l.st=l.ESCAPE # Explicitly reproduce the former post-rescue death softlock.
	l.lu.take_damage(10000,null,false,true)
	check(b.phase==b.Phase.END and not l.victory,"Lu death after rescue clearly fails instead of leaving impossible escort")
	await _dispose(b)
	for mode in ["skirmish","skirmish_ai"]:
		b=await _start(mode)
		check(b._defs.lin_chong==Defs.UNITS.lin_chong,mode+" retains its normal combat Lin Chong")
		await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	visual=OS.get_environment("YF_VISUAL")=="1" and DisplayServer.get_name()!="headless"
	var selected := OS.get_environment("YF_CASE")
	if selected=="": selected="all"
	folder+="/"+selected+("_rendered" if visual else "")
	if visual and OS.get_environment("YF_SIZE")=="1280": folder+="_1280"
	DirAccess.make_dir_recursive_absolute(folder)
	if visual:
		root.size=Vector2i(1280,720) if OS.get_environment("YF_SIZE")=="1280" else Vector2i(1440,900)
		DisplayServer.window_set_size(root.size)
	Engine.time_scale=4
	for name in ["north","south","late","force"]:
		if selected in ["all",name]: await _live(name)
	if selected in ["all","boundaries"]: await _boundaries()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"actual player routes; separately labelled injected boundaries, not human fun or performance acceptance"},"\t"))
	print("[yezhulin-short-result] ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() and checks>0 else 1)
