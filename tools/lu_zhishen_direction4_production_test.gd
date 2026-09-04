extends SceneTree
## Runtime contract for the Wild Boar Forest Lu Zhishen production batch.
## It checks exact source routing, real Unit state selection, intercept aliasing,
## down/death separation, and free-mode isolation without writing player state.

const CA := preload("res://scripts/campaign_art.gd")
const VARIANT := "lu_zhishen_rescue"
const UNIT_KEY := "lu_zhishen"
const STATES := ["idle", "walk", "attack", "hurt", "down"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]

var checks: Array = []
var failures: Array[String] = []
var unit_script
var definition: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name, "passed":passed, "detail":detail})
	print("[lu-direction4] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _expected(state: String, direction: String) -> String:
	return "res://assets/campaign/anim/%s_%s_%s.png" % [VARIANT, state, direction]


func _make_unit():
	var unit = unit_script.new()
	unit.setup(UNIT_KEY, definition, 0, null, null)
	root.add_child(unit)
	unit.art_variant = VARIANT
	unit.set_process(false)
	unit.set_physics_process(false)
	return unit


func _reset_state(unit, direction: String) -> void:
	unit.animation_direction = direction
	unit._direction_candidate = direction
	unit._direction_votes = 4
	unit.face_left = direction in ["sw", "nw"]
	unit._move_blend = 0.0
	unit._lunge = 0.0
	unit._flinch = Vector2.ZERO
	unit.story_outcome = ""
	unit._story_pose_t = 0.0
	unit.remove_meta("story_pose")


func _real_state_frame(unit, art: Node, state: String, direction: String) -> Texture2D:
	_reset_state(unit, direction)
	match state:
		"walk":
			unit._move_blend = 1.0
			unit._anim_t = 1.2
		"attack":
			unit._lunge = 0.72
			unit._lunge_dir = Vector2.RIGHT
		"hurt":
			unit._flinch = Vector2(2.5, -0.5)
	var fallback: Texture2D = art.unit_texture(UNIT_KEY, VARIANT, direction)
	return unit._anim_frame_for_state(fallback)


func _direct_resolution(art: Node) -> void:
	for state in STATES:
		var direction_sources: Array[String] = []
		var direction_pixels: Dictionary = {}
		for direction in DIRECTIONS:
			var expected := _expected(state, direction)
			var path := CA.animation_path(VARIANT, state, direction)
			var frames: Array = art.unit_anim_frames(UNIT_KEY, state, direction, VARIANT)
			var actual := _source(frames[0]) if not frames.is_empty() else ""
			direction_sources.append(actual)
			if not frames.is_empty():
				direction_pixels[hash(frames[0].get_image().get_data())] = true
			_check("exact source %s/%s" % [state, direction],
				path == expected and frames.size() == 1 and actual == expected,
				{"path":path, "expected":expected, "actual":actual, "frames":frames.size()})
			_check("directional source flag %s/%s" % [state, direction],
				art.unit_anim_uses_directional_source(UNIT_KEY, state, direction, VARIANT))
			var cached: Array = art.unit_anim_frames(UNIT_KEY, state, direction, VARIANT)
			_check("cache is stable %s/%s" % [state, direction],
				cached.size() == 1 and frames[0].get_instance_id() == cached[0].get_instance_id())
		_check("four real viewpoints %s" % state,
			direction_sources.size() == 4 and direction_sources.all(func(source): return source != "")
			and direction_pixels.size() == 4,
			{"sources":direction_sources, "unique_pixel_sets":direction_pixels.size()})


func _intercept_alias(art: Node) -> void:
	for direction in DIRECTIONS:
		var attack_path := _expected("attack", direction)
		var intercept_path := CA.animation_path(VARIANT, "intercept", direction)
		var attack: Array = art.unit_anim_frames(UNIT_KEY, "attack", direction, VARIANT)
		var intercept: Array = art.unit_anim_frames(UNIT_KEY, "intercept", direction, VARIANT)
		var attack_source := _source(attack[0]) if not attack.is_empty() else ""
		var intercept_source := _source(intercept[0]) if not intercept.is_empty() else ""
		_check("intercept aliases exact same-direction attack %s" % direction,
			intercept_path == attack_path and intercept_path == attack_path
			and attack.size() == 1 and intercept.size() == 1
			and attack_source == attack_path and intercept_source == attack_path
			and attack[0].get_image().get_data() == intercept[0].get_image().get_data(),
			{"intercept_path":intercept_path, "attack_path":attack_path,
				"intercept_source":intercept_source, "legacy_intercept_selected":intercept_source.ends_with("_intercept_%s.png" % direction)})
		_check("intercept is reported as exact directional art %s" % direction,
			art.campaign_variant_has_animation(VARIANT, "intercept", direction)
			and art.unit_anim_uses_directional_source(UNIT_KEY, "intercept", direction, VARIANT))


func _real_unit_selection(art: Node) -> void:
	for direction in DIRECTIONS:
		var unit = _make_unit()
		for state in ["idle", "walk", "attack", "hurt"]:
			var frame := _real_state_frame(unit, art, state, direction)
			_check("real Unit selects %s/%s" % [state, direction],
				frame != null and _source(frame) == _expected(state, direction) and unit._frame_directional,
				{"expected":_expected(state, direction), "actual":_source(frame), "directional":unit._frame_directional})
		_reset_state(unit, direction)
		unit.play_story_pose("intercept", VARIANT, 2.0)
		var story_frame: Texture2D = unit._anim_frame_for_state(art.unit_texture(UNIT_KEY, VARIANT, direction))
		_check("real Unit intercept pose selects attack %s" % direction,
			story_frame != null and _source(story_frame) == _expected("attack", direction) and unit._frame_directional,
			{"expected":_expected("attack", direction), "actual":_source(story_frame), "directional":unit._frame_directional})
		_reset_state(unit, direction)
		unit.story_outcome = "subdued"
		unit.queue_redraw()
		await process_frame
		_check("real Unit down draw is directional %s" % direction, unit._frame_directional,
			{"expected":_expected("down", direction), "story_outcome":unit.story_outcome})
		unit.queue_free()
		await process_frame


func _terminal_and_mode_isolation(art: Node) -> void:
	for direction in DIRECTIONS:
		var down: Array = art.unit_anim_frames(UNIT_KEY, "down", direction, VARIANT)
		var death: Array = art.unit_anim_frames(UNIT_KEY, "death", direction, VARIANT)
		var death_source := _source(death[0]) if not death.is_empty() else ""
		_check("down does not alias death %s" % direction,
			not down.is_empty() and _source(down[0]) == _expected("down", direction)
			and death_source != _expected("down", direction)
			and not art.unit_anim_uses_directional_source(UNIT_KEY, "death", direction, VARIANT),
			{"down":_source(down[0]) if not down.is_empty() else "", "death":death_source})
		for state in STATES:
			var generic: Array = art.unit_anim_frames(UNIT_KEY, state, direction, "")
			var generic_source := _source(generic[0]) if not generic.is_empty() else ""
			_check("free-mode route stays outside campaign %s/%s" % [state, direction],
				generic_source.is_empty() or not generic_source.begins_with("res://assets/campaign/"), generic_source)
	var campaign_portrait: Texture2D = art.avatar_texture(UNIT_KEY, VARIANT)
	var generic_portrait: Texture2D = art.avatar_texture(UNIT_KEY)
	_check("campaign portrait uses corrected variant bytes",
		campaign_portrait != null and campaign_portrait.resource_path == "res://assets/campaign/portraits/lu_zhishen_rescue.png")
	_check("free-mode portrait remains generic",
		generic_portrait != null and generic_portrait != campaign_portrait
		and not generic_portrait.resource_path.begins_with("res://assets/campaign/"),
		{"campaign":campaign_portrait.resource_path if campaign_portrait != null else "",
			"generic":generic_portrait.resource_path if generic_portrait != null else ""})


func _stop_audio() -> void:
	for autoload_name in ["Sfx", "Music"]:
		var audio_root := root.get_node_or_null(autoload_name)
		if audio_root == null:
			continue
		audio_root.set("enabled", false)
		for child in audio_root.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null


func _write_report() -> void:
	var output := OS.get_environment("LU_ZHISHEN_DIRECTION4_RUNTIME_REPORT")
	if output.is_empty():
		output = "res://qa/lu_zhishen_direction4_production_20260902/runtime_report.json"
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var payload := {
		"passed":failures.is_empty(), "checks":checks.size(), "failures":failures,
		"variant":VARIANT, "required_frames":20,
		"states":STATES, "directions":DIRECTIONS,
		"intercept_route":"exact same-direction attack PNG",
		"death_route":"independent legacy/programmatic death; never down",
		"free_mode_isolation_checked":true,
		"checks_detail":checks,
	}
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	print("LU_ZHISHEN_DIRECTION4_RUNTIME_RESULT ", JSON.stringify(payload))


func _run() -> void:
	await process_frame
	unit_script = load("res://scripts/unit.gd")
	var defs_script = load("res://scripts/defs.gd")
	var scripts_ok: bool = unit_script != null and defs_script != null \
		and unit_script.can_instantiate() and defs_script.can_instantiate()
	_check("production Unit and Defs scripts instantiate", scripts_ok)
	if not scripts_ok:
		_write_report()
		quit(1)
		return
	definition = defs_script.UNITS.get(UNIT_KEY, {})
	_check("Lu Zhishen definition exists", not definition.is_empty())
	var art := root.get_node("Art")
	_direct_resolution(art)
	_intercept_alias(art)
	await _real_unit_selection(art)
	_terminal_and_mode_isolation(art)
	_write_report()
	_stop_audio()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
