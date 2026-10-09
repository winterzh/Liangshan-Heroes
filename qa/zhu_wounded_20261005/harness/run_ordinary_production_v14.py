"""Unmodified production combat/death qualification after reviewed candidate adoption."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time, uuid

sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine

def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--from-pilot',type=Path,required=True)
    ap.add_argument('--visual-review',type=Path,required=True)
    ap.add_argument('--work-root',type=Path,required=True)
    ap.add_argument('--run',action='store_true');args=ap.parse_args()
    rp=args.from_pilot.resolve();pilot=read(rp);old=Path(pilot['project'])
    assert pilot['complete'] and pilot['lock_released'] and pilot['private_patch_verified']
    assert pilot['root_input_drift']==pilot['private_input_drift_except_declared_patch']==0
    assert pilot['result']['passed'] and pilot['candidate_hurt_routes_verified'] and len(pilot['result']['screenshots'])==48
    review_path=args.visual_review.resolve();review=read(review_path)
    assert review['passed'] and review['hurt_qualified']
    assert review['pilot_receipt_sha256']==sha(rp)
    for row in review['viewed']:assert sha(ROOT/row['path'])==row['sha256']
    assert Path(pilot['source_root']).resolve()==ROOT
    before=pilot['source_files'];existing=pilot['candidate_inputs'];new=pilot['new_inputs']
    changed=[row['path'] for row in before if sha(ROOT/row['path'])!=row['sha256']]
    assert changed==['scripts/art_db.gd'],changed
    assert sha(old/'scripts/art_db.gd')==pilot['private_patch']['patched_sha256']
    assert sha(ROOT/'scripts/art_db.gd')==pilot['private_patch']['patched_sha256']
    inputs=[dict(row,sha256=sha(ROOT/row['path'])) for row in before]
    assert all(sha(ROOT/row['path'])==row['sha256']==sha(old/row['path']) for row in inputs+existing+new)
    manifest_path=ROOT/'assets/direction4/ordinary_lin_chong_20261007_hurt_v12.json';manifest=read(manifest_path)
    assert not manifest['production_qualified'] and len(manifest['poses'])==1 and len(manifest['preserved_resources'])==3
    paths=set(manifest['resources'])|{manifest_path.relative_to(ROOT).as_posix()}
    for row in manifest['sources'].values():
        assert row['import_dimensions_verified'] and sha(ROOT/row['path'])==row['sha256'];paths.update([row['path'],row['path']+'.import'])
    for row in manifest['preserved_resources']:assert sha(ROOT/row['original'])==sha(ROOT/row['alias'])==row['sha256']
    previous={row['path'] for row in inputs+existing+new}
    lin_inputs=[{'path':p,'sha256':sha(ROOT/p)} for p in sorted(paths) if p not in previous]
    new=new+lin_inputs
    boot=Path(read(args.work_root/'texture_bootstrap_lin_chong_death_v10_run.json')['run']);assert read(boot/'receipt.json')['complete']
    baseline=pilot['result']['resources'];assert len(baseline)==48
    engine=shared.resolve_godot(None);assert sha(engine)==pilot['godot_sha256']
    base=shared.resolve_profile_root(args.work_root.resolve());assert not base.is_relative_to(ROOT)
    if not args.run:
        print(json.dumps({'preflight':True,'source_inputs':len(inputs),'existing_inputs':len(existing),'new_inputs':len(new),'production_delta':changed,'private_runtime_patches':0}));return 0
    while running_engine() or shared.LOCK.exists():
        print('WAIT natural shared engine idle',flush=True);time.sleep(15)
    run=base/('ordinary_production_v14_'+uuid.uuid4().hex[:8]);project=run/'project';project.mkdir(parents=True)
    receipt={'complete':False,'run':str(run),'project':str(project),'source_root':str(ROOT),
             'source_files':inputs,'candidate_inputs':existing,'new_inputs':new,'harnesses':[],'steps':[],'results':{},
             'pilot_receipt':str(rp),'pilot_receipt_sha256':sha(rp),'visual_review':str(review_path),'visual_review_sha256':sha(review_path),
             'godot_sha256':sha(engine),'private_runtime_patches':0,'production_source_delta':changed,
             'scope':'Current production scripts copied unchanged with Wu death, Lin SW death and standing hurt adopted; no private runtime patch. Original Lin/Zhu and Wu/Daming actual orders, melee/counterhit and separate level1 fatal combat/death/shadow release. Unaffected ordinary and story routes guarded. Contact/freeze/fog/zoom/phase fixtures; not continuous animation, natural full chapter/save/performance/export/platform qualification.'}
    locked=False;child=None
    try:
        with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
        locked=True
        for row in inputs+existing+new:
            dst=project/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/row['path'],dst)
        shutil.copytree(old/'.godot',project/'.godot');receipt['native_dependencies']=shared.install_native(project)
        for src in (boot/'project/.godot/imported').iterdir():
            if not src.is_file():continue
            dst=project/'.godot/imported'/src.name
            if dst.exists():assert sha(dst)==sha(src)
            else:shutil.copy2(src,dst)
        dump(project/'ordinary_predeath_query_baselines.json',baseline)
        receipt['query_baseline_sha256']=sha(project/'ordinary_predeath_query_baselines.json')
        for name in ['ordinary_combat_production_v14.gd','ordinary_death_production_v14.gd','run_ordinary_production_v14.py']:
            src=Path(__file__).with_name(name);shutil.copy2(src,project/name)
            frozen=run/'harness'/name;frozen.parent.mkdir(exist_ok=True);shutil.copy2(src,frozen)
            receipt['harnesses'].append({'path':src.relative_to(ROOT).as_posix(),'sha256':sha(src)})
        profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
        for key in list(env):
            if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO','WORLD_SHADOW_ENABLED']:env.pop(key)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            p=profile/key.lower();p.mkdir();env[key]=str(p)
        out=run/'evidence';out.mkdir();env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ART_QA_PROFILE=str(profile),ART_VISUAL='1',ART_QA_OUT=str(out))
        receipt['private_profile']=str(profile)
        common=['--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000']
        stages=[('import',['--headless','--editor','--import','--quit']),('combat',common+['--script','res://ordinary_combat_production_v14.gd']),('death',common+['--script','res://ordinary_death_production_v14.gd'])]
        for label,extra in stages:
            while running_engine():print('WAIT natural shared engine idle before '+label,flush=True);time.sleep(15)
            out=run/label;out.mkdir();env['ART_QA_OUT']=str(out)
            log=run/(label+'.log');print('RUN '+label+' '+str(run),flush=True)
            with log.open('wb') as f:
                child=subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility']+extra,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                started=last=time.monotonic();reason=None
                while child.poll() is None:
                    time.sleep(.5);output=log.read_text(encoding='utf-8',errors='replace')
                    if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',output):reason='fatal_script_or_engine_error';break
                    if time.monotonic()-started>1200:reason='own_case_timeout';break
                    if time.monotonic()-last>=25:print('RUNNING '+label+' '+str(round(time.monotonic()-started))+'s',flush=True);last=time.monotonic()
                if reason and child.poll() is None:child.terminate();child.wait(timeout=15)
            receipt['steps'].append({'case':label,'pid':child.pid,'exit_code':child.returncode,'stop_reason':reason,'log_sha256':sha(log)})
            assert child.returncode==0 and not reason,log.read_text(encoding='utf-8',errors='replace')[-5500:]
            if label!='import':
                result=read(out/'report.json');assert result['passed'] and result['engine_time_scale']==1.0
                assert len(result['screenshots'])==(48 if label=='combat' else 32)
                receipt['results'][label]=result
        assert set(receipt['results'])=={'combat','death'}
        assert all(sha(ROOT/row['path'])==row['sha256'] for row in inputs+existing+new)
        assert all(sha(project/row['path'])==row['sha256'] for row in inputs+existing+new)
        assert all(sha(ROOT/row['path'])==row['sha256']==sha(project/Path(row['path']).name) for row in receipt['harnesses'])
        assert all(sha(Path(row['path']))==row['sha256'] for result in receipt['results'].values() for row in result['screenshots'])
        receipt.update(complete=True,root_input_drift=0,private_input_drift=0,covered_default_routes_verified=True)
    except BaseException as exc:
        receipt['failure']={'type':type(exc).__name__,'message':str(exc)};raise
    finally:
        if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
        if locked and shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
        receipt['lock_released']=not shared.LOCK.exists();receipt['complete']=receipt['complete'] and receipt['lock_released'];dump(run/'receipt.json',receipt)
        if receipt['complete']:dump(base/'ordinary_production_v14_run.json',{'run':str(run)})
        print(json.dumps({'complete':receipt['complete'],'run':str(run),'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
    return 0

if __name__=='__main__':raise SystemExit(main())
