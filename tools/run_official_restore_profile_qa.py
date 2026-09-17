"""Freeze and run isolated official-profile/Level3 component QA.

Without --run this performs read-only preflight. Engine work uses the shared lock,
a fresh private import and four private environment paths. Never opens player entry.
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

OWN = ["scripts/run_official_restore_profile.gd", "scripts/run_level3_world_factory.gd",
       "tools/official_restore_profile_qa.gd", "tools/run_official_restore_profile_qa.py",
       "tools/run_steam_integration_qa.py"]
SNAPSHOT = OWN + ["scripts/run_campaign_level_state.gd", "scripts/run_state_value_codec.gd",
    "scripts/campaign.gd", "scripts/steam_run_policy.gd", "scripts/levels/skirmish.gd",
    "scripts/levels/level3_zhujiazhuang_rts.gd", "scripts/level_base.gd", "scripts/unit.gd",
    "scripts/defs.gd", "scripts/ability_visuals.gd", "scripts/campaign_environment.gd", "scripts/art_db.gd"]
SCENE_NAME = "official_restore_profile_qa.tscn"
SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/official_restore_profile_qa.gd" id="1"]
[node name="OfficialRestoreProfileQA" type="Node"]
script = ExtResource("1")
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    # Never include another task's untracked files. Only the two new production
    # modules and this explicit QA driver/helper extend the tracked runtime set.
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    names = {n for n in raw.decode("utf-8").split("\0") if n and
             (n in ROOT_FILES or n.split("/")[0] in RUNTIME_DIRS)}
    return sorted(names | set(OWN))


def running_engine():
    query = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", query], text=True).strip()
    value = json.loads(raw) if raw else []
    return sorted(value if isinstance(value, list) else [value])


def phase_guard(receipt, label, run, project, engine, names):
    """Record before/after boundaries; any changed boundary rejects the attempt."""
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
        digest = hashlib.sha256(); count = 0
        if directory.exists():
            for path in sorted(directory.rglob("*")):
                if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400:
                    raise RuntimeError("Protected player directory has a reparse entry")
                if path.is_file():
                    digest.update(path.relative_to(directory).as_posix().encode("utf-8"))
                    digest.update(bytes.fromhex(sha(path))); count += 1
        result[key] = {"exists": directory.exists(), "file_count": count, "sha256": digest.hexdigest()}
    return result


def run_child(engine, project, extra, env, log_file, receipt, case):
    command = [str(engine), "--headless", "--path", str(project)] + extra
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
                if re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", text): step["stop_reason"] = "engine_error"
                elif time.monotonic() - started > 300: step["stop_reason"] = "timeout"
                if step["stop_reason"]: break
    finally:
        if child is not None:
            if child.poll() is None:
                child.terminate()
                try: child.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait(timeout=15)
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
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/official_restore_profile"))
    args = parser.parse_args()
    work_root = resolve_profile_root(args.work_root)
    if not args.run:
        engine = resolve_godot(args.godot)
        print(json.dumps({"preflight": True, "source_files": len(sources()), "lock_busy": LOCK.exists(),
                          "work_root": str(work_root), "engine_sha256": sha(engine)}))
        return 0
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / name
    evidence = ROOT / "qa/official_restore_profile_20260909" / name
    evidence.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "official_restore_profile_runner_v1", "complete": False,
        "component_only": True, "full_world": False, "normal_gameplay": False, "real_steam": False,
        "fresh_import": True, "run": str(run), "source_files": [], "steps": [], "checks": 0,
        "pid_source": "runner Popen and matching behavior report", "source_snapshot": [], "phase_checks": {}}
    locked = False; engine = None; project = None; names = []; failed = False
    try:
        engine = resolve_godot(args.godot)
        receipt["godot_sha256"] = sha(engine)
        receipt["source_head"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        names = sources()
        receipt["protected_player_before"] = player_digest()
        receipt["engines_before"] = running_engine()
        if receipt["engines_before"]: raise RuntimeError("Godot/game engine slot occupied")
        with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
        locked = True
        if running_engine(): raise RuntimeError("Engine started before lock acquisition")
        run.mkdir(parents=True, exist_ok=False)
        project = run / "project"; project.mkdir()
        for relative in names:
            data = (ROOT / relative).read_bytes()
            dest = project / relative; dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(data)
            receipt["source_files"].append({"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        (project / SCENE_NAME).write_text(SCENE, encoding="utf-8", newline="\n")
        receipt["generated_scene_sha256"] = sha(project / SCENE_NAME)
        for relative in sorted(set(SNAPSHOT + [SCENE_NAME])):
            dest = evidence / "source_snapshot" / relative; dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / relative, dest)
            receipt["source_snapshot"].append({"path": relative, "bytes": dest.stat().st_size, "sha256": sha(dest)})
        (evidence / "source_manifest.json").write_text(json.dumps({"sources": receipt["source_files"],
            "snapshots": receipt["source_snapshot"], "generated_scene_sha256": receipt["generated_scene_sha256"]}, indent=2) + "\n", encoding="utf-8")
        profile = create_private_profile(run, work_root / "profiles")
        receipt["private_profile"] = str(profile)
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("LSH_") or key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR"]:
                env.pop(key)
        receipt["private_environment"] = {}
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            directory = profile / key.lower(); directory.mkdir()
            env[key] = str(directory); receipt["private_environment"][key] = str(directory)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_OFFICIAL_PROFILE_ROOT=str(profile),
            LSH_OFFICIAL_ENGINE_SHA256=receipt["godot_sha256"], LSH_OFFICIAL_PROFILE_FIXTURE=str(run / "fixture.json"))
        for case in ["import", "profile_guard", "profile_runtime", "level_restore"]:
            phase_guard(receipt, case + "_before", run, project, engine, names)
            print("RUN " + case + " " + str(evidence), flush=True)
            child_env = env.copy()
            child_env.update(LSH_OFFICIAL_PROFILE_PHASE=case, LSH_OFFICIAL_PROFILE_REPORT=str(run / (case + ".json")))
            if case == "profile_guard": child_env["LSH_OFFICIAL_PROFILE_ROOT"] = str(profile / "mismatch")
            extra = ["--editor", "--import"] if case == "import" else ["res://" + SCENE_NAME]
            report_path = run / (case + ".json")
            try:
                step = run_child(engine, project, extra, child_env, evidence / (case + ".log"), receipt, case)
            finally:
                if report_path.exists(): shutil.copyfile(report_path, evidence / report_path.name)
                if (run / "fixture.json").exists(): shutil.copyfile(run / "fixture.json", evidence / "fixture.json")
                phase_guard(receipt, case + "_after", run, project, engine, names)
            if step["exit_code"] != step["expected_exit_code"] or step["errors"] or step["stop_reason"]:
                raise RuntimeError(case + " failed; see archived log/report")
            if case == "profile_guard":
                text = (evidence / (case + ".log")).read_text(encoding="utf-8", errors="replace")
                if report_path.exists() or (run / "fixture.json").exists() or "PRIVATE_PROFILE_REQUIRED" not in text:
                    raise RuntimeError("Invalid profile did not reject before fixture/report writes")
            if case in ["profile_runtime", "level_restore"]:
                report = json.loads(report_path.read_text(encoding="utf-8"))
                rows = report.get("checks", [])
                minimum = 80 if case == "profile_runtime" else 140
                if report.get("schema") != "official_restore_profile_qa_v1" or report.get("phase") != case or report.get("passed") is not True or report.get("component_only") is not True or any(report.get(k) is not False for k in ["full_world", "normal_gameplay", "real_steam"]) or len(rows) < minimum or any(r.get("passed") is not True for r in rows) or len({r.get("label") for r in rows}) != len(rows) or report.get("pid") != step["pid"]:
                    raise RuntimeError("Incomplete/failed/misattributed " + case + " report")
                step["report_sha256"] = sha(report_path)
                receipt["phase_checks"][case] = len(rows); receipt["checks"] += len(rows)
        fixture = json.loads((run / "fixture.json").read_text(encoding="utf-8"))
        if fixture.get("schema") != "official_profile_level_fixture_v1" or len(fixture.get("records", [])) != 3 or len(fixture.get("unit_keys", [])) != 21:
            raise RuntimeError("Incomplete producer fixture")
        receipt["fixture_sha256"] = sha(run / "fixture.json")
        producer = next(s for s in receipt["steps"] if s["case"] == "profile_runtime")
        consumer = next(s for s in receipt["steps"] if s["case"] == "level_restore")
        if producer["pid"] == consumer["pid"] or fixture.get("producer_pid") != producer["pid"]:
            raise RuntimeError("Fixture producer/consumer PID mismatch")
        for case in ["profile_runtime", "level_restore"]:
            linked = json.loads((run / (case + ".json")).read_text(encoding="utf-8"))["fixture"]
            if linked.get("producer_pid") != producer["pid"] or linked.get("sha256") != receipt["fixture_sha256"]:
                raise RuntimeError("Report does not identify exact producer fixture: " + case)
        receipt["complete"] = True
    except Exception as exc:
        receipt["failure"] = str(exc); failed = True
    finally:
        # These run on failures too. Preserve the raw attempt before releasing its lock.
        if "protected_player_before" in receipt:
            try:
                receipt["protected_player_after"] = player_digest()
                receipt["protected_player_unchanged"] = receipt["protected_player_after"] == receipt["protected_player_before"]
                if not receipt["protected_player_unchanged"]: raise RuntimeError("Protected player summary changed")
            except Exception as exc:
                receipt["protection_failure"] = str(exc); failed = True
        if project is not None:
            try:
                changed = []
                for row in receipt["source_files"]:
                    for where, path in [("source", ROOT / row["path"]), ("private", project / row["path"])]:
                        if not path.is_file() or sha(path) != row["sha256"]: changed.append({"where": where, "path": row["path"]})
                receipt["source_guard_checks"] = 2 * len(receipt["source_files"])
                receipt["source_changes"] = changed
                if changed: failed = True
                if engine is not None and sha(engine) != receipt["godot_sha256"]: receipt["engine_changed"] = True; failed = True
                if (project / SCENE_NAME).exists() and sha(project / SCENE_NAME) != receipt.get("generated_scene_sha256"): receipt["scene_changed"] = True; failed = True
            except Exception as exc:
                receipt["source_guard_failure"] = str(exc); failed = True
        if not (evidence / "source_manifest.json").exists():
            (evidence / "source_manifest.json").write_text(json.dumps({"sources": receipt["source_files"],
                "snapshots": receipt["source_snapshot"], "generated_scene_sha256": receipt.get("generated_scene_sha256"),
                "copy_complete": len(receipt["source_files"]) == len(names) and bool(names)}, indent=2) + "\n", encoding="utf-8")
        receipt["lock_acquired"] = locked
        receipt["lock_released"] = False
        try:
            receipt["engines_after"] = running_engine()
            if receipt["engines_after"]: failed = True
            if locked:
                receipt["lock_owned_at_release"] = LOCK.is_file() and LOCK.read_text(encoding="utf-8") == str(run)
                if receipt["lock_owned_at_release"] and not receipt["engines_after"]:
                    LOCK.unlink()
                    receipt["lock_released"] = not LOCK.exists()
                if not receipt["lock_released"]: failed = True
        except Exception as exc:
            receipt["lock_release_failure"] = str(exc); failed = True
        receipt["complete"] = receipt["complete"] and not failed
        receipt["files"] = [{"path": p.relative_to(evidence).as_posix(), "bytes": p.stat().st_size, "sha256": sha(p)} for p in sorted(evidence.rglob("*")) if p.is_file() and p.name != "receipt.json"]
        (evidence / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "checks": receipt["checks"], "evidence": str(evidence)}, ensure_ascii=False), flush=True)
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
