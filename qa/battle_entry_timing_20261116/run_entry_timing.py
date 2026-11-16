"""Measure rendered menu transitions with a fresh profile per mode."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ENTRY_TAG = "ENTRY_TIMING "
MODES = ("level3", "skirmish", "skirmish_ai", "arena")


def engine_idle():
    powershell = (
        "Get-Process -Name 'Godot*','LiangshanHeroes' -ErrorAction SilentlyContinue"
        " | Select-Object -ExpandProperty ProcessName; exit 0"
    )
    result = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", powershell], text=True)
    return not any(name.startswith("godot") or name == "liangshanheroes" for name in result.lower().split())


def measure(godot, project, mode, folder):
    folder.mkdir()
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("LSH_", "LT_")) and
           key not in {"LEVEL", "SKIRMISH", "SKIRMISH_AI", "ARENA", "SMOKE_TEST", "CAMPAIGN_QA",
                       "SCREENSHOT_DIR", "PROF", "PERF_BENCH", "INFO_UI_TEST_DIR", "INFO_UI_TEST"}}
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME"):
        location = folder / key.lower()
        location.mkdir()
        env[key] = str(location)
    env.update(STEAM_DISABLED="1", LSH_LANGUAGE="zh_CN", LSH_ENTRY_MODE=mode)
    log = folder / "game.log"
    command = [
        str(godot), "--path", str(project), "--rendering-method", "gl_compatibility",
        "--resolution", "1280x720", "--position", "30000,30000",
        "--script", str(Path(__file__).with_name("entry_timing.gd")),
    ]
    with log.open("wb") as file:
        run = subprocess.run(command, env=env, stdout=file, stderr=subprocess.STDOUT, timeout=90)
    lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    results = [json.loads(line[len(ENTRY_TAG):]) for line in lines if line.startswith(ENTRY_TAG)]
    errors = [line for line in lines if re.match(r"^(SCRIPT )?ERROR:|^ENTRY_TIMING_ERROR", line)]
    if run.returncode or errors or len(results) != 1:
        raise RuntimeError(f"{mode} failed (exit {run.returncode}): {errors}. See {log}")
    result = results[0]
    if result["mode"] != mode or [sample["visit"] for sample in result["samples"]] != [1, 2]:
        raise RuntimeError(f"missing fresh or repeated entry: {log}")
    return result


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--godot", type=Path, required=True)
    cli.add_argument("--project", type=Path, required=True)
    cli.add_argument("--lock", type=Path, required=True)
    cli.add_argument("--output", type=Path, required=True)
    cli.add_argument("--modes", nargs="+", choices=MODES, default=MODES)
    args = cli.parse_args()
    godot, project, lock, output = (item.resolve() for item in (args.godot, args.project, args.lock, args.output))
    if not godot.is_file() or not (project / "project.godot").is_file():
        cli.error("Godot executable and source project are required")
    if output.exists() or len(set(args.modes)) != len(args.modes):
        cli.error("use a fresh output directory and distinct modes")
    commit = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
    with lock.open("x", encoding="utf-8") as claim:
        claim.write(str(output))
    try:
        if not engine_idle():
            raise RuntimeError("another game/engine process is active")
        output.mkdir()
        results = []
        with godot.open("rb") as executable:
            engine_identity = hashlib.file_digest(executable, "sha256").hexdigest()
        batch = {
            "commit": commit, "renderer": "gl_compatibility", "resolution": [1280, 720],
            "engine_sha256": engine_identity,
            "modes": results,
        }
        for mode in args.modes:
            if not engine_idle():
                raise RuntimeError("engine was started by another task between samples")
            results.append(measure(godot, project, mode, output / mode))
            (output / "measurements.json").write_text(json.dumps(batch, indent=2) + "\n", encoding="utf-8")
    finally:
        if lock.read_text(encoding="utf-8") == str(output):
            lock.unlink()


if __name__ == "__main__":
    main()
