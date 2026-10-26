"""Three isolated native processes continue one natural Level4 training queue.

Use an already imported, identity-bound production freeze. This does not edit
the frozen source, publish, open player Continue, or automate a desktop window.
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
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "lian_frozen_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
MODES = ("save_training", "resume_complete", "verify_resave")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=360)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    base = args.base_run.resolve()
    if not base.is_relative_to(ROOT / ".godot/huangnigang_production_20261020"):
        raise RuntimeError("An existing local production freeze is required")
    helper.identity.no_links(base)
    if args.timeout < 60 or args.wait_lane < 0:
        raise ValueError("Invalid bounded timeout")
    output = ROOT / ".godot/lianhuanma_resume_20261026" / helper.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "lian_training_three_process_run_v1", "complete": False,
               "execution_kind": "source_project_offscreen_gl", "base_run": str(base),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": helper.sha(__file__), "steps": [], "reports": [],
               "original_release_gui_tested": False, "public_continue_qualified": False}
    owner = str(output)
    locked = False
    project = None
    pins = {}
    worker_rows = []
    engine = None
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
        for path in [base / name for name in ("preparation.json", "root_source.json", "generation.json")]:
            pins[str(path)] = helper.sha(path)
        pins[str(Path(__file__))] = helper.sha(__file__)
        pins[str(Path(helper.__file__))] = helper.sha(helper.__file__)
        project = helper.assert_runtime_current(base)
        generation = helper.read(base / "generation.json")
        helper.identity.verify_generated(project, generation)
        engine = helper.shared.resolve_godot(None)
        receipt.update(project=str(project), engine_sha256=helper.sha(engine),
                       content_version="source-v1:" + generation["identity"]["source_sha256"],
                       initial_identity_passed=True)
        workers = output / "workers"
        workers.mkdir()
        for name in ("bootstrap.gd", "training.gd"):
            source = HERE / name
            digest = helper.sha(source)
            helper.copy_checked(source, workers / name, digest)
            pins[str(source)] = digest
            pins[str(workers / name)] = digest
            worker_rows.append({"path": name, "sha256": digest})
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/liantrain" / nonce[:12]
        helper.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = helper.common.private_environment(profile)
        for key in list(env):
            if key.startswith(("LR_", "HG_")):
                env.pop(key)
        env.update(LR_PROFILE=str(profile), LR_PROJECT=str(project), LR_WORKERS=str(workers),
                   LR_WORKER_SHA256=helper.sha(workers / "training.gd"), LR_NONCE=nonce)
        receipt.update(profile=str(profile), batch_nonce=nonce, workers=worker_rows)
        previous = None
        pids = set()
        for mode in MODES:
            helper.suite_verify_pins(pins)
            stage = output / mode
            stage.mkdir()
            report_path = stage / "report.json"
            stage_env = dict(env, LR_MODE=mode, LR_REPORT=str(report_path))
            if previous:
                stage_env.update(LR_PREVIOUS=str(previous), LR_PREVIOUS_SHA256=pins[str(previous)])
            report = None
            try:
                # Fog capture compares the real GPU texture with its CPU image;
                # headless dummy rendering cannot qualify this world snapshot.
                helper.common.process_step(engine, project, stage_env, stage, mode,
                                           ["--resolution", "1280x720", "--position", "30000,30000",
                                            "--script", str(workers / "bootstrap.gd")],
                                           args.timeout, "gl_compatibility", helper.running, receipt["steps"])
            finally:
                if report_path.is_file():
                    report = helper.read(report_path)
                    pins[str(report_path)] = helper.sha(report_path)
                    receipt["reports"].append({"mode": mode, "path": str(report_path),
                                               "sha256": pins[str(report_path)], "checks": len(report.get("checks", [])),
                                               "passed": report.get("passed", False),
                                               "failures": report.get("failures", [])})
            if report is None:
                raise RuntimeError("Native training report missing: " + mode)
            if not report.get("passed") or report.get("failures") or report.get("mode") != mode:
                raise RuntimeError("Native training report failed: " + mode)
            if (report.get("batch_nonce") != nonce or report.get("profile") != str(profile)
                    or report.get("identity", {}).get("content_version") != receipt["content_version"]
                    or report["identity"].get("engine_sha256") != receipt["engine_sha256"]
                    or not report["identity"].get("source_mode")):
                raise RuntimeError("Report identity/profile mismatch: " + mode)
            pid = report.get("pid")
            if pid != receipt["steps"][-1]["pid"] or pid in pids:
                raise RuntimeError("Independent process identity mismatch")
            pids.add(pid)
            previous = report_path
        receipt["all_three_stages_passed"] = True
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
        receipt["lock_ownership_confirmed"] = locked and helper.shared.LOCK.exists() and helper.shared.LOCK.read_text(encoding="utf-8") == owner
        receipt["complete"] = bool(receipt.get("all_three_stages_passed") and receipt.get("final_identity_passed")
                                   and receipt["lock_ownership_confirmed"] and "error" not in receipt)
        if receipt["lock_ownership_confirmed"]:
            helper.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not helper.shared.LOCK.exists()
        receipt["pinned_files"] = pins
        helper.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"],
                      "error": receipt.get("error"), "reports": receipt["reports"],
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
