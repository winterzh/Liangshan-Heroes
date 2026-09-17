"""Freeze Git baseline plus an explicit recovery overlay and run isolated native QA.

The default is a read-only preflight. --run creates a fresh D-drive project,
imports once, then runs the recovery GUI/live harness under the shared engine
lock. Other tasks' working-tree production edits are never baseline inputs.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import time
import uuid


ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
RUNTIME_DIRS = {"scripts", "scenes", "assets", "content", "scenarios", "fonts", "shaders"}
ROOT_FILES = {"project.godot", "export_presets.cfg", "icon.ico", "icon.png", "icon.png.import"}
DEPENDENCIES = {
    "tools/zhujiazhuang_feedback_qa.gd",
    "tools/zhujiazhuang_rts_test.gd",
}
DEFAULT_OVERLAY = (
    "scripts/levels/level3_zhujiazhuang_rts.gd",
    "scripts/zhujiazhuang_recovery_hint.gd",
    "assets/localization/zhujiazhuang_recovery.json",
    "assets/localization/catalog.json",
    "tools/zhujiazhuang_recovery_qa.gd",
    "tools/run_zhujiazhuang_recovery_qa.py",
)
ALLOWED_OVERLAY = set(DEFAULT_OVERLAY) | {
    "scripts/zhujiazhuang_recovery_hint.gd.uid",
    "tools/zhujiazhuang_recovery_qa.gd.uid",
}
QA_SCRIPT = "tools/zhujiazhuang_recovery_qa.gd"
QA_OUTPUT = ".godot/zhujiazhuang_recovery_qa"
BOOTSTRAP = "tools/_zhujiazhuang_recovery_runner.gd"
ERROR_LINE = re.compile(r"^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)", re.I)
WARNING_LINE = re.compile(r"^\s*WARNING:", re.I)


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def no_links(path):
    """Check lexical ancestors before resolving, including Windows junctions."""
    for item in (path, *path.parents):
        if item.exists() or item.is_symlink():
            if item.is_symlink() or getattr(item.lstat(), "st_file_attributes", 0) & 0x400:
                raise RuntimeError("Link/reparse path refused: " + str(item))
    return path


def work_directory(raw):
    path = Path(raw)
    if not path.is_absolute() or path.drive.casefold() != "d:":
        raise ValueError("--work-root must be an absolute path on D:")
    no_links(path)
    path = path.resolve()
    if path == ROOT or ROOT in path.parents:
        raise ValueError("--work-root must be outside the development checkout")
    if path.exists() and not path.is_dir():
        raise ValueError("--work-root is not a directory")
    return path


def resolve_godot(raw):
    value = raw or os.environ.get("GODOT_PATH")
    if not value:
        value = (ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip()
    engine = Path(value)
    if engine.name.lower().endswith("_console.exe"):
        engine = engine.with_name(engine.name[:-12] + ".exe")
    no_links(engine)
    if not engine.is_absolute() or not engine.is_file():
        raise ValueError("An existing absolute Godot executable path is required")
    return engine.resolve()


def engine_pids():
    command = (
        "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { "
        "$_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*' "
        "} | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    )
    output = subprocess.check_output(
        ["powershell.exe", "-NoProfile", "-Command", command],
        text=True, timeout=20,
    ).strip()
    value = json.loads(output) if output else []
    return value if isinstance(value, list) else [value]


def baseline_tree(base):
    rows = {}
    for raw in git("ls-tree", "-rz", "--full-tree", base).split(b"\0"):
        if not raw:
            continue
        info, name_bytes = raw.split(b"\t", 1)
        mode, kind, oid = info.decode("ascii").split()
        name = name_bytes.decode("utf-8")
        selected = (name in ROOT_FILES or name.split("/")[0] in RUNTIME_DIRS
                    or name in DEPENDENCIES or name.removesuffix(".uid") in DEPENDENCIES)
        if not selected:
            continue
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name:
            raise RuntimeError("Unsafe Git source path: " + name)
        if kind != "blob" or mode not in {"100644", "100755"}:
            raise RuntimeError("Baseline source must be a regular Git blob: " + name)
        rows[name] = {"path": name, "git_oid": oid, "git_mode": mode}
    for name in DEPENDENCIES | {"project.godot", "scripts/battle.gd"}:
        if name not in rows:
            raise RuntimeError("Required committed baseline dependency missing: " + name)
    return rows


def overlays(names):
    if len(names) != len(set(names)) or any(name not in ALLOWED_OVERLAY for name in names):
        raise ValueError("--overlay accepts only unique, explicit recovery-owned paths")
    if not set(DEFAULT_OVERLAY).issubset(names):
        raise ValueError("--overlay must include all six recovery-owned files")
    result = []
    for name in sorted(names):
        source = no_links(ROOT / name)
        if not source.is_file():
            raise FileNotFoundError("Recovery overlay is not ready: " + name)
        result.append({"path": name, "bytes": source.stat().st_size, "sha256": sha(source)})
    return result


def freeze_baseline(project, tree, overlay_names):
    """Read immutable Git blobs without Git checkout filters or worktree copies."""
    rows = []
    process = subprocess.Popen(
        ["git", "cat-file", "--batch"], cwd=ROOT,
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    try:
        for name, entry in sorted(tree.items()):
            if name in overlay_names:
                continue
            process.stdin.write((entry["git_oid"] + "\n").encode("ascii"))
            process.stdin.flush()
            header = process.stdout.readline().decode("ascii").strip().split()
            if len(header) != 3 or header[0] != entry["git_oid"] or header[1] != "blob":
                raise RuntimeError("Git could not supply committed source: " + name)
            size = remaining = int(header[2])
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            digest = hashlib.sha256()
            with target.open("xb") as output:
                while remaining:
                    chunk = process.stdout.read(min(remaining, 1024 * 1024))
                    if not chunk:
                        raise RuntimeError("Incomplete Git blob: " + name)
                    output.write(chunk)
                    digest.update(chunk)
                    remaining -= len(chunk)
            if process.stdout.read(1) != b"\n":
                raise RuntimeError("Invalid Git blob boundary: " + name)
            rows.append(entry | {"origin": "git_baseline", "bytes": size,
                                 "sha256": digest.hexdigest()})
        process.stdin.close()
        stderr = process.stderr.read().decode("utf-8", errors="replace")
        if process.wait(timeout=30) != 0:
            raise RuntimeError("Git baseline extraction failed: " + stderr)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=10)
        for pipe in (process.stdin, process.stdout, process.stderr):
            if pipe is not None and not pipe.closed:
                pipe.close()
    return rows


def changed_files(base, rows):
    return [row["path"] for row in rows if not (base / row["path"]).is_file()
            or sha(base / row["path"]) != row["sha256"]]


def private_environment(profile, evidence, seed):
    no_links(profile)
    profile.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    prefixes = ("LSH_", "RTS_", "KH_", "HNS_", "HNA_", "DAMING_", "MENGZHOU_",
                "SIEGE_", "ART_", "LC_", "SJ_", "SL_", "DIRECTION4_", "ZHU_",
                "DEF_", "STEAM_QA_", "CAMPAIGN_QA_", "PLAYTEST_", "CODEX_QA_")
    exact = {"LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI",
             "ARENA", "AUTO_MICRO", "AUTOMICRO", "AI_FRIENDLY", "AI_DIFF",
             "VICTORY", "SCALE_ON", "ENEMY_MULT", "HERO_MULT", "SCALE_LOCKED"}
    for key in list(env):
        if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith(prefixes) or key in exact:
            env.pop(key)
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        directory = profile / key.lower()
        directory.mkdir(exist_ok=False)
        env[key] = str(directory)
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_LANGUAGE="zh_CN",
               ZHU_RECOVERY_OUT="res://" + QA_OUTPUT, ZHU_FEEDBACK_OUT="res://" + QA_OUTPUT,
               ZHU_RECOVERY_PROFILE=str(profile), ZHU_RECOVERY_SEED=str(seed),
               ZHU_RECOVERY_SOURCE_MANIFEST=str(evidence / "source_manifest.json"))
    return env


def bootstrap_source():
    return '''extends "res://tools/zhujiazhuang_recovery_qa.gd"
func _initialize() -> void:
\troot.unfocusable = true
\troot.position = Vector2i(20000, 20000)
\troot.size = Vector2i(1280, 720)
\troot.content_scale_size = Vector2i(1280, 720)
\tDirAccess.make_dir_recursive_absolute("res://.godot/zhujiazhuang_recovery_qa")
\tvar f := FileAccess.open("res://.godot/zhujiazhuang_recovery_qa/runner_window.json", FileAccess.WRITE)
\tif f == null:
\t\tpush_error("Could not write native recovery window receipt")
\t\tquit(1)
\t\treturn
\tf.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "unfocusable": root.unfocusable,
\t\t"size": [root.size.x, root.size.y], "position": [root.position.x, root.position.y],
\t\t"profile": OS.get_environment("ZHU_RECOVERY_PROFILE"), "user_dir": OS.get_user_data_dir(),
\t\t"engine": Engine.get_version_info(), "executable": OS.get_executable_path()}, "\\t"))
\tf.close()
\tsuper._initialize()
'''


def process_step(engine, project, env, evidence, label, arguments, timeout, receipt):
    if engine_pids():
        raise RuntimeError("Godot/game slot became occupied before " + label)
    log_path = evidence / (label + ".log")
    command = [str(engine), "--path", str(project), "--rendering-method", "gl_compatibility", *arguments]
    row = {"case": label, "command": command, "timeout_seconds": timeout,
           "started_utc": datetime.now(timezone.utc).isoformat(), "passed": False}
    started = time.monotonic()
    child = None
    stopped_for = None
    print("RUN " + label, flush=True)
    try:
        with log_path.open("xb") as log:
            child = subprocess.Popen(command, cwd=project, env=env, stdout=log,
                                     stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            row["pid"] = child.pid
            last_update = started
            while child.poll() is None:
                time.sleep(0.5)
                output = log_path.read_text(encoding="utf-8", errors="replace")
                if any(ERROR_LINE.match(line) for line in output.splitlines()):
                    stopped_for = "script_or_engine_error"
                    break
                if time.monotonic() - started >= timeout - 5:
                    stopped_for = "wall_clock_timeout"
                    break
                if time.monotonic() - last_update >= 25:
                    print("RUNNING " + label + " " + str(round(time.monotonic() - started)) + "s", flush=True)
                    last_update = time.monotonic()
    finally:
        if child is not None and child.poll() is None:
            # Only this private child is ours to stop. Leave unrelated engines alone.
            child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=2)
        output = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        row.update(exit_code=child.returncode if child is not None else None,
                   seconds=round(time.monotonic() - started, 3), stopped_for=stopped_for,
                   errors=[line for line in output.splitlines() if ERROR_LINE.match(line)],
                   warnings=[line for line in output.splitlines() if WARNING_LINE.match(line)],
                   log_sha256=sha(log_path) if log_path.exists() else None)
        row["passed"] = row["exit_code"] == 0 and not row["errors"] and stopped_for is None
        receipt["steps"].append(row)
        print("DONE " + label + " " + str(row["passed"]), flush=True)
    if not row["passed"]:
        raise RuntimeError("Private Godot step failed: " + label)


def verify_results(project, profile, min_png):
    output = project / QA_OUTPUT
    report_path = output / "report.json"
    report = json.loads(report_path.read_text(encoding="utf-8-sig"))
    if report.get("passed") is not True or report.get("failures") != [] or not isinstance(report.get("checks"), int) or report["checks"] <= 0:
        raise RuntimeError("Recovery report did not pass its actual assertions")
    window = json.loads((output / "runner_window.json").read_text(encoding="utf-8"))
    if window.get("renderer") == "headless" or window.get("unfocusable") is not True or window.get("size") != [1280, 720] or window.get("position") != [20000, 20000]:
        raise RuntimeError("Actual native window differs from isolated 1280x720 configuration")
    if window.get("profile") != str(profile) or not Path(window.get("user_dir", "")).resolve().is_relative_to(profile.resolve()):
        raise RuntimeError("Native user directory escaped the private profile")
    pngs = []
    for image in sorted(output.rglob("*.png")):
        no_links(image)
        with image.open("rb") as file:
            header = file.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
            raise RuntimeError("Invalid screenshot file: " + str(image))
        width, height = struct.unpack(">II", header[16:24])
        if (width, height) != (1280, 720):
            raise RuntimeError("Screenshot is not 1280x720: " + str(image))
        pngs.append({"path": image.relative_to(output).as_posix(), "bytes": image.stat().st_size,
                     "sha256": sha(image), "width": width, "height": height})
    if len(pngs) < min_png:
        raise RuntimeError("Missing native screenshot evidence")
    return {"checks": report["checks"], "report_sha256": sha(report_path), "window": window,
            "screenshots": pngs, "visual_inspection": "pending; image files are not human visual approval"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--base", default="HEAD", help="Committed Git baseline, resolved once to its SHA")
    parser.add_argument("--overlay", nargs="+", default=list(DEFAULT_OVERLAY), choices=sorted(ALLOWED_OVERLAY))
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/zhujiazhuang_recovery"))
    parser.add_argument("--godot")
    parser.add_argument("--timeout", type=int, default=600, help="Native wall-clock budget, including stop grace (30-600s)")
    parser.add_argument("--import-timeout", type=int, default=600, help="Import wall-clock budget (30-600s)")
    parser.add_argument("--seed", type=int, default=5088120)
    parser.add_argument("--min-png", type=int, default=1)
    args = parser.parse_args()
    if not 30 <= args.timeout <= 600 or not 30 <= args.import_timeout <= 600 or args.min_png < 1:
        parser.error("Timeouts must be 30-600 seconds and --min-png must be positive")
    engine = resolve_godot(args.godot)
    work_root = work_directory(args.work_root)
    base = git("rev-parse", "--verify", args.base + "^{commit}").decode("ascii").strip()
    tree = baseline_tree(base)
    overlay = overlays(args.overlay)
    preflight = {"preflight": True, "baseline": base, "baseline_files": len(tree),
                 "overlay": overlay, "work_root": str(work_root), "godot": str(engine),
                 "lock_busy": LOCK.exists(), "engine_pids": engine_pids(), "fresh_import": True,
                 "excluded_worktree_production": "All paths outside the explicit overlay use committed Git blobs, including scripts/battle.gd"}
    if not args.run:
        print(json.dumps(preflight, ensure_ascii=False))
        return 0
    if preflight["lock_busy"] or preflight["engine_pids"]:
        raise RuntimeError("Shared Godot/game engine slot is occupied")
    tag = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / tag
    project = run / "project"
    evidence = ROOT / "qa/zhujiazhuang_recovery_20260915" / tag
    receipt = {"schema": "zhujiazhuang_recovery_runner_v1", "complete": False,
               "source_root": str(ROOT), "baseline": base, "run": str(run), "project": str(project),
               "fresh_import": True, "renderer": "gl_compatibility", "seed": args.seed,
               "godot_sha256": sha(engine), "overlay": overlay, "source_files": [], "steps": [],
               "profiles": {}, "scope": "Ordinary-loss recovery UI and real production/movement QA; not full campaign, balance, or human fun acceptance"}
    locked = False
    failure = None
    try:
        no_links(LOCK.parent)
        LOCK.parent.mkdir(exist_ok=True)
        with LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True
        if engine_pids():
            raise RuntimeError("Engine appeared during shared lock acquisition")
        no_links(project)
        project.mkdir(parents=True, exist_ok=False)
        no_links(evidence)
        evidence.mkdir(parents=True, exist_ok=False)
        receipt["source_files"] = freeze_baseline(project, tree, set(args.overlay))
        for row in overlay:
            source = no_links(ROOT / row["path"])
            content = source.read_bytes()
            if hashlib.sha256(content).hexdigest() != row["sha256"]:
                raise RuntimeError("Overlay changed while freezing: " + row["path"])
            target = project / row["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            receipt["source_files"].append(row | {"origin": "explicit_overlay", "git_oid": tree.get(row["path"], {}).get("git_oid")})
        receipt["source_files"].sort(key=lambda row: row["path"])
        baseline_battle = next(row for row in receipt["source_files"] if row["path"] == "scripts/battle.gd")
        receipt["battle_baseline_proof"] = baseline_battle | {"worktree_sha256_at_freeze": sha(ROOT / "scripts/battle.gd")}
        wrapper = project / BOOTSTRAP
        wrapper.write_text(bootstrap_source(), encoding="utf-8", newline="\n")
        receipt["bootstrap"] = {"path": BOOTSTRAP, "sha256": sha(wrapper)}
        write_json(evidence / "source_manifest.json", {"baseline": base, "sources": receipt["source_files"], "bootstrap": receipt["bootstrap"]})
        for row in overlay:
            snapshot = evidence / "overlay" / row["path"]
            snapshot.parent.mkdir(parents=True, exist_ok=True)
            snapshot.write_bytes((project / row["path"]).read_bytes())
        if changed_files(ROOT, overlay):
            raise RuntimeError("Overlay changed before import")
        for label, arguments, budget in (
            ("import", ["--headless", "--editor", "--import", "--quit"], args.import_timeout),
            ("parse", ["--headless", "--script", "res://" + QA_SCRIPT, "--check-only"], 30),
            ("native", ["--position", "20000,20000", "--resolution", "1280x720", "--script", "res://" + BOOTSTRAP], args.timeout),
        ):
            profile = run / "profiles" / label
            env = private_environment(profile, evidence, args.seed)
            receipt["profiles"][label] = str(profile)
            process_step(engine, project, env, evidence, label, arguments, budget, receipt)
            if changed_files(project, receipt["source_files"]):
                raise RuntimeError("Godot changed frozen source/import descriptors")
            if label == "import":
                known = {row["path"] for row in receipt["source_files"]}
                receipt["generated_script_uids"] = [{"path": path.relative_to(project).as_posix(), "sha256": sha(path)}
                    for path in sorted(project.rglob("*.gd.uid")) if path.relative_to(project).as_posix() not in known]
        receipt["result"] = verify_results(project, run / "profiles/native", args.min_png)
        receipt["complete"] = True
    except BaseException as exc:
        failure = exc
        receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        receipt["overlay_changes"] = changed_files(ROOT, overlay)
        receipt["private_source_changes"] = changed_files(project, receipt["source_files"])
        receipt["godot_unchanged"] = engine.is_file() and sha(engine) == receipt["godot_sha256"]
        if evidence.exists():
            output = project / QA_OUTPUT
            if output.is_dir():
                for source in sorted(output.rglob("*")):
                    if source.is_file() and source.suffix.lower() in {".json", ".png"}:
                        no_links(source)
                        target = evidence / "results" / source.relative_to(output)
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(source.read_bytes())
            receipt["artifacts"] = [{"path": path.relative_to(evidence).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)}
                                    for path in sorted(evidence.rglob("*")) if path.is_file() and path.name != "receipt.json"]
        remaining = engine_pids()
        receipt["engines_remaining"] = remaining
        if locked and LOCK.exists() and LOCK.read_text(encoding="utf-8") == str(run) and not remaining:
            LOCK.unlink()
        receipt["lock_released"] = not LOCK.exists()
        receipt["complete"] = bool(receipt["complete"] and not receipt["overlay_changes"] and not receipt["private_source_changes"]
                                   and receipt["godot_unchanged"] and receipt["lock_released"] and not remaining)
        if evidence.exists():
            write_json(evidence / "receipt.json", receipt)
        print(json.dumps({"complete": receipt["complete"], "evidence": str(evidence), "failure": receipt.get("failure")}, ensure_ascii=False), flush=True)
    return 0 if failure is None and receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
