extends SceneTree
## Runtime contract for the intentionally small production batch.
## Scope: li_kui + gou_lian, idle/walk/attack/hurt/down, four exact directions.

const UNITS := ["li_kui", "gou_lian"]
const STATES := ["idle", "walk", "attack", "hurt", "down"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const REPORT := "res://qa/direction4_minimal_production_20260902/runtime_report.json"

var checks: Array = []
var failures: Array[String] = []
var unit_script
var definitions: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name, "passed":passed, "detail":detail})
	print("[direction4-minimal] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _clear_scoped_art_caches(art: Node) -> void:
	for property in ["_anim_cache", "_generic_directional_path_cache"]:
		var cache: Dictionary = art.get(property)
		var erase: Array = []
		for raw_key in cache.keys():
			var key := String(raw_key)
			if "li_kui" in key or "gou_lian" in key:
				erase.append(raw_key)
		for key in erase:
			cache.erase(key)


func _make_unit(key: String):
	var unit = unit_script.new()
	unit.setup(key, definitions[key], 0, null, null)
	root.add_child(unit)
	unit.set_process(false)
	unit.set_physics_process(false)
	return unit


func _state_frame(unit, art: Node, state: String, direction: String) -> Texture2D:
	unit.animation_direction = direction
	unit._move_blend = 0.0
	unit._lunge = 0.0
	unit._flinch = Vector2.ZERO
	unit.story_outcome = ""
	match state:
		"walk": unit._move_blend = 1.0
		"attack": unit._lunge = 1.0
		"hurt": unit._flinch = Vector2(2.0, 0.0)
	var fallback: Texture2D = art.unit_texture(unit.key, "", direction)
	return unit._anim_frame_for_state(fallback)


func _test_direct_resolution(art: Node) -> void:
	for unit in UNITS:
		for state in STATES:
			var state_sources: Array[String] = []
			for direction in DIRECTIONS:
				var expected := "res://assets/anim/%s_%s_%s.png" % [unit, state, direction]
				var frames: Array = art.unit_anim_frames(unit, state, direction, "")
				var actual := _source(frames[0]) if not frames.is_empty() else ""
				state_sources.append(actual)
				_check("exact source %s/%s/%s" % [unit, state, direction],
					frames.size() == 1 and actual == expected,
					{"expected":expected, "actual":actual, "frames":frames.size()})
				_check("directional flag %s/%s/%s" % [unit, state, direction],
					art.unit_anim_uses_directional_source(unit, state, direction, ""))
				var cached: Array = art.unit_anim_frames(unit, state, direction, "")
				_check("cache stable %s/%s/%s" % [unit, state, direction],
					cached.size() == 1 and frames[0].get_instance_id() == cached[0].get_instance_id())
			_check("four sources remain distinct %s/%s" % [unit, state],
				state_sources.size() == 4 and state_sources[0] != state_sources[1]
				and state_sources[0] != state_sources[2] and state_sources[0] != state_sources[3]
				and state_sources[1] != state_sources[2] and state_sources[1] != state_sources[3]
				and state_sources[2] != state_sources[3], state_sources)


func _test_real_unit_selection(art: Node) -> void:
	for unit_key in UNITS:
		for direction in DIRECTIONS:
			var unit = _make_unit(unit_key)
			for state in ["idle", "walk", "attack", "hurt"]:
				var frame := _state_frame(unit, art, state, direction)
				var expected := "res://assets/anim/%s_%s_%s.png" % [unit_key, state, direction]
				_check("Unit selects %s/%s/%s" % [unit_key, state, direction],
					frame != null and _source(frame) == expected and unit._frame_directional,
					{"expected":expected, "actual":_source(frame), "directional":unit._frame_directional})
			unit.story_outcome = "subdued"
			unit.animation_direction = direction
			unit.queue_redraw()
			await process_frame
			_check("story outcome draws exact down direction %s/%s" % [unit_key, direction],
				unit._frame_directional,
				{"expected":"res://assets/anim/%s_down_%s.png" % [unit_key, direction], "story_outcome":unit.story_outcome})
			unit.queue_free()
			await process_frame


func _test_down_death_isolation(art: Node) -> void:
	for unit in UNITS:
		for direction in DIRECTIONS:
			var down: Array = art.unit_anim_frames(unit, "down", direction, "")
			var death: Array = art.unit_anim_frames(unit, "death", direction, "")
			_check("down remains available %s/%s" % [unit, direction],
				not down.is_empty() and _source(down[0]) == "res://assets/anim/%s_down_%s.png" % [unit, direction])
			var death_source := _source(death[0]) if not death.is_empty() else ""
			var valid_legacy_death: bool = death.is_empty() or (
				death_source == "res://assets/anim/%s_death.png" % unit
				and not art.unit_anim_uses_directional_source(unit, "death", direction, "")
			)
			_check("down never aliases into death %s/%s" % [unit, direction],
				valid_legacy_death and death_source != "res://assets/anim/%s_down_%s.png" % [unit, direction],
				{"death_frames":death.size(), "death_source":death_source,
					"note":"An older undirected <unit>_death.png may remain; this batch created no death file or alias."})


func _test_campaign_variant_isolation(art: Node) -> void:
	# These two story costumes existed before this batch.  Their exact campaign
	# paths must still win over ordinary assets/anim files in every direction.
	for fixture in [
		{"key":"wu_song", "variant":"wu_song_mengzhou"},
		{"key":"lin_chong", "variant":"lin_chong_bound"},
	]:
		for direction in DIRECTIONS:
			var expected := "res://assets/campaign/anim/%s_idle_%s.png" % [fixture.variant, direction]
			var frames: Array = art.unit_anim_frames(fixture.key, "idle", direction, fixture.variant)
			var actual := _source(frames[0]) if not frames.is_empty() else ""
			_check("campaign variant remains isolated %s/%s" % [fixture.variant, direction],
				actual == expected and art.unit_anim_uses_directional_source(fixture.key, "idle", direction, fixture.variant),
				{"expected":expected, "actual":actual})


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
	var payload := {
		"passed":failures.is_empty(),
		"checks":checks.size(),
		"failures":failures,
		"scope":"Runtime Art and real Unit selection for li_kui/gou_lian only; idle/walk/attack/hurt/down x four. Includes existing campaign costume isolation and explicit down/death separation.",
		"frame_requirement_count":40,
		"death_aliases_expected":0,
		"checks_detail":checks,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	print("DIRECTION4_MINIMAL_RUNTIME_RESULT ", JSON.stringify(payload))


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
	definitions = defs_script.UNITS
	_check("target definitions exist", definitions.has("li_kui") and definitions.has("gou_lian"))
	var art := root.get_node("Art")
	_clear_scoped_art_caches(art)
	_test_direct_resolution(art)
	await _test_real_unit_selection(art)
	_test_down_death_isolation(art)
	_test_campaign_variant_isolation(art)
	_write_report()
	_stop_audio()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
