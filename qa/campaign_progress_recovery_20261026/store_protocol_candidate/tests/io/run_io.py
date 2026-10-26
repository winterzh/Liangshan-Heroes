"""Unique-cleanup Store/Ledger bounded 23-process I/O slice. Default is preflight; --execute owns the shared lane.

Reuses the existing bounded Godot debugger wire and immutable-project helpers.
No production method is overridden. Faults are actual Windows sharing denials
or termination of this runner's own paused child, with all disk evidence kept.
"""
from __future__ import annotations

import argparse
import ctypes as ct
from ctypes import wintypes as wt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
spec = importlib.util.spec_from_file_location("handoff_io_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
from godot_debug_wire import DebugConnection, stack_frames
from run_workstation_baseline import engines

OWNER = "76561198000000001"
MODES = ("normal", "legacy_upgrade", "write_retry", "rename_writing_retry", "rename_owner_retry",
         "cleanup_delete_retry", "marker_delete_retry", "crash_pending", "crash_record", "crash_half",
         "crash_cleanup", "crash_marker", "crash_cleanup_removed", "crash_marker_removed")
TRIPLE = {"crash_cleanup", "crash_marker"}
POINTS = {
    "write_retry": ("scripts/run_snapshot_store.gd", "var file := FileAccess.open(path, FileAccess.WRITE)", "_write_new"),
    "rename_writing_retry": ("scripts/steam_receipt_store.gd", 'if DirAccess.rename_absolute(directory.path_join("writing"),directory.path_join(cleanup)) != OK: return bad("RENAME")', "release"),
    "rename_owner_retry": ("scripts/steam_receipt_store.gd", 'if DirAccess.rename_absolute(directory.path_join(lock.name).path_join("owner.json"),directory.path_join(name)) != OK: return bad("RENAME")', "release"),
    "cleanup_delete_retry": ("scripts/steam_receipt_store.gd", 'if DirAccess.remove_absolute(directory.path_join(marker.cleanup)) != OK: return bad("LOCK_RELEASE")', "_finish_release"),
    "marker_delete_retry": ("scripts/steam_receipt_store.gd", 'if DirAccess.remove_absolute(directory.path_join(marker.name)) != OK: return bad("LOCK_RELEASE")', "_finish_release"),
    "crash_pending": ("scripts/run_snapshot_store.gd", '_checkpoint("pending_verified")', "commit_locked"),
    "crash_record": ("scripts/run_snapshot_store.gd", '_checkpoint("record_renamed")', "commit_locked"),
    "crash_half": ("scripts/run_snapshot_store.gd", '_checkpoint("pending_half")', "_write_new"),
    "crash_cleanup": ("scripts/steam_receipt_store.gd", '_checkpoint("release_directory_claimed")', "release"),
    "crash_marker": ("scripts/steam_receipt_store.gd", '_checkpoint("release_marker_published")', "release"),
    "crash_cleanup_removed": ("scripts/steam_receipt_store.gd", '_checkpoint("release_directory_removed")', "_finish_release"),
    "crash_marker_removed": ("scripts/steam_receipt_store.gd", '_checkpoint("release_marker_removed")', "_finish_release"),
    "recover_claim_crash": ("scripts/steam_receipt_store.gd", '_checkpoint("unique_release_recovery_claimed")', "recover"),
}


def is_crash(mode):
    return mode.startswith("crash_") or mode == "recover_claim_crash"


def fault_target(directory, profile, mode):
    if mode == "write_retry":
        return owned(directory / "receipt.pending", profile)
    if mode == "rename_writing_retry":
        return owned(directory / "writing", profile)
    cleanup = [p for p in directory.iterdir() if p.is_dir() and re.fullmatch(r"cleanup_v1_[1-9][0-9]*_[0-9a-f]{32}", p.name)]
    markers = [p for p in directory.iterdir() if p.is_file() and re.fullmatch(r"release_v1_[1-9][0-9]*_[0-9a-f]{32}_[1-9][0-9]*_[0-9a-f]{32}_[0-9]+_[0-9a-f]{64}\.json", p.name)]
    if mode in {"rename_owner_retry", "cleanup_delete_retry"}:
        require(len(cleanup) == 1, "One exact unique cleanup target required")
        if mode == "rename_owner_retry":
            require(not markers and (cleanup[0] / "owner.json").is_file(), "Original owner must still be inside cleanup")
            return owned(cleanup[0] / "owner.json", profile)
        require(len(markers) == 1 and not list(cleanup[0].iterdir()), "One marker and empty cleanup required")
        return owned(cleanup[0], profile)
    require(mode == "marker_delete_retry" and len(markers) == 1 and not cleanup,
            "One remaining marker and no cleanup required")
    return owned(markers[0], profile)



def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def owned(path, root):
    path, root = Path(path), Path(root)
    helper.identity.no_links(path)
    require(path.resolve().is_relative_to(root.resolve()), "Path outside this private profile: " + str(path))
    return path


def snapshot(directory):
    directory = Path(directory)
    helper.identity.no_links(directory)
    if not directory.exists():
        return {"exists": False, "files": {}, "directories": []}
    files, directories = {}, []
    for parent, dirs, names in os.walk(directory, followlinks=False):
        for name in dirs + names:
            helper.identity.no_links(Path(parent) / name)
        directories.append(Path(parent).relative_to(directory).as_posix())
        for name in names:
            path = Path(parent) / name
            files[path.relative_to(directory).as_posix()] = {"sha256": helper.sha(path), "bytes": path.stat().st_size}
    return {"exists": True, "files": files, "directories": sorted(directories)}


def read_if_closed(path):
    if not path.exists():
        return None
    try:
        return helper.read(path)
    except (json.JSONDecodeError, UnicodeDecodeError, PermissionError):
        return None


def pin_stage(stage, pins):
    for name in ("controller.json", "native.log", "prepared.json", "report.json"):
        path = stage / name
        if path.is_file():
            pins[str(path)] = helper.sha(path)


class NativeSharingDenial:
    """One owned native handle, preserving the actual file bytes; no ACL changes."""
    def __init__(self, path, profile, kind):
        self.path = owned(path, profile)
        self.kind = kind
        self.handle = None
        require(os.name == "nt", "Windows sharing-fault runner required")
        self.api = ct.WinDLL("kernel32", use_last_error=True)
        self.api.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, ct.c_void_p, wt.DWORD, wt.DWORD, wt.HANDLE]
        self.api.CreateFileW.restype = wt.HANDLE
        self.api.CloseHandle.argtypes = [wt.HANDLE]
        self.api.CloseHandle.restype = wt.BOOL
        if kind == "write_retry":
            require(not self.path.exists(), "Pending file must be absent before owned denial")
            # CREATE_NEW after production's existence check; readers/deletion
            # may proceed, but the upcoming FileAccess.WRITE is denied.
            share, disposition, flags = 1 | 4, 1, 0x80
        else:
            require(self.path.exists(), "Deletion-denial target missing")
            share, disposition, flags = 1 | 2, 3, 0x02000000 if self.path.is_dir() else 0x80
        self.handle = self.api.CreateFileW(str(self.path), 0x80000000, share, None, disposition, flags, None)
        if self.handle == ct.c_void_p(-1).value:
            self.handle = None
            raise ct.WinError(ct.get_last_error())

    def close(self):
        if self.handle is not None:
            require(bool(self.api.CloseHandle(self.handle)), "Native sharing handle close failed")
            self.handle = None


