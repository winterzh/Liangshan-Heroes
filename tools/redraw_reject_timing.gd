extends "res://tools/redraw_reject_validation_base.gd"
## Complete-helper microtiming, never FPS. One actual Unit and physics tick.
const RR_LOOPS := 200
const RR_WARMUP := 6
const RR_WINDOW_TICKS := 12
const RR_WINDOWS := 3
var rr_unit
var rr_battle
var rr_active := false
var rr_ticks := 0
var rr_spec := {}
var rr_rows := []
var rr_samples := []

func rr_clear_pending() -> void:
	# Fixture reset OUTSIDE measured blocks. Give old/new the same initial signal
	# state so neither inherits the other's first-connect or frame-stamp advantage.
	if process_frame.is_connected(rr_unit.queue_redraw):
		process_frame.disconnect(rr_unit.queue_redraw)
	rr_unit._queued_redraw_frame = -1

func rr_measure(which: String) -> int:
	rr_clear_pending()
	var name: StringName = StringName("rr_" + which + "_" + rr_spec.method)
	var started: int = Time.get_ticks_usec()
	if rr_spec.method == "animated":
		for i in range(RR_LOOPS):
			rr_unit._animated_redraw_t = rr_spec.timer
			rr_unit.call(name, 0.08, rr_spec.force)
	else:
		for i in range(RR_LOOPS):
			rr_unit._animated_redraw_t = rr_spec.timer
			rr_unit.call(name)
	return Time.get_ticks_usec() - started

func rr_time_tick() -> void:
	if not rr_active: return
	rr_ticks += 1
	var frame: int = Engine.get_physics_frames()
	var ident: int = rr_unit.get_instance_id()
	var order: Array = ["old","new","empty"] if rr_ticks % 2 == 0 else ["new","old","empty"]
	var values := {}
	# Timer reset and dynamic dispatch occur equally in full helpers and empty
	# control. No dictionaries/probes execute INSIDE a timed helper or loop.
	for which in order: values[which] = rr_measure(which)
	if rr_ticks > RR_WARMUP:
		rr_rows.append({"old_us":values.old,"new_us":values.new,"empty_us":values.empty,
			"first":order[0],"physics_frame":frame,"id_modulo_6":ident%6,
			"same_tick_and_instance":frame==Engine.get_physics_frames() and ident==rr_unit.get_instance_id() and Engine.is_in_physics_frame()})
	# Keep actual Canvas scheduling/later draw alive after isolated batch resets.
	# This is outside the measurements; downstream Canvas work is not timed here.
	rr_clear_pending()
	rr_unit._idle_t = rr_ticks / 60.0
	rr_unit._request_redraw()
	if rr_ticks >= RR_WARMUP + RR_WINDOW_TICKS * RR_WINDOWS: rr_active = false

func rr_quantile(values: Array, q: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(ceili(sorted.size() * q) - 1, 0, sorted.size()-1)])

func rr_timing_case(b, spec: Dictionary) -> void:
	rr_spec = spec
	rr_ticks = 0
	rr_rows = []
	var visible: bool = rr_view(b, spec.location, spec.mob, spec.lite)
	rr_unit.selected = spec.selected
	check(visible == (not spec.lite or spec.location in ["center","inside_edge"]), "real projected view classification: " + str(spec))
	rr_active = true
	var deadline: int = Time.get_ticks_usec() + 30_000_000
	while rr_active and Time.get_ticks_usec() < deadline: await process_frame
	check(not rr_active and rr_rows.size() == RR_WINDOWS * RR_WINDOW_TICKS, "three complete paired timing windows: " + str(spec))
	rr_active = false
	if rr_rows.size() != RR_WINDOWS * RR_WINDOW_TICKS: return
	check(rr_rows.all(func(row): return row.same_tick_and_instance), "all full-helper blocks use the same real instance and physics callback")
	var windows := []
	for w in range(RR_WINDOWS):
		var rows: Array = rr_rows.slice(w*RR_WINDOW_TICKS, (w+1)*RR_WINDOW_TICKS)
		var item := {"rows":rows,"calls_per_block":RR_LOOPS}
		for kind in ["old","new","empty"]:
			var values: Array = rows.map(func(row): return row[kind+"_us"])
			item[kind+"_median_block_us"] = rr_quantile(values, 0.5)
			item[kind+"_p95_block_us"] = rr_quantile(values, 0.95)
		windows.append(item)
	rr_samples.append({"spec":spec,"unit_id":rr_unit.get_instance_id(),"height":b.map.height_at(rr_anchor),
		"visible":visible,"windows":windows,"control_policy":"Raw timings include equal timer assignment and call dispatch. Empty-call control is reported separately, never blindly subtracted. Downstream Canvas flush/draw is excluded."})
	await RenderingServer.frame_post_draw

func _run() -> void:
	var saved := rr_prefs()
	var b = await rr_setup()
	if b == null: quit(2); return
	rr_battle = b
	var script = load(rr_manifest_path.get_base_dir().path_join("timing_unit.gd"))
	check(script != null, "no-probe complete old/new timing Unit class loads")
	if script == null: await rr_finish(b, saved, {}); return
	rr_unit = script.new()
	rr_unit.setup("song_jiang", b._defs.song_jiang, 0, b, b.map)
	rr_unit.position = rr_anchor
	b.units_root.add_child(rr_unit)
	rr_unit.set_physics_process(false)
	rr_unit.set_process(false)
	b.map.sync_render_position(rr_unit)
	physics_frame.connect(rr_time_tick)
	var specs := []
	for mob in [260,261,500,501]:
		for selected in [false,true]:
			for location in ["center","inside_edge","outside_edge"]:
				specs.append({"method":"motion","mob":mob,"selected":selected,"location":location,"lite":true,"timer":0.04,"force":false})
	for timer in [0.0,0.04]:
		for force in [false,true]:
			for location in ["center","inside_edge","offscreen"]:
				specs.append({"method":"animated","mob":501,"selected":false,"location":location,"lite":true,"timer":timer,"force":force})
	for method in ["animated","motion"]:
		specs.append({"method":method,"mob":501,"selected":false,"location":"offscreen","lite":false,"timer":0.04,"force":false})
	for spec in specs:
		await rr_timing_case(b, spec)
		if not failures.is_empty(): break
	physics_frame.disconnect(rr_time_tick)
	rr_clear_pending()
	rr_unit.queue_free()
	await process_frame
	await rr_finish(b, saved, {"samples":rr_samples,"scope":"Complete pinned old/new helper methods, no dictionary probes or request override. One real Unit, real level5 Battle height projection and real _request_redraw, same physics callback, alternating order, six warmup ticks then three twelve-tick windows per fixture. Actual draw work after scheduling is excluded; synthetic load/timer states and microtiming do not establish FPS or normal combat gains."})
