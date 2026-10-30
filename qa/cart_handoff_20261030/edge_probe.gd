extends "probe.gd"
## Only the newly added unreachable/out-of-map wheel-contact fallback.
func _run() -> void:
	out = OS.get_environment("HG_OUTPUT_ROOT")
	root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	if not identity(true): report(); return
	var b = await _start_once()
	var actor = b.find_unit("liu_tang")
	_arrive(b, actor, "force_take_"); _arrive(b, actor, "force_load_")
	var cart = b.level.bundles[3]
	var cases: Array = [{"name": "out_of_map_defensive_fixture", "position": Vector2(1, 1), "direction": "nw", "actor_position_is_natural": false}]
	var found := false
	for x in range(b.map.w):
		if found: break
		for y in range(b.map.h):
			if found: break
			var p: Vector2 = b.map.cell_to_world(Vector2i(x, y))
			if not b.map.is_open_world(p, "land"): continue
			for direction: String in ["se", "sw", "ne", "nw"]:
				actor.animation_direction = direction
				var projected: Vector2 = b.map.project(p) + Wheel.ground_contact(actor, actor.radius * 3.7 * actor.visual_scale)
				var expected: Vector2 = b.map.unproject(projected)
				if not b.map.is_open_world(expected, "land"):
					cases.append({"name": "legal_actor_blocked_cart_contact", "position": p, "direction": direction, "actor_position_is_natural": true})
					found = true
					break
	check(found, "actual chapter has a legal actor point beside an unreachable wheel contact")
	for row in cases:
		actor.position = row.position; actor.animation_direction = row.direction
		var expected: Vector2 = b.map.unproject(b.map.project(actor.position) + Wheel.ground_contact(actor, actor.radius * 3.7 * actor.visual_scale))
		check(not b.map.is_open_world(expected, "land"), "fixture exercises unreachable exact contact " + row.name)
		var before: Array = [actor.position, actor._order_serial, b.level.delivered, b.level.cargo.duplicate(), b.level.cargo_ready.duplicate()]
		check(Ground.place_from_carrier(cart, actor), "handoff accepts original cart at edge " + row.name)
		check(cart.position.is_finite() and b.map.is_open_world(cart.position, "land"), "fallback wheel anchor is finite and on reachable land " + row.name)
		check(before == [actor.position, actor._order_serial, b.level.delivered, b.level.cargo.duplicate(), b.level.cargo_ready.duplicate()], "edge fallback preserves actor and cargo ledger " + row.name)
		check(b.level.bundles[3] == cart and actor.get_meta("carrying_tribute", -1) == 3, "edge fallback preserves original identities")
	await _dispose(b)
	report({"scope": "unreachable and out-of-map wheel contact fallback only", "screenshots": [],
		"same_scene_for_all_cases": true, "actual_provider_identity_reused_via_production_new_game_api": true,
		"wine_and_arrival_positions_are_fixtures": true, "out_of_map_actor_is_explicit_defensive_fixture": true,
		"full_playthrough": false, "full_regression_run": false})
