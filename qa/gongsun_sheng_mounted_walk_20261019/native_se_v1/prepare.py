"""Read-only bitmap inspection and exact copies for one-direction animation QA."""
from pathlib import Path
import hashlib,json,shutil
from PIL import Image
Q=Path(__file__).resolve().parent;S=Q.parent;R=Q.parents[2]
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019/prepared_se_v1')
assert not E.exists();(E/'images').mkdir(parents=True)
L=R/'qa/gongsun_sheng_mounted_layers_20261018'
prior=json.loads((L/'layer_bindings_v2.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
phases=['horse_contact_a_se_v3','horse_passing_a_se_v4','horse_contact_b_se_v1','horse_passing_b_se_v1']
sources={k:S/'native_originals'/(k+'.png') for k in phases}
for key in ['horse_no_reins_v2','rider_sheathed_idle_v2','rein_material_v1']:sources[key]=L/'native_originals'/(key+'.png')
textures={}
for key,source in sources.items():
    target=E/'images'/(key+'.png');shutil.copyfile(source,target);assert sha(source)==sha(target)
    im=Image.open(source);assert im.size==(1254,1254) and im.mode=='RGBA'
    region=[96,600,1060,54] if key=='rein_material_v1' else [0,0,627,627]
    x,y,w,h=region
    corners=[im.getpixel(p)[3] for p in [(x,y),(x+w-1,y),(x,y+h-1),(x+w-1,y+h-1)]]
    if key!='rein_material_v1':assert corners==[0,0,0,0],(key,corners)
    textures[key]={'canonical_source':source.relative_to(R).as_posix(),'file':'images/'+target.name,'sha256':sha(source),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'selected_region':region,'selected_corner_alpha':corners,'bytes':source.stat().st_size}
data={'scope':'SE only: four painted horse phases at ONE fixed scale and translation, same sheathed-idle rider fixed across phases, flexible painted rein material. Standalone comparison/process animation only; no actual Unit/chapter/full gait/production acceptance. Other three directions remain unqualified.','phases':phases,'textures':textures,'horse':{'scale':0.97,'offset':[9.61,3.43],'bit_source':[500,268],'manual_anchor_uncertainty_source_pixels':5},'standing_reference':prior['views']['se']['horse'],'rider':prior['views']['se']['phases']['sheathed_idle'],'rein':prior['rein'],'fps':6,'bbox_fitting_per_phase':False,'production_adopted':False,'full_goal_complete':False}
save(E/'inputs.json',data);shutil.copyfile(Q/'preview.gd.txt',E/'preview.gd')
(E/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Gongsun horse SE source comparison"\n[display]\nwindow/size/viewport_width=2560\nwindow/size/viewport_height=1440\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n',encoding='utf-8')
rows=[{'path':p.relative_to(E).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(E.rglob('*')) if p.is_file()]
save(Q/'prepared_binding.json',{'project':str(E),'files':rows,'inputs':data,'native_executed':False})
print(json.dumps({'prepared':True,'files':len(rows),'textures':len(textures)}))
