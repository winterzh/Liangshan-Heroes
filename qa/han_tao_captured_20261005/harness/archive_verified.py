"""Retain complete exact QA evidence after successful native/visual review."""
from pathlib import Path
import hashlib,json,shutil
base=Path(__file__).parent;repo=Path('E:/ChatGPT/水浒');tag='han_tao_captured_20261005'
run=Path(json.loads((base/'final_run.json').read_text(encoding='utf-8'))['run'])
assert run.resolve().is_relative_to(base.resolve())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
receipt=json.loads((run/'evidence/receipt.json').read_text(encoding='utf-8'))
assert receipt['complete'] and receipt['lock_released'] and not receipt['source_changes'] and not receipt['private_source_changes']
review=json.loads((base/'visual_review.json').read_text(encoding='utf-8'))
assert review['passed'] and review['complete']
dest=repo/'qa'/tag
rows=[]
def copy(src,dst):
    assert dst.resolve().is_relative_to(dest.resolve())
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(src,dst);assert sha(src)==sha(dst)
    rows.append({'path':dst.relative_to(dest).as_posix(),'sha256':sha(dst),'bytes':dst.stat().st_size})
def evidence(source,target):
    receipt_path=source/'evidence/receipt.json'
    data=json.loads(receipt_path.read_text(encoding='utf-8'))
    for row in data.get('artifacts',[]):
        src=source/'evidence'/row['path']
        assert src.resolve().is_relative_to((source/'evidence').resolve()) and sha(src)==row['sha256'] and src.stat().st_size==row['bytes']
        copy(src,dest/target/row['path'])
    copy(receipt_path,dest/target/'receipt.json')
evidence(run,'final')
for name,label in [('20261005_061507_84e22fd5','preimport_engine_race'),('20261005_062329_6578b738','fixture_compile_error')]:
    source=base/name
    if source==run:continue
    evidence(source,'review_iterations/'+label)
for p in sorted([*base.glob('20261005_*/evidence/receipt.json'), *base.glob('continuation_*/evidence/receipt.json')]):
    source=p.parents[1]
    if source==run or source.name in ['20261005_061507_84e22fd5','20261005_062329_6578b738']:continue
    evidence(source,'review_iterations/'+source.name)
for name in ['receipt.json','import.log','dimensions.log']:
    copy(base/'texture_bootstrap_dd9cdb8f'/name,dest/'texture_bootstrap'/name)
copy(base/'texture_bootstrap_dd9cdb8f/project/dimensions.json',dest/'texture_bootstrap/dimensions.json')
copy(base/'own_preimport_lock_release.json',dest/'own_preimport_lock_release.json')
copy(base/'own_finished_lock_release.json',dest/'own_finished_lock_release.json')
copy(base/'visual_review.json',dest/'visual_review.json')
for name in ['audit_captured.py','texture_bootstrap.py','retain_lock_test.py','archive_verified.py','continue_frozen.py','wait_continue.py','review_final.py']:
    copy(base/name,dest/'harness'/name)
(dest/'artifact_index.json').write_text(json.dumps({'complete':True,'artifacts':rows,'scope':'Complete final/failed QA artifacts copied and checked against original receipt bytes.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'retained_artifacts':len(rows),'checks':sum(r['checks'] for r in receipt['character_results']),'screens_reviewed':len(review['screenshots'])}))
