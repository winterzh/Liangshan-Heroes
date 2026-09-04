extends SceneTree
## Spatial state-machine fixtures for the two-wave hook-spear battle.
## The normal, non-injected playthrough remains campaign_later_playthrough.gd.

var failures: Array[String] = []
var assertions := 0
var evidence: Dictionary = {}
const LIANG := 0
const PASSIVE_STANCE := 3

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	print("[lianhuanma-depth] ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func _start():
	seed(5088120)
	var campaign = root.get_node("Campaign")
	campaign.current = campaign.index_for_id("level4")
	campaign.arena = false
	campaign.skirmish = false
	campaign.skirmish_ai = false
	campaign.scenario = false
	campaign.custom_defense = false
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	Engine.time_scale = 4.0
	return b

func _dispose(b) -> void:
	b.queue_free()
	await process_frame
	await process_frame

func _place(u, pos: Vector2) -> void:
	if not is_instance_valid(u): return
	u.order_stop()
	u.position = pos
	u._stun_t = 0.0
	u._disarm_t = 0.0

func _finish_action(b, action_id: String) -> bool:
	if not b.mission.request_action(action_id): return false
	var action: Dictionary = b.mission.actions[action_id]
	_place(b.mission._actor,b.map.cell_to_world(action.cell))
	b.mission.tick(float(action.duration)+0.05)
	return b.mission.active_action_id == ""

func _hook_units(b) -> Array:
	return b.units.filter(func(u): return is_instance_valid(u) and u.faction == LIANG and u.key in ["gou_lian","xu_ning"] and u.story_outcome == "")

func _wave(level, group: int) -> Array:
	return level.riders.filter(func(u): return is_instance_valid(u) and int(u.get_meta("wave_group",0)) == group)

func _park_wave(b, wave: Array, cell: Vector2i) -> void:
	var base: Vector2 = b.map.cell_to_world(cell)
	for i in range(wave.size()):
		var u = wave[i]
		_place(u,base+Vector2((i%3-1)*34.0,(i/3)*30.0-15.0))
		u.stance = PASSIVE_STANCE
		u.passive = true
		u.order_hold_position()
		u.passive = true

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	var campaign = root.get_node("Campaign")
	var save_existed := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_before := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_existed else PackedByteArray()
	var b = await _start()

	# Training fixture: an entered lure is insufficient until it has cleared the strike lane.
	check(_finish_action(b,"lhm_drill"),"drill demonstration action completes")
	check(_finish_action(b,"lhm_partner") and is_instance_valid(b.level.dummy),"two-person hook team sets a live practice rider")
	check(_finish_action(b,"lhm_training_lure") and b.level.training_lure_entered,"Tang Long enters the practice route")
	_place(b.level.dummy,b.map.cell_to_world(b.level.DRILL_CELL))
	b.level.process(b,0.01)
	check(not b.level.training_lure_withdrew and not b.mission.has_event("lhm_drill_complete"),"training does not arm while the lure remains in the strike lane")
	b.level.dummy.take_damage(1000000.0,b.level.xu)
	check(not b.mission.has_event("lhm_drill_complete") and not b.mission.actions.lhm_partner.done,"premature practice strike is refused and recoverable")
	var training_hooks: Array = _hook_units(b)
	var training_partner = training_hooks.filter(func(u): return u.key == "gou_lian")[0]
	_place(b.level.xu,b.map.cell_to_world(b.level.DRILL_CELL)+Vector2(-32,0))
	_place(training_partner,b.map.cell_to_world(b.level.DRILL_CELL)+Vector2(32,0))
	check(_finish_action(b,"lhm_partner") and _finish_action(b,"lhm_training_lure"),"practice target and lure action can be rebuilt")
	_place(b.level.training_lure,b.map.cell_to_world(b.level.DRILL_LURE_RETREAT))
	_place(b.level.dummy,b.map.cell_to_world(b.level.DRILL_CELL))
	b.level.process(b,0.01)
	check(b.level.training_lure_withdrew and b.mission.has_event("lhm_training_lure_withdrew"),"training lure reaches the safe retreat point")
	b.level.dummy.take_damage(1000000.0,b.level.xu)
	check(b.mission.has_event("lhm_drill_complete") and b.kills == 0,"withdrawn lure and two-person strike complete training non-lethally")

	# Battle fixture: all twelve authored riders exist once, but the rear six remain held.
	b.level._deploy_battle(b)
	var far: Vector2 = b.map.cell_to_world(Vector2i(7,55))
	var gunners: Array = b.units.filter(func(u): return is_instance_valid(u) and u.key == "gou_lian")
	for u in _hook_units(b): _place(u,far)
	var west: Vector2 = b.map.cell_to_world(b.level.REED_W)
	var south: Vector2 = b.map.cell_to_world(b.level.REED_S)
	_place(gunners[0],west); _place(gunners[1],west+Vector2(32,0))
	_place(gunners[6],south); _place(gunners[7],south+Vector2(32,0))
	check(_finish_action(b,"lhm_west_ambush") and _finish_action(b,"lhm_south_ambush") and _finish_action(b,"lhm_signal"),"both initial ambush sites and signal complete")
	var front: Array = _wave(b.level,1)
	var rear: Array = _wave(b.level,2)
	check(front.size() == 6 and rear.size() == 6 and b.level.riders.size() == 12,"authored riders split into independent six-rider front and rear groups")
	check(rear.all(func(u): return String(u.get_meta("wave_state","")) == "waiting"),"rear group is held instead of joining the first charge")

	# Entering the route starts the front riders, but two hooks still cannot fire before withdrawal.
	check(_finish_action(b,"lhm_front_lure") and b.level.wave_phase == "front_withdraw","front lure enters the selected first route")
	for u in _hook_units(b): _place(u,far)
	_place(gunners[0],west+Vector2(-32,0)); _place(gunners[1],west+Vector2(32,0))
	_park_wave(b,front,b.level.REED_W)
	b.level.process(b,0.01)
	check(b.level.front_broken == 0 and front.all(func(u): return not bool(u.get_meta("formation_broken",false))),"front armor cannot break while lure has not withdrawn")
	_place(b.level.front_lure,b.map.cell_to_world(b.level._lane_retreat(b.level.first_lane)))
	b.level.process(b,0.01)
	check(b.level.front_broken == 6 and b.level.rear_broken == 0 and rear.all(func(u): return String(u.get_meta("wave_state","")) == "waiting"),"withdrawal breaks only the front six and leaves rear six held")
	for u in front: u.take_damage(1000000.0,b.level.xu)
	b.level.process(b,0.01)
	check(b.level.front_defeated == 6 and b.level.wave_phase == "rear_redeploy" and b.level.rear_lane == "south","first group defeat switches the held group to the opposite route")

	# The used lane is rejected. A lost reserve member must be replaced at the opposite site.
	_place(gunners[0],west); _place(gunners[1],west+Vector2(32,0))
	check(_finish_action(b,"lhm_west_ambush") and not b.mission.has_event("lhm_reserve_redeployed") and not b.mission.actions.lhm_west_ambush.done,"used first lane is rejected and its action remains retryable")
	for u in _hook_units(b): _place(u,far)
	_place(gunners[6],south)
	_place(gunners[7],south+Vector2(32,0))
	gunners[7].resolve_story("captured")
	check(_finish_action(b,"lhm_south_ambush") and not b.mission.has_event("lhm_reserve_redeployed") and not b.mission.actions.lhm_south_ambush.done,"one surviving reserve gunner cannot prepare the second ambush")
	_place(gunners[8],south+Vector2(32,0))
	check(_finish_action(b,"lhm_south_ambush") and b.mission.has_event("lhm_reserve_redeployed") and b.level.wave_phase == "rear_lure","replacement gunner restores the opposite-side reserve team")

	check(_finish_action(b,"lhm_rear_lure") and b.level.wave_phase == "rear_withdraw","second lure enters the changed rear route")
	_park_wave(b,rear,b.level.REED_S)
	b.level.process(b,0.01)
	check(b.level.rear_broken == 0,"rear armor remains intact until its own lure withdraws")
	_place(b.level.rear_lure,b.map.cell_to_world(b.level._lane_retreat(b.level.rear_lane)))
	b.level.process(b,0.01)
	check(b.level.front_broken == 6 and b.level.rear_broken == 6,"opposite-side withdrawal independently breaks the rear six")
	for u in rear: u.take_damage(1000000.0,b.level.xu)
	b.level.process(b,0.01)
	check(b.level.lhm_killed == 12 and b.level.hu.story_outcome == "retreated" and b.level.hu.hp > 0.0,"twelve riders fall and Huyan Zhuo retreats alive toward Qingzhou")
	b.level.han.take_damage(1000000.0,b.level.xu)
	b.level.process(b,0.01)
	check(b.level.han.story_outcome == "captured" and b.level.han.hp > 0.0 and b.mission.has_event("lhm_victory") and b.phase == b.Phase.END,"Han Tao is captured alive and the authored ending resolves")
	evidence = {"front_broken":b.level.front_broken,"rear_broken":b.level.rear_broken,"front_defeated":b.level.front_defeated,"rear_defeated":b.level.rear_defeated,"riders_authored":b.level.riders.size(),"first_lane":b.level.first_lane,"rear_lane":b.level.rear_lane,"han_outcome":b.level.han.story_outcome,"huyan_outcome":b.level.hu.story_outcome,"total_game_seconds":b.mission.total_game_seconds,"stage_metrics":b.mission.stage_metrics}
	await _dispose(b)

	# A new chapter instance must not inherit either wave, lane, or mission events.
	b = await _start()
	check(b.level.stage == "training" and b.level.riders.is_empty() and b.level.front_broken == 0 and b.level.rear_broken == 0,"restart restores the training deployment with no rider state")
	check(b.level.first_lane == "" and b.level.rear_lane == "" and b.level.wave_phase == "" and b.mission.events.is_empty(),"restart clears lane choices, wave phase, and story events")
	await _dispose(b)

	var save_exists_now := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_after := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	var save_unchanged := save_existed == save_exists_now and save_before == save_after
	check(save_unchanged,"CAMPAIGN_QA leaves campaign progress unchanged")
	var report := {"passed":failures.is_empty(),"assertions":assertions,"failures":failures,"evidence":evidence,"campaign_qa":OS.get_environment("CAMPAIGN_QA"),"save_unchanged":save_unchanged,"scope":"spatial fixtures; normal combat proof is campaign_later_playthrough.gd"}
	var report_path := OS.get_environment("LHM_DEPTH_REPORT")
	if report_path != "":
		var file := FileAccess.open(report_path,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t"))
	print("[lianhuanma-depth-result] ",JSON.stringify(report))
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
