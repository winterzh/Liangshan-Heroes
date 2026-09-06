extends SceneTree
## Targeted production contract for the accepted level-6 static bound pose.
## Scope is idle x SE/SW/NE/NW and the real pine-tree binding route only.

const VARIANT := "lin_chong_bound"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const REPORT := "res://qa/lin_chong_bound_direction4_production_20260902/runtime_report.json"
const EXPECTED_SHA256 := {
	"idle_ne": "8929e61c02c3e0a0d087c8b1813a9f8c9d4f8b2affe553fa5006c4cc2d1819d8",
	"idle_nw": "257178b7d538069736f606749f4d428474d083ff6910e262815a7f3632b2d154",
	"idle_se": "cb58e5c5c9e41efd330b1735dcdf905fbacab55157ba18509382822a25ea2e39",
	"idle_sw": "853498999a66dff52bd43eb63c251203166bda1e2c6cf85cfcb92698e7a4f741",
}

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lin-chong-bound] ", "PASS " if passed else "FAIL ", name,
		"" if detail == null else " :: " + JSON.stringify(detail))
	if not passed:
		failures.append(name)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture is AtlasTexture and texture.atlas != null:
		return texture.atlas.resource_path
	return texture.resource_path


func _run() -> void:
	await process_frame
	var art := root.get_node("Art")
	var sources: Array[String] = []
	for direction in DIRECTIONS:
		var suffix := "idle_%s" % direction
		var expected := "res://assets/campaign/anim/%s_%s.png" % [VARIANT, suffix]
		var absolute := ProjectSettings.globalize_path(expected)
		_check("file exists %s" % suffix, FileAccess.file_exists(expected), expected)
		var actual_hash := FileAccess.get_sha256(absolute)
		_check("file hash %s" % suffix, actual_hash == EXPECTED_SHA256[suffix], {
			"actual": actual_hash,
			"expected": EXPECTED_SHA256[suffix],
		})
		var texture := load(expected) as Texture2D
		_check("texture is 256 square %s" % suffix,
			texture != null and texture.get_size() == Vector2(256, 256),
			texture.get_size() if texture != null else Vector2.ZERO)
		var frames: Array = art.unit_anim_frames("lin_chong", "idle", direction, VARIANT)
		var actual_source := _source(frames[0]) if not frames.is_empty() else ""
		sources.append(actual_source)
		_check("exact Art idle source %s" % direction,
			frames.size() == 1 and actual_source == expected,
			{"actual": actual_source, "expected": expected, "frames": frames.size()})
		_check("directional source flag %s" % direction,
			art.unit_anim_uses_directional_source("lin_chong", "idle", direction, VARIANT))
		var building_texture: Texture2D = art.unit_texture("lin_chong", VARIANT, direction)
		_check("bound building route selects exact idle %s" % direction,
			_source(building_texture) == expected,
			{"actual": _source(building_texture), "expected": expected})
	_check("four idle sources remain distinct", sources.size() == 4 and sources.duplicate().all(func(source): return sources.count(source) == 1), sources)

	var portrait := "res://assets/campaign/portraits/lin_chong_bound.png"
	_check("bound portrait matches accepted SE idle",
		FileAccess.get_sha256(ProjectSettings.globalize_path(portrait)) == EXPECTED_SHA256["idle_se"],
		FileAccess.get_sha256(ProjectSettings.globalize_path(portrait)))

	var level_source := FileAccess.get_file_as_string("res://scripts/levels/level6_yezhulin.gd")
	_check("level6 creates bound Lin Chong", 'spawn_unit("lin_chong_bound"' in level_source)
	_check("level6 assigns exact bound variant", 'lin_bound.art_variant = "lin_chong_bound"' in level_source)
	_check("level6 bound transition follows pine arrival", "position.distance_to(b.map.cell_to_world(PINE)) < 60.0" in level_source)
	var unit_source := FileAccess.get_file_as_string("res://scripts/unit.gd")
	_check("bound-person renderer strips bound key and preserves variant",
		'Art.unit_texture(key.trim_suffix("_bound"), art_variant, animation_direction)' in unit_source)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "lin_chong_bound idle x four directions, portrait and real level6 static pine-tree route",
		"excluded": ["walk", "attack", "hurt", "down", "lin_chong_prisoner", "lin_chong_escort", "assisted"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
