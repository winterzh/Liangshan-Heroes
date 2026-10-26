"""Preflight only by default; --run executes three natural Level4 loss processes.

Fresh private profile: actual menu/ordinary paid training/SaveAndExit,
Continue/ordinary Song Jiang movement/natural defeat, then menu refusal. No
production adoption, public Continue, native SDK or human acceptance follows.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve().parent
HERE = QA / "tests/lianhuanma_loss"
WORKERS = ("bootstrap.gd", "base.gd", "terminal.gd", "driver.gd")
MODES = ("save_before_loss", "resume_loss", "reject_terminal")
EXPECTED_FILES = {
    "battle.gd", "campaign.gd", "continue_flow.gd", "menu.gd", "run_world_session.gd", "steam_cloud.gd",
    "run_campaign_cfg_transaction.gd", "run_campaign_cfg_values.gd", "run_campaign_local_lifecycle.gd",
    "run_campaign_progress_coordinator.gd", "run_campaign_progress_gate.gd", "run_campaign_progress_intent.gd",
    "run_campaign_progress_projection.gd", "run_campaign_startup_scan.gd", "run_campaign_legacy_data.gd",
    "steam_run_receipt.gd", "steam_receipt_store.gd", "steam_run_ledger.gd", "steam_local_run_session.gd", "steam_service.gd",
}
spec = importlib.util.spec_from_file_location(
    "lianhuanma_loss_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def preflight(base, manifest_path):
    helper.identity.no_links(base)
    helper.identity.no_links(manifest_path)
    if not base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026") or not manifest_path.is_relative_to(QA):
        raise RuntimeError("Only a local QA candidate and its independent freeze are accepted")
    manifest = helper.read(manifest_path)
    rows = manifest["files"]
    if len(rows) != 20 or {r["path"] for r in rows} != {"scripts/" + n for n in EXPECTED_FILES}:
        raise RuntimeError("Exact twenty-script candidate required")
    pins = {}
    for path in (manifest_path, base / "candidate_manifest.json", base / "preparation.json",
                 base / "root_source.json", base / "generation.json", Path(__file__)):
        pins[str(path)] = helper.sha(path)
    if pins[str(manifest_path)] != pins[str(base / "candidate_manifest.json")]:
        raise RuntimeError("Candidate manifest differs from the actual frozen manifest")
    preparation = helper.read(base / "preparation.json")
    if preparation.get("candidate_manifest_sha256") != pins[str(manifest_path)]:
        raise RuntimeError("Preparation does not bind the requested candidate")
    project = helper.assert_runtime_current(base)
    helper.identity.no_links(project)
    generation = helper.read(base / "generation.json")
    helper.identity.verify_generated(project, generation)
    for row in rows:
        for path in (manifest_path.parent / row["path"], project / row["path"]):
            helper.identity.no_links(path)
            if helper.sha(path) != row["candidate_sha256"]:
                raise RuntimeError("Candidate source mismatch: " + row["path"])
            pins[str(path)] = row["candidate_sha256"]
    for module in (helper, helper.common, helper.shared, helper.identity):
        pins[str(Path(module.__file__))] = helper.sha(module.__file__)
    running_helper = ROOT / "tools/run_campaign_level_state_qa.py"
    pins[str(running_helper)] = helper.sha(running_helper)
    for name in WORKERS:
        helper.identity.no_links(HERE / name)
        pins[str(HERE / name)] = helper.sha(HERE / name)
    provenance_path = HERE / "provenance.json"
    helper.identity.no_links(provenance_path)
    provenance = helper.read(provenance_path)
    expected_inputs = {str(path.relative_to(ROOT)).replace("\\", "/")
                       for path in (Path(__file__).resolve(), HERE / "README.md", *(HERE / name for name in WORKERS))}
    provenance_rows = provenance.get("files", [])
    if (provenance.get("schema") != "lianhuanma_loss_external_sources_v1"
            or len(provenance_rows) != len(expected_inputs)
            or {row.get("path") for row in provenance_rows} != expected_inputs):
        raise RuntimeError("Exact independent loss source provenance required")
    for row in provenance_rows:
        path = ROOT / row["path"]
        helper.identity.no_links(path)
        if helper.sha(path) != row["sha256"]:
            raise RuntimeError("Independent loss source changed: " + row["path"])
        pins[str(path)] = row["sha256"]
    pins[str(provenance_path)] = helper.sha(provenance_path)
    engine = helper.shared.resolve_godot(None)
    return {"project": project, "engine": engine, "pins": pins,
            "candidate_manifest_sha256": pins[str(manifest_path)], "engine_sha256": helper.sha(engine),
            "provenance_sha256": pins[str(provenance_path)],
            "content_version": "source-v1:" + generation["identity"]["source_sha256"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--candidate-manifest", required=True, type=Path)
    parser.add_argument("--run", action="store_true", help="Explicitly start the three native processes")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 120 or args.wait_lane < 0:
        raise ValueError("Invalid bounded deadline")
    helper.identity.no_links(args.base_run.absolute())
    helper.identity.no_links(args.candidate_manifest.absolute())
    base, manifest_path = args.base_run.resolve(), args.candidate_manifest.resolve()
    initial = preflight(base, manifest_path)
    if not args.run:
        print(json.dumps({"preflight_passed": True, "engine_started": False, "lane_acquired": False,
                          "native_qualified": False, "modes": MODES,
                          "content_version": initial["content_version"],
                          "candidate_manifest_sha256": initial["candidate_manifest_sha256"],
                          "worker_sha256": {name: initial["pins"][str(HERE / name)] for name in WORKERS}}, indent=2))
        return
    output = ROOT / ".godot/lianhuanma_natural_loss_20261026" / helper.stamp()
    helper.identity.no_links(output)
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "lianhuanma_natural_loss_three_process_v1", "complete": False,
               "execution_kind": "source_project_offscreen_gl", "base_run": str(base),
               "candidate_manifest": str(manifest_path), "candidate_manifest_sha256": initial["candidate_manifest_sha256"],
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": helper.sha(__file__), "provenance_sha256": initial["provenance_sha256"],
               "steps": [], "reports": [], "attempted_modes": [],
               "natural_loss_required": True, "native_sdk_qualified": False, "public_continue_qualified": False,
               "human_acceptance": False, "native_release_tested": False, "victory_chain_qualified": False}
    owner, locked = str(output), False
    project, engine = initial["project"], initial["engine"]
    pins = initial["pins"]
    try:
        started, last_notice = time.monotonic(), time.monotonic() - 25
        while not locked:
            if not helper.shared.LOCK.exists() and not helper.running():
                try:
                    with helper.shared.LOCK.open("x", encoding="utf-8") as handle: handle.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            if time.monotonic() - started >= args.wait_lane:
                raise RuntimeError("Shared engine occupied; no child started")
            if time.monotonic() - last_notice >= 25:
                print("WAIT shared engine; no child started", flush=True)
                last_notice = time.monotonic()
            time.sleep(1)
        if helper.running(): raise RuntimeError("Engine appeared before native preflight")
        helper.suite_verify_pins(pins)
        current = preflight(base, manifest_path)
        if current != initial: raise RuntimeError("Candidate or engine changed while awaiting lane")
        receipt.update(content_version=initial["content_version"], engine_sha256=initial["engine_sha256"],
                       project=str(project), initial_identity_passed=True)
        workers = output / "workers"
        workers.mkdir()
        for name in WORKERS:
            digest = pins[str(HERE / name)]
            helper.copy_checked(HERE / name, workers / name, digest)
            pins[str(workers / name)] = digest
        bindings = workers / "bindings.json"
        helper.save(bindings, {name: pins[str(workers / name)] for name in WORKERS})
        pins[str(bindings)] = helper.sha(bindings)
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/lhmloss" / nonce[:12]
        helper.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = helper.common.private_environment(profile)
        env["CAMPAIGN_QA"] = ""
        for key in list(env):
            if key.startswith(("LL_", "LT_", "LR_", "CR_", "HG_", "CH_", "LHMR_")): env.pop(key)
        env.update(LSH_CONTINUE_FLOW_QA="1", LSH_CONTINUE_FLOW_PROFILE=str(profile),
                   LL_PROFILE=str(profile), LL_PROJECT=str(project), LL_WORKERS=str(workers), LL_BINDINGS=str(bindings),
                   LL_BINDINGS_SHA256=pins[str(bindings)], LL_NONCE=nonce,
                   LL_CANDIDATE_SHA256=initial["candidate_manifest_sha256"],
                   LL_PROVENANCE_SHA256=initial["provenance_sha256"], LSH_LANGUAGE="zh_CN")
        receipt.update(profile=str(profile), batch_nonce=nonce)
        previous, pids, process_nonces = None, set(), set()
        for mode in MODES:
            helper.suite_verify_pins(pins)
            stage = output / mode
            stage.mkdir()
            report_path = stage / "report.json"
            process_nonce = uuid.uuid4().hex
            stage_env = dict(env, LL_MODE=mode, LL_REPORT=str(report_path), LL_PROCESS_NONCE=process_nonce)
            if previous: stage_env.update(LL_PREVIOUS=str(previous), LL_PREVIOUS_SHA256=pins[str(previous)])
            report = None
            receipt["attempted_modes"].append(mode)
            try:
                helper.common.process_step(engine, project, stage_env, stage, mode,
                                           ["--resolution", "1280x720", "--position", "30000,30000",
                                            "--script", str(workers / "bootstrap.gd")],
                                           args.timeout, "gl_compatibility", helper.running, receipt["steps"])
            finally:
                log_path = stage / (mode + ".log")
                if log_path.is_file(): pins[str(log_path)] = helper.sha(log_path)
                if report_path.is_file():
                    pins[str(report_path)] = helper.sha(report_path)
                    report = helper.read(report_path)
                    receipt["reports"].append({"mode": mode, "path": str(report_path), "sha256": pins[str(report_path)],
                                               "checks": len(report.get("checks", [])), "passed": report.get("passed", False),
                                               "failures": report.get("failures", [])})
            if (report is None or report.get("schema") != "campaign_lianhuanma_loss_v1"
                    or report.get("passed") is not True or report.get("stage_completed") is not True
                    or report.get("failures") or not report.get("checks")
                    or any(row.get("passed") is not True for row in report["checks"])):
                raise RuntimeError("Native route failed or incomplete: " + mode)
            if (report.get("mode") != mode or report.get("batch_nonce") != nonce
                    or report.get("process_nonce") != process_nonce or process_nonce in process_nonces
                    or report.get("profile") != str(profile) or report.get("slot_root") != "user://continue/v1"
                    or report.get("candidate_manifest_sha256") != initial["candidate_manifest_sha256"]
                    or report.get("provenance_sha256") != initial["provenance_sha256"]
                    or report.get("identity", {}).get("content_version") != receipt["content_version"]
                    or report["identity"].get("engine_sha256") != receipt["engine_sha256"]
                    or report["identity"].get("source_mode") is not True
                    or report.get("simulation_time_scale") != 1 or report.get("natural_loss_required") is not True):
                raise RuntimeError("Native process/source/profile contract changed: " + mode)
            if mode == "save_before_loss" and (
                    report.get("save_exit_observed") is not True or report.get("exit_reason") != "continue_saved"):
                raise RuntimeError("Save did not use production SaveAndExit: " + mode)
            step = receipt["steps"][-1]
            pid = report.get("pid")
            if pid != step.get("pid") or pid in pids or step.get("log_sha256") != pins[str(log_path)]:
                raise RuntimeError("PID or terminal log evidence changed")
            pids.add(pid)
            process_nonces.add(process_nonce)
            previous = report_path
        receipt["three_stages_passed"] = len(pids) == 3 and len(process_nonces) == 3
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        try:
            helper.assert_runtime_current(base)
            helper.identity.verify_generated(project, helper.read(base / "generation.json"))
            helper.suite_verify_pins(pins)
            if helper.sha(engine) != initial["engine_sha256"]: raise RuntimeError("Engine bytes changed")
            receipt["final_identity_passed"] = True
        except BaseException as error:
            receipt["final_identity_passed"] = False
            receipt["final_identity_error"] = repr(error)
        receipt["child_process_terminal"] = len(receipt["steps"]) == len(receipt["attempted_modes"]) and all(
            step.get("pid") is None or step.get("exit_code") is not None for step in receipt["steps"])
        receipt["lock_ownership_confirmed"] = bool(locked and helper.shared.LOCK.is_file()
            and helper.shared.LOCK.read_text(encoding="utf-8") == owner)
        if receipt["lock_ownership_confirmed"] and receipt["child_process_terminal"]: helper.shared.LOCK.unlink()
        receipt["lock_released"] = bool(locked and not helper.shared.LOCK.exists())
        receipt["complete"] = bool(receipt.get("three_stages_passed") and receipt.get("final_identity_passed")
                                   and receipt["child_process_terminal"] and receipt["lock_ownership_confirmed"]
                                   and receipt["lock_released"] and "error" not in receipt)
        receipt["pinned_files"] = pins
        helper.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "error": receipt.get("error"),
                      "reports": receipt["reports"], "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]: raise SystemExit(1)


if __name__ == "__main__":
    main()
