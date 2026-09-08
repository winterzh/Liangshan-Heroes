"""Freeze the focused HUD pause restore regression in a fresh private profile.

Read-only preflight without --run. Uses the shared engine lock and only stops its
own child on concrete errors. Does not enable save/continue or real Steam.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

from run_steam_integration_qa import (
    ROOT, LOCK, ROOT_FILES, RUNTIME_DIRS, resolve_godot,
    resolve_profile_root, create_private_profile,
)
from run_campaign_mission_state_qa import running_engine, run_engine

OWN = ["tools/hud_pause_restore_qa.gd", "tools/run_hud_pause_restore_qa.py",
       "tools/run_campaign_mission_state_qa.py", "tools/run_steam_integration_qa.py",
       "scripts/continue_flow.gd", "assets/localization/continue_flow.json"]
SNAPSHOTS = OWN + ["scripts/hud.gd", "scripts/run_hud_state.gd",
                   "scripts/run_hud_messages_state.gd", "scripts/localization.gd"]
SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/hud_pause_restore_qa.gd" id="1"]
[node name="HUDPauseRestoreQA" type="Node"]
script = ExtResource("1")
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/hud_pause_restore"))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    work_root = resolve_profile_root(args.work_root)
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    names = sorted({name for name in raw.decode("utf-8").split("\0") if name and
                    (name in ROOT_FILES or name.split("/")[0] in RUNTIME_DIRS)} | set(OWN))
    if not args.run:
        print(json.dumps({"preflight": True, "source_files": len(names), "lock_busy": LOCK.exists(), "work_root": str(work_root)}))
        return 0
    if running_engine(): raise RuntimeError("Godot/game engine slot is occupied")
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / name
    evidence = ROOT / "qa/hud_pause_restore_20260909" / name
    receipt = {"complete": False, "full_world": False, "real_steam": False,
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "source_files": [], "steps": [], "run": str(run), "fresh_import": True, "godot_sha256": sha(engine)}
    locked = False
    try:
        with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
        locked = True
        if running_engine(): raise RuntimeError("Engine started before lock acquisition")
        run.mkdir(parents=True, exist_ok=False); evidence.mkdir(parents=True, exist_ok=False)
        project = run / "project"; project.mkdir()
        for path in names:
            data = (ROOT / path).read_bytes()
            dest = project / path; dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(data)
            receipt["source_files"].append({"path": path, "sha256": hashlib.sha256(data).hexdigest()})
        scene = project / "hud_pause_restore_qa.tscn"; scene.write_text(SCENE, encoding="utf-8")
        receipt["scene_sha256"] = sha(scene)
        for path in SNAPSHOTS + [scene.name]:
            dest = evidence / "source_snapshot" / path; dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / path, dest)
        profile = create_private_profile(run, work_root / "profiles")
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("LSH_") or key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR"]:
                env.pop(key)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = profile / key.lower(); private.mkdir(); env[key] = str(private)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_HUD_PAUSE_PROFILE=str(profile))
        receipt["private_profile"] = str(profile)
        for label in ["import", "profile_guard", "regression"]:
            print("RUN " + label + " " + str(run), flush=True)
            child_env = env.copy()
            report = run / (label + "_report.json")
            child_env["LSH_HUD_PAUSE_REPORT"] = str(report)
            if label == "profile_guard": child_env["LSH_HUD_PAUSE_PROFILE"] = str(profile / "mismatch")
            extra = ["--editor", "--import"] if label == "import" else ["res://" + scene.name]
            log = evidence / (label + ".log")
            step = dict(run_engine(engine, project, extra, child_env, log), name=label)
            expected = 2 if label == "profile_guard" else 0
            step["expected_exit_code"] = expected; receipt["steps"].append(step)
            if report.exists(): shutil.copyfile(report, evidence / report.name)
            if step["exit_code"] != expected or step["errors"] or step["stop_reason"]:
                raise RuntimeError(label + " failed: " + str(log))
            if label == "profile_guard" and (report.exists() or "PRIVATE_PROFILE_REQUIRED" not in log.read_text(encoding="utf-8")):
                raise RuntimeError("Profile guard did not reject before fixture writes")
        result = json.loads((run / "regression_report.json").read_text(encoding="utf-8"))
        checks = result.get("checks", [])
        if result.get("passed") is not True or result.get("full_world") is not False or result.get("real_steam") is not False or len(checks) < 90 or any(row.get("passed") is not True for row in checks):
            raise RuntimeError("Missing/incomplete/failed HUD regression checks")
        receipt["checks"] = len(checks)
        for row in receipt["source_files"]:
            if sha(ROOT / row["path"]) != row["sha256"] or sha(project / row["path"]) != row["sha256"]:
                raise RuntimeError("Source changed during test: " + row["path"])
        if sha(engine) != receipt["godot_sha256"] or sha(scene) != receipt["scene_sha256"]:
            raise RuntimeError("Engine or generated scene changed")
        receipt["source_guard_checks"] = 2 * len(receipt["source_files"])
        receipt["complete"] = True
    except Exception as exc:
        receipt["failure"] = str(exc)
        raise
    finally:
        if evidence.exists():
            (evidence / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        if locked and LOCK.exists() and LOCK.read_text(encoding="utf-8") == str(run): LOCK.unlink()
        print(json.dumps({"complete": receipt["complete"], "checks": receipt.get("checks", 0), "evidence": str(evidence)}), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
