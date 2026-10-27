"""Three actual private classic ContinueFlow processes; default is named-source read-only.

--run admits the fixed b22 source and its own cold import under the shared lane.
It injects only owned Windows sharing faults on the actual slot owner/record,
never replaces production methods, a proposal, or a player's profile.
"""
from __future__ import annotations

import argparse
import ctypes as ct
from ctypes import wintypes as wt
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import socket
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
WORKERS = ('bootstrap.gd', 'base.gd', 'worker.gd', 'inflight.gd')
MODES = ('save_initial', 'retry_save', 'reject_then_resume')
USERDIR = Path('appdata/Godot/app_userdata/水浒英雄传：八幕战役')
CONTEXT = {'mode': 'defense', 'level_id': '', 'waves': 30}
SNAPSHOT = 'res://scripts/run_snapshot_store.gd'
FALSE_FLAGS = ('public_continue_qualified', 'native_sdk_qualified', 'native_release_tested',
               'desktop_os_input', 'human_acceptance', 'full_campaign_qualified',
               'full_61_qualified', 'published')
GATE_KEYS = {'schema', 'mode', 'phase', 'pid', 'batch_nonce', 'process_nonce', 'profile',
             'content_version', 'engine_sha256', 'detail'}
PHASES = {'save_initial': (), 'retry_save': ('arm_owner_release', 'arm_retry_release', 'release_retry_handles'),
          'reject_then_resume': ('arm_record_read', 'release_record_read')}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prep = load('usr_preparation', HERE.parents[1] / 'integration_3365/prepare_projectile.py')
p, h = prep.p, prep.h
wire = load('usr_debug_wire', ROOT / 'tools/godot_debug_wire.py')
io = load('usr_sharing', ROOT / 'qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_io.py')
baseline = load('usr_process_inventory', ROOT / 'tools/run_workstation_baseline.py')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    h.identity.no_links(p.fs(path))
    return h.sha(p.fs(path))


def read(path):
    h.identity.no_links(p.fs(path))
    return h.read(p.fs(path))


def integer(value, expected):
    return type(value) in (int, float) and math.isfinite(value) and value == expected


def closed_json(path):
    if not p.fs(path).is_file():
        return None
    try:
        return read(path)
    except (json.JSONDecodeError, UnicodeDecodeError, PermissionError):
        return None


def attempt(row, label, function):
    try:
        return True, function()
    except BaseException as error:
        row.setdefault('post_errors', []).append({'phase': label, 'error': repr(error),
                                                  'traceback': traceback.format_exc()})
        row['complete'] = False
        return False, None


def persist(path, row):
    try:
        h.save(p.fs(path), row)
        return True
    except BaseException as error:
        row.setdefault('post_errors', []).append({'phase': 'save ' + str(path), 'error': repr(error),
                                                  'traceback': traceback.format_exc()})
        row['complete'] = False
        if 'three_process_flow_qualified' in row:
            row['three_process_flow_qualified'] = False
        fallback = path.with_name(path.stem + '_write_failed_' + uuid.uuid4().hex + path.suffix)
        row['fallback_evidence_path'] = str(fallback)
        try:
            h.save(p.fs(fallback), row)
        except BaseException as second:
            row['post_errors'].append({'phase': 'fallback_save', 'error': repr(second),
                                      'traceback': traceback.format_exc()})
            print(json.dumps({'evidence_write_failed': row}, ensure_ascii=False), file=sys.stderr, flush=True)
        return False


def module_paths():
    return [Path(module.__file__) for module in (prep, p, h, h.common, h.shared, h.identity, wire, io, baseline)]


def named_state():
    sources = read(HERE / 'sources.json')
    require(sources.get('schema') == 'ui_save_retry_sources_v1', 'Explicit UI retry source schema required')
    required = {str((HERE / name).relative_to(ROOT).as_posix()) for name in
                ('README.md', 'cases.json', 'run_ui_save_retry.py', *WORKERS)}
    rows = sources.get('files', [])
    require(type(rows) is list and len(rows) == 7 and {row['path'] for row in rows} == required,
            'Exactly the seven current UI retry inputs must be bound')
    pins = {}
    for row in [*rows, *sources.get('dependencies', [])]:
        rel = Path(row['path'])
        require(not rel.is_absolute() and '..' not in rel.parts, 'Source path must stay within this repository')
        path = ROOT / rel
        require(path.suffix.lower() not in ('.exe', '.dll', '.pck'), 'Default named admission must not hash binary assets')
        p.pin(path, pins, row['sha256'])
        require(p.fs(path).stat().st_size == row['bytes'], 'Named source byte size changed: ' + str(path))
    expected_modules = {str(path) for path in module_paths()}
    require(expected_modules.issubset(set(pins)), 'Imported host helper is absent from named dependencies')
    p.pin(HERE / 'sources.json', pins)
    cases = read(HERE / 'cases.json')
    require(cases.get('schema') == 'ui_save_retry_cases_v1' and cases.get('source_identity') == CONTENT
            and Path(cases.get('base_run', '')) == BASE_REL
            and cases.get('required_script_count') == 26 and cases.get('required_native_count') == 1
            and cases.get('requires_own_cold_import') is True and cases.get('native_process_count') == 3
            and cases.get('profile_count') == 1 and cases.get('worker_files') == list(WORKERS),
            'Explicit fixed-source three-process case contract required')
    require([case.get('mode') for case in cases.get('stages', [])] == list(MODES)
            and [case.get('index') for case in cases['stages']] == [0, 1, 2]
            and [case.get('expected_generation') for case in cases['stages']] == [1, 2, 2]
            and all(cases.get('qualification', {}).get(flag) is False for flag in FALSE_FLAGS),
            'Stage order/generation/qualification boundary changed')
    return cases, pins


