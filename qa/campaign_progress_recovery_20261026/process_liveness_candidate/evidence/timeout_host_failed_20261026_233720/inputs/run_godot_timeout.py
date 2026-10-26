"""Independent real v1 timeout slice. --execute owns the lane; default only checks inputs."""
from pathlib import Path
import argparse
import ctypes
import importlib.util
import json
import os
import subprocess
import sys
import time
import traceback
import uuid

HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parent
ROOT = CANDIDATE.parents[2]
spec = importlib.util.spec_from_file_location("oracle_timeout_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)


class FileTime(ctypes.Structure):
    _fields_ = [("low", ctypes.c_uint32), ("high", ctypes.c_uint32)]


class Entry(ctypes.Structure):
    _fields_ = [("size", ctypes.c_uint32), ("usage", ctypes.c_uint32), ("pid", ctypes.c_uint32),
               ("heap", ctypes.c_size_t), ("module", ctypes.c_uint32), ("threads", ctypes.c_uint32),
               ("parent", ctypes.c_uint32), ("priority", ctypes.c_long), ("flags", ctypes.c_uint32),
               ("exe", ctypes.c_wchar * 260)]


class Native:
    def __init__(self):
        self.k = ctypes.WinDLL("kernel32", use_last_error=True)
        declarations = {
            "OpenProcess": ([ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32], ctypes.c_void_p),
            "WaitForSingleObject": ([ctypes.c_void_p, ctypes.c_uint32], ctypes.c_uint32),
            "GetExitCodeProcess": ([ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)], ctypes.c_int),
            "GetProcessTimes": ([ctypes.c_void_p] + [ctypes.POINTER(FileTime)] * 4, ctypes.c_int),
            "QueryFullProcessImageNameW": ([ctypes.c_void_p, ctypes.c_uint32, ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_uint32)], ctypes.c_int),
            "CloseHandle": ([ctypes.c_void_p], ctypes.c_int),
            "CreateToolhelp32Snapshot": ([ctypes.c_uint32, ctypes.c_uint32], ctypes.c_void_p),
            "Process32FirstW": ([ctypes.c_void_p, ctypes.POINTER(Entry)], ctypes.c_int),
            "Process32NextW": ([ctypes.c_void_p, ctypes.POINTER(Entry)], ctypes.c_int),
        }
        for name, (arguments, result) in declarations.items():
            function = getattr(self.k, name)
            function.argtypes, function.restype = arguments, result

    def open(self, pid):
        handle = self.k.OpenProcess(0x101000, False, pid)
        if not handle:
            raise OSError(ctypes.get_last_error(), "Cannot retain process handle", pid)
        return handle

    def observe(self, handle):
        values = [FileTime() for _ in range(4)]
        if not self.k.GetProcessTimes(handle, *[ctypes.byref(x) for x in values]):
            raise OSError(ctypes.get_last_error(), "GetProcessTimes failed")
        wait = self.k.WaitForSingleObject(handle, 0)
        if wait not in (0, 258):
            raise OSError(ctypes.get_last_error(), "Unexpected wait result", wait)
        size = ctypes.c_uint32(32768)
        buffer = ctypes.create_unicode_buffer(size.value)
        if not self.k.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(size)):
            raise OSError(ctypes.get_last_error(), "QueryFullProcessImageName failed")
        code = ctypes.c_uint32()
        if not self.k.GetExitCodeProcess(handle, ctypes.byref(code)):
            raise OSError(ctypes.get_last_error(), "GetExitCodeProcess failed")
        return {"state": "dead" if wait == 0 else "alive", "wait": wait, "exit_code": code.value,
                "creation_filetime": str((values[0].high << 32) | values[0].low), "image": buffer.value}

    def parent(self, pid):
        snapshot = self.k.CreateToolhelp32Snapshot(2, 0)
        if snapshot == ctypes.c_void_p(-1).value:
            raise OSError(ctypes.get_last_error(), "Process snapshot failed")
        try:
            entry = Entry(); entry.size = ctypes.sizeof(entry)
            present = self.k.Process32FirstW(snapshot, ctypes.byref(entry))
            while present:
                if entry.pid == pid: return entry.parent
                present = self.k.Process32NextW(snapshot, ctypes.byref(entry))
            raise RuntimeError("Provider absent before ownership binding")
        finally:
            if not self.k.CloseHandle(snapshot): raise OSError(ctypes.get_last_error(), "Snapshot close failed")


