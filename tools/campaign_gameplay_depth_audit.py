from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "campaign_gameplay_depth_20260901"
REPORT = QA / "final_regression" / "report.json"
DETERMINISM = QA / "finale_determinism" / "determinism_report.json"
OUT = QA / "verification_index.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def runtime_manifest() -> dict[str, str]:
    paths = [ROOT / "project.godot"]
    paths += list((ROOT / "scripts").rglob("*.gd"))
    paths += list((ROOT / "scenes").rglob("*.tscn"))
    for folder in ("anim", "objects", "portraits"):
        paths += list((ROOT / "assets" / "campaign" / folder).glob("*.png"))
    return {
        path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(paths)
    }


def main() -> int:
    failures: list[str] = []
    if not REPORT.is_file():
        failures.append("missing final regression report")
        report: dict = {}
    else:
        report = json.loads(REPORT.read_text(encoding="utf-8"))
    if not DETERMINISM.is_file():
        failures.append("missing finale determinism report")
        determinism: dict = {}
    else:
        determinism = json.loads(DETERMINISM.read_text(encoding="utf-8"))

    results = report.get("results", [])
    current_runtime = runtime_manifest()
    if report.get("passed") is not True:
        failures.append("final regression did not pass")
    if len(results) != 18 or not all(row.get("passed") is True for row in results):
        failures.append("expected 18 passing regression jobs")
    if report.get("runtime") != current_runtime:
        failures.append("current runtime differs from final regression manifest")
    if determinism.get("passed") is not True or len(determinism.get("rounds", [])) != 2:
        failures.append("finale determinism proof is incomplete")
    elif not all(row.get("passed") is True for row in determinism["rounds"]):
        failures.append("a finale determinism round failed")

    docs = [
        ROOT / "docs" / "CAMPAIGN_GAMEPLAY_DEPTH_20260901.md",
        ROOT / "docs" / "CAMPAIGN_IMPLEMENTATION.md",
        ROOT / "docs" / "CAMPAIGN_PACING.md",
        ROOT / "docs" / "WEB_CHATGPT_ART_DELIVERY.md",
        ROOT / "README.md",
        ROOT.parent / "SOURCE_SETUP.md",
        ROOT.parent / "WORKLOG.md",
    ]
    missing_docs = [str(path) for path in docs if not path.is_file()]
    if missing_docs:
        failures.extend(f"missing record: {path}" for path in missing_docs)

    index = {
        "passed": not failures,
        "failures": failures,
        "final_regression": {
            "path": REPORT.relative_to(ROOT).as_posix(),
            "sha256": sha256(REPORT) if REPORT.is_file() else "",
            "jobs": len(results),
            "all_jobs_passed": bool(results) and all(row.get("passed") is True for row in results),
            "runtime_files": len(current_runtime),
            "runtime_matches_report": report.get("runtime") == current_runtime,
            "jobs_with_warnings": [row.get("name") for row in results if row.get("warnings")],
        },
        "finale_determinism": {
            "path": DETERMINISM.relative_to(ROOT).as_posix(),
            "sha256": sha256(DETERMINISM) if DETERMINISM.is_file() else "",
            "rounds": len(determinism.get("rounds", [])),
            "passed": determinism.get("passed") is True,
        },
        "records": {
            path.relative_to(ROOT.parent).as_posix(): sha256(path)
            for path in docs
            if path.is_file()
        },
        "baselines": [
            "qa/campaign_gameplay_depth_20260901/baseline",
            "qa/campaign_gameplay_depth_20260901/baseline_batch2",
            "qa/campaign_gameplay_depth_20260901/baseline_tutorial",
        ],
        "scope": (
            "Current runtime hashes, 18 authored automated jobs, two fixed-fps finale "
            "determinism rounds, and record-file receipts. Not human play, visual QA, "
            "15-25 minute pacing, performance, memory health, export, or Steam state."
        ),
    }
    OUT.write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    print("[campaign-depth-audit]", json.dumps(index, ensure_ascii=False))
    return 0 if index["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
