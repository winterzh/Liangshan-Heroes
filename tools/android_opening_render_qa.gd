extends SceneTree
## Real rendered, frozen opening fixture for static-scenery A/B and visual review.
## Not Android device FPS. Run in a private project prepared by run_rts_refinement_qa.py.
## LSH_STATIC_SCENERY_BATCH=0 selects the retained legacy path; default is batched.
var battle
var view: SubViewport
var output := ""
var samples: Array = []
var captures: Array = []
var baseline := false
var physical := Vector2i(3000, 1876)


func _initialize() -> void:
	_run.call_deferred()


func _freeze(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children(): _freeze(child)


func _run() -> void:
	output = OS.get_environment("LSH_RTS_QA_OUT").simplify_path().trim_suffix("/")
	var expected := OS.get_environment("LSH_RTS_QA_PROJECT").simplify_path().trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var profile := OS.get_user_data_dir().simplify_path().trim_suffix("/")
	if expected.is_empty() or expected != project or output.is_empty() or not output.is_absolute_path() \
		or output == project or output.begins_with(project + "/") \
		or profile != OS.get_environment("LSH_RTS_QA_PROFILE").simplify_path().trim_suffix("/") \
		or not profile.get_file().begins_with("LSH-rts-") or output == profile or output.begins_with(profile + "/") \
		or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1" \
		or OS.get_environment("CONTENT_UPDATE_NO_AUTO") != "1" or DisplayServer.get_name() == "headless":
		push_error("Private project/profile and graphical renderer required")
		quit(2)
		return
	if FileAccess.file_exists(output.path_join("opening-render.json")):
		push_error("Fresh output required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	baseline = OS.get_environment("LSH_STATIC_SCENERY_BATCH") == "0"
	if OS.get_environment("LSH_ANDROID_RENDER_SIZE") == "3840x2560": physical = Vector2i(3840, 2560)
	var scale := minf(float(physical.x) / 1280.0, float(physical.y) / 720.0)
	var logical := Vector2i(roundi(physical.x / scale), roundi(physical.y / scale))
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.game_speed = 1.0
	settings.atmosphere = false # Matches the production mobile atmosphere gate.
	settings.effects_quality = "standard"
	var camp = root.get_node("Campaign")
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		camp.set(key, false)
	camp.skirmish = true
	camp.defense_waves = 60
	camp.defense_hero_cap = 6
	camp.defense_random = false
	camp.hero_mult = 1.0
	camp.enemy_mult = 1.0
	view = SubViewport.new()
	view.size = physical
	view.size_2d_override = logical
	view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	battle = load("res://scenes/main.tscn").instantiate()
	var identity: Dictionary = load("res://scripts/run_content_identity.gd").new().resolve_runtime_identity()
	var rng: Dictionary = battle.configure_new_gameplay_rng(identity, 5088120)
	if not rng.get("ok", false):
		push_error("Fixed gameplay RNG configuration failed")
		quit(2)
		return
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	view.add_child(battle)
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud.set_touch_ui(true)
	settings.auto_micro_level = 2
	battle.camera.zoom = Vector2.ONE
	battle.center_camera_cell(battle.level.camera_start_cell())
	battle.camera.force_update_scroll()
	_freeze(battle)
	await _settle()
	await _capture("opening_no_heroes")
	var keys := ["song_jiang", "hua_rong", "lin_chong", "gongsun_sheng", "li_kui", "wu_song"]
	for i in keys.size():
		var hero = battle.spawn_at(keys[i], 0, battle.map.nearest_open(Vector2i(25 + i % 3, 33 + i / 3)))
		if hero == null:
			push_error("Missing fixture hero")
			quit(2)
			return
	battle.select_single(battle.liang_heroes()[0], false)
	battle.hud._process(0.3)
	battle._grid_build()
	battle._fog_pass(1.0)
	battle.map.sample_scenery._process(0.2)
	_freeze(battle)
	await _settle()
	await _capture("opening_six_heroes")
	for repeat in range(2): await _sample("opening_six_heroes", repeat)
	# Reveal only for the geometry/alpha visual fixture. It is not a gameplay change.
	battle.fog = false
	if is_instance_valid(battle._fog_layer): battle._fog_layer.hide()
	battle.map.sample_scenery._process(0.2)
	battle.map.sample_scenery._entrance._process(0.2)
	battle.camera.zoom = Vector2(0.6, 0.6)
	battle.center_camera_cell(Vector2i(29, 31))
	battle.camera.force_update_scroll()
	await _settle()
	await _capture("whole_terrace")
	for repeat in range(2): await _sample("whole_terrace", repeat)
	var report := {"passed": battle.gameplay_rng_fault().is_empty(), "baseline": baseline,
		"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "physical": str(physical), "logical": str(logical),
		"native_android": false, "fixture": "frozen production defense opening, independent RNG seed 5088120, six heroes",
		"limitations": ["Host rendering diagnostic; not Android present, power or temperature acceptance.",
			"Frozen simulation, not a 60-wave playthrough; frame rates do not represent live combat.",
			"Rendering CPU may include driver waits; zero GPU timing is unavailable, not zero cost."],
		"samples": samples, "captures": captures}
	var bank: Dictionary = battle.map.sample_scenery.static_bank_batch_summary()
	var terrace: Dictionary = battle.map.sample_scenery._entrance.static_terrace_batch_summary()
	report["batches"] = {"bank": bank, "terrace": terrace}
	if not baseline:
		report.passed = report.passed and bank.get("valid", false) and terrace.get("valid", false) \
			and int(bank.get("draw_submissions", 0)) > 0 and int(terrace.get("draw_submissions", 0)) > 0
	report.passed = report.passed and captures.all(func(entry): return entry.written) and samples.size() == 4
	FileAccess.open(output.path_join("opening-render.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("[android-opening-render-result] ", JSON.stringify({"passed": report.passed, "samples": samples.size(), "captures": captures.size(), "baseline": baseline}))
	battle.free()
	view.queue_free()
	await process_frame
	quit(0 if report.passed else 1)


func _settle() -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	await create_timer(2.0).timeout


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var error := view.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK: push_error("Screenshot write failed: " + label)
	captures.append({"name": label, "written": error == OK,
		"fps_rect": str(battle.hud._fps_label.get_global_rect()), "rail_rect": str(battle.hud._skill_rail.get_global_rect()),
		"top_rect": str(battle.hud.top_label.get_global_rect()), "heroes": battle.liang_heroes().size()})


func _sample(label: String, repeat: int) -> void:
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var start := Time.get_ticks_usec()
	var previous := start
	var intervals: Array[float] = []
	var draws := 0.0
	var render_cpu := 0.0
	var render_gpu := 0.0
	while Time.get_ticks_usec() - start < 5000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	var sorted := intervals.duplicate()
	sorted.sort()
	var row := {"case": label, "repeat": repeat, "frames": intervals.size(), "wall_seconds": elapsed,
		"fps": intervals.size() / elapsed, "p95_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"p99_ms": sorted[ceili(sorted.size() * 0.99) - 1], "draw_calls": draws / intervals.size(),
		"render_cpu_ms": render_cpu / intervals.size(), "render_gpu_ms": render_gpu / intervals.size(),
		"raw_frame_ms": intervals, "unit_count": battle.units.size(), "hero_count": battle.liang_heroes().size()}
	samples.append(row)
	var summary := row.duplicate()
	summary.erase("raw_frame_ms")
	print("[android-opening-render-sample] ", JSON.stringify(summary))
