extends "res://tools/zhujiazhuang_rts_test.gd"
## Fresh-process rendered statistical baseline. Not a deterministic combat replay.
## POLISH_CASE=economy|defense200|zhu_contact|gao_contact, POLISH_CAMERA=fixed|auto.
## Runner owns repetitions and source/environment receipts. No production mutation.
const CASES := ["economy", "defense200", "zhu_contact", "gao_contact"]
const WARMUP_TICKS := 300
var scenario := ""
var camera_mode := "fixed"
var seconds := 60.0
var physics_tick := 0
var trajectory: Array = []
var input_log: Array = []
var camera_origin := Vector2.ZERO
var frozen_camera := false
var camera_violations := 0
var fixture_units: Array = []
var battle_ref
var prior_hp := {}
var damage_observed := [0.0,0.0,0.0,0.0] # player land, enemy land, player water, enemy water
var autocam_active_ticks := 0
var manual_camera_ticks := 0
var configured_settings := {}

class TickDriver extends Node:
	var owner_probe
	func _physics_process(_delta: float) -> void: owner_probe._on_tick()

func _prefs_hash() -> Dictionary:
	var result := {}
	for path in ["user://campaign.cfg", "user://settings.cfg"]:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result

func _state(b) -> Dictionary:
	var count := [0,0]; var hp := [0.0,0.0]; var water := [0,0]
	var moving := [0,0]; var fighting := [0,0]
	for u in b.units:
		if not alive(u) or u.is_resource or u.faction not in [0,1]: continue
		var f: int = u.faction
		count[f] += 1; hp[f] += u.hp
		if u.movement_profile == "water": water[f] += 1
		if u._state in [u.ST_MOVE,u.ST_AMOVE,u.ST_CHASE]: moving[f] += 1
		if is_instance_valid(u._target) and u._cd > 0.0: fighting[f] += 1
	return {"tick":physics_tick,"phase":b.phase,"count":count,"hp":hp,"water":water,
		"moving":moving,"fighting":fighting,"gold":b.gold,"wood":b.wood,"kills":b.kills,
		"mission_stage":b.mission.stage_id if b.mission != null else "",
		"camera_position":[b.camera.position.x,b.camera.position.y],
		"camera_zoom":[b.camera.zoom.x,b.camera.zoom.y]}

func _amove(units: Array, pos: Vector2, label: String) -> void:
	var issued := []
	for u in units:
		if alive(u) and not u.is_building and not u.is_resource:
			u.order_amove(pos); issued.append(u.key)
	input_log.append({"planned_tick":1,"executed_tick":physics_tick,"action":label,
		"units":issued,"destination":[pos.x,pos.y]})

func _on_tick() -> void:
	if not is_instance_valid(battle_ref): return
	physics_tick += 1
	var b = battle_ref
	if physics_tick == 1:
		if scenario == "economy":
			var issued := []
			for u in b.units:
				if not alive(u) or u.faction != 0 or not u.is_worker: continue
				var resource = b.nearest_resource(u.position,"gold" if issued.size()%2 == 0 else "wood")
				if resource != null: u.order_gather(resource); issued.append(u.key)
			input_log.append({"planned_tick":1,"executed_tick":physics_tick,"action":"initial worker gather orders","units":issued})
		elif scenario == "zhu_contact":
			_amove(fixture_units,b.level.gate.position,"synthetic deployed army attacks native main gate")
		elif scenario == "gao_contact":
			_amove(b.units.filter(func(u):return alive(u) and u.faction==0 and u.movement_profile=="water"),b.map.cell_to_world(b.level.SEA_FRONT),"native player ships advance")
			_amove(b.units.filter(func(u):return alive(u) and u.faction==0 and not u.is_worker and not u.is_noncombat and u.movement_profile!="water"),b.map.cell_to_world(b.level.LAND_FRONT),"native player land army advances")
			b.level._send_wave(b,0)
			input_log.append({"planned_tick":1,"executed_tick":physics_tick,"action":"authored fixture: send existing first land/water wave early"})
	if frozen_camera and (b.camera.position != camera_origin or b.camera.zoom != Vector2.ONE or b.camera.offset != Vector2.ZERO or b.camera.rotation != 0.0):
		camera_violations += 1
	if b._autocam_active: autocam_active_ticks += 1
	if camera_mode == "auto" and b.camera.user_controlling(): manual_camera_ticks += 1
	if physics_tick % 60 == 0:
		for u in b.units:
			if not alive(u) or u.is_resource or u.faction not in [0,1]: continue
			var ident: int = u.get_instance_id()
			if prior_hp.has(ident):
				damage_observed[u.faction+(2 if u.movement_profile=="water" else 0)] += maxf(0.0,float(prior_hp[ident])-u.hp)
			prior_hp[ident] = u.hp
		var state := _state(b); state["sampled_damage_observed"] = damage_observed.duplicate()
		trajectory.append(state)

