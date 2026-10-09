"""Render Shi Qian traits real four-phase candidate gait clocks, start/stop and native poses."""
from pathlib import Path
import sys,json,subprocess,hashlib,shutil,uuid,os,time,argparse
sys.dont_write_bytecode=True
repo=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('base',type=Path)
args=parser.parse_args();base=args.base.resolve();slot='shi_qian_footclear_v4';full_phases=True
sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
bootstrap=Path(json.loads((base/f'texture_bootstrap_shi_qian_walk_footclear_v4_run.json').read_text())['run'])
receipt=json.loads((bootstrap/'receipt.json').read_text(encoding='utf-8'))
assert receipt['complete'] and receipt['dimensions']['passed'] and receipt['lock_released']
mp=repo/f'assets/direction4/zhu_wounded_shi_qian_20261006_walk_footclear_v4.json'
manifest=json.loads(mp.read_text(encoding='utf-8'))
expected={'idle':['idle'],'walk':['walk_a','passing_a','walk_b','passing_b']} if full_phases else {'idle':['idle'],'walk':['walk_a','idle','walk_b','idle']}
assert manifest['states']==expected and not manifest['production_qualified']
paths=set(manifest['resources'])|{mp.relative_to(repo).as_posix(),'scripts/unit.gd'}
for s in manifest['sources'].values():
    assert s['import_dimensions_verified'] and sha(repo/s['path'])==s['sha256']==sha(bootstrap/'project'/s['path'])
    paths.update([s['path'],s['path']+'.import'])
run=base/(f'walk_preview_{slot}_'+uuid.uuid4().hex[:8]);project=run/'project'
shutil.copytree(bootstrap/'project',project)
inputs=[]
for p in sorted(paths):
    src=repo/p;dst=project/p;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    inputs.append({'path':p,'sha256':sha(src)})
gd=Path(__file__).with_suffix('.gd');shutil.copyfile(gd,project/'walk_preview_v3.gd');shutil.copyfile(__file__,run/'walk_preview_v3.py')
(project/'gait_character.json').write_text(json.dumps({'character':manifest['character'],'phases':manifest['states']['walk'],'full_phase_matrix':full_phases,'display_label':'Shi Qian watchful light-step adult gait candidate'}),encoding='utf-8')
profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    p=profile/k.lower();p.mkdir();env[k]=str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
engine=shared.resolve_godot(None)
while running_engine() or shared.LOCK.exists():print('WAIT natural shared-engine idle for gait preview',flush=True);time.sleep(15)
r={'complete':False,'run':str(run),'inputs':inputs,'harness_sha256':sha(Path(__file__)),'draw_script_sha256':sha(gd),
   'scope':'Isolated SpriteFrames process-clock/start/stop render. Actual Unit/campaign and visual continuous acceptance remain separate.'}
locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
    locked=True
    if running_engine():raise RuntimeError('Engine appeared before own gait preview')
    with (run/'preview.log').open('wb') as log:
        child=subprocess.Popen([str(engine),'--path',str(project),'--resolution','96x96','--script','res://walk_preview_v3.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        print('OWN gait preview PID '+str(child.pid),flush=True)
        try:child.wait(timeout=180)
        except subprocess.TimeoutExpired:child.terminate();child.wait();raise
    log=(run/'preview.log').read_text(encoding='utf-8',errors='replace')
    assert child.returncode==0 and not any(t in log for t in ['SCRIPT ERROR:','ERROR:','Parse Error:']),log
    preview=json.loads((project/'preview_result.json').read_text(encoding='utf-8'))
    assert preview['passed'] and len(preview['captures'])==64 and len(preview['seen'])==20
    for row in inputs:assert sha(repo/row['path'])==row['sha256']==sha(project/row['path'])
    captures=[{'path':row['capture'],'sha256':sha(project/row['capture'])} for row in preview['captures']]
    r.update(complete=True,preview=preview,captures=captures,matrix_sha256=sha(project/'walk_matrix_v3.png'),input_sha_drift=0)
except BaseException as exc:
    r['failure']={'type':type(exc).__name__,'message':str(exc)};raise
finally:
    while running_engine():print('WAIT natural idle before own gait lease release',flush=True);time.sleep(15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
    r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released']
    (run/'receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if r['complete']:(base/f'walk_preview_{slot}_run.json').write_text(json.dumps({'run':str(run)}))
print(json.dumps({'complete':r['complete'],'run':str(run)}))
