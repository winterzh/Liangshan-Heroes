"""Freeze and run isolated campaign FX partition components across fresh graphical processes.

Preflight is read-only. Import and invalid-profile checks are headless; component
and restart render through gl_compatibility with Dummy audio at 1280x720. Images
are archived evidence, never a claim of human visual approval or a restored world.
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

OWN = ["scripts/run_visual_graph.gd", "scripts/run_campaign_presentation_state.gd",
       "scripts/run_campaign_mission_state.gd", "scripts/run_official_restore_profile.gd",
       "scripts/run_level3_world_factory.gd", "scripts/run_campaign_level_state.gd",
       "scripts/run_unit_graph.gd", "scripts/run_unit_state.gd", "scripts/run_battle_barrier.gd",
       "scripts/run_local_lifecycle.gd", "tools/campaign_fx_partition_qa.gd",
       "tools/run_campaign_fx_partition_qa.py", "tools/run_steam_integration_qa.py"]
SNAPSHOT = OWN + ["scripts/campaign.gd", "scripts/campaign_mission.gd", "scripts/localization.gd",
    "scripts/run_state_value_codec.gd", "scripts/run_graph_identity.gd", "scripts/hero_inventory.gd",
    "scripts/levels/level3_zhujiazhuang_rts.gd", "scripts/level_base.gd", "scripts/unit.gd", "scripts/battle.gd",
    "scripts/game_map.gd", "scripts/defs.gd", "scripts/ability_visuals.gd", "scripts/art_db.gd",
    "scripts/run_linked_fx_state.gd", "scripts/run_procedural_fx_state.gd",
    "scripts/run_death_remains_state.gd", "scripts/run_content_identity.gd"]
SCENE_NAME = "campaign_fx_partition_qa.tscn"
SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/campaign_fx_partition_qa.gd" id="1"]
[node name="CampaignFXPartitionQA" type="Node"]
script = ExtResource("1")
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    # Only this explicit dependency list extends tracked runtime sources.
    # Other tasks\' untracked modules are never discovered or copied.
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


def archive_run_artifacts(run, evidence):
    """Read only fixed artifact locations in this invocation, never report-selected paths."""
    if not run.is_dir():
        return
    candidates = [(path, evidence / path.name) for path in sorted(run.glob("*_report.json"))]
    candidates.append((run / "fx_partition_snapshot.json", evidence / "fx_partition_snapshot.json"))
    candidates += [(path, evidence / "screenshots" / path.name) for path in sorted(run.glob("*.png"))]
    directory = run / "screenshots"
    if directory.exists():
        if directory.is_symlink() or getattr(directory.lstat(), "st_file_attributes", 0) & 0x400:
            raise RuntimeError("Screenshot directory is a reparse path")
        for path in sorted(directory.rglob("*")):
            if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400:
                raise RuntimeError("Screenshot artifact is a reparse path")
            if path.is_file(): candidates.append((path, evidence / "screenshots" / path.relative_to(directory)))
    for source, destination in candidates:
        if not source.exists(): continue
        if source.is_symlink() or getattr(source.lstat(), "st_file_attributes", 0) & 0x400 or not source.is_file():
            raise RuntimeError("Artifact is not a regular private-run file: " + source.name)
        source.resolve().relative_to(run.resolve())
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)


def screenshot_manifest(directory):
    rows = []
    if not directory.exists(): return rows
    for path in sorted(directory.rglob("*.png")):
        data = path.read_bytes()
        if len(data) < 24 or data[:8] != bytes.fromhex("89504e470d0a1a0a") or data[12:16] != b"IHDR":
            raise RuntimeError("Invalid archived PNG: " + path.name)
        rows.append({"path": "screenshots/" + path.relative_to(directory).as_posix(),
                     "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                     "width": int.from_bytes(data[16:20], "big"), "height": int.from_bytes(data[20:24], "big"),
                     "visually_inspected": False})
    return rows


def run_child(engine, project, extra, env, log_file, receipt, case):
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
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/campaign_fx_partition"))
    args = parser.parse_args()
    work_root = resolve_profile_root(args.work_root)
    if not args.run:
        engine = resolve_godot(args.godot)
        print(json.dumps({"preflight": True, "source_files": len(sources()), "lock_busy": LOCK.exists(),
                          "work_root": str(work_root), "engine_sha256": sha(engine)}))
        return 0
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / name
    evidence = ROOT / "qa/campaign_fx_partition_20260909" / name
    evidence.mkdir(parents=True, exist_ok=False)
    (evidence.parent / ".gdignore").touch(exist_ok=True)
    receipt = {"schema": "campaign_fx_partition_runner_v1", "complete": False,
        "component_only": True, "full_world": False, "normal_gameplay": False, "real_steam": False,
        "fresh_import": True, "run": str(run), "source_files": [], "steps": [], "checks": 0,
        "pid_source": "runner Popen and matching behavior report", "synthetic_fixture": True,
        "graphical_behavior": True, "visual_inspection": False, "source_snapshot": [], "phase_checks": {}}
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
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_CAMPAIGN_FX_PARTITION_PROFILE=str(profile),
            LSH_CAMPAIGN_FX_PARTITION_ENGINE_SHA256=receipt["godot_sha256"], LSH_CAMPAIGN_FX_PARTITION_SNAPSHOT=str(run / "fx_partition_snapshot.json"))
        for case in ["import", "profile_guard", "component", "restart"]:
            phase_guard(receipt, case + "_before", run, project, engine, names)
            print("RUN " + case + " " + str(evidence), flush=True)
            child_env = env.copy()
            child_env.update(LSH_CAMPAIGN_FX_PARTITION_PHASE=case, LSH_CAMPAIGN_FX_PARTITION_REPORT=str(run / (case + "_report.json")))
            if case == "profile_guard": child_env["LSH_CAMPAIGN_FX_PARTITION_PROFILE"] = str(profile / "mismatch")
            if case == "import":
                extra = ["--headless", "--editor", "--import"]
            elif case == "profile_guard":
                extra = ["--headless", "res://" + SCENE_NAME]
            else:
                extra = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                         "--resolution", "1280x720", "res://" + SCENE_NAME]
            report_path = run / (case + "_report.json")
            try:
                step = run_child(engine, project, extra, child_env, evidence / (case + ".log"), receipt, case)
            finally:
                archive_run_artifacts(run, evidence)
                phase_guard(receipt, case + "_after", run, project, engine, names)
            if step["exit_code"] != step["expected_exit_code"] or step["errors"] or step["stop_reason"]:
                raise RuntimeError(case + " failed; see archived log/report")
            if case == "profile_guard":
                text = (evidence / (case + ".log")).read_text(encoding="utf-8", errors="replace")
                if report_path.exists() or (run / "fx_partition_snapshot.json").exists() or "PRIVATE_PROFILE_REQUIRED" not in text:
                    raise RuntimeError("Invalid profile did not reject before fixture/report writes")
            if case in ["component", "restart"]:
                report = json.loads(report_path.read_text(encoding="utf-8"))
                if not isinstance(report, dict): raise RuntimeError("Report must be a JSON object: " + case)
                rows = report.get("checks", [])
                minimum = 70 if case == "component" else 20
                if report.get("phase") != case or report.get("passed") is not True or report.get("component_only") is not True or any(report.get(k) is not False for k in ["full_world", "real_steam", "normal_gameplay"]) or not isinstance(rows, list) or len(rows) < minimum or any(not isinstance(r, dict) or not isinstance(r.get("label"), str) or not r["label"] or r.get("passed") is not True for r in rows) or type(report.get("pid")) is not int or report["pid"] != step["pid"]:
                    raise RuntimeError("Incomplete/failed/misattributed " + case + " report")
                step["report_sha256"] = sha(report_path)
                receipt["phase_checks"][case] = len(rows); receipt["checks"] += len(rows)
        fixture = json.loads((run / "fx_partition_snapshot.json").read_text(encoding="utf-8"))
        receipt["fixture_sha256"] = sha(run / "fx_partition_snapshot.json")
        producer = next(step for step in receipt["steps"] if step["case"] == "component")
        consumer = next(step for step in receipt["steps"] if step["case"] == "restart")
        if producer["pid"] == consumer["pid"] or producer["pid"] <= 0 or consumer["pid"] <= 0:
            raise RuntimeError("Component and restart must be distinct observed native processes")
        if not isinstance(fixture, dict) or fixture.get("synthetic_fixture") is not True or type(fixture.get("producer_pid")) is not int or fixture["producer_pid"] != producer["pid"]:
            raise RuntimeError("Snapshot producer is not the observed component process")
        for case in ["component", "restart"]:
            report_path = run / (case + "_report.json")
            observed = next(step for step in receipt["steps"] if step["case"] == case)
            if sha(report_path) != observed["report_sha256"] or sha(evidence / report_path.name) != observed["report_sha256"]:
                raise RuntimeError("Completed behavior report changed after its observed phase: " + case)
            linked = json.loads(report_path.read_text(encoding="utf-8"))
            if type(linked.get("snapshot_producer_pid")) is not int or linked["snapshot_producer_pid"] != producer["pid"] or linked.get("snapshot_sha256") != receipt["fixture_sha256"]:
                raise RuntimeError("Report does not identify exact producer snapshot: " + case)
        receipt["process_link"] = {"producer_pid": producer["pid"], "consumer_pid": consumer["pid"],
                                   "snapshot_sha256": receipt["fixture_sha256"], "verified": True}
        receipt["complete"] = True
    except Exception as exc:
        receipt["failure"] = str(exc); failed = True
    finally:
        # Preserve every completed/partial report, snapshot and screenshot even on failures.
        try:
            archive_run_artifacts(run, evidence)
            receipt["screenshots"] = screenshot_manifest(evidence / "screenshots")
        except Exception as exc:
            receipt["artifact_archive_failure"] = str(exc); failed = True
        # These guards also run on failures, before the lock release is recorded.
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
