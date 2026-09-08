"""Frozen real-disk/externally killed process proof for the persistent queue.
Default is preflight. --run requires the shared Godot queue allocation.
"""
from pathlib import Path
import argparse
import copy
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
ROOT = HERE.parent
FILES = ["scripts/steam_persistent_outbox.gd", "scripts/steam_persistent_outbox_state.gd", "scripts/steam_persistent_outbox_store.gd",
         "scripts/run_snapshot_store.gd", "scripts/steam_receipt_store.gd", "scripts/steam_run_ledger.gd", "scripts/steam_run_receipt.gd",
         "scripts/steam_achievement_catalog.gd", "scripts/steam_achievement_state.gd", "tools/steam_persistent_outbox_qa.gd",
         "tools/run_steam_persistent_outbox_qa.py", "project.godot"]
CRASHES = [("stage", point) for point in ("prepared", "pending_half", "pending_verified", "record_renamed", "disk_before_memory", "memory_before_unlock", "before_sdk", "after_sdk")]
CRASHES += [(mode, point) for mode in ("confirm", "result8") for point in ("before_notification", "pending_half", "record_renamed", "disk_before_memory")]
CRASHES += [("enqueue", "pending_half"), ("enqueue", "pending_verified")]
ERROR = re.compile(r"SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error|Compile Error|leaked|RID allocations", re.M)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def no_links(path):
    for node in [path] + list(path.parents):
        if node.exists() or node.is_symlink():
            require(not node.is_symlink() and not getattr(node.lstat(), "st_file_attributes", 0) & 0x400, "Link refused " + str(node))


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


def pids():
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"], text=True).strip()
    data = json.loads(raw) if raw else []
    return data if isinstance(data, list) else [data]


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def latest_record(directory):
    names = sorted(directory.glob("record_*.json"))
    require(bool(names), "No complete record")
    path = names[-1]
    raw = path.read_text(encoding="utf-8")
    envelope = json.loads(raw)
    require(hashlib.sha256(envelope["payload"].encode()).hexdigest() == envelope["payload_sha256"], "Oracle payload hash")
    document = json.loads(envelope["payload"])
    require(canonical(document) == envelope["payload"], "Oracle canonical document")
    return document, sha(path)


