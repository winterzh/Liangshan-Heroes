"""Freeze current runtime and render inherited Unit movement with candidate frames."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys, time, uuid
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8'))
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('base',type=Path)
parser.add_argument('--variant',choices=('passing','refined','footclear'),default='passing')
parser.add_argument('--cache-from',type=Path,required=True,help='Verified private QA project containing imported cache; preserved unchanged')
args = parser.parse_args()
base = args.base.resolve()
prior = args.cache_from.resolve()
assert prior.is_dir() and (prior/'.godot/imported').is_dir()
slot=args.variant+'_v4'
mp = ROOT/f'assets/direction4/zhu_wounded_shi_xiu_20261006_walk_{slot}.json'
m = read(mp)
assert len(m['sources']) == 20 and not m['production_qualified']
bootstrap = Path(read(base/f'texture_bootstrap_walk_{slot}_run.json')['run'])
imp = read(bootstrap/'receipt.json')
assert imp['complete'] and imp['lock_released'] and imp['dimensions']['passed']
run = base/('unit_motion_'+slot+'_'+uuid.uuid4().hex[:8])
project = run/'project'
project.mkdir(parents=True)
inputs = []
paths = set(shared.sources())
paths.update(s['path']+'.import' for s in m['sources'].values())
for name in sorted(paths):
    src = ROOT/name
    assert src.is_file()
    dst = project/name
    dst.parent.mkdir(parents=True,exist_ok=True)
    data = src.read_bytes()
    dst.write_bytes(data)
    inputs.append({'path':name,'sha256':hashlib.sha256(data).hexdigest()})
shutil.copytree(prior/'.godot/imported',project/'.godot/imported')
for src in (bootstrap/'project/.godot/imported').iterdir():
    if src.is_file():
        dst = project/'.godot/imported'/src.name
        if not dst.exists(): shutil.copyfile(src,dst)
        else: assert sha(src)==sha(dst), 'Conflicting private cache: '+src.name
native = shared.install_native(project)
harnesses = []
for name in ['unit_motion_v4.gd','unit_candidate_adapter_v4.gd','unit_motion_v4.tscn']:
    src = Path(__file__).with_name(name)
    shutil.copyfile(src,project/name)
    harnesses.append({'path':src.relative_to(ROOT).as_posix(),'sha256':sha(src)})
shutil.copyfile(__file__,run/'unit_motion_v4.py')
(project/'unit_candidate.json').write_text(json.dumps({'character':m['character']}),encoding='utf-8')
profile = shared.create_private_profile(run,base/'profiles')
env = os.environ.copy()
for key in list(env):
    if key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO']: env.pop(key)
for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    p = profile/key.lower(); p.mkdir(); env[key] = str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
engine = shared.resolve_godot(None)
r = {'complete':False,'run':str(run),'inputs':inputs,'harnesses':harnesses,'runner_sha256':sha(Path(__file__)),
     'private_profile':str(profile),'cache_sources':[str(prior),str(bootstrap/'project')],
     'cache_is_not_cold_import':True,'native_dependencies':native,
     'production_qualified':False,'steps':[],
     'scope':'Detached actual Unit fixture with candidate-only resolver; production ArtDB, Battle and campaign qualification excluded.'}
locked = False
try:
    while running_engine() or shared.LOCK.exists(): print('WAIT natural engine idle for actual Unit fixture',flush=True); time.sleep(15)
    with shared.LOCK.open('x',encoding='utf-8') as f: f.write(str(run))
    locked = True
    for label,extra in [('import',['--headless','--editor','--import']),('render',['--resolution','96x96','res://unit_motion_v4.tscn'])]:
        while running_engine(): print('WAIT natural engine idle before '+label,flush=True); time.sleep(15)
        with (run/(label+'.log')).open('wb') as log:
            child = subprocess.Popen([str(engine),'--path',str(project)]+extra,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            print('OWN Unit '+label+' PID '+str(child.pid),flush=True)
            try: child.wait(timeout=600 if label=='import' else 180)
            except subprocess.TimeoutExpired: child.terminate(); child.wait(); raise
        output = (run/(label+'.log')).read_text(encoding='utf-8',errors='replace')
        r['steps'].append({'name':label,'exit_code':child.returncode,'log_sha256':sha(run/(label+'.log'))})
        assert child.returncode==0 and not any(t in output for t in ['SCRIPT ERROR:','ERROR:','Parse Error:']), output[-12000:]
    result = read(project/'unit_result.json')
    assert result['passed'] and len(result['samples'])==80 and len(result['checks'])==44
    for row in inputs: assert sha(ROOT/row['path'])==row['sha256']==sha(project/row['path'])
    for row in harnesses: assert sha(ROOT/row['path'])==row['sha256']
    r.update(complete=True,result=result,input_sha_drift=0,
             captures=[{'path':row['capture'],'sha256':sha(project/row['capture'])} for row in result['samples']])
except BaseException as exc:
    r['failure']={'type':type(exc).__name__,'message':str(exc)}
    raise
finally:
    while running_engine(): print('WAIT natural idle before Unit lease release',flush=True); time.sleep(15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run): shared.LOCK.unlink()
    r['lock_released'] = not shared.LOCK.exists()
    r['complete'] = r['complete'] and r['lock_released']
    (run/'receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if r['complete']: (base/f'unit_motion_{slot}_run.json').write_text(json.dumps({'run':str(run)}))
print(json.dumps({'complete':r['complete'],'run':str(run)}))
