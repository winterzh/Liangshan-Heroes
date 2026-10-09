"""Rebuild only metadata in a tiny separate tree, preserving native bytes."""
from pathlib import Path
import json,hashlib,shutil,subprocess,sys
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;project=base/'reproduction/project'
assert not project.exists();project.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest='assets/direction4/bound_qin_ming_20261005.json';contract='tools/contracts/qin_ming_bound_20261005'
jobs=json.loads((repo/contract/'jobs.json').read_text(encoding='utf-8'))
inputs={job['repository_input'] for job in jobs}|{job['repository_input']+'.import' for job in jobs if (repo/(job['repository_input']+'.import')).is_file()}
inputs|={p.relative_to(repo).as_posix() for p in (repo/contract).rglob('*') if p.is_file()}
inputs|={'tools/build_directional_spriteframes.py','tools/directional_character_sources.py'}
for name in inputs:
    dst=project/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(repo/name,dst)
before={p:sha(project/p) for p in inputs}
steps=[]
for args in [[str(project/contract/'prepare.py')],[str(project/'tools/build_directional_spriteframes.py'),manifest,'--write'],[str(project/'tools/directional_character_sources.py'),manifest,contract+'/generation.json','--out','qa/bound_qin_ming_20261005/source_audit.json']]:
    result=subprocess.run([sys.executable,'-X','utf8','-B',*args],cwd=project,capture_output=True,text=True,encoding='utf-8')
    assert result.returncode==0,result.stdout+result.stderr
    steps.append({'argv':args,'stdout':result.stdout.strip(),'passed':True})
outputs=[manifest,contract+'/generation.json','qa/bound_qin_ming_20261005/bounds_audit.json','qa/bound_qin_ming_20261005/source_audit.json']+json.loads((repo/manifest).read_text(encoding='utf-8'))['resources']
rows=[{'path':p,'sha256':sha(repo/p),'reproduced_sha256':sha(project/p),'passed':sha(repo/p)==sha(project/p)} for p in outputs]
assert all(row['passed'] for row in rows)
assert all(sha(project/p)==s for p,s in before.items() if p!=contract+'/generation.json')
result={'complete':True,'scope':'Independent tiny-tree deterministic metadata/lineage/bounds/source audit/four TRES rebuild; no native pixel edits or engine run.','outputs':rows,'steps':steps,'native_inputs_unchanged':True}
(repo/'qa/bound_qin_ming_20261005/reproduction.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'byte_identical_outputs':len(rows)}))
