from pathlib import Path
import hashlib, json, datetime, re

ROOT = Path('E:/ChatGPT/水浒')
RUN = Path('E:/ChatGPT/qa-world-restore-20261007/daming_admit_v24s_2a817e70')
Q = ROOT / 'qa/zhu_wounded_20261005'
CASES = ['A_half_save', 'B_continue_resave', 'C_verify_resave']
ERROR = re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)')
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')

def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def copy_new(p, name):
    target = Q / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert target.read_bytes() == p.read_bytes(), str(target)
    else:
        with target.open('xb') as f:
            f.write(p.read_bytes())
    assert digest(target) == digest(p)
    return {'path': target.relative_to(ROOT).as_posix(), 'bytes': target.stat().st_size,
            'sha256': digest(target), 'original': str(p)}

main = read(RUN / 'receipt.json')
assert main['complete'] is True and main['lock_released'] is True
assert not main.get('failure')
for key in ['root_input_drift', 'private_input_drift', 'source_native_drift', 'private_native_drift']:
    assert main[key] == 0, key
assert main['independent_processes'] == 3
steps = main['steps']
assert [s['case'] for s in steps if s.get('case') in CASES] == CASES
assert steps[-1].get('case') == 'final_source_native_and_slot_audit'
assert all(s['complete'] is True for s in steps)
candidate = read(Q / 'native_ownership_json_candidate_v24q.json')
for row in candidate['files']:
    p = ROOT / row['path']
    assert p.stat().st_size == row['bytes'] and digest(p) == row['after_sha256'], row['path']
assert all(main.get(k) is False for k in ['public_campaign_continue_qualified', 'natural_victory_qualified', 'reward_once_qualified'])

files = [copy_new(RUN / 'receipt.json', 'daming_admit_complete_receipt_v24s.json')]
logs = []
for step in steps:
    if not step.get('log'):
        continue
    p = Path(step['log'])
    assert digest(p) == step['log_sha256']
    assert step['process_terminal'] is True
    assert not ERROR.search(ANSI.sub('', p.read_text(encoding='utf-8', errors='replace')))
    tag = step.get('case') or step['stage']
    tag = re.sub(r'[^A-Za-z0-9_]+', '_', tag)
    files.append(copy_new(p, 'daming_admit_' + tag + '_log_v24s.txt'))
    logs.append({'stage': tag, 'pid': step['pid'], 'exit_code': step['exit_code'], 'sha256': digest(p), 'errors': 0})
for p in sorted((RUN / 'steps').glob('*/receipt.json')):
    files.append(copy_new(p, 'daming_admit_' + p.parent.name + '_step_v24s.json'))
for name in ['isolated_slot_and_lifecycle_manifest.json', 'qualified_import_metadata_companions.json']:
    files.append(copy_new(RUN / name, 'daming_admit_' + name.replace('.json', '_v24s.json')))

processes = []
for case in CASES:
    step = next(s for s in steps if s.get('case') == case)
    report = read(RUN / 'native_evidence' / case / 'report.json')
    assert report['passed'] is True and all(r['passed'] is True for r in report['checks'])
    assert report['pid'] == step['pid'] and report['nonce'] == step['process_nonce']
    assert len(report['checks']) == step['checks']
    assert digest(RUN / 'native_evidence' / case / 'report.json') == step['report_sha256']
    userdata_for_report = Path(report['actual_user_data_dir'])
    assert userdata_for_report.is_relative_to(RUN / 'profile')
    for row in report['evidence']:
        p = userdata_for_report / row['path'][7:] if row['path'].startswith('user://') else Path(row['path'])
        assert p.is_file() and digest(p) == row['sha256'], str(p)
        # These are isolated synthetic native QA artifacts, never player profiles.
        assert p.is_relative_to(RUN / 'native_evidence') or p.is_relative_to(RUN / 'profile')
    for p in sorted((RUN / 'native_evidence' / case).glob('*.json')):
        files.append(copy_new(p, 'daming_admit_' + case + '_' + p.name.replace('.json', '_v24s.json')))
    processes.append({'case': case, 'pid': step['pid'], 'nonce': step['process_nonce'],
                      'checks': step['checks'], 'generation': 1 if case == CASES[0] else 2,
                      'slot_sha256': step['slot_sha256'], 'content_version': step['actual_content_version'],
                      'native_started_ns': step['native_started_ns'], 'native_finished_ns': step['native_finished_ns']})
