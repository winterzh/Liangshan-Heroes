extends SceneTree
## Read-only production audit: invokes the real Unit renderer and lethal signal.
## Frozen snapshots expose frame transitions, without changing production scripts.
const OUT := "res://qa/skirmish_direction4_fix_20260905"
const VIEW := Vector2i(1920, 1080)
const DIRS := ["se", "sw", "ne", "nw"]
const TIMES := [0.0, 0.36, 0.71, 0.99, 1.30, 1.41]
var b
var overlay: CanvasLayer
var temporary: Array = []
var observations: Array = []
var retained_height

func _initialize() -> void:
	_run.call_deferred()

func label_at(text: String, p: Vector2, size: Vector2, fs := 22) -> void:
	var l := Label.new()
	l.text = text
	l.position = p
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	overlay.add_child(l)

func world_at(screen: Vector2) -> Vector2:
	return b.units_root.get_global_transform_with_canvas().affine_inverse() * screen

func new_unit(key: String, direction: String, screen: Vector2):
	var u = b.spawn_unit(key, 1, world_at(screen))
	# A frozen visual grid deliberately ignores spawn navigation relocation.
	u.position = world_at(screen)
	u.set_process(false)
	u.set_physics_process(false)
	u.animation_direction = direction
	u._direction_candidate = direction
	u._direction_votes = 4
	u.face_left = direction in ["sw", "nw"]
	u._flinch = Vector2.ZERO
	u._idle_t = 0.0
	u._swing_kind = u._weapon_kind()
	u.visible = true
	temporary.append(u)
	var marker := ColorRect.new()
	marker.color = Color(0.35, 0.85, 0.95, 0.8)
	marker.position = screen - Vector2(4, 2)
	marker.size = Vector2(8, 4)
	overlay.add_child(marker)
	return u

