"""Bind untouched canonical Shi En PNGs to native atlas frames; never paint PNGs.

Default verifies the authored manifest/resources. --prepare creates the new
versioned resources once; native import/UI acceptance remains a separate gate.
"""
import argparse, hashlib, importlib.util, json, math, re, shutil, subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/shi_en_canon_sources_20261015'
RUNTIME=ROOT/'assets/characters/shi_en_canon_20261015'
MANIFEST=ROOT/'assets/direction4/ordinary_shi_en_canon_20261015.json'
FAMILY='character_traits_v2_shi_en_canon'
DIRS=('se','sw','ne','nw')
STATES={'idle':['idle'],'walk':['walk_contact_a','walk_passing_a','walk_contact_b','walk_passing_b'],
        'attack':['attack_windup','attack_windup','attack_strike','attack_strike','attack_strike','attack_recover','attack_recover','idle'],
        'hurt':['hurt_recoil','hurt_recover'],'death':['death_buckle','death_fall','death_settle','death_rest']}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,obj):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(obj,ensure_ascii=False,indent=2)+'\n').encode())
def separator(counts):
    n=len(counts);runs=[];start=None
    for i in range(int(n*.4),int(n*.6)+1):
        if counts[i]==0 and start is None:start=i
        if start is not None and (counts[i]!=0 or i==int(n*.6)):
            end=i if counts[i]!=0 else i+1;runs.append((start,end));start=None
    assert runs,'No transparent strong-alpha separator; source requires review'
    a,b=min(runs,key=lambda p:abs((p[0]+p[1])*.5-n*.5)-.1*(p[1]-p[0]))
    return (a+b)//2

def image_geometry(path,single=False):
    image=np.array(Image.open(path));assert image.shape[2]==4
    h,w=image.shape[:2];strong=image[:,:,3]>=16
    if single:cells={'nw':[0,0,w,h]};splits=None
    else:
        sx=separator(strong.sum(axis=0));sy=separator(strong.sum(axis=1));splits=[sx,sy]
        cells=dict(zip(DIRS,([0,0,sx,sy],[sx,0,w-sx,sy],[0,sy,sx,h-sy],[sx,sy,w-sx,h-sy])))
    geometry={}
    for direction,(x,y,cw,ch) in cells.items():
        cell=image[y:y+ch,x:x+cw];mask=cell[:,:,3]>=64;ys,xs=np.where(mask);assert len(xs)>1000
        bounds=[int(xs.min())+x,int(ys.min())+y,int(xs.max())+1+x,int(ys.max())+1+y]
        # Measure feet from the lower silhouette; warm-brown staff pixels do
        # not define the actor's ground pivot. This is measurement only.
        rgb=cell[:,:,:3].astype(np.int16);neutral=(rgb.max(axis=2)-rgb.min(axis=2)<40)
        lower=np.indices(mask.shape)[0]>int(ys.max()-(ys.max()-ys.min())*.23)
        labels,count=ndimage.label(mask & neutral & lower)
        areas=np.bincount(labels.ravel());areas[0]=0
        assert count>0 and areas.max()>100
        # A staff's narrow neutral-shaded edge is far smaller than either
        # shoe/calf component. Retain substantial foot groups, not that edge.
        keep=np.where(areas>=max(100,float(areas.max())*.15))[0]
        fy,fx=np.where(np.isin(labels,keep));assert len(fx)>30
        pivot=[round((int(fx.min())+int(fx.max()))*.5+x,3),int(fy.max())+y+1]
        geometry[direction]={'region':[x,y,cw,ch],'strong_bounds':bounds,'measured_pivot':pivot}
    return {'size':[w,h],'split':splits,'cells':geometry}

def import_descriptor(path):
    template=ROOT/'assets/characters/shi_en_portrait_20261015/shi_en.png.import'
    text=template.read_text(encoding='utf-8');res='res://'+path.relative_to(ROOT).as_posix()
    uid='uid://c'+hashlib.sha256(res.encode()).hexdigest()[:11].replace('9','8')
    cache='res://.godot/imported/'+path.name+'-'+hashlib.md5(res.encode()).hexdigest()+'.ctex'
    text=re.sub(r'uid="[^"]+"','uid="'+uid+'"',text)
    text=text.replace('res://.godot/imported/shi_en.png-a2331b28a9f426ad055239a96d5b6025.ctex',cache)
    text=text.replace('res://assets/characters/shi_en_portrait_20261015/shi_en.png',res)
    Path(str(path)+'.import').write_bytes(text.encode())

