"""Read-only original persistence-19 plan and named-source binding, never execution."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
BASE_REL = ".godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab"
SOURCE_SHA = "b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132"
MATRIX_REL = "qa/zhu_wounded_20261005/proposals/campaign_persistence_observability_v27/FAULT_MATRIX_V27B.json"
RECEIPT_REL = "qa/campaign_persistence_faults_20261008/actual_matrix_v4/receipt.json"
SEAL_REL = "qa/campaign_persistence_faults_20261008/matrix_source_preflight_v4.json"
SOURCE_SCHEMA = "persistence19_named_plan_sources_v1"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def fs(path):
    absolute = os.path.abspath(os.fspath(path))
    if os.name != "nt" or absolute.startswith("\\\\?\\"):
        return Path(absolute)
    return Path("\\\\?\\UNC\\" + absolute[2:] if absolute.startswith("\\\\") else "\\\\?\\" + absolute)


def named_file(relative):
    require(isinstance(relative, str) and relative and "\\" not in relative, "Canonical relative source path required")
    part = Path(relative)
    require(not part.is_absolute() and not part.drive and all(x not in {".", ".."} for x in relative.split("/")), "Source path must stay inside repository")
    path = ROOT / part
    for cursor in (path, *path.parents):
        status = fs(cursor).lstat()
        require(not stat.S_ISLNK(status.st_mode) and not (getattr(status, "st_file_attributes", 0) & 0x400), "Reparse source refused: " + str(cursor))
        if cursor == ROOT:
            break
    require(fs(path).is_file(), "Named source is not a file: " + relative)
    return path


def raw(relative):
    return fs(named_file(relative)).read_bytes()


def read_json(relative):
    return json.loads(raw(relative).decode("utf-8"))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect_plan():
    sources = json.loads(fs(HERE / "sources.json").read_text(encoding="utf-8"))
    require(sources.get("schema") == SOURCE_SCHEMA, "Named plan source schema")
    rows = sources.get("files", [])
    require(isinstance(rows, list) and rows, "Named source rows required")
    pins = {}
    for row in rows:
        require(set(row) == {"path", "bytes", "sha256", "role"}, "Exact source row fields")
        require(row["path"] not in pins, "Duplicate named path")
        data = raw(row["path"])
        require(len(data) == row["bytes"] and digest(data) == row["sha256"], "Named source changed: " + row["path"])
        pins[row["path"]] = row["sha256"]
    prefix = HERE.relative_to(ROOT).as_posix()
    required = {MATRIX_REL, RECEIPT_REL, SEAL_REL, prefix + "/README.md", prefix + "/cases.json", prefix + "/plan_persistence19.py"}
    require(required.issubset(pins), "Core plan sources not sealed")
    plan = read_json(prefix + "/cases.json")
    require(plan.get("schema") == "persistence19_b22_adaptation_plan_v1", "Plan schema")
    require(plan.get("base_run") == BASE_REL and plan.get("source_sha256") == SOURCE_SHA, "Fixed b22 plan identity")
    require(plan.get("worker_implemented") is True and plan.get("native_executed") is False, "Worker source is implemented but not executed")
    old = read_json(MATRIX_REL)
    cases = plan["cases"]
    require(len(cases) == old["case_count"] == 19, "Exactly original nineteen cases")
    require([x["id"] for x in cases] == [x["id"] for x in old["cases"]], "Original case order")
    for index, (case, original) in enumerate(zip(cases, old["cases"])):
        require(case["index"] == index and case["old_expected"] == original["expected"], "Original expected values changed")
        require(case["status"] == "current_protocol_mapped_unexecuted" and case["oracle_version"] == "b22_synthetic_component_v2", "Explicit current non-passing migration oracle required")
        require(case.get("passed") is None and case.get("native_executed") is False, "Plan cannot be a result")
    historical = read_json(RECEIPT_REL)
    report = historical["report"]
    require(historical.get("complete") is True and historical.get("component_matrix_qualified") is True, "Historical V4 qualification")
    require(historical.get("process_terminal") is True and historical.get("lock_released") is True, "Historical terminal/lock")
    require(historical.get("pid") == report.get("pid") == 43016 and historical.get("exit_code") == 0, "Historical actual process")
    require(report.get("checks") == 194 and report.get("failures") == [] and report.get("complete") is True, "Historical global checks")
    require([x["id"] for x in report["cases"]] == [x["id"] for x in cases] and all(x.get("complete") is True for x in report["cases"]), "Historical nineteen exact cases")
    seal = read_json(SEAL_REL)
    require(seal.get("complete") is True and seal.get("original_ids") == [x["id"] for x in cases], "Historical seven-file seal")
    for row in seal["files"]:
        require(pins.get(row["path"]) == row["sha256"], "Historical helper/worker byte identity changed")
    generation = read_json(BASE_REL + "/generation.json")
    expected = read_json(BASE_REL + "/expected_identity.json")
    identity = generation["identity"]
    require(identity["source_sha256"] == SOURCE_SHA, "Generation source identity")
    require({k: v for k, v in identity.items() if k not in {"files", "directories"}} == expected, "Generation/expected metadata mismatch")
    manifest = read_json(BASE_REL + "/candidate_manifest.json")
    require(manifest.get("schema") == "projectile_3365_integrated_manifest_v1" and len(manifest["files"]) == 26 and len(manifest["native_assets"]) == 1, "Current integrated manifest 26+1")
    file_rows = {x["path"]: x for x in identity["files"]}
    require(len(file_rows) == identity["file_count"] == 7062, "Generation inventory count")
    project_prefix = BASE_REL + "/project/"
    for row in rows:
        if row["role"] == "current_runtime":
            require(row["path"].startswith(project_prefix), "Runtime must be the actual new freeze")
            relative = row["path"][len(project_prefix):]
            require(relative in file_rows and file_rows[relative]["sha256"] == row["sha256"] and file_rows[relative]["bytes"] == row["bytes"], "Named current runtime differs from generation")
    return {
        "schema": "persistence19_named_plan_check_v1", "named_source_plan_verified": True,
        "named_pins": len(pins), "source_sha256": SOURCE_SHA, "original_cases": 19,
        "historical_global_checks": 194, "historical_local_case_checks": sum(x["checks"] for x in report["cases"]),
        "full_source_verified": False, "new_protocol_proof": False, "worker_implemented": True,
        "native_executed": False, "native_qualified": False, "unresolved_cases": [],
        "historical_oracle_changes": [0, 1, 2, 3, 16, 17, 18],
        "cases": cases,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", help="Print one original case's migration plan; remains read-only")
    args = parser.parse_args()
    state = inspect_plan()
    if args.case:
        selected = [x for x in state["cases"] if x["id"] == args.case]
        require(len(selected) == 1, "Unknown original case ID")
        state["cases"] = selected
    else:
        state.pop("cases")
    print(json.dumps(state, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
