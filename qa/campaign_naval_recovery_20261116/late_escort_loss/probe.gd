extends "res://qa/campaign_naval_recovery_20261116/escort_loss/live_probe.gd"
## Live late-loss route. The player orders the carrier back into active enemy
## fire only after both original escort boats have already withdrawn.

var withdrawal: Dictionary = {}
var late_loss: Dictionary = {}
var exposure_orders := 0
var first_enemy_distance := -1.0
var lowest_observed_hp := -1.0
var last_exposure: Dictionary = {}

func _story(b, time: float) -> void:
	var level = b.level
	if b.mission.has_event("liu_tang_lost"):
		var occupied: int = b.count_alive(0,"liu_tang")
		late_loss = {
			"game_seconds":time,
			"level_elapsed":level.elapsed,
			"carrier_id":departed_ship_id,
			"carrier_alive":b.units.any(func(u): return alive(u) and u.entity_id == departed_ship_id),
			"fire_credit_present":b.mission.has_event("fire_escort_safe"),
			"fire_goal_state":b.mission.story_goals.gao_fire.state,
			"hero_reservations":occupied,
			"cleared_carrier_reference":level.liu_carrier==null and level.embarked_liu==null,
			"return_blocked":not String(b.mission.actions.gao_liu_return.get("blocked_reason","")).is_empty(),
			"hall_block":b._train_block_reason(level.hall,"liu_tang"),
			"last_exposure":last_exposure.duplicate(true),
		}
		print("[gao-late-escort-loss] ",JSON.stringify(late_loss))
		story_phase = "rebuild"
		route = "recruiting"
		return
	var ship = level.liu_carrier
	if level.fire_lit and alive(ship) and ignition_time < 0:
		ignition_time = time
		departed_ship_id = ship.entity_id
	if is_instance_valid(level.embarked_liu) and embark_uniqueness.is_empty():
		embark_uniqueness = b._train_block_reason(level.hall,"liu_tang")
	if not b.mission.has_event("fire_escort_safe"):
		# Invoke the ordinary story sequence without the early-loss driver's
		# intentional interception at ignition.
		_drive_to_withdrawal(b, time)
		return
	if not alive(ship):
		return
	if withdrawal.is_empty():
		var other = b.find_unit("ruan_xiaowu_boat")
		withdrawal = {
			"game_seconds":time,
			"level_elapsed":level.elapsed,
			"ignition_game_seconds":ignition_time,
			"carrier_id":ship.entity_id,
			"carrier_hp":ship.hp,
			"second_original_ship_alive":alive(other),
			"embarked_original_hero":is_instance_valid(level.embarked_liu) and level.embarked_liu.entity_id==initial_liu_id,
			"original_id_still_reserved":b._train_block_reason(level.hall,"liu_tang")=="hero_exists",
			"all_fire_events":b.mission.story_goals.gao_fire.required_events.all(b.mission.has_event),
		}
		lowest_observed_hp = ship.hp
		print("[gao-late-escort-withdrawal] ", JSON.stringify(withdrawal))
	story_phase = "withdraw"
	var visible_foes: Array = b.units.filter(func(u):
		return alive(u) and u.faction == 1 and u.movement_profile == "water" and b.is_visible_world(u.position)
	)
	visible_foes.sort_custom(func(a,z):
		return a.position.distance_squared_to(ship.position) < z.position.distance_squared_to(ship.position)
	)
	var target_cell: Vector2i = level.SEA_FRONT
	var enemy_id := -1
	if not visible_foes.is_empty():
		var enemy = visible_foes[0]
		var gap: float = ship.position.distance_to(enemy.position)
		if first_enemy_distance < 0:
			first_enemy_distance = gap
		enemy_id = enemy.entity_id
		target_cell = b.map.world_to_cell(enemy.position)
	_click(b,[ship],target_cell)
	exposure_orders += 1
	lowest_observed_hp = minf(lowest_observed_hp,ship.hp)
	last_exposure = {"hp":ship.hp,"enemy_id":enemy_id,"cell":[target_cell.x,target_cell.y],"orders":exposure_orders}
	if exposure_orders == 1 or int(time)%10 == 0:
		print("[gao-late-escort-exposure] ", JSON.stringify(last_exposure))

