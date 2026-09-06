extends "res://tools/chase_speed_qa.gd"
const ACQUIRE_REFERENCE := "res://tools/contracts/enemy_candidates/before_bf3e1a6.txt"
const ACQUIRE_SHA := "0309d0fcd3acc29bc5a41b8f35aad827b14d383a9ee79c32c37ba887da29f7e7"
var query_comparisons := 0
var decision_comparisons := 0
class LegacyQuery extends Node2D:
	var proxy
	var _focus_counts := {}
	func units_near(pos: Vector2,radius: float) -> Array: return proxy.units_near(pos,radius)
	func target_visible_to(observer,target) -> bool: return proxy.target_visible_to(observer,target)

func _identities(units: Array) -> Array:
	return units.map(func(u):return u.get_instance_id() if is_instance_valid(u) else 0)

func _grid_snapshot(b) -> Array:
	var result:=[]
	for key in b._grid:result.append([key,_identities(b._grid[key])])
	return result

func _query_pair(b,point: Vector2,radius: float,faction: int) -> bool:
	var expected: Array=b.units_near(point,radius).filter(func(u):return is_instance_valid(u) and u.faction!=faction)
	var actual: Array=b.enemy_candidates_near(point,radius,faction)
	query_comparisons+=1
	return actual==expected

func _decision_pair(u,range_override: float,closest: bool) -> bool:
	var before:=_capture(u)
	u._qa_reference_acquire(range_override,closest)
	var expected_target = u._target
	var expected:=var_to_bytes(_capture(u))
	_restore(u,before);u._acquire(range_override,closest)
	decision_comparisons+=1
	return u._target==expected_target and var_to_bytes(_capture(u))==expected

func _candidate_queries(b) -> void:
	var units: Array=b.units.filter(func(u):return is_instance_valid(u))
	var saved_units: Array=b.units.duplicate()
	var saved_factions: Array=units.map(func(u):return u.faction)
	var points: Array=[Vector2(-64,-64),Vector2.ZERO,Vector2(63.999996,64),Vector2(64,64),Vector2(64.000008,64),Vector2(1000,1000)]
	for u in units.slice(0,12):points.append(u.position)
	for variant in ["ordinary","reverse","duplicates","empty_bucket","moved_after_grid","faction_changes","invalid_entries","no_grid"]:
		b._grid_build()
		var saved_positions: Array=units.map(func(u):return u.position)
		match variant:
			"reverse":
				for key in b._grid:b._grid[key].reverse()
			"duplicates":
				for key in b._grid:
					if not b._grid[key].is_empty():b._grid[key].append(b._grid[key][0])
			"empty_bucket":b._grid[Vector2i(-1,-1)]=[]
			"moved_after_grid":
				for i in range(0,units.size(),3):units[i].position+=Vector2(192,-64)
			"faction_changes":
				for i in range(units.size()):units[i].faction=i%4-1
			"invalid_entries":
				var dying=load("res://scripts/unit.gd").new()
				for key in b._grid:b._grid[key].append(null);b._grid[key].append(dying)
				b.units.append(null);b.units.append(dying);dying.free()
			"no_grid":b._grid.clear()
		var grid_before:=_grid_snapshot(b);var units_before:=_identities(b.units)
		var exact:=true
		for point in points:
			for radius in [0.0,1.0,63.999999,64.0,64.000001,180.0,240.0]:
				for faction in [-1,0,1,2]:exact=_query_pair(b,point,radius,faction) and exact
		check(exact,"same filtered identities and order for every query: "+variant)
		check(grid_before==_grid_snapshot(b) and units_before==_identities(b.units),"query leaves input grid/list membership and order unchanged: "+variant)
		for i in range(units.size()):units[i].position=saved_positions[i];units[i].faction=saved_factions[i]
		b.units.assign(saved_units)
	b._grid_build()

