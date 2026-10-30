extends "base.gd"
## Original chapter callbacks; wine, arrival positions and stopped simulation are fixtures.
const Captions = preload("res://scripts/campaign_cart_captions.gd")
const Ground = preload("res://scripts/campaign_tribute_cart_visual.gd")
const Transport = preload("res://scripts/huangnigang_transport.gd")
var out := ""
var screenshots: Array = []
var layouts: Array = []
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


func _center(b, zoom: float, offset := Vector2.ZERO) -> void:
	b.camera.zoom = Vector2.ONE * zoom
	b.camera.position = b.to_screen(b.level.bundles[0].position) + Vector2(0, -40) + offset
	b.camera.force_update_scroll()
	for u in b.units: b.map.sync_render_position(u); u.queue_redraw()

func _layout(overlay, label: String, minimum: int) -> Array:
	await _frames(4)
	RenderingServer.force_draw(false)
	var rows: Array = overlay.last_layout.duplicate(true)
	check(rows.size() >= minimum, label + ": actual rendered detail cards present")
	var area: Rect2 = overlay.get_viewport_rect().grow(-8)
	var b = overlay._battle.get_ref()
	var obstacles: Array = overlay._obstacles(b)
	var seen: Array = []
	for item: Dictionary in rows:
		var rect: Rect2 = item.rect
		check(area.encloses(rect) and rect.size == Captions.CARD_SIZE, label + ": fixed screen size and in viewport " + str(item.entity_id))
		check(overlay._free(rect, obstacles) and overlay._free(rect, seen), label + ": avoids real bodies hero labels HUD and other cards " + str(item.entity_id))
		seen.append(rect.grow(Captions.GAP))
		check(item.text != "" and item.health > 0 and item.health <= 1, label + ": original name and current health " + str(item.entity_id))
	layouts.append({"label": label, "viewport": [root.size.x, root.size.y], "cards": rows})
	return rows

func _ledger(b) -> Array:
	return [b.level.delivered, b.level.cargo.duplicate(), b.level.cargo_ready.duplicate(),
		b.level.st, b.level.victory, [b._run_clock._next_tick, b._run_clock._tick, b._run_clock._cache_frame, b._run_clock._fault], (b.level.bundles + b.level.actors).map(func(c): return [c.entity_id, c.position, c.hp, c._order_serial])]

