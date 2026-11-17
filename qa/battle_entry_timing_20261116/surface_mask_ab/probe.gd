extends "res://tools/zhujiazhuang_rts_test.gd"
## A/B the original and current mask builders against the same authored grids.

var before: Script
var facts := {}

func _run() -> void:
	var profile := OS.get_environment("APPDATA").replace("\\","/")
	if OS.get_environment("STEAM_DISABLED") != "1" or not profile.contains("/surface-mask-ab-") \
			or not OS.get_user_data_dir().replace("\\","/").begins_with(profile + "/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	before = load(OS.get_environment("SURFACE_OLD_MAP_SCRIPT"))
	var flow = root.get_node("ContinueFlow")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy() and flow.phase != flow.Phase.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(flow.can_launch() and before != null,"campaign startup and baseline script are ready")
	if not failures.is_empty():
		_finish()
		return
	var b = await _start("",2)
	check(b.phase == b.Phase.FIGHT and b.level.id() == "level3","actual Zhu Manor battle starts")
	if not failures.is_empty():
		_finish()
		return
	b.set_physics_process(false)
	var elapsed := _compare_modes(b.map,"zhu_battle")
	var installed: Dictionary = b.map.get_meta("natural_surface_contract",{})
	check(installed.land_sha256 == elapsed["enabled"]["land_sha256"]
		and installed.weight_sha256 == elapsed["enabled"]["weight_sha256"],
		"normal Zhu entry binds the byte-identical new textures")
	facts["zhu_entry"] = elapsed
	facts["zhu_rebuild"] = _sample_masks(b.map)
	await _dispose(b)
	var campaign = root.get_node("Campaign")
	var environment: Script = load("res://scripts/campaign_environment.gd")
	var map_script: Script = load("res://scripts/game_map.gd")
	var maps := {}
	for entry in campaign.LEVELS:
		var level = load(entry.script).new()
		var map = map_script.new()
		map.init_map(level.map_w(),level.map_h(),level.map_theme(),level.map_base())
		level.paint_map(map)
		environment.paint(map,entry.id)
		maps[entry.id] = _compare_modes(map,entry.id)
		map.free()
	facts["authored_maps"] = maps
	var boundary = map_script.new()
	boundary.init_map(19,18,"plain",boundary.T.GRASS)
	boundary.environment_style = "level3"
	check(boundary.natural_hard_edge_cell(19,15),"authored wall exists just outside the last map column")
	facts["truncated_boundary"] = _compare_modes(boundary,"truncated boundary")
	boundary.natural_surface_enabled = true
	check(boundary.natural_surface_maps().land.get_pixel(18,15).g > 0.99,"the outside wall protects its in-bounds neighbor")
	boundary.free()
	_finish()

func _baseline(map):
	var old = before.new()
	old.w = map.w
	old.h = map.h
	old.grid = map.grid.duplicate()
	old.environment_style = map.environment_style
	old.natural_surface_enabled = map.natural_surface_enabled
	return old

func _compare_modes(map, label: String) -> Dictionary:
	var original = _baseline(map)
	var start: bool = map.natural_surface_enabled
	var rows := {}
	for enabled in [true,false]:
		map.natural_surface_enabled = enabled
		original.natural_surface_enabled = enabled
		var reference: Dictionary = original.natural_surface_maps()
		var actual: Dictionary = map.natural_surface_maps()
		check(reference.weights.get_data() == actual.weights.get_data()
			and reference.land.get_data() == actual.land.get_data(),"identical mask bytes for %s / %s" % [label,enabled])
		for field in ["land","weights"]:
			reference.erase(field)
			actual.erase(field)
		check(reference == actual,"identical mask contract for %s / %s" % [label,enabled])
		rows["enabled" if enabled else "legacy"] = actual
	map.natural_surface_enabled = start
	original.free()
	return rows

func _sample_masks(map) -> Dictionary:
	var original = _baseline(map)
	var baseline_us: Array[int] = []
	var actual_us: Array[int] = []
	for index in range(5):
		if index%2 == 0:
			baseline_us.append(_time_mask(original))
			actual_us.append(_time_mask(map))
		else:
			actual_us.append(_time_mask(map))
			baseline_us.append(_time_mask(original))
	original.free()
	baseline_us.sort()
	actual_us.sort()
	return {"baseline_us":baseline_us,"current_us":actual_us,"baseline_median_us":baseline_us[2],
		"current_median_us":actual_us[2]}

func _time_mask(map) -> int:
	var started := Time.get_ticks_usec()
	map.natural_surface_maps()
	return Time.get_ticks_usec() - started

func _finish() -> void:
	print("SURFACE_MASK_AB_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("surface_mask_comparison")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
