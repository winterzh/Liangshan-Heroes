from pathlib import Path
import concurrent.futures as cf,hashlib,json,os,stat,time
R=Path(__file__).resolve().parents[2];O=Path(__file__).parent;B=R/'.godot/campaign_progress_recovery_20261026';K=B/'20261027_075456_3e4a48ab/project/.godot/imported'
def xp(p):return Path('\\\\?\\'+str(Path(p).absolute()))
def safe(p):
 p=Path(p).absolute();assert p.is_relative_to(R)
 for part in [p,*p.parents]:
  s=xp(part).stat(follow_symlinks=False);assert not s.st_file_attributes&0x400,(part,'reparse')
  if part==R:break
 return p
def sha(p):
 with xp(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def entries(folder):
 if not xp(folder).exists():return []
 safe(folder);out=[]
 for base,dirs,files in os.walk(xp(folder),followlinks=False,onerror=lambda e:(_ for _ in ()).throw(e)):
  for name in dirs+files:safe(Path(str(Path(base)/name).removeprefix('\\\\?\\')))
  out.extend(Path(str(Path(base)/name).removeprefix('\\\\?\\')) for name in files)
 return out
keepers=entries(K);sizes={p.relative_to(K).as_posix():xp(p).stat().st_size for p in keepers}
with cf.ThreadPoolExecutor(max_workers=6) as ex:kh=dict(zip([p.relative_to(K).as_posix() for p in keepers],ex.map(sha,keepers)))
targets=[];summary=[]
for batch in sorted(B.iterdir()):
 if not batch.is_dir() or batch==K.parents[2]:continue
 folder=batch/'project/.godot/imported';fs=entries(folder)
 summary.append({'batch':batch.name,'files':len(fs),'bytes':sum(xp(p).stat().st_size for p in fs)})
 for p in fs:
  s=xp(p).stat();rel=p.relative_to(folder).as_posix()
  if s.st_nlink==1 and rel in sizes and s.st_size==sizes[rel]:targets.append((p,rel,s))
with cf.ThreadPoolExecutor(max_workers=6) as ex:hashes=list(ex.map(sha,[x[0] for x in targets]))
plan=[]
for (p,rel,s),digest in zip(targets,hashes):
 if digest==kh[rel]:plan.append({'path':p.relative_to(R).as_posix(),'bytes':s.st_size,'mtime_ns':s.st_mtime_ns,'sha256':digest,'retained_copy':(K/rel).relative_to(R).as_posix()})
result={'schema':'shuihu_duplicate_import_cache_inventory_v1','retained_cache':K.relative_to(R).as_posix(),'retained_cache_files':len(keepers),'batches':summary,'duplicate_files':len(plan),'duplicate_bytes':sum(x['bytes'] for x in plan),'unique_or_changed_files_preserved':sum(x['files'] for x in summary)-len(plan),'no_deletions_yet':True}
(O/'plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf8');(O/'inventory.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(result,ensure_ascii=False))
