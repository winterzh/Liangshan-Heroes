extends "res://tools/redraw_reject_validation_base.gd"
## Full frozen/production helpers, real Canvas and real Battle projection.
var pair := []
var views := []
var holders := []
var rr_scripts := []
var rr_battle
var ticking := false
var rr_tick := 0
var rr_spec := {}
var rr_samples := []
var rr_phases := {}

func rr_make_pair(b, key: String) -> void:
	var old = rr_scripts[0].new()
	var candidate = null
	var discarded := []
	# Keep all rejected objects alive until a match is found: never forge/override IDs.
	for i in range(128):
		var trial = rr_scripts[1].new()
		if trial.get_instance_id() % 6 == old.get_instance_id() % 6:
			candidate = trial
			break
		discarded.append(trial)
	for trial in discarded: trial.free()
	check(candidate != null, "real object allocation finds matching modulo-6 identity")
	if candidate == null:
		old.free()
		return
	pair = [old, candidate]
	for u in pair:
		var view := SubViewport.new()
		view.size = Vector2i(320, 320)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var world := Node2D.new()
		world.transform = b.map.ISO
		view.add_child(world)
		view.canvas_transform = Transform2D(0.0, Vector2(160,245) - b.to_screen(rr_anchor))
		u.setup(key, b._defs[key], 0, b, b.map)
		u.position = rr_anchor
		u.display_name = ""
		world.add_child(u)
		u.set_physics_process(false)
		u.set_process(false)
		u._idle_t = 0.0
		u._anim_t = 0.0
		u._animated_redraw_t = 0.08
		u._burn_t = 0.0
		b.map.sync_render_position(u)
		u.queue_redraw() # Initial blank-canvas paint only, never in measured fixture ticks.
		views.append(view)
		holders.append(world)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	check(pair[0].get_instance_id() % 6 == pair[1].get_instance_id() % 6, "pair matches both stride-2 and stride-3 identity phases")

func rr_remove_pair() -> void:
	ticking = false
	for view in views: view.queue_free()
	pair.clear()
	views.clear()
	holders.clear()
	await process_frame
	await process_frame

func rr_physics() -> void:
	if not ticking or pair.size() != 2: return
	rr_tick += 1
	rr_phases[int(Engine.get_physics_frames()) % 6] = true
	var location: String = rr_spec.location
	if location == "reenter": location = "offscreen" if rr_tick < 12 else "center"
	rr_view(rr_battle, location, rr_spec.mob, rr_spec.lite)
	for u in pair:
		# Labelled visual state fixture, not normal gameplay: no heal/set_selected
		# invalidations that could mask a missed helper request.
		u._idle_t = rr_tick * 0.017
		u._anim_t = rr_tick * 0.19
		u.animation_direction = ["se","sw","ne","nw"][int(rr_tick / 8) % 4]
		u.selected = rr_spec.selected
		u._move_blend = 1.0 if rr_spec.mode == "walk" else 0.0
		u._lunge = 0.35 + 0.04 * (rr_tick % 6) if rr_spec.mode == "attack" else 0.0
		u._flash = 0.1 if rr_spec.force and rr_tick % 6 < 3 else 0.0
		u._dying = rr_spec.mode == "death"
		u._death_t = u.DEATH_DUR * (0.2 + float(rr_tick % 10) * 0.055) if u._dying else 0.0
		u.hp = u.max_hp * (0.3 if rr_spec.mode == "burn" else 1.0)
		u._burn_t = rr_tick * 0.017
		u._animated_redraw_t = maxf(0.0, u._animated_redraw_t - 1.0 / 60.0)
		if rr_spec.method == "motion": u._queue_motion_redraw()
		else: u._queue_animated_redraw(0.08, rr_spec.force)

