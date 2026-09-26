"""Derive an honest art backlog from one completed frozen Godot inventory.

Counts exact generic direction sources, not artistic quality, gameplay acceptance
or separate campaign variants. Keeps every missing state/direction explicit.
"""
import argparse
import hashlib
import json
from pathlib import Path

STATES = ("idle", "walk", "attack", "hurt", "death")
DIRECTIONS = ("se", "sw", "ne", "nw")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(evidence):
    receipt_path = evidence / "receipt.json"
    report_path = evidence / "inventory/report.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if not receipt["complete"] or not report["passed"] or report["failures"]:
        raise ValueError("A completed passing inventory is required")
    declared = {r["path"]: r["sha256"] for r in receipt["artifacts"]}
    if declared.get("inventory/report.json") != digest(report_path):
        raise ValueError("Inventory report differs from its frozen receipt")
    units = report["units"]
    rows = []
    for unit in units:
        if unit["building"] or unit["resource"]:
            continue
        missing = {state: [d for d in DIRECTIONS if not unit["states"][state][d]["exact_frames"]]
                   for state in STATES}
        rows.append({"key": unit["key"], "name": unit["name"], "hero": unit["hero"],
                     "missing_directions": missing,
                     "complete_source_states": [s for s in STATES if not missing[s]],
                     "visual_review": "pending; source coverage alone is not acceptance"})
    return {
        "schema": 1,
        "scope": "Generic source coverage only. Campaign variants, pose quality, portrait alignment, UI roles and world readability need separate review.",
        "receipt_sha256": digest(receipt_path), "report_sha256": digest(report_path),
        "source_count": len(receipt["source_files"]), "checks": len(report["checks"]),
        "definitions": len(units), "mobile_definitions": len(rows),
        "environment_route_states": len(report["environment"]), "screenshots": len(report["screenshots"]),
        "four_direction_source_counts": {s: sum(s in r["complete_source_states"] for r in rows) for s in STATES},
        "all_five_states_source_complete": [r["key"] for r in rows if len(r["complete_source_states"]) == 5],
        "missing_avatar": [u["key"] for u in units if not u["avatar"]],
        "missing_mobile_body": [u["key"] for u in units if not u["building"] and not u["resource"] and not u["body"]],
        "units": rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = summarize(args.evidence)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "units"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