def require(value, message):
    if not value: raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    require(os.name == "nt", "Windows-only actual timeout slice")
    compiler = Path(os.environ["SystemRoot"]) / "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
    require(compiler.is_file(), "Fixed csc compiler unavailable")
    oracle = CANDIDATE / "scripts/process_liveness_oracle.gd"
    fixture_source = HERE / "HangingProviderFixture.cs"
    worker = HERE / "godot_timeout.gd"
    inputs = [oracle, fixture_source, worker, Path(__file__), compiler,
              CANDIDATE / "native/ProcessLivenessProbe.cs", HERE / "report_model.gd", CANDIDATE / "build_helper.py"]
    pins = {}
    for path in inputs:
        h.identity.no_links(path)
        pins[str(path)] = h.sha(path)
    if not args.execute:
        print(json.dumps({"preflight": True, "engine_started": False, "pins": pins}, indent=2)); return
    output = ROOT / ".godot/process_liveness_timeout_20261026" / h.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema":"process_liveness_timeout_host_v1", "complete":False, "output":str(output),
               "fixture_kind":"sleep_only_test_helper", "store_recovery_qualified":False,
               "real_win32_helper_hang_qualified":False, "production_integrated":False,
               "host_samples":[], "cleanup_errors":[]}
    native = Native()
    compiler_child = engine_child = target = None
    provider_handle = target_handle = None
    locked = False
    try:
        require(not h.shared.LOCK.exists() and not h.running(), "Shared engine occupied; no child started")
        with h.shared.LOCK.open("x", encoding="utf-8") as stream: stream.write(str(output))
        locked = True
        require(not h.running(), "Engine appeared after lane acquisition")
        engine = h.shared.resolve_godot(None); pins[str(engine)] = h.sha(engine)
        artifacts = CANDIDATE / ".artifacts" / ("timeout_" + output.name)
        artifacts.mkdir(parents=True, exist_ok=False)
        executable = artifacts / "ProcessLivenessProbe.exe"
        command = [str(compiler), "/nologo", "/target:exe", "/platform:anycpu", "/optimize+", "/warnaserror+", "/out:" + str(executable), str(fixture_source)]
        with (output / "compile.log").open("xb") as stream:
            compiler_child = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            compiler_child.wait(timeout=30)
        receipt["compile"] = {"command":command, "pid":compiler_child.pid, "exit_code":compiler_child.returncode}
        require(compiler_child.returncode == 0 and executable.is_file(), "Fixture compilation failed")
        pins[str(executable)] = h.sha(executable)
        project = output / "project"; project.mkdir()
        project_file = project / "project.godot"
        project_file.write_text('config_version=5\n[application]\nconfig/name="Process Oracle Timeout"\n', encoding="utf-8")
        pins[str(project_file)] = h.sha(project_file)
        for path in [oracle, worker]:
            h.copy_checked(path, project / path.name, pins[str(path)])
            pins[str(project / path.name)] = pins[str(path)]
        input_dir = output / "inputs"; input_dir.mkdir()
        for path in [fixture_source, Path(__file__)]: h.copy_checked(path, input_dir / path.name, pins[str(path)])
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/processtimeout" / nonce[:12]
        h.identity.no_links(profile); profile.mkdir(parents=True, exist_ok=False)
        probes = profile / "probes"; probes.mkdir()
        target = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(15)"], stdin=subprocess.DEVNULL,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
        target_handle = native.open(target.pid)
        before = native.observe(target_handle)
        require(before["state"] == "alive" and target.poll() is None, "External target is not alive")
        receipt.update(target_pid=target.pid, target_before=before, nonce=nonce, profile=str(profile), helper_sha256=h.sha(executable))
        env = h.common.private_environment(profile)
        env.update(CAMPAIGN_QA="", PT_ORACLE=str(project / oracle.name), PT_ORACLE_SHA=pins[str(oracle)], PT_TARGET=str(target.pid),
                   PT_HELPER=str(executable), PT_HELPER_SHA=pins[str(executable)], PT_PROBES=str(probes), PT_NONCE=nonce, PT_OUTPUT=str(output))
        command = [str(engine), "--headless", "--path", str(project), "--script", str(project / worker.name)]
        with (output / "native.log").open("xb") as stream:
            engine_child = subprocess.Popen(command, env=env, stdout=stream, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            receipt.update(pid=engine_child.pid, command=command, engine_sha256=pins[str(engine)])
            deadline = time.monotonic() + 12
            started_path = output / "started.json"
            while not started_path.exists():
                require(engine_child.poll() is None, "Godot exited before provider ownership could be bound")
                require(time.monotonic() < deadline, "Provider start evidence deadline")
                time.sleep(0.01)
            start = h.read(started_path)
            require(start["schema"] == "process_timeout_started_v1" and start["nonce"] == nonce and start["godot_pid"] == engine_child.pid and start["target_pid"] == target.pid, "Provider start scope mismatch")
            provider_pid = start["provider_pid"]
            require(provider_pid > 0 and provider_pid not in (target.pid, engine_child.pid), "Provider PID scope invalid")
            provider_handle = native.open(provider_pid)
            provider_before = native.observe(provider_handle)
            parent = native.parent(provider_pid)
            require(parent == engine_child.pid and Path(provider_before["image"]).resolve() == executable.resolve() and provider_before["state"] == "alive", "Provider is not the live owned Godot descendant")
            receipt.update(provider_pid=provider_pid, provider_parent_pid=parent, provider_before=provider_before, started_sha256=h.sha(started_path))
            while engine_child.poll() is None:
                require(time.monotonic() < deadline, "Godot timeout test exceeded host deadline")
                sample = native.observe(target_handle)
                require(sample["state"] == "alive" and sample["creation_filetime"] == before["creation_filetime"] and target.poll() is None, "Queried target changed or was terminated")
                receipt["host_samples"].append(sample)
                time.sleep(0.1)
        receipt["exit_code"] = engine_child.returncode
        require(engine_child.returncode == 0, "Godot timeout worker failed")
        log = (output / "native.log").read_text("utf-8", errors="replace")
        require(not h.common.ERROR_LINES.findall(log), "Godot engine/script error")
        report = h.read(output / "report.json")
        require(report["schema"] == "process_liveness_godot_timeout_v1" and report["passed"] and report["pid"] == engine_child.pid and report["nonce"] == nonce, "Worker report mismatch")
        require(report["checks"] and all(row["passed"] for row in report["checks"]), "Timeout assertion failed")
        require(report["observed"]["timeout"]["provider_pid"] == provider_pid and report["observed"]["timeout"]["target_pid"] == target.pid, "Timeout identities changed")
        receipt["provider_after"] = native.observe(provider_handle)
        receipt["target_after"] = native.observe(target_handle)
        require(receipt["provider_after"]["state"] == "dead" and receipt["provider_after"]["creation_filetime"] == provider_before["creation_filetime"], "Owned provider terminal not confirmed")
        require(receipt["target_after"]["state"] == "alive" and receipt["target_after"]["creation_filetime"] == before["creation_filetime"] and target.poll() is None, "Target did not survive timeout")
        receipt.update(test_passed=True, checks=len(report["checks"]), report_sha256=h.sha(output / "report.json"), timeout_control_qualified=True)
    except BaseException as error:
        receipt.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        # The queried target is NEVER terminated by this harness; its bounded fixture exits naturally.
        # The provider is never killed by the host, even through its retained handle.
        for label, child in [("engine", engine_child), ("compiler", compiler_child)]:
            try:
                if child is not None and child.poll() is None: child.kill(); child.wait(timeout=10)
                receipt[label + "_terminal"] = child is None or child.poll() is not None
            except BaseException as error: receipt["cleanup_errors"].append({"where":label, "error":repr(error)})
        try:
            if target is not None: target.wait(timeout=25)
            receipt["target_fixture_terminal"] = target is None or target.poll() is not None
            receipt["target_fixture_exit_code"] = None if target is None else target.returncode
            require(target is None or target.returncode == 0, "Queried target did not exit naturally with zero")
        except BaseException as error: receipt["cleanup_errors"].append({"where":"target_natural_exit", "error":repr(error)})
        try:
            if provider_handle is not None:
                # A failed kill cannot become a pass merely because the Sleep fixture later exits naturally.
                wait = native.k.WaitForSingleObject(provider_handle, 32000)
                receipt["provider_terminal"] = wait == 0
                receipt["provider_final"] = native.observe(provider_handle)
            else:
                receipt["provider_terminal"] = engine_child is None
        except BaseException as error: receipt["cleanup_errors"].append({"where":"provider_terminal", "error":repr(error)})
        for label, handle in [("provider_handle", provider_handle), ("target_handle", target_handle)]:
            try:
                if handle is not None: require(native.k.CloseHandle(handle), "CloseHandle failed")
            except BaseException as error: receipt["cleanup_errors"].append({"where":label, "error":repr(error)})
        try:
            receipt["pins"] = pins
            receipt["pins_unchanged"] = all(h.sha(Path(path)) == value for path, value in pins.items())
        except BaseException as error: receipt["cleanup_errors"].append({"where":"pins", "error":repr(error)})
        terminal = False
        try:
            owned = locked and h.shared.LOCK.is_file() and h.shared.LOCK.read_text("utf-8") == str(output)
            terminal = all(receipt.get(name, False) for name in ["engine_terminal", "compiler_terminal", "target_fixture_terminal", "provider_terminal"])
            receipt["lock_ownership_confirmed"] = owned
            if owned and terminal and not h.running(): h.shared.LOCK.unlink()
            receipt["lock_released"] = locked and not h.shared.LOCK.exists()
        except BaseException as error: receipt["cleanup_errors"].append({"where":"lock", "error":repr(error)})
        receipt["complete"] = bool(receipt.get("test_passed") and receipt.get("pins_unchanged") and receipt.get("lock_released") and terminal and not receipt["cleanup_errors"] and "error" not in receipt)
        if not receipt["complete"]: receipt["timeout_control_qualified"] = False
        h.save(output / "receipt.json", receipt)
    print(json.dumps({"output":str(output), "complete":receipt["complete"], "checks":receipt.get("checks"), "error":receipt.get("error"), "cleanup_errors":receipt["cleanup_errors"], "lock_released":receipt.get("lock_released")}, ensure_ascii=False))
    if not receipt["complete"]: raise SystemExit(1)


if __name__ == "__main__": main()
