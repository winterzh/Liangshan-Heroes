"""Import new native textures in an isolated minimal project; preserve pixels."""
from pathlib import Path
import argparse,sys,json,subprocess,hashlib,shutil,uuid,os,time
sys.dont_write_bytecode=True
repo=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('base',type=Path)
parser.add_argument('--manifest',type=Path,help='Explicit isolated walk candidate; omitted retains seven-idle mode')
parser.add_argument('--label',choices=('walk_v3','walk_v4','walk_body2_v4','walk_matched_v4','walk_passing_v4','walk_refined_v4','walk_footclear_v4','traits_v4','wu_song_traits_v4','lin_chong_traits_v4','wang_ying_traits_v4','wang_ying_fullidle_v4','wang_ying_contact_pair_v4','wang_ying_walk_passing_v4','shi_qian_contact_pair_v4','shi_qian_walk_passing_v4','shi_qian_walk_footclear_v4'),default='walk_v3')
args=parser.parse_args()
base=args.base.resolve();base.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
while running_engine() or shared.LOCK.exists():
 print('WAIT natural shared-engine idle for native import',flush=True);time.sleep(15)
if shared.LOCK.exists():raise RuntimeError('Shared QA lock occupied; inspect owner')
inputs=[]
manifest_paths=[args.manifest.resolve()] if args.manifest else sorted((repo/'assets/direction4').glob('zhu_wounded_*_20261005_v3.json'))
for manifest_path in manifest_paths:
 manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
 assert manifest['revision'] in ('upright_soldier_v3','character_traits_v4') and not manifest['production_qualified']
 inputs.extend(manifest['sources'].values())
assert inputs and len({row['path'] for row in inputs})==len(inputs)
if not args.manifest:assert len(inputs)==7
run_label='texture_bootstrap_'+args.label if args.manifest else 'texture_bootstrap_v3'
run=base/(run_label+'_'+uuid.uuid4().hex[:8]);project=run/'project';project.mkdir(parents=True)
profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
 p=profile/k.lower();p.mkdir();env[k]=str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="ZhuWoundedSevenV3NativeTextureProbe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
(project/'inputs.json').write_text(json.dumps(inputs))
probe='''extends SceneTree
func _initialize(): call_deferred("_run")
func _run():
 var rows = JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
 var checks = []
 var passed = true
 for row in rows:
  var texture = load("res://" + row.path)
  var ok = texture is Texture2D and texture.get_width() == row.native_size[0] and texture.get_height() == row.native_size[1] and FileAccess.get_sha256("res://" + row.path) == row.sha256
  checks.append({"path":row.path,"width":texture.get_width() if texture is Texture2D else 0,"height":texture.get_height() if texture is Texture2D else 0,"passed":ok})
  passed = passed and ok
 var f = FileAccess.open("res://dimensions.json", FileAccess.WRITE)
 f.store_string(JSON.stringify({"passed":passed,"checks":checks},"  "))
 quit(0 if passed else 1)
'''
(project/'probe.gd').write_text(probe)
engine=shared.resolve_godot(None)
shutil.copyfile(__file__,run/'texture_bootstrap_v3.py')
r={'harness_sha256':sha(Path(__file__)),'scope':'Isolated native texture import and exact runtime dimensions only; no game/platform operations.','run':str(run),'complete':False,'source_files':[],'steps':[],'godot_sha256':sha(engine)}
locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
 locked=True
 for s in inputs:
  for suffix in ['', '.import']:
   relative=s['path']+suffix;src=repo/relative;dst=project/relative;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
   r['source_files'].append({'path':relative,'before_sha256':sha(src)})
 for label,extra in [('import',['--editor','--import','--quit']),('dimensions',['--script','res://probe.gd'])]:
  while running_engine():
   print('WAIT natural shared-engine idle before '+label,flush=True);time.sleep(15)
  with (run/(label+'.log')).open('wb') as log:
   child=subprocess.Popen([str(engine),'--headless','--path',str(project),*extra],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
   try:child.wait(timeout=180)
   except subprocess.TimeoutExpired:child.terminate();child.wait();raise
  log=(run/(label+'.log')).read_text(encoding='utf-8',errors='replace')
  assert child.returncode==0 and not any(t in log for t in ['SCRIPT ERROR:','ERROR:','Parse Error:'])
  r['steps'].append({'case':label,'passed':True})
 dimensions=json.loads((project/'dimensions.json').read_text(encoding="utf-8"));assert dimensions['passed'];r['dimensions']=dimensions
 for row in r['source_files']:
  src=repo/row['path'];dst=project/row['path'];assert sha(src)==row['before_sha256']
  if src.name.endswith('.import'):
   assert 'uid="uid://' in dst.read_text();shutil.copyfile(dst,src)
  else:assert sha(src)==sha(dst)
  row['after_sha256']=sha(src)
 r['complete']=True
except BaseException as exc:
 r['failure']={'type':type(exc).__name__,'message':str(exc)}
 raise
finally:
 while running_engine():
  print('WAIT natural idle before releasing own native-import lease',flush=True);time.sleep(15)
 r['engine_remaining']=running_engine()
 if locked and shared.LOCK.exists() and shared.LOCK.read_text()==str(run) and (not r['engine_remaining'] or (not r['steps'] and r.get('failure',{}).get('message')=='Engine appeared before own import step')):shared.LOCK.unlink()
 r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released']
 (run/'receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 if r['complete']:(base/(run_label+'_run.json')).write_text(json.dumps({'run':str(run)}))
print(json.dumps({'complete':r['complete'],'run':str(run)}))
