extends SceneTree

## Runtime-only check for the four Liangshan waterline reed variants.
## It proves that the level-scoped resolver loads the intended 512px textures
## and returns the source-SHA-bound calibration used by the scene.

const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
const EXPECTED := {
	"reeds_short": {"sha": "eacb9d862c1d2d6aafc474290470fb01df13426b85bd8be56f787d4f0e5470e7", "bbox": [115,145,505,366]},
	"reeds_tall": {"sha": "96913721db6412806a37841a24e2c4ed18dedca49b44aaf90bde55dba994c885", "bbox": [129,105,434,405]},
	"reeds_bent": {"sha": "9632aec3e7634cc15456ceb9a40fcf247cc2b294583e252df9f9918e1091fb5f", "bbox": [95,139,325,366]},
	"reeds_seeded": {"sha": "40e9817c206cdabea9c092759a5215c579277966262e33e28bda17fb3ff217c9", "bbox": [121,104,445,403]},
}
var checks: Array = []

func check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	if not passed:
		push_error("[liangshan-reeds] %s: %s" % [name, str(detail)])

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for key in EXPECTED:
		var row: Dictionary = EXPECTED[key]
		var path := EnvironmentArt.route_path("object", "level5", key, "default")
		check("%s/path" % key, path.ends_with("/level5/%s.png" % key), path)
		var texture := EnvironmentArt.object("level5", key, "default")
		check("%s/resource" % key, texture != null, path)
		if texture != null:
			check("%s/size" % key, texture.get_width() == 512 and texture.get_height() == 512,
				[texture.get_width(), texture.get_height()])
		var metrics := EnvironmentArt.calibrated_visual_metrics("object", "level5", key)
		check("%s/calibration_sha" % key, String(metrics.get("source_sha256", "")) == row.sha, metrics)
		check("%s/calibration_bbox" % key, metrics.get("visible_bbox_xywh", []) == row.bbox, metrics)
		check("%s/out_of_scope" % key,
			EnvironmentArt.object("level1", key, "default") == null
			and EnvironmentArt.calibrated_visual_metrics("object", "level1", key).is_empty())
	var passed := checks.all(func(item): return bool(item.passed))
	var report := {"schema": "liangshan_reeds_runtime_contract_v1", "passed": passed,
		"checks": checks.size(), "results": checks}
	var report_path := OS.get_environment("LIANGSHAN_REEDS_RUNTIME_OUT")
	if report_path.is_empty():
		report_path = "res://scratchpad/liangshan_reeds_runtime_contract.json"
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("[liangshan-reeds] %d/%d %s" % [checks.filter(func(item): return bool(item.passed)).size(), checks.size(), "PASS" if passed else "FAIL"])
	quit(0 if passed else 1)
