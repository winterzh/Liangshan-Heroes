#!/usr/bin/env python3
"""Build an isolated macOS user-test app/DMG, never a release or update baseline.

Copies the production allowlist, records every source hash, and applies only
declared private test packaging overlays. Does not edit production gameplay,
reset HOME, use signing credentials, publish, or modify the user's real saves.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

from verify_platform_exports import allowlist, check_inventory, pck_inventory, sha

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError("Private overlay anchor missing or ambiguous: " + old[:100])
    return text.replace(old, new, 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True, help="New absolute directory outside checkout")
    parser.add_argument("--delivery-dir", type=Path, required=True, help="New directory below this checkout's build/")
    parser.add_argument("--expected-commit", required=True)
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This tool requires native macOS export/signing/DMG utilities")
    if not args.out.is_absolute() or not args.delivery_dir.is_absolute():
        parser.error("Output paths must be absolute")
    out, delivery = args.out.resolve(), args.delivery_dir.resolve()
    if out.exists() or out == ROOT or ROOT in out.parents:
        parser.error("--out must be new and outside checkout")
    if delivery.exists() or (ROOT / "build") not in delivery.parents:
        parser.error("--delivery-dir must be new and below checkout/build/")
    env = dict(os.environ)
    for key in list(env):
        if key.startswith(("CONTENT_UPDATE_", "ANDROID_UPDATE_", "LSH_")) or key in {
            "LEVEL", "SMOKE_TEST", "SCREENSHOT_DIR", "AUTOMICRO", "AUTO_MICRO", "SKIRMISH",
            "SKIRMISH_AI", "CUSTOM_DEFENSE", "ARENA", "SCENARIO", "CAMPAIGN_QA", "TOUCH_UI"
        }:
            env.pop(key)
    env.update(STEAM_DISABLED="1", CONTENT_UPDATE_NO_AUTO="1", LSH_LANGUAGE="zh_CN")
    commit = subprocess.check_output(["/usr/bin/git", "rev-parse", "HEAD"], cwd=ROOT, env=env, text=True).strip()
    if commit != args.expected_commit:
        raise RuntimeError("HEAD differs from requested tested source")
    selected = allowlist(ROOT)
    dirty = subprocess.check_output(["/usr/bin/git", "status", "--porcelain", "--", *selected], cwd=ROOT, env=env, text=True)
    if dirty.strip():
        raise RuntimeError("Production allowlist is dirty; review it before freezing")
    date = datetime.date.today().strftime("%Y%m%d")
    stamp = "TEST " + date[4:] + "-" + commit[:8]
    profile = "LSH-macos-test-" + date + "-" + commit[:8]
    basename = "水浒英雄传-TEST-" + date + "-" + commit[:8]
    project = out / "project"
    project.mkdir(parents=True)
    delivery.mkdir(parents=True)
    records = []
    for relative in selected:
        src, dst = ROOT / relative, project / relative
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        records.append({"path": relative, "sha256": sha(src)})
    receipt = {"schema": 1, "diagnostic_only": True, "published": False, "source_commit": commit,
               "stamp": stamp, "profile": profile, "source_files": records, "overlays": [], "runs": [],
               "source_root": str(ROOT), "private_project": str(project), "delivery_dir": str(delivery),
               "builder_sha256": sha(Path(__file__)), "native_launch_tested": False}
    def save_receipt():
        (out / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    def overlay(relative: str, transform, reason: str):
        path = project / relative
        original = sha(path)
        path.write_text(transform(path.read_text(encoding="utf-8")), encoding="utf-8")
        receipt["overlays"].append({"path": relative, "reason": reason, "source_sha256": original,
                                    "test_sha256": sha(path)})
    overlay("project.godot", lambda s: replace_once(s, '[application]\n',
        '[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=' + json.dumps(profile) + '\n'),
        "Isolated user data; no real player saves or cached content")
    def patch_preset(text):
        before, mac = text.split("[preset.1]\n", 1)
        mac, after = mac.split("[preset.2]\n", 1)
        mac = replace_once(mac, 'custom_features=""', 'custom_features="local_rts_test"')
        mac = replace_once(mac, 'application/bundle_identifier="com.liangshan.heroes"',
                           'application/bundle_identifier="com.liangshan.heroes.test.' + commit[:8] + '"')
        return before + "[preset.1]\n" + mac + "[preset.2]\n" + after
    overlay("export_presets.cfg", patch_preset, "Unique test bundle ID and local_rts_test feature; versions unchanged")
    overlay("scripts/android_updater.gd", lambda s: replace_once(s, "func _init() -> void:\n",
        'func _init() -> void:\n\tif OS.has_feature("local_rts_test"):\n\t\t_run_identity_complete = true\n\t\treturn\n'),
        "Test-only guard before any network request or cached PCK load; production updater unchanged")
    def patch_menu(text):
        return replace_once(
            text, '\tadd_child(shade)\n', '\tadd_child(shade)\n' +
            '\tvar test_stamp := Label.new()\n' +
            '\ttest_stamp.text = ' + json.dumps(stamp, ensure_ascii=False) + '\n' +
            '\ttest_stamp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)\n' +
            '\ttest_stamp.offset_left = 16.0\n\ttest_stamp.offset_top = -36.0\n\ttest_stamp.offset_bottom = -12.0\n' +
            '\ttest_stamp.add_theme_font_size_override("font_size", 16)\n' +
            '\ttest_stamp.modulate = Color("e8c66d")\n\tadd_child(test_stamp)\n')
    overlay("scripts/menu.gd", patch_menu, "Visible menu test/source stamp, no gameplay or version changes")
    frozen = {r["path"]: sha(project / r["path"]) for r in records}
    save_receipt()
    def run(label: str, command: list[str], timeout=900):
        log = out / (label + ".log")
        with log.open("w", encoding="utf-8") as stream:
            result = subprocess.run(command, env=env, cwd=out, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        text = log.read_text(encoding="utf-8", errors="replace")
        ok = result.returncode == 0 and "SCRIPT ERROR:" not in text and "Parse Error:" not in text and "\nERROR:" not in text
        receipt["runs"].append({"label": label, "returncode": result.returncode, "passed": ok, "log": str(log)})
        save_receipt()
        print(json.dumps(receipt["runs"][-1], ensure_ascii=False), flush=True)
        if not ok:
            raise RuntimeError("Failed " + label + "; see " + str(log))
    run("import", [str(args.godot), "--headless", "--editor", "--path", str(project), "--import", "--quit"])
    app = delivery / (basename + ".app")
    run("export", [str(args.godot), "--headless", "--path", str(project), "--export-release", "macOS", str(app)])
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = subprocess.check_output(["/usr/bin/lipo", "-archs", str(binary)], env=env, text=True).strip().split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise RuntimeError("Expected universal export")
    packs = list((app / "Contents/Resources").glob("*.pck"))
    if len(packs) != 1:
        raise RuntimeError("Expected exactly one bundled PCK")
    inventory = pck_inventory(packs[0])
    names = [entry["path"] for entry in inventory["entries"]]
    check_inventory(names)
    if not any(name.startswith("assets/ui/items/health_potion.svg") for name in names):
        raise RuntimeError("Health potion icon missing from exported package")
    (out / "pck-inventory.json").write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    run("adhoc-sign", ["/usr/bin/codesign", "--force", "--deep", "--sign", "-", "--timestamp=none", str(app)])
    run("verify-sign", ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)])
    dmg = delivery / (basename + ".dmg")
    stage = out / "dmg-stage"
    stage.mkdir()
    run("stage-app", ["/usr/bin/ditto", str(app), str(stage / app.name)])
    run("dmg", ["/usr/bin/hdiutil", "create", "-volname", "梁山英雄本地测试", "-srcfolder", str(stage),
                "-fs", "HFS+", "-format", "UDZO", str(dmg)])
    run("verify-dmg", ["/usr/bin/hdiutil", "verify", str(dmg)])
    receipt["artifacts"] = {"app": str(app), "binary": str(binary), "architectures": architectures,
                            "bundle_id": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"],
                            "pck": {"path": str(packs[0]), "bytes": packs[0].stat().st_size, "sha256": sha(packs[0]), "files": len(names)},
                            "dmg": {"path": str(dmg), "bytes": dmg.stat().st_size, "sha256": sha(dmg)},
                            "signing": "local ad-hoc, not Apple notarized"}
    receipt["source_drift"] = [r["path"] for r in records if sha(ROOT / r["path"]) != r["sha256"]]
    receipt["private_drift"] = [path for path, digest in frozen.items() if sha(project / path) != digest]
    receipt["passed"] = not receipt["source_drift"] and not receipt["private_drift"]
    save_receipt()
    shutil.copy2(out / "receipt.json", delivery / "build-receipt.json")
    print(json.dumps(receipt["artifacts"], ensure_ascii=False, indent=2), flush=True)
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
