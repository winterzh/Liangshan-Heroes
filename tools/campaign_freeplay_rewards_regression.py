"""Run the 2026-09-01 free-play/story-seal checks against one unchanged runtime.

This runner separates authored automation from human play. It rejects parse or
script errors and partial result streams, but it does not certify feel, pacing,
visual clarity, frame rate, memory health, or a 15-25 minute player session.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa/campaign_freeplay_rewards_20260901/final_regression"
ENGINE = Path(r"C:\Users\rsb\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe")
ALL_FINALE_CASES = "victory,replay,lure_loss,specialist_loss,rescue_loss,return_loss"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def runtime() -> dict[str, str]:
    paths = [ROOT / "project.godot"]
    paths += list((ROOT / "scripts").rglob("*.gd"))
    paths += list((ROOT / "scenes").rglob("*.tscn"))
    for folder in ("anim", "objects", "portraits"):
        paths += list((ROOT / "assets/campaign" / folder).glob("*.png"))
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)}


def marker_rows(log: str, marker: str) -> list[dict]:
    rows: list[dict] = []
    for line in log.splitlines():
        if line.startswith(marker):
            rows.append(json.loads(line.split(marker, 1)[1].strip()))
    return rows


def generic_passed_rows(log: str) -> list[dict]:
    rows: list[dict] = []
    pattern = re.compile(r"^\[[^\]]+(?:result|summary)\]\s+(\{.*\})$")
    for line in log.splitlines():
        match = pattern.match(line.strip())
        if not match:
            continue
        row = json.loads(match.group(1))
        if "passed" in row:
            rows.append(row)
    return rows


def early_negative_semantics(rows: list[dict]) -> bool:
    """Verify the free-play deviations and the true loss fixtures separately."""
    expected = {
        "early_violence": True,
        "early_duel": True,
        "song_killed": False,
        "dai_killed": False,
        "missed_intercept": False,
    }
    if len(rows) != len(expected) or {row.get("case") for row in rows} != set(expected):
        return False
    for row in rows:
        case = row.get("case")
        expect_core = expected[case]
        result = row.get("result", {})
        if row.get("passed") is not True or row.get("expect_core") is not expect_core:
            return False
        if result.get("core_cleared") is not expect_core:
            return False
        if expect_core:
            if row.get("core_event") is not True or result.get("story_complete") is not False:
                return False
        elif row.get("core_event") is not False:
            return False
    return True


def clean_env(extra: dict[str, str]) -> dict[str, str]:
    prefixes = (
        "EARLY_QA_", "LATER_QA_", "FINALE_", "HN_QA_", "JIANGZHOU_",
        "CAMPAIGN_RUNTIME_", "CAMPAIGN_ART_REPORT", "FREEPLAY_EARLY_",
    )
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(prefixes)}
    env["CAMPAIGN_QA"] = "1"
    env.update(extra)
    return env


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    before = runtime()
    jobs = [
        {"name": "freeplay_core", "script": "campaign_freeplay_core_test.gd", "kind": "freeplay_core"},
        {"name": "freeplay_early", "script": "campaign_freeplay_early_test.gd", "kind": "freeplay_early"},
        {"name": "freeplay_late", "script": "campaign_freeplay_late_test.gd", "kind": "freeplay_late"},
        {"name": "core", "script": "campaign_core_test.gd", "kind": "core"},
        {"name": "early", "script": "test_early_episodes.gd", "kind": "early",
         "env": {"EARLY_QA_FAILURES": "1"}},
        {"name": "later", "script": "campaign_later_playthrough.gd", "kind": "later"},
        {"name": "finale", "script": "campaign_finale_playthrough.gd", "kind": "finale",
         "env": {"FINALE_QA_CASES": ALL_FINALE_CASES}},
        {"name": "hn_depth", "script": "campaign_huangnigang_depth_test.gd", "min": 6},
        {"name": "yezhulin_depth", "script": "campaign_yezhulin_depth_test.gd", "min": 1},
        {"name": "kuaihuolin_depth", "script": "campaign_kuaihuolin_depth_test.gd", "min": 1},
        {"name": "jiangzhou_depth", "script": "campaign_jiangzhou_depth_test.gd", "min": 1},
        {"name": "zhujiazhuang_depth", "script": "campaign_zhujiazhuang_depth_test.gd", "min": 1},
        {"name": "lianhuanma_depth", "script": "campaign_lianhuanma_depth_test.gd", "min": 1},
        {"name": "daming_depth", "script": "campaign_daming_depth_test.gd", "min": 1},
        {"name": "finale_depth", "script": "campaign_finale_depth_test.gd", "min": 1},
        {"name": "hn_tactics", "script": "campaign_huangnigang_tactics_test.gd", "min": 10},
        {"name": "hn_cargo", "script": "campaign_huangnigang_cargo_test.gd", "min": 5},
        {"name": "tactics_v2", "script": "campaign_tactics_v2_test.gd", "min": 1},
        {"name": "daming_infiltration", "script": "campaign_daming_infiltration_test.gd", "min": 1},
        {"name": "later_contract", "script": "campaign_later_contract_test.gd", "min": 1},
        {"name": "modes", "script": "campaign_mode_performance_test.gd", "kind": "modes",
         "env": {"CAMPAIGN_RUNTIME_ONLY": "modes", "CAMPAIGN_RUNTIME_OUT": str(OUT)}},
    ]
    results: list[dict] = []
    for job in jobs:
        name = job["name"]
        script_path = ROOT / "tools" / job["script"]
        if not script_path.is_file():
            result = {"name": name, "passed": False, "exit_code": None,
                      "errors": [f"missing script: {script_path.relative_to(ROOT).as_posix()}"],
                      "warnings": []}
            results.append(result)
            print(json.dumps(result, ensure_ascii=False), flush=True)
            continue
        log_path = OUT / f"{name}.log"
        with log_path.open("w", encoding="utf-8") as log_file:
            try:
                completed = subprocess.run(
                    [str(ENGINE), "--headless", "--path", str(ROOT), "--fixed-fps", "60",
                     "--script", str(script_path)],
                    cwd=ROOT, env=clean_env(job.get("env", {})), stdout=log_file,
                    stderr=subprocess.STDOUT, timeout=480,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                )
                exit_code: int | None = completed.returncode
            except subprocess.TimeoutExpired:
                exit_code = None
        log = log_path.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in log.splitlines()
                  if re.search(r"SCRIPT ERROR|Parse Error|^ERROR:", line)]
        warnings = [line for line in log.splitlines() if "WARNING:" in line]
        kind = job.get("kind", "generic")
        detail: dict = {}
        complete = False
        if kind == "freeplay_core":
            passes = len(re.findall(r"^\[freeplay-core\] PASS ", log, re.M))
            rows = marker_rows(log, "[freeplay-core-result]")
            complete = passes == 22 and len(rows) == 1 and rows[0].get("passed") is True
            detail = {"checks": passes, "result_rows": rows}
        elif kind == "freeplay_early":
            passes = len(re.findall(r"^\[freeplay-early\] PASS ", log, re.M))
            rows = marker_rows(log, "[freeplay-early-summary]")
            complete = (passes == 49 and len(rows) == 1 and rows[0].get("passed") is True
                        and rows[0].get("checks") == 49)
            detail = {"checks": passes, "result_rows": rows}
        elif kind == "freeplay_late":
            passes = len(re.findall(r"^\[freeplay-late\] PASS ", log, re.M))
            rows = marker_rows(log, "[freeplay-late-result]")
            complete = (passes == 26 and len(rows) == 1 and rows[0].get("passed") is True
                        and rows[0].get("checks") == 26)
            detail = {"checks": passes, "result_rows": rows}
        elif kind == "core":
            passes = len(re.findall(r"^\[core\] PASS ", log, re.M))
            rows = marker_rows(log, "[core-result]")
            complete = passes == 42 and len(rows) == 1 and rows[0].get("passed") is True
            detail = {"checks": passes, "result_rows": rows}
        elif kind == "early":
            rows = marker_rows(log, "[early-result]")
            negatives = marker_rows(log, "[early-negative]")
            summaries = marker_rows(log, "[early-summary]")
            complete = (len(rows) == 4 and len(negatives) == 5 and len(summaries) == 1
                        and all(row.get("passed") is True for row in rows + summaries)
                        and early_negative_semantics(negatives))
            detail = {"cases": rows, "negative_cases": negatives,
                      "negative_semantics": early_negative_semantics(negatives)}
        elif kind == "later":
            rows = marker_rows(log, "[later-result]")
            saves = marker_rows(log, "[later-save]")
            complete = (len(rows) == 3 and all(row.get("passed") is True for row in rows)
                        and len(saves) == 1 and saves[0].get("unchanged") is True)
            detail = {"cases": rows, "save": saves}
        elif kind == "finale":
            rows = marker_rows(log, "[finale-result]")
            summaries = marker_rows(log, "[finale-summary]")
            complete = (len(rows) == 6 and len(summaries) == 1
                        and all(row.get("passed") is True for row in rows + summaries))
            detail = {"cases": rows}
        elif kind == "modes":
            report_path = OUT / "runtime_modes.json"
            if report_path.is_file():
                report = json.loads(report_path.read_text(encoding="utf-8"))
                checks = report.get("mode_checks", report.get("checks", []))
                complete = (report.get("passed") is True and len(checks) == 25
                            and all(row.get("passed") is True for row in checks))
                detail = {"checks": len(checks), "report": report_path.relative_to(ROOT).as_posix(),
                          "report_sha256": sha(report_path)}
        else:
            rows = generic_passed_rows(log)
            complete = (len(rows) >= int(job.get("min", 1))
                        and all(row.get("passed") is True for row in rows))
            detail = {"result_rows": rows}
        passed = bool(exit_code == 0 and complete and not errors)
        result = {
            "name": name, "passed": passed, "exit_code": exit_code,
            "script": script_path.relative_to(ROOT).as_posix(), "script_sha256": sha(script_path),
            "log": log_path.relative_to(ROOT).as_posix(), "log_sha256": sha(log_path),
            "errors": errors, "warnings": warnings, **detail,
        }
        results.append(result)
        print(json.dumps({key: result[key] for key in ("name", "passed", "exit_code", "errors", "warnings")},
                         ensure_ascii=False), flush=True)
    after = runtime()
    report = {
        "passed": before == after and all(row["passed"] for row in results),
        "runtime_unchanged_during_checks": before == after,
        "runtime": after,
        "results": results,
        "scope": (
            "Free tactical routes, same-run story seals, authored task paths, explicit boundary "
            "fixtures, eight main chains, selected loss branches, public mechanics, and "
            "campaign-arena-campaign isolation. "
            "Not human play, 15-25 minute pacing, visual feel, performance, or memory certification."
        ),
    }
    (OUT / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
