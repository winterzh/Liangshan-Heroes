extends "res://tools/gao_rts_play.gd"
## Live regression: use the original commands through ignition and safe withdrawal.

var initial_liu_id := -1
var expected_carrier_id := -1
var ignition: Dictionary = {}
var returned: Dictionary = {}
var readiness: Dictionary = {}

func _story(b,time: float) -> void:
	var level = b.level
	if level.fire_prepared and readiness.is_empty():
		readiness = {"inner_cell":[level.FIRE_POINTS[1].x,level.FIRE_POINTS[1].y],
			"reach":b.mission.actions.gao_fire_1.reach,"margin":b.mission.actions.gao_fire_1.settle_margin,
			"radius":level.fireboat.radius,
			"inner_navigable":level.Naval.clear_water(b.map,level.FIRE_POINTS[1],level.fireboat.radius)}
	if story_phase == "fire" and time >= 288 and int(time)%10 == 0 and alive(level.fireboat):
		var nearby: Array = level._fire_targets(level.fireboat)
		print("[gao-fire-approach] ",JSON.stringify({"t":time,"hp":level.fireboat.hp,
			"active":b.mission.active_action_id,"status":b.mission._status.text,
			"toward_marker":level.fireboat.position.distance_to(b.map.cell_to_world(level.FIRE_POINTS[1])),
			"targets_in_range":nearby.size(),"escorts":level._fire_escorts(b,level.fireboat).size()}))
	if level.fire_lit and ignition.is_empty():
		ignition = {"game_seconds":time,"carrier_id":level.liu_carrier.entity_id,
			"original_boat_retired":level.fireboat.story_outcome=="retreated",
			"fire_action":b.mission.has_event("action:gao_rts:gao_fire_1")}
		print("[gao-fire-approach] ignited ",JSON.stringify(ignition))
	if b.mission.has_event("gao_liu_returned"):
		var hero = b.find_unit("liu_tang")
		returned = {"game_seconds":time,"hero_id":hero.entity_id if alive(hero) else -1,
			"fire_safe":b.mission.has_event("fire_escort_safe"),"abandoned":level.fire_abandoned}
		print("[gao-fire-approach] return ",JSON.stringify(returned))
		story_phase = "finished_fire"
		route = "assault"
		return
	super._story(b,time)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	route = "story"
	build_cells=[Vector2i(24,26),Vector2i(26,40),Vector2i(14,42),Vector2i(10,43),Vector2i(21,40),Vector2i(26,23),Vector2i(9,31),Vector2i(15,24)]
	var b = await _start("",4)
	Engine.time_scale = 4.0
	initial_liu_id = b.find_unit("liu_tang").entity_id
	expected_carrier_id = b.find_unit("ruan_xiaoer_boat").entity_id
	await _play_gao(b)
	check(readiness.get("inner_navigable",false) and readiness.get("inner_cell",[])==[40,40]
		and readiness.get("reach",0)==48 and readiness.get("margin",0)==12,
		"new inner marker has clear navigable water and retains original arrival range")
	check(b.mission.has_event("gao_fire_lit") and ignition.get("fire_action",false)
		and ignition.get("carrier_id",-1)==expected_carrier_id and ignition.get("original_boat_retired",false),
		"ordinary commands ignite at inner marker and transfer Liu Tang to original rescue boat")
	check(returned.get("hero_id",-1)==initial_liu_id and returned.get("fire_safe",false)
		and not returned.get("abandoned",true),"both rescue boats withdraw and the original Liu Tang disembarks")
	check(b.mission.has_event("gao_basic_victory") and "gao_fire" in b.mission.result_snapshot(true).done_ids,
		"ordinary withdrawal continues through a basic victory while keeping the fire story goal")
	print("GAO_FIRE_APPROACH_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"readiness":readiness,"ignition":ignition,"returned":returned,"metrics":play_metrics,
		"time_scale":Engine.time_scale,"scope":"actual economy, normal move and attack orders, retreat then basic victory"}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
