"""Freeze a declared art batch with fresh source/profile and an optional imported cache."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import time
import uuid
import run_character_art_qa as common

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "tools/art_full_inventory_qa.gd"

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run", action="store_true")
    ap.add_argument("--cache-from", type=Path)
    ap.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/art_full_20260915"))
    args = ap.parse_args()
    shared, running = common.load_helpers(ROOT)
    engine = shared.resolve_godot(None)
    declared = json.loads((ROOT / "tools/contracts/art_full_20260915/inputs.json").read_text(encoding="utf-8"))
    names = set(shared.sources()) | set(common.TOOLS) | set(declared) | {SCRIPT,"tools/run_art_full_qa.py","tools/contracts/art_full_20260915/environment.json"}
    for name in list(names):
        if (ROOT/(name+".import")).is_file(): names.add(name+".import")
    names = sorted(names)
    if not args.run:
        print(json.dumps({"preflight":True,"files":len(names),"lock_busy":shared.LOCK.exists(),"engine_busy":running()})); return
    if running() or shared.LOCK.exists(): raise RuntimeError("Shared Godot slot occupied")
    work = shared.resolve_profile_root(args.work_root)
    tag = time.strftime("%Y%m%d_%H%M%S")+"_"+uuid.uuid4().hex[:8]
    run = work/tag
    project, evidence = run/"project", run/"evidence"
    receipt = {"complete":False,"source_root":str(ROOT),"run":str(run),"source_files":[],"steps":[],"godot_sha256":common.sha(engine)}
    locked = False
    try:
        with shared.LOCK.open("x",encoding="utf-8") as f: f.write(str(run))
        locked = True
        project.mkdir(parents=True);evidence.mkdir()
        for name in names:
            common.relative_source(ROOT,name)
            target = project/name;target.parent.mkdir(parents=True,exist_ok=True)
            data = (ROOT/name).read_bytes();target.write_bytes(data)
            receipt["source_files"].append({"path":name,"sha256":hashlib.sha256(data).hexdigest()})
        profile = shared.create_private_profile(run,work/"profiles")
        env = common.private_environment(profile)
        receipt["private_profile"] = str(profile)
        if args.cache_from:
            old = args.cache_from.resolve(); old_receipt = json.loads((old/"evidence/receipt.json").read_text())
            assert old_receipt["source_root"] == str(ROOT) and old_receipt["godot_sha256"] == common.sha(engine)
            assert any(s["case"] == "import" and s["passed"] for s in old_receipt["steps"])
            shutil.copytree(old/"project/.godot/imported",project/".godot/imported")
            receipt["cache_from"] = str(old)
        common.process_step(engine,project,env,evidence,"import",["--headless","--editor","--import","--quit"],300,"gl_compatibility",running,receipt["steps"])
        drift = common.source_changes(project,receipt["source_files"])
        if drift: raise RuntimeError("Import changed frozen files: "+repr(drift))
        out = evidence/"inventory"
        common.process_step(engine,project,env|{"ART_FULL_OUT":str(out)},evidence,"inventory",["--position","20000,20000","--script","res://"+SCRIPT],300,"gl_compatibility",running,receipt["steps"])
        report = json.loads((out/"report.json").read_text())
        assert report["passed"] and not report["failures"]
        receipt["checks"] = len(report["checks"])
        receipt["source_changes"] = common.source_changes(ROOT,receipt["source_files"])
        receipt["private_source_changes"] = common.source_changes(project,receipt["source_files"])
        assert not receipt["source_changes"] and not receipt["private_source_changes"]
        receipt["complete"] = True
    except Exception as exc:
        receipt["error"] = str(exc)
    finally:
        if locked: shared.LOCK.unlink()
        receipt["lock_released"] = locked and not shared.LOCK.exists()
        evidence.mkdir(parents=True,exist_ok=True)
        receipt["artifacts"] = [{"path":p.relative_to(evidence).as_posix(),"sha256":common.sha(p)} for p in sorted(evidence.rglob("*")) if p.is_file()]
        (evidence/"receipt.json").write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"complete":receipt["complete"],"run":str(run),"error":receipt.get("error")},ensure_ascii=False))
    if not receipt["complete"]: raise SystemExit(1)

if __name__ == "__main__": main()
