"""Owned two-process delayed-acquire interleaving; default is read-only preflight.

A uses the real Ledger. B uses real Store plus Receipt transactions to isolate
the Store stale-CAS path. --expect defects runs only the old first-retry defect;
a successful reproduction is never a production or concurrency qualification.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("unique_protocol_io_helpers", HERE / "run_io.py")
io = importlib.util.module_from_spec(spec)
spec.loader.exec_module(io)
helper, ROOT = io.helper, io.ROOT
require = io.require
POINTS = {
    "A": ('if DirAccess.make_dir_absolute(directory.path_join("writing")) != OK: return bad("WRITER_BUSY")', "acquire"),
    "B": ('_checkpoint("release_marker_published")', "release"),
}


def points_for(project):
    source = project / "scripts/steam_receipt_store.gd"
    lines = source.read_text(encoding="utf-8-sig").splitlines()
    result = {}
    for role, (statement, function) in POINTS.items():
        matches = [i + 1 for i, line in enumerate(lines) if line.strip() == statement]
        require(len(matches) == 1, "Unique delayed-acquire source point required: " + role)
        result[role] = {"source": "res://scripts/steam_receipt_store.gd", "line": matches[0],
                        "function": function, "statement": statement, "source_sha256": helper.sha(source)}
    return result


class Pair:
    def __init__(self, engine, project, workers, profile, nonce, case, expected, output, timeout):
        self.engine, self.project, self.workers, self.profile = engine, project, workers, profile
        self.nonce, self.case, self.expected, self.output = nonce, case, expected, output
        self.timeout = timeout
        self.children = {}
        self.env = helper.common.private_environment(profile)
        self.next_foreign_check = 0.0
        self.trace = []

    def own_active_pids(self):
        return {c["child"].pid for c in self.children.values() if c["child"].poll() is None}

    def foreign_check(self):
        foreign = io.engines() - self.own_active_pids()
        require(not foreign, "Foreign engine present; never terminate it: " + str(sorted(foreign)))

    def launch(self, role, previous=None):
        self.foreign_check()
        folder = self.output / role
        folder.mkdir()
        env = dict(self.env)
        for key in list(env):
            if key.startswith(("DA_", "SP_", "IO_", "MR_", "CR_", "LR_", "HG_", "CH_", "CC_", "RG_")):
                env.pop(key)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", DA_PROFILE=str(self.profile), DA_PROJECT=str(self.project),
                   DA_WORKERS=str(self.workers), DA_WORKER_SHA256=helper.sha(self.workers / "delayed_worker.gd"),
                   DA_NONCE=self.nonce, DA_MODE=role, DA_CASE=self.case, DA_EXPECT=self.expected, DA_OUTPUT=str(folder))
        if previous:
            env.update(DA_PREVIOUS=str(previous), DA_PREVIOUS_SHA256=helper.sha(previous))
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
        command = [str(self.engine), "--path", str(self.project), "--headless", "--remote-debug",
                   "tcp://127.0.0.1:" + str(listener.getsockname()[1]), "--script", str(self.workers / "delayed_bootstrap.gd")]
        stream = (folder / "native.log").open("wb")
        c = {"role": role, "folder": folder, "stream": stream, "listener": listener, "connection": None,
             "thread": None, "pending": None, "paused": False, "gate_index": 0,
             "row": {"mode": role, "command": command, "stops": [], "gates": []}}
        self.children[role] = c
        try:
            child = subprocess.Popen(command, cwd=self.project, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            c["child"] = child; c["row"]["pid"] = child.pid
            connection, _ = listener.accept()
            c["connection"] = connection; connection.settimeout(.05)
            c["peer"] = io.DebugConnection(connection)
        finally:
            listener.close(); c["listener"] = None
        self.trace.append({"event": "launched", "role": role, "pid": c["child"].pid})

    def pump(self):
        if time.monotonic() >= self.next_foreign_check:
            self.foreign_check(); self.next_foreign_check = time.monotonic() + 1
        for c in self.children.values():
            if c["child"].poll() is not None or c.get("eof"):
                continue
            try:
                message, packet = c["peer"].receive()
            except socket.timeout:
                continue
            except EOFError:
                c["eof"] = True
                continue
            name, thread, data = message
            if name == "set_pid":
                require(data == [c["child"].pid], "Debugger PID mismatch")
                c["thread"] = thread
            elif name == "debug_enter":
                require(c["pending"] is not None and data == [True, "Breakpoint", True, thread],
                        "Unexpected debugger/error stop: " + c["role"])
                c["peer"].command("get_stack_dump", thread)
            elif name == "stack_dump":
                frames = io.stack_frames(data)
                point = c["pending"]
                require(point is not None and frames[0] == {k: point[k] for k in ("source", "line", "function")},
                        "Actual delayed source/stack mismatch")
                c["paused"] = True
                c["row"]["stops"].append({"point": point, "frames": frames,
                                               "packet_sha256": io.hashlib.sha256(packet).hexdigest()})

    def wait(self, predicate, label):
        deadline = time.monotonic() + self.timeout
        while not predicate():
            require(time.monotonic() < deadline, "Bounded interleaving timeout: " + label)
            self.pump()

    def gate(self, role, kind):
        c = self.children[role]
        path = c["folder"] / ("request_%02d.json" % c["gate_index"])
        def ready():
            value = io.read_if_closed(path)
            if value is not None and c["thread"] is not None:
                return True
            require(c["child"].poll() is None, "Worker exited before gate: " + role + "/" + kind)
            return False
        self.wait(ready, role + "/" + kind)
        request = helper.read(path)
        require(request.get("schema") == "handoff_delayed_gate_v1" and request.get("pid") == c["child"].pid
                and request.get("nonce") == self.nonce and request.get("index") == c["gate_index"]
                and request.get("mode") == role and request.get("case") == self.case
                and request.get("kind") == kind and request.get("owner") == io.OWNER, "Gate scope/order mismatch")
        directory = io.owned(request["directory"], self.profile)
        require(directory.parts[-4:] == ("steam_receipts", "v1", "5088120", io.OWNER), "Fixed private ledger required")
        c["directory"] = directory
        c["row"]["gates"].append(request)
        self.trace.append({"event": "gate", "role": role, "kind": kind, "inventory": io.snapshot(directory)})
        return request

    def ack(self, role):
        c = self.children[role]
        io.publish_ack(c["folder"] / ("ack_%02d.json" % c["gate_index"]),
                       {"nonce": self.nonce, "pid": c["child"].pid, "index": c["gate_index"]})
        c["gate_index"] += 1

    def arm(self, role, point):
        c = self.children[role]
        require(c["pending"] is None and not c["paused"], "One owned breakpoint per process")
        c["pending"] = dict(point)
        c["peer"].command("breakpoint", c["thread"], [point["source"], point["line"], True])

    def stopped(self, role):
        c = self.children[role]
        self.wait(lambda: c["paused"] or c["child"].poll() is not None, role + " source stop")
        require(c["paused"] and c["child"].poll() is None, "Owned process missed source stop")

    def resume(self, role):
        c = self.children[role]; point = c["pending"]
        require(c["paused"] and point is not None, "Only an observed owned stop may resume")
        c["peer"].command("breakpoint", c["thread"], [point["source"], point["line"], False])
        c["pending"] = None; c["paused"] = False
        c["peer"].command("continue", c["thread"])
        self.trace.append({"event": "resumed", "role": role})

    def close(self):
        # Popen objects, never process-name termination or foreign PID killing.
        for c in self.children.values():
            child = c.get("child")
            if child is not None and child.poll() is None:
                child.terminate(); child.wait(timeout=20); c["row"]["aborted_owned_child"] = True
            if c["connection"] is not None:
                c["connection"].close()
            if c["listener"] is not None:
                c["listener"].close()
            c["stream"].close()
            c["row"]["exit_code"] = child.returncode if child is not None else None
            c["row"]["log_sha256"] = helper.sha(c["folder"] / "native.log")
            if c.get("directory") is not None:
                c["row"]["final_inventory"] = io.snapshot(c["directory"])
            helper.save(c["folder"] / "controller.json", c["row"])


def execute_case(engine, project, workers, profile, nonce, case, expected, output, timeout, points, identity):
    pair = Pair(engine, project, workers, profile, nonce, case, expected, output, timeout)
    result = {"case": case, "expected": expected, "complete": False, "reports": [], "profile": str(profile), "nonce": nonce}
    try:
        pair.launch("A")
        pair.gate("A", "a_apply"); pair.arm("A", points["A"]); pair.ack("A"); pair.stopped("A")
        original = output / "A/prepared.json"
        initial = helper.read(original)
        require(initial.get("pid") == pair.children["A"]["child"].pid and initial.get("identity") == identity,
                "Actual A predecessor identity required")
        result["prepared_sha256"] = helper.sha(original)
        pair.launch("B", original)
        pair.gate("B", "b_begin"); pair.arm("B", points["B"]); pair.ack("B"); pair.stopped("B")
        pair.resume("A"); pair.gate("A", "a_retry")
        a = pair.children["A"]
        owner = helper.read(a["directory"] / "writing/owner.json")
        require(owner.get("pid") == str(a["child"].pid) and owner.get("owner") == io.OWNER,
                "Delayed A must own the actual fixed writing lock")
        if case == "retry_under_barrier":
            pair.ack("A"); pair.gate("A", "a_final_retry")
        pair.resume("B"); pair.gate("B", "b_done")
        pair.ack("A"); pair.gate("A", "a_verified")
        # B independently reads after A has attempted stale-lock cleanup.
        pair.ack("B")
        pair.wait(lambda: pair.children["B"]["child"].poll() is not None, "B independent verification while A is alive")
        pair.ack("A")
        pair.wait(lambda: not pair.own_active_pids(), "both owned workers terminal")
        require(helper.sha(original) == result["prepared_sha256"], "Original A predecessor changed")
        pids = set()
        for role, c in pair.children.items():
            path = c["folder"] / "report.json"
            report = helper.read(path)
            require(report.get("schema") == "handoff_delayed_io_v1" and report.get("mode") == role
                    and report.get("case") == case and report.get("expected") == expected
                    and report.get("pid") == c["child"].pid and report["pid"] not in pids
                    and report.get("nonce") == nonce and report.get("profile") == str(profile)
                    and report.get("identity") == identity and report.get("production_qualified") is False,
                    "Native concurrent report scope/identity mismatch")
            pids.add(report["pid"])
            passed = report.get("passed") is True and not report.get("failures") and c["child"].returncode == 0
            result["reports"].append({"role": role, "path": str(path), "sha256": helper.sha(path),
                                      "passed": passed, "checks": len(report.get("checks", [])),
                                      "failures": report.get("failures", []), "pid": report["pid"]})
        result["complete"] = len(pids) == 2 and all(row["passed"] for row in result["reports"])
    except BaseException as error:
        result["error"] = repr(error)
    finally:
        pair.close()
        for c in pair.children.values():
            log = (c["folder"] / "native.log").read_text(encoding="utf-8", errors="replace")
            if io.re.search(r"SCRIPT ERROR:|Parse Error:|Compile Error:", log):
                result["complete"] = False
                result["error"] = "Script failures are not interleaving evidence: " + c["role"]
        result["trace"] = pair.trace
        helper.save(output / "case_receipt.json", result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--expect", choices=("fixed", "defects"), default="fixed")
    parser.add_argument("--historical-freeze", action="store_true")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--wait-lane", type=int, default=1800)
    args = parser.parse_args()
    require(60 <= args.timeout <= 600 and 0 <= args.wait_lane <= 86400, "Bounded limits required")
    base = args.base_run.resolve()
    require(base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"), "Existing local freeze required")
    helper.identity.no_links(base)
    project = helper.assert_runtime_current(base)
    generation = helper.read(base / "generation.json")
    helper.identity.verify_generated(project, generation)
    points = points_for(project)
    current = HERE.parents[1] / "scripts/steam_receipt_store.gd"
    same = helper.sha(current) == helper.sha(project / "scripts/steam_receipt_store.gd")
    require(same or args.historical_freeze, "Current Store differs; explicit --historical-freeze required")
    cases = ("first_after_clear", "retry_under_barrier") if args.expect == "fixed" else ("first_after_clear",)
    if not args.execute:
        print(json.dumps({"source_preflight": True, "native_started": False, "points": points,
                          "current_candidate_matches": same, "cases": cases, "expected": args.expect}, indent=2))
        return
    output = ROOT / ".godot/campaign_store_delayed_io_20261026" / helper.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "campaign_store_delayed_io_runner_v1", "complete": False, "base_run": str(base),
               "expected": args.expect, "cases": [], "points": points, "current_candidate_matches": same,
               "historical_freeze": args.historical_freeze, "production_qualified": False,
               "two_ledger_concurrency_qualified": False, "os_input": False, "published": False}
    pins, locked = {}, False
    try:
        started = notice = time.monotonic()
        while not locked:
            if not helper.shared.LOCK.exists() and not io.engines():
                try:
                    with helper.shared.LOCK.open("x", encoding="utf-8") as f: f.write(str(output))
                    locked = True
                    break
                except FileExistsError:
                    pass
            require(time.monotonic() - started < args.wait_lane, "Shared engine occupied; no child started")
            if time.monotonic() - notice > 25:
                print("WAIT shared engine; no child started", flush=True); notice = time.monotonic()
            time.sleep(1)
        engine = helper.shared.resolve_godot(None)
        identity = {"content_version": "source-v1:" + generation["identity"]["source_sha256"],
                    "engine_sha256": helper.sha(engine), "source_mode": True}
        receipt["identity"] = identity
        workers = output / "workers"; workers.mkdir()
        for name in ("delayed_bootstrap.gd", "delayed_worker.gd"):
            source = HERE / name; digest = helper.sha(source)
            helper.copy_checked(source, workers / name, digest)
            pins[str(source)] = pins[str(workers / name)] = digest
        for path in (Path(__file__), HERE / "run_io.py", HERE / "README_delayed.md", current, engine,
                     Path(helper.__file__), Path(helper.common.__file__), Path(helper.identity.__file__), Path(helper.shared.__file__),
                     ROOT / "tools/godot_debug_wire.py", ROOT / "tools/run_workstation_baseline.py",
                     *(base / name for name in ("preparation.json", "root_source.json", "generation.json", "candidate_manifest.json"))):
            pins[str(path)] = helper.sha(path)
        for case in cases:
            helper.suite_verify_pins(pins)
            folder = output / case; folder.mkdir()
            nonce = uuid.uuid4().hex
            profile = Path(ROOT.anchor) / "CodexQA/campspdelay" / nonce[:12]
            helper.identity.no_links(profile); profile.mkdir(parents=True, exist_ok=False)
            row = execute_case(engine, project, workers, profile, nonce, case, args.expect, folder, args.timeout, points, identity)
            receipt["cases"].append(row)
            for path in folder.rglob("*"):
                if path.is_file(): pins[str(path)] = helper.sha(path)
            helper.save(output / ("checkpoint_%02d.json" % len(receipt["cases"])), receipt)
        receipt["expectation_passed"] = len(receipt["cases"]) == len(cases) and all(row["complete"] for row in receipt["cases"])
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        try:
            helper.assert_runtime_current(base); helper.identity.verify_generated(project, generation)
            helper.suite_verify_pins(pins); receipt["final_identity_passed"] = True
        except BaseException as error:
            receipt.update(final_identity_passed=False, final_identity_error=repr(error))
        own_lock = locked and helper.shared.LOCK.exists() and helper.shared.LOCK.read_text(encoding="utf-8") == str(output)
        idle = not io.engines()
        receipt["complete"] = bool(receipt.get("expectation_passed") and receipt.get("final_identity_passed") and own_lock and idle and "error" not in receipt)
        receipt["defect_reproduced"] = receipt["complete"] and args.expect == "defects"
        receipt["slice_passed"] = receipt["complete"] and args.expect == "fixed"
        if own_lock and idle: helper.shared.LOCK.unlink()
        receipt["lock_ownership_confirmed"] = own_lock
        receipt["lock_released"] = locked and not helper.shared.LOCK.exists()
        receipt["pinned_files"] = pins
        helper.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "expected": args.expect,
                      "slice_passed": receipt["slice_passed"], "error": receipt.get("error")}, ensure_ascii=False), flush=True)
    if not receipt["complete"]: raise SystemExit(1)


if __name__ == "__main__":
    main()
