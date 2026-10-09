"""Installed chapter factories and original Level/Mission component reconstruction; full world still open."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time,uuid
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--from-production',type=Path,required=True)
    ap.add_argument('--work-root',type=Path,required=True);ap.add_argument('--run',action='store_true');args=ap.parse_args()
    rp=args.from_production.resolve(strict=True);old=read(rp)
    assert old['complete'] and old['lock_released'] and old['private_runtime_patches']==0
    assert old['root_input_drift']==old['private_input_drift']==0 and old['result']['passed'] and old['result']['checks']==761
    assert Path(old['source_root']).resolve()==ROOT and len(old['result']['screenshots'])==112
    patch=read(ROOT/'qa/zhu_wounded_20261005/campaign_foundation_patch_v18.json')
    endings=read(ROOT/'qa/zhu_wounded_20261005/campaign_profile_line_endings_v18.json')
    original=old['source_files'];changed=[row['path'] for row in original if sha(ROOT/row['path'])!=row['sha256']]
    assert set(changed)=={'scripts/run_official_restore_profile.gd','scripts/levels/level5_gao_rts.gd'},changed
    before={row['path']:row['sha256'] for row in original}
    for delta in patch['source_delta']:
        if delta['before_sha256'] is not None:assert before[delta['path']]==delta['before_sha256']
        expected=endings['after_sha256'] if delta['path']=='scripts/run_official_restore_profile.gd' else delta['after_sha256']
        if delta['path']=='scripts/run_level5_world_factory.gd':expected=read(ROOT/'qa/zhu_wounded_20261005/campaign_gao_factory_fix_v18b.json')['after_sha256']
        assert sha(ROOT/delta['path'])==expected
    inputs=[dict(row,sha256=sha(ROOT/row['path']),bytes=(ROOT/row['path']).stat().st_size) for row in original]
    for name in ['scripts/run_level5_world_factory.gd','scripts/run_level8_world_factory.gd']:
        assert name not in before;inputs.append({'path':name,'sha256':sha(ROOT/name),'bytes':(ROOT/name).stat().st_size})
    changed+=['scripts/run_level5_world_factory.gd','scripts/run_level8_world_factory.gd']
    engine=shared.resolve_godot(None);assert sha(engine)==old['godot_sha256']
    base=shared.resolve_profile_root(args.work_root.resolve());assert not base.is_relative_to(ROOT)
    if not args.run:print(json.dumps({'preflight':True,'inputs':len(inputs),'private_patches':0,'expected_captures':0}));return 0
    while running_engine() or shared.LOCK.exists():print('WAIT natural shared engine idle',flush=True);time.sleep(15)
    run=base/('campaign_foundation_v18b_'+uuid.uuid4().hex[:8]);project=run/'project';project.mkdir(parents=True)
    r={'complete':False,'run':str(run),'project':str(project),'source_root':str(ROOT),'source_files':inputs,'harnesses':[],
        'from_receipt':str(rp),'from_receipt_sha256':sha(rp),'godot_sha256':sha(engine),'private_runtime_patches':0,'production_source_delta':changed,'steps':[],
        'scope':'Original installed Level5/Level8 launch, fixed selection/runtime, original Level and Mission state capture, fresh gated ID-only Unit shells and fixed UI/Level reconstruction. Read-only original map borrowed for geometry. Gao end stage via real original enemy damage is explicit fixture. Not full Unit/world/boat/production/scenery/save/independent continue/natural ending/reward/performance/device qualification.'}
    child=None;locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
        locked=True;dump(base/'campaign_foundation_v18b_running.json',{'run':str(run),'wrapper_pid':os.getpid()})
        for row in inputs:
            p=project/row['path'];p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/row['path'],p)
        shutil.copytree(Path(old['project'])/'.godot',project/'.godot');r['native_dependencies']=shared.install_native(project)
        for name in ['campaign_foundation_v18b.gd','run_campaign_foundation_v18b.py']:
            p=Path(__file__).with_name(name);shutil.copy2(p,project/name)
            dest=run/'harness'/name;dest.parent.mkdir(exist_ok=True);shutil.copy2(p,dest)
            r['harnesses'].append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
        profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
        for key in list(env):
            if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO','WORLD_SHADOW_ENABLED']:env.pop(key)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            p=profile/key.lower();p.mkdir();env[key]=str(p)
        out=run/'skills';out.mkdir();env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ART_QA_PROFILE=str(profile),ART_VISUAL='0',ART_QA_OUT=str(out))
        r['private_profile']=str(profile)
        for label,extra in [('import',['--headless','--editor','--import','--quit']),('skills',['--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000','--script','res://campaign_foundation_v18b.gd'])]:
            while running_engine():print('WAIT natural shared engine idle before '+label,flush=True);time.sleep(15)
            log=run/(label+'.log');print('RUN '+label+' '+str(run),flush=True)
            with log.open('wb') as f:
                child=subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility']+extra,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                started=last=time.monotonic();reason=None
                while child.poll() is None:
                    time.sleep(.5);output=log.read_text(encoding='utf-8',errors='replace')
                    if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',output):reason='fatal_script_or_engine_error';break
                    if time.monotonic()-started>1800:reason='own_case_timeout';break
                    if time.monotonic()-last>=25:print('RUNNING '+label+' '+str(round(time.monotonic()-started))+'s',flush=True);last=time.monotonic()
                if reason and child.poll() is None:child.terminate();child.wait(timeout=15)
            r['steps'].append({'case':label,'pid':child.pid,'exit_code':child.returncode,'stop_reason':reason,'log_sha256':sha(log)})
            assert child.returncode==0 and not reason,log.read_text(encoding='utf-8',errors='replace')[-4500:]
        result=read(out/'report.json');r['result']=result; r['component_qualified']=result['passed'];r['full_world_qualified']=False;r['public_campaign_entry_qualified']=False
        assert result['passed'] and result['engine_time_scale']==1.0 and len(result['screenshots'])==0 and result['checks']>=65
        for row in inputs:assert sha(ROOT/row['path'])==sha(project/row['path'])==row['sha256']
        for row in r['harnesses']:assert sha(ROOT/row['path'])==sha(project/Path(row['path']).name)==row['sha256']
        for row in result['screenshots']:assert sha(Path(row['path']))==row['sha256']
        r.update(complete=True,root_input_drift=0,private_input_drift=0)
    except BaseException as exc:r['failure']={'type':type(exc).__name__,'message':str(exc)};raise
    finally:
        if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
        if locked and shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
        r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released'];dump(run/'receipt.json',r)
        if r['complete']:dump(base/'campaign_foundation_v18b_run.json',{'run':str(run)})
        print(json.dumps({'complete':r['complete'],'run':str(run),'failure':r.get('failure')},ensure_ascii=False),flush=True)
    return 0
if __name__=='__main__':raise SystemExit(main())
