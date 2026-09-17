"""Read-only classic30 archive verification; never imports repository code.

Exit 0 means evidence is consistent, not that gameplay passed. Exit 2 means an
evidence or requested source comparison failed; --require-acceptance uses exit 3
when evidence is consistent but full acceptance has not passed. JSON stdout only.
"""
import argparse
import ast
import hashlib
import json
import math
import re
from pathlib import Path, PurePosixPath

RUN_ID = re.compile(r"[0-9]{8}_[0-9]{6}_[0-9a-f]{8}\Z")
SHA = re.compile(r"[0-9a-f]{64}\Z")
ERROR = re.compile(r"(?m)^(?:SCRIPT ERROR:|ERROR:)|Parse Error|Compile Error|leaked at exit|RID allocations")
FULL = ["import", "profile_guard", "public_gate", "new_economy", "resume_combat",
        "resume_transition", "resume_victory", "terminal_reject_1", "terminal_reject_2"]
DIAG = ["import", "profile_guard", "public_gate", "diagnostic"]
OUTCOMES = {"public_gate": "public_gate_verified", "new_economy": "saved_and_exiting",
            "resume_combat": "saved_and_exiting", "resume_transition": "saved_and_exiting",
            "resume_victory": "natural_victory", "terminal_reject_1": "terminal_refused",
            "terminal_reject_2": "terminal_refused"}