func _decision_cases(b,script: GDScript) -> void:
	# Arena normally has no fog buffers; initialize the real fog implementation
	# before enabling it in isolated sight/reveal scenarios below.
	b._init_fog()
	var u=_unit(b,script,0)
	var foes: Array=[_unit(b,script,1),_unit(b,script,1),_unit(b,script,1)]
	var ally=_unit(b,script,0)
	var ordinary: Array=b.units.duplicate();b.units.assign([u,foes[0],foes[1],ally,foes[2]])
	var baselines: Array=([u]+foes+[ally]).map(func(x):return _capture(x))
	var cases: Array=["normal","ties","reverse_ties","same_target","closer_target","wounded","hero","siege","ranged","attacking_self","focus_counts","hidden_reeds","invisible","resource","garrisoned","story","captive","pending_build","no_auto_target","dead","giveup","convert_enemy","convert_ally","duplicate_bucket","bucket_only","moved_after_grid","no_grid","fog","fog_hidden","fog_sight","fog_reveal","nonstandard_faction"]
	for label in cases:
		var all_units: Array=[u]+foes+[ally]
		for i in range(all_units.size()):_restore(all_units[i],baselines[i]);all_units[i].remove_meta("campaign_no_auto_target")
		b.units.assign([u,foes[0],foes[1],ally,foes[2]]);b.fog=false
		b._sight_now.fill(0);b._reveal_t.fill(0.0)
		u.position=Vector2(600,600);u.aggro_range=240;u._giveup_t=0;u._target=null;u._chase_best_distance=123.0
		for i in range(foes.size()):foes[i].position=u.position+Vector2(70+i*30,0)
		ally.position=u.position+Vector2(20,0)
		match label:
			"ties","reverse_ties":foes[1].position=foes[0].position
			"same_target":u._target=foes[0]
			"closer_target":u._target=foes[2]
			"wounded":foes[2].hp=1
			"hero":foes[2].is_hero=true
			"siege":foes[2].key="siege_cata"
			"ranged":foes[2].is_ranged=true
			"attacking_self":foes[2]._target=u
			"hidden_reeds":foes[0].hidden_in_reeds=true;foes[0].position=u.position+Vector2(75.000008,0)
			"invisible":foes[0]._invis_t=10
			"resource":foes[0].is_resource=true
			"garrisoned":foes[0].garrisoned=true
			"story":foes[0].story_outcome="retreated"
			"captive":foes[0].is_captive=true
			"pending_build":foes[0]._pending_build=true
			"no_auto_target":foes[0].set_meta("campaign_no_auto_target",true)
			"dead":foes[0].hp=0
			"giveup":u._giveup_id=foes[0].get_instance_id();u._giveup_t=2.0
			"fog":b.fog=true
			"fog_hidden","fog_sight","fog_reveal":
				b.fog=true;u.setup_def=u.setup_def.duplicate(true);u.setup_def["sight"]=1
				var c: Vector2i=b.map.world_to_cell(foes[0].position)
				if label=="fog_sight":b._sight_now[c.y*b.map.w+c.x]=1
				if label=="fog_reveal":b._reveal_t[c.y*b.map.w+c.x]=1.0
			"nonstandard_faction":u.faction=-1;ally.faction=2
		b._grid_build()
		match label:
			"reverse_ties":
				for key in b._grid:b._grid[key].reverse()
			"focus_counts":b._focus_counts[foes[0].get_instance_id()]=6
			"convert_enemy":foes[0].faction=u.faction
			"convert_ally":ally.faction=1
			"duplicate_bucket":
				for key in b._grid:
					if not b._grid[key].is_empty():b._grid[key].append(b._grid[key][0])
			"bucket_only":b.units.erase(foes[0])
			"moved_after_grid":foes[0].position+=Vector2(320,0)
			"no_grid":b._grid.clear()
		var exact:=true
		for stance in [u.STANCE_AGGRO,u.STANCE_DEFEND,u.STANCE_HOLD,u.STANCE_PASSIVE]:
			u.stance=stance
			for radius in [-1.0,0.0,50.0,75.0,240.0,NAN]:
				for closest in [false,true]:exact=_decision_pair(u,radius,closest) and exact
		check(exact,"complete acquire state and exact selected object match: "+label)
	# Exact float32 distance neighbors are supplied as positions, not rounded text.
	var exact:=true
	for distance in [4.0,12.0,75.0,240.0]:
		for offset in [-1,0,1]:
			var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,distance);bytes.encode_u32(0,bytes.decode_u32(0)+offset)
			u.position=Vector2.ZERO;u.stance=u.STANCE_AGGRO;u.faction=0
			foes[0].position=Vector2(bytes.decode_float(0),0);foes[0].faction=1;foes[0].hp=100;foes[0].hidden_in_reeds=true
			b.units.assign([u,foes[0]]);b._grid_build()
			for closest in [false,true]:exact=_decision_pair(u,distance,closest) and exact
	check(exact,"float32 predecessor/exact/successor distance and reed limits preserve decisions")
	var adapter:=LegacyQuery.new();adapter.proxy=b;adapter._focus_counts=b._focus_counts;u.battle=adapter
	check(_decision_pair(u,-1,false),"legacy two-argument units_near adapter retains complete acquire behavior")
	u.battle=b;adapter.free()
	for range_cap in [0.0,-1.0]:
		u.aggro_range=range_cap
		check(_decision_pair(u,-1,false),"disabled acquisition preserves existing state at range "+str(range_cap))
	b.units.assign(ordinary);b.fog=false
	for x in [u]+foes+[ally]:x.free()
	b._grid_build()

