"""External GameMap behavior QA. Default: bounded read-only preflight.

--run --variant baseline uses the completed 3306-file Unit-body parent.
--run --variant candidate --generation <complete chase generation>
  --baseline-run <complete behavior baseline> uses its 3310-file successor.
No project copy, source write, import, probe-generation run, or implicit restore.
"""
import argparse
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
SELF = Path(__file__).resolve()
CONTRACT = HERE / "runner_contract.json"
HELPER_PATH = ROOT / "scratchpad/chase_path_diag/run_generation.py"
HELPER_SHA = "726f12adaad7ce1942d59fd6d4567b1bd8a4a65f8441d4e5d6ddb849e15766b9"
REUSE_SHA = "b3cfa61bd6a2df02ca89ebd80ad71dd2c6c40a0dda71c2ea5eff4245946bcacc"
QA_SHA = "f567c25a1307049cf13a3208f73ca5df7d5a6b9bd4f9016e24dda9067662aea6"
COMPARE_SHA = "9b1aa9ee32aa6899176672acc71fc67fc2ab0ca0a5a966f6c514f92b8106c6ba"
BEHAVIOR_CONTRACT_SHA = "ef3ce3fb6d8a904185167dfbb0cb5cc2345f4d7deecf1506c906b5bf8302063d"
MAP_RAW = {"baseline": "0f090079229a68269ac94870d1902238444e9ba0ddbc7f359df52f38a4b2db87",
           "candidate": "9145fac5b213ae732fb837f8bd4ecdeccc212b3d39b589798181ad65f6d87122"}
MAP_LF = {"baseline": "35a31084088e8665790b9bc940054d05a96f7e995ecfcd28796d2b6fad63800a",
          "candidate": "cf898e57959412dca0dd3b23de4d9f891bb2859c25cba5df7f63dd0d8f80cc1d"}
STAMP = re.compile(r"\d{8}T\d{12}Z")
LOG_ERROR = re.compile(r"SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b|Parse Error|Unicode parsing error", re.M | re.I)
CASE_IDS = ["strict_same_cell", "strict_outside_start", "strict_reachable", "strict_weighted_detour_faction1",
            "firing_endpoint_reach_reject", "firing_partial_reachable", "firing_one_node_final_empty",
            "firing_zero_reach_guard", "strict_water_reachable"]


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def no_links(path):
    path = Path(path).absolute()
    for item in (path, *path.parents):
        if item.exists() or item.is_symlink():
            stat = item.lstat()
            need(not item.is_symlink() and not getattr(stat, "st_file_attributes", 0) & 0x400,
                 "Link/reparse path refused: " + str(item))


def read(path):
    path = Path(path)
    no_links(path)
    need(path.is_file() and path.stat().st_size <= 16 * 1024 * 1024, "Missing/oversized JSON: " + str(path))

    def unique(pairs):
        result = {}
        for key, value in pairs:
            need(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result

    def nonfinite(value):
        raise RuntimeError("Nonfinite JSON constant: " + value)

    return json.loads(path.read_bytes().decode("utf-8"), object_pairs_hook=unique, parse_constant=nonfinite)


def save(path, value):
    no_links(path)
    Path(path).write_bytes((json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2) + "\n").encode("utf-8"))


def exact(path, expected):
    no_links(path)
    need(Path(path).is_file(), "Frozen file missing: " + str(path))
    raw = Path(path).read_bytes()
    need(sha(raw) == expected, "Frozen file changed: " + str(path))
    return raw


def module(path, raw):
    namespace = {"__file__": str(path), "__name__": "chase_behavior_readonly_helper"}
    exec(compile(raw.decode("utf-8-sig"), str(path), "exec"), namespace)
    return namespace


def selected_directory(value, parent, label):
    need(value is not None, label + " must be explicitly selected")
    path = Path(value)
    need(path.is_absolute(), label + " must use an absolute path")
    no_links(path)
    path = path.resolve()
    need(path.is_dir() and path.parent == parent.resolve() and STAMP.fullmatch(path.name),
         label + " is not a direct completed-run directory")
    return path