func rr_case(b, spec: Dictionary, fps: int) -> void:
	Engine.max_fps = fps
	rr_spec = spec
	rr_tick = 0
	rr_view(b, "center", spec.mob, spec.lite)
	await rr_make_pair(b, spec.key)
	if pair.size() != 2: return
	var initial_location: String = "offscreen" if spec.location == "reenter" else spec.location
	var visible: bool = rr_view(b, initial_location, spec.mob, spec.lite)
	check(visible == (not spec.lite or initial_location in ["center", "inside_edge"]), "fixture uses actual logical viewport visibility: " + str(spec))
	var rows := []
	var pixels_equal := true
	var states_equal := true
	var cadence_equal := true
	var draws_total := 0
	var nonblank := false
	ticking = true
	# 20 render frames at 60 FPS ensure reentry after physics tick 12 is observed.
	for frame in range(20):
		var prior := [pair[0].qa_draws, pair[1].qa_draws]
		var previous_tick: int = rr_tick
		await RenderingServer.frame_post_draw
		var a: Image = views[0].get_texture().get_image()
		var z: Image = views[1].get_texture().get_image()
		var old_draws: int = pair[0].qa_draws - prior[0]
		var new_draws: int = pair[1].qa_draws - prior[1]
		pixels_equal = pixels_equal and a.get_data() == z.get_data()
		nonblank = nonblank or a.get_used_rect().size != Vector2i.ZERO
		states_equal = states_equal and pair[0].qa_last == pair[1].qa_last and pair[0]._animated_redraw_t == pair[1]._animated_redraw_t
		cadence_equal = cadence_equal and old_draws == new_draws and new_draws <= 1
		draws_total += new_draws
		rows.append({"physics_ticks":rr_tick-previous_tick,"old_draws":old_draws,"new_draws":new_draws,"timer":pair[1]._animated_redraw_t,"visible":b.unit_visual_active(rr_anchor)})
		if frame == 19 and spec.location in ["inside_edge", "reenter"]:
			var name: String = "%d_%d_%s_%s" % [rr_samples.size(), fps, spec.method, spec.location]
			check(a.save_png(output.path_join(name + "_old.png")) == OK and z.save_png(output.path_join(name + "_new.png")) == OK, "paired actual edge/reentry screenshots saved")
	ticking = false
	var label: String = str(spec) + " cap=" + str(fps)
	check(pixels_equal, label + " exact rendered RGBA equality")
	check(states_equal, label + " same last painted state and animation timer")
	check(cadence_equal, label + " same actual Canvas draw cadence")
	if spec.location in ["center", "inside_edge", "reenter"] or not spec.lite:
		check(draws_total > 0, label + " exercises visible Canvas submissions")
		check(nonblank, label + " renders actual nontransparent art")
	if spec.location == "outside_edge" and spec.lite:
		check(draws_total == 0, label + " offscreen helpers make no Canvas submission")
	if spec.location == "reenter":
		check(rr_tick >= 18 and rows.any(func(row): return row.visible and row.new_draws > 0), "offscreen changed state is repainted after real visibility reentry")
	rr_samples.append({"spec":spec,"fps_cap":fps,"ids":[pair[0].get_instance_id(),pair[1].get_instance_id()],"anchor":str(rr_anchor),"height":b.map.height_at(rr_anchor),"projection":str(b.to_screen(rr_anchor)),"logical_viewport_size":str(b.get_viewport().get_visible_rect().size),"window_size":str(root.size),"initial_visible":visible,"rows":rows})
	await rr_remove_pair()

