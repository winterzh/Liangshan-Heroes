extends SceneTree
## Graphical fixture for the production death signal and published web atlas.
## It is visual QA only: no human playtest, pacing result or combat-performance claim.

const VIEW := Vector2i(1280, 720)
const OUTPUT := "res://qa/death_remains_20260901/visual"
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	print("[death-remains-visual] ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func _marks(b) -> Array:
	return b.fx_root.get_children().filter(func(node) -> bool:
		return is_instance_valid(node) and not node.is_queued_for_deletion() \
			and bool(node.get_meta("death_remains", false)))


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	if DisplayServer.get_name() == "headless":
		push_error("Death-remains visual QA needs a graphical renderer.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW
	root.content_scale_size = VIEW
	root.title = "Liangshan death remains visual QA · 1280×720"
	AudioServer.set_bus_mute(0, true)
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	var campaign = root.get_node("Campaign")
	for mode in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]:
		campaign.set(mode, false)
	campaign.current = campaign.index_for_id("level5")
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b.set_process(false)
	b.set_physics_process(false)

	# Keep the authored map and render stack, but stop unrelated armies from
	# entering this short fixture while six real died signals are exercised.
	for unit in b.units:
		if is_instance_valid(unit):
			unit.set_physics_process(false)
	var base: Vector2i = b.map.nearest_open(Vector2i(28, 31))
	var death_cells := [
		base + Vector2i(-2, -1), base + Vector2i(0, -1), base + Vector2i(2, -1),
		base + Vector2i(-2, 1), base + Vector2i(0, 1), base + Vector2i(2, 1),
	]
	var death_notices: Array = []
	var victim_refs: Array = []
	for index in range(death_cells.size()):
		var cell: Vector2i = b.map.nearest_open(death_cells[index])
		var victim = b.spawn_at("guan_dao", 1, cell)
		if victim == null:
			_check(false, "fixture victim %d spawned" % index)
			continue
		victim_refs.append(weakref(victim))
		victim.died.connect(func(_unit): death_notices.append(true))
		victim.take_damage(100000.0, null, false, true, "qa_visual_death")

	var before_story := _marks(b).size()
	var story_victim = b.spawn_at("guan_dao", 1, b.map.nearest_open(base + Vector2i(5, 3)))
	story_victim.defeat_outcome = "captured"
	story_victim.set_physics_process(false)
	story_victim.take_damage(100000.0, null, false, true, "qa_visual_story")
	_check(_marks(b).size() == before_story and story_victim.story_outcome == "captured",
		"non-lethal story resolution adds no residue")

	# The Unit death animation is 1.4 s. Keep normal frame processing long enough
	# to prove the residue survives after the bodies have finished fading.
	await create_timer(1.65).timeout
	var marks := _marks(b)
	var bodies_freed := victim_refs.all(func(ref): return ref.get_ref() == null)
	_check(death_notices.size() == death_cells.size(), "six ordinary deaths emitted real died signals")
	_check(bodies_freed, "six dead unit bodies finish their 1.4-second fade and are freed")
	_check(marks.size() == death_cells.size(), "six persistent residue nodes remain after body fade")
	_check(marks.all(func(mark): return mark.frame_texture != null), "all residue nodes use the web atlas")
	_check(marks.all(func(mark): return mark.remaining > 40.0), "residue lifetime is much longer than the old 1.2-second mark")

	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.hud.hide()
	var center: Vector2 = b.map.cell_to_world(base)
	b.camera.position = b.to_screen(center)
	b.camera.zoom = Vector2.ONE * 1.65
	b.camera.force_update_scroll()
	b._grid_build()
	for mark in marks:
		mark.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var png_path := OUTPUT.path_join("death_remains_real_deaths_1280.png")
	var png_ok := image != null and image.get_size() == VIEW and image.save_png(png_path) == OK
	_check(png_ok, "1280x720 production-map capture saved")

	var report := {
		"passed": failures.is_empty(),
		"failures": failures,
		"viewport": [VIEW.x, VIEW.y],
		"real_death_signals": death_notices.size(),
		"dead_unit_bodies_freed": bodies_freed,
		"remains_count": marks.size(),
		"frames": marks.map(func(mark): return int(mark.frame_index)),
		"remaining_seconds": marks.map(func(mark): return float(mark.remaining)),
		"atlas_path": "res://assets/campaign/objects/death_remains_default.png",
		"png": png_path,
		"human_playtest": false,
		"performance_test": false,
		"fixture_note": "Six ordinary units die through Unit.take_damage/died; one captured story unit is a negative control. Camera and HUD visibility change only after the state is reached.",
	}
	var report_file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if report_file == null:
		failures.append("report file opens")
	else:
		report_file.store_string(JSON.stringify(report, "  ") + "\n")
		report_file.close()
	print("[death-remains-visual-result] ", JSON.stringify(report))
	b.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
