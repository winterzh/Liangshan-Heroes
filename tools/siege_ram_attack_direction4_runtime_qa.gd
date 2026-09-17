extends SceneTree
## Runtime proof for siege_ram wooden battering ram attack atlas.
const DIRS := ["se", "sw", "ne", "nw"]
const SOURCE := "res://assets/characters/art_full_20260916/siege_ram_attack_direction4.png"
var checks: Array = []
var failures: Array = []
func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
 checks.append({"name": label, "passed": ok})
 if not ok: failures.append(label)
func _run() -> void:
 var output := OS.get_environment("SIEGE_RAM_ATTACK_OUT")
 if output.is_empty() or OS.get_environment("STEAM_DISABLED") != "1": quit(2); return
 DirAccess.make_dir_recursive_absolute(output)
 var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
 check(not image.is_empty(), "production source loads")
 if not image.is_empty():
  image.convert(Image.FORMAT_RGBA8)
  check(image.get_width() == 2508 and image.get_height() == 2508, "production source size 2508x2508")
  check(image.get_pixel(0,0).a == 0.0, "transparent gutter remains alpha zero")
  check(image.get_pixel(313,313).a > 0.0, "SE attack source contains visible machine")
 var art = root.get_node("Art")
 for direction in DIRS:
  var expected := "res://assets/anim/siege_ram_attack_%s.tres" % direction
  var path: String = art._resolve_generic_directional_path("siege_ram", "attack", direction)
  check(path == expected, "exact attack routing %s" % direction)
  var frames: Array = art.unit_anim_frames("siege_ram", "attack", direction)
  check(frames.size() == 4, "four attack frames %s" % direction)
  for index in range(frames.size()):
   var frame = frames[index]
   check(frame is AtlasTexture, "AtlasTexture %s frame %d" % [direction,index])
   if frame is AtlasTexture:
    check(frame.get_width() == 768 and frame.get_height() == 768, "square virtual frame %s frame %d" % [direction,index])
    check(frame.atlas.resource_path == SOURCE, "native source bound %s frame %d" % [direction,index])
    check(frame.region == Rect2(index*627, DIRS.find(direction)*627, 627, 627), "fixed cell %s frame %d" % [direction,index])
    check(frame.margin == Rect2(70,0,141,141), "ground padding %s frame %d" % [direction,index])
    check(frame.filter_clip, "filter clipping %s frame %d" % [direction,index])
    check(bool(frame.get_meta("authored_direction4", false)), "authored direction metadata %s frame %d" % [direction,index])
  check(art.unit_anim_uses_directional_source("siege_ram", "attack", direction), "attack is not mirrored %s" % direction)
 var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "character": "siege_ram", "scope": "Runtime wooden battering ram attack-only route; existing idle/walk are unchanged."}
 FileAccess.open(output.path_join("runtime.json"), FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
 print("SIEGE_RAM_ATTACK_RUNTIME ", checks.size(), " checks; ", failures.size(), " failures")
 quit(0 if failures.is_empty() else 1)
