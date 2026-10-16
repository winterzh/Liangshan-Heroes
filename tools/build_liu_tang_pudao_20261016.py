"""Bind untouched Liu Tang PNGs with Godot-only regions/margins/uniform scale.

--prepare creates this versioned batch once. Default verifies source hashes and
resource text. No native qualification or PNG pixel writes occur here.
"""
import argparse,hashlib,importlib.util,json,math,shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
import build_shi_en_canon_20261015 as shared
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/liu_tang_canon_sources_20261016'
NEW=ROOT/'assets/characters/liu_tang_pudao_sources_20261016'
RUNTIME=ROOT/'assets/characters/liu_tang_pudao_20261016'
ICONS=ROOT/'assets/ui/liu_tang_pudao_skills_20261016'
MANIFEST=ROOT/'assets/direction4/ordinary_liu_tang_pudao_20261016.json'
FAMILY='character_traits_v2_liu_tang_pudao'
DIRS=('se','sw','ne','nw')
STATES={'idle':['idle'],'walk':['walk_contact_a','walk_passing_a','walk_contact_b','walk_passing_b'],
        'attack':['attack_windup','attack_windup','attack_strike','attack_strike','attack_strike','attack_recover','attack_recover','idle'],
        'hurt':['hurt_recoil','hurt_recover'],'death':['death_buckle','death_fall','death_settle','death_rest']}
