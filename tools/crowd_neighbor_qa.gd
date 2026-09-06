extends "res://tools/crowd_buffer_qa.gd"
## Compare the complete dispatch against the already-buffered 5457de7 solver.
func _reference_spec() -> Dictionary:
	return {"path":"res://tools/contracts/crowd_neighbors/dispatch_before_5457de7.txt","sha256":"6e077651061a8c51448b09d443f8f963cb9746762d5a92a36c5b2271e528a5c7"}

func _output_path() -> String:
	return "res://.godot/crowd_neighbor_qa"

func _bucket_snapshot(buckets: Dictionary) -> Dictionary:
	var result := {}
	for cell in buckets:
		result[cell] = buckets[cell].map(func(u): return u.get_instance_id())
	return result

func _counted_solver(source: String):
	var marker := "\t\t\t\t\tif ids[bi] <= aid"
	check(source.count(marker)==1,"counter observes the actual innermost candidate loop")
	var script := GDScript.new()
	script.source_code=source.replace(marker,"\t\t\t\t\tqa_visits += 1\n"+marker)
	script.source_code+="\nstatic var qa_visits := 0\nstatic func qa_count() -> int: return qa_visits\n"
	check(script.reload()==OK,"candidate-count solver compiles")
	return script

func _extra_cases(b, old) -> void:
	await super(b,old)
	b._perf_bench_setup(200);b._prof_on=false
	await process_frame
	var units: Array=b.units.filter(func(u):return not u.is_building and not u.is_resource)
	var baseline:=_positions(units)
	var layouts:=0
	for variant in ["reverse_buckets","zigzag_buckets","adjacent_duplicates","empty_bucket"]:
		_restore(units,baseline)
		var exact:=true
		var unchanged:=true
		for tick in range(3):
			b._grid_build()
			for cell in b._mob_grid:
				var bucket: Array=b._mob_grid[cell]
				if variant=="reverse_buckets": bucket.reverse()
				elif variant=="zigzag_buckets" and bucket.size()>2:
					var first=bucket.pop_front();bucket.insert(1,first)
				elif variant=="adjacent_duplicates" and not bucket.is_empty():
					bucket.insert(0,bucket[0])
			if variant=="empty_bucket": b._mob_grid[Vector2i(-2,-2)]=[]
			var buckets_before:=_bucket_snapshot(b._mob_grid)
			var start:=_positions(units);var fields:=_state(units)
			old.units=b.units;old._mob_grid=b._mob_grid;old._mob_count=b._mob_count
			old._sep_phase=tick;b._sep_phase=tick
			old._separation_pass(1.0/60.0)
			var expected:=_positions(units)
			_restore(units,start)
			b._separation_pass(1.0/60.0)
			exact=exact and _positions(units)==expected and _state(units)==fields and old._sep_phase==b._sep_phase
			unchanged=unchanged and _bucket_snapshot(b._mob_grid)==buckets_before
			position_comparisons+=units.size();sequential_steps+=1
		check(exact,"three exact ordered candidate steps: "+variant)
		check(unchanged,"input grid membership and order retained: "+variant)
		layouts+=1
	report["neighbor_fixtures"]={"layouts":layouts,"steps":12,"positions":2472}
	# Counting runs separately from all timings. Both execute the full solver.
	var counted := []
	var ends := []
	for path in ["res://tools/contracts/crowd_neighbors/solver_before_5457de7.txt","res://scripts/crowd_separation.gd"]:
		var script=_counted_solver(FileAccess.get_file_as_string(path))
		_restore(units,baseline);b._grid_build()
		script.call("solve",b.units,b._mob_grid,b.map,b.GRID_CELL)
		counted.append(script.call("qa_count"));ends.append(_positions(units))
	check(ends[0]==ends[1],"counted full solvers retain identical actual positions")
	check(counted[1]<counted[0],"pruning reduces actual candidate loop visits")
	report["candidate_visits"]={"units":units.size(),"before":counted[0],"after":counted[1],"scope":"One dense 206-unit pass, separate counters with no timing claim; counts include rejected pairs reached by the inner loop."}
