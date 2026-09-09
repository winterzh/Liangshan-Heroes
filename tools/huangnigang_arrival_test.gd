extends "res://tools/huangnigang_short_test.gd"
## HNA_CASE=live|boundaries|all (default all), HNA_VISUAL=1 for real 1280x720
## frames. HNA_OUT overrides .godot/huangnigang_arrival/<case>[_rendered].
## Live observations never teleport actors or advance the level by direct calls.
## Deliberately frozen/injected boundary fixtures are reported separately.
var arrival_trace: Array=[]
var movers: Dictionary={}
var observed_events: Dictionary={}
var stage_frames: Array=[]
var live_completed:=false
var arrival_boundaries_done:=false
var pre_unload_clean:=true
var last_trace_t:=-1.0
var story_stall_script
var base_fixture_evidence: Dictionary={}

func _xy(v: Vector2) -> Array: return [v.x,v.y]

func _wine_nodes(b) -> Array:
	var found: Array=[]
	for node in b.find_children("*","",true,false):
		var route_key:=String(node.get_meta("campaign_environment_route",""))
		var object_key:=String(node.get_meta("campaign_object",""))
		var fallback:=String(node.get_meta("campaign_environment_fallback_key",""))
		var wine_stall: bool=story_stall_script!=null and node.get_script()==story_stall_script and String(node.get("kind"))=="wine"
		if "wine" in route_key or "wine" in object_key or "wine" in fallback or wine_stall:
			found.append(node)
	return found

func _wine_absent(b) -> bool:
	if not _wine_nodes(b).is_empty(): return false
	if is_instance_valid(b.level.good_sign) or is_instance_valid(b.level.sale_sign): return false
	for item in b.map.decor:
		if not item is Array or item.is_empty(): continue
		if "wine" in String(item[0]): return false
		# The original bug was [market_stall, cell, size, wine]. Its first key
		# contains no 'wine', and StoryStall carries no campaign art metadata.
		if String(item[0])=="market_stall":
			var subtype: String=String(item[3]) if item.size()>3 else "wine"
			if subtype=="wine": return false
	for key in ["taste_wine","distract_yang","drug_scoop","reclaim_scoop","sell_wine"]:
		if b.mission.actions.has(key): return false
	return true

func _observe_mover(b,u,role: String) -> void:
	if not is_instance_valid(u): return
	var uid:=str(u.get_instance_id())
	var t: float=b.mission.total_game_seconds
	if not movers.has(uid):
		movers[uid]={"instance_id":u.get_instance_id(),"key":u.key,"role":role,
			"first_seen_seconds":t,"first_position":_xy(u.position),"first_cell":_xy(Vector2(b.map.world_to_cell(u.position))),
			"last_position":_xy(u.position),"last_seconds":t,"path_distance":0.0,"max_sample_step":0.0,"samples":0,"large_steps":[]}
	var row: Dictionary=movers[uid]
	var previous:=Vector2(float(row.last_position[0]),float(row.last_position[1]))
	var distance: float=u.position.distance_to(previous)
	var dt: float=maxf(0.0,t-float(row.last_seconds))
	row.path_distance=float(row.path_distance)+distance
	row.max_sample_step=maxf(float(row.max_sample_step),distance)
	row.samples=int(row.samples)+1
	# Allow physics-frame scheduling and collision separation, while detecting
	# anything comparable to snapping the whole road distance in one sample.
	if distance>64.0+maxf(120.0,float(u.base_speed))*dt*2.0:
		row.large_steps.append({"seconds":t,"dt":dt,"distance":distance})
	row.last_position=_xy(u.position); row.last_seconds=t

