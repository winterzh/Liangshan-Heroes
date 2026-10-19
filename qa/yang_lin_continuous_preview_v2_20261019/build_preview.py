"""Build a standalone browser art preview using unchanged painted PNG originals."""
from pathlib import Path
import base64,hashlib,json,math,re
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
assert not (Q/'runtime_receipt.json').exists(), 'Frozen runtime evidence exists; use a successor version.'
K=R/'qa/yang_lin_leg_rig_sources_20261019'
model_path=K/'browser_rig_v3/model.json';model=json.loads(model_path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
unit=(R/'scripts/unit.gd').read_text(encoding='utf-8');defs=(R/'scripts/defs.gd').read_text(encoding='utf-8')
game_map=(R/'scripts/game_map.gd').read_text(encoding='utf-8');art=(R/'scripts/art_db.gd').read_text(encoding='utf-8')
definition=next(line for line in defs.splitlines() if line.strip().startswith('"yang_lin":'))
speed=float(re.search(r'"speed":\s*([0-9.]+)',definition).group(1))
radius=float(re.search(r'"radius":\s*([0-9.]+)',definition).group(1))
move_scale=float(re.search(r'const MOVE_SCALE := ([0-9.]+)',unit).group(1))
assert 'var s := radius * 3.7 * visual_scale' in unit
assert 'delta * (13.0 if is_cavalry else 9.5) * MOVE_SCALE * (base_speed / 72.0)' in unit
assert 'return base_speed * buff_speed * temp_speed * _temp_move_boost * _drunk_move * aura_slow * MOVE_SCALE * terrain' in unit
assert 'Transform2D(Vector2(1.0, 0.5), Vector2(-1.0, 0.5), Vector2.ZERO)' in game_map
assert 'at.region = Rect2(i * h, 0, h, h)' in art
legacy=R/'assets/anim/yang_lin_walk.png'
with Image.open(legacy) as im:
    assert im.mode=='RGBA' and im.size==(1024,256)
    alpha=im.getchannel('A');bounds=[alpha.crop((i*256,0,(i+1)*256,256)).getbbox() for i in range(4)]
assert all(b[3]-b[1]==205 for b in bounds)
legacy_visible=radius*3.7*205/256
params={'base_speed':speed,'move_scale':move_scale,'baseline_world_speed':speed*move_scale,
        'radius':radius,'visual_scale_reference':1,'legacy_square_draw_size':radius*3.7,
        'legacy_visible_height_reference':legacy_visible,'legacy_frame_alpha_bounds':bounds,
        'source_human_head_to_hip_reference':234,'model_hip_height':290,
        'model_to_world_scale':legacy_visible/(234+290),
        'legacy_world_distance_per_cycle_reference':2*math.pi*72/9.5,
        'world_distance_per_cycle':2*120/.6*legacy_visible/(234+290),'stride_half_source':120,'stance_fraction':.6,
        'thigh_length_3d':135,'shin_length_3d':135,'boot_scale':.28,'torso_scale':.75,
        'part_width_scale':.25,'swing_height':35,'recovery_lift':14,'manual_anchor_uncertainty_source_pixels':15}
sources=[]
for row in model['sources']['sources']:
    path=K/row['source'];assert sha(path)==row['sha256']
    sources.append({'kind':row['key'].split('_v')[0],'file':path.relative_to(R).as_posix(),
                    'sha256':sha(path),'regions':row['regions'],
                    'image':'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode('ascii')})
with Image.open(K/'native_originals/boots_v2.png') as im:
    for directions in model['boot_points'].values():
        for points in directions.values():
            assert im.getpixel(tuple(round(v) for v in points['sole']))[3]>=64
paths=['scripts/defs.gd','scripts/unit.gd','scripts/art_db.gd','scripts/game_map.gd',
       'assets/anim/yang_lin_walk.png','qa/yang_lin_leg_rig_sources_20261019/browser_rig_v3/model.json',
       'qa/yang_lin_leg_rig_sources_20261019/canon_basis.json']
provenance=[{'path':p,'sha256':sha(R/p)} for p in paths]
data={'params':params,'sources':sources,'torsoHip':model['torso_hip'],'thighJoints':model['thigh_joints'],
      'shinJoints':model['shin_joints'],'bootPoints':model['boot_points'],'provenance':provenance,
      'strict_source_alpha_accepted':False,'production_adopted':False,'native_accepted':False}
fixture={**data,'sources':[{k:v for k,v in s.items() if k!='image'} for s in sources]}
with (Q/'fixture.json').open('w',encoding='utf-8') as f:f.write(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
template=(Q/'viewer.template.html').read_text(encoding='utf-8');js=(Q/'viewer.js').read_text(encoding='utf-8')
build_id=hashlib.sha256(js.encode()+template.encode()+json.dumps(fixture,sort_keys=True,separators=(',',':')).encode()).hexdigest()
data['buildId']=build_id;fixture['buildId']=build_id
with (Q/'fixture.json').open('w',encoding='utf-8') as f:f.write(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
assert '__FIXTURE__' in template and '__VIEWER_SCRIPT__' in template
html=template.replace('__FIXTURE__',json.dumps(data,ensure_ascii=False,separators=(',',':'))).replace('__VIEWER_SCRIPT__',js)
with (Q/'viewer.html').open('w',encoding='utf-8') as f:f.write(html)
print(json.dumps({'viewer':str(Q/'viewer.html'),'bytes':(Q/'viewer.html').stat().st_size,
                  'baseline_speed':params['baseline_world_speed'],'display_height_reference':legacy_visible,
                  'world_distance_per_cycle':params['world_distance_per_cycle'],'source_images':len(sources)}))
