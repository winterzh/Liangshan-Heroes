extends "res://tools/campaign_mode_performance_test.gd"
## Actual renderer + real physics catch-up. Synthetic visual states are labelled;
## live orders/death and campaign regressions run separately.
const DIRECT := "res://tools/contracts/unit_redraw/direct_queue_57e2512.txt"
const COUNTED := """extends "res://scripts/unit.gd"
var qa_draws := 0
var qa_last := {}
func qa_snapshot() -> Dictionary:
	return {"idle":_idle_t,"anim":_anim_t,"hp":hp,"direction":animation_direction,"selected":selected,"lunge":_lunge,"death":_death_t,"variant":art_variant,"flash":_flash}
func _draw() -> void:
	qa_draws += 1
	qa_last = qa_snapshot()
	super._draw()
"""
var pair := []
var views := []
var ticking := false
var tick_id := 0
var visual_case := ""
var samples := []
var counted_scripts := []

func _physics_fixture() -> void:
	if not ticking: return
	tick_id += 1
	for u in pair:
		u._idle_t = tick_id * 0.017
		u._anim_t = tick_id * 0.19
		u.animation_direction = ["se","sw","ne","nw"][int(tick_id/8)%4]
		u.hp = u.max_hp * (0.35 + 0.3 * float(tick_id%13)/13.0)
		u.set_selected(tick_id%2==0)
		u._move_blend = 1.0 if visual_case=="walk" else 0.0
		u._lunge = 0.3 + 0.06*(tick_id%8) if visual_case=="attack" else 0.0
		u._dying = visual_case=="death"
		u._death_t = u.DEATH_DUR * (0.2+float(tick_id%10)*0.055) if u._dying else 0.0
		u._flash = 0.1 if tick_id%3==0 else 0.0
		u._burn_t = tick_id * 0.017
		u._harvest_pulse = float(tick_id%10)*0.1
		# Multiple production invalidation entry points in each real physics tick.
		u._queue_motion_redraw()
		u._queue_animated_redraw(0.0,true)
		u.heal(0.5)

