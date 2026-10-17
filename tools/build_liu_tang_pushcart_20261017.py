"""Bind untouched pushcart originals with read-only geometry and Godot atlases."""
import argparse,json,math,shutil,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
import build_liu_tang_pudao_20261016 as base
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'assets/characters/liu_tang_pushcart_sources_20261017'
EXTRA=ROOT/'assets/characters/liu_tang_pushcart_integration_sources_20261017'
RUNTIME=ROOT/'assets/characters/liu_tang_pushcart_20261017'
MANIFEST=ROOT/'assets/direction4/level1_liu_tang_pushcart_20261017.json'
FAMILY='liu_tang_pushcart_20261017'
SELECTED={'push_idle':'push_idle_clear_v3','push_contact_a':'push_contact_a','push_passing_a':'push_passing_a',
 'push_contact_b':'push_contact_b_poseguide_edge_v2','push_passing_b':'push_passing_b_poseguide_edge_v2'}
STATES={'push_idle':['push_idle'],'push_walk':['push_contact_a','push_passing_a','push_contact_b','push_passing_b'],'parked_cart':['cart_only']}

def wheel_contact(path,direction):
    a=np.array(Image.open(path));h,w=a.shape[:2];index=base.DIRS.index(direction);x,y=(index%2)*w//2,(index//2)*h//2
    cell=a[y:y+h//2,x:x+w//2];rgb=cell[:,:,:3].astype(int);yy,xx=np.indices(cell.shape[:2]);cw,ch=w//2,h//2
    rois={'se':(.38,.74,.45,1),'sw':(.26,.65,.45,1),'ne':(.57,.98,.28,.8),'nw':(.02,.43,.28,.8)}
    left,right,top,bottom=rois[direction]
    mask=(cell[:,:,3]>=64)&(rgb[:,:,0]>100)&(rgb[:,:,0]-rgb[:,:,1]>12)&(rgb[:,:,1]-rgb[:,:,2]>15)&(xx>=cw*left)&(xx<cw*right)&(yy>=ch*top)&(yy<ch*bottom)
    ys,xs=np.where(mask);assert len(xs)>100;low=int(ys.max());_,bottom_x=np.where(mask&(yy>=low-3))
    return [float(bottom_x.mean())+x,low+y+1]

def calibrate_wheels(m):
    # Establish the actor's idle root from human shoes once; moving poses use
    # the fixed wheel-to-root vector so shifting feet cannot lift the whole cart.
    offsets={}
    for d in base.DIRS:
        idle=m['sources']['push_idle']['geometry']['cells'][d]
        root_x={'se':158.0,'sw':1100.0,'ne':170.0,'nw':1097.0}[d]
        reference=math.ceil((idle['ground_y']-idle['head_center'][1])/.74)
        contact=wheel_contact(ROOT/m['sources']['push_idle']['path'],d)
        offsets[d]=[(contact[0]-root_x)/reference,(contact[1]-idle['ground_y'])/reference]
        for key,row in m['sources'].items():
            contact=wheel_contact(ROOT/row['path'],d);row.setdefault('wheel_contacts',{})[d]=contact
            p=m['poses'][key+'_'+d];x,y,w,h=p['region'];px,py=[contact[i]-offsets[d][i]*reference for i in range(2)]
            dx,dy=px-x,py-y;canvas=math.ceil(max(reference,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            p.update(pivot_native=[px,py],margin=[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],draw_scale=canvas/reference,virtual_canvas_reference=reference,
              operations='Untouched builtin PNG. Idle human root established from shoes; every moving/parked pose retains the same wheel-contact vector using read-only warm-wood alpha geometry. Godot regions/margins/uniform display only.')
    m['wheel_offsets_per_body_size']=offsets
    return m

def geometry(path):
    a=np.array(Image.open(path));h,w=a.shape[:2];assert a.shape[2]==4
    strong=a[:,:,3]>=16;sx=base.shared.separator(strong.sum(0));sy=base.shared.separator(strong.sum(1));cells={}
    for d,(x,y,cw,ch) in zip(base.DIRS,([0,0,sx,sy],[sx,0,w-sx,sy],[0,sy,sx,h-sy],[sx,sy,w-sx,h-sy])):
        cell=a[y:y+ch,x:x+cw];mask=cell[:,:,3]>=64;rgb=cell[:,:,:3].astype(int);yy,xx=np.indices(mask.shape)
        person=(xx<cw*.48) if d in ['se','ne'] else (xx>cw*.52)
        dark=mask&person&(yy<ch*.35)&(rgb.max(2)<90)&(rgb.max(2)-rgb.min(2)<35)
        labels,_=ndimage.label(dark);areas=np.bincount(labels.ravel());heads=[]
        for i,box in enumerate(ndimage.find_objects(labels),1):
            if box is not None and areas[i]>=200:heads.append((box[0].start,-int(areas[i]),box))
        assert heads,(path,d,'no headcloth component')
        box=sorted(heads,key=lambda row:row[:2])[0][2]
        head=[x+(box[1].start+box[1].stop)*.5,y+box[0].start]
        boot=mask&person&(yy>box[0].start+140)&(rgb.max(2)<125)&(rgb.max(2)-rgb.min(2)<35)
        labels,_=ndimage.label(boot);areas=np.bincount(labels.ravel());boots=[]
        for i,box in enumerate(ndimage.find_objects(labels),1):
            if box is not None and areas[i]>=2000:
                boots.append({'area':int(areas[i]),'bounds':[x+box[1].start,y+box[0].start,x+box[1].stop,y+box[0].stop]})
        assert boots,(path,d,'no substantial neutral cloth/shoe component')
        ground=max(b['bounds'][3] for b in boots)
        ys,xs=np.where(mask)
        cells[d]={'region':[x,y,cw,ch],'strong_bounds':[x+int(xs.min()),y+int(ys.min()),x+int(xs.max())+1,y+int(ys.max())+1],
          'head_center':head,'ground_y':ground,'shoe_components':boots}
    return {'size':[w,h],'split':[sx,sy],'cells':cells}

def prepare():
    assert not RUNTIME.exists() and not MANIFEST.exists();RUNTIME.mkdir()
    sources={}
    for key,rawkey in SELECTED.items():
        src=RAW/(rawkey+'.png');dest=RUNTIME/(key+'.png');shutil.copyfile(src,dest);base.shared.import_descriptor(dest)
        g=geometry(dest)
        sources[key]={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':src.relative_to(ROOT).as_posix(),
          'sha256':base.sha(dest),'native_size':g['size'],'imported_size':g['size'],'geometry':g}
    src=EXTRA/'cart_only.png';dest=RUNTIME/'cart_only.png';shutil.copyfile(src,dest);base.shared.import_descriptor(dest)
    with Image.open(dest) as image:assert image.mode=='RGBA';size=list(image.size)
    sources['cart_only']={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':src.relative_to(ROOT).as_posix(),'sha256':base.sha(dest),'native_size':size,'imported_size':size}
    poses={}
    # Body pivots refer to the human's shoes, not the forward cart wheel. A
    # virtual transparent canvas can extend below that pivot without bitmap edits.
    idle_x={'se':158.0,'sw':1100.0,'ne':170.0,'nw':1097.0}
    for key,row in sources.items():
        for d in base.DIRS:
            idle=sources['push_idle']['geometry']['cells'][d]
            c=idle if key=='cart_only' else row['geometry']['cells'][d]
            x,y,w,h=c['region'];intended=math.ceil((idle['ground_y']-idle['head_center'][1])/.74)
            px=idle_x[d]+c['head_center'][0]-idle['head_center'][0];py=c['ground_y']
            dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            poses[key+'_'+d]={'source':key,'region':c['region'],'margin':[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],
              'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],
              'operations':'Untouched builtin PNG; Godot atlas region, virtual margins and uniform display only. Human head/shoe measurements do not include cart wheel. Cart-only prop shares idle layout for interrupted push poses.'}
    m={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'liu_tang','sources':sources,'poses':poses,'states':STATES,
      'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in STATES for d in base.DIRS],
      'production_qualified':False,'native_dimensions_verified':False,
      'canon':'Chapter16 seven men cover the tribute goods in seven Jiangzhou carts and push away. Single wheel, frame/cover construction and weapon stowage are art interpretations. Only Liu Tang hn_liu_tang carrying_tribute state; no claim of fixing other carriers or original seven carts/eleven loads vs current three mission targets.'}
    calibrate_wheels(m)
    for name,text in base.renderer().render(m).items():
        p=ROOT/name;assert not p.exists();p.write_bytes(text.encode())
    MANIFEST.write_bytes((json.dumps(m,ensure_ascii=False,indent=2)+'\n').encode());return m

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');p.add_argument('--recalibrate',action='store_true');args=p.parse_args()
    assert not (args.prepare and args.recalibrate)
    m=prepare() if args.prepare else json.loads(MANIFEST.read_text(encoding='utf-8'))
    if args.recalibrate:
        names=[MANIFEST.relative_to(ROOT).as_posix()]+m['resources']
        assert not subprocess.check_output(['git','ls-files','--',*names],cwd=ROOT),'Recalibration writes only a new untracked candidate version'
        calibrate_wheels(m);MANIFEST.write_bytes((json.dumps(m,ensure_ascii=False,indent=2)+'\n').encode())
        for name,text in base.renderer().render(m).items():(ROOT/name).write_bytes(text.encode())
    for row in m['sources'].values():assert base.sha(ROOT/row['path'])==base.sha(ROOT/row['candidate_origin'])==row['sha256']
    for name,text in base.renderer().render(m).items():assert (ROOT/name).read_bytes()==text.encode()
    print(json.dumps({'untouched_runtime_pngs':len(m['sources']),'poses':len(m['poses']),'resources':len(m['resources']),'native_qualified':False}))
if __name__=='__main__':main()
