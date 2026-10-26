"""Three owned processes for exact-Slot readset evidence; default is read-only.

--execute uses only new private profiles. The historical failure is read-only;
its full business tree is cloned for Store recovery, never Flow qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
import traceback
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare = load("readset_component_prepare", HERE.parents[1] / "prepare_readset.py")
p, h, ROOT, require = prepare.p, prepare.h, prepare.ROOT, prepare.require
QA = HERE.parents[2]
timing = load("readset_original_timing", QA / "continue_binding_candidate/tests/classic_recovery_timing/run_timing.py")
io = timing.io
WORKERS = {name: HERE / name for name in ("bootstrap.gd", "driver.gd", "fixtures.gd")}
CASES = ("aba", "file_content", "pending_changed", "file_rename", "directory_set", "owner_replace",
         "scope_expiry", "forged_plan", "record", "pending", "derived_fallback", "cfg_fallback")
NEGATIVE = set(CASES) - {"forged_plan", "record", "pending", "derived_fallback"}
SPECS = {
    "pending": ("commit_locked", '_checkpoint("pending_verified")'),
    "aba_before": ("_inspect_base_recovery", "var current := _chain()"),
    "aba_after": ("_inspect_base_recovery", "if not current.ok: return current"),
    "readback": ("_inspect_base_recovery", "var readback := _base_recovery_readback(plan)"),
    "expiry": ("_inspect_base_recovery", 'var observed := _confirmed_dead([int(metadata.pid)], _base_recovery_binding(plan, lock.raw), "inspect")'),
    "fallback": ("_base_recovery_readback", "var head := _chain()"),
}
PROVIDER_FIELDS = {"code", "creation_filetime", "handle_opened", "nonce", "provider_pid",
                   "query_utc_filetime", "schema", "state", "target_pid", "wait_result", "win32_error"}


def points(project):
    path = project / "scripts/run_snapshot_store.gd"
    lines = io.fs_path(path).read_text(encoding="utf-8-sig").splitlines()
    result = {}
    for key, (function, statement) in SPECS.items():
        current, found = None, []
        for number, line in enumerate(lines, 1):
            match = re.match(r"^func (\w+)\(", line)
            if match:
                current = match.group(1)
            if current == function and line.strip() == statement:
                found.append(number)
        require(len(found) == 1, "Unique actual source statement required: " + key)
        result[key] = {"source": "res://scripts/run_snapshot_store.gd", "line": found[0],
                       "function": function, "statement": statement, "source_sha256": h.sha(io.fs_path(path))}
    return result


def preflight(base):
    state = prepare.prepared_state(base)
    old = timing.preflight(ROOT / prepare.BASE_RUN, timing.FAILURE)
    for path, digest in old["pins"].items():
        require(path not in state["pins"] or state["pins"][path] == digest, "Conflicting predecessor source pin")
        state["pins"][path] = digest
    for path in [Path(__file__), HERE / "README.md", *WORKERS.values()]:
        p.pin(path, state["pins"])
    # The original three business files stay outside runner_inputs. Only their
    # source-bound SHA/inventory is retained; the separate clone is explicit.
    seed = old["original"] / "5088120/1/record_0000000001.json"
    require(h.sha(io.fs_path(seed)) == old["snapshot"]["files"]["5088120/1/record_0000000001.json"]["sha256"],
            "Historical full record seed changed")
    state.update(original=old["original"], original_profile=old["original_profile"],
                 original_inventory=old["snapshot"], old_writer_pid=old["writer_pid"],
                 userdata_name=old["userdata_name"], seed=seed, failure=old["failure"], points=points(state["project"]))
    p.verify_pins(state["pins"])
    return state


def save(path, value):
    h.save(io.fs_path(path), value)


def bound(value, child, env):
    require(type(value.get("pid")) is int and value["pid"] == child.pid
            and value.get("nonce") == env["RS_NONCE"]
            and value.get("process_nonce") == env["RS_PROCESS_NONCE"]
            and value.get("profile") == env["RS_PROFILE"]
            and value.get("content_version") == env["RS_CONTENT"]
            and value.get("engine_sha256") == env["RS_ENGINE"], "PID/profile/nonce/source binding differs")


def checks_pass(value):
    checks = value.get("checks")
    require(isinstance(checks, list) and checks and all(row.get("passed") is True for row in checks)
            and value.get("passed") is True, "Worker assertions failed")


def pin_tree(folder, pins):
    for parent, directories, names in os.walk(io.fs_path(folder), followlinks=False, onerror=io.raise_walk_error):
        for name in directories + names:
            h.identity.no_links(Path(parent) / name)
        for name in names:
            p.pin(io.plain_path(Path(parent) / name), pins)


def variant(prepared, key, producer_stage):
    row = prepared["variants"][key] if key != "pending" else prepared["pending_target"]
    path = io.owned(row["path"] if key != "pending" else row["raw_path"], producer_stage)
    raw = io.fs_path(path).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == row["sha256"], "Prepared fixture SHA differs")
    return raw


def replace_closed(target, raw, profile, expected_sha):
    target = io.owned(target, profile)
    require(h.sha(io.fs_path(target)) == expected_sha, "Fault target changed before closed replacement")
    temporary = io.owned(target.with_name("." + target.name + "." + uuid.uuid4().hex + ".replacement"), profile)
    with io.fs_path(temporary).open("xb") as stream:
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())
    require(h.sha(io.fs_path(temporary)) == hashlib.sha256(raw).hexdigest(), "Closed fault bytes differ")
    os.replace(io.fs_path(temporary), io.fs_path(target))
    require(h.sha(io.fs_path(target)) == hashlib.sha256(raw).hexdigest(), "Published fault bytes differ")


def validate_prepared(path, child, env, profile, stage):
    value = h.read(io.fs_path(path))
    bound(value, child, env); checks_pass(value)
    require(value.get("schema") == "readset_prepared_v1" and set(value["cases"]) == set(CASES)
            and value.get("synthetic") is True and value.get("world_mount_qualified") is False
            and value.get("flow_qualified") is False and value.get("source_seed_sha256") == env["RS_SEED_SHA"],
            "Prepared source/fixture contract differs")
    for key in ("a", "b", "h", "pending"):
        variant(value, key, stage)
    for name, case in value["cases"].items():
        directory = io.owned(case["directory"], profile)
        require(directory.name == "1" and directory.parent.name == "5088120", "Actual Slot/CFG scope required")
        if name == "cfg_fallback":
            raw_path = io.owned(case["raw_path"], stage)
            require(h.sha(io.fs_path(raw_path)) == case["record_sha256"], "Pinned CFG raw fixture differs")
            require(not io.fs_path(directory).exists(), "Invalid CFG journal must not precede normal reader startup")
            continue
        owner = h.read(io.fs_path(directory / "writing/owner.json"))
        require(owner.get("pid") == str(child.pid) and case.get("owner_pid") == child.pid,
                "Every prepared owner must belong to this original Popen")
        require(h.sha(io.fs_path(directory / "record_0000000001.json")) == case["b_sha256"]
                and h.sha(io.fs_path(directory / "record_0000000002.json")) == case["h_sha256"], "Actual B/H commits differ")
    return value


def provider_evidence(report, profile, target_pid, stage, pins):
    require(report.get("providers_terminal") is True and isinstance(report.get("providers"), dict),
            "Worker must confirm its own helper handles are terminal")
    rows = []
    for key, evidence in report["providers"].items():
        path = io.owned(evidence["raw_report_path"], profile)
        require(io.plain_path(key) == path and path.name == "result.json"
                and path.parent.parent.name == "v2" and path.parent.parent.parent.name == "process_liveness",
                "Actual isolated oracle report path required")
        raw_bytes = io.fs_path(path).read_bytes()
        require(0 < len(raw_bytes) <= 4096 and all(32 <= byte <= 126 for byte in raw_bytes), "Bounded ASCII provider bytes required")
        raw = raw_bytes.decode("ascii")
        value = json.loads(raw)
        require(set(value) == PROVIDER_FIELDS and type(value["handle_opened"]) is bool
                and all(type(value[key]) is str for key in PROVIDER_FIELDS - {"handle_opened"}), "Provider field/type contract differs")
        require(raw == evidence["raw_report"] and hashlib.sha256(raw_bytes).hexdigest() == evidence["raw_report_sha256"]
                and value == evidence["evidence"] and value["schema"] == "windows_process_liveness_v1"
                and value["nonce"] == path.parent.name and re.fullmatch(r"[0-9a-f]{32}", value["nonce"])
                and value["provider_pid"] == str(evidence["provider_pid"])
                and type(evidence["provider_pid"]) is int and evidence["provider_pid"] > 0
                and type(evidence["own_child_exit_code"]) is int and evidence["own_child_exit_code"] == 0
                and evidence["own_child_running"] is False, "Actual provider raw/PID/nonce/own-child terminal evidence differs")
        # A late raw result is retained as data, not substituted for a successful
        # Store result. Every accepted positive/negative case is checked below.
        dead = value["target_pid"] == str(target_pid) and value["state"] == "dead" and ((value["code"] == "HANDLE_SIGNALED"
                and value["handle_opened"] is True and value["creation_filetime"] != ""
                and value["wait_result"] == "0" and value["win32_error"] == "0")
                or (value["code"] == "PID_ABSENT_87" and value["handle_opened"] is False
                    and value["creation_filetime"] == "" and value["wait_result"] == "not_queried"
                    and value["win32_error"] == "87"))
        alive_self = report["mode"] == "attack_reader" and value["target_pid"] == str(report["pid"]) \
            and value["state"] == "alive" and value["code"] == "HANDLE_NONSIGNALED" \
            and value["handle_opened"] is True and value["creation_filetime"] != "" \
            and value["wait_result"] == "258" and value["win32_error"] == "0"
        require(dead or alive_self, "UNKNOWN or unrelated alive target is not accepted evidence")
        digest = p.pin(path, pins, evidence["raw_report_sha256"])
        copy = stage / "providers" / path.parent.name / "result.json"
        p.copy(path, copy, digest); p.pin(copy, pins, digest)
        rows.append({"path": str(path), "sha256": digest, "provider_pid": evidence["provider_pid"],
                     "target_pid": int(value["target_pid"]), "nonce": value["nonce"], "state": value["state"], "code": value["code"]})
    return rows


def arm(peer, thread, point, enabled=True):
    peer.command("breakpoint", thread, [point["source"], point["line"], enabled])


def case_point(name):
    if name == "aba": return "aba_before"
    if name in {"file_content", "pending_changed", "file_rename", "directory_set", "owner_replace"}: return "readback"
    if name == "scope_expiry": return "expiry"
    if name == "derived_fallback": return "fallback"
    return None


def expected_after(case, before):
    result = json.loads(json.dumps(before))
    result["files"].pop("writing/owner.json")
    result["directories"].remove("writing")
    if case == "pending":
        result["files"]["record_0000000003.json"] = result["files"].pop("receipt.pending")
        result["files"].pop("record_0000000001.json")
    return result


def consume_case(active, child, env, stage, prepared, point_key, row):
    if active is None:
        return None
    result_path = stage / ("case_%02d.json" % active["index"])
    result = io.read_if_closed(io.fs_path(result_path))
    if result is None:
        return active
    bound(result, child, env); checks_pass(result)
    name = active["case"]
    require(result.get("schema") == "readset_case_v1" and result.get("index") == active["index"]
            and result.get("case") == name and result.get("synthetic") is True
            and result.get("flow_qualified") is False and result.get("world_mount_qualified") is False,
            "Case order/schema/qualification changed")
    require(point_key is None and result["before"] == active["before"], "Expected breakpoint or before inventory missing")
    actual = io.snapshot(active["directory"])
    require(actual == result["after"], "Worker after inventory differs from actual closed files")
    if name in NEGATIVE:
        code = {"aba": "RECOVERY_READSET_CHANGED", "scope_expiry": "PROCESS_LIVENESS_TIMEOUT",
                "cfg_fallback": "CFG_PREPARED_GENESIS_REQUIRED"}.get(name, "RECOVERY_CAS_CHANGED")
        require(result["result"].get("ok") is False and result["result"].get("code") == code,
                "Specific refusal required; an unrelated timeout never passes")
        require(actual == active.get("after_injection", active["before"]), "Rejected operation changed business data")
    elif name == "derived_fallback":
        require(result["result"].get("ok") is True and actual == active["before"], "Derived fallback must be read-only")
    else:
        digest = prepared["pending_target"]["sha256"] if name == "pending" else prepared["cases"][name]["h_sha256"]
        require(result["result"].get("ok") is True and result["result"].get("file_sha256") == digest
                and result["result"].get("revision") == (3 if name == "pending" else 2)
                and actual == expected_after(name, active["before"]), "Exact actual recovery/prune outcome differs")
    row["cases"].append({"case": name, "index": active["index"], "result": result["result"],
                         "before": result["before"], "after": actual, "report_sha256": h.sha(io.fs_path(result_path))})
    return None


def run_process(state, workers, profile, env, stage, timeout, steps, children, prepared=None, producer_stage=None):
    io.fs_path(stage).mkdir()
    env = dict(env, RS_OUTPUT=str(stage))
    mode = env["RS_MODE"]
    row = {"mode": mode, "complete": False, "process_terminal": False, "profile": str(profile),
           "nonce": env["RS_NONCE"], "process_nonce": env["RS_PROCESS_NONCE"], "cases": [], "debug_stops": [],
           "faults": [], "production_method_overrides": 0, "helpers_terminal_confirmed": False}
    steps.append(row)
    listener = connection = child = None
    primary = None
    active = None
    issued = 0
    point_key = None
    thread_id = None
    try:
        listener = socket.socket(); listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
        command = [str(state["engine"]), "--path", str(state["project"]), "--headless", "--remote-debug",
                   "tcp://127.0.0.1:%d" % listener.getsockname()[1], "--script", str(workers / "bootstrap.gd")]
        row["command"] = command
        require(not h.running(), "Foreign engine appeared before owned launch")
        with io.fs_path(stage / "native.log").open("xb") as log:
            child = subprocess.Popen(command, cwd=state["project"], env=env, stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            children.append(child)  # Retains the original producer process HANDLE until the reader is terminal.
            row["pid"] = child.pid
            connection, _ = listener.accept(); connection.settimeout(.10)
            listener.close(); listener = None
            peer = io.DebugConnection(connection)
            deadline, notice = time.monotonic() + timeout, time.monotonic()
            while child.poll() is None:
                require(time.monotonic() < deadline, "Owned process deadline expired")
                require(not (io.engines() - {child.pid}), "Foreign engine in the owned lane")
                if time.monotonic() - notice > 25:
                    print("RUNNING readset " + mode + " case " + str(issued), flush=True); notice = time.monotonic()
                if mode == "attack_reader" and active is not None:
                    active = consume_case(active, child, env, stage, prepared, point_key, row)
                request_name = "gate_request.json" if mode == "producer" else "request_%02d.json" % issued
                request = None if mode == "clone_record" else io.read_if_closed(io.fs_path(stage / request_name))
                if request is not None and thread_id is not None and active is None and (mode != "producer" or issued == 0):
                    bound(request, child, env)
                    require(request.get("schema") == "readset_gate_v1" and request.get("index") == issued
                            and active is None, "Gate order or prior case receipt incomplete")
                    if mode == "producer":
                        require(request.get("kind") == "producer_pending" and request.get("case") == "pending", "Wrong producer gate")
                        prepared = validate_prepared(stage / "prepared.json", child, env, profile, stage)
                        directory = io.owned(prepared["cases"]["pending"]["directory"], profile)
                        require(io.owned(request["directory"], profile) == directory, "Producer pending directory differs")
                        point_key = "pending"
                        active = {"index": 0, "case": "pending", "directory": directory}
                    else:
                        require(issued < len(CASES) and request.get("kind") == "attack_case"
                                and request.get("case") == CASES[issued], "Unexpected actual case")
                        name = CASES[issued]
                        directory = io.owned(prepared["cases"][name]["directory"], profile)
                        require(io.owned(request["directory"], profile) == directory, "Case directory differs from original prepared")
                        active = {"index": issued, "case": name, "directory": directory}
                        if name == "cfg_fallback":
                            cfg_owner = h.read(io.fs_path(directory / "writing/owner.json"))
                            require(cfg_owner.get("pid") == str(child.pid)
                                    and h.sha(io.fs_path(directory / "record_0000000001.json")) == prepared["cases"][name]["record_sha256"],
                                    "Post-startup CFG fixture must have the actual reader owner and pinned bytes")
                        if name == "aba":
                            replace_closed(directory / "record_0000000001.json", variant(prepared, "a", producer_stage),
                                           profile, prepared["cases"][name]["b_sha256"])
                            active["pre_gate_fixture"] = "A,H; individually valid records, inconsistent predecessor"
                        elif name == "pending_changed":
                            raw = variant(prepared, "pending", producer_stage)
                            target = io.owned(directory / "receipt.pending", profile)
                            with io.fs_path(target).open("xb") as stream:
                                stream.write(raw); stream.flush(); os.fsync(stream.fileno())
                            require(h.sha(io.fs_path(target)) == prepared["pending_target"]["sha256"], "Closed pending fixture differs")
                        active["before"] = io.snapshot(directory)
                        point_key = case_point(name)
                    save(stage / ("gate_%02d_bound.json" % issued), {**request, "original_popen_pid": child.pid,
                         "selected_point": state["points"].get(point_key), "host_case": active["case"],
                         "directory_inventory": io.snapshot(directory)})
                    if point_key is not None:
                        arm(peer, thread_id, state["points"][point_key])
                    ack_name = "gate_ack.json" if mode == "producer" else "ack_%02d.json" % issued
                    io.publish_ack(io.fs_path(stage / ack_name), {"pid": child.pid, "nonce": env["RS_NONCE"],
                                   "process_nonce": env["RS_PROCESS_NONCE"], "index": issued})
                    issued += 1
                try:
                    message, packet = peer.receive()
                except socket.timeout:
                    continue
                except EOFError:
                    break
                name, thread, data = message
                if name == "set_pid":
                    require(data == [child.pid], "Debugger PID must match original Popen")
                    thread_id = thread
                elif name == "debug_enter":
                    require(point_key is not None and active is not None and data == [True, "Breakpoint", True, thread],
                            "Unexpected debugger/error stop")
                    peer.command("get_stack_dump", thread)
                elif name == "stack_dump":
                    require(point_key is not None and active is not None, "Unrequested debug stack")
                    point = state["points"][point_key]
                    frames = io.stack_frames(data)
                    require(frames and frames[0] == {key: point[key] for key in ("source", "line", "function")}
                            and h.sha(io.fs_path(state["project"] / "scripts/run_snapshot_store.gd")) == point["source_sha256"],
                            "Actual top frame/source pin differs")
                    driver_function = "prepare_fixture" if mode == "producer" else "attack_reader"
                    require(any(frame["function"] == driver_function and frame["source"].replace("\\", "/") == (workers / "driver.gd").as_posix()
                                for frame in frames), "Original driver call stack missing")
                    stop = {"pid": child.pid, "nonce": env["RS_NONCE"], "process_nonce": env["RS_PROCESS_NONCE"],
                            "case": active["case"], "index": active["index"], "point": point,
                            "frames": frames, "stack_packet_sha256": hashlib.sha256(packet).hexdigest()}
                    row["debug_stops"].append(stop)
                    save(stage / ("stop_%02d_bound.json" % len(row["debug_stops"])), stop)
                    directory = active["directory"]
                    if mode == "producer":
                        require(h.sha(io.fs_path(directory / "receipt.pending")) == prepared["pending_target"]["sha256"],
                                "Actual closed pending differs from prepared generation3")
                        owner = h.read(io.fs_path(directory / "writing/owner.json"))
                        require(owner.get("pid") == str(child.pid), "Stopped producer must still own its actual lock")
                        ipc = io.owned(profile / "appdata/Godot/app_userdata" / state["userdata_name"] / "process_liveness/v2", profile)
                        ipc_inventory = io.snapshot(ipc)
                        require(not ipc_inventory["exists"] or (not ipc_inventory["files"] and ipc_inventory["directories"] == ["."]),
                                "Producer must not have launched a recovery oracle before planned termination")
                        row.update(producer_ipc_inventory=ipc_inventory, helpers_terminal_confirmed=True)
                        before = {case: io.snapshot(io.owned(item["directory"], profile)) for case, item in prepared["cases"].items()}
                        row.update(before_termination=before, original_owner=owner, prepared_sha256=h.sha(io.fs_path(stage / "prepared.json")))
                        child.kill(); child.wait(timeout=20)
                        require(type(child.returncode) is int and child.returncode != 0, "Planned original producer termination missing")
                        after = {case: io.snapshot(io.owned(item["directory"], profile)) for case, item in prepared["cases"].items()}
                        require(before == after, "Fixture bytes changed while producer was stopped/terminated")
                        row.update(after_termination=after, planned_termination=True, complete=True)
                        break
                    name = active["case"]
                    fault = {**stop, "before": io.snapshot(directory), "operation": point_key}
                    save(stage / ("fault_%02d_intent.json" % len(row["faults"])), fault)
                    if point_key == "aba_before":
                        replace_closed(directory / "record_0000000001.json", variant(prepared, "b", producer_stage), profile,
                                       prepared["variants"]["a"]["sha256"])
                    elif point_key == "aba_after":
                        replace_closed(directory / "record_0000000001.json", variant(prepared, "a", producer_stage), profile,
                                       prepared["variants"]["b"]["sha256"])
                        fault["full_B_H_chain_validation_claimed"] = False
                    elif name in {"file_content", "pending_changed"}:
                        target = directory / ("receipt.pending" if name == "pending_changed" else "record_0000000001.json")
                        replace_closed(target, variant(prepared, "a", producer_stage), profile, h.sha(io.fs_path(target)))
                    elif name == "file_rename":
                        target = io.owned(directory / "record_0000000009.json", profile)
                        require(not io.fs_path(target).exists(), "Rename attack must not overwrite an entry")
                        os.rename(io.fs_path(io.owned(directory / "record_0000000001.json", profile)), io.fs_path(target))
                    elif name == "directory_set":
                        io.fs_path(io.owned(directory / "recovering", profile)).mkdir(exist_ok=False)
                    elif name == "owner_replace":
                        target = io.owned(directory / "writing/owner.json", profile)
                        raw = io.fs_path(target).read_bytes(); owner = json.loads(raw)
                        token = owner["token"]
                        require(re.fullmatch(r"[0-9a-f]{32}", token) and owner["pid"] == str(prepared["pid"]), "Original owner identity changed")
                        replacement = ("1" if token[0] == "0" else "0") + token[1:]
                        needle = json.dumps(token).encode("ascii")
                        require(raw.count(needle) == 1, "Unique raw token expected")
                        changed = raw.replace(needle, json.dumps(replacement).encode("ascii"))
                        require(len(changed) == len(raw) and changed != raw, "Same-length raw owner mutation required")
                        replace_closed(target, changed, profile, hashlib.sha256(raw).hexdigest())
                    elif name == "scope_expiry":
                        began = time.monotonic(); time.sleep(3.2)
                        fault["real_sleep_ms"] = (time.monotonic() - began) * 1000
                        require(fault["real_sleep_ms"] >= 3200, "Actual original deadline must expire")
                    else:
                        require(name == "derived_fallback" and point_key == "fallback", "Unrecognized fault operation")
                        fault["fallback_chain_observed"] = True
                    fault["after"] = io.snapshot(directory)
                    row["faults"].append(fault)
                    save(stage / ("fault_%02d_applied.json" % (len(row["faults"]) - 1)), fault)
                    arm(peer, thread, point, False)
                    if point_key == "aba_before":
                        point_key = "aba_after"; arm(peer, thread, state["points"][point_key])
                    else:
                        active["after_injection"] = fault["after"]
                        point_key = None
                    peer.command("continue", thread)
            child.wait(timeout=20)
            if mode == "attack_reader":
                active = consume_case(active, child, env, stage, prepared, point_key, row)
        require(not re.search(r"SCRIPT ERROR:|Parse Error:|Compile Error:|ERROR:",
                              io.fs_path(stage / "native.log").read_text(encoding="utf-8", errors="replace")),
                "Engine errors are not accepted test evidence")
        if mode == "producer":
            require(row.get("planned_termination") is True and len(row["debug_stops"]) == 1, "Exact producer stop was not observed")
        else:
            require(child.returncode == 0, "Native reader failed")
            report = h.read(io.fs_path(stage / "report.json")); bound(report, child, env); checks_pass(report)
            require(report.get("schema") == "readset_driver_v1" and report.get("mode") == mode and report.get("budget_ms") == 3000
                    and report.get("production_method_overrides") == 0
                    and all(report.get(key) is False for key in ("original_profile_used_by_engine", "public_entry_qualified", "flow_qualified",
                            "sdk_qualified", "original_release_qualified", "os_input", "human_acceptance", "production_qualified")),
                    "Report scope or qualification boundary changed")
            if mode == "attack_reader":
                # A final case can publish and exit before the next debugger poll.
                require(active is None and issued == len(CASES) and len(row["cases"]) == len(CASES), "All ordered case receipts must precede exit")
                require([value["case"] for value in report["results"]] == list(CASES)
                        and report["results"] == [h.read(io.fs_path(stage / ("case_%02d.json" % index))) for index in range(len(CASES))],
                        "Final report and original case receipts differ")
            row["providers"] = provider_evidence(report, profile,
                prepared["pid"] if mode == "attack_reader" else state["old_writer_pid"], stage, state["pins"])
            require(row["providers"], "Real external-PID provider evidence required")
            if mode == "attack_reader":
                require(any(value["state"] == "alive" and value["target_pid"] == child.pid for value in row["providers"]),
                        "Actual reader-owning-lock WRITER_ALIVE provider evidence missing")
            row.update(report_sha256=h.sha(io.fs_path(stage / "report.json")), checks=len(report["checks"]),
                       helpers_terminal_confirmed=True, complete=True)
    except BaseException as error:
        row.update(error=repr(error), traceback=traceback.format_exc(), complete=False)
        primary = error
    finally:
        def finish_child():
            if child is not None:
                if child.poll() is None:
                    child.kill(); child.wait(timeout=20); row["aborted_owned_child"] = True
                row.update(exit_code=child.returncode, process_terminal=child.poll() is not None)
        io.post_step(row, "finish original owned Popen", finish_child)
        if connection is not None: io.post_step(row, "close owned debugger", connection.close)
        if listener is not None: io.post_step(row, "close owned listener", listener.close)
        okay, digest = io.post_step(row, "hash original log", lambda: h.sha(io.fs_path(stage / "native.log")))
        if okay: row["log_sha256"] = digest
        io.persist_result(stage / "controller.json", row)
    if primary is not None:
        raise primary
    require(not row.get("post_errors") and row["complete"], "Stage finalization failed; original evidence retained")
    return row, prepared


def environment(state, workers, profile, nonce, mode, base_env):
    env = dict(base_env)
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        target = io.owned(profile / key.lower(), profile)
        require(env.get(key) == str(target) and io.fs_path(target).is_dir(),
                "Private environment directory differs: " + key)
    for key in list(env):
        if key.startswith(("RS_", "CT_", "SC_", "CB_", "CC_", "SP_", "IO_", "DA_", "MR_", "HG_", "LR_", "LSH_CONTINUE_FLOW_")):
            env.pop(key)
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", RS_WORKERS=str(workers),
               RS_DRIVER_SHA256=h.sha(io.fs_path(workers / "driver.gd")), RS_FIXTURES_SHA256=h.sha(io.fs_path(workers / "fixtures.gd")),
               RS_MODE=mode, RS_PROFILE=str(profile), RS_NONCE=nonce, RS_PROCESS_NONCE=uuid.uuid4().hex,
               RS_CONTENT=state["content_version"], RS_ENGINE=state["engine_sha256"],
               RS_SEED_PATH=str(state["private_seed"]) if mode == "producer" else "",
               RS_SEED_SHA=state["original_inventory"]["files"]["5088120/1/record_0000000001.json"]["sha256"]
                   if mode == "producer" else "")
    return env


def execute(args):
    output = ROOT / ".godot/recovery_readset_20261027" / h.stamp()
    io.fs_path(output).mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "readset_component_host_v1", "complete": False, "steps": [], "slice_passed": False,
               "synthetic_attack_fixtures": True, "original_profile_used_by_engine": False,
               "clone_store_recovery_only": True, "flow_qualified": False, "production_qualified": False}
    locked, state, clone = False, None, None
    children, pins = [], {}
    owner = str(output)
    try:
        began = time.monotonic()
        while not locked:
            if not h.shared.LOCK.exists() and not h.running():
                try:
                    with h.shared.LOCK.open("x", encoding="utf-8") as stream: stream.write(owner)
                    locked = True
                except FileExistsError:
                    pass
            if not locked:
                require(time.monotonic() - began < args.wait_lane, "Shared engine lane occupied; no child started")
                time.sleep(1)
        require(not h.running(), "Foreign engine appeared before preflight")
        state = preflight(args.base_run); pins = state["pins"]
        receipt.update(base_run=str(state["run_base"]), project=str(state["project"]), content_version=state["content_version"],
                       engine_sha256=state["engine_sha256"], points=state["points"], original_business=str(state["original"]),
                       original_inventory=state["original_inventory"], original_dead_writer_pid=state["old_writer_pid"],
                       initial_identity_passed=True)
        for path, digest in list(pins.items()):
            source = io.plain_path(path)
            if source == state["engine"] or source.suffix.lower() == ".exe" or source.is_relative_to(state["original"]):
                continue
            relative = source.relative_to(ROOT) if source.is_relative_to(ROOT) else Path("external") / digest / source.name
            target = output / "runner_inputs" / relative
            p.copy(source, target, digest); p.pin(target, pins, digest)
        workers = output / "workers"; io.fs_path(workers).mkdir()
        for name, source in WORKERS.items():
            p.copy(source, workers / name, pins[str(source)]); p.pin(workers / name, pins, pins[str(source)])
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/readset" / nonce[:12]
        h.identity.no_links(profile); io.fs_path(profile).mkdir(parents=True, exist_ok=False)
        base_env = h.common.private_environment(profile)
        private_seed = io.owned(profile / "inputs/seed.json", profile)
        seed_sha = state["original_inventory"]["files"]["5088120/1/record_0000000001.json"]["sha256"]
        p.copy(state["seed"], private_seed, seed_sha)
        p.pin(private_seed, pins, seed_sha)
        state["private_seed"] = private_seed
        receipt.update(profile=str(profile), nonce=nonce)
        receipt["private_seed"] = {"path": str(private_seed), "sha256": seed_sha,
                                   "copied_from_original_by_host_only": True, "archive_payload_allowed": False}
        env = environment(state, workers, profile, nonce, "producer", base_env)
        p.verify_pins(pins)
        producer, prepared = run_process(state, workers, profile, env, output / "producer", args.timeout, receipt["steps"], children)
        pin_tree(output / "producer", pins)
        prepared_path = output / "producer/prepared.json"
        env = environment(state, workers, profile, nonce, "attack_reader", base_env)
        env.update(RS_PREPARED_PATH=str(prepared_path), RS_PREPARED_SHA=pins[str(prepared_path)])
        p.verify_pins(pins)
        reader, _ = run_process(state, workers, profile, env, output / "attack_reader", args.timeout, receipt["steps"],
                                children, prepared, output / "producer")
        require(children[0].poll() == producer["exit_code"] and children[1].poll() == 0,
                "Original producer/reader Popen terminal evidence changed")
        receipt["producer_handle_retained_until_reader_terminal"] = True
        pin_tree(output / "attack_reader", pins)
        clone_nonce = uuid.uuid4().hex
        clone_profile = Path(ROOT.anchor) / "CodexQA/readset" / clone_nonce[:12]
        h.identity.no_links(clone_profile); io.fs_path(clone_profile).mkdir(parents=True, exist_ok=False)
        clone_base_env = h.common.private_environment(clone_profile)
        clone = clone_profile / "appdata/Godot/app_userdata" / state["userdata_name"] / "continue/v1"
        io.fs_path(clone.parent).mkdir(parents=True, exist_ok=False)
        io.copy_account_tree(state["original"], clone)
        require(io.snapshot(clone) == state["original_inventory"] and io.snapshot(state["original"]) == state["original_inventory"],
                "Exact historical three-file/eight-directory clone required")
        inventory_path = output / "original_inventory.json"
        save(inventory_path, state["original_inventory"]); p.pin(inventory_path, pins)
        env = environment(state, workers, clone_profile, clone_nonce, "clone_record", clone_base_env)
        env.update(RS_EXPECTED_INVENTORY=str(inventory_path), RS_EXPECTED_INVENTORY_SHA=pins[str(inventory_path)],
                   RS_CLONE_BUSINESS=str(clone))
        receipt.update(clone_profile=str(clone_profile), clone_business=str(clone), clone_nonce=clone_nonce)
        p.verify_pins(pins)
        clone_row, _ = run_process(state, workers, clone_profile, env, output / "clone_record", args.timeout,
                                   receipt["steps"], children)
        report = h.read(io.fs_path(output / "clone_record/report.json"))
        require(len(report["results"]) == 1, "One original-record clone result required")
        result = report["results"][0]
        allowed = json.loads(json.dumps(state["original_inventory"]))
        allowed["files"].pop("5088120/1/writing/owner.json")
        allowed["directories"].remove("5088120/1/writing")
        digest = state["original_inventory"]["files"]["5088120/1/record_0000000001.json"]["sha256"]
        require(result.get("case") == "original_record_clone" and result.get("store_recovery_only") is True
                and result.get("old_content_not_rewritten") is True and result.get("flow_qualified") is False
                and result.get("world_mount_qualified") is False and result["before"] == state["original_inventory"]
                and result["inspect_result"].get("ok") is True and result["recover_result"].get("ok") is True
                and result["recover_result"].get("revision") == 1 and result["recover_result"].get("file_sha256") == digest
                and result["after"] == allowed and io.snapshot(clone) == allowed, "Exact original Store recovery/LC preservation differs")
        receipt.update(clone_expected_final=allowed, ordered_cases=list(CASES), actual_case_count=len(reader["cases"]),
                       actual_checks=reader["checks"] + clone_row["checks"],
                       actual_provider_count=len(reader["providers"]) + len(clone_row["providers"]), observed=True)
        pin_tree(output / "clone_record", pins)
    except BaseException as error:
        receipt.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        def final_identity():
            if state is not None:
                require(io.snapshot(state["original"]) == state["original_inventory"], "Read-only original business changed")
                receipt["original_unchanged"] = True
                if clone is not None: receipt["clone_final_inventory"] = io.snapshot(clone)
                h.assert_runtime_current(state["run_base"])
                h.identity.verify_generated(state["project"], state["generation"])
                p.verify_pins(pins); receipt["final_identity_passed"] = True
        io.post_step(receipt, "final source and original inventory", final_identity)
        terminal = len(children) == len(receipt["steps"]) and all(child.poll() is not None for child in children)
        helpers_terminal = all(row.get("helpers_terminal_confirmed") is True for row in receipt["steps"])
        receipt.update(attempted_processes=len(receipt["steps"]), terminal_processes=sum(child.poll() is not None for child in children),
                       children_terminal_confirmed=terminal, helpers_terminal_confirmed=helpers_terminal, lock_released=False)
        def release_lane():
            owned = locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text(encoding="utf-8") == owner
            receipt["lock_ownership_confirmed"] = owned
            if owned and terminal and helpers_terminal and not h.running():
                h.shared.LOCK.unlink(); receipt["lock_released"] = not h.shared.LOCK.exists()
        io.post_step(receipt, "release only owned terminal lane", release_lane)
        receipt["complete"] = bool(receipt.get("observed") and len(children) == 3 and terminal and helpers_terminal
                                   and all(row.get("complete") is True for row in receipt["steps"])
                                   and receipt.get("final_identity_passed") and receipt["lock_released"]
                                   and "error" not in receipt and not receipt.get("post_errors"))
        receipt["slice_passed"] = receipt["complete"]
        receipt["pinned_files"] = pins
        io.persist_result(output / "receipt.json", receipt)
    print(json.dumps({"run": str(output), "complete": receipt["complete"], "slice_passed": receipt["slice_passed"],
                      "error": receipt.get("error"), "lock_released": receipt["lock_released"],
                      "flow_qualified": False, "production_qualified": False}, ensure_ascii=False), flush=True)
    if not receipt["complete"] or receipt.get("post_errors"):
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", type=Path, required=True)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    require(60 <= args.timeout <= 900 and args.wait_lane >= 0, "Invalid bounded timeout")
    if args.execute:
        execute(args)
    else:
        state = preflight(args.base_run)
        print(json.dumps({"preflight": True, "engine_started": False, "profile_created": False,
                          "content_version": state["content_version"], "pins": len(state["pins"]),
                          "planned_processes": 3, "cases": list(CASES), "points": state["points"],
                          "original_files": len(state["original_inventory"]["files"]),
                          "original_directories": len(state["original_inventory"]["directories"]),
                          "flow_qualified": False, "production_qualified": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