func _make_pair(b, key: String, variant := "") -> void:
	for script in counted_scripts:
		var viewport := SubViewport.new()
		viewport.size=Vector2i(320,320)
		viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var u=script.new()
		u.setup(key,b._defs[key],0,b,b.map)
		u.art_variant=variant
		u.position=Vector2(160,245)
		u.display_name=""
		viewport.add_child(u)
		u.set_physics_process(false)
		u.set_process(false)
		u.show()
		pair.append(u);views.append(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

func _remove_pair() -> void:
	ticking=false
	for view in views: view.queue_free()
	pair.clear();views.clear()
	await process_frame
	await process_frame

func _compare_case(b, key: String, mode: String, variant := "") -> void:
	visual_case=mode
	await _make_pair(b,key,variant)
	ticking=true
	await RenderingServer.frame_post_draw
	var old_draws: int=pair[0].qa_draws
	var new_draws: int=pair[1].qa_draws
	var start_tick:=tick_id
	var equal_pixels:=true
	var current_state:=true
	var one_per_frame:=true
	var old_multiple:=0
	var frame_rows:=[]
	for i in range(8):
		var old_count: int=pair[0].qa_draws
		var new_count: int=pair[1].qa_draws
		var previous_tick:=tick_id
		await RenderingServer.frame_post_draw
		var a: Image=views[0].get_texture().get_image()
		var z: Image=views[1].get_texture().get_image()
		equal_pixels=equal_pixels and a.get_data()==z.get_data()
		current_state=current_state and pair[1].qa_last==pair[1].qa_snapshot() and pair[0].qa_last==pair[1].qa_last
		one_per_frame=one_per_frame and pair[1].qa_draws-new_count==1
		if pair[0].qa_draws-old_count>1: old_multiple+=1
		frame_rows.append({"physics_ticks":tick_id-previous_tick,"direct_draws":pair[0].qa_draws-old_count,"combined_draws":pair[1].qa_draws-new_count})
		if i==7:
			a.save_png(output.path_join(key+"_"+mode+"_direct.png"))
			z.save_png(output.path_join(key+"_"+mode+"_combined.png"))
	var label:=key+" "+mode+" "+variant
	check(equal_pixels,label+" identical RGBA pixels after every rendered frame")
	check(current_state,label+" final physics state reaches this rendered frame")
	check(one_per_frame,label+" one combined Unit draw per rendered frame")
	check(old_multiple>0 and tick_id-start_tick>8,label+" direct baseline reproduces multiple physics draws")
	samples.append({"key":key,"case":mode,"variant":variant,"frames":8,"physics_ticks":tick_id-start_tick,"direct_draws":pair[0].qa_draws-old_draws,"combined_draws":pair[1].qa_draws-new_draws,"frame_rows":frame_rows})
	await _remove_pair()

func _lifecycle(b) -> void:
	await _make_pair(b,"song_jiang")
	var u=pair[1]
	# Input outside physics keeps normal CanvasItem invalidation, even when paused.
	paused=true
	u.set_selected(not u.selected)
	await RenderingServer.frame_post_draw
	check(u.qa_last.selected==u.selected,"paused non-physics selection redraws")
	paused=false
	await physics_frame
	u._lunge=0.71;u._request_redraw()
	paused=true
	await RenderingServer.frame_post_draw
	check(u.qa_last.lunge==0.71,"queued physics state still draws when immediately paused")
	paused=false
	u.hide()
	await physics_frame
	u._lunge=0.26;u._request_redraw()
	await RenderingServer.frame_post_draw
	u.show()
	await RenderingServer.frame_post_draw
	check(u.qa_last.lunge==0.26,"hidden then revealed unit has current state")
	await physics_frame
	u._lunge=0.44;u._request_redraw()
	views[1].remove_child(u)
	await RenderingServer.frame_post_draw
	views[1].add_child(u);u.set_physics_process(false)
	await RenderingServer.frame_post_draw
	check(u.qa_last.lunge==0.44,"detached and reattached unit redraws current state")
	await physics_frame
	u._request_redraw()
	var freed: WeakRef=weakref(u)
	u.queue_free()
	await RenderingServer.frame_post_draw
	check(freed.get_ref()==null,"unit freed with queued redraw has no retained signal target")
	await _remove_pair()
	var orphan=counted_scripts[1].new()
	orphan._request_redraw()
	orphan.free()
	check(true,"out-of-tree invalidation and immediate free complete")

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2);return
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--fixed-fps"): quit(2);return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/unit_redraw_qa")
	DirAccess.make_dir_recursive_absolute(output)
	var save_before:=_save_hash()
	root.size=Vector2i(960,640);DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.time_scale=1.0;Engine.max_fps=15;Engine.physics_ticks_per_second=60
	for direct in [true,false]:
		var script:=GDScript.new()
		script.source_code=COUNTED+(FileAccess.get_file_as_string(DIRECT) if direct else "")
		check(script.reload()==OK,"counted Unit compiles direct="+str(direct))
		counted_scripts.append(script)
	if not failures.is_empty(): quit(2);return
	var b=await _start("level5")
	b.process_mode=Node.PROCESS_MODE_DISABLED
	b._lite_fx=false
	physics_frame.connect(_physics_fixture)
	for spec in [["song_jiang","walk",""],["song_jiang","attack",""],["song_jiang","death",""],["song_jiang","idle","song_jiang_bound"],["guan_dao","walk",""],["hua_rong","attack",""],["arrow_tower","burn",""],["tree","harvest",""]]:
		if not b._defs.has(spec[0]):
			check(false,"fixture definition exists: "+spec[0]);continue
		await _compare_case(b,spec[0],spec[1],spec[2])
	await _lifecycle(b)
	physics_frame.disconnect(_physics_fixture)
	await _dispose(b,true)
	check(_save_hash()==save_before,"player save bytes unchanged")
	report["samples"]=samples
	report["scope"]="Controlled visual states, actual 60Hz physics catch-up and renderer at max_fps 15; pixel equivalence and invalidation cadence, not normal gameplay FPS. Baseline overrides only the scheduling helper with the previous direct queue behavior."
	report["renderer"]=RenderingServer.get_current_rendering_method()
	report["failures"]=failures;report["passed"]=failures.is_empty()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[unit-redraw-qa] ",report.mode_checks.size()," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
