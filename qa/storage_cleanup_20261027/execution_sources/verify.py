from pathlib import Path
import concurrent.futures as cf,gzip,hashlib,json,os,subprocess
R=Path(__file__).resolve().parents[2];O=Path(__file__).parent;Q=R/'qa/storage_cleanup_20261027';B=R/'.godot/campaign_progress_recovery_20261026'
def readgz(p):return json.loads(gzip.decompress(p.read_bytes()))
def xp(p):return Path('\\\\?\\'+str(Path(p).absolute()))
def sha(p):
 with xp(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
summary=json.loads((O/'removal_summary.json').read_text(encoding='utf-8-sig'));plan=readgz(Q/'plan.json.gz')
protected=readgz(O/'protected_before.json.gz')
with cf.ThreadPoolExecutor(max_workers=6) as ex:digests=list(ex.map(sha,[R/x['path'] for x in protected]))
assert all(h==row['sha256'] and xp(R/row['path']).stat().st_size==row['bytes'] for row,h in zip(protected,digests))
before=readgz(O/'non_target_metadata_before.json.gz');after={};targets={x['path'] for x in plan}
for folder,dirs,files in os.walk(xp(B),followlinks=False,onerror=lambda e:(_ for _ in ()).throw(e)):
 for name in files:
  p=Path(str(Path(folder)/name).removeprefix('\\\\?\\'));rel=p.relative_to(R).as_posix()
  if rel not in targets:s=xp(p).stat();after[rel]=[s.st_size,s.st_mtime_ns]
assert after==before
deleted=[json.loads(x) for x in gzip.decompress((O/'removed.jsonl.gz').read_bytes()).decode().splitlines()]
assert len(deleted)==summary['removed_files'] and sum(x['bytes'] for x in deleted)==summary['removed_bytes']
assert all(not (R/x['path']).exists() for x in deleted)
assert summary['removed_files']+summary['skipped_files']==len(plan)
keepers=readgz(O/'keepers.json.gz')
with cf.ThreadPoolExecutor(max_workers=6) as ex:kh=list(ex.map(sha,[R/x['path'] for x in keepers]))
assert all(h==x['sha256'] for x,h in zip(keepers,kh))
assert subprocess.check_output(['git','diff','--name-only'],cwd=R)==b''
result={'schema':'shuihu_cleanup_20261027_verification_v1','removed_files':summary['removed_files'],'removed_bytes':summary['removed_bytes'],'skipped_files':summary['skipped_files'],'tracked_protected_files_sha256_unchanged':len(protected),'private_non_target_files_metadata_unchanged':len(before),'retained_cache_files_sha256_verified':len(keepers),'current_b22_cache_preserved':True,'main_cache_preserved':True,'original_QA_evidence_and_profiles_preserved':True,'game_engine_started':False,'full_tests_started':False,'execution_audit_directory':str(O),'protected_manifest_sha256':sha(O/'protected_before.json.gz'),'metadata_manifest_sha256':sha(O/'non_target_metadata_before.json.gz')}
(Q/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
for name in ['removed.jsonl.gz','plan_binding.json','actual_restore_verification.json']:(Q/name).write_bytes((O/name).read_bytes())
print(json.dumps(result,ensure_ascii=False))
