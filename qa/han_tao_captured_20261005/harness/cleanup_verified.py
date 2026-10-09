"""After final review, unlink only this batch's byte-identical old import files."""
from pathlib import Path
import hashlib,json
base=Path(__file__).parent.resolve();repo=Path('E:/ChatGPT/水浒').resolve()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def safe(p):
    assert p.resolve().is_relative_to(base)
    for q in [p]+list(p.parents):
        if q==base.parent:break
        assert not q.is_symlink() and not (getattr(q.lstat(),'st_file_attributes',0)&0x400),str(q)
final=json.loads((base/'final_run.json').read_text(encoding='utf-8'))
run=Path(final['run']);receipt=json.loads((run/'evidence/receipt.json').read_text(encoding='utf-8'))
review=json.loads((base/'visual_review.json').read_text(encoding='utf-8'))
assert receipt['complete'] and review['passed'] and review['complete']
latest=Path(receipt['project']).resolve();safe(latest)
cache=latest/'.godot/imported';safe(cache)
reference={p.name:p for p in cache.iterdir() if p.is_file()}
targets=[]
for owner in [*base.glob('20261005_*'),base/'texture_bootstrap_dd9cdb8f']:
    old=owner/'project/.godot/imported'
    if not old.is_dir() or old.resolve()==cache.resolve():continue
    safe(old)
    for p in old.iterdir():
        if not p.is_file() or p.name not in reference:continue
        safe(p);r=reference[p.name]
        if p.stat().st_size==r.stat().st_size and sha(p)==sha(r):
            targets.append({'path':str(p),'reference':str(r),'bytes':p.stat().st_size,'sha256':sha(p)})
selected={Path(row['path']).resolve() for row in targets}
protected={p.resolve():sha(p) for p in base.rglob('*') if p.is_file() and p.resolve() not in selected}
for folder in ['assets/characters/han_tao_captured_20261005','tools/contracts/han_tao_captured_20261005','qa/han_tao_captured_20261005']:
    for p in (repo/folder).rglob('*'):
        if p.is_file():protected[p.resolve()]=sha(p)
for name in ['scripts/unit.gd','scripts/art_db.gd','tools/run_character_art_qa.py','tools/han_tao_capture_direction4_qa.gd','tools/han_tao_capture_body_fixture.gd','assets/portraits4.png','assets/direction4/han_tao_captured_20261005.json']:
    protected[(repo/name).resolve()]=sha(repo/name)
for row in targets:
    p=Path(row['path']);safe(p)
    assert p.resolve() in selected and p.stat().st_size==row['bytes'] and sha(p)==row['sha256'] and sha(Path(row['reference']))==row['sha256']
    p.unlink()
drift=[str(p) for p,s in protected.items() if not p.is_file() or sha(p)!=s]
assert not drift and all(not Path(r['path']).exists() for r in targets)
result={'complete':True,'removed_files':len(targets),'removed_bytes':sum(r['bytes'] for r in targets),'protected_files':len(protected),'protected_drift':drift,'latest_private_project_retained':str(latest),'scope':'Only own prior private imported files equal to latest cache by filename, size, SHA. All native sources, references, failed/final evidence, profiles and newest imported cache retained. No other project or task touched.','targets':targets}
out=repo/'qa/han_tao_captured_20261005/cleanup.json'
out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({k:v for k,v in result.items() if k!='targets'},ensure_ascii=False))
