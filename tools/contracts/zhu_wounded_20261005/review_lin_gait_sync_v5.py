"""Review this Lin candidate round's exact changed paths before staging."""
from pathlib import Path
import subprocess,json,hashlib,re,ast
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
parent='869dea41a55c2797c782a1cc78de86c6e1cf47f8'
assert git('branch','--show-current')=='codex/sync-20260905-stable'
assert git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
assert git('rev-parse','HEAD')==parent==git('rev-parse','origin/codex/sync-20260905-stable')
assert not git('diff','--cached','--name-only')
docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
names=[]
raw=subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8')
for line in raw.split('\0'):
 if not line:continue
 assert line[:2] in [' M','??'];n=line[3:]
 allowed=(n in docs or n.startswith('assets/anim/character_traits_v5_lin_chong_gait_') and n.endswith('.tres')
  or n.startswith('assets/characters/lin_chong_traits_20261006/') and (n.endswith('_v5.png') or n.endswith('_v5.png.import'))
  or n=='assets/direction4/ordinary_lin_chong_20261006_gait_v5.json'
  or n.startswith('tools/contracts/zhu_wounded_20261005/') or n.startswith('qa/zhu_wounded_20261005/'))
 assert allowed,n
 assert not any(p in ['.git','.godot','profiles','build','__pycache__'] for p in Path(n).parts)
 assert Path(n).suffix.lower() not in ['.uid','.exe','.pck','.zip','.7z','.key','.pem'];names.append(n)
for n in names:
 p=ROOT/n;assert p.is_file() and p.stat().st_size<50*1024*1024
 if p.suffix.lower() in ['.py','.gd','.json','.md','.tres','.import']:
  t=p.read_text(encoding='utf-8');assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',t),n
  if p.suffix=='.py':ast.parse(t,filename=n)
r=json.loads((ROOT/'qa/zhu_wounded_20261005/ordinary_lin_chong_gait_motion_comparison_v5.json').read_text(encoding='utf-8'))
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==r['candidate_input_drift']==0
assert r['result']['engine_time_scale']==1.0 and len(r['result']['checks'])==96 and all(c['passed'] for c in r['result']['checks'])
for v in r['candidate_inputs']:assert sha(ROOT/v['path'])==v['sha256']
for v in r['harnesses']:assert sha(ROOT/v['path'])==v['sha256']
j={'passed':True,'parent':parent,'branch':git('branch','--show-current'),'secret_scan_findings':[],
 'scope':'Lin native17source20pose gait candidate, exact authoring/failed corrections and completed detached96check80capture normal-clock motion proof. No default production routing/full-game qualification.',
 'files':[{'path':n,'bytes':(ROOT/n).stat().st_size,'sha256':sha(ROOT/n)} for n in sorted(names)]}
j['bytes']=sum(v['bytes'] for v in j['files'])
p=OUT/'lin_gait_sync_review_v5.json';assert not p.exists();p.write_bytes((json.dumps(j,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
p=OUT/'lin_gait_sync_whitelist_v5.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(names))+b'\0')
print(json.dumps({'passed':True,'files':len(names),'bytes':j['bytes'],'runtime_checks':96,'captures':80,'normal_clock':1.0,'secret_findings':0,'production_qualified':False}))
