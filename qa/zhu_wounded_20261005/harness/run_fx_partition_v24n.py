"""Frozen FX/Presentation caller regression; explicit QA harness change, no private runtime patches.
Waits for a specified live prior checkpoint and shared engine to finish naturally.
Each interrupted native phase has immutable evidence and a new private profile.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,os,re,shutil,subprocess,sys,time,uuid
sys.dont_write_bytecode=True
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-root',type=Path,required=True)
parser.add_argument('--source-receipt',type=Path,required=True)
parser.add_argument('--cache-receipt',type=Path,required=True)
parser.add_argument('--harness',type=Path,required=True)
parser.add_argument('--godot',type=Path,required=True)
parser.add_argument('--work-root',type=Path,required=True)
parser.add_argument('--prior-receipt',type=Path,required=True)
parser.add_argument('--prior-pid',type=int,required=True)
parser.add_argument('--deadline-utc',required=True)
args=parser.parse_args();ROOT=args.source_root.resolve();sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):
    with p.open('x',encoding='utf-8') as f:json.dump(v,f,ensure_ascii=False,indent=2);f.write('\n')
def limit():
    if datetime.datetime.now(datetime.timezone.utc)>=datetime.datetime.fromisoformat(args.deadline_utc):raise TimeoutError('authorized_six_am_wrap_deadline')
def process_alive(pid):
    result=subprocess.check_output(['powershell.exe','-NoProfile','-Command',f'$p=Get-CimInstance Win32_Process -Filter "ProcessId={pid}"; if ($p) {{ $p.CommandLine }}'],text=True).strip()
    return bool(result and 'run_original_world_checkpoint_v24l.py' in result)
def foreign(pid):return any(p!=pid for p in running_engine())
baseline=json.loads(args.source_receipt.read_text(encoding='utf-8'));assert baseline['complete'] and baseline['private_runtime_patches']==0
inputs=baseline['source_files'];assert len(inputs)==5039
cache=json.loads(args.cache_receipt.read_text(encoding='utf-8'));assert cache['steps'][0]['case']=='import' and cache['steps'][0]['exit_code']==0
assert sha(args.godot)==json.loads((ROOT/'qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json').read_text())['godot_sha256']
args.work_root.mkdir(parents=True,exist_ok=True);run=args.work_root/('fx_partition_v24n_'+uuid.uuid4().hex[:8]);run.mkdir()
receipt={'complete':False,'scope':__doc__,'source_root':str(ROOT),'source_files':inputs,'private_runtime_patches':0,'harness_sha256':sha(args.harness),'producer_sha256':sha(Path(__file__)),'godot_sha256':sha(args.godot),'steps':[],'reports':{},'prior_receipt':str(args.prior_receipt),'full_world_qualified':False,'public_campaign_continue_qualified':False}
project=run/'project';child=None;locked=False
def integrity(private=False):
    for r in inputs:
        assert sha(ROOT/r['path'])==r['sha256'],r['path']
        if private:assert sha(project/r['path'])==r['sha256'],r['path']
    assert sha(args.harness)==receipt['harness_sha256']
    assert sha(args.godot)==receipt['godot_sha256']
    if private:assert sha(project/'fx_partition_v24n.gd')==receipt['harness_sha256']
try:
    integrity()
    while not args.prior_receipt.exists():
        limit()
        if not process_alive(args.prior_pid):
            time.sleep(2)
            if not args.prior_receipt.exists():raise RuntimeError('prior_checkpoint_handle_missing_without_terminal_receipt')
        print('WAIT existing live whole-world checkpoint; no restart or foreign control',flush=True);time.sleep(15)
    prior=json.loads(args.prior_receipt.read_text(encoding='utf-8'));assert prior['complete'],'prior checkpoint terminal failure needs repair before FX queue'
    receipt['prior_receipt_sha256']=sha(args.prior_receipt)
    limit();integrity();project.mkdir()
    for r in inputs:
        dest=project/r['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/r['path'],dest)
    shutil.copytree(Path(cache['project'])/'.godot',project/'.godot')
    receipt['cache_source']=str(args.cache_receipt);receipt['native_dependencies']=shared.install_native(project)
    shutil.copy2(args.harness,project/'fx_partition_v24n.gd')
    scene=project/'fx_partition_v24n.tscn';scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://fx_partition_v24n.gd" id="1"]\n[node name="CampaignFXPartitionQA" type="Node"]\nscript=ExtResource("1")\n',encoding='utf-8')
    receipt['scene_sha256']=sha(scene);snapshot=run/'fx_partition_snapshot.json'
    for phase in ['import','profile_guard','component','restart']:
        while True:
            limit();integrity(True)
            while running_engine() or shared.LOCK.exists():limit();print('WAIT natural engine idle '+phase,flush=True);time.sleep(15)
            with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
            locked=True
            if running_engine():
                if shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
                locked=False;continue
            attempt=run/(phase+'_'+uuid.uuid4().hex[:8]);attempt.mkdir()
            profile=shared.create_private_profile(attempt,args.work_root/'profiles');env=os.environ.copy()
            for key in list(env):
                if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO','SCREENSHOT_DIR','WORLD_SHADOW_ENABLED']:env.pop(key)
            for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
                folder=profile/key.lower();folder.mkdir();env[key]=str(folder)
            report=attempt/'report.json';log=attempt/'runtime.log'
            env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',CONTENT_UPDATE_NO_AUTO='1',LSH_CAMPAIGN_FX_PARTITION_PROFILE=str(profile),LSH_CAMPAIGN_FX_PARTITION_ENGINE_SHA256=receipt['godot_sha256'],LSH_CAMPAIGN_FX_PARTITION_SNAPSHOT=str(snapshot),LSH_CAMPAIGN_FX_PARTITION_PHASE=phase,LSH_CAMPAIGN_FX_PARTITION_REPORT=str(report))
            if phase=='profile_guard':env['LSH_CAMPAIGN_FX_PARTITION_PROFILE']=str(profile/'mismatch')
            extra=['--headless','--editor','--import','--quit'] if phase=='import' else ['--headless','res://fx_partition_v24n.tscn'] if phase=='profile_guard' else ['--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x720','--position','30000,30000','res://fx_partition_v24n.tscn']
            step={'case':phase,'attempt':str(attempt),'profile':str(profile),'complete':False};reason=None
            print('RUN '+phase+' '+str(attempt),flush=True)
            with log.open('wb') as f:
                child=subprocess.Popen([str(args.godot),'--path',str(project)]+extra,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                start=time.monotonic();last=start
                while child.poll() is None:
                    time.sleep(1)
                    try:limit()
                    except TimeoutError:reason='authorized_six_am_wrap_deadline';break
                    if foreign(child.pid):reason='foreign_engine_resumed';break
                    if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',log.read_text(encoding='utf-8',errors='replace')):reason='engine_error';break
                    if time.monotonic()-start>900:reason='own_timeout';break
                    if time.monotonic()-last>25:print('RUNNING '+phase+' '+str(round(time.monotonic()-start))+'s',flush=True);last=time.monotonic()
                if reason and child.poll() is None:child.terminate();child.wait(timeout=15)
            step.update(pid=child.pid,exit_code=child.returncode,stop_reason=reason,log_sha256=sha(log))
            if reason is None:
                try:
                    assert child.returncode==(2 if phase=='profile_guard' else 0),log.read_text(encoding='utf-8',errors='replace')[-4000:]
                    assert not re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',log.read_text(encoding='utf-8',errors='replace'))
                    if phase=='profile_guard':assert not report.exists() and not snapshot.exists() and 'PRIVATE_PROFILE_REQUIRED' in log.read_text(encoding='utf-8')
                    if phase in ['component','restart']:
                        data=json.loads(report.read_text(encoding='utf-8'));assert data['passed'] and data['pid']==child.pid and data['phase']==phase and data['component_only'] and not data['full_world'] and not data['normal_gameplay'] and all(r['passed'] for r in data['checks'])
                        expected=['exact native callable with wrong flags is rejected','mounted cleanup has actual new owned localization bindings','mounted failed Visual disposal preserves all actual PP bindings','mounted Presentation disposal releases exactly new binding keys'] if phase=='component' else []
                        assert all(any(label in r['label'] for r in data['checks']) for label in expected)
                        receipt['reports'][phase]=data;step['report_sha256']=sha(report)
                    integrity(True);assert sha(scene)==receipt['scene_sha256'];step['complete']=True
                except Exception as e:
                    reason='validation_failed';step['stop_reason']=reason;step['validation_error']={'type':type(e).__name__,'message':str(e)}
            dump(attempt/'receipt.json',step);receipt['steps'].append(step)
            if shared.LOCK.exists() and shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
            locked=False
            if step['complete']:break
            if reason=='foreign_engine_resumed':continue
            raise RuntimeError(reason)
    comp=receipt['reports']['component'];restart=receipt['reports']['restart'];fixture=json.loads(snapshot.read_text(encoding='utf-8'));digest=sha(snapshot)
    assert comp['pid']!=restart['pid'] and fixture['producer_pid']==comp['pid'] and fixture['synthetic_fixture']
    assert all(r['snapshot_sha256']==digest and r['snapshot_producer_pid']==comp['pid'] for r in [comp,restart])
    receipt.update(complete=True,root_input_drift=0,private_input_drift=0,snapshot_sha256=digest,checks=sum(len(r['checks']) for r in [comp,restart]),process_link={'producer_pid':comp['pid'],'consumer_pid':restart['pid']})
except BaseException as e:receipt['failure']={'type':type(e).__name__,'message':str(e)};raise
finally:
    if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists() or shared.LOCK.read_text()!=str(run)
    dump(run/'receipt.json',receipt)
    print(json.dumps({'run':str(run),'complete':receipt['complete'],'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