func _observe(b) -> void:
	var l=b.level
	for u in l.convoy: _observe_mover(b,u,"convoy")
	for u in l.bundles: _observe_mover(b,u,"tribute")
	var bai=b.find_unit("bai_sheng")
	if is_instance_valid(bai): _observe_mover(b,bai,"bai")
	for event in ["place_dates","convoy_rested","yang_inquired","yang_saw_merchants","merchant_identity_confirmed","bai_entered","bai_arrived","bring_wine","bai_unloaded"]:
		if b.mission.has_event(event) and not observed_events.has(event): observed_events[event]=b.mission.total_game_seconds
	if not b.mission.has_event("bai_unloaded") and not _wine_absent(b): pre_unload_clean=false
	var t: float=b.mission.total_game_seconds
	if last_trace_t<0 or t-last_trace_t>=0.25:
		last_trace_t=t
		arrival_trace.append({"seconds":t,"stage":l.st,"convoy_count":l.convoy.size(),
			"convoy":l.convoy.map(func(u): return {"id":u.get_instance_id(),"key":u.key,"position":_xy(u.position)}),
			"bai_position":_xy(bai.position) if is_instance_valid(bai) else [],
			"bai_carrying":bool(bai.get_meta("carrying_wine",false)) if is_instance_valid(bai) else false,
			"wine_ground_nodes":_wine_nodes(b).size(),"events":b.mission.events.keys()})

func _observe_until(b,predicate: Callable,seconds: float) -> bool:
	var elapsed:=0.0
	_observe(b)
	while not predicate.call() and elapsed<seconds and b.phase==b.Phase.FIGHT:
		await _wait(0.05)
		elapsed+=0.05
		_observe(b)
	return bool(predicate.call())

func _stage_shot(b,name: String,cell: Vector2i,zoom:=1.0) -> void:
	_observe(b)
	var actual_zoom: float=b.camera.zoom.x if zoom<0 else zoom
	var row:={"stage":name,"seconds":b.mission.total_game_seconds,"camera_cell":_xy(Vector2(cell)),"zoom":actual_zoom,"fixture":false}
	if visual:
		if zoom>0: b.camera.zoom=Vector2.ONE*zoom
		b.center_camera_cell(cell)
		b.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		_observe(b)
		var im:=root.get_texture().get_image()
		check(im.get_size()==Vector2i(1280,720),"arrival screenshot is a real 1280x720 viewport: "+name)
		check(im.save_png(folder.path_join(name+".png"))==OK,"saved live arrival stage "+name)
		row["file"]=name+".png"
		row["image_size"]=[im.get_width(),im.get_height()]
		row["ui_task_rect"]=str(b.mission._panel.get_global_rect())
		row["ui_command_rect"]=str(b.hud._bottom_panel.get_global_rect())
		check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"arrival task panel does not overlap command cards: "+name)
	stage_frames.append(row)

