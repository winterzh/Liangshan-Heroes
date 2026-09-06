extends "res://tools/campaign_mode_performance_test.gd"

const REFERENCE := "res://tools/contracts/reeds/before_4e4665c.txt"
const REFERENCE_SHA := "a55136de426c7ff64192dc00972ad1ab8bfea6747cae863dd00827edc4c7e891"
const FIELDS := ["_reed_stems","_reed_leaves","_reed_heads","_reed_stem_anchors","_reed_leaf_anchors","_reed_head_anchors","_reed_cells"]
const COUNTER := "\nvar probe_queries := 0\nfunc _fog_anchor_revealed(p: Vector2, rise_px: float) -> bool:\n\tprobe_queries+=1\n\treturn super._fog_anchor_revealed(p,rise_px)\n"
var vertex_comparisons := 0

func _copy_inputs(source, target) -> void:
	target._map=source._map;target._battle=source._battle
	for field in FIELDS: target.set(field,source.get(field))

func _inputs(target) -> Array:
	return FIELDS.map(func(field): return target.get(field))

func _mesh_arrays(target) -> Array:
	if target._reed_mesh==null: return []
	return target._reed_mesh.surface_get_arrays(0)

func _compare(target, old, label: String) -> void:
	_copy_inputs(target,old)
	var inputs_before:=var_to_bytes(_inputs(target))
	var vision_before: PackedByteArray=target._battle._vision.duplicate()
	old._build_reed_mesh()
	var expected:=_mesh_arrays(old)
	target._build_reed_mesh()
	var actual:=_mesh_arrays(target)
	check(actual==expected and target._reed_visibility_signature==old._reed_visibility_signature,label+" exact mesh arrays and fog signature")
	check(var_to_bytes(_inputs(target))==inputs_before and target._battle._vision==vision_before,label+" preserves geometry inputs and live fog bytes")
	if not actual.is_empty():
		vertex_comparisons+=actual[Mesh.ARRAY_VERTEX].size()
		check(target._reed_mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_LINES,label+" retains line primitive")

func _timed(target) -> int:
	var started:=Time.get_ticks_usec()
	for i in range(12): target._build_reed_mesh()
	return Time.get_ticks_usec()-started

func _benchmark(target, old, label: String) -> void:
	_compare(target,old,label)
	_timed(target);_timed(old)
	var windows:=[];var before:=[];var after:=[]
	for old_first in [true,false,true]:
		for is_old in ([true,false] if old_first else [false,true]):
			var elapsed:=_timed(old if is_old else target)
			(before if is_old else after).append(elapsed)
			windows.append({"implementation":"reference" if is_old else "optimized","calls":12,"microseconds":elapsed})
	before.sort();after.sort()
	report.samples.append({"label":label,"vertices":target._reed_stems.size()+target._reed_leaves.size()+target._reed_heads.size(),"reed_cells":target._reed_cells.size(),"windows":windows,"median_reference_us":before[1],"median_optimized_us":after[1],"optimized_over_reference":float(after[1])/maxi(1,before[1])})

func _query_counts(source, reference_source: String, label: String) -> void:
	var old_script:=GDScript.new();old_script.source_code=reference_source+COUNTER
	var new_script:=GDScript.new();new_script.source_code="extends \"res://scripts/liangshan_scenery.gd\"\n"+COUNTER
	check(old_script.reload()==OK and new_script.reload()==OK,label+" query-count instruments compile")
	var old=old_script.new();var target=new_script.new()
	_copy_inputs(source,old);_copy_inputs(source,target)
	old._build_reed_mesh();target._build_reed_mesh()
	var anchors:={}
	for field in ["_reed_stem_anchors","_reed_leaf_anchors","_reed_head_anchors"]:
		for anchor in source.get(field): anchors[anchor]=true
	var vertices: int=source._reed_stems.size()+source._reed_leaves.size()+source._reed_heads.size()
	check(old.probe_queries==vertices+source._reed_cells.size() and target.probe_queries==anchors.size()+source._reed_cells.size(),label+" visibility queries are one per unique anchor plus unchanged signature")
	check(_mesh_arrays(target)==_mesh_arrays(old),label+" counting does not alter mesh result")
	report.get_or_add("query_counts",[]).append({"label":label,"vertices":vertices,"unique_anchors":anchors.size(),"signature_queries":source._reed_cells.size(),"reference":old.probe_queries,"optimized":target.probe_queries})
	old.free();target.free()

