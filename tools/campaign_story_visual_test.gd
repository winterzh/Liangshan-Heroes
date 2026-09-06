extends SceneTree
## Real-event renderer evidence, not a human playtest, full playthrough, or performance sample.
## Run with a graphical renderer after reserving the shared GPU window:
## Godot --path . --fixed-fps 60 --script res://tools/campaign_story_visual_test.gd
## Optional STORY_VISUAL_IDS=level6,level1,level7,level2,level3,level8; STORY_VISUAL_OUT overrides the output folder.
const VIEW_SIZE := Vector2i(1280, 720)
const MAX_SIM_SECONDS := 300.0
const CASES := [
	{"id": "level6", "state": "intercept", "event": "intercept", "zoom": 1.45},
	{"id": "level1", "state": "unconscious_carry", "event": "take_0", "zoom": 1.20},
	{"id": "level7", "state": "menshen_subdued", "event": "menshen_subdued", "zoom": 1.50},
	{"id": "level2", "state": "rescued_walk", "event": "free_dai", "zoom": 1.35},
	{"id": "level3", "state": "third_day_bound", "event": "third_day_bound", "zoom": 1.35},
	{"id": "level8", "state": "fire_and_rescued", "event": "daming_prisoners_freed", "zoom": 0.88},
]
var results: Array[Dictionary] = []
var output_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	# Keep Battle._ready from bypassing the normal HUD start button path.
	OS.set_environment("SMOKE_TEST", "")
	if DisplayServer.get_name() == "headless":
		push_error("Story visual capture needs a graphical renderer; headless cannot supply screenshot evidence.")
		quit(2)
		return
	output_dir = OS.get_environment("STORY_VISUAL_OUT")
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://qa/campaign_story_visual")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("Cannot create story capture directory: %s (%d)" % [output_dir, mkdir_error])
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.title = "Liangshan campaign story capture · 1280×720"
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	AudioServer.set_bus_mute(0, true)
	var requested := OS.get_environment("STORY_VISUAL_IDS")
	var all_passed := true
	for spec in CASES:
		if requested != "" and String(spec.id) not in requested.split(","):
			continue
		var b = await _start_case(String(spec.id))
		var sim_seconds := 0.0
		var frames := 0
		var last_progress := 0.0
		while not _target_reached(b, String(spec.id)) and b.phase != b.Phase.END and sim_seconds < MAX_SIM_SECONDS:
			await process_frame
			frames += 1
			sim_seconds += b.get_process_delta_time()
			if sim_seconds - last_progress >= 20.0:
				last_progress = sim_seconds
				print("[story-visual-progress] ", spec.id, " stage=", b.mission.stage_id, " action=", b.mission.active_action_id, " sim_seconds=", sim_seconds)
		var reached := _target_reached(b, String(spec.id))
		# Freeze only AFTER the real event. No HP, outcome, position, stage, or animation state is injected.
		b._smoke = false
		b.process_mode = Node.PROCESS_MODE_DISABLED
		Engine.time_scale = 1.0
		_frame_scene(b, String(spec.id), float(spec.zoom))
		b.hud.set_top(b.level.top_status(b))
		b.mission.tick(0.0)
		b.mission._panel.reset_size()
		await process_frame
		await process_frame
		b.mission.tick(0.0)
		b.mission._panel.reset_size()
		b._grid_build()
		for u in b.units:
			if is_instance_valid(u):
				u.queue_redraw()
		await RenderingServer.frame_post_draw
		var stem: String = String(spec.id) + "_" + String(spec.state) + "_1280"
		var screenshot_path := output_dir.path_join(stem + (".png" if reached else "_FAILED.png"))
		var frame_image := root.get_texture().get_image()
		var screenshot_error := ERR_CANT_CREATE
		var correct_size := frame_image != null and not frame_image.is_empty() and frame_image.get_size() == VIEW_SIZE
		if correct_size:
			screenshot_error = frame_image.save_png(screenshot_path)
		var captured := reached and correct_size and screenshot_error == OK
		var result := _snapshot(b, String(spec.id))
		result.merge({
			"capture_state": spec.state,
			"target_event": spec.event,
			"target_reached": reached,
			"captured": captured,
			"png": screenshot_path,
			"png_error": screenshot_error,
			"resolution_ok": correct_size,
			"frames_until_event": frames,
			"simulation_seconds_until_event": sim_seconds,
			"drive_time_scale": 4.0,
			"evidence_scope": "Real mission/combat state rendered after freeze; not human acceptance, full chapter completion, or performance evidence.",
			"progression_method": "Normal HUD start, then existing level _smoke_drive via mission.request_action and normal combat.",
			"capture_adjustments": ["Disable processing after target event", "Camera position and zoom only", "Normal HUD status/layout refresh"],
		})
		var json_error := _write_json(output_dir.path_join(stem + ".json"), result)
		if json_error != OK:
			captured = false
			result["captured"] = false
			result["json_error"] = json_error
		results.append(result)
		all_passed = all_passed and captured
		print("[story-visual-result] ", JSON.stringify({"id": spec.id, "captured": captured, "target_reached": reached, "simulation_seconds": sim_seconds, "png": screenshot_path}))
		b.queue_free()
		await process_frame
		await process_frame
	if results.is_empty():
		all_passed = false
	var summary := {"captured_all_requested": all_passed, "viewport": [1280, 720], "samples": results, "human_playtest": false, "performance_test": false}
	var summary_error := _write_json(output_dir.path_join("report.json"), summary)
	print("[story-visual-summary] ", JSON.stringify({"captured_all_requested": all_passed, "samples": results.size(), "report_error": summary_error}))
	quit(0 if all_passed and summary_error == OK else 1)

