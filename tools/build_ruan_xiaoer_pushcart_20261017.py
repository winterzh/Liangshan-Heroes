"""Bind unchanged Ruan Xiaoer pushcart views with rigid cart depth/contact calibration.

Only --prepare creates a new untracked version; default is read-only verification.
No bitmap writes, extraction, mirroring, recolouring or re-encoding.
"""
import argparse,copy,json,math,shutil,subprocess
from pathlib import Path
import numpy as np
from PIL import Image
import build_liu_tang_pushcart_20261017 as base
import verify_ruan_xiaoer_pushcart_sources_20261017 as audit
import build_chao_gai_pushcart_20261017 as prior
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'assets/characters/ruan_xiaoer_pushcart_sources_20261017'
RUNTIME=ROOT/'assets/characters/ruan_xiaoer_pushcart_20261017'
MANIFEST=ROOT/'assets/direction4/level1_ruan_xiaoer_pushcart_20261017.json'
FAMILY='ruan_xiaoer_pushcart_20261017'
STATES=base.STATES
def measure(path,d,region=None):
    if region is None:return prior.measure(path,d)
    # Read only the authored view, not assumed half-sheet coordinates.
    a=np.asarray(Image.open(path));x,y,cw,ch=region;c=a[y:y+ch,x:x+cw]
    rgb=c[:,:,:3].astype(int);yy,xx=np.indices((ch,cw))
    rois={'se':(.38,.74,.45,1),'sw':(.26,.65,.45,1),'ne':(.57,.98,.28,.8),'nw':(.02,.43,.28,.8)}
    left,right,top,bottom=rois[d]
    wood=(c[:,:,3]>=64)&(rgb[:,:,0]>100)&(rgb[:,:,0]-rgb[:,:,1]>12)&(rgb[:,:,1]-rgb[:,:,2]>15)&(xx>=cw*left)&(xx<cw*right)&(yy>=ch*top)&(yy<ch*bottom)
    ys,xs=np.where(wood);assert len(xs)>100;low=int(ys.max());_,bx=np.where(wood&(yy>=low-3))
    wheel=[float(bx.mean())+x,low+y+1]
    limits={'se':(.56,.98,.28,1),'sw':(.02,.44,.28,1),'ne':(.60,.98,.10,.85),'nw':(.02,.40,.10,.85)}
    left,right,top,bottom=limits[d]
    ys,_=np.where((c[:,:,3]>=64)&(xx>=cw*left)&(xx<cw*right)&(yy>=ch*top)&(yy<ch*bottom))
    assert len(ys)>1000
    surface_top=int(ys.min())+y;depth=wheel[1]-surface_top;assert depth>100
    return {'wheel':wheel,'cart_top':surface_top,'cart_depth':depth,'sampling_roi_normalized':list(limits[d]),'authored_region':list(region)}

