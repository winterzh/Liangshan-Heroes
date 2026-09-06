"""DRAFT: prepare or explicitly run counter-only redraw-rejection diagnostics.

Default: prepare generated artifacts only. --apply temporarily instruments Unit.
--run-state-qa runs only the generated helper-state comparison, without source edits.
No benchmark/FPS conclusion is produced. Run only in an exclusive Godot time slot.
"""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
UNIT = ROOT / "scripts/unit.gd"
META = "_redraw_rejection_diagnostic"
NAMES = ("_queue_animated_redraw", "_queue_motion_redraw")
ACTIVE_GODOT_PROCESS = None
CHILD_EXIT_TIMEOUT = 30
ERROR = re.compile(r"SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b", re.M)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def lf(raw):
    return raw.replace(b"\r\n", b"\n")


def save_json(path, data):
    path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def function_span(raw, name):
    start = re.search(rb"(?m)^func " + re.escape(name.encode()) + rb"\(", raw)
    if start is None:
        raise RuntimeError("Required function missing: " + name)
    following = re.search(rb"(?m)^func ", raw[start.end():])
    end = start.end() + following.start() if following else len(raw)
    return start.start(), end


def function_text(raw, name):
    begin, end = function_span(raw, name)
    return lf(raw[begin:end]).decode("utf-8").rstrip() + "\n"


def validate_pins(pins):
    for name, expected in pins["locked_lf_sha256"].items():
        path = ROOT / name
        if not path.is_file() or sha(lf(path.read_bytes())) != expected:
            raise RuntimeError("Draft pins are stale; review and regenerate pins before use: " + name)
    for name in NAMES:
        actual = sha(function_text(UNIT.read_bytes(), name).encode())
        if actual != pins["method_sha256"][name]:
            raise RuntimeError("Frozen method changed: " + name)


def mark_line(key, indent):
    return indent + 'if not __rd.is_empty(): __rd["%s"] = int(__rd.get("%s", 0)) + 1' % (key, key)


def instrument_method(original, name):
    kind = "animated" if name == NAMES[0] else "motion"
    lines = original.rstrip().splitlines()
    preamble = [
        '\t# TEMPORARY COUNTERS ONLY: original decisions below remain in original order.',
        '\tvar __rd: Dictionary = battle.get_meta("%s", {}) if battle != null else {}' % META,
        mark_line(kind + "_calls", "\t"),
        '\tif not __rd.is_empty() and battle != null and battle._lite_fx:',
        '\t\t__rd["%s_projection_calls"] = int(__rd.get("%s_projection_calls", 0)) + 1' % (kind, kind),
    ]
    if kind == "animated":
        preamble += [
            '\t\tif not force and _animated_redraw_t > 0.0:',
            '\t\t\t__rd["animated_avoidable_cooldown"] = int(__rd.get("animated_avoidable_cooldown", 0)) + 1',
        ]
    else:
        preamble += [
            '\t\tif battle._mob_count > 260 and not selected:',
            '\t\t\tvar __stride := 3 if battle._mob_count > 500 else 2',
            '\t\t\tif get_instance_id() % __stride != int(Engine.get_physics_frames()) % __stride:',
            '\t\t\t\t__rd["motion_avoidable_stride"] = int(__rd.get("motion_avoidable_stride", 0)) + 1',
            '\t\t\t\tvar __key := "motion_avoidable_stride_%d" % __stride',
            '\t\t\t\t__rd[__key] = int(__rd.get(__key, 0)) + 1',
        ]
    result = [lines[0], *preamble]
    submissions = 0
    for line in lines[1:]:
        if line.strip() == "_request_redraw()":
            indent = line[:len(line) - len(line.lstrip())]
            result.append(mark_line(kind + "_request_submissions", indent))
            submissions += 1
        result.append(line)
    expected = 1 if kind == "animated" else 2
    if submissions != expected:
        raise RuntimeError("Unexpected submission sites in " + name)
    return "\n".join(result) + "\n\n\n"


def instrument_unit(raw):
    updated = raw
    # Reverse offsets, preserving all bytes outside the two replaced spans.
    for name in reversed(NAMES):
        begin, end = function_span(updated, name)
        fragment = updated[begin:end]
        replacement = instrument_method(function_text(updated, name), name).encode()
        if b"\r\n" in fragment:
            replacement = replacement.replace(b"\n", b"\r\n")
        updated = updated[:begin] + replacement + updated[end:]
    return updated