def source_points(project):
    result = {}
    for mode, (path, statement, function) in POINTS.items():
        source = project / path
        matches = [i + 1 for i, line in enumerate(source.read_text(encoding="utf-8-sig").splitlines()) if line.strip() == statement]
        require(len(matches) == 1, "Unique unchanged production boundary required: " + mode)
        result[mode] = {"source": "res://" + path, "line": matches[0], "function": function,
                        "source_sha256": helper.sha(source), "statement": statement}
    return result


def run_stage(engine, project, workers, profile, base_env, nonce, mode, stage, points, timeout, previous=None):
    stage.mkdir()
    env = dict(base_env)
    env["CAMPAIGN_QA"] = ""
    for key in list(env):
        if key.startswith(("SP_", "IO_", "MR_", "CR_", "LR_", "HG_", "CC_", "CH_", "RG_")):
            env.pop(key)
    env.update(SP_PROFILE=str(profile), SP_PROJECT=str(project), SP_WORKERS=str(workers),
               SP_WORKER_SHA256=helper.sha(workers / "worker.gd"), SP_NONCE=nonce, SP_MODE=mode, SP_OUTPUT=str(stage))
    if previous is not None:
        env.update(SP_PREVIOUS=str(previous), SP_PREVIOUS_SHA256=helper.sha(previous))
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
    port = listener.getsockname()[1]
    command = [str(engine), "--path", str(project), "--headless", "--remote-debug", f"tcp://127.0.0.1:{port}",
               "--script", str(workers / "bootstrap.gd")]
    row = {"mode": mode, "command": command, "profile": str(profile), "nonce": nonce,
           "complete": False, "faults": [], "debug_stops": [], "synthetic_account_and_token": True,
           "production_method_overrides": 0, "sdk_qualified": False}
    child = connection = handle = None
    pending = None
    observer = None
    directory = None
    try:
        require(not helper.running(), "Foreign engine appeared before this owned launch")
        with (stage / "native.log").open("wb") as log:
            child = subprocess.Popen(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            row["pid"] = child.pid
            connection, _ = listener.accept(); listener.close(); listener = None
            connection.settimeout(.15)
            peer = DebugConnection(connection)
            deadline = time.monotonic() + timeout
            thread_id = None
            issued = 0
            stop_verified = False
            while child.poll() is None:
                require(time.monotonic() < deadline, "Owned I/O process timeout")
                require(not (engines() - {child.pid}), "Shared engine resumed during owned I/O run")
                request = read_if_closed(stage / ("request_%02d.json" % issued))
                if request is not None and thread_id is not None:
                    require(request.get("schema") == "handoff_io_gate_v1" and request.get("pid") == child.pid
                            and request.get("nonce") == nonce and request.get("index") == issued
                            and request.get("owner") == OWNER and request.get("mode") == mode, "Gate identity/order mismatch")
                    directory = owned(request["directory"], profile)
                    require(directory.parts[-4:] == ("steam_receipts", "v1", "5088120", OWNER), "Fixed production ledger path required")
                    if request["kind"] == "release_fault":
                        require(handle is not None and len(row["faults"]) == 1, "Original native denial must still be held")
                        row["faults"][0]["failed_inventory"] = snapshot(directory)
                        handle.close(); handle = None
                        if mode == "write_retry":
                            empty = directory / "receipt.pending"
                            require(empty.is_file() and empty.stat().st_size == 0, "Owned empty denial placeholder changed")
                            row["faults"][0]["removed_own_empty_placeholder_sha256"] = helper.sha(empty)
                            empty.unlink()  # Only the exact zero-byte file this controller created.
                        row["faults"][0]["denial_released"] = True
                    else:
                        require(request["kind"] == mode and mode in points and pending is None, "Unexpected fault request")
                        pending = {**points[mode], "kind": mode}
                        peer.command("breakpoint", thread_id, [pending["source"], pending["line"], True])
                        if mode == "crash_marker_removed":
                            observer = dict(points["crash_marker"])
                            peer.command("breakpoint", thread_id, [observer["source"], observer["line"], True])
                    helper.save(stage / ("ack_%02d.json" % issued), {"nonce": nonce, "pid": child.pid, "index": issued})
                    issued += 1
                try:
                    message, packet = peer.receive()
                except socket.timeout:
                    continue
                except EOFError:
                    break
                name, thread, data = message
                if name == "set_pid":
                    require(data == [child.pid], "Debugger actual PID differs")
                    thread_id = thread
                elif name == "debug_enter":
                    require(pending is not None and data == [True, "Breakpoint", True, thread], "Unexpected debugger/error stop")
                    peer.command("get_stack_dump", thread)
                elif name == "stack_dump":
                    frames = stack_frames(data)
                    if observer is not None and frames[0] == {k: observer[k] for k in ("source", "line", "function")}:
                        require(directory is not None and "preterminal_marker_observation" not in row,
                                "Unique earlier marker observation required")
                        markers = [p for p in directory.iterdir() if p.is_file() and p.name.startswith("release_v1_")]
                        require(len(markers) == 1, "One published marker before terminal removal required")
                        marker = owned(markers[0], profile)
                        metadata = helper.read(marker)
                        require(metadata.get("owner") == OWNER and metadata.get("pid") == str(child.pid),
                                "Observed marker is not the actual owned writer")
                        row["preterminal_marker_observation"] = {
                            "point": dict(observer), "frames": frames, "marker_name": marker.name,
                            "marker_raw": marker.read_text(encoding="utf-8"), "marker_sha256": helper.sha(marker),
                            "inventory": snapshot(directory), "packet_sha256": hashlib.sha256(packet).hexdigest()}
                        peer.command("breakpoint", thread, [observer["source"], observer["line"], False])
                        observer = None
                        peer.command("continue", thread)
                        continue
                    require(pending is not None and frames[0] == {k: pending[k] for k in ("source", "line", "function")}, "Native boundary stack mismatch")
                    row["debug_stops"].append({"frames": frames, "packet_sha256": hashlib.sha256(packet).hexdigest()})
                    if mode == "write_retry" and not any(frame["function"] == "commit_locked" for frame in frames[1:]):
                        # acquire() writes owner.json through the same helper;
                        # only the later commit_locked pending write is targeted.
                        require(any(frame["function"] == "acquire" for frame in frames[1:]), "Unexpected _write_new caller")
                        peer.command("continue", thread)
                        continue
                    require(not stop_verified and directory is not None, "Fault boundary must be unique")
                    stop_verified = True
                    event = {"kind": mode, "point": dict(pending), "frames": frames,
                             "before_inventory": snapshot(directory), "actual_native_operation": True}
                    row["faults"].append(event)
                    if is_crash(mode):
                        require((stage / "prepared.json").is_file(), "Original handoff descriptor absent before termination")
                        child.kill(); child.wait(timeout=20)
                        require(child.returncode != 0, "Deliberate crash must have a non-success process exit")
                        event["externally_terminated_pid"] = child.pid
                        event["exit_code"] = child.returncode
                        event["terminated_inventory"] = snapshot(directory)
                        backup = stage / "terminated_account_copy"
                        shutil.copytree(directory, backup)
                        require(snapshot(backup) == event["terminated_inventory"], "Terminated original bytes copy differs")
                        row["original_pid_terminal"] = True
                        break
                    target = fault_target(directory, profile, mode)
                    handle = NativeSharingDenial(target, profile, mode)
                    event.update(target=str(target), native_sharing_denial_acquired=True)
                    peer.command("breakpoint", thread, [pending["source"], pending["line"], False])
                    pending = None
                    peer.command("continue", thread)
            child.wait(timeout=20)
        row.update(exit_code=child.returncode, process_terminal=True, log_sha256=helper.sha(stage / "native.log"))
        log_text = (stage / "native.log").read_text(encoding="utf-8", errors="replace")
        require(not re.search(r"SCRIPT ERROR:|Parse Error:|Compile Error:", log_text), "Script failures are not I/O fault evidence")
        if is_crash(mode):
            require(row.get("original_pid_terminal") and stop_verified and len(row["faults"]) == 1, "Crash boundary not observed")
            if mode == "crash_marker_removed":
                observed = row.get("preterminal_marker_observation", {})
                require(observed and observer is None, "Final clean crash must retain original owner/marker evidence")
                records = {k: v for k, v in observed["inventory"]["files"].items() if k.startswith("record_")}
                final = row["faults"][0]["terminated_inventory"]
                require(final["files"] == records and final["directories"] == ["."],
                        "Final marker removal changed records or left residue")
            row["complete"] = True
        else:
            require(child.returncode == 0, "Native worker failed")
            report = helper.read(stage / "report.json")
            require(report.get("passed") and not report.get("failures") and report.get("pid") == child.pid
                    and report.get("nonce") == nonce and report.get("profile") == str(profile)
                    and report.get("mode") == mode and report.get("synthetic_account_and_token") is True
                    and report.get("sdk_or_real_account_qualified") is False, "Native worker report mismatch")
            if mode.endswith("_retry"):
                require(stop_verified and len(row["faults"]) == 1 and row["faults"][0].get("denial_released"), "Native denial was not observed and released")
            row.update(complete=True, report=report, report_sha256=helper.sha(stage / "report.json"))
        return row
    except BaseException as exc:
        row["error"] = repr(exc)
        raise
    finally:
        # Only this stage's child and handles. Failed disk state is never repaired.
        if child is not None and child.poll() is None:
            child.terminate(); child.wait(timeout=20)
            row["aborted_owned_child"] = True
        if handle is not None:
            handle.close()
        if connection is not None:
            connection.close()
        if listener is not None:
            listener.close()
        if directory is not None:
            row["final_inventory"] = snapshot(directory)
        helper.save(stage / "controller.json", row)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    base = args.base_run.resolve()
    require(base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"), "Existing candidate freeze required")
    helper.identity.no_links(base)
    require(args.timeout >= 60 and args.wait_lane >= 0, "Invalid bounded timeout")
    project = helper.assert_runtime_current(base)
    generation = helper.read(base / "generation.json")
    helper.identity.verify_generated(project, generation)
    points = source_points(project)
    protocol_source = HERE.parents[1] / "scripts/steam_receipt_store.gd"
    require(helper.sha(project / "scripts/steam_receipt_store.gd") == helper.sha(protocol_source),
            "Installed Store differs from this unique-cleanup protocol candidate")
    if not args.execute:
        print(json.dumps({"source_preflight": True, "base_run": str(base), "points": points,
                          "stages": 23, "native_started": False}, ensure_ascii=False, indent=2))
        return
    output = ROOT / ".godot/campaign_store_protocol_io_20261026" / helper.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "campaign_store_protocol_io_runner_v1", "complete": False, "base_run": str(base),
               "source_points": points, "stages": [], "sdk_or_real_account_qualified": False,
               "production_method_overrides": 0, "power_loss_durability_qualified": False,
               "known_gaps": ["No competing live writers/recoverers in this slice", "No legacy recovering/owner-removed redesign", "No full mutation/foreign-owner negative matrix", "No SDK, gameplay or power-loss qualification"], "expected_processes": 23}
    locked = False
    pins = {}
    try:
        started = last_notice = time.monotonic()
        while not locked:
            if not helper.shared.LOCK.exists() and not helper.running():
                try:
                    with helper.shared.LOCK.open("x", encoding="utf-8") as stream:
                        stream.write(str(output))
                    locked = True
                    break
                except FileExistsError:
                    pass
            require(time.monotonic() - started < args.wait_lane, "Shared engine occupied; no child started")
            if time.monotonic() - last_notice > 25:
                print("WAIT shared engine; no child started", flush=True); last_notice = time.monotonic()
            time.sleep(1)
        engine = helper.shared.resolve_godot(None)
        workers = output / "workers"; workers.mkdir()
        for name in ("bootstrap.gd", "worker.gd", "run_io.py"):
            source = HERE / name
            pins[str(source)] = helper.sha(source)
            helper.copy_checked(source, workers / name, pins[str(source)])
            pins[str(workers / name)] = pins[str(source)]
        for source in (protocol_source, HERE / "README.md", HERE.parents[1] / "source_manifest.json", Path(helper.common.__file__), Path(helper.identity.__file__), Path(helper.shared.__file__), Path(helper.__file__), ROOT / "tools/godot_debug_wire.py", ROOT / "tools/run_workstation_baseline.py", engine,
                       *(base / name for name in ("preparation.json", "root_source.json", "generation.json", "candidate_manifest.json"))):
            pins[str(source)] = helper.sha(source)
        receipt.update(engine_sha256=helper.sha(engine), project=str(project),
                       content_version="source-v1:" + generation["identity"]["source_sha256"])
        expected_identity = {"content_version": receipt["content_version"],
                             "engine_sha256": receipt["engine_sha256"], "source_mode": True}
        pids = set()
        for mode in MODES:
            helper.suite_verify_pins(pins)
            nonce = uuid.uuid4().hex
            profile = Path(ROOT.anchor) / "CodexQA/campspio" / nonce[:12]
            helper.identity.no_links(profile); profile.mkdir(parents=True, exist_ok=False)
            base_env = helper.common.private_environment(profile)
            stage = output / mode
            print("RUN native I/O " + mode, flush=True)
            row = run_stage(engine, project, workers, profile, base_env, nonce, mode, stage, points, args.timeout)
            require(row["pid"] not in pids, "Independent stage PID reused")
            actual = helper.read(stage / "prepared.json") if is_crash(mode) else row["report"]
            require(actual.get("identity") == expected_identity and actual.get("pid") == row["pid"]
                    and actual.get("nonce") == nonce and actual.get("profile") == str(profile)
                    and actual.get("mode") == mode, "Actual process/candidate/engine identity mismatch")
            pin_stage(stage, pins)
            pids.add(row["pid"]); receipt["stages"].append(row)
            if is_crash(mode):
                prepared = stage / "prepared.json"
                pins[str(prepared)] = helper.sha(prepared)
                if mode in TRIPLE:
                    second = output / (mode + "_recover_claim_crash")
                    row = run_stage(engine, project, workers, profile, base_env, nonce, "recover_claim_crash", second, points, args.timeout, prepared)
                    require(row["pid"] not in pids, "Recrashed recovery needs an independent PID")
                    second_prepared = helper.read(second / "prepared.json")
                    require(second_prepared.get("identity") == expected_identity
                            and second_prepared.get("pid") == row["pid"]
                            and second_prepared.get("nonce") == nonce and second_prepared.get("profile") == str(profile)
                            and second_prepared.get("origin_writer_pid") == actual["pid"]
                            and second_prepared.get("predecessor_pid") == actual["pid"], "Second crash actual identity mismatch")
                    pin_stage(second, pins)
                    pids.add(row["pid"]); receipt["stages"].append(row)
                    helper.save(output / ("checkpoint_%02d.json" % len(receipt["stages"])), receipt)
                    prepared = second / "prepared.json"
                    pins[str(prepared)] = helper.sha(prepared)
                row = run_stage(engine, project, workers, profile, base_env, nonce, "recover", output / (mode + "_recover"), points, args.timeout, prepared)
                require(row["pid"] not in pids, "Recovery requires an independent new PID")
                require(row["report"].get("identity") == expected_identity, "Recovery candidate/engine identity mismatch")
                pin_stage(output / (mode + "_recover"), pins)
                pids.add(row["pid"]); receipt["stages"].append(row)
            helper.save(output / ("checkpoint_%02d.json" % len(receipt["stages"])), receipt)
        require(len(receipt["stages"]) == 23, "All twenty-three declared processes required")
        receipt["all_stages_passed"] = True
    except BaseException as exc:
        receipt["error"] = repr(exc)
    finally:
        try:
            helper.assert_runtime_current(base)
            helper.identity.verify_generated(project, generation)
            helper.suite_verify_pins(pins)
            receipt["final_identity_passed"] = True
        except BaseException as exc:
            receipt.update(final_identity_passed=False, final_identity_error=repr(exc))
        receipt["lock_ownership_confirmed"] = locked and helper.shared.LOCK.exists() and helper.shared.LOCK.read_text(encoding="utf-8") == str(output)
        receipt["complete"] = bool(receipt.get("all_stages_passed") and receipt.get("final_identity_passed")
                                   and receipt["lock_ownership_confirmed"] and not helper.running() and "error" not in receipt)
        if receipt["lock_ownership_confirmed"] and not helper.running():
            helper.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not helper.shared.LOCK.exists()
        receipt["pinned_files"] = pins
        helper.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "error": receipt.get("error")}, ensure_ascii=False))
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
