"""Private-profile behavior/render and real-input GUI QA; default is preflight only.

Use --run to launch serial Godot processes. No source swaps, player-save restores,
Git operations or performance claims. Legacy uses a private copied project.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
OUTPUT = ROOT / ".godot/reduced_effects_qa"
CONTRACT = "tools/contracts/reduced_effects"
BEHAVIOR = "tools/reduced_effects_qa.gd"
GUI = "tools/reduced_effects_ui_qa.gd"
HELPER = "tools/run_polish_performance.py"
DIRECTORIES = ("scripts", "scenes", "assets", "shaders", "resources", "data",
               "addons", "content", "scenarios", CONTRACT)
REQUIRED = {"scripts", "scenes", "assets", CONTRACT}
FIXED = ("project.godot", BEHAVIOR, GUI, HELPER, "tools/run_reduced_effects_qa.py")
SIZES = {"1440x900": [1440, 900], "1280x720": [1280, 720]}
ERROR = re.compile(r"SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b", re.M)
ACTIVE_PROCESS = None


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def save(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())


def no_link(path):
    value = path.lstat()
    need(not path.is_symlink() and not getattr(value, "st_file_attributes", 0) & 0x400,
         "Source/output link or reparse point requires review: " + str(path))


def contained(path, parent):
    return parent.resolve() in path.resolve().parents


def enumerate_sources(root):
    files, directories, presence = set(), set(), {}
    def scan_error(error):
        raise error
    for name in DIRECTORIES:
        top = root / name
        presence[name] = top.exists()
        need(top.exists() or name not in REQUIRED, "Required source directory missing: " + name)
        if not top.exists():
            continue
        no_link(top)
        need(top.is_dir(), "Invalid source directory: " + name)
        for parent, dirs, names in os.walk(top, onerror=scan_error, followlinks=False):
            for item in dirs + names:
                no_link(Path(parent) / item)
            directories.add(Path(parent).relative_to(root).as_posix())
            files.update((Path(parent) / item).relative_to(root).as_posix() for item in names)
    for name in FIXED:
        path = root / name
        need(path.is_file(), "Required source file missing: " + name)
        no_link(path)
        files.add(name)
        if path.suffix == ".gd":
            uid = root / (name + ".uid")
            if uid.exists():
                no_link(uid)
                need(uid.is_file(), "Script UID is not a regular file: " + str(uid))
                files.add(name + ".uid")
    for path in root.iterdir():
        if path.name.lower().startswith("icon."):
            no_link(path)
            if path.is_file():
                files.add(path.name)
    return sorted(files), sorted(directories), presence


def source_receipt(root=ROOT):
    paths, directories, presence = enumerate_sources(root)
    rows = {name: sha((root / name).read_bytes()) for name in paths}
    need(enumerate_sources(root) == (paths, directories, presence),
         "Source path set changed during hashing")
    return {"raw_file_sha256": rows, "directories": directories, "root_presence": presence,
            "hash_policy": "all exact raw bytes; hidden files included; links rejected",
            "combined_sha256": sha(json.dumps([rows, directories, presence], sort_keys=True).encode())}


def signatures(directory):
    result = {}
    for key, name in (("settings", "settings.cfg"), ("campaign", "campaign.cfg"), ("screen", "screen.cfg")):
        path = directory / name
        if path.exists():
            no_link(path)
            need(path.is_file(), "Preference path is not a regular file: " + str(path))
        result[key] = sha(path.read_bytes()) if path.is_file() else "absent"
    return result


def project_name(root=ROOT, legacy=False):
    text = (root / "project.godot").read_text(encoding="utf-8-sig")
    need("config/use_custom_user_dir" not in text and "config/custom_user_dir_name" not in text,
         "Custom user-directory settings require a separately reviewed mapping")
    names = re.findall(r'^config/name=("[^\n]+")\s*$', text, re.M)
    need(len(names) == 1, "Expected one project name")
    name = json.loads(names[0])
    need(name and not any(char in name for char in '<>:"/\\|?*') and name not in (".", ".."),
         "Project name requires unreviewed filename sanitization")
    settings = f'Settings="*res://{CONTRACT}/legacy_settings.gd"' if legacy else 'Settings="*res://scripts/settings.gd"'
    need(text.count(settings) == 1, "Settings Autoload mapping changed")
    need(text.count('AndroidUpdater="*res://scripts/android_updater.gd"') == 1,
         "Updater bootstrap mapping changed")
    return name


def contract():
    info = json.loads((ROOT / CONTRACT / "manifest.json").read_text(encoding="utf-8"))
    need(info.get("schema") == 1, "Unknown legacy contract schema")
    item = info["legacy_settings"]
    need(item["file"] == "settings_legacy.gd.txt", "Unexpected legacy fixture path")
    raw = (ROOT / CONTRACT / item["file"]).read_bytes()
    need(sha(raw) == item["raw_sha256"] and sha(raw.replace(b"\r\n", b"\n")) == item["lf_sha256"],
         "Frozen legacy Settings source changed")
    return info


def resolve_godot(value):
    value = value or os.environ.get("GODOT_PATH", "")
    local = ROOT / "godot.local.txt"
    if not value and local.is_file():
        value = local.read_text(encoding="utf-8-sig").strip()
    need(value and Path(value).is_file(), "Provide --godot, GODOT_PATH or ignored godot.local.txt")
    return str(Path(value).resolve())


def require_exclusive_godot():
    if ACTIVE_PROCESS is not None and ACTIVE_PROCESS.poll() is None:
        raise RuntimeError("Owned Godot child has not exited; retain shared lock")
    need(os.name == "nt", "Only the reviewed Windows private-profile mapping is implemented")
    command = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
                                  text=True, timeout=20).strip()
    need(not (json.loads(raw) if raw else []), "Godot is running; coordinate an exclusive slot")


def run_process(exe, project, log_path, env, timeout, script=None):
    """Own the exact child handle through every exception; never kill by name/PID."""
    global ACTIVE_PROCESS
    require_exclusive_godot()
    command = [exe, "--path", str(project)]
    command += (["--rendering-method", "forward_plus", "--rendering-driver", "vulkan", "--script", "res://" + script]
                if script else ["--headless", "--editor", "--import"])
    started = time.monotonic()
    process, failure, cleanup_error, code = None, None, None, None
    confirmed = False
    with log_path.open("xb") as log:
        try:
            process = subprocess.Popen(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT)
            ACTIVE_PROCESS = process
            code = process.wait(timeout=timeout)
        except BaseException as exc:
            failure = exc
            if process is not None:
                try:
                    if process.poll() is None:
                        process.kill()
                    code = process.wait(timeout=30)
                except BaseException as stop_error:
                    cleanup_error = type(stop_error).__name__ + ": " + str(stop_error)
        finally:
            if process is not None:
                try:
                    code = process.poll()
                    confirmed = code is not None
                    if confirmed:
                        ACTIVE_PROCESS = None
                except BaseException as poll_error:
                    cleanup_error = type(poll_error).__name__ + ": " + str(poll_error)
    errors = [line for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines() if ERROR.search(line)]
    receipt = {"command": command, "exit_code": code, "child_pid": process.pid if process else None,
               "child_started": process is not None, "child_exit_confirmed": confirmed,
               "timed_out": isinstance(failure, subprocess.TimeoutExpired),
               "exception": type(failure).__name__ + ": " + str(failure) if failure else None,
               "cleanup_error": cleanup_error, "matched_messages": errors,
               "wall_seconds": time.monotonic() - started, "console_log": log_path.name,
               "scope": "private-profile QA" if script else "private-project resource import only"}
    save(log_path.with_name(log_path.stem + "_process.json"), receipt)
    if failure is not None:
        raise failure
    need(confirmed and not cleanup_error, "Child exit not confirmed; retain lock and process evidence")
    require_exclusive_godot()
    need(code == 0 and not errors, "Godot diagnostics/exit rejected: " + str(log_path))
    return receipt


def read_report(path, stage, run_id, validity_key, manifest_sha):
    need(path.is_file(), "Missing new process report: " + str(path))
    report = json.loads(path.read_text(encoding="utf-8-sig"))
    need(isinstance(report, dict) and report.get("schema") == 1 and report.get("stage") == stage
         and report.get("run_id") == run_id, "Report schema/stage/run provenance mismatch")
    checks = report.get("checks")
    need((type(checks) is int and checks > 0) or (isinstance(checks, list) and len(checks) > 0),
         "Empty QA checks cannot pass")
    need(report.get("failures") == [] and report.get(validity_key) is True,
         "QA checks failed: " + str(path))
    if isinstance(checks, list):
        need(all(isinstance(item, dict) and item.get("passed") is True for item in checks),
             "GUI check rows contradict the success flag")
    need(report.get("source_manifest_sha256") == manifest_sha, "Report source manifest mismatch")
    return report


def environment(source, run_root, profile, user, gui=False):
    # Execute a verified byte snapshot of the existing public environment helper.
    raw = (ROOT / HELPER).read_bytes()
    need(sha(raw) == source["raw_file_sha256"][HELPER], "Public environment helper changed")
    namespace = {"__file__": str(ROOT / HELPER), "__name__": "reduced_effects_environment"}
    exec(compile(raw.decode("utf-8-sig"), str(ROOT / HELPER), "exec"), namespace)
    env, controls = namespace["environment"]()
    for key in list(env):
        if key.startswith(("REDUCED_EFFECTS_", "CONTENT_UPDATE_", "ANDROID_UPDATE_")):
            if not key.startswith("REDUCED_EFFECTS_"):
                controls[key] = "<unset>"
            env.pop(key)
    if gui:
        env.pop("CAMPAIGN_QA", None)
    else:
        env["CAMPAIGN_QA"] = "1"
    env.update(QA_ONLY="1", CONTENT_UPDATE_NO_AUTO="1", ANDROID_UPDATE_NO_AUTO="1",
               APPDATA=str(profile / "appdata"), LOCALAPPDATA=str(profile / "localappdata"),
               REDUCED_EFFECTS_QA_RUN_ROOT=str(run_root), REDUCED_EFFECTS_QA_USER_DIR=str(user))
    for key in ("QA_ONLY", "CAMPAIGN_QA", "CONTENT_UPDATE_NO_AUTO", "ANDROID_UPDATE_NO_AUTO"):
        controls[key] = env.get(key, "<unset>")
    return env, controls


def make_profile(base, name):
    profile = base / "private_profile"
    user = profile / "appdata/Godot/app_userdata" / name
    need(contained(user, OUTPUT), "Private profile escapes public output root")
    user.mkdir(parents=True, exist_ok=False)
    (profile / "localappdata").mkdir()
    return profile, user


def prepare_legacy(run_root, source, legacy_info):
    """Copy only manifest files. Never hardlink, mutate or restore the live project."""
    project = run_root / "legacy_project"
    need(contained(project, OUTPUT) and not project.exists(), "Legacy destination must be new and bounded")
    project.mkdir()
    for relative in source["directories"]:
        (project / relative).mkdir(parents=True, exist_ok=True)
    for relative, expected in source["raw_file_sha256"].items():
        raw = (ROOT / relative).read_bytes()
        need(sha(raw) == expected, "Source changed while preparing legacy project: " + relative)
        destination = project / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
    need(source_receipt(project) == source, "Private project copy differs from frozen source")
    before = (project / "project.godot").read_bytes()
    seam = b'Settings="*res://scripts/settings.gd"'
    replacement = ('Settings="*res://' + CONTRACT + '/legacy_settings.gd"').encode()
    need(before.count(seam) == 1, "Legacy Autoload seam must be unique")
    (project / "project.godot").write_bytes(before.replace(seam, replacement, 1))
    legacy_path = CONTRACT + "/legacy_settings.gd"
    frozen = (ROOT / CONTRACT / legacy_info["file"]).read_bytes()
    need(sha(frozen) == legacy_info["raw_sha256"], "Legacy fixture changed during copy")
    (project / legacy_path).write_bytes(frozen)
    expected = dict(source["raw_file_sha256"])
    expected["project.godot"] = sha(before.replace(seam, replacement, 1))
    expected[legacy_path] = legacy_info["raw_sha256"]
    observed = source_receipt(project)
    need(observed["raw_file_sha256"] == expected and observed["directories"] == source["directories"],
         "Private project has undeclared differences")
    project_name(project, legacy=True)
    missing_uids = {relative + ".uid": relative for relative in expected
                    if relative.endswith(".gd") and relative + ".uid" not in expected}
    save(run_root / "legacy_copy_receipt.json", {"original_source": source["combined_sha256"],
         "private_source": observed["combined_sha256"], "project_before_raw_sha256": sha(before),
         "project_after_raw_sha256": expected["project.godot"], "autoload_replacements": 1,
         "legacy_settings_raw_sha256": legacy_info["raw_sha256"], "live_source_mutated": False,
         "missing_script_uids_before_import": missing_uids})
    return project, observed, missing_uids


def accept_import_metadata(project, before, missing_uids):
    """Only copied scripts proved to lack a UID may acquire their own sidecar."""
    imported = source_receipt(project)
    expected = dict(before["raw_file_sha256"])
    generated = {}
    for uid_path, script in missing_uids.items():
        need(script.endswith(".gd") and script in before["raw_file_sha256"]
             and uid_path == script + ".uid" and uid_path not in before["raw_file_sha256"],
             "Import UID allowance was not derived from a copied script missing its sidecar")
        if uid_path in imported["raw_file_sha256"]:
            raw = (project / uid_path).read_bytes()
            # Godot 4.6 id_to_text emits canonical base-34 (a-y, 0-8), <= int64 max.
            token = re.fullmatch(rb"uid://([a-y0-8]{1,13})(?:\r?\n)?", raw)
            need(token is not None, "Invalid generated UID: " + uid_path)
            digits = token.group(1)
            value = 0
            alphabet = b"abcdefghijklmnopqrstuvwxy012345678"
            for digit in digits:
                value = value * 34 + alphabet.index(digit)
            need(value <= 0x7fffffffffffffff and (len(digits) == 1 or digits[0] != ord("a")),
                 "Noncanonical or out-of-range generated UID: " + uid_path)
            expected[uid_path] = sha(raw)
            generated[uid_path] = {"raw_sha256":sha(raw), "source_script":script,
                                   "source_script_raw_sha256":before["raw_file_sha256"][script]}
    need(imported["raw_file_sha256"] == expected
         and imported["directories"] == before["directories"]
         and imported["root_presence"] == before["root_presence"],
         "Import changed sources/old metadata or added an undeclared file")
    return imported, generated


def run(args, source, legacy_contract, name):
    exe = resolve_godot(args.godot)
    original_appdata = os.environ.get("APPDATA", "")
    need(original_appdata and Path(original_appdata).is_absolute(), "Cannot identify protected player profile")
    real_user = Path(original_appdata) / "Godot/app_userdata" / name
    protected = signatures(real_user)
    require_exclusive_godot()
    need(not LOCK.exists(), "Shared Godot/source lock is occupied")
    need(LOCK.parent.is_dir(), "Import the normal project before actual QA")
    no_link(LOCK.parent)
    if OUTPUT.exists():
        no_link(OUTPUT)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run_root = OUTPUT / stamp
    run_root.mkdir(parents=True, exist_ok=False)
    need(contained(run_root, OUTPUT) and not contained(real_user, run_root)
         and not contained(run_root, real_user) and run_root.resolve() != real_user.resolve(),
         "Unsafe output/profile overlap")
    receipt = {"schema": 1, "run_id": stamp, "suite": args.suite, "samples": [], "complete": False,
               "production_mutated": False, "performance_claim": False, "godot_run": False,
               "protected_saves_before": protected, "lock_released": False,
               "godot_executable_sha256": sha(Path(exe).read_bytes()), "protected_user_dir": str(real_user)}
    save(run_root / "sources_before.json", source)
    with LOCK.open("x", encoding="utf-8") as stream:
        stream.write(str(run_root) + "\n")
    copied_project = None
    copied_source = None
    def verify_sources():
        need(source_receipt() == source, "Live source/resource paths or bytes changed; preserve WIP")
        need(signatures(real_user) == protected, "Protected player saves changed; never restore over them")
        if copied_project:
            need(source_receipt(copied_project) == copied_source, "Private legacy sources changed")
    def sample(project, current_source, base, profile, user, stage, kind, size=None, independent=False):
        verify_sources()
        stage_dir = base / stage if kind == "gui" else base
        stage_dir.mkdir(parents=True, exist_ok=True)
        manifest_path = stage_dir / ("manifest.json" if kind == "gui" else "manifest_" + stage + ".json")
        report_path = stage_dir / ("report.json" if kind == "gui" else "report_" + stage + ".json")
        need(not report_path.exists() and not manifest_path.exists(), "Refuse stale stage outputs")
        before = signatures(user)
        manifest = {"schema": 1, "run_id": stamp, "run_root": str(run_root), "stage": stage,
                    "expected_user_dir":user.as_posix(), "expected_saves": before,
                    "fixed_source_raw_sha256": current_source["raw_file_sha256"],
                    "source_combined_sha256": current_source["combined_sha256"],
                    "independent_restart": independent}
        if size:
            manifest["resolution"] = SIZES[size]
        if stage == "legacy_autoload":
            manifest["legacy_settings_raw_sha256"] = legacy_contract["legacy_settings"]["raw_sha256"]
        save(manifest_path, manifest)
        manifest_sha = sha(manifest_path.read_bytes())
        env, controls = environment(source, run_root, profile, user, gui=kind == "gui")
        if kind == "gui":
            env.update(REDUCED_EFFECTS_UI_OUT=str(stage_dir), REDUCED_EFFECTS_UI_STAGE=stage,
                       REDUCED_EFFECTS_UI_USER_DIR=str(user))
        else:
            env.update(REDUCED_EFFECTS_QA_OUT=str(base), REDUCED_EFFECTS_QA_STAGE=stage,
                       REDUCED_EFFECTS_QA_RENDER="1", REDUCED_EFFECTS_QA_MANIFEST=str(manifest_path))
        save(stage_dir / ("launch_" + stage + ".json"), {"controlled_environment": controls,
             "child_appdata":env["APPDATA"], "child_localappdata":env["LOCALAPPDATA"],
             "source_manifest_sha256": manifest_sha})
        verify_sources()
        receipt["godot_run"] = True
        process = run_process(exe, project, report_path.with_suffix(".log"), env, args.timeout,
                              GUI if kind == "gui" else BEHAVIOR)
        verify_sources()
        need(sha(manifest_path.read_bytes()) == manifest_sha, "Stage manifest changed")
        report = read_report(report_path, stage, stamp, "gui_valid" if kind == "gui" else "automated_checks_passed", manifest_sha)
        need(Path(report["actual_user_dir"]).resolve() == user.resolve(), "Runtime user path differs from private profile")
        after = signatures(user)
        if kind == "gui":
            need(report["initial_saves"] == before and report["final_saves"] == after,
                 "GUI report/private save receipts disagree")
            need(report.get("captures") and report.get("events"), "GUI omitted actual input or screenshots")
        else:
            need(after == before, "Behavior QA unexpectedly saved through real Autoloads")
            if stage == "all":
                need(report.get("render_status") == "automated_pixel_checks_completed_manual_review_pending"
                     and report.get("critical_feedback_status") == "automated_core_oracles_completed_manual_readability_pending",
                     "Behavior QA did not complete actual drawing checks")
        screenshots = {path.name: sha(path.read_bytes()) for path in stage_dir.glob("*.png")}
        for capture in report.get("captures", []):
            need(capture["file"] in screenshots and capture["sha256"] == screenshots[capture["file"]],
                 "GUI screenshot bytes disagree with report")
        receipt["samples"].append({"kind":kind, "stage":stage, "size":size,
             "report":report_path.relative_to(run_root).as_posix(), "checks":report["checks"],
             "initial_saves":before, "final_saves":after, "child_pid":process["child_pid"],
             "source_manifest_sha256":manifest_sha, "screenshots":screenshots,
             "visual_review":"pending; inspect exact PNG hashes", "valid":True})
        save(run_root / "receipt.json", receipt)
        return after
    try:
        require_exclusive_godot()
        verify_sources()
        if args.suite in ("behavior", "all", "freed-target-boundary"):
            base = run_root / "behavior"
            profile, user = make_profile(base, name)
            stages = ["freed_target_boundary"] if args.suite == "freed-target-boundary" else ["all", "restart_write", "restart_read"]
            for stage in stages:
                sample(ROOT, source, base, profile, user, stage, "behavior", independent=stage == "restart_read")
        if args.suite in ("gui", "all"):
            for size in args.sizes:
                base = run_root / "gui" / size
                profile, user = make_profile(base, name)
                previous = sample(ROOT, source, base, profile, user, "write", "gui", size=size)
                need(signatures(user) == previous, "Private saves changed before GUI restart")
                sample(ROOT, source, base, profile, user, "read", "gui", size=size, independent=True)
        if args.suite in ("legacy", "all"):
            copied_project, copied_source, missing_uids = prepare_legacy(run_root, source, legacy_contract["legacy_settings"])
            base = run_root / "legacy"
            profile, user = make_profile(base, name)
            env, controls = environment(source, run_root, profile, user)
            save(base / "import_launch.json", {"controlled_environment":controls,
                 "child_appdata":env["APPDATA"], "child_localappdata":env["LOCALAPPDATA"]})
            receipt["godot_run"] = True
            run_process(exe, copied_project, base / "import.log", env, args.timeout)
            imported, generated_uids = accept_import_metadata(copied_project, copied_source, missing_uids)
            copied_source = imported
            save(base / "import_source_receipt.json", {"source":copied_source,
                 "missing_script_uids_before_import":missing_uids,
                 "generated_script_uids":generated_uids,
                 "source_edits_allowed":False, "behavior_validated_by_import":False})
            verify_sources()
            # Import is a separate process, never included in the behavioral result.
            sample(copied_project, copied_source, base, profile, user, "legacy_autoload", "legacy")
        receipt["complete"] = True
    except BaseException as exc:
        receipt["exception"] = type(exc).__name__ + ": " + str(exc)
    finally:
        try:
            require_exclusive_godot()
            receipt["protected_saves_after"] = signatures(real_user)
            after = source_receipt()
            save(run_root / "sources_after.json", after)
            receipt["source_unchanged"] = after == source
            receipt["protected_saves_unchanged"] = receipt["protected_saves_after"] == protected
            need(receipt["source_unchanged"] and receipt["protected_saves_unchanged"],
                 "External source/save conflict; retain shared lock and observed receipts")
            if copied_project:
                legacy_after = source_receipt(copied_project)
                save(run_root / "legacy_sources_after.json", legacy_after)
                need(legacy_after == copied_source, "Private legacy sources changed")
            need(LOCK.read_text(encoding="utf-8").strip() == str(run_root), "Shared lock owner changed")
            LOCK.unlink()
            receipt["lock_released"] = True
        except BaseException as exc:
            receipt["cleanup_error"] = type(exc).__name__ + ": " + str(exc)
        save(run_root / "receipt.json", receipt)
        print(json.dumps({"output":str(run_root), "complete":receipt["complete"],
                          "lock_released":receipt["lock_released"], "performance_claim":False}))
    return 0 if receipt["complete"] and receipt["lock_released"] else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--suite", choices=("behavior", "gui", "legacy", "all", "freed-target-boundary"), default="all")
    parser.add_argument("--sizes", nargs="+", choices=tuple(SIZES), default=list(SIZES))
    parser.add_argument("--godot")
    parser.add_argument("--timeout", type=int, default=240)
    args = parser.parse_args()
    need(30 <= args.timeout <= 900 and len(set(args.sizes)) == len(args.sizes), "Invalid bounded timeout or duplicate size")
    info = contract()
    name = project_name()
    source = source_receipt()
    if not args.run:
        print(json.dumps({"preflight_passed":True, "godot_run":False, "production_mutated":False,
             "gdscript_parsed":False, "suite":args.suite, "sizes":args.sizes,
             "source_combined_sha256":source["combined_sha256"],
             "source_files":len(source["raw_file_sha256"]), "legacy_copy_performed":False,
             "next":"Use --run after coordinating the shared exclusive Godot slot"}))
        return 0
    return run(args, source, info, name)


if __name__ == "__main__":
    raise SystemExit(main())
