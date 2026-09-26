"""Verify portrait provenance and render production routes in a private Godot copy."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import time
import uuid

import run_character_art_qa as common

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = "tools/contracts/hero_portraits_20260926"
SCRIPT = "tools/hero_portraits_qa.gd"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", required=True, type=Path)
    args = parser.parse_args()
    shared, running = common.load_helpers(ROOT)
    engine = shared.resolve_godot(args.godot)
    work = shared.resolve_profile_root(args.work_root)
    if work.is_relative_to(ROOT):
        raise ValueError("QA workspace must be outside the source checkout")
    manifest = json.loads((ROOT / CONTRACT / "manifest.json").read_text(encoding="utf-8"))
    for row in manifest["portraits"].values():
        common.relative_source(ROOT, row["path"])
        if common.sha(ROOT / row["path"]) != row["sha256"]:
            raise ValueError("Portrait source changed: " + row["path"])
    for row in (manifest["style_reference"], manifest["prompts"]):
        if common.sha(ROOT / row["path"]) != row["sha256"]:
            raise ValueError("Provenance changed: " + row["path"])
    names = set(shared.sources()) | set(common.TOOLS) | {
        SCRIPT, "tools/run_hero_portraits_qa.py", "tools/run_character_art_qa.py",
        CONTRACT + "/manifest.json", CONTRACT + "/prompts.json",
    }
    if not args.run:
        print(json.dumps({"preflight": True, "source_files": len(names),
                          "lock_busy": shared.LOCK.exists(), "engine_busy": running()}))
        return 0
    if running() or shared.LOCK.exists():
        raise RuntimeError("Shared Godot slot is occupied")
    run = work / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8])
    project, evidence = run / "project", run / "evidence"
    receipt = {"complete": False, "source_root": str(ROOT), "run": str(run),
               "source_files": [], "steps": [], "godot_sha256": common.sha(engine)}
    locked = False
    try:
        shared.LOCK.parent.mkdir(parents=True, exist_ok=True)
        with shared.LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True
        project.mkdir(parents=True)
        evidence.mkdir()
        for name in sorted(names):
            common.relative_source(ROOT, name)
            data = (ROOT / name).read_bytes()
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            receipt["source_files"].append({"path": name, "sha256": hashlib.sha256(data).hexdigest()})
        profile = shared.create_private_profile(run, work / "profiles")
        env = common.private_environment(profile)
        common.process_step(engine, project, env, evidence, "import",
                            ["--headless", "--editor", "--import", "--quit"],
                            600, "gl_compatibility", running, receipt["steps"])
        common.process_step(engine, project, env | {"HERO_PORTRAITS_OUT": str(evidence)}, evidence,
                            "portraits", ["--position", "20000,20000", "--script", "res://" + SCRIPT],
                            180, "gl_compatibility", running, receipt["steps"])
        report = json.loads((evidence / "report.json").read_text(encoding="utf-8"))
        if not report["passed"]:
            raise RuntimeError("Portrait route check failed")
        receipt["checks"] = len(report["checks"])
        receipt["source_changes"] = common.source_changes(ROOT, receipt["source_files"])
        receipt["private_source_changes"] = common.source_changes(project, receipt["source_files"])
        if receipt["source_changes"] or receipt["private_source_changes"]:
            raise RuntimeError("Source drift detected")
        receipt["complete"] = True
    except Exception as exc:
        receipt["error"] = str(exc)
    finally:
        if locked:
            shared.LOCK.unlink()
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "run": str(run),
                          "error": receipt.get("error"), "checks": receipt.get("checks")}, ensure_ascii=False))
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
