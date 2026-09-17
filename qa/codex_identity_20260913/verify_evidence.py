"""Read-only verification of archived codex evidence and current production."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    final = sys.argv[1]
    checks = 0
    def verify(condition, label):
        nonlocal checks
        if not condition:
            raise RuntimeError(label)
        checks += 1

    archives = []
    for directory in sorted((HERE / "native").iterdir()):
        receipt = read(directory / "receipt.json")
        for item in receipt["artifacts"]:
            path = directory / item["path"]
            verify(path.is_file() and sha(path) == item["sha256"] and path.stat().st_size == item["bytes"], str(path))
        archives.append({"run": directory.name, "complete": receipt["complete"], "artifacts": len(receipt["artifacts"])})
    directory = HERE / "native" / final
    receipt = read(directory / "receipt.json")
    verify(receipt["complete"] and receipt["visual_acceptance_complete"] and receipt["lock_released"], "Final native run incomplete")
    verify(not receipt["source_changes"] and not receipt["private_source_changes"] and not receipt["engines_remaining"], "Final source/process protection")
    for item in receipt["source_files"]:
        verify(sha(ROOT / item["path"]) == item["sha256"], "Current source drift: " + item["path"])
    verify(sha(ROOT / "tools/codex_identity_qa.gd") == receipt["qa_sha256"], "QA drift")
    verify(sha(ROOT / "tools/run_codex_identity_qa.py") == receipt["driver_sha256"], "Driver drift")
    reports = []
    for mode in ["headless", "visual"]:
        report = read(directory / mode / "report.json")
        verify(report["passed"] and report["complete"] and not report["failures"], mode + " failed")
        verify(len(report["routes"]) == 32 and len(report["portraits"]) == 4 and len(report["languages"]) == 4, mode + " route coverage")
        for row in report["portraits"]:
            verify(row["imported_size"] == [1024, 1024], "Actual imported portrait dimensions")
        verify(len(report["fit_occupancy"]) == 4, "Actual occupancy witnesses")
        reports.append({"mode": mode, "checks": report["count"], "screenshots": len(report["screenshots"])})
    verify(reports[1]["screenshots"] == 13, "Native screenshot count")
    contract = ROOT / "tools/contracts/codex_identity_20260913"
    generation = read(contract / "generation.json")
    known = {"original": generation["original_reference"]["sha256"]}
    for row in generation["reference_catalog"].values():
        verify(sha(ROOT / row["path"]) == row["sha256"], "Existing reference changed")
    for job in generation["jobs"]:
        verify(sha(ROOT / job["repository_path"]) == job["sha256"], "Generation original bytes: " + job["key"])
        for key, digest in job["source_sha256"].items():
            verify(known.get(key) == digest, "Generation prior chain: " + job["key"] + "/" + key)
        if "prompt_sha256" in job:
            verify(hashlib.sha256(job["prompt"].encode()).hexdigest() == job["prompt_sha256"], "Exact prompt")
        known[job["key"]] = job["sha256"]
    for row in read(contract / "portrait_manifest.json")["portraits"].values():
        verify(sha(ROOT / row["path"]) == row["sha256"] == known[row["job"]], "Selected production portrait")
    verify(not (ROOT / ".godot/redraw_rejection_source.lock").exists(), "Shared engine lock remains")
    print(json.dumps({"passed": True, "checks": checks, "final_run": final, "sources": len(receipt["source_files"]), "archives": archives, "reports": reports, "fresh_import": receipt["fresh_import"], "scope": "Source and archived evidence identity; manual screenshot review is recorded separately."}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
