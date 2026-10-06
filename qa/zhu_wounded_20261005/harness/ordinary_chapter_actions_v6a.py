"""Original Wu/Lin chapter action diagnostic; private ArtDB idle/walk substitution."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time, uuid
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def dump(p, value): p.write_bytes((json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))

def private_art_patch(original):
    """No root write; preserve all explicit story variants and non-idle/walk actions."""
    helper = '''
var ordinary_actions_qa_enabled := true
func _ordinary_actions_qa_frames(key: String, state: String, direction: String, variant: String) -> Array:
\tif not ordinary_actions_qa_enabled or not variant.is_empty() or key not in ["wu_song", "lin_chong"] or state not in ["idle", "walk"] or direction not in CampaignArt.DIRECTIONS: return []
\tvar path := "res://assets/anim/character_traits_v5_%s_gait_%s_%s.tres" % [key,state,direction]
\tvar ck := "ordinary_actions_qa|" + path
\tif not _anim_cache.has(ck): _anim_cache[ck] = _load_generic_directional_frames(path)
\treturn _anim_cache[ck]

'''
    replacements = {
        'func unit_texture(key: String, variant := "", direction := "") -> Texture2D:\n':
        '\tvar ordinary_qa := _ordinary_actions_qa_frames(key,"idle","se" if direction.is_empty() else direction,variant)\n\tif not ordinary_qa.is_empty(): return ordinary_qa[0]\n',
        'func unit_anim_frames(key: String, state: String, direction := "", variant := "") -> Array:\n':
        '\tvar ordinary_qa := _ordinary_actions_qa_frames(key,state,direction,variant)\n\tif not ordinary_qa.is_empty(): return ordinary_qa\n',
        'func unit_anim_uses_directional_source(key: String, state: String, direction: String, variant := "") -> bool:\n':
        '\tif not _ordinary_actions_qa_frames(key,state,direction,variant).is_empty(): return true\n',
    }
    for signature, addition in replacements.items():
        assert original.count(signature) == 1, signature
        original = original.replace(signature, signature+addition)
    return original+helper

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--from-receipt', type=Path, required=True)
    ap.add_argument('--work-root', type=Path, required=True)
    ap.add_argument('--run', action='store_true')
    args = ap.parse_args()
    rp = args.from_receipt.resolve(); prior = read(rp); old = Path(prior['project'])
    assert prior['complete'] and prior['lock_released'] and not prior['source_changes'] and not prior['private_source_changes']
    assert Path(prior['source_root']).resolve() == ROOT and old.is_dir() and not old.resolve().is_relative_to(ROOT)
    inputs = prior['source_files']
    assert all(sha(ROOT/r['path']) == r['sha256'] == sha(old/r['path']) for r in inputs)
    engine = shared.resolve_godot(None); assert sha(engine) == prior['godot_sha256']
    candidate_paths = set(); bootstrap_projects = []
    for key in ['wu_song', 'lin_chong']:
        mp = ROOT/f'assets/direction4/ordinary_{key}_20261006_gait_v5.json'; m = read(mp)
        assert not m['production_qualified'] and len(m['sources']) == 17 and len(m['resources']) == 8
        candidate_paths.add(mp.relative_to(ROOT).as_posix()); candidate_paths.update(m['resources'])
        for source in m['sources'].values():
            assert source['import_dimensions_verified'] and sha(ROOT/source['path']) == source['sha256']
            candidate_paths.update([source['path'], source['path']+'.import'])
        boot = read(args.work_root/f'texture_bootstrap_{key}_gait_v5_run.json')
        assert read(Path(boot['run'])/'receipt.json')['complete']
        bootstrap_projects.append(Path(boot['run'])/'project')
    candidates = [{'path':p, 'sha256':sha(ROOT/p)} for p in sorted(candidate_paths)]
    base = shared.resolve_profile_root(args.work_root.resolve()); assert not base.is_relative_to(ROOT)
    if not args.run:
        print(json.dumps({'preflight':True,'frozen_sources':len(inputs),'candidate_inputs':len(candidates),'root_art_db_unchanged':True})); return 0
    while running_engine() or shared.LOCK.exists():
        print('WAIT natural shared engine idle', flush=True); time.sleep(15)
    run = base/('ordinary_chapter_actions_v6a_'+uuid.uuid4().hex[:8]); project = run/'project'; project.mkdir(parents=True)
    receipt = {'complete':False,'run':str(run),'source_root':str(ROOT),'project':str(project),'source_files':inputs,
        'candidate_inputs':candidates,'prior_receipt':str(rp),'prior_receipt_sha256':sha(rp),'godot_sha256':sha(engine),'harnesses':[], 'steps':[],
        'scope':'Actual original Lin/Zhu and Wu/Daming actors, real Unit orders/state priority/melee damage and original HUD. Contact placement, frozen nonparticipants, fog-off, camera zoom and exact-damage-tick physics freeze are explicit fixtures. Private ArtDB substitutes ordinary idle/walk only. Not default production, full chapter, skills/cast/death playback, continuous gait, save/restore, performance, export or platform qualification.',
        'production_qualified':False,'cache_is_not_cold_import':True}
    locked = False; child = None
    try:
        with shared.LOCK.open('x',encoding='utf-8') as f: f.write(str(run))
        locked = True
        for row in inputs:
            dest = project/row['path']; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(old/row['path'], dest)
        shutil.copytree(old/'.godot', project/'.godot'); receipt['native_dependencies'] = shared.install_native(project)
        for row in candidates:
            dest = project/row['path']; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/row['path'], dest)
        for boot in bootstrap_projects:
            for src in (boot/'.godot/imported').iterdir():
                if not src.is_file(): continue
                dest = project/'.godot/imported'/src.name
                if dest.exists(): assert sha(dest) == sha(src)
                else: shutil.copy2(src, dest)
        patch_path = project/'scripts/art_db.gd'
        patch_path.write_bytes(private_art_patch(patch_path.read_text(encoding='utf-8')).encode('utf-8'))
        receipt['private_patch'] = {'path':'scripts/art_db.gd','original_sha256':sha(ROOT/'scripts/art_db.gd'),'patched_sha256':sha(patch_path),'scope':'QA enabled toggle plus empty-variant Wu/Lin idle/walk lookups only; original root file untouched'}
        for name in ['ordinary_chapter_actions_v6a.gd','ordinary_chapter_actions_v6a.py']:
            src = Path(__file__).with_name(name); shutil.copy2(src, project/name)
            frozen = run/'harness'/name; frozen.parent.mkdir(exist_ok=True); shutil.copy2(src, frozen)
            receipt['harnesses'].append({'path':src.relative_to(ROOT).as_posix(),'sha256':sha(src)})
        profile = shared.create_private_profile(run,base/'profiles'); env = os.environ.copy()
        for key in list(env):
            if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO']: env.pop(key)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            dest = profile/key.lower(); dest.mkdir(); env[key] = str(dest)
        evidence = run/'evidence'; evidence.mkdir()
        env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ART_QA_PROFILE=str(profile),ART_VISUAL='1',ART_QA_OUT=str(evidence))
        receipt['private_profile'] = str(profile)
        for label, extra in [('import',['--headless','--editor','--import','--quit']),('render',['--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000','--script','res://ordinary_chapter_actions_v6a.gd'])]:
            while running_engine(): print('WAIT natural shared engine idle before '+label,flush=True); time.sleep(15)
            log = run/(label+'.log'); print('RUN '+label+' '+str(run),flush=True)
            with log.open('wb') as f:
                child = subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility']+extra,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                started = last = time.monotonic(); reason = None
                while child.poll() is None:
                    time.sleep(0.5); output = log.read_text(encoding='utf-8',errors='replace')
                    if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',output): reason='fatal_script_or_engine_error'; break
                    if time.monotonic()-started > 900: reason='own_case_timeout'; break
                    if time.monotonic()-last >=25: print('RUNNING '+label+' '+str(round(time.monotonic()-started))+'s',flush=True); last=time.monotonic()
                if reason and child.poll() is None: child.terminate(); child.wait(timeout=15)
            receipt['steps'].append({'name':label,'pid':child.pid,'exit_code':child.returncode,'stopped_for':reason,'log_sha256':sha(log)})
            assert child.returncode == 0, log.read_text(encoding='utf-8',errors='replace')[-7000:]
        result = read(evidence/'report.json'); assert result['passed'] and result['engine_time_scale']==1.0 and len(result['screenshots'])==32
        source_drift = [r['path'] for r in inputs if sha(ROOT/r['path']) != r['sha256']]
        private_drift = [r['path'] for r in inputs if r['path']!='scripts/art_db.gd' and sha(project/r['path']) != r['sha256']]
        assert not source_drift and not private_drift and sha(patch_path)==receipt['private_patch']['patched_sha256']
        assert all(sha(ROOT/r['path'])==r['sha256']==sha(project/r['path']) for r in candidates)
        assert all(sha(ROOT/r['path'])==r['sha256']==sha(project/Path(r['path']).name) for r in receipt['harnesses'])
        assert all(sha(Path(s['path']))==s['sha256'] for s in result['screenshots'])
        receipt.update(complete=True,result=result,source_changes=source_drift,private_source_changes=private_drift,candidate_input_drift=0,private_patch_verified=True)
    except BaseException as exc:
        receipt['failure'] = {'type':type(exc).__name__,'message':str(exc)}; raise
    finally:
        if child is not None and child.poll() is None: child.terminate(); child.wait(timeout=15)
        if locked and shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(run): shared.LOCK.unlink()
        receipt['lock_released'] = not shared.LOCK.exists(); receipt['complete'] = receipt['complete'] and receipt['lock_released']
        dump(run/'receipt.json', receipt)
        if receipt['complete']: dump(base/'ordinary_chapter_actions_v6a_run.json',{'run':str(run)})
        print(json.dumps({'complete':receipt['complete'],'run':str(run),'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
    return 0
if __name__=='__main__': raise SystemExit(main())
