"""Isolated real CFG replacement/crash/CAS components; not campaign or player qualification."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid

from godot_debug_wire import DebugConnection, stack_frames
from run_workstation_baseline import engines
from run_steam_integration_qa import ROOT, LOCK, resolve_godot

ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")
PROPOSAL = ROOT / "qa/campaign_progress_recovery_20261008/proposed_v2/scripts"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def sources():
    paths = [Path(__file__), ROOT / "tools/campaign_cfg_transaction_probe.gd",
             ROOT / "scripts/run_snapshot_store.gd",
             PROPOSAL / "run_campaign_cfg_transaction.gd", PROPOSAL / "run_campaign_cfg_values.gd",
             ROOT / "tools/godot_debug_wire.py", ROOT / "tools/run_workstation_baseline.py",
             ROOT / "tools/run_steam_integration_qa.py"]
    return [{"path": str(p), "bytes": p.stat().st_size, "sha256": sha(p)} for p in paths]


def verified(rows):
    for row in rows:
        p = Path(row["path"])
        if p.stat().st_size != row["bytes"] or sha(p) != row["sha256"]:
            raise RuntimeError("Frozen source changed: " + str(p))


def write_new(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
        stream.flush()
        os.fsync(stream.fileno())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--source-preflight", type=Path)
    parser.add_argument("--seal-output", type=Path)
    parser.add_argument("--protocol-receipt", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/lsh-campaign-cfg-20261008"))
    args = parser.parse_args()
    pins = sources()
    proposal = PROPOSAL / "run_campaign_cfg_transaction.gd"
    text = proposal.read_text(encoding="utf-8").splitlines()
    breakpoint_lines = {}
    for name in ["cfg_before_backup", "cfg_after_backup", "cfg_after_install"]:
        found = [i + 1 for i, line in enumerate(text) if line.strip() == f'_checkpoint("{name}")']
        if len(found) != 1:
            raise RuntimeError("Exact file-operation breakpoint missing: " + name)
        breakpoint_lines[name] = found[0]
    manifest = {"schema": "campaign_cfg_transaction_component_source_preflight_v1", "files": pins,
                "breakpoint_lines": breakpoint_lines, "cases": ["normal", "window_after_backup", "window_after_install", "external_CAS"],
                "source_patches": 0, "native_return_values_simulated": False, "native_started": False,
                "full_campaign_qualified": False}
    if not args.run:
        if args.seal_output:
            write_new(args.seal_output, manifest)
        print(json.dumps({"preflight": True, "sources": len(pins), "cases": manifest["cases"],
                          "breakpoint_lines": breakpoint_lines, "native_started": False}))
        return
    if args.seal_output or not all([args.source_preflight, args.protocol_receipt, args.baseline]):
        raise RuntimeError("Fresh exact source seal, actual protocol proof and actual baseline required")
    sealed = json.loads(args.source_preflight.read_text(encoding="utf-8"))
    if sealed != manifest:
        raise RuntimeError("Source preflight mismatch")
    protocol = json.loads(args.protocol_receipt.read_text(encoding="utf-8"))
    baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    engine = resolve_godot(args.godot)
    digest = sha(engine)
    if (protocol.get("complete") is not True or protocol.get("actual_debugger_stack_verified") is not True
            or protocol.get("actual_cfg_read_observed") is not True or protocol.get("engine_sha256") != digest
            or baseline.get("complete") is not True or baseline.get("godot_sha256") != digest):
        raise RuntimeError("Actual protocol/baseline engine binding failed")
    run = args.work_root.absolute() / ("cfg_component_" + uuid.uuid4().hex[:8])
    for p in [run, *run.parents]:
        if p.exists() and (p.is_symlink() or getattr(p.lstat(), "st_file_attributes", 0) & 0x400):
            raise RuntimeError("Reparse work path refused")
    run.mkdir(parents=True, exist_ok=False)
    project = run / "project"
    (project / "scripts").mkdir(parents=True)
    (project / "tools").mkdir()
    for source, target in [(ROOT / "scripts/run_snapshot_store.gd", project / "scripts/run_snapshot_store.gd"),
                           (proposal, project / "scripts/run_campaign_cfg_transaction.gd"),
                           (PROPOSAL / "run_campaign_cfg_values.gd", project / "scripts/run_campaign_cfg_values.gd"),
                           (ROOT / "tools/campaign_cfg_transaction_probe.gd", project / "tools/campaign_cfg_transaction_probe.gd")]:
        target.write_bytes(source.read_bytes())
    (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="LSH CFG Transaction Probe"\n', encoding="utf-8")
    installed = {str(p.relative_to(project)): sha(p) for p in project.rglob("*") if p.is_file()}
    version = "cfg-component-fixture-v1:" + hashlib.sha256(json.dumps(installed, sort_keys=True).encode()).hexdigest()
    receipt = {"schema": "campaign_cfg_transaction_component_batch_v1", "complete": False, "run": str(run),
               "source_preflight_sha256": sha(args.source_preflight), "engine_sha256": digest,
               "protocol_receipt_sha256": sha(args.protocol_receipt), "baseline_sha256": sha(args.baseline),
               "source_files": pins, "installed_inputs": installed, "fixture_content_version": version,
               "steps": [], "natural_campaign_qualified": False, "gen2_cfg_ack_recovery_qualified": False,
               "player_ui_qualified": False, "Steam_reward_qualified": False, "power_loss_atomicity_qualified": False}
    child = None
    locked = False
    deadline = time.monotonic() + 3600

    def integrity():
        verified(pins)
        if sha(engine) != digest or sha(args.source_preflight) != receipt["source_preflight_sha256"]:
            raise RuntimeError("Engine or sealed inputs changed")
        for name, expected in installed.items():
            if sha(project / name) != expected:
                raise RuntimeError("Installed runtime bytes changed: " + name)

    def idle_and_lock():
        nonlocal locked
        while True:
            integrity()
            idle_since = None
            last_notice = 0.0
            while idle_since is None or time.monotonic() - idle_since < 60:
                if time.monotonic() > deadline:
                    raise RuntimeError("Bounded component batch deadline")
                if engines() or LOCK.exists():
                    idle_since = None
                elif idle_since is None:
                    idle_since = time.monotonic()
                if time.monotonic() - last_notice >= 30:
                    print("WAIT CFG component: continuous natural engine idle", flush=True)
                    last_notice = time.monotonic()
                time.sleep(2)
            try:
                with LOCK.open("x", encoding="utf-8") as stream:
                    stream.write(str(run))
            except FileExistsError:
                continue
            locked = True
            integrity()
            if not engines():
                return
            release_lock()

    def release_lock():
        nonlocal locked
        if locked:
            if LOCK.read_text(encoding="utf-8") != str(run):
                raise RuntimeError("Own shared lock changed")
            LOCK.unlink()
            locked = False

    def process(label, profile, mode=None, stop=None):
        nonlocal child
        idle_and_lock()
        env = os.environ.copy()
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            path = profile / key.lower()
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        for key in list(env):
            if key.endswith(("_QA", "_TEST", "_QA_MANIFEST", "_AUDIT")) or key in {"GODOT_USER_HOME", "LEVEL", "SMOKE_TEST", "SCENARIO", "SCREENSHOT_DIR"}:
                env.pop(key)
        nonce = uuid.uuid4().hex
        output = run / "output" / label
        output.mkdir(parents=True, exist_ok=False)
        env.update(CAMPAIGN_QA="0", STEAM_DISABLED="1", CFG_TRANSACTION_PROBE_PROFILE=str(profile).replace("\\", "/"),
                   CFG_TRANSACTION_PROBE_OUT=str(output), CFG_TRANSACTION_PROBE_MODE=mode or "",
                   CFG_TRANSACTION_PROBE_NONCE=nonce, CFG_TRANSACTION_PROBE_CONTENT=version)
        listener = connection = None
        command = [str(engine), "--path", str(project), "--headless"]
        if mode is None:
            command += ["--editor", "--quit"]
        else:
            if stop:
                listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
                command += ["--remote-debug", "tcp://127.0.0.1:" + str(listener.getsockname()[1]),
                            "--breakpoints", "res://scripts/run_campaign_cfg_transaction.gd:" + str(breakpoint_lines[stop])]
            command += ["--script", "res://tools/campaign_cfg_transaction_probe.gd"]
        row = {"label": label, "mode": mode, "nonce": nonce, "command": command, "complete": False, "mutations": []}
        receipt["steps"].append(row)
        log = run / (label + ".log")
        try:
            with log.open("wb") as stream:
                child = subprocess.Popen(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
                row["pid"] = child.pid
                print("RUN CFG component", label, child.pid, flush=True)
                if stop:
                    connection, address = listener.accept(); listener.close(); listener = None
                    if address[0] != "127.0.0.1": raise RuntimeError("Non-loopback debugger")
                    connection.settimeout(1)
                    peer = DebugConnection(connection)
                stopped = False
                phase_deadline = min(deadline, time.monotonic() + 150)
                while child.poll() is None:
                    if time.monotonic() > phase_deadline: raise RuntimeError("Owned component process timeout")
                    if engines() - {child.pid}: raise RuntimeError("Foreign shared Godot entered owned component")
                    if not stop or stopped:
                        time.sleep(0.2); continue
                    try:
                        message, packet = peer.receive()
                    except socket.timeout:
                        continue
                    except EOFError:
                        break
                    name, thread, data = message
                    if name == "debug_enter":
                        if len(data) != 4 or data[0] is not True or data[1] != "Breakpoint" or data[2] is not True or data[3] != thread:
                            raise RuntimeError("Unexpected native debugger stop")
                        peer.command("get_stack_dump", thread)
                    elif name == "stack_dump":
                        frames = stack_frames(data)
                        if not frames or frames[0] != {"source": "res://scripts/run_campaign_cfg_transaction.gd",
                                                       "line": breakpoint_lines[stop], "function": "_replace_and_verify"}:
                            raise RuntimeError("Actual source/line/function mismatch")
                        row.update(actual_breakpoint_frames=frames, stack_packet_sha256=hashlib.sha256(packet).hexdigest())
                        target = profile / "appdata/Godot/app_userdata/LSH CFG Transaction Probe/campaign.cfg"
                        if not target.parent.resolve().is_relative_to(profile.resolve()): raise RuntimeError("CFG escaped own profile")
                        if mode == "external_CAS":
                            before = target.read_bytes()
                            changed = before + b'\n[external]\nsentinel="controller_owned_change"\n'
                            target.write_bytes(changed)
                            row["mutations"].append({"kind":"real_external_CFG_write", "before_sha256":hashlib.sha256(before).hexdigest(),
                                                     "after_sha256":sha(target), "actual_bytes_written":len(changed)})
                            peer.command("breakpoint", thread, ["res://scripts/run_campaign_cfg_transaction.gd", breakpoint_lines[stop], False])
                            peer.command("continue", thread)
                        else:
                            candidates = target.parent / "campaign_cfg_candidates/v1"
                            stage_rows = [{"relative":str(p.relative_to(target.parent)), "bytes":p.stat().st_size, "sha256":sha(p)}
                                          for p in sorted(candidates.rglob("*.cfg"))]
                            if not stage_rows: raise RuntimeError("Actual owned stage files missing at interrupt")
                            if mode == "window_after_backup" and target.exists(): raise RuntimeError("Backup window target should be absent")
                            if mode == "window_after_install" and not target.is_file(): raise RuntimeError("Installed CFG window missing")
                            row.update(interrupted_at_exact_native_window=True, window_files=stage_rows,
                                       target_existed_at_interrupt=target.exists(), target_sha256=sha(target) if target.exists() else None)
                            child.kill()
                        stopped = True
                row.update(exit_code=child.wait(timeout=15), process_terminal=True, log_sha256=sha(log))
            if ERRORS.search(log.read_text(encoding="utf-8", errors="replace")):
                raise RuntimeError("Native component log error")
            if mode in ["window_after_backup", "window_after_install"]:
                if not stopped or row["exit_code"] == 0: raise RuntimeError("Actual abrupt owned process stop not proven")
            else:
                if row["exit_code"] != 0: raise RuntimeError("Actual component exit failed")
                if mode:
                    report = json.loads((output / "probe_report.json").read_text(encoding="utf-8"))
                    if report["pid"] != row["pid"] or report["nonce"] != nonce or report["mode"] != mode or report["failures"]:
                        raise RuntimeError("Native component checks/process binding incomplete")
                    if stop and not stopped: raise RuntimeError("Intended actual CAS fault not triggered")
                    row.update(report=report, report_sha256=sha(output / "probe_report.json"))
            integrity()
            row["complete"] = True
        finally:
            if child is not None and child.poll() is None: child.kill(); child.wait(timeout=15)
            if child is not None: row.setdefault("process_terminal", child.poll() is not None)
            child = None
            if connection is not None: connection.close()
            if listener is not None: listener.close()
            release_lock()

    try:
        process("00_import", run / "profiles/import")
        process("01_normal", run / "profiles/normal", "normal")
        for index, mode, stop in [(2, "window_after_backup", "cfg_after_backup"),
                                  (4, "window_after_install", "cfg_after_install"),
                                  (6, "external_CAS", "cfg_before_backup")]:
            profile = run / "profiles" / mode
            process(f"{index:02}_{mode}", profile, mode, stop)
            process(f"{index+1:02}_restart_{mode}", profile, "recover_CAS_refusal" if mode == "external_CAS" else "recover")
        receipt.update(complete=True, component_qualified=True, all_cases_completed=True)
    except BaseException as error:
        receipt["failure"] = repr(error)
        raise
    finally:
        if child is not None and child.poll() is None: child.kill(); child.wait(timeout=15)
        release_lock()
        receipt["lock_released"] = not locked
        write_new(run / "receipt.json", receipt)
        print(json.dumps({"complete":receipt["complete"], "run":str(run), "failure":receipt.get("failure")}))


if __name__ == "__main__":
    main()
