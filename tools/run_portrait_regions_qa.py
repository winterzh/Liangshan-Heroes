"""Render/verify the legacy portrait regions in a fresh frozen project and private profile."""
import argparse
import json
from pathlib import Path
import shutil
import time
import uuid
import run_character_art_qa as common

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "tools/portrait_regions_qa.gd"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--work-root", required=True, type=Path)
    parser.add_argument("--cache-from", type=Path)
    args = parser.parse_args()
    shared, running = common.load_helpers(ROOT)
    engine = shared.resolve_godot(None)
    work = shared.resolve_profile_root(args.work_root)
    if work.is_relative_to(ROOT):
        raise ValueError("QA directory must be outside source checkout")
    names = sorted(set(shared.sources()) | set(common.TOOLS) | {
        SCRIPT, "tools/run_portrait_regions_qa.py", "tools/run_character_art_qa.py",
        "scripts/portrait_atlas_regions.gd", "tools/contracts/portrait_regions_20260926/manifest.json"})
    if not args.run:
        print(json.dumps({"files": len(names), "lock_busy": shared.LOCK.exists(), "engine_busy": running()}))
        return
    if running() or shared.LOCK.exists():
        raise RuntimeError("Shared Godot slot occupied")
    run = work / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8])
    project, evidence = run / "project", run / "evidence"
    receipt = {"complete": False, "source_root": str(ROOT), "run": str(run),
               "godot_sha256": common.sha(engine),
               "source_files": [], "steps": []}
    locked = False
    try:
        shared.LOCK.parent.mkdir(parents=True, exist_ok=True)
        with shared.LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True
        project.mkdir(parents=True)
        evidence.mkdir()
        for name in names:
            common.relative_source(ROOT, name)
            dest = project / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)
            receipt["source_files"].append({"path": name, "sha256": common.sha(dest)})
        profile = shared.create_private_profile(run, work / "profiles")
        env = common.private_environment(profile)
        receipt["private_profile"] = str(profile)
        if args.cache_from:
            old = args.cache_from.resolve()
            if old.is_relative_to(ROOT):
                raise ValueError("Cache must be an external private run")
            prior = json.loads((old / "evidence/receipt.json").read_text(encoding="utf-8"))
            assert prior["source_root"] == str(ROOT) and prior["godot_sha256"] == receipt["godot_sha256"]
            assert any(s["case"] == "import" and s["passed"] for s in prior["steps"])
            shutil.copytree(old / "project/.godot/imported", project / ".godot/imported")
            receipt["cache_from"] = str(old)
        common.process_step(engine, project, env, evidence, "import",
                            ["--headless", "--editor", "--import", "--quit"],
                            600, "gl_compatibility", running, receipt["steps"])
        common.process_step(engine, project, env | {"PORTRAIT_REGIONS_OUT": str(evidence)}, evidence,
                            "regions", ["--position", "20000,20000", "--script", "res://" + SCRIPT],
                            240, "gl_compatibility", running, receipt["steps"])
        report = json.loads((evidence / "report.json").read_text(encoding="utf-8"))
        assert report["passed"]
        receipt["checks"] = len(report["checks"])
        receipt["source_changes"] = common.source_changes(ROOT, receipt["source_files"])
        receipt["private_source_changes"] = common.source_changes(project, receipt["source_files"])
        assert not receipt["source_changes"] and not receipt["private_source_changes"]
        receipt["complete"] = True
    except Exception as exc:
        receipt["error"] = str(exc)
    finally:
        if locked:
            shared.LOCK.unlink()
        evidence.mkdir(parents=True, exist_ok=True)
        receipt["artifacts"] = [{"path": p.relative_to(evidence).as_posix(), "sha256": common.sha(p)}
                                for p in sorted(evidence.rglob("*")) if p.is_file()]
        (evidence / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"complete": receipt["complete"], "run": str(run), "error": receipt.get("error")}, ensure_ascii=False))
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
