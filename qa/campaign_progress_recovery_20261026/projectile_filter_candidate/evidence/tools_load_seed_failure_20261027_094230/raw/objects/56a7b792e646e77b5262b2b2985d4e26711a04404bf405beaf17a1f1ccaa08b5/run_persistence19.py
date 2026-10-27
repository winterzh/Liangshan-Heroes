"""Run the versioned persistence-19 component oracle; default is named-source read-only.

Real injection uses only an owned loopback debugger and Win32 handles on fresh
private profiles. A current candidate-save/oplock proof is mandatory for --run.
This is not a natural battle, public Continue, Steam SDK, or reward-once test.
"""
from __future__ import annotations

import argparse
import ctypes as ct
from ctypes import wintypes as wt
import hashlib
import importlib.util
import json
import math
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
ROOT = HERE.parents[4]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


plan = load("p19_plan", HERE / "plan_persistence19.py")
prep = load("p19_preparation", HERE.parents[1] / "integration_3365/prepare_projectile.py")
p, h, require = prep.p, prep.h, plan.require
wire = load("p19_wire", ROOT / "tools/godot_debug_wire.py")
oplocks = load("p19_oplocks", ROOT / "tools/windows_owned_oplock.py")
io = load("p19_closed_ack", ROOT / "qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_io.py")
baseline = load("p19_process_inventory", ROOT / "tools/run_workstation_baseline.py")
WORKERS = ("bootstrap.gd", "worker.gd")
CFG_SOURCE = "res://scripts/run_campaign_cfg_transaction.gd"
CLOUD_SOURCE = "res://scripts/steam_cloud.gd"
USERDIR = "appdata/Godot/app_userdata/水浒英雄传：八幕战役"
FALSE_FLAGS = ("natural_battle_qualified", "reward_once_qualified", "cloud_upload_qualified",
               "native_sdk_qualified", "public_continue_qualified", "native_release_tested",
               "human_acceptance", "full_61_qualified", "published")
GATE_KEYS = {"schema", "pid", "index", "id", "batch_nonce", "process_nonce", "profile",
             "userdata", "output", "fault", "cfg_path", "cfg_source_sha256", "phase", "cfg_expected_unlock"}


def read(path):
    h.identity.no_links(p.fs(path))
    return h.read(p.fs(path))


def sha(path):
    h.identity.no_links(p.fs(path))
    return h.sha(p.fs(path))


def json_integer(value, expected):
    return type(value) in (int, float) and math.isfinite(value) and value == expected


def owned(path, root):
    return io.owned(path, root)


def attempt(row, label, function):
    try:
        return True, function()
    except BaseException as error:
        row.setdefault("post_errors", []).append({"phase": label, "error": repr(error),
                                                  "traceback": traceback.format_exc()})
        row["complete"] = False
        return False, None


def snapshot_business(profile):
    root = owned(profile / USERDIR, profile)
    cfg = root / "campaign.cfg"
    value = {"campaign.cfg": {"exists":p.fs(cfg).is_file()}}
    if value["campaign.cfg"]["exists"]:
        value["campaign.cfg"].update(sha256=sha(cfg), bytes=p.fs(cfg).stat().st_size)
    value.update({name:io.snapshot(root/name) for name in
                  ("campaign_cfg_candidates", "campaign_cfg_transactions", "continue")})
    return value


def persist(path, row):
    """Exclusive evidence writes; a failed final write cannot retain a qualification."""
    try:
        h.save(p.fs(path), row)
        return True
    except BaseException as error:
        row.setdefault("post_errors", []).append({"phase":"save " + str(path), "error":repr(error),
                                                   "traceback":traceback.format_exc()})
        row["complete"] = False
        for flag in ("protocol_proved", "component_matrix_qualified"):
            if flag in row: row[flag] = False
        fallback = path.with_name(path.stem + "_write_failed_" + uuid.uuid4().hex + path.suffix)
        row["fallback_evidence_path"] = str(fallback)
        try:
            h.save(p.fs(fallback), row)
        except BaseException as second:
            row["post_errors"].append({"phase":"fallback_save", "error":repr(second), "traceback":traceback.format_exc()})
            print(json.dumps({"evidence_write_failed":row},ensure_ascii=False),file=sys.stderr,flush=True)
        return False


