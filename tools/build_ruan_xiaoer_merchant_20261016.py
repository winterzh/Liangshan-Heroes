"""Bind untouched builtin Ruan Xiaoer chapter16 merchant PNGs.

--prepare creates this versioned batch once. Default verifies hashes and exact
Godot resources; it never changes PNG pixels or launches native acceptance.
"""
import argparse,json,math,shutil
from pathlib import Path
import build_liu_tang_pudao_20261016 as base
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'assets/characters/ruan_xiaoer_merchant_sources_20261016'
RUNTIME=ROOT/'assets/characters/ruan_xiaoer_merchant_20261016'
MANIFEST=ROOT/'assets/direction4/level1_ruan_xiaoer_merchant_20261016.json'
ORDINARY=ROOT/'assets/direction4/level1_ruan_xiaowu_merchant_20261016.json'
FAMILY='character_traits_v2_ruan_xiaoer_merchant'
MAP={}
SINGLES={'walk_contact_b_nw_canon':'nw','walk_passing_b_nw_canon':'nw','walk_contact_b_ne':'ne','walk_passing_b_ne_clear':'ne'}
def source(key):return RAW/(key+'_native.png')

def barefoot_geometry(path,single=False,standing=True):
    # Read-only lower bare-skin measurement: no shoe-color assumption, no PNG
    # writes. Atlas splitting retains the existing strong-alpha separator gate.
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    a=np.array(Image.open(path));h,w=a.shape[:2];assert a.shape[2]==4
    strong=a[:,:,3]>=16
    if single:cells={single:[0,0,w,h]};split=None
    else:
        sx=base.shared.separator(strong.sum(axis=0));sy=base.shared.separator(strong.sum(axis=1));split=[sx,sy]
        cells=dict(zip(base.DIRS,([0,0,sx,sy],[sx,0,w-sx,sy],[0,sy,sx,h-sy],[sx,sy,w-sx,h-sy])))
    result={}
    for d,(x,y,cw,ch) in cells.items():
        c=a[y:y+ch,x:x+cw];mask=c[:,:,3]>=64;ys,xs=np.where(mask);assert len(xs)>1000
        bounds=[int(xs.min())+x,int(ys.min())+y,int(xs.max())+1+x,int(ys.max())+1+y]
        if not standing:
            result[d]={'region':[x,y,cw,ch],'strong_bounds':bounds,'measured_pivot':None,'pivot_policy':'Lying pose uses idle world anchor.'};continue
        rgb=c[:,:,:3].astype(np.int16)
        skin=(rgb[:,:,0]>rgb[:,:,1]+12)&(rgb[:,:,1]>rgb[:,:,2]+4)&(rgb[:,:,0]>rgb[:,:,2]+25)
        lower=np.indices(mask.shape)[0]>(ys.max()-(ys.max()-ys.min())*.28)
        labels,count=ndimage.label(mask&skin&lower);areas=np.bincount(labels.ravel());areas[0]=0
        keep=[i for i in range(1,len(areas)) if areas[i]>=max(100,float(areas.max())*.15)]
        assert keep,(str(path),d,'No substantial lower bare-skin component')
        fy,fx=np.where(np.isin(labels,keep));pivot=[round((int(fx.min())+int(fx.max()))*.5+x,3),int(fy.max())+y+1]
        result[d]={'region':[x,y,cw,ch],'strong_bounds':bounds,'measured_pivot':pivot,'pivot_policy':'Read-only lower bare-skin contact bounds; no footwear pixels invented.'}
    return {'size':[w,h],'split':split,'cells':result}

