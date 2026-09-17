"""Compile and run only synthetic C++ reader/observer tests; no Godot or Steam.

Builds test EXEs under .godot/steam_observer_native, never a production DLL.
The existing current-user reader tests run unchanged as a compatibility check.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "native/steam_stats_reader"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcvars", type=Path)
    args = parser.parse_args()
    vcvars = args.vcvars
    if vcvars is None:
        finder = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
        installation = subprocess.check_output([str(finder), "-latest", "-prerelease", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"], text=True).strip()
        if not installation:
            raise RuntimeError("Visual Studio x64 C++ tools unavailable")
        vcvars = Path(installation) / "VC/Auxiliary/Build/vcvars64.bat"
    vcvars = vcvars.resolve(strict=True)
    if any(char in str(vcvars) for char in '"\r\n%&|<>^'):
        raise RuntimeError("Unsafe compiler environment path")
    raw = subprocess.check_output(f'cmd.exe /d /s /c ""{vcvars}" >nul && set"', text=True)
    env = {key.upper(): value for key, value in os.environ.items()}
    for line in raw.splitlines():
        if "=" in line and not line.startswith("="):
            key, value = line.split("=", 1)
            env[key.upper()] = value
    run = ROOT / ".godot/steam_observer_native" / uuid.uuid4().hex[:12]
    run.mkdir(parents=True, exist_ok=False)
    input_paths = [p for p in SOURCE.rglob("*") if p.is_file()]
    input_paths += [ROOT / path for path in ["scripts/steam_stats_reader.gd", "scripts/steam_stats_observer.gd", "tools/test_steam_stats_observer_native.py"]]
    hashes = {p.relative_to(ROOT).as_posix(): sha(p) for p in input_paths}
    receipt = {"complete": False, "sources": hashes, "commands": [], "reports": {}, "live_steam_tested": False, "godot_run": False, "production_dll_built": False}
    try:
        compiler = Path(env["VCTOOLSINSTALLDIR"]) / "bin/Hostx64/x64/cl.exe"
        receipt["compiler_sha256"] = sha(compiler)
        flags = [str(compiler), "/nologo", "/std:c++17", "/EHsc", "/W4", "/WX", "/O2", "/MT", "/Brepro", "/guard:cf"]
        for test in ["reader_test", "observer_test"]:
            commands = [(test + "_compile", flags + [str(SOURCE / (test + ".cpp")), "/Fe:" + test + ".exe"]), (test, [str(run / (test + ".exe"))])]
            for name, command in commands:
                result = subprocess.run(command, cwd=run, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW, timeout=180)
                log = run / (name + ".log")
                log.write_bytes(result.stdout)
                receipt["commands"].append({"name": name, "args": command, "exit_code": result.returncode, "log_sha256": sha(log)})
                output = result.stdout.decode(errors="replace")
                if result.returncode or "warning C" in output or "warning LNK" in output:
                    raise RuntimeError(name + " failed: " + output)
                if name == test:
                    report = json.loads(output)
                    if report.get("passed") is not True:
                        raise RuntimeError(name + " report failed")
                    receipt["reports"][test] = report
                    receipt["reports"][test]["exe_sha256"] = sha(run / (test + ".exe"))
        for name, digest in hashes.items():
            if sha(ROOT / name) != digest:
                raise RuntimeError("Source changed during tests: " + name)
        receipt["complete"] = True
    finally:
        (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"run": str(run), "complete": receipt["complete"], "reports": receipt["reports"]}))


if __name__ == "__main__":
    main()
