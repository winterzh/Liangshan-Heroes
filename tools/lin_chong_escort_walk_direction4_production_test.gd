extends SceneTree
## Targeted production contract for Lin Chong's post-untie cangue walk.
## Scope is walk x four directions x four frames and the real level-6 route.

const VARIANT := "lin_chong_escort"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const REPORT := "res://qa/lin_chong_escort_walk_direction4_production_20260902/runtime_report.json"
const EXPECTED_SHA256 := {
	"se": "78a32ca90a885943140171f415b227e6a1374738554f6bef0ef3d97b622b00e6",
	"sw": "03750bf202c10c7f342d1956c408477eb3a83e942a004ff29673293a207f2c46",
	"ne": "2c1787d8ed6e55602229473eb67f73c7866520e5aea12e3646707021a5c579be",
	"nw": "717ed94c409576527521d82f96ce5e5ae3e3d10d478da94d1ea0df4ad53d52ba",
}

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var unit_script
var definitions: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lin-chong-escort-walk] ", "PASS " if passed else "FAIL ", name,
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
	unit.setup("lin_chong", definitions["lin_chong"], 0, null, null)
	unit.art_variant = VARIANT
	unit.is_noncombat = true
	root.add_child(unit)
	unit.set_process(false)
	unit.set_physics_process(false)
	return unit


func _run() -> void:
	await process_frame
	unit_script = load("res://scripts/unit.gd")
	var defs_script = load("res://scripts/defs.gd")
	var scripts_ok: bool = unit_script != null and defs_script != null and unit_script.can_instantiate() and defs_script.can_instantiate()
	_check("Unit and Defs instantiate", scripts_ok)
	if not scripts_ok:
		_finish()
		return
	definitions = defs_script.UNITS
	var art := root.get_node("Art")
	var sources: Array[String] = []
	for direction in DIRECTIONS:
		var expected := "res://assets/campaign/anim/lin_chong_escort_walk_%s.png" % direction
		var absolute := ProjectSettings.globalize_path(expected)
		_check("file exists %s" % direction, FileAccess.file_exists(expected), expected)
		var actual_hash := FileAccess.get_sha256(absolute)
		_check("file hash %s" % direction, actual_hash == EXPECTED_SHA256[direction], {
			"actual": actual_hash,
			"expected": EXPECTED_SHA256[direction],
		})
		var strip := load(expected) as Texture2D
		_check("strip is 1024x256 %s" % direction,
			strip != null and strip.get_size() == Vector2(1024, 256),
			strip.get_size() if strip != null else Vector2.ZERO)
		var frames: Array = art.unit_anim_frames("lin_chong", "walk", direction, VARIANT)
		var exact := frames.size() == 4
		var regions: Array = []
		for frame_index in range(frames.size()):
			var frame = frames[frame_index]
			var region: Rect2 = frame.region if frame is AtlasTexture else Rect2()
			regions.append(str(region))
			exact = exact and _source(frame) == expected and region == Rect2(frame_index * 256, 0, 256, 256)
		_check("Art slices four exact ordered frames %s" % direction, exact, {
			"source": _source(frames[0]) if not frames.is_empty() else "",
			"expected": expected,
			"frames": frames.size(),
			"regions": regions,
		})
		_check("directional source flag %s" % direction,
			art.unit_anim_uses_directional_source("lin_chong", "walk", direction, VARIANT))
		sources.append(_source(frames[0]) if not frames.is_empty() else "")

		var unit = _make_unit()
		unit.animation_direction = direction
		unit._move_blend = 1.0
		unit._lunge = 0.0
		unit._flinch = Vector2.ZERO
		var fallback: Texture2D = art.unit_texture("lin_chong", VARIANT, direction)
		var selected_all := true
		var selected_regions: Array = []
		for frame_index in range(4):
			unit._anim_t = TAU * (float(frame_index) + 0.1) / 4.0
			var selected: Texture2D = unit._anim_frame_for_state(fallback)
			var selected_region: Rect2 = selected.region if selected is AtlasTexture else Rect2()
			selected_regions.append(str(selected_region))
			selected_all = selected_all and _source(selected) == expected \
				and selected_region == Rect2(frame_index * 256, 0, 256, 256) and unit._frame_directional
		_check("real Unit cycles exact four walk frames %s" % direction, selected_all, selected_regions)
		_check("real Unit remains noncombat %s" % direction, unit.is_noncombat)
		unit.queue_free()
		await process_frame
	_check("four walk strip sources remain distinct", sources.size() == 4 and sources.duplicate().all(func(source): return sources.count(source) == 1), sources)

	var level_source := FileAccess.get_file_as_string("res://scripts/levels/level6_yezhulin.gd")
	var escort_at := level_source.find('lin_freed.art_variant = "lin_chong_escort"')
	var untie_at := level_source.find('"untie":')
	_check("level6 assigns escort variant after untie", untie_at >= 0 and escort_at > untie_at, {
		"untie_offset": untie_at,
		"escort_variant_offset": escort_at,
	})
	_check("level6 retains injured slow walk", "lin_freed.apply_slow(0.7, 999.0)" in level_source)
	_check("level6 keeps the injured solo walk because the two guards, not Lu, support Lin", 
		'lin_freed.set_meta("story_pose", "assisted")' not in level_source \
			and 'lin_freed.set_meta("story_pose", "")' in level_source)
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "lin_chong_escort walk x four directions x four ordered frames and real level6 post-untie route",
		"excluded": ["idle", "attack", "hurt", "down", "assisted", "lin_chong_prisoner", "lin_chong_bound"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
