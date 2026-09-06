"""Describe every ten-second wall-clock segment without changing baseline validity.

Usage: python tools/analyze_polish_performance.py <run-directory>
Writes segment_analysis.json alongside the preserved samples. Frames crossing a
segment boundary are included with proportional duration in both segments; all
positive frame durations contribute. This exposes early battle pressure and later
idle time instead of treating a whole-window average as sustained performance.
"""
import argparse
import json
import math
from pathlib import Path
import statistics


def percentile(values, q):
    return sorted(values)[max(0, min(len(values)-1, math.ceil(len(values)*q)-1))] if values else None


def segments(frames, width_ms=10000.0):
    result = []
    elapsed = 0.0
    for frame_ms in frames:
        if frame_ms <= 0 or not math.isfinite(frame_ms):
            raise ValueError('Frame intervals must be finite and positive.')
        remaining = frame_ms
        while remaining > 1e-8:
            index = int((elapsed + 1e-8) // width_ms)
            if index == len(result):
                result.append({'index': index, 'from_seconds': index*width_ms/1000.0,
                               'duration_ms': 0.0, 'frame_equivalents': 0.0,
                               'overlapping_frame_ms': []})
            row = result[index]
            portion = min(remaining, (index+1)*width_ms-elapsed)
            row['duration_ms'] += portion
            row['frame_equivalents'] += portion/frame_ms
            row['overlapping_frame_ms'].append(frame_ms)
            elapsed += portion
            remaining -= portion
    for row in result:
        frames_in_window = row.pop('overlapping_frame_ms')
        row['seconds'] = row.pop('duration_ms')/1000.0
        row['fps'] = row['frame_equivalents']/row['seconds']
        row['p95_ms'] = percentile(frames_in_window, 0.95)
        row['p99_ms'] = percentile(frames_in_window, 0.99)
        row['complete_ten_seconds'] = row['seconds'] >= width_ms/1000.0-1e-6
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    samples = []
    for path in sorted(args.directory.glob('*.json')):
        report = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(report, dict) or 'raw_frame_ms' not in report:
            continue
        rows = segments(report['raw_frame_ms'])
        full = [r for r in rows if r['complete_ten_seconds']]
        samples.append({'report': path.name, 'scenario': report['scenario'],
                        'camera_mode': report['camera_mode'], 'segments': rows,
                        'lowest_complete_segment_fps': min((r['fps'] for r in full), default=None),
                        'highest_complete_segment_p95_ms': max((r['p95_ms'] for r in full), default=None),
                        'cpu_process_monitor_median_ms': statistics.median(report['process_monitor_ms']),
                        'cpu_physics_monitor_median_ms': statistics.median(report['physics_monitor_ms']),
                        'render_cpu_median_ms': statistics.median(report['render_cpu_ms']),
                        'render_gpu_median_ms': statistics.median(report['gpu_ms']) if report['gpu_ms'] else None})
    output = {'schema': 1, 'segment_seconds': 10,
              'note': 'All wall-clock segments, no best-window selection. Boundary-crossing frames are proportionally counted for FPS. Percentiles include every overlapping frame. This is workload diagnosis, not a new acceptance gate.',
              'samples': samples}
    (args.directory/'segment_analysis.json').write_bytes((json.dumps(output, ensure_ascii=False, indent=2)+'\n').encode('utf8'))
    print('Analyzed', len(samples), 'samples')


if __name__ == '__main__':
    main()
