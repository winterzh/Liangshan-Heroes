#!/usr/bin/env python3
"""Build a signed, source-bound Android test APK; never publish or change a baseline.

Only the private copy receives a version/menu marker and optional template path.
The final APK's assets are checked by host Godot, not presented as a device test.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import time
import uuid
import zipfile

from verify_platform_exports import allowlist, check_inventory, find_sdk_tool, read_presets, sha

ROOT = Path(__file__).resolve().parents[1]
PROBE = '''extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func marker_found(node: Node) -> bool:
    if node is Label and OS.get_environment("LSH_APK_MARKER") in node.text:
        return true
    for child in node.get_children():
        if marker_found(child): return true
    return false
func _run() -> void:
    if OS.get_user_data_dir() != OS.get_environment("LSH_APK_PROFILE"):
        push_error("Private APK profile mismatch")
        quit(2)
        return
    var packed = load("res://scenes/menu.tscn")
    var menu = packed.instantiate()
    root.add_child(menu)
    current_scene = menu
    for frame in range(30): await process_frame
    var updater = root.get_node("AndroidUpdater")
    var steam = root.get_node("SteamService")
    var continuation = root.get_node("ContinueFlow")
    var passed: bool = marker_found(menu) and updater.enabled and updater.platform_id == "android" \
        and updater.BASE_CONTENT_VERSION == OS.get_environment("LSH_APK_BASE") \
        and root.get_node("Campaign").VERSION == OS.get_environment("LSH_APK_BASE") \
        and updater.run_content_mount_identity().patch_sha256 == "" \
        and not steam.available and not continuation.is_enabled()
    print("[android-test-menu] ", JSON.stringify({"passed": passed,
        "marker": OS.get_environment("LSH_APK_MARKER"), "user_dir": OS.get_user_data_dir(),
        "updater_enabled": updater.enabled, "platform": updater.platform_id,
        "base": updater.BASE_CONTENT_VERSION, "steam_available": steam.available,
        "continue_enabled": continuation.is_enabled(), "native_android_test": false}))
    quit(0 if passed else 3)
'''


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError("Private overlay anchor missing/ambiguous: " + old[:80])
    return text.replace(old, new, 1)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("godot", "android-sdk", "java-home", "out", "delivery-dir"):
        p.add_argument("--" + name, type=Path, required=True)
    p.add_argument("--android-template", type=Path)
    p.add_argument("--expected-commit", required=True)
    args = p.parse_args()
    if sys.platform != "darwin":
        p.error("This test builder currently supports a macOS host only")
    out, delivery = args.out.resolve(), args.delivery_dir.resolve()
    if not args.out.is_absolute() or out.exists() or out == ROOT or ROOT in out.parents:
        p.error("--out must be a new absolute directory outside checkout")
    if not args.delivery_dir.is_absolute() or delivery.exists() or ROOT / "build" not in delivery.parents:
        p.error("--delivery-dir must be new and below checkout/build/")
    env = os.environ.copy()
    for key in list(env):
        if key.startswith(("CONTENT_UPDATE_", "ANDROID_UPDATE_", "LSH_")) or key.endswith(("_QA", "_TEST", "_AUDIT")) or key in {
            "LEVEL", "AUTOMICRO", "AUTO_MICRO", "SKIRMISH", "SKIRMISH_AI", "CUSTOM_DEFENSE", "ARENA", "SCENARIO", "TOUCH_UI", "SCREENSHOT_DIR"
        }:
            env.pop(key)
    env.update(JAVA_HOME=str(args.java_home.resolve()), ANDROID_HOME=str(args.android_sdk.resolve()),
               ANDROID_SDK_ROOT=str(args.android_sdk.resolve()), STEAM_DISABLED="1",
               CONTENT_UPDATE_NO_AUTO="1", CAMPAIGN_QA="1", LSH_LANGUAGE="zh_CN")
    def git(*values):
        return subprocess.check_output(["git", *values], cwd=ROOT, env=env, text=True).strip()
    commit = git("rev-parse", "HEAD")
    if commit != args.expected_commit:
        raise RuntimeError("HEAD does not match expected source commit")
    selected = allowlist(ROOT)
    if git("status", "--porcelain", "--", *selected):
        raise RuntimeError("Production source is dirty; review before building")
    _, android = read_presets(ROOT)
    aapt, signer = (find_sdk_tool(args.android_sdk, tool) for tool in ("aapt", "apksigner"))
    for tool in (args.godot, args.java_home / "bin/java", aapt, signer):
        if not tool.is_file() or not os.access(tool, os.X_OK):
            raise RuntimeError("Missing executable: " + str(tool))
    expected_signer = re.search(r'UPDATE_ANDROID_SIGNER_SHA256:=([0-9a-f]{64})',
                                (ROOT / "tools/update_release.env").read_text())[1]
    date = datetime.date.today().strftime("%Y%m%d")
    marker = "TEST " + date[4:] + "-" + commit[:8]
    version = android["version/name"] + "-test." + date + "." + commit[:8]
    profile = "LSH-android-test-" + uuid.uuid4().hex
    profile_dir = Path.home() / "Library/Application Support" / profile
    if profile_dir.exists():
        raise RuntimeError("Refusing existing private profile")
    project, logs = out / "project", out / "logs"
    project.mkdir(parents=True)
    logs.mkdir()
    receipt = {"schema": 1, "passed": False, "diagnostic_only": True, "published": False,
               "source_commit": commit, "source_root": str(ROOT), "private_project": str(project),
               "marker": marker, "version_name": version, "version_code": android["version/code"],
               "profile_directory": str(profile_dir), "source_files": [], "overlays": [], "runs": [],
               "builder_sha256": sha(Path(__file__)), "helper_sha256": sha(ROOT / "tools/verify_platform_exports.py"),
               "godot": subprocess.check_output([str(args.godot), "--version"], env=env, text=True).strip(),
               "godot_sha256": sha(args.godot), "native_android_tested": False, "home_overridden": False}
    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    def run(label, command, timeout=900):
        start = time.monotonic()
        with (logs / (label + ".log")).open("w") as log:
            result = subprocess.run([str(x) for x in command], cwd=out, env=env,
                                    stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        text = (logs / (label + ".log")).read_text(errors="replace")
        plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
        errors = [line for line in plain.splitlines() if re.match(r"^(?:SCRIPT ERROR:|ERROR:|Parse Error:)", line)]
        row = {"step": label, "exit_code": result.returncode, "seconds": round(time.monotonic() - start, 2), "errors": errors}
        receipt["runs"].append(row)
        save()
        print(json.dumps(row), flush=True)
        if result.returncode or errors:
            raise RuntimeError(label + " failed; see retained private log")
        return text
    try:
        for name in selected:
            src, dst = ROOT / name, project / name
            before = sha(src)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            if sha(dst) != before or sha(src) != before:
                raise RuntimeError("Source changed while freezing: " + name)
            receipt["source_files"].append({"path": name, "sha256": before})
        def overlay(name, transform):
            path = project / name
            before = sha(path)
            path.write_text(transform(path.read_text()), encoding="utf-8")
            receipt["overlays"].append({"path": name, "source_sha256": before, "test_sha256": sha(path)})
        def preset(text):
            section = next(s for s in re.split(r"(?=\[preset\.\d+\]\n)", text) if 'name="Android"' in s)
            revised = replace_once(section, 'version/name="' + android["version/name"] + '"', 'version/name="' + version + '"')
            if args.android_template:
                template = args.android_template.resolve()
                if not template.is_file(): raise RuntimeError("Android template missing")
                receipt["template"] = {"path": str(template), "sha256": sha(template)}
                setting = 'custom_template/debug=' + json.dumps(str(template))
                if 'custom_template/debug=""' in revised:
                    revised = replace_once(revised, 'custom_template/debug=""', setting)
                elif 'custom_template/debug=' not in revised:
                    anchor = re.search(r'\[preset\.\d+\.options\]\n', revised)[0]
                    revised = replace_once(revised, anchor, anchor + '\n' + setting + '\n')
                else:
                    raise RuntimeError("Private preset already defines a non-default Android template")
            return replace_once(text, section, revised)
        overlay("export_presets.cfg", preset)
        overlay("scripts/menu.gd", lambda s: replace_once(s,
            'Localize.bind_format(ver, "战役重做 · 八幕战役（v%s）", content_version)',
            'Localize.bind_format(ver, "战役重做 · 八幕战役（v%s）", content_version + " · ' + marker + '")'))
        save()
        engine = [args.godot, "--headless", "--path", project]
        run("import", engine + ["--editor", "--import", "--quit"])
        apk = out / ("水浒英雄传-Android-TEST-" + date + "-" + commit[:8] + ".apk")
        run("android-export", engine + ["--export-debug", "Android", apk])
        badging = run("badging", [aapt, "dump", "badging", apk])
        signatures = run("signature", [signer, "verify", "--verbose", "--print-certs", apk])
        for key, value in (("name", android["package/unique_name"]), ("versionCode", android["version/code"]), ("versionName", version)):
            if f"{key}='{value}'" not in badging.splitlines()[0]: raise RuntimeError("APK metadata mismatch: " + key)
        cert = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)", signatures)
        if not cert or cert[1].lower() != expected_signer: raise RuntimeError("APK signer mismatch")
        for scheme in ("v2", "v3"):
            if not re.search(r"Verified using " + scheme + r" scheme[^\n]*: true", signatures): raise RuntimeError("Signature scheme missing: " + scheme)
        if "uses-permission: name='android.permission.INTERNET'" not in badging: raise RuntimeError("INTERNET permission missing")
        extracted = out / "apk-assets"
        extracted.mkdir()
        with zipfile.ZipFile(apk) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or archive.testzip() is not None: raise RuntimeError("APK ZIP integrity failed")
            abis = sorted({n.split("/")[1] for n in names if n.startswith("lib/") and n.endswith(".so")})
            if abis != ["arm64-v8a"]: raise RuntimeError("Unexpected APK architecture")
            resources = [n[7:] for n in names if n.startswith("assets/") and not n.endswith("/")]
            check_inventory(resources)
            for name in resources:
                if "\\" in name or PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts:
                    raise RuntimeError("Unsafe archive asset path")
                dest = extracted / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                with archive.open("assets/" + name) as src, dest.open("wb") as dst: shutil.copyfileobj(src, dst)
        (out / "apk-inventory.json").write_text(json.dumps(names, indent=2) + "\n")
        (extracted / "override.cfg").write_text('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=' + json.dumps(profile) + '\n')
        probe = out / "apk_menu_probe.gd"
        probe.write_text(PROBE)
        env.update(ANDROID_UPDATE_TEST="1", CONTENT_UPDATE_PLATFORM="android", CONTENT_UPDATE_ARCHITECTURE="arm64",
                   LSH_APK_PROFILE=str(profile_dir), LSH_APK_MARKER=marker, LSH_APK_BASE=android["version/name"])
        output = run("apk-menu-host", [args.godot, "--headless", "--path", extracted, "--script", probe], timeout=180)
        match = re.search(r"\[android-test-menu\] (.+)", output)
        if not match or json.loads(match[1]).get("passed") is not True: raise RuntimeError("APK menu probe did not pass")
        receipt["apk_menu_host"] = json.loads(match[1])
        expected = {r["path"]: r["sha256"] for r in receipt["source_files"]}
        expected.update({r["path"]: r["test_sha256"] for r in receipt["overlays"]})
        receipt["source_drift"] = [r["path"] for r in receipt["source_files"] if sha(ROOT / r["path"]) != r["sha256"]]
        receipt["private_drift"] = [name for name, digest in expected.items() if sha(project / name) != digest]
        if receipt["source_drift"] or receipt["private_drift"] or allowlist(ROOT) != selected or git("rev-parse", "HEAD") != commit \
                or sha(Path(__file__)) != receipt["builder_sha256"] \
                or sha(ROOT / "tools/verify_platform_exports.py") != receipt["helper_sha256"]:
            raise RuntimeError("Source changed during build")
        receipt["apk"] = {"name": apk.name, "bytes": apk.stat().st_size, "sha256": sha(apk),
                          "package": android["package/unique_name"], "abis": abis, "resources": len(resources),
                          "signer_sha256": cert[1].lower(), "v2": True, "v3": True, "internet": True}
        delivery.mkdir(parents=True, exist_ok=False)
        shutil.copy2(apk, delivery / apk.name)
        if sha(delivery / apk.name) != receipt["apk"]["sha256"]: raise RuntimeError("Delivery copy mismatch")
        receipt["delivery_dir"] = str(delivery)
        receipt["passed"] = True
        save()
        shutil.copy2(out / "receipt.json", delivery / "receipt.json")
        print("APK: " + str(delivery / apk.name), flush=True)
    except Exception as error:
        receipt["passed"] = False
        receipt["failure"] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        save()
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
