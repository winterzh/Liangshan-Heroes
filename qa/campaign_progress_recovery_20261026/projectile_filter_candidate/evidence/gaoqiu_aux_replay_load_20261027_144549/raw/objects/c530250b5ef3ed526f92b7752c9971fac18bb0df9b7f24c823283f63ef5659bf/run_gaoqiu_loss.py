"""Three-process natural Gao commander defeat and terminal-slot refusal; --run starts Godot.

No --base-run: lightweight named-source/AST check only. With --base-run: read-only
full b22 freeze/own-cold preflight. Only this source-private loss route is
qualified on success; victory, native SDK, public entry and EXE remain untested.
"""
from __future__ import annotations

import argparse
import ast
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
WORKER_ROOT = HERE.parent / "gaoqiu_continue_candidate/tests/gaoqiu_loss"
CONTENT = 'source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132'
WORKERS = ("bootstrap.gd", "base.gd", "terminal.gd", "driver.gd")
MODES = ("save_before_loss", "resume_loss", "reject_terminal")
spec = importlib.util.spec_from_file_location("gaoqiu_loss_prepare", HERE / "integration_3365/prepare_projectile.py")
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)
p, h, require = prep.p, prep.h, prep.require


def source_pins():
    path = WORKER_ROOT / "sources.json"
    document = h.read(path)
    expected = {str(item.relative_to(ROOT)).replace("\\", "/") for item in
                (HERE.parent / "gaoqiu_continue_candidate/run_gaoqiu_loss.py", WORKER_ROOT / "README.md", *(WORKER_ROOT / name for name in WORKERS))}
    rows = document.get("files", [])
    require(document.get("schema") == "gaoqiu_loss_external_sources_v1"
            and len(rows) == len(expected) and {row["path"] for row in rows} == expected,
            "Exact new external host/README/four-worker source list required")
    pins = {}
    for row in rows + document.get("derived_from", []) + document.get("dependencies", []):
        p.pin(prep.inside(ROOT, row["path"]), pins, row["sha256"])
    p.pin(path, pins)
    for module in (prep, p, h, h.common, h.shared, h.identity):
        p.pin(Path(module.__file__), pins)
    p.pin(ROOT / "tools/run_campaign_level_state_qa.py", pins)
    contract = HERE / 'tests/gaoqiu_aux_replay'
    own = h.read(contract / 'sources.json')
    require(own.get('schema') == 'b22_gaoqiu_aux_replay_sources_v1' and own.get('source_identity') == CONTENT and own.get('candidate_scripts') == 26 and own.get('native_assets') == 1,
            'Fixed b22 auxiliary replay contract required')
    expected_own = {HERE / 'run_gaoqiu_training.py', HERE / 'run_gaoqiu_loss.py', contract / 'README.md'}
    rows_own = own.get('files', [])
    require(len(rows_own) == 3 and {ROOT / row['path'] for row in rows_own} == expected_own,
            'Both replay hosts and their current contract README required')
    for row in rows_own:
        target = prep.inside(ROOT, row['path'])
        p.pin(target, pins, row['sha256'])
        require(p.fs(target).stat().st_size == row['bytes'], 'Named input bytes changed')
    dependencies = own.get('dependencies_by_route', {}).get('loss', [])
    required = set(Path(name) for name in pins) - expected_own
    require(len(dependencies) == len(required) and {ROOT / row['path'] for row in dependencies} == required,
            'Exact original source chain and imported helper set required for this route')
    for row in dependencies:
        target = prep.inside(ROOT, row['path'])
        p.pin(target, pins, row['sha256'])
        require(p.fs(target).stat().st_size == row['bytes'], 'Original named input bytes changed')
    p.pin(contract / 'sources.json', pins)
    for name in pins:
        if Path(name).suffix == '.py':
            ast.parse(p.fs(name).read_text(encoding='utf-8-sig'), filename=name)
    p.verify_pins(pins)
    return pins


def preflight(base):
    state = prep.prepared_state(base)
    require(state["validation_level"] == "full_new_freeze_and_own_import"
            and state["content_version"] == CONTENT and state["cold_import_qualified"] is True
            and state["run_base"] == Path(base).resolve()
            and state["project"] == state["run_base"] / "project",
            "Execution must use complete b22 and its own successful first cold import")
    manifest = h.read(state["run_base"] / "candidate_manifest.json")
    require(len(manifest["files"]) == 26 and len(manifest["native_assets"]) == 1, "Exact b22 combined candidate list required")
    prep.merge_pins(state["pins"], source_pins())
    p.verify_pins(state["pins"])
    return state