def named_state():
    checked = plan.inspect_plan()
    source = read(HERE / "sources.json")
    pins = {}
    for row in source["files"]:
        p.pin(ROOT / row["path"], pins, row["sha256"])
    for module in (plan, prep, p, h, h.common, h.shared, h.identity, wire, oplocks, io, baseline):
        p.pin(Path(module.__file__), pins)
    for path in (Path(__file__), HERE / "prove_fault_protocol.py", HERE / "sources.json"):
        p.pin(path, pins)
    return checked, pins


def statement(project, source, function, text):
    lines = (p.fs(project / source.removeprefix("res://"))).read_text(encoding="utf-8").splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("func " + function + "(")), None)
    require(start is not None, "Missing exact installed function " + function)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("func ")), len(lines))
    matches = [i + 1 for i in range(start + 1, end) if lines[i].strip() == text]
    require(len(matches) == 1, "Ambiguous installed statement " + function + ": " + text)
    return {"source": source, "line": matches[0], "function": function, "statement": text}


def breakpoints(project):
    return {
        "load": statement(project, CFG_SOURCE, "_stable_cfg", "var loaded: int = cfg.load(path)"),
        "save": statement(project, CFG_SOURCE, "retry_write", "var saved: int = _frozen_cfg.save(candidate)"),
        "saved": statement(project, CFG_SOURCE, "retry_write", 'if saved != OK: return {"ok":false, "code":"CFG_STAGE_WRITE", "native_error":saved, "owned_pending":true}'),
        "digest": statement(project, CFG_SOURCE, "retry_write", "var digest: Dictionary = _cfg_sha(candidate)"),
        "dirty": statement(project, CLOUD_SOURCE, "mark_dirty", "if _applying:"),
    }


def full_state(base_run, named_pins):
    require(Path(base_run).resolve() == (ROOT / plan.BASE_REL).resolve(), "Only the fixed b22 run is supported")
    state = prep.prepared_state(base_run)
    require(state.get("validation_level") == "full_new_freeze_and_own_import"
            and state.get("cold_import_qualified") is True
            and state["content_version"] == "source-v1:" + plan.SOURCE_SHA,
            "Full current source and own first cold import required")
    manifest = read(state["run_base"] / "candidate_manifest.json")
    require(manifest.get("schema") == "projectile_3365_integrated_manifest_v1"
            and len(manifest["files"]) == 26 and len(manifest["native_assets"]) == 1, "Strict 26+1 manifest")
    prep.merge_pins(state["pins"], named_pins)
    state["breakpoints"] = breakpoints(state["project"])
    for source in (CFG_SOURCE, CLOUD_SOURCE):
        p.pin(state["project"] / source.removeprefix("res://"), state["pins"])
    return state


class CandidateWriteDenial:
    """Create one identifiable host sentinel with a non-sharing native handle."""
    def __init__(self, path, profile, nonce):
        self.path = owned(path, profile)
        require(not p.fs(path).exists(), "Candidate sentinel cannot overwrite a file")
        self.data = ("P19_HOST_ONLY_WRITE_DENIAL " + nonce + "\n").encode("ascii")
        self.handle = None
        self.api = ct.WinDLL("kernel32", use_last_error=True)
        definitions = {
            "CreateFileW": ([wt.LPCWSTR, wt.DWORD, wt.DWORD, ct.c_void_p, wt.DWORD, wt.DWORD, wt.HANDLE], wt.HANDLE),
            "WriteFile": ([wt.HANDLE, ct.c_void_p, wt.DWORD, ct.POINTER(wt.DWORD), ct.c_void_p], wt.BOOL),
            "FlushFileBuffers": ([wt.HANDLE], wt.BOOL), "CloseHandle": ([wt.HANDLE], wt.BOOL),
        }
        for name, (arguments, result) in definitions.items():
            method = getattr(self.api, name); method.argtypes = arguments; method.restype = result
        try:
            handle = self.api.CreateFileW(str(p.fs(path)), 0xC0000000, 0, None, 1, 0x80, None)
            if handle == ct.c_void_p(-1).value:
                raise ct.WinError(ct.get_last_error())
            self.handle = handle
            buffer = ct.create_string_buffer(self.data); written = wt.DWORD()
            if not self.api.WriteFile(handle, buffer, len(self.data), ct.byref(written), None):
                raise ct.WinError(ct.get_last_error())
            require(written.value == len(self.data), "Partial host sentinel")
            if not self.api.FlushFileBuffers(handle): raise ct.WinError(ct.get_last_error())
        except BaseException:
            self.close()
            raise

    def close(self):
        if self.handle is not None:
            if not self.api.CloseHandle(self.handle): raise ct.WinError(ct.get_last_error())
            self.handle = None


