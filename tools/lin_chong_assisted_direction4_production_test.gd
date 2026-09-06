extends SceneTree
## Targeted production contract for the level-6 Lin Chong/Lu Zhishen pair.
## Scope is assisted x four directions x four frames and its exact story gate.

const VARIANT := "lin_chong_escort"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const REPORT := "res://qa/lin_chong_assisted_direction4_production_20260903/runtime_report.json"
const EXPECTED_SHA256 := {
	"se": "a21382f76440a99dd3c5f32178450dd567e181609ddca47380b60e8fa78c3d40",
	"sw": "89657dafde8c2d2328cfe19dbc39a9d434bd2f1d4ecf20cc6b8ee63e0015eb6a",
	"ne": "5449709300c614c7c60fdc2a82ac9ef6ddff7358fef8616faf9db27ba2508082",
	"nw": "a9ba18bf83f7fce072416bc941a5c71f0c7e1da5167fdb6520311963b67e553d",
}

var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, passed: bool, detail = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[lin-chong-assisted] ", "PASS " if passed else "FAIL ", name,
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
		var expected := "res://assets/campaign/anim/lin_chong_escort_assisted_%s.png" % direction
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
		var frames: Array = art.unit_anim_frames("lin_chong", "assisted", direction, VARIANT)
		var exact := frames.size() == 4
		var regions: Array = []
		for frame_index in range(frames.size()):
			var frame = frames[frame_index]
			var region: Rect2 = frame.region if frame is AtlasTexture else Rect2()
			regions.append(str(region))
			exact = exact and _source(frame) == expected and region == Rect2(frame_index * 256, 0, 256, 256)
		_check("Art slices four exact ordered assisted frames %s" % direction, exact, {
			"source": _source(frames[0]) if not frames.is_empty() else "",
			"frames": frames.size(),
			"regions": regions,
		})
		_check("directional source flag %s" % direction,
			art.unit_anim_uses_directional_source("lin_chong", "assisted", direction, VARIANT))
		sources.append(_source(frames[0]) if not frames.is_empty() else "")
	_check("four assisted strip sources remain distinct",
		sources.size() == 4 and sources.duplicate().all(func(source): return sources.count(source) == 1), sources)

	var unit_source := FileAccess.get_file_as_string("res://scripts/unit.gd")
	_check("assisted gate requires exact escort variant and story pose",
		'art_variant!="lin_chong_escort"' in unit_source and 'String(get_meta("story_pose",""))!="assisted"' in unit_source)
	_check("assisted gate requires a living nearby helper",
		"story_assist_partner.hp<=0.0" in unit_source and "position.distance_to(story_assist_partner.position)>70.0" in unit_source)
	_check("assisted gate requires exact assisted animation availability",
		'campaign_variant_has_animation",art_variant,"assisted",animation_direction' in unit_source)
	_check("real Unit selects assisted before ordinary walk",
		"if story_assistance_active():" in unit_source and unit_source.find("if story_assistance_active():") < unit_source.find('var state := "walk" if moving else "idle"'))

	var level_source := FileAccess.get_file_as_string("res://scripts/levels/level6_yezhulin.gd")
	var tend_at := level_source.find('"tend_feet":')
	var pose_at := level_source.find('lin_freed.set_meta("story_pose", "assisted")')
	var clear_at := level_source.find('lin_freed.set_meta("story_pose", "")')
	_check("level6 retains assisted asset but disables the non-original Lu-support pose", 
		tend_at >= 0 and pose_at < 0 and clear_at > tend_at \
			and "lin_freed.story_assist_partner = null" in level_source, {
		"tend_feet_offset": tend_at,
		"assisted_pose_offset": pose_at,
		"clear_pose_offset": clear_at,
	})
	_finish()


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var report := {
		"passed": failures.is_empty(),
		"checks": checks.size(),
		"failures": failures,
		"results": checks,
		"scope": "lin_chong_escort assisted asset x four directions x four ordered frames; original-faithful level6 runtime keeps it disabled",
		"excluded": ["idle", "walk", "attack", "hurt", "down", "portrait", "mission progression", "human playtest"],
	}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for unused in range(3):
		await process_frame
	quit(0 if failures.is_empty() else 1)
