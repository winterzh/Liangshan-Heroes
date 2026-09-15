extends SceneTree
## Runtime proof for the native Zhu Zhaofeng walk-only atlas. It does not infer other states.
const DIRS := ["se", "sw", "ne", "nw"]
const SOURCE := "res://assets/characters/art_full_20260915/zhu_zhaofeng_walk_direction4.png"
var checks: Array = []
var failures: Array = []
var output := ""

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok:
		failures.append(label)

func _run() -> void:
	output = OS.get_environment("ZHU_ZHAOFENG_WALK_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	check(not image.is_empty(), "production source loads")
	if not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		check(image.get_width() == 2508 and image.get_height() == 2508, "production source size 2508x2508")
		check(image.get_pixel(0, 0).a == 0.0, "transparent gutter remains alpha zero")
		check(image.get_pixel(313, 313).a > 0.0, "SE walk source contains visible body")
	var art = root.get_node("Art")
	for direction in DIRS:
		var expected := "res://assets/anim/zhu_zhaofeng_walk_%s.tres" % direction
		var path: String = art._resolve_generic_directional_path("zhu_zhaofeng", "walk", direction)
		check(path == expected, "exact walk routing %s" % direction)
		var frames: Array = art.unit_anim_frames("zhu_zhaofeng", "walk", direction)
		check(frames.size() == 4, "four walk frames %s" % direction)
		for index in range(frames.size()):
			var frame = frames[index]
			check(frame is AtlasTexture, "AtlasTexture %s frame %d" % [direction, index])
			if frame is AtlasTexture:
				check(frame.get_width() == frame.get_height() and frame.get_width() == 768, "square virtual frame %s frame %d" % [direction, index])
				check(frame.atlas.resource_path == SOURCE, "native source bound %s frame %d" % [direction, index])
				var expected_x := index * 627
				var expected_y := DIRS.find(direction) * 627
				check(frame.region == Rect2(expected_x, expected_y, 627, 627), "fixed cell %s frame %d" % [direction, index])
				check(frame.margin == Rect2(70, 0, 141, 141), "ground padding %s frame %d" % [direction, index])
				check(frame.filter_clip, "filter clipping %s frame %d" % [direction, index])
				check(bool(frame.get_meta("authored_direction4", false)), "authored direction metadata %s frame %d" % [direction, index])
		check(art.unit_anim_uses_directional_source("zhu_zhaofeng", "walk", direction), "walk is not mirrored %s" % direction)
		check(art.unit_anim_frames("zhu_zhaofeng", "death", direction).is_empty(), "death remains unclaimed %s" % direction)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "character": "zhu_zhaofeng", "scope": "Runtime walk-only route; idle is separate and attack/hurt/death remain open and are not inferred."}
	FileAccess.open(output.path_join("runtime.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("ZHU_ZHAOFENG_WALK_RUNTIME ", checks.size(), " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