def load_tools():
    contract = read(CONTRACT)
    need(type(contract.get("schema")) is int and contract["schema"] == 1
         and contract.get("helper_raw_sha256") == HELPER_SHA
         and contract.get("reuse_contract_raw_sha256") == REUSE_SHA
         and contract.get("behavior_sources") == {"qa.gd": QA_SHA, "compare.py": COMPARE_SHA}, "Behavior runner contract changed")
    frozen = {SELF: contract["runner_raw_sha256"], CONTRACT: sha(CONTRACT.read_bytes()),
              HELPER_PATH: HELPER_SHA, HELPER_PATH.with_name("reuse_contract.json"): REUSE_SHA,
              HERE / "behavior_contract.json": BEHAVIOR_CONTRACT_SHA}
    for name, expected in contract["behavior_sources"].items():
        path = HERE / name
        need(path.resolve().parent == HERE.resolve(), "Behavior source must be a direct file")
        frozen[path] = expected
    need(set(contract["behavior_sources"]) == {"qa.gd", "compare.py"}, "Exact external QA/comparer source set required")
    for path, expected in frozen.items():
        exact(path, expected)
    helper = module(HELPER_PATH, exact(HELPER_PATH, HELPER_SHA))
    bundle = helper["load_contract"]()
    need(bundle["plan"]["parent_source_count"] == 3306 and len(bundle["parent_source"]) == 3306
         and len(bundle["parent_cache"]) == 2376, "Wrong completed baseline parent")
    need(bundle["parent_source"]["scripts/game_map.gd"] == MAP_RAW["baseline"], "Wrong baseline Map")
    compare = module(HERE / "compare.py", exact(HERE / "compare.py", contract["behavior_sources"]["compare.py"]))
    return {"contract": contract, "frozen": frozen, "helper": helper, "bundle": bundle, "compare": compare}


def verify_tools(tools):
    for path, expected in tools["frozen"].items():
        exact(path, expected)
    tools["helper"]["check_frozen"](tools["bundle"])


def validate_candidate_metadata(receipt, source, cache, bundle, project, generation):
    """Pure metadata validation; deliberately usable by synthetic refusal fixtures."""
    need(all(receipt.get(key) is True for key in ("complete", "lock_released", "production_unchanged", "import_completed",
                                                "full_parent_source_verified", "full_parent_cache_verified")),
         "Candidate generation is incomplete or unqualified")
    need(receipt.get("production_mutated") is False and receipt.get("new_project_copied") is False
         and receipt.get("production_write_operations") == [] and receipt.get("mutation_in_progress") is None,
         "Candidate generation mutation boundary changed")
    need(receipt.get("generation") == generation.name and Path(receipt["private_project"]).resolve() == project.resolve()
         and Path(receipt["parent_generation"]).resolve() == (ROOT / bundle["plan"]["parent_generation"]).resolve(),
         "Candidate project/parent identity mismatch")
    need(receipt.get("engine_raw_sha256") == bundle["plan"]["engine_raw_sha256"]
         and receipt.get("mutations") == bundle["plan"]["changes_in_order"], "Candidate source/engine lineage differs")
    expected = dict(bundle["parent_source"])
    for change in bundle["plan"]["changes_in_order"]:
        name = change["target_in_private_project"]
        need(expected.get(name) == change["expected_before_raw_sha256"], "Candidate sequential source lineage broke")
        expected[name] = change["expected_after_raw_sha256"]
    uid_names = set(bundle["plan"]["new_source_uid_allowlist"])
    need(type(source) is dict and len(source) == receipt.get("source_files_after_import") == 3310
         and set(source) - set(expected) == uid_names and all(source.get(k) == v for k, v in expected.items())
         and source["scripts/game_map.gd"] == MAP_RAW["candidate"], "Candidate final source is not the exact 3310-file generation")
    need(type(cache) is dict and len(cache) == len(bundle["parent_cache"]), "Candidate cache path count changed")
    delta = tools_difference(bundle["parent_cache"], cache)
    need(set(delta) <= {"uid_cache.bin", "editor/filesystem_cache10"}, "Candidate cache differs outside reviewed import metadata")
    stages = receipt.get("stages")
    need(type(stages) is list and [x.get("mode") for x in stages] == ["timed", "clockless"]
         and all(x.get("basic_report_valid") is True and x.get("exit_code") == 0
                 and type(x.get("process_id")) is int and x["process_id"] > 0 for x in stages),
         "Candidate must complete both original rendered diagnostic modes")
    need(receipt.get("live_before") == receipt.get("live_after") and type(receipt.get("live_before")) is dict
         and set(receipt["live_before"]) == set(bundle["plan"]["live_guard_keys"])
         and receipt.get("protected_player_before") == receipt.get("protected_player_after")
         and set(receipt.get("protected_player_before", {})) == {"settings.cfg", "campaign.cfg", "screen.cfg"},
         "Candidate live/player final guards incomplete")


