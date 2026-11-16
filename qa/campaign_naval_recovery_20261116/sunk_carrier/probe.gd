extends "res://tools/gao_rts_play.gd"
## Live setback route. Normal orders drive all battle and recruitment effects.

var initial_liu_id := -1
var initial_ship_id := -1
var embark_uniqueness := ""
var departed_ship_id := -1
var lost: Dictionary = {}
var recruitment: Dictionary = {}
var replacement: Dictionary = {}

func _story(b, time: float) -> void:
	var level = b.level
	if b.mission.has_event("liu_tang_lost"):
		var occupied: int = b.count_alive(0,"liu_tang")
		lost = {
			"game_seconds":time,
			"fire_ignited":level.fire_lit,
			"initial_hero_id":initial_liu_id,
			"initial_ship_id":initial_ship_id,
			"carrier_id":departed_ship_id,
			"carrier_alive":b.units.any(func(u): return alive(u) and u.entity_id == departed_ship_id),
			"hero_reservations":occupied,
			"return_blocked":not String(b.mission.actions.gao_liu_return.get("blocked_reason","")).is_empty(),
			"fire_goal_state":b.mission.story_goals.gao_fire.state,
			"hall_block":b._train_block_reason(level.hall,"liu_tang"),
		}
		print("[gao-fire-loss] ",JSON.stringify(lost))
		story_phase = "rebuild"
		route = "recruiting"
		return
	if is_instance_valid(level.embarked_liu):
		if embark_uniqueness.is_empty():
			embark_uniqueness = b._train_block_reason(level.hall,"liu_tang")
		var carrying = level.liu_carrier if level.fire_lit else level.fireboat
		if alive(carrying): departed_ship_id = carrying.entity_id
	if level.fire_lit:
		# Commit the original carrier to the harbor fight instead of ordering
		# the story withdrawal. Only enemy combat can sink the ship.
		var ship = level.liu_carrier
		if alive(ship):
			var hostile: Array = b.units.filter(func(u): return alive(u) and u.faction == 1 and not u.is_building and u.movement_profile == "water")
			hostile.sort_custom(func(a,z): return a.position.distance_squared_to(ship.position)<z.position.distance_squared_to(ship.position))
			var goal: Vector2i = level.SEA_FRONT if hostile.is_empty() else b.map.world_to_cell(hostile[0].position)
			_click(b,[ship],goal,true)
		story_phase = "return" # Reserve the carrier's orders from the ordinary fleet group.
		return
	super._story(b,time)

func _economy_gao(b) -> void:
	if route == "recruiting":
		var hall = b.level.hall
		if recruitment.is_empty():
			var cost: Array = [int(b._defs.liu_tang.get("cost_gold",0)),int(b._defs.liu_tang.get("cost_wood",0))]
			var before: Array = [b.gold,b.wood]
			if b.queue_train(hall,"liu_tang",false):
				recruitment = {
					"game_seconds":b.level.elapsed,
					"hall_id":hall.entity_id,
					"cost":cost,
					"paid":[before[0]-b.gold,before[1]-b.wood],
					"second_order_block":b._train_block_reason(hall,"liu_tang"),
					"train_seconds":b.train_time_for("liu_tang"),
				}
				units_queued += 1
				units_queued_by_key["liu_tang"] = 1
				print("[gao-fire-recruit] ",JSON.stringify(recruitment))
		else:
			var hero = b.find_unit("liu_tang")
			if alive(hero) and hero.entity_id != initial_liu_id:
				replacement = {
					"game_seconds":b.level.elapsed,
					"entity_id":hero.entity_id,
					"remaining_reservations":b.count_alive(0,"liu_tang"),
					"duplicate_block":b._train_block_reason(hall,"liu_tang"),
					"movement_profile":hero.movement_profile,
				}
				print("[gao-fire-replacement] ",JSON.stringify(replacement))
				story_phase = "fallback"
				route = "assault"
	super._economy_gao(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	build_cells=[Vector2i(24,26),Vector2i(26,40),Vector2i(14,42),Vector2i(10,43),Vector2i(21,40),Vector2i(26,23),Vector2i(9,31),Vector2i(15,24)]
	route = "story"
	var b = await _start("",4)
	Engine.time_scale = 4.0
	initial_liu_id = b.find_unit("liu_tang").entity_id
	initial_ship_id = b.level.fireboat.entity_id
	var hall_id: int = b.level.hall.entity_id
	await _play_gao(b)
	check(b.mission.has_event("fireboat_prepared") and embark_uniqueness=="hero_exists",
		"normal boarding pays preparation and preserves Liu Tang's uniqueness while at sea")
	check(b.mission.has_event("liu_tang_lost") and lost.get("carrier_id",-1)>0 and not lost.get("carrier_alive",true)
		and lost.get("hero_reservations",-1)==0,"enemy combat sinks the original carrier and releases the lost hero reservation")
	check(lost.get("return_blocked",false) and lost.get("fire_goal_state","")=="missed"
		and not b.mission.has_event("gao_liu_returned"),"the lost carrier cannot disembark and the fire route fails")
	check(recruitment.get("hall_id",-1)==hall_id and recruitment.get("paid",[])==recruitment.get("cost",[-1])
		and recruitment.get("paid",[0,0])[0]+recruitment.get("paid",[0,0])[1]>0
		and recruitment.get("second_order_block","")=="hero_exists","the original hall pays exactly the normal recruitment cost and rejects duplicates")
	check(replacement.get("entity_id",-1)>0 and replacement.get("entity_id",-1)!=initial_liu_id
		and replacement.get("movement_profile","")=="land" and replacement.get("remaining_reservations",-1)==1
		and replacement.get("duplicate_block","")=="hero_exists","one replacement Liu Tang trains normally and appears on land")
	check(b.mission.has_event("gao_basic_victory") and b.level.hall.entity_id==hall_id
		and "gao_fire" in b.mission.result_snapshot(true).missed_ids,"ordinary forces finish by withdrawing and settle the failed fire goal correctly")
	var summary = {
		"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":play_metrics,
		"loss":lost,"recruitment":recruitment,"replacement":replacement,"time_scale":Engine.time_scale,
		"scope":"live enemy combat and ordinary hall recruitment after the original carrier sinks",
	}
	print("GAO_SUNK_CARRIER_RESULT ",JSON.stringify(summary))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