def qa_class(pins):
    blocks = ['extends "res://scripts/unit.gd"', 'var _qa_request_count := 0',
              'func _request_redraw() -> void: _qa_request_count += 1', '']
    for name, suffix in zip(NAMES, ("animated", "motion")):
        old = pins["frozen_methods"][name]
        blocks.append(old.replace("func " + name + "(", "func _qa_reference_" + suffix + "(", 1))
    blocks.append('''func _qa_candidate_animated(interval := 0.08, force := false) -> void:
	if battle != null and battle._lite_fx:
		if not force and _animated_redraw_t > 0.0: return
		if not battle.unit_visual_active(position): return
		if not force: _animated_redraw_t = interval
	_request_redraw()

func _qa_candidate_motion() -> void:
	if battle != null and battle._lite_fx:
		if battle._mob_count > 260 and not selected:
			var stride := 3 if battle._mob_count > 500 else 2
			if get_instance_id() % stride != int(Engine.get_physics_frames()) % stride: return
		if not battle.unit_visual_active(position): return
	_request_redraw()
''')
    return "\n".join(blocks)


def baseline_helpers():
    path = ROOT / "tools/run_polish_performance.py"
    namespace = {"__file__": str(path), "__name__": "redraw_diagnostic_helpers"}
    exec(compile(path.read_text(encoding="utf-8-sig"), str(path), "exec"), namespace)
    return namespace


def require_exclusive_godot():
    if ACTIVE_GODOT_PROCESS is not None and ACTIVE_GODOT_PROCESS.poll() is None:
        raise RuntimeError("Owned Godot child has not exited; source must stay instrumented. PID="
                           + str(ACTIVE_GODOT_PROCESS.pid))
    if os.name != "nt":
        raise RuntimeError("This prepared runner requires the Windows reference environment.")
    command = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
                                  text=True, timeout=20).strip()
    ids = json.loads(raw) if raw else []
    if ids:
        raise RuntimeError("Godot is already running; acquire an exclusive slot first. PIDs=" + str(ids))


def resolve_godot(value):
    value = value or os.environ.get("GODOT_PATH", "")
    local = ROOT / "godot.local.txt"
    if not value and local.is_file():
        value = local.read_text(encoding="utf-8-sig").strip()
    if not value or not Path(value).is_file():
        raise RuntimeError("Provide --godot, GODOT_PATH, or this checkout's ignored godot.local.txt.")
    return str(Path(value).resolve())


def run_godot(exe, script, output, env, timeout, headless=False, validity_key="diagnostic_valid"):
    global ACTIVE_GODOT_PROCESS
    require_exclusive_godot()
    log_path = output.with_suffix(".log")
    command = [exe, "--path", str(ROOT)]
    if headless:
        command.append("--headless")
    else:
        command += ["--rendering-method", "forward_plus", "--rendering-driver", "vulkan"]
    command += ["--script", "res://" + script.relative_to(ROOT).as_posix()]
    started = time.monotonic()
    code, timed_out, failure, cleanup_error = None, False, None, None
    process = None
    child_exit_confirmed = False
    with log_path.open("wb") as log:
        try:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                       stderr=subprocess.STDOUT)
            ACTIVE_GODOT_PROCESS = process
            code = process.wait(timeout=timeout)
        except BaseException as exc:
            failure = exc
            timed_out = isinstance(exc, subprocess.TimeoutExpired)
            if process is not None:
                try:
                    # Keep the exact Popen handle: names/PID scans alone cannot
                    # prove our child exited, including on KeyboardInterrupt.
                    if process.poll() is None:
                        process.kill()
                    code = process.wait(timeout=CHILD_EXIT_TIMEOUT)
                except BaseException as stop_error:
                    cleanup_error = type(stop_error).__name__ + ": " + str(stop_error)
        finally:
            if process is not None:
                try:
                    final_code = process.poll()
                    child_exit_confirmed = final_code is not None
                    if child_exit_confirmed:
                        code = final_code
                        ACTIVE_GODOT_PROCESS = None
                except BaseException as poll_error:
                    cleanup_error = type(poll_error).__name__ + ": " + str(poll_error)
            # An unconfirmed handle deliberately survives for the outer source
            # restoration guard, even if stopping/waiting was interrupted again.
    console = log_path.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in console.splitlines() if ERROR.search(line)]
    receipt = {"command": command, "exit_code": code, "timed_out": timed_out,
               "child_pid": process.pid if process is not None else None,
               "child_started": process is not None, "child_exit_confirmed": child_exit_confirmed,
               "exception": type(failure).__name__ + ": " + str(failure) if failure else None,
               "cleanup_error": cleanup_error,
               "wall_seconds": time.monotonic() - started, "matched_messages": errors,
               "console_log": log_path.name, "scope": "counter or helper-state diagnostic only"}
    save_json(output.with_name(output.stem + "_process.json"), receipt)
    if failure is not None:
        raise failure
    if not child_exit_confirmed or cleanup_error:
        raise RuntimeError("Godot exit was not cleanly confirmed; inspect " + str(log_path))
    require_exclusive_godot()
    if code or errors or not output.is_file():
        raise RuntimeError("Invalid diagnostic process; inspect " + str(log_path))
    report = json.loads(output.read_text(encoding="utf-8-sig"))
    if not report.get(validity_key):
        raise RuntimeError("Diagnostic integrity failed; inspect " + str(output))
    return report



