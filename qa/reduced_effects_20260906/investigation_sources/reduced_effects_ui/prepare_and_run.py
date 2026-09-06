"""Unrun GUI fixture draft. No production mutation; --run is future explicit use only.

Requires the separately reviewed V2 candidate already installed by the root task.
Default performs read-only draft checks. Never applies the V2 patch or invokes Git.
"""
import argparse
import ast
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
V2 = ROOT / "scratchpad/reduced_effects_v2/pins.json"
SAFETY = "scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py"
HELPERS = "tools/run_polish_performance.py"
DIRECTORIES = ("scripts", "scenes", "assets", "shaders", "resources", "data", "addons", "content", "scenarios")
SIZES = {"1440x900": [1440, 900], "1280x720": [1280, 720]}


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def save(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())


def signatures(directory):
    return {key: sha((directory / name).read_bytes()) if (directory / name).is_file() else "absent"
            for key, name in (("settings", "settings.cfg"), ("campaign", "campaign.cfg"), ("screen", "screen.cfg"))}


def load_module(path):
    namespace = {"__file__": str(path), "__name__": "reduced_effects_ui_helpers"}
    exec(compile(path.read_text(encoding="utf-8-sig"), str(path), "exec"), namespace)
    return namespace


def draft_checks():
    pins = json.loads((HERE / "reviewed_sources.json").read_text(encoding="utf-8"))
    for path, value in pins["fixed_raw_sha256"].items():
        need(sha((ROOT / path).read_bytes()) == value, "Reviewed source changed: " + path)
    source = (HERE / "ui_driver.gd.in").read_text(encoding="utf-8")
    for token in ("root.push_input(", "InputEventMouseButton.new()", "InputEventKey.new()", "MOUSE_BUTTON_WHEEL_DOWN", "button.pressed.connect(observer)"):
        need(token in source, "Missing real GUI input/observation seam: " + token)
    for token in (".pressed.emit(", 'set("effects_quality"', ".effects_quality =", "._open_pause(", "._close_pause(", "._show_settings(", "Settings.save(", "Campaign.save_prefs("):
        need(token not in source, "UI draft bypasses production GUI route: " + token)
    ast.parse(Path(__file__).read_text(encoding="utf-8"))
    return pins


def source_receipt():
    """Fresh paths + exact raw bytes; include hidden files, fail on traversal errors."""
    files = set()
    directories = set()
    def scan_error(error):
        raise error
    for top in DIRECTORIES:
        directory = ROOT / top
        if not directory.exists():
            continue
        need(directory.is_dir() and not directory.is_symlink(), "Invalid source directory: " + top)
        for parent, dirs, names in os.walk(directory, onerror=scan_error, followlinks=False):
            for item in dirs + names:
                path = Path(parent) / item
                stat = path.lstat()
                need(not path.is_symlink() and not getattr(stat, "st_file_attributes", 0) & 0x400,
                     "Reparse source is outside the reviewed scope: " + str(path))
            directories.add(Path(parent).relative_to(ROOT).as_posix())
            files.update(Path(parent) / name for name in names)
    files.update(ROOT / name for name in ("project.godot", SAFETY, HELPERS))
    files.update(p for p in ROOT.iterdir() if p.is_file() and p.name.lower().startswith("icon."))
    rows = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in sorted(files)}
    return {"raw_file_sha256": rows, "directories": sorted(directories),
            "combined_sha256": sha(json.dumps([rows, sorted(directories)], sort_keys=True).encode())}


def project_name():
    text = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    need("config/use_custom_user_dir" not in text and "config/custom_user_dir_name" not in text,
         "Custom user directory requires a separately reviewed isolation mapping")
    names = re.findall(r'^config/name=("[^\n]+")\s*$', text, re.M)
    need(len(names) == 1, "Expected one simple project name")
    name = json.loads(names[0])
    need(name and not any(char in name for char in '<>:"/\\|?*') and name not in (".", ".."),
         "Project name requires Godot filename sanitization; do not guess user directory")
    return name


