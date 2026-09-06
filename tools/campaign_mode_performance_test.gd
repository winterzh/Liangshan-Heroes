extends SceneTree
## Modes are checked in a headless process. Performance requires an actual renderer.
## Performance fixtures use current RTS deployments and actual combat orders.
## Zhu gets labelled ordinary reinforcements; Gao's first existing wave is sent
## early. Neither fixture is a paid-production or complete playthrough test.
const CAMPAIGN_KIT := ["mengzhou_punch","mengzhou_step","mengzhou_kick","mengzhou_breath"]
const ARENA_KIT := ["wu_tigers","wu_wine","wu_blades","wu_drunkgod"]
const DIRECTIONS := ["se","sw","ne","nw"]
const P95_FRAME_MS_LIMIT := 16.7
const P99_FRAME_MS_LIMIT := 33.3
const P95_REGRESSION_LIMIT := 1.10
const CONFIRMED_BASELINE := "res://qa/campaign_runtime/confirmed/runtime_performance.json"
var failures: Array[String] = []
var report := {"mode_checks":[],"samples":[]}
var output := ""
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, name: String) -> void:
	print("[runtime-check] ","PASS " if ok else "FAIL ",name)
	report.mode_checks.append({"name":name,"passed":ok})
	if not ok: failures.append(name)
func _save_hash() -> String:
	var path := "user://campaign.cfg"
	return FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"
func _start(id: String, arena := false):
	var c = root.get_node("Campaign")
	c.arena=arena; c.skirmish=false; c.skirmish_ai=false; c.custom_defense=false; c.scenario=false
	c.scale_on=false; c.ai_friendly=false
	c.current=c.index_for_id(id)
	seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b); current_scene=b
	await process_frame
	b.hud._intro_root.hide(); b._on_intro_done(); b.hud._on_start_pressed()
	return b
func _dispose(b, verify := false) -> void:
	var scene_ref=weakref(b)
	var map_ref=weakref(b.map)
	var unit_ref=weakref(b.units[0]) if not b.units.is_empty() else null
	b.queue_free(); await process_frame; await process_frame
	if verify:
		check(scene_ref.get_ref()==null and map_ref.get_ref()==null and (unit_ref==null or unit_ref.get_ref()==null),"previous scene, map and units actually freed")
func _texture_info(tex) -> Dictionary:
	if tex==null: return {"missing":true}
	var source: String=tex.resource_path
	var region := ""
	if tex is AtlasTexture:
		source=tex.atlas.resource_path
		region=str(tex.region)
	var img=tex.get_image()
	return {"source":source,"region":region,"size":str(tex.get_size()),"pixels":img.get_data().hex_encode().sha256_text() if img!=null else "unavailable"}
func _snapshot(b, u) -> Dictionary:
	var art=root.get_node("Art")
	b._set_selection([u]); b.hud.update_selection_panel([u])
	var animations := {}
	for state in ["idle","walk","attack","hurt","down"]:
		for direction in DIRECTIONS:
			var frames: Array=art.unit_anim_frames(u.key,state,direction,u.art_variant)
			animations[state+"|"+direction]={"count":frames.size(),"first":_texture_info(frames[0]) if not frames.is_empty() else {"missing":true}}
	return {"mode":b.level.id(),"variant":u.art_variant,"movement":u.movement_profile,
		"skills":u.ability_slots.map(func(s): return s.id),"ranks":u.ability_slots.map(func(s): return s.rank),
		"portrait":_texture_info(b.hud._port_tex.texture),"animations":animations,"ability_table_has_mengzhou":b._abilities.has("mengzhou_punch")}
func _check_land_move(b,u,label: String) -> void:
	var start: Vector2=u.position
	var cell=b.map.world_to_cell(start)+Vector2i(3,0)
	u.order_move(b.map.cell_to_world(b.map.nearest_open(cell,"land")))
	var path_valid: bool=not u._path.is_empty()
	for point in u._path:
		path_valid=path_valid and b.map.is_open_world(point,"land")
	for i in range(150):
		await physics_frame
		if u.position.distance_to(start)>35.0: break
	check(u.movement_profile=="land" and path_valid and u.position.distance_to(start)>20.0 and b.map.is_open_world(u.position,"land"),label+" actual land movement")
	u.order_stop()
