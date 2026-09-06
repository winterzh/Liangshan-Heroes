extends "res://tools/crowd_separation_qa.gd"

func _reference_spec() -> Dictionary:
	return {"path":"res://tools/contracts/separation/before_4589c85.txt","sha256":"a1953e526f83bbede3cbd65621c1b892314c1d36f21ebb8e45edbba3065734f6"}

func _output_path() -> String:
	return "res://.godot/crowd_buffer_qa"

func _extra_cases(b, old) -> void:
	var layouts := 0
	var extra_positions := 0
	var extra_steps := 0
	for target_count in [6,30,63,64,128,320,321,326,506]:
		b._perf_bench_setup(target_count-6);b._prof_on=false
		await process_frame # Flush the previous setup's queued Unit nodes.
		var units: Array=b.units.filter(func(u):return not u.is_building and not u.is_resource)
		var ordinary_order: Array=b.units.duplicate()
		var baseline:=_positions(units)
		check(units.size()==target_count,"actual Unit count reaches %s"%target_count)
		for variant in ["normal","duplicate_entries","bucket_only","shifted_after_grid"]:
			_restore(units,baseline)
			var mismatch:=false
			for tick in range(3):
				b.units.assign(ordinary_order)
				if variant=="duplicate_entries":
					b.units.append(units[0]);b.units.append(units[1])
				b._grid_build()
				if variant=="bucket_only":
					b.units.erase(units[-1]);b.units.erase(units[-2])
				if variant=="shifted_after_grid":
					for i in range(0,units.size(),7): units[i].position+=Vector2(96,-32)
				old.units=b.units;old._mob_grid=b._mob_grid;old._mob_count=b._mob_count
				old._sep_phase=tick;b._sep_phase=tick
				var positions:=_positions(units)
				var fields:=_state(units)
				old._separation_pass(1.0/60.0)
				var expected:=_positions(units)
				_restore(units,positions)
				b._separation_pass(1.0/60.0)
				mismatch=mismatch or _positions(units)!=expected or _state(units)!=fields or b._sep_phase!=old._sep_phase
				extra_steps+=1;extra_positions+=units.size()
			check(not mismatch,"exact three-step %s at %s actual Units"%[variant,target_count])
			layouts+=1
		b.units.assign(ordinary_order)
		# Keep the warmed 206-unit base samples; report complete-dispatch timings
		# for small, boundary, ordinary and genuinely staggered populations too.
		_benchmark(b,old,units,baseline,"dense_%s"%target_count)
		var spread:=baseline.map(func(p):return baseline[0]+(p-baseline[0])*2.4)
		_benchmark(b,old,units,spread,"spread_%s"%target_count)
	check(layouts==36 and extra_steps==108 and extra_positions==21168,"all population and stale-grid fixtures completed")
	check(report.samples.size()==20,"all twenty density/population timing workloads completed")
	position_comparisons+=extra_positions;sequential_steps+=extra_steps
	report["buffer_fixtures"]={"layouts":layouts,"steps":extra_steps,"position_comparisons":extra_positions,"scope":"Actual populations 6/30/63/64/128/320/321/326/506; three consecutive steps; duplicate order and bucket entries, bucket-only neighbors and coordinates changed after grid build."}
