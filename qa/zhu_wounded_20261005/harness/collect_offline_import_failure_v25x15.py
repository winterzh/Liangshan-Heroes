from pathlib import Path
import datetime, hashlib, json
ROOT = Path('E:/ChatGPT/水浒')
QA = ROOT / 'qa/zhu_wounded_20261005'
RUN = Path('E:/ChatGPT/qa-world-restore-20261007/daming_safe_retreat_v25s_r2f_offline_prefix_c_71d4275a')
OBS = Path('E:/ChatGPT/daming_safe_retreat_v25_proposal/OBSERVED_R2F_71D4275A_INTERRUPTED_FX.json')
files = []

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def copy_pin(row, target):
    source = Path(row['path']); raw = source.read_bytes()
    assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert target.read_bytes() == raw
    else:
        with target.open('xb') as handle:
            handle.write(raw)
    files.append({'path': target.relative_to(ROOT).as_posix(), 'bytes': len(raw),
                  'sha256': sha(raw), 'source': str(source)})

assert sha(OBS.read_bytes()) == '4ff3b233c4a072fc299c8c7d2ec48cd576b6e05a23003f6a37df3c3b46d47860'
obs = json.loads(OBS.read_text(encoding='utf-8'))
assert obs['terminal'] is True and obs['actual_PTY_terminal_exit_code'] == 1 and obs['lock_released'] is True
for key in ['complete', 'overall_v25_qualified', 'native_import_completed',
            'profile_guard_executed', 'new_C_executed', 'both_actual_A_executed',
            'closed_source_proof_created', 'fullreuse_started']:
    assert obs[key] is False
assert not obs['new_continuation_subtree_files']
for row in obs['original_stage_log_final_evidence']:
    source = Path(row['path']); assert source.is_relative_to(RUN)
    copy_pin(row, QA / 'raw' / RUN.name / source.relative_to(RUN))
for source, target in [(OBS, QA / 'proposals/daming_safe_retreat_v25' / OBS.name),
                       (Path(__file__), QA / 'harness' / Path(__file__).name)]:
    raw = source.read_bytes()
    copy_pin({'path': str(source), 'bytes': len(raw), 'sha256': sha(raw)}, target)
out = QA / 'offline_import_interruption_delivery_v25x15.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump({'schema': 'offline_import_interruption_delivery_v25x15',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'files': files, 'actual_PTY_exit_code': 1, 'complete': False,
               'overall_v25_qualified': False, 'new_C_executed': False,
               'both_actual_A_executed': False, 'closed_source_proof_created': False,
               'engine_started_by_collector': False, 'profile_cache_uploaded': False,
               'original_failed_profile_preserved': True}, handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'overall_v25_qualified': False}))
