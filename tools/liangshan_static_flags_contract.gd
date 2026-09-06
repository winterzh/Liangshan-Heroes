extends SceneTree
## Level 5 integration contract for the three fixed original-text standards.
## This checks authored map placement and scoped renderer nodes; it is not a
## substitute for screenshots, campaign completion, or human playtesting.

const CampaignArt := preload("res://scripts/campaign_art.gd")

var checks: Array = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail := "") -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[liangshan-static-flags] ", "PASS " if passed else "FAIL ", name, " ", detail)
	if not passed:
		failures.append(name)


func _stop_audio() -> void:
	for autoload_name in ["Sfx", "Music"]:
		var audio_root = root.get_node_or_null(autoload_name)
		if audio_root == null:
			continue
		audio_root.set("enabled", false)
		for child in audio_root.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null


func _decor_records(map, marker: String) -> Array:
	return map.decor.filter(func(record): return record.size() > 3 and String(record[3]) == marker)


func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	_stop_audio()
	var campaign = root.get_node_or_null("Campaign")
	_check("campaign_autoload_available", campaign != null)
	if campaign == null:
		quit(5)
		return
	for key in ["arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]:
		campaign.set(key, false)
	campaign.current = campaign.index_for_id("level5")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	await process_frame
	_check("level5_loaded", battle.level != null and battle.level.id() == "level5")
	var expected := {
		"liangshan_hilltop_standard": Vector2i(10, 15),
		"zhongyi_hall_standard_west": Vector2i(14, 33),
		"zhongyi_hall_standard_east": Vector2i(18, 33),
	}
	for marker in expected:
		var records := _decor_records(battle.map, marker)
		_check(marker + "_is_one_level5_banner", records.size() == 1
			and String(records[0][0]) == "banner" and records[0][1] == expected[marker], JSON.stringify(records))
		_check(marker + "_has_level5_banner_route",
			not CampaignArt.static_flag_route(marker, "level5", "banner").is_empty())
	# The level owns the terrain enum. Keep this fixture free of a GameMap static
	# reference so direct --script loading does not compile GameMap before autoloads.
	_check("hilltop_standard_has_elevated_render_position", battle.map.height_at(battle.map.cell_to_world(Vector2i(10, 15))) > 0.0,
		str(battle.map.height_at(battle.map.cell_to_world(Vector2i(10, 15)))))
	var scenery = battle.map.sample_scenery
	_check("liangshan_scenery_loaded", scenery != null)
	var rendered_markers: Dictionary = {}
	if scenery != null:
		for child in scenery.get_children():
			if child.has_method("static_marker"):
				var marker := String(child.static_marker())
				if not marker.is_empty():
					rendered_markers[marker] = int(rendered_markers.get(marker, 0)) + 1
	for marker in expected:
		_check(marker + "_renders_once_in_real_level5_scenery", int(rendered_markers.get(marker, 0)) == 1,
			JSON.stringify(rendered_markers))
	var report_path := OS.get_environment("LIANGSHAN_STATIC_FLAGS_REPORT")
	if report_path.is_empty():
		report_path = "res://qa/direction4_20260901/liangshan_static_flags_contract.json"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	_check("report_opened", file != null, report_path)
	if file != null:
		file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks,
			"rendered_markers": rendered_markers}, "\t") + "\n")
		file.close()
	_stop_audio()
	if is_instance_valid(battle):
		battle.queue_free()
	await process_frame
	print("[liangshan-static-flags-result] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 5)
