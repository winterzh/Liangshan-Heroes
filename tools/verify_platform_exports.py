#!/usr/bin/env python3
"""Diagnose Windows/Android candidate exports in a fresh, private directory.

This is not a release or upload command. It never changes versions, creates
tags, invokes publishing scripts, or generates build-source.json. The normal
release guards remain mandatory for any later release. HOME is not changed.
Godot's configured Android debug keystore is reused, never replaced; the
resulting certificate must match tools/update_release.env. The SDK/JDK must
also be configured for Android export in this Godot installation.

Example: python3 tools/verify_platform_exports.py --godot /path/to/Godot \
    --android-sdk /path/to/sdk --java-home /path/to/jdk --build
By default only preflight is performed. --build retains a frozen allowlisted
source copy, logs, package inventories, hashes, and a diagnostic receipt in /tmp.
"""
from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_PARTS = {"tools", "qa", "docs", "source", "sources", "poses",
                   "scratchpad", "build", "__pycache__", "marketing", "native"}
ROOT_FILES = {"project.godot", "export_presets.cfg", "icon.png", "icon.png.import",
              "icon.svg", "icon.svg.import", "icon.ico", "icon.icns"}
ASSET_SUFFIXES = {".png", ".import", ".tres", ".res", ".ttc", ".ttf", ".otf",
                  ".wav", ".ogg", ".mp3", ".svg"}
ASSET_EXTRAS = {"assets/localization/catalog.json", "assets/fonts/OFL.txt"}


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def forbidden(name: str) -> bool:
    parts = PurePosixPath(name.removeprefix("res://")).parts
    return (any(p.lower() in FORBIDDEN_PARTS or p.startswith(("web_prompts_", "implementation_",
                "campaign_environment_v8_")) for p in parts)
            or any("_raw" in p.lower() for p in parts)
            or "override.cfg" in parts)


def allowlist(root: Path) -> list[str]:
    selected = set(ROOT_FILES | ASSET_EXTRAS)
    for directory in ("scripts", "scenes", "assets"):
        for path in (root / directory).rglob("*"):
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                raise RuntimeError("Symbolic source path is not allowed: " + relative)
            if not path.is_file() or forbidden(relative):
                continue
            if directory == "scripts" and path.suffix in {".gd", ".gdshader", ".uid"}:
                selected.add(relative)
            elif directory == "scenes" and path.suffix == ".tscn":
                selected.add(relative)
            elif directory == "assets" and path.suffix in ASSET_SUFFIXES:
                selected.add(relative)
    for relative in selected:
        path = root / relative
        if not path.is_file() or path.is_symlink():
            raise RuntimeError("Missing/unsafe required source: " + relative)
    return sorted(selected)


def read_presets(root: Path) -> tuple[dict, dict]:
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.read(root / "export_presets.cfg", encoding="utf-8")
    def options(name):
        for section in cfg.sections():
            if not section.endswith(".options") and cfg[section].get("name") == json.dumps(name):
                return {key: value.strip('"') for key, value in cfg[section + ".options"].items()}
        raise RuntimeError("Missing preset: " + name)
    return options("Windows Desktop"), options("Android")


def find_sdk_tool(sdk: Path, name: str) -> Path:
    candidates = list((sdk / "build-tools").glob("*/" + name))
    if not candidates:
        raise RuntimeError("Android SDK tool not found: " + name)
    return max(candidates, key=lambda p: tuple(int(x) for x in re.findall(r"\d+", p.parent.name)))


