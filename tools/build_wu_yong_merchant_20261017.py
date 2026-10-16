"""Bind untouched builtin Wu Yong merchant sources; no PNG pixel writes."""
import argparse,json,math,shutil,subprocess
from pathlib import Path
import build_liu_tang_pudao_20261016 as base
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'assets/characters/wu_yong_merchant_sources_20261017'
RUNTIME=ROOT/'assets/characters/wu_yong_merchant_20261017'
MANIFEST=ROOT/'assets/direction4/level1_wu_yong_merchant_20261017.json'
REFERENCE=ROOT/'assets/direction4/level1_chao_gai_merchant_20261017.json'
FAMILY='character_traits_v2_wu_yong_merchant'
SINGLES={'walk_contact_b_ne_corrected':'ne','walk_contact_b_nw_corrected':'nw','walk_contact_a_ne_corrected':'ne'}
ALIASES={k:k+'_v2' for k in ['walk_contact_b','walk_passing_a','walk_passing_b','attack_recover','hurt_recover']}

def merchant_geometry(path,single=False,standing=True):
    # Read-only lower bare-skin measurement: no shoe-color assumption, no PNG
    # writes. Atlas splitting retains the existing strong-alpha separator gate.
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    a=np.array(Image.open(path));h,w=a.shape[:2];assert a.shape[2]==4
    strong=a[:,:,3]>=16
    if single:cells={single:[0,0,w,h]};split=None
    else:
        # Top and rear rows may have different clear vertical gutters. Each
        # is sampled as its own original rectangular Godot atlas region.
        sy=base.shared.separator(strong.sum(axis=1))
        top=base.shared.separator(strong[:sy].sum(axis=0));bottom=base.shared.separator(strong[sy:].sum(axis=0));split={'y':sy,'top_x':top,'bottom_x':bottom}
        cells=dict(zip(base.DIRS,([0,0,top,sy],[top,0,w-top,sy],[0,sy,bottom,h-sy],[bottom,sy,w-bottom,h-sy])))
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

