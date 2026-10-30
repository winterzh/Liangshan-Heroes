extends "base.gd"
## One actual chapter, seven original carts. Only wine/arrival/sample positions
## are fixtures; original load, delivery, damage and relay callbacks execute.
const Wheel = preload("res://scripts/tribute_cart_wheel_visual.gd")
const Ground = preload("res://scripts/campaign_tribute_cart_visual.gd")
const Transport = preload("res://scripts/huangnigang_transport.gd")
var out := ""
var screenshots: Array = []
var samples: Array = []

func _frames(n := 2) -> void:
	for i in range(n): await get_tree().process_frame

func _snapshot(name: String) -> Image:
	await _frames()
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out.path_join(name + ".png")
	check(image != null and not image.is_empty() and image.save_png(path) == OK, "original viewport " + name)
	screenshots.append({"path": name + ".png", "sha256": FileAccess.get_sha256(path)})
	return image

func _start_once():
	var campaign = root.get_node("Campaign")
	campaign.current = 0
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]: campaign.set(key, false)
	root.get_node("Settings").auto_micro_level = 0
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	# Production new-game API consumes the actual provider result resolved above.
	# This avoids a duplicate full source scan in Battle._ready; no provider,
	# gameplay, art, RNG or callback is stubbed and no identity is fabricated.
	var configured: Dictionary = b.configure_new_gameplay_rng(trusted, 5088120)
	check(configured.ok and b._gameplay_content_identity == trusted, "production new-game binding uses this process's actual provider identity")
	root.add_child(b); current_scene = b
	await get_tree().process_frame
	b.hud._intro_root.hide(); b._on_intro_done(); b._on_start_battle()
	check(b.phase == b.Phase.FIGHT, "actual new-game entry reaches fight")
	b.set_process(false); b.set_physics_process(false); b.fog = false
	b.camera.set_process(false); b.camera.set_physics_process(false); b.camera.position_smoothing_enabled = false
	for unit in b.units: unit.set_physics_process(false)
	b.level._ensure_bai(b, false).set_physics_process(false)
	b.level.st = b.level.CARRY; b.level.drug_done = true
	b.level._begin_cargo_choice(b); b.level._sync_controls(b); b.mission.tick(0)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	return b

func _arrive(b, actor, prefix: String) -> String:
	b.select_single(actor, false)
	var id: String = b.level._selected_transport_action(b)
	check(id.begins_with(prefix), "original next action " + actor.key + prefix)
	if id.is_empty(): return ""
	actor.order_stop(); actor.position = b.map.cell_to_world(b.mission.actions[id].cell)
	if prefix == "force_load_":
		var index: int = actor.get_meta("pushing_empty_tribute", -1)
		b.level.jujube_carts[index].position = b.level._empty_cart_anchor(actor)
	check(b.mission.request_action(id), "original mission accepts " + id)
	b.mission.tick(1.0)
	check(b.mission.actions[id].done, "original callback completes " + id)
	return id

func _frame(b, actor) -> void:
	b.map.sync_render_position(actor)
	actor.z_index = clampi(1 + int(b.map.project(actor.position).y), 1, 3400)
	b.camera.zoom = Vector2.ONE * 2.8
	b.camera.position = b.to_screen(actor.position) + Vector2(0, -25)
	b.camera.force_update_scroll()
	actor.queue_redraw()

func _cart_values(cart) -> Array:
	return [cart.position, cart.animation_direction, cart.face_left, cart.visual_scale, cart._tribute_wheel_angle, cart.z_index]

func _sample_positions(b, actor) -> Array:
	var low: Vector2; var high: Vector2
	var low_height := INF; var high_height := -INF
	var original_direction: String = actor.animation_direction
	for x in range(9, 23, 2):
		for y in range(9, 27, 2):
			var p: Vector2 = b.map.cell_to_world(Vector2i(x, y))
			if not b.map.is_open_world(p, "land"): continue
			var valid := true
			for d: String in ["se", "sw", "ne", "nw"]:
				actor.animation_direction = d
				var contact: Vector2 = b.map.project(p) + Wheel.ground_contact(actor, actor.radius * 3.7 * actor.visual_scale)
				if not b.map.is_open_world(b.map.unproject(contact), "land"): valid = false
			if not valid: continue
			var height: float = b.map.height_at(p)
			if height < low_height: low = p; low_height = height
			if height > high_height: high = p; high_height = height
	actor.animation_direction = original_direction
	check(is_finite(low_height) and is_finite(high_height), "real terrain has open handoff samples " + actor.key)
	samples.append({"owner": actor.key, "min_height": low_height, "max_height": high_height})
	return [low, high]

