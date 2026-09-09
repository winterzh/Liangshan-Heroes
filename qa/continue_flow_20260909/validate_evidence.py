"""Read back the final operation-flow evidence; does not run Godot or write files."""
import argparse
import hashlib
import json
from pathlib import Path
import re

QA = Path(__file__).resolve().parent
ROOT = QA.parent.parent
BATCH = "20260909_085735_9439525c"
PROCESS_IDENTITY_V2 = "continue_flow_process_identity_v2"
FULL_CASES = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle", "unsaved_terminal",
              "capture", "restore_and_overwrite", "restore_again", "pending_retry", "held_error",
              "terminal", "terminal_reject"]
FOCUSED_CASES = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle", "unsaved_terminal",
                 "capture", "terminal", "terminal_reject"]
PROCESS_FIELDS = ("case", "pid", "process_nonce", "started_ns", "finished_ns")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_process_identity(receipt, reports):
    steps = receipt["steps"]
    expected_cases = receipt.get("cases", [s["case"] for s in steps])
    assert [s["case"] for s in steps] == expected_cases
    pids = [report["pid"] for report in reports]
    if "process_identity_schema" not in receipt:
        # Historical receipts have no Popen identity record; retain their original gate.
        assert len(pids) == len(set(pids)) == len(expected_cases) - 2 and pids == receipt["processes"]
        return
    assert receipt["process_identity_schema"] == PROCESS_IDENTITY_V2, "Unknown process identity schema"
    assert type(receipt["terminal_only"]) is bool
    assert expected_cases == (FOCUSED_CASES if receipt["terminal_only"] else FULL_CASES)
    behavior_count = len(expected_cases) - 2
    assert len(reports) == behavior_count
    nonces = set()
    previous_finished = 0
    projected_runs = []
    for step in steps:
        assert type(step["pid"]) is int and step["pid"] > 0
        nonce = step["process_nonce"]
        assert type(nonce) is str and re.fullmatch(r"[0-9a-fA-F]{32}", nonce), step["case"]
        assert nonce.lower() not in nonces, "Reused process nonce: " + step["case"]
        nonces.add(nonce.lower())
        started = step["started_ns"]
        finished = step["finished_ns"]
        assert type(started) is int and type(finished) is int
        assert 0 < started < finished and previous_finished <= started, step["case"]
        previous_finished = finished
        if step["case"] in ("import", "profile_guard"):
            continue
        report = reports[len(projected_runs)]
        assert type(report["pid"]) is int
        assert all(report[field] == step[field] for field in ("case", "pid", "process_nonce")), step["case"]
        projected_runs.append({field: step[field] for field in PROCESS_FIELDS})
    runs = receipt["process_runs"]
    assert type(runs) is list and len(runs) == behavior_count
    for row in runs:
        assert type(row) is dict and set(row) == set(PROCESS_FIELDS)
        assert all(type(row[field]) is int for field in ("pid", "started_ns", "finished_ns"))
        assert all(type(row[field]) is str for field in ("case", "process_nonce"))
    assert runs == projected_runs, "Process runs differ from behavioral Popen steps"
    assert type(receipt["processes"]) is list and all(type(pid) is int for pid in receipt["processes"])
    assert pids == receipt["processes"] == [row["pid"] for row in projected_runs]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", default=BATCH)
    parser.add_argument("--historical", action="store_true", help="Read preserved evidence without requiring the current checkout to equal it")
    args = parser.parse_args()
    assert args.batch and Path(args.batch).name == args.batch
    run = QA / args.batch
    receipt = json.loads((run / "receipt.json").read_text(encoding="utf-8"))
    assert receipt["complete"] is True
    total = 0
    reports = []
    for step in receipt["steps"]:
        case = step["case"]
        log = run / (case + ".log")
        assert sha(log) == step["log_sha256"]
        assert step["exit_code"] == step["expected_exit_code"] and step["errors"] == 0
        assert not re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", log.read_text(encoding="utf-8"))
        if case in ["import", "profile_guard"]:
            assert case != "profile_guard" or not (run / (case + ".json")).exists()
            continue
        report = json.loads((run / (case + ".json")).read_text(encoding="utf-8"))
        assert report["passed"] and report["checks"] and all(c["passed"] for c in report["checks"])
        assert report["real_steam"] is False and report["full_30_waves"] is False
        assert f"CONTINUE_FLOW_QA {case} {len(report['checks'])} true" in log.read_text(encoding="utf-8")
        if case in ["capture", "restore_and_overwrite", "restore_again", "pending_retry"]:
            assert report["result"]["ok"] is True
        total += len(report["checks"])
        reports.append(report)
    assert total == receipt["checks"] and total > 0
    expected_cases = receipt.get("cases", [s["case"] for s in receipt["steps"]])
    validate_process_identity(receipt, reports)
    for row in receipt["source_files"]:
        if not args.historical:
            assert sha(ROOT / row["path"]) == row["sha256"], row["path"]
        preserved = run / "source_snapshot" / row["path"]
        if preserved.exists():
            assert sha(preserved) == row["sha256"], str(preserved)
    for image in receipt["screenshots"]:
        assert sha(run / "screenshots" / image["path"]) == image["sha256"]
    expected_images = 4 if receipt.get("terminal_only", False) else (16 if "terminal" in expected_cases else 12)
    assert len(receipt["screenshots"]) == expected_images
    print(json.dumps({"passed": True, "batch": args.batch, "checks": total,
                      "source_files": len(receipt["source_files"]), "screenshots": expected_images, "historical": args.historical,
                      "engine_rerun": False, "full_30_waves": False, "real_steam": False}))

if __name__ == "__main__":
    main()
