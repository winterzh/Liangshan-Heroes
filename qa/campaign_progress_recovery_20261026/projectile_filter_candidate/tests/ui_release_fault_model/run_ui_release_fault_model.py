"""D: real RetryRelease/Leave UI under one explicit permanent clock fault model.

Default verifies only named sources. --run uses the fixed full b22 source and
its own cold import, with two distinct processes and one fresh private profile.
This intentionally calls the original clock.abort_step once; it does not prove
a naturally occurring fault or a successful release-retry recovery branch.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
BASE_REL = Path('.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab')
CONTENT = 'source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132'
WORKERS = ('bootstrap.gd', 'base.gd', 'worker.gd')
MODES = ('fault_exit', 'restart_no_slot')
FAULT = 'QA_INJECTED_CLOCK_FAULT'
CONTEXT = {'mode': 'defense', 'level_id': '', 'waves': 30}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Source-only filesystem/identity helpers. No B1 worker, execution, or runtime
# qualification is imported into this explicit fault-model slice.
b1 = load('urf_closed_helpers', HERE.parent / 'ui_config_retry/run_ui_config_retry.py')
p, h, io, prep, baseline = b1.p, b1.h, b1.io, b1.prep, b1.baseline
require, sha, read, integer, attempt = b1.require, b1.sha, b1.read, b1.integer, b1.attempt
paths, file_row = b1.paths, b1.file_row
ZERO = b1.ZERO
FALSE_FLAGS = (*b1.FALSE_FLAGS, 'natural_fault_reproduced', 'retry_release_success_qualified')


def persist(path, row):
    try:
        h.save(p.fs(path), row)
        return True
    except BaseException as error:
        row.setdefault('post_errors', []).append({'phase': 'save ' + str(path), 'error': repr(error),
                                                  'traceback': traceback.format_exc()})
        row['complete'] = False
        if 'two_process_release_fault_model_qualified' in row:
            row['two_process_release_fault_model_qualified'] = False
        fallback = path.with_name(path.stem + '_write_failed_' + uuid.uuid4().hex + path.suffix)
        row['fallback_evidence_path'] = str(fallback)
        try:
            h.save(p.fs(fallback), row)
        except BaseException as second:
            row['post_errors'].append({'phase': 'fallback_save', 'error': repr(second), 'traceback': traceback.format_exc()})
            print(json.dumps({'evidence_write_failed': row}, ensure_ascii=False), file=sys.stderr, flush=True)
        return False


def native_helpers():
    command = "@(Get-CimInstance Win32_Process -Filter \"Name='ProcessLivenessProbe.exe'\" | Select-Object ProcessId,ParentProcessId,ExecutablePath) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell.exe', '-NoProfile', '-Command', command], text=True,
                                  creationflags=subprocess.CREATE_NO_WINDOW).strip()
    value = json.loads(raw) if raw else []
    return value if type(value) is list else [value]


def module_paths():
    return [Path(b1.__file__), *b1.module_paths()]


def named_state():
    sources = read(HERE / 'sources.json')
    require(sources.get('schema') == 'ui_release_fault_model_sources_v1', 'Explicit permanent-fault-model source schema required')
    required = {(HERE / name).relative_to(ROOT).as_posix() for name in
                ('README.md', 'cases.json', 'run_ui_release_fault_model.py', *WORKERS)}
    rows = sources.get('files', [])
    require(type(rows) is list and len(rows) == 6 and {row['path'] for row in rows} == required,
            'Exactly six current release-model inputs required')
    pins = {}
    for row in [*rows, *sources.get('dependencies', []), *sources.get('derived_from', [])]:
        path = prep.inside(ROOT, row['path'])
        require(path.suffix.lower() not in ('.exe', '.dll', '.pck'), 'Named default must not hash binary assets')
        p.pin(path, pins, row['sha256'])
        require(p.fs(path).stat().st_size == row['bytes'], 'Named source bytes changed: ' + str(path))
    require({str(path) for path in module_paths()}.issubset(pins), 'Imported helper source missing from dependencies')
    p.pin(HERE / 'sources.json', pins)
    cases = read(HERE / 'cases.json')
    require(cases.get('schema') == 'ui_release_fault_model_cases_v1' and cases.get('source_identity') == CONTENT
            and Path(cases.get('base_run', '')) == BASE_REL and cases.get('required_script_count') == 26
            and cases.get('required_native_count') == 1 and cases.get('requires_own_cold_import') is True
            and cases.get('native_process_count') == 2 and cases.get('profile_count') == 1
            and cases.get('worker_files') == list(WORKERS) and cases.get('fault_model_code') == FAULT,
            'Exact fixed-source two-process permanent-fault contract required')
    require([row.get('mode') for row in cases.get('stages', [])] == list(MODES)
            and [row.get('index') for row in cases['stages']] == [0, 1]
            and all(cases.get('qualification', {}).get(flag) is False for flag in FALSE_FLAGS),
            'Stage order or explicit fault-model-only qualification changed')
    return cases, pins


def native_tree(path, profile):
    path = io.owned(path, profile)
    if p.fs(path).is_file():
        return {'path': path.as_posix(), 'kind': 'file', 'file': file_row(path, profile)}
    inventory = io.snapshot(path)
    require(len(inventory['files']) < 64 and len(inventory['directories']) < 32, 'Fault-model business evidence must stay bounded')
    return {'path': path.as_posix(), 'kind': 'directory' if inventory['exists'] else 'absent',
            'files': {name: item['sha256'] for name, item in inventory['files'].items()},
            'directories': [name for name in inventory['directories'] if name != '.']}


def business(profile):
    user = paths(profile)['user']
    return {'continue': native_tree(user / 'continue/v1', profile), 'cfg': file_row(user / 'campaign.cfg', profile),
            'cfg_journal': native_tree(user / 'campaign_cfg_transactions/v1', profile),
            'cfg_candidates': native_tree(user / 'campaign_cfg_candidates', profile),
            'steam_receipts': native_tree(user / 'steam_receipts/v1', profile)}


def require_absent_business(value):
    require(value['cfg']['exists'] is False and value['cfg']['bytes'] == 0 and value['cfg']['sha256'] == ZERO,
            'Fresh explicit clock fault must not write Campaign CFG')
    require(all(value[key]['kind'] == 'absent' and value[key]['files'] == {} and value[key]['directories'] == []
                for key in ('continue', 'cfg_journal', 'cfg_candidates', 'steam_receipts')),
            'No slot/lifecycle/journal/candidate/native reward directory may be created by this failed capture model')


def diagnostic(profile):
    path = io.owned(paths(profile)['user'] / 'continue_error.json', profile)
    metadata = file_row(path, profile)
    return {'file': metadata, 'value': read(path) if metadata['exists'] else None}


def environment(base_env, profile, state, workers, binding, stage, output, mode, batch, nonce, previous):
    env = dict(base_env)
    for key in list(env):
        if key.startswith(('URF_', 'UTR_', 'UST_', 'UCR_', 'USR_', 'P19_', 'DN_', 'DF_', 'GVT_', 'GT_',
                           'GLS_', 'CR_', 'CC_', 'RS_', 'LSH_CONTINUE_FLOW_')):
            env.pop(key)
    for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
        require(env.get(key) == str(profile / key.lower()), 'Same private environment must be reused without recreating directories')
    for key in ('LEVEL', 'SKIRMISH', 'SMOKE_TEST', 'SCREENSHOT_DIR', 'SKIRMISH_AI'):
        env[key] = ''
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_LANGUAGE='zh_CN',
               LSH_CONTINUE_FLOW_QA='1', LSH_CONTINUE_FLOW_PROFILE=str(profile),
               URF_MODE=mode, URF_OUTPUT=str(stage), URF_RUN=str(output), URF_PROFILE=str(profile),
               URF_PROJECT=str(state['project']), URF_CONTENT=CONTENT, URF_ENGINE=state['engine_sha256'],
               URF_MANIFEST=sha(state['run_base'] / 'candidate_manifest.json'), URF_SOURCES_SHA256=sha(HERE / 'sources.json'),
               URF_BATCH_NONCE=batch, URF_PROCESS_NONCE=nonce, URF_WORKERS=str(workers), URF_BINDINGS=str(binding))
    if previous is not None:
        env.update(URF_PREVIOUS=str(previous), URF_PREVIOUS_SHA=sha(previous))
    return env


def validate_common(report, mode, child, profile, state, batch, nonce, before, after, previous):
    require(report.get('schema') == 'ui_release_fault_model_v1' and report.get('mode') == mode
            and report.get('passed') is True and report.get('stage_completed') is True and report.get('failures') == []
            and report.get('checks') and all(row.get('passed') is True for row in report['checks']), 'Actual model worker checks failed')
    require(integer(report.get('pid'), child.pid) and report.get('batch_nonce') == batch and report.get('process_nonce') == nonce
            and report.get('profile') == str(profile) and report.get('context') == CONTEXT
            and report.get('identity') == {'content_version': CONTENT, 'engine_sha256': state['engine_sha256'], 'source_mode': True}
            and report.get('candidate_manifest_sha256') == sha(state['run_base'] / 'candidate_manifest.json')
            and report.get('sources_sha256') == sha(HERE / 'sources.json'), 'Actual model PID/profile/source identity mismatch')
    require(report.get('fault_model') is True and report.get('fault_model_code') == FAULT
            and report.get('natural_fault_reproduced') is False and report.get('no_gameplay_state_injection') is False
            and report.get('no_hp_position_resource_injection') is True and integer(report.get('production_method_overrides'), 0)
            and report.get('initial_private_gate_used') is True and integer(report.get('simulation_time_scale'), 1)
            and integer(report.get('physics_hz'), 60) and report.get('source_private_ui_release_fault_model_qualified') is False
            and all(report.get(flag) is False for flag in b1.FALSE_FLAGS),
            'Only one explicit original-clock fault is modeled; no natural/public/SDK claim is admissible')
    require(after == before, 'Actual closed private business inventory must not change in either process')
    require_absent_business(after)
    checkpoint = report.get('checkpoint', {})
    require(checkpoint.get('business') == after and all(type(checkpoint.get(key)) is dict and checkpoint[key]
                for key in ('exact_business', 'progress', 'exact_progress', 'slot_probe')), 'Actual complete no-write typed checkpoint required')
    progress = checkpoint['progress']
    require(progress.get('records') == {} and integer(progress.get('unlocked'), 1) and progress.get('owner') == ''
            and integer(progress.get('active_run'), 0) and integer(progress.get('run_counter'), 0),
            'Explicit failed capture must not produce campaign progress or a credited run')
    probe = checkpoint['slot_probe']
    require(set(probe) == {'ok', 'exists', 'revision', 'file_sha256'}
            and probe.get('ok') is True and probe.get('exists') is False and integer(probe.get('revision'), 0)
            and probe.get('file_sha256') == ZERO, 'Actual original slot probe must remain absent at revision zero')
    if previous:
        require(checkpoint == previous['checkpoint'], 'Independent restart must retain exact same typed business/progress/no-slot checkpoint')


def validate_model(report, mode, child):
    observations, actions, operations = report.get('observations', {}), report.get('actions', []), report.get('actual_operations', [])
    require(type(actions) is list and type(operations) is list and len(operations) == 1
            and integer(operations[0].get('pid'), child.pid) and operations[0].get('result', {}).get('ok') is False
            and integer(operations[0].get('phase'), 4), 'One actual failed original Flow completion required per process')
    injections = [row for row in actions if row.get('kind') == 'explicit_permanent_fault_injection']
    buttons = [row for row in actions if row.get('kind') == 'original_button_callback']
    for button in buttons:
        require(integer(button.get('pid'), child.pid) and type(button.get('connections')) in (int, float)
                and integer(button['connections'], int(button['connections'])) and button['connections'] > 0,
                'Actual original button action must retain this process and a connected callback')
    if mode == 'fault_exit':
        require(report.get('release_exit_observed') is True and report.get('exit_reason') == 'continue_failed'
                and integer(report.get('capture_count'), 1) and integer(report.get('fault_call_count'), 1)
                and len(injections) == 1 and injections[0].get('api') == 'run_battle_clock.abort_step'
                and injections[0].get('code') == FAULT and integer(injections[0].get('count'), 1)
                and injections[0].get('natural_fault_reproduced') is False, 'Exactly one disclosed permanent fault and actual production failed-exit required')
        result = operations[0]['result']
        require(result.get('code') == FAULT and result.get('original_error') == FAULT and result.get('battle_held') is True
                and not result.get('pending_save', False), 'Original capture and release must both refuse the same actual permanent clock fault')
        registration = observations.get('requested_registration', {})
        rows = registration.get('connections', [])
        require(integer(registration.get('phase'), 2) and integer(registration.get('barrier_state'), 1)
                and registration.get('session_absent') is True and integer(registration.get('calls'), 0)
                and integer(registration.get('fault_calls'), 0) and len(rows) == 2
                and integer(rows[0].get('index'), 0) and integer(rows[1].get('index'), 1)
                and sum(row.get('observer') is True for row in rows) == 1
                and sum(row.get('flow') is True for row in rows) == 1
                and all(not (row.get('observer') is True and row.get('flow') is True) for row in rows)
                and all(row.get('valid') is True and type(row.get('flags')) in (int, float)
                        and integer(row['flags'], int(row['flags'])) and int(row['flags']) & 4 for row in rows),
                'Actual synchronous pre-emission registration of both unique callbacks is required, not an assumed enumeration order')
        capture = observations.get('capture_observer', {})
        require(integer(capture.get('calls'), 1) and capture.get('registration_observed') is True
                and capture.get('outside_physics') is True and capture.get('session_absent') is True
                and capture.get('held') is True and capture.get('disconnected') is True
                and capture.get('healthy', {}).get('ok') is True and capture.get('clock_capture', {}).get('ok') is True
                and capture['clock_capture'].get('record') == capture.get('signal_clock'),
                'Injection must follow real healthy HELD capture and precede original Session capture')
        before, after = observations.get('held_before_fault', {}), observations.get('held_after_fault', {})
        require(before and after and before.get('clock', {}).get('fault') == '' and after.get('clock', {}).get('fault') == FAULT,
                'Real held clock must be healthy before the sole abort_step')
        expected = {**before, 'clock': {**before['clock'], 'fault': FAULT}}
        require(after == expected and after.get('tree_paused') is True and integer(after.get('barrier_state'), 3)
                and after.get('barrier_held_clock') is True and after.get('input_closed') is True
                and after.get('local_receipt_absent') is True and integer(after.get('steam_run_id'), 0),
                'Only permanent fault field changes; original world/lease/HELD/zero-slot CAS remains exact')
        for key in ('battle_instance_id', 'clock_instance_id', 'barrier_instance_id'):
            require(b1.valid_instance_id(after.get(key)), 'Actual signed object identity missing: ' + key)
        require(len({after[key] for key in ('battle_instance_id', 'clock_instance_id', 'barrier_instance_id')}) == 3,
                'Real Battle, clock and barrier must be distinct retained objects')
        first, retried = observations.get('first_failure', {}), observations.get('retry_release', {})
        cancelled, exited = observations.get('leave_cancel', {}), observations.get('production_exit', {})
        require(first.get('result') == operations[0]['result'] and first.get('session_absent') is True
                and first.get('slot_probe') == report['checkpoint']['slot_probe']
                and retried.get('result') == {**first['result'], 'release_error': FAULT}
                and integer(retried.get('fault_calls'), 1) and cancelled.get('result') == retried['result']
                and integer(cancelled.get('phase'), 4) and cancelled.get('quit_started') is False
                and exited.get('quit_started') is True and exited.get('quit_reason') == 'continue_failed'
                and integer(exited.get('phase'), 5) and exited.get('slot_probe') == report['checkpoint']['slot_probe']
                and all(observed.get('scope') == after and integer(observed.get('operation_count'), 1)
                        for observed in (first, retried, cancelled, exited)),
                'Actual failed retry, Leave cancel and production Confirm must retain the identical healthy-origin held scope')
        for name, count in (('SaveAndExit', 1), ('RetryRelease', 1), ('LeaveHeldBattle', 2), ('CancelSave', 1), ('ConfirmSave', 1)):
            require(sum(button.get('name') == name for button in buttons) == count, 'Actual original UI action count changed: ' + name)
        keys = [row for row in actions if row.get('kind') == 'viewport_key']
        require(len(keys) == 2 and all(row.get('key') == 'Escape' and row.get('desktop_os_input') is False for row in keys),
                'Two internal viewport Escape dispatches are evidence, not OS keyboard automation')
        ordinary = observations.get('ordinary_run', {})
        require(type(ordinary.get('first_tick')) is str and ordinary['first_tick'].isdigit()
                and type(ordinary.get('last_tick')) is str and ordinary['last_tick'].isdigit()
                and int(ordinary['last_tick']) >= int(ordinary['first_tick']) + 120 and ordinary.get('fault') == '',
                'Ordinary actual battle must run healthy for 120 ticks before any fault injection')
    else:
        require(report.get('release_exit_observed') is False and report.get('exit_reason') == 'ui_release_fault_model_verified'
                and integer(report.get('capture_count'), 0) and integer(report.get('fault_call_count'), 0) and not injections
                and operations[0]['result'].get('code') == 'NO_SLOT' and not operations[0]['result'].get('battle_held', False),
                'Independent actual menu must reject absent slot without injecting another fault or spawning Battle')
        rejected, closed = observations.get('restart_no_slot', {}), observations.get('restart_after_close', {})
        require(rejected.get('result') == operations[0]['result'] and integer(rejected.get('phase'), 4)
                and rejected.get('slot_probe') == report['checkpoint']['slot_probe'] and rejected.get('no_world') is True
                and rejected.get('session_absent') is True and integer(rejected.get('operation_count'), 1)
                and integer(closed.get('phase'), 0) and closed.get('no_world') is True
                and integer(closed.get('operation_count'), 1) and closed.get('business') == report['checkpoint']['business']
                and closed.get('exact_progress') == report['checkpoint']['exact_progress'],
                'Actual absent-slot refusal then CloseError must preserve menu and original progress without a Battle')
        require(len(buttons) == 2 and [row.get('name') for row in buttons] == ['ContinueBattle', 'CloseError'],
                'Independent process must use actual Continue then CloseError only')


def execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous):
    row = {'mode': mode, 'profile': str(profile), 'process_nonce': nonce, 'complete': False, 'process_terminal': False,
           'post_errors': [], 'debugger_used': False, 'host_business_mutation': False}
    child = None
    log_path = stage / 'native.log'
    started = time.monotonic()
    try:
        require(os.name == 'nt' and not baseline.engines() and not native_helpers(), 'Owned Windows engine/helper lane must be idle')
        before = business(profile); require_absent_business(before)
        row.update(before_business=before, diagnostic_before=diagnostic(profile))
        command = [str(state['engine']), '--path', str(state['project']), '--rendering-method', 'gl_compatibility',
                   '--resolution', '1280x720', '--position', '30000,30000', '--script', str(workers / 'bootstrap.gd')]
        row['command'] = command
        with p.fs(log_path).open('xb') as stream:
            child = subprocess.Popen(command, cwd=state['project'], env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            row['pid'] = child.pid
            deadline, notice, scan = time.monotonic() + state['timeout'], time.monotonic(), 0.0
            while child.poll() is None:
                require(time.monotonic() < deadline, 'Owned fault-model process deadline exceeded')
                if time.monotonic() >= scan:
                    require(not baseline.engines() - {child.pid}, 'Foreign engine appeared; never control it')
                    scan = time.monotonic() + 2
                if time.monotonic() - notice >= 25:
                    print('RUNNING', mode, 'pid', child.pid, flush=True); notice = time.monotonic()
                time.sleep(.05)
            child.wait(timeout=20)
        row.update(exit_code=child.returncode, process_terminal=True, seconds=round(time.monotonic() - started, 3))
        require(child.returncode == 0, 'Actual model process must complete its expected own exit normally')
        native_log = p.fs(log_path).read_text(encoding='utf-8', errors='replace')
        errors = [line for line in native_log.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line or 'Parse Error:' in line]
        row['native_errors'] = errors
        require(not errors, 'Unexpected native parse/runtime errors cannot qualify the explicit fault model')
        report_path = stage / 'report.json'; report = read(report_path)
        after = business(profile)
        validate_common(report, mode, child, profile, state, batch, nonce, before, after, previous)
        validate_model(report, mode, child)
        diag = diagnostic(profile)
        require(diag['file']['exists'] and type(diag['value']) is dict and set(diag['value']) == {'code', 'restoring', 'engine'}
                and diag['value']['code'] == (FAULT if mode == MODES[0] else 'NO_SLOT')
                and diag['value']['restoring'] is (mode == MODES[1]), 'Only the real bounded Flow error diagnostic is permitted to change')
        diagnostic_source = paths(profile)['user'] / 'continue_error.json'
        diagnostic_target = stage / 'continue_error.json'
        p.copy(diagnostic_source, diagnostic_target, diag['file']['sha256'])
        row.update(complete=True, report_path=str(report_path), report_sha256=sha(report_path), actual_checks=len(report['checks']),
                   after_business=after, diagnostic_after=diag, diagnostic_copy=str(diagnostic_target))
    except BaseException as error:
        row.update(error=repr(error), traceback=traceback.format_exc(), complete=False)
    finally:
        def terminal():
            if child is None:
                row.update(process_terminal=True, process_not_started=True); return
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait(timeout=20)
            row.update(pid=child.pid, exit_code=child.returncode, process_terminal=child.poll() is not None)
        attempt(row, 'owned_popen_terminal', terminal)
        def close_process_handle():
            if child is not None:
                require(row.get('process_terminal') is True, 'Cannot close process ownership before confirmed terminal')
                child._handle.Close()
            row['owned_process_handle_closed'] = True
        attempt(row, 'owned_process_handle_close', close_process_handle)
        ok, after = attempt(row, 'final_business_inventory', lambda: business(profile))
        if ok: row['after_business'] = after
        ok, diag = attempt(row, 'final_error_diagnostic', lambda: diagnostic(profile))
        if ok: row['diagnostic_after'] = diag
        row['raw_pins'] = {}
        for path in (log_path, stage / 'report.json', stage / 'continue_error.json'):
            def pin_raw(path=path):
                if p.fs(path).is_file(): row['raw_pins'][str(path)] = sha(path)
            attempt(row, 'pin raw ' + path.name, pin_raw)
        if row['post_errors']: row['complete'] = False
        persist(stage / 'controller.json', row)
    return row


def execute(args):
    cases, named_pins = named_state()
    output = ROOT / '.godot/ui_release_fault_model_20261027' / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {'schema': 'ui_release_fault_model_two_process_v1', 'complete': False, 'two_process_release_fault_model_qualified': False,
               'steps': [], 'post_errors': [], 'named_pins': named_pins, 'base_run': str(args.base_run.resolve()),
               'fault_model': True, 'fault_model_code': FAULT, 'no_gameplay_state_injection': False,
               'debugger_used': False, 'execution_kind': 'source_project_offscreen_gl', **{flag: False for flag in FALSE_FLAGS}}
    state, locked, owner, pins = None, False, str(output), dict(named_pins)
    batch = uuid.uuid4().hex; receipt['batch_nonce'] = batch
    try:
        started = time.monotonic()
        while not locked:
            if not p.fs(h.shared.LOCK).exists() and not baseline.engines():
                try:
                    with p.fs(h.shared.LOCK).open('x', encoding='utf-8') as stream: stream.write(owner)
                    locked = True; break
                except FileExistsError:
                    pass
            require(time.monotonic() - started < args.wait_lane, 'Shared lane occupied; no child started')
            time.sleep(1)
        require(not baseline.engines() and not native_helpers(), 'Foreign engine/helper appeared before full source admission')
        state = b1.full_state(args.base_run, named_pins); state['timeout'] = args.timeout; pins = state['pins']
        receipt.update(project=str(state['project']), source_identity=CONTENT, engine_sha256=state['engine_sha256'],
                       initial_identity_passed=True, cold_import_qualified=True,
                       candidate_manifest_sha256=sha(state['run_base'] / 'candidate_manifest.json'),
                       candidate_script_count=26, native_asset_count=1, import_receipts=state['imports'])
        for name, digest in list(pins.items()):
            source = Path(name)
            if source.suffix.lower() == '.exe': continue
            require(source.is_relative_to(ROOT), 'Non-binary source evidence must be repository-owned')
            target = output / 'runner_inputs' / source.relative_to(ROOT)
            p.copy(source, target, digest); p.pin(target, pins, digest)
        workers = output / 'workers'; p.fs(workers).mkdir()
        bindings = {}
        for name in WORKERS:
            p.copy(HERE / name, workers / name, pins[str(HERE / name)])
            p.pin(workers / name, pins); bindings[name] = sha(workers / name)
        binding = workers / 'bindings.json'; h.save(p.fs(binding), bindings); p.pin(binding, pins)
        profile = Path(ROOT.anchor) / 'CodexQA/ui_release_fault_model' / batch[:12]
        h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
        base_env = h.common.private_environment(profile)
        receipt['profile'] = str(profile)
        previous_path = previous_report = None
        seen, nonces = set(), set()
        for index, mode in enumerate(MODES):
            p.verify_pins(pins)
            stage = output / ('%02d_' % index + mode); p.fs(stage).mkdir()
            nonce = uuid.uuid4().hex
            require(nonce not in nonces, 'Every process must have a distinct nonce'); nonces.add(nonce)
            env = environment(base_env, profile, state, workers, binding, stage, output, mode, batch, nonce, previous_path)
            row = execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous_report)
            receipt['steps'].append(row)
            require(row.get('complete') is True and type(row.get('pid')) is int and row['pid'] not in seen,
                    'Actual independent fault-model process failed')
            seen.add(row['pid'])
            for name, digest in row['raw_pins'].items(): p.pin(name, pins, digest)
            p.pin(stage / 'controller.json', pins)
            previous_path = Path(row['report_path']); previous_report = read(previous_path)
            p.verify_pins(pins)
            print('PASS', index, mode, 'pid', row['pid'], 'checks', row['actual_checks'], flush=True)
        require(len(seen) == len(nonces) == len(receipt['steps']) == 2, 'Exactly two distinct actual native processes required')
        receipt['two_process_release_fault_model_qualified'] = True
    except BaseException as error:
        receipt.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        identity = []
        if state is None:
            identity.append(attempt(receipt, 'full_admission', lambda: require(False, 'Full source admission incomplete'))[0])
        else:
            identity.append(attempt(receipt, 'runtime_current', lambda: h.assert_runtime_current(state['run_base']))[0])
            identity.append(attempt(receipt, 'generated_identity', lambda: h.identity.verify_generated(state['project'], state['generation']))[0])
            identity.append(attempt(receipt, 'engine_sha256', lambda: require(sha(state['engine']) == state['engine_sha256'], 'Engine changed'))[0])
        identity.append(attempt(receipt, 'source_pins', lambda: p.verify_pins(pins))[0])
        receipt['final_identity_passed'] = all(identity)
        receipt['all_owned_children_terminal'] = all(row.get('process_terminal') is True for row in receipt['steps'])
        receipt['all_owned_process_handles_closed'] = all(row.get('owned_process_handle_closed') is True for row in receipt['steps'])
        def unlock():
            receipt['engine_lane_idle'] = not baseline.engines()
            receipt['remaining_native_helpers'] = native_helpers()
            receipt['native_helper_lane_idle'] = not receipt['remaining_native_helpers']
            receipt['lock_owner_verified'] = bool(locked and p.fs(h.shared.LOCK).is_file() and p.fs(h.shared.LOCK).read_text(encoding='utf-8') == owner)
            if receipt['engine_lane_idle'] and receipt['native_helper_lane_idle'] and receipt['lock_owner_verified'] and receipt['all_owned_children_terminal'] and receipt['all_owned_process_handles_closed']:
                p.fs(h.shared.LOCK).unlink(); receipt['lock_released'] = not p.fs(h.shared.LOCK).exists()
        attempt(receipt, 'owned_lock_release', unlock)
        receipt['complete'] = bool(receipt['two_process_release_fault_model_qualified'] and receipt['final_identity_passed']
                                   and receipt.get('lock_released') and not receipt['post_errors'] and 'error' not in receipt)
        if not receipt['complete']: receipt['two_process_release_fault_model_qualified'] = False
        receipt['actual_process_count'] = sum(type(row.get('pid')) is int for row in receipt['steps'])
        receipt['actual_checks'] = sum(row.get('actual_checks', 0) for row in receipt['steps'])
        receipt['pinned_files'] = pins
        persist(output / 'receipt.json', receipt)
    print(json.dumps({'output': str(output), 'complete': receipt['complete'], 'actual_process_count': receipt['actual_process_count'],
                      'actual_checks': receipt['actual_checks'], 'error': receipt.get('error')}, ensure_ascii=False), flush=True)
    if not receipt['complete']: raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-run', type=Path, default=ROOT / BASE_REL)
    parser.add_argument('--run', action='store_true', help='Explicitly execute the two-process permanent clock fault model')
    parser.add_argument('--full-preflight', action='store_true', help='Explicit expensive full-source read-only admission')
    parser.add_argument('--timeout', type=int, default=360, help='Bounded seconds per process, excluding full-source admission')
    parser.add_argument('--wait-lane', type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 60 or args.wait_lane < 0: parser.error('Invalid bounded deadline')
    if args.run:
        execute(args); return
    cases, pins = named_state()
    result = {'validation_level': 'named_sources_only', 'named_pins': len(pins), 'source_identity': CONTENT,
              'modes': MODES, 'engine_started': False, 'profile_created': False, 'lane_acquired': False,
              'full_source_verified': False, 'native_qualified': False, 'fault_model': True,
              'natural_fault_reproduced': False, 'retry_release_success_qualified': False}
    if args.full_preflight:
        state = b1.full_state(args.base_run, pins)
        result.update(validation_level=state['validation_level'], full_source_verified=True,
                      cold_import_qualified=state['cold_import_qualified'], total_pins=len(state['pins']))
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
