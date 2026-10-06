"""Render new primitive geometry in a private Godot project; never edit images."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys,time,uuid
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('base',type=Path)
parser.add_argument('--direction',choices=('se','sw','ne','nw'),required=True)
parser.add_argument('--phase',choices=('passing_a','passing_b'),required=True)
args=parser.parse_args();base=args.base.resolve()
run=base/('wang_ying_passing_geometry_'+args.phase+'_'+args.direction+'_v7_'+uuid.uuid4().hex[:8]);project=run/'project'
project.mkdir(parents=True)
gd=Path(__file__).with_name('wang_ying_passing_geometry_v7.gd')
shutil.copyfile(gd,project/gd.name);shutil.copyfile(__file__,run/Path(__file__).name)
config=ROOT/f'tools/contracts/zhu_wounded_20261005/guides/geometry_{args.phase}_{args.direction}_v7.json'
shutil.copyfile(config,project/'geometry_config.json')
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="WangYingGeometryReferenceOnly"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
for name in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
    dest=profile/name.lower();dest.mkdir();env[name]=str(dest)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
engine=shared.resolve_godot(None)
r={'complete':False,'run':str(run),'method':'godot_3d_pose_reference',
   'scope':'New primitive geometry only. No character PNG opened or modified. No game/platform operation.',
   'generator_artifacts':[{'path':gd.relative_to(ROOT).as_posix(),'sha256':sha(gd)},
       {'path':Path(__file__).relative_to(ROOT).as_posix(),'sha256':sha(Path(__file__))},
       {'path':config.relative_to(ROOT).as_posix(),'sha256':sha(config)}],
   'godot_sha256':sha(engine),'private_profile':str(profile),'production_qualified':False}
locked=False
try:
    while running_engine() or shared.LOCK.exists():print('WAIT natural engine idle for geometry reference',flush=True);time.sleep(15)
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
    locked=True
    if running_engine():raise RuntimeError('Engine appeared before own geometry render')
    with (run/'render.log').open('wb') as log:
        child=subprocess.Popen([str(engine),'--path',str(project),'--resolution','96x96','--script','res://'+gd.name],
            env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        print('OWN geometry render PID '+str(child.pid),flush=True)
        try:child.wait(timeout=180)
        except subprocess.TimeoutExpired:child.terminate();child.wait();raise
    log=(run/'render.log').read_text(encoding='utf-8',errors='replace')
    assert child.returncode==0 and not any(t in log for t in ('SCRIPT ERROR:','ERROR:','Parse Error:')),log
    result=json.loads((project/'geometry_result.json').read_text(encoding='utf-8'))
    assert result['passed'] and abs(result['planted_boot_bottom_y'])<1e-6
    expected=json.loads(config.read_text(encoding='utf-8'))['expected_support_image_side']
    assert result['support_on_image_left']==(expected=='left')
    assert abs(result['swing_screen'][0]-result['support_screen'][0])>60
    assert 0.08<result['raised_boot_center'][1]-0.055<0.14
    guide=project/('wang_ying_'+args.phase+'_'+args.direction+'_geometry_v7.png')
    r.update(complete=True,result=result,output_sha256=sha(guide),log_sha256=sha(run/'render.log'))
except BaseException as exc:
    r['failure']={'type':type(exc).__name__,'message':str(exc)};raise
finally:
    while running_engine():print('WAIT natural idle for own geometry lease release',flush=True);time.sleep(15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
    r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released']
    (run/'receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if r['complete']:(base/('wang_ying_passing_geometry_'+args.phase+'_'+args.direction+'_v7_run.json')).write_text(json.dumps({'run':str(run)}),encoding='utf-8')
print(json.dumps({'complete':r['complete'],'run':str(run)}))
