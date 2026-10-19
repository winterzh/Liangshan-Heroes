import json,gzip,hashlib,concurrent.futures,shutil,time,os
from pathlib import Path
Q=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261019')
def sha(p):
 h=hashlib.sha256()
 with open(str(p) if str(p).startswith(chr(92)*2+'?') else (chr(92)*2+'?'+chr(92))+str(Path(p).absolute()),'rb') as f:
  for b in iter(lambda:f.read(2**20),b''):h.update(b)
 return h.hexdigest()
p=json.load(gzip.open(Q/'plan.json.gz','rt',encoding='utf-8'));b=json.load(gzip.open(Q/'protected_before.json.gz','rt',encoding='utf-8'))
def check(x):
 v=Path((chr(92)*2+'?'+chr(92))+x['path'])
 return x['path'] if not v.is_file() or v.stat().st_size!=x['bytes'] or sha(v)!=x['sha256'] else None
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:changed=[x for x in pool.map(check,b) if x]
remaining=[x['path'] for x in p['targets'] if Path(x['path']).exists()]
receipt={'verified_at':time.strftime('%Y-%m-%d %H:%M:%S'),'deleted_files':len(p['targets'])-len(remaining),'logical_bytes':sum(x['bytes'] for x in p['targets'] if not Path(x['path']).exists()),'protected_files':len(b),'protected_changed':changed,'targets_remaining':remaining,'free_before':p['free_before'],'free_after':{x:shutil.disk_usage(x+':/').free for x in ('C','D')}}
receipt['free_delta']={x:receipt['free_after'][x]-receipt['free_before'][x] for x in ('C','D')}
(Q/'verification.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(receipt,ensure_ascii=False,indent=2));assert not changed and not remaining


