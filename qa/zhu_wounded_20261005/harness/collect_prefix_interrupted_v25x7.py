from pathlib import Path
import datetime, hashlib, json, subprocess

ROOT = Path('E:/ChatGPT/水浒')
QA = ROOT / 'qa/zhu_wounded_20261005'
RUN = Path('E:/ChatGPT/qa-world-restore-20261007/daming_safe_retreat_v25s_r2d_prefix_c_8f3d393d')
OBS = Path('E:/ChatGPT/daming_safe_retreat_v25_proposal/OBSERVED_R2D_8F3D393D_INTERRUPTED_FX.json')
BASE = '6ddb3a60b6e91ba6359817af79e6e7a273c16181'
files = []

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def remember(path, source=None):
    raw = path.read_bytes()
    row = {'path': path.relative_to(ROOT).as_posix(), 'bytes': len(raw), 'sha256': digest(raw)}
    if source is not None:
        row['source'] = str(source)
    files.append(row)

def copy_new(source, target, expected):
    raw = source.read_bytes()
    assert digest(raw) == expected
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as handle:
        handle.write(raw)
    assert target.read_bytes() == raw
    remember(target, source)

assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == BASE
assert digest(OBS.read_bytes()) == 'cd048863e1e03b5dc0e6bbec6fe05f98c307443a6a29a5d27f6ed8a3223b9502'
obs = json.loads(OBS.read_text(encoding='utf-8'))
assert obs['terminal'] is True and obs['actual_PTY_exit_code'] == 1 and obs['lock_released'] is True
assert obs['complete'] is False and obs['overall_v25_qualified'] is False
assert obs['new_C_executed'] is False and obs['both_actual_A_executed'] is False
assert obs['full_reuse_started'] is False
actual = json.loads((RUN / 'receipt.json').read_text(encoding='utf-8'))
assert actual['complete'] is False and actual['lock_released'] is True
assert actual['failure'] == {'type': 'BatchFailure', 'message': 'foreign_engine_resumed; entire batch/profile preserved, no retry'}
for row in obs['original_evidence']:
    source = Path(row['path'])
    assert source.is_relative_to(RUN) and source.stat().st_size == row['bytes']
    copy_new(source, QA / 'raw/daming_safe_retreat_v25s_r2d_prefix_c_8f3d393d' / source.relative_to(RUN), row['sha256'])
copy_new(OBS, QA / 'proposals/daming_safe_retreat_v25' / OBS.name, digest(OBS.read_bytes()))
copy_new(Path(__file__), QA / 'harness' / Path(__file__).name, digest(Path(__file__).read_bytes()))

short = ('<!-- prefix-interruption-v25x7 -->\n'
         '## 2026-10-08 03:46：恢复批导入被共享引擎占用中断\n\n'
         'run8f3d393d 实际 exit1、锁已释放；尚未执行C或双方单人撤离A，整体资格仍false。'
         '原始收据和完整日志已保留于QA，详见 [当前公司交接](OFFICE_START_20261008.md)。'
         '后续仅在更长自然空闲后建全新批，原失败profile不重用；完整计划继续保留。\n\n')
for name in ['WORKLOG.md', 'SOURCE_SETUP.md', 'PROJECT_STATUS.md', 'DEVELOPMENT_PLAN.md',
             'DIRECTORY_INDEX.md', 'HANDOFF_20261007_OFFICE.md', 'DEVELOPMENT_AUDIT_20261007.md',
             'DAMING_SAFE_RETREAT_DESIGN_20261008.md']:
    path = ROOT / 'docs' / name
    old = path.read_bytes()
    assert b'prefix-interruption-v25x7' not in old
    path.write_bytes(short.encode('utf-8') + old)
    remember(path)
office = ROOT / 'docs/OFFICE_START_20261008.md'
text = office.read_text(encoding='utf-8-sig')
title, body = text.split('\n', 1)
office.write_text(title + '\n\n<!-- prefix-interruption-v25x7 -->\n'
                  '最新结果（03:46）：后继8f3d393d在原生导入时因共享Godot恢复占用而中止，'
                  'actual exit1、锁已释放，C/双方撤离A尚未执行。原失败批与新导入失败批分别保留，'
                  'v25整体仍未通过。下方首段“刚启动”是启动时快照，以本段及最终收据为准。'
                  '完整证据：qa/zhu_wounded_20261005/prefix_interrupted_delivery_v25x7.json。\n'
                  + body, encoding='utf-8', newline='\n')
remember(office)
out = QA / 'prefix_interrupted_delivery_v25x7.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump({'schema': 'daming_prefix_interruption_delivery_v25x7',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'base_commit': BASE, 'files': files, 'original_run': str(RUN),
               'source_receipt_sha256': obs['receipt_pin']['sha256'],
               'actual_PTY_exit_code': 1, 'complete': False, 'overall_v25_qualified': False,
               'new_C_executed': False, 'both_actual_A_executed': False,
               'production_candidates_committed': False, 'engine_started_by_collector': False,
               'original_failed_profile_preserved': True}, handle, ensure_ascii=False, indent=2)
remember(out)
with Path('E:/ChatGPT/prefix_interrupted_sync_v25x7_manifest.json').open('x', encoding='utf-8') as handle:
    json.dump({'base': BASE, 'branch': 'codex/sync-20260905-stable',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'files': files, 'qualified_runtime_paths': [],
               'scope': 'Actual interrupted import evidence and corrected office current-state handoff; runtime candidates excluded.'},
              handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'complete': False, 'overall_v25_qualified': False}))
