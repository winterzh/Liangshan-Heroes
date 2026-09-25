"""Private signed HTTP/update/restart regression. No publishing or production key use.

Only the frozen test copy uses an ephemeral public key. The live Android manifest
is first verified against the unmodified shipped key. HOME and player saves are
never redirected or touched. Output stays outside the source checkout.
"""
from __future__ import annotations
import argparse
import base64
import copy
import functools
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import threading
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
LIVE = "http://120.26.237.195:1234/liangshan/android/stable/"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--live", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    if not args.out.is_absolute() or out == ROOT or ROOT in out.parents or out.exists():
        raise SystemExit("--out must be a new directory outside the checkout")
    project = out / "project"
    project.mkdir(parents=True)
    for directory in ("assets", "scripts", "scenes"):
        shutil.copytree(ROOT / directory, project / directory)
    shutil.copy2(ROOT / "project.godot", project / "project.godot")
    (project / "tools").mkdir()
    shutil.copy2(ROOT / "tools/update_transport_qa.gd", project / "tools/update_transport_qa.gd")
    profile = "LSH-update-qa-" + uuid.uuid4().hex
    (project / "override.cfg").write_text(
        '[application]\nconfig/name="' + profile + '"\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="' + profile + '"\n', encoding="utf-8")
    source = (ROOT / "scripts/android_updater.gd").read_text(encoding="utf-8")
    base_version = re.search(r'const BASE_CONTENT_VERSION := "([0-9.]+)"', source).group(1)
    bootstrap = int(re.search(r'const BOOTSTRAP_VERSION := (\d+)', source).group(1))
    major, minor = (int(part) for part in base_version.split("."))
    test_version, next_base = base_version + ".99", f"{major}.{minor + 1}"
    reports = []
    env = os.environ.copy()
    for key in list(env):
        if key.startswith(("CONTENT_UPDATE_", "ANDROID_UPDATE_", "UPDATE_QA_", "LSH_")):
            env.pop(key)
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_LANGUAGE="zh_CN",
               CONTENT_UPDATE_NO_AUTO="1", UPDATE_QA_PROFILE=profile,
               UPDATE_QA_PROJECT=str(project), UPDATE_QA_OUT=str(out))

    def command(name, argv, process_env=None, timeout=300):
        log = out / (name + ".log")
        with log.open("w", encoding="utf-8") as stream:
            result = subprocess.run(argv, env=process_env or env, cwd=out,
                                    stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        text = log.read_text(encoding="utf-8", errors="replace")
        if result.returncode or "SCRIPT ERROR:" in text or "ERROR:" in text:
            raise RuntimeError(f"{name} failed, see {log}")

    def run(name, mode, expected="", **extra):
        runtime = env | {"CONTENT_UPDATE_TEST": "1", "CONTENT_UPDATE_PLATFORM": "android",
                         "CONTENT_UPDATE_ARCHITECTURE": "arm64", "UPDATE_QA_MODE": mode,
                         "UPDATE_QA_CONTENT_VERSION": test_version,
                         "UPDATE_QA_EXPECT": expected, "UPDATE_QA_REPORT": str(out / (name + ".json"))} | extra
        command(name, [str(args.godot), "--headless", "--path", str(project),
                       "--script", "res://tools/update_transport_qa.gd"], runtime, 40)
        report = json.loads((out / (name + ".json")).read_text(encoding="utf-8"))
        reports.append(report | {"name": name})
        print(json.dumps(reports[-1], ensure_ascii=False), flush=True)
        return report

    command("import", [str(args.godot), "--headless", "--path", str(project), "--editor", "--import"])
    for platform in ("windows", "macos"):
        run(platform + "_disabled", "disabled", CONTENT_UPDATE_PLATFORM=platform,
            CONTENT_UPDATE_ARCHITECTURE="x86_64")
    run("android_override_without_test_disabled", "disabled", CONTENT_UPDATE_TEST="0")
    live_report = None
    if args.live:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        def fetch(url):
            with opener.open(url, timeout=30) as response:
                return response.read()
        raw, sig = fetch(LIVE + "manifest.json"), fetch(LIVE + "manifest.sig")
        (out / "live-manifest.json").write_bytes(raw)
        (out / "live-signature.bin").write_bytes(base64.b64decode(sig, validate=True))
        pub = re.search(r'const MANIFEST_PUBLIC_KEY := """(.*?)"""', source, re.S).group(1)
        (out / "production-public.pem").write_text(pub, encoding="ascii")
        command("live-signature", ["openssl", "dgst", "-sha256", "-verify", str(out / "production-public.pem"),
                                   "-signature", str(out / "live-signature.bin"), str(out / "live-manifest.json")])
        data = json.loads(raw)
        patch_info = None
        if isinstance(data.get("patch"), dict):
            patch = fetch(data["patch"]["url"])
            assert len(patch) == data["patch"]["size"]
            assert hashlib.sha256(patch).hexdigest() == data["patch"]["sha256"]
            (out / "live-patch.pck").write_bytes(patch)
            patch_info = {"patch_size": len(patch), "patch_sha256": hashlib.sha256(patch).hexdigest()}
        # Inspect the live service without installing/mounting its real patch in
        # the fixture project. Actual Godot download/restart is exercised below.
        run("live_android", "inspect_live", "current,available,full_update", CONTENT_UPDATE_URL=LIVE + "manifest.json")
        live_report = {"content_version": data["content_version"], "published_at": data["published_at"],
                       "signature": True, **(patch_info or {})}

    command("test-key", ["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048",
                         "-out", str(out / "test-private.pem")])
    os.chmod(out / "test-private.pem", 0o600)
    command("test-public", ["openssl", "pkey", "-in", str(out / "test-private.pem"), "-pubout", "-out", str(out / "test-public.pem")])
    test_pub = (out / "test-public.pem").read_text(encoding="ascii")
    test_source = re.sub(r'(const MANIFEST_PUBLIC_KEY := """).*?(""")',
                         lambda match: match.group(1) + test_pub + match.group(2), source, count=1, flags=re.S)
    (project / "scripts/android_updater.gd").write_text(test_source, encoding="utf-8")
    web = out / "http"
    web.mkdir()
    marker = out / "marker.txt"
    marker.write_text("isolated-patch-loaded", encoding="utf-8")
    run("make_patch", "pack", UPDATE_QA_PACK=str(web / "patch.pck"), UPDATE_QA_MARKER=str(marker))
    patch = (web / "patch.pck").read_bytes()
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(web))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = f"http://127.0.0.1:{server.server_port}/"
    fixture_base = {"version": base_version, "size": len(patch), "sha256": hashlib.sha256(patch).hexdigest()}
    manifest = {"schema": 1, "channel": "stable", "content_version": test_version, "min_bootstrap": bootstrap,
                "platform": "android", "architecture": "arm64",
                "packaged_base": copy.deepcopy(fixture_base), "patch_base": copy.deepcopy(fixture_base),
                "full_package": {"version_name": base_version, "url": base_url + "full.apk"},
                "patch": {"platform": "android", "architecture": "arm64", "url": base_url + "patch.pck",
                          "size": len(patch), "sha256": hashlib.sha256(patch).hexdigest()}}

    def publish_fixture(data, corrupt_signature=False):
        (web / "manifest.json").write_text(json.dumps(data), encoding="utf-8")
        command("sign-fixture", ["openssl", "dgst", "-sha256", "-sign", str(out / "test-private.pem"),
                                 "-out", str(web / "sig.bin"), str(web / "manifest.json")])
        signature = bytearray((web / "sig.bin").read_bytes())
        if corrupt_signature: signature[0] ^= 1
        (web / "manifest.sig").write_bytes(base64.b64encode(signature))

    try:
        # A complete 2.0 release offers no delta to the old 1.8 APK. Change only
        # version constants in the private fixture; the shipped source stays 2.0.
        full_release = copy.deepcopy(manifest)
        full_release["content_version"] = base_version
        del full_release["patch"]
        publish_fixture(full_release)
        legacy_source = test_source.replace('const PACKAGE_VERSION_NAME := "' + base_version + '"',
                                            'const PACKAGE_VERSION_NAME := "1.8"', 1)
        legacy_source = legacy_source.replace('const BASE_CONTENT_VERSION := "' + base_version + '"',
                                              'const BASE_CONTENT_VERSION := "1.8"', 1)
        legacy_source = re.sub(r'const PACKAGE_VERSION_CODE := \d+', 'const PACKAGE_VERSION_CODE := 15', legacy_source, count=1)
        try:
            (project / "scripts/android_updater.gd").write_text(legacy_source, encoding="utf-8")
            run("old_1_8_apk_requires_full_2_0", "request", "full_update",
                UPDATE_QA_FULL_VERSION=base_version, CONTENT_UPDATE_URL=base_url + "manifest.json")
        finally:
            (project / "scripts/android_updater.gd").write_text(test_source, encoding="utf-8")
        run("full_2_0_already_current", "request", "current", CONTENT_UPDATE_URL=base_url + "manifest.json")

        for case in ("signature", "platform", "architecture", "patch_platform", "size", "hash", "bootstrap"):
            data = copy.deepcopy(manifest)
            if case == "platform": data["platform"] = "macos"
            elif case == "architecture": data["architecture"] = "x86_64"
            elif case == "patch_platform": data["patch"]["platform"] = "windows"
            elif case == "size": data["patch"]["size"] += 1
            elif case == "hash": data["patch"]["sha256"] = "0" * 64
            elif case == "bootstrap":
                data["min_bootstrap"] = bootstrap + 1
                data["full_package"]["version_name"] = next_base
            publish_fixture(data, case == "signature")
            run("reject_" + case, "request", "full_update" if case == "bootstrap" else "error",
                CONTENT_UPDATE_URL=base_url + "manifest.json")

        incompatible = {}
        for case in ("packaged_base", "patch_base", "cross_base", "missing_base", "legacy_base",
                     "base_hash", "base_size", "base_type", "base_version_type", "base_hash_type"):
            data = copy.deepcopy(manifest)
            expected = "error"
            if case in ("packaged_base", "patch_base", "cross_base"):
                if case != "patch_base": data["packaged_base"]["version"] = next_base
                if case != "packaged_base": data["patch_base"]["version"] = next_base
                data["content_version"] = next_base + ".99"
                data["full_package"]["version_name"] = next_base
                expected = "full_update"
            elif case == "missing_base": del data["packaged_base"]
            elif case == "legacy_base":
                data["min_bootstrap"] = 1
                data["patch_base"]["version"] = "1.4.0"
                # This is the real legacy base hash, not an allowable exception.
                data["patch_base"]["sha256"] = "d2198b09743d692041c6a5b976a6c3f58943f1955086f5332f9395e6e1a144de"
            elif case == "base_hash": data["patch_base"]["sha256"] = "0" * 64
            elif case == "base_size": data["patch_base"]["size"] += 1
            elif case == "base_type": data["patch_base"] = None
            elif case == "base_version_type": data["patch_base"]["version"] = None
            elif case == "base_hash_type": data["patch_base"]["sha256"] = None
            incompatible[case] = data
            publish_fixture(data)
            run("reject_" + case, "request", expected, CONTENT_UPDATE_URL=base_url + "manifest.json")

        legacy_current = copy.deepcopy(incompatible["legacy_base"])
        legacy_current["content_version"] = base_version
        publish_fixture(legacy_current)
        run("legacy_current_no_downgrade", "request", "current", CONTENT_UPDATE_URL=base_url + "manifest.json")
        publish_fixture(manifest)
        download = run("download", "request", "ready", CONTENT_UPDATE_URL=base_url + "manifest.json")
        run("restart_mount", "mount", CONTENT_UPDATE_URL=base_url + "manifest.json")
        cache_root = Path(download["user_dir"]) / "android_updates"
        cache = cache_root / ("patch-" + test_version + ".pck")
        assert profile in str(cache)
        cache.write_bytes(b"corrupted private QA cache")
        run("reject_corrupt_cache", "reject_cached", CONTENT_UPDATE_URL=base_url + "manifest.json")
        # Seed correctly signed, intact PCK caches: their only incompatibility
        # is the base contract. Every run is a fresh process, before autoloads.
        for case, data in incompatible.items():
            publish_fixture(data)
            (cache_root / ("patch-" + data["content_version"] + ".pck")).write_bytes(patch)
            (cache_root / "state.json").write_text(json.dumps({
                "manifest": (web / "manifest.json").read_text(encoding="utf-8"),
                "signature": (web / "manifest.sig").read_text(encoding="ascii")}), encoding="utf-8")
            run("reject_cached_" + case, "reject_cached", CONTENT_UPDATE_URL=base_url + "manifest.json")
    finally:
        server.shutdown()
        server.server_close()
    assert source == (ROOT / "scripts/android_updater.gd").read_text(encoding="utf-8")
    summary = {"passed": all(report["passed"] for report in reports), "live": live_report,
               "base_version": base_version, "test_version": test_version, "bootstrap": bootstrap,
               "ephemeral_key_only_in_private_copy": True, "production_source_unchanged": True,
               "scope": "Private editor simulates Android; desktop disable policy, 1.8-to-2.0 full-package migration, same-base signed HTTP/cache/PCK mount; not physical Android acceptance",
               "runs": reports}
    (out / "report.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("REPORT " + str(out / "report.json"), flush=True)


if __name__ == "__main__":
    main()
