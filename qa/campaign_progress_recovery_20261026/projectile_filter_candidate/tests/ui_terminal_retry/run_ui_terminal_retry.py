"""C: four real Gao Flow processes with one retained terminal transaction retry.

Default checks named sources only. --run alone acquires the shared lane, performs
full fixed-b22/own-cold-import admission and creates a new private profile. The
two saves and final refusal inherit exact sealed Gao workers; C uses a new thin
driver and a host-owned regular file, never a synthetic victory or edited save.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
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
WORKERS = ('bootstrap.gd', 'driver.gd', 'source_driver.gd', 'base.gd', 'terminal.gd', 'policy.gd')
MODES = ('save_after_wave1', 'resume_core_save', 'resume_finish', 'reject_terminal')
PHASES = ('arm_terminal_stage_parent', 'release_terminal_stage_parent')
CONTEXT = {'mode': 'campaign', 'level_id': 'level5', 'waves': 0}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Only source-level helpers/provenance are reused. Neither old runner executes,
# and no prior native result is accepted as one of these four actual processes.
b1 = load('utr_closed_filesystem', HERE.parent / 'ui_config_retry/run_ui_config_retry.py')
route = load('utr_closed_gao_sources', HERE.parents[1] / 'run_gaoqiu_terminal.py')
p, h, io, prep, baseline = b1.p, b1.h, b1.io, b1.prep, b1.baseline
require, sha, read, integer, attempt = b1.require, b1.sha, b1.read, b1.integer, b1.attempt
closed_json, paths, business = b1.closed_json, b1.paths, b1.business
file_row, observer_tree, observer_disk = b1.file_row, b1.observer_tree, b1.observer_disk
ZERO = b1.ZERO
FALSE_FLAGS = (*b1.FALSE_FLAGS, 'original_19_faults_qualified', 'release_retry_qualified')
LIFE_FIELDS = {'schema', 'generation', 'token', 'context', 'scope', 'state', 'victory',
               'progress_state', 'intent', 'progress_receipt'}
INTENT_FIELDS = {'schema', 'token', 'context', 'profile_id', 'owner', 'content_version',
                 'engine_sha256', 'victory', 'result', 'credit'}


def persist(path, row):
    try:
        h.save(p.fs(path), row)
        return True
    except BaseException as error:
        row.setdefault('post_errors', []).append({'phase': 'save ' + str(path), 'error': repr(error),
                                                  'traceback': traceback.format_exc()})
        row['complete'] = False
        if 'four_process_terminal_retry_qualified' in row:
            row['four_process_terminal_retry_qualified'] = False
        fallback = path.with_name(path.stem + '_write_failed_' + uuid.uuid4().hex + path.suffix)
        row['fallback_evidence_path'] = str(fallback)
        try:
            h.save(p.fs(fallback), row)
        except BaseException as second:
            row['post_errors'].append({'phase': 'fallback_save', 'error': repr(second), 'traceback': traceback.format_exc()})
            print(json.dumps({'evidence_write_failed': row}, ensure_ascii=False), file=sys.stderr, flush=True)
        return False


def module_paths():
    return [Path(b1.__file__), *b1.module_paths(), Path(route.__file__)]


def native_helpers():
    command = "@(Get-CimInstance Win32_Process -Filter \"Name='ProcessLivenessProbe.exe'\" | Select-Object ProcessId,ParentProcessId,ExecutablePath) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell.exe', '-NoProfile', '-Command', command], text=True,
                                  creationflags=subprocess.CREATE_NO_WINDOW).strip()
    value = json.loads(raw) if raw else []
    return value if type(value) is list else [value]


def valid_instance_id(value):
    """Godot RefCounted ObjectID is a nonzero signed int64 when exposed to GDScript."""
    return (type(value) is str and re.fullmatch(r'-?[1-9][0-9]{0,18}', value) is not None
            and -(1 << 63) <= int(value) < (1 << 63))


def named_state():
    sources = read(HERE / 'sources.json')
    require(sources.get('schema') == 'ui_terminal_retry_sources_v1', 'Explicit terminal retry source schema required')
    required = {(HERE / name).relative_to(ROOT).as_posix() for name in
                ('README.md', 'cases.json', 'run_ui_terminal_retry.py', *WORKERS)}
    rows = sources.get('files', [])
    require(type(rows) is list and len(rows) == 9 and {row['path'] for row in rows} == required,
            'Exactly nine current terminal retry input sources required')
    pins = {}
    for row in [*rows, *sources.get('dependencies', [])]:
        rel = Path(row['path'])
        require(not rel.is_absolute() and '..' not in rel.parts, 'Named source must remain repository-owned')
        path = prep.inside(ROOT, row['path'])
        require(path.suffix.lower() not in ('.exe', '.dll', '.pck'), 'Named default must not hash binary assets')
        p.pin(path, pins, row['sha256'])
        require(p.fs(path).stat().st_size == row['bytes'], 'Named source bytes changed: ' + str(path))
    require({str(path) for path in module_paths()}.issubset(pins), 'Imported helper missing from source dependencies')
    ancestry = route.source_pins()
    require(set(ancestry).issubset(pins) and all(pins[name] == digest for name, digest in ancestry.items()),
            'The complete actual sealed Gao host/worker/replay/derived/helper ancestry must be pinned')
    for target, original in (('source_driver.gd', 'driver.gd'), ('base.gd', 'base.gd'),
                             ('terminal.gd', 'terminal.gd'), ('policy.gd', 'policy.gd')):
        require(pins[str(HERE / target)] == pins[str(route.WORKER_ROOT / original)],
                'Inherited Gao worker must retain exact original bytes: ' + target)
    p.pin(HERE / 'sources.json', pins)
    cases = read(HERE / 'cases.json')
    require(cases.get('schema') == 'ui_terminal_retry_cases_v1' and cases.get('source_identity') == CONTENT
            and Path(cases.get('base_run', '')) == BASE_REL and cases.get('required_script_count') == 26
            and cases.get('required_native_count') == 1 and cases.get('requires_own_cold_import') is True
            and cases.get('native_process_count') == 4 and cases.get('profile_count') == 1
            and cases.get('worker_files') == list(WORKERS), 'Exact b22 four-process contract required')
    stages = cases.get('stages', [])
    require([row.get('mode') for row in stages] == list(MODES)
            and [row.get('index') for row in stages] == list(range(4))
            and [row.get('expected_slot_generation') for row in stages] == [1, 2, 2, 2]
            and [row.get('expected_lifecycle_generation') for row in stages] == [1, 1, 3, 3]
            and stages[2].get('gate_phases') == list(PHASES)
            and stages[3].get('checkpoint_source') == 'validated_C_retained_slot_with_independent_D_disk_readback'
            and all(cases.get('qualification', {}).get(flag) is False for flag in FALSE_FLAGS),
            'Four-stage order, generation bounds, real C gates, or qualification changed')
    return cases, pins


class TerminalParentBlocker(b1.StageParentBlocker):
    def __init__(self, profile, stage, batch, nonce, pid):
        super().__init__(profile, stage, batch, nonce, pid)
        self.raw = (json.dumps({'schema': 'ui_terminal_retry_owned_blocker_v1', 'batch_nonce': batch,
                                'process_nonce': nonce, 'pid': pid}, sort_keys=True, separators=(',', ':')) + '\n').encode('utf-8')
        self.expected_sha = hashlib.sha256(self.raw).hexdigest()


def environment(base_env, profile, state, workers, binding, stage, output, mode, batch, nonce, previous):
    env = dict(base_env)
    for key in list(env):
        if key.startswith(('UTR_', 'UST_', 'UCR_', 'USR_', 'P19_', 'DN_', 'DF_', 'GVT_', 'GT_',
                           'GLS_', 'CR_', 'CC_', 'RS_', 'LSH_CONTINUE_FLOW_')):
            env.pop(key)
    for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
        require(env.get(key) == str(profile / key.lower()), 'Same-profile private environment changed')
    for key in ('LEVEL', 'SKIRMISH', 'SMOKE_TEST', 'SCREENSHOT_DIR', 'SKIRMISH_AI'):
        env[key] = ''
    manifest_sha, source_sha = sha(state['run_base'] / 'candidate_manifest.json'), sha(HERE / 'sources.json')
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_LANGUAGE='zh_CN',
               LSH_CONTINUE_FLOW_QA='1', LSH_CONTINUE_FLOW_PROFILE=str(profile),
               GVT_PROFILE=str(profile), GVT_PROJECT=str(state['project']), GVT_WORKERS=str(workers),
               GVT_BINDINGS=str(binding), GVT_BINDINGS_SHA256=sha(binding), GVT_NONCE=batch,
               GVT_CANDIDATE_SHA256=manifest_sha, GVT_SOURCES_SHA256=source_sha, GVT_MODE=mode,
               GVT_REPORT=str(stage / 'report.json'), GVT_PROCESS_NONCE=nonce,
               UTR_GATE_DIR=str(stage), UTR_SOURCES_SHA256=source_sha, UTR_MANIFEST=manifest_sha)
    if previous is not None:
        env.update(GVT_PREVIOUS=str(previous), GVT_PREVIOUS_SHA256=sha(previous))
    return env


def scope_paths(profile, checkpoint):
    binding = checkpoint.get('binding', {})
    require(type(binding) is dict and set(binding) == {'kind', 'token', 'receipt_sha256'}
            and binding['kind'] == 'uncredited' and re.fullmatch(r'[0-9a-f]{32}', binding['token'])
            and re.fullmatch(r'[0-9a-f]{64}', binding['receipt_sha256']), 'Original uncredited slot binding required')
    user = paths(profile)['user']
    slot = io.owned(user / 'continue/v1/5088120/1', profile)
    life = io.owned(user / 'continue/v1/local_runs' / binding['token'] / '5088120/1', profile)
    require(io.owned(checkpoint.get('directory', ''), profile) == slot
            and io.owned(checkpoint.get('lifecycle', {}).get('directory', ''), profile) == life,
            'Actual original slot/lifecycle paths must match this private token')
    return slot, life, binding


def raw_record(path, magic, generation, profile):
    path = io.owned(path, profile)
    require(p.fs(path).is_file() and 0 < p.fs(path).stat().st_size <= 65536, 'Bounded original lifecycle/CFG record required')
    raw = p.fs(path).read_bytes()
    value = json.loads(raw)
    require(type(value) is dict and set(value) == b1.ENVELOPE_FIELDS and all(type(item) is str for item in value.values())
            and value['magic'] == magic and value['version'] == '1' and value['app'] == '5088120'
            and value['owner'] == '1' and value['revision'] == str(generation), 'Exact native envelope identity mismatch')
    payload = value['payload'].encode('utf-8')
    require(value['payload_bytes'] == str(len(payload)) and value['payload_sha256'] == hashlib.sha256(payload).hexdigest(),
            'Original native record payload hash/bytes mismatch')
    document = json.loads(payload)
    require(type(document) is dict and integer(document.get('generation'), generation), 'Actual native record generation mismatch')
    digest = hashlib.sha256(raw).hexdigest()
    require(digest == sha(path), 'Record changed while decoding original bytes')
    return {'path': path.as_posix(), 'sha256': digest, 'bytes': len(raw), 'document': document,
            'previous_sha256': value['previous_sha256'], 'payload_sha256': value['payload_sha256']}


def lifecycle_records(profile, state, checkpoint, generation):
    slot, life, binding = scope_paths(profile, checkpoint)
    inventory = io.snapshot(life)
    require(inventory['exists'] and inventory['directories'] == ['.']
            and sorted(inventory['files']) == ['record_%010d.json' % n for n in range(1, generation + 1)],
            'Only the expected closed lifecycle records may exist')
    rows = []
    for n in range(1, generation + 1):
        row = raw_record(life / ('record_%010d.json' % n), 'LH_LOCAL_CONTINUE_LIFECYCLE', n, profile)
        doc = row['document']
        require(set(doc) == LIFE_FIELDS and doc['schema'] == 'local_campaign_continue_lifecycle_v3'
                and doc['token'] == binding['token'] and doc['context'] == CONTEXT
                and doc['scope'] == {'owner': '', 'content_version': CONTENT, 'engine_sha256': state['engine_sha256']}
                and row['previous_sha256'] == (ZERO if n == 1 else rows[-1]['sha256']), 'Exact original LCv3 scope/chain required')
        require(doc['state'] == ('active' if n == 1 else 'terminal') and doc['victory'] is (n != 1)
                and doc['progress_state'] == ('none' if n == 1 else 'pending' if n == 2 else 'applied'),
                'Actual active/pending/applied lifecycle progression required')
        if n == 1:
            require(doc['intent'] == {} and doc['progress_receipt'] == {} and row['sha256'] == binding['receipt_sha256'],
                    'Both saves must retain the original active binding')
        else:
            intent = doc['intent']
            require(type(intent) is dict and set(intent) == INTENT_FIELDS
                    and intent['schema'] == 'campaign_progress_intent_v2' and intent['token'] == binding['token']
                    and intent['context'] == CONTEXT and intent['profile_id'] == 'campaign_level5_v1'
                    and intent['owner'] == '' and intent['content_version'] == CONTENT
                    and intent['engine_sha256'] == state['engine_sha256'] and intent['victory'] is True
                    and intent['credit'] == {'kind': 'uncredited'}, 'Exact real offline Level5 Intentv2 required')
            require(set(intent['result']) == {'core_cleared', 'story_complete', 'story_done', 'story_total', 'done_ids', 'contract_version'}
                    and intent['result']['core_cleared'] is True and integer(intent['result']['story_total'], 4)
                    and integer(intent['result']['contract_version'], 3), 'Actual current core result, no fabricated full-story requirement')
            if n == 2:
                require(doc['progress_receipt'] == {}, 'Failed CFG stage must retain pending LC2 with no ACK')
            else:
                require(doc['intent'] == rows[1]['document']['intent'], 'ACK must use the original terminal frozen intent')
        rows.append(row)
    return rows


def continuation_after_lifecycle(initial, profile, rows):
    """Only append the exact actual lifecycle records; do not bless unrelated files."""
    root = paths(profile)['user'] / 'continue/v1'
    expected = {**initial, 'files': dict(initial['files']), 'directories': list(initial['directories'])}
    for row in rows:
        path = io.owned(row['path'], profile)
        require(path.is_relative_to(root), 'Actual lifecycle record escaped original continue scope')
        name = path.relative_to(root).as_posix()
        entry = {'sha256': row['sha256'], 'bytes': row['bytes']}
        require(name not in expected['files'] or expected['files'][name] == entry, 'Original lifecycle record was replaced')
        expected['files'][name] = entry
    return expected


def journal_records(profile, state, binding, intent_sha):
    directory = paths(profile)['journal']
    inventory = io.snapshot(directory)
    require(inventory['exists'] and inventory['directories'] == ['.']
            and sorted(inventory['files']) == ['record_0000000001.json', 'record_0000000002.json'],
            'Exactly one closed real CFG prepared/applied pair required')
    rows = []
    for n, phase in ((1, 'prepared'), (2, 'applied')):
        row = raw_record(directory / ('record_%010d.json' % n), 'LH_CAMPAIGN_CFG_TRANSACTION', n, profile)
        doc = row['document']
        require(set(doc) == b1.DOCUMENT_FIELDS and all(type(value) is str for key, value in doc.items() if key != 'generation')
                and doc['schema'] == 'campaign_cfg_transaction_v1' and doc['state'] == phase
                and re.fullmatch(r'[0-9a-f]{32}', doc['transaction']) and doc['content_version'] == CONTENT
                and doc['engine_sha256'] == state['engine_sha256'] and doc['operation'] == 'progress'
                and doc['run_token'] == binding['token'] and doc['intent_sha256'] == intent_sha
                and doc['target_owner'] == '' and doc['original_owner'] == '' and doc['original_sha256'] == ZERO,
                'Actual CFG transaction must bind this original offline terminal intent')
        require(all(re.fullmatch(r'[0-9a-f]{64}', doc[key]) for key in ('candidate_sha256', 'semantics_sha256'))
                and row['previous_sha256'] == (ZERO if n == 1 else rows[-1]['sha256']), 'Actual CFG record hashes/chain mismatch')
        if n == 2:
            require({k: v for k, v in doc.items() if k not in ('generation', 'state')}
                    == {k: v for k, v in rows[0]['document'].items() if k not in ('generation', 'state')},
                    'Prepared/applied must close the exact same original transaction')
        rows.append(row)
    require(sha(paths(profile)['cfg']) == rows[1]['document']['candidate_sha256'], 'Installed CFG must match actual committed candidate SHA')
    return rows


def native_lifecycle_matches(value, rows, directory, token):
    expected_inventory = {Path(row['path']).name: row['sha256'] for row in rows}
    head = rows[-1]
    return (type(value) is dict and value.get('directory') == directory.as_posix() and value.get('token') == token
            and value.get('file_sha256') == head['sha256'] and integer(value.get('generation'), len(rows))
            and value.get('document') == head['document'] and value.get('inventory') == expected_inventory)


def validate_pending(value, observed, arm, previous, profile, state):
    """Native same-object assertions are tied to actual raw files while C waits at its gate."""
    require(type(value) is dict and value.get('schema') == 'ui_terminal_retry_observation_v1', 'Native C observation schema required')
    before = value.get('before', {})
    first, blocked = value.get('first_failure'), value.get('blocked_retry')
    require(type(first) is dict and first and first == blocked, 'Both actual failures must retain exactly identical native observations')
    slot, life, binding = scope_paths(profile, previous['checkpoint'])
    require(before.get('paused') is True and before.get('cfg') == arm['cfg']
            and before.get('slot_sha256') == previous['checkpoint']['file_sha256']
            and native_lifecycle_matches(before.get('lifecycle'), observed['lifecycle_records'][:1], life, binding['token'])
            and before.get('campaign_memory') == {'records': {}, 'unlocked': 1, 'owner': ''},
            'Arm must preserve the real paused active lifecycle and original campaign memory')
    for key in ('coordinator_instance_id', 'writer_instance_id', 'frozen_cfg_instance_id', 'lifecycle_instance_id'):
        require(valid_instance_id(first.get(key)), 'Native retained instance ID missing: ' + key)
    require(len({first[key] for key in ('coordinator_instance_id', 'writer_instance_id', 'frozen_cfg_instance_id', 'lifecycle_instance_id')}) == 4,
            'Coordinator/CFG/frozen ConfigFile/lifecycle must be four actual distinct retained objects')
    require(first.get('coordinator_stage') == 'progress' and first.get('live') is True
            and first.get('presentation_consumed') is False and first.get('stage') == 'staging'
            and all(first.get(key) is True for key in ('locked', 'lock_created', 'head_ok', 'pending_record_empty', 'tree_paused'))
            and integer(first.get('head_revision'), 0) and first.get('head_sha256') == ZERO
            and first.get('original_sha256') == ZERO and integer(first.get('flow_phase'), 4)
            and integer(first.get('battle_phase'), 3) and integer(first.get('barrier_state'), 0)
            and first.get('metrics_closed') is False and first.get('end_hud_visible') is False,
            'Actual terminal END must remain paused before presentation, not borrowed SaveBarrier HELD')
    require(io.owned(first.get('directory', ''), profile) == paths(profile)['journal']
            and io.owned(first.get('owner_path', ''), profile) == paths(profile)['journal'] / 'writing/owner.json'
            and first.get('owner_raw') == observed['owner_raw']
            and first.get('owner_file') == file_row(paths(profile)['journal'] / 'writing/owner.json', profile)
            and first['owner_file']['sha256'] == observed['owner_sha256']
            and first.get('inventory') == {'ok': True, 'items': {'writing/': 'directory', 'writing/owner.json': observed['owner_sha256']}}
            and first.get('cfg') == arm['cfg'] and first.get('blocker') == file_row(paths(profile)['blocker'], profile)
            and first.get('transaction') == observed['request']['detail']['transaction']
            and integer(first.get('slot_revision'), 2) and first.get('slot_sha256') == previous['checkpoint']['file_sha256']
            and native_lifecycle_matches(first.get('lifecycle'), observed['lifecycle_records'], life, binding['token'])
            and first.get('campaign_memory') == before['campaign_memory'],
            'Native retained owner/CAS/token/slot/LC2 must match actual host raw files before removing fault')
    for key in ('exact_active', 'exact_intent', 'exact_gate_scope', 'exact_expected', 'exact_frozen_semantics',
                'exact_lifecycle', 'exact_slot_binding', 'exact_state', 'exact_result', 'exact_metrics', 'exact_report', 'exact_rewards'):
        require(type(first.get(key)) is dict and first[key], 'Production typed pending evidence missing: ' + key)
    require(all(type(first.get(key)) is str and re.fullmatch(r'[0-9a-f]{64}', first[key])
                for key in ('intent_sha256', 'frozen_text_sha256', 'frozen_semantics_sha256'))
            and type(first.get('clock_next')) is str and re.fullmatch(r'[0-9]+', first['clock_next']),
            'Frozen intent/semantics/text and actual frozen clock evidence missing')
    operations = value.get('operations', [])
    require(len(operations) == 2 and all(op.get('result', {}).get('ok') is False
            and op['result'].get('code') == 'CFG_STAGE_PARENT' and op['result'].get('battle_held') is True
            and op['result'].get('terminal_pending') is True and integer(op.get('phase'), 4) for op in operations),
            'Exactly first failure and one blocked real RetryTerminal signal required before removal')
    require(len(value.get('gates', [])) == 1 and value['gates'][0].get('phase') == PHASES[0],
            'Blocked snapshot must precede its release gate and follow one actual arm ACK')
    require(value.get('initial_private_gate_used') is True and all(value.get(key) is False for key in
                ('desktop_os_input', 'public_continue_qualified', 'native_sdk_qualified', 'full_campaign_qualified', 'full_61_qualified', 'published')),
            'Native observation may not grant OS-input/public/SDK/full-game qualification')


def validate_blocked_file(path, row, child, profile, state, batch, nonce, previous):
    value = read(path)
    require(type(value) is dict and set(value) == {'schema', 'mode', 'pid', 'batch_nonce', 'process_nonce', 'profile',
                'identity', 'candidate_manifest_sha256', 'sources_sha256', 'observation'}
            and value['schema'] == 'ui_terminal_retry_blocked_v1' and value['mode'] == 'resume_finish'
            and integer(value['pid'], child.pid) and value['batch_nonce'] == batch and value['process_nonce'] == nonce
            and value['profile'] == str(profile) and value['candidate_manifest_sha256'] == sha(state['run_base'] / 'candidate_manifest.json')
            and value['sources_sha256'] == sha(HERE / 'sources.json')
            and value['identity'].get('content_version') == CONTENT and value['identity'].get('source_mode') is True
            and value['identity'].get('engine_sha256') == state['engine_sha256'], 'Closed native blocked report identity must bind actual C process')
    validate_pending(value['observation'], row['gates'][1], row['gates'][0]['business_before_host_action'], previous, profile, state)
    return value


def gate(path, phase, child, profile, state, batch, nonce, checkpoint):
    value = closed_json(path)
    if value is None:
        return None
    require(type(value) is dict and set(value) == b1.GATE_KEYS and value['schema'] == 'ui_terminal_retry_gate_v1'
            and value['mode'] == 'resume_finish' and value['phase'] == phase and integer(value['pid'], child.pid)
            and value['batch_nonce'] == batch and value['process_nonce'] == nonce and value['profile'] == str(profile)
            and value['content_version'] == CONTENT and value['engine_sha256'] == state['engine_sha256']
            and type(value['detail']) is dict, 'Actual gate PID/nonces/profile/source/field set changed')
    detail, found = value['detail'], paths(profile)
    slot, life, binding = scope_paths(profile, checkpoint)
    keys = {'stage_parent', 'cfg_path', 'journal_directory', 'lifecycle_directory', 'token'}
    keys.update(('slot_sha256',) if phase == PHASES[0] else ('transaction', 'expected_code'))
    require(set(detail) == keys and detail['token'] == binding['token']
            and io.owned(detail['stage_parent'], profile) == found['blocker']
            and io.owned(detail['cfg_path'], profile) == found['cfg']
            and io.owned(detail['journal_directory'], profile) == found['journal']
            and io.owned(detail['lifecycle_directory'], profile) == life, 'Gate must bind actual private original token paths')
    if phase == PHASES[0]:
        require(detail['slot_sha256'] == checkpoint['file_sha256']
                and sha(slot / 'record_0000000002.json') == detail['slot_sha256'], 'Arm must follow original exact paused gen2 restore')
    else:
        require(detail['expected_code'] == 'CFG_STAGE_PARENT' and re.fullmatch(r'[0-9a-f]{32}', detail['transaction']),
                'Only actual repeated parent-stage failure may release the owned blocker')
    return value


def ack(path, request, request_path):
    value = {key: item for key, item in request.items() if key != 'detail'}
    value.update(schema='ui_terminal_retry_ack_v1', request_sha256=sha(request_path), ok=True)
    require(len(value) == 11, 'Exact ACK field set required')
    io.publish_ack(p.fs(path), value)


def validate_route_report(report, mode, child, profile, state, batch, nonce):
    require(report.get('schema') == 'campaign_gaoqiu_terminal_v1' and report.get('passed') is True
            and report.get('stage_completed') is True and report.get('failures') == [] and report.get('checks')
            and all(row.get('passed') is True for row in report['checks']), 'Actual inherited route checks failed: ' + mode)
    require(report.get('mode') == mode and report.get('batch_nonce') == batch and report.get('process_nonce') == nonce
            and report.get('profile') == str(profile) and integer(report.get('pid'), child.pid)
            and report.get('slot_root') == 'user://continue/v1'
            and report.get('candidate_manifest_sha256') == sha(state['run_base'] / 'candidate_manifest.json')
            and report.get('sources_sha256') == sha(HERE / 'sources.json')
            and report.get('identity', {}).get('content_version') == CONTENT
            and report['identity'].get('engine_sha256') == state['engine_sha256']
            and report['identity'].get('source_mode') is True
            and integer(report.get('simulation_time_scale'), 1) and integer(report.get('physics_hz'), 60)
            and report.get('natural_core_victory_required') is True and report.get('full_story_required') is False
            and report.get('no_gameplay_state_injection') is True, 'Exact source/engine/normal clock route binding required')
    require(all(report.get(flag) is False for flag in ('defeat_chain_qualified', 'native_sdk_qualified',
                'public_continue_qualified', 'human_acceptance', 'native_release_tested')), 'Source-private route cannot grant wider qualification')
    if mode in MODES[:2]:
        require(report.get('save_exit_observed') is True and report.get('exit_reason') == 'continue_saved',
                'Production SaveAndExit must own each actual exit')
    if mode == 'resume_finish':
        button = report.get('observations', {}).get('restored_end_button', {})
        result = report.get('terminal_checkpoint', {}).get('full_result', {})
        require(button.get('same_level_mission_node') is True and button.get('original_callback_count') == 1
                and integer(button.get('process_id'), child.pid) and result.get('core_cleared') is True
                and integer(result.get('contract_version'), 3) and integer(result.get('story_total'), 4),
                'Actual restored Mission-owned terminal button and full current result required')
    if mode == 'reject_terminal':
        refusal = report.get('observations', {}).get('terminal_refusal', {})
        require(refusal.get('ok') is False and refusal.get('code') == 'LOCAL_RUN_TERMINAL',
                'Actual independent menu must reject original terminal token')


def validate_checkpoint(report, mode, profile, state, previous):
    if mode == MODES[3]:
        # Refusal creates no Battle or new save checkpoint. Bind its independent
        # native disk readback to the original C report's validated retained slot.
        require(report.get('checkpoint') == {} and previous is not None
                and type(previous.get('checkpoint')) is dict and previous['checkpoint'],
                'Menu refusal must retain an empty current checkpoint and a validated C predecessor')
        checkpoint = previous['checkpoint']
    else:
        checkpoint = report['checkpoint']
    generation = 1 if mode == MODES[0] else 2
    slot, life, binding = scope_paths(profile, checkpoint)
    require(integer(checkpoint.get('generation'), generation)
            and sha(slot / ('record_%010d.json' % generation)) == checkpoint.get('file_sha256'),
            'Actual closed original slot bytes/generation must match native typed checkpoint')
    inventory = io.snapshot(slot)
    require(inventory['exists'] and inventory['directories'] == ['.']
            and sorted(inventory['files']) == ['record_%010d.json' % n for n in range(1, generation + 1)],
            'Closed slot may contain only its actual one or two original records, no pending writer')
    if previous:
        prior_checkpoint = previous['checkpoint']
        require(sha(slot / ('record_%010d.json' % prior_checkpoint['generation'])) == prior_checkpoint['file_sha256'],
                'Later process must preserve predecessor slot record raw bytes')
    for key in ('exact_checkpoint', 'exact_opening', 'exact_terminal'):
        require(type(report.get(key)) is dict and report[key], 'Production Codec typed report missing: ' + key)
    if previous:
        require(binding == previous['checkpoint']['binding'], 'Same original token/active binding must persist across all four processes')
    rows = lifecycle_records(profile, state, checkpoint, 1 if mode in MODES[:2] else 3)
    if mode in MODES[:2]:
        require(not file_row(paths(profile)['cfg'], profile)['exists']
                and not io.snapshot(paths(profile)['journal'])['exists'], 'Active saves must precede any durable CFG settlement')
        return rows, []
    terminal = report['terminal_checkpoint']
    require(terminal.get('slot_binding') == binding, 'Original terminal and retained slot must use exactly the same binding')
    require(terminal['lifecycle']['file_sha256'] == rows[2]['sha256']
            and terminal['lifecycle']['document'] == rows[2]['document']
            and terminal['slot_sha256'] == checkpoint['file_sha256'], 'Native terminal must bind actual LC3 and unchanged saved slot')
    ack_value = rows[2]['document']['progress_receipt']
    proof = terminal['handoff_validation']['ack']['steam_handoff']
    intent_sha = terminal['handoff_validation']['intent_sha256']
    require(re.fullmatch(r'[0-9a-f]{64}', intent_sha) and set(proof) == {'schema', 'token', 'context', 'intent_sha256'}
            and proof == {'schema': 'campaign_uncredited_handoff_v1', 'token': binding['token'], 'context': CONTEXT, 'intent_sha256': intent_sha}
            and ack_value == {'schema': 'campaign_progress_ack_v2', 'code': 'CAMPAIGN_CFG_READBACK_VERIFIED',
                              'persisted': True, 'suppressed': False, 'file_sha256': sha(paths(profile)['cfg']), 'steam_handoff': proof}
            and terminal['handoff_validation']['service_inspection'] == {'ok': True, 'proof': proof},
            'Actual LC ACK2/CFG SHA/native independently inspected same-token proof mismatch')
    journals = journal_records(profile, state, binding, intent_sha)
    if mode == MODES[3]:
        require(terminal == previous['terminal_checkpoint'], 'Independent menu refusal cannot change original terminal checkpoint')
    return rows, journals


def validate_retry_observation(report, row, profile, state, previous, lifecycle, journals):
    value = report.get('observations', {}).get('terminal_retry', {})
    require(value.get('schema') == 'ui_terminal_retry_observation_v1', 'Actual terminal retry observation required')
    first, blocked = value.get('first_failure'), value.get('blocked_retry')
    require(type(first) is dict and first and first == blocked, 'Both real failures must retain identical transaction observations')
    saved = read(Path(row['blocked_observation_path']))
    require(sha(row['blocked_observation_path']) == row['gates'][1]['blocked_observation_sha256']
            and all(value.get(key) == saved['observation'].get(key) for key in ('before', 'first_failure', 'blocked_retry')),
            'Final report must retain exact observations published while fault was still held')
    require(len(row['gates']) == 2 and row['gates'][1]['request']['detail']['transaction'] == journals[0]['document']['transaction'],
            'Actual retained failed transaction must be the one eventually applied')
    require(lifecycle[1] == row['gates'][1]['lifecycle_records'][1], 'Successful retry must preserve original pending LC2 raw bytes')
    success, operations = value.get('success', {}), value.get('operations', [])
    require(success.get('coordinator_instance_id') == first['coordinator_instance_id']
            and success.get('writer_instance_id') == first['writer_instance_id']
            and success.get('transaction') == first['transaction'] == journals[1]['document']['transaction']
            and success.get('intent_sha256') == first['intent_sha256'] == journals[1]['document']['intent_sha256']
            and first['frozen_semantics_sha256'] == journals[1]['document']['semantics_sha256']
            and success.get('cfg') == file_row(paths(profile)['cfg'], profile),
            'Successful original writer must apply the exact retained transaction and projected semantics')
    require(len(operations) == 3 and operations[:2] == saved['observation']['operations']
            and operations[2].get('result') == success.get('operation')
            and success['operation'].get('ok') is True and success['operation'].get('terminal_completed') is True
            and success['operation'].get('campaign_progress_committed') is True and integer(operations[2].get('phase'), 0),
            'Exactly two failed real terminal signals then one completed original terminal signal required')
    journal = success.get('journal', {})
    for index, key in enumerate(('prepared', 'applied')):
        native, actual = journal.get(key, {}), journals[index]
        require(native.get('ok') is True and integer(native.get('revision'), index + 1)
                and native.get('document') == actual['document'] and native.get('file_sha256') == actual['sha256']
                and native.get('previous') == actual['previous_sha256'] and native.get('payload_sha256') == actual['payload_sha256'],
                'Native successful journal verification must match actual host-read raw record')
    require(journal.get('head') == journal.get('applied') and type(journal.get('exact')) is dict and journal['exact']
            and journal.get('inventory') == {'ok': True, 'items': {Path(item['path']).name: item['sha256'] for item in journals}},
            'Successful CFG head/typed journal and exact two-file inventory required')
    require(len(value.get('gates', [])) == 2, 'Exactly two actual host gate handshakes required')
    for native, actual in zip(value['gates'], row['gates']):
        ack_path = Path(actual['request_path']).with_name(actual['request']['phase'] + '.ack.json')
        require(native.get('phase') == actual['request']['phase'] and native.get('request_sha256') == actual['request_sha256']
                and native.get('ack') == read(ack_path), 'Native ACK observation must bind actual closed host ACK bytes')


def execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous):
    row = {'mode': mode, 'profile': str(profile), 'process_nonce': nonce, 'complete': False, 'process_terminal': False,
           'gates': [], 'faults': [], 'post_errors': [], 'debugger_used': False, 'host_production_object_injection': False}
    child = blocker = None
    phase_index, arm = 0, None
    phases = PHASES if mode == 'resume_finish' else ()
    log_path = stage / 'native.log'
    start = time.monotonic()
    try:
        require(os.name == 'nt' and not baseline.engines() and not native_helpers(), 'Owned Windows engine/helper lane must be idle')
        before = business(profile); row['before_business'] = before
        command = [str(state['engine']), '--path', str(state['project']), '--rendering-method', 'gl_compatibility',
                   '--resolution', '1280x720', '--position', '30000,30000', '--script', str(workers / 'bootstrap.gd')]
        row['command'] = command
        with p.fs(log_path).open('xb') as stream:
            child = subprocess.Popen(command, cwd=state['project'], env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            row['pid'] = child.pid
            deadline, notice, scan = time.monotonic() + state['timeout'], time.monotonic(), 0.0
            while child.poll() is None:
                require(time.monotonic() < deadline, 'Owned natural-route process deadline exceeded')
                if time.monotonic() >= scan:
                    require(not baseline.engines() - {child.pid}, 'Foreign engine appeared; never control it')
                    scan = time.monotonic() + 2
                if time.monotonic() - notice >= 25:
                    print('RUNNING', mode, 'pid', child.pid, 'gates', phase_index, flush=True); notice = time.monotonic()
                if phase_index < len(phases):
                    phase = phases[phase_index]
                    request_path = stage / (phase + '.request.json')
                    request = gate(request_path, phase, child, profile, state, batch, nonce, previous['checkpoint'])
                    if request is not None:
                        observed = {'request': request, 'request_path': str(request_path), 'request_sha256': sha(request_path),
                                    'monotonic_ns': time.monotonic_ns()}
                        row['gates'].append(observed)
                        current = business(profile)
                        observed['business_before_host_action'] = current
                        observed['native_observer_disk'] = observer_disk(profile)
                        slot, life, binding = scope_paths(profile, previous['checkpoint'])
                        observed['slot_inventory'] = io.snapshot(slot)
                        observed['lifecycle_records'] = lifecycle_records(profile, state, previous['checkpoint'], 1 if phase_index == 0 else 2)
                        if phase_index == 0:
                            require(current == before and not current['cfg']['exists']
                                    and current['candidate_parent']['kind'] == 'absent' and not current['journal']['exists'],
                                    'C must arm only after exact paused restore with originally absent candidate parent; never delete an existing directory')
                            arm = current
                            blocker = TerminalParentBlocker(profile, stage, batch, nonce, child.pid)
                            blocker.arm()
                            row['faults'].append({'kind': 'owned_regular_file_candidate_parent', **blocker.verify(),
                                                  'armed_ns': time.monotonic_ns(), 'released': False})
                        else:
                            require(blocker is not None and blocker.handle is not None and arm is not None,
                                    'Only the same host-created retained blocker can be removed')
                            blocker.verify()
                            require(current['cfg'] == arm['cfg'] and current['settings'] == arm['settings']
                                    and observed['slot_inventory'] == row['gates'][0]['slot_inventory']
                                    and current['continue'] == continuation_after_lifecycle(arm['continue'], profile, observed['lifecycle_records'])
                                    and sorted(current['journal']['files']) == ['writing/owner.json']
                                    and current['journal']['directories'] == ['.', 'writing'],
                                    'Two terminal failures must leave original CFG/slot and actual rev0-owned CFG journal unchanged')
                            owner_path = paths(profile)['journal'] / 'writing/owner.json'
                            owner_raw = p.fs(owner_path).read_bytes().decode('utf-8')
                            owner = json.loads(owner_raw)
                            require(set(owner) == {'version', 'owner', 'pid', 'token'} and owner['version'] == '1'
                                    and owner['owner'] == '1' and owner['pid'] == str(child.pid)
                                    and re.fullmatch(r'[0-9a-f]{32}', owner['token']), 'CFG owner must be this actual C process')
                            blocked_path = stage / 'blocked_pending.json'
                            require(closed_json(blocked_path) is not None, 'Native blocked observation must be closed before release')
                            observed.update(owner_raw=owner_raw, owner_sha256=sha(owner_path), blocked_observation_sha256=sha(blocked_path))
                            row['blocked_observation_path'] = str(blocked_path)
                            validate_blocked_file(blocked_path, row, child, profile, state, batch, nonce, previous)
                            blocker.release()
                            row['faults'][-1].update(released=True, released_ns=time.monotonic_ns(),
                                                      moved_original_blocker_sha256=sha(blocker.evidence_path))
                            require(not p.fs(paths(profile)['blocker']).exists(), 'Only original owned blocker removed before final real UI retry')
                        ack(stage / (phase + '.ack.json'), request, request_path)
                        observed['ack_sha256'] = sha(stage / (phase + '.ack.json'))
                        phase_index += 1
                time.sleep(.04)
            child.wait(timeout=20)
        row.update(exit_code=child.returncode, process_terminal=True, seconds=round(time.monotonic() - start, 3))
        require(child.returncode == 0 and phase_index == len(phases)
                and (blocker is None or blocker.moved and blocker.handle is None), 'Native process or fault handshake did not complete')
        for observed in row['gates']:
            require(sha(observed['request_path']) == observed['request_sha256']
                    and sha(stage / (observed['request']['phase'] + '.ack.json')) == observed['ack_sha256'],
                    'Closed actual request/ACK bytes changed after publication')
        native_log = p.fs(log_path).read_text(encoding='utf-8', errors='replace')
        errors = [line for line in native_log.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line or 'Parse Error:' in line]
        row['native_errors'] = errors
        require(not errors, 'Native parse/runtime error cannot qualify this route')
        report_path = stage / 'report.json'; report = read(report_path)
        validate_route_report(report, mode, child, profile, state, batch, nonce)
        lifecycle, journals = validate_checkpoint(report, mode, profile, state, previous)
        if mode == 'resume_finish':
            validate_retry_observation(report, row, profile, state, previous, lifecycle, journals)
        after = business(profile)
        if mode == 'resume_finish':
            require(after['continue'] == continuation_after_lifecycle(before['continue'], profile, lifecycle)
                    and after['settings'] == before['settings']
                    and after['candidate_parent']['kind'] == 'directory'
                    and after['candidate_parent']['tree']['files'] == {}
                    and after['candidate_parent']['tree']['directories'] == ['.', 'v1'],
                    'Only actual LC2/LC3 may append to original continue scope; successful transaction cleans its own candidate stage')
        if mode == 'reject_terminal':
            require(after == before, 'Independent terminal refusal/startup may not alter any original business file')
        row.update(complete=True, report_path=str(report_path), report_sha256=sha(report_path), actual_checks=len(report['checks']),
                   lifecycle_records=lifecycle, cfg_journal_records=journals, actual_gate_count=phase_index, after_business=after)
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
        if blocker is not None:
            def preserve_blocker():
                require(row.get('process_terminal') is True, 'Do not remove fault while owned child terminal is unconfirmed')
                blocker.release()
            attempt(row, 'preserve_owned_blocker', preserve_blocker)
            attempt(row, 'close_owned_blocker_handle', blocker.close_handle)
        row['owned_handles_closed'] = blocker is None or blocker.handle is None
        row['owned_blocker_released'] = blocker is None or not blocker.created or blocker.moved
        ok, after = attempt(row, 'final_business_inventory', lambda: business(profile))
        if ok: row['after_business'] = after
        row['raw_pins'] = {}
        for path in (log_path, stage / 'report.json', stage / 'blocked_pending.json', stage / 'owned_stage_parent_blocker.json',
                     *(stage / (phase + suffix) for phase in phases for suffix in ('.request.json', '.ack.json'))):
            def pin_raw(path=path):
                if p.fs(path).is_file(): row['raw_pins'][str(path)] = sha(path)
            attempt(row, 'pin raw ' + path.name, pin_raw)
        if row['post_errors']: row['complete'] = False
        persist(stage / 'controller.json', row)
    return row


def execute(args):
    cases, named_pins = named_state()
    output = ROOT / '.godot/ui_terminal_retry_20261027' / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(parents=True, exist_ok=False)
    receipt = {'schema': 'ui_terminal_retry_four_process_v1', 'complete': False, 'four_process_terminal_retry_qualified': False,
               'steps': [], 'post_errors': [], 'named_pins': named_pins, 'base_run': str(args.base_run.resolve()),
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
        require(not baseline.engines(), 'Foreign engine appeared before full source admission')
        state = b1.full_state(args.base_run, named_pins); state['timeout'] = args.timeout; pins = state['pins']
        receipt.update(project=str(state['project']), source_identity=CONTENT, engine_sha256=state['engine_sha256'],
                       initial_identity_passed=True, cold_import_qualified=True,
                       candidate_manifest_sha256=sha(state['run_base'] / 'candidate_manifest.json'),
                       candidate_script_count=26, native_asset_count=1, import_receipts=state['imports'])
        for name, digest in list(pins.items()):
            source = Path(name)
            if source.suffix.lower() == '.exe': continue
            require(source.is_relative_to(ROOT), 'Non-binary provenance must be repository-owned')
            target = output / 'runner_inputs' / source.relative_to(ROOT)
            p.copy(source, target, digest); p.pin(target, pins, digest)
        workers = output / 'workers'; p.fs(workers).mkdir()
        bindings = {}
        for name in WORKERS:
            p.copy(HERE / name, workers / name, pins[str(HERE / name)])
            p.pin(workers / name, pins); bindings[name] = sha(workers / name)
        binding = workers / 'bindings.json'; h.save(p.fs(binding), bindings); p.pin(binding, pins)
        profile = Path(ROOT.anchor) / 'CodexQA/ui_terminal_retry' / batch[:12]
        h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
        base_env = h.common.private_environment(profile)
        receipt['profile'] = str(profile)
        previous_path = previous_report = None
        seen, nonces = set(), set()
        for index, mode in enumerate(MODES):
            p.verify_pins(pins)
            stage = output / ('%02d_' % index + mode); p.fs(stage).mkdir()
            nonce = uuid.uuid4().hex
            require(nonce not in nonces, 'Every owned process must have a distinct nonce'); nonces.add(nonce)
            env = environment(base_env, profile, state, workers, binding, stage, output, mode, batch, nonce, previous_path)
            row = execute_stage(mode, state, workers, profile, env, stage, batch, nonce, previous_report)
            receipt['steps'].append(row)
            require(row.get('complete') is True and type(row.get('pid')) is int and row['pid'] not in seen,
                    'Actual independent natural terminal process failed')
            seen.add(row['pid'])
            for name, digest in row['raw_pins'].items(): p.pin(name, pins, digest)
            p.pin(stage / 'controller.json', pins)
            previous_path = Path(row['report_path']); previous_report = read(previous_path)
            p.verify_pins(pins)
            print('PASS', index, mode, 'pid', row['pid'], 'checks', row['actual_checks'], flush=True)
        require(len(seen) == len(nonces) == len(receipt['steps']) == 4, 'Exactly four distinct real native processes required')
        receipt['four_process_terminal_retry_qualified'] = True
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
            receipt['remaining_native_helpers'] = native_helpers()
            receipt['native_helper_lane_idle'] = not receipt['remaining_native_helpers']
            receipt['lock_owner_verified'] = bool(locked and p.fs(h.shared.LOCK).is_file() and p.fs(h.shared.LOCK).read_text(encoding='utf-8') == owner)
            if receipt['engine_lane_idle'] and receipt['native_helper_lane_idle'] and receipt['lock_owner_verified'] and receipt['all_owned_children_terminal'] and receipt['all_owned_handles_closed']:
                p.fs(h.shared.LOCK).unlink(); receipt['lock_released'] = not p.fs(h.shared.LOCK).exists()
        attempt(receipt, 'owned_lock_release', unlock)
        receipt['complete'] = bool(receipt['four_process_terminal_retry_qualified'] and receipt['final_identity_passed']
                                   and receipt.get('lock_released') and not receipt['post_errors'] and 'error' not in receipt)
        if not receipt['complete']: receipt['four_process_terminal_retry_qualified'] = False
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
    parser.add_argument('--run', action='store_true', help='Explicitly run four independent natural-route processes')
    parser.add_argument('--full-preflight', action='store_true', help='Explicit expensive whole-source read-only admission')
    parser.add_argument('--timeout', type=int, default=1320, help='Bounded seconds per process; original natural route deadlines retained')
    parser.add_argument('--wait-lane', type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 1200 or args.wait_lane < 0: parser.error('Invalid bounded deadline')
    if args.run:
        execute(args); return
    cases, pins = named_state()
    result = {'validation_level': 'named_sources_only', 'named_pins': len(pins), 'source_identity': CONTENT,
              'modes': MODES, 'engine_started': False, 'profile_created': False, 'lane_acquired': False,
              'full_source_verified': False, 'native_qualified': False}
    if args.full_preflight:
        state = b1.full_state(args.base_run, pins)
        result.update(validation_level=state['validation_level'], full_source_verified=True,
                      cold_import_qualified=state['cold_import_qualified'], total_pins=len(state['pins']))
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
