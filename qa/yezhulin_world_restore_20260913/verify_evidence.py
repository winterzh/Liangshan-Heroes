"""Read-only candidate verification; no successful receipts are selected yet.

No arguments: report pending and exit 2. Explicit candidates must pass all
checks before --write-summary can create this aggregate's own JSON. Raw
receipts, player files, production files and Godot are never modified/run.
"""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ROUTE_CASES = ["level6_cross_save", "level6_cross_rescue", "level6_cross_care",
               "level6_cross_escort", "level6_cross_leave", "level6_cross_finish",
               "level6_terminal_reject"]
HG_CASES = ["level1_cross_save", "level1_cross_arrival", "level1_cross_wine",
            "level1_cross_cargo", "level1_cross_finish", "level1_terminal_reject"]
BASELINE_CASES = {"freeplay_core": 28, "world_restore": 67, "cross_save": 8,
                  "cross_resume": 18, "level1_component": 46,
                  **dict(zip(HG_CASES, [20, 50, 50, 76, 53, 9]))}
DEFAULT_WORLD_CASES = list(BASELINE_CASES) + ["level6_component"] + ROUTE_CASES
CLASSIC_CASES = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle",
                 "unsaved_terminal", "capture", "restore_and_overwrite", "restore_again",
                 "pending_retry", "held_error", "terminal", "terminal_reject"]
REQUIRED_PRODUCTION = {"project.godot", "scripts/battle.gd", "scripts/unit.gd",
                       "scripts/levels/level6_yezhulin.gd", "scripts/run_level6_world_factory.gd",
                       "scripts/run_unit_graph.gd", "scripts/run_unit_state.gd",
                       "scripts/run_battle_world_core.gd", "scripts/run_world_session.gd"}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def contained(base, relative):
    path = (base / relative).resolve()
    require(path.is_relative_to(base.resolve()), "path escapes its evidence root: " + str(relative))
    return path


def candidate(value):
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    require(path.name == "receipt.json" and path.is_relative_to(ROOT / "qa"),
            "candidate must be an archived qa receipt.json")
    require(path.is_file(), "candidate receipt missing: " + str(path))
    return path


def inventory(receipt):
    rows = receipt["source_files"]
    result = {row["path"]: row["sha256"] for row in rows}
    require(len(result) == len(rows), "duplicate source paths")
    require(REQUIRED_PRODUCTION <= result.keys(), "incomplete declared production inventory")
    for name in result:
        contained(ROOT, name)
    return result


def production(receipt):
    result = {name: digest for name, digest in inventory(receipt).items()
              if not name.startswith("tools/")}
    current = current_production_paths()
    require(result.keys() == current,
            "declared production inventory differs from current git inventory: "
            + json.dumps({"missing": sorted(current - result.keys()),
                          "extra": sorted(result.keys() - current)}, ensure_ascii=False))
    return result


def current_production_paths():
    # Read the production selector's literal sets without importing/executing
    # a QA driver. Match its cached + nonignored untracked enumeration exactly.
    selector = ROOT / "tools/run_steam_integration_qa.py"
    tree = ast.parse(selector.read_text(encoding="utf-8"))
    filters = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id in {"ROOT_FILES", "RUNTIME_DIRS"}:
                require(target.id not in filters, "duplicate production selector declaration")
                value = ast.literal_eval(node.value)
                require(isinstance(value, set) and value and all(isinstance(name, str) for name in value),
                        "production selector must remain an explicit string set")
                filters[target.id] = value
    require(filters.keys() == {"ROOT_FILES", "RUNTIME_DIRS"}, "production selector declarations missing")
    raw = subprocess.check_output(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                                  cwd=ROOT, timeout=30)
    names = set(raw.decode("utf-8").split("\0")) - {""}
    return {name for name in names if name in filters["ROOT_FILES"]
            or name.split("/")[0] in filters["RUNTIME_DIRS"]}


