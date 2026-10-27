"""B2: real prepared preference transaction, Startup retry, independent readback.

Default checks only named tool sources. --run admits the fixed full b22 freeze
and its own cold import, then owns the shared lane for three isolated processes.
No B1 runtime result is required or transferred. No business payload is injected.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
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
WORKERS = ('bootstrap.gd', 'base.gd', 'worker.gd')
MODES = ('prepare_crash', 'startup_retry', 'readback')
CFG_SOURCE = 'res://scripts/run_campaign_cfg_transaction.gd'
PHASES = {'prepare_crash': ('prepared_armed',), 'startup_retry': ('release_candidate_install',), 'readback': ()}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Source-only reuse of closed B1 filesystem/identity helpers, never B1 admission,
# workers, qualification, or its engine runner. All imported bytes are named pins.
b1 = load('ust_closed_b1_helpers', HERE.parent / 'ui_config_retry/run_ui_config_retry.py')
p, h, io, prep, baseline = b1.p, b1.h, b1.io, b1.prep, b1.baseline
wire = load('ust_debug_wire', ROOT / 'tools/godot_debug_wire.py')
require, sha, read, integer = b1.require, b1.sha, b1.read, b1.integer
closed_json, attempt = b1.closed_json, b1.attempt
paths, business, file_row, observer_disk = b1.paths, b1.business, b1.file_row, b1.observer_disk
ZERO, FALSE_FLAGS = b1.ZERO, b1.FALSE_FLAGS


def persist(path, row):
    try:
        h.save(p.fs(path), row)
        return True
    except BaseException as error:
        row.setdefault('post_errors', []).append({'phase': 'save ' + str(path), 'error': repr(error),
                                                  'traceback': traceback.format_exc()})
        row['complete'] = False
        if 'three_process_startup_retry_qualified' in row: row['three_process_startup_retry_qualified'] = False
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


def provider_reports(profile):
    root = io.owned(paths(profile)['user'] / 'process_liveness/v2', profile)
    inventory = io.snapshot(root)
    require(len(inventory['files']) <= 64 and len(inventory['directories']) <= 65,
            'Native helper IPC evidence must remain bounded')
    rows = []
    for name, item in sorted(inventory['files'].items()):
        rel = Path(name)
        require(len(rel.parts) == 2 and re.fullmatch(r'[0-9a-f]{32}', rel.parts[0])
                and rel.parts[1] in ('pending.json', 'result.json') and 0 < item['bytes'] <= 4096,
                'Unexpected native helper IPC path/size')
        path = io.owned(root / rel, profile)
        value = read(path)
        rows.append({'path': str(path), 'sha256': item['sha256'], 'bytes': item['bytes'],
                     'nonce': rel.parts[0], 'closed': rel.parts[1] == 'result.json', 'record': value})
    return rows


def verify_dead_providers(rows, producer_pid):
    fields = {'code', 'creation_filetime', 'handle_opened', 'nonce', 'provider_pid', 'query_utc_filetime',
              'schema', 'state', 'target_pid', 'wait_result', 'win32_error'}
    require(rows, 'Actual normal Startup must query the real terminated producer')
    for row in rows:
        value = row['record']
        require(row['closed'] and type(value) is dict and set(value) == fields
                and type(value['handle_opened']) is bool
                and all(type(item) is str for key, item in value.items() if key != 'handle_opened')
                and value['schema'] == 'windows_process_liveness_v1' and value['nonce'] == row['nonce']
                and value['target_pid'] == str(producer_pid) and re.fullmatch(r'[1-9][0-9]*', value['provider_pid'])
                and value['state'] == 'dead', 'Native dead-owner IPC must bind the actual terminated producer, never unknown=false')
        require((value['code'] == 'HANDLE_SIGNALED' and value['handle_opened']
                 and re.fullmatch(r'[1-9][0-9]*', value['creation_filetime']) and value['wait_result'] == '0' and value['win32_error'] == '0')
                or (value['code'] == 'PID_ABSENT_87' and not value['handle_opened']
                    and value['creation_filetime'] == '' and value['wait_result'] == 'not_queried' and value['win32_error'] == '87'),
                'Actual native dead outcome matrix inconsistent')


def module_paths():
    return [Path(b1.__file__), *b1.module_paths(), Path(wire.__file__)]


def named_state():
    sources = read(HERE / 'sources.json')
    require(sources.get('schema') == 'ui_startup_retry_sources_v1', 'Explicit B2 source schema required')
    required = {str((HERE / name).relative_to(ROOT).as_posix()) for name in
                ('README.md', 'cases.json', 'run_ui_startup_retry.py', *WORKERS)}
    rows = sources.get('files', [])
    require(type(rows) is list and len(rows) == 6 and {row['path'] for row in rows} == required,
            'Exactly six B2 input sources must be bound')
    pins = {}
    for row in [*rows, *sources.get('dependencies', [])]:
        rel = Path(row['path'])
        require(not rel.is_absolute() and '..' not in rel.parts, 'Named source must remain repository-owned')
        path = ROOT / rel
        require(path.suffix.lower() not in ('.exe', '.dll', '.pck'), 'Named default must not hash binary assets')
        p.pin(path, pins, row['sha256'])
        require(p.fs(path).stat().st_size == row['bytes'], 'Named source bytes changed: ' + str(path))
    require({str(path) for path in module_paths()}.issubset(set(pins)), 'Imported helper source missing from dependencies')
    p.pin(HERE / 'sources.json', pins)
    cases = read(HERE / 'cases.json')
    require(cases.get('schema') == 'ui_startup_retry_cases_v1' and cases.get('source_identity') == CONTENT
            and Path(cases.get('base_run', '')) == BASE_REL and cases.get('required_script_count') == 26
            and cases.get('required_native_count') == 1 and cases.get('requires_own_cold_import') is True
            and cases.get('native_process_count') == 3 and cases.get('profile_count') == 1
            and cases.get('worker_files') == list(WORKERS), 'Exact fixed-source three-process contract required')
    require([case.get('mode') for case in cases.get('stages', [])] == list(MODES)
            and [case.get('index') for case in cases['stages']] == [0, 1, 2]
            and [case.get('expected_journal_generation') for case in cases['stages']] == [1, 2, 2]
            and all(cases.get('qualification', {}).get(flag) is False for flag in FALSE_FLAGS),
            'Stage order, prepared/applied generations, or qualification boundary changed')
    return cases, pins


def install_point(project):
    source = project / CFG_SOURCE.removeprefix('res://')
    lines = p.fs(source).read_text(encoding='utf-8').splitlines()
    statement = '_checkpoint("cfg_before_install")'
    found = [index + 1 for index, line in enumerate(lines) if line.strip() == statement]
    require(found == [394], 'Unique actual b22 cfg_before_install statement changed')
    function = next(line for line in reversed(lines[:found[0]]) if line.startswith('func '))
    require(function == 'func _replace_and_verify(record: Dictionary) -> Dictionary:', 'Unexpected install function')
    return {'source': CFG_SOURCE, 'line': 394, 'function': '_replace_and_verify',
            'statement': statement, 'source_sha256': sha(source)}


def full_state(base_run, named_pins):
    state = b1.full_state(base_run, named_pins)
    state['point'] = install_point(state['project'])
    p.pin(state['project'] / CFG_SOURCE.removeprefix('res://'), state['pins'], state['point']['source_sha256'])
    return state


def owner_row(profile, expected_pid):
    path = paths(profile)['journal'] / 'writing/owner.json'
    raw = p.fs(io.owned(path, profile)).read_bytes()
    owner = json.loads(raw)
    require(type(owner) is dict and set(owner) == {'version', 'owner', 'pid', 'token'}
            and owner['version'] == '1' and owner['owner'] == '1' and owner['pid'] == str(expected_pid)
            and type(owner['token']) is str and re.fullmatch(r'[0-9a-f]{32}', owner['token']),
            'Actual complete journal owner must belong to this recorded child')
    return {'path': path.as_posix(), 'raw': raw.decode('utf-8'), 'sha256': hashlib.sha256(raw).hexdigest(),
            'bytes': len(raw), 'metadata': owner}


def prepared_record(profile, state, owner_pid):
    """Read the actual closed rev1, candidate and owner; never construct/save a proposal."""
    found = paths(profile)
    inventory = io.snapshot(found['journal'])
    require(inventory['exists'] and inventory['directories'] == ['.', 'writing']
            and sorted(inventory['files']) == ['record_0000000001.json', 'writing/owner.json'],
            'Real prepared1 plus complete owner, no pending/gen2/unknown residue required')
    path = found['journal'] / 'record_0000000001.json'
    require(p.fs(path).stat().st_size <= 65536, 'Production journal size limit exceeded')
    raw = p.fs(path).read_bytes()
    envelope = json.loads(raw)
    require(type(envelope) is dict and set(envelope) == b1.ENVELOPE_FIELDS
            and all(type(value) is str for value in envelope.values())
            and envelope['magic'] == 'LH_CAMPAIGN_CFG_TRANSACTION' and envelope['version'] == '1'
            and envelope['app'] == '5088120' and envelope['owner'] == '1' and envelope['revision'] == '1'
            and envelope['previous_sha256'] == ZERO, 'Actual prepared genesis envelope required')
    payload = envelope['payload'].encode('utf-8')
    require(envelope['payload_bytes'] == str(len(payload))
            and envelope['payload_sha256'] == hashlib.sha256(payload).hexdigest(), 'Actual journal payload SHA mismatch')
    document = json.loads(payload)
    require(type(document) is dict and set(document) == b1.DOCUMENT_FIELDS
            and all(type(value) is str for key, value in document.items() if key != 'generation')
            and document['schema'] == 'campaign_cfg_transaction_v1' and integer(document['generation'], 1)
            and document['state'] == 'prepared' and re.fullmatch(r'[0-9a-f]{32}', document['transaction'])
            and document['original_sha256'] == ZERO and document['original_owner'] == '' and document['target_owner'] == ''
            and document['content_version'] == CONTENT and document['engine_sha256'] == state['engine_sha256']
            and document['operation'] == 'prefs' and document['run_token'] == '' and document['intent_sha256'] == ''
            and all(re.fullmatch(r'[0-9a-f]{64}', document[key]) for key in ('candidate_sha256', 'semantics_sha256')),
            'Exact prepared preference scope and original absence required')
    transaction = document['transaction']
    candidate = io.owned(found['blocker'] / 'v1' / transaction / 'candidate.cfg', profile)
    tree = io.snapshot(found['blocker'])
    require(tree['exists'] and tree['directories'] == ['.', 'v1', 'v1/' + transaction]
            and list(tree['files']) == ['v1/' + transaction + '/candidate.cfg']
            and tree['files']['v1/' + transaction + '/candidate.cfg']['sha256'] == document['candidate_sha256']
            and not p.fs(found['cfg']).exists() and p.fs(found['settings']).is_file(),
            'Exact pre-install candidate must exist while public CFG is still absent')
    return {'path': path.as_posix(), 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
            'payload_sha256': envelope['payload_sha256'], 'document': document,
            'candidate': file_row(candidate, profile), 'owner': owner_row(profile, owner_pid),
            'disk': observer_disk(profile), 'business': business(profile)}


def environment(base_env, profile, state, workers, bindings, stage, output, mode, batch, nonce, previous):
    env = dict(base_env)
    for key in list(env):
        if key.startswith(('UST_', 'UCR_', 'USR_', 'P19_', 'DN_', 'DF_', 'GVT_', 'GT_', 'GLS_', 'CR_', 'CC_', 'RS_', 'LSH_CONTINUE_FLOW_')):
            env.pop(key)
    for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
        require(env.get(key) == str(profile / key.lower()), 'Single private profile environment changed')
    for key in ('LEVEL', 'SKIRMISH', 'SMOKE_TEST', 'SCREENSHOT_DIR', 'SKIRMISH_AI'):
        env[key] = ''
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='', LSH_CONTINUE_FLOW_PROFILE='', LSH_LANGUAGE='zh_CN',
               UST_MODE=mode, UST_OUTPUT=str(stage), UST_RUN=str(output), UST_PROFILE=str(profile),
               UST_PROJECT=str(state['project']), UST_CONTENT=CONTENT, UST_ENGINE=state['engine_sha256'],
               UST_MANIFEST=sha(state['run_base'] / 'candidate_manifest.json'), UST_SOURCES_SHA256=sha(HERE / 'sources.json'),
               UST_BATCH_NONCE=batch, UST_PROCESS_NONCE=nonce, UST_WORKERS=str(workers), UST_BINDINGS=str(bindings))
    if previous is not None:
        env.update(UST_PREVIOUS=str(previous), UST_PREVIOUS_SHA=sha(previous))
    return env


def exact_identity(value, schema, mode, pid, profile, state, batch, nonce):
    require(type(value) is dict and value.get('schema') == schema and value.get('mode') == mode
            and integer(value.get('pid'), pid) and value.get('batch_nonce') == batch
            and value.get('process_nonce') == nonce and Path(value.get('profile', '')) == profile,
            'Actual observation process/profile/nonces mismatch')
    identity = value.get('identity', {})
    require(identity.get('content_version') == CONTENT and identity.get('source_mode') is True
            and identity.get('engine_sha256', identity.get('engine_binary_sha256')) == state['engine_sha256']
            and value.get('candidate_manifest_sha256') == sha(state['run_base'] / 'candidate_manifest.json')
            and value.get('sources_sha256') == sha(HERE / 'sources.json'), 'Actual observation source binding mismatch')


def gate(path, mode, phase, child, profile, state, batch, nonce):
    value = closed_json(path)
    if value is None:
        return None
    require(type(value) is dict and set(value) == b1.GATE_KEYS and value['schema'] == 'ui_startup_retry_gate_v1'
            and value['mode'] == mode and value['phase'] == phase and integer(value['pid'], child.pid)
            and value['batch_nonce'] == batch and value['process_nonce'] == nonce and Path(value['profile']) == profile
            and value['content_version'] == CONTENT and value['engine_sha256'] == state['engine_sha256']
            and type(value['detail']) is dict, 'Exact live gate identity/phase/field set mismatch')
    return value


def ack(path, request, request_path):
    value = {key: item for key, item in request.items() if key != 'detail'}
    value.update(schema='ui_startup_retry_ack_v1', request_sha256=sha(request_path), ok=True)
    require(len(value) == 11, 'Exact gate ACK shape changed')
    io.publish_ack(p.fs(path), value)


def check_worker_checks(value):
    require(type(value.get('checks')) is list and value['checks']
            and all(row.get('passed') is True for row in value['checks']), 'Actual native worker checks failed')


def check_producer_observation(value, submitted, child, profile, state, batch, nonce):
    exact_identity(value, 'ui_startup_producer_observation_v1', 'prepare_crash', child.pid, profile, state, batch, nonce)
    check_worker_checks(value)
    require(value.get('submitted') is submitted and value.get('precondition_checks_passed') is True
            and value.get('stage_completed') is False and value.get('controlled_crash_completed') is False
            and type(value.get('chosen_prefs')) is dict and value['chosen_prefs']
            and type(value.get('exact_chosen_prefs')) is dict and value['exact_chosen_prefs'], 'Real UI choice/submission evidence required')
    if submitted:
        require(value.get('prefs_deferred') is True, 'Actual Settings save must request the later Campaign write')


def preserved_fixture(stage, prepared, submitted, child, profile, state, batch, nonce, row):
    copies = stage / 'private_prepared_scope'; p.fs(copies).mkdir(exist_ok=False)
    mapping = []
    for name, source, expected in (
            ('record_0000000001.json', Path(prepared['path']), prepared['sha256']),
            ('candidate.cfg', Path(prepared['candidate']['path']), prepared['candidate']['sha256']),
            ('owner.json', Path(prepared['owner']['path']), prepared['owner']['sha256'])):
        target = copies / name
        p.copy(source, target, expected)
        mapping.append({'source': str(source), 'frozen_path': str(target), 'sha256': expected,
                        'bytes': p.fs(target).stat().st_size, 'private_business_payload': True, 'git_archive_allowed': False})
    row['private_business_copies'] = mapping
    require(child.poll() is None, 'Only our stopped live producer may be deliberately terminated')
    child.terminate(); child.wait(timeout=20)
    require(child.returncode != 0, 'Prepared producer must have the planned nonzero interruption')
    row.update(planned_termination=True, process_terminal=True, exit_code=child.returncode)
    after = prepared_record(profile, state, child.pid)
    require(after == prepared, 'Planned termination changed prepared/candidate/owner bytes')
    checkpoint = {'cfg': prepared['disk']['cfg'], 'settings': prepared['disk']['settings'],
                  'journal_directory': paths(profile)['journal'].as_posix(),
                  'prepared_path': prepared['path'], 'prepared_sha256': prepared['sha256'],
                  'candidate_path': prepared['candidate']['path'], 'candidate_sha256': prepared['candidate']['sha256'],
                  'owner_path': prepared['owner']['path'], 'owner_raw': prepared['owner']['raw'],
                  'owner_sha256': prepared['owner']['sha256'], 'chosen_prefs': submitted['chosen_prefs'],
                  'exact_chosen_prefs': submitted['exact_chosen_prefs']}
    value = {'schema': 'ui_startup_prepared_fixture_v1', 'mode': 'prepare_crash', 'pid': child.pid,
             'batch_nonce': batch, 'process_nonce': nonce, 'profile': str(profile), 'identity': submitted['identity'],
             'candidate_manifest_sha256': sha(state['run_base'] / 'candidate_manifest.json'),
             'sources_sha256': sha(HERE / 'sources.json'), 'actual_process_terminated': True, 'planned_termination': True,
             'checkpoint': checkpoint, 'prepared_record': prepared, 'frozen_business_copies': mapping,
             'producer_submitted_path': str(stage / 'producer_submitted.json'),
             'producer_submitted_sha256': sha(stage / 'producer_submitted.json'),
             'checks': submitted['checks'], 'passed': True, 'stage_completed': True,
             'startup_recovery_qualified': False, **{flag: False for flag in FALSE_FLAGS}}
    path = stage / 'prepared.json'; h.save(p.fs(path), value)
    return path, value


def validate_final_report(report, mode, child, profile, state, batch, nonce, previous, prepared):
    exact_identity(report, 'ui_startup_retry_three_process_v1', mode, child.pid, profile, state, batch, nonce)
    check_worker_checks(report)
    require(report.get('passed') is True and report.get('stage_completed') is True and report.get('failures') == []
            and report.get('exit_reason') == 'ui_startup_retry_verified'
            and report.get('source_private_ui_startup_retry_qualified') is False
            and report.get('initial_private_gate_used') is False
            and report.get('no_gameplay_state_injection') is True
            and integer(report.get('simulation_time_scale'), 1) and integer(report.get('physics_hz'), 60)
            and all(report.get(flag) is False for flag in FALSE_FLAGS), 'Native final report qualification or completion mismatch')
    checkpoint = report.get('checkpoint', {})
    require(all(type(checkpoint.get(key)) is dict and checkpoint[key] for key in
                ('disk', 'exact_disk', 'prefs', 'exact_prefs', 'journal', 'exact_journal')),
            'Actual typed readback checkpoint required')
    records = b1.journal_records(profile, state, prepared['checkpoint']['cfg'])
    require(checkpoint['disk'] == observer_disk(profile)
            and checkpoint['exact_prefs'] == prepared['checkpoint']['exact_chosen_prefs'],
            'Independent installed bytes and preferences must match the original real UI choice')
    journal = checkpoint['journal']
    require(integer(journal.get('generation'), 2) and journal.get('file_sha256') == records[1]['sha256']
            and journal.get('transaction') == prepared['prepared_record']['document']['transaction']
            and records[0]['sha256'] == prepared['checkpoint']['prepared_sha256']
            and checkpoint['disk']['cfg']['sha256'] == prepared['checkpoint']['candidate_sha256']
            and checkpoint['disk']['settings'] == prepared['checkpoint']['settings'], 'One original prepared transaction must become applied exactly once')
    for index, key in enumerate(('prepared', 'applied')):
        actual, expected = journal.get(key, {}), records[index]
        require(actual.get('ok') is True and integer(actual.get('revision'), index + 1)
                and actual.get('previous') == expected['previous_sha256']
                and actual.get('file_sha256') == expected['sha256'] and actual.get('payload_sha256') == expected['payload_sha256']
                and actual.get('document') == expected['document'], 'Native journal must bind exact host-read raw envelopes')
    if mode == 'readback':
        require(checkpoint == previous['checkpoint'], 'Third process must independently retain the exact original successful checkpoint')
    return records


def execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous, prepared, owned_children):
    row = {'mode': mode, 'profile': str(profile), 'process_nonce': nonce, 'complete': False,
           'process_terminal': False, 'planned_termination': False, 'gates': [], 'debug_stops': [],
           'faults': [], 'post_errors': [], 'debugger_locals_read': False, 'host_production_object_injection': False}
    child = listener = connection = peer = handle = None
    thread = None
    armed, planned_stop, gate_index = False, False, 0
    before = before_prepared = None
    log_path = stage / 'native.log'
    start = time.monotonic()
    try:
        require(os.name == 'nt' and not baseline.engines() and not native_helpers(), 'Owned Windows engine/helper lane must be idle')
        before = business(profile); row['before_business'] = before
        row['provider_reports_before'] = provider_reports(profile)
        command = [str(state['engine']), '--path', str(state['project']), '--rendering-method', 'gl_compatibility',
                   '--resolution', '1280x720', '--position', '30000,30000']
        if mode == 'prepare_crash':
            listener = socket.socket(); listener.bind(('127.0.0.1', 0)); listener.listen(1); listener.settimeout(30)
            command += ['--remote-debug', 'tcp://127.0.0.1:' + str(listener.getsockname()[1])]
        elif mode == 'startup_retry':
            require(prepared is not None and all(item.poll() is not None for item in owned_children),
                    'Only our confirmed-dead prepared producer may precede recovery')
            before_prepared = prepared_record(profile, state, prepared['pid'])
            require(before_prepared == prepared['prepared_record'], 'Original prepared scope changed before normal Startup')
            candidate = io.owned(prepared['checkpoint']['candidate_path'], profile)
            require(candidate == Path(before_prepared['candidate']['path']) and p.fs(candidate).is_file(),
                    'Only original candidate file, never its directory, may be held')
            handle = io.NativeSharingDenial(candidate, profile, 'candidate_install_delete_denial')
            row['faults'].append({'kind': 'original_candidate_no_delete', 'path': str(candidate),
                                  'sha256': sha(candidate), 'bytes': p.fs(candidate).stat().st_size,
                                  'open_existing': True, 'read_access_only': True, 'native_share_mode': 3,
                                  'armed_before_child_start': True, 'armed_ns': time.monotonic_ns(), 'released': False})
        command += ['--script', str(workers / 'bootstrap.gd')]
        row['command'] = command
        with p.fs(log_path).open('xb') as stream:
            child = subprocess.Popen(command, cwd=state['project'], env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            owned_children.append(child)  # Retain the actual native process handle, including the dead producer.
            row['pid'] = child.pid
            if listener is not None:
                connection, _ = listener.accept(); listener.close(); listener = None
                connection.settimeout(.1); peer = wire.DebugConnection(connection)
            deadline, notice, scan = time.monotonic() + state['timeout'], time.monotonic(), 0.0
            while child.poll() is None:
                require(time.monotonic() < deadline, 'Owned Startup stage deadline exceeded')
                if time.monotonic() >= scan:
                    require(not baseline.engines() - {child.pid}, 'Foreign engine appeared; never control it')
                    scan = time.monotonic() + 2
                if time.monotonic() - notice >= 25:
                    print('RUNNING', mode, 'pid', child.pid, 'gates', gate_index, 'stops', len(row['debug_stops']), flush=True)
                    notice = time.monotonic()
                if gate_index < len(PHASES[mode]) and (mode != 'prepare_crash' or thread is not None):
                    phase = PHASES[mode][gate_index]
                    request_path = stage / (phase + '.request.json')
                    request = gate(request_path, mode, phase, child, profile, state, batch, nonce)
                    if request is not None:
                        observed = {'request': request, 'request_path': str(request_path), 'request_sha256': sha(request_path),
                                    'monotonic_ns': time.monotonic_ns(), 'business_before_host_action': business(profile),
                                    'native_observer_disk': observer_disk(profile)}
                        row['gates'].append(observed)
                        detail = request['detail']
                        if mode == 'prepare_crash':
                            require(set(detail) == {'stage_parent', 'cfg_path', 'journal_directory', 'producer_ready_sha256'}
                                    and io.owned(detail['stage_parent'], profile) == paths(profile)['blocker']
                                    and io.owned(detail['cfg_path'], profile) == paths(profile)['cfg']
                                    and io.owned(detail['journal_directory'], profile) == paths(profile)['journal']
                                    and detail['producer_ready_sha256'] == sha(stage / 'producer_ready.json'), 'Exact original pre-submit gate required')
                            ready = read(stage / 'producer_ready.json')
                            check_producer_observation(ready, False, child, profile, state, batch, nonce)
                            require(business(profile) == before and ready['initial_disk'] == observer_disk(profile),
                                    'No business writes are allowed before the actual Settings Return Save')
                            peer.command('breakpoint', thread, [state['point']['source'], state['point']['line'], True])
                            armed = True
                        else:
                            require(set(detail) == {'candidate_path', 'candidate_sha256', 'journal_directory', 'transaction', 'expected_code'}
                                    and detail['expected_code'] == 'CFG_INSTALL_RENAME'
                                    and io.owned(detail['candidate_path'], profile) == Path(before_prepared['candidate']['path'])
                                    and detail['candidate_sha256'] == before_prepared['candidate']['sha256']
                                    and io.owned(detail['journal_directory'], profile) == paths(profile)['journal']
                                    and detail['transaction'] == before_prepared['document']['transaction'] and handle is not None,
                                    'Only original retained candidate can be released after two actual Startup refusals')
                            blocked_path = stage / 'startup_blocked.json'
                            blocked = read(blocked_path)
                            exact_identity(blocked, 'ui_startup_blocked_observation_v1', mode, child.pid, profile, state, batch, nonce)
                            check_worker_checks(blocked)
                            require(blocked.get('prepared_fixture_sha256') == env['UST_PREVIOUS_SHA']
                                    and blocked.get('stage_completed') is False, 'Blocked observation must retain original prepared fixture')
                            actual = prepared_record(profile, state, child.pid)
                            require(actual['sha256'] == before_prepared['sha256'] and actual['candidate'] == before_prepared['candidate']
                                    and actual['disk']['settings'] == before_prepared['disk']['settings'],
                                    'Dead-owner recovery must preserve original prepared/candidate/settings bytes')
                            first, second = blocked.get('first_failure'), blocked.get('blocked_retry')
                            require(type(first) is dict and first and first == second, 'Two real Startup failures must retain the same recovery object and scope')
                            observed.update(blocked_path=str(blocked_path), blocked_sha256=sha(blocked_path),
                                            actual_retained_prepared=actual, first_failure=first)
                            # Per-field native object binding is checked before closing, not inferred from a later success.
                            validate_blocked(first, actual, profile)
                            require(sha(handle.path) == before_prepared['candidate']['sha256'], 'Original held candidate changed')
                            handle.close(); handle = None
                            require(business(profile) == observed['business_before_host_action'], 'Closing only our handle may not mutate business bytes')
                            row['faults'][-1].update(released=True, released_ns=time.monotonic_ns(),
                                                    candidate_sha256_after_close=sha(Path(detail['candidate_path'])))
                        ack(stage / (phase + '.ack.json'), request, request_path)
                        observed['ack_sha256'] = sha(stage / (phase + '.ack.json'))
                        gate_index += 1
                if peer is None:
                    time.sleep(.04)
                    continue
                try:
                    message, packet = peer.receive()
                except socket.timeout:
                    continue
                except EOFError:
                    break
                name, received_thread, data = message
                if name == 'set_pid':
                    require(data == [child.pid], 'Debugger must identify the actual owned Popen')
                    thread = received_thread
                elif name == 'debug_enter':
                    require(armed and data == [True, 'Breakpoint', True, received_thread], 'Unexpected debugger/error stop')
                    peer.command('get_stack_dump', received_thread)
                elif name == 'stack_dump':
                    frames = wire.stack_frames(data)
                    stop = {'pid': child.pid, 'process_nonce': nonce, 'frames': frames,
                            'stack_packet_sha256': hashlib.sha256(packet).hexdigest(), 'monotonic_ns': time.monotonic_ns(),
                            'source_sha256': sha(state['project'] / CFG_SOURCE.removeprefix('res://'))}
                    row['debug_stops'].append(stop)
                    require(armed and gate_index == 1 and len(row['debug_stops']) == 1
                            and frames[0] == {key: state['point'][key] for key in ('source', 'line', 'function')}
                            and stop['source_sha256'] == state['point']['source_sha256'], 'Exact unique cfg_before_install native frame required')
                    ordered = [(frame['source'], frame['function']) for frame in frames[1:]]
                    cursor = 0
                    for expected in [(CFG_SOURCE, 'retry_write'), (CFG_SOURCE, 'commit_prepared'),
                                     ('res://scripts/campaign.gd', '_write_values'), ('res://scripts/campaign.gd', '_save_prefs_deferred')]:
                        require(expected in ordered[cursor:], 'Actual Settings→Campaign→prepared install call chain changed')
                        cursor = ordered.index(expected, cursor) + 1
                    submitted = read(stage / 'producer_submitted.json')
                    check_producer_observation(submitted, True, child, profile, state, batch, nonce)
                    ready = read(stage / 'producer_ready.json')
                    require(submitted['chosen_prefs'] == ready['chosen_prefs']
                            and submitted['exact_chosen_prefs'] == ready['exact_chosen_prefs']
                            and submitted['initial_disk'] == ready['initial_disk'], 'Deferred write must retain original real UI choice')
                    actual = prepared_record(profile, state, child.pid)
                    stop['actual_prepared'] = actual
                    require(actual['business']['continue'] == before['continue'], 'Producer may not write slot/lifecycle')
                    fixture_path, fixture = preserved_fixture(stage, actual, submitted, child, profile, state, batch, nonce, row)
                    row.update(report_path=str(fixture_path), report_sha256=sha(fixture_path),
                               actual_checks=len(submitted['checks']), producer_checks_only=True,
                               prepared_fixture=fixture, actual_prepared_breakpoints=1)
                    planned_stop = True
                    break
            child.wait(timeout=20)
        row.update(exit_code=child.returncode, process_terminal=True, seconds=round(time.monotonic() - start, 3))
        require(gate_index == len(PHASES[mode]) and handle is None, 'Actual fault handshake incomplete')
        require(planned_stop and child.returncode != 0 if mode == 'prepare_crash' else child.returncode == 0,
                'Planned producer interruption and normal reader exit are distinct required outcomes')
        for observed in row['gates']:
            request_path = Path(observed['request_path'])
            require(sha(request_path) == observed['request_sha256']
                    and sha(stage / (observed['request']['phase'] + '.ack.json')) == observed['ack_sha256'], 'Closed gate bytes changed')
        text = p.fs(log_path).read_text(encoding='utf-8', errors='replace')
        row['native_errors'] = [line for line in text.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line or 'Parse Error:' in line]
        require(not row['native_errors'], 'Unexpected native error is not an authorized interruption')
        if mode != 'prepare_crash':
            report_path = stage / 'report.json'; report = read(report_path)
            records = validate_final_report(report, mode, child, profile, state, batch, nonce, previous, prepared)
            observations, operations = report.get('observations', {}), report.get('actual_operations', [])
            initial_count = observations.get('initial_operation_count')
            require(type(initial_count) in (int, float) and 0 <= initial_count <= 8
                    and integer(initial_count, int(initial_count)) and type(operations) is list,
                    'Actual startup operation-signal baseline must be a bounded integer')
            if mode == 'startup_retry':
                require(observations.get('first_failure') == row['gates'][0]['first_failure']
                        and observations.get('blocked_retry') == row['gates'][0]['first_failure']
                        and len(operations) == int(initial_count) + 2
                        and operations[-2].get('result', {}).get('code') == 'CFG_INSTALL_RENAME',
                        'Final report must retain the exact two-refusal evidence observed before host handle release')
                success = observations.get('final_startup_result', {})
                require(success.get('ok') is True and success.get('startup_checked') is True
                        and integer(success.get('progress_recovered'), 0) and success.get('settlement_authorized') is False
                        and operations[-1].get('result') == success, 'Actual original Startup callback must succeed without settlement')
            else:
                require(len(operations) == int(initial_count), 'Third startup cannot emit extra recovery operations')
            after = business(profile)
            require(after['continue'] == before['continue'], 'Startup preference recovery may not write slot/lifecycle')
            require(after['candidate_parent']['kind'] == 'directory'
                    and after['candidate_parent']['tree']['files'] == {}
                    and after['candidate_parent']['tree']['directories'] == ['.', 'v1'], 'Only original successful candidate stage must be cleaned')
            if mode == 'readback':
                require(after == before, 'Third normal Startup must not repeat recovery or write business files')
            providers = provider_reports(profile)
            verify_dead_providers(providers, prepared['pid'])
            if mode == 'readback':
                require(providers == row['provider_reports_before'], 'Third startup must not issue additional liveness recovery queries')
            row['provider_reports_verified'] = providers
            row.update(report_path=str(report_path), report_sha256=sha(report_path), actual_checks=len(report['checks']),
                       journal_records=records, producer_checks_only=False)
        row.update(complete=True, actual_gate_count=gate_index)
    except BaseException as error:
        row.update(error=repr(error), traceback=traceback.format_exc(), complete=False)
    finally:
        def terminal():
            if child is None:
                row.update(process_terminal=True, process_not_started=True)
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
            ok, _ = attempt(row, 'close_owned_candidate_handle', handle.close)
            if ok: handle = None
        row['owned_handles_closed'] = handle is None
        if connection is not None: attempt(row, 'close_owned_debug_connection', connection.close)
        if listener is not None: attempt(row, 'close_owned_debug_listener', listener.close)
        ok, after = attempt(row, 'final_business_inventory', lambda: business(profile))
        if ok: row['after_business'] = after
        ok, helpers = attempt(row, 'native_helper_terminal_inventory', native_helpers)
        row['native_helper_lane_idle'] = bool(ok and not helpers)
        if ok: row['remaining_native_helpers'] = helpers
        if not row['native_helper_lane_idle']:
            attempt(row, 'native_helpers_idle_required', lambda: require(False, 'Native helper still present; no external PID termination'))
        row['raw_pins'] = {}
        names = ['native.log', 'report.json', 'prepared.json', 'producer_ready.json', 'producer_submitted.json', 'startup_blocked.json']
        names += [phase + suffix for phase in PHASES[mode] for suffix in ('.request.json', '.ack.json')]
        for name in names:
            path = stage / name
            def pin_raw(path=path):
                if p.fs(path).is_file(): row['raw_pins'][str(path)] = sha(path)
            attempt(row, 'pin raw ' + name, pin_raw)
        for item in row.get('private_business_copies', []):
            def pin_private(item=item):
                require(sha(item['frozen_path']) == item['sha256'], 'Frozen private producer bytes changed')
                row['raw_pins'][item['frozen_path']] = item['sha256']
            attempt(row, 'pin private frozen business metadata', pin_private)
        def preserve_provider_reports():
            rows = provider_reports(profile)
            row['provider_reports_final'] = rows
            for item in rows:
                target = stage / 'provider_reports' / item['nonce'] / Path(item['path']).name
                p.copy(Path(item['path']), target, item['sha256'])
                row['raw_pins'][str(target)] = item['sha256']
                item['frozen_path'] = str(target)
        attempt(row, 'preserve actual native helper IPC', preserve_provider_reports)
        if row['post_errors']: row['complete'] = False
        persist(stage / 'controller.json', row)
    return row


def validate_blocked(first, actual, profile):
    """Bind native retained-object observations to the actual current owner and rev1."""
    require(first.get('stage') == 'replacing' and first.get('locked') is True and first.get('lock_created') is True
            and first.get('frozen_config_absent') is True and first.get('pending_record_empty') is True
            and first.get('transaction') == actual['document']['transaction']
            and io.owned(first.get('directory', ''), profile) == paths(profile)['journal']
            and io.owned(first.get('owner_path', ''), profile) == Path(actual['owner']['path'])
            and first.get('owner_raw') == actual['owner']['raw'] and first.get('owner_sha256') == actual['owner']['sha256']
            and first.get('head_ok') is True and integer(first.get('head_revision'), 1)
            and first.get('head_sha256') == actual['sha256'] and first.get('candidate_sha256') == actual['candidate']['sha256']
            and io.owned(first.get('prepared_path', ''), profile) == Path(actual['path'])
            and io.owned(first.get('candidate_path', ''), profile) == Path(actual['candidate']['path'])
            and first.get('candidate_read_ok') is True and first.get('semantics_sha256') == actual['document']['semantics_sha256']
            and first.get('tree_paused') is False and first.get('startup_scanned') is False
            and integer(first.get('startup_index'), 0) and first.get('coordinator_absent') is True
            and first.get('lifecycle_absent') is True and first.get('campaign_writer_absent') is True
            and type(first.get('writer_instance_id')) is str and re.fullmatch(r'[1-9][0-9]*', first['writer_instance_id'])
            and first.get('inventory') == {'ok': True, 'items': {'record_0000000001.json': actual['sha256'],
                                          'writing/': 'directory', 'writing/owner.json': actual['owner']['sha256']}}
            and first.get('disk') == actual['disk'], 'Actual retained startup writer must bind original proposal and newly owned recovered lock')
    require(all(type(first.get(key)) is dict and first[key] for key in
                ('exact_active', 'exact_current_record', 'exact_recovery_scope', 'exact_flow_scope', 'exact_candidate_semantics')),
            'Typed original recovered record/scope/candidate semantics observations missing')


def execute(args):
    cases, named_pins = named_state()
    output = ROOT / '.godot/ui_startup_retry_20261027' / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {'schema': 'ui_startup_retry_runner_v1', 'complete': False, 'three_process_startup_retry_qualified': False,
               'steps': [], 'post_errors': [], 'named_pins': named_pins, 'base_run': str(args.base_run.resolve()),
               'depends_on_b1_runtime_pass': False, 'debugger_locals_read': False,
               'natural_terminal_retry_qualified': False, **{flag: False for flag in FALSE_FLAGS}}
    state, locked, owner, pins = None, False, str(output), dict(named_pins)
    batch = uuid.uuid4().hex; receipt['batch_nonce'] = batch
    owned_children = []
    try:
        started = time.monotonic()
        while not locked:
            if not p.fs(h.shared.LOCK).exists() and not baseline.engines() and not native_helpers():
                try:
                    with p.fs(h.shared.LOCK).open('x', encoding='utf-8') as stream: stream.write(owner)
                    locked = True
                    break
                except FileExistsError: pass
            require(time.monotonic() - started < args.wait_lane, 'Shared lane occupied; no engine started')
            time.sleep(1)
        require(not baseline.engines(), 'Foreign engine appeared before admission')
        state = full_state(args.base_run, named_pins); state['timeout'] = args.timeout; pins = state['pins']
        receipt.update(project=str(state['project']), source_identity=CONTENT, engine_sha256=state['engine_sha256'],
                       initial_identity_passed=True, cold_import_qualified=True, breakpoint=state['point'])
        for name, expected in list(pins.items()):
            source = Path(name)
            if source.suffix.lower() == '.exe': continue
            require(source.is_relative_to(ROOT), 'Non-binary source must be repository-owned')
            target = output / 'runner_inputs' / source.relative_to(ROOT)
            p.copy(source, target, expected); p.pin(target, pins, expected)
        workers = output / 'workers'; p.fs(workers).mkdir()
        bindings_value = {}
        for name in WORKERS:
            p.copy(HERE / name, workers / name, pins[str(HERE / name)])
            p.pin(workers / name, pins); bindings_value[name] = sha(workers / name)
        bindings = workers / 'bindings.json'; h.save(p.fs(bindings), bindings_value); p.pin(bindings, pins)
        profile = Path(ROOT.anchor) / 'CodexQA/ui_startup_retry' / batch[:12]
        h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
        base_env = h.common.private_environment(profile); receipt['profile'] = str(profile)
        previous_path = previous = prepared = None
        seen = set()
        for index, mode in enumerate(MODES):
            p.verify_pins(pins)
            stage = output / ('%02d_' % index + mode); p.fs(stage).mkdir()
            nonce = uuid.uuid4().hex
            env = environment(base_env, profile, state, workers, bindings, stage, output, mode, batch, nonce, previous_path)
            row = execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous, prepared, owned_children)
            receipt['steps'].append(row)
            require(row.get('complete') is True and type(row.get('pid')) is int and row['pid'] not in seen,
                    'Actual independent Startup stage failed')
            seen.add(row['pid'])
            for name, expected in row['raw_pins'].items(): p.pin(name, pins, expected)
            p.pin(stage / 'controller.json', pins)
            previous_path = Path(row['report_path']); previous = read(previous_path)
            if mode == 'prepare_crash': prepared = previous
            p.verify_pins(pins)
            print('PASS', index, mode, 'pid', row['pid'], 'planned_nonzero', row['planned_termination'], 'checks', row['actual_checks'], flush=True)
        require(len(seen) == 3 and len(receipt['steps']) == 3 and len(owned_children) == 3,
                'Exactly three actual independent Popen processes required')
        receipt['three_process_startup_retry_qualified'] = True
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
        receipt['all_owned_children_terminal'] = all(row.get('process_terminal') is True for row in receipt['steps']) and all(child.poll() is not None for child in owned_children)
        receipt['all_owned_fault_handles_closed'] = all(row.get('owned_handles_closed') is True for row in receipt['steps'])
        receipt['held_native_process_handles'] = [{'pid': child.pid, 'exit_code': child.returncode,
                                                   'terminal': child.poll() is not None} for child in owned_children]
        process_closes = []
        for child in owned_children:
            def close_owned_process(child=child):
                require(child.poll() is not None, 'Do not close an unconfirmed live owned process handle')
                # This is the CPython Windows Popen-owned Handle, held since our
                # CreateProcess. Never OpenProcess/CloseHandle on an external PID.
                child._handle.Close()
                require(child._handle.closed, 'Owned native Popen handle did not close')
            ok, _ = attempt(receipt, 'close terminal owned Popen handle ' + str(child.pid), close_owned_process)
            process_closes.append(ok)
        receipt['all_owned_process_handles_closed'] = all(process_closes)
        receipt['all_owned_handles_closed'] = receipt['all_owned_fault_handles_closed'] and receipt['all_owned_process_handles_closed']
        def unlock():
            receipt['engine_lane_idle'] = not baseline.engines()
            receipt['remaining_native_helpers'] = native_helpers()
            receipt['native_helper_lane_idle'] = not receipt['remaining_native_helpers']
            receipt['lock_owner_verified'] = bool(locked and p.fs(h.shared.LOCK).is_file()
                                                  and p.fs(h.shared.LOCK).read_text(encoding='utf-8') == owner)
            if receipt['engine_lane_idle'] and receipt['native_helper_lane_idle'] and receipt['lock_owner_verified'] and receipt['all_owned_children_terminal'] and receipt['all_owned_handles_closed']:
                p.fs(h.shared.LOCK).unlink(); receipt['lock_released'] = not p.fs(h.shared.LOCK).exists()
        attempt(receipt, 'owned_lock_release', unlock)
        receipt['complete'] = bool(receipt['three_process_startup_retry_qualified'] and receipt['final_identity_passed']
                                   and receipt.get('lock_released') and not receipt['post_errors'] and 'error' not in receipt)
        if not receipt['complete']: receipt['three_process_startup_retry_qualified'] = False
        receipt['actual_process_count'] = sum(type(row.get('pid')) is int for row in receipt['steps'])
        receipt['actual_checks'] = sum(row.get('actual_checks', 0) for row in receipt['steps'])
        receipt['producer_checks'] = sum(row.get('actual_checks', 0) for row in receipt['steps'] if row.get('producer_checks_only'))
        receipt['normal_reader_checks'] = sum(row.get('actual_checks', 0) for row in receipt['steps'] if not row.get('producer_checks_only'))
        receipt['pinned_files'] = pins
        receipt['private_business_copies_excluded_from_git'] = [item for row in receipt['steps'] for item in row.get('private_business_copies', [])]
        persist(output / 'receipt.json', receipt)
    print(json.dumps({'output': str(output), 'complete': receipt['complete'],
                      'actual_process_count': receipt['actual_process_count'], 'error': receipt.get('error')}, ensure_ascii=False), flush=True)
    if not receipt['complete']: raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-run', type=Path, default=ROOT / BASE_REL)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--full-preflight', action='store_true', help='Expensive explicit complete-source admission without engine')
    parser.add_argument('--timeout', type=int, default=360, help='Per process, excluding full-source pre/post validation')
    parser.add_argument('--wait-lane', type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 60 or args.wait_lane < 0: parser.error('Invalid bounded deadline')
    if args.run:
        execute(args)
        return
    cases, pins = named_state()
    state = full_state(args.base_run, pins) if args.full_preflight else None
    print(json.dumps({'schema': 'ui_startup_retry_named_preflight_v1', 'named_sources_verified': True,
                      'named_pins': len(pins), 'stages': list(MODES), 'source_identity': CONTENT,
                      'full_source_verified': state is not None, 'cold_import_qualified': state is not None,
                      'engine_started': False, 'profile_created': False, 'native_executed': False,
                      'depends_on_b1_runtime_pass': False, 'three_process_startup_retry_qualified': False,
                      **{flag: False for flag in FALSE_FLAGS}}, ensure_ascii=False))


if __name__ == '__main__':
    main()