def run(args, reviewed):
    need(os.name == "nt", "Only the reviewed Windows APPDATA isolation is implemented")
    need(V2.is_file(), "V2 pins are not prepared yet")
    v2_bytes = V2.read_bytes()
    v2 = json.loads(v2_bytes)
    driver_bytes = (HERE / "ui_driver.gd.in").read_bytes()
    draft_bytes = {path: path.read_bytes() for path in (Path(__file__), HERE / "reviewed_sources.json", HERE / "ui_driver.gd.in", V2)}
    def verify_drafts():
        for path, raw in draft_bytes.items():
            need(path.read_bytes() == raw, "Reviewed draft or candidate pins changed: " + str(path))
    fixed = dict(reviewed["fixed_raw_sha256"])
    expected_candidates = v2["candidate_lf_sha256"]
    need(set(expected_candidates) == {"scripts/settings.gd", "scripts/settings_panel.gd", "scripts/battle.gd", "scripts/unit.gd"}, "Unexpected V2 candidate scope")
    for path, value in expected_candidates.items():
        raw = (ROOT / path).read_bytes()
        need(sha(raw.replace(b"\r\n", b"\n")) == value, "Root task must first install the reviewed candidate: " + path)
        fixed[path] = sha(raw)
    name = project_name()
    original_appdata = os.environ.get("APPDATA", "")
    need(original_appdata and Path(original_appdata).is_absolute(), "Real APPDATA cannot be identified safely")
    real_user = Path(original_appdata) / "Godot/app_userdata" / name
    protected_before = signatures(real_user)
    safe = load_module(ROOT / SAFETY)
    helpers = load_module(ROOT / HELPERS)
    exe = safe["resolve_godot"](args.godot)
    safe["require_exclusive_godot"]()
    need(not LOCK.exists(), "Shared source lock exists; coordinate the independent GUI slot")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = HERE / "runs" / stamp
    output.mkdir(parents=True, exist_ok=False)
    source = source_receipt()
    save(output / "source_before.json", source)
    receipt = {"production_mutated": False, "godot_run": False, "performance_claim": False,
               "protected_user_dir": str(real_user), "protected_saves_before": protected_before,
               "v2_pins_raw_sha256": sha(v2_bytes), "samples": [], "complete": False,
               "draft_raw_sha256": {path.relative_to(ROOT).as_posix():sha(raw) for path, raw in draft_bytes.items()}}
    need(LOCK.parent.is_dir(), "Expected imported project .godot directory")
    with LOCK.open("x", encoding="utf-8") as stream:
        stream.write(str(output) + "\n")
    try:
        for size in args.sizes:
            size_root = output / size
            profile = size_root / "private_profile"
            appdata = profile / "appdata"
            localappdata = profile / "localappdata"
            appdata.mkdir(parents=True, exist_ok=False)
            localappdata.mkdir()
            private_user = appdata / "Godot/app_userdata" / name
            need(HERE.resolve() in private_user.resolve().parents and real_user.resolve() not in private_user.resolve().parents,
                 "Private profile must be contained by this scratchpad and separate from real user data")
            # No real player bytes are copied: write starts with genuinely absent prefs.
            private_user.mkdir(parents=True, exist_ok=False)
            last_saves = signatures(private_user)
            process_ids = []
            for stage in ("write", "read"):
                stage_dir = size_root / stage
                stage_dir.mkdir()
                driver = stage_dir / "driver.gd"
                verify_drafts()
                driver.write_bytes(driver_bytes)
                need(source_receipt() == source, "Production source/resource changed before GUI sample")
                current_saves = signatures(private_user)
                need(current_saves == last_saves, "Private restart prefs changed between processes")
                manifest = {"schema":1, "expected_user_dir":private_user.resolve().as_posix(),
                            "resolution":SIZES[size], "expected_saves":current_saves,
                            "fixed_source_raw_sha256":fixed, "stage":stage,
                            "driver_raw_sha256":sha(driver.read_bytes()),
                            "source_combined_sha256":source["combined_sha256"]}
                save(stage_dir / "manifest.json", manifest)
                env, controls = helpers["environment"]()
                for key in list(env):
                    if key.startswith("REDUCED_EFFECTS_"):
                        env.pop(key)
                # The GUI must exercise both actual save callbacks. Its entire
                # user directory is already private, so do not suppress Campaign.
                env.pop("CAMPAIGN_QA", None)
                env["CONTENT_UPDATE_NO_AUTO"] = "1"
                env["ANDROID_UPDATE_NO_AUTO"] = "1"
                for key in ("CAMPAIGN_QA", "CONTENT_UPDATE_NO_AUTO", "ANDROID_UPDATE_NO_AUTO"):
                    controls[key] = env.get(key, "<unset>")
                env.update(APPDATA=str(appdata.resolve()), LOCALAPPDATA=str(localappdata.resolve()),
                           REDUCED_EFFECTS_UI_OUT=str(stage_dir.resolve()), REDUCED_EFFECTS_UI_STAGE=stage,
                           REDUCED_EFFECTS_UI_USER_DIR=str(private_user.resolve()))
                save(stage_dir / "launch.json", {"godot_raw_sha256":sha(Path(exe).read_bytes()),
                     "controlled_environment":controls, "private_appdata":str(appdata),
                     "private_localappdata":str(localappdata), "driver_raw_sha256":sha(driver.read_bytes())})
                receipt["godot_run"] = True
                report = safe["run_godot"](exe, driver, stage_dir / "report.json", env, 240, validity_key="gui_valid")
                verify_drafts()
                need(source_receipt() == source, "Production source/resource changed during GUI sample")
                need(sha(driver.read_bytes()) == manifest["driver_raw_sha256"], "GUI driver changed during sample")
                need(signatures(real_user) == protected_before, "Protected player saves changed; preserve evidence, never restore over them")
                last_saves = signatures(private_user)
                need(last_saves == report["final_saves"], "Process report and actual private save bytes disagree")
                need(report["initial_saves"] == current_saves and report["stage"] == stage, "Wrong restart sample provenance")
                need(report["source_manifest_sha256"] == sha((stage_dir / "manifest.json").read_bytes()), "Run manifest changed")
                process_ids.append(report["process_id"])
                receipt["samples"].append({"size":size,"stage":stage,"report":str((stage_dir / "report.json").relative_to(output)),
                    "initial_saves":current_saves,"final_saves":last_saves,"process_id":report["process_id"],"gui_valid":True})
                save(output / "receipt.json", receipt)
            # Exact Popen lifecycle is already verified by safe.run_godot. PIDs may
            # legitimately be reused by Windows; different PID is not the proof.
            receipt.setdefault("independent_restart_pairs", []).append({"size":size,"fresh_process_invocations":2,"observed_process_ids":process_ids,"same_private_profile":True})
        receipt["complete"] = True
    except BaseException as exc:
        receipt["exception"] = type(exc).__name__ + ": " + str(exc)
        raise
    finally:
        try:
            safe["require_exclusive_godot"]()
            receipt["protected_saves_after"] = signatures(real_user)
            receipt["protected_saves_unchanged"] = receipt["protected_saves_after"] == protected_before
            after = source_receipt()
            save(output / "source_after.json", after)
            receipt["source_unchanged"] = after == source
            verify_drafts()
            need(receipt["protected_saves_unchanged"] and receipt["source_unchanged"], "External source/save conflict: retain shared lock and evidence")
            need(LOCK.read_text(encoding="utf-8").strip() == str(output), "Shared lock ownership changed")
            LOCK.unlink()
            receipt["lock_released"] = True
        except BaseException as exc:
            receipt["cleanup_error"] = type(exc).__name__ + ": " + str(exc)
            receipt["lock_released"] = False
        save(output / "receipt.json", receipt)
        print(json.dumps({"output":str(output),"complete":receipt["complete"],"lock_released":receipt["lock_released"],"performance_claim":False}))
    return 0 if receipt["complete"] and receipt["lock_released"] else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--sizes", nargs="+", choices=tuple(SIZES), default=list(SIZES))
    args = parser.parse_args()
    need(len(set(args.sizes)) == len(args.sizes), "Duplicate sizes")
    reviewed = draft_checks()
    if not args.run:
        print(json.dumps({"draft_static_checks":True,"godot_run":False,"gdscript_parsed":False,"production_mutated":False,"next":"Root task installs reviewed V2 candidate and schedules exclusive GUI slot"}))
        return 0
    return run(args, reviewed)


if __name__ == "__main__":
    raise SystemExit(main())