def steps(receipt):
    result = {step["case"]: step for step in receipt["steps"]}
    require(len(result) == len(receipt["steps"]), "duplicate step cases")
    nonces, previous_end = set(), 0
    for step in receipt["steps"]:
        nonce = step["process_nonce"]
        require(isinstance(nonce, str) and nonce and nonce not in nonces,
                "missing or duplicate process nonce")
        require(step["pid"] > 0 and step["started_ns"] >= previous_end
                and step["finished_ns"] > step["started_ns"], "invalid/overlapping process interval")
        nonces.add(nonce)
        previous_end = step["finished_ns"]
    return result


def passed_step(directory, step):
    require(step["exit_code"] == step["expected_exit_code"] and step["errors"] == 0
            and not step.get("stop_reason"), "failed step: " + step["case"])
    log = directory / (step["case"] + ".log")
    require(sha(log) == step["log_sha256"], "step log SHA mismatch: " + step["case"])


def profile_guard(directory, step_map, world=False):
    guard = step_map["profile_guard"]
    require(guard["expected_exit_code"] == 2 and guard["exit_code"] == 2,
            "profile guard did not use the intended refusal exit code")
    log = (directory / "profile_guard.log").read_text(encoding="utf-8")
    require("PRIVATE_PROFILE_REQUIRED" in log, "profile guard refusal marker missing")
    require("report_sha256" not in guard, "profile guard unexpectedly owns a report hash")
    require(not (directory / "profile_guard.json").exists()
            and not (directory / "profile_guard_report.json").exists(), "unexpected profile-guard report")
    if not world:
        return
    # The world runner reuses world_restore_report.json after the guard for
    # the later full world_restore case. A final archive proves ownership of
    # that later report, not absence at the earlier guard's historical instant.
    shared_report = directory / "world_restore_report.json"
    if "world_restore" not in step_map:
        require(not shared_report.exists(), "world guard wrote the otherwise unused shared report")
    elif shared_report.exists():
        later = step_map["world_restore"]
        value = read(shared_report)
        require(later["started_ns"] >= guard["finished_ns"] and later["pid"] != guard["pid"]
                and value.get("pid") == later["pid"] and value.get("mode") == "full"
                and value.get("chapter") == "level3", "shared world report belongs to the wrong process")


def report(directory, step, suffix="_report.json"):
    path = directory / (step["case"] + suffix)
    value = read(path)
    rows = value["checks"]
    require(value.get("passed") is True and rows
            and all(row.get("passed") is True for row in rows), "report has failures: " + path.name)
    require(value.get("mode", value.get("case")) == step["case"]
            and value.get("pid") == step["pid"]
            and value.get("process_nonce") == step["process_nonce"], "report process binding mismatch")
    return value


def world_guards(path):
    receipt = read(path)
    require(receipt.get("fresh_import") is True, "cached diagnostic is not a fresh-import candidate")
    require(receipt.get("source_changes") == [] and receipt.get("lock_released") is True
            and receipt.get("engines_after") == [] and receipt.get("protected_player_unchanged") is True,
            "world source/player/process/lock guards failed")
    require(receipt.get("phase_guards")
            and all(row.get("passed") is True for row in receipt["phase_guards"]), "phase guards failed")
    require(receipt["source_guard_checks"] == 2 * len(receipt["source_files"]), "source guard coverage differs")
    require(receipt["acceptance_complete"] is
            (receipt["complete"] and receipt["full_suite"] and receipt["fresh_import"]), "raw acceptance flag inconsistent")
    archived = {}
    for row in receipt["files"]:
        require(row["path"] not in archived, "duplicate archived artifact")
        artifact = contained(path.parent, row["path"])
        require(artifact.is_file() and artifact.stat().st_size == row["bytes"]
                and sha(artifact) == row["sha256"], "archived artifact mismatch: " + row["path"])
        archived[row["path"]] = row["sha256"]
    require(archived, "archive inventory missing")
    step_map = steps(receipt)
    for name in ["import", "profile_guard"]:
        passed_step(path.parent, step_map[name])
    profile_guard(path.parent, step_map, world=True)
    return receipt, step_map, archived


