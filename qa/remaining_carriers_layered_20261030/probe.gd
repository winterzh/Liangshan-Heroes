extends "base.gd"
## Scoped source-project integration probe. Wine prerequisite and sampling
## positions are explicit fixtures; this does not qualify an ordinary playthrough.
const Wheel = preload("res://scripts/tribute_cart_wheel_visual.gd")
var screenshots: Array = []
var visual_samples: Array = []
var out := ""
var current_owner := ""

func _frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame

func _snapshot(name: String) -> Image:
	await _frames()
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	name = current_owner + "_" + name.trim_prefix(current_owner + "_")
	var path := out.path_join(name + ".png")
	check(image != null and not image.is_empty(), name + ": rendered viewport")
	check(image.save_png(path) == OK, name + ": saved original screenshot")
	screenshots.append({"path": name + ".png", "sha256": FileAccess.get_sha256(path)})
	return image

func _arrive(b, actor, prefix: String) -> void:
	b.select_single(actor, false)
	var id: String = b.level._selected_transport_action(b)
	check(id.begins_with(prefix), "fixture selects exact original transport action")
	if id.is_empty(): return
	actor.order_stop()
	actor.position = b.map.cell_to_world(b.mission.actions[id].cell)
	if prefix == "force_load_":
		var index: int = actor.get_meta("pushing_empty_tribute", -1)
		b.level.jujube_carts[index].position = b.level._empty_cart_anchor(actor)
	check(b.mission.request_action(id), "original mission accepts fixture arrival " + prefix)
	b.mission.tick(1.0)
	check(b.mission.actions[id].done, "original callback completes " + prefix)

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
		var a := TAU * float(i) / 64.0
		bounds = bounds.expand(to_view * Wheel._point(pose,
			tr + float(row.rim_uniform_scale) * (rc + axes * Vector2(cos(a), sin(a)) * float(row.clip_inner_radius)), scale_native))
	return Rect2i(bounds.position.floor(), bounds.size.ceil()).grow(3).intersection(Rect2i(Vector2i.ZERO, root.size))

func _wheel_matrix(b, actor) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/direction4/level1_" + actor.key + "_layered_20261030.json"))
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.camera.zoom = Vector2.ONE * 2.8
	actor.position = b.map.cell_to_world(Vector2i(12, 12))
	actor._move_blend = 1.0
	actor._lunge = 0.0; actor._cast_t = 0.0; actor._shi_en_hurt_t = 0.0; actor._flinch = Vector2.ZERO
	b.select_single(actor, false)
	for d: String in ["se", "sw", "ne", "nw"]:
		actor.animation_direction = d; actor.face_left = d in ["sw", "nw"]
		b.map.sync_render_position(actor)
		b.camera.position = b.to_screen(actor.position) + Vector2(0, -22)
		b.camera.force_update_scroll()
		var pose: Dictionary = Wheel._pose(actor)
		var expected: Dictionary = manifest.poses["cart_only_" + d]
		check(pose.pivot_native == expected.pivot_native and pose.virtual_canvas_reference == expected.virtual_canvas_reference,
			actor.key + d + ": retains its own adopted cart registration")
		var size: float = actor.radius * 3.7 * actor.visual_scale
		check(Wheel.enabled(actor), actor.key + d + ": loaded actor enables independent wheel")
		check(Wheel.phase_delta(actor, Vector2.ZERO, size) == 0.0, "parked cart cannot spin " + actor.key + d)
		check(Wheel.phase_delta(actor, Vector2(8, 0), size) > 0.0, "actual displacement advances wheel " + actor.key + d)
		for field: String in ["_lunge", "_cast_t", "_shi_en_hurt_t"]:
			actor.set(field, 0.1)
			check(Wheel.phase_delta(actor, Vector2(8, 0), size) == 0.0, field + " cannot spin cart")
			actor.set(field, 0.0)
		actor._flinch = Vector2(2, 0)
		check(Wheel.phase_delta(actor, Vector2(8, 0), size) == 0.0, "recoil cannot spin cart")
		actor._flinch = Vector2.ZERO
		var original_variant: String = actor.art_variant
		actor.art_variant = ""
		check(not Wheel.enabled(actor), "ordinary actor cannot borrow chapter wheel")
		actor.art_variant = "hn_wu_yong"
		check(not Wheel.enabled(actor), "foreign actor variant cannot borrow chapter wheel")
		actor.art_variant = original_variant
		actor._anim_t = 0.1; actor._tribute_wheel_angle = 0.1; actor.queue_redraw()
		var a := await _snapshot(actor.key + "_" + d + "_a")
		actor._tribute_wheel_angle = 0.8; actor.queue_redraw()
		var c := await _snapshot(actor.key + "_" + d + "_b")
		var bounds := _wheel_bounds(b, actor)
		var changed := 0
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				if a.get_pixel(x, y) != c.get_pixel(x, y): changed += 1
		check(changed > 4, actor.key + d + ": wheel phase changes actual rendered pixels")
		visual_samples.append({"actor": actor.key, "direction": d, "changed_wheel_pixels": changed})
	# The normal Unit callback, including motion/gait, remains the production one.
	b.process_mode = Node.PROCESS_MODE_INHERIT
	actor.order_stop(); actor.animation_direction = "se"
	actor.position = b.map.cell_to_world(b.map.nearest_open(Vector2i(12, 12), "land"))
	var origin: Vector2 = actor.position
	var angle: float = actor._tribute_wheel_angle
	actor.set_physics_process(true)
	actor.order_move(b.map.cell_to_world(b.map.nearest_open(Vector2i(16, 12), "land")))
	var seen: Array = []
	var walk: Array = root.get_node("Art").unit_anim_frames(actor.key, "push_walk", "se", actor.art_variant)
	for i in range(120):
		await get_tree().physics_frame
		var index: int = walk.find(actor._anim_frame_for_state(null))
		if index >= 0 and not seen.has(index): seen.append(index)
	check(seen.size() == 4, "normal original Unit movement visits all four authored gait phases")
	actor.set_physics_process(false); actor.order_stop()
	check(actor.position.distance_to(origin) > 1.0 and actor._tribute_wheel_angle != angle,
		actor.key + ": normal Unit movement drives independent wheel")
	var codec = load("res://scripts/run_unit_state.gd").new(null, null, null)
	var raw: Dictionary = codec._read_explicit(actor)
	var gait: float = actor._anim_t
	check(not raw.has("_tribute_wheel_angle"), "wheel stays outside persisted gameplay state")
	codec._assign_values(actor, raw)
	check(actor._tribute_wheel_angle == 0.0 and actor._anim_t == gait, "restore resets visual wheel and preserves saved gait")

