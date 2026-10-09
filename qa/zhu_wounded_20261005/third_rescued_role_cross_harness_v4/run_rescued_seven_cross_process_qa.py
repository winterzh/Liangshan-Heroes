"""Clone a verified original-Battle project; test five real process checkpoints."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time,uuid
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
CASES=('bound','freed','midroute','camp','verifycamp')
ERRORS=re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:).*$')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--from-receipt',type=Path,required=True)
    ap.add_argument('--work-root',type=Path,required=True)
    ap.add_argument('--run',action='store_true')
    args=ap.parse_args()
    receipt_path=args.from_receipt.resolve();prior=read(receipt_path)
    assert prior['complete'] and prior['lock_released'] and not prior['source_changes'] and not prior['private_source_changes']
    assert Path(prior['source_root']).resolve()==ROOT
    old=Path(prior['project']).resolve();assert old.is_dir() and not old.is_relative_to(ROOT)
    engine=shared.resolve_godot(None);assert sha(engine)==prior['godot_sha256']
    helpers=['tools/level3_world_restore_qa.gd','tools/rescued_seven_cross_process_qa.gd','tools/run_rescued_seven_cross_process_qa.py']
    inputs=prior['source_files'];assert all(sha(ROOT/x['path'])==x['sha256']==sha(old/x['path']) for x in inputs)
    base=shared.resolve_profile_root(args.work_root.resolve());assert not base.is_relative_to(ROOT)
    if not args.run:
        print(json.dumps({'preflight':True,'frozen_inputs':len(inputs),'cases':CASES,'engine_busy':running_engine(),'lock_busy':shared.LOCK.exists(),'source_round_unchanged':True}));return 0
    while running_engine() or shared.LOCK.exists():print('WAIT natural engine idle before role continuation allocation',flush=True);time.sleep(15)
    run=base/('rescued_role_cross_v4_'+uuid.uuid4().hex[:8]);run.mkdir(parents=True)
    project=run/'project';project.mkdir()
    r={'complete':False,'run':str(run),'project':str(project),'source_root':str(ROOT),'prior_receipt':str(receipt_path),'prior_receipt_sha256':sha(receipt_path),
       'godot_sha256':sha(engine),'source_files':inputs,'harnesses':[],'steps':[],'process_runs':[],
       'scope':'Original seven RTS actors at bound/freed/mid-route/camp checkpoints across five independent process exits. Contact/attacker positioning and frozen nonparticipants are explicit fixtures; no prisoner teleport or stage/damage injection. Not full chapter/reward-once, normal UI save button, terminal, performance or Android acceptance.',
       'cache_is_not_cold_import':True,'production_qualified':False}
    locked=False;child=None
    try:
        with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
        locked=True
        for x in inputs:
            name=x['path'];assert sha(old/name)==x['sha256']
            dest=project/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(old/name,dest)
        shutil.copytree(old/'.godot',project/'.godot')
        r['native_dependencies']=shared.install_native(project)
        for name in helpers:
            dst=project/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dst)
            r['harnesses'].append({'path':name,'sha256':sha(ROOT/name)})
            frozen=run/'harness'/Path(name).name;frozen.parent.mkdir(exist_ok=True);shutil.copy2(ROOT/name,frozen)
        scene='[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/rescued_seven_cross_process_qa.gd" id="1"]\n[node name="RescuedSevenCrossProcessQA" type="Node"]\nscript = ExtResource("1")\n'
        (project/'tools/rescued_role_process_v4.tscn').write_bytes(scene.encode('utf-8'))
        r['scene_sha256']=sha(project/'tools/rescued_role_process_v4.tscn')
        profile=shared.create_private_profile(run,base/'profiles');r['private_profile']=str(profile)
        env=os.environ.copy()
        for key in list(env):
            if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO']:env.pop(key)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            dest=profile/key.lower();dest.mkdir();env[key]=str(dest)
        env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',LSH_LEVEL3_RESTORE_PROFILE=str(profile),LSH_LEVEL3_RESTORE_SLOT_ROOT='user://rescued_seven_continue/v4')
        for case in ['import','profile_guard']+list(CASES):
            while running_engine():print('WAIT natural engine idle before role '+case,flush=True);time.sleep(15)
            nonce=uuid.uuid4().hex;case_env=env.copy();report=run/(case+'_report.json')
            case_env.update(RESCUED_ROLE_CASE='bound' if case=='profile_guard' else case,RESCUED_ROLE_NONCE=nonce,
                            LSH_LEVEL3_RESTORE_MODE='cross_save' if case in ['bound','profile_guard'] else 'cross_resume',LSH_LEVEL3_RESTORE_REPORT=str(report))
            if case=='profile_guard':case_env['LSH_LEVEL3_RESTORE_PROFILE']=str(profile/'mismatch')
            extra=['--editor','--import','--quit'] if case=='import' else ['res://tools/rescued_role_process_v4.tscn']
            display=['--headless'] if case in ['import','profile_guard'] else ['--audio-driver','Dummy','--resolution','1280x720','--position','30000,30000']
            cmd=[str(engine),'--path',str(project),'--rendering-method','gl_compatibility']+display+extra
            log=run/(case+'.log');started=time.monotonic_ns();last=time.monotonic();stopped=None
            print('RUN role '+case,flush=True)
            with log.open('wb') as f:
                child=subprocess.Popen(cmd,cwd=project,env=case_env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                pid=child.pid
                while child.poll() is None:
                    time.sleep(0.5);output=log.read_text(encoding='utf-8',errors='replace')
                    if ERRORS.search(output):stopped='engine_or_script_error';break
                    if (time.monotonic_ns()-started)/1e9>3600:stopped='own_case_timeout';break
                    if time.monotonic()-last>=25:print('RUNNING role '+case+' '+str(round((time.monotonic_ns()-started)/1e9))+'s',flush=True);last=time.monotonic()
                if stopped and child.poll() is None:child.terminate();child.wait(timeout=15)
            finished=time.monotonic_ns();output=log.read_text(encoding='utf-8',errors='replace')
            step={'case':case,'pid':pid,'process_nonce':nonce,'started_ns':started,'finished_ns':finished,'exit_code':child.returncode,'stopped_for':stopped,'log_sha256':sha(log),'command':cmd,'actual_rendering':case in CASES,'passed':False}
            r['steps'].append(step)
            assert not stopped and not ERRORS.search(output),output[-6000:]
            if case=='profile_guard':assert child.returncode==2 and 'PRIVATE_PROFILE_REQUIRED' in output and not report.exists()
            else:assert child.returncode==0,output[-6000:]
            step['passed']=True
            if case in CASES:
                v=read(report);assert v['passed'] and v['case']==case and v['pid']==pid and v['process_nonce']==nonce and v['engine_time_scale']==1.0
                assert v['checks'] and all(c['passed'] for c in v['checks'])
                r['process_runs'].append(step|{'report_sha256':sha(report),'checks':len(v['checks']),'report':v})
            print('DONE role '+case,flush=True)
        assert [x['case'] for x in r['process_runs']]==list(CASES)
        assert len({x['process_nonce'] for x in r['process_runs']})==5
        assert all(a['finished_ns']<=b['started_ns'] for a,b in zip(r['process_runs'],r['process_runs'][1:]))
        assert all(sha(ROOT/x['path'])==x['sha256']==sha(project/x['path']) for x in inputs)
        assert all(sha(ROOT/x['path'])==x['sha256']==sha(project/x['path']) for x in r['harnesses'])
        r.update(complete=True,input_sha_drift=0,private_input_sha_drift=0,independent_processes=5)
    except BaseException as exc:
        r['failure']={'type':type(exc).__name__,'message':str(exc)}
        raise
    finally:
        if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
        if locked and shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
        r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released']
        dump(run/'receipt.json',r)
        if r['complete']:dump(base/'rescued_role_cross_v4_run.json',{'run':str(run)})
        print(json.dumps({'complete':r['complete'],'run':str(run),'failure':r.get('failure')}),flush=True)
    return 0
if __name__=='__main__':raise SystemExit(main())