def recovery_oracle(base, case_dir, plan, mode, stop, writer_pid):
    """Predict from seeded state, requested operation, and fixed checkpoint.

    The only unpredictable field accepted from the pre-write witness is the new
    enqueue nonce. Recovery output is never an input to this oracle.
    """
    require(plan["pid"] == writer_pid, "Oracle proposal PID")
    expected_old = copy.deepcopy(base)
    expected_new = copy.deepcopy(base)
    events = [json.loads(line) for line in (case_dir / "sdk.jsonl").read_text(encoding="utf-8").splitlines()] if (case_dir / "sdk.jsonl").exists() else []
    sdk_expected = mode in ("confirm", "result8") or stop == "after_sdk"
    require(len(events) == int(sdk_expected), "Exact SDK trace cardinality for checkpoint")
    require(all(row["pid"] == writer_pid for row in events), "Oracle SDK caller PID")
    if mode in ("confirm", "result8") and stop != "before_notification":
        expected_old["revision"] += 1
        expected_old["intents"][0]["state"] = "uncertain"
        expected_new = copy.deepcopy(expected_old)
    expected_new["revision"] += 1
    if mode == "enqueue":
        ledger, digest = latest_record(case_dir / "ledger/5088120/76561198000000001")
        require(ledger["generation"] == base["intents"][0]["generation"] + 1, "Oracle ledger exact next generation")
        require(ledger["stats"] == dict(base["intents"][0]["stats"], TOTAL_KILLS=21), "Oracle ledger exact targets")
        require(ledger["unlocked"] == base["intents"][0]["unlocked"], "Oracle ledger unchanged unlocks")
        nonce = plan["next"]["intents"][-1]["id"]
        require(re.fullmatch("[0-9a-f]{32}", nonce) and nonce != base["intents"][0]["id"], "Oracle fresh intent ID")
        targets = {"stats": ledger["stats"], "unlocked": ledger["unlocked"]}
        expected_new["intents"].append({"id": nonce, "generation": ledger["generation"],
            "receipt_sha256": hashlib.sha256(canonical(ledger).encode()).hexdigest(), "ledger_sha256": digest,
            "targets_sha256": hashlib.sha256(canonical(targets).encode()).hexdigest(), **targets,
            "state": "queued", "confirmation_sha256": ""})
    elif mode == "confirm" and stop != "before_notification":
        require(events[0]["confirmation_issued"] is True, "Oracle confirm authority issued")
        expected_new["intents"][0]["state"] = "confirmed"
        expected_new["intents"][0]["confirmation_sha256"] = hashlib.sha256(canonical(events[0]["proof"]).encode()).hexdigest()
    elif mode == "result8" and stop != "before_notification":
        require(events[0]["confirmation_issued"] is False, "Oracle rejected publication has no confirmation")
        expected_new["correction_required"] = True
    else:
        expected_new["intents"][0]["state"] = "uncertain"
    require(plan["previous"] == expected_old and plan["next"] == expected_new, "Independent expected transaction transition")
    # At prepared no pending exists; half a pending must refuse recovery and keep
    # the exact prior complete head. Every closed pending/renamed/later point must
    # recover the complete new document, including already confirmed/corrected.
    document = expected_old if stop in ("prepared", "pending_half") else expected_new
    return {"document": document, "blocked": stop == "pending_half", "mode": mode, "checkpoint": stop,
            "writer_pid": writer_pid, "sdk_events": len(events), "source": "seed_plus_fixed_checkpoint_plus_prewrite_nonce"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/steam_persistent_outbox"))
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    exe = Path(args.godot or os.environ.get("GODOT_PATH") or (ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip()).absolute()
    no_links(exe)
    freeze = {"inputs": {name: sha(ROOT / name) for name in FILES}, "runner_sha256": sha(Path(__file__)), "godot_sha256": sha(exe)}
    work_root = args.work_root.absolute()
    no_links(work_root)
    require(str(work_root).isascii() and ROOT not in work_root.parents and work_root != ROOT, "Private ASCII work root outside checkout required")
    lock = ROOT / ".godot/redraw_rejection_source.lock"
    no_links(lock)
    print(json.dumps({"preflight": True, "source_head": head, "lock_busy": lock.exists(), "godot_pids": pids(), "crash_cases": len(CRASHES)}), flush=True)
    if not args.run:
        return 0
    require(not lock.exists() and not pids(), "Godot slot occupied")
    token = uuid.uuid4().hex
    run_id = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + token[:8]
    run = work_root / run_id
    no_links(run)
    run.mkdir(parents=True, exist_ok=False)
    project = run / "project"
    project.mkdir()
    profile = run / "profile"
    profile.mkdir()
    expected = profile / "appdata/LHPersistentOutboxQA"
    evidence_root = run / "evidence"
    evidence_root.mkdir()
    write(run / "freeze.json", freeze)
    report = {"suite": "steam-persistent-outbox", "passed": False, "source_head": head, "freeze_sha256": sha(run / "freeze.json"),
              "runner_sha256": freeze["runner_sha256"], "godot_sha256": freeze["godot_sha256"], "run": str(run),
              "production_confirmation_blocked": True, "real_sdk": False, "processes": [], "crashes": [], "inputs": freeze["inputs"]}
    copied, protected = {}, {}
    active = None
    owned = False
    complete = False
    env = os.environ.copy()

    def phase(name, mode=None, case="", stop="", oracle=None, mismatch=False):
        nonlocal active
        require(not pids(), "Godot queue occupied")
        require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == head, "HEAD changed")
        require(all(sha(project / key) == val for key, val in copied.items()), "Copied source changed")
        require(all(sha(ROOT / key) == val for key, val in freeze["inputs"].items()), "Live source changed")
        require(sha(exe) == freeze["godot_sha256"], "Engine changed")
        require(lock.is_file() and lock.read_text(encoding="utf-8") == token, "Shared source lock changed")
        checkpoint = project / "checkpoint.json"
        if checkpoint.exists():
            checkpoint.unlink()  # Raw prior phase checkpoint retained before this.
        result = run / (name + ".json")
        local_env = env.copy()
        local_env.update(OUTBOX_MODE=mode or "", OUTBOX_CASE=case, OUTBOX_STOP=stop, OUTBOX_REPORT=str(result),
                         OUTBOX_EXPECTED_PROFILE=(expected / "mismatch" if mismatch else expected).as_posix(), OUTBOX_EXPECT_BLOCKED="1" if oracle and oracle["blocked"] else "0",
                         OUTBOX_RECOVERY_EXPECTATION=str(run / (case + "_expectation.json")) if oracle else "")
        command = [str(exe), "--headless", "--path", str(project)] + (["--editor", "--import"] if mode is None else ["--script", "res://tools/steam_persistent_outbox_qa.gd"])
        row = {"name": name, "mode": mode, "case": case, "stop": stop, "child_exit_confirmed": False}
        report["processes"].append(row)
        started = time.monotonic()
        with (run / (name + ".log")).open("wb") as log:
            active = subprocess.Popen(command, cwd=project, env=local_env, stdout=log, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            row["pid"] = active.pid
            if stop:
                while time.monotonic() - started < 60:
                    if checkpoint.exists():
                        try:
                            item = json.loads(checkpoint.read_text(encoding="utf-8"))
                        except (json.JSONDecodeError, OSError):
                            time.sleep(0.02)
                            continue
                        require(item == {"name": stop, "pid": active.pid} and active.poll() is None, "Checkpoint identity")
                        shutil.copy2(checkpoint, run / (name + "_checkpoint.json"))
                        row["checkpoint_verified"] = True
                        active.kill()
                        break
                    require(active.poll() is None, "Writer exited before checkpoint")
                    time.sleep(0.02)
                require(row.get("checkpoint_verified") is True, "Checkpoint timeout")
            code = active.wait(timeout=60)
            row.update(exit_code=code, child_exit_confirmed=active.poll() is not None, seconds=time.monotonic()-started)
            active = None
        log_text = (run / (name + ".log")).read_text(encoding="utf-8")
        row["errors"] = [line for line in log_text.splitlines() if ERROR.search(line)]
        require(not row["errors"], "Godot errors " + name)
        require(code != 0 if stop else code == (2 if mismatch else 0), "Unexpected exit " + name)
        if mismatch:
            require("PRIVATE_PROFILE_REQUIRED" in log_text and not result.exists(), "Profile guard report/write ordering")
            require(not (expected / "outbox_qa").exists() and not (project / "transaction_plan.json").exists(), "Profile mismatch wrote fixtures")
            row["fixture_writes"] = 0
        if mode and not stop and not mismatch:
            data = json.loads(result.read_text(encoding="utf-8"))
            require(data["suite"] == report["suite"] and data["mode"] == mode and data["pid"] == row["pid"], "Report identity")
            require(data["passed"] and data["failed"] == 0 and data["checks"] and all(x["passed"] is True for x in data["checks"]), "Native assertions " + name)
            require(Path(data["profile"]).resolve() == expected.resolve(), "Private profile identity")
            if oracle:
                require(data["details"]["before"] == oracle["document"], "Independent exact recovered document before proof")
            row["checks"] = len(data["checks"])
        require(not pids(), "Child still running")
        require(all(snapshot(Path(key)) == val for key, val in protected.items()), "Player profile changed")
        write(run / "receipt.json", report)
        return row

    try:
        with lock.open("x", encoding="utf-8") as handle:
            owned = True
            handle.write(token)
        config = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
        require("config/use_custom_user_dir" not in config, "Production profile mapping changed")
        names = re.findall(r'^config/name=("[^\n]+")\s*$', config, re.M)
        require(len(names) == 1, "Project name")
        production_profile = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / json.loads(names[0])
        for path in (production_profile, Path(os.environ["APPDATA"]) / "LHPersistentOutboxQA"):
            protected[str(path)] = snapshot(path)
        for name in FILES:
            if name == "project.godot": continue
            dest = project / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)
            require(sha(dest) == freeze["inputs"][name], "Freeze copy changed")
            copied[name] = sha(dest)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="LHPersistentOutboxQA"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="LHPersistentOutboxQA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        copied["project.godot"] = sha(project / "project.godot")
        for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
            directory = profile / key.lower()
            directory.mkdir()
            env[key] = str(directory)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1")
        phase("import")
        phase("profile_guard", "seed", "profile_guard", mismatch=True)
        phase("seed", "seed", "base")
        contract_row = phase("contract", "contract", "contract")
        base, _ = latest_record(expected / "outbox_qa/base/queue/5088120/76561198000000001")
        require(base["revision"] == 2 and len(base["intents"]) == 1 and base["intents"][0]["state"] == "queued" and base["intents"][0]["stats"]["TOTAL_KILLS"] == 20, "Fixed seed oracle")
        for index, (mode, stop) in enumerate(CRASHES):
            name = "case_%02d%s" % (index, "_half" if stop == "pending_half" else "")
            source = expected / "outbox_qa/base"
            case_dir = expected / "outbox_qa" / name
            shutil.copytree(source, case_dir)
            killed = phase(name, mode, name, stop)
            before = snapshot(case_dir)
            shutil.copytree(case_dir, evidence_root / (name + "_before"))
            trace = case_dir / "sdk.jsonl"
            trace_bytes = trace.read_bytes() if trace.exists() else b""
            if mode in ("stage", "enqueue") and stop != "after_sdk":
                require(not trace_bytes, "SDK called before durable barrier")
            plan = json.loads((project / "transaction_plan.json").read_text(encoding="utf-8"))
            oracle = recovery_oracle(base, case_dir, plan, mode, stop, killed["pid"])
            write(run / (name + "_transaction_plan.json"), plan)
            write(run / (name + "_expectation.json"), oracle)
            phase(name + "_recover", "recover", name, oracle=oracle)
            require((trace.read_bytes() if trace.exists() else b"") == trace_bytes, "Recovery replayed SDK intent")
            if oracle["blocked"]: require(snapshot(case_dir) == before, "Blocked recovery altered original files")
            require(snapshot(evidence_root / (name + "_before")) == before, "Crash evidence changed")
            shutil.copytree(case_dir, evidence_root / (name + "_after"))
            report["crashes"].append({"name": name, "mode": mode, "point": stop, "writer_pid": killed["pid"], "before": before, "no_sdk_replay": True,
                "exact_oracle_verified_before_reconfirmation": True, "expected_revision": oracle["document"]["revision"], "expected_states": [row["state"] for row in oracle["document"]["intents"]],
                "expected_correction_required": oracle["document"]["correction_required"], "sdk_events": oracle["sdk_events"]})
            print(json.dumps({"completed": name, "mode": mode, "point": stop}), flush=True)
        # Independent proof/marker audit after all mutations and snapshot pruning.
        trace_checks = 0
        for case_dir in sorted((expected / "outbox_qa").iterdir()):
            trace = case_dir / "sdk.jsonl"
            if not trace.exists():
                continue
            for line in trace.read_text(encoding="utf-8").splitlines():
                event = json.loads(line)
                targets = event["targets"]
                raw = event["marker_raw"]
                require(hashlib.sha256(raw.encode()).hexdigest() == targets["marker_sha256"], "Independent marker SHA")
                envelope = json.loads(raw)
                payload = envelope["payload"]
                require(hashlib.sha256(payload.encode()).hexdigest() == envelope["payload_sha256"], "Independent payload SHA")
                document = json.loads(payload)
                intents = [x for x in document["intents"] if x["id"] == targets["intent"]]
                require(len(intents) == 1 and intents[0]["state"] == "uncertain", "Actual SDK marker not uncertain")
                intent = intents[0]
                require(intent["generation"] == targets["generation"] and intent["targets_sha256"] == targets["targets_sha256"] and intent["stats"] == targets["stats"] and intent["unlocked"] == targets["unlocked"], "Marker exact batch binding")
                require(targets["owner"] == document["owner"] == "76561198000000001" and targets["app"] == 5088120, "Marker account")
                require(event["pid"] in [row["pid"] for row in report["processes"]], "Owned SDK caller PID")
                trace_checks += 1
        report["trace_events_independently_checked"] = trace_checks
        require(trace_checks == 13, "Expected all 13 SDK events; zero trace cannot pass")
        shutil.copytree(expected / "outbox_qa/contract", evidence_root / "contract_final")
        complete = True
    except BaseException as exc:
        report["error"] = type(exc).__name__ + ": " + str(exc)
    finally:
        if active is not None:
            if active.poll() is None: active.kill()
            active.wait(timeout=15)
            report["processes"][-1].update(exit_code=active.returncode, child_exit_confirmed=active.poll() is not None)
        report["source_unchanged"] = all(sha(ROOT / name) == digest for name, digest in freeze["inputs"].items())
        report["frozen_inputs_unchanged"] = bool(copied) and all(sha(project / name) == digest for name, digest in copied.items())
        report["engine_unchanged"] = sha(exe) == freeze["godot_sha256"]
        report["head_unchanged"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == head
        report["player_profiles_unchanged"] = len(protected) == 2 and all(snapshot(Path(key)) == val for key, val in protected.items())
        report["child_exits_confirmed"] = all(row["child_exit_confirmed"] for row in report["processes"])
        report["godot_pids_after"] = pids()
        report["lock_released"] = False
        if owned and lock.is_file() and lock.read_text(encoding="utf-8") == token and not report["godot_pids_after"] and report["child_exits_confirmed"]:
            lock.unlink(); report["lock_released"] = True
        report["passed"] = complete and all(report[key] for key in ("source_unchanged", "frozen_inputs_unchanged", "engine_unchanged", "head_unchanged", "player_profiles_unchanged", "child_exits_confirmed", "lock_released")) and report["godot_pids_after"] == []
        report["native_checks"] = sum(row.get("checks", 0) for row in report["processes"])
        write(run / "receipt.json", report)
        public = ROOT / "qa/steam_persistent_outbox_20260908" / run_id
        no_links(public)
        public.mkdir(parents=True, exist_ok=False)
        for path in run.iterdir():
            if path.is_file() and path.suffix in (".json", ".log"): shutil.copyfile(path, public / path.name)
        shutil.copytree(evidence_root, public / "evidence")
        for name in FILES:
            if name == "project.godot": continue
            dest = public / "source_snapshot" / name; dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / name, dest)
        shutil.copyfile(project / "project.godot", public / "source_snapshot/project.godot")
        write(public / "evidence_sha256.json", {path.relative_to(public).as_posix(): sha(path) for path in sorted(public.rglob("*")) if path.is_file()})
        print(str(run / "receipt.json"), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
