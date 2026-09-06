"""Specific ST_CHASE generation: five ordered writes on four final paths.

Default is bounded read-only contract/small-source preflight, no engine or project writes.
--run audits complete parent source/cache under the common lock, saves two original
preimages once, restores Unit then applies pinned Unit/Map observers and two new GDs.
Process/profile/lock primitives derive from the pinned successful Unit-body runner
 ae62d3a503f4d480b47a1a4de2dfae0662b754ff64568028889ad85ba4d72521.
No archive copy, automatic source restoration, production write, or old route entry.
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
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SEP = ROOT / "scratchpad/separation_sections_diag"
PROJECT = SEP / "runs/20260906T104036739951Z/project"
PARENT = ROOT / "scratchpad/unit_body_sections_diag/generations/20260906T153209698572Z"
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
CONTRACT_SHA = "b3cfa61bd6a2df02ca89ebd80ad71dd2c6c40a0dda71c2ea5eff4245946bcacc"
ERROR = re.compile(r"SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b|Parse Error|Unicode parsing error", re.M)
TARGETS = ("scripts/unit.gd", "scripts/unit.gd", "scripts/game_map.gd",
           "scratchpad/chase_path_diag/generated/driver.gd",
           "scratchpad/chase_path_diag/generated/ledger.gd")
ACTIVE = None


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def save(path, data):
    path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def no_links(path):
    current = Path(path).absolute()
    for entry in [current, *current.parents]:
        if entry.exists():
            need(not entry.is_symlink() and not getattr(entry.lstat(), "st_file_attributes", 0) & 0x400,
                 "Reparse/link path rejected: " + str(entry))


def exact(path, expected):
    no_links(path)
    need(path.is_file(), "Required regular file missing: " + str(path))
    raw = path.read_bytes()
    need(sha(raw) == expected, "Frozen file changed: " + str(path))
    return raw


def load_module(path, raw):
    namespace = {"__file__": str(path), "__name__": "unit_generation_readonly_helper"}
    exec(compile(raw.decode("utf-8-sig"), str(path), "exec"), namespace)
    return namespace


def load_contract():
    contract_path = HERE / "reuse_contract.json"
    plan = json.loads(exact(contract_path, CONTRACT_SHA))
    need(plan["source_base"] == "4baafc11af55b0e46a57a48e54df181b8c1917a2", "Wrong frozen base")
    need((ROOT / plan["target_private_project"]).resolve() == PROJECT.resolve(), "Wrong reused project")
    need((ROOT / plan["parent_generation"]).resolve() == PARENT.resolve(), "Wrong completed parent")
    need(tuple(row["target_in_private_project"] for row in plan["changes_in_order"]) == TARGETS, "Wrong five ordered mutations")
    frozen = {contract_path: CONTRACT_SHA, Path(__file__).resolve(): sha(Path(__file__).read_bytes())}
    for rel, expected in plan["frozen_evidence"].items():
        path = ROOT / rel
        exact(path, expected); frozen[path] = expected
    parent = read(PARENT / "receipt.json")
    analysis = read(PARENT / "analysis_receipt.json")
    need(parent["complete"] and parent["lock_released"] and parent["production_unchanged"]
         and analysis["completed"] and analysis["both_analysis_valid"], "Parent not fully completed and analyzed")
    for row in analysis["analyses"]:
        path = PARENT / row["mode"] / "analysis.json"
        exact(path, row["raw_sha256"])
        need(read(path)["analysis_valid"], "Parent analysis invalid")
    pins = read(ROOT / "scratchpad/unit_body_sections_diag/pins.json")
    need(set(pins["source_contract"]) == set(plan["live_guard_keys"]) and len(plan["live_guard_keys"]) == 11, "Live source guard key drift")
    for item in pins["source_contract"].values():
        path = Path(item["frozen_path"])
        exact(path, item["raw_sha256"]); frozen[path] = item["raw_sha256"]
    for row in plan["changes_in_order"]:
        path = ROOT / row["payload"]["path"]
        raw = exact(path, row["expected_after_raw_sha256"])
        need(len(raw) == row["payload"]["bytes"], "Payload length drift")
        frozen[path] = row["expected_after_raw_sha256"]
    chase_pins = read(HERE / "pins.json")
    for leaf, expected in chase_pins["generated_sha256"].items():
        path = HERE / "generated" / leaf
        exact(path, expected); frozen[path] = expected
    need(read(HERE / "static_receipt.json")["static_valid"], "Chase preparation static checks failed")
    launcher_path = SEP / "launch.py"
    safe_path = SEP / "frozen/process_safety.py"
    launcher = load_module(launcher_path, exact(launcher_path, frozen[launcher_path]))
    safe = load_module(safe_path, exact(safe_path, frozen[safe_path]))
    safe["ROOT"] = ROOT
    no_links(PROJECT); no_links(PARENT)
    return {"plan": plan, "pins": pins, "chase_pins": chase_pins, "frozen": frozen,
            "launcher": launcher, "safe": safe,
            "parent_source": read(PARENT / "final_source.json"), "parent_cache": read(PARENT / "final_cache.json")}


def check_frozen(bundle):
    for path, expected in bundle["frozen"].items():
        exact(path, expected)


def live_source_snapshot(bundle):
    result = {}
    for name in bundle["pins"]["source_contract"]:
        path = ROOT / name
        no_links(path)
        need(path.is_file(), "Live critical source missing: " + name)
        result[name] = sha(path.read_bytes())
    return result


def planned_source(bundle, source):
    need(len(source) == 3306, "Wrong parent source size")
    expected = dict(source)
    for row in bundle["plan"]["changes_in_order"]:
        key = row["target_in_private_project"]
        need(expected.get(key) == row["expected_before_raw_sha256"], "Sequential preimage mismatch: " + key)
        expected[key] = row["expected_after_raw_sha256"]
    need(len(expected) == 3308, "Wrong pre-import source count")
    for name in ("scratchpad/.gdignore", "scratchpad/chase_path_diag/.gdignore",
                 "scratchpad/chase_path_diag/generated/.gdignore"):
        need(not (PROJECT / name).exists(), "New script ancestor is ignored")
    for row in bundle["plan"]["changes_in_order"]:
        if row["before_must_be_absent"]:
            need(not (PROJECT / row["target_in_private_project"]).exists(), "New target already exists")
    return expected


def small_preflight(bundle):
    check_frozen(bundle)
    source, cache = bundle["parent_source"], bundle["parent_cache"]
    need(len(cache) == 2376, "Wrong saved parent cache size")
    planned_source(bundle, source)
    total = 0
    for key, row in bundle["plan"]["small_private_source_checks"].items():
        raw = exact(PROJECT / key, row["raw_sha256"])
        need(len(raw) == row["bytes"] and source[key] == row["raw_sha256"], "Small current source mismatch")
        total += len(raw)
    check_frozen(bundle)
    return {"preflight": True, "read_only": True, "small_private_files": len(bundle["plan"]["small_private_source_checks"]),
            "small_private_bytes": total, "recorded_parent_source_files": len(source), "recorded_parent_cache_files": len(cache),
            "whole_current_project_or_cache_hashed": False, "full_audit_required_under_run_lock": True,
            "godot_run": False, "private_project_mutated": False, "new_project_copy": False}


def full_preflight(bundle):
    """Only --run reaches this complete payload audit, after taking the common lock."""
    check_frozen(bundle)
    manifest = bundle["launcher"]["manifest"]
    source = manifest(PROJECT)
    cache = manifest(PROJECT / ".godot", exclude_godot=False)
    need(source == bundle["parent_source"] and cache == bundle["parent_cache"], "Current full source/cache differs from completed parent")
    need(len(cache) == 2376, "Wrong current cache size")
    planned_source(bundle, source)
    check_frozen(bundle)
    return source, cache


def project_name():
    config = (PROJECT / "project.godot").read_text(encoding="utf-8-sig")
    need(not re.search(r"(?m)^config/(use_custom_user_dir|custom_user_dir_name)\s*=", config), "Custom user directory unsupported")
    names = re.findall(r'(?m)^config/name="([^"\r\n]+)"\s*$', config)
    need(len(names) == 1 and not any(x in names[0] for x in '/\\'), "Invalid project name")
    return names[0]


def player_signature(name):
    need(os.environ.get("APPDATA"), "Cannot identify protected Windows profile")
    folder = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / name
    no_links(folder)
    return {leaf: sha((folder / leaf).read_bytes()) if (folder / leaf).is_file() else None
            for leaf in ("settings.cfg", "campaign.cfg", "screen.cfg")}


def profile_environment(bundle, folder, name):
    profile = folder / "private_profile"
    user = profile / "appdata/Godot/app_userdata" / name
    user.mkdir(parents=True, exist_ok=False)
    for leaf in ("localappdata", "temp"):
        (profile / leaf).mkdir()
    helper_path = PROJECT / "tools/run_polish_performance.py"
    helper = load_module(helper_path, exact(helper_path, bundle["parent_source"]["tools/run_polish_performance.py"]))
    env, controls = helper["environment"]()
    prefixes = ("CHASE_PATH_", "UNIT_BODY_SECTIONS_", "SEPARATION_", "FIRST_USE_", "ANIM_LOAD_", "REDRAW_", "REDUCED_EFFECTS_",
                "UNIT_ADAPTER_", "VALUE_CODEC_", "STORE_QA_", "RUN_SAVE_")
    for key in list(env):
        if key.startswith(prefixes):
            env.pop(key)
    env.update(APPDATA=str(profile / "appdata"), LOCALAPPDATA=str(profile / "localappdata"),
               TEMP=str(profile / "temp"), TMP=str(profile / "temp"), CAMPAIGN_QA="1",
               CONTENT_UPDATE_NO_AUTO="1", ANDROID_UPDATE_NO_AUTO="1")
    return env, controls, profile, user


def differences(before, after):
    return {name: {"before": before.get(name), "after": after.get(name)}
            for name in sorted(set(before) | set(after)) if before.get(name) != after.get(name)}


def run_child(bundle, exe, command, env, folder, timeout):
    """Own the actual exe handle through all exceptions, including KeyboardInterrupt."""
    global ACTIVE
    safe = bundle["safe"]
    safe["require_exclusive_godot"]()
    log_path = folder / "process.log"
    need(not log_path.exists(), "New process log already exists")
    process = None
    confirmed = False
    failure = cleanup = None
    started = time.monotonic()
    launched_ns = time.time_ns()
    result = {"command": command, "actual_executable": str(exe), "pid_evidence": "owned Popen handle to actual non-console exe; frozen GD does not self-report PID"}
    try:
        with log_path.open("xb") as log:
            process = subprocess.Popen(command, cwd=PROJECT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            ACTIVE = process
            safe["ACTIVE_GODOT_PROCESS"] = process
            process.wait(timeout=timeout)
    except BaseException as error:
        failure = error
        if process is not None:
            try:
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=30)
            except BaseException as error2:
                cleanup = type(error2).__name__ + ": " + str(error2)
    finally:
        if process is not None:
            confirmed = process.poll() is not None
            if confirmed:
                ACTIVE = None
                safe["ACTIVE_GODOT_PROCESS"] = None
        result.update(child_pid=process.pid if process else None, child_exit_confirmed=confirmed,
                      exit_code=process.returncode if confirmed else None, launched_time_ns=launched_ns,
                      timeout_seconds=timeout, timed_out=isinstance(failure, subprocess.TimeoutExpired),
                      exception=type(failure).__name__ + ": " + str(failure) if failure else None,
                      cleanup_error=cleanup, wall_seconds=time.monotonic() - started)
        raw = log_path.read_bytes() if log_path.exists() else b""
        result["log_raw_sha256"] = sha(raw)
        try:
            text = raw.decode("utf-8", errors="strict")
            result["matched_errors"] = [line for line in text.splitlines() if ERROR.search(line)]
            result["log_decoding_error"] = None
        except UnicodeError as error:
            result["matched_errors"] = []
            result["log_decoding_error"] = str(error)
        save(folder / "process_receipt.json", result)
    if failure:
        raise failure
    need(confirmed and result["exit_code"] == 0 and not cleanup, "Actual child did not exit successfully")
    need(not result["log_decoding_error"] and not result["matched_errors"], "Strict engine log failed")
    safe["require_exclusive_godot"]()
    return result


def check_runtime_reports(folder, mode, user, process):
    for leaf in ("m1_10s.json", "report.json", "m1_10s.png"):
        path = folder / leaf
        no_links(path)
        need(path.is_file() and path.stat().st_mtime_ns >= process["launched_time_ns"] - 1000000000,
             "Missing or stale child artifact: " + leaf)
    m1 = read(folder / "m1_10s.json")
    data = read(folder / "report.json")
    need(m1["integrity_passed"] and not m1["failures"] and m1["sample_complete"], "Original M1 integrity failed")
    need(m1["scenario"] == "defense200" and m1["camera_mode"] == "fixed" and m1["requested_seconds"] == 10
         and m1["seconds"] >= 10 and m1["renderer"] == "forward_plus", "Wrong original M1 scenario/time/renderer")
    need(m1["resolution"] == [1440, 900], "Original M1 resolution must remain 1440x900")
    need(m1["seed"] == 5088120 and m1["physics_hz"] == 60 and m1["time_scale"] == 1
         and m1["warmup_target_ticks"] == 300 and m1["warmup_end_tick"] >= 300, "Original simulation settings changed")
    need(m1["audio_ready"] and m1["contact_covered"] and m1["screenshot_saved"] and not m1["camera_violations"], "Audio/contact/render evidence missing")
    need(data["schema"] == 1 and data["valid"] and data["errors"] == 0 and not data["overflow"], "Chase path ledger invalid")
    need(data["mode"] == mode and data["timed"] == (mode == "timed"), "Wrong timing mode")
    need(Path(data["actual_user_dir"]).resolve() == user.resolve(), "Child user:// differs from exact private path")
    need(data["step_count"] == len(data["steps"]) and all(len(row) == 44 for row in data["steps"]), "Step shape/count")
    need(data["step_columns"] == read(HERE / "pins.json")["step_columns"], "Exact chase metric column contract")
    need(data["presentation_count"] == len(data["presentations"]) == m1["frames"] == len(m1["raw_frame_ms"]), "Original presentation count")
    need(data["m1_end"]["step_count"] - data["m1_start"]["step_count"] == m1["physics_ticks"], "Measurement step anchors")
    need(not data["acceptance_eligible"] and not data["performance_claim"] and not m1["acceptance_eligible"], "Short diagnostic overclaims eligibility")
    return {"mode": mode, "process_id": process["child_pid"], "exit_code": 0, "basic_report_valid": True,
            "full_offline_analysis_pending": True, "m1_raw_sha256": sha((folder / "m1_10s.json").read_bytes()),
            "sidecar_raw_sha256": sha((folder / "report.json").read_bytes()),
            "initial_deployment_sha256": sha(json.dumps(m1["initial_units"], sort_keys=True).encode()),
            "input_sha256": sha(json.dumps(m1["inputs"], sort_keys=True).encode())}


def run(args, bundle):
    need(os.name == "nt", "This private profile/actual exe contract is Windows-only")
    safe, manifest = bundle["safe"], bundle["launcher"]["manifest"]
    exe = Path(safe["resolve_godot"](args.godot))
    no_links(exe)
    need(not re.search(r"[._-]console\.exe$", exe.name, re.I) and exe.suffix.lower() == ".exe", "Provide the actual non-console Godot exe")
    exe_sha = sha(exe.read_bytes())
    need(exe_sha == bundle["plan"]["engine_raw_sha256"], "Engine differs from reviewed parent version")
    name = project_name()
    safe["require_exclusive_godot"]()
    need(not LOCK.exists(), "Shared Godot/source slot occupied")
    no_links(HERE / "generations")
    output = HERE / "generations" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output.mkdir(parents=True, exist_ok=False)
    token = str(os.getpid()) + "|" + str(output)
    no_links(LOCK)
    with LOCK.open("x", encoding="utf-8") as stream:
        stream.write(token)
    player_before = None
    live_before = None
    imported_source = imported_cache = None
    receipt = {"schema": 1, "complete": False, "lock_released": False, "generation": output.name,
               "parent_generation": str(PARENT), "private_project": str(PROJECT), "base": bundle["plan"]["source_base"],
               "new_project_copied": False, "production_mutated": None, "production_unchanged": None,
               "production_write_operations": [], "mutations": [], "stages": [],
               "engine_raw_sha256": exe_sha, "performance_claim": False, "full_offline_analysis_pending": True,
               "pid_scope": "Actual non-console Popen handle; frozen GD has no self-reported PID."}
    save(output / "receipt.json", receipt)

    def ownership():
        need(LOCK.exists() and LOCK.read_text(encoding="utf-8") == token, "Shared lock ownership changed")
        safe["require_exclusive_godot"]()
        check_frozen(bundle)
        need(sha(exe.read_bytes()) == exe_sha, "Engine bytes changed")
        if live_before is not None:
            need(live_source_snapshot(bundle) == live_before, "Live production critical source drift")
        if player_before is not None:
            need(player_signature(name) == player_before, "Protected player files changed")

    def runtime_guard(stage):
        ownership()
        source = manifest(PROJECT)
        cache = manifest(PROJECT / ".godot", exclude_godot=False)
        save(output / (stage + "_source.json"), source)
        save(output / (stage + "_cache.json"), cache)
        need(source == imported_source, "Source/UID/path drift during measurement")
        delta = differences(imported_cache, cache)
        save(output / (stage + "_cache_delta.json"), delta)
        need(not delta, "Any runtime cache drift is outside this narrow generation contract")

    try:
        ownership()
        live_before = live_source_snapshot(bundle)
        receipt["live_before"] = live_before
        player_before = player_signature(name)
        receipt["protected_player_before"] = player_before
        save(output / "receipt.json", receipt)
        source, cache = full_preflight(bundle)
        save(output / "parent_source_verified.json", source)
        save(output / "parent_cache_verified.json", cache)
        save(output / "runner_sources.json", {path.relative_to(ROOT).as_posix(): value for path, value in bundle["frozen"].items()})
        receipt["full_parent_source_verified"] = receipt["full_parent_cache_verified"] = True
        before = output / "before"
        before.mkdir()
        # Unit appears twice in the plan: save its original body-probe bytes only once.
        for name_rel in bundle["plan"]["before_backup_paths"]:
            original_sha = source[name_rel]
            raw = exact(PROJECT / name_rel, original_sha)
            path = before / name_rel.replace("/", "__")
            with path.open("xb") as file:
                file.write(raw); file.flush(); os.fsync(file.fileno())
            exact(path, original_sha)
        expected = dict(source)
        for row in bundle["plan"]["changes_in_order"]:
            ownership()
            target = PROJECT / row["target_in_private_project"]
            no_links(target)
            if row["before_must_be_absent"]:
                need(not target.exists(), "New target appeared during mutation")
            else:
                exact(target, row["expected_before_raw_sha256"])
            payload = exact(ROOT / row["payload"]["path"], row["expected_after_raw_sha256"])
            target.parent.mkdir(parents=True, exist_ok=True)
            receipt["mutation_in_progress"] = row["target_in_private_project"]
            save(output / "receipt.json", receipt)
            with target.open("xb" if row["before_must_be_absent"] else "wb") as file:
                file.write(payload); file.flush(); os.fsync(file.fileno())
            exact(target, row["expected_after_raw_sha256"])
            expected[row["target_in_private_project"]] = row["expected_after_raw_sha256"]
            receipt["mutations"].append(row)
            receipt["mutation_in_progress"] = None
            save(output / "receipt.json", receipt)
        need(manifest(PROJECT) == expected, "Unexpected file change during five-file mutation")
        need(manifest(PROJECT / ".godot", exclude_godot=False) == cache, "Cache changed before import")
        save(output / "expected_source_before_import.json", expected)
        setup = output / "setup"
        setup.mkdir()
        env, controls, profile, user = profile_environment(bundle, setup, name)
        save(setup / "configuration.json", {"private_profile": str(profile), "expected_user": str(user), "controlled_environment": controls})
        ownership()
        run_child(bundle, exe, [str(exe), "--headless", "--editor", "--import", "--path", str(PROJECT)], env, setup, args.import_timeout)
        ownership()
        actual_source = manifest(PROJECT)
        actual_cache = manifest(PROJECT / ".godot", exclude_godot=False)
        save(output / "source_after_import.json", actual_source)
        save(output / "cache_after_import.json", actual_cache)
        cache_delta = differences(cache, actual_cache)
        save(output / "import_cache_delta.json", cache_delta)
        additions = set(actual_source) - set(expected)
        uid_allowlist = bundle["plan"]["new_source_uid_allowlist"]
        need(additions == set(uid_allowlist) and len(actual_source) == 3310 and all(actual_source.get(key) == value for key, value in expected.items()), "Import must create exactly two canonical UID paths and preserve all source bytes")
        uid_receipt = {}
        for path in additions:
            need(bundle["launcher"]["generated_uid"]((PROJECT / path).read_bytes()), "Noncanonical generated UID")
            uid_receipt[path] = {"script": uid_allowlist[path], "script_sha256": expected[uid_allowlist[path]], "uid_sha256": actual_source[path]}
        save(output / "new_uid_receipt.json", uid_receipt)
        # No changed asset source exists: compiled resource data must remain exact.
        allowed_metadata = set(bundle["plan"]["allowed_import_cache_delta_paths"])
        need(allowed_metadata == {"uid_cache.bin", "editor/filesystem_cache10"}, "Import metadata allowance drift")
        unexplained = [path for path in cache_delta if path not in allowed_metadata]
        save(output / "import_cache_qualification.json", {"allowed_metadata": sorted(allowed_metadata),
             "unexplained_changes": unexplained, "imported_resource_changes_allowed": False})
        need(not unexplained, "Unexplained import/runtime-resource cache delta; preserve and review it before freeze")
        imported_source, imported_cache = actual_source, actual_cache
        receipt["import_completed"] = True
        receipt["source_files_after_import"] = len(actual_source)
        save(output / "receipt.json", receipt)
        for mode in ("timed", "clockless"):
            runtime_guard("before_" + mode)
            folder = output / mode
            folder.mkdir()
            env, controls, profile, user = profile_environment(bundle, folder, name)
            env.update(CHASE_PATH_MODE=mode, CHASE_PATH_OUT=str(folder / "report.json"),
                       CHASE_PATH_OUTPUT_ROOT=str(folder), CHASE_PATH_USER_ROOT=str(profile))
            save(folder / "configuration.json", {"mode": mode, "seconds": 10, "private_profile": str(profile), "expected_user": str(user),
                 "private_project": str(PROJECT), "controlled_environment": controls, "source_frozen": "source_after_import.json", "pid_scope": receipt["pid_scope"]})
            command = [str(exe), "--path", str(PROJECT), "--rendering-method", "forward_plus", "--rendering-driver", "vulkan", "--script", "res://" + TARGETS[3]]
            process = run_child(bundle, exe, command, env, folder, args.sample_timeout)
            stage = check_runtime_reports(folder, mode, user, process)
            runtime_guard("after_" + mode)
            receipt["stages"].append(stage)
            save(output / "receipt.json", receipt)
        need(len({row["initial_deployment_sha256"] for row in receipt["stages"]}) == 1
             and len({row["input_sha256"] for row in receipt["stages"]}) == 1, "Two initialization/input fingerprints differ")
        receipt["complete"] = True
    except BaseException as error:
        receipt["exception"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        try:
            if live_before is not None:
                receipt["live_after"] = live_source_snapshot(bundle)
                receipt["production_unchanged"] = receipt["live_after"] == live_before
                receipt["production_mutated"] = not receipt["production_unchanged"]
                need(receipt["production_unchanged"], "Live production source changed; lock retained")
            # No automatic restoration. An unqualified import/partial mutation keeps
            # the lock and before copies until the root reviews the exact state.
            need(imported_source is not None and imported_cache is not None, "No qualified new source/cache generation; lock retained")
            runtime_guard("final")
            need(ACTIVE is None or ACTIVE.poll() is not None, "Owned child still alive")
            receipt["protected_player_after"] = player_signature(name)
            need(LOCK.read_text(encoding="utf-8") == token, "Cannot release a different lock owner")
            LOCK.unlink()
            receipt["lock_released"] = True
        except BaseException as error:
            receipt["cleanup_error"] = type(error).__name__ + ": " + str(error)
            receipt["lock_preserved"] = True
            receipt["complete"] = False
        save(output / "receipt.json", receipt)
        print("GENERATION " + str(output), flush=True)
    need(receipt["complete"] and receipt["lock_released"], "Generation did not finish cleanly")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--import-timeout", type=int, default=600)
    parser.add_argument("--sample-timeout", type=int, default=180)
    args = parser.parse_args()
    need(60 <= args.import_timeout <= 600 and 60 <= args.sample_timeout <= 240, "Timeout outside reviewed bound")
    bundle = load_contract()
    if args.run:
        result = run(args, bundle)
        print(json.dumps({"complete": result["complete"], "stages": result["stages"], "full_offline_analysis_pending": True}))
    else:
        print(json.dumps(small_preflight(bundle)))



if __name__ == "__main__":
    main()
