from pathlib import Path
import json,gzip,hashlib,concurrent.futures,subprocess,shutil,datetime,sys,zipfile
sys.stdout.reconfigure(encoding='utf-8')
R=Path('D:/AI项目/水浒/开发工程');Q=Path('D:/CodexEvidence/shuihu/storage_cleanup_20261020')
def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(2**20),b''):h.update(b)
 return h.hexdigest()
plan=json.load(gzip.open(Q/'plan.json.gz','rt',encoding='utf-8'))
protected=json.load(gzip.open(Q/'protected_before.json.gz','rt',encoding='utf-8'))
archive=json.loads((Q/'document_archive.json').read_text(encoding='utf-8'))
def check(x):
 p=Path(x['path'])
 return x['path'] if not p.is_file() or p.stat().st_size!=x['bytes'] or sha(p)!=x['sha256'] else None
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:changed=[p for p in pool.map(check,protected) if p]
assert not changed,changed[:10]
assert all(not Path(x['path']).exists() for x in plan['targets'])
deleted=[json.loads(s) for s in (Q/'deleted.jsonl').read_text(encoding='utf-8').splitlines()]
assert deleted==plan['targets']
assert sha(archive['archive_path'])==archive['archive_sha256']
with zipfile.ZipFile(archive['archive_path']) as z:
 for x in archive['files']:assert hashlib.sha256(z.read(x['path'])).hexdigest()==x['sha256']
u=subprocess.check_output(['git','-C',str(R),'ls-files','--others','--exclude-standard','-z']).decode().split('\0')
assert u==plan['untracked_files']
allowed={x['path'] for x in archive['files']}
tracked_changes=subprocess.check_output(['git','-C',str(R),'diff','--name-only']).decode().splitlines()
assert set(tracked_changes)==allowed,tracked_changes
free_after={x:shutil.disk_usage(x+':/').free for x in ['C','D']}
receipt={'complete':True,'verified_at':datetime.datetime.now().astimezone().isoformat(),'deleted_cache_files':len(deleted),'deleted_cache_logical_bytes':sum(x['bytes'] for x in deleted),'retained_private_cache_files':plan['retained_unique_private_files'],'protected_file_count':len(protected),'protected_changed':changed,'untracked_inventory_unchanged':True,'document_before_lines':archive['before_lines'],'document_after_lines':archive['after_lines'],'document_archive_verified':True,'free_before':plan['free_before'],'free_after':free_after,'free_delta':{x:free_after[x]-plan['free_before'][x] for x in ['C','D']},'runtime_files_changed':False,'native_game_tests_run':False,'steam_actions':False}
(Q/'verification.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(receipt,ensure_ascii=False,indent=2))
