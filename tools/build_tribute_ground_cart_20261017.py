"""Bind the adopted untouched cart prop to its own wheel-centred world role."""
import argparse,copy,json,math
from pathlib import Path
import numpy as np
from PIL import Image
import build_liu_tang_pushcart_20261017 as base
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'assets/direction4/level1_tribute_ground_cart_20261017.json'
FAMILY='tribute_ground_cart_20261017'
def intended():
    old=json.loads(base.MANIFEST.read_text(encoding='utf-8'))
    row=copy.deepcopy(old['sources']['cart_only']);poses={}
    alpha=np.asarray(Image.open(ROOT/row['path']))[:,:,3]
    for d in base.base.DIRS:
        p=copy.deepcopy(old['poses']['cart_only_'+d]);x,y,w,h=p['region']
        px,py=row['wheel_contacts'][d];dx,dy=px-x,py-y
        reference=p['virtual_canvas_reference']
        canvas=math.ceil(max(reference,2*dx,2*(w-dx),dy/.82,(h-dy)/.18))
        p.update(pivot_native=[px,py],margin=[canvas*.5-dx,canvas*.82-dy,canvas-w,canvas-h],draw_scale=canvas/reference,
            operations='Same untouched adopted cart PNG. Godot atlas/margins/uniform display only; wheel contact is the ground logical anchor. No actor identity is reused.')
        ys,xs=np.where(alpha[y:y+h,x:x+w]>=64);assert len(xs)>0
        p['strong_bounds']=[x+int(xs.min()),y+int(ys.min()),x+int(xs.max())+1,y+int(ys.max())+1]
        p['visible_top']=(p['margin'][1]+int(ys.min()))/canvas
        poses['cart_only_'+d]=p
    return {'schema':'native_direction4_spriteframes_v1','character':FAMILY,'role':'loaded_tribute_ground_prop',
        'sources':{'cart_only':row},'poses':poses,'states':{'idle':['cart_only']},
        'resources':[f'assets/anim/{FAMILY}_idle_{d}.tres' for d in base.base.DIRS],
        'production_qualified':False,'native_dimensions_verified':False,
        'canon':'Chapter16 tribute goods are loaded and covered in seven Jiangzhou carts after seizure. Original escort shoulder loads stay unchanged until this exact mission cargo has actually been taken and subsequently put down. Current three-goal abstraction and force route remain game design; no full seven-carts/eleven-loads claim.'}
def texts(m):
    result=base.base.renderer().render(m)
    for d in base.base.DIRS:
        name=f'assets/anim/{FAMILY}_idle_{d}.tres'
        result[name]=result[name].replace('metadata/draw_scale =',f"metadata/visible_top = {m['poses']['cart_only_'+d]['visible_top']:.9f}\nmetadata/draw_scale =")
    return result
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--update-candidate',action='store_true');args=parser.parse_args()
    assert not (args.prepare and args.update_candidate)
    m=intended();outputs=texts(m)
    if args.prepare:
        assert not MANIFEST.exists() and all(not (ROOT/n).exists() for n in outputs)
    if args.update_candidate:
        import subprocess
        assert not subprocess.check_output(['git','ls-files','--',MANIFEST.relative_to(ROOT).as_posix(),*outputs],cwd=ROOT),'Never overwrite adopted resources'
    if args.prepare or args.update_candidate:
        MANIFEST.write_bytes((json.dumps(m,ensure_ascii=False,indent=2)+'\n').encode())
        for n,t in outputs.items():(ROOT/n).write_bytes(t.encode())
    assert json.loads(MANIFEST.read_text(encoding='utf-8'))==m
    for n,t in outputs.items():assert (ROOT/n).read_bytes()==t.encode()
    row=m['sources']['cart_only'];assert base.base.sha(ROOT/row['path'])==base.base.sha(ROOT/row['candidate_origin'])==row['sha256']
    print(json.dumps({'unchanged_adopted_png':True,'wheel_centred_poses':len(m['poses']),'resources':len(outputs),'native_qualified':False}))
if __name__=='__main__':main()
