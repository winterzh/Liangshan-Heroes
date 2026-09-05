extends "res://tools/campaign_mode_performance_test.gd"

const REFERENCE := "res://tools/contracts/canopy/before_2b14c2a.txt"
const REFERENCE_SHA := "1975f420cfee3890d2f67c3b32dac6a3b21477ef557339c405f7c60cdd52ef38"
var alpha_comparisons := 0

class ProbeUnit extends Node2D:
	var hp := 100.0
	var is_building := false

class ProbeBattle extends Node:
	var units := []

func _alphas(nodes: Array) -> Array:
	return nodes.map(func(n): return n.modulate)

func _compare(s, old, label: String) -> void:
	old._map=s._map;old._battle=s._battle
	old._trees=s._trees;old._guard_posts=s._guard_posts
	var nodes: Array=s._trees+s._guard_posts
	var colors:=_alphas(nodes)
	old._refresh_canopy_visibility()
	var expected:=_alphas(nodes)
	for i in range(nodes.size()): nodes[i].modulate=colors[i]
	s._refresh_canopy_visibility()
	check(_alphas(nodes)==expected,label+" exact tree/post RGBA")
	alpha_comparisons+=nodes.size()

func _timed(target, calls: int) -> int:
	var started:=Time.get_ticks_usec()
	for i in range(calls): target._refresh_canopy_visibility()
	return Time.get_ticks_usec()-started

func _benchmark(s, old, label: String) -> void:
	_compare(s,old,label)
	_timed(s,10);_timed(old,10)
	var windows:=[];var before:=[];var after:=[]
	for old_first in [true,false,true]:
		for is_old in ([true,false] if old_first else [false,true]):
			var duration:=_timed(old if is_old else s,40)
			(before if is_old else after).append(duration)
			windows.append({"implementation":"reference" if is_old else "optimized","calls":40,"microseconds":duration})
	before.sort();after.sort()
	var eligible: int=s._battle.units.filter(func(u): return is_instance_valid(u) and u.hp>0 and not u.is_building and u.visible).size()
	report.samples.append({"label":label,"scene_units":s._battle.units.size(),"eligible_units":eligible,"trees":s._trees.size(),"posts":s._guard_posts.size(),"windows":windows,"median_reference_us":before[1],"median_optimized_us":after[1],"optimized_over_reference":float(after[1])/maxi(1,before[1])})

