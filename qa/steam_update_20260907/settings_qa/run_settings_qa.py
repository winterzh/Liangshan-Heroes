"""Read-only preflight by default; --run tests one exact embedded PCK twice.

The external GD is never copied/imported into a project. Process ownership and
player guards reuse pinned helpers; no generation/controller run function is used.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys

sys.dont_write_bytecode = True
SELF = Path(__file__).resolve()
HERE = SELF.parent
ROOT = HERE.parents[1]
QA = HERE / "package_settings_qa.gd"
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
DEFAULT_COMMIT = "443e75e887afd76f9569cae17b0527a72408aedc"
QA_SHA = "c2595658c0274ff912cc6a6c10b135e31bbf1381fc62c46da22644d7b3559682"
ENGINE_SHA = "ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00"
HELPERS = {
    "child": ("scratchpad/chase_path_diag/run_generation.py", "726f12adaad7ce1942d59fd6d4567b1bd8a4a65f8441d4e5d6ddb849e15766b9"),
    "safe": ("scratchpad/separation_sections_diag/frozen/process_safety.py", "7983b00449f8d606e4f1be55ca13596239fbc8b47c3894ff3c31da03757835a1"),
    "environment": ("tools/run_polish_performance.py", "ede41c7acdf96254bb9725558253dbee5e336019b67bc197bb04d4c0b788c52a"),
}
SOURCES = ("project.godot", "export_presets.cfg", "scripts/settings.gd", "scripts/settings_panel.gd",
           "scripts/menu.gd", "scripts/screen.gd", "scenes/menu.tscn",
           "scripts/campaign.gd", "scripts/campaign_mission.gd", "scripts/battle.gd", "scripts/unit.gd",
           "scripts/levels/level3_zhujiazhuang_rts.gd", "scripts/levels/level6_yezhulin.gd",
           "scripts/run_state_value_codec.gd")
BAD_LOG = re.compile(r"SCRIPT ERROR|\bERROR:|\bWARNING:|\bFAIL\b|Parse Error|Unicode|Failed loading resource|Assertion failed", re.I)


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def no_links(path):
    for item in (Path(path).absolute(), *Path(path).absolute().parents):
        if item.exists():
            need(not item.is_symlink() and not getattr(item.lstat(), "st_file_attributes", 0) & 0x400,
                 "Link/reparse path rejected: " + str(item))


def file_sha(path):
    no_links(path)
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path):
    no_links(path)
    need(path.is_file() and path.stat().st_size <= 4 * 1024 * 1024, "Missing/oversized JSON: " + str(path))

    def pairs(items):
        result = {}
        for key, value in items:
            need(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result

    def reject(value):
        raise RuntimeError("Non-finite JSON: " + value)

    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=pairs, parse_constant=reject)


def save(path, data):
    path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8"))


def load_tools():
    result = {}
    for key, (relative, expected) in HELPERS.items():
        path = ROOT / relative
        need(file_sha(path) == expected, "Frozen helper changed: " + relative)
        namespace = {"__file__": str(path), "__name__": "steam_settings_readonly_helpers"}
        exec(compile(path.read_text(encoding="utf-8-sig"), str(path), "exec"), namespace)
        result[key] = namespace
    result["safe"]["ROOT"] = ROOT
    return result


def source_snapshot(receipt_path):
    paths = [ROOT / p for p in SOURCES] + [SELF, QA, receipt_path]
    paths += [ROOT / p for p, _ in HELPERS.values()]
    result = {}
    for path in paths:
        no_links(path)
        need(path.is_file() and path.stat().st_size <= 2 * 1024 * 1024, "Small guard source missing/oversized: " + str(path))
        result[str(path)] = {"bytes": path.stat().st_size, "raw_sha256": file_sha(path)}
    return result


def project_name():
    config = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    need(not re.search(r"(?m)^config/(use_custom_user_dir|custom_user_dir_name)\s*=", config), "Custom user directory unsupported")
    names = re.findall(r'(?m)^config/name="([^"\r\n]+)"\s*$', config)
    need(len(names) == 1 and not any(x in names[0] for x in '/\\'), "Invalid project name")
    return names[0]


def preflight(args, tools):
    need(re.fullmatch(r"[0-9a-f]{40}", args.source_commit) is not None, "Full lowercase source commit required")
    pack = Path(args.exe).absolute()
    engine = Path(args.godot).absolute()
    receipt_path = Path(args.build_receipt).absolute() if args.build_receipt else pack.parent.parent / "build_receipt.json"
    for path in (pack, engine, receipt_path, QA):
        no_links(path)
    if QA.is_file():
        need(file_sha(QA) == QA_SHA, "Frozen external GD changed")
    need(engine.suffix.lower() == ".exe" and "console" not in engine.stem.lower(), "Actual non-console Godot EXE required")
    need(pack.suffix.lower() == ".exe" and pack != engine, "Separate release EXE required")
    build = read_json(receipt_path) if receipt_path.is_file() else None
    if build is not None:
        need(build.get("passed") is True and build.get("source_commit") == args.source_commit, "Build/source commit mismatch")
        need(Path(build.get("executable", "")).resolve() == pack.resolve(), "Build points at another EXE")
        need(re.fullmatch(r"[0-9a-f]{64}", build.get("sha256", "")) is not None, "Build EXE hash missing")
        if pack.is_file():
            need(build.get("size_bytes") == pack.stat().st_size, "Build EXE size mismatch")
    ready = bool(build is not None and engine.is_file() and pack.is_file() and QA.is_file())
    return {"schema": 1, "kind": "steam_settings_readonly_preflight", "inputs_ready": ready,
            "source_commit": args.source_commit, "exe": str(pack), "godot": str(engine),
            "build_receipt": str(receipt_path), "qa_script": str(QA),
            "qa_script_raw_sha256": file_sha(QA) if QA.is_file() else None,
            "runner_raw_sha256": file_sha(SELF), "project_name": project_name(),
            "helper_pins_verified": True, "godot_run": False, "engine_or_package_hashed": False,
            "production_mutated": False, "run_required": True}


def validate_report(report, mode, process, user, pack_sha, commit, qa_sha):
    need(report.get("schema") == 1 and report.get("mode") == mode, "Wrong QA schema/mode")
    need(report.get("complete") is True and report.get("passed") is True and report.get("failures") == [], "Incomplete/failed GD report")
    checks = report.get("checks")
    need(type(checks) is list and bool(checks) and all(type(c) is dict and c.get("passed") is True for c in checks), "Nonempty all-pass GD checks required")
    need(type(report.get("check_count")) is int and report["check_count"] == len(checks), "GD check count mismatch")
    need(type(report.get("pid")) is int and report["pid"] == process["child_pid"], "Self PID does not match owned process")
    need(Path(report.get("actual_user_dir", "")).resolve() == user.resolve(), "GD user:// escaped this run profile")
    need(report.get("executable_sha256") == pack_sha and report.get("source_commit") == commit, "GD build identity mismatch")
    command = process["command"]
    need(command.count("--main-pack") == 1 and "--path" not in command, "Owned launcher must mount one PCK without a source project")
    need(Path(command[command.index("--main-pack") + 1]).resolve() == Path(report.get("mounted_pack", "")).resolve(), "Owned launcher and actual QA name the same mounted pack")
    need(Path(report.get("qa_script_path", "")).resolve() == QA and report.get("qa_script_raw_sha256") == qa_sha, "Wrong external QA source")
    need(report.get("resolution") == [1280, 720] and report.get("rendering_driver", "").lower() == "vulkan"
         and report.get("rendering_method") == "forward_plus", "Actual renderer/resolution mismatch")
    return len(checks)


def png_identity(path):
    no_links(path)
    with path.open("rb") as stream:
        header = stream.read(24)
    need(len(header) == 24 and header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR", "Screenshot is not PNG")
    dimensions = list(struct.unpack(">II", header[16:24]))
    need(dimensions == [1280, 720], "Screenshot must be 1280x720")
    return {"path": str(path), "sha256": file_sha(path), "dimensions": dimensions, "visual_review_pending": True}


def run(args, tools, plan):
    need(os.name == "nt" and plan["inputs_ready"], "Windows and all preflight inputs required for --run")
    pack, engine, build_path = (Path(plan[k]) for k in ("exe", "godot", "build_receipt"))
    name, child, safe = plan["project_name"], tools["child"], tools["safe"]
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = Path(args.out).absolute() if args.out else HERE / "runs" / stamp
    no_links(output)
    need(not output.exists(), "Output must be a new run directory")
    need(any(parent in output.parents for parent in (ROOT / "scratchpad", ROOT / ".godot")), "Output must be inside checkout scratchpad or .godot")
    safe["require_exclusive_godot"]()
    no_links(LOCK)
    need(not LOCK.exists(), "Shared Godot/source lock occupied")
    output.mkdir(parents=True)
    token = str(output)
    with LOCK.open("x", encoding="utf-8") as stream:
        stream.write(token)
    result = {"schema": 1, "kind": "steam_packaged_settings_qa", "run_id": output.name, "complete": False,
              "passed": False, "lock_released": False, "source_commit": args.source_commit, "executable": str(pack),
              "godot": str(engine), "external_qa_script": str(QA), "production_unchanged": None,
              "player_unchanged": None, "modes": [], "performance_claim": False, "human_playtest": False}
    before = player_before = pack_before = engine_before = None
    launch_attempted = []

    def protected_player():
        folder = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / name
        for leaf in ("settings.cfg", "campaign.cfg", "screen.cfg"):
            no_links(folder / leaf)
        return child["player_signature"](name)

    def guard():
        need(LOCK.is_file() and LOCK.read_text("utf-8") == token, "Shared lock ownership changed")
        safe["require_exclusive_godot"]()
        need(source_snapshot(build_path) == before, "Related source/QA/runner/build receipt changed")
        need(protected_player() == player_before, "Real player settings/save changed")

    try:
        before = source_snapshot(build_path)
        player_before = protected_player()
        pack_before, engine_before = file_sha(pack), file_sha(engine)
        build = read_json(build_path)
        need(pack_before == build["sha256"] and engine_before == ENGINE_SHA, "Wrong exact release/engine bytes")
        result.update(source_before=before, player_before=player_before, executable_sha256=pack_before,
                      engine_sha256=engine_before, build_receipt=str(build_path), build_receipt_sha256=file_sha(build_path))
        profile = output / "private_profile"
        user = profile / "appdata/Godot/app_userdata" / name
        user.mkdir(parents=True)
        for leaf in ("localappdata", "temp"):
            (profile / leaf).mkdir()
        env, controls = tools["environment"]["environment"]()
        for key in list(env):
            if key.startswith(("SH_STEAM_QA_", "PACKAGE_", "CHASE_", "SEPARATION_", "UNIT_BODY_", "REDRAW_", "REDUCED_EFFECTS_", "VALUE_CODEC_", "UNIT_ADAPTER_", "RUN_SAVE_", "STORE_QA_", "FIRST_USE_", "ANIM_LOAD_")):
                env.pop(key)
        env.update(APPDATA=str(profile / "appdata"), LOCALAPPDATA=str(profile / "localappdata"),
                   TEMP=str(profile / "temp"), TMP=str(profile / "temp"), CONTENT_UPDATE_NO_AUTO="1", ANDROID_UPDATE_NO_AUTO="1",
                   SH_STEAM_QA_EXE_PATH=str(pack), SH_STEAM_QA_EXE_SHA256=pack_before,
                   SH_STEAM_QA_SOURCE_COMMIT=args.source_commit, SH_STEAM_QA_USER_ROOT=str(profile))
        result.update(private_profile=str(profile), expected_user_dir=str(user), inherited_control_names_cleared=sorted(controls))
        # Only this loaded namespace's cwd changes; the frozen helper file/project does not.
        child["PROJECT"] = pack.parent
        child["ERROR"] = BAD_LOG
        screenshot = output / "settings_1280x720.png"
        qa_sha = before[str(QA)]["raw_sha256"]
        for mode in ("write", "read"):
            guard()
            folder = output / mode
            folder.mkdir()
            report_path = folder / "report.json"
            mode_env = dict(env, SH_STEAM_QA_MODE=mode, SH_STEAM_QA_REPORT=str(report_path),
                            SH_STEAM_QA_SCREENSHOT=str(screenshot) if mode == "write" else "")
            command = [str(engine), "--main-pack", str(pack), "--rendering-method", "forward_plus",
                       "--rendering-driver", "vulkan", "--windowed", "--resolution", "1280x720",
                       "--log-file", str(folder / "godot.log"), "--script", str(QA)]
            save(folder / "configuration.json", {"mode": mode, "command": command,
                 "environment_overrides": {k: v for k, v in mode_env.items() if k.startswith("SH_STEAM_QA_") or k in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP")}})
            launch_attempted.append(folder)
            process = child["run_child"]({"safe": safe}, engine, command, mode_env, folder, args.timeout)
            report = read_json(report_path)
            count = validate_report(report, mode, process, user, pack_before, args.source_commit, qa_sha)
            need(Path(report.get("mounted_pack", "")).resolve() == pack.resolve(), "Report mounts another package")
            process["borrowed_helper_pid_evidence"] = process["pid_evidence"]
            process["pid_evidence"] = "Owned actual non-console Popen handle plus this external QA's OS.get_process_id self report"
            process["qa_pid_match_verified"] = True
            save(folder / "process_receipt.json", process)
            log = (folder / "godot.log").read_text(encoding="utf-8")
            need(not any(BAD_LOG.search(line) for line in log.splitlines()), "Strict engine sidecar log failed")
            if mode == "write":
                identity = png_identity(screenshot)
                need(Path(report.get("screenshot_path", "")).resolve() == screenshot.resolve()
                     and report.get("screenshot_sha256") == identity["sha256"], "GD screenshot identity mismatch")
                result["screenshot"] = identity
            result["modes"].append({"mode": mode, "pid": process["child_pid"], "checks": count,
                                    "report": str(report_path), "report_sha256": file_sha(report_path),
                                    "process_receipt_sha256": file_sha(folder / "process_receipt.json"),
                                    "godot_log_sha256": file_sha(folder / "godot.log"),
                                    "settings_file_before": report.get("settings_file_before"),
                                    "settings_file_after": report.get("settings_file_after"), "passed": True})
            need(file_sha(user / "settings.cfg") == report.get("settings_file_after"), "Private settings/report bytes mismatch")
            guard()
            save(output / "receipt.json", result)
        need(result["modes"][0]["pid"] != result["modes"][1]["pid"], "Write/read must be distinct owned processes")
        first, second = result["modes"]
        need(first["settings_file_before"] == "absent" and first["settings_file_after"] == second["settings_file_before"]
             == second["settings_file_after"], "Independent restart did not preserve exact written settings")
        result.update(complete=True, passed=True, checks=sum(row["checks"] for row in result["modes"]))
    except BaseException as error:
        result["error"] = type(error).__name__ + ": " + str(error)
    finally:
        try:
            # Explicit receipts, not a process-name scan alone, prove every launch ended.
            for folder in launch_attempted:
                process = read_json(folder / "process_receipt.json")
                need(process.get("child_exit_confirmed") is True, "Owned child exit unconfirmed; keep lock")
            need(before is not None and player_before is not None and pack_before is not None and engine_before is not None,
                 "Guard preimage incomplete; keep lock")
            guard()
            pack_after, engine_after = file_sha(pack), file_sha(engine)
            need(pack_after == pack_before and engine_after == engine_before, "Release EXE/engine changed")
            result.update(source_after=source_snapshot(build_path), player_after=protected_player(),
                          executable_sha256_after=pack_after, engine_sha256_after=engine_after,
                          production_unchanged=True, player_unchanged=True)
            need(LOCK.read_text("utf-8") == token, "Cannot release another owner's lock")
            LOCK.unlink()
            result["lock_released"] = True
        except BaseException as error:
            result.update(complete=False, passed=False, lock_preserved=True,
                          cleanup_error=type(error).__name__ + ": " + str(error))
        save(output / "receipt.json", result)
    return result, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Actual Godot 4.6.3 non-console EXE")
    parser.add_argument("--exe", required=True, help="Exact newly exported embedded-PCK Windows EXE")
    parser.add_argument("--source-commit", default=DEFAULT_COMMIT)
    parser.add_argument("--build-receipt", help="Defaults to EXE.parent.parent/build_receipt.json")
    parser.add_argument("--out", help="New run directory under checkout scratchpad or .godot")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    need(10 <= args.timeout <= 600, "Timeout outside 10..600 seconds")
    tools = load_tools()
    plan = preflight(args, tools)
    if not args.run:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    result, output = run(args, tools, plan)
    print(json.dumps({"output": str(output), "complete": result["complete"], "passed": result["passed"],
                      "lock_released": result["lock_released"], "error": result.get("error"),
                      "cleanup_error": result.get("cleanup_error")}, ensure_ascii=False))
    return 0 if result["complete"] and result["passed"] and result["lock_released"] else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({"complete": False, "error": type(error).__name__ + ": " + str(error)}, ensure_ascii=False))
        raise SystemExit(2)
