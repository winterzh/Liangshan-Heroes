from pathlib import Path
import datetime, hashlib, json, subprocess

ROOT = Path('E:/ChatGPT/水浒')
SOURCE = Path('E:/ChatGPT/daming_safe_retreat_v25_proposal')
QA = ROOT / 'qa/zhu_wounded_20261005'
TARGET = QA / 'proposals/daming_safe_retreat_v25'
PINS = {
    'run_daming_safe_retreat_v25s_r2d_prefix_c.py': '3d3715bb0c0a0b5be77bd840e46875a9856eab1164c65d8bbc44512274d37856',
    'PREFIX_C_INPUTS_V25S_R2D_07AD37BF.json': 'b4cfa3b00f4fdd5e2e354c4e9a5079c46b4b70a8c74633fc92dcda51d4cbcab6',
    'PREFIX_C_REVIEW_V25S_R2D_FX.json': '8972b22f62f9424fcb8958da1dd16778dd9e9eb3b9c033844103a480440e0c26',
}
NAMES = [*PINS, 'PREFIX_C_READY_ARGV_V25S_R2D.json', 'PREFIX_C_STATIC_V25S_R2D.json']

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()

def copy_new(source, target, expected=None):
    raw = source.read_bytes()
    if expected is not None:
        assert sha(raw) == expected, str(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as handle:
        handle.write(raw)
    assert target.read_bytes() == raw
    return {'path': target.relative_to(ROOT).as_posix(), 'bytes': len(raw),
            'sha256': sha(raw), 'source': str(source)}

assert git('branch', '--show-current') == 'codex/sync-20260905-stable'
assert git('remote', 'get-url', 'origin') == 'https://github.com/winterzh/Liangshan-Heroes.git'
assert not git('diff', '--cached', '--name-only')
review = json.loads((SOURCE / 'PREFIX_C_REVIEW_V25S_R2D_FX.json').read_text(encoding='utf-8'))
assert review['static_api_closure_passed'] is True
assert review['approved_stages'] == ['prefix_c_then_both_actual_A']
applied = json.loads(Path('E:/ChatGPT/daming_safe_retreat_v25_preapply_20261008/applied.json').read_text(encoding='utf-8'))
for row in applied['files']:
    assert sha((ROOT / row['path']).read_bytes()) == row['after_sha256']
    archived = TARGET / 'proposed' / row['path']
    assert sha(archived.read_bytes()) == row['after_sha256']

files = [copy_new(SOURCE / name, TARGET / name, PINS.get(name)) for name in NAMES]
files.append(copy_new(Path(__file__), QA / 'harness' / Path(__file__).name))
receipt = {
    'schema': 'safe_retreat_prefix_preparation_delivery_v25x5',
    'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'base_commit': git('rev-parse', 'HEAD'), 'files': files,
    'static_review_qualified': True, 'source_prefix_batch_complete': False,
    'new_native_success_claimed': False, 'overall_v25_qualified': False,
    'production_candidates_committed': False, 'engine_started_by_collector': False,
    'scope': 'Immutable exact-prefix recovery preparation only; original failed batch remains false. Actual new execution requires its own raw receipt and independent read-back.'
}
out = QA / 'safe_retreat_prefix_preparation_delivery_v25x5.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump(receipt, handle, ensure_ascii=False, indent=2)
print(json.dumps({'files': len(files), 'bytes': sum(row['bytes'] for row in files),
                  'receipt': out.relative_to(ROOT).as_posix(), 'overall_v25_qualified': False}))