def release_point(project):
    source = project / SNAPSHOT.removeprefix('res://')
    lines = p.fs(source).read_text(encoding='utf-8').splitlines()
    start = next(i for i, line in enumerate(lines) if line == 'func release() -> Dictionary:')
    end = next(i for i in range(start + 1, len(lines)) if lines[i].startswith('func '))
    statement = 'if DirAccess.remove_absolute(directory.path_join("writing/owner.json")) != OK or DirAccess.remove_absolute(directory.path_join("writing")) != OK: return bad("LOCK_RELEASE")'
    found = [i + 1 for i in range(start + 1, end) if lines[i].strip() == statement]
    require(len(found) == 1 and found[0] == 219, 'Exact b22 owner-file release boundary changed')
    return {'source': SNAPSHOT, 'function': 'release', 'line': found[0],
            'source_sha256': sha(source), 'statement': statement}


def full_state(base_run, named_pins):
    require(Path(base_run).resolve() == (ROOT / BASE_REL).resolve(), 'Only fixed b22 candidate is admitted')
    state = prep.prepared_state(base_run)
    require(state.get('validation_level') == 'full_new_freeze_and_own_import'
            and state.get('cold_import_qualified') is True and state.get('content_version') == CONTENT,
            'Complete current source and its own cold import required')
    manifest = read(state['run_base'] / 'candidate_manifest.json')
    require(manifest.get('schema') == 'projectile_3365_integrated_manifest_v1'
            and len(manifest['files']) == 26 and len(manifest['native_assets']) == 1, 'Exact 26+1 manifest required')
    prep.merge_pins(state['pins'], named_pins)
    state['point'] = release_point(state['project'])
    p.pin(state['project'] / SNAPSHOT.removeprefix('res://'), state['pins'], state['point']['source_sha256'])
    return state


def slot_directory(profile):
    return io.owned(profile / USERDIR / 'continue/v1/5088120/1', profile)


def business(profile):
    user = io.owned(profile / USERDIR, profile)
    cfg = user / 'campaign.cfg'
    value = {'continue': io.snapshot(user / 'continue/v1'), 'campaign.cfg': {'exists': p.fs(cfg).is_file()}}
    if value['campaign.cfg']['exists']:
        value['campaign.cfg'].update(sha256=sha(cfg), bytes=p.fs(cfg).stat().st_size)
    return value


def slot_record(profile, generation, state):
    path = slot_directory(profile) / ('record_%010d.json' % generation)
    require(p.fs(path).is_file() and p.fs(path).stat().st_size <= 67108864, 'Expected bounded real slot record missing')
    raw = p.fs(path).read_bytes()
    envelope = json.loads(raw)
    keys = {'magic', 'version', 'app', 'owner', 'revision', 'previous_sha256', 'payload_bytes', 'payload_sha256', 'payload'}
    require(type(envelope) is dict and set(envelope) == keys and envelope['magic'] == 'LH_CLASSIC_CONTINUE_SLOT'
            and envelope['version'] == '1' and envelope['app'] == '5088120' and envelope['owner'] == '1'
            and envelope['revision'] == str(generation) and type(envelope['payload']) is str, 'Actual slot envelope identity changed')
    payload = envelope['payload'].encode('utf-8')
    require(envelope['payload_bytes'] == str(len(payload))
            and envelope['payload_sha256'] == hashlib.sha256(payload).hexdigest(), 'Actual payload byte binding changed')
    if generation == 1:
        require(envelope['previous_sha256'] == '0' * 64, 'Original generation must begin at the actual genesis hash')
    document = json.loads(payload)
    require(document.get('schema') == 'classic_continue_slot_v3'
            and integer(document.get('generation'), generation) and document.get('context') == CONTEXT
            and document.get('resume_paused') is True and document.get('binding', {}).get('kind') == 'uncredited'
            and document.get('world', {}).get('content_version') == CONTENT
            and document['world'].get('engine_sha256') == state['engine_sha256'], 'Actual classic fixed30 uncredited slot required')
    token = document['binding'].get('token', '')
    require(type(token) is str and re.fullmatch(r'[0-9a-f]{32}', token), 'Actual local run token required')
    return {'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
            'generation': generation, 'previous_sha256': envelope['previous_sha256'],
            'payload_sha256': envelope['payload_sha256'], 'binding': document['binding']}


