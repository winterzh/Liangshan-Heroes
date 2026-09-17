"""Native acceptance of an explicitly frozen stable-identity candidate.

Read-only preflight unless --run. Copies current production bytes by a committed
path whitelist, overlays exactly the frozen candidate, and owns the common Godot
lock. Never edits production, Git, or a real player's files.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
import run_stabilization_performance as guard

ROOT = Path(__file__).resolve().parents[1]
DRIVER = "tools/stabilization_identity/identity_smoke.gd"
PREFIX = "[stable-identity candidate QA] "


def files_snapshot(project):
    result = {}
    for base, dirs, files in os.walk(project, followlinks=False):
        dirs[:] = [x for x in dirs if x not in (".godot", ".git", "__pycache__")]
        for name in dirs + files:
            guard.no_links(Path(base) / name)
        for name in files:
            path = Path(base) / name
            result[path.relative_to(project).as_posix()] = guard.sha(path.read_bytes())
    return result


def current_sources(rows):
    result = {}
    for row in rows:
        path = ROOT / row["path"]
        guard.no_links(path)
        result[row["path"]] = guard.sha(path.read_bytes())
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-head", required=True)
    parser.add_argument("--freeze-sha256", required=True)
    parser.add_argument("--candidate", type=Path, default=ROOT / "scratchpad/stabilization_identity_20260907")
    parser.add_argument("--profile-root", type=Path, default=Path("D:/LHPerfProfiles"))
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    guard.no_links(args.candidate)
    candidate = args.candidate.resolve()
    guard.need((ROOT / "scratchpad").resolve() in candidate.parents, "Candidate outside scratchpad")
    guard.need(args.profile_root.is_absolute(), "Private profile must be absolute")
    guard.no_links(args.profile_root)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    guard.need(head == args.source_head, "Expected exact current HEAD")
    rows = guard.tree(head)
    guard.need(rows and subprocess.run(["git", "diff", "--quiet", head, "--"] + sorted(guard.DIRS | guard.FIXED), cwd=ROOT).returncode == 0,
               "Production has semantic Git differences; freeze must be reviewed again")
    guard.need(guard.sha((candidate / "freeze.json").read_bytes()) == args.freeze_sha256, "Unapproved candidate freeze")
    freeze = json.loads((candidate / "freeze.json").read_text(encoding="utf-8"))
    for name, digest in freeze["inputs"].items():
        guard.need(not Path(name).is_absolute() and ".." not in Path(name).parts, "Unsafe frozen input")
        guard.no_links(candidate / name)
        guard.need(guard.sha((candidate / name).read_bytes()) == digest, "Frozen candidate input changed: " + name)
    source_receipt = json.loads((candidate / "source_receipt.json").read_text(encoding="utf-8"))
    changes = source_receipt["files"]
    source_before = current_sources(rows)
    guard.need(len(changes) == len({x["path"] for x in changes}) == freeze["candidate_file_count"] == 24,
               "Expected exactly 24 distinct candidate sources")
    for change in changes:
        name = change["path"]
        guard.need(source_before.get(name) == change["before_raw_sha256"], "Production before bytes changed: " + name)
        path = candidate / "candidate" / name
        guard.no_links(path)
        guard.need(guard.sha(path.read_bytes()) == change["candidate_sha256"], "Candidate source changed: " + name)
    exe = Path((ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip())
    guard.no_links(exe)
    lock = ROOT / ".godot/redraw_rejection_source.lock"
    guard.no_links(lock)
    info = {"preflight": True, "source_head": head, "source_mode": "current production raw bytes by committed path whitelist",
            "production_files": len(rows), "candidate_files": 24, "freeze_sha256": args.freeze_sha256,
            "godot_sha256": guard.sha(exe.read_bytes()), "godot_pids_before": guard.godot_processes(), "lock_busy": lock.exists()}
    print(json.dumps(info, ensure_ascii=False), flush=True)
    if not args.run:
        return 0
    guard.need(not info["godot_pids_before"] and not info["lock_busy"], "Godot slot unavailable")
    run_id = "identity_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + uuid.uuid4().hex[:8]
    run = ROOT / ".godot/stabilization_identity" / run_id
    guard.no_links(run)
    run.mkdir(parents=True, exist_ok=False)
    owner = json.dumps({"owner": "stabilization_identity", "run_id": run_id, "pid": os.getpid()})
    with lock.open("x", encoding="utf-8") as stream:
        stream.write(owner)
    receipt = dict(info, complete=False, run_id=run_id, steps=[], final_issues=[],
                   runner_sha256=guard.sha(Path(__file__).read_bytes()), guard_sha256=guard.sha(Path(guard.__file__).read_bytes()))
    active = None
    player = None
    player_before = None
    project = run / "project"
    profile = args.profile_root / run_id
    expected = None

    def execute(label, extra, env, timeout):
        nonlocal active
        guard.need(not guard.godot_processes(), "Unexpected Godot before " + label)
        log = run / (label + ".log")
        start = time.monotonic()
        command = [str(exe), "--headless", "--path", str(project)] + extra
        with log.open("xb") as stream:
            active = subprocess.Popen(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                      creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            pid = active.pid
            terminated_for = None
            while True:
                try:
                    code = active.wait(timeout=0.5)
                    break
                except subprocess.TimeoutExpired:
                    elapsed = time.monotonic() - start
                    if guard.ERROR.search(log.read_text(encoding="utf-8", errors="replace")):
                        terminated_for = "native error in owned process log"
                    elif elapsed >= timeout:
                        terminated_for = "timeout"
                    if terminated_for:
                        active.kill(); code = active.wait(timeout=30)
                        break
            active = None
        text = log.read_text(encoding="utf-8", errors="strict")
        errors = [line for line in text.splitlines() if guard.ERROR.search(line)]
        receipt["steps"].append({"name": label, "pid": pid, "exit_code": code, "child_exit_confirmed": True,
                                 "seconds": time.monotonic() - start, "command": command, "log_sha256": guard.sha(log.read_bytes()),
                                 "terminated_for": terminated_for, "errors": errors})
        guard.save(run / "receipt.json", receipt)
        guard.need(code == 0 and not terminated_for and not errors and not guard.godot_processes(), "Native process failed: " + label)
        guard.need(current_sources(rows) == source_before, "Protected production changed")
        guard.need(guard.snapshot(player) == player_before, "Protected player data changed")
        return pid, text

    try:
        project.mkdir()
        for row in rows:
            raw = (ROOT / row["path"]).read_bytes()
            guard.need(guard.sha(raw) == source_before[row["path"]], "Production changed during copy")
            dest = project / row["path"]
            dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(raw)
            row.update(raw_sha256=source_before[row["path"]], bytes=len(raw))
        receipt["production_sources"] = rows
        receipt["candidate_changes"] = changes
        for change in changes:
            raw = (candidate / "candidate" / change["path"]).read_bytes()
            guard.need(guard.sha(raw) == change["candidate_sha256"], "Candidate changed during copy")
            (project / change["path"]).write_bytes(raw)
        driver = project / DRIVER
        driver.parent.mkdir(parents=True); driver.write_bytes((candidate / "identity_smoke.gd").read_bytes())
        guard.need(guard.sha(driver.read_bytes()) == freeze["inputs"]["identity_smoke.gd"], "Driver changed during copy")
        (run / "executed_runner.py.txt").write_bytes(Path(__file__).read_bytes())
        (run / "executed_guard.py.txt").write_bytes(Path(guard.__file__).read_bytes())
        (run / "freeze.json").write_bytes((candidate / "freeze.json").read_bytes())
        guard.need(guard.sha((run / "freeze.json").read_bytes()) == args.freeze_sha256, "Freeze changed during copy")
        expected = files_snapshot(project)
        config = (project / "project.godot").read_text(encoding="utf-8-sig")
        guard.need("config/use_custom_user_dir" not in config and "config/custom_user_dir_name" not in config, "Custom user mapping not reviewed")
        names = re.findall(r'^config/name=("[^\n]+")\s*$', config, re.M)
        guard.need(len(names) == 1, "Project name is ambiguous")
        name = json.loads(names[0])
        guard.need(not any(x in name for x in '<>:"/\\|?*'), "Unsafe player directory name")
        player = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / name
        player_before = guard.snapshot(player)
        receipt["player_before_digest"] = guard.sha(json.dumps(player_before, sort_keys=True).encode())
        guard.no_links(profile); profile.mkdir(parents=True, exist_ok=False)
        env = os.environ.copy()
        switches = set()
        for path in (project / "scripts").rglob("*.gd"):
            switches.update(re.findall(r'OS\.(?:get_environment|has_environment)\(\s*["\']([A-Z0-9_]+)["\']', path.read_text(encoding="utf-8-sig")))
        for key in list(env):
            if key in switches or key.startswith(("PERF_", "POLISH_", "DEF_", "AI_FRIENDLY", "RTS_TEST_", "YF_", "RUN_RESTORE_", "UNIT_REMAINDER_")):
                env.pop(key)
        for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
            dest = profile / key.lower(); dest.mkdir(); env[key] = str(dest)
        env.update(CAMPAIGN_QA="1", STEAM_DISABLED="1")
        private_user = profile / "appdata/Godot/app_userdata" / name
        receipt["private_profile"] = str(profile)
        cache = ROOT / ".godot/imported"
        if cache.exists():
            guard.no_links(cache)
            for base, dirs, files in os.walk(cache, followlinks=False):
                for item in dirs + files: guard.no_links(Path(base) / item)
            shutil.copytree(cache, project / ".godot/imported")
            receipt["cache_seed"] = "imported texture cache only; native import still required"
        execute("import", ["--editor", "--import"], env, 600)
        after_import = files_snapshot(project)
        guard.need(all(after_import.get(k) == v for k, v in expected.items()), "Import modified copied sources")
        added = sorted(set(after_import) - set(expected))
        guard.need(set(added) <= {DRIVER + ".uid"}, "Unexpected import additions")
        receipt["import_added_sources"] = added
        expected = after_import
        report_path = run / "identity_report.json"
        manifest = {"run_id": run_id, "private_user": str(private_user), "report": str(report_path), "source_sha256": expected}
        manifest_path = run / "manifest.json"
        guard.save(manifest_path, manifest)
        env["RUN_RESTORE_QA_MANIFEST"] = str(manifest_path)
        pid, output = execute("identity", ["--script", "res://" + DRIVER], env, 240)
        observed = json.loads(report_path.read_text(encoding="utf-8"))
        printed = [json.loads(line[len(PREFIX):]) for line in output.splitlines() if line.startswith(PREFIX)]
        guard.need(printed == [observed], "Stdout/report are missing, duplicated or disagree")
        guard.need(observed["suite"] == "stable-identity-candidate" and observed["run_id"] == run_id and observed["process_id"] == pid,
                   "Report process/run identity mismatch")
        guard.need(Path(observed["actual_user_dir"]).resolve() == private_user.resolve(), "Wrong runtime user directory")
        guard.need(observed["complete"] is True and observed["passed"] is True and observed["failed_count"] == 0 and observed["failures"] == [], "Candidate checks failed")
        guard.need(observed["check_count"] == len(observed["checks"]) > 0 and all(x["passed"] is True for x in observed["checks"]), "Candidate check inventory invalid")
        guard.need(observed["source_sha256"] == expected and files_snapshot(project) == expected, "Runtime source receipt mismatch")
        receipt.update(complete=True, check_count=observed["check_count"], source_manifest_sha256=guard.sha(manifest_path.read_bytes()),
                       report_sha256=guard.sha(report_path.read_bytes()), battle_resume_tested=False)
    except BaseException as exc:
        receipt["error"] = type(exc).__name__ + ": " + str(exc)
    finally:
        if active is not None:
            try: active.kill(); active.wait(timeout=30)
            except BaseException as exc: receipt["final_issues"].append("owned process cleanup: " + str(exc))
        for label, check in (
            ("source_unchanged", lambda: current_sources(rows) == source_before),
            ("player_unchanged", lambda: player_before is not None and guard.snapshot(player) == player_before),
            ("private_source_unchanged", lambda: expected is not None and files_snapshot(project) == expected),
            ("candidate_unchanged", lambda: guard.sha((candidate / "freeze.json").read_bytes()) == args.freeze_sha256
                and all(guard.sha((candidate / name).read_bytes()) == digest for name, digest in freeze["inputs"].items())
                and all(guard.sha((candidate / "candidate" / x["path"]).read_bytes()) == x["candidate_sha256"] for x in changes)),
        ):
            try: receipt[label] = check()
            except BaseException as exc: receipt[label] = False; receipt["final_issues"].append(label + ": " + str(exc))
        try:
            receipt["godot_pids_after"] = guard.godot_processes()
            guard.need(not receipt["godot_pids_after"], "Unconfirmed Godot exit")
            guard.need(lock.is_file() and lock.read_text(encoding="utf-8") == owner, "Shared lock ownership changed")
            lock.unlink(); receipt["lock_released"] = True
        except BaseException as exc:
            receipt["lock_released"] = False; receipt["final_issues"].append("lock/exit: " + str(exc))
        receipt["complete"] = receipt["complete"] and not receipt["final_issues"] and all(receipt.get(k) is True for k in
            ("source_unchanged", "player_unchanged", "private_source_unchanged", "candidate_unchanged", "lock_released"))
        guard.save(run / "receipt.json", receipt)
        print("RECEIPT " + str(run / "receipt.json"), flush=True)
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
