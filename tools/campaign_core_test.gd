extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, name: String) -> void:
	print("[core] ", "PASS " if ok else "FAIL ", name)
	if not ok: failures.append(name)

func death_remains(b) -> Array:
	return b.fx_root.get_children().filter(func(node) -> bool:
		return is_instance_valid(node) and not node.is_queued_for_deletion() \
			and bool(node.get_meta("death_remains", false)))

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var campaign = root.get_node("Campaign")
	var settings = root.get_node("Settings")
	settings.auto_micro_level=0; settings.edge_scroll=false
	check(campaign.story_indices()==[5,0,6,1,2,3,7,4],"story order preserves legacy ID indices")
	for i in range(8):
		campaign.current=i
		check(campaign.LEVELS[i].id=="level%d"%(i+1),"legacy LEVEL=%d"%(i+1))
	var Map = load("res://scripts/game_map.gd")
	var map = Map.new()
	map.init_map(18,12,"marsh",Map.T.GRASS)
	map.fill_rect(9,0,9,12,Map.T.WATER)
	map.bake()
	var land = map.cell_to_world(Vector2i(5,5))
	var water = map.cell_to_world(Vector2i(12,5))
	check(map.is_open_world(land) and not map.is_open_world(land,"water"),"land only on land")
	check(map.is_open_world(water,"water") and not map.is_open_world(water),"ships only on water")
	check(not map.is_open_world(Vector2(-2,5),"land"),"world boundaries are not clamped into passability")
	check(not map._segment_open(land,water) and not map._segment_open(water,land,"water"),"smoothing rejects shoreline crossing")
	for profile in ["land","water"]:
		var start: Vector2 = land if profile=="land" else water
		var end: Vector2 = water if profile=="land" else land
		var points = map.find_path(start,end,0,profile)
		for point in points:
			check(map.is_open_world(point,profile) and map._segment_open(start,point,profile),"snapped destination stays in "+profile)
			start=point
	map.block_footprint(Vector2i(12,5),1,true)
	check(not map.is_open_world(water,"water"),"dynamic footprint blocks ship")
	map.block_footprint(Vector2i(12,5),1,false)
	check(map.is_open_world(water,"water"),"footprint releases water without opening land")
	map.fill_rect(14,0,4,12,Map.T.GRASS)
	map.bake()
	var far_bank: Vector2=map.cell_to_world(Vector2i(16,5))
	var stopped: Vector2=map.limit_displacement(land,far_bank,"land")
	check(map.is_open_world(far_bank) and map.world_to_cell(stopped).x<9,"displacement cannot tunnel over water to an open far bank")
	map.free()
	campaign.current=4
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b); current_scene=b
	await process_frame
	b.hud._intro_root.hide(); b._on_intro_done(); b._on_start_battle()
	var published_remains := root.get_node("Art").campaign_object_texture("death_remains") as Texture2D
	var published_valid := published_remains != null and published_remains.get_width() % 4 == 0 \
		and published_remains.get_height() % 2 == 0 \
		and floori(float(published_remains.get_width()) / 4.0) == floori(float(published_remains.get_height()) / 2.0)
	check(published_valid,"published death remains is a square-cell 4x2 atlas")
	if not published_valid:
		b.queue_free()
		print("[core-result] ",JSON.stringify({"passed":false,"failures":failures}))
		quit(1)
		return
	var remains_before_story := death_remains(b).size()
	var source=b.spawn_at("liang_dao",0,Vector2i(28,31))
	var target=b.spawn_at("guan_dao",1,Vector2i(29,31))
	var events: Array=[]
	var deaths: Array=[]
	target.story_resolved.connect(func(_u,outcome): events.append(outcome))
	target.died.connect(func(_u): deaths.append(true))
	target.defeat_outcome="captured"
	source.order_attack(target)
	source._pending_target=target; source._pending_done=false
	var old_kills: int=b.kills
	target.take_damage(100000,source,true,true,"qa_critical")
	target.take_damage(100000,source,false,true,"qa_same_frame")
	b._add_ground_dot(target.position,10,100000,1,source,1)
	b._ground_dot_pass(1.0)
	check(target.hp==1 and target.story_outcome=="captured" and events==["captured"] and deaths.is_empty(),"critical + same-frame hit + real DOT resolves once without death")
	check(b.kills==old_kills and source._target==null and source._pending_target==null,"capture clears locks and awards no death kill")
	check(death_remains(b).size()==remains_before_story,"captured story outcome creates no death remains")
	check(not target.resolve_story("retreated"),"second outcome cannot replace first")
	target.order_move(source.position)
	check(target._path.is_empty(),"captured unit rejects commands")
	for outcome in ["unconscious","subdued","retreated","embarked"]:
		var victim=b.spawn_at("guan_dao",1,Vector2i(28,34))
		var notices: Array=[]
		var death_notices: Array=[]
		victim.story_resolved.connect(func(_u,state): notices.append(state))
		victim.died.connect(func(_u): death_notices.append(true))
		victim.defeat_outcome=outcome
		victim.take_damage(100000,source,true,true,"qa_critical")
		victim.take_damage(100000,source,false,true,"qa_same_frame")
		b._add_ground_dot(victim.position,8,100000,1,source,1)
		b._ground_dot_pass(1.0)
		b._grid_build(); b._stealth_pass()
		check(victim.hp==1 and victim.story_outcome==outcome and notices==[outcome] and death_notices.is_empty(),outcome+" remains atomic under critical, repeat hit and DOT")
		check(victim.visible==(not (outcome in ["retreated","embarked"])),outcome+" retains the intended on-map visibility")
		check(death_remains(b).size()==remains_before_story,outcome+" creates no death remains")
	var prisoner=b.spawn_at("guan_dao",1,Vector2i(29,35))
	prisoner.is_captive=true
	var origin: Vector2=prisoner.position
	prisoner.order_move(source.position); prisoner._phys_body(1)
	check(prisoner.position==origin,"bound prisoner cannot walk")
	var prisoner_deaths: Array=[]
	prisoner.died.connect(func(_u): prisoner_deaths.append(true))
	prisoner.take_damage(100000,source,true,true)
	check(prisoner.hp<=0,"unresolved prisoner can still die")
	var remains_after_death := death_remains(b)
	check(prisoner_deaths==[true] and remains_after_death.size()==remains_before_story+1,"one real land death creates exactly one remains node")
	var prisoner_mark = remains_after_death[-1]
	var cell_size := floori(float(b._death_remains_atlas.get_width()) / 4.0)
	var frame_col: int = prisoner_mark.frame_index % 4
	var frame_row := floori(float(prisoner_mark.frame_index) / 4.0)
	check(prisoner_mark.frame_texture != null \
		and prisoner_mark.frame_texture.region==Rect2(frame_col*cell_size,frame_row*cell_size,cell_size,cell_size),
		"death remains slices the selected frame from a 4x2 square-cell atlas")
	check(prisoner_mark.frame_index in [0,1,2,3,5,6] and is_equal_approx(prisoner_mark.lifetime,45.0) \
		and is_equal_approx(prisoner_mark.fade_duration,8.0) and not prisoner_mark.z_as_relative and prisoner_mark.z_index==0,
		"death remains uses restrained deterministic frames, 45s/8s timing and ground z")
	check(prisoner_mark.ground_basis.is_equal_approx(b.map.ground_basis(prisoner_mark.position)) \
		and is_equal_approx(float(prisoner_mark.get_meta("render_height",0.0)),b.map.height_at(prisoner_mark.position)),
		"death remains binds its draw plane and render height to the terrain at the death position")
	var remains_once := death_remains(b).size()
	prisoner.take_damage(100000,source,false,true)
	check(death_remains(b).size()==remains_once,"repeat damage after death cannot duplicate remains")
	var expiring_mark_ref=weakref(prisoner_mark)
	prisoner_mark._process(36.9)
	check(is_instance_valid(prisoner_mark) and prisoner_mark.remaining>prisoner_mark.fade_duration,
		"death remains stays fully present before the final eight-second fade")
	prisoner_mark._process(0.2)
	check(prisoner_mark.remaining<prisoner_mark.fade_duration and prisoner_mark.remaining>0.0,
		"death remains enters its fade only during the final eight seconds")
	prisoner_mark._process(8.0)
	check(prisoner_mark.is_queued_for_deletion() and not (prisoner_mark in b._death_remains),
		"death remains expires at 45 seconds and immediately leaves the tracking array")
	await process_frame
	check(expiring_mark_ref.get_ref()==null and death_remains(b).is_empty(),
		"expired death remains is freed without requiring a later unit death")
	var slope_cell := Vector2i(-1,-1)
	var slope_score := 0.0
	for y in range(b.map.h):
		for x in range(b.map.w):
			var candidate := Vector2i(x,y)
			if not b.map.is_open_cell(candidate,"land"):
				continue
			var candidate_pos: Vector2=b.map.cell_to_world(candidate)
			var candidate_ground: Transform2D=b.map.ground_basis(candidate_pos)
			var candidate_score: float=absf(candidate_ground.x.x-1.0)+absf(candidate_ground.x.y) \
				+absf(candidate_ground.y.x)+absf(candidate_ground.y.y-1.0)
			if b.map.height_at(candidate_pos)>0.5 and candidate_score>slope_score:
				slope_cell=candidate
				slope_score=candidate_score
	var slope_ok := slope_cell.x>=0 and slope_score>0.001
	var slope_mark = null
	if slope_ok:
		var slope_victim=b.spawn_at("guan_dao",1,slope_cell)
		slope_victim.take_damage(100000,source,false,true)
		var slope_marks:=death_remains(b)
		slope_mark=slope_marks[-1] if not slope_marks.is_empty() else null
		slope_ok=slope_mark!=null and b.map.height_at(slope_mark.position)>0.5 \
			and not slope_mark.ground_basis.is_equal_approx(Transform2D.IDENTITY) \
			and slope_mark.ground_basis.is_equal_approx(b.map.ground_basis(slope_mark.position)) \
			and is_equal_approx(float(slope_mark.get_meta("render_height",0.0)),b.map.height_at(slope_mark.position))
	check(slope_ok,"a real death binds remains to an authored nonzero slope and render height")
	if slope_mark!=null:
		slope_mark._process(slope_mark.lifetime)
		await process_frame
	var ship=b.level.fleet[0]
	check(not b._unit_leaves_death_remains(b.level.hall) and not b._unit_leaves_death_remains(ship),
		"buildings and water units are excluded from character remains")
	source.is_summon=true
	check(not b._unit_leaves_death_remains(source),"summons are excluded from character remains")
	source.is_summon=false
	var disbanded=b.spawn_at("liang_dao",0,Vector2i(27,35))
	var remains_before_delete := death_remains(b).size()
	b._demolish(disbanded)
	check(death_remains(b).size()==remains_before_delete,"manual Delete keeps its old short mark and creates no death remains")
	var before: Vector2=ship.position
	var destination: Vector2=b.map.cell_to_world(Vector2i(30,35))
	var land_before: Vector2=source.position
	b._do_swap(source,ship,{}, {},1.0,1)
	check(source.position==land_before and ship.position==before,"cross-domain swap cannot put a soldier on water or a ship on land")
	b._do_knockback(source,{"push":800,"dmg":0},1,before+Vector2(100,0),200,ship.faction,[ship])
	check(b.map.is_open_world(ship.position,"water"),"knockback cannot put ship ashore")
	ship.order_move(destination)
	for i in range(160): ship._follow_path(0.05)
	check(b.map.is_open_world(ship.position,"water"),"real ship movement stays on water")
	b.eject_from_buildings(ship)
	check(b.map.is_open_world(ship.position,"water"),"building ejection retains water profile")
	var spots=b._formation_targets([ship,b.level.fleet[1]],destination)
	check(spots.all(func(p): return b.map.is_open_world(p,"water")),"ship formation targets remain on water")
	b.mission.begin("qa","交互复位测试","同一事件只结算一次")
	b.mission.mark("persist","事件应跨阶段保留")
	b.mission.add_action("qa","现场交互",b.map.world_to_cell(source.position),[source.key],0.2)
	check(b.mission.request_action("qa"),"UI command path starts interaction")
	b.mission.tick(0.25)
	check(not b.mission.request_action("qa"),"repeated action ignored")
	b.mission.begin("qa2","转场","已重置")
	check(b.mission.actions.is_empty() and b.mission.active_action_id=="" and b.mission.has_event("persist"),"phase reset clears interactions and retains story log")
	var last_metrics: Dictionary=b.mission.stage_metrics[-1]
	check(last_metrics.stage=="qa" and is_equal_approx(last_metrics.game_seconds,0.25) and last_metrics.accepted_task_commands==1,"per-stage gameplay time and accepted commands survive transition")
	b.mission.finish_metrics(true)
	var metric_count: int=b.mission.stage_metrics.size()
	b.mission.finish_metrics(false)
	check(b.mission.stage_metrics.size()==metric_count and b.mission.stage_metrics[-1].end_reason=="victory","repeated ending cannot rewrite or duplicate stage metrics")
	check(b.DEATH_REMAINS_CAP==48,"death remains cap is the required 48 nodes")
	for i in range(b.DEATH_REMAINS_CAP): b._spawn_death_remains(source)
	var oldest_mark_ref=weakref(death_remains(b)[0])
	for i in range(3): b._spawn_death_remains(source)
	await process_frame
	var capped_remains := death_remains(b)
	check(capped_remains.size()==b.DEATH_REMAINS_CAP and b._death_remains.size()==b.DEATH_REMAINS_CAP,
		"death remains are hard-capped at 48")
	check(oldest_mark_ref.get_ref()==null,"death remains cap evicts the oldest node")
	check(capped_remains.all(func(mark): return mark.frame_index in [0,1,2,3,5,6]),
		"ordinary deaths only select restrained fresh blood and equipment frames")
	var section_mark_ref=weakref(capped_remains[-1])
	b.clear_campaign_section(); await process_frame
	check(death_remains(b).is_empty() and b._death_remains.is_empty() and section_mark_ref.get_ref()==null,
		"cross-day campaign cleanup removes all death remains and tracking references")
	var fx_ref=weakref(b.fx_root)
	b.queue_free(); await process_frame; await process_frame
	check(fx_ref.get_ref()==null,"scene reload lifetime frees the remains root with Battle")
	var replay=load("res://scenes/main.tscn").instantiate()
	root.add_child(replay); current_scene=replay
	await process_frame
	check(death_remains(replay).is_empty() and replay._death_remains.is_empty(),"a fresh Battle starts with no prior death remains")
	replay.queue_free(); await process_frame; await process_frame
	print("[core-result] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
