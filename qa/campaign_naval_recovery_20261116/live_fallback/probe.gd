extends "res://tools/gao_rts_play.gd"
## Live route. Reuses the ordinary economy and combat driver.

var initial_liu_id := -1
var return_ship_id := -1
var return_origin := Vector2.ZERO
var return_distance := 0.0
var orders_at_return := 0
var fallback: Dictionary = {}
var return_trigger := ""
var return_hp := 0.0
var return_max_hp := 0.0

func _story(b, time: float) -> void:
	var l = b.level
	if return_trigger.is_empty():
		if l.fire_lit:
			return_trigger = "ignited"
		elif l.fire_prepared and story_phase == "fire" and alive(l.fireboat) and l.fireboat.hp < l.fireboat.max_hp:
			return_trigger = "damage_during_approach"
		else:
			super._story(b,time)
			return
	if not b.mission.has_event("gao_liu_returned"):
		var ship = l.liu_carrier if l.fire_lit else l.fireboat
		if not alive(ship): return
		if return_ship_id < 0:
			return_ship_id = ship.entity_id
			return_origin = ship.position
			return_hp = ship.hp
			return_max_hp = ship.max_hp
			print("[gao-fire-fallback] ",return_trigger," at ",time," using original ship ",return_ship_id,
				" HP ",return_hp,"/",return_max_hp)
		return_distance = maxf(return_distance,ship.position.distance_to(return_origin))
		# Keep the actual carrier out of the regular fleet screen until dock transfer.
		story_phase = "return"
		var before := orders
		_action(b,ship,"gao_liu_return")
		orders_at_return += orders-before
		return
	var hero = b.find_unit("liu_tang")
	fallback = {
		"game_seconds":time,
		"original_hero_id":initial_liu_id,
		"returned_hero_id":hero.entity_id if alive(hero) else -1,
		"return_ship_id":return_ship_id,
		"reason":return_trigger,
		"ship_hp_at_return_order":return_hp,
		"ship_max_hp":return_max_hp,
		"fire_ignited":l.fire_lit,
		"return_distance":return_distance,
		"return_orders":orders_at_return,
		"abandoned":l.fire_abandoned,
		"safe_withdrawal":b.mission.has_event("fire_escort_safe"),
		"fire_goal_state":b.mission.story_goals.get("gao_fire",{}).get("state",""),
		"ordinary_warships_queued_at_return":units_queued_by_key.get("liangshan_warship",0),
	}
	print("[gao-fire-fallback] returned ",JSON.stringify(fallback))
	story_phase = "fallback"
	route = "assault"

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
	var original_hall_id: int = b.level.hall.entity_id
	var original_xiaoer_id: int = b.find_unit("ruan_xiaoer_boat").entity_id
	var original_fireboat_id: int = b.level.fireboat.entity_id
	await _play_gao(b)
	check(b.mission.has_event("fireboat_prepared") and (b.mission.has_event("gao_fire_lit")
		or (return_trigger=="damage_during_approach" and return_hp>0.0 and return_hp<return_max_hp)),
		"normal orders pay for preparation and the sortie either takes enemy damage or ignites")
	var expected_carrier := original_xiaoer_id if b.mission.has_event("gao_fire_lit") else original_fireboat_id
	check(fallback.get("return_ship_id",-1)==expected_carrier and fallback.get("return_orders",0)>0
		and fallback.get("return_distance",0)>96,"original carrier receives normal return orders and actually travels toward the pier")
	check(fallback.get("returned_hero_id",-1)==initial_liu_id and b.mission.has_event("gao_liu_returned"),
		"normal dock action returns the same Liu Tang without respawning")
	check(fallback.get("abandoned",false) and not fallback.get("safe_withdrawal",true)
		and fallback.get("fire_goal_state","")=="missed","disembark before the escort goal forfeits only the fire-attack route")
	check(b.mission.has_event("gao_basic_victory") and not b.mission.has_event("gao_captured") and b.level.hall.entity_id==original_hall_id,
		"the original camp survives and settles ordinary withdrawal after returning")
	check(units_queued_by_key.get("liangshan_warship",0)>fallback.get("ordinary_warships_queued_at_return",99999)
		or (not fallback.is_empty() and units_queued_by_key.get("liangshan_warship",0)>=3),
		"paid ordinary fleet remains available through fallback")
	var summary = {
		"passed":failures.is_empty(),
		"checks":checks,
		"failures":failures,
		"metrics":play_metrics,
		"fallback":fallback,
		"time_scale":Engine.time_scale,
		"scope":"live combat and player commands; return decision on damaged approach or ignition before the escort objective"
	}
	print("GAO_LIVE_FALLBACK_RESULT ",JSON.stringify(summary))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
