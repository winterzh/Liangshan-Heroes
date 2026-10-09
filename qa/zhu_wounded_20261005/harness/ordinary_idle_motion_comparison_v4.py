"""Compare upright ordinary idle candidates against existing walk; no routing edits."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time,uuid
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--key',choices=['wu_song','lin_chong'],required=True)
    ap.add_argument('--from-receipt',type=Path,required=True);ap.add_argument('--work-root',type=Path,required=True);ap.add_argument('--run',action='store_true');args=ap.parse_args()
    rp=args.from_receipt.resolve();prior=read(rp);old=Path(prior['project'])
    assert prior['complete'] and prior['lock_released'] and not prior['source_changes'] and not prior['private_source_changes'] and Path(prior['source_root']).resolve()==ROOT
    assert old.is_dir() and not old.resolve().is_relative_to(ROOT)
    inputs=prior['source_files'];assert all(sha(ROOT/r['path'])==r['sha256']==sha(old/r['path']) for r in inputs)
    engine=shared.resolve_godot(None);assert sha(engine)==prior['godot_sha256']
    mp=ROOT/f'assets/direction4/ordinary_{args.key}_20261006_traits_v4.json';m=read(mp)
    assert not m['production_qualified'] and len(m['resources'])==4 and len(m['sources'])==1
    for s in m['sources'].values():assert sha(ROOT/s['path'])==s['sha256']==sha(old/s['path'])
    base=shared.resolve_profile_root(args.work_root.resolve());assert not base.is_relative_to(ROOT)
    if not args.run:print(json.dumps({'preflight':True,'key':args.key,'frozen_inputs':len(inputs),'source_round_unchanged':True,'production_qualified':False}));return 0
    while running_engine() or shared.LOCK.exists():print('WAIT natural engine idle before ordinary comparison',flush=True);time.sleep(15)
    run=base/('ordinary_idle_motion_'+args.key+'_v4_'+uuid.uuid4().hex[:8]);project=run/'project';project.mkdir(parents=True)
    receipt={'complete':False,'key':args.key,'run':str(run),'inputs':inputs,'harnesses':[],'steps':[],'prior_receipt':str(rp),'prior_receipt_sha256':sha(rp),'godot_sha256':sha(engine),
             'scope':'Detached baseline-versus-candidate ordinary idle/existing-walk transition diagnostic. Real ordinary definitions/skills and inherited Unit physics/draw; no production route, Battle/collision/combat/UI/save/continuous-playback/performance/platform qualification.',
             'production_qualified':False,'cache_is_not_cold_import':True}
    locked=False;child=None
    try:
        with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
        locked=True
        for row in inputs:
            src=old/row['path'];dest=project/row['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
        shutil.copytree(old/'.godot',project/'.godot');receipt['native_dependencies']=shared.install_native(project)
        for name in ['ordinary_idle_comparison_actor_v4.gd','ordinary_idle_motion_comparison_v4.gd','ordinary_idle_motion_comparison_v4.py']:
            src=Path(__file__).with_name(name);dest=project/name;shutil.copy2(src,dest)
            receipt['harnesses'].append({'path':src.relative_to(ROOT).as_posix(),'sha256':sha(src)});frozen=run/'harness'/name;frozen.parent.mkdir(exist_ok=True);shutil.copy2(src,frozen)
        dump(project/'ordinary_idle_comparison.json',{'key':args.key,'family':m['character']})
        scene='[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://ordinary_idle_motion_comparison_v4.gd" id="1"]\n[node name="OrdinaryIdleComparison" type="Node"]\nscript = ExtResource("1")\n'
        (project/'ordinary_idle_motion_comparison_v4.tscn').write_bytes(scene.encode('utf-8'))
        profile=shared.create_private_profile(run,base/'profiles');receipt['private_profile']=str(profile);env=os.environ.copy()
        for key in list(env):
            if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO']:env.pop(key)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            p=profile/key.lower();p.mkdir();env[key]=str(p)
        env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ORDINARY_IDLE_QA_PROFILE=str(profile))
        for label,extra in [('import',['--headless','--editor','--import','--quit']),('render',['--resolution','96x96','res://ordinary_idle_motion_comparison_v4.tscn'])]:
            while running_engine():print('WAIT natural engine idle before ordinary '+label,flush=True);time.sleep(15)
            log=run/(label+'.log');print('RUN ordinary '+args.key+' '+label,flush=True)
            with log.open('wb') as f:
                child=subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility']+extra,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                started=time.monotonic();last=started;stop_reason=None
                while child.poll() is None:
                    time.sleep(0.5);text=log.read_text(encoding='utf-8',errors='replace')
                    if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',text):stop_reason='fatal_script_or_engine_error';break
                    if time.monotonic()-started>900:stop_reason='own_case_timeout';break
                    if time.monotonic()-last>=25:print('RUNNING ordinary '+args.key+' '+label+' '+str(round(time.monotonic()-started))+'s',flush=True);last=time.monotonic()
                if stop_reason and child.poll() is None:child.terminate();child.wait(timeout=15)
            output=log.read_text(encoding='utf-8',errors='replace');receipt['steps'].append({'name':label,'pid':child.pid,'exit_code':child.returncode,'stopped_for':stop_reason,'log_sha256':sha(log)})
            assert child.returncode==0 and not re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',output),output[-6000:]
        result=read(project/'ordinary_idle_motion_result.json');assert result['passed'] and result['key']==args.key and len(result['checks'])==80 and len(result['samples'])==80
        assert all(len(s['units'])==16 for s in result['samples'])
        assert all(sha(ROOT/r['path'])==r['sha256']==sha(project/r['path']) for r in inputs)
        assert all(sha(ROOT/r['path'])==r['sha256']==sha(project/Path(r['path']).name) for r in receipt['harnesses'])
        receipt.update(complete=True,input_sha_drift=0,result=result,captures=[{'path':s['capture'],'sha256':sha(project/s['capture'])} for s in result['samples']])
    except BaseException as exc:
        receipt['failure']={'type':type(exc).__name__,'message':str(exc)};raise
    finally:
        if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
        if locked and shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
        receipt['lock_released']=not shared.LOCK.exists();receipt['complete']=receipt['complete'] and receipt['lock_released'];dump(run/'receipt.json',receipt)
        if receipt['complete']:dump(base/('ordinary_idle_motion_'+args.key+'_v4_run.json'),{'run':str(run)})
        print(json.dumps({'complete':receipt['complete'],'run':str(run),'failure':receipt.get('failure')}),flush=True)
    return 0
if __name__=='__main__':raise SystemExit(main())
