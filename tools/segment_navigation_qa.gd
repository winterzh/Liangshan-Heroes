extends "res://tools/campaign_mode_performance_test.gd"
const SNAPSHOT := "res://tools/contracts/navigation/segment_before_7fbdc3a.txt"
const SNAPSHOT_SHA := "b056f62669523d9c1e22e81c37f03da1e48840d94dcbc451f486043f7f3fa82a"
var reference_script: GDScript
var comparisons := 0

func _snapshot_spec() -> Dictionary:
	return {"path":SNAPSHOT,"sha256":SNAPSHOT_SHA}

func _output_path() -> String:
	return "res://.godot/segment_navigation_qa"

func _reference(map):
	var old = reference_script.new()
	old.w = map.w; old.h = map.h
	old.astar = map.astar; old.astar_water = map.astar_water
	return old

func _rays(map, count: int, short_only := false) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 930060
	var rays := []
	for i in range(count):
		var a := Vector2(rng.randf_range(-32,map.w*32+32),rng.randf_range(-32,map.h*32+32))
		var z: Vector2 = a + Vector2(rng.randf_range(-40,40),rng.randf_range(-40,40))
		if not short_only and i % 4 == 0:
			z = Vector2(rng.randf_range(-32,map.w*32+32),rng.randf_range(-32,map.h*32+32))
		if not short_only and i % 4 == 1: z = a
		rays.append([a,z])
	return rays

func _compare(map, old, rays: Array, label: String) -> void:
	var mismatches := 0
	for profile in ["land", "water", "amphibious"]:
		for ray in rays:
			comparisons += 1
			if old._segment_open(ray[0],ray[1],profile) != map._segment_open(ray[0],ray[1],profile): mismatches += 1
	check(mismatches == 0, label + " matches frozen reference for land water and fallback profiles")
	report.samples.append({"label":label, "comparisons":rays.size()*3, "mismatches":mismatches})

func _boundary_cases() -> void:
	var Map = load("res://scripts/game_map.gd")
	var map = Map.new()
	map.init_map(8,8,"marsh",Map.T.GRASS)
	map.set_cell_t(3,2,Map.T.CLIFF)
	map.set_cell_t(2,3,Map.T.CLIFF)
	map.fill_rect(5,0,3,8,Map.T.WATER)
	map.bake()
	var old = _reference(map)
	var cases := [
		[Vector2(48,48),Vector2(60,60),"land",true,"same open cell"],
		[Vector2(112,80),Vector2(113,81),"land",false,"same blocked cell"],
		[Vector2(80,80),Vector2(112,112),"land",false,"diagonal corner blocked on both sides"],
		[Vector2(96,48),Vector2(96,80),"land",false,"exact tile edge reaches wall"],
		[Vector2(-0.001,16),Vector2(16,16),"land",false,"negative endpoint"],
		[Vector2(16,16),Vector2(256,16),"land",false,"right map boundary"],
		[Vector2(16,16),Vector2(16,256),"land",false,"bottom map boundary"],
		[Vector2(0,0),Vector2(16,16),"land",true,"inclusive top left boundary"],
		[Vector2(INF,16),Vector2(16,16),"land",false,"infinite endpoint"],
		[Vector2(NAN,16),Vector2(16,16),"land",false,"NaN endpoint"],
		[Vector2(176,16),Vector2(208,48),"water",true,"water passage"],
		[Vector2(176,16),Vector2(208,48),"land",false,"land cannot traverse water"],
		[Vector2(48,48),Vector2(60,60),"water",false,"ship cannot traverse land"],
	]
	for c in cases:
		check(map._segment_open(c[0],c[1],c[2]) == c[3] and old._segment_open(c[0],c[1],c[2]) == c[3], c[4])
	var start := Vector2(16,16)
	var end := Vector2(80,16)
	check(map._segment_open(start,end), "open dynamic passage before blocking")
	map.block_footprint(Vector2i(1,0),0,true)
	check(not map._segment_open(start,end) and not old._segment_open(start,end), "new dynamic blocker is seen immediately")
	map.block_footprint(Vector2i(1,0),0,false)
	check(map._segment_open(start,end) and old._segment_open(start,end), "removed dynamic blocker opens passage immediately")
	_compare(map,old,_rays(map,3000),"synthetic boundaries and obstacles")
	old.free(); map.free()

func _timing(map, rays: Array) -> Dictionary:
	var opened := 0
	var started := Time.get_ticks_usec()
	for repeat in range(10):
		for ray in rays: opened += int(map._segment_open(ray[0],ray[1]))
	return {"microseconds":Time.get_ticks_usec()-started,"queries":rays.size()*10,"open_results":opened}