func _mode_check() -> void:
	var definitions=load("res://scripts/defs.gd")
	var original: Dictionary=definitions.UNITS.wu_song.duplicate(true)
	var b=await _start("level7")
	var first: Dictionary=_snapshot(b,b.level.wu)
	check(first.variant=="wu_song_mengzhou" and first.skills==CAMPAIGN_KIT and first.ability_table_has_mengzhou,"campaign uses Mengzhou appearance and four fist skills")
	check(first.portrait.source=="res://assets/campaign/portraits/wu_song_mengzhou.png","campaign HUD portrait uses same variant")
	var directions_unique := {}
	for direction in DIRECTIONS:
		var entry: Dictionary=first.animations["attack|"+direction]
		check(entry.count>0 and entry.first.source=="res://assets/campaign/anim/wu_song_mengzhou_attack_%s.png"%direction,"campaign attack cache is keyed by "+direction)
		if not entry.first.get("missing",false): directions_unique[entry.first.pixels]=true
	check(directions_unique.size()==4,"four attack directions contain distinct bitmap pixels")
	await _check_land_move(b,b.level.wu,"campaign first")
	# Leave a terminal state and cooldown behind; neither may leak into the next instance.
	b.level.wu.ability_slots[0].cd_t=77.0
	b.level.wu.resolve_story("subdued")
	await _dispose(b,true)
	b=await _start("level7",true)
	check(b.level.id()=="arena" and b.mission==null,"arena constructs its own sandbox scene")
	check(b.queue_train(b.level.hall,"wu_song",false),"arena recruits Wu Song through normal training queue")
	var wu=b.find_unit("wu_song")
	for i in range(180):
		if wu!=null: break
		await process_frame
		wu=b.find_unit("wu_song")
	check(wu!=null,"arena training creates Wu Song")
	var middle := {}
	if wu!=null:
		middle=_snapshot(b,wu)
		check(middle.variant=="" and middle.skills==ARENA_KIT and not middle.ability_table_has_mengzhou,"arena restores original appearance and four original skills")
		check(middle.portrait.pixels!=first.portrait.pixels and not middle.portrait.source.begins_with("res://assets/campaign/"),"arena HUD portrait does not reuse Mengzhou portrait")
		check(not middle.animations["walk|se"].first.get("source","").begins_with("res://assets/campaign/") and middle.animations["walk|se"].count>0,"arena animation uses legacy cache despite warmed campaign cache")
		check(wu.story_outcome=="" and wu.ability_slots[0].cd_t==0,"arena has no captured state or old cooldown")
		await _check_land_move(b,wu,"arena")
	await _dispose(b,true)
	b=await _start("level7")
	var last: Dictionary=_snapshot(b,b.level.wu)
	check(last==first,"returning campaign restores identical portrait, direction caches, skills and ranks")
	check(b.level.wu.story_outcome=="" and b.level.wu.ability_slots[0].cd_t==0,"returning campaign has fresh state and cooldowns")
	check(definitions.UNITS.wu_song==original and not definitions.ABILITIES.has("mengzhou_punch"),"mode overrides did not mutate global definitions")
	await _check_land_move(b,b.level.wu,"campaign return")
	report["mode_snapshots"]=[first,middle,last]
	await _dispose(b,true)
func _counts(b) -> Dictionary:
	var total := 0
	var active := 0
	var shown := 0
	var in_view := 0
	var attacking := 0
	for u in b.units:
		if not is_instance_valid(u): continue
		total+=1
		if u.hp>0 and u.story_outcome=="" and not u.is_building and not u.is_resource:
			active+=1
			if u._lunge>0.0: attacking+=1 # Both melee and ranged attacks use the production swing window.
			if u.visible and u.is_visible_in_tree(): shown+=1
			if u.visible and u.is_visible_in_tree() and b.unit_visual_active(u.position): in_view+=1
	return {"scene_units":total,"active_units":active,"visible_nodes":shown,"in_camera_activity_region":in_view,"attacking_units":attacking}
func _camera(b,cell: Vector2i,zoom: float) -> void:
	b.camera.set_process(false)
	b.camera.set_process_unhandled_input(false)
	b.camera._user_input_t=1.0e12
	b.camera.offset=Vector2.ZERO; b.camera.rotation=0.0; b.camera._shake=0.0
	b.camera.position=b.to_screen(b.map.cell_to_world(cell)); b.camera.zoom=Vector2.ONE*zoom
	b.camera.force_update_scroll()

func _combatant(u) -> bool:
	return is_instance_valid(u) and u.hp>0.0 and u.story_outcome=="" and not u.is_building and not u.is_resource and not u.is_worker and not u.is_noncombat

func _injured(group: Array) -> bool:
	return group.any(func(u): return is_instance_valid(u) and u.hp<u.max_hp)

func _injured_near(group: Array,point: Vector2,radius: float) -> bool:
	return group.any(func(u): return is_instance_valid(u) and u.hp<u.max_hp and u.position.distance_to(point)<=radius)

