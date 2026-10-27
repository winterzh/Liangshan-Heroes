"""Qualify owned Godot debugger pauses plus real private ConfigFile mutation; no production patch."""
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

from godot_debug_wire import DebugConnection, WireError, stack_frames
from run_workstation_baseline import engines
from run_steam_integration_qa import ROOT, LOCK, resolve_godot


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/lsh-campaign-faults-20261008"))
    args = parser.parse_args()
    script = ROOT / "tools/campaign_fault_debug_probe.gd"
    lines = script.read_text(encoding="utf-8").splitlines()
    targets = [index + 1 for index, line in enumerate(lines) if line.strip() == "var loaded := independent.load(path)"]
    if len(targets) != 1:
        raise RuntimeError("Exact native read breakpoint source missing")
    breakpoint_line = targets[0]
    engine = resolve_godot(args.godot)
    if not args.run:
        print(json.dumps({"source_preflight": True, "probe_script_sha256": sha(script), "breakpoint_line": breakpoint_line,
                          "private_real_file_mutation": True, "source_patches": 0, "native_started": False}))
        return
    run = args.work_root.absolute() / ("debug_probe_" + uuid.uuid4().hex[:8])
    for path in [run, *run.parents]:
        if path.exists() and (path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400):
            raise RuntimeError("Reparse work path refused")
    run.mkdir(parents=True, exist_ok=False)
    project, profile, output = run / "project", run / "profile", run / "output"
    project.mkdir(); profile.mkdir(); output.mkdir()
    (project / "tools").mkdir()
    (project / "tools/campaign_fault_debug_probe.gd").write_bytes(script.read_bytes())
    (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="LSH FaultDebugProbe"\n', encoding="utf-8")
    env = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
        private = profile / key.lower(); private.mkdir(); env[key] = str(private)
    for key in list(env):
        if key.endswith(("_QA", "_TEST", "_QA_MANIFEST", "_AUDIT")) or key in {"GODOT_USER_HOME", "SCREENSHOT_DIR", "LEVEL"}:
            env.pop(key)
    nonce = uuid.uuid4().hex
    env.update(CAMPAIGN_FAULT_PROBE_OUT=str(output), CAMPAIGN_FAULT_PROBE_PROFILE=str(profile).replace("\\", "/"),
               CAMPAIGN_FAULT_PROBE_NONCE=nonce)
    receipt = {"schema": "campaign_owned_debugger_fault_probe_v1", "complete": False, "run": str(run), "nonce": nonce,
               "engine_sha256": sha(engine), "script_sha256": sha(script), "breakpoint_line": breakpoint_line,
               "production_code_patches": 0, "cfg_return_values_simulated": False,
               "fault_matrix_qualified": False, "messages": [], "mutations": []}
    child, listener, connection = None, None, None
    locked = False
    try:
        idle_since = None
        wait_deadline = time.monotonic() + 1800
        while idle_since is None or time.monotonic() - idle_since < 60:
            if time.monotonic() > wait_deadline:
                raise RuntimeError("Natural engine idle observation deadline")
            if engines() or LOCK.exists():
                idle_since = None
            elif idle_since is None:
                idle_since = time.monotonic()
            time.sleep(2)
        with LOCK.open("x", encoding="utf-8") as stream:
            stream.write(str(run))
        locked = True
        if engines():
            raise RuntimeError("Shared engine entered before launch")
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
        port = listener.getsockname()[1]
        command = [str(engine), "--path", str(project), "--headless", "--remote-debug", "tcp://127.0.0.1:" + str(port),
                   # 4.6.3 EngineDebugger::initialize splits at the last colon;
                   # a double separator pins a nonexistent source ending ':'.
                   "--breakpoints", "res://tools/campaign_fault_debug_probe.gd:" + str(breakpoint_line),
                   "--script", "res://tools/campaign_fault_debug_probe.gd"]
        receipt["command"] = command
        log = run / "native.log"
        with log.open("wb") as stream:
            child = subprocess.Popen(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            receipt["pid"] = child.pid
            connection, address = listener.accept(); listener.close(); listener = None
            connection.settimeout(1)
            peer = DebugConnection(connection)
            end = time.monotonic() + 90
            paused_thread = None
            while child.poll() is None:
                if time.monotonic() > end:
                    raise RuntimeError("Owned debugger probe timeout")
                foreign = engines() - {child.pid}
                if foreign:
                    raise RuntimeError("Shared engine resumed: " + repr(sorted(foreign)))
                try:
                    message, raw = peer.receive()
                except socket.timeout:
                    continue
                except EOFError:
                    break
                name, thread, data = message
                receipt["messages"].append({"name": name, "thread": thread, "data": data,
                                            "packet_sha256": hashlib.sha256(raw).hexdigest()})
                if name == "debug_enter":
                    if (paused_thread is not None or len(data) != 4 or data[0] is not True
                            or data[1] != "Breakpoint" or data[2] is not True or data[3] != thread):
                        raise RuntimeError("Unexpected/error debugger stop")
                    paused_thread = thread
                    peer.command("get_stack_dump", thread)
                elif name == "stack_dump":
                    frames = stack_frames(data)
                    if thread != paused_thread or frames[0] != {"source": "res://tools/campaign_fault_debug_probe.gd",
                                                               "line": breakpoint_line, "function": "_run"}:
                        raise RuntimeError("Unexpected source/line/function at real native read")
                    receipt["actual_breakpoint_frames"] = frames
                    path = profile / "appdata/Godot/app_userdata/LSH FaultDebugProbe/debug_probe.cfg"
                    if not path.is_file() or not path.resolve().is_relative_to(profile.resolve()):
                        raise RuntimeError("Owned private CFG unavailable")
                    before = path.read_bytes()
                    changed = re.sub(rb"(?m)^value=11\s*$", b"value=29", before)
                    if changed == before or b"value=29" not in changed:
                        raise RuntimeError("Actual seeded CFG content differs")
                    path.write_bytes(changed)
                    receipt["mutations"].append({"path": str(path), "before_sha256": hashlib.sha256(before).hexdigest(),
                                                 "after_sha256": sha(path), "actual_filesystem_write": True})
                    peer.command("breakpoint", thread, ["res://tools/campaign_fault_debug_probe.gd", breakpoint_line, False])
                    peer.command("continue", thread)
                elif name == "debug_exit":
                    paused_thread = None
        code = child.wait(timeout=20)
        receipt.update(exit_code=code, process_terminal=True, log_sha256=sha(log))
        text = log.read_text(encoding="utf-8", errors="replace")
        if code or re.search(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)", text):
            raise RuntimeError("Actual debugger probe failed")
        report = json.loads((output / "probe_report.json").read_text(encoding="utf-8"))
        if report["pid"] != child.pid or report["nonce"] != nonce or report["save_error"] != 0 or report["load_error"] != 0:
            raise RuntimeError("Actual probe process/result binding failed")
        if len(receipt["mutations"]) != 1 or report["value"] != 29 or report["before_sha256"] == report["after_sha256"]:
            raise RuntimeError("Actual ConfigFile did not observe controlled real file mutation")
        if sha(script) != receipt["script_sha256"] or sha(engine) != receipt["engine_sha256"]:
            raise RuntimeError("Source/engine changed during protocol qualification")
        receipt.update(complete=True, report=report, actual_debugger_stack_verified=True, actual_cfg_read_observed=True)
    except BaseException as error:
        receipt["failure"] = repr(error)
        raise
    finally:
        if child is not None and child.poll() is None:
            child.terminate(); child.wait(timeout=15)
        if connection is not None:
            connection.close()
        if listener is not None:
            listener.close()
        if locked and LOCK.read_text(encoding="utf-8") == str(run):
            LOCK.unlink(); receipt["lock_released"] = True
        (run / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "run": str(run), "failure": receipt.get("failure")}))


if __name__ == "__main__":
    main()
