"""Run 30 synthetic, no-engine process-identity contract checks.

Run with: py -3.14 -X utf8 -B qa/continue_flow_20260909/process_identity_contract_test.py
Only process_identity_contract_test.json beside this script is written. Native
receipts are neither read nor changed, and these checks are not gameplay QA.
"""
import copy
from datetime import datetime, timezone
import hashlib
import inspect
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from validate_evidence import validate_process_identity


FULL_CASES = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle", "unsaved_terminal",
              "capture", "restore_and_overwrite", "restore_again", "pending_retry", "held_error",
              "terminal", "terminal_reject"]
FOCUSED_CASES = ["import", "profile_guard", "public_gate", "no_slot", "lifecycle", "unsaved_terminal",
                 "capture", "terminal", "terminal_reject"]


def fixture(focused=False):
    """Invent serial runs that all reuse one PID; no actual process is created."""
    cases = FOCUSED_CASES if focused else FULL_CASES
    steps = [{"case": case, "pid": 43248, "process_nonce": format(i + 1, "032x"),
              "started_ns": i * 100 + 10, "finished_ns": i * 100 + 90}
             for i, case in enumerate(cases)]
    reports = [{key: step[key] for key in ("case", "pid", "process_nonce")} for step in steps[2:]]
    receipt = {"process_identity_schema": "continue_flow_process_identity_v2",
               "terminal_only": focused, "cases": cases.copy(), "steps": steps,
               "process_runs": copy.deepcopy(steps[2:]), "processes": [step["pid"] for step in steps[2:]]}
    return receipt, reports


def main():
    if not __debug__:
        raise SystemExit("Assertions are required; run Python without -O or -OO.")
    checks = []

    def check(name, receipt, reports, expected_exception=None):
        row = {"name": name, "expected": "accept" if expected_exception is None else "reject",
               "expected_exception": None if expected_exception is None else expected_exception.__name__}
        try:
            validate_process_identity(receipt, reports)
        except Exception as exc:
            row.update(observed="reject", exception=type(exc).__name__, detail=str(exc),
                       passed=expected_exception is not None and type(exc) is expected_exception)
        else:
            row.update(observed="accept", passed=expected_exception is None)
        checks.append(row)

    def reject(name, mutate, expected_exception=AssertionError):
        receipt, reports = fixture()
        mutate(receipt, reports)
        check(name, receipt, reports, expected_exception)

    for focused in (False, True):
        receipt, reports = fixture(focused)
        check(("focused" if focused else "full") + "_reused_pid_pass", receipt, reports)

    reject("unknown_schema", lambda r, p: r.update(process_identity_schema="unknown"))
    reject("null_schema", lambda r, p: r.update(process_identity_schema=None))
    reject("terminal_flag_int", lambda r, p: r.update(terminal_only=0))
    reject("terminal_flag_missing", lambda r, p: r.pop("terminal_only"), KeyError)
    reject("full_marked_focused", lambda r, p: r.update(terminal_only=True))
    reject("missing_import", lambda r, p: (r["steps"].pop(0), r["cases"].pop(0)))
    reject("step_order", lambda r, p: r["steps"].__setitem__(slice(0, 2), list(reversed(r["steps"][:2]))))
    reject("nonce_duplicate", lambda r, p: r["steps"][1].update(process_nonce=r["steps"][0]["process_nonce"]))
    reject("nonce_short", lambda r, p: r["steps"][0].update(process_nonce="a" * 31))
    reject("nonce_nonhex", lambda r, p: r["steps"][0].update(process_nonce="g" * 32))
    reject("nonce_type", lambda r, p: r["steps"][0].update(process_nonce=1))
    reject("pid_bool", lambda r, p: r["steps"][0].update(pid=True))
    reject("pid_zero", lambda r, p: r["steps"][0].update(pid=0))
    reject("timestamp_float", lambda r, p: r["steps"][0].update(started_ns=10.0))
    reject("zero_duration", lambda r, p: r["steps"][0].update(finished_ns=10))
    reject("overlapping_steps", lambda r, p: r["steps"][1].update(started_ns=89))
    reject("report_case", lambda r, p: p[0].update(case="other"))
    reject("report_pid", lambda r, p: p[0].update(pid=123))
    reject("report_float_pid", lambda r, p: p[0].update(pid=43248.0))
    reject("report_nonce", lambda r, p: p[0].update(process_nonce="f" * 32))
    reject("projection_missing", lambda r, p: r["process_runs"].pop())
    reject("projection_extra_field", lambda r, p: r["process_runs"][0].update(extra=1))
    reject("projection_changed", lambda r, p: r["process_runs"][0].update(finished_ns=1))
    reject("projection_float", lambda r, p: r["process_runs"][0].update(pid=43248.0))
    reject("pid_list_order_or_value", lambda r, p: r["processes"].__setitem__(0, 123))
    reject("pid_list_float", lambda r, p: r["processes"].__setitem__(0, 43248.0))

    receipt, reports = fixture()
    receipt.pop("process_identity_schema")
    check("legacy_reused_pid_rejected", receipt, reports, AssertionError)
    receipt, reports = fixture()
    receipt.pop("process_identity_schema")
    for i, report in enumerate(reports):
        report["pid"] = i + 1
    receipt["processes"] = [report["pid"] for report in reports]
    check("legacy_unique_pid_pass", receipt, reports)

    script = Path(__file__).resolve()
    validator = script.with_name("validate_evidence.py")
    report = {
        "schema": "continue_flow_process_identity_contract_test_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "Synthetic process-identity validator contract only; independent of native 295 gameplay checks",
        "synthetic": True, "no_engine": True, "engine_rerun": False,
        "actual_child_processes_started": 0, "native_receipts_read_or_changed": False,
        "gameplay_acceptance": False, "native_gameplay_checks_added": 0,
        "full_30_waves": False, "real_steam": False,
        "passed": len(checks) == 30 and all(row["passed"] for row in checks),
        "check_count": len(checks), "passed_count": sum(row["passed"] for row in checks),
        "source_sha256": {
            script.name: hashlib.sha256(script.read_bytes()).hexdigest(),
            validator.name: hashlib.sha256(validator.read_bytes()).hexdigest(),
        },
        "validator_function_sha256": hashlib.sha256(
            inspect.getsource(validate_process_identity).encode("utf-8")).hexdigest(),
        "checks": checks,
    }
    output = script.with_suffix(".json")
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "checks": len(checks), "synthetic": True,
                      "no_engine": True, "native_gameplay_checks_added": 0, "report": str(output)}))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
