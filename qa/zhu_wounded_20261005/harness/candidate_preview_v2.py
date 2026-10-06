"""Private native resource preview; wait naturally for shared engine, no game edits."""
from pathlib import Path
import sys,json,subprocess,hashlib,shutil,uuid,os,time
from PIL import Image
sys.dont_write_bytecode=True
repo=Path(__file__).resolve().parents[3];base=Path(sys.argv[1]).resolve()
sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
bootstrap=Path(json.loads((base/'texture_bootstrap_run.json').read_text())['run'])
receipt=json.loads((bootstrap/'receipt.json').read_text(encoding='utf-8'))
assert receipt['complete'] and receipt['dimensions']['passed']
manifest=json.loads((repo/'assets/direction4/zhu_wounded_shi_qian_20261005.json').read_text(encoding='utf-8'))
for s in manifest['sources'].values():
    assert sha(repo/s['path'])==s['sha256']==sha(bootstrap/'project'/s['path'])
run=base/('candidate_preview_'+uuid.uuid4().hex[:8]);project=run/'project'
shutil.copytree(bootstrap/'project',project)
paths=[s['path'] for s in manifest['sources'].values()]+manifest['resources']
paths += [s['path']+'.import' for s in manifest['sources'].values()]
inputs=[]
for p in paths:
    src=repo/p;dst=project/p;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    inputs.append({'path':p,'sha256':sha(src)})
shutil.copyfile(Path(__file__).with_suffix('.gd'),project/'candidate_preview.gd')
profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    p=profile/k.lower();p.mkdir();env[k]=str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
engine=shared.resolve_godot(None)
while running_engine() or shared.LOCK.exists():
    print('WAIT natural shared-engine idle for candidate preview',flush=True);time.sleep(15)
result={'complete':False,'run':str(run),'inputs':inputs,'scope':'Isolated real SpriteFrames/render metadata only, not production game or campaign acceptance.'}
locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
    locked=True
    if running_engine():raise RuntimeError('Engine appeared before own preview')
    with (run/'preview.log').open('wb') as log:
        child=subprocess.Popen([str(engine),'--path',str(project),'--resolution','96x96','--script','res://candidate_preview.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        print('OWN preview PID '+str(child.pid),flush=True)
        try:child.wait(timeout=180)
        except subprocess.TimeoutExpired:child.terminate();child.wait();raise
    log=(run/'preview.log').read_text(encoding='utf-8',errors='replace')
    assert child.returncode==0 and not any(t in log for t in ['SCRIPT ERROR:','ERROR:','Parse Error:']),log
    r=json.loads((project/'preview_result.json').read_text(encoding='utf-8'));assert r['passed'] and len(r['checks'])==12 and all(c['directional'] for c in r['checks'])
    # Read-only render evidence gate: dimensions/metadata cannot detect white RID draws.
    image=Image.open(project/'pose_matrix.png').convert('RGB');visible=[]
    for row in range(4):
        for col in range(3):
            x=230+col*390;y=275+row*230
            colors=len(set(image.crop((x-145,y-215,x+145,y+5)).getdata()))
            visible.append({'row':row,'column':col,'distinct_colors':colors,'passed':colors>128})
    assert all(c['passed'] for c in visible),'Blank/flat candidate render'
    for row in inputs:assert sha(repo/row['path'])==row['sha256']==sha(project/row['path'])
    result.update(complete=True,preview=r,visible_render_checks=visible,matrix_sha256=sha(project/'pose_matrix.png'),native_input_drift=0)
except BaseException as exc:
    result['failure']={'type':type(exc).__name__,'message':str(exc)};raise
finally:
    while running_engine():
        print('WAIT natural idle before own preview lease release',flush=True);time.sleep(15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
    result['lock_released']=not shared.LOCK.exists()
    (run/'receipt.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if result['complete']:(base/'candidate_preview_run.json').write_text(json.dumps({'run':str(run)}))
print(json.dumps({'complete':result['complete'],'run':str(run)}))
