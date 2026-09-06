extends SceneTree
## Real task movement is used for route choice, direct evacuation, and the
## optional rearguard recall. Combat is frozen only after the normal rescue
## chain reaches the authored route choice.

var failures: Array[String] = []
var checks := 0
var evidence: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("[jiangzhou-depth] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _start(route_name: String):
	seed(5088120)
	OS.set_environment("JIANGZHOU_SMOKE_ROUTE", route_name)
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == "level2":
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

func _dispose(b) -> void:
	evidence.append({
		"route": b.level.escape_route,
		"route_changed": b.level.route_changed,
		"rear_guard": b.level.rear_guard.key if is_instance_valid(b.level.rear_guard) else "",
		"rear_guard_recalled": b.level.rear_guard_recalled,
		"events": b.mission.events.keys(),
		"game_seconds": b.mission.total_game_seconds,
		"end": b.phase == b.Phase.END,
	})
	b.queue_free()
	await process_frame
	await process_frame

func _wait_for_route(b, limit := 9000) -> bool:
	var frames := 0
	while b.level.escape_route == "" and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	# The smoke driver waits between actions, so stopping here leaves the new
	# route choice committed without auto-clicking Bailong Temple.
	b._smoke = false
	return b.level.escape_route != "" and b.phase != b.Phase.END

func _freeze_enemies(b) -> void:
	for u in b.units:
		if is_instance_valid(u) and u.faction == 1:
			u.order_stop()
			u.set_physics_process(false)
			u.ability_slots.clear()
			# Remove frozen fixture bodies from separation/path checks. This happens
			# only after the finite six-unit split has already been asserted.
			u.resolve_story("retreated")

func _act(b, action_id: String, limit := 2400) -> bool:
	if not b.mission.request_action(action_id):
		return false
	var frames := 0
	while b.mission.active_action_id == action_id and b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	if frames >= limit:
		var actor = b.mission._actor
		print("[jiangzhou-timeout] id=", action_id, " actor=", actor.key if is_instance_valid(actor) else "nil", " pos=", actor.position if is_instance_valid(actor) else Vector2.ZERO, " target=", b.map.cell_to_world(b.mission.actions[action_id].cell), " cell_open=", b.map.is_open_cell(b.mission.actions[action_id].cell), " story=", actor.story_outcome if is_instance_valid(actor) else "nil")
	return frames < limit and b.mission.active_action_id != action_id

func _wait_escort_at_temple(b, limit := 3000) -> bool:
	var destination: Vector2 = b.map.cell_to_world(b.level.BAILONG)
	var frames := 0
	while b.phase != b.Phase.END and frames < limit:
		if b.level._living(b.level.song_freed) and b.level._living(b.level.dai_freed):
			if b.level.song_freed.position.distance_to(destination) < 150.0 and b.level.dai_freed.position.distance_to(destination) < 150.0:
				return true
		await process_frame
		frames += 1
	if b.level._living(b.level.song_freed) and b.level._living(b.level.dai_freed):
		print("[jiangzhou-escort-timeout] route=", b.level.escape_route, " song=", b.level.song_freed.position, " dai=", b.level.dai_freed.position, " target=", destination)
	return false

func _wait_pair_near(b, destination: Vector2, radius := 120.0, limit := 3000) -> bool:
	var frames := 0
	while b.phase != b.Phase.END and frames < limit:
		if b.level._living(b.level.song_freed) and b.level._living(b.level.dai_freed) \
				and b.level.song_freed.position.distance_to(destination) < radius \
				and b.level.dai_freed.position.distance_to(destination) < radius:
			return true
		await process_frame
		frames += 1
	return false

func _wait_unit_near(b, unit, destination: Vector2, radius := 100.0, limit := 3000) -> bool:
	var frames := 0
	while b.phase != b.Phase.END and frames < limit:
		if is_instance_valid(unit) and unit.hp > 0.0 and unit.position.distance_to(destination) < radius:
			return true
		await process_frame
		frames += 1
	return false

func _wait_end(b, limit := 4800) -> bool:
	var frames := 0
	while b.phase != b.Phase.END and frames < limit:
		await process_frame
		frames += 1
	return b.phase == b.Phase.END

func _issue_player_move(b, units: Array, destination: Vector2) -> bool:
	var living: Array = units.filter(func(u):
		return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "")
	if living.is_empty():
		return false
	b._set_selection(living)
	b._issue_order(b.to_screen(destination))
	return true

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0, true)

	# Route recovery remains a one-use tactical choice. It no longer shares a
	# fixture with embarkation because changing a live escort queue and then
	# freezing its bodies made the old test depend on path timing.
	var b = await _start("west")
	check(await _wait_for_route(b), "normal rescue chain reaches the route decision")
	var l = b.level
	check(l.escape_route == "route_west", "west smoke route selects the short narrow lane")
	check(l.route_pressure.size() == 6, "exactly six existing pursuers are split across the two lane mouths")
	check(l.route_pressure.filter(func(u): return is_instance_valid(u) and u.get_meta("jiangzhou_pressure", "") == "west_narrow").size() == 3, "three pursuers visibly pressure the west choke")
	check(l.route_pressure.filter(func(u): return is_instance_valid(u) and u.get_meta("jiangzhou_pressure", "") == "south_open").size() == 3, "three pursuers visibly pressure the south lane")
	_freeze_enemies(b)
	check(await _act(b, "change_route"), "Chao Gai physically reaches the junction to change route")
	check(l.escape_route == "route_south" and l.route_changed and b.mission.has_event("jiangzhou_route_changed"), "the one recovery choice really replaces all escort routes")
	check(not b.mission.request_action("change_route"), "the route cannot be toggled repeatedly")
	await _dispose(b)

	# Free route: once both captives are rescued, they may leave the authored road
	# and walk directly to the dock. Even if every original rescuer is lost, their
	# boarding completes the core rescue without inventing a story seal.
	b = await _start("west")
	check(await _wait_for_route(b), "direct-evacuation fixture reaches the rescued-pair retreat")
	l = b.level
	_freeze_enemies(b)
	for rescuer in l.rescuing_army.duplicate():
		if is_instance_valid(rescuer):
			rescuer.take_damage(100000.0, null, true, true)
	await process_frame
	check(b.phase == b.Phase.FIGHT and l._living_rescuers() == 0, "the rescued pair remains playable after all original rescuers are lost")
	var dock: Vector2 = b.map.cell_to_world(l.DOCK_C)
	check(_issue_player_move(b, [l.song_freed], dock) and await _wait_unit_near(b, l.song_freed, dock), "Song Jiang can move first without falsely completing a two-person rendezvous")
	check(l.st == l.RETREAT and not b.mission.has_event("bailong"), "a single captive at the dock does not trigger the Bailong rendezvous")
	check(l.st == l.RETREAT and _issue_player_move(b, [l.dai_freed], dock), "player independently orders Dai Zong after Song Jiang clears the temple route")
	var direct_frames := 0
	while l.st != l.EMBARK and b.phase != b.Phase.END and direct_frames < 5000:
		await process_frame
		direct_frames += 1
	check(l.st == l.EMBARK and b.mission.has_event("jiangzhou_direct_dock"), "Song Jiang and Dai Zong can physically bypass Bailong Temple and reach the dock")
	check(not is_instance_valid(l.rear_guard) and not b.mission.actions.has("rearguard_li") and not b.mission.actions.has("rearguard_yan"), "no fixed rearguard is required when no eligible rescuer remains")
	check(await _act(b, "board_song") and await _act(b, "board_dai"), "the two core captives board through their separate task actions")
	check(await _wait_end(b, 300) and b.mission.has_event("all_embarked"), "boarding the core pair completes the rescue without waiting for a rearguard")
	var direct_result: Dictionary = b.mission.result_snapshot(true)
	check(bool(direct_result.get("core_cleared", false)) and not bool(direct_result.get("story_complete", false)) and Array(direct_result.get("missed_ids", [])).has("bailong_meeting") and Array(direct_result.get("missed_ids", [])).has("named_survive"), "direct evacuation grants core clear but not the original-story seal")
	await _dispose(b)

	# Original-story route: Bailong Temple, an optional visible rearguard, explicit
	# recall, and every named rescuer alive at the dock earn the story seal.
	b = await _start("west")
	check(await _wait_for_route(b) and b.level.escape_route == "route_west", "original-story fixture keeps the west route to Bailong Temple")
	l = b.level
	_freeze_enemies(b)
	check(_issue_player_move(b, [l.song_freed, l.dai_freed], b.map.cell_to_world(l.BAILONG)), "player orders both rescued captives toward Bailong Temple")
	check(await _wait_escort_at_temple(b), "both unarmed captives physically reach Bailong Temple")
	var river_frames := 0
	while l.st != l.EMBARK and b.phase != b.Phase.END and river_frames < 120:
		await process_frame
		river_frames += 1
	check(l.st == l.EMBARK and b.mission.has_event("bailong"), "Bailong rendezvous opens the river escape")
	check(b.mission.actions.has("board_song") and b.mission.actions.has("board_dai") and b.mission.actions.has("rally_dock") and b.mission.actions.has("rearguard_li"), "boarding and rally actions are available before choosing the optional rearguard")
	check(await _act(b, "rearguard_li"), "Li Kui can physically take the optional temple rearguard position")
	check(is_instance_valid(l.rear_guard) and l.rear_guard.key == "li_kui" and b.mission.has_event("jiangzhou_rearguard_set"), "the optional rearguard is stored without becoming a core victory gate")
	var front_party: Array = l.rescuing_army.filter(func(u): return u != l.rear_guard)
	check(_issue_player_move(b, front_party, b.map.cell_to_world(l.DOCK_C)), "player orders the front party to converge on the dock")
	check(await _act(b, "rally_dock") and await _act(b, "board_song") and await _act(b, "board_dai"), "front party rallies while Song Jiang and Dai Zong board separately")
	var recall_frames := 0
	while not b.mission.actions.has("recall_rearguard") and b.phase != b.Phase.END and recall_frames < 120:
		await process_frame
		recall_frames += 1
	check(b.mission.actions.has("recall_rearguard") and not b.mission.has_event("jiangzhou_depart_early"), "the original route offers recall instead of forcing an early departure")
	check(_issue_player_move(b, [l.rear_guard], b.map.cell_to_world(l.DOCK_C)), "player gives Li Kui the physical recall order")
	check(await _wait_end(b) and b.mission.has_event("all_embarked") and b.mission.has_event("jiangzhou_named_survive"), "all named rescuers converge alive before original-route victory")
	check(is_instance_valid(l.rear_guard) and l.rear_guard_recalled and l.rear_guard.story_outcome == "embarked", "the chosen rearguard is recovered exactly once and boards alive")
	var story_result: Dictionary = b.mission.result_snapshot(true)
	check(bool(story_result.get("core_cleared", false)) and bool(story_result.get("story_complete", false)) and int(story_result.get("story_done", 0)) == int(story_result.get("story_total", -1)), "Bailong rendezvous and named full survival award the complete original-story seal")
	await _dispose(b)

	# A fresh battle must not inherit route or rearguard state.
	b = await _start("west")
	b._smoke = false
	check(b.level.escape_route == "" and not b.level.route_changed and not is_instance_valid(b.level.rear_guard), "restart clears route recovery and rearguard state")
	check(b.level.route_pressure.is_empty() and not b.level.rear_guard_recalled and not b.level.recall_action_added, "restart clears finite pursuit and recall bookkeeping")
	await _dispose(b)

	var report_dir := ProjectSettings.globalize_path("res://qa/campaign_gameplay_depth_20260901/jiangzhou")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var report_path: String = report_dir.path_join("report.json")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "cases": evidence, "scope": "Real task movement covers one-use route recovery, direct pair evacuation for core clear, and the optional Bailong rearguard recall for a complete story seal. Enemies are frozen only after the normal rescue chain reaches the route stage. Not human pacing evidence."}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[jiangzhou-depth-result] ", JSON.stringify(report))
	OS.set_environment("JIANGZHOU_SMOKE_ROUTE", "")
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
