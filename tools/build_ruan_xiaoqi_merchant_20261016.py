"""Measure untouched Ruan Xiaoqi PNGs and bind native four-direction frames.

Pixel reads only. Barefoot skin components define standing ground pivots;
Godot uses native atlas regions, transparent margins and uniform display scale.
"""
import argparse,hashlib,importlib.util,json,math,shutil,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
import build_shi_en_canon_20261015 as shared
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/ruan_xiaoqi_merchant_sources_20261016'
RUNTIME=ROOT/'assets/characters/ruan_xiaoqi_merchant_20261016'
MANIFEST=ROOT/'assets/direction4/level1_ruan_xiaoqi_merchant_20261016.json'
FAMILY='character_traits_v2_ruan_xiaoqi_merchant'
DIRS=('se','sw','ne','nw')
STATES={'idle':['idle'],'walk':['walk_contact_a','walk_passing_a','walk_contact_b','walk_passing_b'],
        'attack':['attack_windup','attack_windup','attack_strike','attack_strike','attack_strike','attack_recover','attack_recover','idle'],
        'hurt':['hurt_recoil','hurt_recover'],'death':['death_buckle','death_fall','death_settle','death_rest']}
ALIASES={'idle':'idle_spacing','walk_contact_a':'walk_contact_a_spacing','attack_windup':'attack_windup_spacing','hurt_recover':'hurt_recover_spacing','death_fall':'death_fall_spacing'}
B_SOURCES={d:'walk_contact_b' for d in DIRS}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def skin_area(path,direction):
    # Measurement only: compare matched original/spacing poses, never sample
    # these approximate quadrants into a runtime texture or modify PNG pixels.
    a=np.array(Image.open(path));h,w=a.shape[:2];i=DIRS.index(direction)
    a=a[(h//2 if i>1 else 0):(h if i>1 else h//2),(w//2 if i%2 else 0):(w if i%2 else w//2)]
    rgb=a[:,:,:3].astype(np.int16)
    return int(((a[:,:,3]>=64)&(rgb[:,:,0]>70)&(rgb[:,:,0]-rgb[:,:,1]>10)&(rgb[:,:,1]-rgb[:,:,2]>4)).sum())
def geometry(path,single=False):
    a=np.array(Image.open(path));h,w=a.shape[:2];strong=a[:,:,3]>=16
    if single:cells={'nw':[0,0,w,h]};split=None
    else:
        sx=shared.separator(strong.sum(axis=0));sy=shared.separator(strong.sum(axis=1));split=[sx,sy]
        cells=dict(zip(DIRS,([0,0,sx,sy],[sx,0,w-sx,sy],[0,sy,sx,h-sy],[sx,sy,w-sx,h-sy])))
    result={}
    for d,(x,y,cw,ch) in cells.items():
        cell=a[y:y+ch,x:x+cw];mask=cell[:,:,3]>=64;ys,xs=np.where(mask);assert len(xs)>1000
        bounds=[int(xs.min())+x,int(ys.min())+y,int(xs.max())+1+x,int(ys.max())+1+y]
        rgb=cell[:,:,:3].astype(np.int16)
        skin=(rgb[:,:,0]>70)&(rgb[:,:,0]-rgb[:,:,1]>10)&(rgb[:,:,1]-rgb[:,:,2]>4)
        lower=np.indices(mask.shape)[0]>(ys.max()-(ys.max()-ys.min())*.28)
        labels,count=ndimage.label(mask&skin&lower);areas=np.bincount(labels.ravel());areas[0]=0
        assert count and areas.max()>150,(path,d,'No readable bare foot')
        keep=[]
        for i,slice_ in enumerate(ndimage.find_objects(labels),1):
            if slice_ is None:continue
            bh=slice_[0].stop-slice_[0].start;bw=slice_[1].stop-slice_[1].start
            if areas[i]>=max(150,areas.max()*.20) and bw>=10 and bh<=bw*4.5:keep.append(i)
        fy,fx=np.where(np.isin(labels,keep));assert len(fx)>100,(path,d,'No substantial barefoot component')
        pivot=[round((int(fx.min())+int(fx.max()))*.5+x,3),int(fy.max())+y+1]
        result[d]={'region':[x,y,cw,ch],'strong_bounds':bounds,'measured_pivot':pivot}
    return {'size':[w,h],'split':split,'cells':result}
def prepare(revise=False):
    if revise:
        tracked=subprocess.run(['git','ls-files','--error-unmatch','--',MANIFEST.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True)
        assert tracked.returncode!=0 and MANIFEST.exists() and RUNTIME.exists()
    else:assert not MANIFEST.exists() and not RUNTIME.exists(),'Never overwrite adopted resources'
    keys={ALIASES.get(k,k) for order in STATES.values() for k in order if k!='walk_contact_b'}|set(B_SOURCES.values())
    for key in sorted(keys):geometry(SOURCE/(key+'_native.png'))
    RUNTIME.mkdir(parents=True,exist_ok=revise)
    keys={ALIASES.get(k,k) for order in STATES.values() for k in order if k!='walk_contact_b'}|set(B_SOURCES.values())
    sources={}
    for key in sorted(keys):
        src=SOURCE/(key+'_native.png');dest=RUNTIME/(key+'.png')
        if not revise:shutil.copyfile(src,dest);shared.import_descriptor(dest)
        assert sha(src)==sha(dest);g=geometry(dest,key=='walk_contact_b_nw')
        sources[key]={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':src.relative_to(ROOT).as_posix(),'sha256':sha(dest),'native_size':g['size'],'imported_size':g['size'],'geometry':g,'import_dimensions_verified':False}
    portrait=RUNTIME/'portrait.png'
    if not revise:shutil.copyfile(SOURCE/'portrait_native.png',portrait);shared.import_descriptor(portrait)
    assert sha(portrait)==sha(SOURCE/'portrait_native.png')
    idle=sources['idle_spacing']['geometry']['cells']
    base={d:math.ceil((idle[d]['measured_pivot'][1]-idle[d]['strong_bounds'][1])/.74) for d in DIRS};poses={}
    calibration={key:{d:math.sqrt(skin_area(SOURCE/(key+'_native.png'),d)/skin_area(SOURCE/(key.removesuffix('_spacing')+'_native.png'),d)) for d in DIRS} for key in ALIASES.values()}
    for pose in dict.fromkeys(k for order in STATES.values() for k in order):
        for d in DIRS:
            source=B_SOURCES[d] if pose=='walk_contact_b' else ALIASES.get(pose,pose)
            cell=sources[source]['geometry']['cells'][d];x,y,w,h=cell['region'];px,py=cell['measured_pivot'];intended=base[d]
            intended=math.ceil(base[d]/calibration['idle_spacing'][d]*calibration.get(source,{}).get(d,1.0))
            if pose in ['death_fall','death_settle','death_rest']:px,py=idle[d]['measured_pivot']
            elif source=='walk_contact_b_nw':intended=math.ceil((py-cell['strong_bounds'][1])/.74)
            dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            left=canvas*.5-dx;top=canvas*.82-dy
            assert min(left,top,canvas-w,canvas-h)>=0
            poses[pose+'_'+d]={'source':source,'region':cell['region'],'margin':[left,top,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched native PNG; Godot atlas sampling, transparent virtual margin, uniform scale; no pixel writes or mirroring.'}
    manifest={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'ruan_xiaoqi','sources':sources,'poses':poses,'states':STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in STATES for d in DIRS],'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'sha256':sha(portrait)},'production_qualified':False,'native_dimensions_verified':False,'canon':'120-chapter Water Margin15 face/dark body spots,16 shirtless merchants resting and carrying pu dao. Tied hair, covered lower costume, bare feet, precise blade dimensions and moves are conservative game art. Ordinary failure is not novel fate. Native adoption requires separate actual evidence.'}
    manifest['spacing_scale_calibration']=calibration
    manifest['scale_method']='Matched-pose skin pixel area ratios measure spacing edit size. Godot-only uniform scale normalizes original and spacing sources against the same original idle anatomy; PNG pixels remain untouched.'
    MANIFEST.parent.mkdir(parents=True,exist_ok=True);MANIFEST.write_bytes((json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode())
    spec=importlib.util.spec_from_file_location('ruan_frame_builder',ROOT/'tools/build_directional_spriteframes.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    for name,value in m.render(manifest).items():
        path=ROOT/name;assert revise or not path.exists();path.write_bytes(value.encode())
    return manifest
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');p.add_argument('--revise-geometry',action='store_true');args=p.parse_args()
    assert not(args.prepare and args.revise_geometry)
    if args.prepare or args.revise_geometry:m=prepare(args.revise_geometry)
    else:
        m=json.loads(MANIFEST.read_text(encoding='utf-8'))
        spec=importlib.util.spec_from_file_location('ruan_frame_builder',ROOT/'tools/build_directional_spriteframes.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
        for n,t in b.render(m).items():assert (ROOT/n).read_bytes()==t.encode()
        for row in m['sources'].values():assert sha(ROOT/row['path'])==sha(ROOT/row['candidate_origin'])==row['sha256']
    print(json.dumps({'textures':len(m['sources'])+1,'resources':len(m['resources']),'poses':len(m['poses']),'png_pixels_edited':False,'native_qualified':False}))
if __name__=='__main__':main()