func _gait_views(b, actor) -> void:
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.camera.zoom = Vector2.ONE * 2.8
	actor.position = b.map.cell_to_world(Vector2i(12, 12))
	actor._lunge = 0; actor._cast_t = 0; actor._shi_en_hurt_t = 0; actor._flinch = Vector2.ZERO
	var art = root.get_node("Art")
	for direction: String in ["se", "sw", "ne", "nw"]:
		actor.animation_direction = direction; actor.face_left = direction in ["sw", "nw"]
		b.map.sync_render_position(actor)
		b.camera.position = b.to_screen(actor.position) + Vector2(0, -22)
		b.camera.force_update_scroll()
		var idle: Array = art.unit_anim_frames(actor.key, "push_idle", direction, actor.art_variant)
		var walk: Array = art.unit_anim_frames(actor.key, "push_walk", direction, actor.art_variant)
		check(idle.size() == 1 and walk.size() == 4, "carrier has own idle and four walk phases " + direction)
		actor._move_blend = 0; actor._anim_t = 0; actor.queue_redraw()
		check(actor._campaign_tribute_layered_frame(actor._anim_frame_for_state(null)), "own idle selects separate actor and cart " + direction)
		await _snapshot("idle_" + direction)
		for i in range(4):
			actor._move_blend = 1; actor._anim_t = (float(i) + 0.15) * TAU / 4.0; actor.queue_redraw()
			check(actor._anim_frame_for_state(null) == walk[i], "actual Unit selects exact own phase " + direction + str(i))
			check(actor._campaign_tribute_layered_frame(walk[i]), "only own actor frame opts into separate cart " + direction + str(i))
			await _snapshot("walk_" + direction + "_" + str(i))
		actor._flinch = Vector2(3, 0); actor.queue_redraw()
		check(actor._campaign_tribute_push_state().is_empty() and not actor._campaign_tribute_layered_frame(actor._anim_frame_for_state(null)), "hurt uses own combat body beside parked cart")
		await _snapshot("hurt_" + direction)
		actor._flinch = Vector2.ZERO; actor._lunge = 0.6; actor.queue_redraw()
		check(actor._campaign_tribute_push_state().is_empty(), "attack interrupts push gait without deleting the cart")
		await _snapshot("attack_" + direction)
		actor._lunge = 0
	b.process_mode = Node.PROCESS_MODE_INHERIT

