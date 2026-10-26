"""Two real Ledgers: a live owner's lock must never be recovered by its sibling.

Default is read-only preflight. --execute is the only engine-starting entry.
--expect defects records the pinned f6ef baseline bug, never a production pass.
--expect fixed requires explicit WRITER_ALIVE and an unchanged live lock.
"""
from __future__ import annotations

import argparse
import ctypes as ct
from ctypes import wintypes as wt
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
QA = HERE.parent
DEPENDENCY = QA / "store_protocol_candidate/tests/io/run_delayed_acquire.py"
spec = importlib.util.spec_from_file_location("live_owner_delayed_helpers", DEPENDENCY)
delayed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delayed)
io, helper, ROOT = delayed.io, delayed.helper, delayed.ROOT
require = io.require
BASELINE = "f6ef8398f297af3a9be64ca376b9f2a940951d9b93b0512808e3f4275afc32e4"
BASE_STORE = "11bf6cae5968baa6c740c3c6be1fc954376048cbbe9a81a77b6cf4588518f9f1"
BASE_SNAPSHOT = "581e638b8f0ce7cb24d5533b03ee94b99732c5cffcbf373b1a5a69a1618d8251"


def source_point(project):
    source = project / "scripts/steam_receipt_store.gd"
    statement = '_checkpoint("lock_acquired")'
    lines = source.read_text(encoding="utf-8-sig").splitlines()
    matches = [n + 1 for n, line in enumerate(lines) if line.strip() == statement]
    require(len(matches) == 1, "One actual Steam acquire lock_acquired statement required")
    preceding = [line for line in lines[:matches[0]] if line.startswith("func ")]
    require(preceding and preceding[-1].startswith("func acquire("), "Checkpoint must belong to acquire")
    return {"source": "res://scripts/steam_receipt_store.gd", "line": matches[0], "function": "acquire",
            "statement": statement, "source_sha256": helper.sha(source)}


def preflight(base, expected):
    require(os.name == "nt", "This harness requires the Windows process-handle oracle")
    base = io.owned(base, ROOT / ".godot/campaign_progress_recovery_20261026")
    project = io.owned(helper.assert_runtime_current(base), base)
    generation = helper.read(base / "generation.json")
    helper.identity.verify_generated(project, generation)
    manifest = helper.read(base / "candidate_manifest.json")
    preparation = helper.read(base / "preparation.json")
    manifest_sha = helper.sha(base / "candidate_manifest.json")
    require(preparation.get("candidate_manifest_sha256") == manifest_sha, "Preparation must bind candidate manifest")
    rows = manifest["files"]
    require(isinstance(rows, list) and len(rows) >= 20, "A complete frozen handoff candidate is required")
    names = set()
    pins = {}
    for row in rows:
        name = row["path"]
        require(isinstance(name, str) and name.startswith("scripts/") and name not in names, "Unique candidate script paths required")
        names.add(name)
        path = io.owned(project / name, project)
        require(helper.sha(io.fs_path(path)) == row["candidate_sha256"], "Frozen candidate bytes changed: " + name)
        pins[str(path)] = row["candidate_sha256"]
    require({"scripts/steam_run_ledger.gd", "scripts/steam_receipt_store.gd", "scripts/steam_run_receipt.gd"} <= names,
            "The real Ledger, Store and Receipt must be in the candidate manifest")
    if expected == "defects":
        require(generation["identity"]["source_sha256"] == BASELINE, "Defects mode is bound to the f6ef baseline")
        require(helper.sha(project / "scripts/steam_receipt_store.gd") == BASE_STORE
                and helper.sha(project / "scripts/run_snapshot_store.gd") == BASE_SNAPSHOT,
                "Defects mode requires exact known Store/base bytes")
    engine = helper.shared.resolve_godot(None)
    helper.identity.no_links(engine)
    identity = {"content_version": "source-v1:" + generation["identity"]["source_sha256"],
                "engine_sha256": helper.sha(engine), "source_mode": True}
    for path in (Path(__file__), HERE / "bootstrap.gd", HERE / "worker.gd", HERE / "README.md", DEPENDENCY,
                 Path(io.__file__), Path(helper.__file__), Path(helper.common.__file__),
                 Path(helper.identity.__file__), Path(helper.shared.__file__), engine,
                 ROOT / "tools/godot_debug_wire.py", ROOT / "tools/run_workstation_baseline.py",
                 ROOT / "tools/run_campaign_level_state_qa.py", project / "scripts/run_snapshot_store.gd",
                 *(base / name for name in ("generation.json", "preparation.json", "root_source.json", "candidate_manifest.json"))):
        helper.identity.no_links(path)
        pins[str(path)] = helper.sha(path)
    return {"base": base, "project": project, "generation": generation, "engine": engine,
            "identity": identity, "manifest_sha256": manifest_sha, "point": source_point(project), "pins": pins}


