import datetime,hashlib,json,pathlib,shutil,subprocess,uuid
import numpy as np
from PIL import Image
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path('D:/CodexEvidence/shuihu/ruan_xiaoqi_pushcart_layers_20261018');Q=R/'qa/ruan_xiaoqi_pushcart_layer_sources_20261018';engine=pathlib.Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe');lock=R/'.godot/redraw_rejection_source.lock'
def sha(p):return hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
busy=subprocess.check_output(['powershell','-NoProfile','-Command',"@(Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'Godot*'}).Count"],text=True).strip();assert busy=='0' and not lock.exists(), 'Shared native lane busy; do not remove its lock.'
run=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];P=E/'native_art_preview'/run;P.mkdir(parents=True)
cart=load(R/'assets/direction4/level1_ruan_xiaoqi_pushcart_20261018.json');empty=load(R/'assets/direction4/level1_ruan_xiaoqi_merchant_20261016.json');cfg={'actor':{},'empty':{},'cart':{},'cart_offset':{'se':[.17,.16],'sw':[-.17,.16],'ne':[.15,-.12],'nw':[-.15,-.12]},'scope':'Idle-only raw texture preview; body height calibration is by construction, not proof of artistic volume continuity.'}
sources={'actor':R/'assets/characters/ruan_xiaoqi_pushcart_layer_sources_20261018/idle_actor.png','cart':R/cart['sources']['cart_only']['path'],'empty':R/empty['sources']['idle_spacing']['path']}
for key,p in sources.items():shutil.copyfile(p,P/(key+'.png'));assert sha(p)==sha(P/(key+'.png'))
actor=np.asarray(Image.open(sources['actor']))[:,:,3];empty_alpha=np.asarray(Image.open(sources['empty']))[:,:,3];pivots={'se':[305,604],'sw':[965,604],'ne':[310,1180],'nw':[970,1180]}
for i,d in enumerate(['se','sw','ne','nw']):
 ep=empty['poses']['idle_'+d];x,y,w,h=ep['region'];ys,xs=np.nonzero(empty_alpha[y:y+h,x:x+w]>=64);old_top=int(ys.min())+y;ratio=(ep['pivot_native'][1]-old_top)/ep['virtual_canvas_reference'];ax=i%2*627;ay=i//2*627;ys,xs=np.nonzero(actor[ay:ay+627,ax:ax+627]>=64);new_top=int(ys.min())+ay
 cfg['actor'][d]={'region':[ax,ay,627,627],'pivot':pivots[d],'reference':(pivots[d][1]-new_top)/ratio,'crown_normalized_height':ratio,'manual_ground_pivot_provisional':True}
 cfg['empty'][d]={'region':ep['region'],'pivot':ep['pivot_native'],'reference':ep['virtual_canvas_reference'],'crown_normalized_height':ratio}
 cp=cart['poses']['cart_only_'+d];cfg['cart'][d]={'region':cp['region'],'pivot':cp['pivot_native'],'reference':cp['virtual_canvas_reference']}
save(P/'config.json',cfg);shutil.copyfile(E/'art_preview.gd',P/'preview.gd');(P/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Ruan Xiaoqi art layer preview"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n',encoding='utf-8')
frozen=[{'path':p.name,'sha256':sha(p)} for p in P.iterdir() if p.is_file()];marker=str(P);cmd=[str(engine),'--path',str(P),'--script','res://preview.gd','--rendering-method','gl_compatibility','--audio-driver','Dummy'];rc=None
with lock.open('x',encoding='utf-8') as f:f.write(marker)
try:
 with (P/'native.log').open('wb') as f:rc=subprocess.run(cmd,cwd=P,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
finally:
 if lock.exists() and lock.read_text(encoding='utf-8')==marker:lock.unlink()
assert rc==0,(rc,str(P/'native.log'))
assert all(sha(P/x['path'])==x['sha256'] for x in frozen)
report=load(P/'report.json');assert report['art_preview_complete'] and len(report['screenshots'])==2
receipt={'art_preview_complete':True,'game_native_acceptance':False,'runtime_adopted':False,'scope':report['scope'],'project':str(P),'command':cmd,'godot_sha256':sha(engine),'frozen':frozen,'unchanged':True,'lock_released':not lock.exists(),'screenshots':[{'path':str(P/name),'sha256':sha(P/name),'size':list(Image.open(P/name).size)} for name in report['screenshots']],'report':report,'source_paths':[{'key':key,'path':str(p),'sha256':sha(p)} for key,p in sources.items()]}
save(P/'receipt.json',receipt);save(E/'art_preview_receipt.json',receipt)
print(json.dumps({'art_preview_complete':True,'project':str(P),'screenshots':len(report['screenshots']),'lock_released':receipt['lock_released'],'native_game':False}))
