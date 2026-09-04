extends SceneTree
## Late-campaign free-play contracts. These are bounded branch fixtures: they
## exercise the real mission callbacks and settlement rules, while direct
## section entry / unit resolution keeps the run deterministic and short.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	print("[freeplay-late] ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func _story_state(b,goal_id: String) -> String:
	if not b.mission.story_goals.has(goal_id): return "missing"
	return String(b.mission.story_goals[goal_id].state)

func _start(level_id: String):
	seed(5088120)
	var campaign=root.get_node("Campaign")
	campaign.current=campaign.index_for_id(level_id)
	campaign.arena=false
	campaign.skirmish=false
	campaign.skirmish_ai=false
	campaign.scenario=false
	campaign.custom_defense=false
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene=b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	Engine.time_scale=4.0
	return b

func _dispose(b) -> void:
	if current_scene==b: current_scene=null
	b.queue_free()
	await process_frame
	await process_frame

func _finish_action(b,action_id: String) -> bool:
	if not b.mission.request_action(action_id): return false
	var action: Dictionary=b.mission.actions[action_id]
	var actor=b.mission._actor
	if not is_instance_valid(actor): return false
	actor.order_stop()
	actor.position=b.map.cell_to_world(action.cell)
	b.map.sync_render_position(actor)
	b.mission.tick(float(action.duration)+0.1)
	return b.mission.active_action_id==""

func _wait_for(predicate: Callable,limit := 120) -> bool:
	var frames := 0
	while not predicate.call() and frames<limit:
		await process_frame
		frames += 1
	return bool(predicate.call())

func _freeze_units(b) -> void:
	for u in b.units:
		if is_instance_valid(u): u.set_physics_process(false)

func _zhujiazhuang_free() -> void:
	var b=await _start("level3")
	var l=b.level
	l._second_day(b) # Boundary fixture: enter the second deployment directly.
	await process_frame
	l._start_second_free_fight(b)
	check(b.phase!=b.Phase.END and b.mission.has_event("zhu_second_freefight"),"Zhujia wrong formation becomes a recoverable free fight")
	l.hu.resolve_story("captured")
	check(await _wait_for(func(): return l.stage=="infiltrate"),"Hu Sanniang stays a captured enemy and the cross-day third fight still opens")
	check(l.hu==null or l.hu.faction==1,"Hu Sanniang never flips sides during capture settlement")
	l._start_third_free_assault(b)
	check(l.free_third_assault and _story_state(b,"zhu_inside")=="missed" and b.phase!=b.Phase.END,"direct manor assault misses only the inside-agent seal")
	_freeze_units(b)
	if is_instance_valid(l.gate): l.gate.resolve_story("subdued")
	for key in ["zhu_long","zhu_hu","zhu_biao","luan_tingyu"]:
		var foe=b.find_unit(key)
		if is_instance_valid(foe) and foe.story_outcome=="": foe.take_damage(1000000.0)
	check(await _wait_for(func(): return b.phase==b.Phase.END),"direct gate breach and defeat of Zhu commanders clears the tactical core")
	check(_story_state(b,"zhu_capture")=="missed" and _story_state(b,"zhu_inside")=="missed","Zhujia free victory records missed seals instead of a false canonical result")
	await _dispose(b)

func _lianhuanma_free() -> void:
	var b=await _start("level4")
	var l=b.level
	check(_finish_action(b,"lhm_skip_training"),"Lianhuanma skip-training choice is executable")
	check(await _wait_for(func(): return l.stage=="prepare"),"skip training redeploys the real battle section")
	check(_finish_action(b,"lhm_direct_battle") and l.free_battle,"front or mixed engagement starts both cavalry waves")
	_freeze_units(b)
	for rider in l.riders:
		if is_instance_valid(rider) and rider.hp>0.0: rider.take_damage(1000000.0)
	if is_instance_valid(l.han) and l.han.story_outcome=="": l.han.resolve_story("captured")
	check(await _wait_for(func(): return b.phase==b.Phase.END),"twelve high-reduction riders can be beaten by costly direct force without a hard fail")
	check(_story_state(b,"lhm_training")=="missed" and _story_state(b,"lhm_hooks")=="missed","direct victory loses training and all-hooks seals only")
	check(b.mission.has_event("lhm_han_captured") and b.mission.has_event("lhm_hu_fled"),"optional Han capture and Huyan Qingzhou retreat remain independently awardable")
	await _dispose(b)