func _fixture_order(b,army: Array,cell: Vector2i) -> void:
	b.select_members(army,false)
	b.minimap_order(b.map.cell_to_world(cell),true)

func _prepare_zhu(b) -> bool:
	var current_level: bool=b.level.get_script().resource_path.ends_with("level3_zhujiazhuang_rts.gd")
	check(current_level,"Zhu fixture enters current persistent RTS chapter")
	if not current_level: return false
	var initial: Dictionary=_counts(b)
	# Keep the defeat-critical commander at the authored camp. The old fixture
	# sent Song Jiang alone ahead of the formation and ended during the window.
	var commander_origin: Vector2=b.level.song.position
	b.level.song.order_hold_position()
	var army: Array=b.units.filter(func(u): return _combatant(u) and u.faction==0 and u.key!="song_jiang")
	var reinforcement_cells: Array=[]
	for i in range(20):
		var cell: Vector2i=b.map.nearest_open(b.level.MAIN_GATE+Vector2i(5+i%4,-3+i/4),"land")
		var u=b.spawn_at("liang_gong" if i%3==2 else "liang_qiang",0,cell)
		army.append(u)
		reinforcement_cells.append([u.key,cell.x,cell.y])
	var gate_hp: float=b.level.gate.hp
	var gate_point: Vector2=b.level.gate.position
	_fixture_order(b,army,b.level.MAIN_GATE)
	Engine.time_scale=4.0
	var deadline:=Time.get_ticks_msec()+60000
	while b.phase==b.Phase.FIGHT and Time.get_ticks_msec()<deadline:
		if _injured_near(army,gate_point,240.0) or not is_instance_valid(b.level.gate) or b.level.gate.hp<gate_hp: break
		await physics_frame
	Engine.time_scale=1.0
	var contacted: bool=_injured_near(army,gate_point,240.0) or not is_instance_valid(b.level.gate) or b.level.gate.hp<gate_hp
	var ready: bool=contacted and b.phase==b.Phase.FIGHT
	report["zhu_rts_fixture"]={"scope":"current authored combat troops plus 20 explicitly spawned ordinary reinforcements attack main gate; Song Jiang holds at camp; live enemies, economy and damage; not paid production or a complete route",
		"level_script":b.level.get_script().resource_path,"initial":initial,"at_contact":_counts(b),
		"contact_seen":contacted,"phase":int(b.phase),"stage":b.level.stage,"setup_time_scale":4.0,"ready":ready,
		"ordinary_reinforcement_cells":reinforcement_cells,"commander_hold_position":[commander_origin.x,commander_origin.y],
		"gate_hp_before":gate_hp,"gate_hp_at_contact":b.level.gate.hp if is_instance_valid(b.level.gate) else 0.0,
		"army_at_contact":army.filter(func(u): return is_instance_valid(u)).map(func(u): return {"key":u.key,"hp":u.hp,"max_hp":u.max_hp,"distance_to_gate":u.position.distance_to(gate_point)})}
	check(ready,"Zhu ordinary reinforcement fixture reaches actual gate combat before sample")
	return ready

func _prepare_gao(b) -> bool:
	var current_level: bool=b.level.get_script().resource_path.ends_with("level5_gao_rts.gd")
	check(current_level,"Gao fixture enters current persistent RTS chapter")
	if not current_level: return false
	var initial: Dictionary=_counts(b)
	var land: Array=b.units.filter(func(u): return _combatant(u) and u.faction==0 and u.movement_profile=="land" and u.key!="song_jiang")
	var water: Array=b.units.filter(func(u): return _combatant(u) and u.faction==0 and u.movement_profile=="water" and u.key!="liu_tang_fireboat")
	_fixture_order(b,land,b.level.LAND_FRONT)
	_fixture_order(b,water,b.level.SEA_FRONT)
	# Current authoring already deploys all expeditions. Dispatch the first one
	# early without creating units, changing prices, pausing AI or bypassing damage.
	b.level._send_wave(b,0)
	var observed_land: Array=land+b.level.land_groups[0]
	var observed_water: Array=water+b.level.water_groups[0]
	Engine.time_scale=4.0
	var deadline:=Time.get_ticks_msec()+60000
	var land_contact := false
	var water_contact := false
	while b.phase==b.Phase.FIGHT and Time.get_ticks_msec()<deadline:
		land_contact=land_contact or _injured(observed_land)
		water_contact=water_contact or _injured(observed_water)
		if land_contact and water_contact: break
		await physics_frame
	Engine.time_scale=1.0
	var ready: bool=land_contact and water_contact and b.phase==b.Phase.FIGHT
	report["gao_rts_fixture"]={"scope":"first authored existing expedition dispatched early with _send_wave; player armies attack-move to both fronts; not natural wave timing or a complete route",
		"level_script":b.level.get_script().resource_path,"initial":initial,"at_contact":_counts(b),
		"land_contact_seen":land_contact,"water_contact_seen":water_contact,"phase":int(b.phase),
		"first_wave_sent":b.level.waves[0].sent,"elapsed_simulation_seconds":b.level.elapsed,"setup_time_scale":4.0,"ready":ready}
	check(ready,"Gao current land and water forces both reach actual combat before sample")
	return ready
