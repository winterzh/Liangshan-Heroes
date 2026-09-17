extends SceneTree
## Runtime route and visual calibration contract for the Liangshan tree batch.
const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
const TARGETS := {
    "tree_broad": {"path":"res://assets/campaign/environment/level5/tree_broad.png", "bbox":[115,119,426,416]},
    "tree_young": {"path":"res://assets/campaign/environment/level5/tree_young.png", "bbox":[120,132,355,408]},
    "willow_old": {"path":"res://assets/campaign/environment/level5/willow_old.png", "bbox":[120,107,407,392]},
}
var checks: Array = []
func check(name: String, ok: bool, detail := "") -> void:
    checks.append({"name":name,"passed":ok,"detail":detail})
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    for key in TARGETS:
        var expected: Dictionary = TARGETS[key]
        var tex = EnvironmentArt.object("level5", key)
        check(key+" scoped texture", tex is Texture2D, str(tex))
        check(key+" exact source", tex is Texture2D and tex.resource_path == expected.path, tex.resource_path if tex is Texture2D else "")
        var metrics: Dictionary = EnvironmentArt.calibrated_visual_metrics("object", "level5", key)
        check(key+" calibration present", not metrics.is_empty(), str(metrics))
        check(key+" calibrated bbox", metrics.get("visible_bbox_xywh",[]) == expected.bbox, str(metrics.get("visible_bbox_xywh",[])))
        check(key+" out-of-scope rejected", EnvironmentArt.object("level1", key) == null)
    var report_path := OS.get_environment("LIANGSHAN_TREES_RUNTIME_REPORT")
    if report_path.is_empty(): report_path = "res://scratchpad/liangshan_trees_runtime.json"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
    var report = {"schema":"liangshan_trees_runtime_contract_v1","passed":checks.all(func(x): return bool(x.passed)),"checks":checks}
    var f=FileAccess.open(report_path,FileAccess.WRITE); if f!=null: f.store_string(JSON.stringify(report,"\t")+"\n")
    print("LIANGSHAN_TREES_RUNTIME ", checks.filter(func(x): return bool(x.passed)).size(), "/", checks.size(), " ", "PASS" if report.passed else "FAIL")
    quit(0 if report.passed else 1)
