"""Run existing campaign checks against one unchanged local runtime snapshot.

This runner does not create screenshots or certify pacing/human play. It keeps
the pre-web evidence intact and rejects empty, partial, or parse-error runs.
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
OUT = ROOT / "qa/web_chatgpt_art_20260831/final_regression"
ENGINE = Path(r"C:\Users\rsb\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def runtime() -> dict[str, str]:
    paths = [ROOT / "project.godot"]
    paths += list((ROOT / "scripts").rglob("*.gd"))
    paths += list((ROOT / "scenes").rglob("*.tscn"))
    for folder in ("anim", "objects", "portraits"):
        paths += list((ROOT / "assets/campaign" / folder).glob("*.png"))
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)}


def rows(log: str, marker: str) -> list[dict]:
    return [json.loads(line.split(marker, 1)[1].strip())
            for line in log.splitlines() if line.startswith(marker)]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    before = runtime()
    results = []
    jobs = [
        ("core", "campaign_core_test.gd", {}, None),
        ("early", "test_early_episodes.gd", {"EARLY_QA_FAILURES": "1"}, None),
        ("later", "campaign_later_playthrough.gd", {}, None),
        ("finale", "campaign_finale_playthrough.gd", {"FINALE_QA_CASES": "victory,replay,lure_loss,specialist_loss,rescue_loss,return_loss"}, None),
        ("modes", "campaign_mode_performance_test.gd", {
            "CAMPAIGN_RUNTIME_ONLY": "modes", "CAMPAIGN_RUNTIME_OUT": str(OUT)}, OUT / "runtime_modes.json"),
        ("art", "campaign_art_contract.gd", {
            "CAMPAIGN_ART_REPORT": str(OUT / "art_contract.json")}, OUT / "art_contract.json"),
        ("motion", "campaign_art_motion_contract.gd", {}, ROOT / "assets/campaign/motion_contract_qa_with_web.json"),
    ]
    for name, script, extra, report_path in jobs:
        env = {k: v for k, v in os.environ.items() if not k.startswith(
            ("EARLY_QA_", "LATER_QA_", "FINALE_", "CAMPAIGN_RUNTIME_", "CAMPAIGN_ART_REPORT"))}
        env.update(extra)
        env["CAMPAIGN_QA"] = "1"
        path = ROOT / "tools" / script
        with (OUT / f"{name}.log").open("w", encoding="utf-8") as log_file:
            completed = subprocess.run([str(ENGINE), "--headless", "--path", str(ROOT),
                "--fixed-fps", "60", "--script", str(path)], cwd=ROOT, env=env,
                stdout=log_file, stderr=subprocess.STDOUT, timeout=300,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        log = (OUT / f"{name}.log").read_text(encoding="utf-8", errors="replace")
        errors = [line for line in log.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|^ERROR:", line)]
        warnings = [line for line in log.splitlines() if "WARNING:" in line]
        detail = {}
        if name == "core":
            detail = {"checks": len(re.findall(r"^\[core\] PASS ", log, re.M))}
            complete = detail["checks"] == 42 and "[core] FAIL" not in log
        elif name in ("early", "later", "finale"):
            marker = f"[{name}-result]"
            detail = {"cases": rows(log, marker)}
            expected = {"early": 4, "later": 3, "finale": 6}[name]
            complete = len(detail["cases"]) == expected and all(r["passed"] for r in detail["cases"])
            if name == "early":
                detail["negative_cases"] = rows(log, "[early-negative]")
                complete &= len(detail["negative_cases"]) == 5 and all(r["passed"] for r in detail["negative_cases"])
            if name == "later":
                saved = rows(log, "[later-save]")
                complete &= len(saved) == 1 and saved[0]["unchanged"]
        else:
            report = json.loads(report_path.read_text(encoding="utf-8"))
            checks = report.get("checks", report.get("mode_checks", []))
            detail = {"checks": len(checks), "report": report_path.relative_to(ROOT).as_posix(), "report_sha256": sha(report_path)}
            expected = {"modes": 25, "art": 89, "motion": 74}[name]
            complete = len(checks) == expected and all(r["passed"] for r in checks)
            complete &= report.get("passed", True)
        result = {"name": name, "passed": bool(completed.returncode == 0 and complete and not errors),
                  "exit_code": completed.returncode, "script_sha256": sha(path),
                  "log_sha256": sha(OUT / f"{name}.log"), "errors": errors, "warnings": warnings, **detail}
        results.append(result)
        print(json.dumps({k: result[k] for k in ("name", "passed", "exit_code", "errors", "warnings")}, ensure_ascii=False), flush=True)
    after = runtime()
    report = {"passed": before == after and all(r["passed"] for r in results),
              "runtime_unchanged_during_checks": before == after, "runtime": after, "results": results,
              "scope": "Existing automated contracts/playthroughs only. Graphical QA and human pacing are separate."}
    (OUT / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
