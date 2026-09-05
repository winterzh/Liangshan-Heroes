extends SceneTree
## Runtime parser/scope check for CampaignEnvironmentArt.
## Prepared during the source-only phase; run only after the shared Godot
## regression process releases its exclusive engine slot.

const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
const LEVELS := ["level1","level2","level3","level4","level5","level6","level7","level8"]
const REPORT_PATH := "res://qa/environment_runtime_router_20260902/runtime_report.json"
var checks: Array = []


func _init() -> void:
	call_deferred("_run")


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	if not passed: push_error("[campaign-environment-art] %s: %s" % [name,str(detail)])


func _verify_route_table(resolver: String, table: Dictionary) -> void:
	for route_key in table:
		var record: Dictionary = table[route_key]
		var levels: Array = record.get("levels",[])
		var paths: Dictionary = record.get("paths",{})
		for state in paths:
			for level_id in LEVELS:
				var actual := EnvironmentArt.route_path(resolver,level_id,route_key,state)
				var allowed: bool = level_id in levels
				_check("%s/%s/%s/%s" % [resolver,route_key,state,level_id],
					actual==paths[state] if allowed else actual.is_empty(),actual)
		for state in paths:
			var path: String = String(paths[state])
			var expected_texture := ResourceLoader.exists(path)
			var texture: Texture2D
			match resolver:
				"object": texture=EnvironmentArt.object(String(levels[0]),route_key,state)
				"overlay": texture=EnvironmentArt.overlay(String(levels[0]),route_key)
				"static_flag": texture=EnvironmentArt.static_flag(String(levels[0]),route_key)
			_check("%s/%s/%s/resource_guard" % [resolver,route_key,state],
				(texture!=null)==expected_texture,path)
			var wrong_level := "level999"
			match resolver:
				"object": texture=EnvironmentArt.object(wrong_level,route_key,state)
				"overlay": texture=EnvironmentArt.overlay(wrong_level,route_key)
				"static_flag": texture=EnvironmentArt.static_flag(wrong_level,route_key)
			_check("%s/%s/%s/out_of_scope_null" % [resolver,route_key,state],texture==null)


func _run() -> void:
	_check("manifest_sha",EnvironmentArt.FROZEN_MANIFEST_SHA256=="162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf")
	_verify_route_table("object",EnvironmentArt.OBJECT_ROUTES)
	_verify_route_table("overlay",EnvironmentArt.OVERLAY_ROUTES)
	_verify_route_table("static_flag",EnvironmentArt.STATIC_FLAG_ROUTES)
	_check("unknown_object_path",EnvironmentArt.route_path("object","level1","town_house").is_empty())
	_check("unknown_object_null",EnvironmentArt.object("level1","town_house")==null)
	_check("unknown_overlay_null",EnvironmentArt.overlay("level1","town_house")==null)
	_check("unknown_static_flag_null",EnvironmentArt.static_flag("level5","banner")==null)
	_check("unknown_cuiyun_state",EnvironmentArt.object("level8","cuiyun_tower","unknown")==null)
	for surface_key in EnvironmentArt.SURFACE_ROUTES:
		var record: Dictionary = EnvironmentArt.SURFACE_ROUTES[surface_key]
		for level_id in LEVELS:
			var path: String = EnvironmentArt.surface_path(level_id,surface_key)
			var allowed: bool = level_id in record.get("levels",[])
			_check("surface/%s/%s/scope" % [surface_key,level_id],
				path==String(record.path) if allowed else path.is_empty(),path)
			var texture := EnvironmentArt.surface(level_id,surface_key)
			_check("surface/%s/%s/resource_guard" % [surface_key,level_id],
				(texture!=null)==(allowed and ResourceLoader.exists(String(record.path))),path)
		_check("surface/%s/unknown_level_null" % surface_key,
			EnvironmentArt.surface("level999",surface_key)==null)
	_check("unknown_surface_path",EnvironmentArt.surface_path("level1","town_house").is_empty())
	_check("unknown_surface_null",EnvironmentArt.surface("level1","town_house")==null)
	# A story-state key is not authorization to look up a global ArtDB fallback.
	var dummy := Node.new()
	dummy.set_meta("campaign_object","cuiyun_tower")
	dummy.set_meta("campaign_environment_route","cuiyun_tower")
	var campaign_scenery = load("res://scripts/campaign_scenery.gd")
	_check("campaign_scenery_runtime_load",campaign_scenery!=null)
	_check("state_fallback_story_key_rejected",campaign_scenery!=null
		and String(campaign_scenery.call("explicit_environment_fallback",dummy)).is_empty())
	dummy.set_meta("campaign_environment_fallback_key","cuiyun_tower")
	_check("state_fallback_explicit_key_reused",
		campaign_scenery!=null
		and String(campaign_scenery.call("explicit_environment_fallback",dummy))=="cuiyun_tower")
	dummy.free()
	_check("cuiyun_default_state_exact_path",
		EnvironmentArt.route_path("object","level8","cuiyun_tower","default").ends_with("cuiyun_tower_default.png"))
	_check("cuiyun_signal_state_exact_path",
		EnvironmentArt.route_path("object","level8","cuiyun_tower","signal").ends_with("cuiyun_tower_signal.png"))
	for surface_id in EnvironmentArt.TEXT_RECTS:
		_check("text_rect/%s/empty_sha" % surface_id,EnvironmentArt.text_rect(surface_id,"")==null)
		_check("text_rect/%s/wrong_sha" % surface_id,EnvironmentArt.text_rect(surface_id,"wrong-source-sha")==null)
	for surface_id in ["level5_hall_plaque","liangshan_hilltop_standard",
			"zhongyi_hall_standard_west","zhongyi_hall_standard_east"]:
		var accepted_sha := String(EnvironmentArt.TEXT_RECT_SOURCE_SHA256[surface_id])
		var measured = EnvironmentArt.text_rect(surface_id,accepted_sha)
		_check("text_rect/%s/accepted_source" % surface_id,
			measured is Array and measured.size()==4,measured)
	for resolver in EnvironmentArt.VISUAL_CALIBRATIONS:
		var calibration_table: Dictionary = EnvironmentArt.VISUAL_CALIBRATIONS[resolver]
		for route_key in calibration_table:
			var record: Dictionary = calibration_table[route_key]
			var level_id := String(record.level_id)
			var metrics := EnvironmentArt.calibrated_visual_metrics(resolver,level_id,route_key)
			_check("visual_metrics/%s/%s/accepted_source" % [resolver,route_key],
				not metrics.is_empty() and metrics.get("visible_bbox_xywh",[])==record.visible_bbox_xywh
				and float(metrics.get("foot",0.0))>0.0 and float(metrics.get("foot",0.0))<=1.0,metrics)
			_check("visual_metrics/%s/%s/out_of_scope" % [resolver,route_key],
				EnvironmentArt.calibrated_visual_metrics(resolver,"level1",route_key).is_empty())
	var passed := checks.all(func(item): return bool(item.passed))
	var report := {"passed":passed,"manifest_sha256":EnvironmentArt.FROZEN_MANIFEST_SHA256,
		"checks":checks.size(),"results":checks}
	var report_path := OS.get_environment("ENVIRONMENT_QA_REPORT")
	if report_path.is_empty(): report_path=REPORT_PATH
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print("[campaign-environment-art] %d/%d %s" % [checks.filter(func(item): return bool(item.passed)).size(),checks.size(),"PASS" if passed else "FAIL"])
	quit(0 if passed else 1)
