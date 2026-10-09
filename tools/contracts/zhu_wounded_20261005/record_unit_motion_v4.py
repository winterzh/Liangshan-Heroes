"""Preserve a completed detached Unit run and its failed entry-point predecessor."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src,dst):
    if dst.exists(): assert sha(src)==sha(dst)
    else: shutil.copyfile(src,dst)
run=Path(sys.argv[1]);r=read(run/'receipt.json')
variant=sys.argv[3] if len(sys.argv)>3 else 'passing'
assert variant in ('passing','refined','footclear')
assert sha(run/'unit_motion_v4.py')==r['runner_sha256']
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0
assert not r['production_qualified'] and len(r['result']['checks'])==44
assert len(r['result']['samples'])==len(r['captures'])==80
for row in r['inputs']: assert sha(ROOT/row['path'])==row['sha256']==sha(run/'project'/row['path'])
for row in r['harnesses']: assert sha(ROOT/row['path'])==row['sha256']
for row in r['captures']: assert sha(run/'project'/row['path'])==row['sha256']
preserve(run/'receipt.json',QA/f'shi_xiu_unit_motion_{variant}_v4.json')
if len(sys.argv)>2 and sys.argv[2]!='-':
    failed=Path(sys.argv[2]);f=read(failed/'receipt.json')
    assert not f['complete'] and f['lock_released'] and 'failure' in f
    preserve(failed/'receipt.json',QA/'shi_xiu_unit_motion_entry_failure_v4.json')
print(json.dumps({'checks':44,'captures':80,'inputs':len(r['inputs']),'input_sha_drift':0,'production_qualified':False}))