func _configure_settings() -> void:
	var settings = root.get_node("Settings")
	for pair in [["game_speed",1.0],["atmosphere",true],["auto_micro_level",0],["formation_mode","loose"],
		["bgm",0.8],["sfx",0.9],["muted",true],["cam_speed",1.0],["zoom_sens",1.0],
		["edge_scroll",false],["show_damage",true],["show_healthbars",true],["show_cooldown",true],
		["show_command_queue",true],["show_target_lines",true],["show_range_rings",true],["show_control_help",false]]:
		settings.set(pair[0],pair[1])
		configured_settings[pair[0]] = pair[1]
	settings.keybinds = settings.DEFAULT_KEYBINDS.duplicate()
	settings.apply_audio()
	AudioServer.set_bus_mute(0,true) # Keep audio generation and its RNG; mute is not disable.
	root.gui_disable_input = true
	root.size = Vector2i(1440,900)
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0; Engine.time_scale = 1.0

func _new_battle():
	var camp = root.get_node("Campaign")
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: camp.set(key,false)
	camp.defense_waves = 30; camp.defense_hero_cap = 4; camp.defense_random = false
	camp.enemy_mult = 1.0; camp.hero_mult = 1.0; camp.hero_mult_touched = false
	camp.ai_difficulty = "normal"; camp.victory_mode = "conquest"
	camp.current = 2 if scenario == "zhu_contact" else (4 if scenario == "gao_contact" else 0)
	if scenario in ["economy","defense200"]: camp.skirmish = true
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(b); current_scene = b
	await process_frame
	b.hud._intro_root.hide(); b._on_intro_done(); b._on_start_battle()
	seed(5088120) # Explicit fixture-generation origin after scene initialization.
	if scenario == "defense200": b._perf_bench_setup(200)
	if scenario == "zhu_contact":
		# Controlled congestion fixture; not a paid-production/balance/playthrough test.
		for i in range(72):
			var cell: Vector2i = b.level.MAIN_GATE + Vector2i(i%9-4,4+i/9)
			cell = b.map.nearest_open(cell)
			fixture_units.append(b.spawn_unit(["liang_dao","liang_qiang","liang_gong"][i%3],0,b.map.cell_to_world(cell)))
		for i in range(4):
			var cell: Vector2i = b.map.nearest_open(b.level.MAIN_GATE+Vector2i(i*2-3,13))
			fixture_units.append(b.spawn_unit("siege_ram",0,b.map.cell_to_world(cell)))
	b._prof_on = false
	await process_frame # Complete queued fixture-node deletion before simulation starts.
	b._grid_build()
	b.camera.zoom = Vector2.ONE; b.camera.rotation = 0.0; b.camera.offset = Vector2.ZERO; b.camera._shake = 0.0
	var cell: Vector2i = b.level.camera_start_cell()
	if scenario == "zhu_contact": cell = b.level.MAIN_GATE
	elif scenario == "gao_contact": cell = b.level.SEA_FRONT
	b.center_camera_cell(cell); camera_origin = b.camera.position
	b.camera.set_process_unhandled_input(false)
	if camera_mode == "fixed":
		b.camera.set_process(false)
		b.camera._user_input_t = 1e12; frozen_camera = true
	else:
		b.camera._user_input_t = 0.0
		b._autocam_enabled = true
	b.camera.force_update_scroll()
	b.set_process_input(false); b.set_process_unhandled_input(false)
	return b