def tools_difference(before, after):
    return {key: {"before": before.get(key), "after": after.get(key)}
            for key in sorted(set(before) | set(after)) if before.get(key) != after.get(key)}


def candidate_parent(tools, value):
    helper, bundle = tools["helper"], tools["bundle"]
    parent = selected_directory(value, HELPER_PATH.parent / "generations", "Candidate generation")
    project = helper["PROJECT"]
    receipt, source, cache = (read(parent / name) for name in ("receipt.json", "final_source.json", "final_cache.json"))
    validate_candidate_metadata(receipt, source, cache, bundle, project, parent)
    runner_sources = read(parent / "runner_sources.json")
    need(runner_sources.get(HELPER_PATH.relative_to(ROOT).as_posix()) == HELPER_SHA, "Candidate did not use the frozen generation runner")
    need(read(parent / "source_after_import.json") == source and read(parent / "cache_after_import.json") == cache,
         "Candidate final source/cache drift from qualified import")
    uid_receipt = read(parent / "new_uid_receipt.json")
    need(set(uid_receipt) == set(bundle["plan"]["new_source_uid_allowlist"]), "Candidate UID receipt incomplete")
    for name, script in bundle["plan"]["new_source_uid_allowlist"].items():
        raw = exact(project / name, source[name])
        need(bundle["launcher"]["generated_uid"](raw) and uid_receipt[name]
             == {"script": script, "script_sha256": source[script], "uid_sha256": source[name]}, "Candidate canonical UID mismatch")
    for stage in receipt["stages"]:
        folder = parent / stage["mode"]
        process = read(folder / "process_receipt.json")
        need(process.get("child_exit_confirmed") is True and process.get("child_pid") == stage["process_id"]
             and process.get("exit_code") == 0 and process.get("timed_out") is False
             and process.get("exception") is None and process.get("cleanup_error") is None
             and process.get("log_decoding_error") is None and process.get("matched_errors") == [],
             "Candidate process receipt incomplete")
        exact(folder / "report.json", stage["sidecar_raw_sha256"])
        exact(folder / "m1_10s.json", stage["m1_raw_sha256"])
        exact(folder / "process.log", process["log_raw_sha256"])
        for name in ("process_receipt.json", "process.log", "report.json", "m1_10s.json"):
            tools["frozen"][folder / name] = sha((folder / name).read_bytes())
    for name in ("receipt.json", "final_source.json", "final_cache.json", "source_after_import.json", "cache_after_import.json",
                 "runner_sources.json", "new_uid_receipt.json"):
        tools["frozen"][parent / name] = sha((parent / name).read_bytes())
    return parent, source, cache