def prepare(output, pins):
    probe = (ROOT / "tools/polish_performance_probe.gd").read_bytes()
    setup = function_text(probe, "_new_battle")
    old = 'if scenario == "defense200": b._perf_bench_setup(200)'
    if setup.count(old) != 1:
        raise RuntimeError("Expected single defense fixture constructor not found.")
    setup = setup.replace(old, 'if scenario == "defense200": b._perf_bench_setup(diagnostic_population - 6)')
    driver = (HERE / "counter_driver.gd.in").read_text(encoding="utf-8")
    if driver.count("# @@NEW_BATTLE@@") != 1:
        raise RuntimeError("Missing counter driver generation marker.")
    (output / "counter_driver.gd").write_bytes(driver.replace("# @@NEW_BATTLE@@", setup).encode())
    (output / "state_qa.gd").write_bytes((HERE / "state_qa.gd.in").read_bytes())
    (output / "qa_unit.gd").write_bytes(qa_class(pins).encode())
    save_json(output / "pins_used.json", pins)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--apply", action="store_true", help="Temporarily instrument Unit and run counters.")
    actions.add_argument("--run-state-qa", action="store_true", help="Run state-only QA; do not edit Unit.")
    parser.add_argument("--godot")
    parser.add_argument("--populations", nargs="+", type=int, choices=(206, 326, 506), default=[206, 326, 506])
    parser.add_argument("--cameras", nargs="+", choices=("fixed", "auto"), default=["fixed", "auto"])
    parser.add_argument("--seconds", type=float, default=10.0)
    parser.add_argument("--screening-ratio", type=float, default=0.10,
                        help="Experiment triage only; never a game/performance acceptance threshold.")
    args = parser.parse_args()
    if not math.isfinite(args.seconds) or args.seconds < 1 or not 0 <= args.screening_ratio <= 1:
        parser.error("Finite seconds >=1 and screening-ratio in [0,1] required.")
    if len(set(args.populations)) != len(args.populations) or len(set(args.cameras)) != len(args.cameras):
        parser.error("Duplicate population/camera combinations are not useful.")
    pins = json.loads((HERE / "pins.json").read_text(encoding="utf-8"))
    validate_pins(pins)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = ROOT / ".godot/redraw_rejection_diagnostics" / stamp
    output.mkdir(parents=True, exist_ok=False)
    prepare(output, pins)
    print("PREPARED " + str(output), flush=True)
    if not args.apply and not args.run_state_qa:
        save_json(output / "preparation.json", {"godot_run": False, "source_mutated": False,
                  "status": "prepared only; GDScript has not been executed", "performance_claim": False})
        return 0
    exe = resolve_godot(args.godot)
    require_exclusive_godot()
    helpers = baseline_helpers()
    clean_env, env_receipt = helpers["environment"]()
    save_json(output / "configuration.json", {"populations": args.populations, "cameras": args.cameras,
              "seconds": args.seconds, "screening_ratio": args.screening_ratio,
              "controlled_environment": env_receipt, "godot_sha256": sha(Path(exe).read_bytes()),
              "scope": "COUNTERS ONLY: instrumentation overhead invalidates FPS measurements"})
    if args.run_state_qa:
        path = output / "state_qa.json"
        qa_source_before = UNIT.read_bytes()
        env = clean_env.copy()
        env.update(REDRAW_DIAG_OUT=str(path), REDRAW_QA_CLASS="res://" + (output / "qa_unit.gd").relative_to(ROOT).as_posix())
        run_godot(exe, output / "state_qa.gd", path, env, 180, headless=True)
        validate_pins(pins)
        save_json(output / "state_qa_source_receipt.json", {"before_sha256": sha(qa_source_before),
                  "after_sha256": sha(UNIT.read_bytes()), "unchanged": UNIT.read_bytes() == qa_source_before})
        if UNIT.read_bytes() != qa_source_before:
            raise RuntimeError("Unit bytes changed during state-only QA.")
        print("State-only QA ended; no render-equivalence or FPS claim.", flush=True)
        return 0

    original = UNIT.read_bytes()
    instrumented = instrument_unit(original)
    backup = output / "unit_original.bin"
    lock = ROOT / ".godot/redraw_rejection_source.lock"
    receipt = {"scope": "temporary counters in two redraw helpers only", "original_sha256": sha(original),
               "instrumented_sha256": sha(instrumented), "backup": str(backup), "applied": False,
               "restored": False, "source_conflict": False, "samples": [], "performance_claim": False}
    with lock.open("x", encoding="utf-8") as stream:
        stream.write(str(output) + "\n")

    def replace_unit(raw, expected):
        temporary = output / "unit_pending_replace.bin"
        temporary.write_bytes(raw)
        if temporary.read_bytes() != raw:
            raise RuntimeError("Pending source bytes failed verification.")
        if UNIT.read_bytes() != expected:
            raise RuntimeError("Source changed before atomic replacement.")
        # Output and Unit are on the same checkout volume. Single-file atomic
        # replacement prevents partial source writes on interruption/disk errors.
        os.replace(temporary, UNIT)

    try:
        validate_pins(pins)
        backup.write_bytes(original)
        if backup.read_bytes() != original:
            raise RuntimeError("Full-byte backup verification failed.")
        save_json(output / "original_sources.json", helpers["source_receipt"]())
        if UNIT.read_bytes() != original:
            raise RuntimeError("Unit changed while preparing instrumentation.")
        replace_unit(instrumented, original)
        receipt["applied"] = True
        if UNIT.read_bytes() != instrumented:
            raise RuntimeError("Instrumented-byte verification failed.")
        active_sources = helpers["source_receipt"]()
        save_json(output / "instrumented_sources.json", active_sources)
        for population in args.populations:
            for camera in args.cameras:
                if helpers["source_receipt"]()["combined_sha256"] != active_sources["combined_sha256"]:
                    raise RuntimeError("Source/resources changed during diagnostic session.")
                path = output / ("counters_%d_%s.json" % (population, camera))
                env = clean_env.copy()
                env.update(REDRAW_DIAG_POPULATION=str(population), REDRAW_DIAG_CAMERA=camera,
                           REDRAW_DIAG_SECONDS=str(args.seconds), REDRAW_DIAG_OUT=str(path))
                report = run_godot(exe, output / "counter_driver.gd", path, env, args.seconds + 180)
                after = helpers["source_receipt"]()
                if after["combined_sha256"] != active_sources["combined_sha256"]:
                    save_json(output / (path.stem + "_changed_sources.json"), after)
                    raise RuntimeError("Source/resources changed during the last diagnostic process.")
                counts = report["counts"]
                total = counts.get("animated_projection_calls", 0) + counts.get("motion_projection_calls", 0)
                avoidable = counts.get("animated_avoidable_cooldown", 0) + counts.get("motion_avoidable_stride", 0)
                ratio = avoidable / total if total else 0.0
                receipt["samples"].append({"population": population, "camera": camera, "report": path.name,
                       "projection_calls": total, "avoidable_projection_calls": avoidable, "avoidable_ratio": ratio,
                       "triage": "low opportunity; defer candidate" if ratio < args.screening_ratio
                       else "opportunity observed; full-function timing and render QA still required"})
                save_json(output / "running_receipt.json", receipt)
    except BaseException as exc:
        receipt["exception"] = type(exc).__name__ + ": " + str(exc)
        raise
    finally:
        receipt["exclusive_before_restore"] = False
        try:
            # Also runs on exceptions/KeyboardInterrupt and after a failed
            # post-process scan. Never restore while any Godot is unconfirmed.
            require_exclusive_godot()
            receipt["exclusive_before_restore"] = True
            current = UNIT.read_bytes()
            receipt["backup_verified_final"] = backup.is_file() and backup.read_bytes() == original
            if current == instrumented:
                # Restore our exact original memory bytes, including mixed line
                # endings. A changed backup cannot silently corrupt restoration.
                replace_unit(original, instrumented)
            elif current != original:
                receipt["source_conflict"] = True
                (output / "unit_conflicting_current.bin").write_bytes(current)
            receipt["final_sha256"] = sha(UNIT.read_bytes())
            receipt["restored"] = UNIT.read_bytes() == original
        except BaseException as restore_error:
            receipt["restoration_error"] = type(restore_error).__name__ + ": " + str(restore_error)
            receipt["final_sha256"] = "unverified"
        save_json(output / "restoration_receipt.json", receipt)
        if receipt["restored"]:
            lock.unlink()
        print("RESTORATION " + json.dumps({key: receipt[key] for key in
              ("applied", "restored", "source_conflict", "original_sha256", "final_sha256")}), flush=True)
        if not receipt["restored"]:
            print("Restoration incomplete: original full bytes remain at " + str(backup)
                  + "; lock retained. Inspect restoration_receipt.json before recovery.", file=sys.stderr)
    return 0 if receipt["restored"] else 2


if __name__ == "__main__":
    sys.exit(main())
