"""Import new native textures in an isolated minimal project; preserve pixels."""
from pathlib import Path
import sys,json,subprocess,hashlib,shutil,uuid,os,time
sys.dont_write_bytecode=True
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
while running_engine():
 print('WAIT natural shared-engine idle for native import',flush=True);time.sleep(15)
if shared.LOCK.exists():raise RuntimeError('Shared QA lock occupied; inspect owner')
inputs=list(json.loads((repo/'assets/direction4/bound_shi_qian_20261005.json').read_text(encoding='utf-8'))['sources'].values())
run=base/('texture_bootstrap_'+uuid.uuid4().hex[:8]);project=run/'project';project.mkdir(parents=True)
profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
 p=profile/k.lower();p.mkdir();env[k]=str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="ShiQianBoundNativeTextureProbe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
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
r={'scope':'Isolated native texture import and exact runtime dimensions only; no game/platform operations.','run':str(run),'complete':False,'source_files':[],'steps':[],'godot_sha256':sha(engine)}
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
 if r['complete']:(base/'texture_bootstrap_run.json').write_text(json.dumps({'run':str(run)}))
print(json.dumps({'complete':r['complete'],'run':str(run)}))
