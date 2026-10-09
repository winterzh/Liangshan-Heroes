"""All six original official scene regressions, durable per-case native evidence."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time,uuid
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,value):
    with p.open('x',encoding='utf-8') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
def foreign(pid):
    q="@(Get-Process -ErrorAction SilentlyContinue | Where-Object { ($_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'Liangshan*') -and $_.Id -ne "+str(pid)+" } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw=subprocess.check_output(['powershell.exe','-NoProfile','-Command',q],text=True).strip()
    return bool(raw and json.loads(raw))
qualified=json.loads((ROOT/'qa/zhu_wounded_20261005/full_scenery_qualified_v23f.json').read_text(encoding='utf-8'))
assert qualified['complete'] and qualified['root_input_drift']==0 and qualified['private_input_drift']==0
project=Path(qualified['project']);inputs=qualified['source_files']
origin=json.loads((Path(qualified['original_run'])/'receipt.json').read_text(encoding='utf-8'))
extra=Path(__file__).with_name('official_scenery_regression_v23h.gd');extra_dest=project/extra.name
def integrity():
    assert all(sha(ROOT/r['path'])==sha(project/r['path'])==r['sha256'] for r in inputs)
    for row in origin['harnesses']:assert sha(ROOT/row['path'])==sha(project/Path(row['path']).name)==row['sha256']
    for name,m in origin['native_dependencies'].items():
        for row in m['files']:
            relative=Path(row['path']).name if name=='steam_stats_reader' else row['path']
            assert sha(project/'addons'/name/relative)==row['sha256']
    if extra_dest.exists():assert sha(extra)==sha(extra_dest)
integrity()
base=Path('E:/ChatGPT/qa-world-restore-20261007');run=base/('official_scene_checkpoint_v23h_'+uuid.uuid4().hex[:8]);run.mkdir()
engine=Path('E:/ChatGPT/steam_release_20261007/engine_host/Godot.exe')
pinned=json.loads((ROOT/'qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json').read_text(encoding='utf-8'));assert sha(engine)==pinned['godot_sha256']
receipt={'complete':False,'run':str(run),'project':str(project),'source_files':inputs,
    'source_root':str(ROOT),'private_runtime_patches':0,'full_world_qualified':False,
    'case_indices':[0,1,2,3,5,6],'qualified_origin_sha256':sha(ROOT/'qa/zhu_wounded_20261005/full_scenery_qualified_v23f.json'),
    'harness_sha256':sha(extra),'producer_sha256':sha(Path(__file__)),'cases':[],'attempts':[],'scope':__doc__}
child=None;locked=False
try:
    for index in receipt['case_indices']:
        while True:
            integrity()
            while running_engine() or shared.LOCK.exists():
                print('WAIT natural shared engine idle for case '+str(index)+'; completed cases retained',flush=True);time.sleep(15)
            integrity()
            with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
            locked=True
            if not extra_dest.exists():
                with extra_dest.open('xb') as f:f.write(extra.read_bytes())
            assert sha(extra_dest)==receipt['harness_sha256']
            attempt=run/('case_'+str(index)+'_'+uuid.uuid4().hex[:8]);attempt.mkdir()
            profile=shared.create_private_profile(attempt,base/'profiles');env=os.environ.copy()
            for key in list(env):
                if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO','WORLD_SHADOW_ENABLED']:env.pop(key)
            for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
                folder=profile/key.lower();folder.mkdir();env[key]=str(folder)
            output=attempt/'result';output.mkdir()
            env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ART_QA_PROFILE=str(profile),ART_VISUAL='0',ART_QA_OUT=str(output),OFFICIAL_SCENE_INDEX=str(index))
            log=attempt/'runtime.log';reason=None
            with log.open('wb') as f:
                child=subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility','--audio-driver','Dummy',
                    '--resolution','1440x960','--position','30000,30000','--script','res://'+extra.name],env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                print('RUN case '+str(index)+' '+str(attempt),flush=True);start=time.monotonic();last=start
                while child.poll() is None:
                    time.sleep(1)
                    if foreign(child.pid):reason='foreign_engine_resumed';break
                    if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',log.read_text(encoding='utf-8',errors='replace')):reason='engine_error';break
                    if time.monotonic()-start>1800:reason='own_timeout';break
                    if time.monotonic()-last>25:print('RUNNING case '+str(index)+' '+str(round(time.monotonic()-start))+'s',flush=True);last=time.monotonic()
                if reason and child.poll() is None:child.terminate();child.wait(timeout=15)
            result={'complete':False,'case_index':index,'attempt':str(attempt),'profile':str(profile),
                'pid':child.pid,'exit_code':child.returncode,'stop_reason':reason,'log_sha256':sha(log),'runtime_qualified':False}
            if child.returncode==0 and reason is None:
                report=json.loads((output/'report.json').read_text(encoding='utf-8'))
                result['result']=report
                result['complete']=report['passed'] and report['engine_time_scale']==1.0 and len(report['runtime'])==1 and report['runtime'][0]['exact_map_recapture']
                integrity();result.update(root_input_drift=0,private_input_drift=0,runtime_qualified=result['complete'])
            dump(attempt/'receipt.json',result);receipt['attempts'].append({'path':str(attempt),'receipt_sha256':sha(attempt/'receipt.json'),'complete':result['complete'],'stop_reason':reason})
            if shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
            locked=False
            if result['complete']:
                receipt['cases'].append(result);print('QUALIFIED case '+str(index),flush=True);break
            if reason=='foreign_engine_resumed':
                print('INTERRUPTED case '+str(index)+'; exact failed attempt preserved; waiting naturally',flush=True);continue
            raise AssertionError(log.read_text(encoding='utf-8',errors='replace')[-4000:])
    integrity();receipt.update(complete=True,root_input_drift=0,private_input_drift=0)
except BaseException as error:
    receipt['failure']={'type':type(error).__name__,'message':str(error)};raise
finally:
    if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists();receipt['complete']=receipt['complete'] and receipt['lock_released']
    dump(run/'receipt.json',receipt)
    (base/'official_scene_checkpoint_v23h_latest.json').write_text(json.dumps({'run':str(run),'complete':receipt['complete']})+'\n',encoding='utf-8')
    print(json.dumps({'run':str(run),'complete':receipt['complete'],'qualified_cases':len(receipt['cases'])}),flush=True)
