"""Freeze same-owner slot retry QA with a fresh import and private profile.

Preflight is read-only. --run acquires the shared Godot lock, retains original
failure logs/receipts and source snapshots, and never enables real Steam.
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

OWN = [
    "tools/owned_slot_retry_qa.gd", "tools/run_owned_slot_retry_qa.py",
    "tools/run_campaign_mission_state_qa.py", "tools/run_steam_integration_qa.py",
    "scripts/run_snapshot_store.gd", "scripts/run_slot_store.gd",
    "scripts/run_world_session.gd", "scripts/continue_flow.gd",
    "assets/localization/continue_flow.json",
]
SNAPSHOTS = OWN + ["scripts/run_battle_barrier.gd", "scripts/run_battle_clock.gd"]
SCENE_NAME = "owned_slot_retry_qa.tscn"
SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/owned_slot_retry_qa.gd" id="1"]
[node name="OwnedSlotRetryQA" type="Node"]
script = ExtResource("1")
'''
MINIMUM_CHECKS = 76


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    tracked = {name for name in raw.decode("utf-8").split("\0") if name and
               (name in ROOT_FILES or name.split("/")[0] in RUNTIME_DIRS)}
    # Every non-ignored production file belongs to this frozen checkout; retain
    # newly integrated modules too. A path-set/hash guard rejects concurrent edits.
    raw = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=ROOT)
    new = {name for name in raw.decode("utf-8").split("\0") if name and
           (name in ROOT_FILES or name.split("/")[0] in RUNTIME_DIRS)}
    return sorted(tracked | new | set(OWN))


def source_guard(receipt, project, engine, names):
    changed = []
    for row in receipt["source_files"]:
        for label, base in [("checkout", ROOT), ("snapshot", project)]:
            path = base / row["path"]
            if not path.is_file() or sha(path) != row["sha256"]:
                changed.append(label + ":" + row["path"])
    if sources() != names:
        changed.append("source_path_set")
    if sha(engine) != receipt["godot_sha256"]:
        changed.append("godot_binary")
    scene_checks = 0
    if "scene_sha256" in receipt:
        scene = project / SCENE_NAME
        scene_checks = 1
        if not scene.is_file() or sha(scene) != receipt["scene_sha256"]:
            changed.append("generated_scene")
    return {"passed": not changed, "changed": changed,
            "checks": 2 * len(receipt["source_files"]) + 2 + scene_checks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/owned_slot_retry"))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    work_root = resolve_profile_root(args.work_root)
    names = sources()
    if not args.run:
        print(json.dumps({"preflight": True, "source_files": len(names),
                          "lock_busy": LOCK.exists(), "work_root": str(work_root),
                          "real_steam": False, "full_world_flow": False}))
        return 0
    if running_engine():
        raise RuntimeError("Godot/game engine slot is occupied")
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / name
    evidence = ROOT / "qa/owned_slot_retry_20260909" / name
    project = run / "project"
    receipt = {
        "complete": False, "full_world_flow": False, "real_steam": False,
        "production_slot_document": False, "fresh_import": True,
        "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "godot_sha256": sha(engine), "source_files": [], "steps": [], "run": str(run),
    }
    locked = False
    try:
        LOCK.parent.mkdir(parents=True, exist_ok=True)
        with LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True
        if running_engine():
            raise RuntimeError("Engine started before lock acquisition")
        run.mkdir(parents=True, exist_ok=False)
        evidence.mkdir(parents=True, exist_ok=False)
        ignore = evidence.parent / ".gdignore"
        if not ignore.exists():
            ignore.write_bytes(b"")
        project.mkdir()
        for path in names:
            data = (ROOT / path).read_bytes()
            dest = project / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            receipt["source_files"].append({"path": path, "sha256": hashlib.sha256(data).hexdigest()})
        scene = project / SCENE_NAME
        scene.write_text(SCENE, encoding="utf-8", newline="\n")
        receipt["scene_sha256"] = sha(scene)
        for path in SNAPSHOTS:
            dest = evidence / "source_snapshot" / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / path, dest)
        shutil.copyfile(scene, evidence / "source_snapshot" / SCENE_NAME)
        profile = create_private_profile(run, work_root / "profiles")
        receipt["private_profile"] = str(profile)
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("LSH_") or key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR"]:
                env.pop(key)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = profile / key.lower()
            private.mkdir()
            env[key] = str(private)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_OWNED_SLOT_RETRY_QA="1",
                   LSH_OWNED_SLOT_RETRY_PROFILE=str(profile))
        for label in ["import", "profile_guard", "regression"]:
            print("RUN " + label + " " + str(run), flush=True)
            child_env = env.copy()
            if label == "profile_guard":
                child_env["LSH_OWNED_SLOT_RETRY_PROFILE"] = str(profile / "mismatch")
            extra = ["--editor", "--import"] if label == "import" else ["res://" + SCENE_NAME]
            log = evidence / (label + ".log")
            step = dict(run_engine(engine, project, extra, child_env, log), name=label)
            expected = 2 if label == "profile_guard" else 0
            step["expected_exit_code"] = expected
            receipt["steps"].append(step)
            reports = list(profile.rglob("owned_slot_retry_qa/report.json"))
            if len(reports) == 1:
                shutil.copyfile(reports[0], evidence / (label + "_report.json"))
            if step["exit_code"] != expected or step["errors"] or step["stop_reason"]:
                raise RuntimeError(label + " failed: " + str(log))
            if label == "profile_guard":
                fixtures = list(profile.rglob("owned_slot_retry_qa"))
                if reports or fixtures or "PRIVATE_PROFILE_REQUIRED" not in log.read_text(encoding="utf-8"):
                    raise RuntimeError("Profile guard did not reject before fixture/report writes")
                receipt["profile_guard_zero_fixture_writes"] = True
        reports = list(profile.rglob("owned_slot_retry_qa/report.json"))
        if len(reports) != 1:
            raise RuntimeError("Missing or ambiguous owned-slot report")
        result = json.loads(reports[0].read_text(encoding="utf-8"))
        checks = result.get("checks", [])
        if result.get("passed") is not True or any(result.get(key) is not False for key in
                ["real_steam", "production_slot_document", "full_world_flow"]):
            raise RuntimeError("Regression scope/result is invalid")
        if len(checks) != MINIMUM_CHECKS or any(row.get("passed") is not True for row in checks) or len({row.get("name") for row in checks}) != len(checks):
            raise RuntimeError("Missing, duplicate, incomplete or failed regression checks")
        for path, expected_sha in result.get("source_sha256", {}).items():
            if not path.startswith("res://") or sha(project / path.removeprefix("res://")) != expected_sha:
                raise RuntimeError("Engine report input hash differs from frozen source")
        if len(result.get("source_sha256", {})) != 4:
            raise RuntimeError("Engine report source hashes are incomplete")
        receipt["checks"] = len(checks)
        receipt["source_guard"] = source_guard(receipt, project, engine, names)
        if not receipt["source_guard"]["passed"]:
            raise RuntimeError("Source or engine changed during test")
        receipt["complete"] = True
    except Exception as exc:
        receipt["failure"] = str(exc)
        raise
    finally:
        if evidence.exists():
            # Even failed imports/runs retain their original logs, source
            # snapshots, incomplete receipt and a post-run source audit.
            if len(receipt["source_files"]) == len(names):
                try:
                    receipt["final_source_guard"] = source_guard(receipt, project, engine, names)
                except Exception as exc:
                    receipt["final_source_guard"] = {"passed": False, "failure": str(exc)}
                if not receipt["final_source_guard"]["passed"]:
                    receipt["complete"] = False
            (evidence / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        if locked and LOCK.exists() and LOCK.read_text(encoding="utf-8") == str(run):
            LOCK.unlink()
        print(json.dumps({"complete": receipt["complete"], "checks": receipt.get("checks", 0),
                          "evidence": str(evidence)}), flush=True)
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
