#!/usr/bin/env python3
"""Build/check an Android content delta; no signing, upload or version changes.

The publisher supplies the clean release tag and independently verified baseline
manifest. This builder freezes the same production allowlist as the full APK.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from verify_platform_exports import ROOT, allowlist, forbidden, pck_inventory, sha


def check_delta(inventory: dict, base_inventory: dict, changed: list[str]) -> None:
    names = [entry["path"] for entry in inventory["entries"]]
    if not names or len(names) != len(set(names)):
        raise RuntimeError("Empty/duplicate patch resource list")
    for name in names:
        if forbidden(name) or name.endswith((".so", ".dll", ".dylib", ".gdextension")):
            raise RuntimeError("Development/native resource in patch: " + name)
    base = {entry["path"]: entry for entry in base_inventory["entries"]}
    for name in ("project.binary", "scripts/android_updater.gdc", "scripts/campaign.gdc"):
        for entry in inventory["entries"]:
            if entry["path"] == name and (name not in base or entry != base[name]):
                raise RuntimeError("Protected exported resource changed: " + name)
    for source in changed:
        if source.endswith(".gd"):
            expected = source[:-3] + ".gdc"
        elif source == "assets/localization/catalog.json":
            expected = source
        else:
            continue
        if expected not in names:
            raise RuntimeError("Changed production resource missing from delta: " + expected)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("godot", "base", "manifest", "out"):
        parser.add_argument("--" + key, type=Path, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("Expected a three-part content version")
    out = args.out.resolve()
    if not args.out.is_absolute() or out.exists() or (ROOT in out.parents and ROOT / "build" not in out.parents):
        parser.error("--out must be new and external or below ignored build/")
    env = dict(os.environ)
    for key in list(env):
        if key.startswith(("CONTENT_UPDATE_", "ANDROID_UPDATE_", "LSH_")) or key in {
            "SMOKE_TEST", "LEVEL", "SKIRMISH", "SKIRMISH_AI", "SCENARIO", "CUSTOM_DEFENSE", "ARENA", "TOUCH_UI"
        }:
            env.pop(key)
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", CONTENT_UPDATE_NO_AUTO="1")
    def git(*values):
        return subprocess.check_output(["git", *values], cwd=ROOT, env=env, text=True).strip()
    if git("rev-parse", "HEAD") != args.commit:
        raise RuntimeError("Source commit mismatch")
    selected = allowlist(ROOT)
    if git("status", "--porcelain", "--", *selected):
        raise RuntimeError("Production inputs are dirty")
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    baseline = manifest["patch_base"]
    if manifest.get("platform") != "android" or baseline != manifest["packaged_base"] \
            or baseline["version"] != ".".join(args.version.split(".")[:2]) \
            or args.base.stat().st_size != baseline["size"] or sha(args.base) != baseline["sha256"]:
        raise RuntimeError("Android baseline identity mismatch")
    base_inventory = pck_inventory(args.base)
    if base_inventory["engine"] != [4, 6, 3]:
        raise RuntimeError("Expected the validated Godot 4.6.3 baseline")
    godot_version = subprocess.check_output([str(args.godot), "--version"], env=env, text=True).strip()
    if not godot_version.startswith("4.6.3.stable."):
        raise RuntimeError("Engine must match the shipped 2.0 baseline")
    changed = git("diff", "--no-renames", "--name-only", "v" + baseline["version"] + ".." + args.commit).splitlines()
    protected = [name for name in changed if name in {"project.godot", "export_presets.cfg", "scripts/android_updater.gd", "scripts/campaign.gd"}
                 or name.startswith(("android/", "ios/", "macos/", "windows/")) or name.endswith((".gdextension", ".so", ".dll", ".dylib"))]
    if protected:
        raise RuntimeError("Full package required: " + str(protected))
    project = out / "project"
    project.mkdir(parents=True)
    inputs = [Path(__file__), ROOT / "tools/verify_platform_exports.py", args.manifest, args.base, args.godot]
    identities = {str(path.resolve()): sha(path) for path in inputs}
    report = {"passed": False, "source_commit": args.commit, "content_version": args.version,
              "baseline": baseline, "engine": godot_version, "production_files": [], "runs": [], "inputs": identities,
              "project": str(project), "source_root": str(ROOT), "native_android": False}
    def save():
        (out / "build-receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    def drift():
        return [row["path"] for row in report["production_files"]
                if sha(ROOT / row["path"]) != row["sha256"] or sha(project / row["path"]) != row["sha256"]]
    try:
        for name in selected:
            source, dest = ROOT / name, project / name
            before = sha(source)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
            if sha(dest) != before or sha(source) != before:
                raise RuntimeError("Input changed while freezing: " + name)
            report["production_files"].append({"path": name, "sha256": before})
        save()
        for label, extra in [("import", ["--editor", "--import", "--quit"]),
                             ("export", ["--export-patch", "Android", str(out / "patch.pck"), "--patches", str(args.base.resolve())])]:
            with (out / (label + ".log")).open("wb") as log:
                result = subprocess.run([str(args.godot), "--headless", "--path", str(project), *extra],
                                        env=env, cwd=out, stdout=log, stderr=subprocess.STDOUT, timeout=600)
            raw = (out / (label + ".log")).read_text(errors="replace")
            plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", raw)
            errors = [line for line in plain.splitlines() if re.match(r"^(?:SCRIPT ERROR:|ERROR:|Parse Error:)", line)]
            report["runs"].append({"label": label, "returncode": result.returncode, "errors": errors})
            save()
            if result.returncode or errors or drift():
                raise RuntimeError(label + " failed or source drifted")
        inventory = pck_inventory(out / "patch.pck")
        check_delta(inventory, base_inventory, [name for name in changed if name in selected])
        (out / "patch-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
        report["source_drift"] = drift()
        if report["source_drift"] or selected != allowlist(ROOT) or git("rev-parse", "HEAD") != args.commit \
                or any(sha(Path(path)) != digest for path, digest in identities.items()):
            raise RuntimeError("Build source/artifact input changed")
        report["patch"] = {"path": str(out / "patch.pck"), "size": (out / "patch.pck").stat().st_size,
                           "sha256": sha(out / "patch.pck"), "resources": len(inventory["entries"])}
        report["passed"] = True
        print(json.dumps({"passed": True, "patch": report["patch"]}), flush=True)
    except BaseException as error:
        report["failure"] = str(error)
        raise
    finally:
        save()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
