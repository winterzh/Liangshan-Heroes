"""Offline structural and timing-ledger analysis; never computes normal FPS."""
import argparse
import json
from pathlib import Path
import statistics

HERE = Path(__file__).resolve().parent


def summarize(report, window_us=10000000):
    step_columns = report["step_columns"]
    frame_columns = report["frame_columns"]
    s = {name: i for i, name in enumerate(step_columns)}
    f = {name: i for i, name in enumerate(frame_columns)}
    steps = report["step_rows"]
    frames = report["frame_rows"]
    timed = report["timing_available"]
    errors = []
    expected_first = 0
    previous_end = 0
    previous_tick = None
    per_frame = []
    for index, row in enumerate(frames):
        start = row[f["start_us"]]; end = row[f["end_us"]]
        first = row[f["first_step_index"]]; count = row[f["physics_step_count"]]
        if first != expected_first: errors.append("noncontiguous step group at presentation " + str(index))
        if start != previous_end or end <= start: errors.append("noncontiguous/nonpositive wall interval at presentation " + str(index))
        if count < 0 or first < 0 or first + count > len(steps): errors.append("step group bounds at presentation " + str(index))
        subset = steps[first:first + count]
        for step in subset:
            tick = step[s["engine_physics_frame"]]
            if previous_tick is not None and tick != previous_tick + 1: errors.append("nonconsecutive physics frames")
            previous_tick = tick
            if step[s["presentation_index"]] != index: errors.append("step assigned to wrong presentation")
            if not start <= step[s["start_us"]] <= end: errors.append("physics start outside its wall interval")
            if timed:
                if step[s["battle_callback_count"]] != 1: errors.append("expected one complete Battle callback per measured step")
                if step[s["unit_callback_count"]] <= 0: errors.append("no measured Unit callback in a defense200 step")
                if step[s["last_measured_callback_end_us"]] > end: errors.append("callback extends past presentation")
                for name in ("battle_callback_us", "unit_callbacks_us"):
                    if step[s[name]] < 0: errors.append("negative measured callback duration")
            elif any(step[s[name]] != -1 for name in ("battle_callback_us", "unit_callbacks_us", "battle_callback_count", "unit_callback_count")):
                errors.append("clockless timing/count cells must use unavailable sentinel -1")
        battle = sum(step[s["battle_callback_us"]] for step in subset) if timed else None
        unit = sum(step[s["unit_callbacks_us"]] for step in subset) if timed else None
        total = battle + unit if timed else None
        if timed and total > end - start: errors.append("separate callback totals exceed their full presentation interval")
        per_frame.append({"presentation_index": index, "start_us": start, "end_us": end,
            "frame_interval_us": end - start, "physics_step_count": count,
            "battle_callback_us": battle, "unit_callbacks_us": unit,
            "measured_disjoint_callbacks_us": total,
            "unattributed_interval_us": end - start - total if timed else None})
        expected_first = first + count
        previous_end = end
    if expected_first != len(steps): errors.append("steps omitted from presentation groups")
    if len(steps) != report.get("physics_ticks", len(steps)): errors.append("M1 tick total mismatch")
    if not report.get("diagnostic_valid"): errors.append("runtime integrity not valid")
    if report.get("overflow") or report.get("callback_frame_mismatches") or report.get("tick_sequence_errors"):
        errors.append("runtime ledger overflow or frame mismatch")

    # Include full frames whose START is in the first-ten-second wall window.
    # The intersecting boundary frame is not proportionally divided across ticks.
    first_window = [row for row in per_frame if row["start_us"] < window_us]
    slow = [row for row in first_window if row["frame_interval_us"] > 100000]
    hist = {}
    for row in first_window:
        key = str(row["physics_step_count"])
        hist[key] = hist.get(key, 0) + 1
    measured_steps = sum(row["physics_step_count"] for row in first_window)
    battle_us = sum(row["battle_callback_us"] for row in first_window) if timed else None
    unit_us = sum(row["unit_callbacks_us"] for row in first_window) if timed else None
    largest = sorted(first_window, key=lambda row: row["frame_interval_us"], reverse=True)[:8]
    contexts = []
    for row in largest:
        index = row["presentation_index"]
        contexts.append(per_frame[max(0, index - 2):min(len(per_frame), index + 2)])
    return {"schema": 1, "analysis_valid": not errors, "errors": sorted(set(errors)),
        "mode": report["mode"], "performance_claim": False, "normal_fps_computed": False,
        "window_requested_us": window_us, "window_covered": bool(frames) and previous_end >= window_us,
        "boundary_policy": "full frames with start < window end; do not split a physics step proportionally",
        "first_window_presentations": len(first_window), "first_window_physics_steps": measured_steps,
        "physics_steps_per_presentation_histogram": hist,
        "first_window_battle_callback_us": battle_us, "first_window_unit_callbacks_us": unit_us,
        "battle_callback_us_per_step": battle_us / measured_steps if timed and measured_steps else None,
        "unit_callbacks_us_per_step": unit_us / measured_steps if timed and measured_steps else None,
        "slow_over_100ms_presentations": len(slow),
        "slow_presentations_median_physics_steps": statistics.median(row["physics_step_count"] for row in slow) if slow else None,
        "largest_frame_contexts": contexts, "per_presentation": per_frame,
        "interpretation": "Battle and Unit callback spans are separate SceneTree calls and may be added once. Unattributed interval also contains all probe work, other callbacks, rendering, engine work and waits; it is not process time or a bottleneck attribution. Clockless control still contains wrappers and ledger work; neither mode is normal FPS."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    path = args.report.resolve()
    if HERE.resolve() not in path.parents:
        parser.error("Use a report under this draft directory; all output stays in the bounded directory")
    result = summarize(json.loads(path.read_text(encoding="utf-8-sig")))
    target = path.with_name(path.stem + "_analysis.json")
    target.write_bytes((json.dumps(result, indent=2) + "\n").encode())
    print(json.dumps({"analysis": str(target), "valid": result["analysis_valid"], "performance_claim": False}))
    return 0 if result["analysis_valid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
