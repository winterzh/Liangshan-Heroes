"""Serial, isolated checks for campaign feedback and Huangnigang arrivals.

Without --run, only prints the selected checks. Each run freezes production
inputs, imports them in a private D-drive project, disables Steam and retains
logs/reports with SHA-256 source receipts. Gameplay routes use their existing
real-command drivers; component fixtures are separately identified.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

from run_steam_integration_qa import (
    ROOT, LOCK, sources, resolve_godot, resolve_profile_root, create_private_profile,
)
from run_campaign_level_state_qa import running_engine

CASES = {
    "gate": ("mengzhou_gate_alignment_test.gd", {"MENGZHOU_GATE_VISUAL": "1"}, True),
    "siege": ("campaign_siege_balance_test.gd", {}, False),
    "heroes": ("campaign_siege_balance_test.gd", {"SIEGE_TEST": "heroes"}, False),
    "fort_ui": ("campaign_fortification_ui_test.gd", {}, True),
    "zhu_contracts": ("zhujiazhuang_rts_test.gd", {"RTS_TEST_ROUTE": "contracts"}, False),
    "zhu_direct": ("zhujiazhuang_rts_test.gd", {"RTS_TEST_ROUTE": "direct"}, False),
    "zhu_inside": ("zhujiazhuang_rts_test.gd", {"RTS_TEST_ROUTE": "inside"}, False),
    "daming_contracts": ("daming_rts_test.gd", {"DAMING_TEST": "contracts"}, False),
    "daming_assault": ("daming_rts_test.gd", {"DAMING_TEST": "assault"}, False),
    "daming_signal": ("daming_rts_test.gd", {"DAMING_TEST": "signal"}, False),
    "kuaihuolin": ("kuaihuolin_short_test.gd", {"KH_CASE": "all"}, False),
    "arrival": ("huangnigang_arrival_test.gd", {"HNA_VISUAL": "1"}, True),
    "huangnigang": ("huangnigang_short_test.gd", {"HNS_CASE": "all"}, False),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--cases", nargs="+", choices=CASES, default=list(CASES))
    parser.add_argument("--godot")
    parser.add_argument("--evidence-group", choices=["campaign_feedback_20260909", "huangnigang_arrival_20260909"], default="campaign_feedback_20260909")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/campaign_feedback"))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    work_root = resolve_profile_root(args.work_root)
    names = sorted(set(sources()) | {
        "tools/" + CASES[case][0] for case in args.cases
    } | {"tools/zhujiazhuang_rts_test.gd", "tools/zhujiazhuang_rts_feedback_test.gd", "tools/run_campaign_feedback_qa.py", "tools/run_steam_integration_qa.py",
         "tools/run_campaign_level_state_qa.py"} | ({"tools/huangnigang_short_test.gd"} if "arrival" in args.cases else set()))
    if not args.run:
        print(json.dumps({"cases": args.cases, "files": len(names), "lock_busy": LOCK.exists()}))
        return 0
    if running_engine():
        raise RuntimeError("Godot/game engine slot is occupied")
    tag = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / tag
    evidence = ROOT / "qa" / args.evidence_group / tag
    project = run / "project"
    receipt = {"complete": False, "source_head": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "run": str(run), "source_files": [], "steps": [], "godot_sha256": sha(engine),
        "scope": "Automated geometry, damage fixtures and gameplay; not human fun acceptance."}
    locked = False
    try:
        with LOCK.open("x", encoding="utf-8") as handle:
            handle.write(str(run))
        locked = True
        if running_engine():
            raise RuntimeError("Godot started before lock acquisition")
        project.mkdir(parents=True, exist_ok=False)
        evidence.mkdir(parents=True, exist_ok=False)
        for name in names:
            source = ROOT / name
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            digest = sha(target)
            if sha(source) != digest:
                raise RuntimeError("Source changed while freezing: " + name)
            receipt["source_files"].append({"path": name, "sha256": digest})
        profile = create_private_profile(run, work_root / "profiles")
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_AUDIT")) or key.startswith(("LSH_", "RTS_", "KH_", "HNS_", "HNA_", "DAMING_", "MENGZHOU_", "SIEGE_")) or key in ["LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO"]:
                env.pop(key)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            target = profile / key.lower()
            target.mkdir()
            env[key] = str(target)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_LANGUAGE="zh_CN")
        receipt["private_profile"] = str(profile)
        steps = [("import", ["--headless", "--editor", "--import"], {})]
        for case in args.cases:
            script, extra, visual = CASES[case]
            steps.append((case, ([] if visual else ["--headless"]) + ["--script", "res://tools/" + script], extra))
        for case, command, extra in steps:
            print("RUN " + case + " " + tag, flush=True)
            started = time.monotonic()
            child_env = env | extra
            log_path = evidence / (case + ".log")
            with log_path.open("wb") as log:
                process = subprocess.Popen([str(engine), "--path", str(project), "--rendering-method", "gl_compatibility"] + command + (["--quit"] if case == "import" else []), env=child_env, stdout=log, stderr=subprocess.STDOUT)
                while process.poll() is None:
                    time.sleep(0.5)
                    current_log = log_path.read_text(encoding="utf-8", errors="replace")
                    if "SCRIPT ERROR:" in current_log or "Parse Error:" in current_log or time.monotonic() - started > 1000:
                        process.terminate()
                        process.wait(timeout=15)
                        break
            output = log_path.read_text(encoding="utf-8", errors="replace")
            errors = [line for line in output.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:") or "Parse Error:" in line]
            passed = process.returncode == 0 and not errors
            receipt["steps"].append({"case": case, "exit_code": process.returncode, "seconds": round(time.monotonic() - started, 3), "passed": passed, "errors": errors[:20], "log_sha256": sha(log_path)})
            print("DONE " + case + " " + str(passed), flush=True)
            if not passed and case == "import":
                break
        receipt["complete"] = len(receipt["steps"]) == len(steps) and all(row["passed"] for row in receipt["steps"])
        receipt["source_unchanged"] = all(sha(ROOT / row["path"]) == row["sha256"] for row in receipt["source_files"])
        receipt["complete"] &= receipt["source_unchanged"]
    finally:
        if evidence.exists():
            for folder in [project / "qa", project / ".godot/kuaihuolin_short", project / ".godot/huangnigang_short", project / ".godot/huangnigang_arrival", project / ".godot/campaign_siege_balance", project / ".godot/mengzhou_gate_alignment", project / ".godot/campaign_fortification_ui"]:
                if folder.exists():
                    for source in folder.rglob("*"):
                        if source.is_file() and source.suffix in [".json", ".png"]:
                            dest = evidence / "results" / source.relative_to(project)
                            dest.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copyfile(source, dest)
            receipt["artifacts"] = [{"path": str(p.relative_to(evidence)).replace("\\", "/"), "sha256": sha(p)} for p in evidence.rglob("*") if p.is_file()]
        if locked and LOCK.exists() and LOCK.read_text(encoding="utf-8") == str(run) and not running_engine():
            LOCK.unlink()
        receipt["lock_released"] = not LOCK.exists()
        if evidence.exists():
            (evidence / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "evidence": str(evidence)}, ensure_ascii=False), flush=True)
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
