"""Freeze production dependencies and verify Level 3 full world save & restore lifecycle.

Preflight is read-only. --run uses a fresh import, private profile and the shared
Godot lock. Executes import, profile_guard, and world_restore across fresh isolated processes.
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

OWN = [
    "scripts/run_battle_root_state.gd",
    "scripts/run_battle_world_core.gd",
    "scripts/run_slot_store.gd",
    "scripts/run_world_session.gd",
    "tools/level3_world_restore_qa.gd",
    "tools/run_level3_world_restore_qa.py",
    "tools/run_steam_integration_qa.py",
]

SNAPSHOT = OWN + [
    "scripts/run_official_restore_profile.gd",
    "scripts/run_level3_world_factory.gd",
    "scripts/run_content_identity.gd",
    "scripts/run_state_value_codec.gd",
    "scripts/campaign_mission.gd",
    "scripts/run_local_lifecycle.gd",
    "scripts/campaign.gd",
    "scripts/levels/level3_zhujiazhuang_rts.gd",
    "scripts/battle.gd",
    "scripts/menu.gd",
]

SCENE_NAME = "level3_world_restore_qa.tscn"
SCENE = """[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/level3_world_restore_qa.gd" id="1"]
[node name="Level3WorldRestoreQA" type="Node"]
script = ExtResource("1")
"""


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    names = {n for n in raw.decode("utf-8").split("\0") if n and
             (n in ROOT_FILES or n.split("/")[0] in RUNTIME_DIRS)}
    return sorted(names | set(OWN))


def running_engine():
    query = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", query], text=True).strip()
    value = json.loads(raw) if raw else []
    return sorted(value if isinstance(value, list) else [value])


def player_digest():
    """Only aggregate count/digest leaves memory; no player names or bytes archived."""
    text = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    match = re.search(r'^config/name=(".*")$', text, re.M)
    if not match:
        raise RuntimeError("Cannot determine protected player directory")
    name = json.loads(match.group(1))
    if re.search(r'^config/use_custom_user_dir=true$', text, re.M):
        raise RuntimeError("Custom player directory needs an explicit protected-path implementation")
    result = {}
    for key in ["APPDATA", "LOCALAPPDATA"]:
        if not os.environ.get(key):
            raise RuntimeError("Missing real environment boundary: " + key)
        directory = Path(os.environ[key]) / "Godot/app_userdata" / name
        digest = hashlib.sha256()
        count = 0
        if directory.exists():
            for path in sorted(directory.rglob("*")):
                if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400:
                    raise RuntimeError("Protected player directory has a reparse entry")
                if path.is_file():
                    digest.update(path.relative_to(directory).as_posix().encode("utf-8"))
                    digest.update(bytes.fromhex(sha(path)))
                    count += 1
        result[key] = {"exists": directory.exists(), "file_count": count, "sha256": digest.hexdigest()}
    return result


def phase_guard(receipt, label, run, project, engine, names):
    row = {"label": label, "engine_pids": running_engine(), "lock_owned": False,
           "source_inventory_matches": False, "source_changes": [], "checks": 0}
    receipt.setdefault("phase_guards", []).append(row)
    row["lock_owned"] = LOCK.is_file() and LOCK.read_text(encoding="utf-8") == str(run)
    row["source_inventory_matches"] = sources() == names
    for source in receipt["source_files"]:
        for where, path in [("source", ROOT / source["path"]), ("private", project / source["path"])]:
            row["checks"] += 1
            if not path.is_file() or sha(path) != source["sha256"]:
                row["source_changes"].append({"where": where, "path": source["path"]})
    row["engine_unchanged"] = sha(engine) == receipt["godot_sha256"]
    row["scene_unchanged"] = (project / SCENE_NAME).is_file() and sha(project / SCENE_NAME) == receipt["generated_scene_sha256"]
    row["passed"] = (not row["engine_pids"] and row["lock_owned"] and row["source_inventory_matches"]
                     and not row["source_changes"] and row["engine_unchanged"] and row["scene_unchanged"])
    if not row["passed"]:
        raise RuntimeError("Frozen source/engine/lock boundary failed: " + label)


def run_child(engine, project, extra, env, log_file, receipt, case, timeout=240):
    command = [str(engine), "--path", str(project)] + extra
    step = {"case": case, "command": command, "expected_exit_code": 2 if case == "profile_guard" else 0,
            "exit_code": None, "pid": None, "errors": None, "stop_reason": None}
    receipt["steps"].append(step)
    started = time.monotonic()
    child = None
    try:
        with log_file.open("wb") as log:
            child = subprocess.Popen(command, cwd=project, env=env, stdout=log,
                stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            step["pid"] = child.pid
            while child.poll() is None:
                time.sleep(0.2)
                text = log_file.read_text(encoding="utf-8", errors="replace")
                if re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", text):
                    step["stop_reason"] = "engine_error"
                elif time.monotonic() - started > timeout:
                    step["stop_reason"] = "timeout"
                if step["stop_reason"]:
                    break
    finally:
        if child is not None:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=15)
            step["exit_code"] = child.returncode
        step["seconds"] = round(time.monotonic() - started, 2)
        if log_file.exists():
            text = log_file.read_text(encoding="utf-8", errors="replace")
            step["errors"] = len(re.findall(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", text))
            step["log_sha256"] = sha(log_file)
    return step


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/level3_world_restore"))
    args = parser.parse_args()
    work_root = resolve_profile_root(args.work_root)
    if not args.run:
        engine = resolve_godot(args.godot)
        print(json.dumps({"preflight": True, "source_files": len(sources()), "lock_busy": LOCK.exists(),
                          "work_root": str(work_root), "engine_sha256": sha(engine)}))
        return 0

    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / name
    evidence = ROOT / "qa/level3_world_restore_20260909" / name
    evidence.mkdir(parents=True, exist_ok=False)
    receipt = {
        "schema": "level3_world_restore_runner_v1",
        "complete": False,
        "full_world": True,
        "chapter": "level3",
        "fresh_import": True,
        "run": str(run),
        "source_files": [],
        "steps": [],
        "checks": 0,
        "source_snapshot": [],
    }
    locked = False
    engine = None
    project = None
    names = []
    failed = False
    try:
        engine = resolve_godot(args.godot)
        receipt["godot_sha256"] = sha(engine)
        receipt["source_head"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        names = sources()
        receipt["protected_player_before"] = player_digest()
        receipt["engines_before"] = running_engine()
        if receipt["engines_before"]:
            raise RuntimeError("Godot/game engine slot occupied")

        with LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True

        if running_engine():
            raise RuntimeError("Engine started before lock acquisition")

        run.mkdir(parents=True, exist_ok=False)
        project = run / "project"
        project.mkdir()

        for relative in names:
            data = (ROOT / relative).read_bytes()
            dest = project / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            receipt["source_files"].append({"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})

        (project / SCENE_NAME).write_text(SCENE, encoding="utf-8", newline="\n")
        receipt["generated_scene_sha256"] = sha(project / SCENE_NAME)

        for relative in sorted(set(SNAPSHOT + [SCENE_NAME])):
            dest = evidence / "source_snapshot" / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / relative, dest)
            receipt["source_snapshot"].append({"path": relative, "bytes": dest.stat().st_size, "sha256": sha(dest)})

        (evidence / "source_manifest.json").write_text(json.dumps({
            "sources": receipt["source_files"],
            "snapshots": receipt["source_snapshot"],
            "generated_scene_sha256": receipt["generated_scene_sha256"]
        }, indent=2) + "\n", encoding="utf-8")

        profile = create_private_profile(run, work_root / "profiles")
        receipt["private_profile"] = str(profile)
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("LSH_") or key in [
                "LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR"
            ]:
                env.pop(key)

        receipt["private_environment"] = {}
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            directory = profile / key.lower()
            directory.mkdir()
            env[key] = str(directory)
            receipt["private_environment"][key] = str(directory)

        slot_root = "user://continue/v1"
        report_path = run / "world_restore_report.json"
        env.update(
            STEAM_DISABLED="1",
            CAMPAIGN_QA="1",
            LSH_LEVEL3_RESTORE_PROFILE=str(profile),
            LSH_LEVEL3_RESTORE_SLOT_ROOT=slot_root,
            LSH_LEVEL3_RESTORE_REPORT=str(report_path),
        )

        for case in ["import", "profile_guard", "world_restore"]:
            phase_guard(receipt, case + "_before", run, project, engine, names)
            print("RUN " + case + " " + str(evidence), flush=True)
            child_env = env.copy()
            if case == "profile_guard":
                child_env["LSH_LEVEL3_RESTORE_PROFILE"] = str(profile / "mismatch")

            if case == "import":
                extra = ["--headless", "--editor", "--import"]
            elif case == "profile_guard":
                extra = ["--headless", "res://" + SCENE_NAME]
            else:
                extra = [
                    "--rendering-method", "gl_compatibility",
                    "--audio-driver", "Dummy",
                    "--resolution", "1280x720",
                    "res://" + SCENE_NAME
                ]

            try:
                step = run_child(engine, project, extra, child_env, evidence / (case + ".log"), receipt, case)
            finally:
                phase_guard(receipt, case + "_after", run, project, engine, names)

            if step["exit_code"] != step["expected_exit_code"] or step["errors"] or step["stop_reason"]:
                raise RuntimeError(case + " failed; see archived log")

            if case == "profile_guard":
                text = (evidence / (case + ".log")).read_text(encoding="utf-8", errors="replace")
                if report_path.exists() or "PRIVATE_PROFILE_REQUIRED" not in text:
                    raise RuntimeError("Profile guard did not reject before fixture/report writes")

            if case == "world_restore":
                if not report_path.exists():
                    raise RuntimeError("Missing world restore report")
                report = json.loads(report_path.read_text(encoding="utf-8"))
                if not isinstance(report, dict):
                    raise RuntimeError("Report must be a JSON object")
                rows = report.get("checks", [])
                if report.get("passed") is not True or report.get("full_world") is not True or report.get("chapter") != "level3":
                    raise RuntimeError("World restore report verification failed")
                if len(rows) < 25 or any(r.get("passed") is not True for r in rows):
                    raise RuntimeError("Not all checks passed in world restore report: " + str(len(rows)))
                shutil.copyfile(report_path, evidence / "world_restore_report.json")
                receipt["checks"] = len(rows)
                receipt["report"] = report

        receipt["complete"] = True
    except Exception as exc:
        receipt["failure"] = str(exc)
        failed = True
        raise
    finally:
        if "protected_player_before" in receipt:
            try:
                receipt["protected_player_after"] = player_digest()
                receipt["protected_player_unchanged"] = receipt["protected_player_after"] == receipt["protected_player_before"]
                if not receipt["protected_player_unchanged"]:
                    raise RuntimeError("Protected player summary changed")
            except Exception as exc:
                receipt["protection_failure"] = str(exc)
                failed = True

        if project is not None:
            try:
                changed = []
                for row in receipt["source_files"]:
                    for where, path in [("source", ROOT / row["path"]), ("private", project / row["path"])]:
                        if not path.is_file() or sha(path) != row["sha256"]:
                            changed.append({"where": where, "path": row["path"]})
                receipt["source_guard_checks"] = 2 * len(receipt["source_files"])
                receipt["source_changes"] = changed
                if changed:
                    failed = True
                if engine is not None and sha(engine) != receipt["godot_sha256"]:
                    receipt["engine_changed"] = True
                    failed = True
                if (project / SCENE_NAME).exists() and sha(project / SCENE_NAME) != receipt.get("generated_scene_sha256"):
                    receipt["scene_changed"] = True
                    failed = True
            except Exception as exc:
                receipt["source_guard_failure"] = str(exc)
                failed = True

        receipt["lock_acquired"] = locked
        receipt["lock_released"] = False
        try:
            receipt["engines_after"] = running_engine()
            if receipt["engines_after"]:
                failed = True
            if locked:
                receipt["lock_owned_at_release"] = LOCK.is_file() and LOCK.read_text(encoding="utf-8") == str(run)
                if receipt["lock_owned_at_release"] and not receipt["engines_after"]:
                    LOCK.unlink()
                    receipt["lock_released"] = not LOCK.exists()
                if not receipt["lock_released"]:
                    failed = True
        except Exception as exc:
            receipt["lock_release_failure"] = str(exc)
            failed = True

        receipt["complete"] = receipt["complete"] and not failed
        receipt["files"] = [
            {"path": p.relative_to(evidence).as_posix(), "bytes": p.stat().st_size, "sha256": sha(p)}
            for p in sorted(evidence.rglob("*")) if p.is_file() and p.name != "receipt.json"
        ]
        (evidence / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "checks": receipt["checks"], "evidence": str(evidence)}, ensure_ascii=False), flush=True)

    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
