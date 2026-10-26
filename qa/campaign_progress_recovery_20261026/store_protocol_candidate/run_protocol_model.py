"""Run only synthetic unique-release models in a separately imported candidate.

Adapted from the verified campaign run_model.py identity/profile/lock protocol.
No Store transaction, crash injection, real SDK qualification or player entry.
The base run must bind this directory's independent twenty-file manifest.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
CANDIDATE = HERE / "integrated_candidate"
MODE = "protocol_model"
EXPECTED_CHECKS = 14
spec = importlib.util.spec_from_file_location(
    "steam_protocol_model_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def bind_candidate(base, project, pins):
    manifest_path = CANDIDATE / "manifest.json"
    manifest_hash = helper.sha(manifest_path)
    manifest = helper.read(manifest_path)
    preparation = helper.read(base / "preparation.json")
    if (helper.sha(base / "candidate_manifest.json") != manifest_hash
            or preparation.get("candidate_manifest_sha256") != manifest_hash):
        raise RuntimeError("Freeze does not bind this independent Store candidate")
    rows = manifest["files"]
    if len(rows) != 20 or len({r["path"] for r in rows}) != 20:
        raise RuntimeError("Exact twenty-file candidate required")
    if manifest.get("revision_changes") != ["scripts/steam_receipt_store.gd"]:
        raise RuntimeError("Unexpected integration scope")
    for row in rows:
        name = row["path"]
        if not name.startswith("scripts/") or len(Path(name).parts) != 2 or not name.endswith(".gd"):
            raise RuntimeError("Unsafe candidate member")
        for path in (CANDIDATE / name, project / name):
            helper.identity.no_links(path)
            if helper.sha(path) != row["candidate_sha256"]:
                raise RuntimeError("Candidate bytes changed: " + name)
            pins[str(path)] = row["candidate_sha256"]
    pins[str(manifest_path)] = manifest_hash
    return manifest_hash


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=360)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    base = args.base_run.resolve()
    if not base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"):
        raise RuntimeError("An existing local candidate freeze is required")
    helper.identity.no_links(base)
    if args.timeout < 60 or args.wait_lane < 0:
        raise ValueError("Invalid bounded timeout")
    output = ROOT / ".godot/steam_store_protocol_model_20261026" / helper.stamp()
    helper.identity.no_links(output)
    output.mkdir(parents=True, exist_ok=False)
    receipt = {
        "schema": "steam_store_protocol_model_run_v1", "complete": False,
        "execution_kind": "source_project_headless_synthetic_model", "base_run": str(base),
        "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "runner_sha256": helper.sha(__file__), "steps": [], "reports": [],
        "synthetic_model_only": True, "native_io_exercised": False, "sdk_qualified": False,
        "original_release_gui_tested": False, "public_continue_qualified": False,
        "prior_qualification_inherited": False,
    }
    owner, locked = str(output), False
    project, engine = None, None
    pins = {}
    try:
        started = time.monotonic()
        last_notice = started - 25
        while not locked:
            if not helper.shared.LOCK.exists() and not helper.running():
                try:
                    with helper.shared.LOCK.open("x", encoding="utf-8") as handle:
                        handle.write(owner)
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
        if helper.running():
            raise RuntimeError("Engine appeared before preflight")
        for path in [base / name for name in (
                "preparation.json", "root_source.json", "generation.json", "candidate_manifest.json")]:
            pins[str(path)] = helper.sha(path)
        for module in (helper, helper.common, helper.shared, helper.identity):
            path = Path(module.__file__)
            pins[str(path)] = helper.sha(path)
        # running_engine is imported by the shared helper from this module.
        level_helper = ROOT / "tools/run_campaign_level_state_qa.py"
        pins[str(level_helper)] = helper.sha(level_helper)
        pins[str(Path(__file__))] = helper.sha(__file__)
        project = helper.assert_runtime_current(base)
        helper.identity.no_links(project)
        generation = helper.read(base / "generation.json")
        helper.identity.verify_generated(project, generation)
        manifest_hash = bind_candidate(base, project, pins)
        engine = helper.shared.resolve_godot(None)
        receipt.update(project=str(project), engine_sha256=helper.sha(engine),
                       candidate_manifest_sha256=manifest_hash,
                       content_version="source-v1:" + generation["identity"]["source_sha256"],
                       initial_identity_passed=True)
        workers = output / "workers"
        workers.mkdir()
        worker_rows = []
        for name in ("protocol_bootstrap.gd", "protocol_worker.gd", "protocol_model.gd"):
            source = HERE / "tests" / name
            digest = helper.sha(source)
            helper.copy_checked(source, workers / name, digest)
            pins[str(source)] = digest
            pins[str(workers / name)] = digest
            worker_rows.append({"path": name, "sha256": digest})
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/stmodel" / nonce[:12]
        helper.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = helper.common.private_environment(profile)
        env["CAMPAIGN_QA"] = ""
        for key in list(env):
            if key.startswith(("SPM_", "MR_", "LR_", "HG_")):
                env.pop(key)
        model_hash = helper.sha(workers / "protocol_model.gd")
        worker_hash = helper.sha(workers / "protocol_worker.gd")
        stage = output / MODE
        stage.mkdir()
        report_path = stage / "report.json"
        env.update(SPM_PROFILE=str(profile), SPM_PROJECT=str(project), SPM_WORKERS=str(workers),
                   SPM_WORKER_SHA256=worker_hash, SPM_MODEL_SHA256=model_hash, SPM_NONCE=nonce,
                   SPM_MODE=MODE, SPM_REPORT=str(report_path), SPM_CANDIDATE_MANIFEST_SHA256=manifest_hash)
        receipt.update(profile=str(profile), batch_nonce=nonce, workers=worker_rows,
                       campaign_qa_suppression=False)
        helper.suite_verify_pins(pins)
        report = None
        receipt["engine_step_attempted"] = True
        try:
            helper.common.process_step(engine, project, env, stage, MODE,
                                       ["--headless", "--script", str(workers / "protocol_bootstrap.gd")],
                                       args.timeout, "gl_compatibility", helper.running, receipt["steps"])
        finally:
            log_path = stage / (MODE + ".log")
            if log_path.is_file():
                pins[str(log_path)] = helper.sha(log_path)
                if receipt["steps"] and pins[str(log_path)] != receipt["steps"][-1].get("log_sha256"):
                    raise RuntimeError("Terminal model log bytes changed")
            if report_path.is_file():
                report = helper.read(report_path)
                pins[str(report_path)] = helper.sha(report_path)
                receipt["reports"].append({"mode": MODE, "path": str(report_path),
                                           "sha256": pins[str(report_path)], "checks": len(report.get("checks", [])),
                                           "passed": report.get("passed", False), "failures": report.get("failures", [])})
        if report is None:
            raise RuntimeError("Protocol model report missing")
        checks = report.get("checks", [])
        if (report.get("schema") != "steam_unique_release_model_v1" or report.get("passed") is not True
                or report.get("failures") or report.get("mode") != MODE or len(checks) != EXPECTED_CHECKS
                or any(row.get("passed") is not True for row in checks)):
            raise RuntimeError("Protocol model report failed")
        if (report.get("synthetic_model_only") is not True or report.get("native_io_exercised") is not False
                or report.get("sdk_qualified") is not False or report.get("synthetic_account_and_token") is not True):
            raise RuntimeError("Synthetic-only evidence boundary changed")
        if (report.get("batch_nonce") != nonce or report.get("profile") != str(profile)
                or report.get("model_sha256") != model_hash or report.get("worker_sha256") != worker_hash
                or report.get("candidate_manifest_sha256") != manifest_hash
                or report.get("identity", {}).get("content_version") != receipt["content_version"]
                or report["identity"].get("engine_sha256") != receipt["engine_sha256"]
                or report["identity"].get("source_mode") is not True
                or report.get("pid") != receipt["steps"][-1].get("pid")):
            raise RuntimeError("Protocol report process/source/profile mismatch")
        receipt["model_stage_passed"] = True
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        if project is not None:
            try:
                helper.assert_runtime_current(base)
                helper.identity.verify_generated(project, helper.read(base / "generation.json"))
                helper.suite_verify_pins(pins)
                if engine is not None and helper.sha(engine) != receipt["engine_sha256"]:
                    raise RuntimeError("Engine bytes changed")
                receipt["final_identity_passed"] = True
            except BaseException as error:
                receipt["final_identity_passed"] = False
                receipt["final_identity_error"] = repr(error)
        # An exception before process_step appends its terminal row cannot be
        # treated as proof that a possibly launched child has stopped.
        receipt["child_process_terminal"] = bool(
            not receipt.get("engine_step_attempted", False)
            or (len(receipt["steps"]) == 1 and all(
                row.get("pid") is None or row.get("exit_code") is not None for row in receipt["steps"])))
        receipt["lock_ownership_confirmed"] = bool(
            locked and helper.shared.LOCK.is_file()
            and helper.shared.LOCK.read_text(encoding="utf-8") == owner)
        receipt["complete"] = bool(receipt.get("model_stage_passed") and receipt.get("final_identity_passed")
                                   and receipt["child_process_terminal"] and receipt["lock_ownership_confirmed"]
                                   and "error" not in receipt)
        if receipt["lock_ownership_confirmed"] and receipt["child_process_terminal"]:
            helper.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not helper.shared.LOCK.exists()
        receipt["complete"] = bool(receipt["complete"] and receipt["lock_released"])
        receipt["pinned_files"] = pins
        helper.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"],
                      "error": receipt.get("error"), "reports": receipt["reports"],
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
