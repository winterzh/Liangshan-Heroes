"""Review the exact owned Wu action/proof round before whitelist staging."""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8').strip()
parent='6faf5fc41c1c215a2fe5aa9830d63dceaa23a896';branch='codex/sync-20260905-stable'
assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
assert not git('diff','--cached','--name-only')
r=read(ROOT/'qa/zhu_wounded_20261005/ordinary_chapter_actions_v6b.json')
assert r['complete'] and r['lock_released'] and r['private_patch_verified'] and r['candidate_input_drift']==0
assert not r['source_changes'] and not r['private_source_changes'] and r['result']['checks']==255 and r['result']['passed']
assert r['result']['engine_time_scale']==1.0 and len(r['result']['screenshots'])==32
for row in r['source_files']+r['candidate_inputs']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
m=read(ROOT/'assets/direction4/ordinary_wu_song_20261007_actions_v6.json')
assert not m['production_qualified'] and not m['runtime_action_qualified'] and not m['resources'] and len(m['sources'])==7 and len(m['poses'])==16
for row in m['sources'].values():assert row['import_dimensions_verified'] and sha(ROOT/row['path'])==row['sha256']
g=read(ROOT/'tools/contracts/zhu_wounded_20261005/generation_wu_song_actions_v6.json')
assert sha(ROOT/g['parent_lineage'])==g['parent_sha256']
for row in g['jobs']:
 assert sha(ROOT/row['repository_path'])==row['sha256'] and sha(ROOT/row['request'])==row['request_sha256'] and not row['native_pixel_edits']
 for ref in row['references']:assert sha(ROOT/ref['path'])==ref['sha256']
review=read(ROOT/'qa/zhu_wounded_20261005/ordinary_chapter_actions_review_v6.json')
for row in review['reviewed']:assert sha(ROOT/row['path'])==row['sha256']
docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
allowed=set(docs)|{'assets/direction4/ordinary_wu_song_20261007_actions_v6.json'}
for row in m['sources'].values():allowed.update([row['path'],row['path']+'.import'])
allowed.update(row['path'] for row in review['reviewed'])
qa='qa/zhu_wounded_20261005/'
allowed.update(qa+n for n in ['ordinary_chapter_actions_v6b.json','ordinary_chapter_actions_review_v6.json','ordinary_chapter_actions_failed_parents_v6.json','wu_song_actions_texture_v6.json'])
allowed.update(qa+'harness/ordinary_chapter_actions_'+v+ext for v in ['v6','v6a','v6b'] for ext in ['.gd','.py'])
allowed.add(qa+'harness/texture_bootstrap_wu_actions_v6.py')
prefix='tools/contracts/zhu_wounded_20261005/'
allowed.update(prefix+n for n in ['build_wu_actions_v6.py','generation_wu_song_actions_v6.json','record_ordinary_actions_v6_progress.py','review_actions_sync_v6.py'])
allowed.update(row['request'] for row in g['jobs'])
raw=subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8')
names=[]
for item in raw.split('\0'):
 if not item:continue
 assert item[:2] in [' M','??'];name=item[3:];assert name in allowed,name;names.append(name)
assert set(names)==allowed,(set(names)-allowed,allowed-set(names))
files=[]
for name in sorted(names):
 p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
 assert not any(part in ['.git','.godot','profiles','build','__pycache__'] for part in p.parts)
 if p.suffix in ['.py','.gd','.json','.md','.import']:
  text=p.read_text(encoding='utf-8')
  assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',text),name
  if p.suffix=='.py':ast.parse(text,filename=name)
 files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name),
  'normalization':'Git text filter permitted for docs only' if name in docs else 'native bytes'})
evidence={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(row['bytes'] for row in files),'secret_findings':[],
 'mechanical_checks':255,'captures':32,'native_import_checks':7,'production_qualified':False,
 'scope':'Original-chapter diagnostic and new native Wu action-source candidates/provenance only; no new SpriteFrames, default route, full-game qualification, cleanup or platform release.'}
p=OUT/'actions_sync_review_v6.json';assert not p.exists();p.write_bytes((json.dumps(evidence,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
p=OUT/'actions_sync_whitelist_v6.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(names))+b'\0')
print(json.dumps({'passed':True,'files':len(files),'bytes':evidence['bytes'],'mechanical_checks':255,'native_import_checks':7,'secret_findings':0}))
