#!/usr/bin/env python3
"""Verify one signed hot-update candidate using unchanged resources from its real APK.

Offline mode seeds an isolated signed cache; --live-url first downloads through
the production updater, then starts a second process to test natural mounting.
Versioned manifests use a byte-identical loopback relay because bootstrap 4
requests the fixed sibling name manifest.sig. The patch URL is never rewritten.
No production key, script, player profile or remote file is modified.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import http.server
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import threading
import urllib.parse
import urllib.request
import uuid
import zipfile

from verify_platform_exports import allowlist, check_inventory, sha

ROOT = Path(__file__).resolve().parents[1]
PROBE = Path(__file__).with_name("android_hot_candidate_probe.gd")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("godot", "apk", "manifest", "signature", "patch", "out", "source-root"):
        p.add_argument("--" + name, type=Path, required=True)
    p.add_argument("--live-url")
    a = p.parse_args()
    out, source = a.out.resolve(), a.source_root.resolve()
    if sys.platform != "darwin":
        p.error("This actual-APK host verifier currently supports macOS only")
    if not a.out.is_absolute() or out.exists() or out == ROOT or out == source or source in out.parents \
            or (ROOT in out.parents and ROOT / "build" not in out.parents):
        p.error("--out must be new and external, or below checkout/build; never inside source-root")
    if any(x.is_symlink() for x in (a.out, *a.out.parents)):
        p.error("--out may not traverse symlinks; use its canonical absolute path")
    if not a.godot.is_file() or not os.access(a.godot, os.X_OK):
        p.error("Godot executable is missing")
    manifest_raw, signature_raw = a.manifest.read_bytes(), a.signature.read_bytes()
    manifest = json.loads(manifest_raw)
    version = manifest.get("content_version", "")
    if not re.fullmatch(r"2\.0\.[1-9][0-9]*", version) or manifest.get("platform") != "android" \
            or manifest.get("architecture") != "arm64" or manifest.get("min_bootstrap") != 4:
        raise RuntimeError("Expected an Android arm64/bootstrap-4 2.0.x candidate")
    for path, descriptor in ((a.apk, manifest["full_package"]), (a.patch, manifest["patch"])):
        if path.stat().st_size != descriptor["size"] or sha(path) != descriptor["sha256"]:
            raise RuntimeError("Artifact differs from signed candidate descriptor: " + path.name)
    if manifest["full_package"].get("version_name") != "2.0" \
            or any(manifest[k].get("version") != "2.0" for k in ("packaged_base", "patch_base")):
        raise RuntimeError("Candidate does not target the original 2.0 APK")
    selected = allowlist(source)
    inputs = {str(source / n): sha(source / n) for n in selected}
    for path in (a.apk, a.patch, a.manifest, a.signature, a.godot, Path(__file__), PROBE):
        inputs[str(path.resolve())] = sha(path)
    out.mkdir(parents=True)
    report = {"schema": 1, "passed": False, "native_android_tested": False, "content_version": version,
              "patch_sha256": manifest["patch"]["sha256"], "apk_sha256": manifest["full_package"]["sha256"],
              "source_root": str(source), "live_url": a.live_url, "runs": [], "source_files": len(selected)}
    server = None
    def save():
        (out / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    try:
        (out / "input-hashes.json").write_text(json.dumps(inputs, indent=2) + "\n")
        public = re.search(r'const MANIFEST_PUBLIC_KEY := """(.*?)"""',
                           (source / "scripts/android_updater.gd").read_text(), re.S)
        if not public: raise RuntimeError("Production public key is absent")
        (out / "public.pem").write_text(public[1], encoding="ascii")
        (out / "signature.bin").write_bytes(base64.b64decode(signature_raw.strip(), validate=True))
        signed = subprocess.run(["openssl", "dgst", "-sha256", "-verify", str(out / "public.pem"),
                                 "-signature", str(out / "signature.bin"), str(a.manifest.resolve())],
                                capture_output=True, text=True)
        (out / "signature.log").write_text(signed.stdout + signed.stderr)
        if signed.returncode: raise RuntimeError("Candidate signature is invalid")
        project = out / "project"
        project.mkdir()
        with zipfile.ZipFile(a.apk) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or archive.testzip() is not None:
                raise RuntimeError("APK ZIP integrity failure")
            assets = [n for n in names if n.startswith("assets/") and not n.endswith("/")]
            check_inventory([n[7:] for n in assets])
            for name in assets:
                relative = name[7:]
                if "\\" in relative or PurePosixPath(relative).is_absolute() or ".." in PurePosixPath(relative).parts:
                    raise RuntimeError("Unsafe APK asset path")
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(name) as src, target.open("xb") as dst: shutil.copyfileobj(src, dst)
        extracted = {str(path.relative_to(project)): sha(path) for path in project.rglob("*") if path.is_file()}
        profile = "LSH-hot-candidate-" + uuid.uuid4().hex
        profile_dir = Path.home() / "Library/Application Support" / profile
        if profile_dir.exists(): raise RuntimeError("Private profile already exists")
        (project / "override.cfg").write_text('[application]\nconfig/use_custom_user_dir=true\n'
            'config/custom_user_dir_name=' + json.dumps(profile) + '\n')
        probe = out / PROBE.name
        shutil.copy2(PROBE, probe)
        env = {k: v for k, v in os.environ.items() if not k.startswith(("CONTENT_UPDATE_", "ANDROID_UPDATE_", "LSH_"))
               and not k.endswith(("_QA", "_TEST", "_AUDIT")) and k not in {
                   "LEVEL", "AUTOMICRO", "AUTO_MICRO", "SKIRMISH", "SKIRMISH_AI", "ARENA", "SCENARIO", "TOUCH_UI", "CUSTOM_DEFENSE"}}
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", CONTENT_UPDATE_NO_AUTO="1", ANDROID_UPDATE_TEST="1",
                   CONTENT_UPDATE_PLATFORM="android", CONTENT_UPDATE_ARCHITECTURE="arm64", LSH_LANGUAGE="en",
                   LSH_HOT_PROJECT=str(project), LSH_HOT_PROFILE=str(profile_dir), LSH_HOT_VERSION=version,
                   LSH_HOT_PATCH_SHA=manifest["patch"]["sha256"], LSH_HOT_MANIFEST_SHA=sha(a.manifest))
        report.update(private_project=str(project), private_profile=str(profile_dir), apk_assets=len(extracted))
        if a.live_url:
            parsed = urllib.parse.urlsplit(a.live_url)
            if parsed.scheme not in ("http", "https") or not parsed.path.endswith(".json") or parsed.query or parsed.fragment:
                raise RuntimeError("--live-url requires a plain HTTP(S) JSON URL")
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            def fetch(url):
                with opener.open(url, timeout=45) as stream: return stream.read()
            if fetch(a.live_url) != manifest_raw or fetch(a.live_url[:-5] + ".sig") != signature_raw:
                raise RuntimeError("Published candidate bytes differ from verified local manifest/signature")
            url = a.live_url
            if PurePosixPath(parsed.path).name != "manifest.json":
                class Relay(http.server.BaseHTTPRequestHandler):
                    def do_GET(self):
                        body = {"/manifest.json": manifest_raw, "/manifest.sig": signature_raw}.get(urllib.parse.urlsplit(self.path).path)
                        if body is None: self.send_error(404); return
                        self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
                    def log_message(self, *_): pass
                server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Relay)
                threading.Thread(target=server.serve_forever, daemon=True).start()
                url = "http://127.0.0.1:%d/manifest.json" % server.server_port
            env["CONTENT_UPDATE_URL"] = url
            report["manifest_transport"] = "byte-identical loopback relay; original remote patch URL" if server else "direct live HTTP"
        else:
            cache = profile_dir / "android_updates"
            cache.mkdir(parents=True)
            shutil.copy2(a.patch, cache / ("patch-" + version + ".pck"))
            (cache / "state.json").write_text(json.dumps({"manifest": manifest_raw.decode(), "signature": signature_raw.decode()}))
            report["manifest_transport"] = "offline signed installed-cache fixture"
        for mode in (["download", "mount"] if a.live_url else ["mount"]):
            runtime = env | {"LSH_HOT_MODE": mode}
            with (out / (mode + ".log")).open("w") as log:
                result = subprocess.run([str(a.godot.resolve()), "--headless", "--path", str(project), "--script", str(probe)],
                                        env=runtime, cwd=out, stdout=log, stderr=subprocess.STDOUT, timeout=240)
            text = (out / (mode + ".log")).read_text(errors="replace")
            plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
            match = re.search(r"\[android-hot-candidate\] (.+)", plain)
            row = json.loads(match[1]) if match else {"passed": False, "missing_probe_result": True}
            row.update(exit_code=result.returncode, mode=mode)
            report["runs"].append(row); save()
            if result.returncode or not row["passed"] or re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:|Parse Error:)", plain):
                raise RuntimeError("Actual APK candidate " + mode + " failed; inspect retained log")
        report["source_drift"] = [name for name, digest in inputs.items() if not Path(name).is_file() or sha(Path(name)) != digest]
        report["extracted_drift"] = [name for name, digest in extracted.items() if not (project / name).is_file() or sha(project / name) != digest]
        if report["source_drift"] or report["extracted_drift"] or allowlist(source) != selected:
            raise RuntimeError("Source, artifact or original APK resource changed during verification")
        report["passed"] = True
    except Exception as error:
        report["failure"] = str(error)
    finally:
        if server: server.shutdown(); server.server_close()
        save()
    print(json.dumps({"passed": report["passed"], "report": str(out / "report.json"), "failure": report.get("failure")}), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
