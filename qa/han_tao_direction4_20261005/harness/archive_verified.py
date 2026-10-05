"""Keep every failed/final artifact, authenticating exact receipt bytes."""
from pathlib import Path
import json,hashlib,shutil
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent.resolve();dest=repo/'qa/han_tao_direction4_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
run=Path(json.loads((base/'final_run.json').read_text(encoding='utf-8'))['run'])
r=json.loads((run/'evidence/receipt.json').read_text(encoding='utf-8'));v=json.loads((base/'visual_review.json').read_text(encoding='utf-8'))
assert r['complete'] and r['lock_released'] and not r['source_changes'] and not r['private_source_changes'] and v['passed'] and v['complete']
rows=[]
def copy(src,dst):
 assert dst.resolve().is_relative_to(dest.resolve());dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(src)==sha(dst)
 rows.append({'path':dst.relative_to(dest).as_posix(),'sha256':sha(dst),'bytes':dst.stat().st_size})
for p in sorted([*base.glob('20261005_*/evidence/receipt.json'),*base.glob('continuation_*/evidence/receipt.json')]):
 owner=p.parents[1];data=json.loads(p.read_text(encoding='utf-8'));folder=dest/('final' if owner==run else 'review_iterations/'+owner.name)
 for row in data.get('artifacts',[]):
  src=owner/'evidence'/row['path'];assert src.resolve().is_relative_to((owner/'evidence').resolve()) and sha(src)==row['sha256'] and src.stat().st_size==row['bytes'];copy(src,folder/row['path'])
 copy(p,folder/'receipt.json')
bootstrap=Path(json.loads((base/'texture_bootstrap_run.json').read_text(encoding='utf-8'))['run'])
for name in ['receipt.json','import.log','dimensions.log']:copy(bootstrap/name,dest/'texture_bootstrap'/name)
copy(bootstrap/'project/dimensions.json',dest/'texture_bootstrap/dimensions.json')
for name in ['visual_review.json','first_visual_review.json','quad_review_errors.json','own_finished_lock_release.json','own_imported_lock_release.json']:
 if (base/name).exists():copy(base/name,dest/name)
for name in ['texture_bootstrap.py','continue_frozen.py','wait_continue.py','archive_verified.py','cleanup_verified.py','review_final.py']:
 if (base/name).exists():copy(base/name,dest/'harness'/name)
(dest/'artifact_index.json').write_text(json.dumps({'complete':True,'artifacts':rows,'scope':'All final and failed run artifacts verified against original receipt SHA; no failed screenshot treated as final.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'retained_artifacts':len(rows),'checks':sum(x['checks'] for x in r['character_results']),'screens_reviewed':len(v['screenshots'])}))
