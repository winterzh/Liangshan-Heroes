"""Run the mission panel candidate in a private project under the shared Godot lock."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

sys.dont_write_bytecode = True
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--project-root", type=Path, required=True)
parser.add_argument("--run", action="store_true")
args = parser.parse_args()
root = args.project_root.resolve()
candidate = Path(__file__).resolve().parent
sys.path.insert(0, str(root / "tools"))
import run_stabilization_performance as guard

head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
rows = guard.tree(head)
sources = {row["path"]: guard.sha((root / row["path"]).read_bytes()) for row in rows}
overlays = [p for folder in ("scripts", "tools") for p in (candidate / folder).glob("*.gd")]
driver = candidate / "campaign_objective_toggle_test.gd"
guard.need(driver.is_file(), "Missing toggle driver")
lock = root / ".godot/redraw_rejection_source.lock"
info = {"head": head, "production_files": len(rows), "overlays": [p.relative_to(candidate).as_posix() for p in overlays],
        "lock_busy": lock.exists(), "godot_pids": guard.godot_processes()}
print(json.dumps(info, ensure_ascii=False), flush=True)
if not args.run:
    raise SystemExit(0)
guard.need(not info["lock_busy"] and not info["godot_pids"], "Shared Godot slot unavailable")
run_id = "mission_toggle_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:6]
run = root / ".godot" / run_id
project = run / "project"
profile = Path("D:/LHUiProfiles") / run_id
for path in (run, profile, candidate, lock):
    guard.no_links(path)
owner = json.dumps({"owner": "mission_toggle_qa", "pid": os.getpid(), "run_id": run_id})
receipt = dict(info, run_id=run_id, complete=False, steps=[])
owned = False
player_before = None
try:
    with lock.open("x", encoding="utf-8") as stream:
        stream.write(owner)
        owned = True
    project.mkdir(parents=True)
    for row in rows:
        destination = project / row["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        raw = (root / row["path"]).read_bytes()
        guard.need(guard.sha(raw) == sources[row["path"]], "Source changed while copying")
        destination.write_bytes(raw)
    # Preserve existing test dependencies and their UIDs, then replace only adapted fixtures.
    for source in (root / "tools").glob("*.gd*"):
        destination = project / "tools" / source.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source.read_bytes())
    for source in overlays:
        (project / source.relative_to(candidate)).write_bytes(source.read_bytes())
    (project / "tools" / driver.name).write_bytes(driver.read_bytes())
    receipt["candidate_sha256"] = {p.relative_to(candidate).as_posix(): guard.sha(p.read_bytes()) for p in overlays + [driver]}
    receipt["production_sha256"] = sources
    config = (project / "project.godot").read_text(encoding="utf-8")
    name = json.loads(re.findall(r'^config/name=("[^\n]+")\s*$', config, re.M)[0])
    player = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / name
    player_before = guard.snapshot(player)
    env = os.environ.copy()
    switches = set()
    for source in (project / "scripts").rglob("*.gd"):
        switches.update(re.findall(r'OS\.(?:get_environment|has_environment)\(\s*["\']([A-Z0-9_]+)["\']', source.read_text(encoding="utf-8-sig")))
    for key in switches:
        env.pop(key, None)
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        directory = profile / key.lower()
        directory.mkdir(parents=True, exist_ok=False)
        env[key] = str(directory)
    env.update(CAMPAIGN_QA="1", STEAM_DISABLED="1", CAMPAIGN_TOGGLE_OUT=str(run / "toggle"), CAMPAIGN_UI_VISUAL_OUT=str(run / "freeplay"))
    receipt["private_user"] = str(profile / "appdata/Godot/app_userdata" / name)
    cache = root / ".godot/imported"
    if cache.exists():
        shutil.copytree(cache, project / ".godot/imported")
    exe = Path((root / "godot.local.txt").read_text(encoding="utf-8-sig").strip())
    receipt["engine_sha256"] = guard.sha(exe.read_bytes())
    checks = [
        ("import", ["--headless", "--editor", "--import"], 180),
        ("toggle", ["--script", "res://tools/" + driver.name], 180),
        ("freeplay_core", ["--headless", "--script", "res://tools/campaign_freeplay_core_test.gd"], 180),
        ("freeplay_visual", ["--script", "res://tools/campaign_freeplay_ui_visual_test.gd"], 180),
    ]
    for label, extra, timeout in checks:
        guard.need(not guard.godot_processes(), "Godot slot occupied before " + label)
        command = [str(exe), "--path", str(project)] + extra
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        with (run / (label + ".log")).open("xb") as stream:
            result = subprocess.run(command, cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW, startupinfo=startup)
        log = (run / (label + ".log")).read_text(encoding="utf-8", errors="strict")
        errors = [line for line in log.splitlines() if guard.ERROR.search(line)]
        receipt["steps"].append({"name": label, "command": command, "exit_code": result.returncode, "errors": errors})
        guard.save(run / "receipt.json", receipt)
        print(json.dumps(receipt["steps"][-1], ensure_ascii=False), flush=True)
        guard.need(result.returncode == 0 and not errors, label + " failed")
        guard.need(guard.snapshot(player) == player_before, "Player files changed")
        guard.need(all(guard.sha((root / p).read_bytes()) == digest for p, digest in sources.items()), "Production source changed")
    receipt["complete"] = True
except BaseException as exc:
    receipt["error"] = str(exc)
    raise
finally:
    if owned:
        receipt["player_unchanged"] = player_before is not None and guard.snapshot(player) == player_before
        receipt["source_unchanged"] = all(guard.sha((root / p).read_bytes()) == digest for p, digest in sources.items())
        receipt["godot_pids_after"] = guard.godot_processes()
        guard.need(not receipt["godot_pids_after"] and lock.read_text(encoding="utf-8") == owner, "Cannot release shared lock")
        lock.unlink()
        receipt["lock_released"] = True
        receipt["complete"] = receipt["complete"] and receipt["player_unchanged"] and receipt["source_unchanged"]
        guard.save(run / "receipt.json", receipt)
        print("RECEIPT " + str(run / "receipt.json"), flush=True)