def configure_environment(profile, state, workers, stage, case, batch, process_nonce, base_env, previous):
    env = dict(base_env)
    for key in list(env):
        if key.startswith(("P19_", "DN_", "DF_", "GVT_", "GT_", "GLS_", "CR_", "CC_", "RS_", "LSH_CONTINUE_FLOW_")):
            env.pop(key)
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        require(env.get(key) == str(profile / key.lower()), "Profile environment mismatch")
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", LSH_CONTINUE_FLOW_QA="", LSH_LANGUAGE="zh_CN",
        P19_CASE=case["id"], P19_INDEX=str(case["index"]), P19_PROFILE=str(profile), P19_OUTPUT=str(stage),
        P19_BATCH_NONCE=batch, P19_PROCESS_NONCE=process_nonce, P19_WORKERS=str(workers),
        P19_WORKER_SHA256=sha(workers / "worker.gd"), P19_CONTENT=state["content_version"],
        P19_ENGINE=state["engine_sha256"], P19_PLAN_SHA256=sha(workers / "cases.json"))
    if previous:
        env.update(P19_PREVIOUS=str(previous), P19_PREVIOUS_SHA=sha(previous))
    return env


def gate_request(path, child, case, profile, stage, batch, nonce):
    if not p.fs(path).is_file(): return None
    try: value = read(path)
    except (json.JSONDecodeError, UnicodeDecodeError, PermissionError): return None
    require(type(value) is dict and set(value) == GATE_KEYS, "Exact case-gate fields")
    require(value["schema"] == "persistence19_gate_v1" and json_integer(value["pid"], child.pid)
        and json_integer(value["index"], case["index"]) and value["id"] == case["id"]
        and value["batch_nonce"] == batch and value["process_nonce"] == nonce
        and Path(value["profile"]) == profile and Path(value["output"]) == stage
        and Path(value["userdata"]) == profile / USERDIR and value["phase"] == "before_operation",
        "Actual gate PID/nonces/profile/case mismatch")
    target = owned(Path(value["cfg_path"]), profile)
    require(target == profile / USERDIR / "campaign.cfg", "Only this process campaign.cfg is permitted")
    actual = sha(target) if p.fs(target).is_file() else ""
    require(value["cfg_source_sha256"] == actual, "Gate original CFG changed")
    return value


def validate_log(path, index, cfg):
    raw = p.fs(path).read_text(encoding="utf-8", errors="replace")
    require(not re.search(r"(?m)^\s*(SCRIPT ERROR:|Parse Error:)", raw), "Script errors are never fault qualification")
    errors = re.findall(r"(?m)^\s*ERROR:.*$", raw)
    # The current CFG implementation passes a globalized path to ConfigFile.load.
    # Accept only this exact private file, never an arbitrary ConfigFile error.
    spellings = {str(cfg), cfg.as_posix()}
    allowed = [line for line in errors if any(line.strip() ==
        "ERROR: ConfigFile parse error at " + value + ":0: Unexpected EOF while parsing simple tag."
        for value in spellings)]
    require(errors == allowed and len(errors) == (1 if index == 6 else 0), "Exact malformed-CFG diagnostic budget")
    return errors


def validate_report(report, row, case, state, profile, batch, nonce):
    require(report.get("schema") == "persistence19_component_v2" and report.get("passed") is True
        and report.get("failures") == [] and report.get("checks")
        and all(check.get("passed") is True for check in report["checks"]), "Worker component checks failed")
    require(report.get("case") == case["id"] and json_integer(report.get("index"), case["index"])
        and json_integer(report.get("pid"), row["pid"]) and report.get("batch_nonce") == batch
        and report.get("process_nonce") == nonce and Path(report.get("profile", "")) == profile,
        "Actual worker identity mismatch")
    identity = report.get("identity", {})
    require(identity.get("content_version") == state["content_version"]
        and identity.get("engine_binary_sha256", identity.get("engine_sha256")) == state["engine_sha256"]
        and identity.get("source_mode") is True, "Actual runtime identity mismatch")
    require(all(report.get(flag) is False for flag in FALSE_FLAGS), "Component report widened qualification")
    require(report.get("old_expected") == case["old_expected"] and report.get("oracle_version") == case["oracle_version"],
        "Original expectation and versioned current oracle must remain explicit")
    require(row.get("gate") is not None and row.get("exit_code") == 0, "Actual terminal process and gate required")


