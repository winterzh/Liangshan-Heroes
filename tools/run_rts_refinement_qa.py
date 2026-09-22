#!/usr/bin/env python3
"""Freeze a private RTS test project; never run against player data or publish.

--prepare-only imports a fresh snapshot for interactive/agent validation.
Without it, also runs the RTS regression scripts. Output must not exist.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

from verify_platform_exports import allowlist, sha

ROOT = Path(__file__).resolve().parents[1]
SUITES = ["hero_function_keys_qa.gd", "rts_foundation_regression_qa.gd", "rts_economy_rules_qa.gd",
          "rts_hero_items_regression_qa.gd", "rts_hud_snapshot_qa.gd",
          "input_controls_regression_qa.gd", "combat_controls_regression_qa.gd",
          "campaign_controls_regression_qa.gd", "steam_cloud_regression_qa.gd",
          "steam_presence_regression_qa.gd"]
COMPLETION_MARKERS = {
    "hero_function_keys_qa": r"\[hero-function-keys-result\] (.+)",
    "rts_foundation_regression_qa": r"\[foundation\] summary checks=(\d+) failures=0",
    "rts_economy_rules_qa": r"\[rts-economy-rules-result\] (.+)",
    "rts_hero_items_regression_qa": r"\[hero-items-result\] (.+)",
    "rts_hud_snapshot_qa": r"\[hud-snapshot-result\] (.+)",
    "input_controls_regression_qa": r"INPUT_CONTROLS_QA checks=(\d+) failures=0",
    "combat_controls_regression_qa": r"\[combat-controls-result\] (.+)",
    "campaign_controls_regression_qa": r"\[campaign-controls-regression\] checks=(\d+) failures=0",
    "steam_cloud_regression_qa": r"\[steam-cloud-result\] (.+)",
    "steam_presence_regression_qa": r"\[steam-presence-result\] (.+)",
}


def main(suites: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_PATH", "godot"))
    parser.add_argument("--out", type=Path)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--visual", action="store_true", help="Also render native-resolution touch screenshots outside the checkout")
    args = parser.parse_args()
    out = args.out.expanduser().resolve() if args.out else Path(tempfile.mkdtemp(prefix="lsh-rts-fix-"))
    if args.out:
        if out.exists() or out == ROOT or ROOT in out.parents:
            parser.error("--out must be a new absolute directory outside the checkout")
        out.mkdir(parents=True)
    project = out / "project"
    project.mkdir()
    selected = allowlist(ROOT)
    selected += [p.relative_to(ROOT).as_posix() for p in (ROOT / "tools").iterdir()
                 if p.is_file() and p.suffix in {".gd", ".tscn"}]
    selected.append("tools/contracts/steam/rich_presence.vdf")
    records = []
    for relative in sorted(set(selected)):
        src, dst = ROOT / relative, project / relative
        if src.is_symlink():
            raise RuntimeError("Symbolic test source is not allowed: " + relative)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        frozen_hash = sha(dst)
        if sha(src) != frozen_hash:
            raise RuntimeError("Source changed while freezing: " + relative)
        records.append({"path": relative, "sha256": frozen_hash})
    profile = "LSH-rts-refinement-" + uuid.uuid4().hex
    (project / "override.cfg").write_text(
        '[application]\nconfig/name=' + json.dumps(profile) + '\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name=' + json.dumps(profile) + '\n', encoding="utf-8")
    env = dict(os.environ, STEAM_DISABLED="1", CAMPAIGN_QA="1", CONTENT_UPDATE_NO_AUTO="1",
               LSH_LANGUAGE="zh_CN", LSH_RTS_QA_PROJECT=str(project), LSH_RTS_QA_OUT=str(out))
    if sys.platform == "darwin":
        profile_dir = Path.home() / "Library" / "Application Support" / profile
    elif sys.platform == "win32":
        profile_dir = Path(os.environ["APPDATA"]) / profile
    else:
        profile_dir = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))) / profile
    if profile_dir.exists():
        raise RuntimeError("Refusing to reuse an existing profile: " + str(profile_dir))
    env["LSH_RTS_QA_PROFILE"] = str(profile_dir)
    env["LSH_INPUT_QA_PROJECT"] = str(project)
    env["LSH_INPUT_QA_PROFILE"] = str(profile_dir)
    for key in ("SMOKE_TEST", "ARENA", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH_AI", "SKIRMISH", "LEVEL"):
        env.pop(key, None)
    receipt = {"source_root": str(ROOT), "project": str(project), "profile": profile,
               "profile_directory": str(profile_dir), "files": records, "runs": [],
               "isolation": {"STEAM_DISABLED": "1", "CAMPAIGN_QA": "1", "home_overridden": False,
                             "native_steam_sdk_copied": False},
               "suites": SUITES if suites is None else suites}
    (out / "source-receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    def run(label: str, command: list[str], timeout: int) -> bool:
        log = out / (label + ".log")
        with log.open("w", encoding="utf-8") as stream:
            result = subprocess.run(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        text = log.read_text(encoding="utf-8", errors="replace")
        ok = result.returncode == 0 and "SCRIPT ERROR:" not in text and "Parse Error:" not in text and "\nERROR:" not in text
        count = None
        if label in COMPLETION_MARKERS:
            marker = re.search(COMPLETION_MARKERS[label], text)
            ok = ok and marker is not None
            if marker:
                value = marker.group(1)
                if value.startswith("{"):
                    report = json.loads(value)
                    count = len(report["checks"]) if isinstance(report["checks"], list) else report["checks"]
                    ok = ok and report.get("passed") is True and not report.get("failures")
                else:
                    count = int(value)
                ok = ok and count > 0
        if label == "touch_visual":
            report = json.loads((out / "screenshots" / "touch-layout-report.json").read_text())
            count = len(report["samples"])
            ok = ok and report.get("ok") is True and not report.get("failures") and count >= 121
        receipt["runs"].append({"label": label, "returncode": result.returncode, "passed": ok, "checks_or_samples": count, "log": str(log)})
        (out / "source-receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(receipt["runs"][-1], ensure_ascii=False), flush=True)
        return ok
    print(json.dumps({"project": str(project), "profile": profile, "output": str(out)}), flush=True)
    imported = run("import", [args.godot, "--headless", "--editor", "--path", str(project), "--import", "--quit"], 600)
    if not imported or args.prepare_only:
        return 0 if imported else 1
    passed = True
    for suite in SUITES if suites is None else suites:
        if not (project / "tools" / suite).is_file():
            raise RuntimeError("Missing regression: " + suite)
        passed = run(suite.removesuffix(".gd"), [args.godot, "--headless", "--path", str(project),
                     "--script", "res://tools/" + suite], 600) and passed
    if args.visual:
        env["LSH_RTS_QA_OUT"] = str(out / "screenshots")
        env["LSH_RTS_UI_ECONOMY"] = "1"
        env.pop("LSH_RTS_UI_CASES", None)
        env.pop("LSH_RTS_UI_STATES", None)
        passed = run("touch_visual", [args.godot, "--path", str(project), "--rendering-method", "gl_compatibility",
                     "--position", "20000,20000", "res://tools/rts_touch_visual_qa.tscn"], 600) and passed
    receipt["source_drift"] = [r["path"] for r in records if sha(project / r["path"]) != r["sha256"]]
    receipt["checkout_drift"] = [r["path"] for r in records if sha(ROOT / r["path"]) != r["sha256"]]
    receipt["passed"] = passed and not receipt["source_drift"] and not receipt["checkout_drift"]
    (out / "source-receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
