extends "res://tools/campaign_mode_performance_test.gd"
const REFERENCE := "res://tools/contracts/grid_build/before_877e713.txt"
const REFERENCE_SHA := "997bddb65ecfccc6c033ab292eeca006b501337297390af74c4f2a0e47c77d2d"
var old_script: GDScript
var unit_states_compared := 0
var query_results_compared := 0

func _copy_context(b, target) -> void:
	target.map=b.map;target.camera=b.camera;target.units=b.units
	target.ai_friendly=b.ai_friendly;target._lite_fx=b._lite_fx
	target._unit_draw_rect=b._unit_draw_rect
	target._impact_fx_frame=b._impact_fx_frame;target._damage_fx_frame=b._damage_fx_frame

func _grid_ids(grid: Dictionary) -> Array:
	var result:=[]
	for cell in grid:
		result.append([cell,grid[cell].map(func(u):return u.get_instance_id())])
	return result

func _state(b) -> Array:
	var visuals:=[]
	for u in b.units:
		if is_instance_valid(u):visuals.append([u.get_instance_id(),u.position,u.visible,u.z_index])
	return [_grid_ids(b._grid),_grid_ids(b._mob_grid),_grid_ids(b._body_grid_liang),_grid_ids(b._body_grid_guan),
		b._focus_counts.keys(),b._focus_counts.values(),b._mob_count,b._lite_fx,b._unit_draw_rect,
		b._impact_fx_frame,b._damage_fx_frame,visuals]

func _visuals(b) -> Array:
	var result:=[]
	for u in b.units:
		if is_instance_valid(u):result.append([u,u.position,u.visible,u.z_index])
	return result

func _restore(rows: Array) -> void:
	for row in rows:
		row[0].visible=row[2];row[0].z_index=row[3];row[0].position=row[1]

func _queries(b) -> Array:
	var result:=[]
	for u in b.units:
		if not is_instance_valid(u) or u.is_building or u.is_resource:continue
		for radius in [0.0,31.0,64.0,193.0]:
			result.append(b.units_near(u.position,radius).map(func(v):return v.get_instance_id()))
		for delta in [Vector2.ZERO,Vector2(3,-2),Vector2(65,0)]:
			result.append(b.can_unit_step(u,u.position+delta))
		if result.size()>=70:break
	return result

func _compare(b, old, label: String) -> void:
	_copy_context(b,old)
	var visuals:=_visuals(b)
	old._grid_build()
	var expected:=_state(old)
	var queries:=_queries(old)
	_restore(visuals)
	b._grid_build()
	check(_state(b)==expected,"exact ordered grids, focus, visibility, depth and counters: "+label)
	check(_queries(b)==queries,"neighbor order and enemy-body queries: "+label)
	unit_states_compared+=visuals.size();query_results_compared+=queries.size()

func _time(target) -> int:
	var started:=Time.get_ticks_usec()
	for i in range(200):target._grid_build()
	return Time.get_ticks_usec()-started

func _benchmark(b, old, label: String) -> void:
	_copy_context(b,old)
	_time(old);_time(b)
	var samples:=[];var before:=[];var after:=[]
	for old_first in [true,false,true]:
		for reference in ([true,false] if old_first else [false,true]):
			var elapsed:=_time(old if reference else b)
			(before if reference else after).append(elapsed)
			samples.append({"reference":reference,"microseconds":elapsed,"calls":200})
	before.sort();after.sort()
	report.samples.append({"label":label,"units":b.units.size(),"windows":samples,"median_before_us":before[1],"median_after_us":after[1],"after_over_before":float(after[1])/before[1]})

func _projection_counts(b) -> void:
	var counts:=[];var states:=[]
	for reference in [true,false]:
		var script:=GDScript.new()
		script.source_code='extends "res://scripts/battle.gd"\nvar projections := 0\nfunc _ready() -> void: pass\nfunc to_screen(p: Vector2) -> Vector2:\n\tprojections+=1\n\treturn super(p)\n'
		if reference:script.source_code+=FileAccess.get_file_as_string(REFERENCE)
		check(script.reload()==OK,"projection counter compiles reference="+str(reference))
		var probe=script.new();probe.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(probe)
		_copy_context(b,probe);probe._grid_build();probe.projections=0;probe._grid_build()
		counts.append(probe.projections);states.append(_state(probe));probe.free()
	check(states[0]==states[1] and counts[1]<counts[0],"same full rebuild output with fewer actual map projections")
	report["projection_counts"]={"before":counts[0],"after":counts[1],"units":b.units.size(),"scope":"Separate instrumented call after visibility stabilizes; no timing from counters."}