func _report_p95(report_path: String, label: String) -> float:
	if report_path.is_empty(): return -1.0
	var path := report_path
	if not (path.begins_with("res://") or path.begins_with("user://")):
		path=ProjectSettings.localize_path(path)
	if not FileAccess.file_exists(path): return -1.0
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary): return -1.0
	for sample in (parsed as Dictionary).get("samples",[]):
		if sample is Dictionary and String((sample as Dictionary).get("label",""))==label:
			return float((sample as Dictionary).get("p95_frame_ms",-1.0))
	return -1.0
func _confirmed_baseline_path() -> String:
	var override := OS.get_environment("CAMPAIGN_CONFIRMED_BASELINE")
	return override if not override.is_empty() else CONFIRMED_BASELINE

func _confirmed_p95(label: String) -> float:
	return _report_p95(_confirmed_baseline_path(),label)
func _shadow_off_p95(label: String) -> float:
	return _report_p95(OS.get_environment("CAMPAIGN_SHADOW_OFF_BASELINE"),label)
func _sample(b,label: String) -> void:
	Engine.time_scale=1.0
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+"_start.png"))
	var initial: Dictionary=_counts(b)
	var highest: int=initial.active_units
	var lowest: int=highest
	var intervals: Array[float]=[]
	var draw_calls: Array[float]=[]
	var ended_during_sample := false
	var attacking_frames := 0
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec()-start<10000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now-previous)/1000.0)
		previous=now
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var frame_counts: Dictionary=_counts(b)
		var count: int=frame_counts.active_units
		if frame_counts.attacking_units>0: attacking_frames+=1
		highest=maxi(highest,count); lowest=mini(lowest,count)
		ended_during_sample=ended_during_sample or b.phase!=b.Phase.FIGHT
	var sorted: Array=intervals.duplicate(); sorted.sort()
	var mean: float=intervals.reduce(func(a,v): return a+v,0.0)/maxi(1,intervals.size())
	var p95: float=sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)]
	var p99: float=sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.99))-1)]
	var historical_p95 := _confirmed_p95(label)
	var shadow_off_p95 := _shadow_off_p95(label)
	var shadow_module=load("res://scripts/world_shadow.gd")
	var result={"label":label,"headless":false,"viewport":str(root.size),"wall_seconds":float(previous-start)/1000000.0,
		"frames":intervals.size(),"initial":initial,"final":_counts(b),"active_peak":highest,"active_min":lowest,"frames_with_attacking_units":attacking_frames,
		"average_frame_ms":mean,"p95_frame_ms":p95,"p95_gate_ms":P95_FRAME_MS_LIMIT,"p99_frame_ms":p99,"p99_gate_ms":P99_FRAME_MS_LIMIT,
		"historical_confirmed_p95_frame_ms":historical_p95,"p95_delta_from_confirmed_ms":p95-historical_p95 if historical_p95>=0.0 else null,
		"shadow_off_p95_frame_ms":shadow_off_p95,"p95_shadow_off_ratio":p95/shadow_off_p95 if shadow_off_p95>0.0 else null,
		"p95_regression_limit_ratio":P95_REGRESSION_LIMIT,
		"worst_frame_ms":sorted.back(),"mean_fps":1000.0/mean,"minimum_instantaneous_fps":1000.0/float(sorted.back()),
		"mean_draw_calls":draw_calls.reduce(func(a,v): return a+v,0.0)/maxi(1,draw_calls.size()),
		"world_shadow_routes":shadow_module.route_summary(b),"world_shadow_batch":shadow_module.batch_summary(b),
		"phase_at_end":int(b.phase),"ended_during_sample":ended_during_sample,"kills_at_end":b.kills,"frame_intervals_ms":intervals}
	report.samples.append(result)
	var compact: Dictionary=result.duplicate(); compact.erase("frame_intervals_ms")
	print("[render-sample] ",JSON.stringify(compact))
	check(not ended_during_sample and result.mean_draw_calls>0,label+" measured ten seconds of live rendered battle")
	check(attacking_frames>0,label+" attack swings actually occur inside measured window")
	check(p95<=P95_FRAME_MS_LIMIT,label+" P95 frame time <= %.1f ms"%P95_FRAME_MS_LIMIT)
	check(p99<=P99_FRAME_MS_LIMIT,label+" P99 frame time <= %.1f ms"%P99_FRAME_MS_LIMIT)
	check(historical_p95>=0.0,label+" has confirmed P95 baseline")
	if historical_p95>=0.0:
		check(p95<=historical_p95*P95_REGRESSION_LIMIT,label+" P95 regression <= 10 percent vs confirmed baseline")
	if OS.get_environment("WORLD_SHADOW_ENABLED")!="0":
		check(shadow_off_p95>=0.0,label+" has shadow-off P95 baseline")
		if shadow_off_p95>=0.0:
			check(p95<=shadow_off_p95*P95_REGRESSION_LIMIT,label+" P95 regression <= 10 percent vs shadow-off baseline")
	root.get_texture().get_image().save_png(output.path_join(label+"_end.png"))