def execute_case(case, state, workers, profile, env, stage, batch, nonce):
    row = {"index": case["index"], "id": case["id"], "profile": str(profile), "complete": False,
           "process_nonce": nonce, "post_errors": [], "debug_stops": [], "mutations": [], "gate": None}
    child = listener = connection = peer = denial = oplock = None
    thread_id = None; pending = None; candidate = None; armed_breaks = []; original_stage_dirs = set()
    log_path = stage / "native.log"; index = case["index"]
    cfg = profile / USERDIR / "campaign.cfg"; candidates = profile / USERDIR / "campaign_cfg_candidates/v1"
    deadline = time.monotonic() + state["timeout"]

    def set_break(key, enabled):
        point = state["breakpoints"][key]
        peer.command("breakpoint", thread_id, [point["source"], point["line"], enabled])
        if enabled: armed_breaks.append(key)
        elif key in armed_breaks: armed_breaks.remove(key)

    def preserve_move(path, label):
        destination = stage / (label + ".cfg")
        owned(path, profile); h.identity.no_links(p.fs(destination))
        require(p.fs(path).is_file() and not p.fs(destination).exists(), "Exclusive owned move required")
        digest = sha(path); p.fs(path).rename(p.fs(destination))
        require(not p.fs(path).exists() and sha(destination) == digest, "Moved bytes changed")
        return {"from":str(path), "backup":str(destination), "sha256":digest, "source_absent":True}

    try:
        require(os.name == "nt" and not baseline.engines(), "Windows idle native lane required")
        listener = socket.socket(); listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(30)
        command = [str(state["engine"]), "--path", str(state["project"]), "--headless", "--remote-debug",
                   "tcp://127.0.0.1:" + str(listener.getsockname()[1]), "--script", str(workers / "bootstrap.gd")]
        row["command"] = command
        with p.fs(log_path).open("xb") as stream:
            child = subprocess.Popen(command, cwd=state["project"], env=env, stdout=stream,
                stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            row["pid"] = child.pid
            connection, address = listener.accept(); listener.close(); listener = None
            connection.settimeout(.1); peer = wire.DebugConnection(connection)
            while child.poll() is None:
                require(time.monotonic() < deadline, "Owned component deadline exceeded")
                require(not baseline.engines() - {child.pid}, "Foreign engine appeared; never control it")
                if oplock is not None and oplock.poll_break():
                    mutation = row["mutations"][-1]
                    mutation["kernel_break_observed_ns"] = time.monotonic_ns()
                    mutation["child_alive_at_break"] = child.poll() is None
                    oplock.append_before_release(b"\n; p19 actual native ConfigFile opener interval\n")
                    oplock = None
                    mutation.update(after_sha256=sha(candidate), released_ns=time.monotonic_ns(),
                                    actual_native_opener_interval=True)
                    require(mutation["before_sha256"] != mutation["after_sha256"], "Native interval did not change bytes")
                if row["gate"] is None and thread_id is not None:
                    request = gate_request(stage / "gate_request.json", child, case, profile, stage, batch, nonce)
                    if request is not None:
                        row["gate"] = request
                        row["before_business"] = snapshot_business(profile)
                        original_stage_dirs = set(io.snapshot(candidates)["directories"])
                        if index == 6:
                            require(p.fs(cfg).read_bytes() == b"[broken", "Exact malformed CFG fixture required")
                        if index == 7: set_break("load", True); pending = "prior_load"
                        elif index in (9, 10, 11, 12, 18): set_break("save", True); pending = "candidate_save"
                        elif index == 17: set_break("dirty", True); pending = "cloud_callback"
                        io.publish_ack(p.fs(stage / "gate_ack.json"), {"schema":"persistence19_gate_ack_v1",
                            "pid":child.pid, "index":index, "id":case["id"], "batch_nonce":batch, "process_nonce":nonce})
                try: message, packet = peer.receive()
                except socket.timeout: continue
                except EOFError: break
                name, thread, data = message
                if name == "set_pid":
                    require(data == [child.pid], "Debugger PID is not the held Popen")
                    thread_id = thread
                elif name == "debug_enter":
                    require(pending is not None and len(data) == 4 and data[:3] == [True, "Breakpoint", True]
                        and data[3] == thread, "Unexpected native debugger/error stop")
                    peer.command("get_stack_dump", thread)
                elif name == "stack_dump":
                    frames = wire.stack_frames(data)
                    key = {"prior_load":"load", "candidate_save":"save", "save_return":"saved",
                           "candidate_digest":"digest", "candidate_load":"load", "cloud_callback":"dirty"}.get(pending)
                    require(key is not None, "Stack without an armed owned operation")
                    point = state["breakpoints"][key]
                    require(frames[0] == {k:point[k] for k in ("source", "line", "function")}, "Exact installed source/function/line differs")
                    stop = {"pid":child.pid, "process_nonce":nonce, "phase":pending, "frames":frames,
                            "source_sha256":sha(state["project"] / point["source"].removeprefix("res://")),
                            "monotonic_ns":time.monotonic_ns()}
                    row["debug_stops"].append(stop)  # Preserve the stack before fallible file observation.
                    if pending == "prior_load":
                        require(len(frames) > 1 and frames[1]["function"] == "begin_write", "Prior read call stack required")
                        stop["file"] = str(cfg); row["mutations"].append({"kind":"prior_vanished", **preserve_move(cfg, "prior_moved")})
                        set_break(key, False); pending = None
                    elif pending == "candidate_save":
                        inventory = io.snapshot(candidates); fresh = set(inventory["directories"]) - original_stage_dirs - {"", "."}
                        require(len(fresh) == 1, "Exactly one native transaction directory required")
                        transaction = next(iter(fresh)); require(re.fullmatch(r"[0-9a-f]{32}", transaction), "Native transaction path shape")
                        candidate = owned(candidates / transaction / "candidate.cfg", profile)
                        require(not p.fs(candidate).exists() and len(str(candidate)) < 240, "Closed short candidate absence before save")
                        stop.update(candidate=str(candidate), transaction=transaction, inventory=inventory,
                                    candidate_absent_before_native_save=True)
                        set_break(key, False)
                        if index == 9:
                            denial = CandidateWriteDenial(candidate, profile, nonce)
                            row["mutations"].append({"kind":"candidate_write_denial", "path":str(candidate),
                                "native_share_mode":0, "create_new":True, "host_sentinel_sha256":hashlib.sha256(denial.data).hexdigest(),
                                "not_production_candidate":True, "armed_ns":time.monotonic_ns()})
                            set_break("saved", True); pending = "save_return"
                        elif index == 11: set_break("digest", True); pending = "candidate_digest"
                        else: set_break("load", True); pending = "candidate_load"
                    elif pending == "save_return":
                        require(denial is not None and candidate is not None, "Owned denial handle missing")
                        denial.close(); row["mutations"][-1].update(preserve_move(candidate, "host_write_denial_sentinel"))
                        require(row["mutations"][-1]["sha256"] == row["mutations"][-1]["host_sentinel_sha256"], "Host sentinel was changed")
                        row["mutations"][-1]["save_return_reached_with_handle_held"] = True
                        denial = None; set_break(key, False); pending = None
                    elif pending == "candidate_digest":
                        before = p.fs(candidate).read_bytes(); expected = row["gate"]["cfg_expected_unlock"]
                        require(json_integer(expected, 9), "Current Level8 projection candidate must unlock 9")
                        after, count = re.subn(rb"(?m)^unlocked=9[ \t]*$", b"unlocked=7", before)
                        require(count == 1 and after != before, "Exactly one legal candidate semantic mutation")
                        with p.fs(candidate).open("wb") as file: file.write(after); file.flush(); os.fsync(file.fileno())
                        row["mutations"].append({"kind":"candidate_semantic_mismatch", "path":str(candidate),
                            "before_sha256":hashlib.sha256(before).hexdigest(), "after_sha256":sha(candidate), "changed_before_first_digest":True})
                        set_break(key, False); pending = None
                    elif pending == "candidate_load":
                        require(len(frames) > 1 and frames[1]["function"] == "retry_write", "Candidate load must come from retry_write")
                        require(candidate is not None and p.fs(candidate).is_file(), "Actual closed candidate is absent")
                        stop.update(candidate=str(candidate), candidate_sha256=sha(candidate))
                        if index == 12:
                            mutation = {"kind":"candidate_oplock_interval", "path":str(candidate),
                                "before_sha256":sha(candidate), "armed_ns":time.monotonic_ns()}
                            row["mutations"].append(mutation)
                            oplock = oplocks.OwnedOplock(candidate, profile)
                        else:
                            row["mutations"].append({"kind":"candidate_load_missing", **preserve_move(candidate, "candidate_moved")})
                        set_break(key, False); pending = None
                    elif pending == "cloud_callback":
                        require(any(x["function"] == "progress_committed" for x in frames)
                            and any(x["function"] == "retry" for x in frames), "Actual Campaign/Coordinator callback stack required")
                        stop["no_mutation"] = True; set_break(key, False); pending = None
                    peer.command("continue", thread)
            child.wait(timeout=20)
        row.update(exit_code=child.returncode, process_terminal=True)
        require(pending is None and not armed_breaks and oplock is None and denial is None, "Unfinished real fault control")
        row["native_errors"] = validate_log(log_path, index, cfg)
        report_path = stage / "report.json"; report = read(report_path)
        validate_report(report, row, case, state, profile, batch, nonce)
        if index in (7, 9, 10, 11, 12, 18): require(len(row["mutations"]) == 1, "One planned actual fault was not injected")
        if index == 9:
            result = report.get("result", {})
            require(result.get("code") == "CFG_STAGE_WRITE" and result.get("owned_pending") is True
                and type(result.get("native_error")) in (int,float) and result["native_error"] != 0,
                "The real candidate save must report its own native write failure")
        if index == 12:
            require(row["mutations"][0].get("actual_native_opener_interval") is True
                and report.get("observations",{}).get("readback_semantics_equal_frozen") is True,
                "Actual opener interval must change bytes while preserving native CFG semantics")
        if index == 17: require(len(row["debug_stops"]) == 1, "Actual mark_dirty callback was not observed")
        row.update(complete=True, report_path=str(report_path), report_sha256=sha(report_path), actual_checks=len(report["checks"]))
    except BaseException as error:
        row.update(error=repr(error), traceback=traceback.format_exc(), complete=False)
    finally:
        def terminal():
            if child is None: return
            if child.poll() is None:
                child.terminate()
                try: child.wait(timeout=20)
                except subprocess.TimeoutExpired: child.kill(); child.wait(timeout=20)
            row.update(pid=child.pid, exit_code=child.returncode, process_terminal=child.poll() is not None)
        attempt(row, "owned_popen_terminal", terminal)
        if denial is not None: attempt(row, "close_owned_denial_handle", denial.close)
        if oplock is not None: attempt(row, "close_owned_oplock", oplock.close)
        if connection is not None: attempt(row, "close_debug_connection", connection.close)
        if listener is not None: attempt(row, "close_listener", listener.close)
        ok, after = attempt(row, "final_case_business_inventory", lambda:snapshot_business(profile))
        if ok: row["after_business"] = after
        row["raw_pins"] = {}
        for path in (log_path, stage/"report.json", stage/"gate_request.json", stage/"gate_ack.json"):
            def pin_evidence(path=path):
                if p.fs(path).is_file(): row["raw_pins"][str(path)] = sha(path)
            attempt(row, "pin_case_evidence " + path.name, pin_evidence)
        if row["post_errors"]: row["complete"] = False
        persist(stage / "controller.json", row)
    return row


def validate_protocol(path, state, named_pins):
    proof = read(path)
    require(proof.get("schema") == "persistence19_fault_protocol_v1" and proof.get("complete") is True
        and proof.get("protocol_proved") is True and proof.get("lock_released") is True
        and proof.get("lock_owner_verified") is True and proof.get("engine_lane_idle") is True
        and proof.get("all_owned_children_terminal") is True and not proof.get("post_errors") and "error" not in proof
        and proof.get("final_identity_passed") is True and proof.get("source_identity") == state["content_version"]
        and proof.get("engine_sha256") == state["engine_sha256"] and proof.get("named_pins") == named_pins,
        "Actual current fault protocol proof and exact tool/source binding required")
    require([row["index"] for row in proof.get("cases", [])] == [9, 12]
        and all(row.get("complete") is True and row.get("process_terminal") is True and row.get("exit_code") == 0 for row in proof["cases"]),
        "Both actual native mechanism cases required")
    for row in proof["cases"]:
        require(sha(row["report_path"]) == row["report_sha256"], "Protocol worker evidence changed")
        for source, digest in row["raw_pins"].items(): require(sha(source) == digest, "Protocol control evidence changed")
        stops, mutations = row.get("debug_stops", []), row.get("mutations", [])
        require(len(stops) == 2 and stops[0].get("phase") == "candidate_save"
            and stops[0].get("candidate_absent_before_native_save") is True and len(mutations) == 1,
            "Actual current candidate entry and exact one mechanism required")
        mutation = mutations[0]
        if row["index"] == 9:
            require(stops[1].get("phase") == "save_return" and mutation.get("kind") == "candidate_write_denial"
                and mutation.get("native_share_mode") == 0 and mutation.get("create_new") is True
                and mutation.get("save_return_reached_with_handle_held") is True
                and mutation.get("not_production_candidate") is True
                and mutation.get("sha256") == mutation.get("host_sentinel_sha256"), "Real native candidate denial proof incomplete")
        else:
            require(stops[1].get("phase") == "candidate_load" and mutation.get("kind") == "candidate_oplock_interval"
                and mutation.get("actual_native_opener_interval") is True and mutation.get("child_alive_at_break") is True
                and mutation["armed_ns"] < mutation["kernel_break_observed_ns"] < mutation["released_ns"]
                and mutation["before_sha256"] != mutation["after_sha256"], "Real native opener interval proof incomplete")
    return proof


def execute(args, proof_mode):
    checked, named_pins = named_state()
    cases = checked["cases"]
    output = ROOT / (".godot/persistence19_protocol_20261027" if proof_mode else ".godot/persistence19_b22_20261027") / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {"schema":"persistence19_fault_protocol_v1" if proof_mode else "persistence19_b22_runner_v1",
        "complete":False, "protocol_proved":False, "component_matrix_qualified":False, "cases":[], "post_errors":[],
        "base_run":str(args.base_run.resolve()), "named_pins":named_pins, **{flag:False for flag in FALSE_FLAGS}}
    state = None; locked = False; owner = str(output); profiles = {}; pins = dict(named_pins)
    batch = uuid.uuid4().hex; receipt["batch_nonce"] = batch
    try:
        require(proof_mode or args.protocol_receipt is not None, "--run needs a successful current protocol receipt")
        start = time.monotonic()
        while not locked:
            if not p.fs(h.shared.LOCK).exists() and not baseline.engines():
                try:
                    with p.fs(h.shared.LOCK).open("x", encoding="utf-8") as stream: stream.write(owner)
                    locked = True
                    break
                except FileExistsError: pass
            require(time.monotonic() - start < args.wait_lane, "Shared engine lane occupied; no child started")
            time.sleep(1)
        require(not baseline.engines(), "Engine appeared before full source admission")
        state = full_state(args.base_run, named_pins); state["timeout"] = args.timeout; pins = state["pins"]
        receipt.update(source_identity=state["content_version"], engine_sha256=state["engine_sha256"],
            project=str(state["project"]), cold_import_qualified=True, initial_identity_passed=True,
            breakpoints=state["breakpoints"])
        if not proof_mode:
            validate_protocol(args.protocol_receipt, state, named_pins)
            p.pin(args.protocol_receipt, pins); receipt["protocol_receipt"] = str(args.protocol_receipt)
        for path, digest in list(pins.items()):
            source = Path(path)
            if source.suffix.lower() == ".exe": continue
            require(source.is_relative_to(ROOT), "Named source outside repository")
            target = output / "runner_inputs" / source.relative_to(ROOT)
            p.copy(source, target, digest); p.pin(target, pins, digest)
        workers = output / "workers"; p.fs(workers).mkdir()
        for name in (*WORKERS, "cases.json"):
            p.copy(HERE / name, workers / name, pins[str(HERE/name)]); p.pin(workers/name, pins)
        previous = None; seen = set()
        for index in ([9, 12] if proof_mode else range(19)):
            p.verify_pins(pins)
            case = cases[index]; require(case["index"] == index, "Original order changed")
            stage = output / (str(index).zfill(2) + "_" + case["id"]); p.fs(stage).mkdir()
            key = 0 if index == 1 else index
            if key not in profiles:
                profile = Path(ROOT.anchor) / "CodexQA/p19" / batch[:12] / str(key).zfill(2)
                h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
                profiles[key] = (profile, h.common.private_environment(profile))
            profile, base_env = profiles[key]; nonce = uuid.uuid4().hex
            env = configure_environment(profile, state, workers, stage, case, batch, nonce, base_env, previous if index == 1 else None)
            result = execute_case(case, state, workers, profile, env, stage, batch, nonce)
            receipt["cases"].append(result)
            require(result.get("pid") not in seen and result.get("complete") is True, "Actual component stage failed")
            seen.add(result["pid"])
            for path, digest in result["raw_pins"].items(): p.pin(path, pins, digest)
            p.pin(stage/"controller.json", pins)
            if index == 0: previous = stage / "report.json"
            p.verify_pins(pins)
            print("PASS", index, case["id"], "checks", result["actual_checks"], flush=True)
        require(len(seen) == len(receipt["cases"]) == (2 if proof_mode else 19), "Actual distinct terminal process count differs")
        receipt["protocol_proved"] = proof_mode
        receipt["component_matrix_qualified"] = not proof_mode
    except BaseException as error:
        receipt.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        identity_results = []
        if state is None:
            identity_results.append(attempt(receipt,"full_admission",lambda:require(False,"Full source admission incomplete"))[0])
        else:
            identity_results.append(attempt(receipt,"runtime_current",lambda:h.assert_runtime_current(state["run_base"]))[0])
            identity_results.append(attempt(receipt,"generated_identity",lambda:h.identity.verify_generated(state["project"],state["generation"]))[0])
            identity_results.append(attempt(receipt,"engine_sha256",lambda:require(sha(state["engine"]) == state["engine_sha256"],"Engine changed"))[0])
        identity_results.append(attempt(receipt,"source_pins",lambda:p.verify_pins(pins))[0])
        receipt["final_identity_passed"] = all(identity_results)
        receipt["all_owned_children_terminal"] = all(row.get("process_terminal") is True for row in receipt["cases"])
        def unlock():
            receipt["engine_lane_idle"] = not baseline.engines()
            receipt["lock_owner_verified"] = bool(locked and p.fs(h.shared.LOCK).is_file() and p.fs(h.shared.LOCK).read_text(encoding="utf-8") == owner)
            if receipt["engine_lane_idle"] and receipt["lock_owner_verified"] and receipt["all_owned_children_terminal"]:
                p.fs(h.shared.LOCK).unlink(); receipt["lock_released"] = not p.fs(h.shared.LOCK).exists()
        attempt(receipt, "owned_lock_release", unlock)
        receipt["complete"] = bool((receipt["protocol_proved"] if proof_mode else receipt["component_matrix_qualified"])
            and receipt.get("final_identity_passed") and receipt.get("lock_released") and not receipt["post_errors"] and "error" not in receipt)
        if not receipt["complete"]:
            receipt["protocol_proved"] = False; receipt["component_matrix_qualified"] = False
        receipt["actual_process_count"] = len(receipt["cases"])
        receipt["actual_checks"] = sum(row.get("actual_checks",0) for row in receipt["cases"])
        receipt["pinned_files"] = pins
        persist(output/"receipt.json",receipt)
    print(json.dumps({"output":str(output),"complete":receipt["complete"],"actual_process_count":len(receipt["cases"]),
                      "error":receipt.get("error")},ensure_ascii=False),flush=True)
    if not receipt["complete"]: raise SystemExit(1)


def main(proof_mode=False):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", type=Path, default=ROOT/plan.BASE_REL)
    parser.add_argument("--prove" if proof_mode else "--run", action="store_true", dest="execute")
    parser.add_argument("--protocol-receipt", type=Path)
    parser.add_argument("--full-preflight", action="store_true", help="Explicit expensive read-only whole-source admission")
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 30 or args.wait_lane < 0: parser.error("Invalid bounded deadline")
    if args.execute: execute(args, proof_mode); return
    checked, pins = named_state()
    state = full_state(args.base_run,pins) if args.full_preflight else None
    print(json.dumps({"named_source_plan_verified":True,"named_pins":len(pins),"original_case_count":19,
        "planned_indices":[9,12] if proof_mode else list(range(19)),"full_source_verified":state is not None,
        "protocol_proved":False,"native_executed":False,"engine_started":False,"profile_created":False,
        "component_matrix_qualified":False,**{flag:False for flag in FALSE_FLAGS}},ensure_ascii=False))


if __name__ == "__main__": main()
