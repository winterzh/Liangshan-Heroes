import argparse,datetime,hashlib,json,pathlib,shutil,subprocess,uuid
from PIL import Image
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path('D:/CodexEvidence/shuihu/ruan_xiaoqi_layer_fixes_20261018');lock=R/'.godot/redraw_rejection_source.lock';engine=pathlib.Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe')
def sha(p):return hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
parser=argparse.ArgumentParser();parser.add_argument('--run-existing',type=pathlib.Path);args=parser.parse_args()
if args.run_existing:
 receipt_path=args.run_existing;r=load(receipt_path);assert r['state']=='prepared';P=pathlib.Path(r['project'])
else:
 m=load(R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json');old=load(R/'assets/direction4/level1_ruan_xiaoqi_merchant_20261016.json');stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];P=E/'native_resource_preview'/stamp;P.mkdir(parents=True)
 textures={v['path']:v for v in m['sources'].values()};empty_resources={d:next(p for p in old['resources'] if p.endswith('_idle_'+d+'.tres')) for d in ['se','sw','ne','nw']};textures[old['sources']['idle_spacing']['path']]=old['sources']['idle_spacing'];files=set(m['resources'])|set(empty_resources.values())|set(textures)
 for p in textures:files.add(p+'.import')
 for name in sorted(files):dest=P/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/name,dest)
 save(P/'manifest.json',m);save(P/'inputs.json',{'textures':{p:{'size':list(Image.open(R/p).size),'source_sha256':sha(R/p)} for p in textures},'empty_resources':empty_resources});shutil.copyfile(E/'resource_preview.gd',P/'preview.gd');(P/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Unrouted Ruan7 imported art resources"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
 frozen=[{'path':f.relative_to(P).as_posix(),'sha256':sha(f)} for f in P.rglob('*') if f.is_file()];r={'state':'prepared','project':str(P),'frozen':frozen,'texture_count':len(textures),'art_resource_preview_complete':False,'native_launched':False,'runtime_adopted':False};receipt_path=P/'receipt.json';save(receipt_path,r);save(E/'prepared_pointer.json',{'receipt':str(receipt_path)})
assert all(sha(P/x['path'])==x['sha256'] for x in r['frozen'])
busy=subprocess.check_output(['powershell','-NoProfile','-Command',"@(Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'Godot*'}).Count"],text=True).strip()
if busy!='0' or lock.exists():
 r['shared_lane_wait']={'live_engine_count':busy,'lock_exists':lock.exists(),'lock_owner':lock.read_text(encoding='utf-8') if lock.exists() else None};save(receipt_path,r);print(json.dumps({'state':'prepared_waiting_for_shared_lane','receipt':str(receipt_path),'native_launched':False}));raise SystemExit(0)
marker=str(P)
with lock.open('x',encoding='utf-8') as f:f.write(marker)
try:
 r.update(state='running',native_launched=True);save(receipt_path,r);r['commands']=[]
 for tag,tail in [('import',['--headless','--editor','--import']),('native',['--script','res://preview.gd','--rendering-method','gl_compatibility'])]:
  cmd=[str(engine),'--path',str(P),'--audio-driver','Dummy',*tail];r['commands'].append(cmd)
  with (P/(tag+'.log')).open('wb') as log:code=subprocess.run(cmd,cwd=P,stdout=log,stderr=subprocess.STDOUT,timeout=180).returncode
  assert code==0,(tag,code,str(P/(tag+'.log')))
 report=load(P/'report.json');assert report['art_resource_preview_complete'] and not report['failures'];r.update(state='complete',art_resource_preview_complete=True,checks=len(report['checks']),screenshots=[{'path':str(P/name),'sha256':sha(P/name)} for name in report['screenshots']]);r['source_drift']=[x['path'] for x in r['frozen'] if sha(P/x['path'])!=x['sha256']];assert not r['source_drift'],r['source_drift']
except Exception as exc:
 r.update(state='failed',error=repr(exc));raise
finally:
 if lock.exists() and lock.read_text(encoding='utf-8')==marker:lock.unlink()
 r['lock_released']=not lock.exists();save(receipt_path,r)
print(json.dumps({'state':r['state'],'receipt':str(receipt_path),'checks':r.get('checks',0),'textures':r['texture_count'],'native_game':False}))
