import os,json,hashlib,stat,subprocess,time,shutil,gzip,concurrent.futures
from pathlib import Path
R=Path('D:/AI项目/水浒/开发工程'); E=Path('D:/CodexEvidence/shuihu'); Q=E/'storage_cleanup_20261019'
def sha(p):
 h=hashlib.sha256()
 with open((chr(92)*2+'?'+chr(92))+str(Path(p).absolute()),'rb') as f:
  for b in iter(lambda:f.read(2**20),b''):h.update(b)
 return h.hexdigest()
def safe(p,root):
 p=Path(p).absolute(); root=root.absolute(); assert p.is_relative_to(root) and p!=root
 for a in [p,*p.parents]:
  if a==root.parent:break
  assert not a.is_junction() and not a.is_symlink(),str(a)
 s=p.lstat();assert not s.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT
 assert s.st_nlink==1,str(p)
 return s
def files(root):
 for dp,dn,fn in os.walk(root,followlinks=False):
  p=Path(dp);dn[:]=[d for d in dn if not (p/d).is_junction() and not (p/d).is_symlink()]
  for f in fn:yield p/f
def row(p):return {'path':str(p),'bytes':os.stat((chr(92)*2+'?'+chr(92))+str(p.absolute())).st_size,'sha256':sha(p)}
inv=json.loads((Q/'inventory.json').read_text(encoding='utf-8'));main=R/'.godot/imported'; targets=[]; retained=[]
# Four exact private runs only, keep all Steam/performance/main caches.
allowed=[R/'.godot'/x/'project/.godot/imported' for x in ['chao_gai_full_package/20261018_195328_67efb3d5','liu_tang_pushcart_20261017/20261017_111546_63bf3954','shi_en_packed_hud_20261015/20261015_144300_215e00e5','wu_yong_gait_unit/20261018_220551_307c2379']]
mainhash={p.name:(p.stat().st_size,sha(p)) for p in files(main)}
for d in allowed:
 for p in files(d):
  s=safe(p,R/'.godot');match=mainhash.get(p.name)
  if match and match[0]==s.st_size and sha(p)==match[1]:targets.append({'path':str(p),'bytes':s.st_size,'sha256':match[1],'kind':'identical_import_cache','retained_copy':str(main/p.name)})
  else:retained.append(row(p))
for v,info in inv['candidates'].items():
 p=Path(v)
 if not p.is_relative_to(E) or p.name.lower() not in ('cache','code cache','gpucache','shadercache','grshadercache','dawncache'):continue
 if not any(x.lower().startswith('profile') for x in p.parts):continue
 if any(x in ('Storage','Service Worker','CacheStorage','Shared Dictionary') for x in p.parts):continue
 for f in files(p):
  s=safe(f,E); targets.append({**row(f),'kind':'private_browser_rebuildable_cache'})
assert len({x['path'] for x in targets})==len(targets)
# Protect checkout tracked/untracked files, main cache and all unique private caches.
tracked=subprocess.check_output(['git','-C',str(R),'ls-files','-z']).decode('utf-8').split('\0');others=subprocess.check_output(['git','-C',str(R),'ls-files','--others','--exclude-standard','-z']).decode('utf-8').split('\0')
protected=set(R/p for p in tracked+others if p and (R/p).is_file())
protected.update(files(main));protected.update(Path(v['path']) for v in retained)
# Protect non-cache external artifacts and original logs/videos. Browser user state is left untouched.
for dp,dn,fn in os.walk(E,followlinks=False):
 p=Path(dp);dn[:]=[d for d in dn if not d.lower().startswith('profile') and d not in ('storage_cleanup_20261019','python_deps_1_64_0','.godot','__pycache__','shader_cache') and not (p/d).is_junction() and not (p/d).is_symlink()]
 for f in fn:protected.add(p/f)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:before=list(pool.map(row,sorted(protected)))
with gzip.open(Q/'protected_before.json.gz','wt',encoding='utf-8') as f:json.dump(before,f,ensure_ascii=False)
plan={'created':time.strftime('%Y-%m-%d %H:%M:%S'),'head':subprocess.check_output(['git','-C',str(R),'rev-parse','HEAD']).decode().strip(),'untracked_files':others,'free_before':{x:shutil.disk_usage(x+':/').free for x in ('C','D')},'targets':targets,'retained_unique_private_cache':retained,'protected_count':len(before),'protected_bytes':sum(x['bytes'] for x in before)}
with gzip.open(Q/'plan.json.gz','wt',encoding='utf-8') as f:json.dump(plan,f,ensure_ascii=False)
print(json.dumps({'delete_files':len(targets),'logical_bytes':sum(x['bytes'] for x in targets),'import_bytes':sum(x['bytes'] for x in targets if x['kind']=='identical_import_cache'),'browser_bytes':sum(x['bytes'] for x in targets if x['kind']!='identical_import_cache'),'unique_import_files_retained':len(retained),'protected_count':len(before),'protected_bytes':plan['protected_bytes']},ensure_ascii=False,indent=2))