func _arrival_live() -> void:
	var b=await _start("",0)
	var l=b.level
	check(l.get_script().resource_path=="res://scripts/levels/level1_huangnigang_short.gd" and not b._smoke,"arrival test runs the actual short campaign without smoke driver")
	check(l.st==l.MARCH and l.convoy.size()==1 and l.convoy[0]==l.yang,"Yang starts the finite column before the other fourteen appear")
	check(l.actors.size()==7 and l.jujube_carts.size()==7 and b.mission.has_event("place_dates"),"seven merchants and seven carts already rest in the grove")
	check(l.actors.all(func(u): return b.map.world_to_cell(u.position).x<30),"merchants start in the grove rather than entering with the convoy")
	check(b.find_unit("bai_sheng")==null and _wine_absent(b),"Bai, wine stall, wine props and wine interaction points are absent initially")
	var cart_ids: Array=l.jujube_carts.map(func(u): return u.get_instance_id())
	var bundle_ids: Array=l.bundles.map(func(u): return u.get_instance_id())
	await _stage_shot(b,"00_default_merchants",l.camera_start_cell(),-1.0)
	await _stage_shot(b,"01_merchants_waiting",Vector2i(25,18))
	check(await _observe_until(b,func(): return l.convoy.size()>=5,10),"convoy visibly grows through timed entries")
	await _stage_shot(b,"02_convoy_on_east_road",Vector2i(38,20))
	check(await _observe_until(b,func(): return b.mission.has_event("convoy_rested"),65),"the whole convoy and its loads actually reach the rest area")
	await _stage_shot(b,"03_convoy_resting",Vector2i(24,19))
	check(l.convoy.size()==15 and l.convoy.filter(func(u): return u.key=="jun_han").size()==11 and l.convoy.filter(func(u): return u.key=="yu_hou").size()==2 and l.convoy.filter(func(u): return u.key=="lao_duguan").size()==1,"the final convoy has Yang, eleven carriers, two escorts and the steward")
	check(await _observe_until(b,func(): return b.mission.has_event("yang_inquired") and b.mission.has_event("yang_saw_merchants"),12),"Yang walks from the resting column to inspect the merchants")
	check(l.st==l.INQUIRY and _wine_absent(b) and b.find_unit("bai_sheng")==null,"inquiry precedes the wine seller and leaves the real rest scene intact")
	await _stage_shot(b,"04_yang_inquires",Vector2i(24,18),1.1)
	_action(b,b.find_unit("liu_tang"),"answer_yang")
	check(await _observe_until(b,func(): return b.mission.has_event("merchant_identity_confirmed") and is_instance_valid(b.find_unit("bai_sheng")),30),"actual Liu movement and answer introduce Bai after inquiry")
	var bai=b.find_unit("bai_sheng")
	if not is_instance_valid(bai):
		await _dispose(b)
		return
	var bai_origin: Vector2=bai.position
	check(b.map.world_to_cell(bai.position).x>=44 and bai.get_meta("carrying_wine",false) and _wine_absent(b),"Bai appears carrying wine on the far road without pre-existing barrels")
	await _stage_shot(b,"05_bai_far_road",b.map.world_to_cell(bai.position),1.1)
	_action(b,bai,"bring_wine")
	check(await _observe_until(b,func(): return bai.position.distance_to(bai_origin)>120,15) and l.st==l.ARRIVAL and bai.get_meta("carrying_wine",false),"Bai carries the load along a real player-issued path")
	await _stage_shot(b,"06_bai_carrying_uphill",b.map.world_to_cell(bai.position),1.1)
	check(await _observe_until(b,func(): return l.st==l.WINE and b.mission.has_event("bai_unloaded"),45),"Bai reaches the clearing and finishes putting the wine down")
	await _stage_shot(b,"07_wine_put_down",Vector2i(24,22),1.1)
	check(bai.position.distance_to(b.map.cell_to_world(l.WINE_UNLOAD))<=50 and not bai.get_meta("carrying_wine",false),"the same Bai stops carrying only at the unloading place")
	check(pre_unload_clean,"no sampled frame exposes a wine stall, barrels, bowls or wine-use markers before unloading")
	var wine: Array=_wine_nodes(b)
	check(wine.size()==2 and wine.any(func(n): return n.get_meta("campaign_environment_route","")=="wine_buckets") and wine.any(func(n): return n.get_meta("campaign_environment_route","")=="wine_bowls"),"unloading creates exactly one barrel prop and one bowl prop")
	check(is_instance_valid(l.good_sign) and is_instance_valid(l.sale_sign),"the two wine interaction places appear only after unloading")
	check(l.jujube_carts.map(func(u): return u.get_instance_id())==cart_ids and l.bundles.map(func(u): return u.get_instance_id())==bundle_ids,"arrival retains all original carts and tribute load nodes")
	var convoy_rows: Array=movers.values().filter(func(row): return row.role=="convoy")
	check(convoy_rows.size()==15 and convoy_rows.all(func(row): return row.first_cell[0]>=44 and row.path_distance>400 and row.large_steps.is_empty()),"all fifteen observed convoy members really travel from the eastern entrance without road-length jumps")
	convoy_rows.sort_custom(func(a,z): return a.first_seen_seconds<z.first_seen_seconds)
	var spaced:=convoy_rows.size()==15
	for i in range(1,convoy_rows.size()):
		spaced=spaced and float(convoy_rows[i].first_seen_seconds)-float(convoy_rows[i-1].first_seen_seconds)>=0.55
	check(spaced,"each convoy appearance is separated in observed gameplay time")
	var bai_rows: Array=movers.values().filter(func(row): return row.role=="bai")
	check(bai_rows.size()==1 and bai_rows[0].path_distance>400 and bai_rows[0].large_steps.is_empty(),"one Bai instance traverses the road instead of teleporting to a prepared shop")
	var expected: Array=["convoy_rested","yang_inquired","merchant_identity_confirmed","bai_entered","bai_arrived","bai_unloaded"]
	var ordered:=expected.all(func(event): return observed_events.has(event))
	if ordered:
		for i in range(1,expected.size()): ordered=ordered and observed_events[expected[i]]>=observed_events[expected[i-1]]
	check(ordered,"observed events preserve rest, inquiry, answer, seller entry and unloading order")
	live_completed=true
	await _dispose(b)