def sha(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def pairs(values):
    result = {}
    for key, value in values:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def decode(text):
    return json.loads(text, object_pairs_hook=pairs,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite JSON")))


def read(path):
    return decode(path.read_text(encoding="utf-8-sig"))


def no_links(path):
    for item in [path, *path.parents]:
        if item.exists() or item.is_symlink():
            if item.is_symlink() or getattr(item.lstat(), "st_file_attributes", 0) & 0x400:
                raise ValueError("link/reparse path refused")


def relative(name):
    if not isinstance(name, str) or not name or "\\" in name or ":" in name:
        raise ValueError("unsafe relative path")
    pure = PurePosixPath(name)
    if pure.is_absolute() or any(part in ("", ".", "..") for part in name.split("/")):
        raise ValueError("unsafe relative path")
    return name


def file_at(base, name):
    result = base / relative(name)
    no_links(result)
    return result


def inventory(base):
    result = set()
    for path in base.rglob("*"):
        no_links(path)
        if path.is_file():
            result.add(path.relative_to(base).as_posix())
    return result


def number(value):
    return not isinstance(value, bool) and isinstance(value, (int, float)) and math.isfinite(value)


def verify(args):
    batch = args.batch.absolute()
    no_links(batch)
    result = {"batch": str(batch), "evidence_consistent": False,
              "gameplay_status": "unknown", "full_acceptance_verified": False,
              "diagnostic_complete_verified": False, "current_source_match": None,
              "private_source_match": None, "checks": 0, "evidence_errors": [],
              "source_comparison_errors": [], "steps": []}

    def check(condition, label):
        result["checks"] += 1
        if not condition:
            result["evidence_errors"].append(label)
        return bool(condition)

    if not RUN_ID.fullmatch(batch.name):
        raise ValueError("explicit batch directory name required")
    manifest = read(file_at(batch, "manifest.json"))
    receipt = read(file_at(batch, "receipt.json"))
    check(manifest.get("schema") == "classic30_attempt_archive_v1", "manifest schema")
    check(receipt.get("schema") == "classic30_acceptance_attempt_v1", "receipt schema")
    check(receipt.get("run_id") == batch.name, "batch/run identity")
    files = manifest["files"]
    check(isinstance(files, dict) and bool(files), "manifest file inventory")
    check(inventory(batch) == set(files) | {"manifest.json"}, "manifest exact complete file set")
    check(len({name.casefold() for name in files}) == len(files), "manifest case-insensitive uniqueness")
    total_bytes = 0
    for name, record in files.items():
        path = file_at(batch, name)
        valid = isinstance(record, dict) and set(record) == {"bytes", "sha256"}
        if not check(valid, "manifest metadata:" + name):
            continue
        check(path.is_file(), "manifest missing:" + name)
        if path.is_file():
            total_bytes += path.stat().st_size
            check(type(record["bytes"]) is int and record["bytes"] == path.stat().st_size,
                  "manifest bytes:" + name)
            check(isinstance(record["sha256"], str) and SHA.fullmatch(record["sha256"])
                  and sha(path) == record["sha256"], "manifest sha:" + name)
    result.update(manifest_entries=len(files), manifest_entry_bytes=total_bytes,
                  manifest_sha256=sha(batch / "manifest.json"), receipt_sha256=sha(batch / "receipt.json"))

    sources = {}
    for entry in receipt["source_files"]:
        name = relative(entry["path"])
        check(name not in sources, "duplicate source:" + name)
        check(isinstance(entry["sha256"], str) and SHA.fullmatch(entry["sha256"]), "source hash grammar:" + name)
        sources[name] = entry["sha256"]
    check(bool(sources), "nonempty frozen sources")
    check(len({name.casefold() for name in sources}) == len(sources), "source case-insensitive uniqueness")
    result["frozen_source_files"] = len(sources)
    # Read only literal lists from the archived runner. Never import/evaluate it.
    runner = file_at(batch, "source_snapshot/tools/run_classic30_continue_acceptance.py.txt")
    declarations = {}
    for node in ast.parse(runner.read_text(encoding="utf-8-sig")).body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in ("OWN", "OBSERVED"):
                    declarations[target.id] = ast.literal_eval(node.value)
    if set(declarations) != {"OWN", "OBSERVED"}:
        raise ValueError("archived runner source inventory declarations missing")
    expected_observed = {relative(name) for names in declarations.values() for name in names}
    expected_snapshots = {"source_snapshot/" + name + ".txt" for name in expected_observed}
    check({name for name in files if name.startswith("source_snapshot/")} == expected_snapshots,
          "source snapshots exact frozen runner inventory")
    observed_hashes = {}
    for name in sorted(expected_observed):
        snapshot = file_at(batch, "source_snapshot/" + name + ".txt")
        if not check(snapshot.is_file() and name in sources, "source snapshot exists:" + name):
            continue
        observed_hashes[name] = sha(snapshot)
        check(observed_hashes[name] == sources[name], "source snapshot frozen hash:" + name)

    diag = receipt.get("diagnostic_seconds", 0)
    plan = DIAG if diag else FULL
    steps = receipt["steps"]
    cases = [step["case"] for step in steps]
    check(cases == plan[:len(cases)], "steps are ordered attempt prefix")
    check(len(cases) == len(set(cases)), "steps unique")
    check(all(receipt.get(k) is False for k in
              ("real_steam", "player_entry_enabled", "human_playtest", "performance_acceptance")),
          "receipt scope remains private automated only")
    reports = {}
    states = {}
    all_step_passed = True
    for step in steps:
        case, pid = step["case"], step["pid"]
        check(case in plan, "known case:" + case)
        check(number(pid) and pid > 0 and int(pid) == pid, "positive process PID:" + case)
        log_file = file_at(batch, case + ".log")
        log = log_file.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in log.splitlines() if ERROR.search(line)]
        check(sha(log_file) == step.get("log_sha256"), "step log hash:" + case)
        check(errors == step.get("errors"), "independent error log inventory:" + case)
        check(type(step.get("exit_code")) is int, "recorded process exit:" + case)
        process_ok = step.get("exit_code") == (2 if case == "profile_guard" else 0)
        process_ok = process_ok and not errors and not step.get("stop_reason")
        row = {"case": case, "pid": pid, "exit_code": step.get("exit_code"),
               "engine_errors": len(errors), "process_expected_result": bool(process_ok)}
        if case in ("import", "profile_guard"):
            if case == "profile_guard":
                process_ok = process_ok and "PRIVATE_PROFILE_REQUIRED" in log
                row["process_expected_result"] = bool(process_ok)
            for suffix in ("_report.json", "_state.json", "_events.jsonl", "_progress.json"):
                check(not (batch / (case + suffix)).exists(), "no unexpected fixture:" + case + suffix)
            row["gameplay_step_passed"] = bool(process_ok)
            all_step_passed = all_step_passed and bool(process_ok)
            result["steps"].append(row)
            continue
        report_file = file_at(batch, case + "_report.json")
        if not report_file.exists():
            # A crash/timeout may legitimately leave no report, but cannot pass.
            check(not process_ok, "normally exited step missing report:" + case)
            row.update(gameplay_step_passed=False, report_missing=True)
            all_step_passed = False
            result["steps"].append(row)
            continue
        report = read(report_file)
        state_file = file_at(batch, case + "_state.json")
        events_file = file_at(batch, case + "_events.jsonl")
        state = read(state_file)
        reports[case] = report
        states[case] = state
        check(report.get("suite") == "classic30-continue-acceptance" and report.get("run_id") == batch.name
              and report.get("case") == case and report.get("pid") == pid, "report PID/case/run:" + case)
        check(state.get("run_id") == batch.name and state.get("pid") == pid, "state PID/run:" + case)
        check(report.get("state_sha256") == sha(state_file) and report.get("events_sha256") == sha(events_file),
              "report/state/events hashes:" + case)
        check(report.get("source_sha256") == observed_hashes, "report exact source snapshot hashes:" + case)
        for field, observed in (("report_sha256", sha(report_file)), ("state_sha256", sha(state_file)),
                                ("outcome", report.get("outcome")), ("report_passed", report.get("passed"))):
            if field in step: check(step[field] == observed, "step/report " + field + ":" + case)
        checks = report.get("checks")
        shape = isinstance(checks, list) and bool(checks) and all(isinstance(c, dict) and
                isinstance(c.get("name"), str) and type(c.get("passed")) is bool for c in checks)
        check(shape, "report checks inventory:" + case)
        failed = [c["name"] for c in checks if not c["passed"]] if shape else ["invalid check inventory"]
        if "failed_checks" in step: check(step["failed_checks"] == failed, "step failed-check inventory:" + case)
        check(not (report.get("passed") is True and failed), "report PASS cannot conceal failed checks:" + case)
        check(all(report.get(k) is False for k in
                  ("real_steam", "player_entry_enabled", "manual_player_test", "performance_acceptance")),
              "report scope private automated only:" + case)
        check(report.get("diagnostic_only") is (case == "diagnostic"), "report diagnostic scope:" + case)
        event_count = 0
        for line in events_file.read_text(encoding="utf-8").splitlines():
            event = decode(line)
            event_count += 1
            check(isinstance(event, dict) and event.get("case") == case and event.get("pid") == pid
                  and isinstance(event.get("kind"), str) and number(event.get("sim_seconds"))
                  and event["sim_seconds"] >= 0, "event identity:" + case + ":" + str(event_count))
        outcome_ok = report.get("outcome") in ["diagnostic_duration_reached", "normal_play_defeat", "natural_victory"] if case == "diagnostic" else report.get("outcome") == OUTCOMES.get(case)
        step_passed = bool(process_ok and shape and not failed and report.get("passed") is True and outcome_ok)
        row.update(outcome=report.get("outcome"), report_passed=report.get("passed"),
                   checks=len(checks) if shape else 0, failed_checks=failed, events=event_count,
                   gameplay_step_passed=step_passed)
        all_step_passed = all_step_passed and step_passed
        result["steps"].append(row)

    # Current/private verification is optional and never opens a receipt-supplied
    # arbitrary path or a player's profile. Known private batch path only.
    if args.current is not None:
        current = args.current.absolute()
        private_run = Path("D:/CodexTemp/classic30_continue") / batch.name
        private = private_run / "project"
        no_links(current); no_links(private)
        result["current_source_match"] = True
        result["private_source_match"] = True
        check(str(receipt.get("run", "")).replace("\\", "/").casefold() == str(private_run).replace("\\", "/").casefold(),
              "receipt fixed private run path")
        for label, base in (("current", current), ("private", private)):
            for name, digest in sources.items():
                path = file_at(base, name)
                if not path.is_file() or sha(path) != digest:
                    result[label + "_source_match"] = False
                    result["source_comparison_errors"].append(label + ":" + name)
        generated = file_at(private, "classic30_acceptance.tscn")
        check(generated.is_file() and sha(generated) == receipt.get("scene_sha256"), "private generated scene hash")
        previous_case = None
        for step in steps:
            case = step["case"]
            control_file = file_at(private_run, case + "_control.json")
            check(control_file.is_file() and sha(control_file) == step.get("control_sha256"), "private control hash:" + case)
            if not control_file.is_file(): continue
            control = read(control_file)
            control_case = "public_gate" if case in ("import", "profile_guard") else case
            check(control.get("run_id") == batch.name and control.get("case") == control_case
                  and control.get("source_sha256") == observed_hashes, "private control identity/sources:" + case)
            for key, suffix in (("report", "_report.json"), ("state", "_state.json"),
                                ("events", "_events.jsonl"), ("progress", "_progress.json")):
                expected_path = private_run / (case + suffix)
                check(str(control.get(key, "")).replace("\\", "/") == str(expected_path).replace("\\", "/"),
                      "private control fixed output:" + case + ":" + key)
                archived = batch / (case + suffix)
                if archived.exists():
                    check(expected_path.is_file() and sha(expected_path) == sha(archived), "private archived output:" + case + ":" + key)
            if previous_case is None:
                check(control.get("previous_state") == "" and control.get("previous_sha256") == "", "first control has no previous state:" + case)
            else:
                expected_previous = private_run / (previous_case + "_state.json")
                check(str(control.get("previous_state", "")).replace("\\", "/") == str(expected_previous).replace("\\", "/")
                      and control.get("previous_sha256") == sha(batch / (previous_case + "_state.json")),
                      "private cross-process previous state chain:" + case)
            if case in reports and case != "public_gate": previous_case = case

    guards_ok = receipt.get("source_guard") is True and receipt.get("player_unchanged") is True
    guards_ok = guards_ok and receipt.get("protected_profile_before_digest") == receipt.get("protected_profile_after_digest")
    guards_ok = guards_ok and receipt.get("lock_released") is True and receipt.get("godot_pids_after") == []
    guards_ok = guards_ok and not receipt.get("guard_failures") and not receipt.get("step_failures")
    diagnostic_pass = bool(diag and cases == DIAG and all_step_passed and guards_ok
                           and reports.get("diagnostic", {}).get("outcome") == "diagnostic_duration_reached"
                           and reports["diagnostic"]["summary"].get("sim_seconds", -1) >= diag)
    full_pass = False
    if not diag and cases == FULL and all_step_passed and guards_ok:
        final = states["terminal_reject_2"]
        waves = final.get("waves", [])
        checkpoints = final.get("checkpoints", [])
        resumes = final.get("resumes", [])
        refusals = final.get("terminal_rejections", [])
        combat = checkpoints[1].get("held_witness", {}) if len(checkpoints) == 3 else {}
        full_pass = bool(final.get("normal_start") is True and final.get("initial_orders_paid") is True
            and final.get("victory") is True and [w.get("wave") for w in waves] == list(range(1, 31))
            and sum(len(w.get("enemy_roster", [])) for w in waves) == 778
            and [c.get("kind") for c in checkpoints] == ["economy", "combat", "wave_transition"]
            and combat.get("enemies", 0) > 0 and combat.get("in_flight", 0) > 0
            and len(resumes) == 3 and all(r.get("from_pid") != r.get("pid") and r.get("differences") == [] for r in resumes)
            and [r.get("case") for r in refusals] == ["terminal_reject_1", "terminal_reject_2"])
    check(not receipt.get("acceptance_passed") or (receipt.get("complete") is True and full_pass), "claimed full acceptance supported")
    check(not receipt.get("diagnostic_complete") or diagnostic_pass, "claimed diagnostic completion supported")
    check(not receipt.get("complete") or (cases == plan and all_step_passed and guards_ok), "claimed completed run supported")
    result["evidence_consistent"] = not result["evidence_errors"]
    result["full_acceptance_verified"] = bool(result["evidence_consistent"] and full_pass and receipt.get("acceptance_passed") is True)
    result["diagnostic_complete_verified"] = bool(result["evidence_consistent"] and diagnostic_pass and receipt.get("diagnostic_complete") is True)
    result["gameplay_status"] = ("full_acceptance_passed" if result["full_acceptance_verified"] else
        "diagnostic_complete_only" if result["diagnostic_complete_verified"] else "failed_or_incomplete")
    result["receipt_claims"] = {k: receipt.get(k) for k in
        ("complete", "acceptance_passed", "diagnostic_complete", "source_guard", "player_unchanged", "failure", "final_guard_failure")}
    result["limits"] = ["Evidence consistency is not gameplay acceptance.",
        "Archived process exit and player digests are recorded evidence, not independently re-executed or re-read player files.",
        "Without --current, private control files and full frozen source copies are not read.",
        "--current checks every receipt-listed source path; it does not execute the historical dynamic source collector.",
        "Full acceptance here is automated classic-only; no Steam, eight missions, human, second Windows or performance claim."]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch", type=Path, help="Explicit completed public archive batch directory")
    parser.add_argument("--current", type=Path, metavar="CHECKOUT", help="Also compare every frozen input in this checkout and fixed D private copy")
    parser.add_argument("--require-acceptance", action="store_true")
    args = parser.parse_args()
    try:
        result = verify(args)
    except (OSError, ValueError, KeyError, TypeError, SyntaxError, IndexError) as exc:
        result = {"evidence_consistent": False, "gameplay_status": "unknown", "full_acceptance_verified": False,
                  "fatal": type(exc).__name__ + ": " + str(exc)}
    print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    if not result["evidence_consistent"] or result.get("source_comparison_errors"):
        return 2
    return 3 if args.require_acceptance and not result["full_acceptance_verified"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
