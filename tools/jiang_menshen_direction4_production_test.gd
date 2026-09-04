extends SceneTree
## Runtime contract for the original-novel Jiang Zhong Happy Grove production batch.

const CA := preload("res://scripts/campaign_art.gd")
const VARIANT := "jiang_menshen_fists"
const UNIT_KEY := "jiang_menshen"
const STATES := ["idle", "walk", "attack", "hurt", "down"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const LOGIC_DIRECTIONS := {
	"se": Vector2(100.0, 0.0), "sw": Vector2(0.0, 100.0),
	"ne": Vector2(0.0, -100.0), "nw": Vector2(-100.0, 0.0),
}
const OPPOSITE := {"se":"nw", "sw":"ne", "ne":"sw", "nw":"se"}

var checks: Array = []
var failures: Array[String] = []
var unit_script
var definition: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name, "passed":passed, "detail":detail})
	print("[jiang-menshen-direction4] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null: return ""
	if texture is AtlasTexture and texture.atlas != null: return texture.atlas.resource_path
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
	unit._cast_t = 0.0
	unit._flinch = Vector2.ZERO
	unit.story_outcome = ""


func _state_frame(unit, art: Node, state: String, direction: String) -> Texture2D:
	_reset_state(unit, direction)
	match state:
		"walk": unit._move_blend = 1.0; unit._anim_t = 1.2
		"attack": unit._lunge = 0.72; unit._lunge_dir = LOGIC_DIRECTIONS[direction]
		"hurt": unit._flinch = Vector2(2.5, -0.5)
	var fallback: Texture2D = art.unit_texture(UNIT_KEY, VARIANT, direction)
	return unit._anim_frame_for_state(fallback)


func _direct_and_real_unit(art: Node) -> void:
	for state in STATES:
		var direction_pixels: Dictionary = {}
		for direction in DIRECTIONS:
			var expected := _expected(state, direction)
			var frames: Array = art.unit_anim_frames(UNIT_KEY, state, direction, VARIANT)
			var actual := _source(frames[0]) if not frames.is_empty() else ""
			if not frames.is_empty(): direction_pixels[hash(frames[0].get_image().get_data())] = true
			_check("exact source %s/%s" % [state, direction], CA.animation_path(VARIANT, state, direction) == expected and frames.size() == 1 and actual == expected)
			_check("directional source flag %s/%s" % [state, direction], art.unit_anim_uses_directional_source(UNIT_KEY, state, direction, VARIANT))
			var cached: Array = art.unit_anim_frames(UNIT_KEY, state, direction, VARIANT)
			_check("cache stable %s/%s" % [state, direction], cached.size() == 1 and frames[0].get_instance_id() == cached[0].get_instance_id())
		_check("four real viewpoints " + state, direction_pixels.size() == 4, direction_pixels.size())
	for direction in DIRECTIONS:
		var unit = _make_unit()
		for state in ["idle", "walk", "attack", "hurt"]:
			var frame := _state_frame(unit, art, state, direction)
			_check("real Unit selects %s/%s" % [state, direction], frame != null and _source(frame) == _expected(state, direction) and unit._frame_directional)
		_reset_state(unit, direction)
		unit.story_outcome = "subdued"
		unit.queue_redraw()
		await process_frame
		_check("real Unit down draw directional " + direction, unit._frame_directional)
		unit.queue_free()
		await process_frame


func _terminal_and_mode_isolation(art: Node) -> void:
	for direction in DIRECTIONS:
		var down: Array = art.unit_anim_frames(UNIT_KEY, "down", direction, VARIANT)
		var death: Array = art.unit_anim_frames(UNIT_KEY, "death", direction, VARIANT)
		var death_source := _source(death[0]) if not death.is_empty() else ""
		_check("down does not alias death " + direction, not down.is_empty() and _source(down[0]) == _expected("down", direction) and death_source != _expected("down", direction) and not art.unit_anim_uses_directional_source(UNIT_KEY, "death", direction, VARIANT))
		for state in STATES:
			var generic: Array = art.unit_anim_frames(UNIT_KEY, state, direction, "")
			var source := _source(generic[0]) if not generic.is_empty() else ""
			_check("free mode outside campaign %s/%s" % [state, direction], source.is_empty() or not source.begins_with("res://assets/campaign/"), source)
	var campaign_portrait: Texture2D = art.avatar_texture(UNIT_KEY, VARIANT)
	var generic_portrait: Texture2D = art.avatar_texture(UNIT_KEY)
	_check("campaign portrait exact route", campaign_portrait != null and campaign_portrait.resource_path == "res://assets/campaign/portraits/jiang_menshen_fists.png")
	_check("free mode portrait isolated", generic_portrait != null and generic_portrait != campaign_portrait and not generic_portrait.resource_path.begins_with("res://assets/campaign/"))


func _level7_story_route(art: Node) -> void:
	var campaign := root.get_node("Campaign")
	for mode in ["arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]: campaign.set(mode, false)
	campaign.current = campaign.index_for_id("level7")
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await process_frame
	var menshen = battle.level.menshen
	_check("real Level7 deploys original-result Jiang Menshen",
		menshen != null and menshen.key == UNIT_KEY and menshen.art_variant == VARIANT
		and menshen.defeat_outcome == "subdued")
	for direction in DIRECTIONS:
		_reset_state(menshen, direction)
		menshen.story_outcome = "subdued"
		menshen.queue_redraw()
		await process_frame
		var down_frames: Array = art.unit_anim_frames(UNIT_KEY, "down", direction, VARIANT)
		var down_source := _source(down_frames[0]) if not down_frames.is_empty() else ""
		_check("subdued draw selects living down " + direction,
			down_frames.size() == 1 and down_source == _expected("down", direction) and menshen._frame_directional,
			down_source)
		_reset_state(menshen, direction)
		menshen.set_meta("story_pose", "windup")
		var attack_frame: Texture2D = menshen._anim_frame_for_state(art.unit_texture(UNIT_KEY, VARIANT, direction))
		_check("heavy windup selects coarse attack " + direction,
			attack_frame != null and _source(attack_frame) == _expected("attack", direction) and menshen._frame_directional,
			_source(attack_frame))
		menshen.set_meta("story_pose", "")
		_reset_state(menshen, direction)
		menshen._flinch = Vector2(2.5, -0.5)
		var hurt_frame: Texture2D = menshen._anim_frame_for_state(art.unit_texture(UNIT_KEY, VARIANT, direction))
		_check("abdomen hit selects living hurt " + direction,
			hurt_frame != null and _source(hurt_frame) == _expected("hurt", direction) and menshen._frame_directional,
			_source(hurt_frame))
	current_scene = null
	battle.queue_free()
	await process_frame
	await process_frame


func _write_report() -> void:
	var output := OS.get_environment("JIANG_MENSHEN_DIRECTION4_RUNTIME_REPORT")
	if output.is_empty(): output = "res://qa/jiang_menshen_direction4_production_20260902/runtime_report.json"
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var payload := {"passed":failures.is_empty(), "checks":checks.size(), "failures":failures, "variant":VARIANT, "required_frames":20, "states":STATES, "directions":DIRECTIONS, "story_route":"Level7 hurt is a living abdomen hit; subdued is a living backward fall/yield; windup is same-direction attack", "death_route":"independent legacy death; never down", "free_mode_isolation_checked":true, "checks_detail":checks}
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	print("JIANG_MENSHEN_DIRECTION4_RUNTIME_RESULT ", JSON.stringify(payload))


func _run() -> void:
	await process_frame
	unit_script = load("res://scripts/unit.gd")
	var defs_script = load("res://scripts/defs.gd")
	var scripts_ok: bool = unit_script != null and defs_script != null and unit_script.can_instantiate() and defs_script.can_instantiate()
	_check("Unit and Defs scripts instantiate", scripts_ok)
	if not scripts_ok: _write_report(); quit(1); return
	definition = defs_script.UNITS.get(UNIT_KEY, {})
	_check("Jiang Menshen definition exists", not definition.is_empty())
	var art := root.get_node("Art")
	await _direct_and_real_unit(art)
	_terminal_and_mode_isolation(art)
	await _level7_story_route(art)
	_write_report()
	AudioServer.set_bus_mute(0, true)
	for unused in range(3): await process_frame
	quit(0 if failures.is_empty() else 1)