func clear_probe() -> void:
	for u in temporary:
		if is_instance_valid(u):
			b.units.erase(u)
			u.queue_free()
	temporary.clear()
	for m in b._death_remains.duplicate():
		if is_instance_valid(m): m.queue_free()
	b._death_remains.clear()
	for fx in b.fx_root.get_children():
		if not fx.is_queued_for_deletion(): fx.queue_free()
	for l in overlay.get_children(): l.queue_free()
	await process_frame

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	var err := im.save_png(OUT.path_join(name + ".png"))
	print("RECHECK_CAPTURE ", name, " error=", err)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	OS.set_environment("CAMPAIGN_QA", "1")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = VIEW
	root.content_scale_size = VIEW
	AudioServer.set_bus_mute(0, true)
	var s = root.get_node("Settings")
	s.edge_scroll = false
	s.auto_micro_level = 0
	s.game_speed = 1.0
	s.show_damage = false
	var c = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		c.set(mode, false)
	c.skirmish = true
	c.defense_waves = 1
	c.defense_random = false
	b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b._on_intro_done()
	b.phase = b.Phase.DEPLOY
	b.hud.hide()
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	# Flat isolated canvas for anchor comparison; terrain integration is audited separately.
	retained_height = b.map.height_field
	b.map.height_field = null
	for u in b.units:
		u.hide()
		u.set_process(false)
		u.set_physics_process(false)
	for child in b.world.get_children():
		if child is CanvasItem and child != b.units_root and child != b.fx_root:
			child.hide()
	b.camera.zoom = Vector2.ONE * 3.0
	b.camera.position = b.to_screen(b.map.cell_to_world(Vector2i(23, 35)))
	b.camera.force_update_scroll()
	var bg := CanvasLayer.new()
	bg.layer = -100
	root.add_child(bg)
	var rect := ColorRect.new()
	rect.color = Color("28343a")
	rect.size = Vector2(VIEW)
	bg.add_child(rect)
	overlay = CanvasLayer.new()
	overlay.layer = 50
	root.add_child(overlay)
	await process_frame
	for key in ["guan_dao", "guan_gong", "guan_jingqi", "guan_qi"]:
		label_at("REAL UNIT DEATH + BLOOD | " + key + " | independent victims; debris varies by seed", Vector2(0, 8), Vector2(1920, 38))
		for col in TIMES.size():
			label_at("%.2f s" % TIMES[col], Vector2(155 + col * 287, 65), Vector2(260, 35))
		for row in DIRS.size():
			label_at(DIRS[row].to_upper(), Vector2(5, 215 + row * 225), Vector2(130, 45))
			for col in TIMES.size():
				var u = new_unit(key, DIRS[row], Vector2(290 + col * 287, 280 + row * 225))
				u.take_damage(u.hp + 1.0)
				var mark = b._death_remains.back()
				mark.process_mode = Node.PROCESS_MODE_DISABLED
				var t: float = TIMES[col]
				u._phys_body(t)
				mark._process(t)
				mark.queue_redraw()
				u.queue_redraw()
				observations.append({"key": key, "direction": DIRS[row], "time": t,
					"dying": u._dying, "queued_free": u.is_queued_for_deletion(),
					"blood_revealed": mark.is_revealed(), "blood_position": str(mark.position),
					"unit_position": str(u.position)})
		await capture("death_" + key)
		await clear_probe()
	label_at("REAL UNIT | guan_gong | walk / attack continuity | cyan = ground point", Vector2(0, 8), Vector2(1920, 38))
	var states := ["idle", "walk phase 0", "walk phase PI", "attack start", "attack strike", "attack recover"]
	for col in DIRS.size(): label_at(DIRS[col].to_upper(), Vector2(390 + col * 410, 60), Vector2(200, 40))
	for row in states.size():
		label_at(states[row], Vector2(5, 125 + row * 155), Vector2(280, 40), 19)
		for col in DIRS.size():
			var u = new_unit("guan_gong", DIRS[col], Vector2(490 + col * 410, 218 + row * 155))
			u._move_blend = 1.0 if row in [1, 2] else 0.0
			u._anim_t = PI + 0.05 if row == 2 else 0.0
			u._lunge = [0.0, 0.0, 0.0, 1.0, 0.5, 0.05][row]
			u.queue_redraw()
	await capture("archer_actual_walk_attack")
	await clear_probe()
	label_at("REAL UNIT WEAPON ROUTE | cavalry spear art + runtime swing effect", Vector2(0, 8), Vector2(1920, 38))
	for col in DIRS.size(): label_at(DIRS[col].to_upper(), Vector2(390 + col * 410, 60), Vector2(200, 40))
	for row in 4:
		var key: String = "guan_qi" if row < 2 else "guan_jingqi"
		label_at(key + (" idle" if row % 2 == 0 else " attack"), Vector2(5, 170 + row * 220), Vector2(280, 40), 19)
		for col in DIRS.size():
			var u = new_unit(key, DIRS[col], Vector2(490 + col * 410, 290 + row * 220))
			u._lunge = 0.5 if row % 2 == 1 else 0.0
			u.queue_redraw()
			observations.append({"scope": "cavalry weapon route", "key": key,
				"direction": DIRS[col], "swing_kind": u._swing_kind,
				"sword_enum": u.WK.SWORD, "spear_enum": u.WK.SPEAR, "lunge": u._lunge})
	await capture("cavalry_actual_weapon_route")
	await clear_probe()
	b.map.height_field = retained_height
	b.map.show()
	var shadow_batch = b.world.get_node("WorldShadowBatch")
	shadow_batch.show()
	var highest := Vector2.ZERO
	var highest_height := -1.0
	for yy in b.map.h:
		for xx in b.map.w:
			var wp: Vector2 = b.map.cell_to_world(Vector2i(xx, yy))
			var hh: float = b.map.height_at(wp)
			if b.map.is_open_world(wp, "land") and hh > highest_height:
				highest = wp
				highest_height = hh
	b.camera.position = b.to_screen(highest)
	b.camera.zoom = Vector2.ONE * 3.0
	b.camera.force_update_scroll()
	await process_frame
	var slope_victim = b.spawn_unit("guan_dao", 1, highest)
	slope_victim.visible = true
	slope_victim.set_physics_process(false)
	slope_victim.set_process(false)
	slope_victim.animation_direction = "ne"
	await process_frame
	shadow_batch._update_visible_units()
	var alive_shadows: Dictionary = shadow_batch.summary()
	var ground_screen: Vector2 = b.get_canvas_transform() * b.to_screen(highest)
	var body_screen: Vector2 = slope_victim.get_global_transform_with_canvas().origin
	label_at("SAME VICTIM ON AUTHORED HIGH GROUND | terrain h=%.1f | body render h=%.1f | cyan=ground" % [highest_height, slope_victim.get_meta("render_height", 0.0)], Vector2(0, 6), Vector2(1920, 38))
	var ground_marker := ColorRect.new()
	ground_marker.color = Color.CYAN
	ground_marker.size = Vector2(36, 4)
	ground_marker.position = ground_screen-Vector2(18, 2)
	overlay.add_child(ground_marker)
	await capture("slope_same_victim_alive")
	slope_victim.take_damage(slope_victim.hp+1.0)
	var smark = b._death_remains.back()
	smark.process_mode = Node.PROCESS_MODE_DISABLED
	slope_victim._phys_body(0.71)
	smark._process(0.71)
	smark.queue_redraw()
	slope_victim.queue_redraw()
	shadow_batch._update_visible_units()
	observations.append({"scope": "same victim high ground", "height": highest_height,
		"logical_transform_delta_not_rendered_gap": body_screen.y-ground_screen.y,
		"body_render_height_meta": slope_victim.get_meta("render_height", 0.0),
		"mark_render_height_meta": smark.get_meta("render_height", 0.0), "flash_after_071": slope_victim._flash,
		"alive_shadows": alive_shadows, "dying_shadows": shadow_batch.summary(),
		"dying_node_still_in_tree": slope_victim.is_inside_tree(), "dying_node_in_battle_units": b.units.has(slope_victim)})
	await capture("slope_same_victim_death_071")
	var f := FileAccess.open(OUT.path_join("runtime_observations.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope": "Frozen real Unit renderer audit", "observations": observations}, "  "))
	f.close()
	current_scene = null
	b.queue_free()
	overlay.queue_free()
	bg.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0)