func _start_case(id: String):
	Engine.time_scale = 1.0
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.current = campaign.index_for_id(id)
	seed(5088120)
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

func _target_reached(b, id: String) -> bool:
	match id:
		"level6":
			return b.mission.has_event("intercept") and is_instance_valid(b.level.lu) and String(b.level.lu.get_meta("story_pose", "")) == "intercept"
		"level1":
			if not b.mission.has_event("drugged") or not b.mission.has_event("take_0"):
				return false
			if b.level.convoy.size() != 15:
				return false
			for guard in b.level.convoy:
				if not is_instance_valid(guard) or guard.hp <= 0.0 or guard.story_outcome != "unconscious":
					return false
			var carrier = b.find_unit("liu_tang")
			return carrier != null and int(carrier.get_meta("carrying_tribute", -1)) == 0 and b.kills == 0
		"level7":
			return b.mission.has_event("menshen_subdued") and is_instance_valid(b.level.menshen) and b.level.menshen.story_outcome == "subdued" and b.level.menshen.hp > 0.0 and b.kills == 0
		"level2":
			if b.mission.stage_id != "bailong" or not b.mission.has_event("free_song") or not b.mission.has_event("free_dai"):
				return false
			for person in [b.level.song_freed, b.level.dai_freed]:
				if not is_instance_valid(person) or person.hp <= 0.0 or person.is_captive or person.story_outcome != "" or person._move_blend <= 0.3 or person.position.distance_to(b.map.cell_to_world(b.level.SCAFFOLD)) < 120.0:
					return false
			return true
		"level3":
			if b.mission.stage_id != "zhu_infiltrate" or b.level.prisoners.size() != 7:
				return false
			for prisoner in b.level.prisoners:
				if not is_instance_valid(prisoner) or not prisoner.is_captive or not prisoner.is_noncombat or prisoner.base_speed != 0.0 or prisoner.atk != 0.0 or prisoner.art_variant != "bound_" + prisoner.key:
					return false
			return true
		"level8":
			return b.mission.has_event("daming_fire_lit") and b.mission.has_event("daming_prisoners_freed") and is_instance_valid(b.level.lu) and is_instance_valid(b.level.shi) and b.level.lu.hp > 0.0 and b.level.shi.hp > 0.0 and not b.level.lu.is_captive and not b.level.shi.is_captive
	return false