func _edge_cases(b, old) -> void:
	var ordinary: Array=b.units.duplicate()
	var rows:=_visuals(b)
	var fields:=[]
	for u in b.units:fields.append([u,u.hp,u.garrisoned,u.story_outcome,u.is_resource,u.is_building,u.faction,u.fog_visible,u._target])
	for i in range(b.units.size()):
		var u=b.units[i]
		u.position=Vector2(-65.0+float(i%15)*64.0,63.999+float(i/15)*64.0)
		u.z_index=4;u.visible=i%2==0
		u.faction=i%3;u.fog_visible=i%5!=0
		u._target=b.units[(i+1)%b.units.size()]
		match i%13:
			0:u.hp=0.0
			1:u.garrisoned=true
			2:u.story_outcome="retreated"
			3:u.story_outcome="embarked"
			4:u.story_outcome="subdued"
			5:u.is_resource=true
			6:u.is_building=true
			7:u.hp=NAN
	var stale=load("res://scripts/unit.gd").new()
	b.units.append(stale);b.units.append(null);stale.free()
	b.units.reverse();b.units.append(ordinary[10]);b.units.append(ordinary[10])
	for lite in [false,true]:
		b._lite_fx=lite;b._impact_fx_frame=11;b._damage_fx_frame=17
		_compare(b,old,"mixed states, negative/boundary cells, duplicate/null/freed entries lite="+str(lite))
	b.units.assign(ordinary)
	for f in fields:
		f[0].hp=f[1];f[0].garrisoned=f[2];f[0].story_outcome=f[3];f[0].is_resource=f[4]
		f[0].is_building=f[5];f[0].faction=f[6];f[0].fog_visible=f[7];f[0]._target=f[8]
	_restore(rows)
	# A visibility listener can move the unit synchronously, before depth/grid reads.
	var actor=ordinary[0]
	var callback:=func():actor.position+=Vector2(80,40)
	actor.visibility_changed.connect(callback)
	actor.fog_visible=false;actor.visible=true
	_compare(b,old,"visibility callback moves unit before final depth and bucket")
	actor.visibility_changed.disconnect(callback)
	for f in fields:f[0].fog_visible=f[7]
	_restore(rows)
	var camera=b.camera;b.camera=null;b._unit_draw_rect=Rect2(100,100,200,200);b._lite_fx=true
	_compare(b,old,"no camera retains previous clipping rectangle")
	b.camera=camera
	for full_auto in [false,true]:
		b.ai_friendly=full_auto;root.get_node("Settings").auto_micro_level=3 if full_auto else 2
		var threshold: int=b.LITE_FX_FULL_AUTO_THRESHOLD if full_auto else b.LITE_FX_MOB_THRESHOLD
		for count in [threshold-1,threshold,threshold+1]:
			b.units.assign(ordinary.filter(func(u):return not u.is_building and not u.is_resource).slice(0,count))
			b._lite_fx=false
			_compare(b,old,"first threshold tick count="+str(count)+" full="+str(full_auto))
			check(b._mob_count==count and b._lite_fx==(count>threshold),"strict population threshold retained")
			_compare(b,old,"next threshold tick count="+str(count)+" full="+str(full_auto))
	b.ai_friendly=false;root.get_node("Settings").auto_micro_level=2;b.units.assign(ordinary)

func _defense() -> void:
	var campaign=root.get_node("Campaign")
	campaign.current=7
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]:campaign.set(key,false)
	campaign.skirmish=true;root.get_node("Settings").auto_micro_level=0;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b
	await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();b.process_mode=Node.PROCESS_MODE_DISABLED
	var old=old_script.new();old.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(old)
	_compare(b,old,"real defense deployment");_benchmark(b,old,"defense deployment")
	b._perf_bench_setup(200);b._prof_on=false;await process_frame
	_compare(b,old,"real defense 200 enemy fixture");_benchmark(b,old,"defense 200 enemy fixture")
	for u in b.units:u.fog_visible=true
	_compare(b,old,"defense stress with all units revealed");_benchmark(b,old,"defense stress all visible")
	_projection_counts(b)
	old.free();await _dispose(b,true)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/grid_build_qa");DirAccess.make_dir_recursive_absolute(output)
	var saved:=_save_hash()
	check(FileAccess.get_sha256(REFERENCE)==REFERENCE_SHA,"frozen complete 877e713 grid rebuild hash matches")
	old_script=GDScript.new();old_script.source_code='extends "res://scripts/battle.gd"\nfunc _ready() -> void: pass\n'+FileAccess.get_file_as_string(REFERENCE)
	check(old_script.reload()==OK,"frozen full grid rebuild compiles")
	if not failures.is_empty():quit(2);return
	for id in ["level1","level2","level3","level4","level5","level6","level7","level8"]:
		var b=await _start(id);b.process_mode=Node.PROCESS_MODE_DISABLED
		var old=old_script.new();old.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(old)
		_compare(b,old,id+" original deployment");_benchmark(b,old,id+" original deployment")
		b._perf_bench_setup(200);b._prof_on=false;await process_frame
		for tick in range(4):
			for u in b.units:
				if not u.is_building and not u.is_resource:u.position+=Vector2(7.25,-3.5)
			b.camera.zoom=Vector2.ONE*(0.7+float(tick)*0.2)
			_compare(b,old,id+" moving stress tick "+str(tick))
		_benchmark(b,old,id+" 200 enemy fixture")
		if id=="level5":_projection_counts(b);_edge_cases(b,old)
		old.free();await _dispose(b,true)
	await _defense()
	check(_save_hash()==saved,"player campaign save bytes unchanged")
	report["passed"]=failures.is_empty();report["failures"]=failures
	report["unit_states_compared"]=unit_states_compared;report["query_results_compared"]=query_results_compared
	report["scope"]="Complete frozen 877e713 grid function vs production on shared real Units/maps. Ordered membership, focus, visual fields and downstream queries; eight deployments and moving synthetic crowds. Function-only paired timings, not live FPS or chapter playthrough."
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[grid-build-qa] ",JSON.stringify({"passed":report.passed,"checks":report.mode_checks.size(),"unit_states":unit_states_compared,"queries":query_results_compared,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