def validate_report(report, variant, process, expected_user, project, qa_path, qa_sha):
    need(type(report) is dict and type(report.get("schema")) is int and report["schema"] == 1
         and report.get("variant") == variant and report.get("complete") is True
         and report.get("failures") == [], "Behavior report incomplete or wrong variant")
    need(type(report.get("pid")) is int and report["pid"] == process["child_pid"], "Actual GD/Popen PID mismatch")
    need(Path(report["actual_user_dir"]).resolve() == expected_user.resolve()
         and Path(report["project_root"]).resolve() == project.resolve(), "Behavior user/project path mismatch")
    need(Path(report["qa_script_path"]).resolve() == qa_path.resolve()
         and report.get("qa_script_raw_sha256") == qa_sha, "External QA script identity mismatch")
    need(report.get("map_source_before") == report.get("map_source_after") == MAP_RAW[variant]
         and report.get("map_script_lf_sha256") == MAP_LF[variant], "Actual loaded GameMap source mismatch")
    need(type(report.get("checks")) is int and report["checks"] == (55 if variant == "baseline" else 88),
         "Incomplete behavior QA check sequence")
    need(type(report.get("cases")) is list and len(report["cases"]) == 9
         and sum(len(row.get("calls", [])) for row in report["cases"]) == 13
         and all(row.get("map_freed") is True for row in report["cases"]), "Exact nine cases/thirteen original calls or map release missing")
    need([row.get("spec", {}).get("id") for row in report["cases"]] == CASE_IDS, "Behavior case order/set changed")
    for row in report["cases"]:
        spec = row["spec"]
        expected_methods = ["find_path", "find_firing_path"] if spec["id"].startswith("firing_") else ["find_path"]
        need([call.get("method") for call in row["calls"]] == expected_methods, "Original strict/fallback call order changed")
        need(type(row.get("navigation_before")) is dict and row["navigation_before"] == row.get("navigation_after")
             and bool(row["navigation_before"].get("variant_bytes_hex")), "Navigation inputs changed or missing")
        for call in row["calls"]:
            need(type(call.get("variant_type")) is int and call["variant_type"] == 35
                 and type(call.get("size")) is int and type(call.get("points")) is list
                 and 0 <= call["size"] == len(call["points"]) <= 1024
                 and all(type(point) is list and len(point) == 2
                         and all(type(v) in (int, float) for v in point) for point in call["points"])
                 and type(call.get("variant_bytes_hex")) is str
                 and re.fullmatch(r"(?:[0-9a-f]{2})+", call["variant_bytes_hex"]), "Packed path evidence malformed")
            if variant == "baseline":
                need(call.get("ledger_after_call") is None, "Baseline unexpectedly contains observer data")
    need(report.get("stub_cases") == [] and report.get("unit_do_chase_state_equivalence") is False
         and report.get("performance_claim") is False and type(report.get("uncovered_real_branches")) is list
         and len(report["uncovered_real_branches"]) == 2, "Behavior scope or unhit branches changed")
    need(type(report.get("godot")) is dict and all(type(report["godot"].get(key)) is int for key in ("major", "minor", "patch"))
         and [report["godot"][key] for key in ("major", "minor", "patch")] == [4, 6, 3], "Actual engine version mismatch")
    return {"actual_gd_pid": report["pid"], "gd_pid_matches_owned_popen": True, "checks": report["checks"],
            "cases": 9, "original_navigation_calls": 13, "unit_do_chase_state_equivalence": False}


def baseline_reference(tools, value):
    folder = selected_directory(value, HERE / "runs", "Completed behavior baseline")
    receipt = read(folder / "receipt.json")
    need(receipt.get("complete") is True and receipt.get("lock_released") is True
         and receipt.get("variant") == "baseline" and receipt.get("source_unchanged") is True
         and receipt.get("cache_unchanged") is True and receipt.get("production_unchanged") is True
         and receipt.get("private_project_mutated") is False and receipt.get("report_valid") is True,
         "Behavior baseline is incomplete or unqualified")
    need(receipt.get("runner_contract_raw_sha256") == tools["frozen"][CONTRACT]
         and receipt.get("runner_raw_sha256") == tools["frozen"][SELF], "Baseline used another runner contract")
    need(receipt.get("full_parent_source_verified") is True and receipt.get("full_parent_cache_verified") is True
         and receipt.get("live_before") == receipt.get("live_after")
         and set(receipt.get("live_before", {})) == set(tools["bundle"]["plan"]["live_guard_keys"])
         and receipt.get("protected_player_before") == receipt.get("protected_player_after")
         and set(receipt.get("protected_player_before", {})) == {"settings.cfg", "campaign.cfg", "screen.cfg"},
         "Baseline root/player guard evidence incomplete")
    need(Path(receipt["parent_generation"]).resolve() == tools["helper"]["PARENT"].resolve(), "Baseline parent lineage differs")
    for stage in ("before", "after", "final"):
        need(read(folder / (stage + "_source.json")) == tools["bundle"]["parent_source"]
             and read(folder / (stage + "_cache.json")) == tools["bundle"]["parent_cache"], "Baseline full source/cache differs from original completed parent")
    report = read(folder / "report.json")
    process = read(folder / "process_receipt.json")
    manifest = read(folder / "execution_manifest.json")
    need(process.get("child_exit_confirmed") is True and process.get("exit_code") == 0
         and process.get("qa_pid_match_verified") is True and process.get("timed_out") is False
         and process.get("matched_errors") == [] and process.get("log_decoding_error") is None
         and process.get("exception") is None and process.get("cleanup_error") is None, "Baseline process incomplete")
    exact(folder / "report.json", receipt["report_raw_sha256"])
    exact(folder / "execution_manifest.json", receipt["execution_manifest_raw_sha256"])
    exact(folder / "process.log", process["log_raw_sha256"])
    validate_report(report, "baseline", process, Path(manifest["private_user"]), tools["helper"]["PROJECT"],
                    HERE / "qa.gd", tools["contract"]["behavior_sources"]["qa.gd"])
    for name in ("receipt.json", "report.json", "execution_manifest.json", "process_receipt.json", "process.log",
                 "before_source.json", "before_cache.json", "after_source.json", "after_cache.json", "final_source.json", "final_cache.json"):
        tools["frozen"][folder / name] = sha((folder / name).read_bytes())
    return folder, report


