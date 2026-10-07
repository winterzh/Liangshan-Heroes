"""Exact frozen v24f original whole-core test, same verified source and harness. Fresh native evidence/profile after an actual foreign-engine interruption; no source/harness/private runtime patch or coverage change."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time,uuid
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def dump(path,value):
    with path.open('x',encoding='utf-8') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
def foreign_engine(pid):
    query="@(Get-Process -ErrorAction SilentlyContinue | Where-Object { ($_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*') -and $_.Id -ne "+str(pid)+" } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    data=subprocess.check_output(['powershell.exe','-NoProfile','-Command',query],text=True).strip()
    return bool(data and json.loads(data))

origin=Path('E:/ChatGPT/qa-world-restore-20261007/campaign_core_v24f_c95ec840')
previous=json.loads((origin/'receipt.json').read_text(encoding='utf-8'))
assert not previous['complete'] and previous['lock_released']
assert previous['steps'][0]['case']=='import' and previous['steps'][0]['exit_code']==0 and previous['steps'][0]['stop_reason'] is None
assert previous['steps'][1]['stop_reason']=='foreign_engine_resumed'
assert sha(origin/'import.log')==previous['steps'][0]['log_sha256']
project=Path(previous['project']);inputs=previous['source_files']
def source_integrity():
    assert all(sha(ROOT/r['path'])==sha(project/r['path'])==r['sha256'] for r in inputs)
    for row in previous['harnesses']:
        assert sha(ROOT/row['path'])==sha(project/Path(row['path']).name)==row['sha256']
    for name,manifest in previous['native_dependencies'].items():
        for row in manifest['files']:
            relative=Path(row['path']).name if name=='steam_stats_reader' else row['path']
            assert sha(project/'addons'/name/relative)==row['sha256']
source_integrity()
base=Path('E:/ChatGPT/qa-world-restore-20261007');run=base/('campaign_core_frozen_v24f1_'+uuid.uuid4().hex[:8]);run.mkdir()
engine=Path('E:/ChatGPT/steam_release_20261007/engine_host/Godot.exe')
pinned=json.loads((ROOT/'qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json').read_text(encoding='utf-8'))
assert sha(engine)==pinned['godot_sha256']
receipt={'complete':False,'run':str(run),'project':str(project),'source_root':str(ROOT),'source_files':inputs,
         'private_runtime_patches':0,'frozen_project_reused':True,'original_run':str(origin),
         'previous_import_evidence_sha256':sha(origin/'receipt.json'),'previous_import_log_sha256':sha(origin/'import.log'),
         'harnesses':previous['harnesses'],'producer_sha256':sha(Path(__file__)),
         'full_world_qualified':False,'public_campaign_entry_qualified':False,
         'requires_outer_activation':True,'steps':[],'scope':__doc__}
child=None;locked=False
try:
    profile=shared.create_private_profile(run,base/'profiles');receipt['private_profile']=str(profile)
    env=os.environ.copy()
    for key in list(env):
        if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO','WORLD_SHADOW_ENABLED']:env.pop(key)
    for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
        folder=profile/key.lower();folder.mkdir();env[key]=str(folder)
    output=run/'result';output.mkdir()
    env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ART_QA_PROFILE=str(profile),ART_VISUAL='0',ART_QA_OUT=str(output))
    while running_engine() or shared.LOCK.exists():
        print('WAIT natural shared engine idle; frozen candidate retained, no foreign task controlled',flush=True);time.sleep(15)
    source_integrity()
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
    locked=True
    log=run/'roundtrip.log'
    with log.open('wb') as f:
        child=subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility',
            '--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000',
            '--script','res://campaign_core_v24f.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        started=time.monotonic();last=started;reason=None
        print('RUN full two-case initial world roundtrip '+str(run),flush=True)
        while child.poll() is None:
            time.sleep(1)
            if foreign_engine(child.pid):reason='foreign_engine_resumed';break
            if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',log.read_text(encoding='utf-8',errors='replace')):reason='engine_error';break
            if time.monotonic()-started>1800:reason='own_timeout';break
            if time.monotonic()-last>25:print('RUNNING initial world '+str(round(time.monotonic()-started))+'s',flush=True);last=time.monotonic()
        if reason and child.poll() is None:child.terminate();child.wait(timeout=15)
    receipt['steps'].append({'case':'whole_map_roundtrip','pid':child.pid,'exit_code':child.returncode,'stop_reason':reason,'log_sha256':sha(log)})
    assert child.returncode==0 and not reason,log.read_text(encoding='utf-8',errors='replace')[-3500:]
    result=json.loads((output/'report.json').read_text(encoding='utf-8'));receipt['result']=result
    assert result['passed'] and result['engine_time_scale']==1.0 and len(result['runtime'])==2 and all(r['whole_capture'] and r['activated'] and r['exact_nonroot_sections'] and r['root_nonclock_exact'] and r['timing_audit']['mission_age_qualified'] and r['timing_audit']['root_clock_qualified'] for r in result['runtime'])
    source_integrity();receipt.update(complete=True,root_input_drift=0,private_input_drift=0)
except BaseException as error:
    receipt['failure']={'type':type(error).__name__,'message':str(error)};raise
finally:
    if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists();receipt['complete']=receipt['complete'] and receipt['lock_released']
    dump(run/'receipt.json',receipt)
    pointer=base/'campaign_core_frozen_v24f1_latest.json'
    pointer.write_text(json.dumps({'run':str(run),'complete':receipt['complete']})+'\n',encoding='utf-8')
    print(json.dumps({'run':str(run),'complete':receipt['complete'],'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
