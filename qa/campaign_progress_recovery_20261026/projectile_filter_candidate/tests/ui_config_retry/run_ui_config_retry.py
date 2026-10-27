"""Two actual settings UI processes; default is named-source read-only.

--run requires the exact b22 full freeze and its own cold import under the shared
engine lane. A host-owned regular file blocks only the otherwise absent candidate
parent. No production method, configuration payload, or retained proposal is injected.
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
MODES = ('save_retry', 'readback')
USERDIR = Path('appdata/Godot/app_userdata/水浒英雄传：八幕战役')
ZERO = '0' * 64
FALSE_FLAGS = ('public_continue_qualified', 'native_sdk_qualified', 'native_release_tested',
               'desktop_os_input', 'human_acceptance', 'full_campaign_qualified',
               'full_61_qualified', 'published')
GATE_KEYS = {'schema', 'mode', 'phase', 'pid', 'batch_nonce', 'process_nonce', 'profile',
             'content_version', 'engine_sha256', 'detail'}
PHASES = {'save_retry': ('arm_stage_parent', 'release_stage_parent'), 'readback': ()}
ENVELOPE_FIELDS = {'magic', 'version', 'app', 'owner', 'revision', 'previous_sha256',
                   'payload_bytes', 'payload_sha256', 'payload'}
DOCUMENT_FIELDS = {'schema', 'generation', 'state', 'transaction', 'original_sha256',
                   'candidate_sha256', 'semantics_sha256', 'original_owner', 'target_owner',
                   'content_version', 'engine_sha256', 'operation', 'run_token', 'intent_sha256'}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prep = load('ucr_preparation', HERE.parents[1] / 'integration_3365/prepare_projectile.py')
p, h = prep.p, prep.h
io = load('ucr_filesystem', ROOT / 'qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_io.py')
baseline = load('ucr_process_inventory', ROOT / 'tools/run_workstation_baseline.py')


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
        if 'two_process_config_retry_qualified' in row:
            row['two_process_config_retry_qualified'] = False
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
    return [Path(module.__file__) for module in (prep, p, h, h.common, h.shared, h.identity, io, baseline)]


def valid_instance_id(value):
    """Godot RefCounted ObjectID is a nonzero signed int64 when exposed to GDScript."""
    return (type(value) is str and re.fullmatch(r'-?[1-9][0-9]{0,18}', value) is not None
            and -(1 << 63) <= int(value) < (1 << 63))


def named_state():
    sources = read(HERE / 'sources.json')
    require(sources.get('schema') == 'ui_config_retry_sources_v1', 'Explicit settings retry source schema required')
    required = {str((HERE / name).relative_to(ROOT).as_posix()) for name in
                ('README.md', 'cases.json', 'run_ui_config_retry.py', *WORKERS)}
    rows = sources.get('files', [])
    require(type(rows) is list and len(rows) == 6 and {row['path'] for row in rows} == required,
            'Exactly six current settings retry source inputs required')
    pins = {}
    for row in [*rows, *sources.get('dependencies', [])]:
        rel = Path(row['path'])
        require(not rel.is_absolute() and '..' not in rel.parts, 'Source path must stay within repository')
        path = ROOT / rel
        require(path.suffix.lower() not in ('.exe', '.dll', '.pck'), 'Named admission must not hash binary assets')
        p.pin(path, pins, row['sha256'])
        require(p.fs(path).stat().st_size == row['bytes'], 'Named source byte size changed: ' + str(path))
    require({str(path) for path in module_paths()}.issubset(set(pins)), 'Host helper missing from named dependencies')
    p.pin(HERE / 'sources.json', pins)
    cases = read(HERE / 'cases.json')
    require(cases.get('schema') == 'ui_config_retry_cases_v1' and cases.get('source_identity') == CONTENT
            and Path(cases.get('base_run', '')) == BASE_REL and cases.get('required_script_count') == 26
            and cases.get('required_native_count') == 1 and cases.get('requires_own_cold_import') is True
            and cases.get('native_process_count') == 2 and cases.get('profile_count') == 1
            and cases.get('worker_files') == list(WORKERS), 'Fixed-source two-process contract required')
    require([case.get('mode') for case in cases.get('stages', [])] == list(MODES)
            and [case.get('index') for case in cases['stages']] == [0, 1]
            and [case.get('expected_journal_generation') for case in cases['stages']] == [2, 2]
            and all(cases.get('qualification', {}).get(flag) is False for flag in FALSE_FLAGS),
            'Stage order, actual fresh journal generations, or scope changed')
    return cases, pins


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
    return state


def paths(profile):
    user = io.owned(profile / USERDIR, profile)
    return {'user': user, 'cfg': user / 'campaign.cfg', 'settings': user / 'settings.cfg',
            'blocker': user / 'campaign_cfg_candidates',
            'journal_root': user / 'campaign_cfg_transactions/v1',
            'journal': user / 'campaign_cfg_transactions/v1/5088120/1'}


def file_row(path, profile):
    path = io.owned(path, profile)
    require(not p.fs(path).exists() or p.fs(path).is_file(), 'Expected ordinary file or absence: ' + str(path))
    present = p.fs(path).is_file()
    return {'path': path.as_posix(), 'exists': present, 'bytes': p.fs(path).stat().st_size if present else 0,
            'sha256': sha(path) if present else ZERO}


def node_inventory(path, profile):
    path = io.owned(path, profile)
    if p.fs(path).is_file():
        return {'kind': 'file', 'file': file_row(path, profile)}
    return {'kind': 'directory' if p.fs(path).is_dir() else 'absent', 'tree': io.snapshot(path)}


def business(profile):
    found = paths(profile)
    return {'cfg': file_row(found['cfg'], profile), 'settings': file_row(found['settings'], profile),
            'journal': io.snapshot(found['journal']),
            'candidate_parent': node_inventory(found['blocker'], profile),
            'continue': io.snapshot(found['user'] / 'continue/v1')}


def observer_tree(path, profile):
    """Exact native observer shape, independently derived from host file SHA inventory."""
    path = io.owned(path, profile)
    if p.fs(path).is_file():
        return {'kind': 'file', 'file': file_row(path, profile)}
    value = io.snapshot(path)
    return {'kind': 'directory' if value['exists'] else 'absent',
            'files': {name: item['sha256'] for name, item in value['files'].items()},
            'directories': [name for name in value['directories'] if name != '.']}


def observer_disk(profile):
    found = paths(profile)
    return {'cfg': file_row(found['cfg'], profile), 'settings': file_row(found['settings'], profile),
            'journal_inventory': observer_tree(found['journal_root'], profile),
            'candidate_inventory': observer_tree(found['blocker'], profile)}


def journal_records(profile, state, original_cfg=None):
    """Independent raw envelope/hash binding; native worker performs production validation."""
    found = paths(profile)
    inventory = io.snapshot(found['journal'])
    require(inventory['exists'] and inventory['directories'] == ['.']
            and sorted(inventory['files']) == ['record_0000000001.json', 'record_0000000002.json'],
            'One prepared/applied pair and no pending/owner/extra journal allowed')
    result = []
    for generation, phase in ((1, 'prepared'), (2, 'applied')):
        path = found['journal'] / ('record_%010d.json' % generation)
        require(p.fs(path).stat().st_size <= 65536, 'Journal exceeds actual production record limit')
        raw = p.fs(path).read_bytes()
        value = json.loads(raw)
        require(type(value) is dict and set(value) == ENVELOPE_FIELDS
                and all(type(item) is str for item in value.values())
                and value['magic'] == 'LH_CAMPAIGN_CFG_TRANSACTION' and value['version'] == '1'
                and value['app'] == '5088120' and value['owner'] == '1'
                and value['revision'] == str(generation), 'Actual CFG journal envelope mismatch')
        payload = value['payload'].encode('utf-8')
        require(value['payload_bytes'] == str(len(payload))
                and value['payload_sha256'] == hashlib.sha256(payload).hexdigest(), 'Actual journal payload binding failed')
        document = json.loads(payload)
        require(type(document) is dict and set(document) == DOCUMENT_FIELDS
                and all(type(v) is str for k, v in document.items() if k != 'generation')
                and document['schema'] == 'campaign_cfg_transaction_v1'
                and integer(document['generation'], generation) and document['state'] == phase
                and re.fullmatch(r'[0-9a-f]{32}', document['transaction'])
                and document['content_version'] == CONTENT and document['engine_sha256'] == state['engine_sha256']
                and document['operation'] == 'prefs' and document['run_token'] == '' and document['intent_sha256'] == ''
                and document['target_owner'] == '' and document['original_owner'] == '', 'Exact uncredited prefs journal scope required')
        require(all(re.fullmatch(r'[0-9a-f]{64}', document[key]) for key in
                    ('original_sha256', 'candidate_sha256', 'semantics_sha256')), 'Journal digest field malformed')
        require(value['previous_sha256'] == (ZERO if generation == 1 else result[0]['sha256']),
                'Actual prepared/applied journal chain changed')
        result.append({'path': str(path), 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
                       'previous_sha256': value['previous_sha256'], 'payload_sha256': value['payload_sha256'],
                       'document': document})
    require({key: value for key, value in result[0]['document'].items() if key not in ('generation', 'state')}
            == {key: value for key, value in result[1]['document'].items() if key not in ('generation', 'state')},
            'Applied journal must retain the original prepared proposal exactly')
    if original_cfg is not None:
        require(result[0]['document']['original_sha256'] == original_cfg['sha256'], 'Original CFG SHA changed across retry')
    require(file_row(found['cfg'], profile)['sha256'] == result[1]['document']['candidate_sha256'],
            'Final CFG must be the exact recorded candidate bytes')
    return result


class StageParentBlocker:
    """CREATE_NEW regular file at the absent parent; retain read-share only, no deletion."""
    def __init__(self, profile, stage, batch, nonce, pid):
        self.profile, self.stage = profile, stage
        self.path = io.owned(paths(profile)['blocker'], profile)
        self.handle = None
        self.created = False
        self.moved = False
        self.evidence_path = stage / 'owned_stage_parent_blocker.json'
        require(not p.fs(self.path).exists() and p.fs(self.path.parent).is_dir(),
                'Candidate parent must be wholly absent within existing private user directory')
        require(not p.fs(self.evidence_path).exists(), 'Owned evidence destination already exists')
        self.raw = (json.dumps({'schema': 'ui_config_retry_owned_blocker_v1', 'batch_nonce': batch,
                                'process_nonce': nonce, 'pid': pid}, sort_keys=True, separators=(',', ':')) + '\n').encode('utf-8')
        self.expected_sha = hashlib.sha256(self.raw).hexdigest()
        self.api = ct.WinDLL('kernel32', use_last_error=True)
        self.api.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, ct.c_void_p, wt.DWORD, wt.DWORD, wt.HANDLE]
        self.api.CreateFileW.restype = wt.HANDLE
        self.api.WriteFile.argtypes = [wt.HANDLE, ct.c_void_p, wt.DWORD, ct.POINTER(wt.DWORD), ct.c_void_p]
        self.api.WriteFile.restype = wt.BOOL
        self.api.FlushFileBuffers.argtypes = [wt.HANDLE]
        self.api.FlushFileBuffers.restype = wt.BOOL
        self.api.CloseHandle.argtypes = [wt.HANDLE]
        self.api.CloseHandle.restype = wt.BOOL
        self.write_error = None

    def arm(self):
        require(self.handle is None and not self.created and not p.fs(self.path).exists(),
                'Owned blocker arm may occur once at an absent path')
        handle = self.api.CreateFileW(str(p.fs(self.path)), 0xC0000000, 1, None, 1, 0x80, None)
        if handle == ct.c_void_p(-1).value:
            raise ct.WinError(ct.get_last_error())
        self.handle, self.created = handle, True
        try:
            buffer, count = ct.create_string_buffer(self.raw), wt.DWORD()
            require(bool(self.api.WriteFile(self.handle, buffer, len(self.raw), ct.byref(count), None))
                    and count.value == len(self.raw), 'Owned blocker write incomplete')
            require(bool(self.api.FlushFileBuffers(self.handle)), 'Owned blocker flush failed')
            self.verify()
        except BaseException as error:
            self.write_error = repr(error)
            # The caller owns this instance before arm(). Preserve partial file
            # and leave the independent finally to close even on a failed write.
            raise

    def verify(self):
        require(io.owned(self.path, self.profile) == self.path and p.fs(self.path).is_file()
                and p.fs(self.path).stat().st_size == len(self.raw)
                and sha(self.path) == self.expected_sha and p.fs(self.path).read_bytes() == self.raw,
                'Only original host-owned nonce/SHA/size/raw blocker may be removed')
        return {'path': str(self.path), 'bytes': len(self.raw), 'sha256': self.expected_sha,
                'regular_file': True, 'create_new': True, 'share_read_only': True,
                'evidence_path': str(self.evidence_path)}

    def close_handle(self):
        if self.handle is not None:
            require(bool(self.api.CloseHandle(self.handle)), 'Owned blocker handle close failed')
            self.handle = None

    def release(self):
        if self.moved or not self.created:
            return
        self.verify()
        self.close_handle()
        self.verify()
        h.identity.no_links(p.fs(self.evidence_path))
        require(not p.fs(self.evidence_path).exists(), 'Never overwrite blocker evidence')
        # Windows rename refuses an existing destination. Same volume, no copy/delete.
        os.rename(p.fs(self.path), p.fs(self.evidence_path))
        self.moved = True
        require(not p.fs(self.path).exists() and sha(self.evidence_path) == self.expected_sha
                and p.fs(self.evidence_path).read_bytes() == self.raw, 'Owned blocker move did not preserve exact evidence')


def environment(base_env, profile, state, workers, bindings, stage, output, mode, batch, nonce, previous):
    env = dict(base_env)
    for key in list(env):
        if key.startswith(('UCR_', 'USR_', 'P19_', 'DN_', 'DF_', 'GVT_', 'GT_', 'GLS_', 'CR_', 'CC_', 'RS_', 'LSH_CONTINUE_FLOW_')):
            env.pop(key)
    for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
        require(env.get(key) == str(profile / key.lower()), 'Shared private environment path changed')
    for key in ('LEVEL', 'SKIRMISH', 'SMOKE_TEST', 'SCREENSHOT_DIR', 'SKIRMISH_AI'):
        env[key] = ''
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='', LSH_CONTINUE_FLOW_PROFILE='', LSH_LANGUAGE='zh_CN',
               UCR_MODE=mode, UCR_OUTPUT=str(stage), UCR_RUN=str(output), UCR_PROFILE=str(profile),
               UCR_PROJECT=str(state['project']), UCR_CONTENT=CONTENT, UCR_ENGINE=state['engine_sha256'],
               UCR_MANIFEST=sha(state['run_base'] / 'candidate_manifest.json'), UCR_SOURCES_SHA256=sha(HERE / 'sources.json'),
               UCR_BATCH_NONCE=batch, UCR_PROCESS_NONCE=nonce, UCR_WORKERS=str(workers), UCR_BINDINGS=str(bindings))
    if previous is not None:
        env.update(UCR_PREVIOUS=str(previous), UCR_PREVIOUS_SHA=sha(previous))
    return env


def gate(path, mode, phase, child, profile, state, batch, nonce):
    value = closed_json(path)
    if value is None:
        return None
    require(type(value) is dict and set(value) == GATE_KEYS and value['schema'] == 'ui_config_retry_gate_v1'
            and value['mode'] == mode and value['phase'] == phase and integer(value['pid'], child.pid)
            and value['batch_nonce'] == batch and value['process_nonce'] == nonce and Path(value['profile']) == profile
            and value['content_version'] == CONTENT and value['engine_sha256'] == state['engine_sha256']
            and type(value['detail']) is dict, 'Actual gate identity/phase/field set changed')
    found, detail = paths(profile), value['detail']
    keys = {'stage_parent', 'cfg_path', 'journal_directory', 'expected_code'}
    if phase == 'arm_stage_parent':
        keys.update(('initial_cfg', 'initial_settings'))
    require(set(detail) == keys and detail['expected_code'] == 'CFG_STAGE_PARENT'
            and io.owned(detail['stage_parent'], profile) == found['blocker']
            and io.owned(detail['cfg_path'], profile) == found['cfg']
            and io.owned(detail['journal_directory'], profile) == found['journal'],
            'Only the exact candidate parent/config/journal within this private profile is admitted')
    return value


def ack(path, request, request_path):
    value = {key: item for key, item in request.items() if key != 'detail'}
    value.update(schema='ui_config_retry_ack_v1', request_sha256=sha(request_path), ok=True)
    require(len(value) == 11, 'Exact gate ACK shape changed')
    io.publish_ack(p.fs(path), value)


def validate_report(report, mode, child, profile, state, batch, nonce, records, previous):
    require(report.get('schema') == 'ui_config_retry_two_process_v1' and report.get('mode') == mode
            and report.get('passed') is True and report.get('stage_completed') is True and report.get('failures') == []
            and report.get('checks') and all(row.get('passed') is True for row in report['checks']), 'Actual worker checks/stage failed')
    require(integer(report.get('pid'), child.pid) and report.get('batch_nonce') == batch
            and report.get('process_nonce') == nonce and Path(report.get('profile', '')) == profile,
            'Actual report process/profile/nonces mismatch')
    identity = report.get('identity', {})
    require(identity.get('content_version') == CONTENT and identity.get('source_mode') is True
            and identity.get('engine_binary_sha256', identity.get('engine_sha256')) == state['engine_sha256'],
            'Actual source/engine identity mismatch')
    require(report.get('candidate_manifest_sha256') == sha(state['run_base'] / 'candidate_manifest.json')
            and report.get('sources_sha256') == sha(HERE / 'sources.json'), 'Actual report source binding differs')
    require(all(report.get(flag) is False for flag in FALSE_FLAGS)
            and report.get('source_private_ui_config_retry_qualified') is False
            and report.get('no_gameplay_state_injection') is True and integer(report.get('simulation_time_scale'), 1)
            and integer(report.get('physics_hz'), 60), 'Worker cannot self-award the entire chain or wider qualification')
    require(report.get('exit_reason') == 'ui_config_retry_verified' and report.get('initial_private_gate_used') is False,
            'Settings verification must use a test quit, not production SaveAndExit')
    checkpoint = report.get('checkpoint', {})
    require(all(type(checkpoint.get(key)) is dict and checkpoint[key] for key in
                ('disk', 'exact_disk', 'prefs', 'exact_prefs', 'journal', 'exact_journal')), 'Complete actual typed checkpoint required')
    actual = business(profile)
    disk, journal = checkpoint['disk'], checkpoint['journal']
    require(disk == observer_disk(profile),
            'Worker checkpoint must bind actual host-read configuration bytes/inventories')
    require(integer(journal.get('generation'), 2) and journal.get('file_sha256') == records[1]['sha256']
            and journal.get('transaction') == records[1]['document']['transaction'], 'Actual journal head/transaction mismatch')
    for index, key in enumerate(('prepared', 'applied')):
        verified = journal.get(key, {})
        record = records[index]
        require(verified.get('ok') is True and integer(verified.get('revision'), index + 1)
                and verified.get('previous') == record['previous_sha256']
                and verified.get('file_sha256') == record['sha256']
                and verified.get('payload_sha256') == record['payload_sha256']
                and verified.get('document') == record['document'], 'Native verified journal must match host-read raw envelope')
    if previous is not None:
        require(checkpoint == previous['checkpoint'], 'Restart must independently retain the same typed configuration checkpoint')


def execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous):
    row = {'mode': mode, 'profile': str(profile), 'process_nonce': nonce, 'complete': False,
           'process_terminal': False, 'gates': [], 'faults': [], 'post_errors': [],
           'debugger_used': False, 'host_production_object_injection': False}
    child = blocker = None
    phase_index, before, arm, release_disk = 0, None, None, None
    log_path = stage / 'native.log'
    start = time.monotonic()
    try:
        require(os.name == 'nt' and not baseline.engines(), 'Owned Windows engine lane must be idle')
        before = business(profile)
        row['before_business'] = before
        command = [str(state['engine']), '--path', str(state['project']), '--rendering-method', 'gl_compatibility',
                   '--resolution', '1280x720', '--position', '30000,30000', '--script', str(workers / 'bootstrap.gd')]
        row['command'] = command
        with p.fs(log_path).open('xb') as stream:
            child = subprocess.Popen(command, cwd=state['project'], env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            row['pid'] = child.pid
            deadline, notice, process_scan = time.monotonic() + state['timeout'], time.monotonic(), 0.0
            while child.poll() is None:
                require(time.monotonic() < deadline, 'Owned settings stage deadline exceeded')
                if time.monotonic() >= process_scan:
                    require(not baseline.engines() - {child.pid}, 'Foreign engine appeared; never control it')
                    process_scan = time.monotonic() + 2
                if time.monotonic() - notice >= 25:
                    print('RUNNING', mode, 'pid', child.pid, 'gates', phase_index, flush=True)
                    notice = time.monotonic()
                if phase_index < len(PHASES[mode]):
                    phase = PHASES[mode][phase_index]
                    request_path = stage / (phase + '.request.json')
                    request = gate(request_path, mode, phase, child, profile, state, batch, nonce)
                    if request is not None:
                        observation = {'request': request, 'request_path': str(request_path),
                                       'request_sha256': sha(request_path), 'monotonic_ns': time.monotonic_ns()}
                        row['gates'].append(observation)
                        current = business(profile)
                        observation['business_before_host_action'] = current
                        observation['native_observer_disk'] = observer_disk(profile)
                        if phase == 'arm_stage_parent':
                            require(current['cfg'] == request['detail']['initial_cfg']
                                    and current['settings'] == request['detail']['initial_settings']
                                    and current['candidate_parent']['kind'] == 'absent'
                                    and not current['journal']['files'] and not current['journal']['exists']
                                    and current['continue'] == before['continue'], 'Fresh closed CFG/journal state required before submit')
                            arm = current
                            blocker = StageParentBlocker(profile, stage, batch, nonce, child.pid)
                            blocker.arm()
                            row['faults'].append({'kind': 'owned_regular_file_candidate_parent', **blocker.verify(),
                                                  'armed_ns': time.monotonic_ns(), 'released': False})
                        else:
                            require(blocker is not None and arm is not None and blocker.handle is not None,
                                    'Only the same still-owned parent blocker may be released')
                            blocker.verify()
                            require(current['cfg'] == arm['cfg'] and current['settings']['exists']
                                    and current['settings'] != arm['settings'] and current['continue'] == arm['continue']
                                    and sorted(current['journal']['files']) == ['writing/owner.json']
                                    and current['journal']['directories'] == ['.', 'writing'],
                                    'Both failed retries must preserve CFG and leave no prepared/applied record; settings save is separate')
                            owner_path = paths(profile)['journal'] / 'writing/owner.json'
                            owner_raw = p.fs(owner_path).read_text(encoding='utf-8')
                            owner = json.loads(owner_raw)
                            require(set(owner) == {'version', 'owner', 'pid', 'token'} and owner['version'] == '1'
                                    and owner['owner'] == '1' and owner['pid'] == str(child.pid)
                                    and re.fullmatch(r'[0-9a-f]{32}', owner['token']), 'Actual journal lock must belong to this child')
                            release_disk = current
                            observation.update(owner_raw=owner_raw, owner_sha256=sha(owner_path))
                            blocker.release()
                            row['faults'][-1].update(released=True, released_ns=time.monotonic_ns(),
                                                      moved_original_blocker_sha256=sha(blocker.evidence_path))
                            require(not p.fs(paths(profile)['blocker']).exists(), 'Original blocker path must be absent before UI retry')
                        ack(stage / (phase + '.ack.json'), request, request_path)
                        observation['ack_sha256'] = sha(stage / (phase + '.ack.json'))
                        phase_index += 1
                time.sleep(.04)
            child.wait(timeout=20)
        row.update(exit_code=child.returncode, process_terminal=True, seconds=round(time.monotonic() - start, 3))
        require(child.returncode == 0 and phase_index == len(PHASES[mode])
                and (blocker is None or blocker.moved and blocker.handle is None), 'Actual terminal process or fault handshake incomplete')
        for observed in row['gates']:
            request_path = Path(observed['request_path'])
            ack_path = stage / (observed['request']['phase'] + '.ack.json')
            require(sha(request_path) == observed['request_sha256'] and sha(ack_path) == observed['ack_sha256'],
                    'Closed gate request/ACK changed after publication')
        text = p.fs(log_path).read_text(encoding='utf-8', errors='replace')
        errors = [line for line in text.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line or 'Parse Error:' in line]
        row['native_errors'] = errors
        require(not errors, 'Unexpected native parse/runtime error is not qualification')
        report_path = stage / 'report.json'
        report = read(report_path)
        records = journal_records(profile, state, arm['cfg'] if arm is not None else None)
        validate_report(report, mode, child, profile, state, batch, nonce, records, previous)
        after = business(profile)
        require(after['continue'] == before['continue'], 'Settings operation may not write slot or lifecycle')
        require(after['candidate_parent']['kind'] == 'directory'
                and after['candidate_parent']['tree']['files'] == {}
                and after['candidate_parent']['tree']['directories'] == ['.', 'v1'], 'Completed transaction must clean only its stage')
        if mode == 'save_retry':
            observations = report.get('observations', {})
            first, blocked = observations.get('first_failure'), observations.get('blocked_retry')
            require(type(first) is dict and first and first == blocked and release_disk is not None,
                    'Two actual failures must retain exactly the same writer/frozen proposal observations')
            release_gate = row['gates'][1]
            require(first.get('stage') == 'staging' and first.get('head_ok') is True
                    and integer(first.get('head_revision'), 0) and first.get('head_sha256') == ZERO
                    and first.get('original_sha256') == arm['cfg']['sha256']
                    and first.get('transaction') == records[1]['document']['transaction']
                    and all(first.get(key) is True for key in ('locked', 'lock_created', 'pending_record_empty', 'tree_paused'))
                    and all(valid_instance_id(first.get(key))
                            for key in ('writer_instance_id', 'frozen_cfg_instance_id'))
                    and first['writer_instance_id'] != first['frozen_cfg_instance_id']
                    and io.owned(first.get('directory', ''), profile) == paths(profile)['journal']
                    and io.owned(first.get('owner_path', ''), profile) == paths(profile)['journal'] / 'writing/owner.json'
                    and first.get('owner_raw') == release_gate['owner_raw']
                    and first.get('owner_sha256') == release_gate['owner_sha256']
                    and first.get('inventory') == {'ok': True, 'items': {'writing/': 'directory',
                                                  'writing/owner.json': release_gate['owner_sha256']}}
                    and first.get('disk') == release_gate['native_observer_disk']
                    and observations.get('initial_disk') == row['gates'][0]['native_observer_disk'],
                    'Native retained writer/owner/CAS/proposal must bind this actual host gate and final transaction')
            require(all(type(first.get(key)) is dict and first[key] for key in
                        ('exact_active', 'exact_request_scope', 'exact_frozen_semantics', 'exact_failed_prefs', 'exact_failed_scope')),
                    'Typed retained original proposal/scope/prefs observations missing')
            result = observations.get('final_write_result', {})
            require(result.get('ok') is True and result.get('code') == 'CAMPAIGN_CFG_READBACK_VERIFIED'
                    and result.get('persisted') is True and result.get('file_sha256') == after['cfg']['sha256']
                    and result.get('transaction') == records[1]['document']['transaction'], 'Real successful UI retry result required')
            require(after['settings'] == release_disk['settings'] and after['cfg'] != arm['cfg'],
                    'Only successful retry changes Campaign CFG; prior Settings write must remain exact')
            operations = report.get('actual_operations', [])
            require(len(operations) == 2 and operations[0].get('result', {}).get('code') == 'CFG_STAGE_PARENT'
                    and operations[1].get('result', {}).get('code') == 'CAMPAIGN_CFG_READBACK_VERIFIED',
                    'Only initial failure and final success emit actual operation completion')
        else:
            require(after == before and report.get('actual_operations') == [],
                    'Independent readback/restart/quit may not add a config or journal write')
        row.update(complete=True, report_path=str(report_path), report_sha256=sha(report_path),
                   actual_checks=len(report['checks']), journal_records=records, actual_gate_count=phase_index,
                   after_business=after)
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
        if blocker is not None:
            # No removal until our child is terminal on error. Independent close
            # still runs if raw/SHA verification refuses to move an altered file.
            def preserve_blocker():
                require(row.get('process_terminal') is True, 'Do not move blocker while owned child terminal is unconfirmed')
                blocker.release()
            attempt(row, 'preserve_owned_blocker', preserve_blocker)
            attempt(row, 'close_owned_blocker_handle', blocker.close_handle)
        row['owned_handles_closed'] = blocker is None or blocker.handle is None
        row['owned_blocker_released'] = blocker is None or not blocker.created or blocker.moved
        ok, after = attempt(row, 'final_business_inventory', lambda: business(profile))
        if ok:
            row['after_business'] = after
        row['raw_pins'] = {}
        for path in [log_path, stage / 'report.json', stage / 'owned_stage_parent_blocker.json',
                     *[stage / (phase + suffix) for phase in PHASES[mode] for suffix in ('.request.json', '.ack.json')]]:
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
    output = ROOT / '.godot/ui_config_retry_20261027' / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {'schema': 'ui_config_retry_runner_v1', 'complete': False, 'two_process_config_retry_qualified': False,
               'steps': [], 'post_errors': [], 'named_pins': named_pins, 'base_run': str(args.base_run.resolve()),
               'debugger_used': False, 'startup_prepared_recovery_qualified': False, **{flag: False for flag in FALSE_FLAGS}}
    state, locked, owner, pins = None, False, str(output), dict(named_pins)
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
                       initial_identity_passed=True, cold_import_qualified=True)
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
        profile = Path(ROOT.anchor) / 'CodexQA/ui_config_retry' / batch[:12]
        h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
        base_env = h.common.private_environment(profile)
        receipt['profile'] = str(profile)
        previous_path = previous_report = None
        seen = set()
        for index, mode in enumerate(MODES):
            p.verify_pins(pins)
            stage = output / ('%02d_' % index + mode); p.fs(stage).mkdir()
            nonce = uuid.uuid4().hex
            env = environment(base_env, profile, state, workers, bindings, stage, output, mode, batch, nonce, previous_path)
            row = execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous_report)
            receipt['steps'].append(row)
            require(row.get('complete') is True and type(row.get('pid')) is int and row['pid'] not in seen,
                    'Actual independent settings process failed')
            seen.add(row['pid'])
            for name, expected in row['raw_pins'].items():
                p.pin(name, pins, expected)
            p.pin(stage / 'controller.json', pins)
            previous_path = Path(row['report_path']); previous_report = read(previous_path)
            p.verify_pins(pins)
            print('PASS', index, mode, 'pid', row['pid'], 'checks', row['actual_checks'], flush=True)
        require(len(seen) == 2 and len(receipt['steps']) == 2, 'Exactly two independent processes required')
        receipt['two_process_config_retry_qualified'] = True
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
        receipt['complete'] = bool(receipt['two_process_config_retry_qualified'] and receipt['final_identity_passed']
                                   and receipt.get('lock_released') and not receipt['post_errors'] and 'error' not in receipt)
        if not receipt['complete']:
            receipt['two_process_config_retry_qualified'] = False
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
    parser.add_argument('--timeout', type=int, default=360, help='Bounded seconds per process, excluding full-source admission')
    parser.add_argument('--wait-lane', type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 60 or args.wait_lane < 0:
        parser.error('Invalid bounded deadline')
    if args.run:
        execute(args)
        return
    cases, pins = named_state()
    state = full_state(args.base_run, pins) if args.full_preflight else None
    print(json.dumps({'schema': 'ui_config_retry_named_preflight_v1', 'named_sources_verified': True,
                      'named_pins': len(pins), 'stages': list(MODES), 'source_identity': CONTENT,
                      'full_source_verified': state is not None, 'cold_import_qualified': state is not None,
                      'engine_started': False, 'profile_created': False, 'native_executed': False,
                      'two_process_config_retry_qualified': False, 'startup_prepared_recovery_qualified': False,
                      **{flag: False for flag in FALSE_FLAGS}}, ensure_ascii=False))


if __name__ == '__main__':
    main()