func _time_acquire(u,reference: bool,origin: Vector2) -> int:
	var elapsed:=0
	for i in range(2000):
		u.position=origin;u._target=null;u._chase_best_distance=INF
		var start:=Time.get_ticks_usec()
		if reference:u._qa_reference_acquire()
		else:u._acquire()
		elapsed+=Time.get_ticks_usec()-start
	return elapsed

func _benchmarks(b,script: GDScript) -> void:
	var u=_unit(b,script,0);u.aggro_range=240;u.stance=u.STANCE_AGGRO
	for count in [64,206,506]:
		b._perf_bench_setup(count-6);b._prof_on=false;await process_frame
		var original_factions: Array=b.units.map(func(x):return x.faction)
		var origin: Vector2=b.units.filter(func(x):return not x.is_building and not x.is_resource and x.faction==1)[0].position
		for density in ["homogeneous","mixed"]:
			if density=="mixed":
				for i in range(b.units.size()):b.units[i].faction=i%2
			b._grid_build()
			for faction in [0,1]:
				u.faction=faction;u.position=origin
				check(_decision_pair(u,-1,false),"timed complete acquire selects same target "+str(count)+" "+density+" "+str(faction))
				_time_acquire(u,true,origin);_time_acquire(u,false,origin)
				var windows:=[];var before:=[];var after:=[]
				for old_first in [true,false,true]:
					for reference in ([true,false] if old_first else [false,true]):
						var elapsed:=_time_acquire(u,reference,origin)
						windows.append({"reference":reference,"us":elapsed,"calls":2000});(before if reference else after).append(elapsed)
				before.sort();after.sort();report.samples.append({"units":count,"density":density,"faction":faction,"windows":windows,"before_us":before[1],"after_us":after[1],"ratio":float(after[1])/before[1],"all_candidates":b.units_near(origin,240).size(),"opponents":b.enemy_candidates_near(origin,240,faction).size()})
		for i in range(b.units.size()):b.units[i].faction=original_factions[i]
	u.free();b._grid_build()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path("res://.godot/enemy_candidates_qa");DirAccess.make_dir_recursive_absolute(output)
	var saved:=_save_hash()
	check(FileAccess.get_sha256(ACQUIRE_REFERENCE)==ACQUIRE_SHA,"frozen complete bf3e1a6 acquire hash matches")
	var b=await _start("level7",true);b.process_mode=Node.PROCESS_MODE_DISABLED
	var script:=GDScript.new();script.source_code='extends "res://scripts/unit.gd"\n'+FileAccess.get_file_as_string(ACQUIRE_REFERENCE).replace('func _acquire(','func _qa_reference_acquire(')
	check(script.reload()==OK,"frozen complete acquire method compiles on actual Unit")
	if not failures.is_empty():quit(2);return
	b._perf_bench_setup(200);b._prof_on=false;await process_frame
	_candidate_queries(b);_decision_cases(b,script);await _benchmarks(b,script)
	await _dispose(b,true);check(_save_hash()==saved,"player campaign save bytes unchanged")
	report["query_comparisons"]=query_comparisons;report["decision_comparisons"]=decision_comparisons
	report["passed"]=failures.is_empty();report["failures"]=failures
	report["scope"]="Live faction reads and original candidate order against units_near, including edited/empty grids and invalid/duplicate entries. Complete frozen acquire compares all Unit script state and selected object. Twelve full-function paired timings include query allocation/filtering/scoring; external state reset excluded, not live FPS."
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[enemy-candidates-qa] ",JSON.stringify({"checks":report.mode_checks.size(),"passed":report.passed,"queries":query_comparisons,"decisions":decision_comparisons,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