func _run() -> void:
	out = OS.get_environment("HG_OUTPUT_ROOT")
	root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	if not identity(true): report(); return
	var b = await _start_once()
	var overlay = b.hud.get_node_or_null(Captions.NODE_NAME)
	check(is_instance_valid(overlay), "production on_start creates caption overlay")
	if not is_instance_valid(overlay): report(); return
	var overlay_id: int = overlay.get_instance_id()
	Captions.ensure(b); Captions.ensure(b)
	check(b.hud.get_node(Captions.NODE_NAME).get_instance_id() == overlay_id, "ensure is idempotent")
	check(b.level.actors.all(func(a): return not Captions.owns(a)), "all original hero labels remain under Unit drawing")
	check(b.level.bundles.all(func(c): return not Captions.owns(c)), "unclaimed cargo still uses its normal label path")
	for owner: String in Transport.OWNERS:
		var actor = b.find_unit(owner)
		var index: int = Transport.OWNERS.find(owner)
		_arrive(b, actor, "force_take_"); _arrive(b, actor, "force_load_")
		var cart = b.level.bundles[index]
		check(not Captions.owns(cart), "loaded original cart has no delivered caption ownership " + owner)
		var id: String = b.level._selected_transport_action(b)
		check(id.begins_with("force_deliver_"), "original delivery is still next " + owner)
		actor.order_stop(); actor.position = b.map.cell_to_world(b.mission.actions[id].cell)
		actor.animation_direction = ["se", "sw", "ne", "nw"][index % 4]
		actor.face_left = actor.animation_direction in ["sw", "nw"]
		actor._move_blend = 0; actor._anim_t = 0; actor._flinch = Vector2.ZERO; actor._lunge = 0
		check(b.mission.request_action(id), "original delivery accepted " + owner)
		b.mission.tick(1.0)
		check(Captions.owns(cart) and not Captions.wants_info(cart), "healthy delivered cart is quiet until requested " + owner)
	var cart = b.level.bundles[0]
	var original_variant: String = cart.art_variant
	cart.art_variant = "tribute_load"
	check(not Captions.owns(cart), "foreign legacy cart variant keeps its original label path")
	cart.art_variant = original_variant
	cart.set_meta("campaign_environment_route", "tribute_load")
	check(not Captions.owns(cart), "environment-routed props never lose their original labels")
	cart.remove_meta("campaign_environment_route")
	b._set_selection([])
	_center(b, 2.8)
	await _layout(overlay, "quiet", 0)
	check(overlay.last_layout.is_empty(), "all seven healthy parked carts draw no detail cards")
	await _snapshot("quiet_zh_CN")
	check(b.level.delivered == 11 and b.level.st == b.level.WITHDRAW and not b.level.victory, "all original seven carts eleven loads retain manual withdrawal")
	b.select_single(cart, false)
	check(cart.selected and b.hud._sel_ref == [cart] and b.hud._info_name.text.contains(Localize.text(cart.display_name)), "actual selection retains bottom information panel and cart identity")
	await _layout(overlay, "selected", 1)
	await _snapshot("selected_zh_CN")
	b._set_selection([])
	await _frames(4)
	check(overlay.last_layout.is_empty(), "healthy deselection removes screen card")
	b._set_inspect(cart)
	check(cart.inspected and b.hud._sel_ref == [cart], "actual read-only inspection retains information panel")
	await _layout(overlay, "inspected", 1)
	await _snapshot("inspected_zh_CN")
	b._set_inspect(null)
	cart.take_damage(1.0, null, false, true)
	check(cart.hp < cart.max_hp and Captions.wants_info(cart), "real damage requests an unselected cart card")
	await _layout(overlay, "damaged", 1)
	await _snapshot("damaged_zh_CN")
	cart.hp = cart.max_hp; cart.queue_redraw()
	await _frames(4)
	check(not Captions.wants_info(cart) and overlay.last_layout.is_empty(), "healing fixture restores quiet display")
	b.select_single(cart, false)
	Settings.show_healthbars = false
	await _layout(overlay, "healthbars_disabled", 1)
	var without_bar: Image = await _snapshot("no_healthbar_zh_CN")
	var bar_point: Vector2i = Vector2i(overlay.last_layout[0].rect.position + Vector2(20,26))
	var disabled_pixel: Color = without_bar.get_pixelv(bar_point)
	Settings.show_healthbars = true
	await _frames(4); RenderingServer.force_draw(false)
	var enabled_pixel: Color = root.get_texture().get_image().get_pixelv(bar_point)
	check(enabled_pixel.g > enabled_pixel.r + 0.1 and not disabled_pixel.g > disabled_pixel.r + 0.1, "actual viewport health strip follows existing healthbar setting")
	var before := _ledger(b)
	get_tree().paused = true
	var start_rows: Array = await _layout(overlay, "paused_start", 1)
	_center(b, 1.0, Vector2(60, -25))
	var moved_rows: Array = await _layout(overlay, "paused_pan_zoom", 1)
	check(start_rows[0].anchor != moved_rows[0].anchor and start_rows[0].rect.size == moved_rows[0].rect.size, "paused pan and zoom update anchor without scaling font/card")
	check(before == _ledger(b), "caption redraw and paused camera do not change ledger positions orders health or gameplay clock")
	await _snapshot("paused_pan_zoom_zh_CN")
	get_tree().paused = false
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	for size: Vector2i in [Vector2i(1280,720), Vector2i(1600,900)]:
		root.size = size; root.content_scale_size = size
		await _frames(5)
		for locale: String in ["zh_CN", "zh_TW", "en", "ja"]:
			Localize.set_language(locale, false)
			b.select_members(b.level.bundles, false)
			_center(b, 1.0)
			var label: String = "multi_" + locale + "_" + str(size.x)
			var rows: Array = await _layout(overlay, label, 7)
			check(rows == overlay.compute_layout(), label + ": deterministic original cargo order")
			check(rows.all(func(row): return row.text == Localize.text(b.level.bundles.filter(func(c): return c.entity_id == row.entity_id)[0].display_name)), label + ": actual localized cargo names")
			for row: Dictionary in rows:
				var source: String = b.level.bundles.filter(func(c): return c.entity_id == row.entity_id)[0].display_name
				check(row.text == (source if locale == "zh_CN" else catalog[source][locale]), label + ": text matches authored locale catalog " + str(row.entity_id))
			await _snapshot(label)
	Localize.set_language("zh_CN", false)
	b.select_single(cart, false); _center(b, 2.8)
	b.hud._pause_root.show()
	await _frames(4)
	check(overlay.last_layout.is_empty(), "full-screen pause menu is never covered by captions")
	b.hud._pause_root.hide()
	await _layout(overlay, "resume_menu_closed", 1)
	var blocked := [Rect2(Vector2.ZERO, Vector2(1280,720))]
	check(not overlay._place(Vector2(400,300), Rect2(8,8,1264,704), blocked).has_area(), "saturated viewport has no overlapping fallback")
	check(b.hud._sel_ref == [cart], "information panel remains available if no card slot")
	b._set_selection([])
	overlay.queue_free(); await _frames(2)
	Captions.ensure(b)
	check(is_instance_valid(b.hud.get_node(Captions.NODE_NAME)) and b.hud.get_node(Captions.NODE_NAME).get_instance_id() != overlay_id, "restore/process ensure can recreate ephemeral overlay without save fields")
	var weak_overlay: WeakRef = weakref(b.hud.get_node(Captions.NODE_NAME))
	await _dispose(b)
	check(not is_instance_valid(weak_overlay.get_ref()), "scene disposal frees overlay with no strong Unit/Battle references")
	report({"scope": "delivered-cart captions only", "screenshots": screenshots, "layouts": layouts,
		"same_scene_for_all_owners": true, "wine_arrival_heal_and_frozen_simulation_are_fixtures": true,
		"full_playthrough": false, "full_regression_run": false})
