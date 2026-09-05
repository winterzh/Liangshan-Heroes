"""Audit environment routes, committed production bytes and missing provenance.

Exit 0: all gates complete; 1: material/provenance gaps; 2: invalid inputs,
route errors or byte drift. A route PASS alone never approves the artwork.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

import campaign_environment_art_static_contract as router_contract
from environment_validation_common import ROOT, MAPPING, MAPPING_SHA256, contained_path, report_target, sha256, write_report

INVENTORY = Path("tools/contracts/environment/inventory_20260906.json")
INVENTORY_SHA256 = "72453ce8cfb37f435582463bc7d97d69ca13967caef3adc493c3cc6bc95fec32"


def run(repo: Path, output: Path, inventory_path: Path | None = None) -> dict:
    repo = repo.resolve()
    if output.name == "router.json":
        raise ValueError("audit report must not use the reserved auxiliary router.json name")
    inventory_path = inventory_path or repo / INVENTORY
    if sha256(inventory_path) != INVENTORY_SHA256:
        raise ValueError("production inventory SHA256 mismatch; do not regenerate acceptance from the current files")
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    mapping_path = repo / MAPPING
    if sha256(mapping_path) != MAPPING_SHA256:
        raise ValueError("retained production mapping SHA256 mismatch")
    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    expected = [cell for batch in mapping["batches"] for cell in batch.get("cells", [batch])]
    entries = inventory["entries"]
    if len(entries) != 69 or len({e["path"] for e in entries}) != 69:
        raise ValueError("inventory must cover 69 distinct environment targets")
    by_id = {e["output_id"]: e for e in entries}
    for cell in expected:
        item = by_id[cell["output_id"]]
        for field in ("resolver", "route_key", "level_scope"):
            if item[field] != cell[field]:
                raise ValueError(f"inventory/mapping disagreement: {item['output_id']}:{field}")
        if item["path"] != cell["target"] or item["state"] != cell.get("state", "default"):
            raise ValueError(f"inventory/mapping path or state disagreement: {item['output_id']}")
    route_report = router_contract.run(repo, mapping_path, output.parent / "router.json")
    errors = []
    gaps = []
    results = []
    present = 0
    verified = 0
    for entry in entries:
        path = contained_path(repo, entry["path"])
        baseline = entry["production_baseline"]
        result = {"output_id": entry["output_id"], "path": entry["path"], "batch_id": entry["batch_id"],
                  "expected_sha256": baseline["sha256"], "actual_sha256": None, "production_status": "missing",
                  "source_status": "incomplete"}
        if not path.is_file():
            gaps.append({"code": "missing_production_png", "path": entry["path"], "output_id": entry["output_id"]})
            if baseline["status"] == "tracked":
                errors.append({"code": "tracked_production_deleted", "path": entry["path"]})
        else:
            present += 1
            actual = sha256(path)
            result["actual_sha256"] = actual
            if not baseline["sha256"]:
                result["production_status"] = "unreviewed_new_file"
                errors.append({"code": "unreviewed_production_png", "path": entry["path"], "actual_sha256": actual})
            elif actual != baseline["sha256"]:
                result["production_status"] = "sha256_mismatch"
                errors.append({"code": "production_sha256_mismatch", "path": entry["path"], "expected_sha256": baseline["sha256"], "actual_sha256": actual})
            else:
                with Image.open(path) as png:
                    png.load()
                    if png.format != "PNG" or list(png.size) != baseline["png_size"]:
                        raise ValueError(f"invalid production PNG dimensions/format: {entry['path']}")
                result["production_status"] = "matches_committed_baseline"
                verified += 1
        source_issue_count = len(gaps) + len(errors)
        for component in ("original_png", "prompt_file", "intake_record"):
            evidence = entry["source_evidence"].get(component)
            if evidence is None:
                gaps.append({"code": "missing_source_evidence", "output_id": entry["output_id"], "component": component,
                             "documented_original_sha256": entry["source_evidence"].get("documented_original_sha256") if component == "original_png" else None})
            else:
                source_path = contained_path(repo, evidence["path"])
                if not source_path.is_file():
                    gaps.append({"code": "missing_source_file", "output_id": entry["output_id"], "component": component, "path": evidence["path"]})
                elif not evidence.get("sha256") or sha256(source_path) != evidence["sha256"]:
                    errors.append({"code": "source_sha256_mismatch", "output_id": entry["output_id"], "component": component, "path": evidence["path"]})
        if len(gaps) + len(errors) == source_issue_count:
            result["source_status"] = "matches_reviewed_source_records"
        results.append(result)
    known = {e["path"] for e in entries}
    for path in sorted((repo / "assets/campaign/environment").rglob("*.png")):
        relative = path.relative_to(repo).as_posix()
        contained_path(repo, relative)
        if relative not in known:
            errors.append({"code": "unmapped_production_png", "path": relative})
    historical = []
    for requirement in inventory["historical_inputs"]:
        item = dict(requirement)
        relative = requirement.get("path")
        path = contained_path(repo, relative) if relative else None
        if path is None or not path.is_file():
            item["status"] = "missing"
            gaps.append({"code": "missing_historical_input", "id": requirement["id"], "path": relative,
                         "expected_sha256": requirement.get("sha256")})
        elif not requirement.get("sha256"):
            item["status"] = "unverified_evidence"
            gaps.append({"code": "unverified_historical_input", "id": requirement["id"], "path": relative})
        elif sha256(path) != requirement["sha256"]:
            item["status"] = "sha256_mismatch"
            errors.append({"code": "historical_sha256_mismatch", "id": requirement["id"], "path": relative,
                           "actual_sha256": sha256(path), "expected_sha256": requirement["sha256"]})
        else:
            item["status"] = "matches_frozen_hash"
        historical.append(item)
    if not route_report["passed"]:
        errors.extend({"code": "route_contract_failed", "check": item["name"], "detail": item.get("detail")}
                      for item in route_report["checks"] if not item["passed"])
    passed = not errors and not gaps
    report = {"schema_version": 1, "kind": "environment_art_audit", "passed": passed,
              "status": "complete" if passed else "invalid_or_changed_inputs" if errors else "incomplete_evidence",
              "exit_code": 0 if passed else 2 if errors else 1,
              "scope": "all 69 mapped environment targets; no visual/performance/release approval",
              "inventory_sha256": sha256(inventory_path), "mapping_sha256": sha256(mapping_path),
              "baseline_commit": inventory["baseline_commit"],
              "routes_passed": route_report["passed"], "route_checks": len(route_report["checks"]),
              "production_integrity_passed": verified == sum(e["production_baseline"]["status"] == "tracked" for e in entries)
                  and not any(e["code"] in {"tracked_production_deleted", "unreviewed_production_png", "production_sha256_mismatch", "unmapped_production_png"} for e in errors),
              "production_complete": present == len(entries) and verified == len(entries),
              "provenance_complete": not any(g["code"] != "missing_production_png" for g in gaps) and not errors,
              "counts": {"targets": len(entries), "present": present, "verified_production_hashes": verified,
                         "missing_production": len(entries) - present, "errors": len(errors), "gaps": len(gaps)},
              "production": results, "historical_inputs": historical, "errors": errors, "gaps": gaps}
    write_report(output, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--report", type=Path, default=Path(".godot/environment_validation/audit.json"))
    args = parser.parse_args()
    output = None
    try:
        output = report_target(args.repo.resolve(), args.report)
        report = run(args.repo, output)
        print(json.dumps({key: report[key] for key in ("passed", "status", "exit_code", "routes_passed", "production_integrity_passed", "production_complete", "provenance_complete", "counts")}, ensure_ascii=False))
        return report["exit_code"]
    except (OSError, ValueError, KeyError, TypeError, AssertionError) as error:
        report = {"passed": False, "kind": "environment_art_audit", "status": "invalid_or_missing_input", "exit_code": 2, "error": str(error)}
        if output:
            write_report(output, report)
        print(json.dumps(report, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
