extends SceneTree
## Runtime proof for the native Zhu Zhaofeng idle-only atlas. It does not infer action states.
const DIRS := ["se", "sw", "ne", "nw"]
const SOURCE := "res://assets/characters/art_full_20260915/zhu_zhaofeng_direction4.png"
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
	output = OS.get_environment("ZHU_ZHAOFENG_IDLE_OUT")
	if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	check(not image.is_empty(), "native source loads")
	if not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		check(image.get_width() == 1254 and image.get_height() == 1254, "native source size 1254x1254")
		check(image.get_pixel(0, 0).a == 0.0, "transparent gutter remains alpha zero")
		check(image.get_pixel(313, 307).a > 0.0, "SE source contains visible body")
	var art = root.get_node("Art")
	var portrait = art.portrait_texture("zhu_zhaofeng")
	check(portrait != null, "matching portrait resolves")
	if portrait != null:
		check(portrait.resource_path == "res://assets/characters/art_full_20260915/zhu_zhaofeng.png", "portrait uses same-source crop")
		check(portrait.get_width() == 400 and portrait.get_height() == 400, "portrait crop is 400x400")
	for direction in DIRS:
		var expected := "res://assets/anim/zhu_zhaofeng_idle_%s.tres" % direction
		var path: String = art._resolve_generic_directional_path("zhu_zhaofeng", "idle", direction)
		check(path == expected, "exact idle routing %s" % direction)
		var frames: Array = art.unit_anim_frames("zhu_zhaofeng", "idle", direction)
		check(frames.size() == 1, "one idle frame %s" % direction)
		if frames.size() == 1:
			var frame = frames[0]
			check(frame is AtlasTexture, "AtlasTexture %s" % direction)
			if frame is AtlasTexture:
				check(frame.get_width() == frame.get_height() and frame.get_width() == 768, "square virtual frame %s" % direction)
				check(frame.atlas.resource_path == SOURCE, "native source bound %s" % direction)
				var expected_x := 0 if direction in ["se", "ne"] else 627
				var expected_y := 0 if direction in ["se", "sw"] else 627
				check(frame.region == Rect2(expected_x, expected_y, 627, 627), "fixed cell %s" % direction)
				check(frame.margin == Rect2(70, 0, 141, 141), "ground padding %s" % direction)
				check(frame.filter_clip, "filter clipping %s" % direction)
				check(bool(frame.get_meta("authored_direction4", false)), "authored direction metadata %s" % direction)
		check(art.unit_anim_uses_directional_source("zhu_zhaofeng", "idle", direction), "idle is not mirrored %s" % direction)
		check(art.unit_anim_frames("zhu_zhaofeng", "death", direction).is_empty(), "death remains unclaimed %s" % direction)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "character": "zhu_zhaofeng", "scope": "Runtime idle-only route; walk/attack/hurt/death remain open and are not inferred."}
	FileAccess.open(output.path_join("runtime.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("ZHU_ZHAOFENG_IDLE_RUNTIME ", checks.size(), " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
