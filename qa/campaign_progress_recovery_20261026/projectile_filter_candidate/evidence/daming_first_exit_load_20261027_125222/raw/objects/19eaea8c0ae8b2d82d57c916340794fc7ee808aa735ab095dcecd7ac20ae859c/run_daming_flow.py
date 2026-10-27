"""Eight-process Daming Flow route: two roles, two saves, victory and terminal refusal.

No --base-run: named source-plan checks only. --base-run performs read-only full
new-Daming freeze/import admission. Only --run starts Godot. This source-private
route does not qualify the original 61 stages, 19 faults, public entry or SDK.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time
import traceback
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
WORKER_ROOT = HERE / "tests/daming_flow"
WORKERS = ("bootstrap.gd", "base.gd", "terminal.gd", "driver.gd", "route.gd")
ROLES = ("lu", "shi")
MODES = ("save_single", "resume_settle_save", "resume_finish", "reject_terminal")
WIDER_FLAGS = ("native_sdk_qualified", "public_continue_qualified", "human_acceptance",
               "native_release_tested", "defeat_chain_qualified", "full_61_qualified",
               "original_19_faults_qualified")
spec = importlib.util.spec_from_file_location("daming_flow_prepare", HERE / "integration_941/prepare_daming.py")
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)
p, h, require = prep.p, prep.h, prep.require
fixture_spec = importlib.util.spec_from_file_location("daming_closed_a_fixture", WORKER_ROOT / "fixture_freeze.py")
fixture = importlib.util.module_from_spec(fixture_spec)
fixture_spec.loader.exec_module(fixture)


def source_pins():
    path = WORKER_ROOT / "sources.json"
    document = h.read(p.fs(path))
    expected = {str(item.relative_to(ROOT)).replace("\\", "/") for item in
                (Path(__file__).resolve(), WORKER_ROOT / "README.md", WORKER_ROOT / "fixture_freeze.py",
                 WORKER_ROOT / "test_fixture_freeze.py", *(WORKER_ROOT / name for name in WORKERS))}
    rows = document.get("files", [])
    require(document.get("schema") == "daming_flow_external_sources_v1"
            and len(rows) == len(expected) and {row["path"] for row in rows} == expected,
            "Exact Daming host/README/fixture helper/model/five-worker source list required")
    pins = {}
    for row in rows + document.get("derived_from", []) + document.get("dependencies", []):
        p.pin(prep.inside(ROOT, row["path"]), pins, row["sha256"])
    p.pin(path, pins)
    for module in (prep, h, h.common, h.shared, h.identity):
        p.pin(Path(module.__file__), pins)
    p.pin(ROOT / "tools/run_campaign_level_state_qa.py", pins)
    p.verify_pins(pins)
    return pins


def preflight(base):
    state = prep.prepared_state(base)
    require(state["validation_level"] == "full_new_freeze_and_own_import"
            and state["run_base"] == Path(base).resolve()
            and state["project"] == state["run_base"] / "project"
            and state["run_base"] != state["base"],
            "Execution requires the new Daming freeze and its own successful import")
    manifest = h.read(p.fs(state["run_base"] / "candidate_manifest.json"))
    require(manifest.get("schema") == "daming_941_integrated_manifest_v1"
            and len(manifest.get("files", [])) == 25 and len(manifest.get("native_assets", [])) == 1,
            "Exact Daming 25-script/one-native manifest required")
    prep.merge_pins(state["pins"], source_pins())
    p.verify_pins(state["pins"])
    return state


def cleanup_error(receipt, action, error):
    # Keep cleanup failures separate; never overwrite the primary traceback.
    receipt["cleanup_errors"].append({"action": action, "error": repr(error),
                                      "traceback": traceback.format_exc()})


def capture_stage(receipt, stage, mode, role, pins):
    report_path, log_path = stage / "report.json", stage / (mode + ".log")
    report = None
    try:
        if p.fs(log_path).is_file():
            p.pin(log_path, pins)
    except BaseException as error:
        cleanup_error(receipt, role + "/" + mode + ": pin log", error)
    try:
        if p.fs(report_path).is_file():
            p.pin(report_path, pins)
            report = h.read(p.fs(report_path))
            require(type(report) is dict, "Report root must be an object")
            receipt["reports"].append({"first_role": role, "mode": mode,
                "path": str(report_path), "sha256": pins[str(report_path)],
                "checks": len(report.get("checks", [])), "passed": report.get("passed", False),
                "failures": report.get("failures", [])})
    except BaseException as error:
        cleanup_error(receipt, role + "/" + mode + ": pin/read report", error)
    return report


def role_environment(profile, role, role_nonce, batch_nonce, project, workers, binding, pins, manifest_sha):
    # The shared helper creates these four directories with exist_ok=False.
    # Call exactly once per role; each stage receives only a dictionary copy.
    env = h.common.private_environment(profile)
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        require(env.get(key) == str(profile / key.lower()) and p.fs(profile / key.lower()).is_dir(),
                "Private profile environment escaped its role directory")
    for key in list(env):
        if key.startswith(("DF_", "GVT_", "GLS_", "GT_", "LL_", "LT_", "LSH_CONTINUE_FLOW_",
                           "CB_", "CC_", "CT_", "SC_", "CR_", "HG_", "LHMR_", "MR_", "LR_", "RS_")):
            env.pop(key)
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", LSH_CONTINUE_FLOW_QA="1",
               LSH_CONTINUE_FLOW_PROFILE=str(profile), DF_PROFILE=str(profile), DF_PROJECT=str(project),
               DF_WORKERS=str(workers), DF_BINDINGS=str(binding), DF_BINDINGS_SHA256=pins[str(binding)],
               DF_NONCE=batch_nonce, DF_ROLE_NONCE=role_nonce, DF_FIRST_ROLE=role,
               DF_CANDIDATE_SHA256=manifest_sha,
               DF_SOURCES_SHA256=pins[str(WORKER_ROOT / "sources.json")], LSH_LANGUAGE="zh_CN")
    return env


def validate_report(report, role, mode, profile, batch_nonce, role_nonce, process_nonce,
                    state, manifest_sha, pins, step, log_path, pids, nonces):
    require(type(report) is dict and report.get("schema") == "campaign_daming_flow_v1"
            and report.get("passed") is True and report.get("stage_completed") is True
            and report.get("failures") == [] and type(report.get("checks")) is list and report["checks"]
            and all(type(row) is dict and row.get("passed") is True for row in report["checks"]),
            "Native Daming route failed: " + role + "/" + mode)
    identity = report.get("identity", {})
    require(report.get("mode") == mode and report.get("first_role") == role
            and report.get("batch_nonce") == batch_nonce and report.get("role_nonce") == role_nonce
            and report.get("process_nonce") == process_nonce and process_nonce not in nonces
            and report.get("profile") == str(profile) and report.get("slot_root") == "user://continue/v1"
            and report.get("candidate_manifest_sha256") == manifest_sha
            and identity.get("content_version") == state["content_version"]
            and identity.get("engine_sha256") == state["engine_sha256"] and identity.get("source_mode") is True
            and type(report.get("simulation_time_scale")) in (int, float) and report["simulation_time_scale"] == 1
            and type(report.get("physics_hz")) in (int, float) and report["physics_hz"] == 60
            and report.get("natural_core_victory_required") is True and report.get("full_story_required") is False
            and report.get("sources_sha256") == pins[str(WORKER_ROOT / "sources.json")]
            and report.get("no_gameplay_state_injection") is True,
            "Actual role/PID/profile/source and normal-clock contract required")
    require(all(report.get(flag) is False for flag in WIDER_FLAGS),
            "Eight-process source Flow route cannot grant broader qualification")
    if mode in ("save_single", "resume_settle_save"):
        require(report.get("save_exit_observed") is True and report.get("exit_reason") == "continue_saved",
                "Production SaveAndExit must own the actual process exit")
    if mode == "resume_finish":
        result = report.get("terminal_checkpoint", {}).get("full_result", {})
        require(report.get("observations", {}).get("natural_terminal") is True
                and result.get("core_cleared") is True
                and type(result.get("contract_version")) in (int, float) and result["contract_version"] == 2
                and type(result.get("story_total")) in (int, float) and result["story_total"] == 3,
                "Actual natural Daming terminal result with current three-goal contract required")
    if mode == "reject_terminal":
        refusal = report.get("observations", {}).get("terminal_refusal", {})
        require(refusal.get("ok") is False and refusal.get("code") == "LOCAL_RUN_TERMINAL",
                "Actual restarted menu must refuse the original terminal token")
    pid = report.get("pid")
    require(type(pid) is int and pid > 0 and pid == step.get("pid") and pid not in pids
            and type(step.get("exit_code")) is int and step["exit_code"] == 0
            and step.get("passed") is True and step.get("errors") == [] and step.get("stopped_for") is None
            and step.get("log_sha256") == pins.get(str(log_path)),
            "Actual distinct terminal Popen, exit status and exact log required")
    pids.add(pid)
    nonces.add(process_nonce)


def execute(args):
    output = ROOT / ".godot/daming_flow_20261027" / h.stamp()
    h.identity.no_links(p.fs(output))
    p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "daming_flow_eight_process_v1", "complete": False,
               "execution_kind": "source_project_offscreen_gl", "base_run": str(args.base_run.resolve()),
               "runner_sha256": h.sha(p.fs(__file__)), "steps": [], "reports": [], "attempted_modes": [],
               "roles": {}, "cleanup_errors": [], "source_flow_chain_passed": False,
               "credited_rewards_qualified": False, **{flag: False for flag in WIDER_FLAGS}}
    owner, locked, state, pins = str(output), False, None, {}
    try:
        receipt["source_head"] = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        start, notice = time.monotonic(), 0.0
        while not locked:
            if not p.fs(h.shared.LOCK).exists() and not h.running():
                try:
                    with p.fs(h.shared.LOCK).open("x", encoding="utf-8") as stream:
                        stream.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            require(time.monotonic() - start < args.wait_lane, "Shared engine occupied; no child started")
            if time.monotonic() - notice >= 25:
                print("WAIT shared engine; no child started", flush=True)
                notice = time.monotonic()
            time.sleep(1)
        require(not h.running(), "Engine appeared before full admission")
        state = preflight(args.base_run)
        pins = state["pins"]
        project, engine = state["project"], state["engine"]
        manifest_sha = pins[str(state["run_base"] / "candidate_manifest.json")]
        receipt.update(project=str(project), content_version=state["content_version"],
                       ancestor_base_run=str(state["base"]), engine_sha256=state["engine_sha256"],
                       initial_identity_passed=True, candidate_manifest_sha256=manifest_sha,
                       candidate_script_count=25, native_asset_count=1, import_receipts=state["imports"])
        for path, digest in list(pins.items()):
            source = Path(path)
            if source.suffix.lower() == ".exe":
                continue
            require(source.is_relative_to(ROOT), "Unexpected external provenance input")
            target = output / "runner_inputs" / source.relative_to(ROOT)
            p.copy(source, target, digest)
            p.pin(target, pins, digest)
        workers = output / "workers"
        p.fs(workers).mkdir()
        for name in WORKERS:
            digest = pins[str(WORKER_ROOT / name)]
            p.copy(WORKER_ROOT / name, workers / name, digest)
            p.pin(workers / name, pins, digest)
        binding = workers / "bindings.json"
        h.save(p.fs(binding), {name: pins[str(workers / name)] for name in WORKERS})
        p.pin(binding, pins)
        batch_nonce = uuid.uuid4().hex
        receipt["batch_nonce"] = batch_nonce
        pids, nonces, role_nonces = set(), set(), set()
        for role in ROLES:
            role_nonce = uuid.uuid4().hex
            require(role_nonce not in role_nonces, "Distinct role nonce required")
            role_nonces.add(role_nonce)
            profile = Path(ROOT.anchor) / "CodexQA/damingflow" / batch_nonce[:12] / role
            h.identity.no_links(p.fs(profile))
            p.fs(profile).mkdir(parents=True, exist_ok=False)
            role_row = {"profile": str(profile), "role_nonce": role_nonce, "complete": False,
                        "process_ids": [], "process_nonces": []}
            receipt["roles"][role] = role_row
            env = role_environment(profile, role, role_nonce, batch_nonce, project, workers, binding, pins, manifest_sha)
            previous = None
            for mode in MODES:
                p.verify_pins(pins)
                for completed_role in receipt["roles"].values():
                    if "closed_a_fixture" in completed_role:
                        fixture.verify_frozen(p=p, output=output, reference=completed_role["closed_a_fixture"], pins=pins)
                stage = output / role / mode
                p.fs(stage).mkdir(parents=True, exist_ok=False)
                report_path, log_path = stage / "report.json", stage / (mode + ".log")
                process_nonce = uuid.uuid4().hex
                require(process_nonce not in nonces, "Distinct process nonce required")
                stage_env = dict(env, DF_MODE=mode, DF_REPORT=str(report_path), DF_PROCESS_NONCE=process_nonce)
                if previous is not None:
                    stage_env.update(DF_PREVIOUS=str(previous), DF_PREVIOUS_SHA256=pins[str(previous)])
                attempt = {"first_role": role, "mode": mode, "process_nonce": process_nonce,
                           "profile": str(profile), "report": str(report_path)}
                receipt["attempted_modes"].append(attempt)
                step_count = len(receipt["steps"])
                report = None
                try:
                    h.common.process_step(engine, project, stage_env, p.fs(stage), mode,
                                          ["--resolution", "1280x720", "--position", "30000,30000",
                                           "--script", str(workers / "bootstrap.gd")],
                                          args.timeout, "gl_compatibility", h.running, receipt["steps"])
                finally:
                    # Each collection operation catches its own errors so the original
                    # process_step exception and its traceback propagate unchanged.
                    report = capture_stage(receipt, stage, mode, role, pins)
                    if len(receipt["steps"]) == step_count + 1:
                        receipt["steps"][-1].update(first_role=role, mode=mode, process_nonce=process_nonce)
                require(not receipt["cleanup_errors"], "Stage evidence collection failed")
                require(len(receipt["steps"]) == step_count + 1, "Exactly one actual terminal step required")
                validate_report(report, role, mode, profile, batch_nonce, role_nonce, process_nonce,
                                state, manifest_sha, pins, receipt["steps"][-1], log_path, pids, nonces)
                role_row["process_ids"].append(report["pid"])
                role_row["process_nonces"].append(process_nonce)
                if mode == "save_single":
                    # A is already terminal/validated; freeze before any B launch.
                    # Only immutable copies join long-lived pins, never the live
                    # profile scope which B/C are authorized to advance.
                    role_row["closed_a_attempt"] = str(output / "closed_a" / role)
                    role_row["closed_a_fixture"] = fixture.freeze(p=p, output=output, profile=profile,
                        role=role, report_path=report_path, log_path=log_path,
                        step=receipt["steps"][-1], pins=pins,
                        expected={"batch_nonce": batch_nonce, "role_nonce": role_nonce,
                                  "process_nonce": process_nonce, "content_version": state["content_version"],
                                  "engine_sha256": state["engine_sha256"],
                                  "candidate_manifest_sha256": manifest_sha,
                                  "sources_sha256": pins[str(WORKER_ROOT / "sources.json")]})
                previous = report_path
            role_row["complete"] = len(role_row["process_ids"]) == 4
        receipt["eight_stages_passed"] = len(pids) == 8 and len(nonces) == 8 and len(role_nonces) == 2
    except BaseException as error:
        receipt["error"] = repr(error)
        receipt["traceback"] = traceback.format_exc()
    finally:
        try:
            require(state is not None, "Full admission did not complete")
            h.assert_runtime_current(state["run_base"])
            h.identity.verify_generated(state["project"], state["generation"])
            p.verify_pins(pins)
            for completed_role in receipt["roles"].values():
                if "closed_a_fixture" in completed_role:
                    fixture.verify_frozen(p=p, output=output, reference=completed_role["closed_a_fixture"], pins=pins)
            require(h.sha(p.fs(state["engine"])) == state["engine_sha256"], "Engine bytes changed")
            receipt["final_identity_passed"] = True
        except BaseException as error:
            receipt["final_identity_passed"] = False
            cleanup_error(receipt, "final source identity", error)
        receipt["child_process_terminal"] = len(receipt["steps"]) == len(receipt["attempted_modes"]) and all(
            type(step.get("pid")) is int and step["pid"] > 0 and type(step.get("exit_code")) is int
            for step in receipt["steps"])
        receipt.update(lock_ownership_confirmed=False, engine_lane_idle=False, lock_released=False)
        try:
            receipt["lock_ownership_confirmed"] = bool(locked and p.fs(h.shared.LOCK).is_file()
                and p.fs(h.shared.LOCK).read_text(encoding="utf-8") == owner)
        except BaseException as error:
            cleanup_error(receipt, "read lock ownership", error)
        try:
            receipt["engine_lane_idle"] = not h.running()
        except BaseException as error:
            cleanup_error(receipt, "query engine lane", error)
        try:
            if receipt["lock_ownership_confirmed"] and receipt["child_process_terminal"] and receipt["engine_lane_idle"]:
                p.fs(h.shared.LOCK).unlink()
                receipt["lock_released"] = not p.fs(h.shared.LOCK).exists()
        except BaseException as error:
            cleanup_error(receipt, "release owned terminal lane", error)
        receipt["complete"] = bool(receipt.get("eight_stages_passed") and receipt.get("final_identity_passed")
            and receipt["child_process_terminal"] and receipt["lock_ownership_confirmed"]
            and receipt["engine_lane_idle"] and receipt["lock_released"]
            and not receipt["cleanup_errors"] and "error" not in receipt)
        receipt["source_flow_chain_passed"] = receipt["complete"]
        receipt["pinned_files"] = pins
        try:
            h.save(p.fs(output / "receipt.json"), receipt)
        except BaseException as error:
            receipt["complete"] = False
            receipt["source_flow_chain_passed"] = False
            cleanup_error(receipt, "persist final receipt", error)
            # If the evidence volume itself failed, retain both original and
            # persistence tracebacks on stdout rather than masking the former.
            print(json.dumps(receipt, ensure_ascii=False), flush=True)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "error": receipt.get("error"),
                      "reports": receipt["reports"], "cleanup_errors": receipt["cleanup_errors"],
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", type=Path, help="New complete Daming freeze with its own successful import")
    parser.add_argument("--run", action="store_true", help="Start eight real processes across two isolated role profiles")
    parser.add_argument("--timeout", type=int, default=1320)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 1200 or args.wait_lane < 0:
        parser.error("Invalid bounded deadline")
    if args.run and args.base_run is None:
        parser.error("--run requires --base-run")
    if args.run:
        execute(args)
        return
    pins = source_pins()
    if args.base_run:
        state = preflight(args.base_run)
        result = {"validation_level": state["validation_level"], "full_source_verified": True,
                  "content_version": state["content_version"], "import_receipts": state["imports"]}
    else:
        prep.lightweight()
        result = {"validation_level": "source_plan_only", "full_source_verified": False,
                  "base_identity": prep.BASE_IDENTITY, "worker_pins": len(pins)}
    print(json.dumps({**result, "roles": ROLES, "modes": MODES, "process_count": 8,
                      "engine_started": False, "lane_acquired": False, "profile_created": False,
                      "native_qualified": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