def prepare_selection(args, tools):
    need(args.variant in ("baseline", "candidate"), "Unknown behavior variant")
    if args.variant == "baseline":
        need(args.generation is None and args.baseline_run is None, "Baseline cannot select a candidate generation/reference")
        return {"parent": tools["helper"]["PARENT"], "source": tools["bundle"]["parent_source"],
                "cache": tools["bundle"]["parent_cache"], "baseline_folder": None, "baseline_report": None}
    parent, source, cache = candidate_parent(tools, args.generation)
    baseline, report = baseline_reference(tools, args.baseline_run)
    return {"parent": parent, "source": source, "cache": cache, "baseline_folder": baseline, "baseline_report": report}


def small_preflight(args, tools, selection):
    verify_tools(tools)
    project = tools["helper"]["PROJECT"]
    names = set(tools["bundle"]["plan"]["small_private_source_checks"])
    names.add("tools/run_polish_performance.py")
    if args.variant == "candidate":
        names.update(row["target_in_private_project"] for row in tools["bundle"]["plan"]["changes_in_order"])
        names.update(tools["bundle"]["plan"]["new_source_uid_allowlist"])
    byte_count = 0
    for name in sorted(names):
        byte_count += len(exact(project / name, selection["source"][name]))
    need(selection["source"]["scripts/game_map.gd"] == MAP_RAW[args.variant], "Selected Map variant mismatch")
    verify_tools(tools)
    return {"schema": 1, "preflight": True, "variant": args.variant, "read_only": True,
            "parent_generation": str(selection["parent"]), "recorded_source_files": len(selection["source"]),
            "recorded_cache_files": len(selection["cache"]), "small_private_source_files": len(names),
            "small_private_source_bytes": byte_count, "whole_current_project_or_cache_hashed": False,
            "full_audit_required_under_run_lock": True, "godot_run": False, "private_project_mutated": False,
            "external_script": str(HERE / "qa.gd"), "script_copied_to_private_project": False}


def annotate_process(output, pid_verified):
    path = output / "process_receipt.json"
    if not path.is_file():
        return
    process = read(path)
    original = process.get("borrowed_helper_pid_evidence", process.get("pid_evidence"))
    process.update(borrowed_helper_pid_evidence=original, borrowed_helper_raw_sha256=HELPER_SHA,
                   pid_evidence="Owned non-console Popen handle; this external behavior QA also self-reports OS.get_process_id(). See qa_pid_match_verified.",
                   qa_pid_match_verified=pid_verified,
                   pid_scope_note="Borrowed helper text describes its older diagnostic GD. It does not describe this external QA; only this new process receipt is annotated.")
    save(path, process)


