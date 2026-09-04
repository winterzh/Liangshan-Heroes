extends SceneTree
## Targeted runtime contract for the accepted Lin Chong prisoner subset.
## Scope is intentionally limited to idle/walk x SE/SW/NE/NW plus the real
## level-6 noncombat route. Bound, escort and assisted assets remain separate.

const VARIANT := "lin_chong_prisoner"
const UNIT_KEY := "lin_chong"
const STATES := ["idle", "walk"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const REPORT := "res://qa/lin_chong_prisoner_direction4_production_20260902/runtime_report.json"
const EXPECTED_SHA256 := {
	"idle_ne": "9f2f5f9b49e421793d304ded7e12b8717f39ea29ec2adc223bc93193be8e0282",
	"idle_nw": "28668a1d10bbb21985261de6b141ac6489614b129dcef1bb806aaac61e9ca530",
	"idle_se": "845d488458493f539b5d7d7754d461b8f5f73a76e2ceb1f4f8fe16c9f4273be6",
	"idle_sw": "be46b9fbf1587a0921b10ab8862c7365014cdc647a1debb63c0a7e997dc3534d",
	"walk_ne": "ac40ee59194fe56bf3f0ba2122548749257754e077ae67a573572bbbe2f832b7",
	"walk_nw": "515df0c9c175bd709fe9026eb378a0613ecc69af26c4669d431035905059a06e",
	"walk_se": "b6105c89e4421589f5a66a8d0c573060c55af2eb2721407b5d407298d7d75265",
	"walk_sw": "2fd7d744a7286daa1477dba6470917d6267fcedb9cb145a9afff49fed6e77255",
}

var checks: Array = []
var failures: Array[String] = []
var unit_script
var definitions: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lin-chong-prisoner] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _make_unit():
	var unit = unit_script.new()
	unit.setup(UNIT_KEY, definitions[UNIT_KEY], 0, null, null)
	unit.art_variant = VARIANT
	unit.is_noncombat = true
	root.add_child(unit)
	unit.set_process(false)
	unit.set_physics_process(false)
	return unit


func _clear_cache(art: Node) -> void:
	var cache: Dictionary = art.get("_anim_cache")
	var erase: Array = []
	for raw_key in cache.keys():
		if VARIANT in String(raw_key):
			erase.append(raw_key)
	for raw_key in erase:
		cache.erase(raw_key)


func _test_files(art: Node) -> void:
	for state in STATES:
		var distinct_sources: Array[String] = []
		for direction in DIRECTIONS:
			var suffix := "%s_%s" % [state, direction]
			var expected := "res://assets/campaign/anim/%s_%s.png" % [VARIANT, suffix]
			var absolute := ProjectSettings.globalize_path(expected)
			_check("file exists %s" % suffix, FileAccess.file_exists(expected), expected)
			_check("file hash %s" % suffix,
				FileAccess.get_sha256(absolute) == EXPECTED_SHA256[suffix],
				{"expected": EXPECTED_SHA256[suffix], "actual": FileAccess.get_sha256(absolute)})
			var texture := load(expected) as Texture2D
			_check("texture is 256 square %s" % suffix,
				texture != null and texture.get_size() == Vector2(256, 256),
				texture.get_size() if texture != null else Vector2.ZERO)
			var frames: Array = art.unit_anim_frames(UNIT_KEY, state, direction, VARIANT)
			var actual := _source(frames[0]) if not frames.is_empty() else ""
			distinct_sources.append(actual)
			_check("exact Art source %s" % suffix,
				frames.size() == 1 and actual == expected,
				{"expected": expected, "actual": actual, "frames": frames.size()})
			_check("directional source flag %s" % suffix,
				art.unit_anim_uses_directional_source(UNIT_KEY, state, direction, VARIANT))
		_check("four sources distinct for %s" % state,
			distinct_sources.size() == 4 and distinct_sources[0] != distinct_sources[1]
			and distinct_sources[0] != distinct_sources[2] and distinct_sources[0] != distinct_sources[3]
			and distinct_sources[1] != distinct_sources[2] and distinct_sources[1] != distinct_sources[3]
			and distinct_sources[2] != distinct_sources[3], distinct_sources)


func _test_real_unit(art: Node) -> void:
	for direction in DIRECTIONS:
		var unit = _make_unit()
		unit.animation_direction = direction
		unit._move_blend = 0.0
		unit._lunge = 0.0
		unit._flinch = Vector2.ZERO
		var fallback: Texture2D = art.unit_texture(UNIT_KEY, VARIANT, direction)
		var idle: Texture2D = unit._anim_frame_for_state(fallback)
		var idle_expected := "res://assets/campaign/anim/%s_idle_%s.png" % [VARIANT, direction]
		_check("real Unit idle %s" % direction,
			idle != null and _source(idle) == idle_expected and unit._frame_directional,
			{"expected": idle_expected, "actual": _source(idle), "directional": unit._frame_directional})
		unit._move_blend = 1.0
		var walk: Texture2D = unit._anim_frame_for_state(fallback)
		var walk_expected := "res://assets/campaign/anim/%s_walk_%s.png" % [VARIANT, direction]
		_check("real Unit walk %s" % direction,
			walk != null and _source(walk) == walk_expected and unit._frame_directional,
			{"expected": walk_expected, "actual": _source(walk), "directional": unit._frame_directional})
		_check("real Unit remains noncombat %s" % direction, unit.is_noncombat)
		unit.queue_free()
		await process_frame


func _test_level_route() -> void:
	var level_source := FileAccess.get_file_as_string("res://scripts/levels/level6_yezhulin.gd")
	var variant_at := level_source.find('lin_freed.art_variant = "lin_chong_prisoner"')
	var noncombat_at := level_source.find("lin_freed.is_noncombat = true")
	_check("level6 assigns exact prisoner variant", variant_at >= 0, variant_at)
	_check("level6 marks prisoner noncombat", noncombat_at > variant_at,
		{"variant_offset": variant_at, "noncombat_offset": noncombat_at})
	_check("level6 later isolates bound variant", 'lin_bound.art_variant = "lin_chong_bound"' in level_source)
	_check("level6 later isolates escort variant", 'lin_freed.art_variant = "lin_chong_escort"' in level_source)


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"kind": "lin_chong_prisoner_direction4_production_runtime",
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"scope": "lin_chong_prisoner idle/walk x four directions and real level6 noncombat route",
		"excluded": ["lin_chong_bound", "lin_chong_escort", "assisted", "attack", "hurt", "down"],
		"results": checks,
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")


func _run() -> void:
	await process_frame
	unit_script = load("res://scripts/unit.gd")
	var defs_script = load("res://scripts/defs.gd")
	var scripts_ok: bool = unit_script != null and defs_script != null \
		and unit_script.can_instantiate() and defs_script.can_instantiate()
	_check("Unit and Defs instantiate", scripts_ok)
	if not scripts_ok:
		_write_report()
		quit(1)
		return
	definitions = defs_script.UNITS
	_check("Lin Chong definition exists", definitions.has(UNIT_KEY))
	var art := root.get_node("Art")
	_clear_cache(art)
	_test_files(art)
	await _test_real_unit(art)
	_test_level_route()
	_write_report()
	for autoload_name in ["Sfx", "Music"]:
		var audio_root := root.get_node_or_null(autoload_name)
		if audio_root != null:
			audio_root.set("enabled", false)
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
