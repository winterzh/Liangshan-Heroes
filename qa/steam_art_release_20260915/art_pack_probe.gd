extends SceneTree
## External editor host loads the actual candidate PCK. Frozen state fixtures;
## button signals test packed bindings, not physical mouse input or natural loss.
var checks: Array = []
var failures: Array = []
var languages: Array = []
var profile_proof: Dictionary = {}

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[art-pack] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _profile_guard() -> bool:
	var profile := OS.get_environment("ART_QA_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	var environment := {}
	for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var actual := OS.get_environment(key).replace("\\", "/").simplify_path()
		environment[key] = actual
		safe = safe and actual.to_lower() == (profile + "/" + String(key).to_lower()).to_lower()
	var user_path := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	safe = safe and user_path.to_lower().begins_with((profile + "/appdata/").to_lower())
	safe = safe and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"
	safe = safe and OS.get_environment("PCK_ART_REPORT").is_absolute_path() and OS.get_environment("PCK_ART_PACK").is_absolute_path() and OS.get_environment("PCK_ART_PACK_SHA").length() == 64
	profile_proof = {"passed": safe, "profile": profile, "environment": environment, "user_data_dir": user_path}
	return safe

func _run() -> void:
	if not _profile_guard(): quit(2); return
	await process_frame
	var art = root.get_node("Art")
	var environment = load("res://scripts/campaign_environment_art.gd")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("environment.json")))
	for row in manifest.resources:
		var state: String = row.get("state","default")
		for level in row.levels:
			var tex = environment.object(level,row.key,state) if row.resolver=="object" else environment.overlay(level,row.key)
			check(tex is AtlasTexture and tex.get_width()>0,"packed atlas "+row.key+state+level)
		check(environment.object("skirmish",row.key,state)==null and environment.overlay("skirmish",row.key)==null,"scoped atlas "+row.key)
	check(environment.calibrated_text_rect("object","level7","heyang_wine_sign","default","level7_heyang_wine_sign") != null,"packed wine cloth calibration survives export")
	if not environment._atlas_pixel_hashes.is_empty(): print("IMPORTED_PIXEL_SHA ",environment._atlas_pixel_hashes.values()[0].sha256)
	var atlas_path := "res://assets/campaign/environment/level7/heyang_wine_sign_blank.tres"
	var sign = environment.object("level7","heyang_wine_sign")
	var record: Dictionary = environment.ATLAS_TEXT_CALIBRATIONS["level7_heyang_wine_sign"].duplicate(true)
	var changed: AtlasTexture = sign.duplicate()
	changed.region.position.x += 1
	check(not environment._atlas_calibration_matches(atlas_path,changed,record),"changed atlas region rejects calibration")
	changed = sign.duplicate()
	changed.margin.position.x += 1
	check(not environment._atlas_calibration_matches(atlas_path,changed,record),"changed canvas margin rejects calibration")
	record.source_sha256 = "invalid"
	record.imported_pixel_sha256 = "invalid"
	check(not environment._atlas_calibration_matches(atlas_path,sign,record),"changed source identity rejects calibration")
	for key in ["dong_chao","xue_ba"]:
		check(art.avatar_texture(key,key+"_escort") != null,"packed portrait "+key)
		for direction in ["se","sw","ne","nw"]:
			for state in ["idle","walk"]:
				check(art.unit_anim_frames(key,state,direction).size()==(1 if state=="idle" else 4),"packed escort "+key+state+direction)
	for direction in ["se","sw","ne","nw"]:
		check(art.unit_texture("guan_zhanchuan","",direction)!=null,"packed warship "+direction)
		for state in ["idle","walk","attack","hurt","death"]:
			check(not art.unit_anim_frames("guan_zhanzi",state,direction).is_empty(),"packed executioner "+state+direction)
	var camera = load("res://scripts/rts_camera.gd").new()
	root.add_child(camera)
	camera.touch_mode = true
	camera._unhandled_input(InputEventMouseMotion.new())
	check(not camera.touch_mode,"packed mouse activity exits touch mode")
	camera.queue_free()
	var settings = root.get_node("Settings")
	var settings_path: String = "user://settings.cfg"
	var before: String = FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "absent"
	settings.save()
	var after: String = FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "absent"
	check(before==after,"packed QA settings guard preserves disk")
	for name in ["Sfx","Music"]:
		var singleton = root.get_node_or_null(name)
		if singleton != null and singleton.has_method("shutdown"): singleton.shutdown()
	var report := {"schema":"art_pck_probe_v1","complete":true,"passed":failures.is_empty(),"checks":checks,"failures":failures,"private_profile":profile_proof,"pid":OS.get_process_id(),"pack":OS.get_environment("PCK_ART_PACK"),"pack_sha256":OS.get_environment("PCK_ART_PACK_SHA"),"scope":"Editor host mounts actual release PCK; resource, calibration and input callback checks. No physical mouse or human playtest."}
	FileAccess.open(OS.get_environment("PCK_ART_REPORT"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