class LiveProcess:
    """A retained OS handle proves the same owned process never exited between samples."""
    def __init__(self, child, engine):
        self.child, self.engine = child, Path(engine).resolve()
        self.handle = None
        self.samples = []
        self.api = ct.WinDLL("kernel32", use_last_error=True)
        self.api.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
        self.api.OpenProcess.restype = wt.HANDLE
        self.api.GetProcessId.argtypes = [wt.HANDLE]
        self.api.GetProcessId.restype = wt.DWORD
        self.api.GetExitCodeProcess.argtypes = [wt.HANDLE, ct.POINTER(wt.DWORD)]
        self.api.GetExitCodeProcess.restype = wt.BOOL
        self.api.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
        self.api.WaitForSingleObject.restype = wt.DWORD
        self.api.GetProcessTimes.argtypes = [wt.HANDLE] + [ct.POINTER(wt.FILETIME)] * 4
        self.api.GetProcessTimes.restype = wt.BOOL
        self.api.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ct.POINTER(wt.DWORD)]
        self.api.QueryFullProcessImageNameW.restype = wt.BOOL
        self.api.CloseHandle.argtypes = [wt.HANDLE]
        self.api.CloseHandle.restype = wt.BOOL
        require(child.poll() is None, "Cannot bind a terminal child as alive")
        self.handle = self.api.OpenProcess(0x100000 | 0x1000, False, child.pid)  # SYNCHRONIZE | QUERY_LIMITED_INFORMATION
        require(bool(self.handle), "OpenProcess failed for own child: " + str(ct.get_last_error()))
        try:
            length = wt.DWORD(32768)
            buffer = ct.create_unicode_buffer(length.value)
            require(self.api.QueryFullProcessImageNameW(self.handle, 0, buffer, ct.byref(length)), "Query owned image failed")
            require(io.plain_path(buffer.value).resolve() == self.engine, "Owned process image does not match pinned engine")
            self.image = buffer.value
            self.creation = self.created_at()
            self.observe("bound_handle")
        except BaseException:
            self.close()
            raise

    def created_at(self):
        creation, exited, kernel, user = wt.FILETIME(), wt.FILETIME(), wt.FILETIME(), wt.FILETIME()
        require(self.api.GetProcessTimes(self.handle, ct.byref(creation), ct.byref(exited), ct.byref(kernel), ct.byref(user)),
                "GetProcessTimes failed for owned handle")
        return (creation.dwHighDateTime << 32) | creation.dwLowDateTime

    def observe(self, label):
        require(self.handle and self.child.poll() is None, "A Popen reports terminal while live proof is required")
        wait_result = self.api.WaitForSingleObject(self.handle, 0)
        code = wt.DWORD()
        query_ok = bool(self.api.GetExitCodeProcess(self.handle, ct.byref(code)))
        require(self.api.GetProcessId(self.handle) == self.child.pid and self.created_at() == self.creation,
                "Retained A handle PID/incarnation changed")
        require(wait_result == 258 and query_ok and code.value == 259, "A is not confirmed alive by retained Win32 handle")
        require(len(self.samples) < 20000, "Bounded live-sample budget exceeded")
        self.samples.append({"label": label, "monotonic_ns": time.monotonic_ns(), "pid": self.child.pid,
                             "wait_result": wait_result, "exit_code": code.value, "popen_returncode": None})

    def receipt(self):
        return {"schema": "owned_process_liveness_v1", "pid": self.child.pid, "image": self.image,
                "creation_filetime": str(self.creation), "retained_handle": True, "samples": self.samples,
                "method": "Popen.poll + retained OpenProcess handle + WaitForSingleObject + GetExitCodeProcess + GetProcessTimes",
                "foreign_godot_pid_query_used": False}

    def close(self):
        if self.handle:
            handle, self.handle = self.handle, None
            require(self.api.CloseHandle(handle), "Close owned process proof handle failed")