def pck_inventory(path: Path) -> dict:
    """Read Godot PCK v2/v3 directories, including an EXE's embedded footer.

    Format: godotengine/godot 4.6 core/io/file_access_pack.cpp, try_open_pack.
    No extracted file is executed; encrypted/delta/sparse packs fail closed.
    """
    size = path.stat().st_size
    with path.open("rb") as stream:
        def number(fmt):
            length = struct.calcsize(fmt)
            raw = stream.read(length)
            if len(raw) != length:
                raise RuntimeError("Truncated pack")
            return struct.unpack(fmt, raw)[0]
        start = 0
        if stream.read(4) != b"GDPC":
            stream.seek(-12, 2)
            length = number("<Q")
            if stream.read(4) != b"GDPC" or length > size - 12:
                raise RuntimeError("No embedded PCK footer")
            start = size - 12 - length
            stream.seek(start)
            if stream.read(4) != b"GDPC":
                raise RuntimeError("Invalid embedded PCK offset")
        version = number("<I")
        engine = [number("<I") for _ in range(3)]
        flags = number("<I")
        file_base = number("<Q")
        if version not in (2, 3) or flags & ~2:
            raise RuntimeError("Unsupported pack version/flags")
        if version == 3 or flags & 2:
            file_base += start
        if version == 3:
            stream.seek(start + number("<Q"))
        else:
            stream.seek(64, 1)
        count = number("<I")
        if count > 100000:
            raise RuntimeError("Unreasonable pack directory")
        entries = []
        for _ in range(count):
            length = number("<I")
            if length > 65536:
                raise RuntimeError("Invalid pack path length")
            name = stream.read(length).rstrip(b"\x00").decode("utf-8").removeprefix("res://")
            offset, length = number("<Q") + file_base, number("<Q")
            digest = stream.read(16).hex()
            entry_flags = number("<I")
            if entry_flags or offset + length > size or ".." in PurePosixPath(name).parts:
                raise RuntimeError("Invalid/non-plain pack entry: " + name)
            entries.append({"path": name, "bytes": length, "md5": digest})
    return {"format": version, "engine": engine, "entries": entries}


def inspect_windows(path: Path, options: dict) -> dict:
    with path.open("rb") as stream:
        if stream.read(2) != b"MZ":
            raise RuntimeError("Windows artifact is not PE")
        stream.seek(0x3C)
        offset = struct.unpack("<I", stream.read(4))[0]
        stream.seek(offset)
        header = stream.read(176)
        if header[:4] != b"PE\0\0" or struct.unpack_from("<H", header, 4)[0] != 0x8664:
            raise RuntimeError("Windows artifact is not x86_64 PE")
        certificate_offset, certificate_bytes = struct.unpack_from("<II", header, 24 + 112 + 32)
        stream.seek(0)
        # Resource metadata lies before the embedded PCK; bound the search.
        binary = stream.read(min(path.stat().st_size, 128 * 1024 * 1024))
    index = binary.find(b"\xbd\x04\xef\xfe\x00\x00\x01\x00")
    if index < 0:
        raise RuntimeError("Missing Windows version resource")
    def version(at):
        high, low = struct.unpack_from("<II", binary, at)
        return ".".join(str(v) for v in (high >> 16, high & 65535, low >> 16, low & 65535))
    file_version, product_version = version(index + 8), version(index + 16)
    if (file_version != options["application/file_version"]
            or product_version != options["application/product_version"]):
        raise RuntimeError("Windows version resources differ from preset")
    return {"architecture": "x86_64", "file_version": file_version,
            "product_version": product_version, "authenticode_present": bool(certificate_offset and certificate_bytes),
            "native_launch": "not tested: this verifier does not run Windows binaries"}


def check_inventory(names: list[str]) -> None:
    rejected = [name for name in names if forbidden(name)]
    if rejected:
        raise RuntimeError("Development/source material entered package: " + ", ".join(rejected[:12]))
    for required in ("project.binary", "assets/localization/catalog.json", "assets/fonts/OFL.txt"):
        if required not in names:
            raise RuntimeError("Runtime package is missing: " + required)