ALIASES={'hurt_recoil':'hurt_recoil_clear','death_fall':'death_fall_clear','death_settle':'death_settle_directions','death_rest':'death_rest_directions'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source(key):return (NEW if key.endswith('_clear') or key=='walk_contact_b_nw_final' or key.startswith('walk_passing_b_') else SOURCE)/(key+'_native.png')
def geometry(path,single=False,standing=True):
    a=np.array(Image.open(path));h,w=a.shape[:2];assert a.shape[2]==4
    strong=a[:,:,3]>=16
    if single:cells={single if isinstance(single,str) else 'nw':[0,0,w,h]};split=None
    else:
        sx=shared.separator(strong.sum(axis=0));sy=shared.separator(strong.sum(axis=1));split=[sx,sy]
        cells=dict(zip(DIRS,([0,0,sx,sy],[sx,0,w-sx,sy],[0,sy,sx,h-sy],[sx,sy,w-sx,h-sy])))
    result={}
    for d,(x,y,cw,ch) in cells.items():
        cell=a[y:y+ch,x:x+cw];mask=cell[:,:,3]>=64;ys,xs=np.where(mask);assert len(xs)>1000
        bounds=[int(xs.min())+x,int(ys.min())+y,int(xs.max())+1+x,int(ys.max())+1+y]
        if not standing:
            result[d]={'region':[x,y,cw,ch],'strong_bounds':bounds,'measured_pivot':None,'pivot_policy':'Lying pose uses original idle world anchor; no standing-foot estimate.'}
            continue
        rgb=cell[:,:,:3].astype(np.int16)
        # Read-only dark neutral shoe/legwrap components. Broad pale blade
        # surfaces and narrow steel edges must not define a standing ground pivot.
        shoe=(rgb.max(axis=2)-rgb.min(axis=2)<40)&(rgb.max(axis=2)<125)
        lower=np.indices(mask.shape)[0]>(ys.max()-(ys.max()-ys.min())*.28)
        labels,count=ndimage.label(mask&shoe&lower);areas=np.bincount(labels.ravel());areas[0]=0
        keep=[]
        for i,box in enumerate(ndimage.find_objects(labels),1):
            if box is None:continue
            bh=box[0].stop-box[0].start;bw=box[1].stop-box[1].start
            if areas[i]>=max(150,float(areas.max())*.2) and bw>=15 and bh>=12 and .25<=bw/bh<=2.8:keep.append(i)
        assert keep,(path,d,'No substantial shoe/legwrap component')
        fy,fx=np.where(np.isin(labels,keep));pivot=[round((int(fx.min())+int(fx.max()))*.5+x,3),int(fy.max())+y+1]
        result[d]={'region':[x,y,cw,ch],'strong_bounds':bounds,'measured_pivot':pivot}
    return {'size':[w,h],'split':split,'cells':result}
def area(path,d):
    a=np.array(Image.open(path));h,w=a.shape[:2];ix,iy=DIRS.index(d)%2,DIRS.index(d)//2
    return int(np.count_nonzero(a[iy*h//2:(iy+1)*h//2,ix*w//2:(ix+1)*w//2,3]>=64))
def head_center(path,region):
    # Read-only scalar measurement. All idle/walk weapons are low; the top
    # sixteen percent of the human silhouette isolates headcloth/upper face.
    # A lifted boot must not drag the entire torso sideways between phases.
    x,y,w,h=region;a=np.array(Image.open(path));alpha=a[y:y+h,x:x+w,3]
    ys,xs=np.where(alpha>=64);top=int(ys.min());bottom=int(ys.max())
    band=alpha[top:top+max(12,round((bottom-top)*.16))]>=64
    _,hx=np.where(band);assert len(hx)>100
    return x+(int(hx.min())+int(hx.max()))*.5
def calibrate_walk_roots(m):
    references={}
    for d in DIRS:
        idle=m['poses']['idle_'+d];row=m['sources'][idle['source']]
        hc=head_center(ROOT/row['path'],idle['region'])
        references[d]=(hc-idle['pivot_native'][0])/idle['virtual_canvas_reference']
        for phase in STATES['walk']:
            p=m['poses'][phase+'_'+d];row=m['sources'][p['source']]
            hc=head_center(ROOT/row['path'],p['region']);intended=p['virtual_canvas_reference']
            px=hc-references[d]*intended;py=p['pivot_native'][1];x,y,w,h=p['region'];dx,dy=px-x,py-y
            canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            p.update(pivot_native=[px,py],margin=[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],draw_scale=canvas/intended,head_center_native=hc,horizontal_anchor_policy='Idle head offset normalized by uniform canvas reference; original shoe ground row retained.')
    m['walk_horizontal_head_offsets']=references
    return m
def prepare():
    assert not MANIFEST.exists() and not RUNTIME.exists() and not ICONS.exists()
    keys={ALIASES.get(k,k) for phases in STATES.values() for k in phases if k!='walk_passing_b'}|{'walk_contact_b_nw_final','walk_passing_b_opposite','walk_passing_b_ne_canon'}
    measured={k:geometry(source(k),'ne' if k=='walk_passing_b_ne_canon' else k=='walk_contact_b_nw_final',not k.startswith(('death_fall','death_settle','death_rest'))) for k in keys}
    for key in ['hurt_recoil_clear','death_fall_clear']:
        im=Image.open(source(key));assert im.getpixel((0,0))[3]==0
    RUNTIME.mkdir(parents=True);ICONS.mkdir(parents=True);sources={}
    for key in sorted(keys):
        src=source(key);dest=RUNTIME/(key+'.png');shutil.copyfile(src,dest);shared.import_descriptor(dest)
        assert sha(src)==sha(dest)
        sources[key]={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':src.relative_to(ROOT).as_posix(),'sha256':sha(dest),'native_size':measured[key]['size'],'imported_size':measured[key]['size'],'geometry':measured[key],'import_dimensions_verified':False}
    portrait=RUNTIME/'portrait.png';shutil.copyfile(SOURCE/'portrait_complexion_native.png',portrait);shared.import_descriptor(portrait)
    for s in 'qwer':
        dest=ICONS/('liu_tang_'+s+'.png');shutil.copyfile(NEW/('liu_tang_'+s+'_native.png'),dest);shared.import_descriptor(dest)
    idle=sources['idle']['geometry']['cells'];base={d:math.ceil((idle[d]['measured_pivot'][1]-idle[d]['strong_bounds'][1])/.74) for d in DIRS}
    calibrations={value:{d:math.sqrt(area(source(value),d)/area(source(key),d)) for d in DIRS} for key,value in ALIASES.items()}
    poses={}
    for pose in dict.fromkeys(k for phases in STATES.values() for k in phases):
        for d in DIRS:
            key='walk_contact_b_nw_final' if pose=='walk_contact_b' and d=='nw' else ('walk_passing_b_ne_canon' if d=='ne' else 'walk_passing_b_opposite') if pose=='walk_passing_b' else ALIASES.get(pose,pose)
            cell=sources[key]['geometry']['cells'][d];x,y,w,h=cell['region'];intended=math.ceil(base[d]*calibrations.get(key,{}).get(d,1.0))
            px,py=idle[d]['measured_pivot'] if pose in ['death_fall','death_settle','death_rest'] else cell['measured_pivot']
            if key in ['walk_contact_b_nw_final','walk_passing_b_ne_canon']:intended=math.ceil((py-cell['strong_bounds'][1])/.74)
            dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            left,top=canvas*.5-dx,canvas*.82-dy;assert min(left,top,canvas-w,canvas-h)>=0
            poses[pose+'_'+d]={'source':key,'region':cell['region'],'margin':[left,top,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched native PNG. Godot atlas sampling, transparent virtual margins and uniform scale only; no bitmap write or mirror.'}
    manifest={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'liu_tang','sources':sources,'poses':poses,'states':STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in STATES for d in DIRS],'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'sha256':sha(portrait),'candidate_origin':'assets/characters/liu_tang_canon_sources_20261016/portrait_complexion_native.png'},'production_qualified':False,'native_dimensions_verified':False,'scale_calibration':calibrations,'canon':'120-chapter Water Margin14 broad purplish-dark face, temple cinnabar birthmark with black/yellow hair, pu-dao combat. Right temple, exact scarf/beard/costume/weapon dimensions and ordinary moves are conservative art/game design. Generic defeat is not novel fate. Chapter16 explicit merchant body remains separate and pending.'}
    calibrate_walk_roots(manifest)
    MANIFEST.write_bytes((json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode())
    for name,text in renderer().render(manifest).items():
        p=ROOT/name;assert not p.exists();p.write_bytes(text.encode())
    return manifest
def renderer():
    spec=importlib.util.spec_from_file_location('liu_frames',ROOT/'tools/build_directional_spriteframes.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');args=parser.parse_args()
    m=prepare() if args.prepare else json.loads(MANIFEST.read_text(encoding='utf-8'))
    for name,text in renderer().render(m).items():assert (ROOT/name).read_bytes()==text.encode()
    for row in m['sources'].values():assert sha(ROOT/row['path'])==sha(ROOT/row['candidate_origin'])==row['sha256']
    for s in 'qwer':assert sha(ICONS/('liu_tang_'+s+'.png'))==sha(NEW/('liu_tang_'+s+'_native.png'))
    print(json.dumps({'runtime_body_portrait':len(m['sources'])+1,'icons':4,'resources':len(m['resources']),'poses':len(m['poses']),'native_qualified':False}))
if __name__=='__main__':main()
