import os,json,stat,time,collections
from pathlib import Path
out=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261019')
roots=[Path('D:/CodexEvidence/shuihu'),Path('D:/AI项目/水浒/开发工程')]
totals=collections.defaultdict(lambda:[0,0]); candidates={}; skips=[]
start=time.time()
for root in roots:
 for dp,dn,fn in os.walk(root,followlinks=False):
  p=Path(dp)
  dn[:]=[d for d in dn if d!='.git' and not (p/d).is_junction() and not (p/d).is_symlink()]
  rel=p.relative_to(root); parts=rel.parts
  key=str(root/(parts[0] if parts else '.'))
  for f in fn:
   v=p/f
   try:
    s=v.lstat()
    if s.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT: skips.append(str(v)); continue
    totals[key][0]+=s.st_size; totals[key][1]+=1
   except OSError: continue
  if p.name.lower() in ('cache','code cache','gpucache','shadercache','grshadercache','dawncache','imported'):
   candidates[str(p)]={'type':p.name,'bytes':0,'files':0}
# aggregate candidate sizes from same bounded roots
for path,info in candidates.items():
 for dp,dn,fn in os.walk(path,followlinks=False):
  p=Path(dp);dn[:]=[d for d in dn if not (p/d).is_junction() and not (p/d).is_symlink()]
  for f in fn:
   try:
    s=(p/f).lstat()
    if not s.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:info['bytes']+=s.st_size;info['files']+=1
   except OSError:pass
result={'elapsed_seconds':time.time()-start,'roots':list(map(str,roots)),'totals':dict(totals),'candidates':candidates,'skips':skips}
(out/'inventory.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'elapsed':result['elapsed_seconds'],'largest':sorted(totals.items(),key=lambda x:x[1][0],reverse=True)[:16],'cache_count':len(candidates),'largest_cache':sorted(candidates.items(),key=lambda x:x[1]['bytes'],reverse=True)[:25]},ensure_ascii=False,indent=2))