class RecordReadDenial:
    """OPEN_EXISTING, read-only access, share zero; no bytes/ACL/attributes written."""
    def __init__(self, path, profile):
        self.path = io.owned(path, profile)
        require(p.fs(self.path).is_file(), 'Existing owned gen2 record required')
        self.handle = None
        self.api = ct.WinDLL('kernel32', use_last_error=True)
        self.api.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, ct.c_void_p, wt.DWORD, wt.DWORD, wt.HANDLE]
        self.api.CreateFileW.restype = wt.HANDLE
        self.api.CloseHandle.argtypes = [wt.HANDLE]
        self.api.CloseHandle.restype = wt.BOOL
        handle = self.api.CreateFileW(str(p.fs(self.path)), 0x80000000, 0, None, 3, 0x80, None)
        if handle == ct.c_void_p(-1).value:
            raise ct.WinError(ct.get_last_error())
        self.handle = handle

    def close(self):
        if self.handle is not None:
            require(bool(self.api.CloseHandle(self.handle)), 'Owned read-denial handle close failed')
            self.handle = None


def environment(base_env, profile, state, workers, bindings, stage, output, mode, batch, nonce, previous):
    env = dict(base_env)
    for key in list(env):
        if key.startswith(('USR_', 'P19_', 'DN_', 'DF_', 'GVT_', 'GT_', 'GLS_', 'CR_', 'CC_', 'RS_', 'LSH_CONTINUE_FLOW_')):
            env.pop(key)
    for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
        require(env.get(key) == str(profile / key.lower()), 'Shared private environment path changed')
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='1',
               LSH_CONTINUE_FLOW_PROFILE=str(profile), LSH_LANGUAGE='zh_CN',
               USR_MODE=mode, USR_OUTPUT=str(stage), USR_RUN=str(output), USR_PROFILE=str(profile),
               USR_PROJECT=str(state['project']), USR_CONTENT=CONTENT, USR_ENGINE=state['engine_sha256'],
               USR_MANIFEST=sha(state['run_base'] / 'candidate_manifest.json'),
               USR_SOURCES_SHA256=sha(HERE / 'sources.json'), USR_BATCH_NONCE=batch,
               USR_PROCESS_NONCE=nonce, USR_WORKERS=str(workers), USR_BINDINGS=str(bindings))
    if previous is not None:
        env.update(USR_PREVIOUS=str(previous), USR_PREVIOUS_SHA=sha(previous))
    return env


def gate(path, mode, phase, child, profile, state, batch, nonce):
    value = closed_json(path)
    if value is None:
        return None
    require(type(value) is dict and set(value) == GATE_KEYS and value['schema'] == 'ui_save_retry_gate_v1'
            and value['mode'] == mode and value['phase'] == phase and integer(value['pid'], child.pid)
            and value['batch_nonce'] == batch and value['process_nonce'] == nonce
            and Path(value['profile']) == profile and value['content_version'] == CONTENT
            and value['engine_sha256'] == state['engine_sha256'] and type(value['detail']) is dict,
            'Exact actual gate identity/phase/field set changed')
    return value


def ack(path, request, request_path):
    value = {key: item for key, item in request.items() if key != 'detail'}
    value.update(schema='ui_save_retry_ack_v1', request_sha256=sha(request_path), ok=True)
    require(len(value) == 11, 'Exact gate ACK shape changed')
    io.publish_ack(p.fs(path), value)


def actual_owner(path, profile, pid):
    path = io.owned(path, profile)
    require(path == slot_directory(profile) / 'writing/owner.json', 'Only actual slot owner file may be denied')
    raw = p.fs(path).read_bytes()
    value = json.loads(raw)
    require(type(value) is dict and set(value) == {'version', 'owner', 'pid', 'token'}
            and value['version'] == '1' and value['owner'] == '1' and value['pid'] == str(pid)
            and type(value['token']) is str and re.fullmatch(r'[0-9a-f]{32}', value['token']),
            'Actual writing owner must belong to held Popen')
    return {'path': str(path), 'raw': raw.decode('utf-8'), 'sha256': hashlib.sha256(raw).hexdigest(),
            'bytes': len(raw), 'metadata': value}