func _frame_scene(b, id: String, zoom_value: float) -> void:
	var center := Vector2.ZERO
	match id:
		"level6":
			center = b.map.cell_to_world(Vector2i(28, 19))
		"level1":
			center = b.map.cell_to_world(Vector2i(24, 20))
		"level7":
			if is_instance_valid(b.level.wu) and is_instance_valid(b.level.menshen):
				center = (b.level.wu.position + b.level.menshen.position) * 0.5
			else:
				center = b.map.cell_to_world(Vector2i(51, 19))
		"level8":
			# The jail and burning tower are both in frame; do not move the rescued people.
			center = b.map.cell_to_world(Vector2i(28, 18))
		"level2":
			center = (b.level.song_freed.position + b.level.dai_freed.position) * 0.5
		"level3":
			center = b.map.cell_to_world(Vector2i(12, 33))
	b.camera.position = b.to_screen(center)
	b.camera.zoom = Vector2.ONE * zoom_value
	# Move the subject to the open area right of the task panel and above the command bar.
	# This is a camera framing offset only; all world positions remain untouched.
	b.camera.position -= Vector2(70.0, -48.0) / zoom_value
	if id == "level8":
		# Keep the real jail occupants to the right of the two-column hero/task UI
		# while retaining the fire signal at the opposite edge of the same view.
		b.camera.position -= Vector2(90.0, 55.0) / zoom_value
	b.camera.offset = Vector2.ZERO
	b.camera.force_update_scroll()
	b._grid_build()

func _snapshot(b, id: String) -> Dictionary:
	var units: Array[Dictionary] = []
	for u in b.units:
		if not is_instance_valid(u):
			continue
		var cell: Vector2i = b.map.world_to_cell(u.position)
		units.append({
			"key": u.key, "name": u.display_name, "hp": u.hp, "faction": u.faction,
			"story_outcome": u.story_outcome, "captive": u.is_captive,
			"art_variant": u.art_variant, "direction": u.animation_direction,
			"story_pose": String(u.get_meta("story_pose", "")),
			"pose_seconds_remaining": u._story_pose_t,
			"move_blend": u._move_blend,
			"carrying_tribute": int(u.get_meta("carrying_tribute", -1)),
			"logical_position": [u.position.x, u.position.y], "cell": [cell.x, cell.y],
			"visible": u.visible, "movement_profile": u.movement_profile,
		})
	var objects: Array[Dictionary] = []
	if b.map.sample_scenery != null:
		for sprite in b.map.sample_scenery._sprites:
			if not is_instance_valid(sprite) or not sprite.has_meta("campaign_object"):
				continue
			var key := String(sprite.get_meta("campaign_object", ""))
			var record := {"key": key, "logical_position": [sprite.position.x, sprite.position.y], "visible": sprite.visible}
			if key == "cuiyun_tower":
				record["signal_texture_active"] = sprite.tex == root.get_node("Art").campaign_object_texture(key, "signal")
			if key == "prison_gate":
				record["open_texture_active"] = sprite.tex == root.get_node("Art").campaign_object_texture(key, "open")
			objects.append(record)
	var panel_rect: Rect2 = b.mission._panel.get_global_rect()
	return {
		"id": id, "title": b.level.title(), "phase": b.phase,
		"mission_stage": b.mission.stage_id, "mission_title": b.mission.stage_title,
		"objective": b.mission.objective, "top_status": b.hud.top_label.text,
		"active_action_id": b.mission.active_action_id, "events": b.mission.events.duplicate(true),
		"battle_report": b.mission.report.duplicate(), "kills": b.kills,
		"units": units, "story_objects": objects,
		"camera_position": [b.camera.position.x, b.camera.position.y], "camera_zoom": b.camera.zoom.x,
		"task_panel": [panel_rect.position.x, panel_rect.position.y, panel_rect.size.x, panel_rect.size.y],
		"start_button_visible": b.hud.start_btn.visible,
	}

func _write_json(path: String, value: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	return OK
