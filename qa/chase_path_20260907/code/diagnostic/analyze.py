"""Offline validator for the 44-column direct-chase path ledger, not engine QA.

API: analyze(m1, data) -> JSON-compatible dict. Invalid input raises AnalysisError.
CLI: python analyze.py m1_10s.json report.json --out new_analysis.json
The CLI refuses to overwrite an output. No old analyzer or engine is called.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

ANALYSIS_SCHEMA = "chase_path_analysis_v1"
STEP_COLUMNS = [
    "m1_tick", "physics_id", "process_id", "physics_signal_us", "observer_us",
    "collection_physics_id", "collected_us", "chain_calls", "chain_completions",
    "ranged_chains", "strict_calls", "strict_returns", "strict_empty",
    "strict_ranged_empty", "strict_points", "strict_us", "strict_fallback_us",
    "strict_fallback_astar_us", "fallback_calls", "fallback_returns",
    "fallback_empty", "fallback_points", "fallback_us", "strict_endpoint_reject",
    "strict_same_cell", "strict_astar_empty_reject", "strict_smooth_return",
    "strict_smooth_empty", "strict_astar_enter", "strict_astar_return",
    "strict_astar_empty_ids", "strict_astar_ids_total", "strict_astar_us",
    "fallback_precondition_reject", "fallback_no_open_target",
    "fallback_astar_empty_reject", "fallback_reach_reject",
    "fallback_smooth_return", "fallback_smooth_empty", "fallback_astar_enter",
    "fallback_astar_return", "fallback_astar_empty_ids", "fallback_astar_ids_total",
    "fallback_astar_us",
]
TIME_COLUMNS = ["strict_us", "strict_fallback_us", "strict_fallback_astar_us",
                "fallback_us", "strict_astar_us", "fallback_astar_us"]
COUNT_COLUMNS = [name for name in STEP_COLUMNS[7:] if name not in TIME_COLUMNS]
FRAME_COLUMNS = ["start_us", "end_us", "process_id", "physics_id", "m1_tick",
                 "step_begin_index", "step_end_index"]
PROCESS_COLUMNS = ["signal_us", "process_id", "physics_id"]
INDEX = {name: index for index, name in enumerate(STEP_COLUMNS)}
MAX_INT = (1 << 63) - 1


class AnalysisError(ValueError):
    def __init__(self, code, detail):
        self.code = code
        super().__init__(code + ": " + detail)


def need(ok, code, detail):
    if not ok:
        raise AnalysisError(code, detail)


def integer(value):
    return type(value) is int and 0 <= value <= MAX_INT


def number(value):
    if type(value) is int:
        return -MAX_INT <= value <= MAX_INT
    return type(value) is float and math.isfinite(value)


def _rows(rows, width, cap, label):
    need(type(rows) is list and 0 < len(rows) <= cap, "ROW_COUNT", label)
    for index, row in enumerate(rows):
        need(type(row) is list and len(row) == width
             and all(type(v) is int and -1 <= v <= MAX_INT for v in row),
             "ROW_SHAPE", "%s[%d]" % (label, index))


def _step(row, timed):
    q = dict(zip(STEP_COLUMNS, row))
    context = "tick %d" % q["m1_tick"]
    need(all(q[name] >= 0 for name in STEP_COLUMNS if name not in TIME_COLUMNS),
         "NEGATIVE_COUNT", context)
    need(q["physics_signal_us"] <= q["observer_us"] <= q["collected_us"]
         and q["collection_physics_id"] in (q["physics_id"], q["physics_id"] + 1),
         "STEP_CLOCK", context)
    need(q["chain_calls"] == q["chain_completions"] == q["strict_calls"] == q["strict_returns"],
         "CHAIN_COUNTS", context)
    need(q["fallback_calls"] == q["fallback_returns"] == q["strict_ranged_empty"]
         and q["strict_ranged_empty"] <= min(q["strict_empty"], q["ranged_chains"])
         and q["ranged_chains"] <= q["chain_calls"], "FALLBACK_PAIRING", context)
    need(q["strict_calls"] == q["strict_endpoint_reject"] + q["strict_same_cell"] + q["strict_astar_enter"],
         "STRICT_TERMINALS", context)
    need(q["strict_astar_enter"] == q["strict_astar_return"]
         == q["strict_astar_empty_reject"] + q["strict_smooth_return"]
         and q["strict_astar_empty_ids"] == q["strict_astar_empty_reject"],
         "STRICT_ASTAR", context)
    need(q["strict_empty"] == q["strict_endpoint_reject"] + q["strict_astar_empty_reject"] + q["strict_smooth_empty"],
         "STRICT_EMPTY", context)
    need(q["fallback_calls"] == q["fallback_precondition_reject"] + q["fallback_no_open_target"] + q["fallback_astar_enter"],
         "FALLBACK_TERMINALS", context)
    need(q["fallback_astar_enter"] == q["fallback_astar_return"]
         == q["fallback_astar_empty_reject"] + q["fallback_reach_reject"] + q["fallback_smooth_return"]
         and q["fallback_astar_empty_ids"] == q["fallback_astar_empty_reject"],
         "FALLBACK_ASTAR", context)
    need(q["fallback_empty"] == q["fallback_precondition_reject"] + q["fallback_no_open_target"]
         + q["fallback_astar_empty_reject"] + q["fallback_reach_reject"] + q["fallback_smooth_empty"],
         "FALLBACK_EMPTY", context)
    for kind in ("strict", "fallback"):
        calls, empty, points = (q[kind + suffix] for suffix in ("_calls", "_empty", "_points"))
        smooth, smooth_empty = q[kind + "_smooth_return"], q[kind + "_smooth_empty"]
        astar, empty_ids, ids = (q[kind + suffix] for suffix in ("_astar_enter", "_astar_empty_ids", "_astar_ids_total"))
        need(empty <= calls and smooth_empty <= smooth and empty_ids <= astar,
             "SUBSET_COUNTS", context + " " + kind)
        need(ids >= astar - empty_ids and (astar > empty_ids or ids == 0),
             "ASTAR_IDS", context + " " + kind)
        upper = (q["strict_same_cell"] + ids - smooth if kind == "strict"
                 else ids - smooth - q["fallback_reach_reject"])
        need(calls - empty <= points <= upper and (calls > empty or points == 0),
             "RETURN_POINTS", context + " " + kind)
    if not timed:
        need(all(q[name] == -1 for name in TIME_COLUMNS), "CLOCKLESS_TIMES", context)
    else:
        need(all(q[name] >= 0 for name in TIME_COLUMNS), "TIMED_NEGATIVE", context)
        need(q["strict_astar_us"] <= q["strict_us"]
             and q["fallback_astar_us"] <= q["fallback_us"]
             and q["strict_fallback_us"] <= q["strict_us"]
             and q["strict_fallback_astar_us"] <= min(q["strict_astar_us"], q["strict_fallback_us"])
             and q["strict_astar_us"] - q["strict_fallback_astar_us"]
             <= q["strict_us"] - q["strict_fallback_us"], "NESTED_TIMES", context)
        owners = {"strict_us": "strict_calls", "fallback_us": "fallback_calls",
                  "strict_astar_us": "strict_astar_enter", "fallback_astar_us": "fallback_astar_enter",
                  "strict_fallback_us": "fallback_calls", "strict_fallback_astar_us": "fallback_calls"}
        need(all(q[owner] > 0 or q[name] == 0 for name, owner in owners.items()), "TIME_WITHOUT_CALL", context)
        if q["fallback_calls"] == q["strict_calls"]:
            need(q["strict_fallback_us"] == q["strict_us"]
                 and q["strict_fallback_astar_us"] == q["strict_astar_us"], "PAIRED_ALL_TIMES", context)
        need(q["strict_us"] + q["fallback_us"] <= q["collected_us"] - q["observer_us"],
             "STEP_SPANS", context)
    return q


def _summary(rows, timed):
    counts = {name: sum(row[name] for row in rows) for name in COUNT_COLUMNS}
    times = {name: sum(row[name] for row in rows) if timed else None for name in TIME_COLUMNS}
    paired = times["strict_fallback_us"] + times["fallback_us"] if timed else None
    direct = times["strict_us"] + times["fallback_us"] if timed else None
    per_step = {name: value / len(rows) if value is not None and rows else None for name, value in times.items()}
    per_step.update(paired_chain_us=paired / len(rows) if paired is not None and rows else None,
                    all_direct_methods_us=direct / len(rows) if direct is not None and rows else None)
    denominators = {"strict_us": "strict_calls", "fallback_us": "fallback_calls",
                    "strict_astar_us": "strict_astar_enter", "fallback_astar_us": "fallback_astar_enter",
                    "strict_fallback_us": "fallback_calls", "strict_fallback_astar_us": "fallback_calls"}
    return {"physics_steps": len(rows), "zero_chase_steps": sum(row["chain_calls"] == 0 for row in rows),
            "count_totals": counts, "time_totals_us": times,
            "paired_chain_us": paired, "all_direct_methods_us": direct,
            "mean_us_per_physics_step": per_step,
            "mean_us_per_counted_call": {name: times[name] / counts[owner]
                                         if times[name] is not None and counts[owner] else None
                                         for name, owner in denominators.items()},
            "mean_call_denominators": denominators,
            "paired_chain_mean_us_per_fallback_chain": paired / counts["fallback_calls"]
            if paired is not None and counts["fallback_calls"] else None}


def analyze(m1, data):
    """Validate only this ledger schema; source/cache/PID guards belong to runner."""
    need(type(m1) is dict and type(data) is dict, "INPUT_SHAPE", "two objects required")
    need(type(m1.get("schema")) is int and m1["schema"] == 1
         and type(data.get("schema")) is int and data["schema"] == 1, "SCHEMA", "expected schema 1")
    need(m1.get("integrity_passed") is True and m1.get("sample_complete") is True
         and m1.get("acceptance_eligible") is False and m1.get("failures") == [], "M1_INTEGRITY", "incomplete or eligible sample")
    expected = {"scenario": "defense200", "camera_mode": "fixed", "seed": 5088120,
                "renderer": "forward_plus", "resolution": [1440, 900], "warmup_target_ticks": 300}
    need(all(m1.get(k) == v for k, v in expected.items())
         and integer(m1.get("seed")) and integer(m1.get("warmup_target_ticks"))
         and type(m1.get("resolution")) is list and all(integer(v) for v in m1["resolution"])
         and number(m1.get("requested_seconds")) and m1["requested_seconds"] == 10
         and number(m1.get("time_scale")) and m1["time_scale"] == 1
         and type(m1.get("physics_hz")) is int and m1["physics_hz"] == 60
         and number(m1.get("seconds")) and m1["seconds"] >= 10
         and m1.get("audio_ready") is True and type(m1.get("camera_violations")) is int
         and m1["camera_violations"] == 0, "M1_WORKLOAD", "wrong bounded workload")
    need(data.get("valid") is True and type(data.get("errors")) is int and data["errors"] == 0
         and data.get("overflow") is False, "LEDGER_INVALID", "observer error or overflow")
    need(data.get("mode") in ("timed", "clockless") and type(data.get("timed")) is bool
         and data["timed"] == (data["mode"] == "timed"), "MODE", "mode/timed mismatch")
    need(data.get("acceptance_eligible") is False and data.get("performance_claim") is False
         and data.get("rng_added") is False and data.get("per_unit_rows") is False
         and data.get("retained_path_arrays") is False and type(data.get("extra_nodes")) is int
         and data["extra_nodes"] == 0, "CLAIMS", "unsupported observer claim")
    need(data.get("step_columns") == STEP_COLUMNS and data.get("presentation_columns") == FRAME_COLUMNS
         and data.get("process_columns") == PROCESS_COLUMNS, "COLUMNS", "not the 44-column chase contract")
    need(all(type(data.get(k)) is str and data[k] for k in ("scope", "overhead", "clock")), "METADATA", "missing scope/clock/overhead")
    steps, frames, processes = (data.get(k) for k in ("steps", "presentations", "processes"))
    _rows(steps, 44, 2048, "steps")
    _rows(frames, 7, 8192, "presentations")
    _rows(processes, 3, 8192, "processes")
    need(integer(data.get("step_count")) and data["step_count"] == len(steps)
         and [row[0] for row in steps] == list(range(1, len(steps) + 1)), "STEP_SEQUENCE", "missing/repeated tick")
    start, end = data.get("m1_start"), data.get("m1_end")
    for anchor in (start, end):
        need(type(anchor) is dict and all(integer(anchor.get(k)) for k in ("us", "m1_tick", "physics_id", "process_id", "step_count")),
             "ANCHOR_SHAPE", "missing/noninteger anchor")
    need(type(m1.get("sample_start")) is dict and type(m1.get("sample_end")) is dict
         and integer(m1["sample_start"].get("tick")) and integer(m1["sample_end"].get("tick"))
         and start["m1_tick"] == m1["sample_start"]["tick"] and end["m1_tick"] == m1["sample_end"]["tick"]
         and start["step_count"] == start["m1_tick"] < end["step_count"] == end["m1_tick"] == len(steps)
         and integer(m1.get("warmup_end_tick")) and 300 <= m1["warmup_end_tick"] <= start["m1_tick"],
         "ANCHOR_RANGE", "M1 tick/index/warmup mismatch")
    need(integer(m1.get("physics_ticks")) and end["m1_tick"] - start["m1_tick"] == m1["physics_ticks"] > 0,
         "MEASURED_STEPS", "wrong measured step count")
    parsed = [_step(row, data["timed"]) for row in steps]
    for previous, row in zip(steps, steps[1:]):
        need(row[1] == previous[1] + 1 and row[2] >= previous[2]
             and row[3] >= previous[3] and row[4] >= previous[4] and row[6] >= previous[6],
             "ENGINE_SEQUENCE", "physics/process clocks skipped or reversed")
    for anchor in (start, end):
        last = steps[anchor["m1_tick"] - 1]
        need(anchor["physics_id"] == last[1] and anchor["process_id"] >= last[2], "ANCHOR_ENGINE", "anchor/step engine IDs disagree")
    raw_ms = m1.get("raw_frame_ms")
    need(type(raw_ms) is list and all(number(value) and value >= 0 for value in raw_ms)
         and integer(m1.get("frames")) and integer(data.get("presentation_count"))
         and len(frames) == len(raw_ms) == m1["frames"] == data["presentation_count"] == len(processes),
         "PRESENTATION_COUNT", "frame/raw/process row counts disagree")
    process_by_id = {}
    previous_process = None
    for row in processes:
        need(all(value >= 0 for value in row) and row[1] not in process_by_id, "PROCESS_SIGNAL", "invalid/duplicate process signal")
        if previous_process:
            need(row[0] >= previous_process[0] and row[1] > previous_process[1] and row[2] >= previous_process[2],
                 "PROCESS_SEQUENCE", "process clocks/IDs reversed")
        process_by_id[row[1]] = row
        previous_process = row
    cursor, stamp, previous_pid, previous_physics = start["step_count"], start["us"], start["process_id"], start["physics_id"]
    frame_summaries, per_step, used_pids = [], [], set()
    for index, frame in enumerate(frames):
        lo, hi, pid, physics, tick, begin, finish = frame
        need(all(value >= 0 for value in frame) and lo == stamp and hi >= lo
             and pid > previous_pid and physics >= previous_physics, "FRAME_CHAIN", "presentation timestamps/IDs reversed")
        need(math.isclose((hi - lo) / 1000, raw_ms[index], rel_tol=0.0, abs_tol=1e-8),
             "M1_FRAME_CLOCK", "raw_frame_ms disagrees at frame %d" % index)
        need(begin == cursor and begin <= finish <= len(steps) and tick == finish, "FRAME_RANGE", "overlap/gap/out-of-range frame allocation")
        signal = process_by_id.get(pid)
        need(signal is not None and lo <= signal[0] <= hi and previous_physics <= signal[2] <= physics,
             "FRAME_PROCESS", "missing/misplaced process signal")
        used_pids.add(pid)
        selected = parsed[begin:finish]
        for row in selected:
            need(row["process_id"] == pid and lo <= row["physics_signal_us"] <= row["observer_us"] <= hi
                 and previous_physics < row["physics_id"] <= physics, "FRAME_STEP", "step outside its same-clock frame")
            output_row = dict(row)
            for name in TIME_COLUMNS:
                if not data["timed"]:
                    output_row[name] = None
            output_row.update(frame_index=index, paired_chain_us=row["strict_fallback_us"] + row["fallback_us"] if data["timed"] else None,
                              all_direct_methods_us=row["strict_us"] + row["fallback_us"] if data["timed"] else None)
            per_step.append(output_row)
        detail = _summary(selected, data["timed"])
        need(detail["all_direct_methods_us"] is None or detail["all_direct_methods_us"] <= hi - lo,
             "FRAME_SPANS", "sequential complete-method spans exceed frame")
        frame_summaries.append({"frame_index": index, "start_us": lo, "end_us": hi, "frame_us": hi - lo,
                                "process_id": pid, "physics_id": physics, "step_begin_index": begin, "step_end_index": finish,
                                "physics_steps": len(selected), "count_totals": detail["count_totals"],
                                "time_totals_us": detail["time_totals_us"], "paired_chain_us": detail["paired_chain_us"],
                                "all_direct_methods_us": detail["all_direct_methods_us"]})
        cursor, stamp, previous_pid, previous_physics = finish, hi, pid, physics
    need(cursor == len(steps) and len(per_step) == m1["physics_ticks"] and used_pids == set(process_by_id)
         and end["us"] >= stamp and end["process_id"] == previous_pid and end["physics_id"] == previous_physics,
         "FINAL_TAIL", "unassigned final steps/process signal or inconsistent end anchor")
    need((stamp - start["us"]) / 1000000 - 1e-6 <= m1["seconds"]
         <= (end["us"] - start["us"]) / 1000000 + 1e-6, "M1_ELAPSED", "elapsed time outside same-clock final tail")
    measured = parsed[start["m1_tick"]:end["m1_tick"]]
    total = _summary(measured, data["timed"])
    if total["count_totals"]["fallback_calls"] == 0:
        screening = "stop_no_fallback"
    elif not data["timed"]:
        screening = "timing_unavailable"
    elif total["mean_us_per_physics_step"]["paired_chain_us"] < 500:
        screening = "stop_below_500us_per_physics_step"
    else:
        screening = "further_equivalence_review_only"
    return {"schema": ANALYSIS_SCHEMA, "analysis_valid": True, "mode": data["mode"],
            "all_measurement": total, "first_up_to_600_steps": _summary(measured[:600], data["timed"]),
            "first600_complete": len(measured) >= 600, "measured_tick_first": start["m1_tick"] + 1,
            "measured_tick_last": end["m1_tick"], "warmup_steps_excluded": start["m1_tick"],
            "per_step": per_step, "frame_summaries": frame_summaries,
            "presentations": len(frames), "over_100ms_presentations": sum(f["frame_us"] > 100000 for f in frame_summaries),
            "largest_frames": sorted(frame_summaries, key=lambda f: f["frame_us"], reverse=True)[:8],
            "final_tail": {"start_us": stamp, "end_us": end["us"], "duration_us": end["us"] - stamp,
                           "physics_steps": 0, "fabricated_presentation": False},
            "same_clock_m1_frame_links_verified": True, "all_step_conservation_verified": True,
            "screening": {"threshold_us_per_physics_step": 500, "metric": "strict_fallback_us + fallback_us",
                          "decision": screening, "optimization_authorized": False},
            "normal_fps_available": False, "acceptance_eligible": False, "performance_claim": False,
            "scope": data["scope"], "overhead": data["overhead"],
            "cost_interpretation": "Complete strict and fallback methods include probe overhead. AStar is a nested subset; do not add it to methods. Paired strict costs are a subset of all strict costs. Clockless costs are null; no overhead subtraction or cross-generation body arithmetic.",
            "aggregation_limits": "Per-step aggregates retain no individual call/path rows; conservation cannot prove each individual pairing or gameplay equivalence. Observer validity and runner evidence remain required.",
            "external_guards": "Source/cache/private-profile/Popen/strict-log guard verification belongs to the generation runner, not this two-report analyzer."}


def read_json(path):
    need(Path(path).stat().st_size <= 32 * 1024 * 1024, "JSON_SIZE", "input exceeds 32 MiB")
    raw = Path(path).read_bytes()
    need(len(raw) <= 32 * 1024 * 1024, "JSON_SIZE", "input exceeds 32 MiB")

    def unique(pairs):
        value = {}
        for key, item in pairs:
            need(key not in value, "JSON_DUPLICATE", key)
            value[key] = item
        return value

    def constant(value):
        raise AnalysisError("JSON_NONFINITE", value)

    return json.loads(raw.decode("utf-8"), object_pairs_hook=unique, parse_constant=constant), hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("m1")
    parser.add_argument("ledger")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    m1, m1_sha = read_json(args.m1)
    ledger, ledger_sha = read_json(args.ledger)
    result = analyze(m1, ledger)
    result["input_raw_sha256"] = {"m1": m1_sha, "ledger": ledger_sha}
    result["analyzer_raw_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    with Path(args.out).open("x", encoding="utf-8", newline="\n") as output:
        json.dump(result, output, ensure_ascii=False, allow_nan=False, indent=2)
        output.write("\n")
    print(json.dumps({"analysis_valid": True, "mode": result["mode"], "output": str(Path(args.out)),
                      "physics_steps": result["all_measurement"]["physics_steps"]}))


if __name__ == "__main__":
    main()
