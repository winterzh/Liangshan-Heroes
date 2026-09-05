extends "res://tools/campaign_mode_performance_test.gd"
const REFERENCE := "res://tools/contracts/separation/before_3a218f0.txt"
const REFERENCE_SHA := "f9dd340873d58ffe803d2793f388dbd98ebf8ee144dec8e523cee5b85fd7d1e5"
var position_comparisons := 0
var sequential_steps := 0

func _reference_spec() -> Dictionary:
	return {"path":REFERENCE,"sha256":REFERENCE_SHA}

func _output_path() -> String:
	return "res://.godot/crowd_separation_qa"

func _extra_cases(_battle, _reference) -> void:
	pass

func _positions(units: Array) -> Array:
	return units.map(func(u): return u.position)

func _restore(units: Array, positions: Array) -> void:
	for i in range(units.size()): units[i].position = positions[i]

func _state(units: Array) -> Array:
	return units.map(func(u): return [u.hp,u._state,u.radius,u.is_worker,u._carry_kind,u.garrisoned,u.story_outcome,u.movement_profile,u.selected,u._path,u._path_i])

func _reset_fields(units: Array, fields: Array) -> void:
	for i in range(units.size()):
		var u=units[i];var f: Array=fields[i]
		u.hp=f[0];u._state=f[1];u.radius=f[2];u.is_worker=f[3];u._carry_kind=f[4]
		u.garrisoned=f[5];u.story_outcome=f[6];u.movement_profile=f[7];u.selected=f[8]

func _timed(target, units: Array, positions: Array) -> Dictionary:
	var elapsed := 0
	var calls := 800 if units.size() <= 64 else 80
	for i in range(calls):
		_restore(units,positions)
		target._sep_phase=0
		var started := Time.get_ticks_usec()
		target._separation_pass(1.0/60.0)
		elapsed+=Time.get_ticks_usec()-started
	return {"calls":calls,"microseconds":elapsed}

func _benchmark(b, old, units: Array, positions: Array, label: String) -> void:
	_restore(units,positions)
	b._grid_build();b._mob_count=units.size()
	old.units=b.units;old._mob_grid=b._mob_grid;old._mob_count=b._mob_count
	_timed(b,units,positions);_timed(old,units,positions)
	var samples := []
	for old_first in [true,false,true]:
		for reference in ([true,false] if old_first else [false,true]):
			var sample := _timed(old if reference else b,units,positions)
			sample["implementation"]="reference" if reference else "optimized"
			samples.append(sample)
	var before:=[];var after:=[]
	for sample in samples: (before if sample.implementation=="reference" else after).append(sample.microseconds)
	before.sort();after.sort()
	var phase_counts := [0,0,0]
	for u in units: phase_counts[u.get_instance_id()%3]+=1
	report.samples.append({"label":label,"units":units.size(),"windows":samples,"median_reference_us":before[1],"median_optimized_us":after[1],"optimized_over_reference":float(after[1])/before[1],"sampled_phase":1,"phase_populations":phase_counts,"grid_buckets":b._mob_grid.size()})

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	output=ProjectSettings.globalize_path(_output_path())
	DirAccess.make_dir_recursive_absolute(output)
	var saved_before:=_save_hash()
	var reference:=_reference_spec()
	check(FileAccess.get_sha256(reference.path)==reference.sha256,"frozen separation reference hash matches")
	if not failures.is_empty(): quit(2);return
	var b=await _start("level7",true)
	b._perf_bench_setup(200);b._prof_on=false
	b.process_mode=Node.PROCESS_MODE_DISABLED
	var reference_script:=GDScript.new()
	reference_script.source_code="extends \"res://scripts/battle.gd\"\n"+FileAccess.get_file_as_string(reference.path)
	check(reference_script.reload()==OK,"frozen reference compiles after actual Battle startup")
	if not failures.is_empty(): quit(2);return
	var old=reference_script.new()
	old.map=b.map
	var units: Array=b.units.filter(func(u):return not u.is_building and not u.is_resource)
	var baseline:=_positions(units)
	var fields:=_state(units)
	var ordinary_order: Array=b.units.duplicate()
	var variants := ["moving","idle","mixed_water","gold_workers","fractional_radii","same_position","reversed_order","stale_grid"]
	var completed:=0
	for variant in variants:
		for spacing in [0.7,1.7]:
			for stagger in [false,true]:
				_reset_fields(units,fields)
				b.units.assign(ordinary_order)
				for i in range(units.size()):
					units[i].position=baseline[0]+(baseline[i]-baseline[0])*spacing
					match variant:
						"idle": units[i]._state=units[i].ST_IDLE
						"mixed_water": units[i].movement_profile="water" if i%3==0 else "land"
						"gold_workers":
							units[i].is_worker=i%2==0;units[i]._carry_kind="gold"
							units[i]._state=units[i].ST_GATHER if i%3==0 else units[i].ST_RETURN
						"fractional_radii": units[i].radius=8.3+float(i%12)*0.917
						"same_position": units[i].position=baseline[0]
				if variant=="reversed_order": b.units.reverse()
				var mismatch:=false
				for tick in range(9):
					b._grid_build()
					if variant=="stale_grid":
						# State can change after grid build in real ability/death processing.
						for i in range(units.size()):
							if i%11==0: units[i].hp=0.0
							elif i%13==0: units[i].story_outcome="retreated"
							elif i%17==0: units[i].garrisoned=true
					b._mob_count=321 if stagger else units.size()
					old.units=b.units;old._mob_grid=b._mob_grid;old._mob_count=b._mob_count
					var start:=_positions(units)
					var state_before:=_state(units)
					old._sep_phase=tick%3;b._sep_phase=tick%3
					old._separation_pass(1.0/60.0)
					var expected:=_positions(units)
					_restore(units,start)
					b._separation_pass(1.0/60.0)
					mismatch=mismatch or _positions(units)!=expected or b._sep_phase!=old._sep_phase or _state(units)!=state_before
					position_comparisons+=units.size();sequential_steps+=1
				check(not mismatch,"nine consecutive exact steps: %s spacing=%s stagger=%s"%[variant,spacing,stagger])
				completed+=1
	_reset_fields(units,fields);b.units.assign(ordinary_order)
	_benchmark(b,old,units,baseline,"dense_206")
	var sparse:=baseline.map(func(p):return baseline[0]+(p-baseline[0])*2.4)
	_benchmark(b,old,units,sparse,"spread_206")
	check(completed==32 and sequential_steps==288 and units.size()==206,"all regular stagger and edge fixtures completed")
	check(report.samples.size()==2,"both paired timing workloads completed")
	await _extra_cases(b,old)
	old.free()
	await _dispose(b,true)
	check(_save_hash()==saved_before,"player campaign save bytes unchanged")
	report["scope"]="Base fixtures: frozen old solver vs optimized solver on the same 206 actual Units, 32 explicitly synthetic fixtures with nine consecutive steps each; timings exclude external position reset/grid setup but include all internal solver work; not live game FPS."
	report["reference"]=reference
	report["position_comparisons"]=position_comparisons
	report["sequential_steps"]=sequential_steps
	report["passed"]=failures.is_empty();report["failures"]=failures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[crowd-separation-summary] ",JSON.stringify({"checks":report.mode_checks.size(),"positions":position_comparisons,"steps":sequential_steps,"passed":failures.is_empty(),"sample_count":report.samples.size()}))
	quit(0 if failures.is_empty() else 1)