def prepare(revise=False):
    # Resume an interrupted, still-untracked prepare without overwriting PNGs.
    if RUNTIME.exists() and not MANIFEST.exists():
        assert not subprocess.check_output(['git','ls-files','--',RUNTIME.relative_to(ROOT).as_posix()],cwd=ROOT)
        revise=True
    if revise:
        assert RUNTIME.exists()
        assert subprocess.run(['git','ls-files','--error-unmatch','--',MANIFEST.relative_to(ROOT).as_posix()],cwd=ROOT,capture_output=True).returncode!=0,'Never revise adopted resources'
    else:assert not RUNTIME.exists() and not MANIFEST.exists()
    RUNTIME.mkdir(exist_ok=revise)
    old=json.loads(REFERENCE.read_text(encoding='utf-8'))
    keys=list(dict.fromkeys(k for phases in base.STATES.values() for k in phases));sources={}
    for key in keys+list(SINGLES):
        src=RAW/(ALIASES.get(key,key)+'_native.png');dest=RUNTIME/(key+'.png')
        if not dest.exists():shutil.copyfile(src,dest);base.shared.import_descriptor(dest)
        else:assert revise and base.sha(src)==base.sha(dest),'Never overwrite a native PNG'
        lying=key in ['death_fall','death_settle','death_rest'];g=merchant_geometry(dest,single=SINGLES.get(key,False),standing=not lying)
        for c in g['cells'].values():
            if c['measured_pivot'] is not None:
                # The skin pass locates the calf/toe contact, never a pale blade.
                # If the lowest painted pixels are within a sandal sole width,
                # retain that actual row; otherwise allow only seven native px
                # below exposed toes, excluding a foreground weapon tip.
                skin_y=c['measured_pivot'][1];bottom=c['strong_bounds'][3]
                c['measured_pivot'][1]=bottom if bottom-skin_y<=20 else skin_y+7
                c['pivot_policy']='Read-only calf/toe contact plus actual nearby sandal sole; no shoe recoloring or bitmap writes.'
        sources[key]={'path':dest.relative_to(ROOT).as_posix(),'candidate_origin':src.relative_to(ROOT).as_posix(),'sha256':base.sha(dest),'native_size':g['size'],'imported_size':g['size'],'geometry':g}
    portrait=RUNTIME/'portrait.png'
    if not portrait.exists():shutil.copyfile(RAW/'portrait_native.png',portrait);base.shared.import_descriptor(portrait)
    else:assert revise and base.sha(portrait)==base.sha(RAW/'portrait_native.png')
    poses={};idle=sources['idle']['geometry']['cells']
    for key in keys:
        for d in base.DIRS:
            source_key='walk_contact_a_ne_corrected' if key=='walk_contact_a' and d=='ne' else ('walk_contact_b_'+d+'_corrected' if key=='walk_contact_b' and d in ['ne','nw'] else key)
            row=sources[source_key];c=row['geometry']['cells'][d]
            previous=old['poses'][key+'_'+d];prior=old['sources'][previous['source']]['geometry']['cells'][d]
            box=c['strong_bounds'];pb=prior['strong_bounds'];lying=key in ['death_fall','death_settle','death_rest']
            ratio=(box[2]-box[0])/(pb[2]-pb[0]) if lying else (box[3]-box[1])/(pb[3]-pb[1])
            intended=math.ceil(previous['virtual_canvas_reference']*ratio)
            x,y,w,h=c['region']
            if lying:
                ix,iy,_,_=idle[d]['region'];px,_=idle[d]['measured_pivot'];px+=x-ix
                # A horizontal body occupies a different native row than idle.
                # Its visible supporting hand/feet bottom meets the world floor;
                # inheriting idle's lower row leaves a visible ground gap.
                py=box[3]
            else:px,py=c['measured_pivot']
            dx,dy=px-x,py-y;canvas=math.ceil(max(intended,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            poses[key+'_'+d]={'source':source_key,'region':c['region'],'margin':[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'same_pose_reference':key+'_'+d,'uniform_reference_ratio':ratio,'operations':'Untouched builtin PNG. Godot atlas regions, virtual margins and uniform display only. Same-pose reference calibrates source spacing, never copies or transforms pixels.'}
    m={'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'wu_yong','sources':sources,'poses':poses,'states':base.STATES,'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in base.STATES for d in base.DIRS],'portrait':{'path':portrait.relative_to(ROOT).as_posix(),'candidate_origin':(RAW/'portrait_native.png').relative_to(ROOT).as_posix(),'sha256':base.sha(portrait)},'production_qualified':False,'native_dimensions_verified':False,'canon':'Chapter14 Wu Yong has refined features, fair complexion and long beard; cloth scholar headwear. Chapter15 he puts on straw sandals. Chapter16 seven merchants strip to cool and all carry pu-dao. Exact body/continued black headcloth/trouser colors/hand/sandals/moves are art choices. hn_wu_yong only, generic defeat not novel death. Stage range200 phantom melee intentionally corrected to26; ordinary ranged Wu and skills unchanged.'}
    base.calibrate_walk_roots(m)
    for n,t in base.renderer().render(m).items():
        p=ROOT/n;assert revise or not p.exists();p.write_bytes(t.encode())
    MANIFEST.write_bytes((json.dumps(m,ensure_ascii=False,indent=2)+'\n').encode());return m
def main():
    p=argparse.ArgumentParser(description=__doc__);group=p.add_mutually_exclusive_group();group.add_argument('--prepare',action='store_true');group.add_argument('--revise',action='store_true');args=p.parse_args()
    m=prepare(args.revise) if args.prepare or args.revise else json.loads(MANIFEST.read_text(encoding='utf-8'))
    for row in m['sources'].values():assert base.sha(ROOT/row['path'])==base.sha(ROOT/row['candidate_origin'])==row['sha256']
    assert base.sha(ROOT/m['portrait']['path'])==base.sha(ROOT/m['portrait']['candidate_origin'])==m['portrait']['sha256']
    for n,t in base.renderer().render(m).items():assert (ROOT/n).read_bytes()==t.encode()
    print(json.dumps({'runtime_body_portrait':len(m['sources'])+1,'poses':len(m['poses']),'resources':len(m['resources']),'native_qualified':False}))
if __name__=='__main__':main()
