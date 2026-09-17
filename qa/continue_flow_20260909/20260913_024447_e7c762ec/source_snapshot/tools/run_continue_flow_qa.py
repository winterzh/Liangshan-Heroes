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

OWN = ["scripts/run_local_lifecycle.gd", "scripts/run_campaign_presentation_state.gd", "scripts/continue_flow.gd", "assets/localization/continue_flow.json",
       "tools/continue_flow_qa.gd", "tools/run_continue_flow_qa.py",
       "tools/run_steam_integration_qa.py", "tools/run_campaign_level_state_qa.py"]
CHANGED = ["project.godot", "scripts/battle.gd", "scripts/hud.gd",
           "scripts/menu.gd", "scripts/app_lifecycle.gd", "scripts/run_slot_store.gd",
           "scripts/run_world_session.gd", "scripts/run_snapshot_store.gd",
           "scripts/run_battle_world_core.gd", "scripts/run_meteor_wards_state.gd",
           "scripts/run_battle_barrier.gd", "scripts/run_battle_root_state.gd", "assets/localization/catalog.json"]
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

def validate_process_report(result, case, step):
    if (not isinstance(result, dict) or result.get("case") != case
            or type(result.get("pid")) is not int or result["pid"] != step["pid"]
            or result.get("process_nonce") != step["process_nonce"]):
        raise RuntimeError(case + " report does not belong to its observed process")


