"""Restore named duplicate import caches from the retained b22 cache.

Default verifies keeper bytes only. --restore writes missing files under DEST;
--prefix limits the exact original cache prefix. Existing differing files reject.
"""
from pathlib import Path
import argparse,gzip,hashlib,json,os,shutil

def relative(value):
 if not isinstance(value,str) or not value or any(x in value for x in ('\\',':','\0')):raise ValueError('Invalid relative path')
 p=Path(value)
 if p.is_absolute() or any(x in ('','.','..') or x.endswith((' ','.')) for x in value.split('/')):raise ValueError('Unsafe relative path')
 return p
def safe(p):
 p=Path(p).absolute()
 for q in [p,*p.parents]:
  try:s=q.lstat()
  except FileNotFoundError:continue
  if s.st_file_attributes&0x400:raise ValueError('Reparse path refused')
 return p
def sha(p):
 with safe(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def restore(plan,root,dest,prefix='',write=False):
 root=safe(root);dest=safe(dest);rows=json.loads(gzip.decompress(Path(plan).read_bytes()));checked={};done=[]
 if prefix:relative(prefix.rstrip('/'))
 for r in rows:
  target=relative(r['path']);keeper=relative(r['retained_copy'])
  if prefix and not r['path'].startswith(prefix):continue
  if target.parts[:2]!=('.godot','campaign_progress_recovery_20261026') or target.parts[-3:-1]!=('.godot','imported'):raise ValueError('Only exact flat private import caches allowed')
  if keeper.parts[:3]!=('.godot','campaign_progress_recovery_20261026','20261027_075456_3e4a48ab') or keeper.parts[-3:-1]!=('.godot','imported'):raise ValueError('Keeper outside retained b22 cache')
  source=safe(root/keeper)
  if str(source) not in checked:
   if source.stat().st_size!=r['bytes'] or sha(source)!=r['sha256']:raise ValueError('Keeper changed')
   checked[str(source)]=r['sha256']
  elif checked[str(source)]!=r['sha256']:raise ValueError('Conflicting keeper hash')
  if write:
   out=safe(dest/target);out.parent.mkdir(parents=True,exist_ok=True);safe(out.parent)
   if out.exists():
    if out.stat().st_size!=r['bytes'] or sha(out)!=r['sha256']:raise ValueError('Existing different destination')
   else:
    with source.open('rb') as src,out.open('xb') as dst:shutil.copyfileobj(src,dst,1024*1024)
    if sha(out)!=r['sha256']:raise ValueError('Restored bytes differ')
    os.utime(out,ns=(r['mtime_ns'],r['mtime_ns']))
  done.append(r['path'])
 return {'selected_files':len(done),'unique_keepers_verified':len(checked),'restored':write}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('plan');p.add_argument('root');p.add_argument('destination');p.add_argument('--prefix',default='');p.add_argument('--restore',action='store_true');a=p.parse_args();print(json.dumps(restore(a.plan,a.root,a.destination,a.prefix,a.restore)))
