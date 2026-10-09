"""Actual initial Gao/Daming whole-core barrier capture/prepare/paused mount/final activation. Complete native records retained; no public continue, full-world clock qualification, disk or independent-process claim."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys,time,uuid,re
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def foreign_engine(pid):
 query="@(Get-Process -ErrorAction SilentlyContinue | Where-Object { ($_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*') -and $_.Id -ne "+str(pid)+" } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
 raw=subprocess.check_output(['powershell.exe','-NoProfile','-Command',query],text=True).strip()
 return bool(raw and json.loads(raw))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
old=json.loads((ROOT/'qa/zhu_wounded_20261005/full_scenery_qualified_v23f.json').read_text(encoding='utf-8'))
assert old['complete'] and old['private_runtime_patches']==0
inputs=old['source_files'];changed=[r['path'] for r in inputs if sha(ROOT/r['path'])!=r['sha256']]
assert set(changed)=={'scripts/run_battle_root_state.gd','scripts/run_visual_graph.gd','scripts/run_battle_world_core.gd'},changed
inputs=[dict(r,sha256=sha(ROOT/r['path']),bytes=(ROOT/r['path']).stat().st_size) for r in inputs]
pinned=json.loads((ROOT/'qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json').read_text(encoding='utf-8'))
while running_engine() or shared.LOCK.exists():
 print('WAIT natural shared engine idle; no foreign task controlled',flush=True);time.sleep(15)
base=Path('E:/ChatGPT/qa-world-restore-20261007');base.mkdir(exist_ok=True)
run=base/('campaign_core_v24b_'+uuid.uuid4().hex[:8]);project=run/'project';project.mkdir(parents=True)
engine=Path('E:/ChatGPT/steam_release_20261007/engine_host/Godot.exe');assert sha(engine)==pinned['godot_sha256']
receipt={'complete':False,'run':str(run),'project':str(project),'source_root':str(ROOT),'source_files':inputs,'private_runtime_patches':0,'steps':[],'full_world_qualified':False,'public_campaign_entry_qualified':False,'scope':__doc__}
child=None;locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
 locked=True
 for row in inputs:
  p=project/row['path'];p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/row['path'],p)
 cache_run=Path('E:/ChatGPT/qa-world-restore-20261007/campaign_core_v24a_691c3566')
 cache_receipt=json.loads((cache_run/'receipt.json').read_text(encoding='utf-8'));assert cache_receipt['steps'][0]['case']=='import' and cache_receipt['steps'][0]['exit_code']==0
 shutil.copytree(cache_run/'project/.godot',project/'.godot')
 receipt['cache_source']=str(cache_run);receipt['cache_only_reused']=True;receipt['complete_scenery_qualified']=False
 receipt['native_dependencies']=shared.install_native(project)
 for name in ['campaign_core_v24b.gd','run_campaign_core_v24b.py']:
  src=Path(__file__).with_name(name);shutil.copy2(src,project/name)
  receipt.setdefault('harnesses',[]).append({'path':src.relative_to(ROOT).as_posix(),'sha256':sha(src)})
 profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
 for key in list(env):
  if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO','WORLD_SHADOW_ENABLED']:env.pop(key)
 for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
  p=profile/key.lower();p.mkdir();env[key]=str(p)
 output=run/'result';output.mkdir();env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ART_QA_PROFILE=str(profile),ART_VISUAL='0',ART_QA_OUT=str(output))
 receipt['private_profile']=str(profile)
 for label,extra in [('import',['--headless','--editor','--import','--quit']),('roundtrip',['--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000','--script','res://campaign_core_v24b.gd'])]:
  while running_engine():
   print('WAIT natural shared engine idle before '+label,flush=True);time.sleep(15)
  log=run/(label+'.log');print('RUN '+label+' '+str(run),flush=True)
  with log.open('wb') as f:
   child=subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility']+extra,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
   start=time.monotonic();last=start;reason=None
   while child.poll() is None:
    time.sleep(1)
    if foreign_engine(child.pid):reason='foreign_engine_resumed';break
    if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',log.read_text(encoding='utf-8',errors='replace')):reason='engine_error';break
    if time.monotonic()-start>1800:reason='own_timeout';break
    if time.monotonic()-last>25:print('RUNNING '+label+' '+str(round(time.monotonic()-start))+'s',flush=True);last=time.monotonic()
   if reason and child.poll() is None:child.terminate();child.wait(timeout=15)
  receipt['steps'].append({'case':label,'pid':child.pid,'exit_code':child.returncode,'stop_reason':reason,'log_sha256':sha(log)})
  assert child.returncode==0 and not reason,log.read_text(encoding='utf-8',errors='replace')[-5000:]
 result=json.loads((output/'report.json').read_text(encoding='utf-8'));receipt['result']=result
 assert result['engine_time_scale']==1.0 and result['passed'] and len(result['runtime'])==2 and all(r['whole_capture'] and r['activated'] and r['exact_nonroot_sections'] and r['root_nonclock_exact'] and r['timing_audit']['mission_age_qualified'] and r['timing_audit']['root_clock_qualified'] for r in result['runtime'])
 assert all(sha(ROOT/r['path'])==sha(project/r['path'])==r['sha256'] for r in inputs)
 receipt.update(complete=True,root_input_drift=0,private_input_drift=0)
except BaseException as e:receipt['failure']={'type':type(e).__name__,'message':str(e)};raise
finally:
 if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
 if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
 receipt['lock_released']=not shared.LOCK.exists();receipt['complete']=receipt['complete'] and receipt['lock_released'];dump(run/'receipt.json',receipt)
 dump(base/'campaign_core_v24b_latest.json',{'run':str(run),'complete':receipt['complete']})
 print(json.dumps({'run':str(run),'complete':receipt['complete'],'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
