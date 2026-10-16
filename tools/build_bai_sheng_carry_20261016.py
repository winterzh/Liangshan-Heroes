"""Bind untouched builtin carry PNGs; default verifies, --prepare writes once."""
import argparse,json,math,shutil
from pathlib import Path
import numpy as np
from PIL import Image
import build_liu_tang_pudao_20261016 as base
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'assets/characters/bai_sheng_carry_sources_20261016'
RUNTIME=ROOT/'assets/characters/bai_sheng_carry_20261016'
MANIFEST=ROOT/'assets/direction4/level1_bai_sheng_carry_20261016.json'
FAMILY='bai_sheng_carry_20261016'
STATES={'carry_idle':['carry_idle'],'carry_walk':['carry_contact_a','carry_passing_a','carry_contact_b','carry_passing_b']}
def geometry(path):
    a=np.array(Image.open(path));h,w=a.shape[:2];assert a.shape[2]==4
    strong=a[:,:,3]>=16;sx=base.shared.separator(strong.sum(axis=0));sy=base.shared.separator(strong.sum(axis=1));cells={}
    for d,(x,y,cw,ch) in zip(base.DIRS,([0,0,sx,sy],[sx,0,w-sx,sy],[0,sy,sx,h-sy],[sx,sy,w-sx,h-sy])):
        mask=a[y:y+ch,x:x+cw,3]>=64;ys,xs=np.where(mask);assert len(xs)>1000
        # Crown-only alpha centroid avoids including a bucket or pole in the
        # horizontal body anchor. Lowest alpha bounds are visible sandal soles.
        hy,hx=np.where(mask & (np.indices(mask.shape)[0]<ys.min()+max(12,(ys.max()-ys.min())*.08)))
        hc=float(hx.mean())+x
        cells[d]={'region':[x,y,cw,ch],'strong_bounds':[int(xs.min())+x,int(ys.min())+y,int(xs.max())+x+1,int(ys.max())+y+1],'head_center':hc,'ground_y':int(ys.max())+y+1}
    return {'size':[w,h],'split':[sx,sy],'cells':cells}
def prepare():
    assert not RUNTIME.exists() and not MANIFEST.exists();RUNTIME.mkdir()
    selected=json.loads((RAW/'prompt_set.json').read_text(encoding='utf-8'))['selected'];sources={}
    for key,rawkey in selected.items():
        src=RAW/(rawkey+'_native.png');dest=RUNTIME/(key+'.png');shutil.copyfile(src,dest);base.shared.import_descriptor(dest);g=geometry(dest)
        sources[key]={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':src.relative_to(ROOT).as_posix(),'sha256':base.sha(dest),'native_size':g['size'],'imported_size':g['size'],'geometry':g}
    poses={}
    for key,row in sources.items():
        for d,c in row['geometry']['cells'].items():
            idle=sources['carry_idle']['geometry']['cells'][d];intended=math.ceil((idle['ground_y']-idle['strong_bounds'][1])/.74)
            x,y,w,h=c['region'];px,py=c['head_center'],c['ground_y'];dx,dy=px-x,py-y
            canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            poses[key+'_'+d]={'source':key,'region':c['region'],'margin':[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched builtin PNG; Godot atlas region, virtual margins and uniform display only. Crown X and lowest visible sandal Y measured read-only.'}
    m={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'bai_sheng','sources':sources,'poses':poses,'states':STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in STATES for d in base.DIRS],'production_qualified':False,'native_dimensions_verified':False,'canon':'Chapter16 Bai Sheng shoulders two wine buckets up the hill, puts them down, later departs with empty buckets. Existing face, straw hat, clothing, sandals, plain wood construction and right shoulder are art choices, not exact novel descriptions. Only explicit wine-carry state; no tribute or ordinary identity substitution.'}
    for n,t in base.renderer().render(m).items():
        p=ROOT/n;assert not p.exists();p.write_bytes(t.encode())
    MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');return m
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');args=p.parse_args()
    m=prepare() if args.prepare else json.loads(MANIFEST.read_text(encoding='utf-8'))
    for row in m['sources'].values():assert base.sha(ROOT/row['path'])==base.sha(ROOT/row['candidate_origin'])==row['sha256']
    for n,t in base.renderer().render(m).items():assert (ROOT/n).read_bytes()==t.encode()
    print(json.dumps({'untouched_runtime_pngs':len(m['sources']),'resources':len(m['resources']),'poses':len(m['poses']),'native_qualified':False}))
if __name__=='__main__':main()
