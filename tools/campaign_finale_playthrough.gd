extends SceneTree
## Uses real mission requests, navigation and combat. Damage injection appears only in explicit loss cases.
var failures: Array[String] = []
var capture_directory := ""
var captured_stages: Dictionary = {}
func _initialize() -> void: _run.call_deferred()

func _start():
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.current=4
	seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene=b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	Engine.time_scale=4.0
	return b

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	capture_directory=OS.get_environment("FINALE_CAPTURE")
	if capture_directory!="":
		DirAccess.make_dir_recursive_absolute(capture_directory)
		root.size=Vector2i(1280,720)
		root.content_scale_size=root.size
	root.get_node("Settings").auto_micro_level=0
	root.get_node("Settings").edge_scroll=false
	AudioServer.set_bus_mute(0,true)
	var chosen:=OS.get_environment("FINALE_QA_CASES")
	var cases: Array=Array(chosen.split(",")) if chosen!="" else ["victory"]
	for case_name in cases:
		if case_name not in ["victory","replay","lure_loss","specialist_loss","rescue_loss","return_loss"]:
			push_error("Unknown finale QA case: "+String(case_name))
			quit(2)
			return
	for case_name in cases:
		var b=await _start()
		var fresh: bool=b.level.stage=="water_lure" and b.mission.events.is_empty() and b.level.fleet.size()==5 and not b.level.transfer_done and not b.level.recovered_gao and b.level.lure_route=="" and not b.level.fire_lit and not b.level.port_sealed
		var dock_land: Vector2i=b.level.PRISONER_DOCK_LAND
		var dock_water: Vector2i=b.level.PRISONER_DOCK_WATER
		var dock_connected: bool=b.map.t_at(dock_land.x,dock_land.y)==b.map.T.DOCK and b.map.is_open_world(b.map.cell_to_world(dock_water),"water") and dock_land.distance_to(dock_water)==1.0
		var sim_time:=0.0
		var commands:=0.0
		var old_stage: String=b.level.stage
		var domain_failures:=0
		var last_snapshot:=0.0
		var injected:=false
		var continued_after_injection:=false
		var water_transfer_safe:=true
		var saw_flooding:=false
		var saw_return:=false
		while b.phase!=b.Phase.END and sim_time<420.0:
			await process_frame
			var dt: float=b.get_process_delta_time()
			sim_time+=dt
			commands+=dt
			for u in b.units:
				if is_instance_valid(u) and u.hp>0 and not u.is_building and not b.map.is_open_world(u.position,u.movement_profile):
					domain_failures+=1
			if old_stage!=b.level.stage:
				old_stage=b.level.stage
				print("[finale-stage] ",case_name," ",old_stage," t=",sim_time)
			if capture_directory!="" and case_name=="victory" and b.level.stage in ["water_rescue","return_prisoner","capture_gao"] and not captured_stages.has(b.level.stage):
				await _capture_event(b)
			if b.phase!=b.Phase.END and b.level.stage in ["water_rescue","return_prisoner"]:
				water_transfer_safe=water_transfer_safe and not b.level.transfer_done and b.find_unit("gao_qiu")==null
				var specialist=b.find_unit("zhang_shun_boat")
				if b.level.stage=="water_rescue":
					saw_flooding=true
					water_transfer_safe=water_transfer_safe and b.level.flagship.get_meta("ship_state")=="flooding"
				else:
					saw_return=true
					if is_instance_valid(specialist):
						water_transfer_safe=water_transfer_safe and specialist.get_meta("carried_story_person","")=="高俅"
			if not injected and case_name=="lure_loss":
				b.find_unit("ruan_xiaoqi_boat").take_damage(100000.0,null,true,true)
				injected=true
				continued_after_injection=b.phase!=b.Phase.END and b.level.first_direct and b.mission.has_event("gao_first_direct")
			elif not injected and case_name=="specialist_loss" and b.level.stage=="final_fleet":
				b.find_unit("zhang_shun_boat").take_damage(100000.0,null,true,true)
				injected=true
				continued_after_injection=b.phase!=b.Phase.END and b.mission.has_event("gao_capture_route_lost")
			elif not injected and ((case_name=="rescue_loss" and b.level.stage=="water_rescue") or (case_name=="return_loss" and b.level.stage=="return_prisoner")):
				b.find_unit("zhang_shun_boat").take_damage(100000.0,null,true,true)
				injected=true
			if sim_time-last_snapshot>30.0:
				last_snapshot=sim_time
				_snapshot(b,sim_time)
			if commands<0.5:
				continue
			commands=0.0
			if b.phase!=b.Phase.END:
				_drive(b)
		var won: bool=b.mission.has_event("gao_captured")
		var passed: bool=fresh and b.phase==b.Phase.END and domain_failures==0 and water_transfer_safe and dock_connected
		var duplicate_safe:=true
		var story_result: Dictionary = b.mission.result_snapshot(case_name in ["victory","replay"])
		if case_name=="lure_loss":
			passed=passed and injected and continued_after_injection and bool(story_result.get("core_cleared",false))
			passed=passed and not bool(story_result.get("story_complete",true)) and "gao_lure" in story_result.get("missed_ids",[])
		elif case_name=="specialist_loss":
			# Losing Zhang Shun removes only the optional capture route.  This case must
			# still prove that the surviving fleet can complete the core objective by
			# defeating Gao's flagship; a later ordinary defeat is not a passing result.
			passed=passed and injected and continued_after_injection and not won and not b.level.transfer_done
			passed=passed and bool(story_result.get("core_cleared",false))
			passed=passed and b.mission.has_event("gao_capture_route_lost") and "gao_capture" in story_result.get("missed_ids",[])
		elif case_name in ["rescue_loss","return_loss"]:
			passed=passed and injected and not won and not b.level.transfer_done and bool(story_result.get("core_cleared",false))
			passed=passed and b.mission.has_event("gao_escaped") and "gao_capture" in story_result.get("missed_ids",[])
		else:
			passed=passed and won and b.level.transfer_done and saw_flooding and saw_return
			passed=passed and b.mission.has_event("lure_route_main") and b.mission.has_event("fleet_in_ambush")
			passed=passed and b.mission.has_event("gongsun_wind") and b.mission.has_event("liu_tang_fire_leader") and b.mission.has_event("fireboat_prepared")
			passed=passed and (b.mission.has_event("fire_point_north") or b.mission.has_event("fire_point_south")) and b.mission.has_event("fire_escort_safe")
			passed=passed and b.mission.has_event("escort_suppressed") and b.mission.has_event("port_sealed") and b.level.hard_rushes==0
			if won:
				var gao=b.level.gao
				var crew_count: int=b.units.filter(func(u): return is_instance_valid(u) and u.key=="gao_qiu").size()
				var mark_count: int=b.mission.report.size()
				var repeated: bool=gao.resolve_story("captured")
				var action_accepted: bool=b.mission.request_action("scuttle")
				var specialist=b.find_unit("zhang_shun_boat")
				b.level.on_mission_action(b,"scuttle",specialist)
				b.level.on_mission_action(b,"recover_gao",specialist)
				b.level.on_mission_action(b,"land_gao",specialist)
				gao.take_damage(100000.0,null,true,true)
				duplicate_safe=not repeated and not action_accepted and crew_count==1 and b.mission.report.size()==mark_count and gao.hp>0 and gao.story_outcome=="captured"
				duplicate_safe=duplicate_safe and b.units.filter(func(u): return is_instance_valid(u) and u.key=="gao_qiu").size()==1
				passed=passed and duplicate_safe
		if case_name in ["victory","replay"]:
			passed=passed and bool(story_result.get("story_complete",false))
		print("[finale-result] ",JSON.stringify({"case":case_name,"passed":passed,"stage":b.level.stage,"sim_seconds":sim_time,"domain_failures":domain_failures,"fresh_state":fresh,"continued_after_injection":continued_after_injection,"water_transfer_safe":water_transfer_safe,"duplicate_transfer_safe":duplicate_safe,"events":b.mission.events.keys(),"stage_metrics":b.mission.stage_metrics,"story_result":story_result}))
		if not passed:
			failures.append(case_name)
			for u in b.units:
				if is_instance_valid(u):
					print("[finale-unit] ",u.key," hp=",u.hp," cell=",b.map.world_to_cell(u.position)," result=",u.story_outcome)
		b.queue_free()
		await process_frame
		await process_frame
	Engine.time_scale=1.0
	print("[finale-summary] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _snapshot(b,sim_time: float) -> void:
	var boats:=[]
	for u in b.units:
		if is_instance_valid(u) and u.movement_profile=="water":
			boats.append({"key":u.key,"hp":u.hp,"cell":str(b.map.world_to_cell(u.position)),"outcome":u.story_outcome})
	print("[finale-progress] ",JSON.stringify({"stage":b.level.stage,"time":sim_time,"action":b.mission.active_action_id,"boats":boats}))

func _capture_event(b) -> void:
	var stage: String=b.level.stage
	captured_stages[stage]=true
	b.camera.set_process(false)
	var point: Vector2=b.level.flagship.position
	if stage=="return_prisoner": point=b.find_unit("zhang_shun_boat").position
	elif stage=="capture_gao": point=b.level.gao.position
	b.camera.position=b.to_screen(point)
	b.camera.zoom=Vector2.ONE*1.2
	b.camera.force_update_scroll()
	b.mission.tick(0.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_directory.path_join("level5_"+stage+"_1280.png"))
	print("[finale-visual] ",stage," saved from real event")

func _drive(b) -> void:
	if b.mission.active_action_id=="":
		if b.level.stage=="fire_withdraw":
			var safe: Vector2 = b.map.cell_to_world(b.level.FIRE_SAFE_CELL)
			if not bool(b.get_meta("qa_fire_escort_ordered",false)):
				b.set_meta("qa_fire_escort_ordered",true)
				b._set_selection(b.level.fire_escorts)
				b._issue_order(b.to_screen(safe))
			var escorts_ready: bool = b.level.fire_escorts.all(func(ship):
				return b.level._effective(ship) and ship.position.distance_to(safe)<=96.0)
			var safe_clear: bool = b.level.enemy_fleet.all(func(ship):
				return not b.level._effective(ship) or ship.position.distance_to(safe)>=210.0)
			if escorts_ready and safe_clear:
				b.mission.request_action("fire_withdraw")
		elif b.level.stage=="final_fleet":
			if not b.level.lure_started:
				b.mission.request_action("sortie")
			# The objective opens after three escorts are suppressed.  This smoke
			# route waits for the flagship to physically enter the port before it
			# commits its reserved seal boat, avoiding repeated exposed attempts.
			elif b.level.escort_suppressed and b.mission.actions.has("seal_port") \
					and is_instance_valid(b.level.flagship) and b.level.flagship.position.distance_to(b.map.cell_to_world(b.level.FINAL_FLAG_CELL))<=144.0:
				b.mission.request_action("seal_port")
		elif b.level.stage=="scuttle":
			b.mission.request_action("scuttle")
		else:
			for action in b.mission.actions:
				if b.mission.request_action(action): break
	# The finite fireboat must stay intact until it has physically reached the
	# chosen chain segment. These stages contain only navigation/task commands.
	if b.level.stage in ["fire_prepare","fire_position","fire_ignite"]:
		return
	var foes: Array=b.units_of(1).filter(func(u): return not u.is_captive and not u.is_building and u.story_outcome=="")
	var ships: Array=b.units_of(0).filter(func(u): return u.movement_profile=="water" and u.story_outcome=="")
	var escorts: Array=foes.filter(func(u): return u.movement_profile=="water" and u.key!="gao_flagship")
	var capture_route_available: bool=b.level.stage=="final_fleet" and b.level._capture_route_available()
	var focus=null
	for foe in escorts:
		if focus==null or foe.hp<focus.hp: focus=foe
	# The flagship is disabled by the physical port-seal task.  Once its finite
	# escorts are gone, stop firing and let it finish the real route into port;
	# grinding it to its story outcome offshore would strand the task marker.
	if focus==null and (b.level.stage!="final_fleet" or not capture_route_available):
		for foe in foes:
			if foe.key=="gao_flagship": focus=foe
	var awaiting_flag_at_port: bool=b.level.stage=="final_fleet" and b.level.lure_started and escorts.is_empty() and capture_route_available
	for ally in b.units_of(0):
		if ally.is_building or ally.story_outcome!="" or ally.key in ["song_jiang","wu_yong"] or ally==b.mission._actor: continue
		if bool(ally.get_meta("bait_withdrawing",false)): continue
		if b.level.stage=="fire_withdraw" and ally in b.level.fire_escorts: continue
		# Preserve one of the two finite seal-capable boats as a real reserve while
		# the other four combat boats create the suppression window.  It navigates
		# to the south-east water pocket, close to the seal route but outside the
		# escort approach; no teleport, health edit or enemy injection.
		if b.level.stage=="final_fleet" and capture_route_available and not escorts.is_empty() and ally.key=="ruan_xiaoer_boat":
			if not bool(ally.get_meta("finale_seal_reserve",false)):
				ally.set_meta("finale_seal_reserve",true)
				ally.order_move(b.map.cell_to_world(Vector2i(43,52)))
				ally.passive=true
				ally.stance=3 # Unit.STANCE_PASSIVE; keep this SceneTree tool dependency-free.
			continue
		if ally.key=="zhang_shun_boat" and not escorts.is_empty() and ships.size()>1: continue
		if b.level.stage=="water_lure" and not b.level.lure_complete: continue
		if b.level.stage=="final_fleet" and not b.level.lure_started: continue
		if ally.movement_profile=="water":
			if awaiting_flag_at_port:
				if ally._target!=null or not ally.passive or ally.stance!=3:
					ally.order_stop()
					ally.passive=true
					ally.stance=3 # Unit.STANCE_PASSIVE; keep this SceneTree tool dependency-free.
				continue
			if focus!=null and ally._target!=focus: ally.order_attack(focus)
			continue
		var best=null
		var score:=INF
		for foe in foes:
			var distance: float=ally.position.distance_to(foe.position)
			if foe.movement_profile!=ally.movement_profile and (not ally.is_ranged or distance>ally.atk_range+20): continue
			if distance<score: best=foe; score=distance
		if best!=null and ally._target!=best: ally.order_attack(best)
