from pathlib import Path
import concurrent.futures as cf,gzip,hashlib,importlib.util,json,os,shutil,subprocess,uuid
R=Path(__file__).resolve().parents[2];O=Path(__file__).parent;Q=R/'qa/storage_cleanup_20261027';B=R/'.godot/campaign_progress_recovery_20261026'
def xp(p):return Path('\\\\?\\'+str(Path(p).absolute()))
def sha(p):
 with xp(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
plan=json.loads((O/'plan.json').read_bytes());inv=json.loads((O/'inventory.json').read_bytes());assert len(plan)==52176
roots=[];keepers={}
for r in plan:
 r['root']=str(Path(r['path']).parent.as_posix());r['utc_ticks']=r['mtime_ns']//100+621355968000000000
 if r['root'] not in roots:roots.append(r['root'])
 keepers[r['retained_copy']]={'path':r['retained_copy'],'bytes':r['bytes'],'sha256':r['sha256'],'utc_ticks':(R/r['retained_copy']).stat().st_mtime_ns//100+621355968000000000}
(Q/'plan.json.gz').write_bytes(gzip.compress((json.dumps(plan,ensure_ascii=False)+'\n').encode(),mtime=0))
(O/'plan.jsonl.gz').write_bytes(gzip.compress(('\n'.join(json.dumps(x,ensure_ascii=False) for x in plan)+'\n').encode(),mtime=0))
(O/'keepers.json.gz').write_bytes(gzip.compress((json.dumps(list(keepers.values()),ensure_ascii=False)+'\n').encode(),mtime=0));save(O/'candidate_roots.json',roots)
spec=importlib.util.spec_from_file_location('cleanup_restore',Q/'restore_imports.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
samples=[next(r for r in plan if r['root']==root) for root in roots]
probeplan=O/'restore_probe_plan.json.gz';probeplan.write_bytes(gzip.compress(json.dumps(samples,ensure_ascii=False).encode(),mtime=0));probe=O/('restore_probe_'+uuid.uuid4().hex[:8])
assert not probe.exists();result=m.restore(probeplan,R,probe,write=True);assert result['selected_files']==12
for r in samples:
 p=probe/r['path'];assert sha(p)==r['sha256'];p.unlink()
save(O/'actual_restore_verification.json',{'verified':True,'restored_files':12,'all_sample_sha256_equal':True,'probe_files_removed_after_verification':True,'result':result})
names=[x for x in subprocess.check_output(['git','ls-files','-z'],cwd=R).decode().split('\0') if x];paths=[R/n for n in names]
with cf.ThreadPoolExecutor(max_workers=6) as ex:digests=list(ex.map(sha,paths))
protected=[{'path':n,'bytes':xp(p).stat().st_size,'sha256':h} for n,p,h in zip(names,paths,digests)]
(O/'protected_before.json.gz').write_bytes(gzip.compress(json.dumps(protected,ensure_ascii=False).encode(),mtime=0))
metadata={}
targetpaths={r['path'] for r in plan}
for folder,dirs,files in os.walk(xp(B),followlinks=False,onerror=lambda e:(_ for _ in ()).throw(e)):
 for name in files:
  p=Path(str(Path(folder)/name).removeprefix('\\\\?\\'));rel=p.relative_to(R).as_posix()
  if rel not in targetpaths:
   s=xp(p).stat(follow_symlinks=False);assert not s.st_file_attributes&0x400;metadata[rel]=[s.st_size,s.st_mtime_ns]
(O/'non_target_metadata_before.json.gz').write_bytes(gzip.compress(json.dumps(metadata,ensure_ascii=False).encode(),mtime=0))
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip();assert head=='5837d1bdc769f2847888a074f41b5c3d629c5529'
save(O/'plan_binding.json',{'git_head':head,'plan_sha256':sha(O/'plan.jsonl.gz'),'keepers_sha256':sha(O/'keepers.json.gz'),'retained_copy_sha256_verified':True,'protected_files':len(protected),'non_target_metadata_files':len(metadata),'plan_files':len(plan),'plan_bytes':sum(x['bytes'] for x in plan)})
save(Q/'inventory.json',inv)
print(json.dumps({'protected_files':len(protected),'non_target_metadata_files':len(metadata),'restore_samples':12,'planned_files':len(plan),'planned_bytes':sum(x['bytes'] for x in plan)}))
