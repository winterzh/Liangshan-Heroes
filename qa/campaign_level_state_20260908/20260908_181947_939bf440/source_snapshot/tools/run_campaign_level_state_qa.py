"""Freeze production dependencies and verify the eight-chapter Level component.

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

OWN = ["scripts/run_campaign_level_state.gd", "tools/campaign_level_state_qa.gd",
       "tools/run_campaign_level_state_qa.py", "tools/run_steam_integration_qa.py"]
SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/campaign_level_state_qa.gd" id="1"]
[node name="CampaignLevelStateQA" type="Node"]
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/campaign_level_state"))
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
    evidence = ROOT / "qa/campaign_level_state_20260908" / name
    receipt = {"complete": False, "component_only": True, "source_head": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "godot_sha256": sha(engine),
        "source_files": [], "steps": [], "fresh_import": True, "run": str(run)}
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
        (project / "campaign_level_state_qa.tscn").write_text(SCENE, encoding="utf-8")
        receipt["generated_scene_sha256"] = sha(project / "campaign_level_state_qa.tscn")
        profile = create_private_profile(run, work_root / "profiles")
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("LSH_") or key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO"]:
                env.pop(key)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = profile / key.lower(); private.mkdir(); env[key] = str(private)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_CAMPAIGN_STATE_REPORT=str(run / "report.json"))
        receipt["private_profile"] = str(profile)
        for label, extra in [("import", ["--editor", "--import"]), ("component", ["res://campaign_level_state_qa.tscn"])]:
            print("RUN " + label + " " + str(run), flush=True)
            started = time.monotonic()
            log_file = evidence / (label + ".log")
            with log_file.open("wb") as log:
                result = subprocess.run([str(engine), "--headless", "--path", str(project)] + extra,
                    cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            log = log_file.read_text(encoding="utf-8", errors="replace")
            errors = len(re.findall(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", log))
            receipt["steps"].append({"name": label, "exit_code": result.returncode, "errors": errors,
                "seconds": round(time.monotonic() - started, 2), "log_sha256": sha(log_file)})
            if result.returncode or errors: raise RuntimeError(label + " failed; see " + str(log_file))
        report = json.loads((run / "report.json").read_text(encoding="utf-8"))
        checks = report.get("checks", [])
        if report.get("passed") is not True or report.get("component_only") is not True or len(checks) < 200 or any(row.get("passed") is not True for row in checks):
            raise RuntimeError("Missing/incomplete/failed behavioral checks")
        receipt["checks"] = len(checks)
        for row in receipt["source_files"]:
            if sha(ROOT / row["path"]) != row["sha256"] or sha(project / row["path"]) != row["sha256"]:
                raise RuntimeError("Source changed during test: " + row["path"])
        if sha(engine) != receipt["godot_sha256"]: raise RuntimeError("Godot binary changed")
        if sha(project / "campaign_level_state_qa.tscn") != receipt["generated_scene_sha256"]: raise RuntimeError("QA scene changed")
        snapshot = set(OWN) | {row["path"] for row in receipt["source_files"] if row["path"].startswith("scripts/levels/")}
        snapshot |= {"scripts/level_base.gd", "scripts/campaign.gd", "scripts/run_state_value_codec.gd", "scripts/unit.gd"}
        for path in sorted(snapshot):
            dest = evidence / "source_snapshot" / path; dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / path, dest)
        shutil.copyfile(project / "campaign_level_state_qa.tscn", evidence / "source_snapshot/campaign_level_state_qa.tscn")
        shutil.copyfile(run / "report.json", evidence / "report.json")
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
