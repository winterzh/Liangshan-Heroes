"""Review only this Wu gait round's changed paths before an explicit Git stage."""
from pathlib import Path
import subprocess,hashlib,json,re,ast
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8').strip()
assert git('branch','--show-current')=='codex/sync-20260905-stable'
assert git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
parent='3ee570bd8c1eee156583addb6062d1de5f1cf7d3'
assert git('rev-parse','HEAD')==parent==git('rev-parse','origin/codex/sync-20260905-stable')
assert not git('diff','--cached','--name-only')
raw=subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8')
names=[]
docs={'docs/'+name for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
for line in raw.split('\0'):
    if not line:continue
    assert line[:2] in [' M','??'],line
    name=line[3:]
    allowed=(name=='.gitattributes' or name in docs
        or name.startswith('assets/anim/character_traits_v5_wu_song_gait_') and name.endswith('.tres')
        or name.startswith('assets/characters/wu_song_traits_20261006/') and (name.endswith('_v5.png') or name.endswith('_v5.png.import'))
        or name=='assets/direction4/ordinary_wu_song_20261006_gait_v5.json'
        or name.startswith('tools/contracts/zhu_wounded_20261005/')
        or name.startswith('qa/zhu_wounded_20261005/'))
    assert allowed,name
    assert not any(part in ['.godot','.git','profiles','build','__pycache__'] for part in Path(name).parts)
    assert Path(name).suffix.lower() not in ['.uid','.exe','.pck','.zip','.7z','.pem','.key']
    names.append(name)
for name in names:
    p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
    if p.suffix.lower() in ['.py','.gd','.json','.md','.tres','.import'] or name=='.gitattributes':
        t=p.read_text(encoding='utf-8')
        assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',t),name
        if p.suffix=='.py':ast.parse(t,filename=name)
r=json.loads((ROOT/'qa/zhu_wounded_20261005/ordinary_wu_song_gait_motion_comparison_v5.json').read_text(encoding='utf-8'))
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==r['candidate_input_drift']==0
assert len(r['result']['checks'])==96 and all(c['passed'] for c in r['result']['checks'])
for v in r['candidate_inputs']:assert sha(ROOT/v['path'])==v['sha256']
for v in r['harnesses']:assert sha(ROOT/v['path'])==v['sha256']
review={'passed':True,'parent':parent,'branch':git('branch','--show-current'),'secret_scan_findings':[],
        'scope':'Wu ordinary native17source/20pose gait candidate, exact authoring/failures and completed detached96check/80capture motion diagnostic. No ordinary production routing or platform qualification.',
        'files':[{'path':n,'bytes':(ROOT/n).stat().st_size,'sha256':sha(ROOT/n)} for n in sorted(names)]}
review['bytes']=sum(v['bytes'] for v in review['files'])
p=OUT/'wu_gait_sync_review_v5.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
p=OUT/'wu_gait_sync_whitelist_v5.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(names))+b'\0')
print(json.dumps({'passed':True,'files':len(names),'bytes':review['bytes'],'runtime_checks':96,'captures':80,'secret_findings':0,'production_qualified':False}))
