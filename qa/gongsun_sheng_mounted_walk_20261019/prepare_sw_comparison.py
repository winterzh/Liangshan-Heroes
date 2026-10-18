"""Prepare four SW source poses for diagnosis, not a gait qualification."""
from pathlib import Path
import hashlib,json,shutil
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1];N=Q/'native_sw_v1';N.mkdir()
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_walk_20261019/prepared_sw_v1');(E/'images').mkdir(parents=True)
L=R/'qa/gongsun_sheng_mounted_layers_20261018';old=json.loads((L/'layer_bindings_v2.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
phases=['horse_contact_a_sw_v1','horse_passing_a_sw_v3','horse_contact_b_sw_v1','horse_passing_b_sw_v1']
sources={k:Q/'native_originals'/(k+'.png') for k in phases}
for key in ['horse_no_reins_v2','rider_sheathed_idle_v2','rein_material_v1']:sources[key]=L/'native_originals'/(key+'.png')
textures={}
for key,source in sources.items():
    target=E/'images'/(key+'.png');shutil.copyfile(source,target);assert sha(source)==sha(target)
    im=Image.open(source);assert im.size==(1254,1254) and im.mode=='RGBA'
    region=[96,600,1060,54] if key=='rein_material_v1' else [627,0,627,627]
    x,y,w,h=region;corners=[im.getpixel(p)[3] for p in [(x,y),(x+w-1,y),(x,y+h-1),(x+w-1,y+h-1)]]
    if key!='rein_material_v1':assert corners==[0,0,0,0],(key,corners)
    textures[key]={'canonical_source':source.relative_to(R).as_posix(),'file':'images/'+target.name,'sha256':sha(source),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'selected_region':region,'selected_corner_alpha':corners,'bytes':source.stat().st_size}
view=old['views']['sw'];horse=dict(view['horse']);horse['bit_source']=[755,268]
data={'scope':'SW only, four source-pose comparison candidates. Passing A/B anatomy, hoof clearance, limb-root depth and trajectory are unresolved, not qualified gait. Fixed horse/rider scale and position, same sheathed rider, painted flexible reins; no Unit/chapter/production acceptance.','phases':phases,'origin':[627,0],'textures':textures,'horse':horse,'rider':view['phases']['sheathed_idle'],'rein':old['rein'],'fps':6,'bbox_fitting_per_phase':False,'anatomical_cycle_accepted':False,'production_adopted':False,'full_goal_complete':False}
(E/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
driver=(Q/'native_se_v2/preview.gd.txt').read_text()
assert driver.count('source.position*sc+vec(offset)')==1
driver=driver.replace('source.position*sc+vec(offset)','source.position*sc+vec(offset)-vec(data.origin)')
driver=driver.replace('vec(data.horse.offset);var b:','vec(data.horse.offset)-vec(data.origin);var b:').replace('vec(data.rider.offset)\n','vec(data.rider.offset)-vec(data.origin)\n')
driver=driver.replace('SE source comparison only','SW source comparison only').replace('Other directions remain unfinished.','Anatomy and clearance remain unqualified.')
(N/'preview.gd.txt').write_text(driver,encoding='utf-8',newline='\n');shutil.copyfile(N/'preview.gd.txt',E/'preview.gd')
run=(Q/'native_se_v2/run.py').read_text().replace('native_se_v2','native_sw_v1');(N/'run.py').write_text(run,encoding='utf-8',newline='\n')
template=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_layers_20261018/prepared_v3/images/horse_no_reins_v2.png.import').read_text()
for key in sources:
    resource='res://images/'+key+'.png';ctex=key+'.png-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
    raw=template.replace('horse_no_reins_v2.png-a4aceb1e8de5a112998a347bcd6d430f.ctex',ctex).replace('res://images/horse_no_reins_v2.png',resource)
    (E/'images'/(key+'.png.import')).write_text(raw,encoding='utf-8',newline='\n')
source=Path(json.loads((Q/'native_se_v2/prepared_binding.json').read_text())['project'])/'project.godot';shutil.copyfile(source,E/'project.godot')
rows=[{'path':p.relative_to(E).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(E.rglob('*')) if p.is_file()]
with (N/'prepared_binding.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'project':str(E),'files':rows,'inputs':data,'native_executed':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'prepared':True,'files':len(rows),'textures':len(textures),'gait_accepted':False}))
