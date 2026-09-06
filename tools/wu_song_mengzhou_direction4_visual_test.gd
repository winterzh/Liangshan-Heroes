extends SceneTree
## 1280x720 Vulkan fixture for the Mengzhou-period Wu Song batch.

const VIEW_SIZE := Vector2i(1280, 720)
const STATES := ["idle", "walk", "attack", "hurt", "down"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const VARIANT := "wu_song_mengzhou"
const ISO_INV := Transform2D(Vector2(0.5, -0.5), Vector2(1.0, 1.0), Vector2.ZERO)
const P95_LIMIT_MS := 16.7
const P99_LIMIT_MS := 33.3

var checks: Array = []
var failures: Array[String] = []
var captures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name, "passed":passed, "detail":detail})
	print("[wu-mengzhou-visual] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed: failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null: return ""
	return texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path


func _expected(state: String, direction: String) -> String:
	return "res://assets/campaign/anim/%s_%s_%s.png" % [VARIANT, state, direction]


func _label(layer: CanvasLayer, text: String, at: Vector2, size: Vector2, font_size := 18, color := Color("e8dfc5")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)
	return label


func _state_setup(unit, state: String, direction: String) -> void:
	unit.art_variant = VARIANT
	unit.animation_direction = direction
	unit._direction_candidate = direction
	unit._direction_votes = 4
	unit.face_left = direction in ["sw", "nw"]
	unit._move_blend = 0.0
	unit._lunge = 0.0
	unit._cast_t = 0.0
	unit._flinch = Vector2.ZERO
	unit.story_outcome = ""
	match state:
		"walk": unit._move_blend = 1.0; unit._anim_t = 1.2
		"attack": unit._lunge = 0.68; unit._lunge_dir = Vector2.RIGHT
		"hurt": unit._flinch = Vector2(2.5, -0.5)
		"down": unit.story_outcome = "subdued"
	unit.queue_redraw()


func _release_battle_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty(): return INF
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[mini(ordered.size() - 1, int(ceil(ordered.size() * percentile)) - 1)]


func _performance_sample() -> Dictionary:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var intervals: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < 3000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
	var p95 := _percentile(intervals, 0.95)
	var p99 := _percentile(intervals, 0.99)
	var mean: float = float(intervals.reduce(func(total, value): return total + value, 0.0)) / float(maxi(1, intervals.size()))
	_check("Level7 renderer fixture P95 <= 16.7 ms", p95 <= P95_LIMIT_MS, p95)
	_check("Level7 renderer fixture P99 <= 33.3 ms", p99 <= P99_LIMIT_MS, p99)
	return {"wall_seconds":float(previous - start) / 1000000.0, "frames":intervals.size(), "mean_frame_ms":mean, "p95_frame_ms":p95, "p99_frame_ms":p99, "p95_gate_ms":P95_LIMIT_MS, "p99_gate_ms":P99_LIMIT_MS, "scope":"Level7 renderer stress fixture with 40 corrected Wu Song nodes; no combat AI, balance, relative baseline, or soak claim."}


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("wu_song_mengzhou_direction4_visual_test needs a graphical renderer")
		quit(2)
		return
	var output_dir := OS.get_environment("WU_SONG_MENGZHOU_DIRECTION4_VISUAL_OUT")
	if output_dir.is_empty(): output_dir = ProjectSettings.globalize_path("res://qa/wu_song_mengzhou_direction4_production_20260902/runtime_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	OS.set_environment("CAMPAIGN_QA", "1")
	root.mode = Window.MODE_WINDOWED
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	DisplayServer.window_set_size(VIEW_SIZE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AudioServer.set_bus_mute(0, true)
	var art := root.get_node("Art")
	var campaign := root.get_node("Campaign")
	for mode in ["arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]: campaign.set(mode, false)
	campaign.current = campaign.index_for_id("level7")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.hud.hide()
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.camera.set_process(false)
	for existing in battle.units:
		existing.hide()
		existing.set_process(false)
		existing.set_physics_process(false)
	var open_cell: Vector2i = battle.map.nearest_open(Vector2i(31, 21), "land")
	var origin: Vector2 = battle.map.cell_to_world(open_cell)
	battle.camera.position = battle.to_screen(origin)
	battle.camera.zoom = Vector2.ONE
	battle.camera.force_update_scroll()

	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var top := ColorRect.new()
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 58)
	top.color = Color(0.055, 0.075, 0.095, 0.94)
	overlay.add_child(top)
	for column in DIRECTIONS.size():
		_label(overlay, DIRECTIONS[column].to_upper(), Vector2(300 + column * 175, 64), Vector2(165, 26), 17, Color("9cc8e6"))
	var title := _label(overlay, "", Vector2(0, 13), Vector2(1280, 34), 22)

	for state in STATES:
		title.text = "快活林·孟州武松·真四向 · %s" % state.to_upper()
		var spawned: Array = []
		for column in DIRECTIONS.size():
			var direction: String = DIRECTIONS[column]
			var unit = battle.spawn_unit("wu_song", 0, origin)
			# Keep every review figure away from the fixed willow at the left edge;
			# occlusion belongs to gameplay QA, not this silhouette/direction plate.
			unit.position = origin + ISO_INV.basis_xform(Vector2(-160 + column * 175, 20))
			unit.visual_scale = 1.55
			_state_setup(unit, state, direction)
			unit.set_process(false)
			unit.set_physics_process(false)
			var frames: Array = art.unit_anim_frames("wu_song", state, direction, VARIANT)
			var actual := _source(frames[0]) if not frames.is_empty() else ""
			_check("visual source %s/%s" % [state, direction], actual == _expected(state, direction), {"expected":_expected(state, direction), "actual":actual})
			spawned.append(unit)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if state == "down":
			for index in spawned.size(): _check("real down draw directional " + DIRECTIONS[index], spawned[index]._frame_directional)
		var output := output_dir.path_join("%s_1280x720.png" % state)
		var image := root.get_texture().get_image()
		var error := image.save_png(output) if image != null and image.get_size() == VIEW_SIZE else ERR_CANT_CREATE
		_check("capture written " + state, error == OK and FileAccess.file_exists(output), output)
		captures.append({"state":state, "png":output, "sha256":FileAccess.get_sha256(output)})
		for unit in spawned:
			battle.units.erase(unit)
			unit.queue_free()
		await process_frame

	var stress_units: Array = []
	for index in range(40):
		var state: String = STATES[index % STATES.size()]
		var direction: String = DIRECTIONS[index % DIRECTIONS.size()]
		var unit = battle.spawn_unit("wu_song", 0, origin)
		unit.position = origin + ISO_INV.basis_xform(Vector2(-360 + (index % 8) * 100, -190 + (index / 8) * 92))
		unit.visual_scale = 1.15
		_state_setup(unit, state, direction)
		unit.set_process(false)
		unit.set_physics_process(false)
		stress_units.append(unit)
	await process_frame
	await process_frame
	var performance := await _performance_sample()
	var performance_png := output_dir.path_join("performance_fixture_1280x720.png")
	var performance_error := root.get_texture().get_image().save_png(performance_png)
	_check("performance fixture capture written", performance_error == OK, performance_png)

	var report := {"passed":failures.is_empty(), "checks":checks.size(), "failures":failures, "captures":captures, "performance_capture":performance_png, "viewport":[1280, 720], "display_server":DisplayServer.get_name(), "renderer":RenderingServer.get_video_adapter_name(), "rendering_method":RenderingServer.get_current_rendering_method(), "performance":performance, "scope":"Real Battle-spawned Wu Song nodes on the Level7 map; visual and bounded render evidence only, not a chapter playthrough, human acceptance, balance test, or 30-minute soak."}
	var report_path := output_dir.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("WU_SONG_MENGZHOU_DIRECTION4_VISUAL_RESULT ", JSON.stringify(report))
	current_scene = null
	_release_battle_cursor_textures(battle)
	overlay.queue_free()
	battle.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	quit(0 if failures.is_empty() else 1)
