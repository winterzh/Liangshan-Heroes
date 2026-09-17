"""Freeze normal menu/HUD save-and-exit and cross-process continue tests.

Without --run this is read-only. Runtime work uses the shared Godot lock,
a fresh import, a new isolated profile and disabled real Steam.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

from run_steam_integration_qa import (
    ROOT, LOCK, ROOT_FILES, RUNTIME_DIRS, resolve_godot,
    resolve_profile_root, create_private_profile,
)
from run_campaign_level_state_qa import running_engine

OWN = ["scripts/continue_flow.gd", "assets/localization/continue_flow.json",
       "tools/continue_flow_qa.gd", "tools/run_continue_flow_qa.py",
       "tools/run_steam_integration_qa.py", "tools/run_campaign_level_state_qa.py"]
CHANGED = ["project.godot", "scripts/battle.gd", "scripts/hud.gd",
           "scripts/menu.gd", "scripts/app_lifecycle.gd", "scripts/run_slot_store.gd",
           "scripts/run_world_session.gd", "assets/localization/catalog.json"]
SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/continue_flow_qa.gd" id="1"]
[node name="ContinueFlowQA" type="Node"]
script = ExtResource("1")
'''

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def sources():
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    names = {n for n in raw.decode("utf-8").split("\0") if n and
             (n in ROOT_FILES or n.split("/")[0] in RUNTIME_DIRS)}
    return sorted(names | set(OWN))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/continue_flow"))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    work_root = resolve_profile_root(args.work_root)
    names = sources()
    if not args.run:
        print(json.dumps({"preflight": True, "source_files": len(names), "lock_busy": LOCK.exists(), "work_root": str(work_root)}))
        return 0
    if running_engine(): raise RuntimeError("Godot/game engine slot occupied")
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / name
    evidence = ROOT / "qa/continue_flow_20260909" / name
    receipt = {"complete": False, "scope": "Isolated normal-scene operation flow; not full 30-wave acceptance or live Steam",
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "godot_sha256": sha(engine), "source_files": [], "steps": [], "fresh_import": True,
               "run": str(run), "checks": 0}
    locked = False
    try:
        with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
        locked = True
        if running_engine(): raise RuntimeError("Engine started before lock acquisition")
        run.mkdir(parents=True, exist_ok=False)
        evidence.mkdir(parents=True, exist_ok=False)
        project = run / "project"; project.mkdir()
        for path in names:
            data = (ROOT / path).read_bytes()
            dest = project / path; dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(data)
            receipt["source_files"].append({"path": path, "sha256": hashlib.sha256(data).hexdigest()})
        scene = project / "continue_flow_qa.tscn"
        scene.write_text(SCENE, encoding="utf-8")
        receipt["generated_scene_sha256"] = sha(scene)
        profile = create_private_profile(run, work_root / "profiles")
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("LSH_") or key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR"]:
                env.pop(key)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = profile / key.lower(); private.mkdir(); env[key] = str(private)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_CONTINUE_FLOW_QA="1",
                   LSH_CONTINUE_FLOW_PROFILE=str(profile), LSH_CONTINUE_FLOW_STATE=str(run / "state.json"))
        receipt["private_profile"] = str(profile)
        pids = []
        for case in ["import", "profile_guard", "public_gate", "no_slot", "capture", "restore_and_overwrite", "restore_again"]:
            print("RUN " + case + " " + str(run), flush=True)
            child_env = env.copy()
            child_env.update(LSH_CONTINUE_FLOW_CASE=case, LSH_CONTINUE_FLOW_REPORT=str(run / (case + ".json")))
            if case == "profile_guard": child_env["LSH_CONTINUE_FLOW_PROFILE"] = str(profile / "mismatch")
            if case == "public_gate": child_env["LSH_CONTINUE_FLOW_QA"] = "0"
            extra = ["--editor", "--import"] if case == "import" else ["res://continue_flow_qa.tscn"]
            started = time.monotonic()
            log_file = evidence / (case + ".log")
            with log_file.open("wb") as log:
                child = subprocess.Popen([str(engine), "--headless", "--path", str(project)] + extra,
                    cwd=project, env=child_env, stdout=log, stderr=subprocess.STDOUT,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                while child.poll() is None:
                    time.sleep(0.2)
                    observed_log = log_file.read_text(encoding="utf-8", errors="replace")
                    if re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", observed_log) or time.monotonic() - started > 240:
                        child.terminate()  # Only this runner's known child, after a concrete failure.
                        child.wait(timeout=15)
                        break
            errors = len(re.findall(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", log_file.read_text(encoding="utf-8", errors="replace")))
            expected = 2 if case == "profile_guard" else 0
            receipt["steps"].append({"case": case, "exit_code": child.returncode, "expected_exit_code": expected,
                                     "errors": errors, "seconds": round(time.monotonic() - started, 2), "log_sha256": sha(log_file)})
            report = run / (case + ".json")
            if report.exists(): shutil.copyfile(report, evidence / report.name)
            if child.returncode != expected or errors: raise RuntimeError(case + " failed: " + str(log_file))
            if case == "profile_guard":
                if report.exists() or "PRIVATE_PROFILE_REQUIRED" not in log_file.read_text(encoding="utf-8"):
                    raise RuntimeError("Profile guard did not reject before fixture writes")
            elif case != "import":
                result = json.loads(report.read_text(encoding="utf-8"))
                checks = result.get("checks", [])
                if result.get("passed") is not True or not checks or any(c.get("passed") is not True for c in checks):
                    raise RuntimeError(case + " missing or failed behavioral checks")
                receipt["checks"] += len(checks)
                pids.append(result["pid"])
        if len(pids) != 5 or len(set(pids)) != 5 or receipt["checks"] < 70:
            raise RuntimeError("Independent process or check coverage incomplete")
        receipt["processes"] = pids
        for row in receipt["source_files"]:
            if sha(ROOT / row["path"]) != row["sha256"] or sha(project / row["path"]) != row["sha256"]:
                raise RuntimeError("Source changed during QA: " + row["path"])
        if sha(engine) != receipt["godot_sha256"] or sha(scene) != receipt["generated_scene_sha256"]:
            raise RuntimeError("Engine or generated scene changed")
        receipt["source_guard_checks"] = len(receipt["source_files"]) * 2
        receipt["complete"] = True
    except Exception as exc:
        receipt["failure"] = str(exc)
        raise
    finally:
        if evidence.exists():
            for path in sorted(set(OWN + CHANGED)):
                frozen = run / "project" / path
                if frozen.exists():
                    dest = evidence / "source_snapshot" / path
                    dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(frozen, dest)
            (evidence / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        if locked and LOCK.exists() and LOCK.read_text(encoding="utf-8") == str(run): LOCK.unlink()
        print(json.dumps({"complete": receipt["complete"], "checks": receipt["checks"], "evidence": str(evidence)}), flush=True)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