func _fixtures(old) -> void:
	var scenery_script=load("res://scripts/liangshan_scenery.gd")
	var s=scenery_script.new()
	var map_script:=GDScript.new()
	map_script.source_code="extends \"res://scripts/game_map.gd\"\nvar projections := 0\nfunc project(p: Vector2) -> Vector2:\n\tprojections+=1\n\treturn super.project(p)\n"
	check(map_script.reload()==OK,"projection-count fixture compiles")
	var map=map_script.new()
	s._map=map;s._battle=ProbeBattle.new()
	var tree=scenery_script.ScenerySprite.new()
	tree.position=Vector2.ZERO;tree.size=100.0;tree.z_index=20
	tree.modulate=Color(0.73,0.88,0.61,1.0)
	s._trees.append(tree)
	var u:=ProbeUnit.new()
	s._battle.units=[u]
	var cases:=[
		{"label":"inside","feet":Vector2(0,-40),"fade":true},
		{"label":"left touches","feet":Vector2(-49,-40),"fade":false},
		{"label":"left overlaps","feet":Vector2(-48.99,-40),"fade":true},
		{"label":"right touches","feet":Vector2(49,-40),"fade":false},
		{"label":"right overlaps","feet":Vector2(48.99,-40),"fade":true},
		{"label":"top touches","feet":Vector2(0,-89),"fade":false},
		{"label":"top overlaps","feet":Vector2(0,-88.99),"fade":true},
		{"label":"bottom touches","feet":Vector2(0,33),"fade":false},
		{"label":"bottom overlaps","feet":Vector2(0,32.99),"fade":true},
		{"label":"outside","feet":Vector2(500,400),"fade":false},
		{"label":"same depth","feet":Vector2(0,-40),"z":20,"fade":false},
		{"label":"in front","feet":Vector2(0,-40),"z":21,"fade":false},
		{"label":"hidden","feet":Vector2(0,-40),"shown":false,"fade":false},
		{"label":"dead","feet":Vector2(0,-40),"hp":0.0,"fade":false},
		{"label":"building","feet":Vector2(0,-40),"building":true,"fade":false},
		{"label":"negative depth","feet":Vector2(0,-40),"z":-100,"fade":true},
	]
	for entry in cases:
		u.position=map.ISO_INV*entry.feet;u.z_index=entry.get("z",19)
		u.visible=entry.get("shown",true);u.hp=entry.get("hp",100.0);u.is_building=entry.get("building",false)
		_compare(s,old,entry.label)
		check(is_equal_approx(tree.modulate.a,0.4 if entry.fade else 1.0),entry.label+" expected opacity")
	u.is_building=false;u.hp=100.0;u.visible=true;u.z_index=0
	s._battle.units.append(u);s._battle.units.append(null)
	var freed:=ProbeUnit.new();s._battle.units.append(freed);freed.free()
	_compare(s,old,"duplicate, null and freed unit references")
	s._guard_posts.append(tree)
	_compare(s,old,"same sprite appears in trees and posts")
	s._trees.clear()
	_compare(s,old,"guard posts alone")
	s._guard_posts.clear()
	_compare(s,old,"no scenery")
	map.projections=0;s._refresh_canopy_visibility()
	check(map.projections==0,"no canopies skips unit projection work")
	s._trees.append(tree);s._battle.units.clear()
	_compare(s,old,"no units restores opacity")
	u.free()
	# A deterministic worst-case scan: every unit is behind, outside every canopy.
	for i in range(206):
		var unit:=ProbeUnit.new();unit.position=Vector2(1000+i*3,900-i*2)
		s._battle.units.append(unit)
	for i in range(99):
		var extra=scenery_script.ScenerySprite.new();extra.size=100.0
		extra.position=Vector2(i*2,i);extra.z_index=20;s._trees.append(extra)
	_compare(s,old,"206 units and 100 unobstructed canopies")
	map.projections=0;old._refresh_canopy_visibility();var reference_calls: int=map.projections
	map.projections=0;s._refresh_canopy_visibility();var optimized_calls: int=map.projections
	check(reference_calls==20700 and optimized_calls==306,"projections reduced from pairs to units plus canopies")
	report["projection_counts"]={"reference":reference_calls,"optimized":optimized_calls}
	_benchmark(s,old,"synthetic_206_outside_100_canopies")
	for unit in s._battle.units: unit.free()
	for node in s._trees: node.free()
	s._battle.free();s.free();map.free()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/canopy_visibility_qa")
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before:=_save_hash()
	check(FileAccess.get_sha256(REFERENCE)==REFERENCE_SHA,"frozen old canopy loop hash matches")
	var reference_source:=FileAccess.get_file_as_string(REFERENCE)
	var old_script:=GDScript.new();old_script.source_code=reference_source
	check(old_script.reload()==OK,"frozen old canopy loop compiles")
	if not failures.is_empty(): quit(2);return
	var old=old_script.new()
	_fixtures(old)
	for id in ["level1","level2","level3","level4","level5","level6","level7","level8"]:
		var b=await _start(id)
		b.process_mode=Node.PROCESS_MODE_DISABLED
		var s=b.map.sample_scenery
		check(s!=null,id+" constructs production scenery")
		if s!=null:
			_compare(s,old,id+" authored scene")
			s._visibility_tick=0.0;s._process(0.04)
			check(is_equal_approx(s._visibility_tick,0.04),id+" retains sub-tick cadence")
			s._process(0.06)
			check(s._visibility_tick==0.0,id+" refreshes on 0.1 second boundary")
			_compare(s,old,id+" after full scenery update")
			if id=="level5":
				_benchmark(s,old,"level5_authored")
				b._perf_bench_setup(200);b._prof_on=false
				await process_frame
				_compare(s,old,"level5 200-enemy bench on elevated map")
				_benchmark(s,old,"level5_200_enemy_bench")
				for unit in b.units: unit.visible=true
				_benchmark(s,old,"level5_bench_all_units_shown")
		await _dispose(b,true)
	old.free()
	check(_save_hash()==saved_before,"player campaign save bytes unchanged")
	check(report.samples.size()==4,"all four paired timing workloads completed")
	report["reference"]={"path":REFERENCE,"sha256":FileAccess.get_sha256(REFERENCE)}
	report["alpha_comparisons"]=alpha_comparisons
	report["failures"]=failures
	report["passed"]=failures.is_empty()
	report["scope"]="Frozen old canopy loop, exact RGBA and edge/depth/state fixtures; all eight actual campaign maps. Pair timings include temporary body/depth preparation and alpha writes. Simulation is frozen for comparisons; this is not gameplay FPS or a human playtest."
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[canopy-qa] ",JSON.stringify({"passed":report.passed,"checks":report.mode_checks.size(),"alpha_comparisons":alpha_comparisons,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