func rr_lifecycle(b) -> void:
	rr_view(b, "center", 501, true)
	await rr_make_pair(b, "song_jiang")
	if pair.size() != 2: return
	paused = true
	for u in pair:
		u._flash = 0.0
		u._lunge = 0.61
		u._queue_animated_redraw(0.08, true)
	await RenderingServer.frame_post_draw
	check(pair.all(func(u): return u.qa_last.lunge == 0.61 and u.qa_last.flash == 0.0), "paused force clears flash and paints new state outside physics")
	paused = false
	await physics_frame
	for u in pair:
		u._lunge = 0.71
		u._queue_animated_redraw(0.08, true)
	paused = true
	await RenderingServer.frame_post_draw
	check(pair.all(func(u): return u.qa_last.lunge == 0.71), "queued real physics force survives immediate pause")
	paused = false
	for u in pair: u.hide()
	await physics_frame
	for u in pair:
		u._lunge = 0.26
		u._queue_animated_redraw(0.08, true)
	await RenderingServer.frame_post_draw
	for u in pair: u.show()
	await RenderingServer.frame_post_draw
	check(pair.all(func(u): return u.qa_last.lunge == 0.26), "hidden/revealed Canvas paints the final forced state")
	await physics_frame
	for i in range(2):
		pair[i]._lunge = 0.44
		pair[i]._queue_animated_redraw(0.08, true)
		holders[i].remove_child(pair[i])
	await RenderingServer.frame_post_draw
	for i in range(2):
		holders[i].add_child(pair[i])
		pair[i].set_physics_process(false)
	await RenderingServer.frame_post_draw
	check(pair.all(func(u): return u.qa_last.lunge == 0.44), "detached/reattached actual Canvas retains requested state")
	await physics_frame
	var weak := []
	for u in pair:
		u._queue_animated_redraw(0.08, true)
		weak.append(weakref(u))
		u.queue_free()
	await RenderingServer.frame_post_draw
	check(weak.all(func(w): return w.get_ref() == null), "free with pending one-shot redraw leaves no live Unit target")
	await rr_remove_pair()
	for script in rr_scripts:
		var orphan = script.new()
		orphan._queue_animated_redraw(0.08, true)
		orphan.free()
	check(true, "actual out-of-tree helpers and immediate free complete")

func _run() -> void:
	var saved := rr_prefs()
	var b = await rr_setup()
	if b == null: quit(2); return
	rr_battle = b
	var base: String = rr_manifest_path.get_base_dir()
	for name in ["old_render_unit.gd", "new_render_unit.gd"]:
		var script = load(base.path_join(name))
		check(script != null, "actual render Unit class loads: " + name)
		rr_scripts.append(script)
	if not failures.is_empty(): await rr_finish(b, saved, {}); return
	physics_frame.connect(rr_physics)
	var specs := []
	for mob in [260, 261, 500, 501]:
		for selected in [false, true]:
			for location in ["center", "inside_edge", "outside_edge"]:
				specs.append({"key":"song_jiang","mode":"walk","method":"motion","mob":mob,"selected":selected,"location":location,"lite":true,"force":false})
	for force in [false, true]:
		for location in ["center", "inside_edge", "outside_edge", "reenter"]:
			specs.append({"key":"song_jiang","mode":"attack","method":"animated","mob":501,"selected":false,"location":location,"lite":true,"force":force})
	for extra in [["song_jiang","death",true],["arrow_tower","burn",true],["song_jiang","walk",false]]:
		specs.append({"key":extra[0],"mode":extra[1],"method":"animated","mob":501,"selected":false,"location":"center","lite":extra[2],"force":true})
	for fps in [15, 60]:
		for spec in specs: await rr_case(b, spec, fps)
	check(rr_phases.size() == 6, "real physics callbacks cover all stride modulo phases")
	Engine.max_fps = 15
	await rr_lifecycle(b)
	physics_frame.disconnect(rr_physics)
	await rr_finish(b, saved, {"samples":rr_samples,"scope":"Full pinned old/candidate redraw helpers. Matching real modulo-6 Unit IDs, real level5 heightfield and Battle viewport visibility, isolated paired Canvas pixel/cadence comparisons at 15/60 FPS caps. Offscreen request behavior is observed in paired viewports kept visible for diagnosis. Synthetic visual/load fixtures and lifecycle checks; not combat or FPS acceptance."})
