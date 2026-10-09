"""Delete only own older imported files identical to latest, retaining evidence."""
from pathlib import Path
import os,json,hashlib,sys
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent.resolve()
sys.dont_write_bytecode=True;sys.path.insert(0,str(repo/'tools'))
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def safe(p):
    assert p.resolve().is_relative_to(base)
    for q in [p,*p.parents]:
        if q==base.parent: break
        assert not os.lstat(q).st_file_attributes & 0x400,'Reparse point: '+str(q)
success=[]
for p in base.glob('20261005_*/evidence/receipt.json'):
    r=json.loads(p.read_text(encoding='utf-8'))
    if r.get('complete') and not (p.parent.parent/'visual_rejection.json').exists(): success.append((p.parent.parent,r))
assert len(success)==1,'Require exactly one latest accepted run'
run,r=success[0];latest=run/'project/.godot/imported';safe(latest)
review=json.loads((repo/'qa/bound_shi_qian_20261005/visual_review.json').read_text(encoding='utf-8'))
assert review['complete'] and review['passed'] and not running_engine()
olds=[p for p in base.glob('*/project/.godot/imported') if p!=latest]
for p in olds:safe(p)
protected=set()
for p in base.rglob('*'):
    if p.is_file() and not any(p.is_relative_to(old) for old in olds):protected.add(p)
for row in r['source_files']:protected.add(repo/row['path'])
protected.update(p for p in (repo/'qa/bound_shi_qian_20261005').rglob('*') if p.is_file())
before={str(p):sha(p) for p in sorted(protected)}
index={p.name:p for p in latest.iterdir() if p.is_file()}
removed=[];retained=[]
for old in olds:
    for p in old.iterdir():
        safe(p);assert p.is_file()
        keep=index.get(p.name)
        if keep is not None and p.stat().st_size==keep.stat().st_size and sha(p)==sha(keep):
            removed.append({'path':str(p),'retained':str(keep),'bytes':p.stat().st_size,'sha256':sha(p)})
        else:retained.append(str(p))
assert not running_engine()
for row in removed:
    p=Path(row['path']);keep=Path(row['retained']);safe(p);safe(keep)
    assert sha(p)==sha(keep)==row['sha256'];p.unlink();assert not p.exists()
assert all(Path(p).is_file() and sha(Path(p))==s for p,s in before.items())
result={'complete':True,'scope':'Only this Shi Qian QA root older imported files with latest filename/size/SHA identity; sources, profiles, native images, receipts/logs/screens, mismatches and latest full cache retained. Other batch/primary caches untouched. Older projects require reimport.','older_own_caches':len(olds),'removed_files':len(removed),'removed_bytes':sum(x['bytes'] for x in removed),'retained_mismatches':retained,'protected_files':len(before),'protected_sha_unchanged':True,'latest_project':str(run/'project'),'removed':removed}
(repo/'qa/bound_shi_qian_20261005/cleanup.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['complete','removed_files','removed_bytes','protected_files','protected_sha_unchanged']}))