func _wheel_bounds(b, actor) -> Rect2i:
	var row: Dictionary = Wheel.FIT[actor.animation_direction]
	var pose: Dictionary = Wheel._pose(actor)
	var scale_native: float = actor.radius * 3.7 * actor.visual_scale / float(pose.virtual_canvas_reference)
	var tr := Vector2(row.rim_translation_original_native[0], row.rim_translation_original_native[1])
	var rc := Vector2(row.rim_plane_center[0], row.rim_plane_center[1])
	var axes: Transform2D = Wheel._matrix(row.rim_inner_plane_axes)
	var to_view: Transform2D = actor.get_global_transform_with_canvas() * b.map.ISO_INV
	var parent_view: Transform2D = actor.get_parent().get_global_transform_with_canvas()
	to_view.origin -= (parent_view.x + parent_view.y) * float(actor.get_meta("render_height", 0.0))
	var center: Vector2 = to_view * Wheel._point(pose, tr + float(row.rim_uniform_scale) * rc, scale_native)
	var bounds := Rect2(center, Vector2.ZERO)
	for i in range(64):
		var angle := TAU * float(i) / 64.0
		bounds = bounds.expand(to_view * Wheel._point(pose, tr + float(row.rim_uniform_scale) * (rc + axes * Vector2(cos(angle), sin(angle)) * 0.7), scale_native))
	return Rect2i(bounds.position.floor(), bounds.size.ceil()).intersection(Rect2i(Vector2i.ZERO, root.size))

func _geometry(b, actor, cart, index: int) -> void:
	var positions := _sample_positions(b, actor)
	var codec = load("res://scripts/run_unit_state.gd").new(null, null, null)
	for d: String in ["se", "sw", "ne", "nw"]:
		for sample in range(positions.size()):
			actor.position = positions[sample]; actor.animation_direction = d; actor.face_left = d in ["sw", "nw"]
			actor._move_blend = 0; actor._anim_t = 0; actor._flinch = Vector2.ZERO; actor._lunge = 0
			actor._tribute_wheel_angle = 0.63
			_frame(b, actor)
			var expected: Vector2 = b.map.project(actor.position) + Wheel.ground_contact(actor, actor.radius * 3.7 * actor.visual_scale)
			var ledger: Array = [b.level.delivered, b.level.cargo.duplicate(), b.level.cargo_ready.duplicate(), actor.position, actor._order_serial]
			check(Ground.place_from_carrier(cart, actor), "exact same cart accepts handoff " + actor.key + d + str(sample))
			check(b.map.project(cart.position).distance_to(expected) < 0.01, "projected wheel contact survives terrain " + actor.key + d + str(sample))
			check(cart.position.distance_to(actor.position) > 3.0, "cart is not anchored on carrier feet " + actor.key + d)
			check(cart.animation_direction == d and is_equal_approx(cart.visual_scale * Ground.BASE_BODY_SIZE, actor.radius * 3.7 * actor.visual_scale) and cart._tribute_wheel_angle == actor._tribute_wheel_angle, "direction size and live wheel phase retained " + actor.key + d)
			check(ledger == [b.level.delivered, b.level.cargo.duplicate(), b.level.cargo_ready.duplicate(), actor.position, actor._order_serial], "placement preserves actor orders and transport ledger")
			var saved: Dictionary = codec._read_explicit(cart)
			cart.position = Vector2.ZERO; cart.visual_scale = 0.2; cart.animation_direction = "se"
			codec._assign_values(cart, saved)
			check(cart.position.distance_to(saved.position) < 0.001 and cart.visual_scale == saved.visual_scale and cart.animation_direction == saved.animation_direction and cart._tribute_wheel_angle == 0.0, "existing explicit fields restore ground pose; visual angle resets")
			cart._tribute_wheel_angle = actor._tribute_wheel_angle
			if actor.key == "gongsun_sheng" and sample == 0:
				var bounds := _wheel_bounds(b, actor)
				var before := await _snapshot("handoff_" + d + "_before")
				actor.remove_meta("carrying_tribute"); b.units.append(cart); cart.show(); cart.process_mode = Node.PROCESS_MODE_DISABLED
				b.map.sync_render_position(cart); actor.queue_redraw(); cart.queue_redraw()
				var after := await _snapshot("handoff_" + d + "_after")
				var error := 0.0
				for y in range(bounds.position.y, bounds.end.y):
					for x in range(bounds.position.x, bounds.end.x):
						var delta: Color = before.get_pixel(x, y) - after.get_pixel(x, y)
						error += (absf(delta.r) + absf(delta.g) + absf(delta.b)) / 3.0
				var mean_error: float = error / maxf(1.0, bounds.size.x * bounds.size.y)
				check(mean_error < 0.12, "actual rendered wheel retains its position and phase " + d)
				samples.append({"direction": d, "wheel_region_rgb_mean_error": mean_error})
				cart.hide(); b.units.erase(cart); actor.set_meta("carrying_tribute", index); actor.queue_redraw()
	var before_wrong := _cart_values(cart)
	var variant: String = actor.art_variant
	actor.art_variant = "hn_bai_sheng"
	check(not Ground.place_from_carrier(cart, actor) and _cart_values(cart) == before_wrong, "foreign identity cannot move this cart")
	actor.art_variant = variant
	check(not Ground.place_from_carrier(b.level.bundles[(index + 1) % 7], actor), "cannot place another cargo identity")

