import os,stat,json,gzip,hashlib,subprocess,shutil,sys,concurrent.futures,time
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
R=Path('D:/AI项目/水浒/开发工程');Q=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261020')
def files(root):
 for dp,dn,fn in os.walk(root,followlinks=False):
  p=Path(dp);dn[:]=[d for d in dn if not (p/d).lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT]
  for f in fn:
   v=p/f
   if not v.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:yield v

def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(2**20),b''):h.update(b)
 return h.hexdigest()
def row(p):
 s=p.lstat()
 return {'path':str(p),'bytes':s.st_size,'sha256':sha(p)}
def safe(p,root):
 assert p.absolute()==p and p.is_relative_to(root) and p!=root,str(p)
 for a in [p,*p.parents]:
  assert not a.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT,str(a)
 s=p.lstat();assert stat.S_ISREG(s.st_mode) and s.st_nlink==1,str(p)
 return s
inv=json.loads((Q/'inventory.json').read_text(encoding='utf-8'))
main=R/'.godot/imported';private=[p for x in inv['caches'] for p in files(Path(x['path']))]
mainfiles=list(files(main))
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 mainrows=list(pool.map(row,mainfiles));privaterows=list(pool.map(row,sorted(private)))
keepers={}
for x in mainrows:keepers.setdefault((x['bytes'],x['sha256']),x['path'])
targets=[];unique=[]
for x in privaterows:
 safe(Path(x['path']),R/'.godot');key=(x['bytes'],x['sha256'])
 if key in keepers:targets.append({**x,'retained_copy':keepers[key],'kind':'byte_identical_import_cache'})
 else:keepers[key]=x['path'];unique.append(x)
planned={x['path'] for x in targets}
assert not any(x['retained_copy'] in planned for x in targets)
untracked=subprocess.check_output(['git','-C',str(R),'ls-files','--others','--exclude-standard','-z']).decode('utf-8').split('\0')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:untrackedrows=list(pool.map(row,[R/p for p in untracked if p and (R/p).is_file()]))
protected=mainrows+unique+untrackedrows
with gzip.open(Q/'protected_before.json.gz','wt',encoding='utf-8') as f:json.dump(protected,f,ensure_ascii=False)
plan={'head':subprocess.check_output(['git','-C',str(R),'rev-parse','HEAD']).decode().strip(),'scope':str(R/'.godot'),'allowed_cache_roots':[x['path'] for x in inv['caches']],'targets':targets,'retained_unique_private_files':len(unique),'protected_count':len(protected),'untracked_files':untracked,'free_before':{v:shutil.disk_usage(v+':/').free for v in ['C','D']}}
with gzip.open(Q/'plan.json.gz','wt',encoding='utf-8') as f:json.dump(plan,f,ensure_ascii=False)
print(json.dumps({'target_count':len(targets),'target_bytes':sum(x['bytes'] for x in targets),'unique_private_retained':len(unique),'protected_count':len(protected)},ensure_ascii=False,indent=2))
