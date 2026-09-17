"""Read the signed-in user's Steam statistics without any stat/achievement writes.

Read-only preflight by default; --run explicitly initializes the real Steam API
in a new, isolated minimal Godot process. Never loads the game's SteamService.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import uuid
from run_steam_integration_qa import ROOT, LOCK, install_native, resolve_godot, create_private_profile, resolve_profile_root


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/lsh_live_read"))
    parser.add_argument("--reader-build", type=Path, help="A complete verified build to probe before promotion")
    args = parser.parse_args()
    work_root = resolve_profile_root(args.work_root)
    exe = resolve_godot(None)
    source_paths = ["scripts/steam_stats_reader.gd", "scripts/steam_achievement_catalog.gd", "tools/steam_stats_live_read.gd", "tools/run_steam_stats_live_read.py", "tools/run_steam_integration_qa.py"]
    sources = {name: sha(ROOT / name) for name in source_paths}
    vendor = ROOT / "vendor/steam_stats_reader"
    manifest = json.loads((vendor / "provenance.json").read_text())
    for row in manifest["files"]:
        if sha(vendor / row["path"]) != row["sha256"]: raise RuntimeError("Reader dependency changed")
    reader_dll = vendor / "win64/steam_stats_reader.dll"
    if args.reader_build:
        build = args.reader_build.resolve()
        build.relative_to((ROOT / ".godot/steam_reader_build").resolve())
        proof = json.loads((build / "receipt.json").read_text())
        if not proof.get("complete"): raise RuntimeError("Reader build not validated")
        reader_dll = build / "steam_stats_reader.dll"
        if sha(reader_dll) != proof["dll_sha256"]: raise RuntimeError("Reader build modified")
        for name, digest in proof["sources"].items():
            if sha(ROOT / name) != digest: raise RuntimeError("Reader source changed since build: " + name)
    receipt = {"complete": False, "kind": "real_steam_read_only", "write_calls": 0, "sources": sources,
               "godot_sha256": sha(exe), "reader_dll_sha256": sha(reader_dll),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "steps": []}
    if not args.run:
        print(json.dumps({"preflight": True, "lock_busy": LOCK.exists(), "reader_verified": True})); return
    running = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"], text=True).strip()
    if running and json.loads(running): raise RuntimeError("Game or Godot is running")
    run = work_root / uuid.uuid4().hex[:12]; run.mkdir(parents=True, exist_ok=False)
    owned = False
    try:
        with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
        owned = True
        project = run / "project"; project.mkdir()
        for name in source_paths[:3]:
            dest = project / name; dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(ROOT / name, dest)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="SteamReadOnlyProbe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        (project / "steam_appid.txt").write_text("5088120\n", encoding="ascii")
        install_native(project, include_reader=False)
        dest = project / "addons/steam_stats_reader"; dest.mkdir(parents=True)
        shutil.copyfile(reader_dll, dest / "steam_stats_reader.dll")
        (dest / "reader.gdextension").write_text('[configuration]\nentry_symbol="lsh_stats_reader_init"\ncompatibility_minimum="4.4"\n[libraries]\nwindows.x86_64="res://addons/steam_stats_reader/steam_stats_reader.dll"\n', encoding="utf-8")
        (project / ".godot").mkdir()
        (project / ".godot/extension_list.cfg").write_text("res://addons/godotsteam/godotsteam.gdextension\nres://addons/steam_stats_reader/reader.gdextension\n", encoding="utf-8")
        profile = create_private_profile(run, work_root / "profiles")
        env = os.environ.copy()
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = profile / key.lower(); private.mkdir(); env[key] = str(private)
        binaries = {str(path.relative_to(project)): sha(path) for path in project.rglob("*.dll")}
        # This minimal probe explicitly initializes Steam. Production eligibility
        # rules and all player files remain untouched; no game autoload is present.
        env["SteamAppId"] = "5088120"; env["SteamGameId"] = "5088120"
        for label, extra in [("import", ["--editor", "--import"]), ("read", ["--script", "res://tools/steam_stats_live_read.gd"])]:
            with (run / (label + ".log")).open("wb") as stream:
                result = subprocess.run([str(exe), "--headless", "--path", str(project)] + extra, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=90, creationflags=subprocess.CREATE_NO_WINDOW)
            log = (run / (label + ".log")).read_text(encoding="utf-8", errors="replace")
            errors = len(re.findall(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", log))
            receipt["steps"].append({"label": label, "exit_code": result.returncode, "errors": errors})
            if result.returncode or errors: break
        if (project / "read_report.json").exists(): receipt["result"] = json.loads((project / "read_report.json").read_text())
        if any(sha(ROOT / name) != digest for name, digest in sources.items()): raise RuntimeError("Source changed during probe")
        if sha(exe) != receipt["godot_sha256"] or sha(reader_dll) != receipt["reader_dll_sha256"]: raise RuntimeError("Runtime binary changed during probe")
        if any(sha(project / name) != digest for name, digest in binaries.items()): raise RuntimeError("Installed dependency changed during probe")
        receipt["installed_binary_sha256"] = binaries
        receipt["complete"] = len(receipt["steps"]) == 2 and all(row["exit_code"] == 0 and row["errors"] == 0 for row in receipt["steps"]) and receipt.get("result", {}).get("complete", False)
    finally:
        (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        if owned: LOCK.unlink()
    print(json.dumps({"run": str(run), "complete": receipt["complete"], "result": receipt.get("result", {})}))
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
