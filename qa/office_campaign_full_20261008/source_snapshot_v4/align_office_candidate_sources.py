"""Align only LF/CRLF checkout representations to the actual local baseline; preserve every old byte."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "qa/zhu_wounded_20261005/harness/run_daming_admit_v24s.py"
BASE_SHA = "049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626"
PROPOSED = {"scripts/run_battle_world_core.gd", "scripts/run_level8_unit_contract.gd"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(value, message):
    if not value:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preparation", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(sha(BASE) == BASE_SHA, "Immutable installed-identity implementation drift")
    spec = importlib.util.spec_from_file_location("office_source_identity_only", BASE)
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    preparation = json.loads(args.preparation.read_text(encoding="utf-8"))
    candidate = base.no_reparse(Path(preparation["candidate_root"]))
    require(candidate != ROOT and not candidate.is_relative_to(ROOT), "Independent candidate required")
    require(not args.output.exists(), "Source alignment receipt must be new")
    production = base.installed_identity(ROOT)
    current = base.installed_identity(candidate)
    production_rows = {row["path"]: row for row in production["files"]}
    candidate_rows = {row["path"]: row for row in current["files"]}
    require(production_rows.keys() == candidate_rows.keys() and production["directories"] == current["directories"],
            "Source inventories differ; provision exact source companions first")
    changes = []
    for name in sorted(production_rows):
        if name in PROPOSED:
            row = next(row for row in preparation["files"] if row["path"] == name)
            require(production_rows[name]["sha256"] == row["before_sha256"]
                    and candidate_rows[name]["sha256"] == row["after_sha256"], "Declared proposal bridge changed")
            continue
        if production_rows[name] == candidate_rows[name]:
            continue
        source, target = ROOT / name, candidate / name
        require(source.read_bytes().replace(b"\r\n", b"\n") == target.read_bytes().replace(b"\r\n", b"\n"),
                "Candidate source differs semantically: " + name)
        changes.append({"path": name, "before": candidate_rows[name], "after": production_rows[name],
                        "reason": "Same content after CRLF-to-LF comparison; freeze actual baseline bytes"})
    original = args.output.parent / (args.output.stem + "_original")
    require(not original.exists(), "Alignment backup must be new")
    original.mkdir(parents=True)
    for row in changes:
        source, target = ROOT / row["path"], candidate / row["path"]
        backup = original / row["path"]
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(target.read_bytes())
        require(sha(backup) == row["before"]["sha256"], "Original checkout backup mismatch")
        require(sha(source) == row["after"]["sha256"], "Production changed during alignment")
        target.write_bytes(source.read_bytes())
        require(sha(target) == row["after"]["sha256"], "Aligned source readback mismatch")
    aligned = base.installed_identity(candidate)
    require(base.installed_identity(ROOT) == production, "Production changed during source bridge")
    expected = dict(production_rows)
    for name in PROPOSED:
        expected[name] = candidate_rows[name]
    require({row["path"]: row for row in aligned["files"]} == expected
            and aligned["directories"] == production["directories"], "Complete final candidate source bridge failed")
    record = {"schema": "office_complete_candidate_source_bridge_v1", "complete": True,
              "production_root": str(ROOT), "candidate_root": str(candidate),
              "production_identity": production, "candidate_identity": aligned,
              "only_semantic_changes": sorted(PROPOSED), "representation_changes": changes,
              "original_backup": str(original), "native_started": False, "runtime_qualified": False}
    args.output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"complete": True, "runtime_files": aligned["file_count"],
                      "representation_changes": len(changes), "only_semantic_changes": sorted(PROPOSED),
                      "receipt": str(args.output), "native_started": False}))


if __name__ == "__main__":
    main()
