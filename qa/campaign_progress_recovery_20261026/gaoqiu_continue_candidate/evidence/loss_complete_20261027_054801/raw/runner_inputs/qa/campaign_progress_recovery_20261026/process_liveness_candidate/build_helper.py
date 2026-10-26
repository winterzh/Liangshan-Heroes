"""Compile only the standalone QA helper; never starts Godot or changes a Store."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "native/ProcessLivenessProbe.cs"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", help="Actually compile; default prints preflight only.")
    args = parser.parse_args()
    if os.name != "nt":
        raise SystemExit("Windows-only compiler; other platforms retain unknown.")
    windows = Path(os.environ.get("SystemRoot", ""))
    if not windows.is_absolute():
        raise SystemExit("SystemRoot must be an absolute path.")
    compiler = windows / "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
    if not compiler.is_file():
        compiler = windows / "Microsoft.NET/Framework/v4.0.30319/csc.exe"
    if not compiler.is_file():
        raise SystemExit("Fixed .NET Framework csc.exe unavailable; no PATH or shell fallback.")
    preflight = {"schema": "process_liveness_build_v1", "compiled": False, "compiler_path": str(compiler),
                 "compiler_sha256": sha(compiler), "source_path": str(SOURCE), "source_sha256": sha(SOURCE),
                 "build_tool_sha256": sha(Path(__file__)), "godot_started": False, "production_integrated": False}
    if not args.build:
        print(json.dumps(preflight, indent=2)); return
    name = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    output = ROOT / ".artifacts" / name
    output.mkdir(parents=True, exist_ok=False)
    executable = output / "ProcessLivenessProbe.exe"
    command = [str(compiler), "/nologo", "/target:exe", "/platform:anycpu", "/optimize+", "/checked+",
               "/warn:4", "/warnaserror+", "/out:" + str(executable), str(SOURCE)]
    report = dict(preflight, command=command, output=str(output))
    child = None
    started = time.monotonic()
    try:
        with (output / "compile.log").open("xb") as log:
            child = subprocess.Popen(command, cwd=output, shell=False, stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            report["compiler_pid"] = child.pid
            child.wait(timeout=30)
        report["compiler_exit"] = child.returncode
        if child.returncode != 0:
            raise RuntimeError("csc failed; retained compile.log")
        if not executable.is_file() or executable.stat().st_size > 1024 * 1024:
            raise RuntimeError("helper missing/oversized")
        if sha(compiler) != preflight["compiler_sha256"] or sha(SOURCE) != preflight["source_sha256"]:
            raise RuntimeError("build input changed")
        report.update(compiled=True, helper_path=str(executable), helper_sha256=sha(executable), helper_bytes=executable.stat().st_size)
    except BaseException as error:
        report["error"] = repr(error)
    finally:
        if child is not None and child.poll() is None:
            child.kill(); child.wait(timeout=10)  # Only this Popen-owned compiler.
        report["owned_compiler_terminal"] = child is None or child.poll() is not None
        report["elapsed_seconds"] = time.monotonic() - started
        report["complete"] = report["compiled"] and report["owned_compiler_terminal"]
        (output / "build_receipt.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        (ROOT / "evidence" / ("build_" + name + ".json")).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    if not report["complete"]:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
