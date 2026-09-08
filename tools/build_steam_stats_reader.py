"""Build/test the read-only Windows x64 bridge. Never initialize Steam.

Requires Visual Studio C++ tools. Generated files remain under .godot; promotion
to vendor/ is a separate reviewed operation after the Godot smoke test.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil
import uuid
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "native/steam_stats_reader"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcvars", type=Path)
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/lsh_reader_build"))
    parser.add_argument("--profile-root", type=Path, default=Path("D:/CodexTemp/lsh_reader_profiles"))
    args = parser.parse_args()
    vcvars = args.vcvars
    if vcvars is None:
        finder = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
        installation = subprocess.check_output([str(finder), "-latest", "-prerelease", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"], text=True).strip()
        if not installation: raise RuntimeError("Visual Studio x64 C++ tools unavailable")
        vcvars = Path(installation) / "VC/Auxiliary/Build/vcvars64.bat"
    vcvars = vcvars.resolve(strict=True)
    if any(c in str(vcvars) for c in '"\r\n%&|<>^'): raise RuntimeError("Unsafe compiler environment path")
    raw = subprocess.check_output(f'cmd.exe /d /s /c ""{vcvars}" >nul && set"', text=True)
    env = {key.upper(): value for key, value in os.environ.items()}
    for line in raw.splitlines():
        if "=" in line and not line.startswith("="):
            key, value = line.split("=", 1); env[key.upper()] = value
    run = ROOT / ".godot/steam_reader_build" / uuid.uuid4().hex[:12]
    run.mkdir(parents=True, exist_ok=False)
    rows = {p.relative_to(ROOT).as_posix(): sha(p) for p in SOURCE.rglob("*") if p.is_file()}
    inputs = ["scripts/steam_stats_reader.gd", "scripts/steam_achievement_catalog.gd", "tools/steam_stats_reader_qa.gd", "tools/build_steam_stats_reader.py", "tools/run_steam_integration_qa.py"]
    rows.update({path: sha(ROOT / path) for path in inputs})
    receipt = {"complete": False, "sources": rows, "commands": [], "live_steam_tested": False,
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()}
    def execute(args, name):
        result = subprocess.run(args, cwd=run, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW, timeout=180)
        (run / (name + ".log")).write_bytes(result.stdout)
        receipt["commands"].append({"name": name, "args": args, "exit_code": result.returncode})
        if result.returncode:
            print(result.stdout.decode(errors="replace")); raise RuntimeError(name + " failed")
        return result.stdout
    try:
        compiler = Path(env["VCTOOLSINSTALLDIR"]) / "bin/Hostx64/x64/cl.exe"
        receipt["compiler_sha256"] = sha(compiler)
        flags = [str(compiler), "/nologo", "/std:c++17", "/EHsc", "/W4", "/WX", "/O2", "/MT", "/Brepro", "/guard:cf", "/I" + str(SOURCE / "third_party")]
        execute(flags + [str(SOURCE / "reader_test.cpp"), "/Fe:reader_test.exe"], "compile_tests")
        output = execute([str(run / "reader_test.exe")], "unit_tests")
        receipt["unit_tests"] = json.loads(output)
        cpp_url = "https://github.com/godotengine/godot-cpp/archive/refs/tags/godot-4.4-stable.zip"
        cpp_sha = "0d64106ce1e09547f6054743b6fb9db903f23f27d1e669c7556a0a02669bd9ba"
        archive = ROOT / ".godot/steam_reader_build/godot-cpp.zip"
        if not archive.exists(): urllib.request.urlretrieve(cpp_url, archive)
        if sha(archive) != cpp_sha: raise RuntimeError("godot-cpp archive hash mismatch")
        from run_steam_integration_qa import resolve_profile_root
        work_root = resolve_profile_root(args.work_root)
        if not str(work_root).isascii(): raise RuntimeError("Native build requires an ASCII work path")
        build_root = work_root / run.name
        build_root.mkdir(parents=True, exist_ok=False)
        shutil.copytree(SOURCE, build_root / "source")
        with zipfile.ZipFile(archive) as zipped: zipped.extractall(build_root / "dependency")
        cpp = build_root / "dependency/godot-cpp-godot-4.4-stable"
        cmake_home = vcvars.parents[3] / "Common7/IDE/CommonExtensions/Microsoft/CMake"
        cmake = cmake_home / "CMake/bin/cmake.exe"
        ninja = cmake_home / "Ninja/ninja.exe"
        cmake_build = build_root / "cmake"
        execute([str(cmake), "-S", str(build_root / "source"), "-B", str(cmake_build), "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_MAKE_PROGRAM=" + str(ninja), "-DCMAKE_CXX_COMPILER=" + str(compiler), "-DPython3_EXECUTABLE=" + sys.executable, "-DGODOT_CPP_SOURCE=" + str(cpp)], "configure_extension")
        execute([str(cmake), "--build", str(cmake_build), "--target", "steam_stats_reader", "--parallel", "6"], "compile_extension")
        shutil.copyfile(cmake_build / "steam_stats_reader.dll", run / "steam_stats_reader.dll")
        receipt["godot_cpp"] = {"url": cpp_url, "sha256": cpp_sha}
        execute(flags + ["/LD", str(SOURCE / "mock_steam.cpp"), "/Fe:steam_api64.dll", "/link", "/DYNAMICBASE", "/NXCOMPAT", "/Brepro"], "compile_mock")
        # Run the exact DLL through Godot against no Steam and a synthetic DLL.
        # The synthetic library has no initialization or write exports.
        from run_steam_integration_qa import LOCK, resolve_godot, create_private_profile
        godot = resolve_godot(None)
        receipt["godot_sha256"] = sha(godot)
        running = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"], text=True).strip()
        if running and json.loads(running): raise RuntimeError("Godot slot unavailable")
        lock_owned = False
        try:
            with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
            lock_owned = True
            profile = create_private_profile(run, args.profile_root)
            for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
                target = profile / key.lower(); target.mkdir(); env[key] = str(target)
            env["CAMPAIGN_QA"] = "1"; env["STEAM_DISABLE"] = "1"
            for key in list(env):
                if key.startswith("LSH_MOCK_") or key == "LSH_READER_ABSENT": env.pop(key)
            for case in ["absent", "mock"]:
                project = build_root / case; project.mkdir()
                (project / "project.godot").write_text('[application]\nconfig/name="SteamReaderQA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
                for path in ["scripts/steam_stats_reader.gd", "scripts/steam_achievement_catalog.gd", "tools/steam_stats_reader_qa.gd"]:
                    source = ROOT / path
                    if sha(source) != rows[path]: raise RuntimeError("Input changed before copy: " + path)
                    dest = project / path; dest.parent.mkdir(exist_ok=True); shutil.copyfile(source, dest)
                shutil.copyfile(run / "steam_stats_reader.dll", project / "steam_stats_reader.dll")
                (project / "reader.gdextension").write_text('[configuration]\nentry_symbol="lsh_stats_reader_init"\ncompatibility_minimum="4.4"\n[libraries]\nwindows.x86_64="res://steam_stats_reader.dll"\n', encoding="utf-8")
                env["LSH_READER_ABSENT"] = "1" if case == "absent" else "0"
                if case == "mock":
                    shutil.copyfile(run / "steam_api64.dll", project / "steam_api64.dll")
                    (project / "mock.gdextension").write_text('[configuration]\nentry_symbol="lsh_mock_init"\ncompatibility_minimum="4.4"\n[libraries]\nwindows.x86_64="res://steam_api64.dll"\n', encoding="utf-8")
                # Avoid late class discovery during --import (Godot #111645).
                # Register the fixed extension paths before the first editor scan.
                (project / ".godot").mkdir()
                extensions = (["res://mock.gdextension"] if case == "mock" else []) + ["res://reader.gdextension"]
                (project / ".godot/extension_list.cfg").write_text("\n".join(extensions) + "\n", encoding="utf-8")
                execute([str(godot), "--headless", "--path", str(project), "--editor", "--import"], case + "_import")
                execute([str(godot), "--headless", "--path", str(project), "--script", "res://tools/steam_stats_reader_qa.gd"], case + "_test")
                report = json.loads((project / "report.json").read_text())
                (run / (case + "_report.json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
                if not report["passed"]: raise RuntimeError(case + " failed")
                receipt[case] = report
        finally:
            if lock_owned: LOCK.unlink()
        for path, digest in rows.items():
            if sha(ROOT / path) != digest: raise RuntimeError("Source changed during build: " + path)
        for log in run.glob("*.log"):
            text = log.read_bytes().decode(errors="replace")
            if any(marker in text for marker in ["SCRIPT ERROR", "ERROR:", "warning C", "warning LNK"]): raise RuntimeError("Errors or compiler warnings in " + log.name)
        receipt["dll_sha256"] = sha(run / "steam_stats_reader.dll")
        receipt["complete"] = True
    finally:
        (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"run": str(run), "checks": receipt["unit_tests"]["checks"], "dll_sha256": receipt["dll_sha256"]}))


if __name__ == "__main__":
    main()
