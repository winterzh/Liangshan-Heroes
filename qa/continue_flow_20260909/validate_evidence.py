"""Read back the final operation-flow evidence; does not run Godot or write files."""
import hashlib
import json
from pathlib import Path
import re

QA = Path(__file__).resolve().parent
ROOT = QA.parent.parent
BATCH = "20260909_033854_66f38f86"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    run = QA / BATCH
    receipt = json.loads((run / "receipt.json").read_text(encoding="utf-8"))
    assert receipt["complete"] is True
    total = 0
    pids = []
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
        pids.append(report["pid"])
    assert total == receipt["checks"] == 186
    assert len(pids) == len(set(pids)) == 7 and pids == receipt["processes"]
    for row in receipt["source_files"]:
        assert sha(ROOT / row["path"]) == row["sha256"], row["path"]
    for image in receipt["screenshots"]:
        assert sha(run / "screenshots" / image["path"]) == image["sha256"]
    assert len(receipt["screenshots"]) == 12
    print(json.dumps({"passed": True, "batch": BATCH, "checks": total,
                      "source_files": len(receipt["source_files"]), "screenshots": 12,
                      "engine_rerun": False, "full_30_waves": False, "real_steam": False}))

if __name__ == "__main__":
    main()