func _run() -> void:
	out = OS.get_environment("HG_OUTPUT_ROOT")
	root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	if not identity(true): report(); return
	var art = root.get_node("Art")
	var routing = load("res://scripts/campaign_art.gd")
	for owner: String in routing.NATIVE_TRIBUTE_LAYERED_FAMILIES:
		var family: String = routing.NATIVE_TRIBUTE_LAYERED_FAMILIES[owner]
		for d: String in ["se", "sw", "ne", "nw"]:
			for state: String in ["push_idle", "push_walk", "parked_cart"]:
				check(routing.native_tribute_push_path(owner, "hn_" + owner, state, d) == "res://assets/anim/" + family + "_" + state + "_" + d + ".tres", "exact own layered route " + owner + state + d)
				check(art.unit_anim_frames(owner, state, d, "hn_" + owner).size() == (4 if state == "push_walk" else 1), "actual imported family " + owner + state + d)
			for foreign: String in ["", "hn_bai_sheng", "hn_not_an_owner"]:
				check(routing.native_tribute_push_path(owner, foreign, "push_walk", d).is_empty(), "reject foreign/ordinary body route " + owner + foreign + d)
	var requested: PackedStringArray = OS.get_environment("HG_CARRIER_OWNERS").split(",", false)
	for owner: String in requested:
		check(owner in ["gongsun_sheng", "ruan_xiaoer", "ruan_xiaowu"], "explicit carrier scope is registered")
		if owner not in ["gongsun_sheng", "ruan_xiaoer", "ruan_xiaowu"]: continue
		current_owner = owner
		var b = await _start()
		b.set_process(false); b.set_physics_process(false); b.fog = false
		b.camera.set_process(false); b.camera.set_physics_process(false); b.camera.position_smoothing_enabled = false
		for unit in b.units: unit.set_physics_process(false)
		b.level._ensure_bai(b, false).set_physics_process(false)
		var actor = b.find_unit(owner)
		check(is_instance_valid(actor) and actor.art_variant == "hn_" + owner, "actual original chapter identity " + owner)
		var original_idle: Array = art.unit_anim_frames(owner, "idle", "se", actor.art_variant)
		var portrait: Texture2D = actor.ui_portrait_texture()
		var stats: Array = [actor.max_hp, actor.atk, actor.atk_cd, actor.base_speed, actor.setup_def.abilities]
		check(not actor._campaign_tribute_push_active() and not Wheel.enabled(actor), "unloaded own merchant body " + owner)
		b.level.st = b.level.CARRY; b.level.drug_done = true
		b.level._begin_cargo_choice(b); b.level._sync_controls(b); b.mission.tick(0)
		_arrive(b, actor, "force_take_")
		check(actor.has_meta("pushing_empty_tribute") and not Wheel.enabled(actor), "empty cart remains original route " + owner)
		_arrive(b, actor, "force_load_")
		var cargo_index: int = actor.get_meta("carrying_tribute", -1)
		check(cargo_index == {"gongsun_sheng":2, "ruan_xiaoer":4, "ruan_xiaowu":5}[owner], "original load callback assigns cart " + owner)
		for other in b.units:
			if other != actor: check(not Wheel.enabled(other), "unloaded other actor remains disabled " + other.key)
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/direction4/level1_" + owner + "_layered_20261030.json"))
		for source in manifest.sources.values():
			var texture: Texture2D = load("res://" + String(source.path))
			check(texture != null and texture.get_width() == int(source.native_size[0]) and texture.get_height() == int(source.native_size[1]), "native imported dimensions " + source.path)
		await _wheel_matrix(b, actor)
		await _gait_views(b, actor)
		_arrive(b, actor, "force_deliver_")
		check(b.level.delivered > 0 and not Wheel.enabled(actor), "original delivery counts loads and restores renderer " + owner)
		actor.animation_direction = "se"; actor._move_blend = 0; actor._anim_t = 0; actor._flinch = Vector2.ZERO; actor._lunge = 0
		check(actor._anim_frame_for_state(null) == original_idle[0], "original own idle restored " + owner)
		check(actor.ui_portrait_texture() == portrait and [actor.max_hp, actor.atk, actor.atk_cd, actor.base_speed, actor.setup_def.abilities] == stats, "portrait and gameplay values preserved " + owner)
		b.map.sync_render_position(actor)
		b.camera.position = b.to_screen(actor.position) + Vector2(0, -22); b.camera.force_update_scroll()
		actor.queue_redraw(); await _snapshot("after_delivery")
		var checkpoint := FileAccess.open(out.path_join("checkpoint_" + owner + ".json"), FileAccess.WRITE)
		checkpoint.store_string(JSON.stringify({"owner": owner, "checks": checks, "failures": failures,
			"trusted_identity": trusted, "screenshots": screenshots, "visual_samples": visual_samples,
			"full_run_passed": false, "checkpoint_before_scene_cleanup": true}, "\t"))
		checkpoint.close()
		print("CARRIER_SCENE_CLEANUP_BEGIN ", owner)
		await _dispose(b)
		print("CARRIER_SCENE_CLEANUP_END ", owner)
	report({"scope": "three remaining own-body layered carriers; seven-owner route isolation; original transport callbacks",
		"screenshots": screenshots, "visual_samples": visual_samples,
		"wine_prerequisite_and_sampling_positions_are_fixtures": true,
		"full_playthrough": false, "steam_updated": false})
