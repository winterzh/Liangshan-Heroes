"""Private seven-character idle render; preserve inputs and wait for engine naturally."""
from pathlib import Path
import argparse, sys, json, subprocess, hashlib, shutil, uuid, os, time
from PIL import Image
sys.dont_write_bytecode=True
repo=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('base',type=Path)
parser.add_argument('--manifest',type=Path,help='Explicit individual traits v4 candidate')
parser.add_argument('--bootstrap-label',choices=('traits_v4','wu_song_traits_v4','lin_chong_traits_v4','wang_ying_traits_v4','wang_ying_fullidle_v4','qin_ming_fullidle_v4'),default='traits_v4')
args=parser.parse_args()
base=args.base.resolve()
sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
if not args.manifest and (repo/'qa/zhu_wounded_20261005/user_character_traits_review_v4.json').exists():
    raise RuntimeError('Old seven-soldier preview superseded; use an explicit character-traits manifest.')
label='idle_preview_'+args.bootstrap_label if args.manifest else 'idle_preview_v3'
bootstrap_label='texture_bootstrap_'+args.bootstrap_label if args.manifest else 'texture_bootstrap_v3'
bootstrap=Path(json.loads((base/(bootstrap_label+'_run.json')).read_text())['run'])
import_receipt=json.loads((bootstrap/'receipt.json').read_text(encoding='utf-8'))
assert import_receipt['complete'] and import_receipt['dimensions']['passed'] and import_receipt['lock_released']
manifests=[]
paths=set()
manifest_paths=[args.manifest.resolve()] if args.manifest else sorted((repo/'assets/direction4').glob('zhu_wounded_*_20261005_v3.json'))
for p in manifest_paths:
    manifest=json.loads(p.read_text(encoding='utf-8'))
    assert manifest['states']=={'idle':['idle']} and not manifest['production_qualified']
    manifests.append(manifest)
    paths.add(p.relative_to(repo).as_posix())
    for source in manifest['sources'].values():
        assert source['import_dimensions_verified'] and sha(repo/source['path'])==source['sha256']==sha(bootstrap/'project'/source['path'])
        paths.update([source['path'],source['path']+'.import'])
    paths.update(manifest['resources'])
assert len(manifests)==(1 if args.manifest else 7)
run=base/(label+'_'+uuid.uuid4().hex[:8]);project=run/'project'
shutil.copytree(bootstrap/'project',project)
inputs=[]
for p in sorted(paths):
    src=repo/p;dst=project/p;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    inputs.append({'path':p,'sha256':sha(src)})
gd=Path(__file__).with_suffix('.gd')
if args.manifest:
    m=manifests[0]
    fallback_key='_'.join(m['character'].split('_')[-2:])
    context='ordinary idle candidate' if m['character'].startswith('character_traits_') else 'rescued idle candidate'
    (project/'individual_idle.json').write_text(json.dumps({'character':m['character'],'key':m.get('identity_key',fallback_key),
        'context':m.get('display_context',context)}),encoding='utf-8')
shutil.copyfile(gd,project/'idle_preview_v3.gd')
shutil.copyfile(__file__,run/'idle_preview_v3.py')
profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    p=profile/k.lower();p.mkdir();env[k]=str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
engine=shared.resolve_godot(None)
while running_engine() or shared.LOCK.exists():
    print('WAIT natural shared-engine idle for seven-character preview',flush=True);time.sleep(15)
result={'complete':False,'run':str(run),'inputs':inputs,'harness_sha256':sha(Path(__file__)),
        'draw_script_sha256':sha(gd),'scope':'Isolated real SpriteFrames/Unit render metadata only; not game or continuous gait acceptance.'}
locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
    locked=True
    if running_engine():raise RuntimeError('Engine appeared before own preview')
    with (run/'preview.log').open('wb') as log:
        child=subprocess.Popen([str(engine),'--path',str(project),'--resolution','96x96','--script','res://idle_preview_v3.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        print('OWN seven-idle preview PID '+str(child.pid),flush=True)
        try:child.wait(timeout=180)
        except subprocess.TimeoutExpired:child.terminate();child.wait();raise
    log=(run/'preview.log').read_text(encoding='utf-8',errors='replace')
    assert child.returncode==0 and not any(t in log for t in ['SCRIPT ERROR:','ERROR:','Parse Error:']),log
    preview=json.loads((project/'preview_result.json').read_text(encoding='utf-8'))
    assert preview['passed'] and len(preview['checks'])==(4 if args.manifest else 28) and all(c['directional'] and c['frame_count']==1 for c in preview['checks'])
    with Image.open(project/'idle_matrix_v3.png') as image:
        rgb=image.convert('RGB');visible=[]
        for row in range(1 if args.manifest else 4):
            for column in range(4 if args.manifest else 7):
                x=110+column*(210 if args.manifest else 175);y=270+row*230
                colors=len(set(rgb.crop((x-74,y-215,x+74,y+5)).getdata()))
                visible.append({'row':row,'column':column,'distinct_colors':colors,'passed':colors>128})
    assert all(c['passed'] for c in visible),'Blank/flat candidate render'
    for p in inputs:assert sha(repo/p['path'])==p['sha256']==sha(project/p['path'])
    result.update(complete=True,preview=preview,visible_render_checks=visible,matrix_sha256=sha(project/'idle_matrix_v3.png'),native_input_drift=0)
except BaseException as exc:
    result['failure']={'type':type(exc).__name__,'message':str(exc)};raise
finally:
    while running_engine():
        print('WAIT natural idle before own preview lease release',flush=True);time.sleep(15)
    if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run):shared.LOCK.unlink()
    result['lock_released']=not shared.LOCK.exists()
    result['complete']=result['complete'] and result['lock_released']
    (run/'receipt.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if result['complete']:(base/(label+'_run.json')).write_text(json.dumps({'run':str(run)}))
print(json.dumps({'complete':result['complete'],'run':str(run)}))
