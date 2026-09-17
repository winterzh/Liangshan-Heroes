"""Verify this feedback fix against current sources and its separate QA receipts."""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gameplay", type=Path, required=True)
    parser.add_argument("--component", type=Path, required=True)
    parser.add_argument("--world", type=Path, required=True)
    parser.add_argument("--classic", type=Path, required=True)
    args = parser.parse_args()
    result = {"passed": True, "scope": "Huangnigang feedback, not full-suite or Steam acceptance", "batches": {}}
    for key in ("gameplay", "component", "world", "classic"):
        folder = getattr(args, key).resolve()
        receipt = read(folder / "receipt.json")
        changed = [r["path"] for r in receipt["source_files"]
                   if not (ROOT / r["path"]).is_file() or sha(ROOT / r["path"]) != r["sha256"]]
        row = {"receipt": (folder / "receipt.json").relative_to(ROOT).as_posix(),
               "receipt_sha256": sha(folder / "receipt.json"),
               "complete": receipt.get("complete", False), "source_count": len(receipt["source_files"]),
               "changed_sources": changed, "checks": receipt.get("checks"), "lock_released": receipt.get("lock_released")}
        artifacts = receipt.get("artifacts", receipt.get("files", receipt.get("screenshots", [])))
        artifact_root = folder / "screenshots" if key == "classic" else folder
        bad_artifacts = []
        for artifact in artifacts:
            path = (artifact_root / artifact["path"]).resolve()
            if not path.is_relative_to(folder) or not path.is_file() or sha(path) != artifact["sha256"]:
                bad_artifacts.append(artifact["path"])
        row.update(artifact_hashes_checked=len(artifacts), bad_artifacts=bad_artifacts)
        result["passed"] &= not bad_artifacts
        if key == "component":
            report = read(folder / "report.json")
            row["component_report_sha256"] = sha(folder / "report.json")
            result["passed"] &= report["passed"] and len(report["checks"]) == receipt["checks"] and all(c["passed"] for c in report["checks"])
        if key == "world":
            row.update(total_checks=receipt["total_checks"], full_suite=receipt["full_suite"],
                       acceptance_complete=receipt["acceptance_complete"],
                       protected_player_unchanged=receipt["protected_player_unchanged"])
            result["passed"] &= row["protected_player_unchanged"]
        result["batches"][key] = row
        result["passed"] &= row["complete"] and not changed and row["lock_released"] is not False

    result["shared_lock_free_at_verification"] = not (ROOT / ".godot/redraw_rejection_source.lock").exists()
    result["passed"] &= result["shared_lock_free_at_verification"]

    reports = list(args.gameplay.rglob("report.json"))
    arrival = next(read(p) for p in reports if "convoy_stability" in read(p))
    short = next(read(p) for p in reports if "cases" in read(p) and "convoy_stability" not in read(p))
    result["gameplay"] = {"arrival_checks": arrival["checks"], "arrival_failures": arrival["failures"],
                          "short_checks": short["checks"], "short_failures": short["failures"],
                          "stability": [{"label": r["label"], "duration": r["duration"], "max_drift": r["max_drift"],
                                         "min_distance": min(s["min_distance"] for s in r["samples"])}
                                        for r in arrival["convoy_stability"]],
                          "takeover_stop_max_drift": arrival["takeover_live"]["stop_max_drift"]}
    result["passed"] &= arrival["passed"] and short["passed"]
    # Also assess the original screenshot's later phase: Yang returns while Bai
    # is walking in. This derives from real sampled positions, never target cells.
    later = [r for r in arrival["trace"] if r["stage"] == 3 and len(r["convoy"]) == 15]
    if later:
        radii = {r["id"]: r["radius"] for r in arrival["convoy_stability"][0]["samples"][0]["members"]}
        minimum = math.inf
        for sample in later:
            people = sample["convoy"]
            for i, person in enumerate(people):
                for other in people[:i]:
                    minimum = min(minimum, math.dist(person["position"], other["position"]) - radii[person["id"]] - radii[other["id"]])
        result["gameplay"]["after_answer_observation"] = {"samples": len(later), "min_body_clearance": minimum,
                                                         "includes_Yang_returning": True}
    locale = read(HERE / "localization/scope_validation.json")
    result["localization"] = {k: locale[k] for k in ["added_source_keys", "translated_target_strings_added", "strict_build_exit_code", "level1_missing_count", "global_missing_count", "global_require_complete_exit_code"]}
    result["passed"] &= locale["strict_build_exit_code"] == 0 and locale["level1_missing_count"] == 0
    (HERE / "validation_summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