class ControlledPair(delayed.Pair):
    def __init__(self, *args):
        super().__init__(*args)
        self.live = None
        self.require_a_alive = False

    def own_active_pids(self):
        return {c["child"].pid for c in self.children.values() if c.get("child") is not None and c["child"].poll() is None}

    def launch(self, role, previous=None):
        self.foreign_check()
        folder = self.output / role
        folder.mkdir()
        env = dict(self.env)
        for key in list(env):
            if key.startswith(("LO_", "DA_", "SP_", "IO_", "LT_", "MR_", "CR_", "LR_", "HG_", "CH_", "CC_", "RG_")):
                env.pop(key)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", LO_PROFILE=str(self.profile), LO_PROJECT=str(self.project),
                   LO_WORKERS=str(self.workers), LO_WORKER_SHA256=helper.sha(self.workers / "worker.gd"),
                   LO_NONCE=self.nonce, LO_MODE=role, LO_EXPECT=self.expected, LO_OUTPUT=str(folder))
        if previous:
            env.update(LO_PREVIOUS=str(previous), LO_PREVIOUS_SHA256=helper.sha(previous))
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
        command = [str(self.engine), "--path", str(self.project), "--headless", "--remote-debug",
                   "tcp://127.0.0.1:" + str(listener.getsockname()[1]), "--script", str(self.workers / "bootstrap.gd")]
        stream = (folder / "native.log").open("wb")
        c = {"role": role, "folder": folder, "stream": stream, "listener": listener, "connection": None,
             "thread": None, "pending": None, "paused": False, "gate_index": 0,
             "row": {"mode": role, "command": command, "stops": [], "gates": []}}
        self.children[role] = c
        child = subprocess.Popen(command, cwd=self.project, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        c["child"] = child; c["row"]["pid"] = child.pid
        # Short socket polling also checks A while B connects; no unobserved 30s accept wait.
        listener.settimeout(.1)
        deadline = time.monotonic() + 30
        while True:
            if self.require_a_alive: self.live.observe("B_debugger_connect")
            require(child.poll() is None and time.monotonic() < deadline, "Worker failed to connect debugger")
            try:
                connection, _ = listener.accept()
                break
            except socket.timeout:
                continue
        c["connection"] = connection; connection.settimeout(.05)
        c["peer"] = io.DebugConnection(connection)
        listener.close(); c["listener"] = None
        self.trace.append({"event": "launched", "role": role, "pid": child.pid})

    def pump(self):
        if self.require_a_alive: self.live.observe("pump")
        super().pump()

    def gate(self, role, kind):
        c = self.children[role]
        path = c["folder"] / ("request_%02d.json" % c["gate_index"])
        def ready():
            value = io.read_if_closed(path)
            if value is not None and c["thread"] is not None: return True
            require(c["child"].poll() is None, "Worker exited before gate " + role + "/" + kind)
            return False
        self.wait(ready, role + "/" + kind)
        request = helper.read(path)
        require(request.get("schema") == "live_owner_gate_v1" and request.get("pid") == c["child"].pid
                and request.get("nonce") == self.nonce and request.get("index") == c["gate_index"]
                and request.get("mode") == role and request.get("case") == "live_owner"
                and request.get("kind") == kind and request.get("owner") == io.OWNER, "Exact gate scope/order required")
        directory = io.owned(request["directory"], self.profile)
        require(directory.parts[-4:] == ("steam_receipts", "v1", "5088120", io.OWNER), "Fixed private receipt root required")
        c["directory"] = directory; c["row"]["gates"].append(request)
        self.trace.append({"event": "gate", "role": role, "kind": kind, "inventory": io.snapshot(directory)})
        return request


def execute_case(config, workers, profile, nonce, output, expected, timeout):
    pair = ControlledPair(config["engine"], config["project"], workers, profile, nonce,
                          "live_owner", expected, output, timeout)
    result = {"schema": "live_owner_case_v1", "complete": False, "expected": expected,
              "profile": str(profile), "nonce": nonce, "reports": [], "production_qualified": False}
    try:
        pair.launch("A")
        pair.gate("A", "a_apply")
        prepared = output / "A/prepared.json"
        initial = helper.read(prepared)
        a = pair.children["A"]
        require(initial.get("schema") == "live_owner_prepared_v1" and initial.get("pid") == a["child"].pid
                and initial.get("identity") == config["identity"] and initial.get("nonce") == nonce
                and initial.get("expected") == expected and initial.get("profile") == str(profile)
                and initial.get("owner") == io.OWNER and io.owned(initial["directory"], profile) == a["directory"],
                "Exact A prepared scope required")
        prepared_sha = helper.sha(prepared)
        result["prepared_sha256"] = prepared_sha
        pair.arm("A", config["point"]); pair.ack("A"); pair.stopped("A")
        pair.live = LiveProcess(a["child"], config["engine"])
        pair.require_a_alive = True
        before = io.snapshot(a["directory"])
        owner_path = io.fs_path(a["directory"] / "writing/owner.json")
        owner_bytes = owner_path.read_bytes()
        owner = json.loads(owner_bytes)
        require(owner.get("pid") == str(a["child"].pid) and owner.get("owner") == io.OWNER
                and owner.get("version") == "1" and set(owner) == {"version", "owner", "pid", "token"}
                and io.re.fullmatch(r"[0-9a-f]{32}", owner.get("token", "")), "Actual complete A owner required")
        require(before["directories"] == [".", "writing"] and "receipt.pending" not in before["files"]
                and set(before["files"]) == {"writing/owner.json"} | {name for name in before["files"] if io.re.fullmatch(r"record_[0-9]{10}\.json", name)},
                "A source stop must have complete owner, records and no pending/barrier")
        result.update(before=before, owner_raw=owner_bytes.decode("utf-8"), owner_sha256=io.hashlib.sha256(owner_bytes).hexdigest())
        io.copy_account_tree(a["directory"], output / "before_b_account")
        pair.live.observe("before_B_launch")
        pair.launch("B", prepared)
        pair.gate("B", "b_open")
        require(pair.children["B"]["directory"] == a["directory"] and a["paused"], "Same account with A still at exact debugger stop")
        require(io.snapshot(a["directory"]) == before, "B pre-open gate must not mutate A files")
        pair.live.observe("before_B_open"); pair.ack("B")
        pair.gate("B", "b_observed")
        pair.live.observe("after_B_open")
        require(a["paused"], "A must remain paused throughout B automatic recovery")
        observed_path = output / "B/b_observed.json"
        observed = helper.read(observed_path)
        require(observed.get("schema") == "live_owner_b_observed_v1" and observed.get("pid") == pair.children["B"]["child"].pid
                and observed.get("nonce") == nonce and observed.get("expected") == expected, "Bound B observed evidence")
        after = io.snapshot(a["directory"])
        result.update(after_b=after, b_open_result=observed["result"], b_observed_sha256=helper.sha(observed_path))
        io.copy_account_tree(a["directory"], output / "after_b_account")
        if expected == "defects":
            wanted = dict(before, files={k: v for k, v in before["files"].items() if k != "writing/owner.json"}, directories=["."])
            require(observed["result"].get("ok") is True and after == wanted,
                    "Defect requires B to actually delete only A live owner/writing while records remain identical")
        else:
            require(observed["result"].get("ok") is False and observed["result"].get("code") == "WRITER_ALIVE"
                    and after == before, "Fixed requires explicit WRITER_ALIVE and zero filesystem mutation; UNKNOWN is not a pass")
        helper.save(output / "live_owner_intervention.json", {"schema": "live_owner_intervention_v1", "expected": expected,
                    "before": before, "after": after, "b_result": observed["result"], "a_live": pair.live.receipt(),
                    "actual_breakpoint": a["row"]["stops"], "a_paused": a["paused"]})
        pair.live.observe("before_A_resume"); pair.resume("A")
        pair.gate("A", "a_verified")
        pair.live.observe("A_outcome_verified")
        final_inventory = io.snapshot(a["directory"])
        pair.ack("B")
        pair.wait(lambda: pair.children["B"]["child"].poll() is not None, "B independent readback while A remains alive")
        pair.live.observe("B_finished_A_still_alive")
        require(io.snapshot(a["directory"]) == final_inventory, "B final verification may not change A durable files")
        pair.require_a_alive = False
        pair.ack("A")
        pair.wait(lambda: not pair.own_active_pids(), "both exact children terminal")
        require(helper.sha(prepared) == prepared_sha, "A prepared bytes changed")
        pids = set()
        for role, c in pair.children.items():
            path = c["folder"] / "report.json"
            report = helper.read(path)
            require(report.get("schema") == "live_owner_worker_v1" and report.get("mode") == role
                    and report.get("expected") == expected and report.get("nonce") == nonce
                    and report.get("pid") == c["child"].pid and report["pid"] not in pids
                    and report.get("identity") == config["identity"] and report.get("profile") == str(profile)
                    and report.get("owner") == io.OWNER and report.get("production_root") == "user://steam_receipts/v1"
                    and report.get("workers") == str(workers) and report.get("production_qualified") is False,
                    "Actual worker report identity/PID scope mismatch")
            pids.add(report["pid"])
            passed = (report.get("passed") is True and report.get("stage_completed") is True and not report.get("failures")
                      and bool(report.get("checks")) and all(row.get("passed") is True for row in report["checks"]))
            require(passed and c["child"].returncode == 0, "Worker checks and actual exit 0 are both mandatory")
            result["reports"].append({"role": role, "path": str(path), "sha256": helper.sha(path), "pid": report["pid"],
                                      "checks": len(report["checks"]), "exit_code": c["child"].returncode, "passed": passed})
        result["complete"] = len(pids) == 2
    except BaseException as error:
        result.update(error=repr(error), traceback=io.traceback.format_exc(), complete=False)
        for c in pair.children.values():
            c["row"].update(primary_case_error=result["error"], primary_case_traceback=result["traceback"])
    finally:
        pair.require_a_alive = False
        if pair.live is not None:
            result["a_liveness"] = pair.live.receipt()
            io.post_step(result, "close owned A proof handle", pair.live.close)
        okay, errors = io.post_step(result, "close owned pair", pair.close)
        if okay and errors:
            result.setdefault("post_errors", []).extend(errors); result["complete"] = False
        for c in pair.children.values():
            def check_log():
                log = io.fs_path(c["folder"] / "native.log").read_text(encoding="utf-8", errors="replace")
                require(not helper.common.ERROR_LINES.search(log) and not io.re.search(r"Compile Error:", log),
                        "Engine/script errors do not qualify as live-owner evidence: " + c["role"])
            io.post_step(result, "scan native log " + c["role"], check_log)
        result["trace"] = pair.trace
        io.persist_result(output / "case_receipt.json", result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--expect", choices=("defects", "fixed"), default="defects")
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    require(30 <= args.timeout <= 110 and 0 <= args.wait_lane <= 86400, "Bounded timeouts required")
    config = preflight(args.base_run, args.expect)
    if not args.execute:
        print(json.dumps({"source_preflight": True, "engine_started": False, "lane_acquired": False,
                          "expected": args.expect, "identity": config["identity"], "point": config["point"],
                          "candidate_manifest_sha256": config["manifest_sha256"], "production_qualified": False}, indent=2))
        return
    output = ROOT / ".godot/campaign_live_owner_io_20261026" / helper.stamp()
    helper.identity.no_links(output); output.mkdir(parents=True, exist_ok=False)
    pins, locked = dict(config["pins"]), False
    receipt = {"schema": "live_owner_runner_v1", "complete": False, "expected": args.expect, "base_run": str(config["base"]),
               "identity": config["identity"], "point": config["point"], "candidate_manifest_sha256": config["manifest_sha256"],
               "production_qualified": False, "sdk_qualified": False, "two_ledger_general_concurrency_qualified": False,
               "defect_reproduced": False, "slice_passed": False, "diagnostic_only": args.expect == "defects"}
    try:
        started = notice = time.monotonic()
        while not locked:
            if not helper.shared.LOCK.exists() and not io.engines():
                try:
                    with helper.shared.LOCK.open("x", encoding="utf-8") as handle: handle.write(str(output))
                    locked = True
                    break
                except FileExistsError:
                    pass
            require(time.monotonic() - started < args.wait_lane, "Shared engine occupied; no child started")
            if time.monotonic() - notice >= 25:
                print("WAIT shared engine; no child started", flush=True); notice = time.monotonic()
            time.sleep(1)
        helper.suite_verify_pins(pins)
        require(preflight(config["base"], args.expect) == config, "Preflight changed while waiting for shared lane")
        require(not io.engines(), "Engine appeared before own children")
        workers = output / "workers"; workers.mkdir()
        for name in ("bootstrap.gd", "worker.gd"):
            digest = pins[str(HERE / name)]
            helper.copy_checked(HERE / name, workers / name, digest)
            pins[str(workers / name)] = digest
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/liveowner" / nonce[:12]
        helper.identity.no_links(profile); profile.mkdir(parents=True, exist_ok=False)
        receipt.update(profile=str(profile), nonce=nonce)
        case_output = output / "live_owner"; case_output.mkdir()
        receipt["case"] = execute_case(config, workers, profile, nonce, case_output, args.expect, args.timeout)
        receipt["expectation_passed"] = receipt["case"]["complete"]
    except BaseException as error:
        receipt.update(error=repr(error), traceback=io.traceback.format_exc())
    finally:
        def verify_identity():
            helper.assert_runtime_current(config["base"])
            helper.identity.verify_generated(config["project"], config["generation"])
            helper.suite_verify_pins(pins)
        receipt["final_identity_passed"], _ = io.post_step(receipt, "final source/engine/helper pins", verify_identity)
        def lane_state():
            return (locked and helper.shared.LOCK.is_file() and helper.shared.LOCK.read_text(encoding="utf-8") == str(output), not io.engines())
        okay, lane = io.post_step(receipt, "final shared lane state", lane_state)
        own_lock, idle = lane if okay else (False, False)
        receipt["lock_ownership_confirmed"] = own_lock
        if own_lock and idle: io.post_step(receipt, "release own shared lock", helper.shared.LOCK.unlink)
        okay, released = io.post_step(receipt, "confirm shared lock release", lambda: locked and not helper.shared.LOCK.exists())
        receipt["lock_released"] = bool(okay and released)
        receipt["complete"] = bool(receipt.get("expectation_passed") and receipt["final_identity_passed"] and own_lock and idle
                                   and receipt["lock_released"] and "error" not in receipt and not receipt.get("post_errors"))
        receipt["defect_reproduced"] = receipt["complete"] and args.expect == "defects"
        receipt["slice_passed"] = receipt["complete"] and args.expect == "fixed"
        receipt["pinned_files"] = pins
        io.persist_result(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "expected": args.expect,
                      "defect_reproduced": receipt["defect_reproduced"], "slice_passed": receipt["slice_passed"],
                      "error": receipt.get("error")}, ensure_ascii=False), flush=True)
    if not receipt["complete"]: raise SystemExit(1)


if __name__ == "__main__":
    main()