PACK_PROBE = '''extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var expected := OS.get_environment("LSH_EXPORT_PROFILE")
    if OS.get_user_data_dir().get_file() != expected:
        push_error("Private profile did not apply")
        quit(2)
        return
    var packed = load("res://scenes/menu.tscn")
    if packed == null:
        quit(3)
        return
    var menu = packed.instantiate()
    root.add_child(menu)
    current_scene = menu
    for i in range(30):
        await process_frame
    var font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
    if font == null or not font.has_char("汉".unicode_at(0)) or not font.has_char("あ".unicode_at(0)):
        push_error("Packed font is incomplete")
        quit(4)
        return
    print("[platform-export-menu] ", JSON.stringify({"passed": true,
        "scene": current_scene.scene_file_path, "user_dir": OS.get_user_data_dir(),
        "version": root.get_node("AndroidUpdater").PACKAGE_VERSION_NAME}))
    quit(0)
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--android-sdk", type=Path, required=True)
    parser.add_argument("--java-home", type=Path, required=True)
    parser.add_argument("--out", type=Path, help="New private directory outside the source tree")
    parser.add_argument("--build", action="store_true", help="Export diagnostic candidates (never publish)")
    args = parser.parse_args()
    root = args.root.resolve()
    env = os.environ.copy()
    env.update(JAVA_HOME=str(args.java_home.resolve()), ANDROID_HOME=str(args.android_sdk.resolve()),
               ANDROID_SDK_ROOT=str(args.android_sdk.resolve()))
    for key in list(env):
        if key.startswith(("CONTENT_UPDATE_", "ANDROID_UPDATE_", "LSH_")) or key in {
                "LEVEL", "SMOKE_TEST", "AUTOMICRO", "SKIRMISH", "SKIRMISH_AI", "ARENA", "SCENARIO", "CAMPAIGN_QA"}:
            env.pop(key)
    env["CONTENT_UPDATE_NO_AUTO"] = "1"
    selected = allowlist(root)
    windows, android = read_presets(root)
    signer_match = re.search(r'UPDATE_ANDROID_SIGNER_SHA256:=([0-9a-f]{64})',
                             (root / "tools/update_release.env").read_text(encoding="utf-8"))
    if signer_match is None:
        raise RuntimeError("Expected Android signer hash is absent")
    aapt = find_sdk_tool(args.android_sdk, "aapt")
    apksigner = find_sdk_tool(args.android_sdk, "apksigner")
    for binary in (args.godot, args.java_home / "bin/java", aapt, apksigner):
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise RuntimeError("Missing executable: " + str(binary))
    receipt = {"schema": 1, "diagnostic_only": True, "published": False, "version_changed": False,
               "source_root": str(root), "file_count": len(selected), "runs": [], "artifacts": {},
               "verifier_sha256": sha(Path(__file__).resolve()),
               "godot": subprocess.check_output([str(args.godot), "--version"], text=True, env=env).strip(),
               "expected_android": {"version": android["version/name"], "code": android["version/code"],
                                    "package": android["package/unique_name"], "signer_sha256": signer_match[1]}}
    print(json.dumps(receipt, ensure_ascii=False), flush=True)
    if not args.build:
        return 0
    out = args.out.resolve() if args.out else Path(tempfile.mkdtemp(prefix="lsh-platform-exports-", dir="/tmp"))
    if out == root or root in out.parents:
        raise RuntimeError("Diagnostic output must be outside the source checkout")
    if args.out:
        out.mkdir(parents=True, exist_ok=False)
    project, artifacts, logs = out / "project", out / "artifacts", out / "logs"
    for directory in (project, artifacts, logs):
        directory.mkdir()
    receipt["output"] = str(out)
    receipt["source_files"] = []
    print("Private candidate directory: " + str(out), flush=True)

    def write_receipt():
        (out / "diagnostic-receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def run(name, command, timeout=900):
        start = time.monotonic()
        log = logs / (name + ".log")
        with log.open("w", encoding="utf-8") as stream:
            result = subprocess.run([str(x) for x in command], cwd=out, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        output = log.read_text(encoding="utf-8", errors="replace")
        plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
        errors = [line for line in plain.splitlines() if re.match(r"^(?:SCRIPT ERROR:|ERROR:)", line)]
        row = {"step": name, "exit": result.returncode, "seconds": round(time.monotonic() - start, 2),
               "log": str(log), "errors": errors}
        receipt["runs"].append(row)
        write_receipt()
        print(json.dumps(row, ensure_ascii=False), flush=True)
        if result.returncode or errors:
            raise RuntimeError(name + " failed; retained log: " + str(log))
        return output

    try:
        for relative in selected:
            src, dst = root / relative, project / relative
            before = sha(src)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            if sha(dst) != before or sha(src) != before:
                raise RuntimeError("Source changed while freezing: " + relative)
            receipt["source_files"].append({"path": relative, "bytes": dst.stat().st_size, "sha256": before})
        receipt["source_tree_sha256"] = hashlib.sha256(json.dumps(
            receipt["source_files"], sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
        write_receipt()
        engine = [args.godot, "--headless", "--path", project]
        run("import", engine + ["--editor", "--import", "--log-file", logs / "import-engine.log"])
        exe, apk = artifacts / "LiangshanHeroes-candidate.exe", artifacts / "LiangshanHeroes-candidate.apk"
        run("windows-export", engine + ["--export-release", "Windows Desktop", exe,
                                        "--log-file", logs / "windows-engine.log"])
        win_data = inspect_windows(exe, windows)
        inventory = pck_inventory(exe)
        check_inventory([entry["path"] for entry in inventory["entries"]])
        (out / "windows-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
        receipt["artifacts"]["windows"] = {"path": str(exe), "sha256": sha(exe), "bytes": exe.stat().st_size,
                                           "resources": len(inventory["entries"]), **win_data}
        run("android-export", engine + ["--export-debug", "Android", apk,
                                        "--log-file", logs / "android-engine.log"])
        badging = run("android-badging", [aapt, "dump", "badging", apk])
        manifest = run("android-manifest", [aapt, "dump", "xmltree", apk, "AndroidManifest.xml"])
        signatures = run("android-signature", [apksigner, "verify", "--verbose", "--print-certs", apk])
        for key, expected in (("name", android["package/unique_name"]), ("versionCode", android["version/code"]),
                              ("versionName", android["version/name"])):
            if f"{key}='{expected}'" not in badging.splitlines()[0]:
                raise RuntimeError("APK metadata mismatch: " + key)
        signer = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)", signatures)
        if signer is None or signer[1].lower() != signer_match[1]:
            raise RuntimeError("APK signer differs from installed-client compatibility contract")
        if "uses-permission: name='android.permission.INTERNET'" not in badging:
            raise RuntimeError("APK lacks INTERNET permission")
        cleartext = bool(re.search(r"usesCleartextTraffic.*(?:0xffffffff|true)", manifest))
        # Android's Java network security policy does not prove whether a native
        # Godot HTTPClient request works. Record the manifest, do not misreport
        # an absent usesCleartextTraffic attribute as a demonstrated failure.
        with zipfile.ZipFile(apk) as archive:
            names = archive.namelist()
        abis = sorted({name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")})
        if abis != ["arm64-v8a"]:
            raise RuntimeError("Unexpected APK ABIs: " + str(abis))
        resources = sorted(name.removeprefix("assets/") for name in names if name.startswith("assets/") and not name.endswith("/"))
        check_inventory(resources)
        (out / "android-inventory.json").write_text(json.dumps(names, indent=2) + "\n", encoding="utf-8")
        receipt["artifacts"]["android"] = {"path": str(apk), "sha256": sha(apk), "bytes": apk.stat().st_size,
                                           "resources": len(resources), "abis": abis,
                                           "signer_sha256": signer[1].lower(), "internet": True,
                                           "explicit_cleartext_traffic": cleartext,
                                           "native_http_request": "not tested by static export audit",
                                           "native_launch": "not tested by static export audit",
                                           **receipt["expected_android"]}
        # Godot loads this external override beside --main-pack, not from the
        # exported resources (core/config/project_settings.cpp::_setup).
        profile = "LSH-platform-exports-" + uuid.uuid4().hex
        env["LSH_EXPORT_PROFILE"] = profile
        env["LSH_LANGUAGE"] = "zh_CN"
        override = artifacts / "override.cfg"
        override.write_text('[application]\nconfig/name=' + json.dumps(profile) + '\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=' + json.dumps(profile) + '\n', encoding="utf-8")
        probe = out / "packed_menu_probe.gd"
        probe.write_text(PACK_PROBE, encoding="utf-8")
        try:
            output = run("windows-packed-menu", [args.godot, "--headless", "--main-pack", exe,
                         "--script", probe, "--log-file", logs / "packed-menu-engine.log"], timeout=180)
            if "[platform-export-menu]" not in output:
                raise RuntimeError("Packed menu did not finish its resource check")
            receipt["artifacts"]["windows"]["packed_menu_loaded_on_host"] = True
        finally:
            override.unlink(missing_ok=True)
        changed = [row["path"] for row in receipt["source_files"] if sha(root / row["path"]) != row["sha256"]]
        receipt["source_changed_during_build"] = changed
        receipt["source_inventory_unchanged"] = allowlist(root) == selected
        if changed or not receipt["source_inventory_unchanged"]:
            raise RuntimeError("Source changed during build; candidates are stale: " + ", ".join(changed))
        receipt["passed"] = True
    except Exception as error:
        receipt["passed"] = False
        receipt["failure"] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        write_receipt()
    print("Diagnostic receipt: " + str(out / "diagnostic-receipt.json"), flush=True)
    return 0 if receipt.get("passed") else 1


if __name__ == "__main__":
    sys.exit(main())
