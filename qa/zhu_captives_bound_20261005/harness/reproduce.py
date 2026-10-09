"""Independently rebuild all four captive manifests/resources with unchanged native inputs."""
from pathlib import Path
import json,hashlib,shutil,subprocess,sys
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;project=base/'reproduction/project'
assert not project.exists();project.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
keys=['yang_lin','huang_xin','wang_ying','deng_fei'];inputs={'tools/build_directional_spriteframes.py','tools/directional_character_sources.py'}
for key in keys:
 contract=repo/f'tools/contracts/{key}_bound_20261005';jobs=json.loads((contract/'jobs.json').read_text(encoding='utf-8'))
 inputs|={j['repository_input'] for j in jobs}|{j['repository_input']+'.import' for j in jobs if (repo/(j['repository_input']+'.import')).is_file()}
 inputs|={p.relative_to(repo).as_posix() for p in contract.rglob('*') if p.is_file()}
for name in inputs:
 dst=project/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(repo/name,dst)
before={p:sha(project/p) for p in inputs};rows=[];steps=[]
for key in keys:
 manifest=f'assets/direction4/bound_{key}_20261005.json';contract=f'tools/contracts/{key}_bound_20261005';qa=f'qa/bound_{key}_20261005'
 for args in [[str(project/contract/'prepare.py')],[str(project/'tools/build_directional_spriteframes.py'),manifest,'--write'],[str(project/'tools/directional_character_sources.py'),manifest,contract+'/generation.json','--out',qa+'/source_audit.json']]:
  r=subprocess.run([sys.executable,'-X','utf8','-B',*args],cwd=project,capture_output=True,text=True,encoding='utf-8');assert r.returncode==0,r.stdout+r.stderr;steps.append({'argv':args,'stdout':r.stdout.strip(),'passed':True})
 outputs=[manifest,contract+'/generation.json',qa+'/bounds_audit.json',qa+'/source_audit.json']+json.loads((repo/manifest).read_text(encoding='utf-8'))['resources']
 current=[{'path':p,'sha256':sha(repo/p),'reproduced_sha256':sha(project/p),'passed':sha(repo/p)==sha(project/p)} for p in outputs];assert all(x['passed'] for x in current);rows+=current
 result={'complete':True,'outputs':current,'native_inputs_unchanged':True,'scope':'Separate tiny-tree deterministic metadata, source audit, lineage, bounds and four native TRES; PNGs unedited.'}
 (repo/qa/'reproduction.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert all(sha(project/p)==s for p,s in before.items())
qa=repo/'qa/zhu_captives_bound_20261005';qa.mkdir(parents=True,exist_ok=True)
(qa/'reproduction.json').write_text(json.dumps({'complete':True,'outputs':rows,'steps':steps,'native_inputs_unchanged':True},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'byte_identical_outputs':len(rows)}))