func _freeze_arrival_fixture(b) -> void:
	b.set_process(false); b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)

func _base_arrival_fixture() -> void:
	# This is deliberately NOT a legacy campaign playthrough. Reuse the real
	# map and units, inject a completed arrival, then invoke the actual base
	# instance so the short chapter's override cannot hide a base MARCH deadlock.
	var b=await _start("",0)
	_freeze_arrival_fixture(b)
	_complete_convoy_fixture(b)
	var original_level=b.level
	var base=load("res://scripts/levels/level1_huangnigang.gd").new()
	for key in ["actors","convoy","bundles","yang","cart","jujube_carts","field_signs","suspicion_sign"]:
		base.set(key,original_level.get(key))
	base.st=base.MARCH
	b.level=base
	check(base.get_script().resource_path=="res://scripts/levels/level1_huangnigang.gd","base fixture invokes the actual base script, not the short subclass")
	for i in range(base.convoy.size()):
		base.convoy[i].order_stop()
		base.convoy[i].position=b.map.cell_to_world(base._convoy_rest_cell(i))
	for i in range(base.bundles.size()):
		base.bundles[i].position=b.map.cell_to_world(base.TOP+Vector2i(i,0))
	var old_top_distance: float=base.yang.position.distance_to(b.map.cell_to_world(base.TOP))
	check(old_top_distance>110.0,"base fixture reproduces the new rest position outside the obsolete TOP arrival radius")
	var convoy_ids: Array=base.convoy.map(func(u): return u.get_instance_id())
	var bundle_ids: Array=base.bundles.map(func(u): return u.get_instance_id())
	base.process(b,0.0)
	check(base.st==base.MARCH and b.mission.has_event("convoy_rested"),"base fixture recognizes all fifteen arrivals and begins the rest beat")
	var stages: Array=[base.st]
	base.process(b,1.0)
	stages.append(base.st)
	check(base.st==base.MARCH,"base fixture does not skip the two-second rest beat")
	base.process(b,1.1)
	stages.append(base.st)
	check(base.st==base.INQUIRY and b.mission.actions.has("answer_yang"),"base fixture advances through its own process to inquiry after resting")
	check(base.convoy.map(func(u): return u.get_instance_id())==convoy_ids and convoy_ids.size()==15 and base.bundles.map(func(u): return u.get_instance_id())==bundle_ids and bundle_ids.size()==3,"base fixture preserves the same finite party and three loads across the transition")
	base.yang.position=b.map.cell_to_world(base.INSPECT) # Explicit arrival injection.
	base.process(b,0.0)
	check(b.mission.has_event("yang_inquired") and b.mission.has_event("yang_saw_merchants") and b.find_unit("bai_sheng")==null and _wine_absent(b),"base fixture permits real inquiry state without prematurely creating the seller or wine scene")
	base_fixture_evidence={"fixture":true,"ordinary_playthrough":false,"script":base.get_script().resource_path,
		"injected_layout":"15 guards at authored rest cells; 3 loads at TOP; Yang later at INSPECT",
		"process_deltas":[0.0,1.0,1.1,0.0],"stages_before_final_inquiry":stages,"old_top_distance":old_top_distance,
		"convoy_count":convoy_ids.size(),"bundle_count":bundle_ids.size(),"events":b.mission.events.keys()}
	b.level=original_level
	await _dispose(b)