func _run() -> void:
	out = OS.get_environment("HG_OUTPUT_ROOT")
	root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	if not identity(true): report(); return
	var b = await _start_once()
	var carried_originals: Array = []
	for owner: String in Transport.OWNERS:
		var actor = b.find_unit(owner)
		var index: int = Transport.OWNERS.find(owner)
		_arrive(b, actor, "force_take_"); _arrive(b, actor, "force_load_")
		check(actor.get_meta("carrying_tribute", -1) == index, "original loading assigns its original cargo " + owner)
		var cart = b.level.bundles[index]
		carried_originals.append(cart.get_instance_id())
		await _geometry(b, actor, cart, index)
		if owner == "ruan_xiaoqi":
			actor.animation_direction = "nw"; actor._tribute_wheel_angle = 0.63
			var death_contact: Vector2 = b.map.project(actor.position) + Wheel.ground_contact(actor, actor.radius * 3.7 * actor.visual_scale)
			actor.take_damage(100000.0, null, false, true)
			check(actor.hp <= 0 and not actor.has_meta("carrying_tribute") and b.units.has(cart) and not b.level.cargo.has(index), "real death releases the original cart")
			check(b.map.project(cart.position).distance_to(death_contact) < 0.01, "death drop keeps prior wheel contact")
			var relay = b.find_unit("wu_yong")
			_arrive(b, relay, "force_take_")
			check(relay.get_meta("carrying_tribute", -1) == index and b.level.bundles[index].get_instance_id() == carried_originals[index], "surviving original Wu relays the same cart")
			actor = relay
		b.select_single(actor, false)
		var action_id: String = b.level._selected_transport_action(b)
		check(action_id.begins_with("force_deliver_"), "delivery remains an explicit original mission action")
		actor.order_stop(); actor.position = b.map.cell_to_world(b.mission.actions[action_id].cell)
		actor.animation_direction = ["se", "sw", "ne", "nw"][index % 4]; actor.face_left = actor.animation_direction in ["sw", "nw"]
		actor._move_blend = 0; actor._anim_t = 0; actor._flinch = Vector2.ZERO; actor._lunge = 0; actor._tribute_wheel_angle = 0.63
		_frame(b, actor)
		var expected: Vector2 = b.map.project(actor.position) + Wheel.ground_contact(actor, actor.radius * 3.7 * actor.visual_scale)
		await _snapshot(owner + "_loaded")
		check(b.mission.request_action(action_id), "original delivery request accepted " + owner)
		b.mission.tick(1.0)
		check(not actor.has_meta("carrying_tribute") and Ground.layered(cart) and b.units.has(cart), "ground and actor separate after real callback " + owner)
		check(b.map.project(cart.position).distance_to(expected) < 0.01, "delivery keeps actual wheel contact " + owner)
		check(cart._tribute_wheel_angle == actor._tribute_wheel_angle and cart.animation_direction == actor.animation_direction, "delivery retains live phase and facing " + owner)
		check(b.level.bundles[index].get_instance_id() == carried_originals[index], "delivery never creates a replacement cart")
		var delivered: int = b.level.delivered; var position: Vector2 = cart.position
		b.level._force_deliver_cargo(b, action_id, actor, index)
		check(b.level.delivered == delivered and cart.position == position, "duplicate delivery changes neither count nor parked pose")
		b.map.sync_render_position(cart); actor.queue_redraw(); cart.queue_redraw()
		await _snapshot(owner + "_released")
		var checkpoint := FileAccess.open(out.path_join("checkpoint_" + owner + ".json"), FileAccess.WRITE)
		checkpoint.store_string(JSON.stringify({"owner": owner, "checks": checks, "failures": failures,
			"content_version": trusted.content_version, "screenshots": screenshots,
			"full_run_passed": false, "checkpoint_before_next_owner": true}, "\t"))
		checkpoint.close()
	var ledger: Dictionary = Transport.ledger(b.level.cargo_ready, {}, b.level._delivered_cart_indices(b), true, {})
	check(ledger.ok and ledger.complete and ledger.delivered_loads == 11 and b.level.delivered == 11 and b.level.st == b.level.WITHDRAW, "same seven carts deliver eleven loads and enter original withdraw phase")
	check(not b.level.victory, "delivery does not automatically finish manual withdrawal")
	await _dispose(b)
	report({"scope": "seven-owner ground handoff and death relay only", "screenshots": screenshots, "samples": samples,
		"same_scene_for_all_owners": true, "actual_provider_identity_reused_via_production_new_game_api": true,
		"wine_and_arrival_positions_are_fixtures": true, "full_playthrough": false, "full_regression_run": false})
