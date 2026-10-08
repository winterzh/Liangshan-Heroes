"""Record local import, ordinary startup and a real menu viewport in a private profile."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid

from run_steam_integration_qa import ROOT, LOCK, sources, native_dependencies, resolve_godot

ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def engines():
    command = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", command], text=True,
                                  creationflags=subprocess.CREATE_NO_WINDOW).strip()
    result = json.loads(raw) if raw else []
    return set(result if isinstance(result, list) else [result])


def foreign_engines(owner_pid):
    command = "@(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", command], text=True,
                                  creationflags=subprocess.CREATE_NO_WINDOW)
    rows = json.loads(raw)
    parents = {row["ProcessId"]: row["ParentProcessId"] for row in rows}
    foreign = []
    for row in rows:
        if not row["Name"].lower().startswith("godot"):
            continue
        pid = row["ProcessId"]
        seen = set()
        while pid not in seen and pid != owner_pid and pid in parents:
            seen.add(pid)
            pid = parents[pid]
        if pid != owner_pid:
            foreign.append(row["ProcessId"])
    return foreign


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/lsh-office-20261008"))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    dependencies = native_dependencies()
    if not args.run:
        print(json.dumps({"preflight": True, "godot": str(engine), "native_manifests_verified": list(dependencies),
                          "source_files": len(sources()), "lock_busy": LOCK.exists(), "engine_pids": sorted(engines())}))
        return
    work_root = args.work_root.absolute()
    for path in [work_root, *work_root.parents]:
        if path.exists() and (path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400):
            raise RuntimeError("Reparse work path refused: " + str(path))
    run = work_root / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8])
    run.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "workstation_baseline_v1", "complete": False, "run": str(run),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "engine": str(engine), "engine_sha256": sha(engine), "native_dependencies": dependencies,
               "steps": [], "source_files": [], "player_save_acceptance": False}
    child = None
    acquired = False
    try:
        idle_since = None
        deadline = time.monotonic() + 1200
        print("WAIT natural engine idle for 60 seconds", flush=True)
        while idle_since is None or time.monotonic() - idle_since < 60:
            if time.monotonic() >= deadline:
                raise RuntimeError("Natural engine idle observation deadline reached")
            if engines() or LOCK.exists():
                idle_since = None
            elif idle_since is None:
                idle_since = time.monotonic()
            time.sleep(2)
        with LOCK.open("x", encoding="utf-8") as stream:
            stream.write(str(run))
        acquired = True
        if engines():
            raise RuntimeError("Engine started before local lease acquisition")
        names = sources() + ["tools/workstation_startup_probe.gd"]
        receipt["source_files"] = [{"path": name, "bytes": (ROOT / name).stat().st_size,
                                    "sha256": sha(ROOT / name)} for name in names]
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith("STEAM_") or key in {
                "LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO",
                "AUTOMICRO", "SMOKE_TEST", "SCREENSHOT_DIR", "GODOT_USER_HOME"}:
                env.pop(key)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = run / "profile" / key.lower()
            private.mkdir(parents=True)
            env[key] = str(private)
        env["LSH_WORKSTATION_OUTPUT"] = str(run)
        steps = [
            ("import", [str(engine), "--headless", "--path", str(ROOT), "--import"]),
            ("ordinary_startup", [str(engine), "--path", str(ROOT), "--headless", "--quit-after", "180"]),
            ("menu_viewport", [str(engine), "--path", str(ROOT), "--rendering-method", "gl_compatibility",
                              "--script", "res://tools/workstation_startup_probe.gd"]),
        ]
        for name, command in steps:
            if engines():
                raise RuntimeError("Foreign engine before " + name)
            log = run / (name + ".log")
            started = time.monotonic()
            print("RUN " + name + " " + str(run), flush=True)
            with log.open("wb") as stream:
                child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
                # Bind every completion and ownership check to the actual launched engine.
                while child.poll() is None:
                    if time.monotonic() - started > 900:
                        raise RuntimeError(name + " timeout")
                    foreign = foreign_engines(child.pid)
                    if foreign:
                        receipt["foreign_engine_pids"] = foreign
                        raise RuntimeError("Shared engine resumed during " + name)
                    time.sleep(2)
                code = child.returncode
            text = log.read_text(encoding="utf-8", errors="replace")
            receipt["steps"].append({"name": name, "command": command, "pid": child.pid, "exit_code": code,
                                     "process_terminal": True, "seconds": round(time.monotonic() - started, 2),
                                     "log_sha256": sha(log), "engine_errors": len(ERRORS.findall(text))})
            if code != 0 or ERRORS.search(text):
                raise RuntimeError(name + " failed; inspect " + str(log))
        report = json.loads((run / "startup_report.json").read_text(encoding="utf-8"))
        if not report.get("passed") or not Path(report["user_directory"]).is_relative_to(run / "profile"):
            raise RuntimeError("Menu probe or private user directory validation failed")
        drift = [row["path"] for row in receipt["source_files"] if sha(ROOT / row["path"]) != row["sha256"]]
        receipt["source_drift"] = drift
        if drift:
            raise RuntimeError("Source changed during local baseline: " + repr(drift))
        receipt["generated_runtime_sidecars"] = sorted(set(sources()) - set(names))
        if native_dependencies() != dependencies or sha(engine) != receipt["engine_sha256"]:
            raise RuntimeError("Engine/native dependency changed")
        receipt["startup_report"] = report
        receipt["menu_sha256"] = sha(run / "menu.png")
        receipt["complete"] = True
    except BaseException as error:
        receipt["failure"] = repr(error)
        raise
    finally:
        if child is not None and child.poll() is None:
            subprocess.run(["taskkill.exe", "/PID", str(child.pid), "/T", "/F"], capture_output=True)
            child.wait(timeout=30)
        if acquired and LOCK.read_text(encoding="utf-8") == str(run):
            LOCK.unlink()
            receipt["lock_released"] = True
        (run / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "run": str(run), "failure": receipt.get("failure")}), flush=True)


if __name__ == "__main__":
    main()