func _percentile(values: Array, q: float) -> float:
	if values.is_empty(): return 0.0
	var sorted = values.duplicate(); sorted.sort()
	return float(sorted[clampi(ceili(sorted.size()*q)-1,0,sorted.size()-1)])

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	scenario = OS.get_environment("POLISH_CASE")
	camera_mode = OS.get_environment("POLISH_CAMERA")
	if camera_mode.is_empty(): camera_mode = "fixed"
	if not OS.get_environment("POLISH_SECONDS").is_empty(): seconds = float(OS.get_environment("POLISH_SECONDS"))
	if DisplayServer.get_name()=="headless" or scenario not in CASES or camera_mode not in ["fixed","auto"] or seconds<1.0:
		push_error("Rendered valid POLISH_CASE/POLISH_CAMERA/POLISH_SECONDS required"); quit(2); return
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--fixed-fps"): push_error("Fixed-fps is not a live performance sample"); quit(2); return
	var prefs_before := _prefs_hash()
	_configure_settings()
	var music = root.get_node("Music")
	var audio_started := Time.get_ticks_usec()
	while Time.get_ticks_usec()-audio_started < 60000000 and (music._thr != null and music._thr.is_alive() or music._tracks.calm.size()<4 or music._tracks.battle.size()<4):
		await process_frame
	var audio_ready: bool = (music._thr == null or not music._thr.is_alive()) and music._tracks.calm.size()==4 and music._tracks.battle.size()==4
	check(audio_ready,"background music synthesis finished before battle setup")
	check(Engine.physics_ticks_per_second==60,"production 60Hz physics configuration")
	var b = await _new_battle(); battle_ref = b
	var initial_units := []
	for u in b.units:
		if is_instance_valid(u): initial_units.append([u.key,u.faction,u.position.x,u.position.y,u.hp,u.movement_profile])
	var initial_state := _state(b)
	var tick_driver := TickDriver.new(); tick_driver.owner_probe = self; tick_driver.process_physics_priority = -10000
	root.add_child(tick_driver)
	var warm_start := Time.get_ticks_usec()
	b.process_mode = Node.PROCESS_MODE_INHERIT
	while physics_tick < WARMUP_TICKS and b.phase == b.Phase.FIGHT: await process_frame
	var warm_end_tick := physics_tick
	var warm_wall := float(Time.get_ticks_usec()-warm_start)/1000000.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await RenderingServer.frame_post_draw
	var started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick
	var raw := []; var process_ms := []; var physics_ms := []; var gpu_ms := []; var render_cpu_ms := []; var draws := []
	var sample_start := _state(b)
	var autocam_start := autocam_active_ticks
	var damage_start := damage_observed.duplicate()
	while float(Time.get_ticks_usec()-started)/1000000.0 < seconds and b.phase == b.Phase.FIGHT:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		raw.append(float(now-previous)/1000.0); previous = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var elapsed := float(Time.get_ticks_usec()-started)/1000000.0
	var end_state := _state(b)
	var complete: bool = elapsed >= seconds and b.phase == b.Phase.FIGHT and not raw.is_empty()
	check(camera_violations==0,"fixed camera transform has no drift")
	check(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"unmodified simulation speed and frequency")
	check(not input_log.is_empty() or scenario=="defense200","planned scenario input was issued")
	var contact_covered := true
	if scenario in ["defense200","zhu_contact"]: contact_covered = damage_observed[0]+damage_observed[1]>damage_start[0]+damage_start[1]
	elif scenario == "gao_contact":
		contact_covered = damage_observed[0]+damage_observed[1]>damage_start[0]+damage_start[1] and damage_observed[2]+damage_observed[3]>damage_start[2]+damage_start[3]
	if seconds >= 60.0: check(contact_covered,"requested land/water combat actually occurred in sample")
	if camera_mode == "auto":
		check(autocam_active_ticks>autocam_start,"automatic camera actually active during sample")
		check(manual_camera_ticks==0,"automatic camera has no manual keyboard takeover")
	var report := {"schema":1,"scenario":scenario,"camera_mode":camera_mode,"requested_seconds":seconds,
		"seed":5088120,"reproducibility":"fixed_seed_fixed_tick_inputs_statistical_not_exact_replay",
		"known_variance_sources":["audio wall-clock global RNG","render-frame Li Kui axe damage"],
		"audio_policy":"normal synthesis completed before battle, playback logic active; master muted only","audio_ready":audio_ready,
		"configured_settings":configured_settings,"keybinds":"production defaults",
		"fixture_kind":"native economy" if scenario=="economy" else "explicit combat workload fixture, not a chapter playthrough",
		"initial_units":initial_units,"initial_state":initial_state,"sample_start":sample_start,"sample_end":end_state,
		"warmup_target_ticks":WARMUP_TICKS,"warmup_end_tick":warm_end_tick,"warmup_wall_seconds":warm_wall,
		"seconds":elapsed,"frames":raw.size(),"fps":raw.size()/elapsed if elapsed>0 else 0.0,
		"p95_ms":_percentile(raw,0.95),"p99_ms":_percentile(raw,0.99),"worst_ms":raw.max() if not raw.is_empty() else null,
		"physics_ticks":physics_tick-start_tick,"simulated_seconds":float(physics_tick-start_tick)/60.0,
		"raw_frame_ms":raw,"process_monitor_ms":process_ms,"physics_monitor_ms":physics_ms,
		"render_cpu_ms":render_cpu_ms,"gpu_ms":gpu_ms if gpu_ms.any(func(x):return x>0.0) else null,"draw_calls":draws,
		"trajectory":trajectory,"inputs":input_log,"camera_violations":camera_violations,
		"sampled_damage_at_start":damage_start,"sampled_damage_at_end":damage_observed,"contact_covered":contact_covered,"autocam_active_ticks":autocam_active_ticks,
		"sample_autocam_active_ticks":autocam_active_ticks-autocam_start,"manual_camera_ticks":manual_camera_ticks,
		"sample_complete":complete,"incomplete_reason":"" if complete else "battle ended or sample shorter than requested",
		"acceptance_eligible":complete and seconds>=60.0,"time_scale":Engine.time_scale,
		"physics_hz":Engine.physics_ticks_per_second,"resolution":[root.size.x,root.size.y],
		"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info().string}
	var output: String = OS.get_environment("POLISH_OUT")
	if output.is_empty(): output = "res://.godot/polish_performance_report.json"
	var shot: String = output.get_basename()+".png"
	report["screenshot_saved"] = root.get_texture().get_image().save_png(shot)==OK
	tick_driver.queue_free(); battle_ref = null; fixture_units.clear()
	var weak = weakref(b)
	await _dispose(b)
	check(weak.get_ref()==null,"sample battle actually freed")
	check(_prefs_hash()==prefs_before,"player campaign and settings files unchanged")
	report["checks"] = checks; report["failures"] = failures; report["integrity_passed"] = failures.is_empty()
	report.acceptance_eligible = report.acceptance_eligible and failures.is_empty()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[polish-performance] ",JSON.stringify({"scenario":scenario,"camera":camera_mode,"complete":complete,"seconds":elapsed,"fps":report.fps,"p95_ms":report.p95_ms,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() and complete else 1)