def run(args, tools, selection):
    need(os.name == "nt", "Private APPDATA/non-console exe contract is Windows-only")
    helper, bundle = tools["helper"], tools["bundle"]
    project, lock, safe = helper["PROJECT"], helper["LOCK"], bundle["safe"]
    need(project.resolve() not in (HERE / "qa.gd").resolve().parents, "QA script must remain external to private project")
    exe = Path(safe["resolve_godot"](args.godot))
    no_links(exe)
    need(exe.suffix.lower() == ".exe" and not re.search(r"[._-]console\.exe$", exe.name, re.I), "Actual non-console exe required")
    engine_sha = sha(exe.read_bytes())
    need(engine_sha == bundle["plan"]["engine_raw_sha256"], "Wrong engine bytes")
    verify_tools(tools)
    safe["require_exclusive_godot"]()
    no_links(lock)
    need(not lock.exists(), "Shared Godot/source lock occupied")
    output = HERE / "runs" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    no_links(output)
    output.mkdir(parents=True, exist_ok=False)
    token = str(os.getpid()) + "|" + str(output)
    with lock.open("x", encoding="utf-8") as stream:
        stream.write(token)
    name = None
    live_before = player_before = None
    full_before_verified = False
    receipt = {"schema": 1, "variant": args.variant, "run_id": output.name, "complete": False, "lock_released": False,
               "godot_run": False, "private_project": str(project), "parent_generation": str(selection["parent"]),
               "baseline_run": str(selection["baseline_folder"]) if selection["baseline_folder"] else None,
               "private_project_mutated": None, "source_write_operations": [], "project_copy": False, "import_run": False,
               "production_unchanged": None, "runner_raw_sha256": tools["frozen"][SELF],
               "runner_contract_raw_sha256": tools["frozen"][CONTRACT], "borrowed_helper_raw_sha256": HELPER_SHA,
               "engine_raw_sha256": engine_sha, "report_valid": False, "performance_claim": False,
               "unit_do_chase_state_equivalence": False}
    save(output / "receipt.json", receipt)

    def ownership():
        need(lock.is_file() and lock.read_text("utf-8") == token, "Shared lock ownership changed")
        safe["require_exclusive_godot"]()
        verify_tools(tools)
        if live_before is not None:
            need(helper["live_source_snapshot"](bundle) == live_before, "Root 11-source guard drift")
        if player_before is not None:
            need(helper["player_signature"](name) == player_before, "Protected player signature drift")

    def full_guard(stage):
        ownership()
        source = bundle["launcher"]["manifest"](project)
        cache = bundle["launcher"]["manifest"](project / ".godot", exclude_godot=False)
        save(output / (stage + "_source.json"), source)
        save(output / (stage + "_cache.json"), cache)
        save(output / (stage + "_source_delta.json"), tools_difference(selection["source"], source))
        save(output / (stage + "_cache_delta.json"), tools_difference(selection["cache"], cache))
        receipt["source_matches_parent"] = source == selection["source"]
        receipt["cache_matches_parent"] = cache == selection["cache"]
        if full_before_verified:
            receipt["source_unchanged"] = receipt["source_matches_parent"]
            receipt["cache_unchanged"] = receipt["cache_matches_parent"]
            receipt["private_project_mutated"] = not (receipt["source_unchanged"] and receipt["cache_unchanged"])
        need(source == selection["source"], "Private source/UID/path differs from completed parent")
        need(cache == selection["cache"], "Private cache differs from completed parent; no cache mutation is allowed")
        return source, cache

    try:
        ownership()
        name = helper["project_name"]()
        live_before = helper["live_source_snapshot"](bundle)
        player_before = helper["player_signature"](name)
        need(len(live_before) == 11 and len(player_before) == 3, "Root/player guard width changed")
        receipt.update(live_before=live_before, protected_player_before=player_before)
        source, cache = full_guard("before")
        full_before_verified = True
        receipt.update(full_parent_source_verified=True, full_parent_cache_verified=True,
                       source_files=len(source), cache_files=len(cache))
        save(output / "runner_sources.json", {p.relative_to(ROOT).as_posix(): expected for p, expected in tools["frozen"].items()})
        env, controls, profile, user = helper["profile_environment"](bundle, output, name)
        for key in list(env):
            if key.startswith(("CHASE_BEHAVIOR_", "UNIT_REFERENCES_", "INVENTORY_QA_")):
                env.pop(key)
        env.update(CHASE_BEHAVIOR_VARIANT=args.variant, CHASE_BEHAVIOR_OUT=str(output / "report.json"),
                   CHASE_BEHAVIOR_USER_ROOT=str(profile), CHASE_BEHAVIOR_OUTPUT_ROOT=str(output), QA_ONLY="1")
        qa_path = HERE / "qa.gd"
        manifest = {"schema": 1, "run_id": output.name, "variant": args.variant, "project": str(project),
                    "parent_generation": str(selection["parent"]), "report": str(output / "report.json"),
                    "private_profile": str(profile), "private_user": str(user), "qa_script_path": str(qa_path),
                    "qa_script_raw_sha256": tools["contract"]["behavior_sources"]["qa.gd"],
                    "map_raw_sha256": MAP_RAW[args.variant], "map_lf_sha256": MAP_LF[args.variant],
                    "source_files": len(source), "cache_files": len(cache), "controlled_environment": controls,
                    "private_environment": {key: env[key] for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP")},
                    "qa_environment": {key: env[key] for key in ("CHASE_BEHAVIOR_VARIANT", "CHASE_BEHAVIOR_OUT", "CHASE_BEHAVIOR_USER_ROOT", "CHASE_BEHAVIOR_OUTPUT_ROOT")},
                    "baseline_run": receipt["baseline_run"],
                    "baseline_report_raw_sha256": sha((selection["baseline_folder"] / "report.json").read_bytes()) if selection["baseline_folder"] else None}
        save(output / "execution_manifest.json", manifest)
        receipt["execution_manifest_raw_sha256"] = sha((output / "execution_manifest.json").read_bytes())
        save(output / "receipt.json", receipt)
        ownership()
        process = helper["run_child"](bundle, exe, [str(exe), "--headless", "--path", str(project), "--script", str(qa_path)], env, output, args.timeout)
        receipt["godot_run"] = True
        exact(output / "execution_manifest.json", receipt["execution_manifest_raw_sha256"])
        path = output / "report.json"
        no_links(path)
        need(path.is_file() and path.stat().st_mtime_ns >= process["launched_time_ns"] - 1000000000, "Missing/stale behavior sidecar")
        report = read(path)
        counts = validate_report(report, args.variant, process, user, project, qa_path, manifest["qa_script_raw_sha256"])
        text = exact(output / "process.log", process["log_raw_sha256"]).decode("utf-8", errors="strict")
        need(not LOG_ERROR.search(text), "Behavior strict stdout diagnostics")
        summaries = [json.loads(line[len("[chase-path-behavior] "):]) for line in text.splitlines() if line.startswith("[chase-path-behavior] ")]
        need(len(summaries) == 1 and summaries[0] == {"variant": args.variant, "complete": True, "checks": report["checks"],
                                                     "failures": 0, "cases": 9, "pid": process["child_pid"]}, "Behavior stdout/sidecar mismatch")
        annotate_process(output, True)
        receipt.update(report_valid=True, report_raw_sha256=sha(path.read_bytes()), process_id=process["child_pid"], exit_code=0, **counts)
        if args.variant == "candidate":
            comparison = tools["compare"]["compare_reports"](selection["baseline_report"], report)
            comparison["source_report_sha256"] = {"baseline": manifest["baseline_report_raw_sha256"],
                                                   "candidate": receipt["report_raw_sha256"]}
            comparison["comparator_raw_sha256"] = tools["contract"]["behavior_sources"]["compare.py"]
            save(output / "comparison.json", comparison)
            receipt.update(comparison_valid=comparison.get("comparison_valid") is True,
                           comparison_raw_sha256=sha((output / "comparison.json").read_bytes()))
            need(receipt["comparison_valid"], "Offline baseline/candidate behavior comparison failed")
        full_guard("after")
        receipt["complete"] = True
    except BaseException as error:
        receipt["exception"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        try:
            process_path = output / "process_receipt.json"
            if process_path.is_file():
                annotate_process(output, receipt["report_valid"])
                receipt["godot_run"] = read(process_path).get("child_pid") is not None
            need(full_before_verified, "No verified parent preimage; retain lock")
            full_guard("final")
            receipt.update(source_unchanged=True, cache_unchanged=True,
                           live_after=helper["live_source_snapshot"](bundle), protected_player_after=helper["player_signature"](name))
            receipt["production_unchanged"] = receipt["live_after"] == live_before
            need(receipt["production_unchanged"] and receipt["protected_player_after"] == player_before, "Live/player final guard failed")
            active = helper.get("ACTIVE")
            need(active is None or active.poll() is not None, "Owned child still alive")
            need(sha(exe.read_bytes()) == engine_sha, "Engine bytes changed")
            need(lock.read_text("utf-8") == token, "Cannot release another owner's lock")
            lock.unlink()
            receipt["lock_released"] = True
        except BaseException as error:
            receipt.update(complete=False, cleanup_error=type(error).__name__ + ": " + str(error), lock_preserved=True)
        save(output / "receipt.json", receipt)
        print("BEHAVIOR_RUN " + str(output), flush=True)
    need(receipt["complete"] and receipt["lock_released"], "Behavior QA did not finish cleanly")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--variant", choices=("baseline", "candidate"), default="baseline")
    parser.add_argument("--generation")
    parser.add_argument("--baseline-run")
    parser.add_argument("--godot")
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()
    need(30 <= args.timeout <= 180, "Timeout outside reviewed bound")
    tools = load_tools()
    selection = prepare_selection(args, tools)
    result = run(args, tools, selection) if args.run else small_preflight(args, tools, selection)
    print(json.dumps(result if not args.run else {"complete": result["complete"], "variant": result["variant"],
                                                "checks": result["checks"], "lock_released": result["lock_released"]}))


if __name__ == "__main__":
    main()
