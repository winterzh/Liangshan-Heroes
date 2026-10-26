"""Bounded native helper tests, isolated from Godot and every Store. Default is preflight only."""
from pathlib import Path
import argparse
import ctypes
import hashlib
import json
import os
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
FIELDS = {"code", "creation_filetime", "handle_opened", "nonce", "provider_pid", "query_utc_filetime", "schema", "state", "target_pid", "wait_result", "win32_error"}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-receipt", type=Path, required=True)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    if os.name != "nt":
        raise SystemExit("Windows-only actual native helper probe")
    receipt_path = args.build_receipt.resolve()
    build = json.loads(receipt_path.read_text("utf-8"))
    helper = Path(build["helper_path"]).resolve()
    assert helper.is_relative_to(ROOT / ".artifacts") and helper.name == "ProcessLivenessProbe.exe"
    assert build["complete"] and build["compiled"] and sha(helper) == build["helper_sha256"]
    source = ROOT / "native/ProcessLivenessProbe.cs"
    assert sha(source) == build["source_sha256"]
    pins = {"helper": sha(helper), "source": sha(source), "build_receipt": sha(receipt_path), "native_runner": sha(Path(__file__))}
    if not args.run:
        print(json.dumps({"preflight": True, "pins": pins, "godot_started": False}, indent=2)); return
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    output = ROOT / ".artifacts" / ("native_" + name)
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "process_liveness_native_helper_tests_v1", "complete": False, "pins": pins,
              "output": str(output), "cases": [], "godot_started": False, "store_recovery_qualified": False,
              "godot_adapter_qualified": False, "production_integrated": False, "sdk_qualified": False}
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    k.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]; k.OpenProcess.restype = ctypes.c_void_p
    k.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]; k.WaitForSingleObject.restype = ctypes.c_uint32
    k.CloseHandle.argtypes = [ctypes.c_void_p]; k.CloseHandle.restype = ctypes.c_int
    children = []

    def native(pid):
        handle = k.OpenProcess(0x101000, False, pid)
        if not handle:
            error = ctypes.get_last_error()
            return {"state": "dead" if error == 87 and pid > 0 else "unknown", "error": error, "wait": None}
        try:
            wait = k.WaitForSingleObject(handle, 0)
            return {"state": "dead" if wait == 0 else "alive" if wait == 258 else "unknown", "error": 0, "wait": wait}
        finally:
            assert k.CloseHandle(handle)

    def child(command):
        result = subprocess.Popen(command, shell=False, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
        children.append(result); return result

    def probe(label, target, expected_state=None, expected_code=None, invalid_pid=None, collision=None):
        nonce = uuid.uuid4().hex
        directory = output / nonce
        directory.mkdir(exist_ok=False)
        case = {"name": label, "target_pid": target, "nonce": nonce, "directory": str(directory), "passed": False}
        report["cases"].append(case)
        if collision:
            (directory / collision).write_bytes(b"retained-owned-evidence")
        case["host_before"] = native(target) if invalid_pid is None else None
        process = child([str(helper), str(target) if invalid_pid is None else invalid_pid, nonce, str(directory)])
        case["provider_pid"] = process.pid
        started = time.monotonic()
        try:
            process.wait(timeout=5)
            case["exit_code"] = process.returncode
            case["elapsed_seconds"] = time.monotonic() - started
            if invalid_pid is not None:
                assert process.returncode == 64 and not (directory / "result.json").exists()
            elif collision:
                assert process.returncode != 0 and (directory / collision).read_bytes() == b"retained-owned-evidence"
                assert not (directory / ("pending.json" if collision == "result.json" else "result.json")).exists()
            else:
                assert process.returncode == 0
                final = directory / "result.json"
                assert final.stat().st_size <= 4096 and not (directory / "pending.json").exists()
                raw = final.read_text("ascii")
                row = json.loads(raw)
                assert set(row) == FIELDS and json.dumps(row, sort_keys=True, separators=(",", ":")) == raw
                assert row["schema"] == "windows_process_liveness_v1" and row["nonce"] == nonce
                assert row["target_pid"] == str(target) and row["provider_pid"] == str(process.pid)
                assert isinstance(row["handle_opened"], bool)
                assert all(isinstance(v, str) for key, v in row.items() if key != "handle_opened")
                assert row["state"] == expected_state
                if expected_code is not None:
                    assert row["code"] == expected_code
                case["row"] = row
                case["report_sha256"] = sha(final)
            case["host_after"] = native(target) if invalid_pid is None else None
            if expected_state is not None:
                assert case["host_before"]["state"] == expected_state and case["host_after"]["state"] == expected_state
            case["passed"] = True
        except BaseException as error:
            case["error"] = repr(error)
            raise
        finally:
            if process.poll() is None:
                process.kill(); process.wait(timeout=5)
            case["owned_provider_terminal"] = process.poll() is not None
        return case

    try:
        probe("actual external observer process alive", os.getpid(), "alive", "HANDLE_NONSIGNALED")
        live = child([sys.executable, "-c", "import time; time.sleep(60)"])
        assert live.poll() is None
        probe("actual external sibling process alive", live.pid, "alive", "HANDLE_NONSIGNALED")
        for exit_code in (7, 259):
            dead = child([sys.executable, "-c", "import sys; sys.exit(" + str(exit_code) + ")"])
            dead.wait(timeout=5)
            assert dead.returncode == exit_code
            # Popen retains the kernel process handle, permitting OpenProcess on the exited object.
            probe("actual exited process retained handle exit " + str(exit_code), dead.pid, "dead", "HANDLE_SIGNALED")
        gone = child([sys.executable, "-c", "pass"])
        gone.wait(timeout=5)
        gone._handle.Close()  # Owned CPython Windows process handle; never a target opened by PID.
        probe("actual exited and released PID absent", gone.pid, "dead", "PID_ABSENT_87")
        # Ordinary account on this host: record native permission evidence instead of claiming SDK identity.
        system = native(4)
        if system["state"] == "unknown" and system["error"] == 5:
            probe("actual System process permission denied", 4, "unknown", "OPEN_FAILED")
        else:
            report["permission_denied_case_unavailable"] = system
        for invalid in ("0", "-1", "1.0", "01", "2147483648"):
            probe("reject invalid PID " + invalid, 0, invalid_pid=invalid)
        probe("do not replace existing pending evidence", os.getpid(), collision="pending.json")
        probe("do not replace existing final evidence", os.getpid(), collision="result.json")
        assert sha(helper) == pins["helper"] and sha(source) == pins["source"] and sha(receipt_path) == pins["build_receipt"]
        report["complete"] = all(case["passed"] for case in report["cases"])
    except BaseException as error:
        report["error"] = repr(error)
    finally:
        for process in children:
            if process.poll() is None:
                process.kill(); process.wait(timeout=5)
        report["owned_children_terminal"] = all(process.poll() is not None for process in children)
        report["complete"] = report["complete"] and report["owned_children_terminal"]
        report["current_pins"] = {"helper": sha(helper), "source": sha(source), "build_receipt": sha(receipt_path), "native_runner": sha(Path(__file__))}
        report["complete"] = report["complete"] and report["current_pins"] == pins
        serialized = json.dumps(report, indent=2)
        (output / "receipt.json").write_text(serialized, encoding="utf-8")
        (ROOT / "evidence" / ("native_" + name + ".json")).write_text(serialized, encoding="utf-8")
    print(json.dumps({"complete": report["complete"], "output": str(output), "cases": len(report["cases"]), "error": report.get("error")}, indent=2))
    if not report["complete"]:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