def execute(args):
    output = ROOT / ".godot/gaoqiu_loss_b22_20261027" / h.stamp()
    h.identity.no_links(output)
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "b22_gaoqiu_loss_three_process_v1", "complete": False,
               "execution_kind": "source_project_offscreen_gl", "base_run": str(args.base_run.resolve()),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": h.sha(__file__), "steps": [], "reports": [], "attempted_modes": [],
               "native_sdk_qualified": False, "public_continue_qualified": False,
               "human_acceptance": False, "native_release_tested": False,
               "credited_rewards_qualified": False, "victory_chain_qualified": False, "source_loss_chain_passed": False}
    owner, locked, state, pins = str(output), False, None, {}
    try:
        start, notice = time.monotonic(), 0.0
        while not locked:
            if not h.shared.LOCK.exists() and not h.running():
                try:
                    with h.shared.LOCK.open("x", encoding="utf-8") as stream: stream.write(owner)
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
                       engine_sha256=state["engine_sha256"], initial_identity_passed=True,
                       candidate_manifest_sha256=manifest_sha, candidate_script_count=26,
                       native_asset_count=1, import_receipts=state["imports"])
        # Freeze source provenance before launch; never copy profile/business
        # state, a complete project or native EXEs into the external worker set.
        for path, digest in list(pins.items()):
            source = Path(path)
            if source.suffix.lower() == ".exe":
                continue
            require(source.is_relative_to(ROOT), "Unexpected external provenance input")
            target = output / "runner_inputs" / source.relative_to(ROOT)
            p.copy(source, target, digest)
            p.pin(target, pins, digest)
        workers = output / "workers"
        workers.mkdir()
        for name in WORKERS:
            digest = pins[str(WORKER_ROOT / name)]
            p.copy(WORKER_ROOT / name, workers / name, digest)
            p.pin(workers / name, pins, digest)
        binding = workers / "bindings.json"
        h.save(binding, {name: pins[str(workers / name)] for name in WORKERS})
        p.pin(binding, pins)
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/gaoloss" / nonce[:12]
        h.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = h.common.private_environment(profile)
        for key in list(env):
            if key.startswith(("GVT_", "DF_", "DN_", "UST_", "UCR_", "USR_", "UTR_", "URF_", "P19_", "GLS_", "GT_", "LL_", "LT_", "LSH_CONTINUE_FLOW_", "CB_", "CC_", "CT_", "SC_", "CR_", "HG_", "LHMR_", "MR_", "LR_", "RS_")):
                env.pop(key)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", LSH_CONTINUE_FLOW_QA="1",
                   LSH_CONTINUE_FLOW_PROFILE=str(profile), GLS_PROFILE=str(profile), GLS_PROJECT=str(project),
                   GLS_WORKERS=str(workers), GLS_BINDINGS=str(binding), GLS_BINDINGS_SHA256=pins[str(binding)],
                   GLS_NONCE=nonce, GLS_CANDIDATE_SHA256=manifest_sha,
                   GLS_SOURCES_SHA256=pins[str(WORKER_ROOT / "sources.json")], LSH_LANGUAGE="zh_CN")
        receipt.update(profile=str(profile), batch_nonce=nonce)
        previous, pids, nonces = None, set(), set()
        for mode in MODES:
            p.verify_pins(pins)
            stage = output / mode
            stage.mkdir()
            report_path = stage / "report.json"
            process_nonce = uuid.uuid4().hex
            stage_env = dict(env, GLS_MODE=mode, GLS_REPORT=str(report_path), GLS_PROCESS_NONCE=process_nonce)
            if previous:
                stage_env.update(GLS_PREVIOUS=str(previous), GLS_PREVIOUS_SHA256=pins[str(previous)])
            report = None
            receipt["attempted_modes"].append(mode)
            try:
                h.common.process_step(engine, project, stage_env, stage, mode,
                                      ["--resolution", "1280x720", "--position", "30000,30000",
                                       "--script", str(workers / "bootstrap.gd")],
                                      args.timeout, "gl_compatibility", h.running, receipt["steps"])
            finally:
                log_path = stage / (mode + ".log")
                if log_path.is_file(): p.pin(log_path, pins)
                if report_path.is_file():
                    p.pin(report_path, pins)
                    report = h.read(report_path)
                    receipt["reports"].append({"mode":mode, "path":str(report_path), "sha256":pins[str(report_path)],
                                               "checks":len(report.get("checks", [])), "passed":report.get("passed", False),
                                               "failures":report.get("failures", [])})
            require(report is not None and report.get("schema") == "campaign_gaoqiu_loss_v1"
                    and report.get("passed") is True and report.get("stage_completed") is True
                    and report.get("failures") == [] and report.get("checks")
                    and all(row.get("passed") is True for row in report["checks"]), "Native route failed: " + mode)
            require(report.get("mode") == mode and report.get("batch_nonce") == nonce
                    and report.get("process_nonce") == process_nonce and process_nonce not in nonces
                    and report.get("profile") == str(profile) and report.get("slot_root") == "user://continue/v1"
                    and report.get("candidate_manifest_sha256") == manifest_sha
                    and report.get("identity", {}).get("content_version") == state["content_version"]
                    and report["identity"].get("engine_sha256") == state["engine_sha256"]
                    and report["identity"].get("source_mode") is True
                    and report.get("simulation_time_scale") == 1 and report.get("physics_hz") == 60
                    and report.get("natural_loss_required") is True and report.get("full_story_required") is False
                    and report.get("sources_sha256") == pins[str(WORKER_ROOT / "sources.json")]
                    and report.get("no_gameplay_state_injection") is True,
                    "Actual PID/profile/source/normal clock contract required")
            require(all(report.get(flag) is False for flag in ("victory_chain_qualified", "native_sdk_qualified", "public_continue_qualified",
                        "human_acceptance", "native_release_tested")), "Source-private loss test cannot grant wider qualification")
            if mode == "save_before_loss":
                require(report.get("save_exit_observed") is True and report.get("exit_reason") == "continue_saved",
                        "Production SaveAndExit must own the actual exit")
            if mode == "resume_loss":
                death = report.get("observations", {}).get("natural_death", {})
                require(death.get("same_original_actor") is True and death.get("hp") == 0
                        and death.get("killer_valid") is True and death.get("killer_faction") == 1
                        and death.get("killer_registered") is True,
                        "Actual original commander enemy-damage death evidence required")
            if mode == "reject_terminal":
                refusal = report.get("observations", {}).get("terminal_refusal", {})
                require(refusal.get("ok") is False and refusal.get("code") == "LOCAL_RUN_TERMINAL",
                        "Actual restarted menu must reject the original terminal token")
            step = receipt["steps"][-1]
            pid = report.get("pid")
            require(type(pid) is int and pid > 0 and pid == step.get("pid") and pid not in pids
                    and step.get("exit_code") == 0 and step.get("passed") is True and step.get("errors") == []
                    and step.get("log_sha256") == pins[str(log_path)], "Actual distinct terminal process and exact log required")
            pids.add(pid); nonces.add(process_nonce)
            previous = report_path
        receipt["three_stages_passed"] = len(pids) == 3 and len(nonces) == 3
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        try:
            require(state is not None, "Full admission did not complete")
            h.assert_runtime_current(state["run_base"])
            h.identity.verify_generated(state["project"], state["generation"])
            p.verify_pins(pins)
            require(h.sha(state["engine"]) == state["engine_sha256"], "Engine bytes changed")
            receipt["final_identity_passed"] = True
        except BaseException as error:
            receipt.update(final_identity_passed=False, final_identity_error=repr(error))
        receipt["child_process_terminal"] = len(receipt["steps"]) == len(receipt["attempted_modes"]) and all(
            type(step.get("pid")) is int and step["pid"] > 0 and type(step.get("exit_code")) is int
            for step in receipt["steps"])
        receipt["lock_ownership_confirmed"] = bool(locked and h.shared.LOCK.is_file()
            and h.shared.LOCK.read_text(encoding="utf-8") == owner)
        try:
            receipt["engine_lane_idle"] = not h.running()
            if receipt["lock_ownership_confirmed"] and receipt["child_process_terminal"] and receipt["engine_lane_idle"]:
                h.shared.LOCK.unlink()
            receipt["lock_released"] = bool(locked and not h.shared.LOCK.exists())
        except BaseException as error:
            receipt.update(lock_released=False, lock_release_error=repr(error))
        receipt["complete"] = bool(receipt.get("three_stages_passed") and receipt.get("final_identity_passed")
                                   and receipt["child_process_terminal"] and receipt["lock_ownership_confirmed"]
                                   and receipt["lock_released"] and "error" not in receipt)
        receipt["source_loss_chain_passed"] = receipt["complete"]
        receipt["pinned_files"] = pins
        h.save(output / "receipt.json", receipt)
    print(json.dumps({"output":str(output), "complete":receipt["complete"], "error":receipt.get("error"),
                      "reports":receipt["reports"], "lock_released":receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]: raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", type=Path, help="Complete b22 freeze with its own successful first cold import")
    parser.add_argument("--run", action="store_true", help="Explicitly start three independent native processes")
    parser.add_argument("--timeout", type=int, default=360)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 120 or args.wait_lane < 0: parser.error("Invalid bounded deadline")
    if args.run and args.base_run is None: parser.error("--run requires --base-run")
    if args.run:
        execute(args)
        return
    pins = source_pins()
    if args.base_run:
        state = preflight(args.base_run)
        result = {"validation_level":state["validation_level"], "full_source_verified":True,
                  "content_version":state["content_version"], "import_receipts":state["imports"]}
    else:
        state = prep.lightweight()
        result = {"validation_level":"source_plan_only", "full_source_verified":False,
                  "source_identity_expected":CONTENT, "worker_pins":len(pins)}
    print(json.dumps({**result, "modes":MODES, "engine_started":False, "lane_acquired":False,
                      "profile_created":False, "native_qualified":False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
