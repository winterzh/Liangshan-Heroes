from pathlib import Path
import datetime, hashlib, json
ROOT = Path('E:/ChatGPT/水浒')
QA = ROOT / 'qa/zhu_wounded_20261005'
SOURCE = Path('E:/ChatGPT/daming_safe_retreat_v25_proposal')
RUN = Path('E:/ChatGPT/qa-world-restore-20261007/daming_safe_retreat_v25s_r2d_prefix_c_5284b47e')
OBS = SOURCE / 'OBSERVED_R2D_5284B47E_INTERRUPTED_FX.json'
files = []

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def copy_pin(row, target):
    source = Path(row['path']); raw = source.read_bytes()
    assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as handle:
        handle.write(raw)
    assert target.read_bytes() == raw
    files.append({'path': target.relative_to(ROOT).as_posix(), 'bytes': len(raw),
                  'sha256': sha(raw), 'source': str(source)})

def copy_file(source, target):
    raw = source.read_bytes()
    copy_pin({'path': str(source), 'bytes': len(raw), 'sha256': sha(raw)}, target)

assert sha(OBS.read_bytes()) == '4566884e025652f884a475631c0590565165a22995ab4e96ef76d3a617902de9'
obs = json.loads(OBS.read_text(encoding='utf-8'))
assert obs['terminal'] is True and obs['actual_PTY_exit_code'] == 1 and obs['lock_released'] is True
for key in ['complete', 'overall_v25_qualified', 'new_C_executed', 'both_actual_A_executed', 'full_reuse_started']:
    assert obs[key] is False
for row in obs['original_evidence']:
    source = Path(row['path']); assert source.is_relative_to(RUN)
    copy_pin(row, QA / 'raw' / RUN.name / source.relative_to(RUN))
copy_file(OBS, QA / 'proposals/daming_safe_retreat_v25' / OBS.name)
row = obs['startup_receipt_pin']
copy_pin(row, QA / 'proposals/daming_safe_retreat_v25' / Path(row['path']).name)
row = obs['outer_natural_idle180_log']
copy_pin(row, QA / 'raw' / RUN.name / 'outer_natural_idle180_log.json')
copy_file(SOURCE / 'IDLE_COST_CORRECTION_V25S_20261008.json',
          QA / 'proposals/daming_safe_retreat_v25/IDLE_COST_CORRECTION_V25S_20261008.json')
copy_file(Path(__file__), QA / 'harness' / Path(__file__).name)
out = QA / 'second_prefix_interrupted_delivery_v25x9.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump({'schema': 'second_prefix_interrupted_delivery_v25x9',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'files': files, 'actual_PTY_exit_code': 1, 'complete': False,
               'overall_v25_qualified': False, 'new_C_executed': False,
               'both_actual_A_executed': False, 'engine_started_by_collector': False,
               'failed_original_profiles_preserved': True}, handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'receipt': out.relative_to(ROOT).as_posix(), 'overall_v25_qualified': False}))