func _synthetic(target, old, reference_source: String) -> void:
	var b=target._battle
	b.fog=true;b._vision.resize(target._map.w*target._map.h);b._vision.fill(0)
	b._vision[0]=2
	var a:=Vector2(-5,-2);var z:=Vector2(32.25,64.5)
	target._reed_stems=PackedVector2Array([Vector2(-4,2),Vector2(-4,-8),Vector2(4,2),Vector2(4,-10)])
	target._reed_leaves=PackedVector2Array([Vector2(-4,-3),Vector2(-7,-5),Vector2(4,-3),Vector2(7,-5)])
	target._reed_heads=PackedVector2Array([Vector2(4,-10),Vector2(5,-13)])
	target._reed_stem_anchors=PackedVector2Array([a,a,z,z])
	target._reed_leaf_anchors=PackedVector2Array([a,a,z,z])
	target._reed_head_anchors=PackedVector2Array([z,z])
	target._reed_cells=PackedVector2Array([a,z])
	_compare(target,old,"mixed clumps across all three line groups")
	_query_counts(target,reference_source,"synthetic shared anchors")
	var colors: PackedColorArray=target._reed_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(colors[0].a>0.0 and colors[2].a==0.0 and colors[4].a>0.0 and colors[8].a==0.0,"one explored and one hidden clump retain per-group colors")
	b._vision.fill(2)
	_compare(target,old,"reveal on the next rebuild")
	check(target._reed_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][8].a>0.0,"previously hidden head becomes visible")
	b._vision.fill(0)
	_compare(target,old,"hide again on the next rebuild")
	check(target._reed_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][0].a==0.0,"previously revealed stem becomes hidden")
	target._reed_cells=PackedVector2Array([z,z])
	_compare(target,old,"vertex anchors absent from cell list and duplicate signature entries")
	var previous_mesh=target._reed_mesh;var previous_signature: int=target._reed_visibility_signature
	for field in FIELDS: target.set(field,PackedVector2Array())
	_compare(target,old,"empty geometry preserves the previous mesh")
	check(target._reed_mesh==previous_mesh and target._reed_visibility_signature==previous_signature,"empty rebuild retains mesh identity and signature")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/reed_mesh_qa")
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before:=_save_hash()
	check(FileAccess.get_sha256(REFERENCE)==REFERENCE_SHA,"frozen old mesh builder hash matches")
	var reference_source:=FileAccess.get_file_as_string(REFERENCE)
	var old_script:=GDScript.new();old_script.source_code=reference_source
	check(old_script.reload()==OK,"frozen old mesh builder compiles")
	if not failures.is_empty(): quit(2);return
	var old=old_script.new()
	for id in ["level1","level2","level3","level4","level5","level6","level7","level8"]:
		var b=await _start(id);b.process_mode=Node.PROCESS_MODE_DISABLED
		var authored_fog: bool=b.fog
		var authored_vision: PackedByteArray=b._vision.duplicate()
		var source=b.map.sample_scenery
		var target=load("res://scripts/liangshan_scenery.gd").new()
		_copy_inputs(source,target)
		# Start both with a null mesh; empty authored levels keep the same old state.
		old._reed_mesh=null;old._reed_visibility_signature=-1
		_compare(target,old,id+" authored fog")
		for mode in ["disabled","uninitialized","hidden","explored","lit","checker","changed"]:
			b.fog=mode!="disabled"
			b._vision.resize(b.map.w*b.map.h);b._vision.fill(0)
			match mode:
				"uninitialized": b._vision.resize(1)
				"explored": b._vision.fill(1)
				"lit": b._vision.fill(2)
				"checker","changed":
					for i in range(b._vision.size()): b._vision[i]=((i+(1 if mode=="changed" else 0))%3)
			_compare(target,old,id+" "+mode)
		if id=="level5":
			_query_counts(target,reference_source,"level5 authored reeds")
			_benchmark(target,old,"level5_mixed_fog")
			b._vision.fill(2);_benchmark(target,old,"level5_all_explored")
			b.fog=false;_benchmark(target,old,"level5_fog_disabled")
			_synthetic(target,old,reference_source)
		# Pending HUD draw notifications can run while queue_free is flushed.
		# Restore the authored mode before yielding: fog-free chapters have no
		# corresponding live-visibility buffer for our temporary fog fixtures.
		b.fog=authored_fog;b._vision=authored_vision
		target.free()
		await _dispose(b,true)
	old.free()
	check(_save_hash()==saved_before,"player campaign save bytes unchanged")
	check(report.samples.size()==3,"all three uninstrumented paired workloads completed")
	report["reference"]={"path":REFERENCE,"sha256":REFERENCE_SHA}
	report["vertex_comparisons"]=vertex_comparisons
	report["failures"]=failures;report["passed"]=failures.is_empty()
	report["scope"]="Frozen old mesh builder against current production; full mesh surface arrays/signature/geometry/fog state, eight maps and live-state transitions. Count wrappers are separate from timings. Timings include complete mesh allocation, upload submission and signature generation, but no asynchronous GPU completion or gameplay simulation."
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[reed-mesh-qa] ",JSON.stringify({"passed":report.passed,"checks":report.mode_checks.size(),"vertex_comparisons":vertex_comparisons,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
