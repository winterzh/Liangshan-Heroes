"""Run six classic-30 save/restore/terminal stages on an existing handoff freeze.

Default execution is the full six-stage sequence, real GL offscreen, one isolated
profile and unchanged 1.0 simulation speed. This never imports or edits the
candidate, invokes desktop input, publishes, or qualifies the release EXE.
Use --help for a read-only invocation.
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
MODES = ("new_economy", "resume_combat", "resume_transition", "resume_victory",
         "terminal_reject_1", "terminal_reject_2")
OUTCOMES = ("saved_and_exiting", "saved_and_exiting", "saved_and_exiting",
            "natural_victory", "terminal_refused", "terminal_refused")
WORKERS = ("bootstrap.gd", "driver.gd", "policy.gd", "inflight.gd")
OBSERVED = ("project.godot", "scripts/run_content_identity.gd", "scripts/run_local_lifecycle.gd",
            "scripts/run_slot_store.gd", "scripts/run_battle_world_core.gd", "scripts/run_battle_barrier.gd",
            "scripts/run_battle_clock.gd", "scripts/run_state_value_codec.gd", "scripts/run_snapshot_store.gd",
            "scripts/unit.gd", "scripts/defs.gd", "scripts/levels/skirmish.gd", "scripts/hud.gd",
            "scripts/settings.gd", "scripts/app_lifecycle.gd", "scripts/projectile.gd")
UNVERIFIED = ("original_release_gui_tested", "public_continue_qualified", "real_steam",
              "os_input", "human_acceptance", "performance_acceptance", "published")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def load_helpers():
    path = ROOT / "qa/huangnigang_production_20261020/run_batch.py"
    spec = importlib.util.spec_from_file_location("handoff_classic_helpers", path)
    require(spec is not None and spec.loader is not None, "QA helper unavailable")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper


def validate_report(report, state, mode, outcome, nonce, process_nonce, profile, receipt, step):
    checks = report.get("checks", [])
    require(report.get("schema") == "handoff_classic30_regression_v1" and report.get("passed") is True
            and isinstance(checks, list) and checks and all(row.get("passed") is True for row in checks),
            "Classic checks failed: " + mode)
    require(report.get("mode") == mode and report.get("case") == mode and report.get("outcome") == outcome
            and report.get("run_id") == nonce and report.get("batch_nonce") == nonce,
            "Report stage/batch mismatch: " + mode)
    require(report.get("profile") == str(profile) and report.get("slot_root") == "user://continue/v1"
            and report.get("process_nonce") == process_nonce and type(report.get("pid")) is int
            and report["pid"] == step["pid"] and step.get("exit_code") == 0 and step.get("passed") is True,
            "Report does not belong to the observed process: " + mode)
    identity = report.get("trusted_identity", {})
    require(identity.get("ok") is True and identity.get("save_eligible") is True
            and identity.get("source_mode") is True and identity.get("content_version") == receipt["content_version"]
            and identity.get("engine_binary_sha256") == receipt["engine_sha256"],
            "Actual candidate/engine identity mismatch: " + mode)
    require(all(report.get(key) is False for key in ("native_release", "os_input", "human_acceptance", "published",
                                                   "real_steam", "manual_player_test", "performance_acceptance",
                                                   "public_player_entry_tested", "diagnostic_only")),
            "Report broadened its acceptance scope: " + mode)
    require(state.get("run_id") == nonce and state.get("pid") == step["pid"]
            and state.get("process_nonce") == process_nonce and state.get("profile") == str(profile)
            and state.get("slot_root") == "user://continue/v1" and state.get("identity") == identity,
            "Exact predecessor state identity mismatch: " + mode)
    binding = state.get("slot_binding", {})
    require(binding.get("kind") == "uncredited" and len(binding.get("token", "")) == 32
            and len(binding.get("receipt_sha256", "")) == 64, "Original classic binding absent: " + mode)
    index = MODES.index(mode)
    require(len(state.get("checkpoints", [])) == min(index + 1, 3)
            and len(state.get("resumes", [])) == min(index, 3), "Checkpoint/restore sequence mismatch: " + mode)
    if index >= 3:
        require(state.get("victory") is True and report.get("full_30_wave_victory") is True
                and [row.get("wave") for row in state.get("waves", [])] == list(range(1, 31))
                and sum(len(row.get("enemy_roster", [])) for row in state["waves"]) == 778,
                "Natural thirty-wave completion missing: " + mode)
    require(len(state.get("terminal_rejections", [])) == max(0, index - 3),
            "Independent terminal-rejection count mismatch: " + mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", type=Path, required=True,
                        help="Already imported twenty-file freeze under .godot/campaign_progress_recovery_20261026")
    parser.add_argument("--timeout", type=int, default=1800, help="Per-process wall-clock limit, default 1800 seconds")
    parser.add_argument("--wait-lane", type=int, default=1800, help="Shared-lane wait limit, default 1800 seconds")
    args = parser.parse_args()
    if not 60 <= args.timeout <= 3600 or not 0 <= args.wait_lane <= 86400:
        raise ValueError("Bounded timeout must be 60..3600 and lane wait 0..86400 seconds")
    helper = load_helpers()
    base = args.base_run.resolve()
    require(base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"),
            "An existing campaign-progress production freeze is required")
    helper.identity.no_links(base)
    output = ROOT / ".godot/campaign_progress_classic_20261026" / helper.stamp()
    helper.identity.no_links(output)
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "handoff_classic_six_process_run_v1", "complete": False,
               "execution_kind": "source_project_offscreen_gl", "base_run": str(base),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": helper.sha(__file__), "steps": [], "reports": [], "process_runs": [],
               "modes": list(MODES), "timeout_seconds": args.timeout, "wait_lane_seconds": args.wait_lane,
               "campaign_qa_suppression": False, "slot_root": "user://continue/v1",
               "profile_or_slot_copied": False, **{key: False for key in UNVERIFIED}}
    owner, locked, project, engine = str(output), False, None, None
    pins = {}
    original_binding = None
    try:
        waiting = time.monotonic()
        notice = waiting - 25
        while not locked:
            if not helper.shared.LOCK.exists() and not helper.running():
                try:
                    with helper.shared.LOCK.open("x", encoding="utf-8") as handle:
                        handle.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            if time.monotonic() - waiting >= args.wait_lane:
                raise RuntimeError("Shared engine occupied; no child started")
            if time.monotonic() - notice >= 25:
                print("WAIT shared engine; no child started", flush=True)
                notice = time.monotonic()
            time.sleep(1)
        receipt["lane_wait_seconds"] = round(time.monotonic() - waiting, 3)
        require(not helper.running(), "Engine appeared before preflight")
        preparation = helper.read(base / "preparation.json")
        require(preparation.get("schema") == "campaign_handoff_overlay_preparation_v1"
                and preparation.get("complete") is True, "Completed twenty-file handoff preparation required")
        for path in [base / name for name in ("preparation.json", "root_source.json", "generation.json", "candidate_manifest.json")]:
            pins[str(path)] = helper.sha(path)
        for path in (Path(__file__), HERE / "README.md", Path(helper.__file__), Path(helper.common.__file__),
                     Path(helper.shared.__file__), Path(helper.identity.__file__), ROOT / "tools/run_campaign_level_state_qa.py"):
            pins[str(path)] = helper.sha(path)
        candidate_manifest = helper.read(base / "candidate_manifest.json")
        rows = candidate_manifest.get("files", [])
        require(len(rows) == 20 and len({row["path"] for row in rows}) == 20,
                "Exactly twenty frozen candidate scripts required")
        require(helper.sha(CANDIDATE / "manifest.json") == preparation["candidate_manifest_sha256"]
                == pins[str(base / "candidate_manifest.json")], "Candidate manifest differs from its freeze")
        pins[str(CANDIDATE / "manifest.json")] = preparation["candidate_manifest_sha256"]
        for row in rows:
            path = CANDIDATE / row["path"]
            helper.identity.no_links(path)
            require(helper.sha(path) == row["candidate_sha256"], "Candidate source changed: " + row["path"])
            pins[str(path)] = row["candidate_sha256"]
        project = helper.assert_runtime_current(base)
        require(project.resolve() == (base / "project").resolve(), "Preparation project escapes selected freeze")
        generation = helper.read(base / "generation.json")
        helper.identity.verify_generated(project, generation)
        engine = helper.shared.resolve_godot(None)
        receipt.update(project=str(project), engine_sha256=helper.sha(engine),
                       content_version="source-v1:" + generation["identity"]["source_sha256"],
                       candidate_manifest_sha256=pins[str(base / "candidate_manifest.json")],
                       initial_identity_passed=True)
        sources = {name: helper.sha(project / name) for name in OBSERVED}
        for row in rows:
            require(helper.sha(project / row["path"]) == row["candidate_sha256"],
                    "Installed overlay differs from candidate: " + row["path"])
            sources[row["path"]] = row["candidate_sha256"]
        workers = output / "workers"
        workers.mkdir()
        worker_rows = []
        for name in WORKERS:
            source, target = HERE / name, workers / name
            digest = helper.sha(source)
            helper.copy_checked(source, target, digest)
            pins[str(source)] = pins[str(target)] = digest
            worker_rows.append({"path": name, "sha256": digest})
        bindings = workers / "bindings.json"
        helper.save(bindings, {row["path"]: row["sha256"] for row in worker_rows if row["path"] != "bootstrap.gd"})
        pins[str(bindings)] = helper.sha(bindings)
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/campclassic" / nonce[:12]
        helper.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = helper.common.private_environment(profile)
        for key in list(env):
            if key.startswith(("CC_", "CR_", "CH_", "LR_", "HG_")):
                env.pop(key)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", LSH_CONTINUE_FLOW_QA="1",
                   LSH_CONTINUE_FLOW_PROFILE=str(profile), CC_PROFILE=str(profile), CC_PROJECT=str(project),
                   CC_RUN=str(output), CC_WORKERS=str(workers), CC_BINDINGS=str(bindings), CC_NONCE=nonce,
                   CC_EXPECTED_CONTENT_VERSION=receipt["content_version"],
                   CC_EXPECTED_ENGINE_SHA256=receipt["engine_sha256"], LSH_LANGUAGE="zh_CN")
        receipt.update(profile=str(profile), batch_nonce=nonce, workers=worker_rows)
        previous_state = previous_report = None
        for mode, outcome in zip(MODES, OUTCOMES):
            helper.suite_verify_pins(pins)
            require(helper.sha(engine) == receipt["engine_sha256"], "Engine changed before " + mode)
            stage = output / mode
            stage.mkdir()
            report_path, state_path = stage / "report.json", stage / "state.json"
            control = {"run_id": nonce, "case": mode, "report": str(report_path), "state": str(state_path),
                       "events": str(stage / "events.jsonl"), "progress": str(stage / "progress.json"),
                       "screenshots": str(stage / "screenshots"), "max_sim_seconds": 1800,
                       "diagnostic_seconds": 0, "source_sha256": sources,
                       "previous_state": str(previous_state) if previous_state else "",
                       "previous_sha256": pins[str(previous_state)] if previous_state else "",
                       "previous_report": str(previous_report) if previous_report else "",
                       "previous_report_sha256": pins[str(previous_report)] if previous_report else ""}
            control_path = stage / "control.json"
            helper.save(control_path, control)
            pins[str(control_path)] = helper.sha(control_path)
            process_nonce = uuid.uuid4().hex
            stage_env = dict(env, CC_MODE=mode, CC_PROCESS_NONCE=process_nonce,
                             CC_CONTROL=str(control_path), CC_CONTROL_SHA256=pins[str(control_path)])
            process = {"case": mode, "process_nonce": process_nonce, "started_ns": time.monotonic_ns()}
            report = state = None
            step_count = len(receipt["steps"])
            try:
                helper.common.process_step(engine, project, stage_env, stage, mode,
                                           ["--audio-driver", "Dummy", "--resolution", "1280x720",
                                            "--position", "30000,30000", "--script", str(workers / "bootstrap.gd")],
                                           args.timeout, "gl_compatibility", helper.running, receipt["steps"])
            finally:
                process["finished_ns"] = time.monotonic_ns()
                if len(receipt["steps"]) > step_count:
                    process["pid"] = receipt["steps"][-1].get("pid")
                    process["exit_code"] = receipt["steps"][-1].get("exit_code")
                receipt["process_runs"].append(process)
                for path in sorted(stage.rglob("*")):
                    if path.is_file():
                        digest = helper.sha(path)
                        require(str(path) not in pins or pins[str(path)] == digest,
                                "Previously pinned stage input changed: " + str(path))
                        pins[str(path)] = digest
                if report_path.is_file():
                    report = helper.read(report_path)
                    receipt["reports"].append({"mode": mode, "path": str(report_path),
                                               "sha256": pins[str(report_path)], "checks": len(report.get("checks", [])),
                                               "passed": report.get("passed", False), "outcome": report.get("outcome"),
                                               "failed_checks": [row for row in report.get("checks", []) if row.get("passed") is not True]})
                if state_path.is_file():
                    state = helper.read(state_path)
            require(report is not None and state is not None, "Native report/state missing: " + mode)
            validate_report(report, state, mode, outcome, nonce, process_nonce, profile, receipt, receipt["steps"][-1])
            require(report.get("source_sha256") == sources, "Report runtime-input map changed: " + mode)
            require(report.get("state_sha256") == pins[str(state_path)]
                    and report.get("events_sha256") == pins[str(stage / "events.jsonl")],
                    "Report does not bind the exact output bytes: " + mode)
            if original_binding is None:
                original_binding = state["slot_binding"]
            require(state["slot_binding"] == original_binding, "Original run token/binding changed: " + mode)
            previous_state, previous_report = state_path, report_path
            helper.suite_verify_pins(pins)
        processes = receipt["process_runs"]
        require(len(processes) == 6 and len({row["process_nonce"] for row in processes}) == 6
                and all(type(row.get("pid")) is int and row["pid"] > 0 and row["exit_code"] == 0
                        and row["finished_ns"] > row["started_ns"] for row in processes)
                and all(processes[i]["started_ns"] >= processes[i-1]["finished_ns"] for i in range(1, 6)),
                "Independent process sequence incomplete")
        receipt.update(all_six_stages_passed=True, checks=sum(row["checks"] for row in receipt["reports"]),
                       same_token_verified=True, original_binding=original_binding,
                       pid_reused=len({row["pid"] for row in processes}) != 6,
                       process_identity_basis="observed Popen PID plus unique nonce and nonoverlapping intervals")
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        if project is not None:
            try:
                helper.assert_runtime_current(base)
                helper.identity.verify_generated(project, helper.read(base / "generation.json"))
                helper.suite_verify_pins(pins)
                if engine is not None:
                    require(helper.sha(engine) == receipt["engine_sha256"], "Engine bytes changed")
                receipt["final_identity_passed"] = True
            except BaseException as error:
                receipt["final_identity_passed"] = False
                receipt["final_identity_error"] = repr(error)
        receipt["engine_idle_after"] = not helper.running() if locked else None
        receipt["lock_ownership_confirmed"] = (locked and helper.shared.LOCK.exists()
                                                and helper.shared.LOCK.read_text(encoding="utf-8") == owner)
        receipt["complete"] = bool(receipt.get("all_six_stages_passed") and receipt.get("final_identity_passed")
                                   and receipt["engine_idle_after"] and receipt["lock_ownership_confirmed"]
                                   and "error" not in receipt)
        if receipt["lock_ownership_confirmed"]:
            helper.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not helper.shared.LOCK.exists()
        receipt["pinned_files"] = pins
        helper.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "checks": receipt.get("checks", 0),
                      "error": receipt.get("error"), "reports": receipt["reports"],
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
