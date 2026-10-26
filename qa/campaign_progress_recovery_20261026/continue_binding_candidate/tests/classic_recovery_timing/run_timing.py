"""Same-byte isolated-copy recovery timing; default preflight is read-only.

Only --execute creates a private clone and owns one Godot child. No recovery or
claim is called. A timeout is an observed result, never a successful recovery.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
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


disk = load("classic_timing_disk", HERE.parent / "run_disk.py")
p, h, ROOT, require = disk.p, disk.h, disk.ROOT, disk.require
io = load("classic_timing_io", HERE.parents[2] / "store_protocol_candidate/tests/io/run_io.py")
CONTENT = "source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac"
FAILURE = ROOT / ".godot/classic_recovery_branch_20261027/20261027_023731_c180a912"


def preflight(base, failure):
    state = disk.preflight(base, "fixed")
    require(state["content_version"] == CONTENT, "Only original d7 source is admitted")
    failure = failure.resolve()
    require(failure == FAILURE.resolve(), "Only this preserved terminal failure is admitted")
    provenance = h.read(HERE / "sources.json")
    require(provenance.get("schema") == "classic_recovery_timing_sources_v1", "Unknown provenance")
    for row in provenance["files"]:
        relative = Path(row["path"])
        require(not relative.is_absolute() and ".." not in relative.parts, "Repository-relative sources required")
        p.pin(ROOT / relative, state["pins"], row["sha256"])
    p.pin(HERE / "sources.json", state["pins"])
    paths = [failure / name for name in ("receipt.json", "record/writer/prepared.json",
                                        "record/writer/receipt.json", "record/reader/report.json")]
    for path in paths:
        p.pin(path, state["pins"])
    receipt, prepared, writer, reader = [h.read(path) for path in paths]
    require(receipt.get("complete") is False and receipt.get("expected") == "fixed"
            and receipt.get("lock_released") is True and receipt.get("attempted_processes") == 4
            and receipt.get("terminal_processes") == 4 and receipt.get("content_version") == CONTENT
            and Path(receipt["base_run"]).resolve() == state["run_base"], "Terminal original failure/source mismatch")
    require(writer.get("complete") is True and writer.get("process_terminal") is True
            and type(writer.get("exit_code")) is int and writer["exit_code"] != 0
            and writer["before_termination"] == writer["after_termination"]
            and reader.get("passed") is False and reader.get("outcome") == "restore_refused", "Original process evidence mismatch")
    require(prepared.get("passed") is True and prepared.get("case") == "record"
            and prepared.get("content_version") == CONTENT and prepared.get("pid") == writer["pid"], "Prepared writer binding mismatch")
    profile = Path(prepared["profile"]).resolve()
    slot = Path(prepared["slot_directory"]).resolve()
    require(profile.is_relative_to(Path(ROOT.anchor) / "CodexQA/cslot") and slot.is_relative_to(profile)
            and slot.parts[-4:] == ("continue", "v1", "5088120", "1"), "Original private slot boundary required")
    original = slot.parents[1]
    snapshot = io.snapshot(original)
    require(snapshot["exists"] and len(snapshot["files"]) == 3 and len(snapshot["directories"]) == 8,
            "Exact preserved three-file/eight-directory business tree required")
    require(snapshot == writer["after_termination"], "Original full business tree changed since producer termination")
    require(h.sha(io.fs_path(slot / "record_0000000001.json")) == writer["slot_sha256"], "Original complete record SHA changed")
    for name, row in snapshot["files"].items():
        p.pin(original / name, state["pins"], row["sha256"])
    state.update(failure=failure, original=original, original_profile=profile, snapshot=snapshot,
                 userdata_name=original.parents[1].name, writer_pid=writer["pid"])
    p.verify_pins(state["pins"])
    return state


def execute(args):
    output = ROOT / ".godot/classic_recovery_timing_20261027" / h.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema":"classic_recovery_timing_host_v1", "complete":False, "steps":[],
               "same_byte_isolated_copy":True, "original_profile_used_by_engine":False,
               "recovery_qualified":False, "production_qualified":False}
    owner, locked, attempted, state, pins, clone = str(output), False, False, None, {}, None
    report = {}
    try:
        began = time.monotonic()
        while not locked:
            if not h.shared.LOCK.exists() and not h.running():
                try:
                    with h.shared.LOCK.open("x", encoding="utf-8") as stream: stream.write(owner)
                    locked = True
                    break
                except FileExistsError: pass
            require(time.monotonic() - began < args.wait_lane, "Shared engine lane occupied")
            time.sleep(1)
        require(not h.running(), "Engine appeared before preflight")
        state = preflight(args.base_run, args.failure_run)
        pins = state["pins"]
        receipt.update(base_run=str(state["run_base"]), project=str(state["project"]),
                       content_version=state["content_version"], engine_sha256=state["engine_sha256"],
                       failure_run=str(state["failure"]), original_business=str(state["original"]),
                       original_inventory=state["snapshot"], original_dead_writer_pid=state["writer_pid"],
                       initial_identity_passed=True)
        for path, digest in list(pins.items()):
            source = Path(path)
            if source.is_relative_to(state["project"]) or source == state["engine"]: continue
            relative = source.relative_to(ROOT) if source.is_relative_to(ROOT) else Path("external") / digest / source.name
            target = output / "runner_inputs" / relative
            p.copy(source, target, digest); p.pin(target, pins, digest)
        workers = output / "workers"
        workers.mkdir()
        for name in ("bootstrap.gd", "driver.gd"):
            p.copy(HERE / name, workers / name, pins[str(HERE / name)])
            p.pin(workers / name, pins)
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/ctiming" / nonce[:12]
        h.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = h.common.private_environment(profile)
        for key in list(env):
            if key.startswith(("CT_", "SC_", "CB_", "CC_", "LSH_CONTINUE_FLOW_")):
                env.pop(key)
        clone = profile / "appdata/Godot/app_userdata" / state["userdata_name"] / "continue/v1"
        clone.parent.mkdir(parents=True, exist_ok=False)
        io.copy_account_tree(state["original"], clone)
        require(io.snapshot(clone) == state["snapshot"] and io.snapshot(state["original"]) == state["snapshot"], "Same-byte clone required")
        inventory_path = output / "original_inventory.json"
        h.save(inventory_path, state["snapshot"]); p.pin(inventory_path, pins)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", CT_WORKERS=str(workers), CT_WORKER_SHA256=pins[str(workers / "driver.gd")],
                   CT_OUTPUT=str(output), CT_PROFILE=str(profile), CT_NONCE=nonce, CT_CONTENT=state["content_version"],
                   CT_ENGINE=state["engine_sha256"], CT_CLONE_BUSINESS=str(clone),
                   CT_INVENTORY=str(inventory_path), CT_INVENTORY_SHA=pins[str(inventory_path)])
        receipt.update(profile=str(profile), clone_business=str(clone), nonce=nonce)
        p.verify_pins(pins)
        attempted = True
        h.common.process_step(state["engine"], state["project"], env, output, "timing",
                              ["--headless", "--script", str(workers / "bootstrap.gd")], args.timeout,
                              "gl_compatibility", h.running, receipt["steps"])
        report = h.read(output / "report.json"); p.pin(output / "report.json", pins)
        receipt["report_sha256"] = pins[str(output / "report.json")]
        step = receipt["steps"][0]
        require(step["exit_code"] == 0 and step["passed"] is True and step["errors"] == [], "Native diagnostic process failed")
        require(report.get("schema") == "classic_recovery_timing_v1" and report.get("diagnostic_complete") is True
                and report.get("pid") == step["pid"] and report.get("nonce") == nonce and report.get("profile") == str(profile)
                and report.get("content_version") == state["content_version"] and report.get("engine_sha256") == state["engine_sha256"]
                and report.get("budget_ms") == 3000 and report.get("same_byte_isolated_copy") is True
                and report.get("original_profile_used_by_engine") is False and report.get("recovery_called") is False
                and report.get("claim_created") is False and report.get("recovery_qualified") is False
                and report.get("providers_terminal") is True and all(row.get("passed") is True for row in report["checks"]),
                "Bound native observation/inventory/terminal evidence required")
        for directory, provider in report["providers"].items():
            path = Path(provider["raw_report_path"])
            require(path == Path(directory) / "result.json" and path.is_relative_to(profile)
                    and provider["own_child_exit_code"] >= 0 and provider["own_child_running"] is False,
                    "Only actual terminal own-child evidence is admitted")
            if provider["raw_report_sha256"]:
                p.pin(path, pins, provider["raw_report_sha256"])
                require(io.fs_path(path).read_text(encoding="ascii") == provider["raw_report"], "Original provider JSON bytes differ")
                raw = json.loads(provider["raw_report"])
                require(raw["target_pid"] == str(state["writer_pid"]) and raw["provider_pid"] == str(provider["provider_pid"])
                        and raw["nonce"] == provider["request_nonce"], "Provider PID/nonce binding differs")
                if provider["observation"].get("state") in ("alive", "dead"):
                    require(raw == provider["observation"]["evidence"], "Oracle accepted evidence differs from raw report")
                p.copy(path, output / "providers" / str(provider["provider_pid"]) / "result.json", pins[str(path)])
        receipt.update(diagnostic_observed=True, initial_inspection=report["initial_inspection"],
                       preclaim_attempted=report["preclaim_attempted"], preclaim_result=report["preclaim_result"],
                       whole_preclaim_result=report["whole_preclaim_result"],
                       actual_timed_calls=len(report["timings"]), actual_provider_count=len(report["providers"]))
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        if (output / "report.json").is_file() and not report:
            try: report = h.read(output / "report.json"); receipt["report_sha256"] = h.sha(output / "report.json")
            except BaseException as error: receipt["report_read_error"] = repr(error)
        if state is not None:
            try:
                receipt["original_unchanged"] = io.snapshot(state["original"]) == state["snapshot"]
                receipt["clone_unchanged"] = clone is not None and io.snapshot(clone) == state["snapshot"]
                require(receipt["original_unchanged"] and receipt["clone_unchanged"], "Business files changed")
                h.assert_runtime_current(state["run_base"])
                h.identity.verify_generated(state["project"], state["generation"])
                p.verify_pins(pins)
                receipt["final_identity_passed"] = True
            except BaseException as error:
                receipt["final_identity_error"] = repr(error)
        steps = receipt["steps"]
        terminal = not attempted or (len(steps) == 1 and type(steps[0].get("pid")) is int
                                     and type(steps[0].get("exit_code")) is int)
        helpers_terminal = not attempted or report.get("providers_terminal") is True
        receipt.update(child_terminal_confirmed=terminal, helpers_terminal_confirmed=helpers_terminal, lock_released=False)
        try:
            owned = locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text(encoding="utf-8") == owner
            receipt["lock_ownership_confirmed"] = owned
            if owned and terminal and helpers_terminal and not h.running():
                h.shared.LOCK.unlink(); receipt["lock_released"] = not h.shared.LOCK.exists()
        except BaseException as error: receipt["lock_release_error"] = repr(error)
        receipt["complete"] = bool(receipt.get("diagnostic_observed") and receipt.get("final_identity_passed")
                                   and receipt["lock_released"] and "error" not in receipt)
        receipt["pinned_files"] = pins
        h.save(output / "receipt.json", receipt)
    print(json.dumps({"run":str(output),"complete":receipt["complete"],"error":receipt.get("error"),
                      "recovery_qualified":False,"lock_released":receipt["lock_released"]},ensure_ascii=False))
    if not receipt["complete"]: raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run",type=Path,required=True)
    parser.add_argument("--failure-run",type=Path,required=True)
    parser.add_argument("--execute",action="store_true")
    parser.add_argument("--timeout",type=int,default=120)
    parser.add_argument("--wait-lane",type=int,default=0)
    args = parser.parse_args()
    require(30 <= args.timeout <= 600 and args.wait_lane >= 0,"Invalid bound")
    if args.execute: execute(args)
    else:
        state = preflight(args.base_run,args.failure_run)
        print(json.dumps({"preflight":True,"engine_started":False,"clone_created":False,
                          "content_version":state["content_version"],"files":len(state["snapshot"]["files"]),
                          "directories":len(state["snapshot"]["directories"]),"pins":len(state["pins"]),
                          "recovery_qualified":False}))


if __name__ == "__main__": main()
