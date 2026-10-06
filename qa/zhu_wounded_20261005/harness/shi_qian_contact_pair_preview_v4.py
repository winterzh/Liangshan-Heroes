"""Render native idle/opposing-contact comparisons in a frozen private project."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys,time,uuid
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('base',type=Path)
args=parser.parse_args();base=args.base.resolve()
mp=ROOT/'assets/direction4/zhu_wounded_shi_qian_20261006_contact_pair_v4.json';m=read(mp)
assert m['diagnostic_only'] and not m['production_qualified'] and len(m['sources'])==6
assert m['states']=={'idle':['idle'],'walk':['walk_a','walk_b']}
bootstrap=Path(read(base/'texture_bootstrap_shi_qian_contact_pair_v4_run.json')['run'])
imp=read(bootstrap/'receipt.json');assert imp['complete'] and imp['lock_released'] and imp['dimensions']['passed']
paths={mp.relative_to(ROOT).as_posix(),*m['resources']}
for source in m['sources'].values():
    assert source['import_dimensions_verified'] and sha(ROOT/source['path'])==source['sha256']==sha(bootstrap/'project'/source['path'])
    paths.update([source['path'],source['path']+'.import'])
run=base/('shi_qian_contact_pair_preview_v4_'+uuid.uuid4().hex[:8]);project=run/'project'
shutil.copytree(bootstrap/'project',project)
inputs=[]
for name in sorted(paths):
    src=ROOT/name;dst=project/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    inputs.append({'path':name,'sha256':sha(src)})
gd=Path(__file__).with_suffix('.gd');shutil.copyfile(gd,project/gd.name)
shutil.copyfile(__file__,run/Path(__file__).name)
(project/'contact_pair_config.json').write_text(json.dumps({'character':m['character']}),encoding='utf-8')
profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
for name in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
    p=profile/name.lower();p.mkdir();env[name]=str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
engine=shared.resolve_godot(None)
r={'complete':False,'run':str(run),'inputs':inputs,'harness_sha256':sha(Path(__file__)),
    'draw_script_sha256':sha(gd),'diagnostic_only':True,'production_qualified':False,
    'scope':'Static twelve-pose comparison only; no passing, full gait, Unit physics, campaign or platform qualification'}
locked=False
try:
    while running_engine() or shared.LOCK.exists():print('WAIT natural engine idle for static contact comparisons',flush=True);time.sleep(15)
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
    locked=True
    if running_engine():raise RuntimeError('Engine appeared before own static comparison')
    with (run/'preview.log').open('wb') as log:
        child=subprocess.Popen([str(engine),'--path',str(project),'--resolution','96x96','--script','res://'+gd.name],
            env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        print('OWN static contact comparison PID '+str(child.pid),flush=True)
        try:child.wait(timeout=180)
        except subprocess.TimeoutExpired:child.terminate();child.wait();raise
    log=(run/'preview.log').read_text(encoding='utf-8',errors='replace')
    assert child.returncode==0 and not any(t in log for t in ('SCRIPT ERROR:','ERROR:','Parse Error:')),log
    result=read(project/'contact_pair_result.json')
    assert result['passed'] and result['diagnostic_only'] and len(result['checks'])==12
    assert all(c['directional'] and c['frame_count']==(1 if c['state']=='idle' else 2) for c in result['checks'])
    with Image.open(project/'contact_pair_matrix_v4.png') as im:
        assert im.size==(900,860)
        rgb=im.convert('RGB');visible=[]
        for row in range(3):
            for col in range(4):
                x,y=110+col*210,270+row*265
                colors=len(set(rgb.crop((x-74,y-210,x+74,y+5)).getdata()))
                visible.append({'row':row,'column':col,'distinct_colors':colors,'passed':colors>128})
    assert all(c['passed'] for c in visible)
    for item in inputs:assert sha(ROOT/item['path'])==item['sha256']==sha(project/item['path'])
    r.update(complete=True,result=result,visible_checks=visible,input_sha_drift=0,
        matrix_sha256=sha(project/'contact_pair_matrix_v4.png'))
except BaseException as exc:
    r['failure']={'type':type(exc).__name__,'message':str(exc)};raise
finally:
    while running_engine():print('WAIT natural idle for own static comparison lease release',flush=True);time.sleep(15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
    r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released']
    (run/'receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if r['complete']:(base/'shi_qian_contact_pair_preview_v4_run.json').write_text(json.dumps({'run':str(run)}),encoding='utf-8')
print(json.dumps({'complete':r['complete'],'run':str(run)}))
