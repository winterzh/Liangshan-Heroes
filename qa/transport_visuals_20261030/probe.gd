extends "base.gd"
## Scoped source-project integration probe. Wine prerequisite and sampling
## positions are explicit fixtures; this does not qualify an ordinary playthrough.
const Wheel = preload("res://scripts/tribute_cart_wheel_visual.gd")
const Transport = preload("res://scripts/huangnigang_transport.gd")
var screenshots: Array = []
var visual_samples: Array = []
var out := ""

func _frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame

func _snapshot(name: String) -> Image:
	await _frames()
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out.path_join(name + ".png")
	check(image != null and not image.is_empty(), name + ": rendered viewport")
	check(image.save_png(path) == OK, name + ": saved original screenshot")
	screenshots.append({"path": name + ".png", "sha256": FileAccess.get_sha256(path)})
	return image

func _selector(b, id: String) -> Button:
	for node in b.mission._buttons.get_children():
		if node is Button and node.get_meta("campaign_presentation_v1", {}).get("button_id", "") == id:
			return node
	return null

func _navigation(b, actor, prefix: String) -> void:
	b.select_single(actor, false)
	var action_id: String = b.level._selected_transport_action(b)
	check(action_id.begins_with(prefix), actor.key + ": next step is " + prefix)
	if action_id.is_empty(): return
	var action: Dictionary = b.mission.actions[action_id]
	var before: Array = [actor.position, actor._order_serial, b.level.delivered,
		b.level.cargo.duplicate(), b.level.empty_cargo.duplicate(), action.done, b.mission.active_action_id]
	var button := _selector(b, "hg_transport_next")
	check(button != null, "actual task panel exposes next-step button")
	if button != null:
		await _frames()
		b.mission._detail_scroll.ensure_control_visible(button)
		await _frames()
		var rect := button.get_global_rect()
		var usable: bool = button.is_visible_in_tree() and root.get_visible_rect().encloses(rect) and b.mission._detail_scroll.get_global_rect().encloses(rect)
		check(usable, "next-step button is fully inside actual viewport and task scroll")
		if usable:
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.position = rect.get_center()
				event.global_position = event.position
				event.pressed = pressed
				root.push_input(event, true)
				await get_tree().process_frame
	check(b.mission._status.text.contains(root.get_node("Localize").text(action.label)), "next step names the actual action")
	check(b.camera.position.distance_to(b.to_screen(b.map.cell_to_world(action.cell))) < 1.0, "next step locates current marker")
	check(before == [actor.position, actor._order_serial, b.level.delivered,
		b.level.cargo.duplicate(), b.level.empty_cargo.duplicate(), action.done, b.mission.active_action_id],
		"navigation preserves movement, cargo, score and action lifecycle")

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
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/direction4/level1_" + actor.key + "_layered_20261018.json"))
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
		actor.art_variant = "hn_liu_tang"
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
	for i in range(75): await get_tree().physics_frame
	actor.set_physics_process(false); actor.order_stop()
	check(actor.position.distance_to(origin) > 1.0 and actor._tribute_wheel_angle != angle,
		actor.key + ": normal Unit movement drives independent wheel")
	var codec = load("res://scripts/run_unit_state.gd").new(null, null, null)
	var raw: Dictionary = codec._read_explicit(actor)
	var gait: float = actor._anim_t
	check(not raw.has("_tribute_wheel_angle"), "wheel stays outside persisted gameplay state")
	codec._assign_values(actor, raw)
	check(actor._tribute_wheel_angle == 0.0 and actor._anim_t == gait, "restore resets visual wheel and preserves saved gait")