func _paired_timing(map, old) -> void:
	var rays := _rays(map,10000,true)
	# Warm both paths before timing; alternate and reverse the middle pair.
	_timing(old,rays); _timing(map,rays)
	var windows := []
	for old_first in [true,false,true]:
		for reference in ([true,false] if old_first else [false,true]):
			var window := _timing(old if reference else map,rays)
			window["implementation"] = "reference" if reference else "optimized"
			windows.append(window)
	var reference_times := []; var optimized_times := []
	for window in windows:
		(reference_times if window.implementation == "reference" else optimized_times).append(window.microseconds)
	reference_times.sort(); optimized_times.sort()
	check(windows.all(func(x): return x.open_results == windows[0].open_results), "paired CPU windows return equal counts")
	report["cpu_timing"] = {"scope":"100000 short segment queries per window in frozen authored level3 collision grid, not game FPS", "windows":windows, "median_reference_us":reference_times[1], "median_optimized_us":optimized_times[1], "optimized_over_reference":float(optimized_times[1])/float(reference_times[1])}

func _crowd_equivalence() -> void:
	var b = await _start("level7",true)
	b._perf_bench_setup(200)
	b._prof_on = false
	b.process_mode = Node.PROCESS_MODE_DISABLED
	var map = b.map
	var old = _reference(map)
	var movers: Array = b.units.filter(func(u): return not u.is_building and not u.is_resource)
	var original: Array = movers.map(func(u): return u.position)
	var cases := 0
	for spacing in [0.65,1.0,1.7]:
		for phase_index in range(3):
			for stagger in [false,true]:
				for i in range(movers.size()): movers[i].position = original[0] + (original[i]-original[0])*spacing
				b._grid_build()
				b._mob_count = 321 if stagger else movers.size()
				var positions: Array = movers.map(func(u): return u.position)
				b._sep_phase = phase_index
				b.map = old
				b._separation_pass(1.0/60.0)
				var expected: Array = movers.map(func(u): return u.position)
				for i in range(movers.size()): movers[i].position = positions[i]
				b._sep_phase = phase_index
				b.map = map
				b._separation_pass(1.0/60.0)
				check(movers.map(func(u): return u.position) == expected, "crowd exact positions spacing=%s phase=%s stagger=%s" % [spacing,phase_index,stagger])
				cases += 1
	check(cases == 18 and movers.size() == 206, "all dense crowd and stagger fixtures actually ran")
	report["crowd"] = {"units":movers.size(),"cases":cases,"fixture":"Synthetic 200 enemies plus six heroes; three spacings and phases; stagger threshold explicitly injected; exact Vector2 equality."}
	old.free()
	await _dispose(b,true)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	output = ProjectSettings.globalize_path(_output_path())
	DirAccess.make_dir_recursive_absolute(output)
	AudioServer.set_bus_mute(0,true)
	var save_before := _save_hash()
	var snapshot := _snapshot_spec()
	check(FileAccess.get_sha256(snapshot.path) == snapshot.sha256, "frozen old function hash matches")
	if not failures.is_empty(): quit(2); return
	reference_script = GDScript.new()
	reference_script.source_code = "extends \"res://scripts/game_map.gd\"\n" + FileAccess.get_file_as_string(snapshot.path)
	# Compile after autoloads are ready, without changing reference function bytes.
	check(reference_script.reload() == OK, "reference compiles against unchanged map helpers")
	if not failures.is_empty(): quit(2); return
	_boundary_cases()
	for id in ["level1","level2","level3","level4","level5","level6","level7","level8"]:
		var b = await _start(id)
		b.process_mode = Node.PROCESS_MODE_DISABLED
		var old = _reference(b.map)
		_compare(b.map,old,_rays(b.map,3000),id)
		report.samples.back()["level_script"] = b.level.get_script().resource_path
		if id == "level3": _paired_timing(b.map,old)
		old.free()
		await _dispose(b,true)
	await _crowd_equivalence()
	check(comparisons == 81000 and report.samples.size() == 9, "all eight chapters and boundary grid comparisons completed")
	check(_save_hash() == save_before, "player campaign save bytes unchanged")
	report["passed"] = failures.is_empty()
	report["comparisons"] = comparisons
	report["failures"] = failures
	report["reference"] = snapshot
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[segment-navigation-summary] ",JSON.stringify({"checks":report.mode_checks.size(),"comparisons":comparisons,"passed":failures.is_empty(),"cpu_timing":report.cpu_timing}))
	quit(0 if failures.is_empty() else 1)
