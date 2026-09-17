"""Run the prepared remaining-Unit diagnostic under the shared exclusive lock.

The only timed workload is the current defense200 fixed-camera M1 fixture.
Each mode gets a new short private profile and a fresh Godot process. These are
diagnostic observations; no normal FPS, optimization, or gameplay-equivalence claim.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
import run_stabilization_performance as guard

ROOT = Path(__file__).resolve().parents[1]


def source_snapshot(project):
    files = {}
    for base, dirs, names in os.walk(project, followlinks=False):
        dirs[:] = [name for name in dirs if name not in (".godot", ".git", "__pycache__")]
        for name in dirs + names:
            guard.no_links(Path(base) / name)
        for name in names:
            p = Path(base) / name
            files[p.relative_to(project).as_posix()] = guard.sha(p.read_bytes())
    return files


def analyze(observed, m1):
    guard.need(observed["complete"] and not observed["issues"], "Observer contract failed")
    presents = observed["presents"]
    raw = m1["raw_frame_ms"]
    guard.need(len(presents) == len(raw) and len(raw) > 0, "M1/presentation count mismatch")
    last = observed["start_usec"]
    for row, ms in zip(presents, raw):
        guard.need(row[0] > last and abs((row[0] - last) / 1000.0 - ms) < 1e-8, "M1/common-clock frame mismatch")
        last = row[0]
    guard.need(last == observed["end_usec"], "End clock mismatch")
    steps = observed["steps"]
    ids = [row["physics_id"] for row in steps]
    guard.need(ids == sorted(set(ids)) and steps, "Physical step ordering or empty scope")
    guard.need(len(steps) == observed["end_tick"] - observed["start_tick"], "Missing measured physics step")
    totals = {name: [0, 0, 0] for name in observed["scope_names"]}
    for step in steps:
        guard.need("unit._phys_body" in step["scopes"], "Step has no root Unit calls")
        for name, values in step["scopes"].items():
            guard.need(name in totals and len(values) == 3 and values[0] > 0, "Scope row invalid")
            totals[name][0] += values[0]
            if observed["timed"]:
                guard.need(values[1] >= values[2] >= 0, "Invalid inclusive/exclusive time")
                totals[name][1] += values[1]; totals[name][2] += values[2]
            else:
                guard.need(values[1:] == [-1, -1], "Clockless contains fabricated timing")
        if observed["timed"]:
            guard.need(sum(values[2] for values in step["scopes"].values()) == step["scopes"]["unit._phys_body"][1], "Nested exclusive conservation failed")
    rows = []
    for name, values in totals.items():
        rows.append({"scope": name, "calls": values[0], "calls_per_step": values[0] / len(steps),
                     "inclusive_us_per_step": values[1] / len(steps) if observed["timed"] else None,
                     "exclusive_us_per_step": values[2] / len(steps) if observed["timed"] else None})
    return {"complete": True, "timed": observed["timed"], "physics_steps": len(steps),
            "presented_frames": len(raw), "scope_rows": rows,
            "common_clock_frames_match": True, "nested_time_conservation": True if observed["timed"] else None,
            "note": "This only attributes instrumented work. Inclusive child times are nested and must not be added to parents. No FPS benefit or baseline acceptance."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepared", type=Path, required=True)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--profile-root", type=Path, default=Path("D:/LHPerfProfiles"))
    args = parser.parse_args()
    guard.need(args.profile_root.is_absolute(), "Private profile root must be absolute")
    guard.no_links(args.prepared)
    guard.no_links(args.profile_root)
    run = args.prepared.resolve()
    allowed = (ROOT / ".godot/stabilization_performance").resolve()
    guard.need(allowed in run.parents, "Prepared run outside dedicated private root")
    preparation = json.loads((run / "preparation.json").read_text(encoding="utf-8"))
    project = run / "project"
    baseline = Path(preparation["baseline_run"])
    guard.no_links(baseline)
    guard.need(guard.sha((baseline / "receipt.json").read_bytes()) == preparation["baseline_receipt_sha256"],
               "Completed baseline receipt changed")
    expected = dict(preparation["original_source_sha256"])
    committed = {row["path"]: row["git_oid"] for row in guard.tree(preparation["source_head"])}
    guard.need(committed == preparation["committed_blob_oids"], "Named production Git tree changed")
    for row in preparation["changes"]:
        guard.need(expected.get(row["path"]) == row["before_sha256"], "Derivative before source is not bound to baseline")
        guard.need(guard.sha((project / row["path"]).read_bytes()) == row["after_sha256"], "Prepared source drift")
        expected[row["path"]] = row["after_sha256"]
    guard.need(guard.sha((project / "tools/unit_remainder_observer.gd").read_bytes()) == preparation["observer_sha256"], "Observer drift")
    expected["tools/unit_remainder_observer.gd"] = preparation["observer_sha256"]
    expected["tools/unit_remainder_scopes.json"] = preparation["scopes_sha256"]
    guard.need(source_snapshot(project) == expected, "Prepared whole-source identity differs from bound baseline plus declared changes")
    exe = Path((ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip())
    lock = ROOT / ".godot/redraw_rejection_source.lock"
    info = {"preflight": True, "source_head": preparation["source_head"], "scopes": preparation["scopes"],
            "godot_pids": guard.godot_processes(), "lock_busy": lock.exists()}
    print(json.dumps(info), flush=True)
    if not args.run:
        return 0
    guard.need(not info["godot_pids"], "Godot slot unavailable")
    owner = json.dumps({"owner": "unit_remainder_diagnostic", "id": uuid.uuid4().hex, "pid": os.getpid()})
    with lock.open("x", encoding="utf-8") as f: f.write(owner)
    receipt = {"complete": False, "source_head": preparation["source_head"], "steps": [],
               "runner_sha256": guard.sha(Path(__file__).read_bytes()), "guard_sha256": guard.sha(Path(guard.__file__).read_bytes())}
    real = None
    player_before = None
    active = None
    def execute(label, env, extra, timeout=240):
        nonlocal active
        guard.need(not guard.godot_processes(), "Unexpected Godot before " + label)
        log = run / (label + ".log")
        guard.need(not log.exists(), "Do not overwrite a diagnostic attempt")
        start = time.monotonic()
        command = [str(exe), "--path", str(project)] + extra
        with log.open("wb") as f:
            active = subprocess.Popen(command, cwd=project, env=env, stdout=f, stderr=subprocess.STDOUT,
                                      creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            pid = active.pid
            try:
                code = active.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                active.kill(); active.wait(timeout=30); code = -1
            active = None
        errors = [line for line in log.read_text(encoding="utf-8", errors="strict").splitlines() if guard.ERROR.search(line)]
        receipt["steps"].append({"name": label, "pid": pid, "exit_code": code, "seconds": time.monotonic()-start, "errors": errors})
        guard.save(run / "receipt.json", receipt)
        guard.need(code == 0 and not errors and not guard.godot_processes(), "Diagnostic process failed: " + label)
        guard.need(guard.snapshot(real) == player_before, "Protected player data changed")
    try:
        text = (project / "project.godot").read_text(encoding="utf-8-sig")
        guard.need("config/use_custom_user_dir" not in text and "config/custom_user_dir_name" not in text,
                   "Custom player path mapping not reviewed")
        matches = re.findall(r'^config/name=("[^\n]+")\s*$', text, re.M)
        guard.need(len(matches) == 1, "Project name must resolve unambiguously")
        name = json.loads(matches[0])
        guard.need(not any(char in name for char in '<>:"/\\|?*'), "Unsafe project user directory name")
        real = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / name
        player_before = guard.snapshot(real)
        receipt["player_before_digest"] = guard.sha(json.dumps(player_before, sort_keys=True).encode())
        spec = importlib.util.spec_from_file_location("frozen_perf_environment", project / "tools/run_polish_performance.py")
        helper = importlib.util.module_from_spec(spec); spec.loader.exec_module(helper)
        profiles = {}
        for mode in ("import", "timed", "clockless"):
            profile = args.profile_root / (run.name + "_" + mode)
            guard.no_links(profile); profile.mkdir(parents=True, exist_ok=False)
            env, unused = helper.environment()
            for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
                path = profile / key.lower(); path.mkdir(); env[key] = str(path)
            env.update(POLISH_CASE="defense200", POLISH_CAMERA="fixed", POLISH_SECONDS="10",
                       POLISH_EFFECTS_QUALITY="standard", POLISH_OUT=str(run / (mode + "_m1.json")),
                       UNIT_REMAINDER_MODE=mode, UNIT_REMAINDER_OUT=str(run / (mode + "_observer.json")),
                       CAMPAIGN_QA="1", STEAM_DISABLED="1")
            profiles[mode] = (env, profile / "appdata/Godot/app_userdata" / name)
        sources_before_import = source_snapshot(project)
        execute("import", profiles["import"][0], ["--headless", "--editor", "--import"], 600)
        sources = source_snapshot(project)
        changed = [name for name, digest in sources_before_import.items() if sources.get(name) != digest]
        added = sorted(set(sources) - set(sources_before_import))
        guard.need(not changed and set(added) <= {"tools/unit_remainder_observer.gd.uid"}, "Unexpected import source mutation")
        receipt["import_added_sources"] = added
        receipt["source_sha256"] = sources
        deployment_hashes = []
        input_hashes = []
        for mode in ("timed", "clockless"):
            execute(mode, profiles[mode][0], ["--script", "res://tools/polish_performance_probe.gd"])
            guard.need(source_snapshot(project) == sources, "Diagnostic sources drifted")
            observed = json.loads((run / (mode + "_observer.json")).read_text(encoding="utf-8"))
            m1 = json.loads((run / (mode + "_m1.json")).read_text(encoding="utf-8"))
            expected = profiles[mode][1].resolve()
            guard.need(Path(observed["actual_user_dir"]).resolve() == expected and Path(m1["actual_user_dir"]).resolve() == expected, "Private runtime user path mismatch")
            guard.need(m1["integrity_passed"] and m1["sample_complete"], "M1 short diagnostic fixture incomplete")
            deployment_hashes.append(guard.sha(json.dumps(m1["initial_units"], sort_keys=True).encode()))
            input_hashes.append(guard.sha(json.dumps(m1["inputs"], sort_keys=True).encode()))
            result = analyze(observed, m1)
            guard.save(run / (mode + "_analysis.json"), result)
            print(json.dumps({"mode": mode, "physics_steps": result["physics_steps"], "complete": True}), flush=True)
        guard.need(len(set(deployment_hashes)) == 1 and len(set(input_hashes)) == 1,
                   "Timed/clockless fixture deployment or input plan differs")
        receipt["initial_deployment_matches"] = True
        receipt["input_plan_matches"] = True
        receipt["complete"] = True
    except BaseException as exc:
        receipt["error"] = type(exc).__name__ + ": " + str(exc)
        raise
    finally:
        if active is not None: active.kill(); active.wait(timeout=30)
        if player_before is not None:
            after = guard.snapshot(real)
            receipt["player_unchanged"] = after == player_before
            receipt["player_after_digest"] = guard.sha(json.dumps(after, sort_keys=True).encode())
        else:
            receipt["player_unchanged"] = None
        receipt["godot_pids_after"] = guard.godot_processes()
        if lock.is_file() and lock.read_text(encoding="utf-8") == owner and not receipt["godot_pids_after"]:
            lock.unlink(); receipt["lock_released"] = True
        else:
            receipt["lock_released"] = False; receipt["complete"] = False
        if not receipt["player_unchanged"]: receipt["complete"] = False
        guard.save(run / "receipt.json", receipt)
        print("RECEIPT " + str(run / "receipt.json"), flush=True)
    return 0 if (receipt["complete"] and receipt.get("player_unchanged") is True
                 and receipt.get("lock_released") is True) else 1


if __name__ == "__main__":
    raise SystemExit(main())
