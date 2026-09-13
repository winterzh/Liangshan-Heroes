"""Verify one fresh 37-case world batch and same-source classic 296 receipt.

No arguments: pending, exit 2, without loading a helper or reading evidence.
Full verification uses the unchanged Yezhulin helper's read-only Git inventory
and hashes. Only --write-summary writes this new aggregate's own summary.
The historical Jiangzhou validator, summaries and raw receipts are immutable.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
COMMON_PATH = HERE.parent / "yezhulin_world_restore_20260913/verify_evidence.py"
COMMON = None
COMMON_SHA256 = "37c4cb06841d116cce2c459f73fe4cae5594335345f86ae92cc36eb2f61119cb"
JIANG_COPY_SHA256 = "04ae0109c9133d51121696d88362dc1c4267942763e95bc4fe6337be6ab418fe"
HG_CASES = ["level1_cross_save", "level1_cross_arrival", "level1_cross_wine",
            "level1_cross_cargo", "level1_cross_finish", "level1_terminal_reject"]
BASELINE_CASES = {"freeplay_core": 28, "world_restore": 67, "cross_save": 8,
                  "cross_resume": 18, "level1_component": 46,
                  **dict(zip(HG_CASES, [20, 50, 50, 76, 53, 9]))}
LEVEL6_CASES = ["level6_cross_save", "level6_cross_rescue", "level6_cross_care",
                "level6_cross_escort", "level6_cross_leave", "level6_cross_finish",
                "level6_terminal_reject"]
EARLIER_CASES = list(BASELINE_CASES) + ["level6_component"] + LEVEL6_CASES
ROUTE = ["level2_cross_save", "level2_cross_alarm", "level2_cross_rescue",
         "level2_cross_escort", "level2_cross_board", "level2_cross_finish",
         "level2_terminal_reject"]
KUAI_ROUTE = ["level7_cross_save", "level7_cross_drill", "level7_cross_fist",
              "level7_cross_rush", "level7_cross_opening", "level7_cross_subdued",
              "level7_cross_terms", "level7_cross_finish", "level7_terminal_reject"]
CASES = EARLIER_CASES + ["level2_component"] + ROUTE + ["level7_component"] + KUAI_ROUTE
REQUIRED = {"scripts/run_level2_world_factory.gd", "scripts/levels/level2_jiangzhou_rts.gd",
            "scripts/run_scenery_state.gd", "scripts/run_visual_graph.gd",
            "scripts/run_battle_root_state.gd", "scripts/campaign_scenery.gd",
            "scripts/run_map_state.gd", "scripts/run_level2_world_factory.gd.uid"}
REQUIRED |= {"scripts/run_level7_world_factory.gd", "scripts/run_level7_world_factory.gd.uid",
             "scripts/run_level7_visual_state.gd", "scripts/run_level7_visual_state.gd.uid",
             "scripts/levels/level7_kuaihuolin_short.gd", "scripts/levels/level7_kuaihuolin.gd",
             "scripts/campaign_mengzhou_gate.gd"}
FIXTURES = ["paid_queue", "real_summons", "alarm_production", "song_freed",
            "both_freed", "one_embarked", "departure_ready", "dying_pursuer",
            "expired_pursuer_post"]
KUAI_FIXTURES = ["road", "sober_steady", "sober_expired", "steady_then_drink",
                 "four_taverns", "four_steady", "drill_tell", "heavy_windup",
                 "moved_w_before_e", "verified_counter", "rush_windup", "charge_hit_sign",
                 "subdued_alive", "subdued_offscreen", "terms_before_shop"]
WORLD_TOOLS = {"tools/campaign_freeplay_core_test.gd", "tools/level3_world_restore_qa.gd",
               "tools/level1_world_restore_qa.gd", "tools/level1_cross_process_qa.gd",
               "tools/level6_world_restore_qa.gd", "tools/level6_cross_process_qa.gd",
               "tools/level2_world_restore_qa.gd", "tools/level2_cross_process_qa.gd",
               "tools/level7_world_restore_qa.gd", "tools/level7_cross_process_qa.gd",
               "tools/run_level3_world_restore_qa.py", "tools/run_steam_integration_qa.py"}
CLASSIC_TOOLS = {"tools/continue_flow_qa.gd", "tools/run_continue_flow_qa.py",
                 "tools/run_campaign_level_state_qa.py", "tools/run_steam_integration_qa.py"}
SCENES = {"level3_world_restore_qa.tscn": "generated_scene_sha256"}
for _level in [1, 6, 2, 7]:
    SCENES["level%d_world_restore_qa.tscn" % _level] = "generated_level%d_scene_sha256" % _level
    SCENES["level%d_cross_process_qa.tscn" % _level] = "generated_level%d_cross_scene_sha256" % _level


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_common():
    global COMMON
    if COMMON is None:
        require(COMMON_PATH.is_file(), "Install this candidate under qa/kuaihuolin_world_restore_20260913 before full verification")
        helper_bytes = COMMON_PATH.read_bytes()
        require(hashlib.sha256(helper_bytes).hexdigest() == COMMON_SHA256, "immutable Yezhulin helper bytes changed")
        require(sha(HERE.parent / "jiangzhou_world_restore_20260913/verify_evidence.py") == JIANG_COPY_SHA256,
                "immutable Jiangzhou validator bytes changed")
        spec = importlib.util.spec_from_file_location("immutable_world_evidence", COMMON_PATH)
        module = importlib.util.module_from_spec(spec)
        # Execute the exact checked source without writing a __pycache__ file
        # beside the immutable historical evidence, even if -B was omitted.
        exec(compile(helper_bytes, str(COMMON_PATH), "exec"), module.__dict__)
        require(module.DEFAULT_WORLD_CASES == EARLIER_CASES and module.BASELINE_CASES == BASELINE_CASES,
                "earlier 19-case helper scope differs")
        COMMON = module
    return COMMON


def checked_tools(receipt, expected):
    inventory = COMMON.inventory(receipt)
    tools = {name: digest for name, digest in inventory.items() if name.startswith("tools/")}
    require(tools.keys() == expected, "tested QA tool inventory differs")
    for name, digest in tools.items():
        require(sha(COMMON.contained(ROOT, name)) == digest, "current QA tool differs from tested source: " + name)
    return tools


def checked_snapshots(world_path, receipt, archived):
    source_rows = {row["path"]: row for row in receipt["source_files"]}
    snapshots = {row["path"]: row for row in receipt["source_snapshot"]}
    require(len(snapshots) == len(receipt["source_snapshot"]), "duplicate source snapshot path")
    require(REQUIRED | WORLD_TOOLS | SCENES.keys() <= snapshots.keys(), "required source/QA/scene snapshot missing")
    require("source_manifest.json" in archived, "source manifest is not in archived SHA inventory")
    manifest = read(world_path.parent / "source_manifest.json")
    require(manifest.get("sources") == receipt["source_files"] and manifest.get("snapshots") == receipt["source_snapshot"]
            and manifest.get("generated_scene_sha256") == receipt["generated_scene_sha256"], "source manifest differs from raw receipt")
    for name, row in snapshots.items():
        path = "source_snapshot/" + name
        require(path in archived and archived[path] == row["sha256"], "snapshot not bound to archive: " + name)
        snapshot = COMMON.contained(world_path.parent, path)
        require(snapshot.stat().st_size == row["bytes"], "snapshot size differs")
        if name in SCENES:
            require(row["sha256"] == receipt[SCENES[name]], "generated scene snapshot differs")
        else:
            require(name in source_rows and row["sha256"] == source_rows[name]["sha256"]
                    and row["bytes"] == source_rows[name]["bytes"], "source snapshot differs from tested bytes: " + name)


def kuai_component(component):
    require(component.get("chapter") == "level7" and component.get("fixture") is True
            and component.get("natural_route") is False and component.get("real_steam") is False,
            "Kuaihuolin component scope differs")
    observations = component.get("observations")
    require(isinstance(observations, list) and all(isinstance(row, dict) for row in observations), "Kuai component observations malformed")
    fixtures = [row for row in observations if "fixture" in row]
    require([row["fixture"] for row in fixtures] == KUAI_FIXTURES, "15 Kuai component checkpoints missing or reordered")
    for row in fixtures:
        require(isinstance(row.get("slot_sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", row["slot_sha256"])
                and row.get("root_entities") == 8 and row.get("active_entities") == 8,
                "Kuai component closed slot/eight-entity state missing")
    deaths = [row for row in observations if "death_fixture" in row]
    require([row["death_fixture"] for row in deaths] == ["wu", "shi"]
            and all(isinstance(row.get("save_result"), dict) and row["save_result"].get("ok") is False for row in deaths),
            "both essential-hero death save refusals missing")


def distance_squared(a, b):
    require(isinstance(a, list) and isinstance(b, list) and len(a) == len(b) == 2
            and all(type(value) in [int, float] and math.isfinite(value) for value in a + b), "Kuai vector observation malformed")
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2


def kuai_state(state, lineage):
    require(isinstance(state, dict), "Kuai checkpoint state missing")
    units = state.get("units")
    require(isinstance(units, list) and len(units) == 8 and all(isinstance(row, dict) for row in units), "Kuai checkpoint root entities differ")
    indexed = {row["id"]: row for row in units}
    require(len(indexed) == 8 and set(indexed) == set(lineage["entities"])
            and len(state["active"]) == 8 and set(state["active"]) == set(indexed)
            and all(type(row.get("hp")) in [int, float] and math.isfinite(row["hp"]) and row["hp"] > 0 and row.get("dying") is False for row in units),
            "Kuai original eight living active entities differ")
    roles = state["roles"]
    require([roles["wu"], roles["shi"]] + [row["id"] for row in roles["taverns"]] + [roles["menshen"], roles["sign"]] == lineage["entities"],
            "Kuai role mapping differs from original lineage")
    return indexed


def kuai_route(reports, rows, steps, counts):
    require([row["case"] for row in rows] == KUAI_ROUTE, "nine Kuai processes missing or reordered")
    first_lineage = reports[KUAI_ROUTE[0]].get("lineage")
    entities = first_lineage.get("entities") if isinstance(first_lineage, dict) else None
    require(isinstance(entities, list) and len(entities) == 8
            and all(isinstance(value, str) and re.fullmatch(r"[1-9][0-9]*", value) for value in entities)
            and len(set(entities)) == 8, "Kuai original entity lineage malformed")
    saved_states = {}
    for index, row in enumerate(rows):
        case = row["case"]
        step, report = steps[case], reports[case]
        for key in ["pid", "process_nonce", "started_ns", "finished_ns"]:
            require(row[key] == step[key], "Kuai process/step identity differs")
        require(row["checks"] == counts[case], "Kuai process count differs")
        require(report.get("chapter") == "level7" and report.get("full_world") is True
                and report.get("actor_teleports") == 0 and report.get("stage_injections") == 0
                and report.get("clock_acceleration") is False and report.get("lineage") == first_lineage,
                "Kuai natural scope/original lineage differs")
        previous = rows[6]["pid"] if index == 8 else rows[index - 1]["pid"] if index else 0
        require(report.get("previous_pid") == previous, "Kuai previous process not bound to this batch")
        observations = report.get("observations")
        require(isinstance(observations, list) and all(isinstance(value, dict) and "failure" not in value for value in observations), "Kuai natural observations malformed or failed")
        saved = [value["saved"] for value in observations if "saved" in value]
        restored = [value["restored"] for value in observations if "restored" in value]
        require(len(saved) == (1 if index < 7 else 0) and len(restored) == (1 if 0 < index < 8 else 0), "Kuai saved/restored checkpoint coverage differs")
        if restored:
            require(restored[0] == saved_states[KUAI_ROUTE[index - 1]], "Kuai restored observation differs from preceding saved observation")
            kuai_state(restored[0], first_lineage)
        if saved:
            state = saved[0]
            indexed = kuai_state(state, first_lineage)
            saved_states[case] = state
            level, tells, events = state["level"], state["tells"], state["mission"]["events"]
            require(level.get("victory") is False and "restore_shop" not in events, "Kuai live checkpoint claims shop victory")
            if index == 0:
                require(level["st"] == 0 and level["drunk"] == 1, "Kuai first road checkpoint differs")
            elif index == 1:
                require(level["st"] == 1 and level["drunk"] == 4 and isinstance(tells["drill_marker"], dict), "Kuai four-tavern live drill missing")
            elif index == 2:
                require(level["st"] == 2 and level["fist_windup"] > 0.5 and level["special_kind"] == "heavy"
                        and tells["fist_marker"]["kind"] == "heavy", "Kuai live heavy checkpoint missing")
            elif index == 3:
                menshen = indexed[state["roles"]["menshen"]]
                require(level["charge_running"] is True and level["fist_windup"] == 0 and level["special_kind"] == "rush"
                        and menshen["_charge_dash"] > 0 and distance_squared(menshen["position"], level["rush_from"]) > 1.0
                        and tells["fist_marker"]["progress"] == 1 and tells["fist_marker"]["kind"] == "rush",
                        "Kuai actual in-flight rush checkpoint missing")
            elif index == 4:
                wu = indexed[state["roles"]["wu"]]
                require(level["exposed_left"] > 0.6 and level["step_serial"] == level["opening_serial"] > 0
                        and level["counter_hits"] == 0 and "mengzhou_signature" not in events
                        and distance_squared(wu["position"], level["step_origin"]) >= 24.0 ** 2,
                        "Kuai moved W opening before E missing")
                before = restored[0]
                prior_level = before["level"]
                prior_units = kuai_state(before, first_lineage)
                menshen = indexed[state["roles"]["menshen"]]
                prior_menshen = prior_units[before["roles"]["menshen"]]
                require(level["special_kind"] == "rush" and level["charge_running"] is False
                        and level["special_index"] == level["opening_serial"] == prior_level["special_index"]
                        and level["rush_dodges"] == prior_level["rush_dodges"] + 1
                        and level["heavy_dodges"] == prior_level["heavy_dodges"] > 0
                        and menshen["_charge_dash"] == 0 and menshen["_charge_t"] == 0
                        and state["roles"]["wu"] not in menshen["charge_hit"]
                        and state["roles"]["shi"] not in menshen["charge_hit"]
                        and distance_squared(menshen["position"], prior_menshen["position"]) > 1.0
                        and events.get("dodge_heavy") is True and events.get("dodge_rush") is True,
                        "Kuai same restored rush movement and native miss completion missing")
            else:
                menshen = indexed[state["roles"]["menshen"]]
                require(level["st"] == 3 and menshen["outcome"] == "subdued", "Kuai living subdual checkpoint missing")
                require(("terms" in events) == (index == 6), "Kuai terms checkpoint differs")
        if index == 7:
            wins = [value for value in observations if "victory" in value]
            require(len(wins) == 1 and wins[0].get("result", {}).get("story_complete") is True
                    and wins[0]["result"].get("story_done") == 4 and wins[0]["result"].get("story_total") == 4
                    and wins[0]["victory"]["level"].get("victory") is True, "Kuai actual 4/4 victory missing")
            indexed = kuai_state(wins[0]["victory"], first_lineage)
            require(indexed[wins[0]["victory"]["roles"]["menshen"]]["outcome"] == "subdued", "Kuai victory killed Menshen")
        if index == 8:
            refuses = [value["terminal_refusal"] for value in observations if "terminal_refusal" in value]
            require(len(refuses) == 1 and refuses[0].get("ok") is False and refuses[0].get("code") == "LOCAL_RUN_TERMINAL", "Kuai terms-slot terminal refusal missing")


def verify(world_path, classic_path):
    load_common()
    receipt, steps, archived = COMMON.world_guards(world_path)
    require(receipt.get("complete") is True and receipt.get("full_suite") is True
            and receipt.get("acceptance_complete") is True and receipt.get("level7_uid_inventory_complete") is True,
            "fresh default world incomplete or actual Level7 UID inputs missing")
    require(len(CASES) == 37 and receipt["cases"] == CASES
            and list(steps) == ["import", "profile_guard"] + CASES,
            "37-case default coverage/order differs")
    labels = [case + suffix for case in ["import", "profile_guard"] + CASES for suffix in ["_before", "_after"]]
    require([row["label"] for row in receipt["phase_guards"]] == labels, "full phase-guard coverage/order differs")
    # Revalidate all earlier chapter cases from this same newly executed batch.
    prior = COMMON.verify(world_path, world_path, classic_path)
    require(prior["classic_checks"] == 296, "classic 296 coverage changed")
    production = COMMON.production(receipt)
    require(REQUIRED <= production.keys(), "Jiangzhou/Kuaihuolin production inventory missing")
    world_tools = checked_tools(receipt, WORLD_TOOLS)
    classic_tools = checked_tools(read(classic_path), CLASSIC_TOOLS)
    checked_snapshots(world_path, receipt, archived)
    reports, counts = {}, {}
    for case in CASES:
        step = steps[case]
        require(step["expected_exit_code"] == 0, "gameplay step has an unexpected success exit code")
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
            if case.startswith(("level2_", "level6_", "level7_")):
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
    kuai_component(reports["level7_component"])
    require(receipt["level7_component_checks"] == counts["level7_component"], "Kuai component count differs")
    kuai_route(reports, receipt["level7_processes"], steps, counts)
    kuai_shots = {case + "_report_saved.png" for case in KUAI_ROUTE[:7]}
    kuai_shots |= {case + "_report_restored.png" for case in KUAI_ROUTE[1:8]}
    kuai_shots.add(KUAI_ROUTE[7] + "_report_victory.png")
    require(len(kuai_shots) == 15 and kuai_shots <= archived.keys(), "15 native Kuai screenshots missing")
    for name in kuai_shots:
        require((world_path.parent / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), "invalid Kuai PNG")
    return {"schema": "kuaihuolin_world_validation_v1", "complete": True,
            "world_receipt": world_path.relative_to(ROOT).as_posix(),
            "classic_receipt": classic_path.relative_to(ROOT).as_posix(),
            "source_inventory_count": len(production), "source_files_match_current": True,
            "world_qa_sources_match_current": True, "classic_qa_sources_match_current": True,
            "world_qa_source_sha256": world_tools, "classic_qa_source_sha256": classic_tools,
            "immutable_common_sha256": COMMON_SHA256, "immutable_jiang_validator_sha256": JIANG_COPY_SHA256,
            "production_manifest_sha256": prior["production_manifest_sha256"],
            "world_qa_source_differences": prior["world_qa_source_differences"],
            "receipts": prior["receipts"],
            "world_receipt_sha256": sha(world_path), "classic_receipt_sha256": sha(classic_path),
            "world_checks": sum(counts.values()), "case_checks": counts,
            "classic_checks": prior["classic_checks"],
            "jiangzhou_screenshot_count": len(shots),
            "kuaihuolin_component_fixture_count": len(KUAI_FIXTURES),
            "kuaihuolin_processes": receipt["level7_processes"],
            "kuaihuolin_checks": counts["level7_component"] + sum(counts[case] for case in KUAI_ROUTE),
            "kuaihuolin_screenshot_count": len(kuai_shots),
            "kuaihuolin_screenshots_sha_verified": sorted(kuai_shots),
            "default_world_cases": CASES,
            "single_full_default_world_run_verified": True,
            "public_continue_acceptance": False, "steam_release_performed": False,
            "limits": ["All 37 cases are from one fresh complete default world batch; historical receipts and validators remain unchanged.",
                       "Components use explicit fixtures; Jiangzhou and Kuaihuolin natural routes are separate.",
                       "New chapter and Huang route reports bind process nonces; legacy reports without that field retain their existing PID/log binding and unique runner step nonces.",
                       "Component slot digests are report observations; private slots and handoffs are not archived or reread by this verifier.",
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
        load_common()
        result = verify(COMMON.candidate(args.full_world), COMMON.candidate(args.classic_receipt))
        if args.write_summary:
            (HERE / "validation_summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, IndexError, AttributeError, TypeError, RuntimeError, subprocess.SubprocessError) as exc:
        print(json.dumps({"complete": False, "reason": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
