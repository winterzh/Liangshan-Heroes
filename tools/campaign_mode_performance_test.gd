extends SceneTree
## Modes are checked in a headless process. Performance requires an actual renderer.
## Performance fixtures invoke authored stage deployment; they are not playthrough evidence.
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
		await process_frame
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
	for u in b.units:
		if not is_instance_valid(u): continue
		total+=1
		if u.hp>0 and u.story_outcome=="" and not u.is_building and not u.is_resource:
			active+=1
			if u.visible and u.is_visible_in_tree(): shown+=1
			if u.visible and u.is_visible_in_tree() and b.unit_visual_active(u.position): in_view+=1
	return {"scene_units":total,"active_units":active,"visible_nodes":shown,"in_camera_activity_region":in_view}
func _camera(b,cell: Vector2i,zoom: float) -> void:
	b.camera.set_process(false)
	b.camera.position=b.to_screen(b.map.cell_to_world(cell)); b.camera.zoom=Vector2.ONE*zoom
	b.camera.force_update_scroll()
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
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec()-start<10000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now-previous)/1000.0)
		previous=now
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var count: int=_counts(b).active_units
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
		"frames":intervals.size(),"initial":initial,"final":_counts(b),"active_peak":highest,"active_min":lowest,
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
	b.level._third_day(b)
	report["zhu_authored_deployment"]=_counts(b)
	b._smoke=true
	Engine.time_scale=4.0
	var deadline:=Time.get_ticks_msec()+30000
	while b.level.stage!="assault" and b.phase!=b.Phase.END and Time.get_ticks_msec()<deadline:
		await process_frame
	b._smoke=false; Engine.time_scale=1.0
	check(b.level.stage=="assault","Zhu performance fixture reaches authored third assault through prisoner and gate actions")
	_camera(b,Vector2i(29,29),0.8)
	await _sample(b,"zhu_authored_assault")
	await _dispose(b)
	b=await _start("level5")
	# `_start_land` now deploys the second water-fire act. The authored land
	# fixture begins after that act's closure, where the real land_ambush mission
	# action exists and summons its ordinary northern force.
	b.level._start_land_closure(b)
	b.mission.request_action("land_ambush")
	Engine.time_scale=4.0
	deadline=Time.get_ticks_msec()+20000
	while not b.level.land_started and b.phase!=b.Phase.END and Time.get_ticks_msec()<deadline:
		await process_frame
	report["liangshan_authored_deployment"]=_counts(b)
	# Wait for the authored northern force to approach the real defenders, not a static crowd.
	deadline=Time.get_ticks_msec()+20000
	while not b.units.any(func(u): return is_instance_valid(u) and not u.is_building and u.hp<u.max_hp) and b.phase!=b.Phase.END and Time.get_ticks_msec()<deadline:
		await process_frame
	Engine.time_scale=1.0
	check(b.level.land_started and b.phase==b.Phase.FIGHT,"Liangshan performance fixture reaches authored land battle")
	_camera(b,Vector2i(23,23),0.8)
	await _sample(b,"liangshan_authored_land_battle")
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
	if only=="performance": await _performance_check()
	if only!="performance": check(report.mode_checks.size()==23,"all 23 mode assertions actually executed")
	root.get_node("Campaign").save_prefs()
	check(_save_hash()==saved_before,"CAMPAIGN_QA leaves campaign progress bytes unchanged")
	report["passed"]=failures.is_empty(); report["failures"]=failures
	report["save_hash_before"]=saved_before; report["save_hash_after"]=_save_hash()
	var file=FileAccess.open(output.path_join("runtime_"+("performance" if only=="performance" else "modes")+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("[runtime-result] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
