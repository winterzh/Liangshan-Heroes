#!/usr/bin/env python3
"""Serial desktop render diagnostics from a passed, frozen RTS snapshot.

No Android-device or visual-acceptance claim. Reuses only the receipt's private
LSH-rts profile; output must be new and outside source, snapshot and profile.
"""
from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ["static_scenery_batch_qa.gd", "android_opening_render_qa.gd"]
DISABLED = {"STEAM_DISABLED": "1", "CAMPAIGN_QA": "1", "CONTENT_UPDATE_NO_AUTO": "1"}

def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def outside(path: Path, parent: Path) -> bool:
    return path != parent and parent not in path.parents

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", required=True, type=Path, help="RTS output directory or source-receipt.json")
    parser.add_argument("--godot", required=True)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    snapshot = args.snapshot.expanduser().resolve()
    receipt_path = snapshot / "source-receipt.json" if snapshot.is_dir() else snapshot
    require(receipt_path.name == "source-receipt.json", "Expected source-receipt.json")
    receipt_sha = sha(receipt_path)
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    require(receipt.get("passed") is True, "RTS snapshot must have completed and passed")
    project = Path(receipt["project"]).resolve()
    profile = Path(receipt["profile_directory"]).resolve()
    name = receipt["profile"]
    require(Path(receipt["source_root"]).resolve() == ROOT, "Receipt belongs to a different source ROOT")
    require(project == receipt_path.parent / "project" and outside(project, ROOT), "Project is not an external frozen snapshot")
    require(not (project / ".git").exists(), "Refusing a Git checkout")
    require(re.fullmatch(r"LSH-rts-[A-Za-z0-9_-]+", name) is not None, "Invalid private profile name")
    base = Path.home() / "Library/Application Support" if sys.platform == "darwin" else (
        Path(os.environ["APPDATA"]) if sys.platform == "win32" else Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))))
    require(profile == (base / name).resolve() and outside(profile, ROOT) and outside(profile, project), "Profile isolation mismatch")
    config = configparser.ConfigParser(interpolation=None)
    require(config.read(project / "override.cfg", encoding="utf-8") != [], "Missing private override.cfg")
    expected = {"config/name": json.dumps(name), "config/use_custom_user_dir": "true", "config/custom_user_dir_name": json.dumps(name)}
    require(config.sections() == ["application"] and dict(config["application"]) == expected, "Private profile override mismatch")
    override_sha = sha(project / "override.cfg")
    records = receipt["files"]
    paths = [row["path"] for row in records]
    require(records and len(paths) == len(set(paths)), "Empty or duplicate frozen source records")
    for row in records:
        relative = Path(row["path"])
        require(not relative.is_absolute() and ".." not in relative.parts and "\\" not in row["path"], "Unsafe source record")
        require(re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is not None, "Invalid frozen SHA256")
    require(all("tools/" + name in paths for name in SCRIPTS), "Render scripts were not frozen in receipt")
    out = args.out.expanduser().resolve()
    require(not out.exists() and all(outside(out, p) for p in [ROOT, receipt_path.parent, profile]), "--out must be a new external directory")
    executable = shutil.which(args.godot)
    require(executable is not None, "Godot executable not found")
    executable = str(Path(executable).resolve())
    out.mkdir(parents=True)

    def drift() -> list[str]:
        changed = []
        for prefix, base_dir in [("snapshot", project), ("source", ROOT)]:
            for row in records:
                path = base_dir / row["path"]
                if not path.is_file() or path.is_symlink() or outside(path.resolve(), base_dir) or sha(path) != row["sha256"]:
                    changed.append(prefix + ":" + row["path"])
        if sha(receipt_path) != receipt_sha:
            changed.append("source-receipt.json")
        if sha(project / "override.cfg") != override_sha:
            changed.append("snapshot:override.cfg")
        return changed

    report = {"passed": False, "native_android": False, "visual_approved": False,
              "scope": "Desktop synthetic/real-scene execution and capture only; pixel acceptance requires review",
              "snapshot": str(receipt_path), "snapshot_sha256": receipt_sha, "project": str(project), "profile": str(profile),
              "source_records": len(records), "isolation": DISABLED, "start_drift": drift(), "runs": []}
    jobs = [("static_scenery_batch", SCRIPTS[0], "1", "3000x1876", "static-scenery-batch-result.json", 12)]
    jobs += [(mode + "_" + size, SCRIPTS[1], flag, size, "opening-render.json", 3)
             for size in ["3000x1876", "3840x2560"] for mode, flag in [("baseline", "0"), ("optimized", "1")]]
    blocked = {"SMOKE_TEST", "ARENA", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH_AI", "SKIRMISH", "LEVEL"}
    env = {key: value for key, value in os.environ.items() if not key.startswith("LSH_") and key not in blocked}
    env.update(DISABLED, LSH_RTS_QA_PROJECT=str(project), LSH_RTS_QA_PROFILE=str(profile), LSH_LANGUAGE="zh_CN", TOUCH_UI="1")
    for label, script, flag, size, result_name, png_count in ([] if report["start_drift"] else jobs):
        task_out = out / label
        task_out.mkdir()
        env.update(LSH_RTS_QA_OUT=str(task_out), LSH_STATIC_SCENERY_BATCH=flag, LSH_ANDROID_RENDER_SIZE=size)
        command = [executable, "--path", str(project), "--rendering-method", "gl_compatibility", "--position", "20000,20000", "--script", "res://tools/" + script]
        row = {"label": label, "command": command, "mode": flag, "size": size, "timeout_seconds": 180, "returncode": None, "passed": False}
        started = time.monotonic()
        try:
            with (task_out / "stdout.log").open("wb") as stream:
                result = subprocess.run(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
            row["returncode"] = result.returncode
            text = (task_out / "stdout.log").read_text(encoding="utf-8", errors="replace")
            row["error_log"] = bool(re.search(r"\b(?:SCRIPT ERROR|Parse Error|ERROR)\b", text))
            payload = json.loads((task_out / result_name).read_text(encoding="utf-8"))
            row["report"] = {"path": result_name, "sha256": sha(task_out / result_name), "passed": payload.get("passed")}
            row["passed"] = result.returncode == 0 and not row["error_log"] and payload.get("passed") is True and not payload.get("failures")
        except (OSError, ValueError, subprocess.TimeoutExpired) as error:
            row["error"] = str(error)
        row["pngs"] = [{"path": p.name, "sha256": sha(p), "bytes": p.stat().st_size} for p in sorted(task_out.glob("*.png"))]
        row["passed"] = row["passed"] and len(row["pngs"]) == png_count
        row.update(seconds=round(time.monotonic() - started, 3), log=str(task_out / "stdout.log"))
        report["runs"].append(row)
        (out / "render-receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(row, ensure_ascii=False), flush=True)
    report["end_drift"] = drift()
    report["passed"] = not report["start_drift"] and not report["end_drift"] and len(report["runs"]) == 5 and all(row["passed"] for row in report["runs"])
    (out / "render-receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, configparser.Error) as error:
        print("Render QA refused: " + str(error), file=sys.stderr)
        sys.exit(2)