def intended():
    audit.verify();selection=json.loads((RAW/'prompt_set.json').read_text(encoding='utf-8'))
    old=json.loads(base.MANIFEST.read_text(encoding='utf-8'));by_key={r['key']:r for r in selection['sources']}
    sources={}
    for k in selection['selected_candidates']:
        row=by_key[k];p=RUNTIME/(k+'.png')
        sources[k]={'path':p.relative_to(ROOT).as_posix(),'candidate_origin':row['path'],'sha256':row['sha256'],
          'native_size':row['geometry']['size'],'imported_size':row['geometry']['size'],'selected_directions':row['selected_directions'],
          'whole_original_corner_alpha':row['geometry']['corner_alpha'],'view_geometry':row['geometry']['cells']}
    sources['cart_only']=copy.deepcopy(old['sources']['cart_only'])
    offsets=old['wheel_offsets_per_body_size'];poses={};canonical={}
    for d in base.base.DIRS:
        canonical[d]=measure(ROOT/sources['cart_only']['path'],d)
        original_reference=old['poses']['cart_only_'+d]['virtual_canvas_reference']
        for pose in ['push_idle','push_contact_a','push_passing_a','push_contact_b','push_passing_b','cart_only']:
            key='cart_only' if pose=='cart_only' else selection['view_bindings'][pose][d];row=sources[key]
            region=old['poses']['cart_only_'+d]['region'] if pose=='cart_only' else by_key[key]['geometry']['cells'][d]['region']
            source_path=ROOT/row['path'] if pose=='cart_only' else ROOT/row['candidate_origin']
            metrics=measure(source_path,d,None if pose=='cart_only' else region);row.setdefault('wheel_contacts',{})[d]=metrics['wheel']
            row.setdefault('cart_depth_geometry',{})[d]=metrics
            reference=original_reference*metrics['cart_depth']/canonical[d]['cart_depth']
            px,py=[metrics['wheel'][i]-offsets[d][i]*reference for i in range(2)]
            x,y,w,h=region;dx,dy=px-x,py-y
            canvas=math.ceil(max(reference,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
            poses[pose+'_'+d]={'source':key,'region':region,'margin':[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],
             'draw_offset_px':[0,0],'draw_scale':canvas/reference,'virtual_canvas_reference':reference,'pivot_native':[px,py],
             'cart_depth_pixels':metrics['cart_depth'],'operations':'Untouched PNG; explicit accepted view only. Godot region/margins/uniform display. Shared cart-depth scale and fixed wheel-to-root vector; no per-step footwear anchoring or bitmap edits.'}
            alpha=np.asarray(Image.open(source_path))[y:y+h,x:x+w,3];ys,_=np.where(alpha>=64);assert len(ys)>0
            poses[pose+'_'+d]['visible_top']=(poses[pose+'_'+d]['margin'][1]+int(ys.min()))/canvas
    return {'schema':'native_direction4_spriteframes_v1','character':FAMILY,'body_owner':'ruan_xiaoer','sources':sources,'poses':poses,'states':STATES,
     'resources':[f'assets/anim/{FAMILY}_{s}_{d}.tres' for s in STATES for d in base.base.DIRS],
     'wheel_offsets_per_body_size':offsets,'canonical_cart_geometry':canonical,'production_qualified':False,'native_dimensions_verified':False,
     'canon':'Chapter16 Ruan Xiaoer is one of seven shirtless jujube merchants who cover eleven tribute burdens in seven Jiangzhou carts and push away. Chapter15 broad face/mouth, upright brows, strong ribs/arms and natural yellow chest hair retained. Brown headcloth, short black beard, grey trousers/olive grey sash, continued bare feet, exact proportions, single visible wheel, covered bundle count/materials/weapon stowage are art interpretations. No Ruan Xiaowu flower/leopard or Xiaoqi yellow beard/black spots. Two other Ruan carriers, three-target/shoulder wording, seven-cart-eleven-burden mapping and full wheel rotation remain open. Only ruan_xiaoer/hn_ruan_xiaoer carrying_tribute in level1.'}


def render(m):
    outputs=base.base.renderer().render(m)
    for name,text in outputs.items():
        for key,pose in m['poses'].items():
            marker='[sub_resource type="AtlasTexture" id="'+key+'"]\n'
            if marker in text:text=text.replace(marker,marker+f"metadata/visible_top = {pose['visible_top']:.9f}\n")
        outputs[name]=text
    return outputs
def main():
    p=argparse.ArgumentParser(description=__doc__);g=p.add_mutually_exclusive_group();g.add_argument('--prepare',action='store_true');g.add_argument('--revise-candidate',action='store_true');args=p.parse_args();m=intended()
    if args.prepare:assert not RUNTIME.exists() and not MANIFEST.exists()
    if args.revise_candidate:assert not subprocess.check_output(['git','ls-files','--',MANIFEST.relative_to(ROOT).as_posix(),*m['resources']],cwd=ROOT),'Never revise adopted resources'
    if args.prepare or args.revise_candidate:
        RUNTIME.mkdir(exist_ok=args.revise_candidate)
        for k,row in m['sources'].items():
            if k=='cart_only':continue
            dest=ROOT/row['path']
            if dest.exists():assert args.revise_candidate and base.base.sha(dest)==row['sha256']
            else:shutil.copyfile(ROOT/row['candidate_origin'],dest);base.base.shared.import_descriptor(dest)
        for n,t in render(m).items():
            assert args.revise_candidate or not (ROOT/n).exists();(ROOT/n).write_bytes(t.encode())
        MANIFEST.write_bytes((json.dumps(m,ensure_ascii=False,indent=2)+'\n').encode())
    assert json.loads(MANIFEST.read_text(encoding='utf-8'))==m
    for row in m['sources'].values():assert base.base.sha(ROOT/row['path'])==base.base.sha(ROOT/row['candidate_origin'])==row['sha256']
    for n,t in render(m).items():assert (ROOT/n).read_bytes()==t.encode()
    print(json.dumps({'new_untouched_pngs':5,'shared_cart_pngs':1,'poses':len(m['poses']),'resources':len(m['resources']),'native_qualified':False}))
if __name__=='__main__':main()
