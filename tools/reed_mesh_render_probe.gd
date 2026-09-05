extends "res://tools/campaign_mode_performance_test.gd"

const REFERENCE := "res://tools/contracts/reeds/before_4e4665c.txt"
const REFERENCE_SHA := "a55136de426c7ff64192dc00972ad1ab8bfea6747cae863dd00827edc4c7e891"
const FIELDS := ["_reed_stems","_reed_leaves","_reed_heads","_reed_stem_anchors","_reed_leaf_anchors","_reed_head_anchors","_reed_cells"]

func _frame(s, old, reference: bool) -> float:
	var started:=Time.get_ticks_usec()
	if reference:
		old._build_reed_mesh()
		s._reed_mesh=old._reed_mesh;s._reed_visibility_signature=old._reed_visibility_signature
		s.queue_redraw()
	else:
		s._build_reed_mesh()
	await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec()-started)/1000.0

func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2);return
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--fixed-fps"): quit(2);return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").game_speed=1.0
	Engine.time_scale=1.0;Engine.max_fps=0
	root.size=Vector2i(1440,900);DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	output=ProjectSettings.globalize_path("res://.godot/reed_mesh_render_probe")
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before:=_save_hash()
	check(FileAccess.get_sha256(REFERENCE)==REFERENCE_SHA,"frozen old mesh builder hash matches")
	var old_script:=GDScript.new();old_script.source_code=FileAccess.get_file_as_string(REFERENCE)
	check(old_script.reload()==OK,"render reference compiles")
	if not failures.is_empty(): quit(2);return
	var old=old_script.new()
	var b=await _start("level5");b.process_mode=Node.PROCESS_MODE_DISABLED
	var scene_ref=weakref(b)
	var s=b.map.sample_scenery
	old._map=b.map;old._battle=b
	for field in FIELDS: old.set(field,s.get(field))
	# Controlled upload/draw fixture: fully explored reeds, frozen units, fixed camera.
	# The fog overlay is explicitly hidden for the screenshot, not gameplay evidence.
	b.fog=true;b._vision.resize(b.map.w*b.map.h);b._vision.fill(2)
	if b._fog_layer!=null: b._fog_layer.hide()
	s._refresh_fog_visibility()
	_camera(b,Vector2i(28,43),0.8)
	for i in range(4):
		await _frame(s,old,true);await _frame(s,old,false)
	var source_positions: Array=b.units.map(func(u):return u.position)
	var source_vision: PackedByteArray=b._vision.duplicate()
	var expected: Array=old._reed_mesh.surface_get_arrays(0)
	var before:=[];var after:=[];var windows:=[]
	for old_first in [true,false,true]:
		for reference in ([true,false] if old_first else [false,true]):
			var times:=[]
			for i in range(12): times.append(await _frame(s,old,reference))
			(before if reference else after).append_array(times)
			windows.append({"implementation":"reference" if reference else "optimized","frame_ms":times})
			check(s._reed_mesh.surface_get_arrays(0)==expected,"rendered window retains identical complete surface arrays")
	var sorted_before:=before.duplicate();var sorted_after:=after.duplicate()
	sorted_before.sort();sorted_after.sort()
	var median_before: float=(sorted_before[17]+sorted_before[18])*0.5
	var median_after: float=(sorted_after[17]+sorted_after[18])*0.5
	check(before.size()==36 and after.size()==36,"both implementations complete 36 rendered rebuilds")
	check(b.units.map(func(u):return u.position)==source_positions and b._vision==source_vision,"paired render keeps unit positions and fog bytes frozen")
	await _frame(s,old,false)
	var captured: Image=root.get_texture().get_image()
	check(captured!=null and captured.get_size()==root.size and captured.save_png(output.path_join("scene.png"))==OK,"final production mesh screenshot saved")
	report["render"]={"godot":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1440,900],"windows":windows,"median_reference_ms":median_before,"median_optimized_ms":median_after,"p95_reference_ms":sorted_before[34],"p95_optimized_ms":sorted_after[34],"vertices":expected[Mesh.ARRAY_VERTEX].size(),"scope":"Each interval starts before synchronous rebuilding and ends at frame_post_draw. Frozen level5, all reeds explored, fog overlay hidden and camera fixed at cell 28,43/zoom0.8. Old mesh is assigned into the same live scenery node. Includes full frame work and submission; it is not a GPU fence, combat FPS or human playthrough."}
	old.free();await _dispose(b,true)
	check(scene_ref.get_ref()==null,"paired render scene released")
	check(_save_hash()==saved_before,"player campaign save bytes unchanged")
	report["failures"]=failures;report["passed"]=failures.is_empty()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[reed-render-probe] ",JSON.stringify({"passed":report.passed,"checks":report.mode_checks.size(),"median_reference_ms":median_before,"median_optimized_ms":median_after,"p95_reference_ms":sorted_before[34],"p95_optimized_ms":sorted_after[34],"failures":failures}))
	quit(0 if failures.is_empty() else 1)
