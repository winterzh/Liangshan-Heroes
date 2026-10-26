"""Reproduce two known logic defects, or verify their fixes, on an imported freeze.

This runs a real Receipt reducer and LocalSession with a synthetic memory Ledger.
--expect defects means a complete run confirms defects, never candidate acceptance.
No real SDK, filesystem transaction, Battle, desktop input or release is qualified.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[5]
CANDIDATE = HERE.parents[1]
WORKERS = ("bootstrap.gd", "worker.gd", "receipt_case.gd", "session_case.gd")
UNVERIFIED = ("original_release_gui_tested", "public_continue_qualified", "real_steam",
              "os_input", "human_acceptance", "performance_acceptance", "published",
              "candidate_runtime_qualified", "filesystem_transaction_qualified")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--expect", choices=("defects", "fixed"), default="defects")
    parser.add_argument("--historical-freeze", action="store_true",
                        help="Permit changed current candidate; frozen project must exactly match its original twenty-file manifest")
    parser.add_argument("--timeout", type=int, default=360)
    parser.add_argument("--wait-lane", type=int, default=1800)
    args = parser.parse_args()
    require(60 <= args.timeout <= 3600 and 0 <= args.wait_lane <= 86400, "Invalid bounded timeout")
    path = ROOT / "qa/huangnigang_production_20261020/run_batch.py"
    spec = importlib.util.spec_from_file_location("handoff_regression_helpers", path)
    require(spec is not None and spec.loader is not None, "QA helper unavailable")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    base = args.base_run.resolve()
    require(base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"),
            "An existing campaign-progress production freeze is required")
    helper.identity.no_links(base)
    output = ROOT / ".godot/campaign_progress_handoff_regressions_20261026" / helper.stamp()
    helper.identity.no_links(output)
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "handoff_known_regressions_run_v1", "complete": False,
               "expected": args.expect, "historical_freeze": args.historical_freeze,
               "execution_kind": "source_project_headless_logic_model",
               "base_run": str(base), "source_head": subprocess.check_output(
                   ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": helper.sha(__file__), "steps": [], "reports": [],
               "scope": "real Receipt reducer; real LocalSession; synthetic memory Ledger",
               "campaign_qa_suppression": False, **{key: False for key in UNVERIFIED}}
    owner, locked, project, engine = str(output), False, None, None
    pins = {}
    try:
        start, notice = time.monotonic(), time.monotonic() - 25
        while not locked:
            if not helper.shared.LOCK.exists() and not helper.running():
                try:
                    with helper.shared.LOCK.open("x", encoding="utf-8") as handle:
                        handle.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            if time.monotonic() - start >= args.wait_lane:
                raise RuntimeError("Shared engine occupied; no child started")
            if time.monotonic() - notice >= 25:
                print("WAIT shared engine; no child started", flush=True)
                notice = time.monotonic()
            time.sleep(1)
        require(not helper.running(), "Engine appeared before preflight")
        preparation = helper.read(base / "preparation.json")
        require(preparation.get("schema") == "campaign_handoff_overlay_preparation_v1"
                and preparation.get("complete") is True, "Completed twenty-file handoff preparation required")
        for file in [base / name for name in ("preparation.json", "root_source.json", "generation.json", "candidate_manifest.json")]:
            pins[str(file)] = helper.sha(file)
        for file in (Path(__file__), HERE / "README.md", Path(helper.__file__), Path(helper.common.__file__),
                     Path(helper.shared.__file__), Path(helper.identity.__file__), ROOT / "tools/run_campaign_level_state_qa.py"):
            pins[str(file)] = helper.sha(file)
        manifest = helper.read(base / "candidate_manifest.json")
        rows = manifest.get("files", [])
        require(len(rows) == 20 and len({row["path"] for row in rows}) == 20,
                "Exactly twenty candidate files required")
        require(preparation["candidate_manifest_sha256"] == pins[str(base / "candidate_manifest.json")],
                "Frozen candidate manifest differs from preparation")
        current_manifest_sha = helper.sha(CANDIDATE / "manifest.json")
        pins[str(CANDIDATE / "manifest.json")] = current_manifest_sha
        current_matches = current_manifest_sha == preparation["candidate_manifest_sha256"]
        for row in rows:
            file = CANDIDATE / row["path"]
            helper.identity.no_links(file)
            current_sha = helper.sha(file)
            current_matches = current_matches and current_sha == row["candidate_sha256"]
            pins[str(file)] = current_sha
        receipt["current_candidate_matches_freeze"] = current_matches
        require(current_matches or args.historical_freeze, "Current candidate differs; explicit --historical-freeze required")
        project = helper.assert_runtime_current(base)
        require(project.resolve() == (base / "project").resolve(), "Project escapes selected freeze")
        generation = helper.read(base / "generation.json")
        helper.identity.verify_generated(project, generation)
        for row in rows:
            require(helper.sha(project / row["path"]) == row["candidate_sha256"],
                    "Installed overlay differs: " + row["path"])
        engine = helper.shared.resolve_godot(None)
        receipt.update(project=str(project), engine_sha256=helper.sha(engine),
                       content_version="source-v1:" + generation["identity"]["source_sha256"],
                       candidate_manifest_sha256=pins[str(base / "candidate_manifest.json")],
                       initial_identity_passed=True)
        workers = output / "workers"
        workers.mkdir()
        receipt["workers"] = []
        for name in WORKERS:
            source, target = HERE / name, workers / name
            digest = helper.sha(source)
            helper.copy_checked(source, target, digest)
            pins[str(source)] = pins[str(target)] = digest
            receipt["workers"].append({"path": name, "sha256": digest})
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/campregress" / nonce[:12]
        helper.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = helper.common.private_environment(profile)
        for key in list(env):
            if key.startswith(("RG_", "MR_", "LR_", "HG_", "CC_", "CH_", "CR_")):
                env.pop(key)
        stage = output / "model_regressions"
        stage.mkdir()
        report_path = stage / "report.json"
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", RG_PROFILE=str(profile), RG_PROJECT=str(project),
                   RG_WORKERS=str(workers), RG_NONCE=nonce, RG_REPORT=str(report_path), RG_EXPECT=args.expect,
                   RG_WORKER_SHA256=helper.sha(workers / "worker.gd"),
                   RG_RECEIPT_SHA256=helper.sha(workers / "receipt_case.gd"),
                   RG_SESSION_SHA256=helper.sha(workers / "session_case.gd"))
        receipt.update(profile=str(profile), batch_nonce=nonce)
        report = None
        try:
            helper.suite_verify_pins(pins)
            helper.common.process_step(engine, project, env, stage, "model_regressions",
                                       ["--headless", "--script", str(workers / "bootstrap.gd")],
                                       args.timeout, "gl_compatibility", helper.running, receipt["steps"])
        finally:
            if report_path.is_file():
                report = helper.read(report_path)
                pins[str(report_path)] = helper.sha(report_path)
                receipt["reports"].append({"mode": "model_regressions", "path": str(report_path),
                                           "sha256": pins[str(report_path)], "checks": len(report.get("checks", [])),
                                           "passed": report.get("passed", False), "failures": report.get("failures", [])})
        require(report is not None, "Native regression report missing")
        require(report.get("schema") == "handoff_known_regressions_v1" and report.get("mode") == "model_regressions"
                and report.get("expected") == args.expect and report.get("passed") is True
                and not report.get("failures") and report.get("checks")
                and all(row.get("passed") is True for row in report["checks"]), "Regression assertions failed")
        identity = report.get("trusted_identity", {})
        step = receipt["steps"][-1]
        require(report.get("batch_nonce") == nonce and report.get("profile") == str(profile)
                and type(report.get("pid")) is int and report["pid"] == step["pid"]
                and step.get("exit_code") == 0 and step.get("passed") is True
                and identity.get("ok") is True and identity.get("save_eligible") is True
                and identity.get("source_mode") is True and identity.get("content_version") == receipt["content_version"]
                and identity.get("engine_binary_sha256") == receipt["engine_sha256"], "Process/source identity mismatch")
        require(report.get("candidate_regressions_passed") is (args.expect == "fixed")
                and report.get("defect_reproduction_complete") is (args.expect == "defects")
                and all(report.get(key) is False for key in ("filesystem_or_sdk_exercised", "original_release_gui_tested",
                      "human_acceptance", "performance_acceptance", "published", "candidate_runtime_qualified")),
                "Report acceptance boundary mismatch")
        receipt["requested_expectation_passed"] = True
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        if project is not None:
            try:
                helper.assert_runtime_current(base)
                helper.identity.verify_generated(project, helper.read(base / "generation.json"))
                helper.suite_verify_pins(pins)
                if engine is not None:
                    require(helper.sha(engine) == receipt["engine_sha256"], "Engine changed")
                receipt["final_identity_passed"] = True
            except BaseException as error:
                receipt["final_identity_passed"] = False
                receipt["final_identity_error"] = repr(error)
        receipt["lock_ownership_confirmed"] = locked and helper.shared.LOCK.exists() and helper.shared.LOCK.read_text(encoding="utf-8") == owner
        receipt["complete"] = bool(receipt.get("requested_expectation_passed") and receipt.get("final_identity_passed")
                                   and receipt["lock_ownership_confirmed"] and "error" not in receipt)
        receipt["candidate_regressions_passed"] = receipt["complete"] and args.expect == "fixed"
        receipt["defect_reproduction_complete"] = receipt["complete"] and args.expect == "defects"
        if receipt["lock_ownership_confirmed"]:
            helper.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not helper.shared.LOCK.exists()
        receipt["pinned_files"] = pins
        helper.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "expected": args.expect,
                      "candidate_regressions_passed": receipt["candidate_regressions_passed"],
                      "error": receipt.get("error"), "reports": receipt["reports"],
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
