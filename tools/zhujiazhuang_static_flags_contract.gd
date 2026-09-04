extends SceneTree
## Level 3 integration and isolation contract for the Chapter 48 gate standards.
## It loads the real level and scenery renderer; it does not alter PNG assets,
## complete the campaign, benchmark performance, or stand in for visual review.

const CampaignArt := preload("res://scripts/campaign_art.gd")

const EXPECTED := {
	"zhujiazhuang_gate_chao_standard": {
		"cell": Vector2i(10, 26), "text": "填平水泊擒晁盖",
	},
	"zhujiazhuang_gate_song_standard": {
		"cell": Vector2i(14, 30), "text": "踏破梁山捉宋江",
	},
}

var checks: Array = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail := "") -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[zhujiazhuang-static-flags] ", "PASS " if passed else "FAIL ", name, " ", detail)
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
	campaign.current = campaign.index_for_id("level3")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	await process_frame
	_check("level3_loaded", battle.level != null and battle.level.id() == "level3")
	for marker in EXPECTED:
		var expected: Dictionary = EXPECTED[marker]
		var records := _decor_records(battle.map, marker)
		_check(marker + "_is_one_authored_level3_banner", records.size() == 1
			and String(records[0][0]) == "banner" and records[0][1] == expected.cell
			and is_equal_approx(float(records[0][2]), 144.0), JSON.stringify(records))
		var route := CampaignArt.static_flag_route(marker, "level3", "banner")
		_check(marker + "_uses_exact_chapter48_text", String(route.get("overlay_id", "")) == marker
			and String(CampaignArt.flag_text_spec(marker).get("text", "")) == expected.text
			and String(CampaignArt.flag_text_spec(marker).get("chapter", "")) == "第四十八回")
		_check(marker + "_rejects_other_modes_and_decor", CampaignArt.static_flag_route(marker, "level5", "banner").is_empty()
			and CampaignArt.static_flag_route(marker, "arena", "banner").is_empty()
			and CampaignArt.static_flag_route(marker, "level3", "tower").is_empty())
	_check("generic_banner_remains_unlettered", CampaignArt.static_flag_overlay_id("banner").is_empty()
		and CampaignArt.static_flag_route("banner", "level3", "banner").is_empty())
	_check("level5_standards_cannot_render_in_level3",
		CampaignArt.static_flag_route("liangshan_hilltop_standard", "level3", "banner").is_empty()
		and CampaignArt.static_flag_route("zhongyi_hall_standard_west", "level3", "banner").is_empty()
		and CampaignArt.static_flag_route("zhongyi_hall_standard_east", "level3", "banner").is_empty())
	var scenery = battle.map.sample_scenery
	_check("level3_campaign_scenery_loaded", scenery != null)
	var art = root.get_node_or_null("Art")
	_check("generic_banner_texture_available", art != null and art.terrain_texture("banner") != null)
	var rendered: Dictionary = {}
	var base_flag_sprites: Dictionary = {}
	var nodes_at_flag_cells: Dictionary = {}
	if scenery != null:
		for child in scenery.get_children():
			for marker in EXPECTED:
				var expected_position: Vector2 = battle.map.cell_to_world(EXPECTED[marker].cell)
				if child is Node2D and child.position.distance_to(expected_position) < 0.1:
					nodes_at_flag_cells[marker] = int(nodes_at_flag_cells.get(marker, 0)) + 1
			if child.has_meta("campaign_environment_static_flag"):
				var base_marker := String(child.get_meta("campaign_environment_static_flag"))
				base_flag_sprites[base_marker] = int(base_flag_sprites.get(base_marker, 0)) + 1
			if child.has_method("static_marker"):
				var marker := String(child.static_marker())
				if not marker.is_empty():
					rendered[marker] = int(rendered.get(marker, 0)) + 1
					if marker in EXPECTED:
						_check(marker + "_runtime_overlay_id_exact", child.has_method("overlay_id")
							and String(child.overlay_id()) == marker)
	for marker in EXPECTED:
		_check(marker + "_renders_once_in_real_level3_scenery", int(rendered.get(marker, 0)) == 1,
			JSON.stringify(rendered))
	_check("real_level3_has_only_the_two_scoped_text_overlays", rendered.size() == 2,
		JSON.stringify({"rendered": rendered, "base_flag_sprites": base_flag_sprites,
			"nodes_at_flag_cells": nodes_at_flag_cells}))
	var report_path := OS.get_environment("ZHUJIAZHUANG_STATIC_FLAGS_REPORT")
	if report_path.is_empty():
		report_path = "res://qa/zhujiazhuang_static_flags_20260902/runtime_contract.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	_check("report_opened", file != null, report_path)
	if file != null:
		file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks,
			"rendered_markers": rendered, "base_flag_sprites": base_flag_sprites,
			"nodes_at_flag_cells": nodes_at_flag_cells,
			"scope": "real level3 static flag routing and cross-mode isolation"}, "\t") + "\n")
		file.close()
	_stop_audio()
	if is_instance_valid(battle):
		battle.queue_free()
	await process_frame
	print("[zhujiazhuang-static-flags-result] ", JSON.stringify({"passed": failures.is_empty(),
		"checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 5)