def prepare():
    assert not any(p.exists() for p in [RUNTIME,MANIFEST])
    old=json.loads(ORDINARY.read_text(encoding='utf-8'));keys={MAP.get(p['source'],p['source']) for p in old['poses'].values()}
    g={k:barefoot_geometry(source(k),SINGLES.get(k,False),not k.startswith(('death_fall','death_settle','death_rest'))) for k in keys}
    RUNTIME.mkdir();sources={}
    for k in sorted(keys):
        dest=RUNTIME/(k+'.png');shutil.copyfile(source(k),dest);base.shared.import_descriptor(dest)
        sources[k]={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':source(k).relative_to(ROOT).as_posix(),'sha256':base.sha(dest),'native_size':g[k]['size'],'imported_size':g[k]['size'],'geometry':g[k],'import_dimensions_verified':False}
    portrait=RUNTIME/'portrait.png';shutil.copyfile(source('portrait'),portrait);base.shared.import_descriptor(portrait)
    idle=g['idle']['cells'];scale={d:math.ceil((idle[d]['measured_pivot'][1]-idle[d]['strong_bounds'][1])/.74)/old['poses']['idle_'+d]['virtual_canvas_reference'] for d in base.DIRS}
    poses={}
    for name,previous in old['poses'].items():
        phase,d=name.rsplit('_',1);k=MAP.get(previous['source'],previous['source']);c=g[k]['cells'][d];x,y,w,h=c['region']
        intended=math.ceil(previous['virtual_canvas_reference']*scale[d]);px,py=c['measured_pivot'] or idle[d]['measured_pivot']
        # The builtin spacing revision draws the entire original windup pose
        # smaller to leave a transparent cross. Restore only uniform displayed
        # size from the same raised-blade-to-shoe measurement in both sources.
        if k=='attack_windup_spacing':
            prior=old['sources'][previous['source']]['geometry']['cells'][d]
            ratio=(py-c['strong_bounds'][1])/(prior['measured_pivot'][1]-prior['strong_bounds'][1])
            intended=math.ceil(previous['virtual_canvas_reference']*ratio)
        if phase in ['death_fall','death_settle','death_rest']:
            ix,iy,_,_=idle[d]['region'];px,py=idle[d]['measured_pivot'];px+=x-ix;py+=y-iy
        if k in SINGLES:intended=math.ceil((py-c['strong_bounds'][1])/.74)
        dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
        poses[name]={'source':k,'region':c['region'],'margin':[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched builtin native PNG. Godot atlas sampling, virtual transparent margins and uniform scale only; no bitmap writes, cropping, mirror or resampling.'}
    m={'schema':old['schema'],'character':FAMILY,'body_owner':'ruan_xiaoer','sources':sources,'poses':poses,'states':base.STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in base.STATES for d in base.DIRS],'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'candidate_origin':source('portrait').relative_to(ROOT).as_posix(),'sha256':base.sha(portrait)},'production_qualified':False,'native_dimensions_verified':False,'canon':'120-chapter Water Margin15: rugged hollow-cheeked face, upright brows, wide mouth, powerful arms, yellow chest hair and broad back; worn headcloth/old clothing and bare feet at first meeting. Chapter16: seven merchants strip to cool and carry pu-dao. Explicit hn_ruan_xiaoer only. Exact face/beard/colors/trousers, continued bare feet and game moves are conservative art choices. No Ruan5 flower/leopard tattoo or Ruan7 yellow beard/spots. Generic ruan_brother group identity, skills, other stages and novel fate unchanged.'}
    base.calibrate_walk_roots(m)
    for name,text in base.renderer().render(m).items():
        p=ROOT/name;assert not p.exists();p.write_bytes(text.encode())
    MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n');return m
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');args=p.parse_args()
    m=prepare() if args.prepare else json.loads(MANIFEST.read_text(encoding='utf-8'))
    for row in m['sources'].values():assert base.sha(ROOT/row['path'])==base.sha(ROOT/row['candidate_origin'])==row['sha256']
    assert base.sha(ROOT/m['portrait']['path'])==base.sha(ROOT/m['portrait']['candidate_origin'])==m['portrait']['sha256']
    for name,text in base.renderer().render(m).items():assert (ROOT/name).read_bytes()==text.encode()
    print(json.dumps({'runtime_body_portrait':len(m['sources'])+1,'resources':len(m['resources']),'poses':len(m['poses']),'native_qualified':False}))
if __name__=='__main__':main()
