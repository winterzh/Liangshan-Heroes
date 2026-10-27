"""52 original Daming negative processes against a completed same-source eight-Flow fixture.

Default: named small-source checks only. --flow-receipt also checks immutable
producer evidence. --run additionally requires a full new freeze/own first cold
import, acquires the shared engine lane, and creates 52 private GL profiles.
This does not grant the other original 19 fault stages or full 61 qualification.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import time
import traceback
import uuid
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("daming_negative_plan", HERE / "plan_negative.py")
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
p, h, prep, require, ROOT = a.p, a.h, a.prep, a.require, a.ROOT
WIDER_FLAGS = ("full_61_qualified", "original_19_faults_qualified", "native_sdk_qualified",
               "public_continue_qualified", "native_release_tested", "human_acceptance", "published")


def source_pins():
    a.static_plan()
    document = a.document(HERE / "sources.json")
    pins = {}
    for row in document["files"] + document["dependencies"]:
        p.pin(ROOT / row["path"], pins, row["sha256"])
    for row in a.document(HERE / "case_plan.json")["historical_sources"]:
        p.pin(ROOT / row["path"], pins, row["sha256"])
    for module in (a, prep, p, h, h.common, h.shared, h.identity, a.fixture):
        p.pin(Path(module.__file__), pins)
    p.pin(HERE / "sources.json", pins)
    return pins


def admits(flow_receipt):
    # This rejects failed/partial/old-source evidence before any output/profile/lock.
    return {role: a.admit_closed_a(flow_receipt, role) for role in ("lu", "shi")}


def preflight(base_run, inputs):
    state = prep.prepared_state(base_run)
    require(state["validation_level"] == "full_new_freeze_and_own_import" and state["cold_import_qualified"] is True
            and state["run_base"] == Path(base_run).resolve() and state["project"] == state["run_base"] / "project",
            "Full new freeze and own first cold import admission required")
    manifest = a.document(state["run_base"] / "candidate_manifest.json")
    require(manifest.get("schema") == "projectile_3365_integrated_manifest_v1"
            and len(manifest.get("files", [])) == 26 and len(manifest.get("native_assets", [])) == 1,
            "Exact 26-script/native manifest")
    manifest_sha = a.pin(state["run_base"] / "candidate_manifest.json")["sha256"]
    for role, request in inputs.items():
        require(request["base_run"] == str(state["run_base"]) and request["project"] == str(state["project"])
                and request["content_version"] == state["content_version"]
                and request["engine_sha256"] == state["engine_sha256"]
                and request["candidate_manifest_sha256"] == manifest_sha
                and [request["cold_import_receipt"]["path"]] == state["imports"],
                "Producer and consumer exact same new source/cold import: " + role)
        prep.merge_pins(state["pins"], request["producer_evidence_pins"])
        for key in ("flow_receipt", "closed_a_descriptor", "a_report", "a_log", "slot", "lifecycle", "producer_terminal_report", "cold_import_receipt"):
            row = request[key]
            p.pin(Path(row["path"]), state["pins"], row["sha256"])
    prep.merge_pins(state["pins"], source_pins())
    # These are named installed script pins, not a fabricated identity or DTO.
    names = set(re.findall(r'res://scripts/[A-Za-z0-9_]+\.gd', a.raw(HERE / "component_worker.gd").decode("utf-8")))
    for name in ("run_level8_world_factory", "run_content_identity", "run_campaign_progress_gate", "run_battle_barrier"):
        names.add("res://scripts/" + name + ".gd")
    generation_files = {row["path"]: row for row in state["generation"]["identity"]["files"]}
    source_map = {}
    for name in sorted(names):
        relative = name.removeprefix("res://")
        row = generation_files[relative]
        digest = row["sha256"] if isinstance(row, dict) else row
        p.pin(state["project"] / relative, state["pins"], digest)
        source_map[name] = digest
    state["component_source_pins"] = source_map
    p.verify_pins(state["pins"])
    return state


def environment(profile, state, workers, request_path, request, stage):
    env = h.common.private_environment(profile)
    for key in list(env):
        if key.startswith(("DN_", "DF_", "GT_", "GVT_", "GLS_", "LL_", "LT_", "CB_", "CC_", "CT_", "SC_", "CR_", "HG_", "LHMR_", "MR_", "LR_", "RS_", "LSH_CONTINUE_FLOW_", "DAMING_")):
            env.pop(key)
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        require(env.get(key) == str(profile / key.lower()), "Private environment escaped")
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", LSH_CONTINUE_FLOW_QA="", LSH_LANGUAGE="zh_CN",
               DN_PROFILE=str(profile), DN_PROJECT=str(state["project"]), DN_WORKERS=str(workers),
               DN_REQUEST=str(request_path), DN_REQUEST_SHA256=a.pin(request_path)["sha256"],
               DN_BATCH_NONCE=request["consumer_batch_nonce"], DN_PROCESS_NONCE=request["consumer_process_nonce"],
               DN_FAMILY=request["family"], DN_CASE=request["case"], DN_OUTPUT=str(stage),
               DN_EVIDENCE=str(stage / "evidence"), DN_REPORT=str(stage / "report.json"))
    return env


def clone_fixture(profile, request):
    descriptor = a.document(request["closed_a_descriptor"]["path"])
    # Fixed production application name is checked again against OS.get_user_data_dir by the worker.
    target = profile / "appdata/Godot/app_userdata/水浒英雄传：八幕战役/continue/v1"
    h.identity.no_links(p.fs(target))
    p.fs(target).mkdir(parents=True, exist_ok=False)
    inventory = descriptor["frozen_inventory"]
    source = Path(descriptor["frozen_scope"])
    for relative in sorted(inventory["directories"], key=lambda s: (s.count("/"), s)):
        p.fs(target / relative).mkdir(exist_ok=False)
    for relative, row in inventory["files"].items():
        p.copy(source / relative, target / relative, row["sha256"])
    require(a.fixture.inventory(target, p) == inventory, "Private copy is complete raw original two-file/six-directory tree")
    return target, inventory


def validate_report(report, request, step, stage, state, seen):
    require(type(report) is dict and report.get("schema") == "daming_negative_stage_report_v2"
            and report.get("passed") is True and report.get("checks")
            and all(row.get("passed") is True for row in report["checks"]), "Native negative stage failed")
    require(report.get("family") == request["family"] and report.get("case") == request["case"]
            and report.get("first_role") == request["first_role"] and report.get("profile") == request["consumer_profile"]
            and report.get("batch_nonce") == request["consumer_batch_nonce"]
            and report.get("process_nonce") == request["consumer_process_nonce"]
            and report.get("request_sha256") == a.pin(stage / "request.json")["sha256"]
            and report.get("worker_bindings") == request["worker_bindings"]
            and report.get("source_pins") == state["component_source_pins"]
            and report.get("identity", {}).get("content_version") == state["content_version"]
            and report.get("identity", {}).get("engine_binary_sha256") == state["engine_sha256"]
            and report.get("identity", {}).get("source_mode") is True
            and all(report.get(k) is True for k in ("fixture_admission_passed", "native_slot_decode_called",
                "native_lifecycle_decode_called", "producer_terminal_document_validate_called"))
            and all(report.get(k) is False for k in WIDER_FLAGS), "Native source/role/profile/scope report binding")
    pid = report.get("pid")
    require(type(pid) is int and pid > 0 and pid not in seen and pid == step.get("pid")
            and type(step.get("exit_code")) is int and step["exit_code"] == 0 and step.get("passed") is True
            and step.get("errors") == [] and step.get("stopped_for") is None
            and step.get("log_sha256") == a.pin(stage / "negative.log")["sha256"], "Actual distinct terminal Popen/log")
    seen.add(pid)
    # Complete raw per-row audit artifacts remain local and are individually pinned.
    for row in report.get("evidence", []):
        path = Path(row["path"])
        require(path.parent == stage / "evidence" and a.pin(path)["sha256"] == row["sha256"],
                "Exact private per-row raw evidence")
    family = request["family"]
    if family in ("world", "component"):
        count = 132 if family == "world" else 181
        specs = report.get("planned_cases") if family == "world" else report.get("planned_specs")
        expected_names = specs if family == "world" else [row["id"] for row in specs]
        require(type(specs) is list and len(specs) == len(set(expected_names)) == count, "Exact original case cardinality")
        rows = report.get("executed_rows", [])
        row_key = "case" if family == "world" else "id"
        require(len(rows) == count * 2 and {(row[row_key], row["route"]) for row in rows}
                == {(name, route) for name in expected_names for route in ("source", "json")}
                and all(row.get("passed") is True for row in rows), "Both original actual routes for every spec")
        require(report.get("pure_matrix_passed") is True
                and report.get("matrix_complete" if family == "world" else "component_matrix_complete") is True,
                "Actual whole matrix complete")
        positives = report.get("positives", [])
        require(len(positives) == (2 if family == "world" else 8), "Original positive-control cardinality")
        require(all(row.get("expected_code") == row.get("actual_code") for row in rows), "Exact original expected refusals")
        if family == "world":
            require(all(all(row.get(k) is True for k in ("actual_A_unmodified", "prepared", "detached_inert", "input_exact", "disposed_zero"))
                        for row in positives), "Actual complete world positive controls")
        if family == "component":
            require(report.get("actual_Core_prepare_calls") == 0 and report.get("actual_Core_capture_calls") == 0
                    and all(row.get("passed") is True for row in positives), "Independent direct components, no substitution")
    else:
        row = report.get("executed_live_row", {})
        require(report.get("row_completed") is True and report.get("actual_Core_capture_called") is True
                and report.get("actual_live_object_capture") is True and report.get("actual_session_install") is True
                and row.get("passed") is True and row.get("case") == request["case"]
                and row.get("expected_code") == request["expected_code"], "Actual restored HELD Core.capture negative row")
        require(report.get("planned_cases") == 24 and set(report.get("implemented_cases", []))
                == set(a.document(HERE / "case_plan.json")["capture"]["cases"]), "All original capture declarations retained")


def execute(args):
    plan = a.static_plan()
    inputs = admits(args.flow_receipt)  # No partial producer may create even a test profile.
    output = ROOT / ".godot/daming_negative_v2_20261027" / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {"schema":"daming_negative_52_process_v2", "complete":False, "base_run":str(args.base_run.resolve()),
               "flow_receipt":str(args.flow_receipt.resolve()), "steps":[], "reports":[], "attempts":[],
               "cleanup_errors":[], "negative_52_passed":False, **{key:False for key in WIDER_FLAGS}}
    pins, state, locked, owner = source_pins(), None, False, str(output)
    profiles = []
    try:
        start = time.monotonic()
        while not locked:
            if not p.fs(h.shared.LOCK).exists() and not h.running():
                try:
                    with p.fs(h.shared.LOCK).open("x", encoding="utf-8") as stream: stream.write(owner)
                    locked = True
                    break
                except FileExistsError: pass
            require(time.monotonic() - start < args.wait_lane, "Shared engine lane occupied; no child started")
            time.sleep(1)
        require(not h.running(), "Engine appeared before full admission")
        state = preflight(args.base_run, inputs)
        pins = state["pins"]
        receipt.update(project=str(state["project"]), content_version=state["content_version"],
            engine_sha256=state["engine_sha256"], import_receipts=state["imports"], cold_import_qualified=True,
            initial_identity_passed=True, candidate_script_count=26, native_asset_count=1)
        for name, digest in list(pins.items()):
            source = Path(name)
            if source.suffix.lower() == ".exe": continue
            require(source.is_relative_to(ROOT), "External named source outside root")
            target = output / "runner_inputs" / source.relative_to(ROOT)
            p.copy(source, target, digest); p.pin(target, pins, digest)
        workers = output / "workers"; p.fs(workers).mkdir()
        for name in a.WORKERS:
            p.copy(HERE / name, workers / name, pins[str(HERE / name)]); p.pin(workers / name, pins)
        batch = uuid.uuid4().hex
        receipt["batch_nonce"] = batch
        seen = set()
        for index, planned in enumerate(plan):
            p.verify_pins(pins)
            role, family = planned["first_role"], planned["family"]
            case = planned.get("case", "")
            stage = output / (str(index + 1).zfill(2) + "_" + role + "_" + family + ("_" + case if case else ""))
            p.fs(stage).mkdir()
            profile = Path(ROOT.anchor) / "CodexQA/dn52" / batch[:12] / str(index + 1).zfill(2)
            h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
            request = copy.deepcopy(inputs[role])
            request.update(family=family, case=case, expected_code=planned.get("expected_code", ""),
                consumer_batch_nonce=batch, consumer_process_nonce=uuid.uuid4().hex,
                consumer_profile=str(profile), source_pins=state["component_source_pins"])
            request_path = stage / "request.json"; h.save(p.fs(request_path), request); p.pin(request_path, pins)
            env = environment(profile, state, workers, request_path, request, stage)
            private_scope, expected = clone_fixture(profile, request)
            profiles.append((private_scope, expected))
            attempt = {"index":index + 1, "first_role":role, "family":family, "case":case,
                       "profile":str(profile), "process_nonce":request["consumer_process_nonce"]}
            receipt["attempts"].append(attempt)
            before = len(receipt["steps"])
            try:
                h.common.process_step(state["engine"], state["project"], env, p.fs(stage), "negative",
                    ["--resolution","1280x720","--position","30000,30000","--script",str(workers / "bootstrap.gd")],
                    args.timeout, "gl_compatibility", h.running, receipt["steps"])
            finally:
                if len(receipt["steps"]) == before + 1: receipt["steps"][-1].update(attempt)
                for name in ("negative.log", "report.json"):
                    if p.fs(stage / name).is_file(): p.pin(stage / name, pins)
                if p.fs(stage / "report.json").is_file():
                    report = a.document(stage / "report.json")
                    receipt["reports"].append({**attempt, "path":str(stage / "report.json"),
                        "sha256":pins[str(stage / "report.json")], "passed":report.get("passed",False),
                        "checks":len(report.get("checks", []))})
            require(len(receipt["steps"]) == before + 1, "One terminal child step per attempted stage")
            report = a.document(stage / "report.json")
            validate_report(report, request, receipt["steps"][-1], stage, state, seen)
            for row in report.get("evidence", []): p.pin(Path(row["path"]), pins, row["sha256"])
            require(a.fixture.inventory(private_scope, p) == expected, "Private source records/directories changed")
            p.verify_pins(pins)
            print("PASS", index + 1, role, family, case, "checks", len(report["checks"]), flush=True)
        require(len(seen) == len(receipt["reports"]) == len(receipt["steps"]) == 52, "52 actual distinct complete processes")
        receipt["negative_52_passed"] = True
    except BaseException as error:
        receipt.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        try:
            require(state is not None, "Full native admission incomplete")
            h.assert_runtime_current(state["run_base"])
            h.identity.verify_generated(state["project"], state["generation"])
            p.verify_pins(pins)
            for scope, expected in profiles:
                require(a.fixture.inventory(scope, p) == expected, "A private cloned business tree changed")
            require(h.sha(p.fs(state["engine"])) == state["engine_sha256"], "Actual engine changed")
            receipt["final_identity_passed"] = True
        except BaseException as error:
            receipt["final_identity_passed"] = False
            receipt["cleanup_errors"].append({"phase":"final_identity", "error":repr(error), "traceback":traceback.format_exc()})
        receipt["child_process_terminal"] = len(receipt["steps"]) == len(receipt["attempts"]) and all(
            type(row.get("pid")) is int and row["pid"] > 0 and type(row.get("exit_code")) is int for row in receipt["steps"])
        receipt.update(lock_ownership_confirmed=False, engine_lane_idle=False, lock_released=False)
        try:
            receipt["lock_ownership_confirmed"] = bool(locked and p.fs(h.shared.LOCK).is_file()
                and p.fs(h.shared.LOCK).read_text(encoding="utf-8") == owner)
            receipt["engine_lane_idle"] = not h.running()
            if receipt["lock_ownership_confirmed"] and receipt["engine_lane_idle"] and receipt["child_process_terminal"]:
                p.fs(h.shared.LOCK).unlink(); receipt["lock_released"] = not p.fs(h.shared.LOCK).exists()
        except BaseException as error:
            receipt["cleanup_errors"].append({"phase":"owned_lock_terminal", "error":repr(error)})
        receipt["complete"] = bool(receipt["negative_52_passed"] and receipt.get("final_identity_passed")
            and receipt["child_process_terminal"] and receipt["lock_ownership_confirmed"] and receipt["engine_lane_idle"]
            and receipt["lock_released"] and not receipt["cleanup_errors"] and "error" not in receipt)
        receipt["actual_process_count"] = len(receipt["steps"])
        receipt["pinned_files"] = pins
        h.save(p.fs(output / "receipt.json"), receipt)
    print(json.dumps({"output":str(output), "complete":receipt["complete"], "actual_processes":len(receipt["steps"]),
                      "lock_released":receipt["lock_released"], "error":receipt.get("error")},ensure_ascii=False),flush=True)
    if not receipt["complete"]: raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flow-receipt", type=Path, help="Actual complete b22 eight-stage Flow receipt")
    parser.add_argument("--base-run", type=Path, help="The exact same new freeze with its own first cold import")
    parser.add_argument("--run", action="store_true", help="Explicitly start 52 actual processes after full admission")
    parser.add_argument("--timeout", type=int, default=420)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 120 or args.wait_lane < 0: parser.error("Invalid bounded deadline")
    if args.run and (args.flow_receipt is None or args.base_run is None): parser.error("--run needs --flow-receipt and --base-run")
    if args.run: execute(args); return
    pins = source_pins()
    inputs = admits(args.flow_receipt) if args.flow_receipt else None
    if args.base_run:
        require(inputs is not None, "Full preflight requires successful actual eight-Flow evidence")
        state = preflight(args.base_run, inputs)
    else: state = None
    print(json.dumps({"planned_processes":52,"world_processes":2,"component_processes":2,"capture_gl_processes":48,
        "named_pins":len(pins),"same_source_eight_flow_admitted":inputs is not None,
        "full_source_verified":state is not None,"cold_import_qualified":state is not None,
        "engine_started":False,"profile_created":False,"negative_52_passed":False,"full_61_qualified":False},ensure_ascii=False))

if __name__ == "__main__": main()
