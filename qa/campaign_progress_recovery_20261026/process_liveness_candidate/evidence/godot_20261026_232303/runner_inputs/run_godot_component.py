"""Minimal Godot component test; explicit --execute, no Store/game or production changes."""
from pathlib import Path
import argparse
import ctypes
import hashlib
import importlib.util
import json
import subprocess
import sys
import uuid

HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parent
ROOT = CANDIDATE.parents[2]

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value

h = module("oracle_component_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")

class FileTime(ctypes.Structure):
    _fields_ = [("low", ctypes.c_uint32), ("high", ctypes.c_uint32)]

def native_state(pid):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    kernel.WaitForSingleObject.restype = ctypes.c_uint32
    kernel.GetProcessTimes.argtypes = [ctypes.c_void_p] + [ctypes.POINTER(FileTime)] * 4
    kernel.GetProcessTimes.restype = ctypes.c_int
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    kernel.CloseHandle.restype = ctypes.c_int
    handle = kernel.OpenProcess(0x101000, False, pid)
    if not handle:
        error = ctypes.get_last_error()
        return {"state": "dead" if error == 87 and pid > 0 else "unknown", "error": error, "creation_filetime": ""}
    try:
        creation, exit_time, system, user = [FileTime() for _ in range(4)]
        assert kernel.GetProcessTimes(handle, *[ctypes.byref(x) for x in [creation, exit_time, system, user]])
        wait = kernel.WaitForSingleObject(handle, 0)
        return {"state": "dead" if wait == 0 else "alive" if wait == 258 else "unknown", "wait": wait,
                "creation_filetime": str((creation.high << 32) | creation.low)}
    finally:
        assert kernel.CloseHandle(handle)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-receipt", required=True, type=Path)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    build = h.read(args.build_receipt)
    executable = Path(build["helper_path"])
    assert build["complete"] and h.sha(executable) == build["helper_sha256"]
    assert h.sha(CANDIDATE / "native/ProcessLivenessProbe.cs") == build["source_sha256"]
    if not args.execute:
        print(json.dumps({"preflight": True, "engine_started": False, "helper_sha256": build["helper_sha256"]})); return
    output = ROOT / ".godot/process_liveness_godot_20261026" / h.stamp()
    output.mkdir(parents=True)
    receipt = {"schema": "process_liveness_godot_host_v1", "complete": False, "store_recovery_qualified": False,
               "gameplay_qualified": False, "production_integrated": False, "output": str(output)}
    children, pins = [], {}
    engine_child = None
    locked = False
    try:
        assert not h.shared.LOCK.exists() and not h.running(), "Shared engine occupied"
        with h.shared.LOCK.open("x", encoding="utf-8") as stream: stream.write(str(output))
        locked = True
        engine = h.shared.resolve_godot(None)
        project = output / "project"; project.mkdir()
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Process Oracle Component"\n', encoding="utf-8")
        for path in [CANDIDATE / "scripts/process_liveness_oracle.gd", HERE / "report_model.gd", HERE / "godot_component.gd"]:
            pins[str(path)] = h.sha(path)
            h.copy_checked(path, project / path.name, pins[str(path)])
            pins[str(project / path.name)] = pins[str(path)]
        for path in [Path(__file__), HERE / "run_native_helper.py", args.build_receipt, executable,
                     CANDIDATE / "native/ProcessLivenessProbe.cs", engine]: pins[str(path)] = h.sha(path)
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/processcomponent" / nonce[:12]
        profile.mkdir(parents=True, exist_ok=False)
        probes = profile / "probes"; probes.mkdir()
        def child(code):
            process = subprocess.Popen([sys.executable, "-c", code], creationflags=subprocess.CREATE_NO_WINDOW)
            children.append(process); return process
        live = child("import time; time.sleep(90)")
        held = child("import sys; sys.exit(259)")
        held.wait(timeout=10); assert held.returncode == 259
        gone = child("pass"); gone.wait(timeout=10); gone._handle.Close()
        targets = []
        for label, pid, expected, code in [("external sibling alive", live.pid, "alive", "HANDLE_NONSIGNALED"),
                                           ("retained exited 259", held.pid, "dead", "HANDLE_SIGNALED"),
                                           ("released absent PID", gone.pid, "dead", "PID_ABSENT_87"),
                                           ("permission denied", 4, "unknown", "OPEN_FAILED")]:
            state = native_state(pid)
            assert state["state"] == expected, (label, state)
            targets.append(dict(state, label=label, pid=pid, expected=expected, code=code))
        fixture = {"nonce": nonce, "targets": targets}
        h.save(output / "fixtures.json", fixture)
        env = h.common.private_environment(profile)
        env.update(PL_ORACLE=str(project / "process_liveness_oracle.gd"), PL_MODEL=str(project / "report_model.gd"),
                   PL_ORACLE_SHA=pins[str(project / "process_liveness_oracle.gd")], PL_MODEL_SHA=pins[str(project / "report_model.gd")],
                   PL_HELPER=str(executable), PL_HELPER_SHA=build["helper_sha256"], PL_PROBES=str(probes),
                   PL_FIXTURES=str(output / "fixtures.json"), PL_NONCE=nonce, PL_REPORT=str(output / "report.json"))
        command = [str(engine), "--headless", "--path", str(project), "--script", str(project / "godot_component.gd")]
        with (output / "native.log").open("xb") as stream:
            engine_child = subprocess.Popen(command, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                            creationflags=subprocess.CREATE_NO_WINDOW)
            receipt.update(pid=engine_child.pid, command=command, engine_sha256=h.sha(engine), profile=str(profile))
            engine_child.wait(timeout=35)
        receipt["exit_code"] = engine_child.returncode
        log = (output / "native.log").read_text("utf-8", errors="replace")
        assert not any(word in log for word in ["SCRIPT ERROR:", "Parse Error:", "Compile Error:"]), "GDScript failed"
        assert engine_child.returncode == 0
        report = h.read(output / "report.json")
        assert report["passed"] and report["pid"] == engine_child.pid and report["nonce"] == nonce
        assert all(row["passed"] for row in report["checks"])
        assert len(report["model"]["checks"]) == 22 and all(row["passed"] for row in report["model"]["checks"])
        receipt["host_after"] = [native_state(row["pid"]) for row in targets]
        assert all(row["state"] == after["state"] for row, after in zip(targets, receipt["host_after"]))
        assert live.poll() is None
        receipt.update(complete=True, report_sha256=h.sha(output / "report.json"), model_checks=22,
                       component_checks=len(report["checks"]), native_queries=len(report["queries"]))
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        for process in [engine_child] + children:
            if process is not None and process.poll() is None: process.kill(); process.wait(timeout=10)
        receipt["owned_children_terminal"] = all(p is None or p.poll() is not None for p in [engine_child] + children)
        receipt["pins"] = pins
        receipt["pins_unchanged"] = all(h.sha(Path(p)) == digest for p, digest in pins.items())
        if locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text("utf-8") == str(output) and not h.running(): h.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not h.shared.LOCK.exists()
        receipt["complete"] = bool(receipt["complete"] and receipt["pins_unchanged"] and receipt["lock_released"] and receipt["owned_children_terminal"])
        h.save(output / "receipt.json", receipt)
    print(json.dumps(receipt, ensure_ascii=False))
    if not receipt["complete"]: raise SystemExit(1)

if __name__ == "__main__": main()