def classic_check(path, expected_production, engine_sha):
    receipt = read(path)
    require(receipt.get("complete") is True and receipt.get("fresh_import") is True
            and receipt.get("terminal_only") is False, "classic default candidate incomplete")
    require(receipt["cases"] == CLASSIC_CASES and [row["case"] for row in receipt["steps"]] == CLASSIC_CASES,
            "classic default coverage differs")
    require(receipt.get("source_changes") == [] and receipt.get("lock_released") is True
            and receipt.get("source_inventory_matches") is True and receipt.get("engine_unchanged") is True
            and receipt.get("scene_unchanged") is True and not receipt.get("engine_running_at_release"),
            "classic guards failed")
    require(production(receipt) == expected_production and receipt["godot_sha256"] == engine_sha,
            "classic production or engine differs")
    count = 0
    step_map = steps(receipt)
    profile_guard(path.parent, step_map)
    for step in step_map.values():
        passed_step(path.parent, step)
        if step["case"] in ["import", "profile_guard"]:
            continue
        report_path = path.parent / (step["case"] + ".json")
        require(sha(report_path) == step["report_sha256"], "classic report SHA mismatch")
        value = report(path.parent, step, ".json")
        if step["case"] in ["capture", "restore_and_overwrite", "restore_again", "pending_retry"]:
            operation = value.get("result")
            require(isinstance(operation, dict) and operation.get("ok") is True,
                    "classic save/restore operation did not succeed: " + step["case"])
        count += len(value["checks"])
    require(count == receipt["checks"], "classic total differs")
    expected_shots = {state + "_" + language + ".png"
                      for state in ["overwrite_confirm", "pending_save", "held_error", "terminal_pending"]
                      for language in ["zh_CN", "zh_TW", "en", "ja"]}
    require(len(receipt["screenshots"]) == len(expected_shots)
            and {row["path"] for row in receipt["screenshots"]} == expected_shots, "classic screenshot coverage differs")
    for row in receipt["screenshots"]:
        require(sha(contained(path.parent / "screenshots", row["path"])) == row["sha256"], "classic screenshot SHA mismatch")
    return receipt, count


