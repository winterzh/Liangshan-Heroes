import os,json,stat,time,sys
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
R=Path('D:/AI项目/水浒/开发工程');Q=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261020')
def files(root):
 for dp,dn,fn in os.walk(root,followlinks=False):
  p=Path(dp);dn[:]=[d for d in dn if not (p/d).lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT]
  for f in fn:
   v=p/f;s=v.lstat()
   if not s.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:yield v,s
exclude={'imported','editor','exported','shader_cache','steam_candidates','steam_integration_qa','stabilization_performance'}
rows=[]
for top in sorted((R/'.godot').iterdir()):
 if not top.is_dir() or top.name in exclude or top.is_junction() or top.is_symlink():continue
 for dp,dn,fn in os.walk(top,followlinks=False):
  p=Path(dp);dn[:]=[d for d in dn if not (p/d).lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT]
  if p.name=='imported' and p.parent.name=='.godot':
   data=list(files(p));rows.append({'path':str(p),'files':len(data),'bytes':sum(s.st_size for v,s in data)});dn[:]=[]
result={'scope':str(R/'.godot'),'excluded_top_directories':sorted(exclude),'caches':rows}
(Q/'inventory.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'cache_dirs':len(rows),'files':sum(x['files'] for x in rows),'logical_gib':round(sum(x['bytes'] for x in rows)/2**30,3),'largest':sorted(rows,key=lambda x:x['bytes'],reverse=True)[:12]},ensure_ascii=False,indent=2))