func _run() -> void:
	out = OS.get_environment("HG_OUTPUT_ROOT")
	root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	if not identity(true): report(); return
	var b = await _start()
	b.set_process(false); b.set_physics_process(false); b.fog = false
	b.camera.set_process(false); b.camera.set_physics_process(false); b.camera.position_smoothing_enabled = false
	for actor in b.units: actor.set_physics_process(false)
	# Explicit post-wine fixture: this batch does not rerun the wine route.
	b.level._ensure_bai(b, false).set_physics_process(false)
	b.level.st = b.level.CARRY; b.level.drug_done = true
	b.level._begin_cargo_choice(b); b.level._sync_controls(b)
	b.mission.tick(0.0) # Normal presentation update, while simulation stays frozen.
	check(b.phase == b.Phase.FIGHT and b.level.actors.has(b.find_unit("bai_sheng")), "post-wine fixture includes the original Bai entry and fight phase")
	var next := _selector(b, "hg_transport_next")
	check(next != null, "new button passes actual mission whitelist")
	if next == null: report(); return
	b.mission._set_expanded(true)
	b.mission._detail_scroll.ensure_control_visible(next)
	var localize = root.get_node("Localize")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	for lang: String in ["zh_CN", "zh_TW", "en", "ja"]:
		localize.set_language(lang, false)
		b.hud.set_top(b.level.top_status(b))
		b.mission._detail_scroll.ensure_control_visible(next)
		await _frames()
		check(next.is_visible_in_tree(), lang + ": task guidance is visible")
		check(next.text == ("下一步 · 当前所选" if lang == "zh_CN" else catalog["下一步 · 当前所选"][lang]), lang + ": translated actual next-step button")
		await _navigation(b, b.find_unit("chao_gai"), "force_take_")
		await _frames()
		b.mission._detail_scroll.ensure_control_visible(b.mission._status)
		await _frames()
		await _snapshot("navigation_" + lang)
	localize.set_language("zh_CN", false)
	b.level.activate_mission_button(b, "hg_empty_hands")
	check(b.selection.size() == 7 and not b.selection.has(b.find_unit("bai_sheng")), "transport selector selects seven carriers and excludes Bai")
	check(b.level._selected_transport_action(b).is_empty(), "group selection needs an explicit single carrier")
	b.select_single(b.find_unit("bai_sheng"), false)
	check(b.level._selected_transport_action(b).is_empty(), "Bai cannot acquire a cart task")
	for owner: String in ["chao_gai", "wu_yong", "ruan_xiaoqi"]:
		var actor = b.find_unit(owner)
		check(not Wheel.enabled(actor), owner + ": unloaded body retains existing art")
		await _navigation(b, actor, "force_take_")
		_arrive(b, actor, "force_take_")
		check(actor.has_meta("pushing_empty_tribute") and not Wheel.enabled(actor), "empty date cart retains its original art")
		await _navigation(b, actor, "force_load_")
		_arrive(b, actor, "force_load_")
		check(actor.has_meta("carrying_tribute"), owner + ": original loading callback assigns cargo")
		await _navigation(b, actor, "force_deliver_")
		if OS.get_environment("HG_TRANSPORT_MODE") != "guidance": await _wheel_matrix(b, actor)
		_arrive(b, actor, "force_deliver_")
		check(not Wheel.enabled(actor) and not actor.has_meta("carrying_tribute"), owner + ": delivery removes loaded cart renderer")
		check(b.level._selected_transport_action(b).is_empty(), "delivered carrier gets no stale task")
	check(b.level.delivered == 5, "real callbacks count Chao/Wu/Ruan7 cart weights exactly once")
	for actor in b.units:
		check(not Wheel.enabled(actor), "remaining non-layered or unloaded actors keep existing route " + actor.key)
	b.level.st = b.level.WITHDRAW
	b.level.activate_mission_button(b, "hg_empty_hands")
	check(b.selection.has(b.find_unit("bai_sheng")), "withdrawal selector retains Bai for regrouping")
	await _dispose(b)
	report({"scope": "three adopted layered carts and selection-only transport guidance",
		"screenshots": screenshots, "visual_samples": visual_samples,
		"guidance_only": OS.get_environment("HG_TRANSPORT_MODE") == "guidance",
		"wine_prerequisite_and_sampling_positions_are_fixtures": true,
		"full_playthrough": false, "steam_updated": false})
