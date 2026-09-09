"""Read-only verification of archived Huangnigang QA and its final input bytes.

Pass the final feedback receipt and the final Level-component receipt.
Earlier gameplay failures are preserved and checked for integrity, not success.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, "Duplicate JSON key: " + key
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("final_receipt", type=Path)
    parser.add_argument("component_receipt", type=Path)
    args = parser.parse_args()
    checked_artifacts = 0
    receipts = sorted(EVIDENCE.glob("*/receipt.json"))
    for path in receipts:
        receipt = json.loads(path.read_text(encoding="utf-8"))
        for row in receipt["artifacts"]:
            target = path.parent / row["path"]
            assert target.is_file() and sha(target) == row["sha256"], str(target)
            checked_artifacts += 1
        assert receipt["source_unchanged"] and receipt["lock_released"], str(path)
    current = json.loads(args.final_receipt.read_text(encoding="utf-8"))
    component = json.loads(args.component_receipt.read_text(encoding="utf-8"))
    assert current["complete"] and component["complete"]
    component_dir = args.component_receipt.parent
    component_hashes = {row["path"]: row["sha256"] for row in component["source_files"]}
    for path in (component_dir / "source_snapshot").rglob("*"):
        if not path.is_file():
            continue
        name = path.relative_to(component_dir / "source_snapshot").as_posix()
        expected = component["generated_scene_sha256"] if name == "campaign_level_state_qa.tscn" else component_hashes[name]
        assert sha(path) == expected, str(path)
        checked_artifacts += 1
    for row in component["steps"]:
        assert sha(component_dir / (row["name"] + ".log")) == row["log_sha256"]
        checked_artifacts += 1
    component_report = json.loads((component_dir / "report.json").read_text(encoding="utf-8"))
    assert component_report["passed"] and component_report["component_only"]
    assert len(component_report["checks"]) == component["checks"] and all(row["passed"] for row in component_report["checks"])
    assert {row["case"] for row in current["steps"]} == {"import", "arrival", "huangnigang", "zhu_contracts"}
    checked_sources = 0
    for receipt in [current, component]:
        for row in receipt["source_files"]:
            assert sha(ROOT / row["path"]) == row["sha256"], row["path"]
            checked_sources += 1
    arrival_path = args.final_receipt.parent / "results/.godot/huangnigang_arrival/all_rendered/report.json"
    route_path = args.final_receipt.parent / "results/.godot/huangnigang_short/all/report.json"
    arrival = json.loads(arrival_path.read_text(encoding="utf-8"))
    routes = json.loads(route_path.read_text(encoding="utf-8"))
    assert arrival["passed"] and routes["passed"]
    assert len(arrival["frames"]) == 8 and all(row["image_size"] == [1280, 720] for row in arrival["frames"])
    visual = json.loads((EVIDENCE / "visual_review.json").read_text(encoding="utf-8"))
    assert len(visual["frames"]) == 8 and all(row["reviewed"] and sha(EVIDENCE / row["file"]) == row["sha256"] for row in visual["frames"])
    assert {row["route"] for row in routes["cases"]} == {"wine", "force"}
    assert all(row["result"]["core_cleared"] for row in routes["cases"])
    catalog = json.loads((ROOT / "assets/localization/catalog.json").read_text(encoding="utf-8"), object_pairs_hook=unique_object)
    baseline = json.loads(subprocess.check_output(["git", "show", "0e9b48fc2fd9c0fe3e452f02d1033c58d2b70433:assets/localization/catalog.json"], cwd=ROOT).decode("utf-8"))
    assert all(catalog[key] == value for key, value in baseline.items())
    added = catalog.keys() - baseline.keys()
    assert len(added) == 24
    token = re.compile(r"%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdf]|\{[^{}]+\}")
    for key in added:
        for language in ["zh_TW", "en", "ja"]:
            translated = catalog[key][language]
            assert translated.strip() and token.findall(key) == token.findall(translated), (key, language)
    print(json.dumps({"passed": True, "receipts": len(receipts),
        "artifact_hashes_checked": checked_artifacts, "current_source_hashes_checked": checked_sources,
        "arrival_checks": arrival["checks"], "route_and_boundary_checks": routes["checks"],
        "level_component_checks": component["checks"], "frames": len(arrival["frames"]),
        "new_translation_keys": len(added), "new_translations": len(added) * 3,
        "scope": "Archived byte integrity and automated results; human visual review recorded separately."}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