func _daming_free() -> void:
	var b=await _start("level8")
	var l=b.level
	check(_finish_action(b,"daming_open_assault") and l.open_assault,"Daming public-assault choice bypasses infiltration without ending the mission")
	check(_story_state(b,"daming_infiltration")=="missed" and _story_state(b,"daming_signal")=="missed","public assault explicitly forfeits infiltration and fire-signal seals")
	_freeze_units(b)
	if is_instance_valid(l.gate): l.gate.resolve_story("subdued")
	_freeze_units(b)
	for guard in l.guards:
		if is_instance_valid(guard) and guard.story_outcome=="": guard.resolve_story("subdued")
	var rescuer=b.find_unit("lu_zhishen")
	rescuer.position=b.map.cell_to_world(l.PRISON_CHECK)
	b.map.sync_render_position(rescuer)
	l._open_assault_tick(b)
	rescuer.position=b.map.cell_to_world(l.JAIL_ACTION)
	b.map.sync_render_position(rescuer)
	l._open_assault_tick(b)
	check(l.rescued and l.prison_breached and b.phase!=b.Phase.END,"any surviving fighter can breach the jail and release both prisoners")
	for captive in [l.lu,l.shi]:
		captive.position=b.map.cell_to_world(l.EXIT_CELL)
		b.map.sync_render_position(captive)
	l._auto_extract_free(b)
	l.process(b,0.1)
	check(b.phase==b.Phase.END and b.mission.has_event("daming_lu_safe") and b.mission.has_event("daming_shi_safe"),"Lu Junyi and Shi Xiu alive outside the gate settle the free-route core victory")
	check(_story_state(b,"daming_response")=="missed","forced gate and jail entry are reported as a missed response seal")
	await _dispose(b)
	b=await _start("level8")
	l=b.level
	for event_id in ["daming_city_entered","daming_officer_cover","daming_chai_positioned","daming_yue_positioned","daming_fire_lit","daming_gate_opened"]:
		b.mission.mark(event_id,"晚期转路边界夹具")
	l.stage="rescue"
	l.gate_open=true
	l.chai.take_damage(1000000.0)
	var late_states := {"open":l.open_assault,"phase":b.phase,"infiltration":_story_state(b,"daming_infiltration"),"signal":_story_state(b,"daming_signal"),"response":_story_state(b,"daming_response")}
	var earlier_seals_kept: bool = late_states.infiltration in ["pending","done"] and late_states.signal in ["pending","done"]
	if not (late_states.open and b.phase!=b.Phase.END and earlier_seals_kept and late_states.response=="missed"):
		print("[freeplay-late-debug] ",JSON.stringify(late_states))
	check(late_states.open and b.phase!=b.Phase.END and earlier_seals_kept and late_states.response=="missed","post-signal Chai loss keeps earned infiltration and signal seals while opening a brute-force jail route")
	await _dispose(b)

func _finale_free() -> void:
	var b=await _start("level5")
	var l=b.level
	l._start_land(b) # Boundary fixture: enter the second invasion.
	await process_frame
	l.fireboat.take_damage(1000000.0)
	check(l.stage=="fire_direct" and b.phase!=b.Phase.END,"loss of the only prepared fire boat switches to direct naval combat")
	check(_story_state(b,"gao_fire")=="missed","fire-boat loss forfeits only the fire-assault seal")
	for ship in l.enemy_fleet:
		if is_instance_valid(ship) and ship.story_outcome=="": ship.resolve_story("subdued")
	check(await _wait_for(func(): return l.stage=="land_ambush"),"surviving ships can finish the second invasion after the fire plan fails")
	l._start_final_fleet(b) # Boundary fixture: enter the third invasion.
	await process_frame
	l._start_final_direct(b,"测试：直接迎击高俅座船")
	_freeze_units(b)
	var one_seal_boat=b.find_unit("ruan_xiaowu_boat")
	if is_instance_valid(one_seal_boat): one_seal_boat.take_damage(1000000.0)
	check(not b.mission.has_event("gao_capture_route_lost"),"one Ruan seal boat loss still leaves the other boat plus Zhang Shun capture route intact")
	var zhang_boat=b.find_unit("zhang_shun_boat")
	if is_instance_valid(zhang_boat): zhang_boat.take_damage(1000000.0)
	check(b.phase!=b.Phase.END and b.mission.has_event("gao_capture_route_lost"),"Zhang Shun boat loss removes capture only and leaves the naval core playable")
	l.flagship.resolve_story("subdued")
	check(b.phase==b.Phase.END and b.mission.has_event("flagship_repelled") and not b.mission.has_event("gao_captured"),"repelling Gao's flagship grants base victory without claiming capture")
	check(_story_state(b,"gao_capture")=="missed","base finale victory records the uncaptured-Gao seal as missed")
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").auto_micro_level=0
	AudioServer.set_bus_mute(0,true)
	var campaign=root.get_node("Campaign")
	var save_existed:=FileAccess.file_exists(campaign.SAVE_PATH)
	var save_data:=FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_existed else PackedByteArray()
	await _zhujiazhuang_free()
	await _lianhuanma_free()
	await _daming_free()
	await _finale_free()
	var save_exists_now:=FileAccess.file_exists(campaign.SAVE_PATH)
	var save_data_now:=FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	check(save_existed==save_exists_now and save_data==save_data_now,"CAMPAIGN_QA free-play fixtures perform zero campaign-save writes")
	Engine.time_scale=1.0
	print("[freeplay-late-result] ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
