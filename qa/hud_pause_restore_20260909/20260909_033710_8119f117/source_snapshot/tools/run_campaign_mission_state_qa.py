"""Freeze production dependencies and verify the CampaignMission component across two fresh processes.

Preflight is read-only. --run uses a fresh import, private profile and the shared
Godot lock. Evidence contains code snapshots and hashes, never import caches.
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

OWN = ["scripts/run_campaign_mission_state.gd", "tools/campaign_mission_state_qa.gd",
       "tools/run_campaign_mission_state_qa.py", "tools/run_steam_integration_qa.py",
       "scripts/continue_flow.gd", "assets/localization/continue_flow.json"]
SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/campaign_mission_state_qa.gd" id="1"]
[node name="CampaignMissionStateQA" type="Node"]
script = ExtResource("1")
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    # Other tasks' untracked modules are not dependency candidates. The current
    # explicit new component is included; all tracked production inputs freeze.
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    names = {name for name in raw.decode("utf-8").split("\0") if name and
             (name in ROOT_FILES or name.split("/")[0] in RUNTIME_DIRS)}
    return sorted(names | set(OWN))


def running_engine():
    query = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", query], text=True).strip()
    return bool(raw and json.loads(raw))


def run_engine(engine, project, extra, env, log_file, timeout=240):
    """Stop only this invocation's child when its own log or deadline fails."""
    started = time.monotonic()
    stopped = None
    with log_file.open("wb") as log:
        child = subprocess.Popen([str(engine), "--headless", "--path", str(project)] + extra,
            cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            while child.poll() is None:
                time.sleep(0.2)
                observed = log_file.read_text(encoding="utf-8", errors="replace")
                if re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", observed): stopped = "engine_error"
                elif time.monotonic() - started > timeout: stopped = "timeout"
                if stopped:
                    child.terminate()
                    try: child.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        child.kill(); child.wait(timeout=15)
                    break
        finally:
            if child.poll() is None:
                child.terminate()
                try: child.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait(timeout=15)
    text = log_file.read_text(encoding="utf-8", errors="replace")
    return {"exit_code": child.returncode, "pid": child.pid,
            "errors": len(re.findall(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", text)),
            "seconds": round(time.monotonic() - started, 2), "stop_reason": stopped,
            "log_sha256": sha(log_file)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/campaign_mission_state"))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    work_root = resolve_profile_root(args.work_root)
    names = sources()
    if not args.run:
        print(json.dumps({"preflight": True, "source_files": len(names), "lock_busy": LOCK.exists(), "work_root": str(work_root)}))
        return 0
    if running_engine(): raise RuntimeError("Godot/game engine slot is occupied")
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / name
    evidence = ROOT / "qa/campaign_mission_state_20260909" / name
    receipt = {"complete": False, "component_only": True, "source_head": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "godot_sha256": sha(engine),
        "source_files": [], "steps": [], "fresh_import": True, "run": str(run), "real_steam": False, "full_world": False}
    locked = False
    try:
        with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
        locked = True
        if running_engine(): raise RuntimeError("Engine started before lock acquisition")
        run.mkdir(parents=True, exist_ok=False)
        evidence.mkdir(parents=True, exist_ok=False)
        project = run / "project"; project.mkdir()
        for path in names:
            source = ROOT / path
            data = source.read_bytes()
            dest = project / path; dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(data)
            receipt["source_files"].append({"path": path, "sha256": hashlib.sha256(data).hexdigest()})
        (project / "campaign_mission_state_qa.tscn").write_text(SCENE, encoding="utf-8")
        receipt["generated_scene_sha256"] = sha(project / "campaign_mission_state_qa.tscn")
        # Save the exact component inputs before the engine runs, including failed attempts.
        snapshot = set(OWN) | {"scripts/campaign_mission.gd", "scripts/localization.gd", "scripts/run_state_value_codec.gd", "scripts/unit.gd"}
        for path in sorted(snapshot):
            dest = evidence / "source_snapshot" / path; dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / path, dest)
        shutil.copyfile(project / "campaign_mission_state_qa.tscn", evidence / "source_snapshot/campaign_mission_state_qa.tscn")
        profile = create_private_profile(run, work_root / "profiles")
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("LSH_") or key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO"]:
                env.pop(key)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = profile / key.lower(); private.mkdir(); env[key] = str(private)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_MISSION_STATE_REPORT=str(run / "report.json"), LSH_MISSION_STATE_PROFILE=str(profile), LSH_MISSION_STATE_SNAPSHOT=str(run / "mission_snapshot.json"))
        receipt["private_profile"] = str(profile)
        for label, extra in [("import", ["--editor", "--import"]), ("profile_guard", ["res://campaign_mission_state_qa.tscn"]), ("component", ["res://campaign_mission_state_qa.tscn"]), ("restart", ["res://campaign_mission_state_qa.tscn"])]:
            print("RUN " + label + " " + str(run), flush=True)
            log_file = evidence / (label + ".log")
            child_env = env.copy()
            child_env["LSH_MISSION_STATE_PHASE"] = label
            child_env["LSH_MISSION_STATE_REPORT"] = str(run / (label + "_report.json"))
            if label == "profile_guard": child_env["LSH_MISSION_STATE_PROFILE"] = str(profile / "mismatch")
            step = run_engine(engine, project, extra, child_env, log_file)
            log = log_file.read_text(encoding="utf-8", errors="replace")
            receipt["steps"].append(dict(step, name=label))
            expected_code = 2 if label == "profile_guard" else 0
            receipt["steps"][-1]["expected_exit_code"] = expected_code
            if step["exit_code"] != expected_code or step["errors"] or step["stop_reason"]:
                raise RuntimeError(label + " failed; see " + str(log_file))
            if label == "profile_guard" and ((run / "profile_guard_report.json").exists() or (run / "mission_snapshot.json").exists() or "PRIVATE_PROFILE_REQUIRED" not in log):
                raise RuntimeError("Profile guard did not exit before fixture/report writes")
        receipt["checks"] = 0
        receipt["phase_checks"] = {}
        for phase, minimum in [("component", 90), ("restart", 20)]:
            report = json.loads((run / (phase + "_report.json")).read_text(encoding="utf-8"))
            checks = report.get("checks", [])
            if report.get("passed") is not True or report.get("component_only") is not True or report.get("phase") != phase or report.get("real_steam") is not False or report.get("full_world") is not False or len(checks) < minimum or any(row.get("passed") is not True for row in checks):
                raise RuntimeError("Missing/incomplete/failed " + phase + " checks")
            receipt["checks"] += len(checks)
            receipt["phase_checks"][phase] = len(checks)
            shutil.copyfile(run / (phase + "_report.json"), evidence / (phase + "_report.json"))
        shutil.copyfile(run / "mission_snapshot.json", evidence / "mission_snapshot.json")
        for row in receipt["source_files"]:
            if sha(ROOT / row["path"]) != row["sha256"] or sha(project / row["path"]) != row["sha256"]:
                raise RuntimeError("Source changed during test: " + row["path"])
        if sha(engine) != receipt["godot_sha256"]: raise RuntimeError("Godot binary changed")
        if sha(project / "campaign_mission_state_qa.tscn") != receipt["generated_scene_sha256"]: raise RuntimeError("QA scene changed")
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