def validate_report(report, mode, child, profile, state, batch, nonce, record):
    require(report.get('schema') == 'ui_save_retry_three_process_v1'
            and report.get('mode') == mode and report.get('passed') is True and report.get('stage_completed') is True
            and report.get('failures') == [] and report.get('checks')
            and all(row.get('passed') is True for row in report['checks']), 'Actual worker checks/stage failed')
    require(integer(report.get('pid'), child.pid) and report.get('batch_nonce') == batch
            and report.get('process_nonce') == nonce and Path(report.get('profile', '')) == profile,
            'Actual report process/profile/nonces mismatch')
    identity = report.get('identity', {})
    require(identity.get('content_version') == CONTENT and identity.get('source_mode') is True
            and identity.get('engine_binary_sha256', identity.get('engine_sha256')) == state['engine_sha256']
            and report.get('context') == CONTEXT, 'Actual source/engine/classic context mismatch')
    require(report.get('candidate_manifest_sha256') == sha(state['run_base'] / 'candidate_manifest.json')
            and report.get('sources_sha256') == sha(HERE / 'sources.json'),
            'Actual worker report must retain the admitted manifest and exact tool-source binding')
    require(all(report.get(flag) is False for flag in FALSE_FLAGS), 'Report widened qualification')
    require(report.get('source_private_ui_save_retry_qualified') is False
            and report.get('no_gameplay_state_injection') is True
            and integer(report.get('simulation_time_scale'), 1) and integer(report.get('physics_hz'), 60),
            'Worker must retain ordinary simulation and cannot self-award the whole process chain')
    checkpoint = report.get('checkpoint', {})
    require(integer(checkpoint.get('generation'), record['generation']) and checkpoint.get('file_sha256') == record['sha256']
            and checkpoint.get('binding') == record['binding'] and Path(checkpoint.get('record_path', '')) == Path(record['path'])
            and Path(checkpoint.get('slot_directory', '')) == slot_directory(profile)
            and type(checkpoint.get('exact_snapshot')) is dict and checkpoint['exact_snapshot'],
            'Typed checkpoint must bind the actual closed slot record')
    wanted = 'ui_save_retry_verified' if mode == 'reject_then_resume' else 'continue_saved'
    require(report.get('exit_reason') == wanted and report.get('save_exit_observed') is (mode != 'reject_then_resume'),
            'Actual production SaveAndExit / final no-save test quit differs')


def execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous_record):
    row = {'mode': mode, 'profile': str(profile), 'process_nonce': nonce, 'complete': False,
           'process_terminal': False, 'gates': [], 'debug_stops': [], 'faults': [], 'post_errors': [],
           'debugger_locals_read': False, 'host_production_object_injection': False}
    child = listener = connection = peer = handle = None
    phase_index = 0
    thread_id = None
    release_armed = False
    release_hits = 0
    held_owner = None
    held_inventory = None
    record_denial_before = None
    expected_cas = None
    point = state['point']
    before = None
    log_path = stage / 'native.log'
    start = time.monotonic()

    def set_release(enabled):
        nonlocal release_armed
        peer.command('breakpoint', thread_id, [point['source'], point['line'], enabled])
        release_armed = enabled

    try:
        require(os.name == 'nt' and not baseline.engines(), 'Owned Windows engine lane must be idle')
        before = business(profile)
        row['before_business'] = before
        row['before_local_lifecycle'] = io.snapshot(profile / USERDIR / 'continue/v1/local_runs')
        listener = socket.socket()
        listener.bind(('127.0.0.1', 0)); listener.listen(1); listener.settimeout(30)
        command = [str(state['engine']), '--path', str(state['project']), '--rendering-method', 'gl_compatibility',
                   '--resolution', '1280x720', '--position', '30000,30000', '--remote-debug',
                   'tcp://127.0.0.1:' + str(listener.getsockname()[1]), '--script', str(workers / 'bootstrap.gd')]
        row['command'] = command
        with p.fs(log_path).open('xb') as stream:
            child = subprocess.Popen(command, cwd=state['project'], env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            row['pid'] = child.pid
            connection, _ = listener.accept(); listener.close(); listener = None
            connection.settimeout(.1); peer = wire.DebugConnection(connection)
            deadline, notice = start + state['timeout'], time.monotonic()
            while child.poll() is None:
                require(time.monotonic() < deadline, 'Owned UI stage deadline exceeded')
                require(not baseline.engines() - {child.pid}, 'Foreign engine appeared; never control it')
                if time.monotonic() - notice >= 25:
                    print('RUNNING', mode, 'pid', child.pid, 'gates', phase_index, 'release_hits', release_hits, flush=True)
                    notice = time.monotonic()
                if thread_id is not None and phase_index < len(PHASES[mode]):
                    phase = PHASES[mode][phase_index]
                    request_path = stage / (phase + '.request.json')
                    request = gate(request_path, mode, phase, child, profile, state, batch, nonce)
                    if request is not None:
                        observation = {'request': request, 'request_path': str(request_path),
                                       'request_sha256': sha(request_path), 'monotonic_ns': time.monotonic_ns()}
                        row['gates'].append(observation)
                        detail = request['detail']
                        if phase == 'arm_owner_release':
                            require(previous_record is not None and integer(detail.get('expected_revision'), 1)
                                    and detail.get('expected_sha256') == previous_record['sha256']
                                    and io.owned(detail['slot_directory'], profile) == slot_directory(profile)
                                    and io.owned(detail['owner_path'], profile) == slot_directory(profile) / 'writing/owner.json',
                                    'Confirm gate must retain original slot CAS and owner path')
                            require(not p.fs(slot_directory(profile) / 'writing').exists()
                                    and business(profile) == before, 'Cancel/Confirm may not change original business files')
                            expected_cas = {'revision': 1, 'file_sha256': detail['expected_sha256']}
                            set_release(True)
                        elif phase == 'arm_retry_release':
                            require(release_hits == 1 and not release_armed and handle is not None
                                    and detail.get('expected_code') == 'LOCK_RELEASE'
                                    and io.owned(detail['owner_path'], profile) == slot_directory(profile) / 'writing/owner.json'
                                    and integer(detail.get('expected_revision'), expected_cas['revision'])
                                    and detail.get('expected_sha256') == expected_cas['file_sha256'],
                                    'Actual first failure must precede arming the separate UI retry stop')
                            require(actual_owner(detail['owner_path'], profile, child.pid) == held_owner
                                    and business(profile) == held_inventory,
                                    'The first failed save must retain the same original owner and committed proposal')
                            observation['first_failure_boundary_with_original_handle'] = True
                            set_release(True)
                            observation['retry_breakpoint_rearmed_ns'] = time.monotonic_ns()
                        elif phase == 'release_retry_handles':
                            require(release_hits == 2 and not release_armed and handle is not None
                                    and detail.get('expected_code') == 'LOCK_RELEASE'
                                    and io.owned(detail['owner_path'], profile) == slot_directory(profile) / 'writing/owner.json',
                                    'Both actual same-owner release failures required before unlock')
                            require(actual_owner(detail['owner_path'], profile, child.pid) == held_owner
                                    and business(profile) == held_inventory, 'Same failed proposal/owner files changed before retry release')
                            handle.close(); handle = None
                            observation['closed_owned_handle_ns'] = time.monotonic_ns()
                            require(business(profile) == held_inventory, 'Closing own handle may not alter business bytes')
                        elif phase == 'arm_record_read':
                            require(previous_record is not None and previous_record['generation'] == 2
                                    and io.owned(detail['slot_directory'], profile) == slot_directory(profile)
                                    and io.owned(detail['record_path'], profile) == Path(previous_record['path'])
                                    and detail.get('record_sha256') == previous_record['sha256']
                                    and sha(detail['record_path']) == previous_record['sha256'], 'Actual existing gen2 record gate required')
                            record_denial_before = business(profile)
                            require(record_denial_before == before, 'Startup before the actual menu Continue changed business files')
                            handle = RecordReadDenial(detail['record_path'], profile)
                            row['faults'].append({'kind': 'existing_record_read_denial', 'path': detail['record_path'],
                                                  'native_share_mode': 0, 'open_existing': True,
                                                  'before_sha256': previous_record['sha256'], 'armed_ns': time.monotonic_ns(),
                                                  'no_file_bytes_written': True})
                        elif phase == 'release_record_read':
                            require(handle is not None and detail.get('expected_code') == 'READ_OPEN'
                                    and io.owned(detail['record_path'], profile) == Path(previous_record['path']),
                                    'Actual menu refusal/CloseError must precede release of original record handle')
                            handle.close(); handle = None
                            observation['closed_owned_handle_ns'] = time.monotonic_ns()
                            require(business(profile) == record_denial_before, 'Refusal or CloseError changed original slot/lifecycle')
                            row['faults'][-1].update(after_sha256=sha(previous_record['path']), bytes_unchanged_after_close=True,
                                                      released_ns=observation['closed_owned_handle_ns'])
                        ack(stage / (phase + '.ack.json'), request, request_path)
                        observation['ack_sha256'] = sha(stage / (phase + '.ack.json'))
                        phase_index += 1
                try:
                    message, packet = peer.receive()
                except socket.timeout:
                    continue
                except EOFError:
                    break
                name, thread, data = message
                if name == 'set_pid':
                    require(data == [child.pid], 'Debugger PID does not match owned Popen')
                    thread_id = thread
                elif name == 'debug_enter':
                    require(mode == 'retry_save' and release_armed and data == [True, 'Breakpoint', True, thread],
                            'Unexpected debugger or native error stop')
                    peer.command('get_stack_dump', thread)
                elif name == 'stack_dump':
                    frames = wire.stack_frames(data)
                    require(mode == 'retry_save' and release_armed and release_hits < 2
                            and frames[0] == {key: point[key] for key in ('source', 'line', 'function')},
                            'Exact original owner-release frame required')
                    stop = {'pid': child.pid, 'process_nonce': nonce, 'frames': frames,
                            'source_sha256': sha(state['project'] / SNAPSHOT.removeprefix('res://')),
                            'stack_packet_sha256': hashlib.sha256(packet).hexdigest(), 'monotonic_ns': time.monotonic_ns()}
                    row['debug_stops'].append(stop)
                    require(stop['source_sha256'] == point['source_sha256'], 'Running release source changed')
                    wanted = [('res://scripts/run_slot_store.gd', 'write_slot'),
                              ('res://scripts/run_world_session.gd', 'save_held'),
                              ('res://scripts/continue_flow.gd', '_capture_ready')] if release_hits == 0 else [
                              (SNAPSHOT, 'retry_owned_commit'), ('res://scripts/run_slot_store.gd', 'retry_pending_write'),
                              ('res://scripts/run_world_session.gd', 'retry_pending_save'),
                              ('res://scripts/continue_flow.gd', 'retry_save')]
                    ordered = [(frame['source'], frame['function']) for frame in frames[1:]]
                    cursor = 0
                    for expected in wanted:
                        require(expected in ordered[cursor:], 'Wrong Store/Session/Flow release call chain')
                        cursor = ordered.index(expected, cursor) + 1
                    current_owner = actual_owner(slot_directory(profile) / 'writing/owner.json', profile, child.pid)
                    record = slot_record(profile, 2, state)
                    require(record['previous_sha256'] == expected_cas['file_sha256']
                            and record['binding'] == previous_record['binding'], 'Gen2 must extend original gen1 same token')
                    inventory = business(profile)
                    stop.update(owner=current_owner, committed_record=record, business_inventory=inventory, expected_cas=expected_cas)
                    if release_hits == 0:
                        held_owner, held_inventory = current_owner, inventory
                        handle = io.NativeSharingDenial(Path(current_owner['path']), profile, 'owner_delete_retry')
                        require(handle.path == slot_directory(profile) / 'writing/owner.json', 'Never hold writing directory itself')
                        row['faults'].append({'kind': 'existing_owner_delete_denial', 'path': current_owner['path'],
                                              'native_share_mode': 3, 'open_existing': True,
                                              'owner_sha256': current_owner['sha256'], 'armed_ns': time.monotonic_ns(),
                                              'only_owner_file_not_writing_directory': True})
                    else:
                        require(handle is not None and current_owner == held_owner and inventory == held_inventory,
                                'Retry must reach same retained owner and already committed gen2 without rewriting')
                        row['faults'][-1]['second_release_reached_with_original_handle'] = True
                    # One arm accepts one original call chain. Disable before resuming
                    # either stop; the first native failure must reach the separate GD
                    # arm_retry_release gate before the real RetrySave is armed again.
                    set_release(False)
                    stop['breakpoint_removed_before_continue'] = True
                    stop['breakpoint_removed_ns'] = time.monotonic_ns()
                    release_hits += 1
                    peer.command('continue', thread)
            child.wait(timeout=20)
        row.update(exit_code=child.returncode, process_terminal=True, seconds=round(time.monotonic() - start, 3))
        require(child.returncode == 0 and phase_index == len(PHASES[mode]) and not release_armed and handle is None,
                'Actual terminal process or fault handshake incomplete')
        require(release_hits == (2 if mode == 'retry_save' else 0), 'Actual release fault count changed')
        for observed in row['gates']:
            request_path = Path(observed['request_path'])
            ack_path = stage / (observed['request']['phase'] + '.ack.json')
            require(sha(request_path) == observed['request_sha256'] and sha(ack_path) == observed['ack_sha256'],
                    'Closed request/ACK bytes changed after the actual fault gate')
        text = p.fs(log_path).read_text(encoding='utf-8', errors='replace')
        errors = [line for line in text.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line or 'Parse Error:' in line]
        row['native_errors'] = errors
        require(not errors, 'Unexpected native parse/runtime error is not fault qualification')
        record = slot_record(profile, 1 if mode == 'save_initial' else 2, state)
        report_path = stage / 'report.json'
        report = read(report_path)
        validate_report(report, mode, child, profile, state, batch, nonce, record)
        if mode == 'retry_save':
            observations = report.get('observations', {})
            first = observations.get('first_failure', {})
            blocked = observations.get('blocked_retry', {})
            require(type(first) is dict and first and first == blocked
                    and first.get('owner_raw') == held_owner['raw']
                    and first.get('owner_sha256') == held_owner['sha256']
                    and io.owned(first.get('owner_path', ''), profile) == Path(held_owner['path'])
                    and io.owned(first.get('directory', ''), profile) == slot_directory(profile)
                    and integer(first.get('expected_revision'), 1)
                    and first.get('expected_sha256') == previous_record['sha256']
                    and integer(first.get('proposal_record_generation'), 2)
                    and first.get('proposal_record_sha256') == record['payload_sha256']
                    and first.get('barrier_held') is True and first.get('tree_paused') is True
                    and first.get('locked') is True and first.get('clock_ok') is True
                    and first.get('exact_clock') == first.get('exact_session_clock'),
                    'Real GD pending-object observations must bind both host-owned failure stops and the original gen2 bytes')
        elif mode == 'reject_then_resume':
            refusal = report.get('observations', {}).get('continue_read_refusal', {})
            require(refusal.get('ok') is False and refusal.get('code') == 'READ_OPEN'
                    and not refusal.get('pending_save', False) and not refusal.get('battle_held', False),
                    'Actual menu Continue must report the real read refusal before successful restoration')
        require(not p.fs(slot_directory(profile) / 'writing').exists()
                and not p.fs(slot_directory(profile) / 'receipt.pending').exists(), 'Successful stage must leave no pending slot writer')
        require(sorted(name for name in io.snapshot(slot_directory(profile))['files'] if name.startswith('record_'))
                == ['record_%010d.json' % value for value in range(1, record['generation'] + 1)],
                'Only expected slot generations may exist')
        if mode != 'save_initial':
            require(record['binding'] == previous_record['binding'], 'Local token/binding changed across process')
            require(io.snapshot(profile / USERDIR / 'continue/v1/local_runs') == row['before_local_lifecycle'],
                    'Retry/restore may not add local lifecycle records')
            require(business(profile)['campaign.cfg'] == before['campaign.cfg'], 'Save retry/restore may not change campaign progression')
        if mode == 'retry_save':
            require(record['previous_sha256'] == previous_record['sha256']
                    and slot_record(profile, 1, state) == previous_record,
                    'The successful retry must append exactly gen2 to the unchanged original gen1')
        if mode == 'reject_then_resume':
            require(record == previous_record and business(profile) == before, 'Final restore or test quit changed durable business files')
        row.update(complete=True, report_path=str(report_path), report_sha256=sha(report_path),
                   actual_checks=len(report['checks']), record=record, actual_gate_count=phase_index,
                   actual_release_breakpoints=release_hits)
    except BaseException as error:
        row.update(error=repr(error), traceback=traceback.format_exc(), complete=False)
    finally:
        def terminal():
            if child is None:
                row['process_terminal'] = True
                row['process_not_started'] = True
                return
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait(timeout=20)
            row.update(pid=child.pid, exit_code=child.returncode, process_terminal=child.poll() is not None)
        attempt(row, 'owned_popen_terminal', terminal)
        if handle is not None:
            ok, _ = attempt(row, 'close_owned_native_handle', handle.close)
            if ok:
                handle = None
        row['owned_handles_closed'] = handle is None
        if connection is not None:
            attempt(row, 'close_debug_connection', connection.close)
        if listener is not None:
            attempt(row, 'close_debug_listener', listener.close)
        ok, after = attempt(row, 'final_business_inventory', lambda: business(profile))
        if ok:
            row['after_business'] = after
        row['raw_pins'] = {}
        for path in [log_path, stage / 'report.json', *[stage / (phase + suffix) for phase in PHASES[mode]
                                                     for suffix in ('.request.json', '.ack.json')]]:
            def pin_raw(path=path):
                if p.fs(path).is_file():
                    row['raw_pins'][str(path)] = sha(path)
            attempt(row, 'pin raw ' + path.name, pin_raw)
        if row['post_errors']:
            row['complete'] = False
        persist(stage / 'controller.json', row)
    return row


def execute(args):
    cases, named_pins = named_state()
    output = ROOT / '.godot/ui_save_retry_20261027' / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {'schema': 'ui_save_retry_runner_v1', 'complete': False, 'three_process_flow_qualified': False,
               'steps': [], 'post_errors': [], 'named_pins': named_pins, 'base_run': str(args.base_run.resolve()),
               'debugger_locals_read': False, **{flag: False for flag in FALSE_FLAGS}}
    state = None
    locked = False
    owner = str(output)
    pins = dict(named_pins)
    batch = uuid.uuid4().hex
    receipt['batch_nonce'] = batch
    try:
        started = time.monotonic()
        while not locked:
            if not p.fs(h.shared.LOCK).exists() and not baseline.engines():
                try:
                    with p.fs(h.shared.LOCK).open('x', encoding='utf-8') as stream:
                        stream.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            require(time.monotonic() - started < args.wait_lane, 'Shared lane occupied; no engine started')
            time.sleep(1)
        require(not baseline.engines(), 'Foreign engine appeared before full source admission')
        state = full_state(args.base_run, named_pins); state['timeout'] = args.timeout; pins = state['pins']
        receipt.update(project=str(state['project']), source_identity=CONTENT, engine_sha256=state['engine_sha256'],
                       initial_identity_passed=True, cold_import_qualified=True, breakpoint=state['point'])
        for name, expected in list(pins.items()):
            source = Path(name)
            if source.suffix.lower() == '.exe':
                continue
            require(source.is_relative_to(ROOT), 'Non-binary source must be repository-owned')
            target = output / 'runner_inputs' / source.relative_to(ROOT)
            p.copy(source, target, expected); p.pin(target, pins, expected)
        workers = output / 'workers'; p.fs(workers).mkdir()
        bindings_value = {}
        for name in WORKERS:
            p.copy(HERE / name, workers / name, pins[str(HERE / name)])
            p.pin(workers / name, pins); bindings_value[name] = sha(workers / name)
        bindings = workers / 'bindings.json'; h.save(p.fs(bindings), bindings_value); p.pin(bindings, pins)
        profile = Path(ROOT.anchor) / 'CodexQA/ui_save_retry' / batch[:12]
        h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
        base_env = h.common.private_environment(profile)
        receipt['profile'] = str(profile)
        previous = previous_record = None
        seen = set()
        for index, mode in enumerate(MODES):
            p.verify_pins(pins)
            stage = output / ('%02d_' % index + mode); p.fs(stage).mkdir()
            nonce = uuid.uuid4().hex
            env = environment(base_env, profile, state, workers, bindings, stage, output, mode, batch, nonce, previous)
            row = execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous_record)
            receipt['steps'].append(row)
            require(row.get('complete') is True and type(row.get('pid')) is int and row['pid'] not in seen,
                    'Actual independent UI process failed')
            seen.add(row['pid'])
            for name, expected in row['raw_pins'].items():
                p.pin(name, pins, expected)
            p.pin(stage / 'controller.json', pins)
            previous = Path(row['report_path']); previous_record = row['record']
            p.verify_pins(pins)
            print('PASS', index, mode, 'pid', row['pid'], 'checks', row['actual_checks'], flush=True)
        require(len(seen) == 3 and len(receipt['steps']) == 3, 'Exactly three actual independent processes required')
        receipt['three_process_flow_qualified'] = True
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
        receipt['all_owned_handles_closed'] = all(row.get('owned_handles_closed') is True for row in receipt['steps'])
        def unlock():
            receipt['engine_lane_idle'] = not baseline.engines()
            receipt['lock_owner_verified'] = bool(locked and p.fs(h.shared.LOCK).is_file()
                                                  and p.fs(h.shared.LOCK).read_text(encoding='utf-8') == owner)
            if receipt['engine_lane_idle'] and receipt['lock_owner_verified'] and receipt['all_owned_children_terminal'] and receipt['all_owned_handles_closed']:
                p.fs(h.shared.LOCK).unlink(); receipt['lock_released'] = not p.fs(h.shared.LOCK).exists()
        attempt(receipt, 'owned_lock_release', unlock)
        receipt['complete'] = bool(receipt['three_process_flow_qualified'] and receipt['final_identity_passed']
                                   and receipt.get('lock_released') and not receipt['post_errors'] and 'error' not in receipt)
        if not receipt['complete']:
            receipt['three_process_flow_qualified'] = False
        receipt['actual_process_count'] = sum(type(row.get('pid')) is int for row in receipt['steps'])
        receipt['actual_checks'] = sum(row.get('actual_checks', 0) for row in receipt['steps'])
        receipt['pinned_files'] = pins
        persist(output / 'receipt.json', receipt)
    print(json.dumps({'output': str(output), 'complete': receipt['complete'],
                      'actual_process_count': receipt['actual_process_count'], 'error': receipt.get('error')}, ensure_ascii=False), flush=True)
    if not receipt['complete']:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-run', type=Path, default=ROOT / BASE_REL)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--full-preflight', action='store_true', help='Explicit expensive whole-source read-only admission')
    parser.add_argument('--timeout', type=int, default=600, help='Bounded seconds per actual process, excluding whole-source admission')
    parser.add_argument('--wait-lane', type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 60 or args.wait_lane < 0:
        parser.error('Invalid bounded deadline')
    if args.run:
        execute(args)
        return
    cases, pins = named_state()
    state = full_state(args.base_run, pins) if args.full_preflight else None
    print(json.dumps({'schema': 'ui_save_retry_named_preflight_v1', 'named_sources_verified': True,
                      'named_pins': len(pins), 'stages': list(MODES), 'source_identity': CONTENT,
                      'full_source_verified': state is not None, 'cold_import_qualified': state is not None,
                      'engine_started': False, 'profile_created': False, 'native_executed': False,
                      'three_process_flow_qualified': False, **{flag: False for flag in FALSE_FLAGS}}, ensure_ascii=False))


if __name__ == '__main__':
    main()
