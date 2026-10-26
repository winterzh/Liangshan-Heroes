"""New readset freeze; original four-process classic SOURCE BRANCH diagnostic.

Initial visible buttons use the private QA gate. Reader clears only that flag
after synchronous request admission, before the original deferred _restore.
This is never public-entry/release/SDK qualification. --execute owns the lane.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


candidate = load("classic_readset_binding", HERE.parents[1] / "prepare_readset.py")
p, h, ROOT, require = candidate.p, candidate.h, candidate.ROOT, candidate.require
QA = HERE.parents[2]
ORIGINAL = QA / "continue_binding_candidate/tests/classic_recovery"
CLASSIC = QA / "handoff_candidate/tests/classic"
io = load("classic_recovery_debug_helpers", QA / "store_protocol_candidate/tests/io/run_io.py")
WORKERS = {"bootstrap.gd": ORIGINAL / "bootstrap.gd", "driver.gd": ORIGINAL / "driver.gd",
           "classic_base.gd": CLASSIC / "driver.gd", "policy.gd": CLASSIC / "policy.gd",
           "inflight.gd": CLASSIC / "inflight.gd"}
POINTS = {"pending": ("scripts/run_snapshot_store.gd", '_checkpoint("pending_verified")', "commit_locked"),
          "record": ("scripts/run_slot_store.gd", "var released := release()", "write_slot")}


def points(project):
    found = {}
    for kind, (relative, statement, function) in POINTS.items():
        lines = (project / relative).read_text(encoding="utf-8-sig").splitlines()
        matches = [i + 1 for i, line in enumerate(lines) if line.strip() == statement]
        require(len(matches) == 1, "Unique original transaction statement required: " + kind)
        functions = [re.match(r"^func (\w+)\(", line) for line in lines[:matches[0]]]
        require([match.group(1) for match in functions if match][-1] == function, "Containing function differs")
        found[kind] = {"source": "res://" + relative, "line": matches[0], "function": function,
                       "statement": statement, "sha256": h.sha(project / relative)}
    return found


def preflight(base, expected):
    require(expected == "fixed", "This adapter only accepts the new readset candidate")
    state = candidate.prepared_state(base)
    provenance = h.read(ORIGINAL / "sources.json")
    require(provenance.get("schema") == "classic_recovery_branch_sources_v1", "Unknown sources")
    for row in provenance["files"]:
        relative = Path(row["path"])
        require(not relative.is_absolute() and ".." not in relative.parts, "Repository-relative provenance only")
        p.pin(ROOT / relative, state["pins"], row["sha256"])
    for path in [ORIGINAL / "sources.json", Path(__file__), HERE / "README.md", *WORKERS.values()]:
        p.pin(path, state["pins"])
    state["points"] = points(state["project"])
    p.verify_pins(state["pins"])
    return state


def gate_row(value, child, env):
    require(value.get("pid") == child.pid and value.get("nonce") == env["SC_NONCE"]
            and value.get("process_nonce") == env["SC_PROCESS_NONCE"]
            and value.get("profile") == env["SC_PROFILE"] and value.get("content_version") == env["SC_CONTENT"]
            and value.get("engine_sha256") == env["SC_ENGINE"], "Actual producer process/profile/source mismatch")


def capture_registration_observed(prepared):
    registration = prepared.get("capture_registration", {})
    before = registration.get("before_button", {})
    require(before.get("observer_registered") is True and before.get("flow_callback_absent") is True
            and before.get("capture_calls") == 0 and registration.get("frame") == before.get("frame")
            and registration.get("capture_calls") == 0
            and all(registration.get(key) is True for key in ("saving", "source_is_battle", "session_absent", "requested")),
            "Original capture must be registered in the button's synchronous request stack before emission")
    connections = registration.get("connections")
    require(isinstance(connections, list) and registration.get("connection_count") == len(connections)
            and all(isinstance(row, dict) and row.get("index") == index for index, row in enumerate(connections)),
            "Complete capture connection observation required")
    require(registration.get("one_shot_flag") == 4, "Actual Godot CONNECT_ONE_SHOT flag required")
    for role, method, owner in (("is_flow", "_capture_ready", "flow_object_id"),
                                ("is_observer", "capture_witness", "observer_object_id")):
        matching = [row for row in connections if row.get(role) is True]
        require(len(matching) == 1, "Each original capture callback must be registered exactly once")
        row = matching[0]
        require(row.get("valid") is True and row.get("method") == method
                and isinstance(row.get("flags"), int) and row["flags"] & 4
                and isinstance(row.get("object_id"), str) and row["object_id"].isdigit()
                and int(row["object_id"]) > 0 and row["object_id"] == registration.get(owner),
                "Actual original callback and one-shot registration required")
    # Array order is retained, not assumed to be invocation order. The HELD
    # observer/session evidence plus the real Flow -> Session -> Slot stack
    # establish the subsequent original production callback.


def pin_tree(folder, pins):
    for parent, directories, names in io.os.walk(p.fs(folder), followlinks=False, onerror=io.raise_walk_error):
        for name in directories + names:
            h.identity.no_links(Path(parent) / name)
        for name in names:
            p.pin(io.plain_path(Path(parent) / name), pins)


def writer(state, workers, profile, env, stage, kind, timeout, steps):
    stage.mkdir()
    env = dict(env, SC_STAGE="writer", SC_OUTPUT=str(stage))
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
    command = [str(state["engine"]), "--path", str(state["project"]), "--rendering-method", "gl_compatibility",
               "--resolution", "1280x720", "--position", "30000,30000", "--remote-debug",
               "tcp://127.0.0.1:%d" % listener.getsockname()[1], "--script", str(workers / "bootstrap.gd")]
    row = {"case": kind + "_writer", "complete": False, "process_terminal": False,
           "command": command, "nonce": env["SC_NONCE"], "process_nonce": env["SC_PROCESS_NONCE"],
           "initial_private_gate_used": True, "public_entry_qualified": False, "production_method_overrides": 0}
    steps.append(row)
    child = connection = None
    point = state["points"][kind]
    armed, observed = False, False
    directory = None
    try:
        require(not h.running(), "Engine appeared before owned writer launch")
        with (stage / "writer.log").open("wb") as log:
            child = subprocess.Popen(command, cwd=state["project"], env=env, stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            row["pid"] = child.pid
            connection, _ = listener.accept()
            connection.settimeout(.15)
            peer = io.DebugConnection(connection)
            thread_id = None
            deadline, notice = time.monotonic() + timeout, time.monotonic()
            while child.poll() is None:
                require(time.monotonic() < deadline, "Writer deadline expired")
                require(not (io.engines() - {child.pid}), "Foreign engine in owned lane")
                if time.monotonic() - notice > 25:
                    print("RUNNING native writer " + kind, flush=True); notice = time.monotonic()
                request = io.read_if_closed(stage / "request.json")
                if request is not None and thread_id is not None and not armed:
                    gate_row(request, child, env)
                    require(request.get("schema") == "classic_recovery_gate_v1" and request.get("case") == kind, "Wrong gate request")
                    directory = io.owned(request["directory"], profile)
                    require(directory.parts[-4:] == ("continue", "v1", "5088120", "1"), "Actual classic slot directory required")
                    peer.command("breakpoint", thread_id, [point["source"], point["line"], True])
                    io.publish_ack(stage / "ack.json", {"pid": child.pid, "nonce": env["SC_NONCE"], "process_nonce": env["SC_PROCESS_NONCE"]})
                    armed = True
                try:
                    message, packet = peer.receive()
                except socket.timeout:
                    continue
                except EOFError:
                    break
                name, thread, data = message
                if name == "set_pid":
                    require(data == [child.pid], "Debugger PID differs from original Popen")
                    thread_id = thread
                elif name == "debug_enter":
                    require(armed and data == [True, "Breakpoint", True, thread], "Unexpected debug/error stop")
                    peer.command("get_stack_dump", thread)
                elif name == "stack_dump":
                    frames = io.stack_frames(data)
                    require(frames[0] == {key: point[key] for key in ("source", "line", "function")}, "Wrong native boundary")
                    slot_frame = any(f["source"] == "res://scripts/run_slot_store.gd" and f["function"] == "write_slot" for f in frames)
                    if not slot_frame:
                        require(kind == "pending" and any(f["source"] == "res://scripts/run_local_lifecycle.gd" for f in frames), "Unrecognized non-slot commit")
                        row.setdefault("ignored_local_lifecycle_stops", []).append(frames)
                        peer.command("continue", thread)
                        continue
                    require(any(f["source"] == "res://scripts/continue_flow.gd" and f["function"] == "_capture_ready" for f in frames)
                            and any(f["source"] == "res://scripts/run_world_session.gd" and f["function"] == "save_held" for f in frames), "Must be actual Flow SaveAndExit stack")
                    prepared = h.read(stage / "prepared.json")
                    gate_row(prepared, child, env)
                    require(prepared.get("passed") is True and prepared.get("schema") == "classic_recovery_prepared_v1"
                            and all(c.get("passed") is True for c in prepared["checks"]), "Actual HELD observer failed")
                    capture_registration_observed(prepared)
                    observer = prepared.get("capture_observer", {})
                    require(observer.get("calls") == 1 and all(observer.get(key) is True for key in
                            ("held", "outside_physics", "flow_session_absent", "observer_disconnected"))
                            and isinstance(observer.get("flow_callback_connected"), bool),
                            "Original production capture order was not observed")
                    target = directory / ("receipt.pending" if kind == "pending" else "record_0000000001.json")
                    require(p.fs(target).stat().st_size <= 134217728, "Bounded slot envelope required")
                    raw = p.fs(target).read_bytes()
                    envelope = json.loads(raw)
                    payload = envelope["payload"].encode("utf-8")
                    require(envelope["magic"] == "LH_CLASSIC_CONTINUE_SLOT" and envelope["owner"] == "1"
                            and envelope["revision"] == "1" and envelope["previous_sha256"] == "0" * 64
                            and int(envelope["payload_bytes"]) == len(payload)
                            and envelope["payload_sha256"] == hashlib.sha256(payload).hexdigest(), "Complete original envelope/chain required")
                    packet_doc = json.loads(payload)
                    require(packet_doc["schema"] == "classic_continue_slot_v3" and packet_doc["context"] == {"mode":"defense","level_id":"","waves":30}
                            and packet_doc["generation"] == 1 and packet_doc["binding"]["kind"] == "uncredited", "Actual normal classic slot required")
                    lock_owner = h.read(p.fs(directory / "writing/owner.json"))
                    require(lock_owner.get("pid") == str(child.pid), "Original process must own the live writer lock")
                    before = io.snapshot(directory.parents[1])
                    row.update(point=point, frames=frames, stack_packet_sha256=hashlib.sha256(packet).hexdigest(),
                               slot_sha256=hashlib.sha256(raw).hexdigest(), slot_target=target.name,
                               slot_binding=packet_doc["binding"], head_revision=1, previous_sha256=envelope["previous_sha256"],
                               original_owner=lock_owner, before_termination=before)
                    child.kill(); child.wait(timeout=20)
                    require(child.returncode is not None and child.returncode != 0, "Original stopped writer must terminate nonzero")
                    row["after_termination"] = io.snapshot(directory.parents[1])
                    require(before == row["after_termination"], "Original bytes changed while stopped/terminated")
                    io.copy_account_tree(directory.parents[1], stage / "terminated_continue_copy")
                    require(io.snapshot(stage / "terminated_continue_copy") == before, "Original evidence copy mismatch")
                    observed = True
                    break
            child.wait(timeout=20)
        text = (stage / "writer.log").read_text(encoding="utf-8", errors="replace")
        require(not re.search(r"SCRIPT ERROR:|Parse Error:|Compile Error:|ERROR:", text), "Engine errors are not fault evidence")
        require(observed, "Exact original Flow breakpoint was not observed")
        row["complete"] = True
    finally:
        if connection is not None: connection.close()
        listener.close()
        try:
            if child is not None and child.poll() is None:
                child.kill(); child.wait(timeout=20)
        finally:
            row["process_terminal"] = child is not None and child.poll() is not None
            row["exit_code"] = None if child is None else child.returncode
            if (stage / "writer.log").exists(): row["log_sha256"] = h.sha(stage / "writer.log")
            h.save(stage / "receipt.json", row)
    return row


def execute(args):
    output = ROOT / ".godot/classic_readset_branch_20261027" / h.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema":"classic_recovery_branch_run_v1","complete":False,"expected":args.expect,"steps":[],"cases":[],
               "initial_private_gate_used":True,"source_restore_branch_only":True,"public_entry_qualified":False,
               "original_release_qualified":False,"sdk_qualified":False,"os_input":False}
    locked, state, attempted = False, None, 0
    pins = {}
    try:
        start = time.monotonic()
        while not locked:
            if not h.shared.LOCK.exists() and not h.running():
                try:
                    with h.shared.LOCK.open("x",encoding="utf-8") as stream: stream.write(str(output))
                    locked = True
                except FileExistsError: pass
            if not locked:
                require(time.monotonic() - start < args.wait_lane,"Shared lane occupied; no engine started")
                time.sleep(1)
        state = preflight(args.base_run,args.expect); pins = state["pins"]
        receipt.update(base_run=str(state["run_base"]),project=str(state["project"]),content_version=state["content_version"],
                       engine_sha256=state["engine_sha256"],points=state["points"])
        for path, digest in list(pins.items()):
            source = Path(path)
            if source == state["engine"]: continue
            relative = source.relative_to(ROOT) if source.is_relative_to(ROOT) else Path("external")/digest/source.name
            target = output/"runner_inputs"/relative
            p.copy(source,target,digest); p.pin(target,pins,digest)
        workers = output / "workers"; workers.mkdir()
        for name, source in WORKERS.items():
            p.copy(source,workers/name,pins[str(source)]); p.pin(workers/name,pins,pins[str(source)])
        bindings = {name:h.sha(workers/name) for name in WORKERS if name != "bootstrap.gd"}
        h.save(workers/"bindings.json",bindings); p.pin(workers/"bindings.json",pins)
        for kind in ("pending","record"):
            nonce = uuid.uuid4().hex
            profile = Path(ROOT.anchor)/"CodexQA/cslot"/nonce[:12]
            h.identity.no_links(profile); profile.mkdir(parents=True,exist_ok=False)
            env = h.common.private_environment(profile)
            for key in list(env):
                if key.startswith(("SC_","CB_","CC_","CT_","MR_","HG_","LR_","LHM_","LSH_CONTINUE_FLOW_")): env.pop(key)
            env.update(STEAM_DISABLED="1",CAMPAIGN_QA="",LSH_CONTINUE_FLOW_QA="1",LSH_CONTINUE_FLOW_PROFILE=str(profile),
                       SC_WORKERS=str(workers),SC_BINDINGS=str(workers/"bindings.json"),SC_PROFILE=str(profile),
                       SC_PROJECT=str(state["project"]),SC_RUN=str(output),
                       SC_NONCE=nonce,SC_CASE=kind,SC_EXPECT=args.expect,SC_CONTENT=state["content_version"],SC_ENGINE=state["engine_sha256"])
            case = output/kind; case.mkdir()
            env["SC_PROCESS_NONCE"] = uuid.uuid4().hex
            p.verify_pins(pins); attempted += 1
            original = writer(state,workers,profile,env,case/"writer",kind,args.timeout,receipt["steps"])
            pin_tree(case/"writer",pins)
            prepared_path = case/"writer/prepared.json"
            p.pin(prepared_path,pins)
            stage = case/"reader"; stage.mkdir()
            env.update(SC_STAGE="reader",SC_OUTPUT=str(stage),SC_PROCESS_NONCE=uuid.uuid4().hex,
                       SC_PREVIOUS=str(prepared_path),SC_PREVIOUS_SHA=pins[str(prepared_path)],SC_SLOT_SHA=original["slot_sha256"])
            p.verify_pins(pins); attempted += 1
            h.common.process_step(state["engine"],state["project"],env,stage,"reader",
                                  ["--resolution","1280x720","--position","30000,30000","--script",str(workers/"bootstrap.gd")],
                                  args.timeout,"gl_compatibility",h.running,receipt["steps"])
            report = h.read(stage/"report.json"); step = receipt["steps"][-1]
            require(report.get("schema") == "classic_recovery_branch_v1" and report.get("passed") is True
                    and report.get("expected") == args.expect and report.get("case") == kind and report.get("stage") == "reader"
                    and report.get("pid") == step["pid"] and report.get("pid") != original["pid"]
                    and report.get("nonce") == nonce and report.get("process_nonce") == env["SC_PROCESS_NONCE"]
                    and report.get("profile") == str(profile) and report.get("content_version") == state["content_version"]
                    and report.get("engine_sha256") == state["engine_sha256"]
                    and report.get("outcome") == ("baseline_preread_reproduced" if args.expect == "baseline" else "fixed_branch_restored")
                    and all(c.get("passed") is True for c in report["checks"]), "Reader process/expected/outcome mismatch")
            require(report.get("initial_private_gate_used") is True and report.get("source_restore_branch_only") is True
                    and all(report.get(k) is False for k in ("public_entry_qualified","original_release_qualified","sdk_qualified","os_input")),"Qualification boundary changed")
            require(report["gate"]["before_frame"] == report["gate"]["after_frame"]
                    and report["gate"]["initial_private_gate_used"] is True
                    and report["gate"]["private_gate_after_clear"] is False
                    and report["gate"]["request"] == report["gate"]["after_clear"]
                    and all(report["gate"]["after_clear"].get(key) is True for key in ("restoring","source_is_menu","session_absent"))
                    and report["gate"]["after_clear"].get("operation_received") is False,"Original deferred branch timing not demonstrated")
            for name in ("writer/receipt.json","writer/prepared.json","writer/writer.log","reader/report.json","reader/reader.log"):
                p.pin(case/name,pins)
            receipt["cases"].append({"case":kind,"complete":True,"profile":str(profile),"writer_pid":original["pid"],
                                     "reader_pid":report["pid"],"report":str(stage/"report.json"),
                                     "report_sha256":pins[str(stage/"report.json")],"reader_checks":len(report["checks"]),
                                     "slot_sha256":original["slot_sha256"]})
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        try:
            if state is not None:
                h.assert_runtime_current(state["run_base"])
                h.identity.verify_generated(state["project"],state["generation"])
                p.verify_pins(pins); receipt["final_identity_passed"] = True
        except BaseException as error: receipt["final_identity_error"] = repr(error)
        terminal = len(receipt["steps"]) == attempted and all(type(row.get("pid")) is int and type(row.get("exit_code")) is int for row in receipt["steps"])
        receipt.update(attempted_processes=attempted,terminal_processes=sum(type(row.get("exit_code")) is int for row in receipt["steps"]),lock_released=False)
        try:
            owned = locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text(encoding="utf-8") == str(output)
            receipt["lock_ownership_confirmed"] = owned
            if owned and terminal and not h.running():
                h.shared.LOCK.unlink(); receipt["lock_released"] = not h.shared.LOCK.exists()
        except BaseException as error: receipt["lock_release_error"] = repr(error)
        receipt["complete"] = bool(len(receipt["cases"]) == 2 and attempted == 4 and terminal and receipt.get("final_identity_passed") and receipt["lock_released"] and "error" not in receipt)
        receipt["pinned_files"] = pins
        h.save(output/"receipt.json",receipt)
    print(json.dumps({"run":str(output),"complete":receipt["complete"],"expected":args.expect,
                      "actual_cases":len(receipt["cases"]),"actual_terminal_processes":receipt["terminal_processes"],
                      "error":receipt.get("error"),"public_entry_qualified":False},ensure_ascii=False),flush=True)
    if not receipt["complete"]: raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run",type=Path,required=True)
    parser.add_argument("--expect",choices=("fixed",),default="fixed")
    parser.add_argument("--execute",action="store_true")
    parser.add_argument("--timeout",type=int,default=180)
    parser.add_argument("--wait-lane",type=int,default=0)
    args = parser.parse_args()
    require(60 <= args.timeout <= 900 and args.wait_lane >= 0,"Invalid time bound")
    if args.execute: execute(args)
    else:
        state = preflight(args.base_run,args.expect)
        print(json.dumps({"preflight":True,"expected":args.expect,"project":str(state["project"]),
                          "points":state["points"],"pins":len(state["pins"]),"planned_processes":4,
                          "engine_started":False,"public_entry_qualified":False},ensure_ascii=False))


if __name__ == "__main__": main()
