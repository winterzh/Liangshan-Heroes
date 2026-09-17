"""Recheck this delivery's staged evidence without launching Godot.

The full diagnostic batch remains failed. Only its passing foundation cases
are combined with the later complete six-process run and classic regression.
No raw receipt is changed and no public/Steam acceptance is implied.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FOUNDATION = ROOT / "qa/level3_world_restore_20260909/20260913_015956_3bc1fd31"
ROUTE = ROOT / "qa/level3_world_restore_20260909/20260913_021853_de632b8f"
CLASSIC = ROOT / "qa/continue_flow_20260909/20260913_024947_f6a8c09f"
ROUTE_CASES = ["level1_cross_save", "level1_cross_arrival", "level1_cross_wine",
               "level1_cross_cargo", "level1_cross_finish", "level1_terminal_reject"]
FOUNDATION_CASES = {"freeplay_core": 28, "world_restore": 67, "cross_save": 8,
                    "cross_resume": 18, "level1_component": 46}
CLASSIC_CASES = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle",
                 "unsaved_terminal", "capture", "restore_and_overwrite", "restore_again",
                 "pending_retry", "held_error", "terminal", "terminal_reject"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def production(receipt):
    rows = receipt["source_files"]
    require(len({r["path"] for r in rows}) == len(rows), "duplicate source paths")
    return {r["path"]: r["sha256"] for r in rows if not r["path"].startswith("tools/")}


def check_steps(receipt, cases):
    steps = {s["case"]: s for s in receipt["steps"]}
    require(len(steps) == len(receipt["steps"]), "duplicate step cases")
    for case in cases:
        step = steps[case]
        require(step["exit_code"] == step["expected_exit_code"] and step["errors"] == 0
                and not step.get("stop_reason"), "failed step: " + case)


def check_report(path, count=None):
    report = read(path)
    checks = report["checks"]
    require(report["passed"] is True and checks and all(c["passed"] is True for c in checks),
            "failed report: " + str(path))
    if count is not None:
        require(len(checks) == count, "changed check count: " + str(path))
    return report


def common_guards(receipt):
    require(receipt["fresh_import"] is True and receipt["source_changes"] == []
            and receipt["lock_released"] is True, "source/import/lock guard failed")


def main():
    f, r, c = (read(d / "receipt.json") for d in [FOUNDATION, ROUTE, CLASSIC])
    for receipt in [f, r, c]:
        common_guards(receipt)
    require(f["complete"] is False and f["full_suite"] is True
            and f["acceptance_complete"] is False, "foundation diagnostic status changed")
    require(r["complete"] is True and r["full_suite"] is False
            and r["acceptance_complete"] is False, "route subset status changed")
    require(c["complete"] is True and c["terminal_only"] is False, "classic default run incomplete")
    require(c["cases"] == CLASSIC_CASES and [s["case"] for s in c["steps"]] == CLASSIC_CASES,
            "classic default case coverage differs")
    require(r["cases"] == ROUTE_CASES
            and [s["case"] for s in r["steps"]] == ["import", "profile_guard"] + ROUTE_CASES,
            "route case coverage differs")
    require(f["godot_sha256"] == r["godot_sha256"] == c["godot_sha256"], "engine versions differ")
    for directory, receipt in [(FOUNDATION, f), (ROUTE, r)]:
        require(receipt["protected_player_unchanged"] is True and receipt["engines_after"] == []
                and all(g["passed"] is True for g in receipt["phase_guards"]), "world guards failed")
        for row in receipt["files"]:
            path = directory / row["path"]
            require(path.is_file() and path.stat().st_size == row["bytes"]
                    and sha(path) == row["sha256"], "archived artifact mismatch: " + str(path))
    require(c["source_inventory_matches"] and c["engine_unchanged"] and c["scene_unchanged"]
            and not c["engine_running_at_release"], "classic guards failed")
    p = production(f)
    require(p == production(r) == production(c), "production dependency sets/bytes differ")
    require(len(p) == 2958, "production dependency count changed")
    for path, digest in p.items():
        require(sha(ROOT / path) == digest, "checkout differs from tested production: " + path)
    f_sources = {x["path"]: x["sha256"] for x in f["source_files"]}
    r_sources = {x["path"]: x["sha256"] for x in r["source_files"]}
    require(f_sources.keys() == r_sources.keys(), "world source inventory differs")
    changed = sorted(k for k in f_sources if f_sources[k] != r_sources[k])
    require(changed == ["tools/level1_cross_process_qa.gd"], "unexpected QA changes")
    check_steps(f, ["import", "profile_guard"] + list(FOUNDATION_CASES))
    check_steps(r, ["import", "profile_guard"] + ROUTE_CASES)
    check_steps(c, c["cases"])
    classic_count = 0
    previous_end = 0
    classic_nonces = set()
    for step in c["steps"]:
        require(sha(CLASSIC / (step["case"] + ".log")) == step["log_sha256"], "classic log hash mismatch")
        require(step["process_nonce"] not in classic_nonces and step["started_ns"] >= previous_end
                and step["finished_ns"] > step["started_ns"], "classic process sequence failed")
        classic_nonces.add(step["process_nonce"])
        previous_end = step["finished_ns"]
        if step["case"] not in ["import", "profile_guard"]:
            report_path = CLASSIC / (step["case"] + ".json")
            require(sha(report_path) == step["report_sha256"], "classic report hash mismatch")
            report = check_report(report_path)
            require(report["case"] == step["case"] and report["pid"] == step["pid"]
                    and report["process_nonce"] == step["process_nonce"], "classic process report binding failed")
            classic_count += len(report["checks"])
    require(classic_count == c["checks"], "classic check total mismatch")
    expected_shots = {state + "_" + language + ".png"
                      for state in ["overwrite_confirm", "pending_save", "held_error", "terminal_pending"]
                      for language in ["zh_CN", "zh_TW", "en", "ja"]}
    require(len(c.get("screenshots", [])) == len(expected_shots)
            and {shot["path"] for shot in c["screenshots"]} == expected_shots,
            "classic native screenshot coverage differs")
    for shot in c["screenshots"]:
        require(sha(CLASSIC / "screenshots" / shot["path"]) == shot["sha256"], "classic screenshot hash mismatch")
    for case, count in FOUNDATION_CASES.items():
        if case == "freeplay_core":
            log = (FOUNDATION / "freeplay_core.log").read_text(encoding="utf-8")
            require(len(re.findall(r"(?m)^\[freeplay-core\] PASS ", log)) == count
                    and "[freeplay-core] FAIL " not in log, "core checks changed")
        else:
            check_report(FOUNDATION / (case + "_report.json"), count)
    require([x["case"] for x in r["level1_processes"]] == ROUTE_CASES, "six-process coverage changed")
    nonces, previous_end, route_count = set(), 0, 0
    for row in r["level1_processes"]:
        report = check_report(ROUTE / (row["case"] + "_report.json"), row["checks"])
        require(report["mode"] == row["case"] and report["pid"] == row["pid"]
                and report["process_nonce"] == row["process_nonce"], "process report binding failed")
        require(report["actor_teleports"] == 0 and report["stage_injections"] == 0, "natural route fixture injection")
        require(row["process_nonce"] not in nonces and row["started_ns"] >= previous_end
                and row["finished_ns"] > row["started_ns"], "process sequence failed")
        nonces.add(row["process_nonce"])
        previous_end = row["finished_ns"]
        route_count += row["checks"]
    require(route_count == r["total_checks"] == 258, "route count changed")
    victory = read(ROUTE / "level1_cross_finish_report.json")["observations"][-1]
    require(victory["result"]["story_complete"] is True
            and len(victory["result"]["done_ids"]) == 4
            and victory["victory"]["level"]["delivered"] == 3, "victory evidence incomplete")
    summary = {
        "schema": "huangnigang_staged_validation_v1", "staged_validation_complete": True,
        "single_full_world_run_passed": False, "public_continue_acceptance": False,
        "steam_release_performed": False,
        "production_file_count": len(p),
        "production_manifest_sha256": hashlib.sha256(json.dumps(p, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        "production_matches_current_checkout": True,
        "world_qa_source_changes": changed,
        "foundation_cases": FOUNDATION_CASES,
        "world_checks": sum(FOUNDATION_CASES.values()) + route_count,
        "route_checks": route_count, "route_processes": r["level1_processes"],
        "classic_checks": c["checks"], "classic_default_complete": True,
        "receipts": [{"path": str((d / "receipt.json").relative_to(ROOT)).replace("\\", "/"),
                      "sha256": sha(d / "receipt.json"), "raw_complete": receipt["complete"]}
                     for d, receipt in [(FOUNDATION, f), (ROUTE, r), (CLASSIC, c)]],
        "limits": ["The full world diagnostic batch remains failed; only named passing foundation cases are reused.",
                   "The complete route run is a subset; its acceptance_complete remains false.",
                   "Death-drop is a positioned component fixture; the six-process route has no actor teleport or stage injection.",
                   "Group formation behavior is not claimed fixed; the successful route uses individual gathering orders.",
                   "No new full 30-wave, six other chapters, live Steam durability, long-run, two-machine/account or human acceptance."]
    }
    (HERE / "validation_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: summary[k] for k in ["staged_validation_complete", "production_file_count", "world_checks", "classic_checks"]}))


if __name__ == "__main__":
    main()