func _arrival_boundaries() -> void:
	# These injections check callback and finite-spawn boundaries, not playability.
	var b=await _start("",0)
	var l=b.level
	_freeze_arrival_fixture(b)
	check(_wine_absent(b),"boundary: clean initial scene has no configured or instantiated wine stall")
	b.map.decor.append(["market_stall",Vector2i(23,23),64.0,"wine"])
	check(not _wine_absent(b),"boundary: original explicit wine market_stall configuration is detected")
	b.map.decor.pop_back()
	b.map.decor.append(["market_stall",Vector2i(23,23),64.0])
	check(not _wine_absent(b),"boundary: market_stall without subtype is detected as the production default wine stall")
	b.map.decor.pop_back()
	for subtype in ["inn","goods","lantern"]:
		b.map.decor.append(["market_stall",Vector2i(23,23),64.0,subtype])
		check(_wine_absent(b),"boundary: non-wine stall subtype does not create a false alarm: "+subtype)
		b.map.decor.pop_back()
	var scenery=b.map.sample_scenery
	scenery._add_story_stall(b.map.cell_to_world(Vector2i(23,23)),64.0,"wine")
	var injected_stall=scenery._sprites.back()
	check(not _wine_absent(b) and _wine_nodes(b).has(injected_stall),"boundary: an actual metadata-free StoryStall wine node is detected")
	scenery._sprites.erase(injected_stall)
	injected_stall.free()
	check(_wine_absent(b),"boundary: removing injected original-bug fixtures restores the clean scene")
	l.on_mission_action(b,"bring_wine",b.find_unit("chao_gai"))
	check(_wine_absent(b) and b.find_unit("bai_sheng")==null,"boundary: an early invalid wine callback cannot introduce seller or shop")
	var chao=b.find_unit("chao_gai")
	chao.position=l.yang.position+Vector2(24,0)
	b.select_single(chao,false)
	b._issue_order(b.to_screen(l.yang.position),false); orders+=1
	l.process(b,0)
	check(l.force_started and l.st==l.FORCE and l.convoy.size()<15,"boundary: an early real attack order changes the partially entered convoy to force")
	for i in range(18):
		l.process(b,1.0)
		for u in b.units: u.set_physics_process(false)
	check(l.convoy.size()==15 and l.convoy.all(func(u): return not u.passive),"boundary: early force admits the remaining finite convoy as combatants")
	check(_wine_absent(b) and not b.mission.has_event("bring_wine") and not b.mission.has_event("bai_unloaded"),"boundary: interrupted entry never builds the wine scene")
	var ids: Array=l.convoy.map(func(u): return u.get_instance_id())
	l.convoy[0].resolve_story("subdued")
	for i in range(5): l._spawn_next_convoy_member(b)
	l.process(b,20.0)
	check(l.convoy.map(func(u): return u.get_instance_id())==ids and l.convoy[0].story_outcome=="subdued","boundary: further entry ticks neither duplicate nor revive the original convoy")
	await _dispose(b)
	b=await _start("",0); l=b.level
	_freeze_arrival_fixture(b)
	var fallen_bai=l._ensure_bai(b,true)
	fallen_bai.set_physics_process(false)
	var fallen_id: int=fallen_bai.get_instance_id()
	l.st=l.ARRIVAL
	fallen_bai.set_meta("carrying_wine",true)
	b.mission.mark("merchant_identity_confirmed","explicit early-death boundary fixture")
	fallen_bai.take_damage(10000,null,false,true)
	check(fallen_bai.hp<=0 and l.force_started and b._gameplay_rng_issue.is_empty(),"boundary: seller death changes route without fabricating a required-entity failure")
	var bai_instances: Array=l.actors.filter(func(u): return is_instance_valid(u) and u.key=="bai_sheng")
	check(bai_instances.size()==1 and bai_instances[0].get_instance_id()==fallen_id and b.find_unit("bai_sheng")==null and _wine_absent(b),"boundary: dead Bai is never respawned by the force fallback and never unloads wine")
	var actor_count: int=l.actors.size()
	fallen_bai.queue_free()
	await process_frame
	await process_frame
	var replacement_bai=l._ensure_bai(b,false)
	check(not is_instance_valid(replacement_bai) and l.actors.size()==actor_count and b.find_unit("bai_sheng")==null and b._gameplay_rng_issue.is_empty(),"boundary: freeing the original dead Bai node still cannot create a replacement seller")
	await _dispose(b)
	b=await _start("",0); l=b.level
	_freeze_arrival_fixture(b)
	var bai=l._ensure_bai(b,true)
	bai.set_physics_process(false)
	bai.set_meta("carrying_wine",true)
	l.st=l.ARRIVAL
	b.mission.mark("merchant_identity_confirmed","explicit frozen unloading boundary fixture")
	b.mission.begin("wine_arrival","fixture","Explicit frozen boundary fixture, not a live route")
	b.mission.add_action("bring_wine","白胜·挑酒到冈边",l.WINE_UNLOAD,["bai_sheng"],1.5,40.0)
	l.on_mission_action(b,"bring_wine",bai)
	check(_wine_absent(b) and bai.get_meta("carrying_wine",false),"boundary: seller cannot unload remotely without a completed command")
	bai.position=b.map.cell_to_world(l.WINE_UNLOAD)
	l.on_mission_action(b,"bring_wine",bai)
	check(_wine_absent(b) and not b.mission.has_event("bai_unloaded"),"boundary: merely occupying the destination does not forge completed unloading")
	_action(b,bai,"bring_wine"); b.mission.tick(1.6)
	check(l.st==l.WINE and b.mission.has_event("bai_unloaded") and _wine_nodes(b).size()==2,"boundary: completed at-destination player interaction creates the wine scene")
	var wine_ids: Array=_wine_nodes(b).map(func(n): return n.get_instance_id())
	l.on_mission_action(b,"bring_wine",bai)
	l._ensure_bai(b,true)
	check(_wine_nodes(b).map(func(n): return n.get_instance_id())==wine_ids and l.actors.filter(func(u): return u.key=="bai_sheng").size()==1,"boundary: repeated arrival/unload callbacks retain the same seller and props")
	var old_scene: int=b.get_instance_id()
	l.bundles[0].take_damage(10000,null,false,true)
	check(b.phase==b.Phase.END and not l.victory,"boundary: a destroyed original load causes an explicit loss")
	var retry: Array=b.hud.find_children("*","Button",true,false).filter(func(n): return n.text=="重打本关")
	if retry.size()==1: retry[0].pressed.emit()
	await until(func(): return is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_scene,10)
	b=current_scene
	check(retry.size()==1 and is_instance_valid(b) and b.get_instance_id()!=old_scene,"boundary: actual restart button creates a fresh chapter scene")
	if is_instance_valid(b):
		check(b.level.id()=="level1" and b.level.bundles.size()==3 and b.level.delivered==0 and b.find_unit("bai_sheng")==null and _wine_absent(b),"boundary: restart removes late seller and wine props and restores the original cargo count")
		check(not b.mission.has_event("merchant_identity_confirmed") and not b.mission.has_event("bai_unloaded"),"boundary: restart does not inherit answered inquiry or unloaded wine events")
		await _dispose(b)
	await _base_arrival_fixture()
	arrival_boundaries_done=true

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	# Resolve the inner renderer class only after autoload initialization.
	story_stall_script=load("res://scripts/campaign_scenery.gd").StoryStall
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var selected:=OS.get_environment("HNA_CASE")
	if selected.is_empty(): selected="all"
	visual=OS.get_environment("HNA_VISUAL")=="1"
	if visual:
		check(DisplayServer.get_name()!="headless","arrival visual run uses a real rendering device")
		if DisplayServer.get_name()=="headless": visual=false
	Engine.time_scale=1.0 if visual else 3.0
	folder=OS.get_environment("HNA_OUT")
	if folder.is_empty(): folder="res://.godot/huangnigang_arrival/"+selected+("_rendered" if visual else "")
	DirAccess.make_dir_recursive_absolute(folder)
	if visual:
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1280,720)
		root.content_scale_size=root.size
		DisplayServer.window_set_size(root.size)
	if selected in ["all","live"]: await _arrival_live()
	if selected in ["all","boundaries"]: await _arrival_boundaries()
	var passed:=selected in ["all","live","boundaries"] and failures.is_empty() and (live_completed if selected!="boundaries" else true) and (arrival_boundaries_done if selected!="live" else true)
	var report:={"passed":passed,"checks":checks,"failures":failures,"orders":orders,"live_completed":live_completed,
		"boundary_fixtures_completed":arrival_boundaries_done,"boundary_fixtures_are_live_gameplay":false,
		"base_arrival_fixture":base_fixture_evidence,"visual":visual,"frames":stage_frames,"observed_events":observed_events,"movers":movers.values(),"trace":arrival_trace}
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("[hna-result] ",checks," checks, failures=",failures)
	quit(0 if passed else 1)
