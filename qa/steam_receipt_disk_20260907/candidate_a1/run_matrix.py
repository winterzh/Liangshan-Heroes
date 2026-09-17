"""Fixture-only real Godot file journal and externally terminated PID matrix.

Preflight is default. --run requires ROOT's exclusive Godot queue allocation.
Original inputs and every killed writer's entire account directory are retained.
No production SteamService, Steam SDK, account profile or gameplay scene is loaded.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OWNER = "76561198000000001"
APP = "5088120"
ERROR = re.compile(r"SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error|Compile Error|leaked|RID allocations", re.M)
CANDIDATES = ["checkpoint.gd", "receipt_disk.gd", "fake_sdk.gd", "receipt_host.gd", "worker.gd"]
DEPENDENCIES = {
    "steam_run_receipt.gd": "tools/contracts/steam_receipt_outbox_draft_20260907/steam_run_receipt.gd.txt",
    "steam_receipt_outbox.gd": "tools/contracts/steam_receipt_outbox_draft_20260907/steam_receipt_outbox.gd.txt",
    "scripts/steam_achievement_catalog.gd": "scripts/steam_achievement_catalog.gd",
    "scripts/steam_achievement_state.gd": "scripts/steam_achievement_state.gd",
}
CRASHES = [("dispatch", point) for point in (
    "lock_acquired", "prepared_dispatch", "pending_half", "pending_verified",
    "record_renamed", "record_verified", "disk_before_model_dispatch",
    "model_before_unlock_dispatch", "before_sdk", "after_first_stat",
    "after_achievement", "after_store")]
CRASHES += [(mode, point) for mode in ("callback1", "callback8") for point in (
    "callback_1" if mode == "callback1" else "callback_8", "prepared_stored",
    "pending_half", "pending_verified", "record_renamed",
    "disk_before_model_stored", "model_before_unlock_stored")]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def no_links(path):
    for node in [path] + list(path.parents):
        if node.exists() or node.is_symlink():
            require(not node.is_symlink() and not getattr(node.lstat(), "st_file_attributes", 0) & 0x400,
                    "Link refused: " + str(node))


def snapshot(path):
    no_links(path)
    if not path.exists():
        return {"exists": False, "files": {}, "directories": []}
    files, directories = {}, []
    for base, dirs, names in os.walk(path, followlinks=False):
        for name in dirs + names:
            no_links(Path(base) / name)
        directories.append(Path(base).relative_to(path).as_posix())
        for name in names:
            node = Path(base) / name
            files[node.relative_to(path).as_posix()] = sha(node)
    return {"exists": True, "files": files, "directories": sorted(directories)}


def godot_pids():
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command",
        "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"], text=True).strip()
    value = json.loads(raw) if raw else []
    return value if isinstance(value, list) else [value]


def player_directory():
    text = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    require("config/use_custom_user_dir" not in text and "config/custom_user_dir_name" not in text,
            "Production user directory mapping changed")
    names = re.findall(r'^config/name=("[^\n]+")\s*$', text, re.M)
    require(len(names) == 1, "Production project name")
    name = json.loads(names[0])
    require(name not in ("", ".", "..") and not any(c in name for c in '<>:"/\\|?*'), "Project name")
    return Path(os.environ["APPDATA"]) / "Godot/app_userdata" / name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--freeze-sha256", required=True)
    parser.add_argument("--source-head", help="Optional explicit current HEAD; all runs pin and recheck the actual starting HEAD")
    args = parser.parse_args()
    freeze_path = HERE / "freeze.json"
    require(sha(freeze_path) == args.freeze_sha256, "Freeze differs")
    freeze = json.loads(freeze_path.read_text(encoding="utf-8"))
    current_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if args.source_head:
        require(current_head == args.source_head, "Requested source HEAD differs")
    originals = {}
    for name, digest in freeze["inputs"].items():
        path = HERE / name
        no_links(path)
        require(sha(path) == digest, "Candidate changed: " + name)
        originals[str(path)] = digest
    for name, digest in freeze["dependencies"].items():
        path = ROOT / name
        no_links(path)
        require(sha(path) == digest, "Dependency changed: " + name)
        originals[str(path)] = digest
    exe = Path((ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip())
    no_links(exe)
    require(sha(exe) == freeze["godot_sha256"], "Engine changed")
    lock = ROOT / ".godot/redraw_rejection_source.lock"
    no_links(lock)
    pids = godot_pids()
    print(json.dumps({"phase": "preflight", "freeze_sha256": args.freeze_sha256, "source_head": current_head,
                      "godot_pids": pids, "lock_busy": lock.exists(), "crash_cases": len(CRASHES)}, ensure_ascii=False), flush=True)
    if not args.run:
        return 0
    require(not pids and not lock.exists(), "Godot queue occupied")
    token = uuid.uuid4().hex
    run = HERE / "runs" / (datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + token[:8])
    no_links(run)
    run.mkdir(parents=True, exist_ok=False)
    project = run / "project"
    project.mkdir()
    profile = run / "private_profile"
    profile.mkdir()
    report = {"suite": "steam-receipt-disk-fake-sdk", "passed": False, "source_head": current_head,
              "freeze_sha256": args.freeze_sha256, "godot_sha256": sha(exe), "processes": [], "crash_cases": [],
              "negative_cases": [], "real_sdk": False, "production_integration": False, "power_loss_tested": False,
              "boundaries": ["append-only fixture journal capped at 2048 records", "torn pending remains blocked",
                             "crashed recovery lock remains blocked", "no multi-device merge or rollback resistance",
                             "callback session and authoritative reads are synthetic", "no automatic retry of uncertain batches"]}
    protected, copied = {}, {}
    active = None
    owned = False
    complete = False
    env = os.environ.copy()

    def run_phase(name, mode=None, case=None, checkpoint=None, blocked=False):
        nonlocal active
        require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == current_head,
                "Production HEAD changed during native queue slot")
        require(not godot_pids(), "Godot queue occupied before " + name)
        require(all(sha(project / p) == digest for p, digest in copied.items()), "Frozen project changed")
        expected_checkpoint = project / "checkpoint.json"
        if expected_checkpoint.exists():
            require(expected_checkpoint.is_file(), "Checkpoint shape")
            expected_checkpoint.unlink()  # Previous raw checkpoint is preserved under its phase name.
        result = run / (name + ".json")
        phase_env = env.copy()
        phase_env.update(DISK_MODE=mode or "", DISK_CASE=case or "", DISK_STOP_AT=checkpoint or "",
                         DISK_REPORT=str(result), DISK_EXPECT_BLOCKED="1" if blocked else "0")
        command = [str(exe), "--headless", "--path", str(project)]
        command += ["--editor", "--import"] if mode is None else ["--script", "res://worker.gd"]
        row = {"name": name, "mode": mode, "case": case, "checkpoint": checkpoint,
               "child_exit_confirmed": False, "expected_external_termination": bool(checkpoint)}
        report["processes"].append(row)
        started = time.monotonic()
        with (run / (name + ".log")).open("wb") as log:
            active = subprocess.Popen(command, cwd=project, env=phase_env, stdout=log, stderr=subprocess.STDOUT,
                                      creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            row["pid"] = active.pid
            if checkpoint:
                while time.monotonic() - started < 60:
                    if expected_checkpoint.exists():
                        try:
                            observed = json.loads(expected_checkpoint.read_text(encoding="utf-8"))
                        except (json.JSONDecodeError, OSError):
                            time.sleep(0.02)
                            continue
                        require(observed == {"name": checkpoint, "pid": active.pid}, "Checkpoint identity")
                        require(active.poll() is None, "Checkpoint writer already exited")
                        shutil.copy2(expected_checkpoint, run / (name + "_checkpoint.json"))
                        row["checkpoint_verified"] = True
                        active.kill()  # Deliberate actual process termination by the external parent.
                        break
                    require(active.poll() is None, "Writer exited before checkpoint: " + name)
                    time.sleep(0.02)
                require(row.get("checkpoint_verified") is True, "Checkpoint timeout")
            code = active.wait(timeout=60)
            row.update(exit_code=code, child_exit_confirmed=active.poll() is not None, seconds=time.monotonic()-started)
            active = None
        logs = (run / (name + ".log")).read_text(encoding="utf-8", errors="strict")
        row["errors"] = [line for line in logs.splitlines() if ERROR.search(line)]
        require(not row["errors"], "Godot errors: " + name)
        require(code != 0 if checkpoint else code == 0, "Unexpected exit: " + name)
        if mode and not checkpoint:
            data = json.loads(result.read_text(encoding="utf-8"))
            require(data["suite"] == report["suite"] and data["phase"] == mode and data["pid"] == row["pid"], "Report identity")
            require(data["passed"] is True and data["failed"] == 0 and data["checks"] and all(x["passed"] is True for x in data["checks"]), "Fixture checks: " + name)
            require(Path(data["profile"]).resolve() == (profile / "appdata/LHReceiptDiskContract").resolve(), "Profile identity")
            row["checks"] = len(data["checks"])
        require(not godot_pids(), "Child did not exit")
        require(all(snapshot(Path(p)) == before for p, before in protected.items()), "Player profile changed")
        write(run / "receipt.json", report)
        return row

    try:
        with lock.open("x", encoding="utf-8") as handle:
            owned = True
            handle.write(token)
        for player in (player_directory(), Path(os.environ["APPDATA"]) / "LHReceiptDiskContract"):
            protected[str(player)] = snapshot(player)
        for name in CANDIDATES:
            shutil.copyfile(HERE / name, project / name)
            copied[name] = sha(project / name)
        for destination, origin in DEPENDENCIES.items():
            dest = project / destination
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / origin, dest)
            copied[destination] = sha(dest)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="LHReceiptDiskContract"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="LHReceiptDiskContract"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        copied["project.godot"] = sha(project / "project.godot")
        report["copied_inputs"] = copied
        for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
            directory = profile / key.lower()
            directory.mkdir()
            env[key] = str(directory)
        env.update(DISK_EXPECTED_PROFILE=(profile / "appdata/LHReceiptDiskContract").as_posix(), STEAM_DISABLED="1", CAMPAIGN_QA="1")
        run_phase("import")
        base = project / "fixtures/base" / APP / OWNER
        base.mkdir(parents=True)
        run_phase("seed", "seed", "base")
        base_snapshot = snapshot(base)
        contract = project / "fixtures/contract" / APP / OWNER
        contract.mkdir(parents=True)
        run_phase("contract", "contract", "contract")
        for index, (mode, point) in enumerate(CRASHES):
            name = "crash_%02d" % index
            account = project / "fixtures" / name / APP / OWNER
            account.parent.mkdir(parents=True)
            shutil.copytree(base, account)
            require(snapshot(account) == base_snapshot, "Fixture seed differs")
            run_phase(name, mode, name, point)
            evidence = run / "crash_evidence" / name
            evidence.parent.mkdir(exist_ok=True)
            shutil.copytree(account, evidence)
            before = snapshot(account)
            trace = account.parent.parent / "sdk.jsonl"
            trace_before = trace.read_bytes() if trace.exists() else b""
            run_phase(name + "_recover", "recover", name, blocked=point == "pending_half")
            require((trace.read_bytes() if trace.exists() else b"") == trace_before, "Recovery replayed an SDK call")
            require(snapshot(evidence) == before, "Crash evidence changed")
            report["crash_cases"].append({"name": name, "mode": mode, "point": point, "recovery_blocked_expected": point == "pending_half",
                                          "pre_recovery": before, "evidence": evidence.relative_to(run).as_posix(), "no_sdk_replay": True})
            print(json.dumps({"completed_crash": name, "point": point, "mode": mode}), flush=True)
        for mode in ("stat_failure", "store_false"):
            account = project / "fixtures" / mode / APP / OWNER
            account.parent.mkdir(parents=True)
            shutil.copytree(base, account)
            run_phase(mode, mode, mode)
            trace = account.parent.parent / "sdk.jsonl"
            before = trace.read_bytes()
            run_phase(mode + "_recover", "recover", mode)
            require(trace.read_bytes() == before, "Failure recovery replayed SDK")
        # Corrupt only isolated copies. Re-sign selected outer envelopes so the
        # complete model validator, not merely a checksum mismatch, must reject.
        for kind in ("utf8", "truncated", "hash", "owner", "extra", "negative", "bool", "fraction", "chain", "unknown"):
            name = "bad_" + kind
            account = project / "fixtures" / name / APP / OWNER
            account.parent.mkdir(parents=True)
            shutil.copytree(base, account)
            target = account / "record_0000000003.json"
            envelope = json.loads(target.read_text(encoding="utf-8"))
            if kind == "utf8": target.write_bytes(b"\xff\xfe\x80")
            elif kind == "truncated": target.write_bytes(target.read_bytes()[:50])
            elif kind == "unknown": (account / "foreign.txt").write_text("preserve", encoding="utf-8")
            else:
                if kind == "hash": envelope["payload_sha256"] = "0" * 64
                elif kind == "owner": envelope["owner"] = "76561198000000002"
                elif kind == "extra": envelope["extra"] = "unexpected"
                elif kind == "chain": envelope["previous_sha256"] = "0" * 64
                else:
                    doc = json.loads(envelope["payload"])
                    doc["receipt"]["stats"]["TOTAL_KILLS"] = {"negative": -1, "bool": True, "fraction": 20.5}[kind]
                    payload = json.dumps(doc, separators=(",", ":"))
                    envelope.update(payload=payload, payload_bytes=str(len(payload.encode("utf-8"))),
                                    payload_sha256=hashlib.sha256(payload.encode("utf-8")).hexdigest())
                write(target, envelope)
            before = snapshot(account)
            run_phase(name, "inspect_bad", name)
            require(snapshot(account) == before, "Bad evidence was altered")
            report["negative_cases"].append({"name": name, "rejected_unchanged": True})
        complete = True
    except BaseException as exc:
        report["error"] = type(exc).__name__ + ": " + str(exc)
    finally:
        if active is not None:
            if active.poll() is None:
                active.kill()
            active.wait(timeout=15)
            report["processes"][-1].update(exit_code=active.returncode, child_exit_confirmed=active.poll() is not None)
        report["source_unchanged"] = all(sha(Path(p)) == digest for p, digest in originals.items())
        report["head_unchanged"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == current_head
        report["frozen_inputs_unchanged"] = bool(copied) and all(sha(project / p) == digest for p, digest in copied.items())
        report["player_profiles_unchanged"] = len(protected) == 2 and all(snapshot(Path(p)) == before for p, before in protected.items())
        report["godot_pids_after"] = godot_pids()
        report["child_exits_confirmed"] = all(row.get("child_exit_confirmed") is True for row in report["processes"])
        report["lock_released"] = False
        if owned and lock.is_file() and lock.read_text(encoding="utf-8") == token and not report["godot_pids_after"] and report["child_exits_confirmed"]:
            lock.unlink()
            report["lock_released"] = True
        report["passed"] = complete and all(report.get(key) is True for key in (
            "source_unchanged", "head_unchanged", "frozen_inputs_unchanged", "player_profiles_unchanged", "child_exits_confirmed", "lock_released")) and report["godot_pids_after"] == []
        write(run / "receipt.json", report)
        print(str(run / "receipt.json"), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
