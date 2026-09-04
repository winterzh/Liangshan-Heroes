extends SceneTree
## Focused gameplay fixtures for the no-damage road drill and two distinct
## readable boss tells. The normal early-episode playthrough remains the source
## for the unmodified full duel and non-lethal chapter result.

const CA := preload("res://scripts/campaign_art.gd")

var failures: Array[String] = []
var checks := 0
var evidence: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("[kuaihuolin-depth] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _start():
	seed(5088120)
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == "level7":
			campaign.current = i
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b._smoke = true
	Engine.time_scale = 4.0
	return b

func _to_showdown(b, limit := 6000) -> bool:
	var frames := 0
	while b.level.st != b.level.SHOWDOWN and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	b._smoke = false
	if b.level.st == b.level.SHOWDOWN:
		b.level.wu.order_stop()
		b.level.menshen.order_stop()
		b.level.wu.set_physics_process(false)
		b.level.menshen.set_physics_process(false)
	return b.level.st == b.level.SHOWDOWN and b.phase != b.Phase.END

func _place(b, u, position: Vector2) -> void:
	u.position = position
	b.map.sync_render_position(u)

func _frame_source(frame: Texture2D) -> String:
	if frame is AtlasTexture and frame.atlas != null:
		return frame.atlas.resource_path
	return frame.resource_path if frame != null else ""

func _menshen_story_pose_source(l) -> String:
	var art = root.get_node("Art")
	var idle: Array = art.unit_anim_frames("jiang_menshen", "idle", l.menshen.animation_direction, l.menshen.art_variant)
	if idle.is_empty():
		return ""
	return _frame_source(l.menshen._anim_frame_for_state(idle[0]))

func _dispose(b) -> void:
	evidence.append({
		"events": b.mission.events.keys(),
		"heavy_dodges": b.level.heavy_dodges,
		"rush_dodges": b.level.rush_dodges,
		"game_seconds": b.mission.total_game_seconds,
	})
	b.queue_free()
	await process_frame
	await process_frame

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)

	var b = await _start()
	check(await _to_showdown(b), "normal tavern route reaches the duel")
	var l = b.level
	check(b.mission.has_event("road_step_practiced"), "the second tavern inserts one real footwork drill")
	check(b.mission.events.keys().find("road_step_practiced") < b.mission.events.keys().find("provoke"), "footwork is taught before the hotel provocation")
	check(l.drunk == 4 and l.wu.hp > 0.0, "road drill does no damage and preserves four authored taverns")
	check(l.menshen._damage_reduction_sources.has(l.BRACE_SOURCE), "Menshen begins braced instead of receiving extra health")

	# Heavy punch: a circular ground marker, escaped by leaving that point.
	_place(b, l.menshen, Vector2(1000, 700))
	_place(b, l.wu, Vector2(1080, 700))
	l.fist_cd = 0.0
	l.process(b, 0.01)
	check(l.fist_windup > 0.0 and l.special_kind == "heavy", "first special is the circular heavy-punch tell")
	check(l.menshen.get_meta("story_pose", "") == "windup"
		and _menshen_story_pose_source(l) == CA.animation_path("jiang_menshen_fists", "attack", l.menshen.animation_direction),
		"heavy windup uses the exact four-direction campaign attack start")
	check(is_instance_valid(l.fist_marker) and l.fist_marker.get_meta("tell_kind", "") == "heavy", "heavy tell uses a circular world marker")
	_place(b, l.wu, l.fist_at + Vector2(0, 130))
	l.process(b, l.fist_windup + 0.05)
	check(l.heavy_dodges == 1 and b.mission.has_event("dodge_heavy"), "leaving the circle creates a heavy-punch counter window")
	check(not l.menshen._damage_reduction_sources.has(l.BRACE_SOURCE) and l.exposed_left > 0.0, "a clean heavy dodge temporarily opens the boss guard")

	# Let that window expire without allowing the next special to auto-start.
	l.fist_cd = 99.0
	l.process(b, l.exposed_left + 0.05)
	check(l.menshen._damage_reduction_sources.has(l.BRACE_SOURCE), "brace returns after the finite counter window")

	# Rush: a corridor from the boss, escaped by moving perpendicular to it.
	_place(b, l.menshen, Vector2(1000, 700))
	_place(b, l.wu, Vector2(1135, 700))
	l.fist_cd = 0.0
	l.process(b, 0.01)
	check(l.fist_windup > 0.0 and l.special_kind == "rush", "second special alternates to a straight rush")
	check(l.menshen.get_meta("story_pose", "") == "rush_windup"
		and _menshen_story_pose_source(l) == CA.animation_path("jiang_menshen_fists", "attack", l.menshen.animation_direction),
		"rush windup uses the exact four-direction campaign attack start")
	check(is_instance_valid(l.fist_marker) and l.fist_marker.get_meta("tell_kind", "") == "rush", "rush tell uses a long corridor marker")
	_place(b, l.wu, l.rush_from + Vector2(80, 120))
	l.process(b, l.fist_windup + 0.05)
	check(l.rush_dodges == 1 and b.mission.has_event("dodge_rush"), "perpendicular movement escapes the rush and creates a counter window")
	check(l.heavy_dodges == 1 and l.rush_dodges == 1, "the two spatial answers are tracked independently")
	check(l.wu.hp > 0.0 and l.menshen.story_outcome == "", "tell fixtures do not fake victory or a lethal result")
	await _dispose(b)

	b = await _start()
	b._smoke = false
	l = b.level
	check(l.st == l.ROAD and l.drunk == 0 and l.special_index == 0, "restart clears road and alternating-special progress")
	check(l.heavy_dodges == 0 and l.rush_dodges == 0 and not is_instance_valid(l.drill_marker), "restart clears drill markers and dodge counters")
	await _dispose(b)

	var report_dir := ProjectSettings.globalize_path("res://qa/campaign_gameplay_depth_20260901/kuaihuolin")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var report_path: String = report_dir.path_join("report.json")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "cases": evidence, "scope": "Road drill plus authored heavy/rush miss fixtures. Full combat outcome is verified separately by test_early_episodes.gd; not human feel or pacing evidence."}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[kuaihuolin-depth-result] ", JSON.stringify(report))
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
