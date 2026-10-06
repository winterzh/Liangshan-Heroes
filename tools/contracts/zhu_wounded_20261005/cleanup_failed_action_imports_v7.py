"""Delete only revalidated duplicate imported files in two explicitly owned failed batches."""
from pathlib import Path
import argparse,hashlib,json,os,stat,subprocess,time
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--keeper-receipt',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--apply',action='store_true')
args=ap.parse_args()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def dump(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
base=ROOT.parent/'qa-ordinary-posture-20261006';base=base.resolve(strict=True)
assert args.out.resolve().is_relative_to(base) and not args.out.exists()
keeper_receipt=args.keeper_receipt.resolve(strict=True);keeper=read(keeper_receipt)
assert keeper['complete'] and keeper['lock_released'] and keeper['covered_default_routes_verified'] and keeper['private_runtime_patches']==0
assert not keeper['source_changes'] and not keeper['private_source_changes'] and keeper['result']['passed'] and keeper['result']['checks']==367
kept_project=Path(keeper['project']).resolve(strict=True);assert kept_project.is_relative_to(base)
kept_imports=(kept_project/'.godot/imported').resolve(strict=True)
failed_names=['ordinary_chapter_actions_v6_5600c55f','ordinary_chapter_actions_v6a_5ea8ab6d']
targets=[]
def safe_path(p,boundary):
 resolved=p.resolve(strict=True);assert resolved.is_relative_to(boundary),str(p)
 current=p.absolute()
 while current!=boundary.parent:
  assert not (current.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT),str(current)
  current=current.parent
 return resolved
safe_path(kept_imports,base)
for name in failed_names:
 run=base/name;receipt=read(run/'receipt.json')
 assert not receipt['complete'] and receipt['lock_released'] and Path(receipt['source_root']).resolve()==ROOT
 imported=run/'project/.godot/imported';safe_path(imported,base)
 targets.append({'run':run,'imported':imported})
def live_guard():
 ps="Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Liangshan' } | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
 raw=subprocess.check_output(['powershell','-NoProfile','-Command',ps],encoding='utf-8').strip()
 rows=json.loads(raw) if raw else [];rows=[rows] if isinstance(rows,dict) else rows
 for row in rows:
  command=str(row.get('CommandLine','')).replace('\\','/').lower()
  assert not any(str(t['run']).replace('\\','/').lower() in command for t in targets),'Target batch currently used by an engine'
 return [{'pid':r['ProcessId'],'uses_target':False} for r in rows]
live_before=live_guard()
protected={}
for target in targets:
 for p in target['run'].rglob('*'):
  if not p.is_file() or p.is_relative_to(target['imported']):continue
  safe_path(p,base);protected[str(p)]=sha(p)
# Source, selected resources, current successful evidence and every keeper cache
# match are protected; main/older successful/platform paths are not deletion targets.
for row in keeper['source_files']+keeper['candidate_inputs']:
 p=ROOT/row['path'];assert sha(p)==row['sha256'];protected[str(p)]=row['sha256']
for p in (kept_project.parent/'evidence').rglob('*'):
 if p.is_file():protected[str(p)]=sha(p)
protected[str(keeper_receipt)]=sha(keeper_receipt)
matches=[];different=[];kept_hashes={};started=time.monotonic()
for target in targets:
 for p in sorted(target['imported'].iterdir()):
  assert p.is_file(),'Unexpected imported subdirectory'
  safe_path(p,target['imported']);other=kept_imports/p.name
  if not other.is_file() or p.stat().st_size!=other.stat().st_size:different.append(str(p));continue
  safe_path(other,kept_imports)
  digest=sha(p);kept_digest=kept_hashes.setdefault(p.name,sha(other))
  if digest!=kept_digest:different.append(str(p));continue
  matches.append({'path':str(p),'keeper':str(other),'bytes':p.stat().st_size,'sha256':digest})
 inventory={'scope':'Only two named failed action QA imported caches; same filename/size/SHA256 as retained current successful production cache. All other paths excluded.',
  'keeper_receipt':str(keeper_receipt),'keeper_receipt_sha256':sha(keeper_receipt),'targets':[str(t['imported']) for t in targets],
  'matches':matches,'different_or_missing_kept':different,'protected_files':len(protected),'matched_bytes':sum(r['bytes'] for r in matches),
  'live_before':live_before,'apply_requested':args.apply,'complete':False,'deleted_files':0,'deleted_bytes':0,'producer_sha256':sha(Path(__file__))}
dump(args.out,inventory)
assert all(sha(Path(path))==digest for path,digest in protected.items())
if args.apply:
 live_guard()
 try:
  for row in matches:
   p=Path(row['path']);target=next(t for t in targets if p.parent==t['imported'])
   safe_path(p,target['imported']);other=Path(row['keeper']);safe_path(other,kept_imports)
   assert p.stat().st_size==other.stat().st_size==row['bytes'] and sha(p)==sha(other)==row['sha256']
   p.unlink() # Exact verified file only; never recurse into/remove a directory.
   inventory['deleted_files']+=1;inventory['deleted_bytes']+=row['bytes']
   if inventory['deleted_files']%1000==0:
    dump(args.out,inventory);live_guard();print('DELETED verified duplicate files '+str(inventory['deleted_files']),flush=True)
 except BaseException as exc:
  inventory['failure']={'type':type(exc).__name__,'message':str(exc)}
  raise
 finally:dump(args.out,inventory)
 assert all(not Path(r['path']).exists() for r in matches)
 assert all(Path(p).is_file() for p in different)
 assert all(sha(Path(path))==digest for path,digest in protected.items())
 assert all(sha(kept_imports/name)==digest for name,digest in kept_hashes.items())
inventory.update(complete=True,protected_hash_drift=0,keeper_match_hash_drift=0,elapsed_seconds=round(time.monotonic()-started,2))
dump(args.out,inventory)
print(json.dumps({k:inventory[k] for k in ['complete','matched_bytes','protected_files','deleted_files','deleted_bytes','protected_hash_drift']},ensure_ascii=False))