def verify(component_path, route_path, classic_path=None):
    component_receipt, component_steps, component_files = world_guards(component_path)
    if component_path == route_path:
        route_receipt, route_steps, route_files = component_receipt, component_steps, component_files
    else:
        route_receipt, route_steps, route_files = world_guards(route_path)
    component_step = component_steps["level6_component"]
    passed_step(component_path.parent, component_step)
    require("level6_component_report.json" in component_files, "component report not covered by archive SHA")
    component = report(component_path.parent, component_step)
    require(component.get("fixture") is True and component.get("natural_route") is False
            and component.get("real_steam") is False, "component scope markers differ")
    component_count = len(component["checks"])
    require(component_receipt["level6_component_checks"] == component_count, "component count differs")
    require(route_receipt.get("complete") is True, "seven-process batch is incomplete")
    require([case for case in route_receipt["cases"] if case.startswith("level6_") and case != "level6_component"] == ROUTE_CASES,
            "seven-process requested coverage differs")
    rows = route_receipt["level6_processes"]
    require([row["case"] for row in rows] == ROUTE_CASES, "seven-process actual coverage differs")
    route_count, reports = 0, {}
    for index, row in enumerate(rows):
        step = route_steps[row["case"]]
        passed_step(route_path.parent, step)
        for key in ["pid", "process_nonce", "started_ns", "finished_ns"]:
            require(row[key] == step[key], "route process/step mismatch: " + key)
        require(row["case"] + "_report.json" in route_files, "route report not covered by archive SHA")
        value = report(route_path.parent, step)
        require(value.get("chapter") == "level6" and value.get("full_world") is True
                and value.get("actor_teleports") == 0 and value.get("stage_injections") == 0
                and value.get("clock_acceleration") is False, "natural-route scope differs")
        previous = rows[4]["pid"] if index == 6 else (rows[index - 1]["pid"] if index else 0)
        require(value["previous_pid"] == previous, "route handoff process mismatch")
        require(len(value["checks"]) == row["checks"], "route check count differs")
        route_count += row["checks"]
        reports[row["case"]] = value
    victories = [row for row in reports[ROUTE_CASES[5]]["observations"] if "victory" in row]
    require(len(victories) == 1, "one natural victory observation required")
    victory = victories[0]
    require(victory["result"].get("story_complete") is True
            and victory["result"].get("story_done") == 3 and victory["result"].get("story_total") == 3
            and victory["victory"]["level"].get("victory") is True
            and len(victory["victory"]["active"]) == 4, "four-person 3/3 victory evidence differs")
    refusals = [row["terminal_refusal"] for row in reports[ROUTE_CASES[6]]["observations"] if "terminal_refusal" in row]
    require(len(refusals) == 1 and refusals[0].get("ok") is False
            and refusals[0].get("code") == "LOCAL_RUN_TERMINAL", "specific terminal refusal missing")
    expected_shots = {case + "_report_saved.png" for case in ROUTE_CASES[:5]}
    expected_shots |= {case + "_report_restored.png" for case in ROUTE_CASES[1:6]}
    expected_shots.add(ROUTE_CASES[5] + "_report_victory.png")
    require(expected_shots <= route_files.keys(), "native checkpoint screenshot coverage missing")
    for name in expected_shots:
        require((route_path.parent / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), "screenshot is not PNG")
    p = production(component_receipt)
    require(p == production(route_receipt), "component and route production inventories/bytes differ")
    require(component_receipt["godot_sha256"] == route_receipt["godot_sha256"], "world engines differ")
    for name, digest in p.items():
        require(sha(contained(ROOT, name)) == digest, "checkout differs from tested production: " + name)
    sources = [(component_path, component_receipt)]
    if route_path != component_path:
        sources.append((route_path, route_receipt))
    classic_count = None
    if classic_path is not None:
        classic_receipt, classic_count = classic_check(classic_path, p, route_receipt["godot_sha256"])
        sources.append((classic_path, classic_receipt))
    first_sources, last_sources = inventory(component_receipt), inventory(route_receipt)
    differences = sorted(name for name in first_sources.keys() | last_sources.keys()
                         if first_sources.get(name) != last_sources.get(name))
    return {"schema": "yezhulin_world_validation_v1", "status": "verified",
            "yezhulin_world_validation_complete": True, "component_checks": component_count,
            "route_checks": route_count, "yezhulin_checks": component_count + route_count,
            "route_processes": rows, "classic_default_verified": classic_path is not None,
            "classic_checks": classic_count, "production_file_count": len(p),
            "production_manifest_sha256": hashlib.sha256(json.dumps(p, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
            "production_matches_current_checkout": True, "world_qa_source_differences": differences,
            "native_route_screenshots_sha_verified": sorted(expected_shots),
            "manual_visual_review_performed_by_this_script": False,
            "public_continue_acceptance": False, "steam_release_performed": False,
            "receipts": [{"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path),
                          "raw_complete": receipt["complete"],
                          "raw_acceptance_complete": receipt.get("acceptance_complete"),
                          "raw_fresh_import": receipt["fresh_import"]} for path, receipt in sources],
            "limits": ["Only named Level6 component and seven-process cases are aggregated; raw receipts are unchanged.",
                       "Component early-force/death setup is an explicit fixture; the natural route covers the south route only.",
                       "No manual screenshot review, nine-mode, full 30-wave, live Steam, long-run, performance or human acceptance is inferred."]}


def verify_full_world(path, classic_path=None):
    receipt = read(path)
    require(receipt.get("complete") is True and receipt.get("full_suite") is True
            and receipt.get("fresh_import") is True and receipt.get("acceptance_complete") is True,
            "full default world candidate must be complete and freshly imported")
    require(len(DEFAULT_WORLD_CASES) == 19 and receipt["cases"] == DEFAULT_WORLD_CASES
            and [step["case"] for step in receipt["steps"]] == ["import", "profile_guard"] + DEFAULT_WORLD_CASES,
            "full default world 19-case coverage/order differs")
    summary = verify(path, path, classic_path)
    step_map = steps(receipt)
    archived = {row["path"]: row for row in receipt["files"]}
    baseline_count = 0
    for case, expected_count in BASELINE_CASES.items():
        step = step_map[case]
        passed_step(path.parent, step)
        if case == "freeplay_core":
            log = (path.parent / "freeplay_core.log").read_text(encoding="utf-8")
            finals = re.findall(r"(?m)^\[freeplay-core-result\] (.+)$", log)
            count = len(re.findall(r"(?m)^\[freeplay-core\] PASS ", log))
            require(len(finals) == 1 and read_json_line(finals[0]).get("passed") is True
                    and "[freeplay-core] FAIL " not in log, "task core report incomplete")
            require(receipt["freeplay_core_checks"] == count, "task core receipt count differs")
        else:
            name = case + "_report.json"
            require(name in archived, "baseline report not covered by archived SHA: " + name)
            value = read(path.parent / name)
            require(value.get("passed") is True and value.get("checks")
                    and all(row.get("passed") is True for row in value["checks"]), "baseline report failed: " + case)
            require(value.get("pid") == step["pid"]
                    and value.get("mode") == ("full" if case == "world_restore" else case), "baseline report identity differs")
            require(value.get("chapter") == ("level1" if case.startswith("level1_") else "level3"), "baseline report chapter differs")
            count = len(value["checks"])
            if case in HG_CASES:
                require(value.get("process_nonce") == step["process_nonce"]
                        and value.get("actor_teleports") == 0 and value.get("stage_injections") == 0,
                        "Huang route identity or natural scope differs")
            else:
                key = "checks" if case == "world_restore" else case + "_checks"
                require(receipt[key] == count, "baseline receipt count differs: " + case)
        require(count == expected_count, "baseline count changed: " + case)
        baseline_count += count
    require(baseline_count == 425, "existing world regression subtotal differs")
    require([row["case"] for row in receipt["level1_processes"]] == HG_CASES, "Huang process coverage differs")
    for row in receipt["level1_processes"]:
        step = step_map[row["case"]]
        for key in ["pid", "process_nonce", "started_ns", "finished_ns"]:
            require(row[key] == step[key], "Huang process/step binding differs")
        require(row["checks"] == BASELINE_CASES[row["case"]], "Huang process count differs")
    require(summary["component_checks"] == 183, "Yezhulin full component count changed")
    total = baseline_count + summary["component_checks"] + summary["route_checks"]
    require(receipt["total_checks"] == total, "full default world check total differs")
    summary.update({"single_full_default_world_run_verified": True,
                    "default_world_cases": DEFAULT_WORLD_CASES,
                    "baseline_regression_cases": BASELINE_CASES,
                    "baseline_regression_checks": baseline_count, "world_checks": total,
                    "evidence_is_staged_from_old_batches": False})
    summary["limits"][0] = "All 19 cases are verified from one complete fresh default world receipt; no old staged evidence is reused."
    return summary


def read_json_line(value):
    return json.loads(value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full-world", help="Final candidate: one complete fresh 19-case default world receipt")
    parser.add_argument("--component-receipt")
    parser.add_argument("--route-receipt")
    parser.add_argument("--classic-receipt")
    parser.add_argument("--write-summary", action="store_true")
    args = parser.parse_args()
    if not args.full_world and (not args.component_receipt or not args.route_receipt):
        print(json.dumps({"schema": "yezhulin_world_validation_v1", "status": "pending",
                          "yezhulin_world_validation_complete": False,
                          "reason": "An explicit full default world candidate, or both diagnostic component/route candidates, is required."}))
        return 2
    try:
        require(not args.full_world or not (args.component_receipt or args.route_receipt), "do not mix full-world and staged diagnostic candidates")
        require(not args.write_summary or (args.full_world and args.classic_receipt),
                "final summary requires one fresh full default world candidate and a same-version fresh classic default candidate")
        classic_path = candidate(args.classic_receipt) if args.classic_receipt else None
        summary = (verify_full_world(candidate(args.full_world), classic_path) if args.full_world
                   else verify(candidate(args.component_receipt), candidate(args.route_receipt), classic_path))
        if args.write_summary:
            (HERE / "validation_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(summary, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.SubprocessError) as exc:
        print(json.dumps({"status": "failed", "yezhulin_world_validation_complete": False, "reason": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
