"""Validate one completed M1/Unit ledger pair; summarize measured body sections."""
import math

SECTIONS = ['lifecycle_building_death_us', 'status_timers_us',
            'target_state_movement_us', 'tail_animation_hit_watchdog_us']
STEP_COLUMNS = ['m1_tick', 'physics_id', 'process_id', 'physics_signal_us',
                'observer_us', 'collection_physics_id', 'collected_us',
                'body_starts', 'body_completions', 'body_total_us'] + SECTIONS + [
                'reached_lifecycle', 'reached_status', 'reached_target', 'reached_tail',
                'exited_lifecycle', 'exited_status', 'exited_target', 'exited_tail',
                'partition_delta_us']
FRAME_COLUMNS = ['start_us', 'end_us', 'process_id', 'physics_id', 'm1_tick',
                 'step_begin_index', 'step_end_index']


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def analyze(m1, data):
    need(m1.get('integrity_passed') is True and m1.get('sample_complete') is True
         and m1.get('acceptance_eligible') is False, 'Incomplete/eligible diagnostic')
    need(m1['requested_seconds'] == 10 and m1['scenario'] == 'defense200'
         and m1['camera_mode'] == 'fixed', 'Wrong bounded M1 workload')
    need(data.get('valid') is True and data['errors'] == 0 and data['overflow'] is False,
         'Invalid Unit ledger')
    need(data['step_columns'] == STEP_COLUMNS and data['presentation_columns'] == FRAME_COLUMNS,
         'Column contract changed')
    need(data['process_columns'] == ['signal_us', 'process_id', 'physics_id'], 'Process columns changed')
    need(data['mode'] in ['timed', 'clockless'] and data['timed'] == (data['mode'] == 'timed'), 'Mode mismatch')
    need(data['acceptance_eligible'] is False and data['performance_claim'] is False, 'Diagnostic claims changed')
    steps, frames, processes = data['steps'], data['presentations'], data['processes']
    si = {name: i for i, name in enumerate(STEP_COLUMNS)}
    fi = {name: i for i, name in enumerate(FRAME_COLUMNS)}
    for rows, width in [(steps, 23), (frames, 7), (processes, 3)]:
        need(all(len(row) == width and all(type(value) is int for value in row) for row in rows), 'Noninteger/malformed row')
    need([row[0] for row in steps] == list(range(1, len(steps) + 1)), 'Missing/duplicate M1 tick')
    start, end = data['m1_start'], data['m1_end']
    need(start['m1_tick'] == m1['sample_start']['tick'] and end['m1_tick'] == m1['sample_end']['tick'], 'M1 anchor mismatch')
    need(end['m1_tick'] == len(steps) == data['step_count'], 'Final step missing')
    need(start['step_count'] == start['m1_tick'] and end['step_count'] == len(steps), 'Anchor indices mismatch')
    need(end['m1_tick'] - start['m1_tick'] == m1['physics_ticks'] > 0, 'Measurement step count mismatch')
    for index, row in enumerate(steps):
        starts, completions = row[7:9]
        reaches, exits = row[14:18], row[18:22]
        need(starts == completions > 0 and min(reaches + exits) >= 0, 'Body entry/exit count mismatch')
        need(reaches[0] == starts and reaches[3] == exits[3] and sum(exits) == completions, 'Body reach/exit conservation')
        need(all(reaches[i] - reaches[i + 1] == exits[i] for i in range(3)) and exits[1] == 0,
             'Section transition/early-return conservation')
        need(row[3] <= row[4] <= row[6] and row[5] in (row[1], row[1] + 1), 'Physics clock/boundary mismatch')
        if index:
            need(row[1] == steps[index - 1][1] + 1, 'Engine physics ID skipped/repeated')
        if data['timed']:
            need(min(row[9:14]) >= 0 and row[9] == sum(row[10:14]) and row[22] == 0, 'Timed partition mismatch')
        else:
            need(row[9:14] == [-1] * 5 and row[22] == -1, 'Clockless timing is unavailable, never zero')

    need(len(frames) == data['presentation_count'] == m1['frames'] == len(m1['raw_frame_ms']) > 0,
         'Presentation row count mismatch')
    process_ids = {}
    for row in processes:
        need(row[1] not in process_ids, 'Duplicate process signal')
        process_ids[row[1]] = row
    cursor, stamp, linked = start['step_count'], start['us'], 0
    frame_costs = []
    for index, frame in enumerate(frames):
        lo, hi, pid, physics_id, tick, begin, finish = frame
        need(lo == stamp and hi >= lo, 'Presentation clock chain broke')
        need(math.isclose((hi - lo) / 1000, m1['raw_frame_ms'][index], abs_tol=1e-8), 'M1/frame same-clock mismatch')
        need(begin == cursor and begin <= finish <= len(steps) and tick == finish, 'Frame step ranges overlap/skip')
        need(pid in process_ids and lo <= process_ids[pid][0] <= hi, 'Missing/misplaced process signal')
        selected = steps[begin:finish]
        for row in selected:
            need(row[2] == pid and lo <= row[3] <= row[4] <= hi and row[1] <= physics_id,
                 'Physics step outside matching process/presentation')
            linked += 1
        body_us = sum(row[9] for row in selected) if data['timed'] else None
        if body_us is not None:
            need(body_us <= hi - lo, 'Sequential Unit spans exceed containing frame')
        frame_costs.append({'process_id': pid, 'frame_us': hi - lo, 'physics_steps': len(selected),
                            'body_calls': sum(row[7] for row in selected), 'body_total_us': body_us})
        cursor, stamp = finish, hi
    need(cursor == len(steps) and linked == m1['physics_ticks'] and end['us'] >= stamp, 'Unaccounted final tail')

    def summary(rows):
        calls = sum(row[7] for row in rows)
        totals = {name: sum(row[si[name]] for row in rows) if data['timed'] else None for name in SECTIONS}
        body = sum(row[9] for row in rows) if data['timed'] else None
        return {'physics_steps': len(rows), 'body_calls': calls, 'body_total_us': body,
                'section_total_us': totals,
                'section_mean_us_per_physics_step': {name: value / len(rows) if value is not None and rows else None for name, value in totals.items()},
                'section_mean_us_per_body_call': {name: value / calls if value is not None and calls else None for name, value in totals.items()},
                'share_of_observed_body': {name: value / body if body else None for name, value in totals.items()},
                'exit_counts': {name: sum(row[18 + i] for row in rows) for i, name in enumerate(SECTIONS)}}

    measured = steps[start['m1_tick']:end['m1_tick']]
    return {'analysis_valid': True, 'mode': data['mode'], 'all_measurement': summary(measured),
            'first_up_to_600_steps': summary(measured[:600]), 'first600_complete': len(measured) >= 600,
            'presentations': len(frames), 'over_100ms_presentations': sum(row['frame_us'] > 100000 for row in frame_costs),
            'largest_frames': sorted(frame_costs, key=lambda row: row['frame_us'], reverse=True)[:8],
            'same_clock_m1_frame_links_verified': True, 'entry_exit_partition_conservation_verified': True,
            'normal_fps_available': False, 'acceptance_eligible': False, 'performance_claim': False,
            'scope': data['scope'], 'overhead': data['overhead'],
            'next_action': 'Review measured section costs; do not infer product speedup or subtract independent clockless trajectory.'}
