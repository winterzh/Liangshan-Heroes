from pathlib import Path
from collections import Counter
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / 'scratchpad/first_use_diag/runs/20260906T112637549233Z_timed'
raw = (RUN / 'report.json').read_bytes()
report = json.loads(raw)
receipt = json.loads((RUN / 'completion_receipt.json').read_bytes())
assert receipt['passed'] and receipt['source_unchanged'] and not receipt['lock_preserved']
diag = report['first_use']
assert diag['valid'] and diag['mode'] == 'timed' and not diag['overflow'] and not diag['open_depth']
events, kinds = diag['events'], diag['kind_names']
stages, boundaries = diag['stage_names'], diag['stage_points']
assert [row[0] for row in boundaries] == list(range(len(stages)))
assert all(a[1] <= b[1] for a, b in zip(boundaries, boundaries[1:]))
counts = Counter(row[2] for row in events)
assert [counts[i] for i in range(len(kinds))] == diag['counts']
for index, event in enumerate(events):
    start, end, kind, stage = event[:4]
    assert diag['capture_start_us'] <= start <= end <= diag['capture_end_us']
    assert 0 <= kind < len(kinds) and 0 <= stage < len(stages)
    assert boundaries[stage][1] <= start
    if stage + 1 < len(boundaries):
        assert end <= boundaries[stage + 1][1]
    parent = event[8]
    assert parent == -1 or (0 <= parent < index and events[parent][0] <= start <= end <= events[parent][1])


def union(intervals):
    merged = []
    for start, end in sorted(intervals):
        if not merged or start > merged[-1][1]:
            merged.append([start, end])
        else:
            merged[-1][1] = max(merged[-1][1], end)
    return sum(end - start for start, end in merged)


def summary(selected):
    out = []
    for kind, name in enumerate(kinds):
        rows = [row for row in selected if row[2] == kind]
        out.append({'kind': name, 'calls': len(rows),
                    'inclusive_total_us': sum(row[1] - row[0] for row in rows),
                    'max_us': max([row[1] - row[0] for row in rows], default=0)})
    return {'event_count': len(selected), 'kind_summary': out,
            'nonoverlapping_observed_us': union((row[0], row[1]) for row in selected)}


stage_summary = []
for stage, name in enumerate(stages[:-1]):
    data = summary([row for row in events if row[3] == stage])
    data.update(stage=name, start_us=boundaries[stage][1], end_us=boundaries[stage + 1][1],
                duration_us=boundaries[stage + 1][1] - boundaries[stage][1])
    stage_summary.append(data)
sample = stages.index('sample')
start, end = boundaries[sample][1], diag['capture_end_us']
points = [row for row in diag['points'] if row[1] == 1]
assert all(a[0] <= b[0] for a, b in zip(points, points[1:]))
intervals = []
for left, right in zip(points, points[1:]):
    if not (start <= left[0] < right[0] <= end):
        continue
    intersected = [(max(row[0], left[0]), min(row[1], right[0])) for row in events
                   if max(row[0], left[0]) < min(row[1], right[0])]
    intervals.append({'start_us': left[0], 'end_us': right[0], 'duration_us': right[0] - left[0],
                      'process_frame': right[3], 'physics_frame': right[2],
                      'observed_interval_union_us': union(intersected)})
result = {'valid': True, 'report_sha256': hashlib.sha256(raw).hexdigest(),
          'snapshot': receipt['snapshot'], 'stages': stage_summary,
          'sample': summary([row for row in events if row[3] == sample]),
          'complete_postdraw_intervals_in_sample': intervals,
          'sample_slow_over_100ms_count': sum(row['duration_us'] > 100000 for row in intervals),
          'top_events': sorted([{'kind': kinds[row[2]], 'stage': stages[row[3]], 'label': row[-1],
                                'duration_us': row[1] - row[0], 'start_us': row[0], 'parent': row[8]}
                               for row in events], key=lambda row: row['duration_us'], reverse=True)[:20],
          'acceptance_eligible': False,
          'limits': ['Inclusive nested kind totals must not be added; interval union is separate.',
                     'Only the eight instrumented method paths are observed, not all CPU/GPU resource work.',
                     'Postdraw gaps use actual shared diagnostic clock, not guessed M1 row indexes.',
                     'A single instrumented entry does not establish a product performance gain.']}
(RUN / 'first_use_analysis.json').write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode())
print(json.dumps({'valid': result['valid'], 'events': len(events),
                  'stages': [{'stage': row['stage'], 'events': row['event_count'], 'union_us': row['nonoverlapping_observed_us']} for row in stage_summary],
                  'sample': result['sample'], 'sample_slow_over_100ms_count': result['sample_slow_over_100ms_count'],
                  'top_events': result['top_events'][:4]}, ensure_ascii=False))