func _performance_check() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"performance refuses headless renderer"); return
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	report["renderer"]={"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"vendor":RenderingServer.get_video_adapter_vendor(),"api":RenderingServer.get_video_adapter_api_version(),
		"method":RenderingServer.get_current_rendering_method(),"vsync":DisplayServer.window_get_vsync_mode(),"game_speed":1.0,
		"physics_ticks_per_second":Engine.physics_ticks_per_second,"godot":Engine.get_version_info()}
	report["world_shadow_enabled"]=OS.get_environment("WORLD_SHADOW_ENABLED")!="0"
	report["p95_contract"]={"absolute_gate_ms":P95_FRAME_MS_LIMIT,
		"regression_limit_ratio":P95_REGRESSION_LIMIT,"confirmed_baseline":_confirmed_baseline_path(),
		"shadow_off_baseline":OS.get_environment("CAMPAIGN_SHADOW_OFF_BASELINE"),
		"requires_shadow_off_when_enabled":true}
	var b=await _start("level3")
	if await _prepare_zhu(b):
		_camera(b,b.level.MAIN_GATE,0.8)
		await _sample(b,"zhu_rts_gate_contact")
	await _dispose(b)
	b=await _start("level5")
	if await _prepare_gao(b):
		_camera(b,Vector2i(35,37),0.8)
		await _sample(b,"gao_rts_land_water_contact")
	await _dispose(b)
	if OS.get_environment("CAMPAIGN_RUNTIME_STRESS")=="1":
		b=await _start("level7",true)
		for u in b.units.duplicate():
			if not u.is_building and not u.is_resource:
				b.units.erase(u); u.queue_free()
		await process_frame
		for faction in [0,1]:
			for i in range(60):
				var key: String=("liang_gong" if i%3==0 else "liang_qiang") if faction==0 else ("guan_gong" if i%3==0 else "guan_dao")
				var u=b.spawn_at(key,faction,Vector2i(21+faction*12+i%6,19+i/6))
				u.order_amove(b.map.cell_to_world(Vector2i(30-faction*3,24)))
		_camera(b,Vector2i(29,24),0.85)
		await _sample(b,"synthetic_120_troops")
		await _dispose(b)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	output=OS.get_environment("CAMPAIGN_RUNTIME_OUT")
	if output=="": output=ProjectSettings.globalize_path("res://qa/campaign_runtime")
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before:=_save_hash()
	var s=root.get_node("Settings")
	s.edge_scroll=false; s.auto_micro_level=0; s.game_speed=1.0
	AudioServer.set_bus_mute(0,true)
	var only:=OS.get_environment("CAMPAIGN_RUNTIME_ONLY")
	if only!="performance": await _mode_check()
	if only=="performance":
		await _performance_check()
		check(report.samples.size()==(3 if OS.get_environment("CAMPAIGN_RUNTIME_STRESS")=="1" else 2),"all requested performance samples actually completed")
	if only!="performance": check(report.mode_checks.size()==23,"all 23 mode assertions actually executed")
	root.get_node("Campaign").save_prefs()
	check(_save_hash()==saved_before,"CAMPAIGN_QA leaves campaign progress bytes unchanged")
	report["passed"]=failures.is_empty(); report["failures"]=failures
	report["save_hash_before"]=saved_before; report["save_hash_after"]=_save_hash()
	var file=FileAccess.open(output.path_join("runtime_"+("performance" if only=="performance" else "modes")+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("[runtime-result] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