func _drive_to_withdrawal(b, time: float) -> void:
	var level = b.level
	# Same successful opening used in the original natural fire route. After
	# withdrawing, the main driver above replaces only the return order.
	match story_phase:
		"lure":
			if b.units.filter(func(u): return alive(u) and u.faction==0 and u.key=="liangshan_warship").size()>=2:
				_action(b,b.find_unit("ruan_xiaoqi_boat"),"gao_lure_side")
			if level.lure_started:
				_click(b,[b.find_unit("ruan_xiaoqi_boat")],Vector2i(36,49))
				story_phase = "wind"
		"wind":
			_action(b,b.find_unit("gongsun_sheng"),"gao_wind")
			if b.mission.has_event("gongsun_wind"):
				story_phase = "prepare"
		"prepare":
			_action(b,b.find_unit("liu_tang"),"gao_prepare")
			if level.fire_prepared:
				story_phase = "fire"
		"fire":
			var escorts: Array = [b.find_unit("ruan_xiaoer_boat"),b.find_unit("ruan_xiaowu_boat")].filter(func(u): return alive(u))
			if time > 280:
				_click(b,escorts,level.FIRE_POINTS[1]+Vector2i(-1,1))
				_action(b,level.fireboat,"gao_fire_1")
			else:
				_click(b,escorts,level.FIRE_SAFE)
			if level.fire_lit:
				story_phase = "withdraw"
		"withdraw":
			var five = b.find_unit("ruan_xiaowu_boat")
			if alive(five):
				_click(b,[five],level.FIRE_SAFE)
			_action(b,b.find_unit("ruan_xiaoer_boat"),"gao_fire_withdraw")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	root.size = Vector2i(1440,900)
	build_cells = [Vector2i(24,26),Vector2i(26,40),Vector2i(14,42),Vector2i(10,43),Vector2i(21,40),Vector2i(26,23),Vector2i(9,31),Vector2i(15,24)]
	route = "story"
	var b = await _start("",4)
	Engine.time_scale = 4.0
	initial_liu_id = b.find_unit("liu_tang").entity_id
	initial_ship_id = b.level.fireboat.entity_id
	escort_id = b.find_unit("ruan_xiaoer_boat").entity_id
	var hall_id: int = b.level.hall.entity_id
	await _play_gao(b)
	var done: Dictionary = b.mission.result_snapshot(b.mission.has_event("gao_basic_victory"))
	check(withdrawal.get("all_fire_events",false) and withdrawal.get("second_original_ship_alive",false)
		and withdrawal.get("embarked_original_hero",false) and withdrawal.get("original_id_still_reserved",false)
		and withdrawal.get("carrier_id",-1)==escort_id and initial_ship_id!=escort_id,
		"both normal escort boats withdraw first, while original Liu Tang remains aboard Ruan Xiaoer")
	check(not late_loss.is_empty() and late_loss.get("level_elapsed",0)>withdrawal.get("level_elapsed",0)
		and first_enemy_distance>=0 and exposure_orders>=1 and lowest_observed_hp<withdrawal.get("carrier_hp",0)
		and not late_loss.get("carrier_alive",true) and late_loss.get("carrier_id",-1)==escort_id,
		"normal enemy combat sinks the original carrier after the credited withdrawal")
	check(late_loss.get("fire_credit_present",false) and late_loss.get("fire_goal_state","")!="missed"
		and late_loss.get("hero_reservations",-1)==0 and late_loss.get("cleared_carrier_reference",false)
		and late_loss.get("return_blocked",false) and not b.mission.has_event("gao_liu_returned"),
		"late loss retains the event and clears the passenger reservation and impossible return")
	check(recruitment.get("hall_id",-1)==hall_id and recruitment.get("paid",[])==recruitment.get("cost",[-1])
		and recruitment.get("second_order_block","")=="hero_exists" and recruitment.get("paid",[0,0])[0]>0
		and replacement.get("entity_id",-1)>0 and replacement.get("entity_id",-1)!=initial_liu_id
		and replacement.get("movement_profile","")=="land" and replacement.get("remaining_reservations",-1)==1,
		"the original hall pays to reassemble one nonduplicated land hero")
	check(b.mission.has_event("gao_basic_victory") and "gao_fire" in done.done_ids and "gao_fire" not in done.missed_ids,
		"the ordinary fleet wins and the fulfilled fire attack still counts in settlement")
	print("GAO_LATE_ESCORT_LOSS_RESULT ",JSON.stringify({
		"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":play_metrics,
		"withdrawal":withdrawal,"loss":late_loss,"recruitment":recruitment,"replacement":replacement,
		"exposure":{"orders":exposure_orders,"first_visible_enemy_distance":first_enemy_distance,"lowest_hp":lowest_observed_hp},
		"time_scale":Engine.time_scale,"scope":"normal player orders, live enemy fire after withdrawal and paid recruitment",
	}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