def validate_process_sequence(rows, expected_cases):
    # Windows can reuse a PID after a child exits. Each Popen has its own nonce
    # and monotonic interval; every child must finish before the next starts.
    if [row.get("case") for row in rows] != expected_cases:
        raise RuntimeError("Independent process case coverage incomplete")
    nonces = set()
    previous_finished = 0
    for row in rows:
        nonce = row.get("process_nonce")
        started = row.get("started_ns")
        finished = row.get("finished_ns")
        if (type(row.get("pid")) is not int or row["pid"] <= 0
                or not isinstance(nonce, str) or re.fullmatch(r"[0-9a-f]{32}", nonce) is None
                or nonce in nonces or type(started) is not int or type(finished) is not int
                or started <= 0 or started < previous_finished or finished <= started):
            raise RuntimeError("Independent process identity/sequence incomplete: " + str(row.get("case")))
        nonces.add(nonce)
        previous_finished = finished


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--terminal-only", action="store_true", help="Fresh focused lifecycle + save + terminal + restart run")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/continue_flow"))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    work_root = resolve_profile_root(args.work_root)
    names = sources()
    cases = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle", "unsaved_terminal", "capture", "restore_and_overwrite", "restore_again", "pending_retry", "held_error", "terminal", "terminal_reject"]
    if args.terminal_only:
        cases = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle", "unsaved_terminal", "capture", "terminal", "terminal_reject"]
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
               "run": str(run), "checks": 0, "cases": cases, "terminal_only": args.terminal_only,
               "process_identity_schema": "continue_flow_process_identity_v2",
               "process_runs": [], "processes": []}
    locked = False
    project = None
    scene = None
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
        for case in cases:
            print("RUN " + case + " " + str(run), flush=True)
            child_env = env.copy()
            process_nonce = uuid.uuid4().hex
            child_env.update(LSH_CONTINUE_FLOW_CASE=case, LSH_CONTINUE_FLOW_REPORT=str(run / (case + ".json")),
                             LSH_CONTINUE_FLOW_PROCESS_NONCE=process_nonce)
            if case == "profile_guard": child_env["LSH_CONTINUE_FLOW_PROFILE"] = str(profile / "mismatch")
            if case == "public_gate": child_env["LSH_CONTINUE_FLOW_QA"] = "0"
            extra = ["--editor", "--import"] if case == "import" else ["res://continue_flow_qa.tscn"]
            # Dummy headless textures do not retain ImageTexture.update pixels.
            # World capture deliberately verifies the real fog GPU resource.
            graphics = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "1280x720"] if case in ["unsaved_terminal", "capture", "restore_and_overwrite", "restore_again", "pending_retry", "held_error", "terminal", "terminal_reject"] else ["--headless"]
            started = time.monotonic()
            log_file = evidence / (case + ".log")
            expected = 2 if case == "profile_guard" else 0
            step = {"case": case, "pid": None, "process_nonce": process_nonce,
                    "started_ns": None, "finished_ns": None, "exit_code": None,
                    "expected_exit_code": expected, "errors": None, "graphics": graphics}
            receipt["steps"].append(step)
            child = None
            try:
                with log_file.open("wb") as log:
                    step["started_ns"] = time.monotonic_ns()
                    child = subprocess.Popen([str(engine)] + graphics + ["--path", str(project)] + extra,
                        cwd=project, env=child_env, stdout=log, stderr=subprocess.STDOUT,
                        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                    step["pid"] = child.pid
                    while child.poll() is None:
                        time.sleep(0.2)
                        observed_log = log_file.read_text(encoding="utf-8", errors="replace")
                        if re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", observed_log) or time.monotonic() - started > 240:
                            step["stop_reason"] = "engine_error" if re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", observed_log) else "timeout"
                            break
            finally:
                if child is not None:
                    if child.poll() is None:
                        child.terminate()  # Only this runner's known child, after a concrete failure.
                        try: child.wait(timeout=15)
                        except subprocess.TimeoutExpired:
                            child.kill(); child.wait(timeout=15)
                    else:
                        child.wait()
                    step["exit_code"] = child.returncode
                    step["finished_ns"] = time.monotonic_ns()
                step["seconds"] = round(time.monotonic() - started, 2)
                if log_file.exists():
                    step["errors"] = len(re.findall(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", log_file.read_text(encoding="utf-8", errors="replace")))
                    step["log_sha256"] = sha(log_file)
            report = run / (case + ".json")
            if report.exists(): shutil.copyfile(report, evidence / report.name)
            if step["exit_code"] != expected or step["errors"] or step.get("stop_reason"):
                raise RuntimeError(case + " failed: " + str(log_file))
            if case == "profile_guard":
                if report.exists() or "PRIVATE_PROFILE_REQUIRED" not in log_file.read_text(encoding="utf-8"):
                    raise RuntimeError("Profile guard did not reject before fixture writes")
            elif case != "import":
                result = json.loads(report.read_text(encoding="utf-8"))
                validate_process_report(result, case, step)
                checks = result.get("checks", [])
                if result.get("passed") is not True or not checks or any(c.get("passed") is not True for c in checks):
                    raise RuntimeError(case + " missing or failed behavioral checks")
                if case in ["capture", "restore_and_overwrite", "restore_again", "pending_retry"] and result.get("result", {}).get("ok") is not True:
                    raise RuntimeError(case + " did not complete the requested save/restore operation")
                receipt["checks"] += len(checks)
                step["report_sha256"] = sha(report)
                receipt["processes"].append(step["pid"])
                receipt["process_runs"].append({key: step[key] for key in ["case", "pid", "process_nonce", "started_ns", "finished_ns"]})
        validate_process_sequence(receipt["steps"], cases)
        validate_process_sequence(receipt["process_runs"], [case for case in cases if case not in ["import", "profile_guard"]])
        if len(receipt["processes"]) != len(cases) - 2 or receipt["checks"] < (75 if args.terminal_only else 120):
            raise RuntimeError("Independent process or check coverage incomplete")
        receipt["complete"] = True
    except Exception as exc:
        receipt["failure"] = str(exc)
        raise
    finally:
        try:
            if project is not None:
                changes = []
                for row in receipt["source_files"]:
                    for where, path in [("source", ROOT / row["path"]), ("private", project / row["path"])]:
                        if not path.is_file() or sha(path) != row["sha256"]: changes.append({"where": where, "path": row["path"]})
                receipt["source_guard_checks"] = len(receipt["source_files"]) * 2
                receipt["source_changes"] = changes
                receipt["source_inventory_matches"] = sources() == names
                receipt["engine_unchanged"] = sha(engine) == receipt["godot_sha256"]
                receipt["scene_unchanged"] = scene is not None and scene.is_file() and sha(scene) == receipt.get("generated_scene_sha256")
                if changes or not all(receipt[k] for k in ["source_inventory_matches", "engine_unchanged", "scene_unchanged"]):
                    raise RuntimeError("Source, engine or generated scene changed during QA")
        except Exception as exc:
            receipt["source_guard_failure"] = str(exc); receipt["complete"] = False
        try:
            if evidence.exists():
                screenshots = run / "screenshots"
                if screenshots.exists():
                    shutil.copytree(screenshots, evidence / "screenshots")
                    receipt["screenshots"] = [{"path": p.name, "sha256": sha(p)} for p in sorted(screenshots.glob("*.png"))]
                for path in sorted(set(OWN + CHANGED)):
                    frozen = run / "project" / path
                    if frozen.exists():
                        dest = evidence / "source_snapshot" / path
                        dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(frozen, dest)
        except Exception as exc:
            receipt["artifact_archive_failure"] = str(exc); receipt["complete"] = False
        receipt["lock_acquired"] = locked
        receipt["lock_released"] = False
        try:
            if locked:
                receipt["lock_owned_at_release"] = LOCK.is_file() and LOCK.read_text(encoding="utf-8") == str(run)
                receipt["engine_running_at_release"] = running_engine()
                if receipt["lock_owned_at_release"] and not receipt["engine_running_at_release"]:
                    LOCK.unlink()
                    receipt["lock_released"] = not LOCK.exists()
                if not receipt["lock_released"]: raise RuntimeError("Owned engine lock could not be released")
        except Exception as exc:
            receipt["lock_release_failure"] = str(exc); receipt["complete"] = False
        if evidence.exists():
            (evidence / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "checks": receipt["checks"], "evidence": str(evidence)}), flush=True)
    return 0 if receipt["complete"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
