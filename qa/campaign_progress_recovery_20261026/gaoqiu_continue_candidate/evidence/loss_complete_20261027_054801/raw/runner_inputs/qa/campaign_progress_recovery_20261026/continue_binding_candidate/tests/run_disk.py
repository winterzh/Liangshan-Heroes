"""Strict real-filesystem LC model host; default preflight NEVER starts Godot.

--expect baseline only accepts original e97a; fixed requires the new 23-script
freeze and its own successful import. --execute is the sole engine opt-in.
Synthetic credits/terminal inputs do not qualify public Flow, Steam or gameplay.
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
spec = importlib.util.spec_from_file_location("continue_disk_prepare", HERE.parent / "prepare_continue.py")
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
h, require, ROOT = p.h, p.require, p.ROOT


def preflight(base, expected):
    state = p.preflight()
    pins = state["pins"]
    base = base.resolve()
    require(base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"), "Private campaign freeze required")
    h.identity.no_links(base)
    manifest = h.read(base / "candidate_manifest.json")
    preparation = h.read(base / "preparation.json")
    if expected == "baseline":
        require(base == state["base"] and manifest == h.read(state["base"] / "candidate_manifest.json"),
                "Baseline is exclusively the original e97a, never a repaired candidate")
    else:
        require(base != state["base"] and manifest == state["manifest"], "Fixed requires exact newly composed 23-script manifest")
        require(preparation.get("schema") == "continue_binding_preparation_v1"
                and preparation.get("base_run") == str(state["base"])
                and preparation.get("base_identity") == state["overlay"]["base_identity"], "Fixed preparation origin mismatch")
    require(preparation.get("complete") is True
            and preparation.get("candidate_manifest_sha256") == h.sha(base / "candidate_manifest.json")
            and preparation.get("overlays") == manifest["files"]
            and preparation.get("native_assets") == manifest["native_assets"], "Complete preparation/manifest binding required")
    p.verify_pins(preparation["pinned_candidates"])
    pins.update(preparation["pinned_candidates"])
    project = h.assert_runtime_current(base)
    require(project == base / "project", "Frozen project path mismatch")
    generation = h.read(base / "generation.json")
    h.identity.verify_generated(project, generation)
    actual = {row["path"]: row for row in generation["identity"]["files"]}
    require(len(manifest["files"]) == 23 and len(manifest["native_assets"]) == 1, "23 scripts plus bound helper required")
    for row in manifest["files"] + manifest["native_assets"]:
        require(actual[row["path"]]["sha256"] == row["candidate_sha256"], "Generated member changed")
        p.pin(project / row["path"], pins, row["candidate_sha256"])
    engine = h.shared.resolve_godot(None)
    engine_sha = p.pin(engine, pins)
    imports = []
    for path in sorted(base.glob("import__*/receipt.json")):
        value = h.read(path)
        steps = value.get("steps", [])
        if (value.get("complete") is True and value.get("phase") == "import"
                and value.get("project") == str(project) and value.get("engine_sha256") == engine_sha
                and value.get("lock_released") is True and len(steps) == 1
                and steps[0].get("exit_code") == 0 and steps[0].get("passed") is True and steps[0].get("errors") == []):
            p.pin(path.parent / "import.log", pins, steps[0]["log_sha256"])
            p.pin(path, pins)
            imports.append(str(path))
    require(imports, "Successful terminal import for this exact project and engine required")
    for path in [Path(__file__), HERE / "bootstrap.gd", HERE / "binding_disk.gd",
                 *(base / name for name in ("candidate_manifest.json", "preparation.json", "root_source.json", "preimport_source.json", "generation.json"))]:
        p.pin(path, pins)
    p.verify_pins(pins)
    return {**state, "run_base": base, "project": project, "generation": generation, "engine": engine,
            "engine_sha256": engine_sha, "manifest": manifest, "imports": imports,
            "content_version": "source-v1:" + generation["identity"]["source_sha256"], "expected": expected}


def execute(args):
    output = ROOT / ".godot/continue_binding_disk_20261027" / h.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "continue_binding_disk_run_v1", "complete": False, "expected": args.expect,
               "base_run": str(args.base_run.resolve()), "steps": [], "reports": [],
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": h.sha(__file__), "execution_kind": "real_disk_synthetic_lifecycle_model",
               "baseline_defect_reproduced": False, "fixed_lifecycle_model_passed": False,
               "public_flow_qualified": False, "slot_recovery_qualified": False,
               "sdk_qualified": False, "natural_battle_qualified": False, "production_qualified": False}
    owner, locked, state, pins = str(output), False, None, {}
    native_step_attempted = False
    try:
        start, notice = time.monotonic(), 0.0
        while not locked:
            if not h.shared.LOCK.exists() and not h.running():
                try:
                    with h.shared.LOCK.open("x", encoding="utf-8") as stream:
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
        require(not h.running(), "Engine appeared before preflight")
        state = preflight(args.base_run, args.expect)
        pins = state["pins"]
        receipt.update(project=str(state["project"]), content_version=state["content_version"],
                       engine_sha256=state["engine_sha256"], initial_identity_passed=True,
                       candidate_manifest_sha256=h.sha(state["run_base"] / "candidate_manifest.json"),
                       imports=state["imports"])
        # Freeze every imported source/provenance input as well as the workers.
        for path, digest in list(pins.items()):
            source = Path(path)
            if source == state["engine"]:
                continue  # Hash the actual executable before/after; do not duplicate it.
            relative = source.relative_to(ROOT) if source.is_relative_to(ROOT) else Path("external") / digest / source.name
            target = output / "runner_inputs" / relative
            p.copy(source, target, digest)
            p.pin(target, pins, digest)
        workers = output / "workers"
        workers.mkdir()
        for name in ("bootstrap.gd", "binding_disk.gd"):
            p.copy(HERE / name, workers / name, pins[str(HERE / name)])
            p.pin(workers / name, pins, pins[str(HERE / name)])
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/cbind" / nonce[:12]
        h.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = h.common.private_environment(profile)
        for key in list(env):
            if key.startswith(("CB_", "MR_", "LR_", "HG_", "CR_", "LHM_")):
                env.pop(key)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="", CB_WORKERS=str(workers),
                   CB_WORKER_SHA256=pins[str(workers / "binding_disk.gd")], CB_PROFILE=str(profile),
                   CB_OUTPUT=str(output), CB_NONCE=nonce, CB_EXPECT=args.expect)
        receipt.update(profile=str(profile), nonce=nonce, workers=str(workers))
        p.verify_pins(pins)
        report_path = output / "report.json"
        try:
            native_step_attempted = True
            h.common.process_step(state["engine"], state["project"], env, output, "disk_model",
                                  ["--headless", "--script", str(workers / "bootstrap.gd")],
                                  args.timeout, "gl_compatibility", h.running, receipt["steps"])
        finally:
            if report_path.is_file():
                report = h.read(report_path)
                p.pin(report_path, pins)
                receipt["reports"].append({"path": str(report_path), "sha256": pins[str(report_path)],
                                           "expected": report.get("expected"), "passed": report.get("passed"),
                                           "checks": len(report.get("checks", [])), "failures": report.get("failures", [])})
        require(report_path.is_file(), "Native report missing")
        report = h.read(report_path)
        require(len(receipt["steps"]) == 1 and receipt["steps"][0].get("exit_code") == 0
                and receipt["steps"][0].get("passed") is True and receipt["steps"][0].get("errors") == [], "Terminal native process/log failure")
        p.pin(output / "disk_model.log", pins, receipt["steps"][0]["log_sha256"])
        require(report.get("schema") == "continue_binding_disk_fixture_v1" and report.get("expected") == args.expect
                and report.get("passed") is True and report.get("failures") == []
                and report.get("checks") and all(row.get("passed") is True for row in report["checks"]), "Native model checks failed")
        require(report.get("pid") == receipt["steps"][0]["pid"] and report.get("nonce") == nonce
                and report.get("profile") == str(profile)
                and Path(report.get("user_directory", "")).is_relative_to(profile)
                and report.get("root_path") == "user://continue_binding_probe/" + nonce
                and report.get("identity", {}).get("content_version") == state["content_version"]
                and report["identity"].get("engine_binary_sha256") == state["engine_sha256"]
                and report["identity"].get("source_mode") is True, "PID/nonce/content/engine mismatch")
        require(report.get("baseline_defect_reproduced") is (args.expect == "baseline"), "Wrong expected baseline/fixed determination")
        counts = {kind: sum(row.get("category") == kind for row in report["checks"])
                  for kind in ("fixture_precondition", "baseline_reproduction", "fixed_regression")}
        require(sum(counts.values()) == len(report["checks"]) and counts["baseline_reproduction"] == 3,
                "Actual check categories are incomplete")
        require(report.get("fixed_regression_count") == counts["fixed_regression"]
                and report.get("fixed_lifecycle_model_passed") is (args.expect == "fixed")
                and ((counts["fixed_regression"] > 0) if args.expect == "fixed" else counts["fixed_regression"] == 0),
                "Baseline demonstration must not grant fixed-model qualification")
        receipt["actual_check_counts"] = counts
        for field in ("sdk_qualified", "natural_battle_qualified", "public_flow_qualified", "production_qualified"):
            require(report.get(field) is False, "Synthetic model exceeded qualification: " + field)
        require(report.get("synthetic_account_credit_and_terminal") is True, "Synthetic boundary missing")
        receipt["baseline_defect_reproduced"] = args.expect == "baseline"
        receipt["fixed_lifecycle_model_passed"] = args.expect == "fixed"
        receipt["expected_model_passed"] = True
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        if state is not None:
            try:
                h.assert_runtime_current(state["run_base"])
                h.identity.verify_generated(state["project"], state["generation"])
                h.identity.verify_generated(state["base"] / "project", h.read(state["base"] / "generation.json"))
                p.verify_pins(pins)
                receipt["final_identity_passed"] = True
            except BaseException as error:
                receipt["final_identity_passed"] = False
                receipt["final_identity_error"] = repr(error)
        # process_step records the original Popen returncode only after its
        # final terminate/wait path. If kill/wait itself raises, the row can be
        # absent: retain our lock rather than assume that child is terminal.
        steps = receipt["steps"]
        terminal = not native_step_attempted or (
            len(steps) == 1 and type(steps[0].get("pid")) is int and steps[0]["pid"] > 0
            and type(steps[0].get("exit_code")) is int)
        receipt.update(native_step_attempted=native_step_attempted, child_terminal_confirmed=terminal,
                       engine_lane_idle_confirmed=False, lock_ownership_confirmed=False, lock_released=False)
        try:
            owned = locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text(encoding="utf-8") == owner
            receipt["lock_ownership_confirmed"] = owned
            if owned:
                receipt["engine_lane_idle_confirmed"] = h.running() is False
                if terminal and receipt["engine_lane_idle_confirmed"]:
                    h.shared.LOCK.unlink()
                    receipt["lock_released"] = not h.shared.LOCK.exists()
                else:
                    receipt["lock_retained_reason"] = "CHILD_NOT_TERMINAL_OR_ENGINE_LANE_NOT_IDLE"
        except BaseException as error:
            receipt["lock_release_error"] = repr(error)
        receipt["complete"] = bool(receipt.get("expected_model_passed") and receipt.get("final_identity_passed")
                                   and receipt["lock_released"] and "error" not in receipt)
        receipt["pinned_files"] = pins
        h.save(output / "receipt.json", receipt)
    print(json.dumps({"run": str(output), "complete": receipt["complete"], "expected": args.expect,
                      "baseline_defect_reproduced": receipt["baseline_defect_reproduced"],
                      "fixed_lifecycle_model_passed": receipt["fixed_lifecycle_model_passed"],
                      "error": receipt.get("error"), "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--expect", required=True, choices=("baseline", "fixed"))
    parser.add_argument("--execute", action="store_true", help="explicitly acquire shared lane and run one private model process")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    require(30 <= args.timeout <= 900 and args.wait_lane >= 0, "Invalid bounded timeout/wait")
    if args.execute:
        execute(args)
    else:
        state = preflight(args.base_run, args.expect)
        print(json.dumps({"preflight": True, "expected": args.expect, "scripts": 23,
                          "native_assets": 1, "content_version": state["content_version"],
                          "pins": len(state["pins"]), "engine_started": False,
                          "baseline_defect_reproduced": False, "fixed_lifecycle_model_passed": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
