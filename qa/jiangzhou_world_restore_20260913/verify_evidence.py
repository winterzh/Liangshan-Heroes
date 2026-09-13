"""Verify explicit Jiangzhou/default-world and classic receipts, without Godot.

The previous verifier supplies unchanged archive, identity, source and classic
checks. This file defines the expanded 27-case scope and Jiangzhou assertions.
No raw receipt is edited; only --write-summary writes this directory's summary.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
COMMON_PATH = HERE.parent / "yezhulin_world_restore_20260913/verify_evidence.py"
SPEC = importlib.util.spec_from_file_location("previous_world_evidence", COMMON_PATH)
COMMON = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMMON)
require = COMMON.require
read = COMMON.read
sha = COMMON.sha
ROUTE = ["level2_cross_save", "level2_cross_alarm", "level2_cross_rescue",
         "level2_cross_escort", "level2_cross_board", "level2_cross_finish",
         "level2_terminal_reject"]
CASES = COMMON.DEFAULT_WORLD_CASES + ["level2_component"] + ROUTE
REQUIRED = {"scripts/run_level2_world_factory.gd", "scripts/levels/level2_jiangzhou_rts.gd",
            "scripts/run_scenery_state.gd", "scripts/run_visual_graph.gd",
            "scripts/run_battle_root_state.gd", "scripts/campaign_scenery.gd",
            "scripts/run_map_state.gd", "scripts/run_level2_world_factory.gd.uid"}
FIXTURES = ["paid_queue", "real_summons", "alarm_production", "song_freed",
            "both_freed", "one_embarked", "departure_ready", "dying_pursuer",
            "expired_pursuer_post"]


def verify(world_path, classic_path):
    receipt, steps, archived = COMMON.world_guards(world_path)
    require(receipt.get("complete") is True and receipt.get("full_suite") is True
            and receipt.get("acceptance_complete") is True, "fresh default world incomplete")
    require(len(CASES) == 27 and receipt["cases"] == CASES
            and list(steps) == ["import", "profile_guard"] + CASES,
            "27-case default coverage/order differs")
    # Revalidate all earlier chapter cases from this same newly executed batch.
    prior = COMMON.verify(world_path, world_path, classic_path)
    production = COMMON.production(receipt)
    require(REQUIRED <= production.keys(), "Jiangzhou production inventory missing")
    reports, counts = {}, {}
    for case in CASES:
        step = steps[case]
        COMMON.passed_step(world_path.parent, step)
        if case == "freeplay_core":
            log = (world_path.parent / "freeplay_core.log").read_text(encoding="utf-8")
            final = re.findall(r"(?m)^\[freeplay-core-result\] (.+)$", log)
            count = len(re.findall(r"(?m)^\[freeplay-core\] PASS ", log))
            require(len(final) == 1 and json.loads(final[0]).get("passed") is True
                    and "[freeplay-core] FAIL " not in log and count == receipt["freeplay_core_checks"],
                    "task-core evidence differs")
        else:
            name = case + "_report.json"
            require(name in archived, "report missing from SHA archive: " + case)
            report = read(world_path.parent / name)
            checks = report.get("checks", [])
            require(report.get("passed") is True and checks
                    and all(row.get("passed") is True for row in checks), "failed report: " + case)
            require(report.get("pid") == step["pid"]
                    and report.get("mode") == ("full" if case == "world_restore" else case),
                    "report process/mode differs: " + case)
            if case.startswith(("level2_", "level6_")):
                require(report.get("process_nonce") == step["process_nonce"], "report nonce differs")
            if case in COMMON.BASELINE_CASES:
                require(report.get("chapter") == ("level1" if case.startswith("level1_") else "level3"),
                        "earlier report chapter differs: " + case)
                if case in COMMON.HG_CASES:
                    require(report.get("process_nonce") == step["process_nonce"]
                            and report.get("actor_teleports") == 0 and report.get("stage_injections") == 0,
                            "Huang route process/natural scope differs")
                else:
                    key = "checks" if case == "world_restore" else case + "_checks"
                    require(receipt[key] == len(checks), "earlier receipt count differs: " + case)
            reports[case] = report
            count = len(checks)
        if case in COMMON.BASELINE_CASES:
            require(count == COMMON.BASELINE_CASES[case], "earlier baseline coverage changed: " + case)
        counts[case] = count
    require(receipt["total_checks"] == sum(counts.values()), "default total differs")
    require([row["case"] for row in receipt["level1_processes"]] == COMMON.HG_CASES,
            "Huang process coverage differs")
    for row in receipt["level1_processes"]:
        step = steps[row["case"]]
        for key in ["pid", "process_nonce", "started_ns", "finished_ns"]:
            require(row[key] == step[key], "Huang process/step binding differs")
        require(row["checks"] == counts[row["case"]], "Huang process count differs")
    require(prior["component_checks"] == 183, "Yezhulin component coverage changed")
    component = reports["level2_component"]
    require(component.get("fixture") is True and component.get("natural_route") is False
            and component.get("real_steam") is False, "component fixture scope missing")
    fixture_rows = [row for row in component["observations"] if "fixture" in row]
    require([row["fixture"] for row in fixture_rows] == FIXTURES
            and all(re.fullmatch(r"[0-9a-f]{64}", row["slot_sha256"]) for row in fixture_rows),
            "nine closed-slot component checkpoints missing")
    require(receipt["level2_component_checks"] == counts["level2_component"], "component count differs")
    rows = receipt["level2_processes"]
    require([row["case"] for row in rows] == ROUTE, "Jiangzhou process coverage differs")
    for index, row in enumerate(rows):
        step, value = steps[row["case"]], reports[row["case"]]
        for key in ["pid", "process_nonce", "started_ns", "finished_ns"]:
            require(row[key] == step[key], "Jiangzhou process/step binding differs")
        require(row["checks"] == counts[row["case"]], "route check count differs")
        require(value.get("chapter") == "level2" and value.get("full_world") is True
                and value.get("actor_teleports") == 0 and value.get("stage_injections") == 0
                and value.get("clock_acceleration") is False, "natural Jiangzhou scope differs")
        previous = rows[4]["pid"] if index == 6 else (rows[index - 1]["pid"] if index else 0)
        require(value["previous_pid"] == previous, "Jiangzhou cross-process source differs")
    wins = [row for row in reports[ROUTE[5]]["observations"] if "victory" in row]
    require(len(wins) == 1 and wins[0]["result"].get("story_complete") is True
            and wins[0]["result"].get("story_done") == 4
            and wins[0]["result"].get("story_total") == 4,
            "natural Jiangzhou 4/4 victory missing")
    refuses = [row["terminal_refusal"] for row in reports[ROUTE[6]]["observations"]
               if "terminal_refusal" in row]
    require(len(refuses) == 1 and refuses[0].get("ok") is False
            and refuses[0].get("code") == "LOCAL_RUN_TERMINAL", "terminal old-slot refusal missing")
    shots = {case + "_report_saved.png" for case in ROUTE[:5]}
    shots |= {case + "_report_restored.png" for case in ROUTE[1:6]}
    shots.add(ROUTE[5] + "_report_victory.png")
    require(shots <= archived.keys(), "native checkpoint screenshots missing")
    for name in shots:
        require((world_path.parent / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), "invalid PNG")
    return {"schema": "jiangzhou_world_validation_v1", "complete": True,
            "world_receipt": world_path.relative_to(ROOT).as_posix(),
            "classic_receipt": classic_path.relative_to(ROOT).as_posix(),
            "source_inventory_count": len(production), "source_files_match_current": True,
            "production_manifest_sha256": prior["production_manifest_sha256"],
            "world_qa_source_differences": prior["world_qa_source_differences"],
            "receipts": prior["receipts"],
            "world_receipt_sha256": sha(world_path), "classic_receipt_sha256": sha(classic_path),
            "world_checks": sum(counts.values()), "case_checks": counts,
            "classic_checks": prior["classic_checks"],
            "jiangzhou_screenshot_count": len(shots),
            "single_full_default_world_run_verified": True,
            "limits": ["All 27 cases are from one fresh default world batch; old receipts are unchanged.",
                       "Components use explicit fixtures; the Jiangzhou real-order route is separate.",
                       "No full 30-wave, nine-mode, live Steam, long-run, performance or human acceptance is inferred.",
                       "Image byte validation does not imply every screenshot received manual visual review."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full-world")
    parser.add_argument("--classic-receipt")
    parser.add_argument("--write-summary", action="store_true")
    args = parser.parse_args()
    if not args.full_world or not args.classic_receipt:
        print(json.dumps({"complete": False, "status": "pending", "reason": "Explicit fresh world and classic candidates required."}))
        return 2
    try:
        result = verify(COMMON.candidate(args.full_world), COMMON.candidate(args.classic_receipt))
        if args.write_summary:
            (HERE / "validation_summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
        print(json.dumps({"complete": False, "reason": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
