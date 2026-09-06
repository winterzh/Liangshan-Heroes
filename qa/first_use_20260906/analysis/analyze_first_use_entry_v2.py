"""V2 for one completed first-use entry. Read originals; write only a new V2 JSON.

Separates complete postdraw intervals from M1's complete raw sample. No Godot.
"""
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "scratchpad/first_use_diag/runs/20260906T112637549233Z_timed"


def need(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def merged_union(intervals):
    merged = []
    for lo, hi in sorted(intervals):
        if hi <= lo:
            continue
        if not merged or lo > merged[-1][1]:
            merged.append([lo, hi])
        else:
            merged[-1][1] = max(hi, merged[-1][1])
    return sum(hi - lo for lo, hi in merged)


def swept_union(intervals):
    """Independent endpoint-depth integration for every reported union."""
    endpoints = []
    for lo, hi in intervals:
        if hi > lo:
            endpoints.extend(((lo, 1), (hi, -1)))
    depth = last = total = 0
    for stamp, change in sorted(endpoints):
        if depth:
            total += stamp - last
        depth += change
        need(depth >= 0, "invalid interval sweep depth")
        last = stamp
    need(depth == 0, "unclosed interval sweep")
    return total


def union(intervals):
    rows = list(intervals)
    answer = swept_union(rows)
    need(answer == merged_union(rows), "independent union algorithms disagree")
    return answer


def main():
    protected = [RUN / "report.json", RUN / "completion_receipt.json", RUN / "first_use_analysis.json",
                 ROOT / "scratchpad/analyze_first_use_entry.py"]
    original_bytes = {path: path.read_bytes() for path in protected}
    report = json.loads(original_bytes[protected[0]])
    receipt = json.loads(original_bytes[protected[1]])
    old = json.loads(original_bytes[protected[2]])
    need(receipt["passed"] and receipt["source_unchanged"] and not receipt["lock_preserved"]
         and receipt["exit_code"] == 0 and not receipt["engine_errors"], "completed diagnostic receipt required")
    need(report["integrity_passed"] and report["sample_complete"] and not report["failures"], "valid complete M1 report required")
    diag = report["first_use"]
    need(diag["valid"] and diag["mode"] == "timed" and not diag["overflow"] and not diag["open_depth"], "valid timed ledger required")
    need(sha(original_bytes[protected[0]]) == old["report_sha256"], "old analysis is attached to different report bytes")
    events, kinds = diag["events"], diag["kind_names"]
    names, boundaries = diag["stage_names"], diag["stage_points"]
    need([row[0] for row in boundaries] == list(range(len(names))), "stage indices")
    need(all(a[1] <= b[1] for a, b in zip(boundaries, boundaries[1:])), "stage order")
    need(names[-1] == "sample_end" and boundaries[-1][1] == diag["capture_end_us"], "terminal boundary")
    counts = Counter(row[2] for row in events)
    need([counts[i] for i in range(len(kinds))] == diag["counts"], "kind counter reconciliation")
    for index, event in enumerate(events):
        need(len(event) == 12 and all(type(v) is int for v in event[:-1]) and isinstance(event[-1], str), "event schema")
        start, end, kind, stage = event[:4]
        need(diag["capture_start_us"] <= start <= end <= diag["capture_end_us"], "capture containment")
        need(0 <= kind < len(kinds) and 0 <= stage < len(names) - 1, "kind or nonterminal stage")
        need(boundaries[stage][1] <= start <= end <= boundaries[stage + 1][1], "stage containment")
        parent = event[8]
        need(parent == -1 or (0 <= parent < index and events[parent][0] <= start <= end <= events[parent][1]
                             and events[parent][3] == stage), "parent nesting")

    def summary(selected):
        kinds_out = []
        for kind, name in enumerate(kinds):
            durations = [row[1] - row[0] for row in selected if row[2] == kind]
            kinds_out.append({"kind": name, "calls": len(durations), "inclusive_total_us": sum(durations),
                              "max_us": max(durations, default=0)})
        return {"event_count": len(selected), "kind_summary": kinds_out,
                "nonoverlapping_observed_us": union((row[0], row[1]) for row in selected)}

    stages = []
    for stage, name in enumerate(names[:-1]):
        data = summary([row for row in events if row[3] == stage])
        data.update(stage=name, start_us=boundaries[stage][1], end_us=boundaries[stage + 1][1],
                    duration_us=boundaries[stage + 1][1] - boundaries[stage][1])
        stages.append(data)
    sample_index = names.index("sample")
    start, end = boundaries[sample_index][1], diag["capture_end_us"]
    sample = summary([row for row in events if row[3] == sample_index])
    need(stages == old["stages"] and sample == old["sample"], "V1 stage or sample aggregate discrepancy")
    need(len(events) == 375 and sample["event_count"] == 85, "this entry's event count")
    points = diag["points"]
    need(all(len(row) == 5 and all(type(v) is int for v in row) for row in points), "point schema")
    need(all(a[0] <= b[0] for a, b in zip(points, points[1:])), "shared-clock point order")
    postdraw = [row for row in points if row[1] == 1]
    within = [row for row in postdraw if start <= row[0] <= end]
    need(len(within) >= 2 and all(a[0] < b[0] for a, b in zip(within, within[1:])), "positive complete postdraw intervals")

    def slice_union(lo, hi):
        return union((max(row[0], lo), min(row[1], hi)) for row in events
                     if max(row[0], lo) < min(row[1], hi))

    intervals = [{"start_us": left[0], "end_us": right[0], "duration_us": right[0] - left[0],
                  "process_frame": right[3], "physics_frame": right[2],
                  "observed_interval_union_us": slice_union(left[0], right[0])}
                 for left, right in zip(within, within[1:])]
    need(intervals == old["complete_postdraw_intervals_in_sample"], "V1 complete interval discrepancy")
    complete = {"interval_count": len(intervals), "slow_over_100ms_count": sum(row["duration_us"] > 100000 for row in intervals),
                "duration_us": sum(row["duration_us"] for row in intervals),
                "observed_interval_union_us": sum(row["observed_interval_union_us"] for row in intervals), "intervals": intervals,
                "scope": "Both actual postdraw timestamps are inside sample; excludes the start prefix and end suffix."}
    prior = [row for row in postdraw if row[0] < start]
    prefix = {"start_us": start, "end_us": within[0][0], "duration_us": within[0][0] - start,
              "observed_interval_union_us": slice_union(start, within[0][0]),
              "previous_postdraw_us": prior[-1][0] if prior else None,
              "previous_postdraw_before_sample_us": start - prior[-1][0] if prior else None,
              "is_complete_postdraw_interval": False}
    suffix = {"start_us": within[-1][0], "end_us": end, "duration_us": end - within[-1][0],
              "observed_interval_union_us": slice_union(within[-1][0], end), "is_complete_postdraw_interval": False}
    need(complete["duration_us"] + prefix["duration_us"] + suffix["duration_us"] == end - start, "whole sample wall-clock partition")
    need(complete["observed_interval_union_us"] + prefix["observed_interval_union_us"] + suffix["observed_interval_union_us"]
         == sample["nonoverlapping_observed_us"], "whole sample union partition")
    raw_frames = report["raw_frame_ms"]
    need(len(raw_frames) == report["frames"] == len(within), "M1 sample frame count")
    m1 = {"frames": len(raw_frames), "slow_over_100ms_count": sum(value > 100 for value in raw_frames),
          "raw_frame_total_ms": sum(raw_frames), "first_raw_frame_ms": raw_frames[0], "last_raw_frame_ms": raw_frames[-1],
          "seconds": report["seconds"], "physics_ticks": report["physics_ticks"], "simulated_seconds": report["simulated_seconds"],
          "warmup_target_ticks": report["warmup_target_ticks"], "warmup_end_tick": report["warmup_end_tick"],
          "scope": "All original M1 raw_frame_ms rows, including its first start-to-postdraw measurement. Callback timestamps differ by a few microseconds from diagnostic postdraw points; do not index-match them as identical clocksamples."}
    need((complete["interval_count"], complete["slow_over_100ms_count"], m1["frames"], m1["slow_over_100ms_count"]) == (127, 41, 128, 42), "this entry's two slow-frame scopes")
    need(prefix["observed_interval_union_us"] == 207 and suffix["observed_interval_union_us"] == 0, "this entry's omitted observed work")
    need(complete["slow_over_100ms_count"] == old["sample_slow_over_100ms_count"], "V1 count corresponds to complete intervals")
    result = {"schema": 2, "valid": True, "report_sha256": sha(original_bytes[protected[0]]), "snapshot": receipt["snapshot"],
              "event_count": len(events), "stages": stages, "sample": sample,
              "complete_postdraw_intervals": complete, "m1_full_sample": m1,
              "sample_boundary_prefix": prefix, "sample_boundary_suffix": suffix,
              "reconciliation": {"independent_union_algorithms_agree": True, "v1_numeric_aggregates_unchanged": True,
                                 "sample_union_minus_complete_interval_union_us": sample["nonoverlapping_observed_us"] - complete["observed_interval_union_us"],
                                 "wall_partition_passed": True, "observed_union_partition_passed": True,
                                 "all_originals_preserved": True},
              "top_events": sorted([{"event_index": i, "kind": kinds[row[2]], "stage": names[row[3]], "label": row[-1],
                                     "duration_us": row[1] - row[0], "start_us": row[0], "parent": row[8]}
                                    for i, row in enumerate(events)], key=lambda row: row["duration_us"], reverse=True)[:20],
              "original_file_sha256": {path.relative_to(ROOT).as_posix(): sha(raw) for path, raw in original_bytes.items()},
              "analyzer_sha256": sha(Path(__file__).read_bytes()), "acceptance_eligible": False,
              "limits": old["limits"] + ["Complete postdraw intervals and full M1 sample have separate explicit counts.",
                                          "Observed unions are instrumented-path wall-clock coverage, not pure disk IO or guaranteed savings.",
                                          "V2 reanalyzes preserved evidence only; it executes no new engine run."]}
    for path, raw in original_bytes.items():
        need(path.read_bytes() == raw, "original changed during analysis: " + str(path))
    output = RUN / "first_use_analysis_v2.json"
    output.write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    for path, raw in original_bytes.items():
        need(path.read_bytes() == raw, "original changed after V2 output: " + str(path))
    print(json.dumps({"valid": True, "events": len(events), "sample_events": sample["event_count"],
                      "complete_intervals": [complete["interval_count"], complete["slow_over_100ms_count"]],
                      "m1_full_sample": [m1["frames"], m1["slow_over_100ms_count"]],
                      "union_difference_us": result["reconciliation"]["sample_union_minus_complete_interval_union_us"],
                      "originals_preserved": True, "output_sha256": sha(output.read_bytes())}))


if __name__ == "__main__":
    main()
