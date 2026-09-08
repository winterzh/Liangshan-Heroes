"""Read-only independent check of one frozen Mission component evidence batch.

Checks actual reports/logs and every current/frozen production input. Later
source changes will correctly fail current-source parity; do not rewrite an old
receipt to conceal drift. This script never starts Godot or writes game data.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
from run_steam_integration_qa import resolve_godot


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch", nargs="?", default="20260909_045557_eb6be9e0")
    args = parser.parse_args()
    assert re.fullmatch(r"\d{8}_\d{6}_[0-9a-f]{8}", args.batch), "Invalid batch name"
    evidence = QA / args.batch
    receipt = json.loads((evidence / "receipt.json").read_text(encoding="utf-8"))
    assert receipt["complete"] is True and receipt["component_only"] is True
    assert receipt["real_steam"] is False and receipt["full_world"] is False
    assert receipt["fresh_import"] is True
    assert sha(resolve_godot(None)) == receipt["godot_sha256"]
    frozen = Path(receipt["run"]) / "project"
    sources = receipt["source_files"]
    known = {}
    for row in sources:
        name = row["path"]
        path = PurePosixPath(name)
        assert not path.is_absolute() and ".." not in path.parts and name not in known
        known[name] = row["sha256"]
        assert sha(ROOT / name) == row["sha256"], "Current source drift: " + name
        assert sha(frozen / name) == row["sha256"], "Frozen source drift: " + name
    assert receipt["source_guard_checks"] == 2 * len(sources)
    scene = "campaign_mission_state_qa.tscn"
    assert sha(frozen / scene) == receipt["generated_scene_sha256"]
    snapshot_checks = 0
    for path in (evidence / "source_snapshot").rglob("*"):
        if not path.is_file(): continue
        name = path.relative_to(evidence / "source_snapshot").as_posix()
        expected = receipt["generated_scene_sha256"] if name == scene else known[name]
        assert sha(path) == expected, "Archived snapshot drift: " + name
        snapshot_checks += 1
    assert snapshot_checks >= 11
    assert [step["name"] for step in receipt["steps"]] == ["import", "profile_guard", "component", "restart"]
    pids = []
    for step in receipt["steps"]:
        name = step["name"]
        log_path = evidence / (name + ".log")
        log = log_path.read_text(encoding="utf-8")
        assert sha(log_path) == step["log_sha256"]
        assert not re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", log)
        assert step["errors"] == 0 and step["stop_reason"] is None
        assert step["expected_exit_code"] == step["exit_code"] == (2 if name == "profile_guard" else 0)
        pids.append(step["pid"])
    assert len(set(pids)) == 4
    guard = (evidence / "profile_guard.log").read_text(encoding="utf-8")
    assert "PRIVATE_PROFILE_REQUIRED" in guard
    assert not (Path(receipt["run"]) / "profile_guard_report.json").exists()
    phase_counts = {}
    for phase in ["component", "restart"]:
        report = json.loads((evidence / (phase + "_report.json")).read_text(encoding="utf-8"))
        assert report["passed"] is True and report["phase"] == phase
        assert report["component_only"] is True and report["real_steam"] is False and report["full_world"] is False
        checks = report["checks"]
        assert checks and all(row["passed"] is True for row in checks)
        assert len({row["label"] for row in checks}) == len(checks)
        logs = [line[len("CAMPAIGN_MISSION_STATE_QA "):] for line in
                (evidence / (phase + ".log")).read_text(encoding="utf-8").splitlines()
                if line.startswith("CAMPAIGN_MISSION_STATE_QA {")]
        assert len(logs) == 1 and json.loads(logs[0]) == report
        phase_counts[phase] = len(checks)
    assert phase_counts == receipt["phase_checks"] == {"component": 120, "restart": 22}
    assert sum(phase_counts.values()) == receipt["checks"] == 142
    snapshot = evidence / "mission_snapshot.json"
    assert sha(snapshot) == sha(Path(receipt["run"]) / snapshot.name)
    wire = json.loads(snapshot.read_text(encoding="utf-8"))
    assert wire["schema"] == "campaign_mission_component_v1"
    assert wire["context"]["content_version"] == "fixture:mission:v1"
    artifacts = [{"path": path.relative_to(QA).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)}
                 for path in sorted(evidence.rglob("*")) if path.is_file()]
    print(json.dumps({"passed": True, "batch": args.batch, "scope": "independent readback; no engine execution",
                      "component_only": True, "full_world": False, "real_steam": False,
                      "source_head": receipt["source_head"], "source_files": len(sources),
                      "current_and_frozen_hash_checks": 2 * len(sources),
                      "archived_source_snapshot_checks": snapshot_checks,
                      "behavior_checks": 142, "phase_checks": phase_counts, "processes": pids,
                      "receipt_sha256": sha(evidence / "receipt.json"),
                      "validator_sha256": sha(Path(__file__)), "artifacts": artifacts}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
