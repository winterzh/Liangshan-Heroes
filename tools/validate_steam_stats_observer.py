"""Preflight by default; --run validates an isolated observer DLL, never vendor.

Reuses the existing reader builder (including its absent/mock QA), then runs
observer facade/absent/mock cases while holding the existing shared Godot lock.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import struct
import sys
import time
import uuid

from run_steam_integration_qa import LOCK, create_private_profile, resolve_godot, resolve_profile_root

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "native/steam_stats_reader"
FACADE_FILES = ["scripts/steam_stats_observer.gd", "scripts/steam_achievement_catalog.gd", "tools/steam_stats_observer_qa.gd"]
INPUT_FILES = FACADE_FILES + ["scripts/steam_stats_reader.gd", "tools/steam_stats_reader_qa.gd", "tools/build_steam_stats_reader.py", "tools/run_steam_integration_qa.py", "tools/test_steam_stats_observer_native.py", "tools/validate_steam_stats_observer.py"]
MOCK_EXPORTS = {
    "SteamAPI_GetHSteamPipe", "SteamAPI_GetHSteamUser", "SteamAPI_SteamUserStats_v013",
    "SteamAPI_SteamUser_v023", "SteamAPI_SteamUtils_v011", "SteamAPI_ISteamUser_GetSteamID",
    "SteamAPI_ISteamUtils_GetAppID", "SteamAPI_ISteamUserStats_RequestUserStats",
    "SteamAPI_ISteamUtils_IsAPICallCompleted", "SteamAPI_ISteamUtils_GetAPICallResult",
    "SteamAPI_ISteamUserStats_GetStatInt32", "SteamAPI_ISteamUserStats_GetUserStatInt32",
    "SteamAPI_ISteamUserStats_GetAchievement", "SteamAPI_ISteamUserStats_GetUserAchievement",
    "lsh_mock_init",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory():
    paths = [p for p in SOURCE.rglob("*") if p.is_file()]
    paths += [ROOT / name for name in INPUT_FILES]
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in paths}


def vendor_inventory():
    directory = ROOT / "vendor/steam_stats_reader"
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in directory.rglob("*") if p.is_file()}


def verify_inventory(expected):
    for name, digest in expected.items():
        if not (ROOT / name).is_file() or sha(ROOT / name) != digest:
            raise RuntimeError("Input changed: " + name)


def require_engine_idle():
    if LOCK.exists():
        raise RuntimeError("Shared Godot lock is busy")
    command = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    running = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", command], text=True).strip()
    if running and json.loads(running):
        raise RuntimeError("Godot is running; shared engine slot unavailable")


def mock_exports(path):
    """Inspect the PE without loading it; a real Steam DLL must never qualify."""
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise RuntimeError("Mock is not a PE image")
    pe = struct.unpack_from("<I", data, 60)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        raise RuntimeError("Mock PE signature mismatch")
    machine, count = struct.unpack_from("<HH", data, pe + 4)
    optional_size = struct.unpack_from("<H", data, pe + 20)[0]
    optional = pe + 24
    if machine != 0x8664 or struct.unpack_from("<H", data, optional)[0] != 0x20B:
        raise RuntimeError("Mock must be Windows x64 PE32+")
    sections = []
    for index in range(count):
        offset = optional + optional_size + index * 40
        virtual_size, rva, raw_size, raw_offset = struct.unpack_from("<IIII", data, offset + 8)
        sections.append((rva, max(virtual_size, raw_size), raw_offset, raw_size))

    def file_offset(rva):
        for start, size, raw, raw_size in sections:
            if start <= rva < start + size and rva - start < raw_size:
                return raw + rva - start
        raise RuntimeError("Mock PE RVA has no file backing")

    export_rva = struct.unpack_from("<I", data, optional + 112)[0]
    export = file_offset(export_rva)
    total, named, _, names_rva = struct.unpack_from("<IIII", data, export + 20)
    if total != len(MOCK_EXPORTS) or named != len(MOCK_EXPORTS):
        raise RuntimeError("Mock has unexpected or unnamed exports")
    names = file_offset(names_rva)
    found = set()
    for index in range(named):
        offset = file_offset(struct.unpack_from("<I", data, names + index * 4)[0])
        end = data.find(b"\0", offset, offset + 160)
        if end < 0:
            raise RuntimeError("Invalid mock export name")
        found.add(data[offset:end].decode("ascii"))
    if found != MOCK_EXPORTS:
        raise RuntimeError("Mock export allowlist mismatch; refusing to load it")
    return sorted(found)


def verify_builder_receipt(path):
    path = path.resolve(strict=True)
    path.relative_to((ROOT / ".godot/steam_reader_build").resolve())
    receipt = json.loads(path.read_text(encoding="utf-8"))
    if receipt.get("complete") is not True or receipt.get("unit_tests", {}).get("passed") is not True:
        raise RuntimeError("Reader builder receipt is incomplete")
    for case in ["absent", "mock"]:
        if receipt.get(case, {}).get("passed") is not True:
            raise RuntimeError("Reader builder did not pass " + case)
    verify_inventory(receipt["sources"])
    # The source set must contain every current native file, not only old files.
    current_native = {p.relative_to(ROOT).as_posix() for p in SOURCE.rglob("*") if p.is_file()}
    if not current_native.issubset(receipt["sources"]):
        raise RuntimeError("Reader builder omitted current native source inputs")
    dll = path.parent / "steam_stats_reader.dll"
    if sha(dll) != receipt.get("dll_sha256"):
        raise RuntimeError("Reader builder DLL hash mismatch")
    mock = path.parent / "steam_api64.dll"
    if not mock.is_file():
        raise RuntimeError("Reader builder mock missing")
    mock_exports(mock)
    return path, receipt, dll, mock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--vcvars", type=Path)
    parser.add_argument("--build-receipt", type=Path, help="Reuse only a complete, source-identical reader builder receipt")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/lsh_observer_build"))
    parser.add_argument("--profile-root", type=Path, default=Path("D:/CodexTemp/lsh_observer_profiles"))
    args = parser.parse_args()
    godot = resolve_godot(args.godot)
    work_root = resolve_profile_root(args.work_root)
    profile_root = resolve_profile_root(args.profile_root)
    if not str(work_root).isascii():
        raise RuntimeError("Native work path must be ASCII")
    sources = inventory()
    vendor = vendor_inventory()
    if not args.run:
        print(json.dumps({"preflight": True, "godot": str(godot), "lock_busy": LOCK.exists(), "source_files": len(sources), "vendor_files": len(vendor), "work_root": str(work_root), "profile_root": str(profile_root), "live_steam_tested": False, "will_replace_vendor": False}))
        return
    require_engine_idle()
    run = ROOT / ".godot/steam_observer_validation" / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8])
    run.mkdir(parents=True, exist_ok=False)
    receipt = {"complete": False, "sources": sources, "vendor_before": vendor, "commands": [], "reports": {}, "live_steam_tested": False, "write_confirmation_tested": False, "vendor_replaced": False, "godot_sha256": sha(godot)}
    env = os.environ.copy()
    env["GODOT_PATH"] = str(godot)
    lock_owned = False

    def execute(command, name, cwd, timeout=180):
        result = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW, timeout=timeout)
        log = run / (name + ".log")
        log.write_bytes(result.stdout)
        receipt["commands"].append({"name": name, "args": command, "exit_code": result.returncode, "log_sha256": sha(log)})
        output = result.stdout.decode(errors="replace")
        if result.returncode or any(marker in output for marker in ["SCRIPT ERROR", "ERROR:", "warning C", "warning LNK"]):
            raise RuntimeError(name + " failed; see " + str(log))
        return output

    try:
        native_command = [sys.executable, "-X", "utf8", "-B", str(ROOT / "tools/test_steam_stats_observer_native.py")]
        if args.vcvars:
            native_command += ["--vcvars", str(args.vcvars)]
        native_output = execute(native_command, "native_tests", ROOT)
        native_summary = json.loads(native_output.strip().splitlines()[-1])
        if native_summary.get("complete") is not True:
            raise RuntimeError("Native observer tests failed")
        native_receipt = Path(native_summary["run"]) / "receipt.json"
        receipt["native_tests"] = {"receipt": str(native_receipt.relative_to(ROOT)), "receipt_sha256": sha(native_receipt), "reports": native_summary["reports"]}
        # The existing builder owns the shared lock during its Godot phase. Do
        # not nest that lock; acquire it again for this wrapper's observer phase.
        if args.build_receipt is None:
            command = [sys.executable, "-X", "utf8", "-B", str(ROOT / "tools/build_steam_stats_reader.py"), "--work-root", str(work_root), "--profile-root", str(profile_root)]
            if args.vcvars:
                command += ["--vcvars", str(args.vcvars)]
            output = execute(command, "reader_builder", ROOT, timeout=1800)
            summary = json.loads(output.strip().splitlines()[-1])
            build_receipt = Path(summary["run"]) / "receipt.json"
        else:
            build_receipt = args.build_receipt
        build_receipt, built, dll, mock = verify_builder_receipt(build_receipt)
        receipt["reader_builder"] = {"receipt": str(build_receipt.relative_to(ROOT)), "receipt_sha256": sha(build_receipt), "dll_sha256": sha(dll), "mock_sha256": sha(mock), "mock_exports": mock_exports(mock)}
        if built.get("godot_sha256") != receipt["godot_sha256"]:
            raise RuntimeError("Builder used a different Godot executable")
        verify_inventory(sources)
        require_engine_idle()
        with LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        lock_owned = True
        project_root = work_root / ("observer_" + run.name)
        resolve_profile_root(project_root)
        project_root.mkdir(parents=True, exist_ok=False)
        for case in ["facade", "absent", "mock"]:
            project = project_root / case
            project.mkdir()
            (project / "project.godot").write_text('[application]\nconfig/name="SteamObserverQA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
            for name in FACADE_FILES:
                if sha(ROOT / name) != sources[name]:
                    raise RuntimeError("Input changed before copy: " + name)
                destination = project / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, destination)
            extensions = []
            if case != "facade":
                shutil.copyfile(dll, project / "steam_stats_reader.dll")
                if sha(project / "steam_stats_reader.dll") != receipt["reader_builder"]["dll_sha256"]:
                    raise RuntimeError("Staged observer DLL hash mismatch")
                (project / "reader.gdextension").write_text('[configuration]\nentry_symbol="lsh_stats_reader_init"\ncompatibility_minimum="4.4"\n[libraries]\nwindows.x86_64="res://steam_stats_reader.dll"\n', encoding="utf-8")
                extensions.append("res://reader.gdextension")
            if case == "mock":
                shutil.copyfile(mock, project / "steam_api64.dll")
                if sha(project / "steam_api64.dll") != receipt["reader_builder"]["mock_sha256"]:
                    raise RuntimeError("Staged synthetic Steam DLL hash mismatch")
                mock_exports(project / "steam_api64.dll")
                (project / "mock.gdextension").write_text('[configuration]\nentry_symbol="lsh_mock_init"\ncompatibility_minimum="4.4"\n[libraries]\nwindows.x86_64="res://steam_api64.dll"\n', encoding="utf-8")
                extensions.insert(0, "res://mock.gdextension")
            if extensions:
                (project / ".godot").mkdir()
                (project / ".godot/extension_list.cfg").write_text("\n".join(extensions) + "\n", encoding="utf-8")
            profile = create_private_profile(project, profile_root / run.name)
            for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
                directory = profile / key.lower()
                directory.mkdir()
                env[key] = str(directory)
            for key in list(env):
                if key.startswith("LSH_MOCK_") or key in ["LSH_READER_ABSENT", "LSH_OBSERVER_NATIVE"]:
                    env.pop(key)
            env["CAMPAIGN_QA"] = "1"
            env["STEAM_DISABLE"] = "1"
            env["LSH_OBSERVER_NATIVE"] = "0" if case == "facade" else "1"
            env["LSH_READER_ABSENT"] = "1" if case == "absent" else "0"
            if case == "mock":
                env["LSH_MOCK_TARGET_OFFSET"] = "1"
                env["LSH_MOCK_DONE"] = "0"
            execute([str(godot), "--headless", "--path", str(project), "--editor", "--import"], case + "_import", project)
            execute([str(godot), "--headless", "--path", str(project), "--script", "res://tools/steam_stats_observer_qa.gd"], case + "_test", project)
            report = json.loads((project / "observer_report.json").read_text(encoding="utf-8"))
            if report.get("passed") is not True or not report.get("checks") or not all(row.get("passed") is True for row in report["checks"]):
                raise RuntimeError("Observer " + case + " report failed")
            (run / (case + "_report.json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
            receipt["reports"][case] = report
        verify_inventory(sources)
        if inventory() != sources or vendor_inventory() != vendor:
            raise RuntimeError("Source inventory or protected vendor changed during validation")
        receipt["complete"] = True
    finally:
        if lock_owned:
            if LOCK.read_text(encoding="utf-8") != str(run):
                receipt["lock_owner_changed"] = True
                receipt["complete"] = False
            else:
                LOCK.unlink()
                receipt["lock_released"] = True
        (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"run": str(run), "complete": receipt["complete"], "cases": {name: len(report["checks"]) for name, report in receipt["reports"].items()}, "vendor_replaced": False}))


if __name__ == "__main__":
    main()
