"""Review exact owned default-art, evidence and cleanup round before staging."""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
parent='7b453daa30a8d4873393c168cb311c18c09afd92';branch='codex/sync-20260905-stable'
assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0] and not git('diff','--cached','--name-only')
r=read(ROOT/'qa/zhu_wounded_20261005/ordinary_chapter_combat_production_v7.json')
assert r['complete'] and r['lock_released'] and r['covered_default_routes_verified'] and r['private_runtime_patches']==0
assert r['result']['passed'] and r['result']['checks']==367 and r['result']['engine_time_scale']==1.0 and len(r['result']['screenshots'])==48
assert not r['source_changes'] and not r['private_source_changes'] and r['candidate_input_drift']==0
for row in r['source_files']+r['candidate_inputs']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
registry=read(ROOT/'qa/zhu_wounded_20261005/ordinary_character_default_routes_v7.json')
assert registry['current_default_routes_verified'] and len(registry['resources'])==24
for row in registry['resources']+registry['source_manifests']+registry['production_scripts']:assert sha(ROOT/row['path'])==row['sha256']
assert sha(ROOT/registry['evidence'])==registry['evidence_sha256']
m=read(ROOT/'assets/direction4/ordinary_wu_song_20261007_combat_v7.json')
assert len(m['resources'])==8 and len(m['poses'])==20 and len(m['sources'])==6
for source in m['sources'].values():assert source['import_dimensions_verified'] and sha(ROOT/source['path'])==source['sha256']
g=read(ROOT/'tools/contracts/zhu_wounded_20261005/generation_wu_song_combat_v7.json')
assert sha(ROOT/g['parent_lineage'])==g['parent_sha256']
for row in g['jobs']:
 assert sha(ROOT/row['repository_path'])==row['sha256'] and sha(ROOT/row['request'])==row['request_sha256'] and not row['native_pixel_edits']
 for ref in row['references']:assert sha(ROOT/ref['path'])==ref['sha256']
cleanup=read(ROOT/'qa/zhu_wounded_20261005/failed_action_import_cleanup_v7.json')
assert cleanup['complete'] and cleanup['deleted_files']==7436 and cleanup['deleted_bytes']==1780976820 and cleanup['protected_hash_drift']==cleanup['keeper_match_hash_drift']==0
assert sha(Path(cleanup['full_inventory']))==cleanup['full_inventory_sha256']
assert sha(ROOT/'tools/contracts/zhu_wounded_20261005/cleanup_failed_action_imports_v7.py')==cleanup['producer_sha256']
review=read(ROOT/'qa/zhu_wounded_20261005/ordinary_combat_production_visual_review_v7.json')
for row in review['viewed']:assert sha(ROOT/row['path'])==row['sha256']
docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
allowed=set(docs)|{'.gitattributes','scripts/art_db.gd','scripts/unit.gd','assets/direction4/ordinary_wu_song_20261007_combat_v7.json'}|set(m['resources'])
allowed.update(['assets/characters/wu_song_traits_20261006/actions_nw3_v7.png','assets/characters/wu_song_traits_20261006/actions_nw3_v7.png.import'])
allowed.update(row['path'] for row in review['viewed'])
qa='qa/zhu_wounded_20261005/'
allowed.update(qa+n for n in ['ordinary_chapter_combat_pilot_v7.json','ordinary_chapter_combat_production_v7.json','ordinary_character_default_routes_v7.json','ordinary_combat_production_visual_review_v7.json','wu_combat_native_texture_v7.json','wu_combat_sampling_v7.json','failed_action_import_cleanup_v7.json'])
allowed.update(qa+'harness/'+stem+ext for stem in ['ordinary_chapter_combat_v7','ordinary_chapter_combat_production_v7'] for ext in ['.gd','.py'])
allowed.add(qa+'harness/texture_bootstrap_wu_combat_v7.py')
prefix='tools/contracts/zhu_wounded_20261005/'
allowed.update(prefix+n for n in ['build_wu_combat_frames_v7.py','generation_wu_song_combat_v7.json','cleanup_failed_action_imports_v7.py','record_wu_combat_production_v7.py','record_combat_round_docs_v7.py','review_combat_sync_v7.py','wu_song_actions_nw3_v7_request.json'])
raw=subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8');names=[]
for item in raw.split('\0'):
 if not item:continue
 assert item[:2] in [' M','??'];name=item[3:];assert name in allowed,name;names.append(name)
assert set(names)==allowed,(allowed-set(names),set(names)-allowed)
files=[]
for name in sorted(names):
 p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
 assert not any(part in ['.git','.godot','profiles','build','__pycache__'] for part in Path(name).parts)
 if p.suffix in ['.py','.gd','.json','.md','.import','.tres'] or name=='.gitattributes':
  text=p.read_text(encoding='utf-8');assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',text),name
  if p.suffix=='.py':ast.parse(text,filename=name)
 files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name),'normalization':'Git text filter for docs only' if name in docs else 'native bytes'})
evidence={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(r['bytes'] for r in files),'secret_findings':[],
 'production_checks':367,'captures':48,'private_runtime_patches':0,'covered_default_routes_verified':True,'cleanup_files':7436,'cleanup_bytes':1780976820,
 'scope':'Default ordinary Wu/Lin gait and Wu four-direction combat drawing, verified original actor transitions/HUD and limited duplicate failed-cache cleanup only. Full development audit remains active; no platform release.'}
p=OUT/'combat_sync_review_v7.json';assert not p.exists();p.write_bytes((json.dumps(evidence,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
p=OUT/'combat_sync_whitelist_v7.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(names))+b'\0')
print(json.dumps({'passed':True,'files':len(files),'bytes':evidence['bytes'],'production_checks':367,'private_patches':0,'secret_findings':0,'cleanup_files':7436}))