def prepare(revise=False):
    if revise:
        tracked=subprocess.run(['git','ls-files','--error-unmatch','--',MANIFEST.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True)
        assert tracked.returncode!=0 and MANIFEST.exists() and RUNTIME.exists(),'Only uncommitted candidate geometry can be revised'
    else:assert not MANIFEST.exists() and not RUNTIME.exists(),'Never overwrite adopted resources'
    keys=list(dict.fromkeys(k for order in STATES.values() for k in order if k not in ('walk_contact_b','walk_passing_b')))
    keys+=['walk_contact_b_fix2','walk_contact_b_fix3','walk_contact_b_nw_single','walk_passing_b_fix']
    RUNTIME.mkdir(parents=True,exist_ok=revise);sources={}
    for key in keys:
        src=SOURCE/(key+'_native.png');dst=RUNTIME/(key+'.png')
        if not revise:shutil.copyfile(src,dst);import_descriptor(dst)
        assert sha(src)==sha(dst)
        g=image_geometry(dst,key=='walk_contact_b_nw_single')
        sources[key]={'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst),'candidate_origin':src.relative_to(ROOT).as_posix(),
                      'native_size':g['size'],'imported_size':g['size'],'import_dimensions_verified':False,'geometry':g,
                      'import_dimension_status':'Expected only; actual native import receipt required'}
    portrait=RUNTIME/'portrait.png'
    if not revise:shutil.copyfile(SOURCE/'portrait_native.png',portrait);import_descriptor(portrait)
    assert sha(portrait)==sha(SOURCE/'portrait_native.png')
    idle=sources['idle']['geometry']['cells'];base={d:math.ceil((idle[d]['measured_pivot'][1]-idle[d]['strong_bounds'][1])/.74) for d in DIRS}
    poses={}
    for pose in dict.fromkeys(k for order in STATES.values() for k in order):
        for direction in DIRS:
            source=pose
            if pose=='walk_contact_b':source={'se':'walk_contact_b_fix2','sw':'walk_contact_b_fix2','ne':'walk_contact_b_fix3','nw':'walk_contact_b_nw_single'}[direction]
            elif pose=='walk_passing_b':source='walk_passing_b_fix'
            cell=sources[source]['geometry']['cells'][direction];x,y,w,h=cell['region'];px,py=cell['measured_pivot']
            intended=base[direction]
            if pose in ('death_fall','death_settle','death_rest'):
                px,py=idle[direction]['measured_pivot']
            elif source=='walk_contact_b_nw_single':
                intended=math.ceil((py-cell['strong_bounds'][1])/.74)
            dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            left=canvas*.5-dx;top=canvas*.82-dy
            assert min(left,top,canvas-w,canvas-h)>=0 and left+w<=canvas+.0001 and top+h<=canvas+.0001
            poses[pose+'_'+direction]={'source':source,'region':cell['region'],'margin':[left,top,canvas-w,canvas-h],
                'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,
                'pivot_native':[px,py],'operations':'Native atlas sampling, transparent virtual margin and uniform draw scale only; no PNG pixel edit or mirror.'}
    manifest={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'shi_en','production_qualified':False,
              'sources':sources,'poses':poses,'states':STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for d in DIRS for s in STATES],
              'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'sha256':sha(portrait)},
              'canon':'Water Margin 120 chapters 28–29: young fair face, three beard locks, blue-green cloth robe. Staff and ordinary battle poses are conservative gameplay design, not literal novel events.',
              'native_dimensions_verified':False,'qualification_note':'Original authoring state retained; final native adoption receipt must separately prove actual import, body/UI and source pinning.'}
    spec=importlib.util.spec_from_file_location('canon_frame_builder',ROOT/'tools/build_directional_spriteframes.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    write(MANIFEST,manifest)
    for name,text in module.render(manifest).items():
        path=ROOT/name;assert revise or not path.exists();path.write_bytes(text.encode())
    return manifest

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--revise-geometry',action='store_true');args=parser.parse_args()
    assert not (args.prepare and args.revise_geometry)
    if args.prepare or args.revise_geometry:m=prepare(args.revise_geometry)
    else:
        m=json.loads(MANIFEST.read_text(encoding='utf-8'));spec=importlib.util.spec_from_file_location('canon_frame_builder',ROOT/'tools/build_directional_spriteframes.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        for name,text in module.render(m).items():assert (ROOT/name).read_bytes()==text.encode()
        for source in m['sources'].values():assert sha(ROOT/source['path'])==sha(ROOT/source['candidate_origin'])==source['sha256']
    print(json.dumps({'sources':len(m['sources']),'poses':len(m['poses']),'resources':len(m['resources']),'native_qualified':False,'png_pixels_edited':False}))
if __name__=='__main__':main()
