#!/usr/bin/env python3
"""Build a signed, source-bound Android APK without publishing.

Default mode adds a marker only to the private test copy. --release requires a
clean tagged release and emits an Android-only APK/base-PCK provenance proof.
Both modes load the final APK's assets on the host; this is not a device test.
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

from verify_platform_exports import allowlist, check_inventory, find_sdk_tool, pck_inventory, read_presets, sha

ROOT = Path(__file__).resolve().parents[1]
PROBE = '''extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func label_contains(node: Node, needle: String) -> bool:
    if node is Label and needle in node.text:
        return true
    for child in node.get_children():
        if label_contains(child, needle): return true
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
    var marker_ok: bool = label_contains(menu, OS.get_environment("LSH_APK_MARKER"))
    var test_marker_absent: bool = not label_contains(menu, "TEST") and not label_contains(menu, "-test.")
    if OS.get_environment("LSH_APK_RELEASE") == "1": marker_ok = marker_ok and test_marker_absent
    var passed: bool = marker_ok and updater.enabled and updater.platform_id == "android" \
        and updater.BASE_CONTENT_VERSION == OS.get_environment("LSH_APK_BASE") \
        and root.get_node("Campaign").VERSION == OS.get_environment("LSH_APK_BASE") \
        and updater.run_content_mount_identity().patch_sha256 == "" \
        and not steam.available and not continuation.is_enabled()
    print("[android-test-menu] ", JSON.stringify({"passed": passed,
        "marker": OS.get_environment("LSH_APK_MARKER"), "user_dir": OS.get_user_data_dir(),
        "release_mode": OS.get_environment("LSH_APK_RELEASE") == "1", "test_marker_absent": test_marker_absent,
        "updater_enabled": updater.enabled, "platform": updater.platform_id,
        "base": updater.BASE_CONTENT_VERSION, "steam_available": steam.available,
        "continue_enabled": continuation.is_enabled(), "native_android_test": false}))
    quit(0 if passed else 3)
'''


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError("Private overlay anchor missing/ambiguous: " + old[:80])
    return text.replace(old, new, 1)


def release_contract(root: Path, android: dict, environment: dict) -> dict:
    """Read only committed public defaults; never source shell or signing secrets."""
    public = (root / "tools/update_release.env").read_text(encoding="utf-8")
    values = {}
    for key in ("UPDATE_BASE_VERSION", "UPDATE_ANDROID_VERSION_CODE", "UPDATE_BOOTSTRAP_VERSION"):
        match = re.search(r'\$\{' + key + r':=([^}]+)\}', public)
        if not match or environment.get(key, match[1]) != match[1]:
            raise RuntimeError("Missing or overridden release contract: " + key)
        values[key] = match[1]
    version, code, bootstrap = (values[k] for k in (
        "UPDATE_BASE_VERSION", "UPDATE_ANDROID_VERSION_CODE", "UPDATE_BOOTSTRAP_VERSION"))
    if not re.fullmatch(r"[0-9]+\.[0-9]+", version) or not code.isdecimal() or int(code) <= 0 or not bootstrap.isdecimal() or int(bootstrap) <= 0:
        raise RuntimeError("Invalid release version/code/bootstrap contract")
    updater = (root / "scripts/android_updater.gd").read_text(encoding="utf-8")
    campaign = (root / "scripts/campaign.gd").read_text(encoding="utf-8")
    for name, expected, quoted in (("PACKAGE_VERSION_NAME", version, True), ("BASE_CONTENT_VERSION", version, True),
                                  ("PACKAGE_VERSION_CODE", code, False), ("BOOTSTRAP_VERSION", bootstrap, False)):
        value = re.escape('"' + expected + '"' if quoted else expected)
        if not re.search(r"^const " + name + r" := " + value + r"(?:\s|$)", updater, re.M):
            raise RuntimeError("Updater release contract mismatch: " + name)
    if not re.search(r'^const VERSION := "' + re.escape(version) + r'"(?:\s|$)', campaign, re.M):
        raise RuntimeError("Campaign release version mismatch")
    if android["version/name"] != version or android["version/code"] != code:
        raise RuntimeError("Android preset version/code differs from release contract")
    section = next(s for s in re.split(r"(?=\[preset\.\d+\]\n)", (root / "export_presets.cfg").read_text())
                   if 'name="Android"' in s)
    if 'platform="Android"' not in section or 'custom_features=""' not in section:
        raise RuntimeError("Android release preset must not add custom platform features")
    return {"version": version, "version_code": int(code), "bootstrap": int(bootstrap)}


def require_new_canonical(path: Path) -> None:
    if path.exists() or path.is_symlink():
        raise RuntimeError("Refusing existing canonical output: " + str(path))
    for parent in path.parents:
        if parent == ROOT: break
        if parent.is_symlink():
            raise RuntimeError("Canonical output parent may not be a symlink: " + str(parent))


def verify_artifact(path: Path, recorded: dict) -> None:
    if path.stat().st_size != recorded["bytes"] or sha(path) != recorded["sha256"]:
        raise RuntimeError("Artifact changed after export/verification: " + str(path))


def copy_new(source: Path, target: Path, recorded: dict | None = None) -> None:
    """Exclusive creation also closes the preflight-to-copy overwrite race."""
    target.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as src, target.open("xb") as dst:
        shutil.copyfileobj(src, dst)
        dst.flush()
        os.fsync(dst.fileno())
    if source.stat().st_size != target.stat().st_size or sha(source) != sha(target):
        raise RuntimeError("Copied artifact differs: " + str(target))
    if recorded is not None:
        verify_artifact(source, recorded)
        verify_artifact(target, recorded)


def write_proof_new(path: Path, value: dict) -> None:
    """Atomic, no-replace publication of an already fully verified local proof."""
    temporary = path.with_name("." + path.name + "." + uuid.uuid4().hex + ".tmp")
    published = False
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, path)
        published = True
        temporary.unlink()
    except BaseException:
        if published: path.unlink(missing_ok=True)
        raise
    finally:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass  # Retain an unreferenced temporary file; never hide a failure.


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("godot", "android-sdk", "java-home", "out", "delivery-dir"):
        p.add_argument("--" + name, type=Path, required=True)
    p.add_argument("--android-template", type=Path)
    p.add_argument("--expected-commit", required=True)
    p.add_argument("--release", action="store_true", help="Require a clean version tag and emit the canonical APK/base proof")
    p.add_argument("--version", help="Optional expected full version (release mode only)")
    args = p.parse_args()
    if sys.platform != "darwin":
        p.error("This builder currently supports a macOS host only")
    if args.version and not args.release:
        p.error("--version requires --release")
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
    contract = release_contract(ROOT, android, env) if args.release else None
    def release_git_guard():
        if env.get("LIANGSHAN_SKIP_GIT_GUARD") == "1":
            raise RuntimeError("Release mode cannot skip Git guards")
        if git("status", "--porcelain", "--untracked-files=all"):
            raise RuntimeError("Release mode requires the entire worktree to be clean")
        if git("rev-parse", "HEAD") != commit or git("rev-parse", "v" + contract["version"] + "^{commit}") != commit:
            raise RuntimeError("Release HEAD must equal its vVERSION tag and expected commit")
    canonical = {}
    if args.release:
        if args.version and args.version != contract["version"]:
            raise RuntimeError("Requested release version differs from source contract")
        release_git_guard()
        canonical = {"package": ROOT / "build" / ("LiangshanHeroes-v" + contract["version"] + ".apk"),
                     "base": ROOT / "build/updates/android" / ("base-" + contract["version"] + ".pck"),
                     "proof": ROOT / "build/updates/build-source.json"}
        for target in canonical.values(): require_new_canonical(target)
    aapt, signer = (find_sdk_tool(args.android_sdk, tool) for tool in ("aapt", "apksigner"))
    for tool in (args.godot, args.java_home / "bin/java", aapt, signer):
        if not tool.is_file() or not os.access(tool, os.X_OK):
            raise RuntimeError("Missing executable: " + str(tool))
    signer_contract = re.search(r'UPDATE_ANDROID_SIGNER_SHA256:=([0-9a-f]{64})',
                                (ROOT / "tools/update_release.env").read_text())
    if not signer_contract: raise RuntimeError("Expected Android signer contract is missing")
    expected_signer = signer_contract[1]
    if args.release and env.get("UPDATE_ANDROID_SIGNER_SHA256", expected_signer) != expected_signer:
        raise RuntimeError("Release signer contract cannot be overridden")
    date = datetime.date.today().strftime("%Y%m%d")
    marker = "（v" + android["version/name"] + "）" if args.release else "TEST " + date[4:] + "-" + commit[:8]
    version = android["version/name"] if args.release else android["version/name"] + "-test." + date + "." + commit[:8]
    profile = "LSH-android-test-" + uuid.uuid4().hex
    profile_dir = Path.home() / "Library/Application Support" / profile
    if profile_dir.exists():
        raise RuntimeError("Refusing existing private profile")
    project, logs = out / "project", out / "logs"
    project.mkdir(parents=True)
    logs.mkdir()
    receipt = {"schema": 1, "passed": False, "diagnostic_only": not args.release, "release_mode": args.release, "published": False,
               "source_commit": commit, "source_root": str(ROOT), "private_project": str(project),
               "marker": marker, "version_name": version, "version_code": android["version/code"],
               "profile_directory": str(profile_dir), "source_files": [], "overlays": [], "runs": [],
               "builder_sha256": sha(Path(__file__)), "helper_sha256": sha(ROOT / "tools/verify_platform_exports.py"),
               "release_contract": contract, "release_env_sha256": sha(ROOT / "tools/update_release.env"),
               "release_wrapper_sha256": sha(ROOT / "tools/build_android_release.sh"),
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
        row = {"step": label, "exit_code": result.returncode, "seconds": round(time.monotonic() - start, 2), "errors": errors,
               "log": str(logs / (label + ".log"))}
        receipt["runs"].append(row)
        save()
        print(json.dumps(row), flush=True)
        if result.returncode or errors:
            raise RuntimeError(label + " failed; see retained private log")
        return text
    proof_created = False
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
            revised = section if args.release else replace_once(section, 'version/name="' + android["version/name"] + '"', 'version/name="' + version + '"')
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
        if not args.release or args.android_template: overlay("export_presets.cfg", preset)
        if not args.release:
            overlay("scripts/menu.gd", lambda s: replace_once(s,
                'Localize.bind_format(ver, "战役重做 · 八幕战役（v%s）", content_version)',
                'Localize.bind_format(ver, "战役重做 · 八幕战役（v%s）", content_version + " · ' + marker + '")'))
        save()
        engine = [args.godot, "--headless", "--path", project]
        run("import", engine + ["--editor", "--import", "--quit"])
        apk = out / (canonical["package"].name if args.release else "水浒英雄传-Android-TEST-" + date + "-" + commit[:8] + ".apk")
        run("android-export", engine + ["--export-debug", "Android", apk])
        apk_identity = {"bytes": apk.stat().st_size, "sha256": sha(apk)}
        base = None
        if args.release:
            base = out / canonical["base"].name
            run("android-base-export", engine + ["--export-pack", "Android", base])
            base_identity = {"bytes": base.stat().st_size, "sha256": sha(base)}
            base_inventory = pck_inventory(base)
            base_names = [entry["path"] for entry in base_inventory["entries"]]
            if len(base_names) != len(set(base_names)): raise RuntimeError("Duplicate base PCK resource")
            check_inventory(base_names)
            (out / "base-inventory.json").write_text(json.dumps(base_inventory, indent=2) + "\n")
            verify_artifact(base, base_identity)
            receipt["base"] = {"name": base.name, **base_identity, "resources": len(base_names)}
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
                   LSH_APK_PROFILE=str(profile_dir), LSH_APK_MARKER=marker, LSH_APK_BASE=android["version/name"],
                   LSH_APK_RELEASE="1" if args.release else "0")
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
                or sha(ROOT / "tools/verify_platform_exports.py") != receipt["helper_sha256"] \
                or sha(ROOT / "tools/update_release.env") != receipt["release_env_sha256"] \
                or sha(ROOT / "tools/build_android_release.sh") != receipt["release_wrapper_sha256"]:
            raise RuntimeError("Source changed during build")
        if args.release:
            release_git_guard()
            if release_contract(ROOT, android, env) != contract: raise RuntimeError("Release contract changed during build")
        verify_artifact(apk, apk_identity)
        if base is not None: verify_artifact(base, receipt["base"])
        receipt["apk"] = {"name": apk.name, **apk_identity,
                          "package": android["package/unique_name"], "abis": abis, "resources": len(resources),
                          "signer_sha256": cert[1].lower(), "v2": True, "v3": True, "internet": True}
        delivery.mkdir(parents=True, exist_ok=False)
        copy_new(apk, delivery / apk.name, receipt["apk"])
        if base is not None: copy_new(base, delivery / base.name, receipt["base"])
        receipt["delivery_dir"] = str(delivery)
        proof = None
        if args.release:
            for target in canonical.values(): require_new_canonical(target)
            copy_new(apk, canonical["package"], receipt["apk"])
            copy_new(base, canonical["base"], receipt["base"])
            release_git_guard()
            proof = {"schema": 1, "version": version, "git_commit": commit,
                     "built_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
                     "platforms": {"android": {kind: {"path": canonical[kind].relative_to(ROOT).as_posix(),
                         "size": canonical[kind].stat().st_size, "sha256": sha(canonical[kind])}
                         for kind in ("package", "base")}}}
            for kind, row in (("package", receipt["apk"]), ("base", receipt["base"])):
                if proof["platforms"]["android"][kind]["sha256"] != row["sha256"] or proof["platforms"]["android"][kind]["size"] != row["bytes"]:
                    raise RuntimeError("Canonical output differs from verified artifact")
            receipt["build_source"] = str(canonical["proof"])
            receipt["canonical_outputs"] = proof["platforms"]["android"]
        if proof is not None:
            write_proof_new(canonical["proof"], proof)
            proof_created = True
        receipt["passed"] = True
        save()
        copy_new(out / "receipt.json", delivery / "receipt.json")
        print("APK: " + str(delivery / apk.name), flush=True)
    except BaseException as error:
        receipt["passed"] = False
        receipt["failure"] = str(error)
        (out / "failure.log").write_text(type(error).__name__ + ": " + str(error) + "\n", encoding="utf-8")
        if proof_created: canonical["proof"].unlink(missing_ok=True)
        if (delivery / "receipt.json").exists():
            (delivery / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(str(error), file=sys.stderr)
    finally:
        if not receipt["passed"]: save()
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