assert len({r['pid'] for r in processes}) == len({r['nonce'] for r in processes}) == 3
assert processes[0]['native_finished_ns'] <= processes[1]['native_started_ns']
assert processes[1]['native_finished_ns'] <= processes[2]['native_started_ns']
assert processes[1]['slot_sha256'] == processes[2]['slot_sha256']

userdata = Path(read(RUN / 'native_evidence' / CASES[2] / 'report.json')['actual_user_data_dir'])
assert userdata.is_relative_to(RUN / 'profile')
for tag in ['A', 'B']:
    files.append(copy_new(userdata / 'daming_admit_v24o' / ('handoff_' + tag + '.json'),
                          'daming_admit_handoff_' + tag + '_v24s.json'))
for generation in [1, 2]:
    p = RUN / 'retained_slots' / ('generation_' + str(generation) + '.json')
    envelope = read(p)
    raw = envelope['payload'].encode('utf-8')
    assert len(raw) == int(envelope['payload_bytes'])
    assert hashlib.sha256(raw).hexdigest() == envelope['payload_sha256']
    assert digest(p) == processes[generation - 1]['slot_sha256']
    assert int(envelope['revision']) == generation
    assert envelope['previous_sha256'] == ('0' * 64 if generation == 1 else processes[0]['slot_sha256'])
    files.append(copy_new(p, 'daming_admit_generation_' + str(generation) + '_v24s.json'))
for p in sorted((RUN / 'native_evidence').glob('*.json')):
    files.append(copy_new(p, 'daming_admit_' + p.name.replace('.json', '_v24s.json')))
for key, name, checks in [('json_boundary_report', 'daming_admit_json_boundary_report_v24s.json', 533),
                           ('owned_slot_retry_report', 'daming_admit_owned_slot_report_v24s.json', 76)]:
    row = main[key]
    p = Path(row['path'])
    assert digest(p) == row['sha256'] and row['checks'] == checks
    files.append(copy_new(p, name))

proof = {'schema': 'daming_admission_native_continuation_qualified_v24s',
         'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
         'complete': True, 'runtime_candidate_qualified': True, 'private_runtime_patches': 0,
         'source_candidate_receipt': 'qa/zhu_wounded_20261005/native_ownership_json_candidate_v24q.json',
         'source_candidate_receipt_sha256': digest(Q / 'native_ownership_json_candidate_v24q.json'),
         'actual_producer': 'E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24s.py',
         'actual_producer_sha256': digest(Path('E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24s.py')),
         'original_run': str(RUN), 'original_receipt_sha256': digest(RUN / 'receipt.json'),
         'processes': processes, 'native_logs': logs, 'files': files,
         'scope': 'Actual normal-order admission half-save, distinct full Session install/natural admission/resave, third process generation2 install and 120 native ticks without duplicate effects; fixed JSON boundary and original OwnedSlot regressions.',
         'public_campaign_continue_qualified': False, 'natural_victory_qualified': False,
         'reward_once_qualified': False, 'campaign_persistence_qualified': False,
         'safe_retreat_qualified': False, 'steam_published_this_round': False,
         'remaining_development_plan_unchanged': True}
target = Q / 'daming_admission_continuation_qualified_v24s.json'
with target.open('x', encoding='utf-8') as f:
    json.dump(proof, f, ensure_ascii=False, indent=2)
    f.write('\n')
print(json.dumps({'proof': str(target), 'files': len(files) + 1,
                  'bytes': sum(r['bytes'] for r in files), 'processes': processes}))
